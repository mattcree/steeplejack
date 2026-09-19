#pragma once

// Hauling on the gin wheel — VERB-007.
//
// A pulley lashed to your top dog, a rope to the yard, and everything heavy comes up it. Without
// it, every one of the eleven sections on a 55 m stack meant climbing to the ground and back, which
// is not a loop anybody would still be in at anchor #10 — and that is MVP criterion 2.
//
// It is also the game's quiet moment: standing still, sixty metres up, gently pulling a rope,
// watching something heavy rise out of the yard. The skill is that patience beats force.
//
// ## The model
//
// A pendulum on a rope that is getting shorter, integrated at the fixed step — ADR-0002 says an ODE
// and not a rope simulation, and this is one:
//
//     θ'' = −(g/L)·sin θ − c·θ' + (pump + steer + wind) / m
//
// where m is the load against a single ladder section, so a heavy load answers to everything more
// slowly (acceptance 3). Three forcing terms:
//
// * **pump** — hauling jerks the load, and the jerk goes into whatever way it is already swinging.
//   Harder hauling, more of it. This is why fast is worse: nothing detects haste; pulling hard
//   simply feeds the swing.
// * **steer** — the player's hand on the rope. Pushed against the swing it takes energy out;
//   pushed with it, it adds. So the skill is reading the phase, which is small, physical and
//   learnable, and is the entire verb.
// * **wind** — a steady push the player can lean against (acceptance 4).
//
// Integrated semi-implicitly — velocity first, then position from the new velocity — which is what
// keeps an undriven pendulum from gaining energy over ten thousand steps (acceptance 5). The
// explicit version gains a little every swing and eventually flings the load over the top.
//
// Past `haulFoulAmplitudeDegrees` the load fouls: it snags or swings into the brickwork.

#include "Export.h"

namespace sj {

class Tuning;

struct HaulState
{
    float height{};      // of the load, metres
    float swingDeg{};    // off the vertical; positive is away from the wall
    float swingVel{};    // degrees a second
    bool  fouled{};
};

namespace haul {

// One fixed step.
//   pull   0..1, how hard he is hauling; 1 is haulSpeedMetresPerSecond
//   steer  -1..1, his hand on the rope; positive pushes away from the wall
//   wind   m/s at the pulley
//   loadKg what is on the hook
//   topM   the pulley's height; the load stops a metre under it
SJ_API void Step(HaulState& s, float dt, float pull, float steer, float wind, float loadKg,
                 float topM, const Tuning& t) noexcept;

// Whether the load is up: close enough under the pulley to take off the hook.
SJ_API bool Arrived(const HaulState& s, float topM) noexcept;

// The swing's amplitude, from where it is and how fast it is going — what the swing meter shows. A
// meter of the angle itself would read zero at the bottom of every swing, which is exactly when
// the player most needs to know how big it is.
SJ_API float AmplitudeDeg(const HaulState& s, float topM, const Tuning& t) noexcept;

}  // namespace haul
}  // namespace sj
