#pragma once

// Deterministic RNG with forkable substreams. See ADR-0003.
//
// Every random value in the sim comes from one of these, passed in by reference. There is
// no ambient randomness anywhere: no rand(), no static generator, no engine RNG. That is
// what makes a recorded replay reproducible, and replay regression is the highest-leverage
// test in the project.

#include "Export.h"

#include <array>
#include <cstdint>

namespace sj {

class SJ_API Rng
{
public:
    explicit Rng(uint64_t seed) noexcept;

    uint32_t NextU32() noexcept;                            // xorshift128+
    float    NextFloat() noexcept;                          // [0, 1)
    float    RangeFloat(float lo, float hi) noexcept;       // [lo, hi)
    int32_t  RangeInt(int32_t lo, int32_t hi) noexcept;     // [lo, hi), returns lo if hi <= lo
    int32_t  PickWeighted(const float* weights, int n) noexcept;  // -1 if n <= 0 or all weights <= 0

    // Independent substream. const on purpose: forking must never advance the parent, or
    // adding one subsystem would shift every later value in the parent stream and
    // invalidate every replay ever recorded. Same parent state + same tag => same stream.
    Rng Fork(uint32_t tag) const noexcept;

    std::array<uint64_t, 2> State() const noexcept;
    void Restore(const std::array<uint64_t, 2>& s) noexcept;

private:
    explicit Rng(const std::array<uint64_t, 2>& s) noexcept;
    uint64_t NextU64() noexcept;

    std::array<uint64_t, 2> state_{};
};

}  // namespace sj
