#pragma once

// The fixed-step accumulator — CORE-005.
//
// The sim advances in exact 1/60 s increments and nothing else. Every test in this project, the
// replay regression above all, rests on that: a step that sometimes takes 0.0161 s and sometimes
// 0.0163 s makes a recorded run unreproducible and the whole test strategy decorative (ADR-0003).
// So the frame's variable delta is accumulated here and spent in whole ticks.
//
//     const int steps = clock.Advance(deltaSeconds);
//     for (int i = 0; i < steps; ++i) { sim.Step(intents, kTick); }
//     presentation.Render(Lerp(previous, current, clock.Alpha()));
//
// Two things this must get right, and both are about what happens when a frame goes wrong:
//
// * **The spiral of death.** A frame that stalls for two seconds would owe 120 steps; running them
//   makes the next frame late too, which owes more steps again. Advance() caps at
//   kMaxCatchUpSteps and *discards* the rest, so a hitch costs simulated time rather than
//   becoming permanent. A game that stutters and recovers beats one that stutters and dies.
// * **Alpha.** Whatever time is left in the accumulator, as a fraction of a tick, is how far
//   between the last two sim states presentation should draw. It is always in [0, 1); if it ever
//   reached 1 there was a step left unspent.
//
// **The accumulator is an integer, and that is not an optimisation.** The obvious version — a
// float accumulator and `acc -= tick` in a loop — is permanently **one step short** at 75, 90,
// 100, 144 and 165 fps, and exact at 30, 60 and 120. Not drift, and not per second: the deficit
// appears in the first second and stays at exactly 1 forever (measured to one hour: 215999 steps
// against 216000). `kTick` as a float is `0.016666668`, very slightly *larger* than 1/60, so sixty
// of them exceed a second and the sixtieth step never arrives; after that the boundary never bites
// again.
//
// One step in 216000 is nothing as a rate. It is not nothing for **replay**: a run recorded at 60
// fps and played back at 144 is offset by a whole tick from the first second onward, and replay
// regression compares state byte for byte (ADR-0003). A constant offset is exactly as fatal there
// as a growing one. Counting in exact integer sub-tick units removes the class of problem — no
// boundary, no epsilon, the same answer on every compiler.

#include "Export.h"
#include "Types.h"

#include <cstdint>

// Symbol visibility at the UE boundary — the same stopgap Tuning.h carries, and the second time
// this has been needed. UBT builds SteeplejackSim with -fvisibility-ms-compat, so a class's
// out-of-line members are hidden and SteeplejackGame will not link against them. UE's own
// STEEPLEJACKSIM_API macro cannot be used: it expands to DLLEXPORT, which lives in an Unreal
// header this module must never include (ADR-0004). CORE-015 replaces both copies with one
// Export.h; the guard means having both is harmless until it lands.

namespace sj {

class SJ_API SimClock
{
public:
    // The tick is a parameter only so tests can drive it at a rate they can do exact arithmetic
    // in; production always uses kTick. `SimClock clock;` works despite `explicit`, which applies
    // to conversions rather than to default construction.
    explicit SimClock(float tick = kTick) noexcept;

    // Accumulate `realDelta` and return how many whole sim steps the caller owes. Negative or
    // non-finite deltas contribute nothing: time does not run backwards, and one NaN frame would
    // otherwise poison the accumulator for the rest of the session.
    int Advance(float realDelta) noexcept;

    // Render interpolation factor in [0, 1). Valid only after Advance().
    float Alpha() const noexcept;

    // Sim steps dropped to avoid a spiral of death, since construction. Nonzero means the frame
    // rate could not keep up and simulated time was lost — worth surfacing in a dev HUD rather
    // than leaving invisible.
    int64_t DroppedSteps() const noexcept;

    float Tick() const noexcept;

    void Reset() noexcept;

private:
    // One tick is exactly this many accumulator units. Large enough that converting a frame delta
    // to units rounds to well under a microsecond of error, small enough that an int64 cannot
    // overflow in any session length that matters.
    static constexpr int64_t kUnitsPerTick = 1000000;  // literal: the unit scale itself, not a tunable

    float   tick_;
    int64_t accumulator_{};
    int64_t dropped_{};
};

}  // namespace sj
