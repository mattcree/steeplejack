// Rng tests — CORE-003.
//
// These are determinism tests, not statistics tests. The question is never "is this a
// good generator" (xorshift128+ is a known-good one); it is "does it produce the same
// bytes twice, forever". Replay regression (TEST-002) is built entirely on that, so a
// failure here is a failure of the project's highest-leverage test.

#include "doctest.h"

#include "Rng.h"

#include <array>
#include <cmath>
#include <cstdint>
#include <vector>

using sj::Rng;

namespace {
constexpr int kLongRun = 10000;
constexpr int kDrawsForProportion = 100000;
constexpr uint64_t kSeedA = 12345u;
constexpr uint64_t kSeedB = 999u;

std::vector<uint32_t> Sequence(Rng& r, int n)
{
    std::vector<uint32_t> out;
    out.reserve(static_cast<std::size_t>(n));
    for (int i = 0; i < n; ++i)
    {
        out.push_back(r.NextU32());
    }
    return out;
}
}  // namespace

TEST_CASE("Rng: Acceptance 1: same seed, identical 10,000-value sequence")
{
    Rng a(kSeedA);
    Rng b(kSeedA);
    CHECK(Sequence(a, kLongRun) == Sequence(b, kLongRun));
}

TEST_CASE("Rng: Different seeds diverge")
{
    Rng a(kSeedA);
    Rng b(kSeedB);
    CHECK(Sequence(a, kLongRun) != Sequence(b, kLongRun));
}

TEST_CASE("Rng: Seed 0 is not a degenerate state")
{
    // xorshift128+ is absorbing at all-zero state: seeded naively with 0 it returns 0
    // forever. Seed 0 is also the most likely seed anyone types, so this is the single
    // most valuable case in the file.
    Rng z(0u);
    const std::vector<uint32_t> s = Sequence(z, 100);
    bool all_zero = true;
    for (const uint32_t v : s)
    {
        if (v != 0u)
        {
            all_zero = false;
        }
    }
    CHECK_FALSE(all_zero);

    Rng z2(0u);
    CHECK(Sequence(z2, 100) == s);
}

TEST_CASE("Rng: Acceptance 2: fork(tag) from the same parent state is reproducible")
{
    Rng parent(kSeedA);
    parent.NextU32();
    parent.NextU32();

    Rng f1 = parent.Fork(7u);
    Rng f2 = parent.Fork(7u);
    CHECK(Sequence(f1, kLongRun) == Sequence(f2, kLongRun));
}

TEST_CASE("Rng: Different tags give different substreams")
{
    Rng parent(kSeedA);
    Rng f7 = parent.Fork(7u);
    Rng f8 = parent.Fork(8u);
    CHECK(Sequence(f7, 1000) != Sequence(f8, 1000));
}

TEST_CASE("Rng: A fork is not the parent")
{
    Rng parent(kSeedA);
    Rng forked = parent.Fork(0u);
    CHECK(Sequence(forked, 1000) != Sequence(parent, 1000));
}

TEST_CASE("Rng: Acceptance 3: draining a fork does not move the parent")
{
    // The whole reason Fork() exists. If this fails, adding one random call in the
    // weather system shifts every joint in the grid and invalidates every replay.
    Rng control(kSeedA);
    const std::vector<uint32_t> expected = Sequence(control, 500);

    Rng parent(kSeedA);
    Rng forked = parent.Fork(42u);
    for (int i = 0; i < 5000; ++i)
    {
        forked.NextFloat();
    }
    CHECK(Sequence(parent, 500) == expected);
}

TEST_CASE("Rng: Fork does not advance the parent even once")
{
    Rng parent(kSeedA);
    const std::array<uint64_t, 2> before = parent.State();
    Rng forked = parent.Fork(3u);
    CHECK(parent.State() == before);
    (void)forked;
}

TEST_CASE("Rng: Acceptance 4: state/restore round-trips mid-sequence")
{
    Rng r(kSeedA);
    for (int i = 0; i < 777; ++i)
    {
        r.NextU32();
    }

    const std::array<uint64_t, 2> saved = r.State();
    const std::vector<uint32_t> after = Sequence(r, 1000);

    r.Restore(saved);
    CHECK(r.State() == saved);
    CHECK(Sequence(r, 1000) == after);
}

TEST_CASE("Rng: Restore into a different instance reproduces the stream")
{
    Rng a(kSeedA);
    for (int i = 0; i < 100; ++i)
    {
        a.NextU32();
    }
    Rng b(kSeedB);
    b.Restore(a.State());
    CHECK(Sequence(a, 500) == Sequence(b, 500));
}

TEST_CASE("Rng: NextFloat stays inside [0, 1)")
{
    Rng r(kSeedA);
    for (int i = 0; i < kDrawsForProportion; ++i)
    {
        const float v = r.NextFloat();
        REQUIRE(v >= 0.0f);
        REQUIRE(v < 1.0f);
    }
}

TEST_CASE("Rng: RangeFloat stays inside [lo, hi)")
{
    Rng r(kSeedA);
    for (int i = 0; i < 10000; ++i)
    {
        const float v = r.RangeFloat(-2.5f, 7.5f);
        REQUIRE(v >= -2.5f);
        REQUIRE(v < 7.5f);
    }
}

TEST_CASE("Rng: RangeInt stays inside [lo, hi) and covers both ends")
{
    Rng r(kSeedA);
    bool saw_lo = false;
    bool saw_hi = false;
    for (int i = 0; i < 10000; ++i)
    {
        const int32_t v = r.RangeInt(3, 8);
        REQUIRE(v >= 3);
        REQUIRE(v < 8);
        if (v == 3) { saw_lo = true; }
        if (v == 7) { saw_hi = true; }
    }
    CHECK(saw_lo);
    CHECK(saw_hi);
}

TEST_CASE("Rng: RangeInt degenerate ranges return lo rather than misbehaving")
{
    Rng r(kSeedA);
    CHECK(r.RangeInt(5, 5) == 5);
    CHECK(r.RangeInt(5, 1) == 5);
    CHECK(r.RangeInt(-3, -3) == -3);
}

TEST_CASE("Rng: RangeInt consumes exactly one draw per call")
{
    // Not a style point. A rejection loop would consume a variable number of draws, so
    // the stream position would depend on the values drawn — and a replay landing on a
    // different position diverges everywhere after it. See the note in Rng.cpp.
    Rng a(kSeedA);
    for (int i = 0; i < 100; ++i)
    {
        a.RangeInt(0, 7);
    }

    Rng b(kSeedA);
    for (int i = 0; i < 100; ++i)
    {
        b.NextU32();
    }
    CHECK(a.State() == b.State());
}

TEST_CASE("Rng: Acceptance 5: PickWeighted lands within 1% of its weights")
{
    Rng r(kSeedA);
    const float weights[3] = {0.6f, 0.3f, 0.1f};
    int counts[3] = {0, 0, 0};

    for (int i = 0; i < kDrawsForProportion; ++i)
    {
        const int32_t k = r.PickWeighted(weights, 3);
        REQUIRE(k >= 0);
        REQUIRE(k < 3);
        counts[k] += 1;
    }

    // Absolute tolerance, deliberately not doctest::Approx().epsilon(). Approx compares
    // against epsilon * (scale + max(|lhs|,|rhs|)) with scale defaulting to 1.0, so
    // .epsilon(0.01) on an expected 0.1 is a +/-0.011 window — 11% relative, not the 1%
    // the criterion asks for. It would have passed at 0.089. The criterion says "within
    // 1% of those proportions", so assert exactly that.
    const float n = static_cast<float>(kDrawsForProportion);
    CHECK(std::fabs(static_cast<float>(counts[0]) / n - 0.6f) <= 0.01f);
    CHECK(std::fabs(static_cast<float>(counts[1]) / n - 0.3f) <= 0.01f);
    CHECK(std::fabs(static_cast<float>(counts[2]) / n - 0.1f) <= 0.01f);
}

TEST_CASE("Rng: PickWeighted never returns a zero-weighted option")
{
    Rng r(kSeedA);
    const float weights[4] = {0.5f, 0.0f, 0.5f, 0.0f};
    for (int i = 0; i < 20000; ++i)
    {
        const int32_t k = r.PickWeighted(weights, 4);
        REQUIRE(k != 1);
        REQUIRE(k != 3);
    }
}

TEST_CASE("Rng: PickWeighted rejects input it cannot answer")
{
    Rng r(kSeedA);
    const float ok[2] = {1.0f, 1.0f};
    const float zero[2] = {0.0f, 0.0f};
    CHECK(r.PickWeighted(nullptr, 2) == -1);
    CHECK(r.PickWeighted(ok, 0) == -1);
    CHECK(r.PickWeighted(ok, -1) == -1);
    CHECK(r.PickWeighted(zero, 2) == -1);
}

TEST_CASE("Rng: PickWeighted tolerates a single option and negative weights")
{
    Rng r(kSeedA);
    const float one[1] = {0.25f};
    CHECK(r.PickWeighted(one, 1) == 0);

    const float mixed[3] = {-1.0f, 2.0f, -0.5f};
    for (int i = 0; i < 1000; ++i)
    {
        CHECK(r.PickWeighted(mixed, 3) == 1);
    }
}
