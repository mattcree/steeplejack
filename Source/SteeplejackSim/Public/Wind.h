#pragma once

// Wind and the gust that warns you — ENV-003.
//
// The wind was a hard-coded 9 m/s at every height of every level, and the `gust` argument that
// `WobbleAmplitudeDeg` has always taken was passed 0 from the one place that calls it. So every
// level's authored wind profile did nothing, and the gust — which the fairness table lists as a
// thing that can blow you off a chimney — did not exist.
//
// ## The tell is the feature
//
// From 10-failure-and-difficulty.md, on whether being blown off is fair:
//
//     Gust blew you off — only if the 1.2 s audio tell played. Otherwise it's a bug.
//
// That is the only ⚠️ in the table this module can produce, and it is why the gust is modelled as
// two phases rather than as a wind value that jumps. `Tell()` is true for `gustPreRollSeconds`
// before the gust has any mechanical effect at all: the sound arrives, the player has 1.2 seconds
// to take a hand off the hammer and put it on the ladder, and only then does the wobble land. A
// gust with no pre-roll is not a harder gust, it is a broken one.
//
// The presentation layer decides what the tell *is* — a rising note, a visual, both, per rule 8 —
// and may not decide when it happens or whether it happened.
//
// ## Determinism
//
// Gust timing comes from a caller-supplied seeded stream (CORE-003), never from an ambient RNG, so
// a recorded shift replays with the same gusts at the same moments. That is ADR-0003's whole point
// and the reason `Step` takes an `Rng&` rather than reaching for one.

#include "Export.h"
#include "Types.h"

#include <cstdint>

namespace sj {

class Rng;
class Tuning;
struct WeatherSpec;

// Where a gust is in its life. Ordered, so `>= Building` reads as "the player can tell".
enum class GustPhase : uint8_t { Calm, Building, Blowing, Easing };

// The wind, as a thing that changes. One per shift.
class SJ_API WindModel
{
public:
    // Arms the first gust. Call once when the shift starts; without it the first gust of a level
    // lands at a time drawn from an unstarted clock.
    void Begin(const WeatherSpec& weather, Rng& rng, const Tuning& t) noexcept;

    // Advance by one fixed step. `rng` is drawn from only when a gust ends and the next is timed.
    void Step(float dt, const WeatherSpec& weather, Rng& rng, const Tuning& t) noexcept;

    GustPhase Phase() const noexcept { return phase_; }

    // **The 1.2 second warning.** True through the whole of the pre-roll and false the instant the
    // gust bites. A caller that draws its telegraph from `Strength() > 0` instead has built a
    // telegraph that arrives with the consequence, which is the thing the fairness contract exists
    // to forbid.
    bool Tell() const noexcept { return phase_ == GustPhase::Building; }

    // How far through the tell, 0 to 1. For a cue that rises rather than one that just plays.
    float TellProgress(const Tuning& t) const noexcept;

    // 0 to 1, the gust's mechanical strength. Zero during the tell, by design. This is what
    // `WobbleAmplitudeDeg` takes.
    float Strength() const noexcept { return strength_; }

    // Wind speed in m/s at a height, including whatever the gust is adding. What goes into
    // `MeterContext::windSpeed`.
    float SpeedAt(float height, const WeatherSpec& weather, const Tuning& t) const noexcept;

    // Seconds until the next gust begins its tell. Negative on a level with no gusts.
    float SecondsToNextGust() const noexcept { return armed_ ? untilNext_ : -1.0f; }

    // Which quarter it is blowing from, clockwise from north: the level's own bearing, veered by
    // however long the shift has run, and swung by `gustBearingSpreadDegrees` while a gust is on
    // it. A gust that arrives from the same bearing as the wind is not a gust, it is more wind —
    // the shift in direction is most of what makes one feel like a separate event.
    float BearingDeg(const WeatherSpec& weather, const Tuning& t) const noexcept;

    // How the wind is trending, -1 to 1: rising towards a gust, falling as one eases, 0 in calm.
    // What a needle on a gauge does between gusts, and the thing a jack reads off the rope and the
    // sound long before any number changes.
    float Trend() const noexcept;

private:
    void Arm(const WeatherSpec& weather, Rng& rng) noexcept;

    GustPhase phase_{GustPhase::Calm};
    bool      armed_{false};
    float     untilNext_{0.0f};
    float     inPhase_{0.0f};
    float     strength_{0.0f};
    float     elapsed_{0.0f};       // seconds of shift, for the veer
    float     gustSwingDeg_{0.0f};  // this gust's quarter, drawn when it is armed
};

// How hard the wind is shoving him along the rung, in metres of drift a second.
//
// Until now the wind was a nerve drain and a reticle wobble: it frightened him and it spoiled his
// aim, and his body never felt it. A playtest put it plainly — the climb shifts side to side and
// nothing explains why. This is the why. Wind across the face of a chimney pushes a man sideways
// off his line, and holding that line is work.
//
// `relativeBearingDeg` is the wind's bearing measured off the way he is facing, so 0 is straight
// into the brickwork — which presses him onto the ladder and moves him nowhere — and 90 is dead
// abeam, which is the whole of the push. The sign carries which way: positive drifts him right.
//
// Speed enters squared, because drag does, and only the excess over `windPushCalmMetresPerSecond`
// counts: a man is not fighting a four-metre breeze. Stance decides how much of it reaches him —
// belted on, it is a nuisance; one hand on a rung, it is the thing that takes you off.
SJ_API float SidePushMetresPerSecond(float speedAtHeight, float relativeBearingDeg, Stance stance,
                                     const Tuning& t) noexcept;

}  // namespace sj
