// Reachability — CORE-009. See Reachability.h.

#include "Reachability.h"

#include "JointGrid.h"
#include "Tuning.h"
#include "Types.h"
#include "Verbs/Tap.h"

#include <algorithm>
#include <cmath>

namespace sj {
namespace {

// Round the face from the climbing line, in metres: the chord between the joint's normal and the
// ladder's, times the radius — face.gd's under_ladder, so the two agree on what the stiles hide.
float OffLine(const Joint& j, float bearingDeg) noexcept
{
    const float r = std::sqrt(j.pos.x * j.pos.x + j.pos.z * j.pos.z);
    if (r <= 0.0f)
    {
        return 0.0f;
    }
    const float b = bearingDeg * 0.017453292f;   // literal: degrees to radians
    const float dx = j.pos.x / r - std::sin(b);
    const float dz = j.pos.z / r + std::cos(b);
    return std::sqrt(dx * dx + dz * dz) * r;
}

}  // namespace

Route Solve(const JointGrid& grid, int32_t ladders, float maxSpan, float topM, float bearingDeg,
            const Tuning& t)
{
    const float length = t.GetF("ladderLengthMetres");
    const float rise = length - t.GetF("ladderMinOverlapMetres");
    const float shoulder = t.GetF("climberShoulderAboveFeetMetres");
    const float standoff = t.GetF("climberWallStandoffMetres");
    const float range = t.GetF("tapTestMaxRangeMetres");
    const float covered = t.GetF("ladderCoversMetres");
    // Reach measured along the wall from the point level with his shoulders: the rest of the
    // hand-to-joint distance is the gap between him and the brick.
    const float onWall = std::sqrt(std::max(0.0f, range * range - standoff * standoff));
    const float step = std::max(grid.RowSpacing(), 0.05f);   // literal: floor for a degenerate grid

    Route route;
    float dog = 0.0f;         // the ground is anchor zero
    float top = length;       // the standing ladder
    route.reached = top;
    while (top < topM)
    {
        if (route.sections >= ladders)
        {
            return route;     // out of ladders
        }
        const float ceiling = dog + maxSpan;
        int32_t best = -1;
        float best_h = dog;
        // Every stance on the section he is on, from its top down: a joint the span allows may only
        // be reachable standing lower.
        for (float feet = top; feet >= dog - step; feet -= step)
        {
            const float hands = feet + shoulder;
            for (int32_t id : grid.Near(hands, bearingDeg, onWall))
            {
                const Joint& j = grid.ById(id);
                if (j.height <= best_h || j.height > ceiling)
                {
                    continue;
                }
                if (tap::TierOf(j.quality, t) == JointTier::Cracked || OffLine(j, bearingDeg) < covered)
                {
                    continue;
                }
                best = id;
                best_h = j.height;
            }
        }
        if (best < 0)
        {
            return route;     // nothing usable in reach: stuck at `top`
        }
        route.maxSpan = std::max(route.maxSpan, best_h - dog);
        route.anchors.push_back(best);
        route.sections += 1;
        dog = best_h;
        top = dog + rise;
        route.reached = top;
    }
    route.valid = true;
    return route;
}

}  // namespace sj
