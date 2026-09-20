// Wind and the gust that warns you — ENV-003. See Wind.h for why the tell is the feature.

#include "Wind.h"

#include <cmath>

#include "Level.h"
#include "Rng.h"
#include "Tuning.h"

#include <algorithm>

namespace sj {
namespace {

constexpr float kFullTurn = 360.0f;          // literal: degrees in a turn
constexpr float kHalfTurn = 180.0f;          // literal: degrees in a half turn
constexpr float kPi       = 3.14159265f;     // literal: pi, for degrees to radians
constexpr float kSecondsPerHour = 3600.0f;   // literal: seconds in an hour
// How far off the prevailing quarter a gust can come from. Not tuned: a gust that arrives from the
// same bearing as the wind is not a gust, it is more wind, and the swing is most of what makes one
// read as a separate event rather than as the needle going up.
constexpr float kGustSpread = 35.0f;         // literal: degrees either side of the prevailing wind

}  // namespace

namespace {

// Guards two divisions against a designer setting gustPreRollSeconds to zero. Not a tuned value:
// it exists so a nonsense setting produces an instant phase rather than an infinity.
constexpr float kTiny = 1.0e-4f;   // literal: division guard, not a game constant

}  // namespace

void WindModel::Arm(const WeatherSpec& weather, Rng& rng) noexcept
{
    if (!weather.hasGusts)
    {
        armed_ = false;
        untilNext_ = 0.0f;
        return;
    }
    armed_ = true;
    untilNext_ = rng.RangeFloat(weather.gustEverySecondsMin, weather.gustEverySecondsMax);
    // Which quarter this one will come out of. Drawn when the gust is armed rather than when it
    // arrives, so it is part of the same deterministic stream as its timing and a replay puts the
    // same gust on the same side of the same man.
    gustSwingDeg_ = rng.RangeFloat(-kGustSpread, kGustSpread);
}

void WindModel::Begin(const WeatherSpec& weather, Rng& rng, const Tuning& t) noexcept
{
    (void)t;
    phase_ = GustPhase::Calm;
    strength_ = 0.0f;
    inPhase_ = 0.0f;
    Arm(weather, rng);
}

void WindModel::Step(float dt, const WeatherSpec& weather, Rng& rng, const Tuning& t) noexcept
{
    const float tell = t.GetF("gustPreRollSeconds");
    // The gust itself is the same length as its warning, and then the same again easing off. Not a
    // tuned value of its own because nothing in the design asks for one, and a third knob here
    // would be a third thing to get wrong.
    const float blow = tell;

    inPhase_ += dt;
    elapsed_ += dt;

    switch (phase_)
    {
    case GustPhase::Calm:
        strength_ = 0.0f;
        if (!armed_)
        {
            return;   // a sheltered level: no gusts, ever
        }
        untilNext_ -= dt;
        if (untilNext_ <= 0.0f)
        {
            phase_ = GustPhase::Building;
            inPhase_ = 0.0f;
        }
        return;

    case GustPhase::Building:
        // **Zero strength through the whole tell.** The warning has to precede the consequence or
        // it is not a warning; this is the one line that makes being blown off a fair failure
        // rather than a bug, per the fairness table.
        strength_ = 0.0f;
        if (inPhase_ >= tell)
        {
            phase_ = GustPhase::Blowing;
            inPhase_ = 0.0f;
            // Set here rather than left for the next step. Otherwise there is one step that reports
            // Blowing with zero strength — a frame in which the gust has neither warned nor
            // arrived, which is invisible in play and makes any caller asking "did a tell precede
            // this?" see the answer flicker.
            strength_ = 1.0f;
        }
        return;

    case GustPhase::Blowing:
        strength_ = 1.0f;
        if (inPhase_ >= blow)
        {
            phase_ = GustPhase::Easing;
            inPhase_ = 0.0f;
        }
        return;

    case GustPhase::Easing:
        strength_ = std::clamp(1.0f - (inPhase_ / std::max(blow, kTiny)), 0.0f, 1.0f);
        if (inPhase_ >= blow)
        {
            phase_ = GustPhase::Calm;
            inPhase_ = 0.0f;
            strength_ = 0.0f;
            // Timed only when the last one has finished, so a long gust never overlaps the next and
            // the interval in the level file means what a designer would expect: the gap between
            // gusts, not the gap between their starts.
            Arm(weather, rng);
        }
        return;
    }
}

float WindModel::TellProgress(const Tuning& t) const noexcept
{
    if (phase_ != GustPhase::Building)
    {
        return 0.0f;
    }
    const float tell = t.GetF("gustPreRollSeconds");
    return std::clamp(inPhase_ / std::max(tell, kTiny), 0.0f, 1.0f);
}

float WindModel::SpeedAt(float height, const WeatherSpec& weather, const Tuning& t) const noexcept
{
    // A gust is a multiple of the wind that is already blowing, not a fixed addition. The same
    // gust on a sheltered level and an exposed one should not be the same event.
    const float steady = weather.WindAt(height);
    return steady * (1.0f + strength_ * t.GetF("gustWindMultiplier"));
}

float WindModel::BearingDeg(const WeatherSpec& weather, const Tuning&) const noexcept
{
    // The level's quarter, veered by however long the shift has run, and swung while a gust is on
    // it. The swing fades in and out with the gust's own strength, so the needle moves with the
    // weather rather than snapping to a new bearing the instant one arrives.
    const float veer = weather.windVeerDegPerHour * (elapsed_ / kSecondsPerHour);
    float deg = weather.windBearingDeg + veer + gustSwingDeg_ * Strength();
    deg = std::fmod(deg, kFullTurn);
    return (deg < 0.0f) ? deg + kFullTurn : deg;
}

float WindModel::Trend() const noexcept
{
    switch (phase_)
    {
    case GustPhase::Building:
        return 1.0f;    // it is coming, and this is the second and a bit you have to notice
    case GustPhase::Blowing:
        return 1.0f;
    case GustPhase::Easing:
        return -1.0f;
    default:
        return 0.0f;
    }
}

namespace {

float StanceShare(Stance stance, const Tuning& t) noexcept
{
    switch (stance)
    {
        case Stance::HookedLeg: return t.GetF("windPushHookedLegMultiplier");
        case Stance::Clipped:   return t.GetF("windPushClippedMultiplier");
        case Stance::Belted:    return t.GetF("windPushBeltedMultiplier");
        case Stance::Chair:     return t.GetF("windPushChairMultiplier");
        case Stance::OneHand:
        default:                return t.GetF("windPushOneHandMultiplier");
    }
}

}  // namespace

float SidePushMetresPerSecond(float speedAtHeight, float relativeBearingDeg, Stance stance,
                              const Tuning& t) noexcept
{
    const float calm = t.GetF("windPushCalmMetresPerSecond");
    const float over = speedAtHeight - calm;
    if (over <= 0.0f)
    {
        return 0.0f;
    }
    const float reference = t.GetF("windPushReferenceExcessMetresPerSecond");
    if (reference <= 0.0f)
    {
        return 0.0f;
    }
    // Squared, like drag, and scaled so that a wind `reference` above calm and dead abeam pushes a
    // one-handed man at exactly `windPushMetresPerSecondAbeam`. That keeps the tuning readable:
    // one number is the whole feel of it at the speed the trade calls a working limit.
    const float strength = t.GetF("windPushMetresPerSecondAbeam") * (over * over)
                           / (reference * reference);
    // Capped, and the cap is a fairness rule rather than a taste one. Squared growth means that by
    // 25 m/s the raw figure is four times what a man can pull back against, and a drift the
    // correction rate cannot beat is not a difficulty — it is a cutscene with a controller
    // attached. Above the cap the wind stops getting stronger and starts being the reason the
    // trade says no fixing work should be in progress at all.
    const float capped = std::min(strength, t.GetF("windPushMaxMetresPerSecond"));
    const float across = std::sin(relativeBearingDeg * kPi / kHalfTurn);
    return capped * across * StanceShare(stance, t);
}

}  // namespace sj
