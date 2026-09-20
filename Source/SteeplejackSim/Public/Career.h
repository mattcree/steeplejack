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

    // The stars you would have if you gained `extraPoints` more. Used to answer a question the
    // game has to be able to answer honestly while it is half built: **is this gate unreachable
    // because I have not earned it, or because the jobs that would earn it do not exist yet?**
    //
    // Twelve levels were designed and five have data. Doing all five perfectly comes to two stars,
    // and every felling in the game is gated at three or more — so a gate enforced without this
    // distinction locks the player out of half the game and looks exactly like a bug. A gate above
    // what the built content can reach is not a gate, it is a gap, and the board says so and lets
    // you through. It starts enforcing itself the moment the levels between exist.
    int32_t StarsAfter(int32_t extraPoints, const Tuning& t) const noexcept;

    // Settle a felling. Does not itself decide whether the job happened — the caller has run it.
    Settlement Settle(const std::string& levelId, float feeGbp, const FellOutcome& outcome,
                      const Tuning& t);

    // Settle the other half of the game: a job you finished by getting to the top of it. No
    // bonuses and no damages, because a survey has nothing to hit — the fee, and your name moves
    // the same way a completed felling moves it. `reachedTop` false is an abandoned job, which
    // costs you rather than paying you, because the client is still looking at their chimney.
    Settlement SettleClimb(const std::string& levelId, float feeGbp, bool reachedTop,
                           const Tuning& t);

    // You were inside the line when it went, or you came off a ladder. Separate from settling a
    // job because being hurt is not a grade — it happens to a job that otherwise went perfectly,
    // and it is the one thing in here that has nothing to do with how well you did the work.
    int32_t Injured(const Tuning& t);

    // Round trip, as JSON, because everything this project persists is text somebody can read.
    std::string ToJson() const;
    static Career FromJson(const std::string& json, const std::string& origin);

private:
    float   money_{};
    int32_t reputation_{};
    std::vector<JobRecord> jobs_;
};

}  // namespace sj
