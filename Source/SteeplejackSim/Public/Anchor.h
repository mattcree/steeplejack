#pragma once

// What a driven dog is worth — VERB-004, and the span economy it feeds.
//
// An anchor's rating is the whole risk model of the ascent in one number: how good the joint was,
// how deep the dog went, and how much brick you split getting it there. Everything above you on
// the stack is hanging off decisions you made about anchors below.

#include "Export.h"
#include "Types.h"

#include <vector>

namespace sj {

class LevelData;
class Rng;
class Tuning;
struct BandSpec;

// A dog a previous jack left in the wall — LVL-000's old-fixtures band.
//
// It is free: lash to it and skip the hammer work. What it will hold is its joint, less its rust,
// and the rust is the part nobody can tap for. So the band is speed for uncertainty, which is the
// design doc's phrase and the only reason the band exists: if taking one were obviously right or
// obviously foolish, it would not be a gamble, it would be a tax.
//
// The rust is visible at close range — that is the fixture's telegraph, and the fairness table
// requires one — so it is exposed to the renderer. The rating is not: an unrated fixture is shown as
// unrated, never mislabelled.
struct FixtureSpec
{
    float height{};
    float rust{};   // 0-1, taken off the rating the way spall is
};

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

// The old fixtures in a level: every band's, at its spacing, each with its rust. Deterministic from
// the level's own seed, on a fork of its own, so adding anything else random cannot move one.
SJ_API std::vector<FixtureSpec> OldFixtures(const LevelData& level, const Rng& parent,
                                            const Tuning& t);

}  // namespace anchor
}  // namespace sj
