#pragma once

// Reading the brickwork — VERB-001.
//
// You tap a mortar joint with the hammer and listen. A ring means sound; a dull thud means
// perished; a rattle means cracked. It is the only way to know what you are about to trust your
// weight to, and it costs time and grip to find out — which is the decision.
//
// The result carries a **shape** index as well as a sound, never a colour. Rule 8: every audio cue
// has a visual fallback, and that fallback must not rely on hue.

#include "Export.h"
#include "Types.h"

#include <string_view>

namespace sj {

class Tuning;

struct TapResult
{
    JointTier        tier{};
    float            confidence{};   // 0-1. Gloves cost you a tier of resolution.
    std::string_view soundId;
    int32_t          pipShape{};     // index, not a colour
};

namespace tap {

// What the joint sounds like. Deterministic: the same joint always reads the same, so a player can
// re-tap to confirm rather than reroll.
SJ_API TapResult Tap(const Joint& joint, const Tuning& t, bool wearingGloves) noexcept;

// The tier a quality value really is, before any reading error.
SJ_API JointTier TierOf(float quality, const Tuning& t) noexcept;

}  // namespace tap
}  // namespace sj
