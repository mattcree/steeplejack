#pragma once

// What a driven dog is worth — VERB-004, and the span economy it feeds.
//
// An anchor's rating is the whole risk model of the ascent in one number: how good the joint was,
// how deep the dog went, and how much brick you split getting it there. Everything above you on
// the stack is hanging off decisions you made about anchors below.

#include "Export.h"
#include "Types.h"

namespace sj {

class Tuning;
struct BandSpec;

namespace anchor {

SJ_API AnchorRate Rate(const Joint& joint, float depth, float spall, const Tuning& t) noexcept;
SJ_API float      CapacityKN(AnchorRate rate, const Tuning& t) noexcept;
SJ_API Anchor     Make(const Joint& joint, float depth, float spall, const Tuning& t) noexcept;

// Where a span sits in the risk table. This is the entire risk/reward economy of the ascent:
// longer spans mean fewer anchors, which is faster and cheaper, right up until the ladder bows.
//
//   <= spanSoftMetres    Rigid   no penalty
//   <= spanWarnMetres    Flex    visible bounce, grip drain up
//   <= spanDangerMetres  Sway    heavy sway, nerve doubled, anchors see more dynamic load
//   >  spanDangerMetres  Buckle  the section bows and fails within buckleSecondsUnderLoad
SJ_API SpanBand ClassifySpan(float spanMetres, const Tuning& t) noexcept;

// What that span does to you while you climb it.
SJ_API float GripDrainMultiplier(SpanBand band, const Tuning& t) noexcept;
SJ_API float NerveDrainMultiplier(SpanBand band, const Tuning& t) noexcept;
SJ_API float DynamicLoadMultiplier(SpanBand band, const Tuning& t) noexcept;

}  // namespace anchor
}  // namespace sj
