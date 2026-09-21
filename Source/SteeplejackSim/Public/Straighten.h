#pragma once

// Bringing a leaning chimney back upright — the STRAIGHTEN archetype.
//
// The tenth archetype, argued for in 19-the-complete-game.md and placed at job eleven on purpose:
// it is felling INVERTED. You cut into the base of a shaft with everything you learned killing
// them, and this time if it comes down you have failed. It is the one job in the campaign where
// the skyline is the same at the end as it was at the start, and it can only mean that after ten
// jobs of the opposite.
//
// ## The method, which is real and is a hundred and forty years old
//
// Chisel a course of brick out of the CONVEX side — the side it leans away from — hold the gap
// open on graduated iron wedges, then withdraw the smallest wedges first and let gravity bring the
// stack back onto itself. Refill with a thinner course. One recorded job took a 120 ft shaft that
// was 3 ft 1 1/2 in out of perpendicular and brought it back with "not a single brick fractured".
// Usually one cut does it; a 200 ft stack 4 ft 6 in out took three. It cost about a tenth of a
// rebuild.
//
// ## Why it is a good verb
//
// **The arithmetic is the puzzle, and it is arithmetic the trade actually did.** From a job in
// 1875: "it had been calculated that 1/4 inch would bring the stack back 7 inches at top". Choose
// where to cut and how much thickness to take out, and the game tells you what that will do —
// before you do it. Cut high and a little goes a long way, which is leverage and is also the
// reason the masons at the highest cut on one job left the work: the oscillation opened and closed
// the slit by three quarters of an inch.
//
// **And it overshoots.** "The chimney continued during several weeks to settle slightly in the
// direction opposite to its former inclination. This circumstance had to be carefully considered
// beforehand, or else the slits would have been made too wide." A perfect cut on the day is wrong
// by the next month, so the aim is not zero — it is a little short of zero.

#include "Export.h"

#include <cstdint>

namespace sj {

class Tuning;

// How it reads when it has settled. Ordered, so `>= Worse` is "you have made it worse".
enum class PlumbVerdict : uint8_t { Upright, Standing, Short, Worse, Down };

struct StraightenPlan
{
    float cutHeightM{};        // where the course comes out
    float takeOutMm{};         // how much thinner the replacement course is
    float bringsBackM{};       // what that will do at the top, before overshoot
    float leverage{};          // metres of top movement per mm taken out
    float riskShare{};         // 0..1 — how frightening the cut is where you have put it
};

struct StraightenState
{
    PlumbVerdict verdict{PlumbVerdict::Standing};
    float leanAtTopM{};        // where the top is now, relative to plumb. Signed.
    float startedAtM{};
    float settledM{};          // how much has come back so far
    float swayCm{};            // the slit opening and closing while it goes
    bool  settling{};
    bool  collapsed{};
};

class SJ_API Straighten
{
public:
    // `heightM` the shaft, `leanDegrees` how far over it is, `radiusAtCutM` the half-width the cut
    // acts across.
    void Begin(float heightM, float leanDegrees, const Tuning& t) noexcept;

    // What a cut here, this deep, would do. Pure: it changes nothing, and it is what the player
    // reads before committing — the whole verb is deciding, not aiming.
    StraightenPlan Plan(float cutHeightM, float takeOutMm, float radiusAtCutM,
                        const Tuning& t) const noexcept;

    // Commit to it. From here the wedges come out and she moves.
    bool Cut(const StraightenPlan& plan, const Tuning& t) noexcept;

    // Draw one wedge, smallest first. `share` is how far through the set you are, 0 to 1.
    void DrawWedge(float share, const Tuning& t) noexcept;

    // Time passing while she comes back onto herself. Real ones took 18 to 36 hours.
    void Step(float hours, const Tuning& t) noexcept;

    const StraightenState& State() const noexcept { return state_; }
    // What she will read once the settling is finished AND the weeks of overshoot have run.
    StraightenState Settled(const Tuning& t) const noexcept;

private:
    StraightenState state_{};
    StraightenPlan  plan_{};
    float           heightM_{};
    bool            cut_{};
};

}  // namespace sj
