#pragma once

// Going up to look at it — the SURVEY archetype.
//
// 05-mission-types.md §A: "Go up, look at it, tell me what's wrong, come down." It is the training
// level's job and, the doc adds, "an excellent low-stress replayable side job".
//
// It has also never existed. Three levels ship with `mission.defects` authored — a cracked course,
// a perished band, a jackdaw's nest, a missing clip, each with the way it is meant to be found —
// and nothing in the game has ever read them, so a SURVEY job has been "climb to the top" with a
// briefing that promised something else. Hollin Bank asks you to go over a chimney and say what is
// holding it together, and the job was to touch the cap.
//
// ## Four ways to find a thing
//
// The discovery method is the archetype's whole texture, and all four already exist as things the
// player does:
//
//   VISUAL    you have to look at it from close enough to see it
//   TAP       you have to sound the joint — the note tells you, the eye cannot
//   SUMMIT    only findable from the top, which is what makes the climb the job
//   TRAVERSE  on the far side, so you have to work round the shaft to meet it
//
// ## And the honest part
//
// A defect you did not find is not a failure, it is a worse report — the fee is for the survey,
// and what a thin survey costs you is what anyone will let you do next. That is the same shape as
// every other consequence in this game, and it is why `Judge` returns a fraction rather than a
// pass.

#include "Export.h"

#include <cstdint>
#include <string>
#include <vector>

namespace sj {

class Tuning;

enum class FindBy : uint8_t { Visual, Tap, Summit, Traverse };

struct Defect
{
    std::string id;
    float       height{};
    int32_t     bearing{};
    FindBy      how{FindBy::Visual};
    bool        found{};
};

struct SurveyReport
{
    int32_t total{};
    int32_t found{};
    float   share{};       // 0..1, what fraction of what was there you came back with
    bool    complete{};
};

class SJ_API Survey
{
public:
    void Begin(const std::vector<Defect>& defects);

    // Is there anything here to be found? `height` and `bearing` are where he is, `atTop` whether
    // he is standing on the cap, `sounded` whether he has just tapped the joint in front of him.
    // Returns the index of what he has just found, or -1.
    int32_t Look(float height, int32_t bearing, bool atTop, bool sounded, const Tuning& t);

    const std::vector<Defect>& Defects() const noexcept { return defects_; }
    SurveyReport Report() const noexcept;

private:
    std::vector<Defect> defects_;
};

// The word a level file uses for a discovery method.
SJ_API FindBy FindByName(const std::string& name) noexcept;

}  // namespace sj
