// Lashing — VERB-005. See Lash.h for where the skill lives and why.

#include "Verbs/Lash.h"

#include "Tuning.h"

#include <algorithm>
#include <cmath>

namespace sj::lash {

float LayRate(float rotationRate, const Tuning& t) noexcept
{
    const float per_wrap = t.GetF("lashSecondsPerWrapIdeal");
    if (per_wrap <= 0.0f || rotationRate <= 0.0f)
    {
        return 0.0f;
    }
    const float ideal = 1.0f / per_wrap;   // turns a second that lays one wrap per turn
    // Saturating. k makes a steady turn at the ideal rate lay exactly the ideal, so acceptance 1 is
    // arithmetic rather than a coincidence of tuning; the tanh is what makes rope ride up when you
    // spin it, and so what makes jerky input slow without anything having to detect jerkiness.
    const float k = 1.0f / std::tanh(1.0f);
    return ideal * k * std::tanh(rotationRate / ideal);
}

void Step(LashState& s, float dt, float rotationRate, const Tuning& t) noexcept
{
    if (s.tied)
    {
        return;   // a tied knot is finished; turning the stick further does nothing to it
    }

    const float rate = std::max(rotationRate, 0.0f);
    const float per_wrap = t.GetF("lashSecondsPerWrapIdeal");
    const float ideal = (per_wrap > 0.0f) ? 1.0f / per_wrap : 1.0f;

    // Tension: rises towards how hard you are working the rope, bleeds away the moment you stop.
    if (rate > 0.0f)
    {
        const float target = std::min(rate / ideal, 1.0f);
        const float rise = t.GetF("lashTensionRisePerSecond");
        s.tension += (target - s.tension) * std::min(rise * dt, 1.0f);
    }
    else
    {
        s.tension -= t.GetF("lashTensionDecayPerSecond") * dt;
    }
    s.tension = std::clamp(s.tension, 0.0f, 1.0f);

    s.laid += LayRate(rate, t) * dt;
    while (s.laid >= 1.0f)
    {
        s.laid -= 1.0f;
        ++s.wraps;
    }
}

Lashing TieOff(LashState& s, const Tuning& t) noexcept
{
    s.tied = true;
    const int32_t hitch = t.GetI("lashWrapsQuickHitch");
    const int32_t full = t.GetI("lashWrapsFull");

    if (s.wraps < hitch)
    {
        // Acceptance 4. Two turns round a stile is not a lashing, and the game says so rather than
        // letting the player find out forty metres up.
        s.slipping = true;
        return Lashing::None;
    }
    // Tied off slack: the knot holds for now and walks. That is the "mistiming" the verb spec means,
    // and it is recoverable — visible, and fixable by re-tying — rather than a hidden failure.
    s.slipping = s.tension < t.GetF("lashTieOffMinTension");
    return (s.wraps >= full) ? Lashing::Full : Lashing::Hitch;
}

float RateFromMash(float pressesPerSecond, const Tuning& t) noexcept
{
    return std::max(pressesPerSecond, 0.0f) * t.GetF("lashMashTurnsPerPress");
}

float RateFromHold(const Tuning& t) noexcept
{
    return t.GetF("lashHoldTurnsPerSecond");
}

float DriftPerMinuteCm(Lashing l, const Tuning& t) noexcept
{
    switch (l)
    {
    case Lashing::Hitch: return t.GetF("lashHitchDriftCmPerMinute");
    case Lashing::Full:  return 0.0f;
    case Lashing::None:  return 0.0f;   // not holding anything, so nothing to drift
    }
    return 0.0f;
}

}  // namespace sj::lash
