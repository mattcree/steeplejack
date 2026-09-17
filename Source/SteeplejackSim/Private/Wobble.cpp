// Wobble — METER-003. See Wobble.h for why there is exactly one of these.

#include "Wobble.h"

#include "Meters.h"
#include "Tuning.h"

#include <algorithm>

namespace sj {
namespace {

const char* StanceKey(Stance s) noexcept
{
    switch (s)
    {
    case Stance::OneHand:   return "stanceWobbleMultiplier.oneHand";
    case Stance::HookedLeg: return "stanceWobbleMultiplier.hookedLeg";
    case Stance::Clipped:   return "stanceWobbleMultiplier.clipped";
    case Stance::Belted:    return "stanceWobbleMultiplier.belted";
    case Stance::Chair:     return "stanceWobbleMultiplier.chair";
    }
    return "stanceWobbleMultiplier.oneHand";
}

const char* NerveKey(int32_t band) noexcept
{
    // Three multipliers for four bands: the worst band shares the "bad" figure. Reading it off the
    // data rather than inventing a fourth value keeps the tuning file the single source.
    switch (band)
    {
    case 0:  return "nerveWobbleMultiplier.calm";
    case 1:  return "nerveWobbleMultiplier.uneasy";
    default: return "nerveWobbleMultiplier.bad";
    }
}

}  // namespace

float WobbleAmplitudeDeg(const Meters& m, const MeterContext& ctx, float gust,
                         const Tuning& t) noexcept
{
    float degrees = t.GetF("baseWobbleDegrees");

    // Your posture. A belt round the stack is the baseline 1.0; one hand on a rung is the worst.
    degrees *= t.GetF(StanceKey(m.stance));

    // Fear. Steps up in bands rather than sliding, so the player can feel the threshold cross.
    degrees *= t.GetF(NerveKey(nerve::Band(m.nerve, t)));

    // Tiredness. Below the tremor threshold the hands start to shake, ramping to gripWobbleAtZero
    // as grip runs out — so the warning is not just a HUD flag, it is felt in the aim.
    const float threshold = t.GetF("gripTremorThreshold");
    if (threshold > 0.0f && m.grip < threshold)
    {
        const float into = std::clamp(1.0f - (m.grip / threshold), 0.0f, 1.0f);
        const float atZero = t.GetF("gripWobbleAtZero");
        degrees *= 1.0f + into * (atZero - 1.0f);
    }

    // Wind. Added rather than multiplied: a gust shoves you, it does not scale your nerves.
    degrees += std::clamp(gust, 0.0f, 1.0f) * t.GetF("gustWobbleDegrees");

    // Carrying a ladder one-handed is not a steady way to aim at anything.
    if (ctx.carryingLadder)
    {
        degrees *= t.GetF("gripModifiers.carryingLadder");
    }

    return std::max(degrees, 0.0f);
}

}  // namespace sj
