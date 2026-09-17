#pragma once

// The two meters. METER-001 (grip) and METER-002 (nerve).
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

#include <cstdint>
#include <string_view>

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

// ---------------------------------------------------------------- nerve
//
// Nerve — the long meter. METER-002.
//
// Nerve is what makes height *mechanically* frightening rather than merely impressive. Without it
// a 110 m chimney plays exactly like a 12 m one, and altitude is set dressing. With it, altitude
// is difficulty.
//
// It never kills the player. It makes them worse at the job, and the job kills them. That is the
// whole design: nerve is not a second health bar, and a third meter would be an anti-pillar.
//
// Minutes-to-hours, against grip's seconds-to-minutes. Nothing here resolves an effect — `Band()`
// reports which of four states the player is in and the presentation layer decides what a
// narrowing audio mix or a tunnel vignette looks like. Wobble is METER-003's, recovery is
// METER-004's, and neither belongs here.
//
// See docs/01-gdd/03-meters-grip-nerve.md.

namespace nerve {

// One fixed step of passive drain:
//
//     drain = base * heightFactor * windFactor * exposureFactor
//
// Every term is tuned, and the height factor is clamped, so a chimney twice as tall is not twice
// as frightening forever — the fear saturates, as it does in people.
void Step(Meters& m, float dt, const MeterContext& ctx, const Tuning& t) noexcept;

// An instant loss from something that happened: a dropped tool, an anchor letting go, a jackdaw.
// Named rather than numbered so the caller reads as the event and not as a magic value.
//
// `noexcept`, per interfaces.md — so an unknown event name cannot throw and **does nothing**. That
// is the one silent failure in this module, and it is deliberate: the alternative inside a
// noexcept contract is std::terminate on a typo. `IsKnownShock` exists so a caller or a test can
// check, and test_nerve.cpp asserts that every `nerveShock.*` key in the tuning data is known —
// which catches the realistic version of this, a shock added to the JSON that the code never
// learned about.
void Shock(Meters& m, std::string_view event, const Tuning& t) noexcept;

// Whether `event` names a shock this build knows. See Shock().
bool IsKnownShock(std::string_view event, const Tuning& t) noexcept;

// How much nerve `event` costs, as a negative number. 0 if unknown.
float ShockAmount(std::string_view event, const Tuning& t) noexcept;

// 0 calm, 1 uneasy, 2 bad, 3 worst. The presentation layer maps these to effects; the sim only
// says which one you are in.
int32_t Band(float nerve, const Tuning& t) noexcept;

// Nerve is gone: the player can descend or recover in place, but cannot climb. Reported, not
// enforced — PLAYER-001 owns what "cannot climb" does.
bool Frozen(const Meters& m) noexcept;

// Change the nerve ceiling for the rest of the shift, and bring current nerve down with it.
//
// `delta` is the **signed change**, matching how the penalty is stored: `meters.json` holds
// `recover.cigaretteMaxNervePenalty` as `-5.0`, so the obvious call does the obvious thing:
//
//     nerve::ReduceMax(m, t.GetF("recover.cigaretteMaxNervePenalty"), t);
//
// A positive delta is ignored — the ceiling only ever falls within a shift. An earlier version took
// a positive magnitude, which meant passing the tuned value straight in was a silent no-op: a sign
// error converted into no effect, in the module that spends a page explaining why silent failures
// are unacceptable. Caught in review.
//
// This is the cigarette: fast, works anywhere, costs you the top of your range. The bad option that
// is always tempting.
void ReduceMax(Meters& m, float delta, const Tuning& t) noexcept;

// A fresh climber at the start of a shift: nerve at nerveStart, which is 90 and not 100, because
// you are always slightly on edge.
Meters FreshShift(const Tuning& t) noexcept;

// The terms of the drain, exposed for a HUD and for tests that assert the formula rather than its
// result.
float HeightFactor(const MeterContext& ctx, const Tuning& t) noexcept;
float WindFactor(const MeterContext& ctx, const Tuning& t) noexcept;
float ExposureFactor(Exposure exposure, const Tuning& t) noexcept;
float DrainRate(const Meters& m, const MeterContext& ctx, const Tuning& t) noexcept;

}  // namespace nerve
}  // namespace sj
