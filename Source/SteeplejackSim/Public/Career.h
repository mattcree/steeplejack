#pragma once

// What you have made and what you are trusted with — CAREER-001.
//
// Twelve jobs in a district over a season, and the only two things that carry between them are the
// money in the tin and whether anyone will have you back. Both are here rather than in a script,
// for the same reason every other rule is: whether a job unlocks decides what the player is allowed
// to do, and a decision like that is not presentation.
//
// ## Reputation
//
// A hundred points shown as five stars, on `economy.json`'s own thresholds, and a level's
// `reputationGate` is the number of stars you need before the letter arrives at all.
//
// It is deliberately not symmetric in two ways. **Gains are first-time only**: doing Waterside
// again pays, but it does not make anyone think better of you, so the road to five stars is new
// work rather than a grind. **Losses always apply**: putting a chimney through a chapel costs you
// every time you do it, including the fourth time on the same chapel.
//
// ## The money
//
// The fee plus what the felling earned in bonuses, less what it broke, and never less than nothing
// — a job cannot leave you owing money, because a game that can put you in an unrecoverable hole
// twelve jobs deep is not the game this is. A job you have done before pays `replayFeeFraction`
// of its fee. A catastrophe fails it outright: no fee at all, and the reputation is yours to keep.

#include "Export.h"

#include <cstdint>
#include <string>
#include <vector>

namespace sj {

struct FellOutcome;
class Tuning;

// One job, as the tin remembers it.
struct JobRecord
{
    std::string id;
    float       paidGbp{};
    float       errorDegrees{};
    bool        failed{};
};

// What a job did to you, which is what the board tells you afterwards.
struct Settlement
{
    float   feeGbp{};
    float   bonusGbp{};
    float   damagesGbp{};
    float   paidGbp{};          // what actually went in the tin, never below zero
    int32_t reputationDelta{};
    bool    failed{};
    bool    firstTime{};        // whether the reputation moved at all
};

class SJ_API Career
{
public:
    Career() = default;

    float   MoneyGbp() const noexcept { return money_; }
    int32_t Reputation() const noexcept { return reputation_; }
    // Reputation as the board draws it: how many of `economy.json`'s thresholds you are past.
    int32_t Stars(const Tuning& t) const noexcept;
    const std::vector<JobRecord>& Jobs() const noexcept { return jobs_; }

    // Has this job been done at all, and how well it went the best time.
    bool  Done(const std::string& levelId) const noexcept;
    float BestErrorDegrees(const std::string& levelId) const noexcept;

    // Whether the letter arrives. A gate of 0 always does; the grey box and the back yard are 0.
    bool CanTake(int32_t gateStars, const Tuning& t) const noexcept;

    // Settle a felling. Does not itself decide whether the job happened — the caller has run it.
    Settlement Settle(const std::string& levelId, float feeGbp, const FellOutcome& outcome,
                      const Tuning& t);

    // Round trip, as JSON, because everything this project persists is text somebody can read.
    std::string ToJson() const;
    static Career FromJson(const std::string& json, const std::string& origin);

private:
    float   money_{};
    int32_t reputation_{};
    std::vector<JobRecord> jobs_;
};

}  // namespace sj
