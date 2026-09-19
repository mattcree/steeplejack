#pragma once

// Lashing a ladder to a dog — VERB-005.
//
// The only continuous, physical input in the game: you wrap rope by going round, and each full turn
// is a wrap. It was a keypress — press R and the next section was lashed, instantly and perfectly —
// which is the "Press E to work" the anti-pillars forbid by name: an interaction the player could
// not perform better or worse.
//
// ## Where the skill lives
//
// Two things, and each acceptance criterion falls out of one of them rather than being bolted on.
//
// **Rope can only be laid so fast.** Spin faster than the ideal rate and the rope rides up rather
// than bedding down, so the useful rate saturates:
//
//     laid per second = ideal · k · tanh(rate / ideal),   k = 1 / tanh(1)
//
// k is chosen so a steady turn at exactly the ideal rate lays exactly one wrap per
// `lashSecondsPerWrapIdeal` (acceptance 1). The saturation is what punishes jerky input: alternating
// double speed and a stop averages the same rate as a steady turn and lays about 40% less rope,
// because tanh(2) is nowhere near twice tanh(1). Smoothness is not rewarded by a rule that detects
// it; it is rewarded because that is how rope behaves.
//
// **Tension is a hand on the rope.** It rises while you turn and bleeds away when you stop
// (acceptance 3), and tying off with too little of it leaves a slipping knot — the "mistiming" the
// verb spec warns about. So a pause costs twice: the rope you did not lay, and the grip you lost on
// what you had.
//
// Three wraps is a quick hitch: it holds, and it drifts under load, a few centimetres a minute, so
// over a long job the ladder walks off the anchor. Six is a full lashing and does not move. That
// delayed consequence is deliberate — it is the clearest fast-and-worse decision in the anchor loop.

#include "Export.h"
#include "Types.h"

#include <cstdint>

namespace sj {

class Tuning;

struct LashState
{
    int32_t wraps{};
    float   tension{};     // 0-1
    bool    tied{};
    bool    slipping{};    // tied off badly; the knot is walking
    float   laid{};        // progress towards the next wrap, 0-1
};

namespace lash {

// One fixed step. `rotationRate` is turns per second the player is making — from a stick going
// round, a mouse going round, a button being mashed, or a button being held; VERB-006 turns each of
// those into the same number, so this function never knows which it was.
SJ_API void Step(LashState& s, float dt, float rotationRate, const Tuning& t) noexcept;

// Tie it off. Below three wraps it is nothing, and says it is slipping. At three and up it is a
// hitch; at six, a full lashing. Tying off with too little tension leaves whatever it is slipping.
SJ_API Lashing TieOff(LashState& s, const Tuning& t) noexcept;

// How far a lashing walks under load, in cm per minute. Non-zero for a hitch, zero for a full
// lashing, zero for no lashing because there is nothing there to walk.
SJ_API float DriftPerMinuteCm(Lashing l, const Tuning& t) noexcept;

// VERB-006. Three ways to lash, one number out of each: going round (a stick or a mouse, which is
// already a turn rate), mashing a button, or holding one. Stick rotation shuts out players with
// motor impairments from a verb used on every anchor, and there is no version of this game playable
// without lashing — so all three feed `Step` identically and it never learns which it was.
//
// Each press of a mash is a fraction of a turn.
SJ_API float RateFromMash(float pressesPerSecond, const Tuning& t) noexcept;
// Holding turns at a fixed rate: slower than a good hand going round, faster than a bad one. That
// is the right place for it — never the best way, never a punishment.
SJ_API float RateFromHold(const Tuning& t) noexcept;

// Rope laid per second at a given turn rate. Exposed for the HUD, which draws it, and for the test,
// which asserts the shape of it rather than one outcome of it.
SJ_API float LayRate(float rotationRate, const Tuning& t) noexcept;

}  // namespace lash
}  // namespace sj
