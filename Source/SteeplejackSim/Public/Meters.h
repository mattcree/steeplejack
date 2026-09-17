#pragma once

// Grip — the short meter. METER-001.
//
// Grip is not a stamina bar. A stamina bar restricts movement; grip restricts *work*, and the
// player can always buy more of it by spending time on a better stance. It says: you have about
// twelve seconds of one-handed work before you must stop and hold on. That is the rhythm of the
// whole game — work, hold on, work, hold on — and it is the difficulty dial for every level, since
// level design controls difficulty by controlling how much time pressure you are under, which
// controls which stance you can afford.
//
// See docs/01-gdd/03-meters-grip-nerve.md and the stance table in 02-climbing-system.md.
//
// Everything here is a free function over plain data, with tuning injected. No state of its own,
// no clock, no randomness: the same Meters and MeterContext always produce the same result, which
// is what lets a recorded shift replay (ADR-0003).

#include "Types.h"

namespace sj {

class Tuning;

namespace grip {

// One fixed step. Drains at the stance rate while `ctx.working`, recovers otherwise, and clamps to
// [0, MaxGrip]. Writes only to `m`; the context is read-only, including `workedSeconds`, which the
// caller must advance itself — see the note on MaxGrip.
void Step(Meters& m, float dt, const MeterContext& ctx, const Tuning& t) noexcept;

// Grip lost per second while working in this stance, with every modifier applied. Exposed
// separately because the HUD wants to show the cost of a stance *before* the player commits to
// rigging it — a decision the player cannot make well if the number is invisible.
float DrainRate(Stance stance, const MeterContext& ctx, const Tuning& t) noexcept;

// Grip recovered per second while holding on with both hands.
float RecoverRate(const Tuning& t) noexcept;

// The ceiling. Normally gripMax; capped lower while cold, until enough work has been done to warm
// up. This is why a winter level feels different without changing any other rule.
//
// Reads `ctx.workedSeconds`, which nothing in the sim advances yet — `Step` takes the context by
// const reference on purpose, so whoever assembles a MeterContext each tick owns that accumulator.
// Until that exists the cold cap is correct and permanently inert. See METER-001's Outcome.
float MaxGrip(const MeterContext& ctx, const Tuning& t) noexcept;

// Below the tremor threshold the hands visibly shake and the aim reticle wobbles harder. The
// telegraph for running out, and it must be visible before the failure, not with it — the fairness
// contract requires the warning to precede the consequence.
bool Tremor(const Meters& m, const Tuning& t) noexcept;

// Grip is gone and the hand is coming off. This *reports* the condition; it does not resolve it.
//
// Note for callers: a default-constructed Meters has grip 0, so Slipping({}) is true. That is
// CORE-004's default, not this module's, and it is the mirror image of the hazard MeterContext
// avoids by defaulting `working` to false. Start a climber at MaxGrip, not at {}.
// The slip window, the grab input and the fall are METER-005's, deliberately, so that the meter
// cannot quietly acquire a second responsibility.
bool Slipping(const Meters& m) noexcept;

// Seconds of work left in this stance before a slip, at the current drain rate. What the twelve
// seconds in the design doc actually is, and what a HUD would show. Negative means never (a stance
// that does not drain).
float SecondsOfWorkLeft(const Meters& m, const MeterContext& ctx, const Tuning& t) noexcept;

}  // namespace grip
}  // namespace sj
