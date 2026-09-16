#include "Rng.h"

namespace sj {
namespace {

// SplitMix64 (Steele, Lea & Flood, 2014). Used only to turn a single seed into a full
// 128-bit state. xorshift128+ is absorbing at an all-zero state, and seed 0 is the most
// likely seed anybody types by hand, so the seed is never used as state directly.
constexpr uint64_t kSplitMixGamma  = 0x9E3779B97F4A7C15ull;
constexpr uint64_t kSplitMixMulA   = 0xBF58476D1CE4E5B9ull;
constexpr uint64_t kSplitMixMulB   = 0x94D049BB133111EBull;
constexpr int      kSplitMixShiftA = 30;
constexpr int      kSplitMixShiftB = 27;
constexpr int      kSplitMixShiftC = 31;

// The xorshift128+ shift triple (Vigna, 2017). These three numbers ARE the algorithm.
// Changing any of them silently invalidates every replay in data/replays/.
constexpr int kShiftA = 23;
constexpr int kShiftB = 18;
constexpr int kShiftC = 5;

constexpr int kU64Bits = 64;
constexpr int kU32Bits = 32;

// Take the HIGH 32 bits of the 64-bit output: xorshift128+'s low-order bits are measurably
// weaker than its high ones, and the low bit fails linearity tests outright.
constexpr int kHighHalfShift = kU64Bits - kU32Bits;

// A float carries 24 mantissa bits including the implicit leading one, so 24 random bits
// scaled by 2^-24 covers [0, 1) with every value exactly representable and no rounding
// back up to 1.0f.
constexpr int   kMantissaBits  = 24;
constexpr float kMantissaScale = 1.0f / 16777216.0f;   // 2^24

uint64_t SplitMix64(uint64_t& x) noexcept
{
    x += kSplitMixGamma;
    uint64_t z = x;
    z = (z ^ (z >> kSplitMixShiftA)) * kSplitMixMulA;
    z = (z ^ (z >> kSplitMixShiftB)) * kSplitMixMulB;
    return z ^ (z >> kSplitMixShiftC);
}

}  // namespace

Rng::Rng(uint64_t seed) noexcept
{
    uint64_t s = seed;
    state_[0] = SplitMix64(s);
    state_[1] = SplitMix64(s);
    if (state_[0] == 0 && state_[1] == 0)
    {
        state_[1] = kSplitMixGamma;
    }
}

Rng::Rng(const std::array<uint64_t, 2>& s) noexcept : state_(s) {}

uint64_t Rng::NextU64() noexcept
{
    uint64_t s1 = state_[0];
    const uint64_t s0 = state_[1];
    state_[0] = s0;
    s1 ^= s1 << kShiftA;
    state_[1] = s1 ^ s0 ^ (s1 >> kShiftB) ^ (s0 >> kShiftC);
    return state_[1] + s0;
}

uint32_t Rng::NextU32() noexcept
{
    return static_cast<uint32_t>(NextU64() >> kHighHalfShift);
}

float Rng::NextFloat() noexcept
{
    const uint32_t bits = NextU32() >> (kU32Bits - kMantissaBits);
    return static_cast<float>(bits) * kMantissaScale;
}

float Rng::RangeFloat(float lo, float hi) noexcept
{
    return lo + (hi - lo) * NextFloat();
}

int32_t Rng::RangeInt(int32_t lo, int32_t hi) noexcept
{
    if (hi <= lo)
    {
        return lo;
    }
    const uint32_t span =
        static_cast<uint32_t>(static_cast<int64_t>(hi) - static_cast<int64_t>(lo));

    // Lemire's multiply-shift, deliberately WITHOUT the usual rejection loop. A rejection
    // loop draws a variable number of values, so the stream position would depend on the
    // values drawn — and a replay that lands on a different position produces different
    // results everywhere after it. One draw in, one value out, always.
    const uint64_t m = static_cast<uint64_t>(NextU32()) * static_cast<uint64_t>(span);
    return static_cast<int32_t>(lo + static_cast<int32_t>(m >> kU32Bits));
}

int32_t Rng::PickWeighted(const float* weights, int n) noexcept
{
    if (weights == nullptr || n <= 0)
    {
        return -1;
    }

    float total = 0.0f;
    for (int i = 0; i < n; ++i)
    {
        if (weights[i] > 0.0f)
        {
            total += weights[i];
        }
    }
    if (total <= 0.0f)
    {
        return -1;
    }

    float u = NextFloat() * total;
    for (int i = 0; i < n; ++i)
    {
        if (weights[i] > 0.0f)
        {
            u -= weights[i];
            if (u < 0.0f)
            {
                return static_cast<int32_t>(i);
            }
        }
    }

    // Only reachable through float rounding, when u survives the whole sweep. Fall back to
    // the last positive weight rather than the last index, so a zero-weighted tail is never
    // returned — a caller asking for 0.0 weight must never see that option come back.
    for (int i = n - 1; i >= 0; --i)
    {
        if (weights[i] > 0.0f)
        {
            return static_cast<int32_t>(i);
        }
    }
    return -1;
}

Rng Rng::Fork(uint32_t tag) const noexcept
{
    uint64_t z = state_[0] ^ (static_cast<uint64_t>(tag) * kSplitMixGamma);
    std::array<uint64_t, 2> forked{};
    forked[0] = SplitMix64(z);
    z ^= state_[1];
    forked[1] = SplitMix64(z);
    if (forked[0] == 0 && forked[1] == 0)
    {
        forked[1] = kSplitMixGamma;
    }
    return Rng(forked);
}

std::array<uint64_t, 2> Rng::State() const noexcept
{
    return state_;
}

void Rng::Restore(const std::array<uint64_t, 2>& s) noexcept
{
    state_ = s;
}

}  // namespace sj
