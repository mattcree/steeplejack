// The ladder stack and its load — CLIMB-001 and CLIMB-002.
//
// Where the anchor loop's decisions come due. Each acceptance criterion from both tasks is a case
// here, and one of them documents a disagreement between two numbers the design wrote rather than
// hiding it: see "the top three anchors' share".

#include "doctest.h"

#include "Anchor.h"
#include "Stack.h"
#include "Tuning.h"
#include "Types.h"

#include <chrono>
#include <cmath>
#include <filesystem>
#include <numeric>
#include <string>

using sj::Anchor;
using sj::AnchorRate;
using sj::Lashing;
using sj::SpanBand;
using sj::Stack;
using sj::Tuning;

namespace {

std::string TuningDir()
{
    namespace fs = std::filesystem;
    fs::path here = fs::current_path();
    for (int up = 0; up < 5; ++up)
    {
        if (fs::is_directory(here / "data" / "tuning"))
        {
            return (here / "data" / "tuning").string();
        }
        if (!here.has_parent_path())
        {
            break;
        }
        here = here.parent_path();
    }
    return {};
}

const Tuning& Tune()
{
    static const Tuning t = Tuning::LoadAll(TuningDir());
    return t;
}

Anchor Dog(float height, AnchorRate rate)
{
    Anchor a{};
    a.height = height;
    a.rate = rate;
    a.capacityKN = sj::anchor::CapacityKN(rate, Tune());
    return a;
}

// A stack of `n` dogs `spacing` apart, all of one rating, each section lashed full.
Stack Tower(int n, float spacing, AnchorRate rate)
{
    Stack s;
    int32_t below = 0;
    for (int i = 1; i <= n; ++i)
    {
        const int32_t a = s.AddAnchor(Dog(spacing * static_cast<float>(i), rate));
        s.AddSection(below, a, Lashing::Full);
        below = a;
    }
    return s;
}

}  // namespace

// ---------------------------------------------------------------- CLIMB-001

TEST_CASE("Stack: acceptance 1, the span bands break exactly where climbing.json says")
{
    // Built one section at a time at each boundary and just past it. Not rounded, not reinterpreted.
    auto band = [](float span) {
        Stack s;
        const int32_t a = s.AddAnchor(Dog(span, AnchorRate::Sound));
        const int32_t sec = s.AddSection(0, a, Lashing::Full);
        return s.Band(sec, Tune());
    };
    CHECK(band(4.0f) == SpanBand::Rigid);
    CHECK(band(4.01f) == SpanBand::Flex);
    CHECK(band(6.0f) == SpanBand::Flex);
    CHECK(band(6.01f) == SpanBand::Sway);
    CHECK(band(8.0f) == SpanBand::Sway);
    CHECK(band(8.01f) == SpanBand::Buckle);
}

TEST_CASE("Stack: acceptance 2, an over-long section buckles on a timer, not at once")
{
    // The fairness contract: a warning the player can act on. So under load it counts down for
    // buckleSecondsUnderLoad, and only then goes.
    Stack s;
    const int32_t a = s.AddAnchor(Dog(9.0f, AnchorRate::Sound));
    const int32_t sec = s.AddSection(0, a, Lashing::Full);
    const float limit = Tune().GetF("buckleSecondsUnderLoad");

    float t = 0.0f;
    bool gone = false;
    while (t < limit * 2.0f && !gone)
    {
        const sj::StackEvents ev = s.Step(sj::kTick, sec, Tune().GetF("playerLoadKN"), Tune());
        t += sj::kTick;
        if (!ev.failedSections.empty())
        {
            gone = true;
        }
        else
        {
            REQUIRE(ev.buckling == sec);   // warning the whole time
        }
    }
    CHECK(gone);
    CHECK(t == doctest::Approx(limit).epsilon(0.02));
}

TEST_CASE("Stack: acceptance 3, stepping off a bowing section resets it")
{
    Stack s;
    const int32_t a = s.AddAnchor(Dog(9.0f, AnchorRate::Sound));
    const int32_t sec = s.AddSection(0, a, Lashing::Full);
    const float limit = Tune().GetF("buckleSecondsUnderLoad");
    const float load = Tune().GetF("playerLoadKN");

    // Most of the way to buckling, then off it for a moment, then back on: a full timer again.
    for (float t = 0.0f; t < limit * 0.8f; t += sj::kTick)
    {
        (void)s.Step(sj::kTick, sec, load, Tune());
    }
    (void)s.Step(sj::kTick, -1, load, Tune());
    const sj::StackEvents back = s.Step(sj::kTick, sec, load, Tune());
    CHECK(back.buckleSecondsLeft == doctest::Approx(limit - sj::kTick).epsilon(0.01));
    CHECK_FALSE(s.SectionFailed(sec));
}

TEST_CASE("Stack: acceptance 4, a 5 m span bows several centimetres and a 3 m one hardly at all")
{
    auto bow = [](float span) {
        Stack s;
        const int32_t a = s.AddAnchor(Dog(span, AnchorRate::Sound));
        const int32_t sec = s.AddSection(0, a, Lashing::Full);
        return s.FlexDeflectionM(sec, 1.2f, Tune());
    };
    CHECK(bow(5.0f) >= 0.060f);
    CHECK(bow(5.0f) <= 0.090f);
    CHECK(bow(3.0f) < 0.010f);
    // And it keeps going: a buckling span bows by a lot, which is what the player sees.
    CHECK(bow(8.5f) > bow(6.5f) * 2.0f);
}

TEST_CASE("Stack: acceptance 5, the top of a 14-section stack is its highest anchor")
{
    const Stack s = Tower(14, 3.5f, AnchorRate::Sound);
    CHECK(s.TopHeight() == doctest::Approx(14.0f * 3.5f));
    CHECK(s.SectionCount() == 14);
}

TEST_CASE("Stack: acceptance 6, a 28-section stack steps in under 0.1 ms")
{
    Stack s = Tower(28, 3.5f, AnchorRate::Sound);
    const auto t0 = std::chrono::steady_clock::now();   // test code, not the sim: allowed
    for (int i = 0; i < 1000; ++i)
    {
        (void)s.Step(sj::kTick, 27, Tune().GetF("playerLoadKN"), Tune());
    }
    const double ms_each = std::chrono::duration<double, std::milli>(
        std::chrono::steady_clock::now() - t0).count() / 1000.0;
    CAPTURE(ms_each);
    CHECK(ms_each < 0.1);
}

// ---------------------------------------------------------------- CLIMB-002

TEST_CASE("Stack: acceptance 1, the shares sum to the load")
{
    const Stack s = Tower(12, 3.5f, AnchorRate::Sound);
    const std::vector<float> share = s.Shares(11, 1.2f, Tune());
    CHECK(std::accumulate(share.begin(), share.end(), 0.0f) == doctest::Approx(1.2f));
}

TEST_CASE("Stack: the top three anchors' share — the formula as written, and a disagreement")
{
    // CLIMB-002 acceptance 2 wants the top three anchors to take 78-82% on a 12-section stack, and
    // its context says "falloff 0.55, so the top three take about 80%". Those two sentences
    // disagree: 0.55^n normalised over a dozen anchors puts 83.4% on the top three. The data is
    // implemented as written and the question is in BLOCKED.md rather than settled here by changing
    // a tuning target nobody asked me to change. What is asserted is the formula, exactly, so the
    // number moves the moment the designer moves the falloff.
    const Stack s = Tower(12, 3.5f, AnchorRate::Sound);
    const std::vector<float> share = s.Shares(11, 1.0f, Tune());

    // Anchors 12, 11, 10 are the top three; anchor 0 is the ground, which is also in the chain.
    const float top3 = share[12] + share[11] + share[10];
    const float f = Tune().GetF("loadShareFalloff");
    float sum = 0.0f;
    for (int n = 0; n < 13; ++n)   // twelve dogs and the ground
    {
        sum += std::pow(f, static_cast<float>(n));
    }
    CHECK(top3 == doctest::Approx((1.0f + f + f * f) / sum).epsilon(0.001));
    // "About 80%" is honoured in spirit either way: it is most of the load, on the nearest three.
    CHECK(top3 > 0.75f);
    CHECK(top3 < 0.88f);
}

TEST_CASE("Stack: acceptance 3, a Poor dog holds its share and fails under a shock")
{
    // Its share of a climber, static, is within a Poor dog's rating. The same share arriving as a
    // shock — a slip onto the line — is not.
    const Stack s = Tower(6, 3.5f, AnchorRate::Poor);
    const float load = Tune().GetF("playerLoadKN");
    const std::vector<float> share = s.Shares(5, load, Tune());
    const float cap = Tune().GetF("anchorCapacityKN.poor");
    CHECK(share[6] <= cap);
    CHECK(share[6] * Tune().GetF("dynamicLoadFactor") > cap);
}

TEST_CASE("Stack: acceptance 4, a cascade from 8 takes 7, 6 and 5, in that order")
{
    Stack s = Tower(10, 3.5f, AnchorRate::Poor);
    const float shock = Tune().GetF("playerLoadKN") * Tune().GetF("dynamicLoadFactor");
    const std::vector<int32_t> order = s.Cascade(8, shock, Tune());
    REQUIRE(order.size() == 4);
    CHECK(order[0] == 8);
    CHECK(order[1] == 7);
    CHECK(order[2] == 6);
    CHECK(order[3] == 5);
    CHECK_FALSE(s.AnchorFailed(4));
}

TEST_CASE("Stack: acceptance 5, a cascade stops at the first anchor that can take it")
{
    // Poor dogs above a Sound one: it runs down the Poor ones and stops dead at the Sound.
    Stack s;
    int32_t below = 0;
    const AnchorRate rates[] = {AnchorRate::Poor, AnchorRate::Poor, AnchorRate::Sound,
                                AnchorRate::Poor, AnchorRate::Poor, AnchorRate::Poor};
    for (int i = 0; i < 6; ++i)
    {
        const int32_t a = s.AddAnchor(Dog(3.5f * static_cast<float>(i + 1), rates[i]));
        s.AddSection(below, a, Lashing::Full);
        below = a;
    }
    const float shock = Tune().GetF("playerLoadKN") * Tune().GetF("dynamicLoadFactor");
    const std::vector<int32_t> order = s.Cascade(6, shock, Tune());
    CHECK(order.size() == 3);   // 6, 5, 4 — and the Sound dog at 3 holds
    CHECK_FALSE(s.AnchorFailed(3));
}

TEST_CASE("Stack: acceptance 6, the same cascade twice is the same cascade")
{
    // No randomness anywhere in the module: a cascade the player cannot trace is one that could
    // have gone differently, and this one never can.
    const float shock = Tune().GetF("playerLoadKN") * Tune().GetF("dynamicLoadFactor");
    Stack a = Tower(10, 3.5f, AnchorRate::Poor);
    Stack b = Tower(10, 3.5f, AnchorRate::Poor);
    CHECK(a.Cascade(9, shock, Tune()) == b.Cascade(9, shock, Tune()));
}

TEST_CASE("Stack: when a dog goes, everything above it comes down")
{
    Stack s = Tower(8, 3.5f, AnchorRate::Sound);
    (void)s.Cascade(5, 0.0f, Tune());
    CHECK(s.TopHeight() == doctest::Approx(4.0f * 3.5f));   // anchors 1-4 still hold sections
    for (int32_t sec = 4; sec < 8; ++sec)
    {
        CHECK(s.SectionFailed(sec));
    }
}

TEST_CASE("Stack: a sway span loads its anchors harder, and can pull a Poor dog that carries it")
{
    // The span table's third row made real: on a 6-8 m span the anchors see 1.4x.
    //
    // Worth being precise about what that does with the design's own numbers, because the first
    // version of this test assumed more than it does. Spread down a three-dog stack, a swaying
    // climber puts 0.83 kN on the top dog — inside a Poor dog's 1.0 kN. Sway alone pulls a Poor dog
    // only where it carries most of him: the first dog on the stack, with nothing but the ground
    // below it. Poor dogs higher up fail on *shocks* — a slip onto the line — which is the
    // grimmer and more interesting failure, and the one the load-sharing design is about.
    const float load = Tune().GetF("playerLoadKN");
    auto top_load = [&](float spacing) {
        const Stack s = Tower(3, spacing, AnchorRate::Sound);
        return s.Shares(2, load * sj::anchor::DynamicLoadMultiplier(s.Band(2, Tune()), Tune()),
                        Tune())[3];
    };
    CHECK(top_load(7.0f) == doctest::Approx(top_load(3.5f)
                                            * Tune().GetF("spanDangerDynamicLoadMultiplier")));

    auto first_dog_pulls = [&](float span) {
        Stack s;
        const int32_t a = s.AddAnchor(Dog(span, AnchorRate::Poor));
        const int32_t sec = s.AddSection(0, a, Lashing::Full);
        return !s.Step(sj::kTick, sec, load, Tune()).failedAnchors.empty();
    };
    CHECK_FALSE(first_dog_pulls(3.5f));
    CHECK(first_dog_pulls(7.0f));
}

TEST_CASE("Stack: a quick hitch walks off its dog, and a full lashing does not")
{
    const float load = Tune().GetF("playerLoadKN");
    const float walk_off = Tune().GetF("lashHitchWalkOffCm");
    const float rate = Tune().GetF("lashHitchDriftCmPerMinute");
    const float minutes = walk_off / rate;

    Stack hitch;
    const int32_t a = hitch.AddAnchor(Dog(3.5f, AnchorRate::Sound));
    const int32_t h = hitch.AddSection(0, a, Lashing::Hitch);
    bool went = false;
    for (float t = 0.0f; t < minutes * 60.0f * 1.1f && !went; t += 0.5f)
    {
        went = !hitch.Step(0.5f, h, load, Tune()).failedSections.empty();
    }
    CHECK(went);

    Stack full;
    const int32_t b = full.AddAnchor(Dog(3.5f, AnchorRate::Sound));
    const int32_t f = full.AddSection(0, b, Lashing::Full);
    for (float t = 0.0f; t < minutes * 60.0f * 3.0f; t += 0.5f)
    {
        REQUIRE(full.Step(0.5f, f, load, Tune()).failedSections.empty());
    }
    CHECK(full.SectionDriftCm(f) == doctest::Approx(0.0f));
}

TEST_CASE("Stack: a dog nobody lashed a ladder to carries nothing")
{
    // The first game-side test found this: a player surveys a working position by driving a few
    // dogs, keeps one, lashes to it — and the load model spread his weight across every dog in the
    // wall, including the ones holding nothing up. A driven, unlashed dog is not part of the ladder.
    Stack s;
    const int32_t spare = s.AddAnchor(Dog(6.0f, AnchorRate::Poor));
    const int32_t used = s.AddAnchor(Dog(7.0f, AnchorRate::Sound));
    const int32_t sec = s.AddSection(0, used, Lashing::Full);

    CHECK_FALSE(s.InStructure(spare));
    CHECK(s.InStructure(used));
    CHECK(s.InStructure(0));
    const std::vector<float> share = s.Shares(sec, 1.2f, Tune());
    CHECK(share[static_cast<std::size_t>(spare)] == doctest::Approx(0.0f));

    // And the next section starts from the last *lashed* dog, not the last driven one.
    CHECK(s.TopOfStructure() == used);
}
