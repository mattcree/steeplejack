// Wind and the gust that warns you — ENV-003. See Wind.h for why the tell is the feature.

#include "Wind.h"

#include "Level.h"
#include "Rng.h"
#include "Tuning.h"

#include <algorithm>

namespace sj {
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

}  // namespace sj
