#pragma once

// The joint grid — STRUCT-002. The gameplay surface of every structure in the game.
//
// Everything the player reads, taps and hammers comes from here. Before it existed, a joint was
// derived from a hash of the height alone: one joint per centimetre of height, its quality drawn
// uniformly from a fixed range, the level's band **ignored entirely**. So the Grey Box's perished
// band played exactly like its plain one, the level design did nothing, and there was never a
// choice about *where* to drive a dog — you tapped where you stood, and that was the joint.
//
// ## What a grid is
//
// Candidate mortar joints on the face of the stack, in rows up its height and around its
// circumference, spaced so there is one per `1 / candidateDensity` m² — four per square metre, so
// half a metre apart. Alternate rows are offset by half a step, because that is what bonded
// brickwork does and because a square grid reads as a spreadsheet.
//
// Each joint has a hidden `quality` and the tier it implies, drawn from **its band's authored
// distribution**. The draw is stratified, not independent: each band gets exactly the counts its
// proportions ask for, then those are shuffled into place. Independent draws over a few hundred
// joints miss a 5% tier by a third either way, and a designer who writes `cracked: 0.02` means two
// in a hundred, not "somewhere between none and five".
//
// ## The tell
//
// Each joint also has an **apparent quality** — what it looks like. It is the true quality plus a
// fixed, per-joint error sized so that a player can narrow a joint to about two tiers by looking
// and only the tap test settles it (02-climbing-system.md §1). It is deterministic: looking again is
// not a reroll. A band's `visualReadReliability` scales how much of the truth survives into the
// look — the Grey Box's salt-bloom band sets it to zero, so there the look tells you nothing and the
// tap is the only instrument.
//
// It lives here and not in the renderer because it decides what information the player had, and
// the fairness contract (10-failure-and-difficulty.md) is written in exactly those terms.
//
// ## Coordinates
//
// Y up, matching the engine: bearing is degrees clockwise from north, north is -Z, east is +X, so a
// joint at bearing θ sits at (r·sin θ, h, −r·cos θ). West, 270°, is −X.

#include "Export.h"
#include "Types.h"

#include <cstdint>
#include <vector>

namespace sj {

class LevelData;
class Rng;
class Tuning;

class SJ_API JointGrid
{
public:
    // Build the grid for a level. Draws only from a fork of `parent`, never from `parent` itself,
    // so adding a random call anywhere else in the sim cannot move a single joint (acceptance 6).
    //
    // `climbBearingDeg` is where the ladder goes up. Authored joints — `forceCrackedAt` and
    // friends — are placed on that line, because the only reason to author a joint is to put it
    // where the player is certain to meet it.
    static JointGrid Generate(const LevelData& level, const Rng& parent, const Tuning& t,
                              float climbBearingDeg);

    int32_t Count() const noexcept { return static_cast<int32_t>(joints_.size()); }

    // The joint with this id, or a null-object Joint (id -1, tier Cracked, quality 0) if there is
    // no such joint. Never throws, never returns a reference to nothing.
    const Joint& ById(int32_t id) const noexcept;

    // What the joint looks like, 0-1, on the same scale as `quality`. The tell.
    float Apparent(int32_t id) const noexcept;

    // Every joint within `range` metres of the point on the face at this height and bearing, in no
    // particular order. What a renderer draws and what targeting chooses from.
    std::vector<int32_t> Near(float height, float bearingDeg, float range) const;

    // The nearest joint to `pos` within `maxRange`, or -1. Occupied joints are skipped: you cannot
    // drive a second dog into a joint that already has one.
    int32_t Nearest(const Vec3& pos, float maxRange) const noexcept;

    void SetOccupied(int32_t id, bool occupied) noexcept;

    // The row spacing and the joint spacing along a row, in metres. For a renderer that wants its
    // brick to line up with the joints it is drawing.
    float RowSpacing() const noexcept { return rowSpacing_; }

private:
    std::vector<Joint>   joints_;
    std::vector<float>   apparent_;
    // Index of the first joint in each row, plus one past the end. Rows are generated bottom to
    // top, so a height range is a contiguous range of rows and `Near` does not scan the stack.
    std::vector<int32_t> rowStart_;
    std::vector<float>   rowHeight_;
    float                rowSpacing_{};
};

}  // namespace sj
