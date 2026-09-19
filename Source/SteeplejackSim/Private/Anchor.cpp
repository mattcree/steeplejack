// Anchor rating and the span economy — VERB-004. See Anchor.h.

#include "Anchor.h"

#include "Level.h"
#include "Rng.h"

#include "Tuning.h"
#include "Verbs/Tap.h"

#include <algorithm>

namespace sj {
namespace anchor {

AnchorRate Rate(const Joint& joint, float depth, float spall, const Tuning& t) noexcept
{
    // A cracked joint holds nothing, at any depth (acceptance 2). This is checked on the joint
    // itself, before anything else: the depth bonus below used to lift a cracked joint's score
    // into the perished band, so a dog in a crack rated Poor and held a kilonewton it should never
    // have held — a failure with no honest telegraph, because the pip said Poor.
    if (tap::TierOf(std::clamp(joint.quality, 0.0f, 1.0f), t) == JointTier::Cracked)
    {
        return AnchorRate::Failed;
    }

    // Start from the joint, then take away what you damaged getting in. This is why soft mortar is
    // a trap: it seats fast, and the spalling you caused on the way is exactly what downgrades it.
    const float seat = t.GetF("dogSeatDepthFraction");
    float score = std::clamp(joint.quality, 0.0f, 1.0f) - std::clamp(spall, 0.0f, 1.0f);

    // Depth past the minimum is worth something, but cannot rescue a bad joint.
    if (depth >= seat)
    {
        score += (depth - seat) * 0.5f;   // literal: half weight, not tuned
    }

    AnchorRate rate = AnchorRate::Failed;
    switch (tap::TierOf(std::clamp(score, 0.0f, 1.0f), t))
    {
    case JointTier::Sound:    rate = AnchorRate::Sound; break;
    case JointTier::Fair:     rate = AnchorRate::Fair; break;
    case JointTier::Perished: rate = AnchorRate::Poor; break;
    case JointTier::Cracked:  rate = AnchorRate::Failed; break;
    }

    // Not driven home: one tier below what the joint would allow (acceptance 3). The game only
    // rates a dog once it is seated, so this is the contract for anything else that asks.
    if (depth < seat && rate != AnchorRate::Failed)
    {
        rate = static_cast<AnchorRate>(static_cast<int>(rate) - 1);
    }
    return rate;
}

float CapacityKN(AnchorRate rate, const Tuning& t) noexcept
{
    switch (rate)
    {
    case AnchorRate::Sound:  return t.GetF("anchorCapacityKN.sound");
    case AnchorRate::Fair:   return t.GetF("anchorCapacityKN.fair");
    case AnchorRate::Poor:   return t.GetF("anchorCapacityKN.poor");
    case AnchorRate::Failed: return t.GetF("anchorCapacityKN.failed");
    }
    return 0.0f;
}

Anchor Make(const Joint& joint, float depth, float spall, const Tuning& t) noexcept
{
    Anchor a{};
    a.jointId = joint.id;
    a.height = joint.height;
    a.depth = depth;
    a.spall = spall;
    a.rate = Rate(joint, depth, spall, t);
    a.capacityKN = CapacityKN(a.rate, t);
    return a;
}

SpanBand ClassifySpan(float spanMetres, const Tuning& t) noexcept
{
    if (spanMetres <= t.GetF("spanSoftMetres"))
    {
        return SpanBand::Rigid;
    }
    if (spanMetres <= t.GetF("spanWarnMetres"))
    {
        return SpanBand::Flex;
    }
    if (spanMetres <= t.GetF("spanDangerMetres"))
    {
        return SpanBand::Sway;
    }
    return SpanBand::Buckle;
}

float GripDrainMultiplier(SpanBand band, const Tuning& t) noexcept
{
    return band >= SpanBand::Flex ? t.GetF("spanWarnGripDrainMultiplier") : 1.0f;
}

float NerveDrainMultiplier(SpanBand band, const Tuning& t) noexcept
{
    return band >= SpanBand::Sway ? t.GetF("spanDangerNerveMultiplier") : 1.0f;
}

float DynamicLoadMultiplier(SpanBand band, const Tuning& t) noexcept
{
    return band >= SpanBand::Sway ? t.GetF("spanDangerDynamicLoadMultiplier") : 1.0f;
}


std::vector<FixtureSpec> OldFixtures(const LevelData& level, const Rng& parent, const Tuning& t)
{
    std::vector<FixtureSpec> out;
    Rng rng = parent.Fork(0x46495854u);   // literal: 'FIXT', the fixtures' own stream
    const float lo = t.GetF("fixtureRustMin");
    const float hi = t.GetF("fixtureRustMax");
    for (const BandSpec& band : level.Bands())
    {
        if (band.fixtureCount <= 0 || band.fixtureSpacingMetres <= 0.0f)
        {
            continue;
        }
        // Up the band from a little above its floor, at the spacing the previous jack used — which
        // is the line his ladder went up, and so the line this one goes up too.
        const float first = band.from + band.fixtureSpacingMetres * 0.5f;
        for (int32_t k = 0; k < band.fixtureCount; ++k)
        {
            const float h = first + band.fixtureSpacingMetres * static_cast<float>(k);
            if (h >= band.to)
            {
                break;
            }
            out.push_back(FixtureSpec{h, rng.RangeFloat(lo, hi)});
        }
    }
    return out;
}

}  // namespace anchor
}  // namespace sj
