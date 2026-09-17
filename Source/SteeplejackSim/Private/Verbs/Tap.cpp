// The tap test — VERB-001. See Verbs/Tap.h.

#include "Verbs/Tap.h"

#include "Tuning.h"

#include <algorithm>

namespace sj {
namespace tap {

JointTier TierOf(float quality, const Tuning& t) noexcept
{
    // Bounds from jointQualityTierBounds. Read as upper bounds, worst first, so adding a tier is a
    // row in the JSON rather than a rewrite here.
    if (quality < t.GetF("jointQualityTierBounds.cracked"))
    {
        return JointTier::Cracked;
    }
    if (quality < t.GetF("jointQualityTierBounds.perished"))
    {
        return JointTier::Perished;
    }
    if (quality < t.GetF("jointQualityTierBounds.fair"))
    {
        return JointTier::Fair;
    }
    return JointTier::Sound;
}

TapResult Tap(const Joint& joint, const Tuning& t, bool wearingGloves) noexcept
{
    TapResult out{};
    const JointTier True = TierOf(joint.quality, t);
    out.tier = True;
    out.confidence = 1.0f;

    if (wearingGloves)
    {
        // Gloves cost a tier of resolution — the trade from the grip table, felt here. You read
        // one tier optimistic, which is the dangerous direction: a perished joint reads fair.
        out.confidence = 0.5f;   // literal: one tier of resolution lost, not a tuned value
        // 3 is JointTier::Sound, the top of a fixed four-value enum, not a tunable.
        const int32_t Softened = std::min(static_cast<int32_t>(True) + 1,
                                          static_cast<int32_t>(JointTier::Sound));
        out.tier = static_cast<JointTier>(Softened);
    }

    switch (out.tier)
    {
    case JointTier::Sound:
        out.soundId = "tap_ring";
        out.pipShape = 0;   // a full circle
        break;
    case JointTier::Fair:
        out.soundId = "tap_firm";
        out.pipShape = 1;   // a square
        break;
    case JointTier::Perished:
        out.soundId = "tap_dull";
        out.pipShape = 2;   // a triangle
        break;
    case JointTier::Cracked:
        out.soundId = "tap_rattle";
        out.pipShape = 3;   // literal: shape index for the accessibility pip, a broken cross
        break;
    }
    return out;
}

}  // namespace tap
}  // namespace sj
