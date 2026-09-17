// Dogging in — VERB-003. See Verbs/Hammer.h.
//
// The formulae are the GDD's, transcribed:
//
//   strikeQuality = clamp(1 - angleError/MAX_ANGLE, 0, 1)
//   depthGain     = power * strikeQuality * jointSoftness
//   bendRisk      = power * (1 - strikeQuality)
//   spallRisk     = power * (1 - jointQuality) * depth
//
// The three outcomes the player is meant to learn to feel fall out of them rather than being
// special-cased:
//
//   soft mortar takes a dog fast and holds it badly — the trap
//   sound mortar resists, needing five or six solid strikes, and rewards you with a Sound anchor
//   a full-power swing at a poor angle bends the dog, which costs material, time and nerve

#include "Verbs/Hammer.h"

#include "Tuning.h"

#include <algorithm>

namespace sj {
namespace hammer {

float SeatDepth(const Tuning& t) noexcept
{
    return t.GetF("dogSeatDepthFraction");
}

float StrikeQuality(float angleErrorDeg, const Tuning& t) noexcept
{
    const float maxError = t.GetF("hammerMaxAngleErrorDegrees");
    if (maxError <= 0.0f)
    {
        return 0.0f;
    }
    return std::clamp(1.0f - (std::abs(angleErrorDeg) / maxError), 0.0f, 1.0f);
}

StrikeResult Strike(const Joint& joint, float currentDepth, float power, float angleErrorDeg,
                    float toolCondition, const Tuning& t) noexcept
{
    StrikeResult out{};

    power = std::clamp(power, 0.0f, 1.0f);
    currentDepth = std::clamp(currentDepth, 0.0f, 1.0f);
    toolCondition = std::clamp(toolCondition, 0.0f, 1.0f);

    const float quality = StrikeQuality(angleErrorDeg, t);

    // Soft mortar takes the dog faster. `quality` here is the joint's hidden condition: 1 is sound
    // brickwork that resists, 0 is perished mortar you could push a dog into with your thumb.
    const float softness = std::clamp(1.0f - joint.quality, 0.0f, 1.0f);

    // A worn hammer does not swing straight. It scales the *good* part of the strike without
    // reducing the risk, which is what makes tool condition worth paying to repair.
    const float tool = 0.5f + 0.5f * toolCondition;   // literal: a dead tool is half as effective

    out.depthGain = power * quality * softness * tool;

    // A hard swing at a bad angle bends the dog. Note it is the product: a gentle bad-angle tap is
    // survivable, and a full-power clean strike is safe. That relationship is the skill.
    const float bendRisk = power * (1.0f - quality) * t.GetF("hammerBendRiskScale");
    out.bent = bendRisk > 0.5f;   // literal: half the available risk, a coin-flip swing

    // Over-driving a weak joint splits the brick. Rises with depth, so the last strikes on a
    // perished joint are the dangerous ones — which is when the player most wants to finish.
    out.spalled = power * (1.0f - joint.quality) * currentDepth *
                  t.GetF("hammerSpallRiskScale");

    if (out.bent)
    {
        out.depthGain = 0.0f;   // a bent dog goes nowhere
        return out;
    }

    out.seated = (currentDepth + out.depthGain) >= SeatDepth(t);
    return out;
}

}  // namespace hammer
}  // namespace sj
