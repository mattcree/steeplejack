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
// float accumulator and `acc -= tick` in a loop — loses a step per second at 75, 90, 100 and 144
// fps. Not through drift: `kTick` as a float is very slightly *larger* than 1/60, so sixty of them
// add up to more than one second and the sixtieth step never comes. The game would simply run slow
// on those monitors, by an amount too small to see and large enough to make every replay recorded
// at one frame rate fail at another. Counting in exact integer sub-tick units removes the entire
// class of problem: no drift, no epsilon, and the same answer on every compiler.

#include "Types.h"

#include <cstdint>

namespace sj {

class SimClock
{
public:
    // Non-explicit default so `SimClock clock;` works; the tick is a parameter only so tests can
    // drive it at a rate they can do exact arithmetic in.
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
    int DroppedSteps() const noexcept;

    float Tick() const noexcept;

    void Reset() noexcept;

private:
    // One tick is exactly this many accumulator units. Large enough that converting a frame delta
    // to units rounds to well under a microsecond of error, small enough that an int64 cannot
    // overflow in any session length that matters.
    static constexpr int64_t kUnitsPerTick = 1000000;  // literal: the unit scale itself, not a tunable

    float   tick_;
    int64_t accumulator_{};
    int     dropped_{};
};

}  // namespace sj
