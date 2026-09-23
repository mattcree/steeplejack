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
#include <utility>
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

// A felling's Act 2, which happens on a different day and in the other half of the game: the bands
// come off, the conductor comes down, and the chimney is made ready to be cut. Remembered per job
// because it is work you do once — you do not re-strip a chimney because your first gob went wrong.

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

    // --- the yard -----------------------------------------------------------------------------
    //
    // The day and the engine. Both belong in the tin rather than in a second save file beside it:
    // a split save is the kind of thing that rots the first time one half is written and the other
    // is not, and a career whose money says one thing and whose calendar says another is not
    // recoverable by anybody.

    // --- what you left on the chimney -----------------------------------------------------
    //
    // Dogs you did not draw, remembered per job. Come back to that stack and they are still in it,
    // a season more corroded, and so are the holes. The trade did exactly this — jacks with a
    // standing contract left their dogs in — and the consequence is the one the record actually
    // reports: the next crew "had used the old dog holes and it wandered a bit".
    //
    // It is also the cheapest version of the idea 17-the-long-game.md argues is the most valuable
    // thing in the backlog: the district should remember you.
    const std::vector<float>& LeftIn(const std::string& levelId) const noexcept;
    void RememberLeftIn(const std::string& levelId, const std::vector<float>& heights);

    // --- what you carried home ----------------------------------------------------------------
    //
    // One thing off every job, kept. Not bought — earned by doing, and by choosing to bring it
    // back. 19-the-complete-game.md, on the five axes of a hundred per cent: "twelve objects, and
    // the yard is a museum of a trade that no longer exists, assembled by the man who ended it."
    //
    // It is the counterweight to the engine. The engine is the thing you buy; this is the thing
    // you remember, and between them they are the only two things in the game that get bigger.
    const std::vector<std::pair<std::string, std::string>>& Salvage() const noexcept
    {
        return salvage_;
    }
    void RememberSalvage(const std::string& levelId, const std::string& what);

    // --- the shed ------------------------------------------------------------------------------
    //
    // What you own, and what you are carrying up today. Two different questions, and conflating
    // them is what made the climbing verbs opaque: every stance in the table was always available,
    // so a player pressed Q, waited twenty seconds for a bosun's chair to rig, and had no idea
    // where the chair had come from or what it was for. Gear you had to buy and then decide to
    // put on the cart is gear you know the name of before you use it.
    //
    // Ids are `economy.json`'s own `costs` keys, so the price of a thing and the fact that you
    // own it cannot disagree. Buying is refused rather than allowed into debt, like the engine.
    bool Owns(const std::string& item) const noexcept;
    bool Buy(const std::string& item, float costGbp);
    const std::vector<std::string>& Owned() const noexcept { return owned_; }

    // The loadout: the subset of what you own that went on the cart. Setting it keeps only what
    // you actually have, so a save that names a chair you sold cannot put one on the chimney.
    const std::vector<std::string>& Carried() const noexcept { return carried_; }
    void  Carry(const std::string& item, bool take);
    bool  Carrying(const std::string& item) const noexcept;

    // --- the ladders -----------------------------------------------------------------------
    //
    // Sections are stock, not a number you dial in before each job. You buy them, you keep them,
    // and a chimney you have not got the ladders for is a chimney you cannot take — which is the
    // cheapest honest lock in the game and the one reason the shop needs to exist.
    //
    // They were a slider in the van, and the question that killed it was the right one: what is
    // the penalty for choosing wrong? Either the number the reachability gate proved is correct
    // and the player should not be invited to get it wrong, or it is not and the gate is a lie.
    int32_t Ladders() const noexcept { return ladders_; }
    bool    BuyLadders(int32_t howMany, float costEach);

    // Days since the season started. The board shows weather by the day and some jobs have
    // deadlines, so this is the clock the whole meta layer hangs off.
    int32_t Day() const noexcept { return day_; }
    void    SleepOneNight() noexcept { ++day_; }

    // Parts bought for the traction engine under the tarpaulin. It has no mechanical benefit of
    // any kind, which is the entire point of it: see 19-the-complete-game.md on what a player
    // keeps. Buying is refused rather than allowed into debt — a job cannot leave you owing money
    // and neither can a boiler tube.
    int32_t EngineParts() const noexcept { return engineParts_; }
    bool    BuyEnginePart(float costGbp) noexcept;

    float   MoneyGbp() const noexcept { return money_; }
    int32_t Reputation() const noexcept { return reputation_; }
    // Reputation as the board draws it: how many of `economy.json`'s thresholds you are past.
    int32_t Stars(const Tuning& t) const noexcept;
    const std::vector<JobRecord>& Jobs() const noexcept { return jobs_; }

    // Has this job been done at all, and how well it went the best time.
    bool  Done(const std::string& levelId) const noexcept;

    // The strip-out. "Act 2 exists so that a felling level is not a puzzle with no climbing in it.
    // It's also where the player's relationship with the chimney becomes personal — you've been
    // all over it before you kill it." So a felling will not let you cut until you have.
    bool  Stripped(const std::string& levelId) const noexcept;
    void  MarkStripped(const std::string& levelId);
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
    // `extraBonusGbp` is what the level pays for things the fall itself does not know about —
    // finishing before dark, chiefly. It goes on the bonus and into the tin like any other.
    Settlement Settle(const std::string& levelId, float feeGbp, const FellOutcome& outcome,
                      const Tuning& t, float extraBonusGbp = 0.0f);

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
    int32_t day_{};
    int32_t engineParts_{};
    // Enough for the first three jobs, so the shop arrives when there is money to spend in it
    // rather than as a wall on day one. See the schedule in the commit that added this.
    int32_t ladders_{11};   // literal: the starting stock, chosen against the fee schedule
    std::vector<std::pair<std::string, std::vector<float>>> leftIn_;
    std::vector<std::pair<std::string, std::string>> salvage_;
    int32_t reputation_{};
    std::vector<JobRecord> jobs_;
    std::vector<std::string> stripped_;
    std::vector<std::string> owned_;
    std::vector<std::string> carried_;
};

}  // namespace sj
