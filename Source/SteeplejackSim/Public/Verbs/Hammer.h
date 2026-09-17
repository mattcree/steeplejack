#pragma once

// Driving a dog into a mortar joint — VERB-003.
//
// A dog is a forged steel spike with a lug; the ladder lashes to the lug. Getting one in is the
// skill the whole game is built on, and the design is deliberate about what kind of skill:
//
//   **Not a timing bar.** Three axes that interact — power, angle, depth — so that the player
//   learns a feel rather than a rhythm. The lesson they are meant to discover is that full-power
//   swings are wrong most of the time: 60-75% with a clean angle beats 100% with a poor one.
//
// Pure, and one strike at a time. The caller owns the swing state machine and the wobble; wobble
// specifically comes from WobbleAmplitudeDeg (METER-003) and is never recomputed here.
//
// See docs/01-gdd/02-climbing-system.md#2-dogging-in--the-hammer.

#include "Export.h"
#include "Types.h"

namespace sj {

class Tuning;

namespace hammer {

// Resolve one strike.
//
//   joint          what you are driving into; `quality` is the hidden truth the tap test reads
//   currentDepth   0-1, how far this dog is already in
//   power          0-1, the arc length at release
//   angleErrorDeg  how far off the dog's head you were when you let go
//   toolCondition  0-1; a worn hammer is less predictable
SJ_API StrikeResult Strike(const Joint& joint, float currentDepth, float power,
                           float angleErrorDeg, float toolCondition, const Tuning& t) noexcept;

// The depth at which a dog is seated and will hold a ladder.
SJ_API float SeatDepth(const Tuning& t) noexcept;

// How good that strike was, 0-1, from the angle alone. Exposed because it is the number the
// player is actually learning to feel, and a HUD or a tutorial wants to show it.
SJ_API float StrikeQuality(float angleErrorDeg, const Tuning& t) noexcept;

}  // namespace hammer
}  // namespace sj
