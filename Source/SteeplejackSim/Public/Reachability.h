#pragma once

// Can this level be climbed at all? — CORE-009.
//
// Authoring an unwinnable level is easy, and the failure is invisible until someone has played it
// for twenty minutes. This proves, headlessly and in milliseconds, that the top can be reached with
// the ladders the job comes with, at spans no worse than a limit — or says where it cannot.
//
// Existence, not a recommendation: the player finds their own route. The search is greedy — from
// each dog, the highest usable joint in reach — which is optimal for existence here, because a
// higher dog never loses an option a lower one had: its next window reaches at least as high.
//
// The geometry is the game's: the first ladder stands on the ground; each lashed section rises
// `ladderLength − ladderMinOverlap` above its dog; the climber stands at most at the ladder's top,
// shoulders `climberShoulderAboveFeetMetres` above the rungs and `climberWallStandoffMetres` off
// the wall, and works any joint within `tapTestMaxRangeMetres` of them. Cracked joints are
// unusable (a dog in one rates Failed), and so are joints under the ladder's own stiles.

#include "Export.h"

#include <cstdint>
#include <vector>

namespace sj {

class JointGrid;
class Tuning;

struct Route
{
    std::vector<int32_t> anchors;   // joint ids, bottom to top
    int32_t sections{};             // lashed sections used, not counting the standing ladder
    float   maxSpan{};              // the longest span on the route
    bool    valid{};                // the top is reached
    float   reached{};              // how high the ladder got — where it stopped, when not valid
};

// `ladders` is the sections available to lash; the standing ladder is extra. `topM` is the height
// the ladder must reach; `bearingDeg` is the climbing line.
SJ_API Route Solve(const JointGrid& grid, int32_t ladders, float maxSpan, float topM,
                   float bearingDeg, const Tuning& t);

}  // namespace sj
