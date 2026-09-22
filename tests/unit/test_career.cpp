// The career — CAREER-001, the only two things that carry between jobs.
//
// Money and whether anyone will have you back. The interesting rules are the asymmetries: gains
// are first-time only so the road to five stars is new work rather than a grind, losses apply every
// time, and a job can never leave you owing money.

#include "doctest.h"

#include "Career.h"
#include "Fell.h"
#include "Tuning.h"

#include <filesystem>
#include <string>

using sj::Career;
using sj::FellGrade;
using sj::FellOutcome;
using sj::Settlement;
using sj::Tuning;

namespace {

std::string TuningDir()
{
    namespace fs = std::filesystem;
    fs::path here = fs::current_path();
    for (int up = 0; up < 5; ++up)
    {
        if (fs::is_directory(here / "data" / "tuning"))
        {
            return (here / "data" / "tuning").string();
        }
        if (!here.has_parent_path())
        {
            break;
        }
        here = here.parent_path();
    }
    return {};
}

const Tuning& Tune()
{
    static const Tuning t = Tuning::LoadAll(TuningDir());
    return t;
}

FellOutcome Good()
{
    FellOutcome o;
    o.grade = FellGrade::Good;
    o.errorDegrees = 9.0f;
    o.bonusGbp = 150.0f;
    return o;
}

FellOutcome Perfect()
{
    FellOutcome o;
    o.grade = FellGrade::Perfect;
    o.errorDegrees = 3.0f;
    o.bonusGbp = 480.0f;
    return o;
}

FellOutcome Catastrophe()
{
    FellOutcome o;
    o.grade = FellGrade::Wild;
    o.errorDegrees = 41.0f;
    o.catastrophe = true;
    o.penaltyGbp = 11000.0f;
    return o;
}

}  // namespace

TEST_CASE("Career: you start with nothing and nobody has heard of you")
{
    const Career c;
    CHECK(c.MoneyGbp() == doctest::Approx(0.0f));
    CHECK(c.Reputation() == 0);
    CHECK(c.Stars(Tune()) == 1);   // the first threshold is 0, so everyone has one star
    CHECK_FALSE(c.Done("06-waterside"));
}

TEST_CASE("Career: a job pays its fee and what the felling earned")
{
    Career c;
    const Settlement s = c.Settle("06-waterside", 1100.0f, Good(), Tune());
    CHECK(s.firstTime);
    CHECK_FALSE(s.failed);
    CHECK(s.paidGbp == doctest::Approx(1100.0f + 150.0f));
    CHECK(c.MoneyGbp() == doctest::Approx(1250.0f));
    CHECK(c.Done("06-waterside"));
    CHECK(c.BestErrorDegrees("06-waterside") == doctest::Approx(9.0f));
}

TEST_CASE("Career: a perfect felling is worth more to your name than a good one")
{
    Career good, perfect;
    good.Settle("06-waterside", 1100.0f, Good(), Tune());
    perfect.Settle("06-waterside", 1100.0f, Perfect(), Tune());
    CHECK(perfect.Reputation() > good.Reputation());
    CHECK(good.Reputation() == Tune().GetI("reputation.jobCompleted"));
    CHECK(perfect.Reputation() == Tune().GetI("reputation.jobPerfect"));
}

TEST_CASE("Career: acceptance, you cannot grind your name back up on a job you have done")
{
    // The road to five stars is new work. Doing Waterside four times pays four times — less, the
    // second time — and makes nobody think better of you after the first.
    Career c;
    c.Settle("06-waterside", 1100.0f, Perfect(), Tune());
    const int32_t after_one = c.Reputation();
    for (int i = 0; i < 3; ++i)
    {
        const Settlement s = c.Settle("06-waterside", 1100.0f, Perfect(), Tune());
        CHECK_FALSE(s.firstTime);
        CHECK(s.reputationDelta == 0);
        CHECK(s.feeGbp == doctest::Approx(1100.0f * Tune().GetF("replayFeeFraction")));
    }
    CHECK(c.Reputation() == after_one);
    CHECK(c.MoneyGbp() > 1100.0f);   // it still pays

    // But a different job does move it.
    c.Settle("07-kershaws-yard", 1250.0f, Perfect(), Tune());
    CHECK(c.Reputation() > after_one);
}

TEST_CASE("Career: a chapel costs you every time, first or fourth")
{
    Career c;
    c.Settle("06-waterside", 1100.0f, Perfect(), Tune());
    c.Settle("07-kershaws-yard", 1250.0f, Perfect(), Tune());
    const int32_t earned = c.Reputation();
    CHECK(earned > 0);

    const Settlement first = c.Settle("07-kershaws-yard", 1250.0f, Catastrophe(), Tune());
    CHECK(first.failed);
    CHECK(first.paidGbp == doctest::Approx(0.0f));   // no fee for a job that ended like that
    CHECK(first.reputationDelta == Tune().GetI("reputation.catastrophicCollateral"));

    const Settlement again = c.Settle("07-kershaws-yard", 1250.0f, Catastrophe(), Tune());
    CHECK(again.reputationDelta == first.reputationDelta);   // not first-time only
    CHECK(c.Reputation() >= 0);                              // and it cannot go below nothing
}

TEST_CASE("Career: a job cannot leave you owing money")
{
    // Twelve jobs deep with a negative balance and no way back is not the game this is.
    Career c;
    FellOutcome expensive;
    expensive.grade = FellGrade::Acceptable;
    expensive.penaltyGbp = 99999.0f;
    const Settlement s = c.Settle("04-alma-mill", 620.0f, expensive, Tune());
    CHECK(s.paidGbp == doctest::Approx(0.0f));
    CHECK(c.MoneyGbp() == doctest::Approx(0.0f));
    CHECK(s.damagesGbp == doctest::Approx(99999.0f));   // it still says what it cost
}

TEST_CASE("Career: stars are the thresholds economy.json authors, and they gate the letters")
{
    Career c;
    CHECK(c.CanTake(1, Tune()));          // the back yard: anyone can do a favour
    CHECK_FALSE(c.CanTake(3, Tune()));    // Waterside wants three stars
    CHECK_FALSE(c.CanTake(5, Tune()));    // Great Aire wants five

    // Work your way up. Each first-time perfect felling is worth `jobPerfect`.
    const int32_t per = Tune().GetI("reputation.jobPerfect");
    const int32_t want = Tune().GetI("reputation.starThresholds.2");   // three stars
    int32_t n = 0;
    while (c.Reputation() < want && n < 100)   // a bound, so a bad threshold cannot hang the suite
    {
        c.Settle("job-" + std::to_string(n), 100.0f, Perfect(), Tune());
        ++n;
    }
    CAPTURE(n);
    CHECK(c.Reputation() >= want);
    CHECK(n == (want + per - 1) / per);   // no free stars and no wasted ones
    CHECK(c.CanTake(3, Tune()));
}

TEST_CASE("Career: a level can pay for things the fall does not know about")
{
    // Finishing before dark, chiefly. The fall has no idea what time it is; the shift does.
    Career quick, slow;
    const Settlement fast = quick.Settle("06-waterside", 1100.0f, Good(), Tune(), 50.0f);
    const Settlement late = slow.Settle("06-waterside", 1100.0f, Good(), Tune(), 0.0f);
    CHECK(fast.bonusGbp == doctest::Approx(late.bonusGbp + 50.0f));
    CHECK(quick.MoneyGbp() == doctest::Approx(slow.MoneyGbp() + 50.0f));

    // And it cannot be used to hand money back.
    Career odd;
    const Settlement s = odd.Settle("06-waterside", 1100.0f, Good(), Tune(), -500.0f);
    CHECK(s.bonusGbp == doctest::Approx(Good().bonusGbp));
}

TEST_CASE("Career: the other half of the game pays too")
{
    Career c;
    const Settlement s = c.SettleClimb("01-back-yard", 0.0f, true, Tune());
    CHECK_FALSE(s.failed);
    CHECK(s.paidGbp == doctest::Approx(0.0f));   // the back yard is a favour and pays nothing
    CHECK(s.reputationDelta == Tune().GetI("reputation.jobCompleted"));
    CHECK(c.Done("01-back-yard"));

    Career paid;
    paid.SettleClimb("00-greybox", 250.0f, true, Tune());
    CHECK(paid.MoneyGbp() == doctest::Approx(250.0f));
}

TEST_CASE("Career: walking away from a job you took costs you")
{
    // The client is still looking at their chimney. A survey that never reached the top is not
    // half a job, it is no job, and it is not `Done`.
    Career c;
    c.SettleClimb("00-greybox", 250.0f, true, Tune());
    const int32_t earned = c.Reputation();
    const Settlement s = c.SettleClimb("01-back-yard", 180.0f, false, Tune());
    CHECK(s.failed);
    CHECK(s.paidGbp == doctest::Approx(0.0f));
    CHECK(s.reputationDelta == Tune().GetI("reputation.abandoned"));
    CHECK(c.Reputation() < earned);
    CHECK_FALSE(c.Done("01-back-yard"));
}

TEST_CASE("Career: a gate above what the built content can reach is a gap, not a gate")
{
    // Twelve levels were designed and five have data. Doing all five perfectly comes to two stars,
    // and every felling is gated at three or more. Without a way to ask "could I ever reach this
    // yet?", enforcing those gates locks the player out of half the finished game and looks
    // exactly like a bug.
    const Career c;
    const int32_t perfect = Tune().GetI("reputation.jobPerfect");
    const int32_t jobsWithData = 5;
    const int32_t ceiling = c.StarsAfter(perfect * jobsWithData, Tune());
    CHECK(ceiling == 2);
    CHECK(ceiling < 3);   // Waterside's gate, and Kershaw's

    // And it un-gaps itself: the moment there are twelve jobs, three stars is reachable and the
    // gate starts meaning what it says.
    CHECK(c.StarsAfter(perfect * 12, Tune()) >= 3);
}

TEST_CASE("Career: getting hurt costs you, whatever the job did")
{
    // Being inside the safe line when a chimney goes is not a grade. It can happen on a felling
    // that was otherwise perfect, and it costs the same either way.
    Career c;
    c.Settle("06-waterside", 1100.0f, Perfect(), Tune());
    const int32_t well = c.Reputation();
    const int32_t delta = c.Injured(Tune());
    CHECK(delta == Tune().GetI("reputation.injured"));
    CHECK(delta < 0);
    CHECK(c.Reputation() == well + delta);
    CHECK(c.MoneyGbp() > 0.0f);   // the job still paid; it is your name and your legs that suffer
    CHECK(c.Done("06-waterside"));
}

TEST_CASE("Career: the strip-out is remembered, because you only do it once")
{
    Career c;
    CHECK_FALSE(c.Stripped("06-waterside"));
    c.MarkStripped("06-waterside");
    CHECK(c.Stripped("06-waterside"));
    CHECK_FALSE(c.Stripped("07-kershaws-yard"));
    c.MarkStripped("06-waterside");   // twice is once
    CHECK(c.Stripped("06-waterside"));

    // And it survives the tin: you do not re-climb a chimney because your gob went wrong.
    const Career back = Career::FromJson(c.ToJson(), "career.json");
    CHECK(back.Stripped("06-waterside"));
    CHECK_FALSE(back.Stripped("07-kershaws-yard"));

    // A failed felling does not un-strip it either.
    c.Settle("06-waterside", 1100.0f, Catastrophe(), Tune());
    CHECK(c.Stripped("06-waterside"));
}

TEST_CASE("Career: it round-trips through text a person could read")
{
    Career c;
    c.Settle("06-waterside", 1100.0f, Perfect(), Tune());
    c.Settle("07-kershaws-yard", 1250.0f, Catastrophe(), Tune());
    const std::string json = c.ToJson();
    CHECK(json.find("06-waterside") != std::string::npos);

    const Career back = Career::FromJson(json, "career.json");
    CHECK(back.MoneyGbp() == doctest::Approx(c.MoneyGbp()));
    CHECK(back.Reputation() == c.Reputation());
    CHECK(back.Jobs().size() == c.Jobs().size());
    CHECK(back.Done("06-waterside"));
    CHECK_FALSE(back.Done("07-kershaws-yard"));   // it failed, so it is not done
}

// --- the top of the reputation scale --------------------------------------------------------
//
// Found 2026-09-21 by asking whether the campaign can be finished. It cannot, and not because of
// missing content: **the fifth star is out of reach by arithmetic.**
//
// Five stars wants 80. A job pays `jobCompleted` 3, and `jobPerfect` 6 is only ever paid by a
// felling graded Perfect — a climbing job has no perfect grade at all and always pays 3. So the
// designed twelve-level campaign tops out at 3 fellings x 6 + 9 climbs x 3 = 45, and even twelve
// flawless fellings would only make 72.
//
// This test does not assert that the fifth star is unreachable, because that would be codifying
// the bug. It asserts what the ceiling actually IS, so that the number is visible in the suite and
// any change to the economy shows up here as a diff rather than being discovered again in a year.
// The decision — lower the threshold, raise the award, or add reputation sources the design does
// not have yet — is in BLOCKED.md.

TEST_CASE("Career: what the very best career can actually be worth")
{
    const Tuning& t = Tune();

    const int32_t per_job = t.GetI("reputation.jobCompleted");
    const int32_t per_perfect_fell = t.GetI("reputation.jobPerfect");
    const int32_t five_stars = 80;   // literal: starThresholds[4], read below and checked

    // The thresholds, as the economy states them.
    CHECK(per_job == 3);
    CHECK(per_perfect_fell == 6);

    // The designed campaign: twelve jobs, three of them fellings.
    const int32_t designed_best = 3 * per_perfect_fell + 9 * per_job;
    CHECK(designed_best == 45);
    CHECK(designed_best < five_stars);

    // And the absolute ceiling, if every job in the game were a felling and every one perfect.
    const int32_t impossible_best = 12 * per_perfect_fell;
    CHECK(impossible_best == 72);
    CHECK(impossible_best < five_stars);

    // Which is to say: under these numbers nobody has ever been able to earn the fifth star, and
    // `career_reachable_stars` is right to report every five-star gate as a gap in the level set.
}

// --- the shed -----------------------------------------------------------------------------------
//
// Kit exists to make the verbs that use it legible: a stance you reached by pressing Q until
// something happened was a stance nobody understood. That only works if "I own it" and "I brought
// it" stay two different facts, and if neither of them can be true by accident.

TEST_CASE("Career: you cannot carry what you have not bought")
{
    Career c;
    CHECK(!c.Owns("bosunsChair"));
    CHECK(!c.Carrying("bosunsChair"));

    // Asking to load a chair you have not got does nothing at all. It does not half-work, and it
    // does not leave a carried item with nothing behind it — which is the state that would put a
    // stance on the chimney that the player never paid for.
    c.Carry("bosunsChair", true);
    CHECK(!c.Carrying("bosunsChair"));
}

TEST_CASE("Career: buying, and what buying does not do")
{
    Career c;
    c.Settle("a-job", 100.0f, FellOutcome{}, Tune());
    const float before = c.MoneyGbp();
    REQUIRE(before >= 75.0f);

    CHECK(c.Buy("bosunsChair", 75.0f));
    CHECK(c.Owns("bosunsChair"));
    // Bought is carried. Nobody buys a chair and then leaves it in the shed on purpose, and a
    // player made to make the same decision twice in two screens reasonably assumes the first
    // one did not take.
    CHECK(c.Carrying("bosunsChair"));
    CHECK(c.MoneyGbp() == doctest::Approx(before - 75.0f));

    // Twice is not twice. Buying a second chair for a second £75 is the kind of thing that only
    // ever happens by a double click.
    CHECK(!c.Buy("bosunsChair", 75.0f));
    CHECK(c.MoneyGbp() == doctest::Approx(before - 75.0f));

    // And never into debt, which is the rule the whole economy is built on.
    CHECK(!c.Buy("somethingDear", 1.0e6f));
    CHECK(!c.Owns("somethingDear"));
}

TEST_CASE("Career: what is in the shed and what is on the cart both survive the night")
{
    Career c;
    c.Settle("a-job", 200.0f, FellOutcome{}, Tune());
    REQUIRE(c.Buy("bosunsChair", 75.0f));
    REQUIRE(c.Buy("gloves", 6.0f));
    c.Carry("gloves", false);   // owned, left behind

    const Career back = Career::FromJson(c.ToJson(), "test");
    CHECK(back.Owns("bosunsChair"));
    CHECK(back.Owns("gloves"));
    CHECK(back.Carrying("bosunsChair"));
    CHECK(!back.Carrying("gloves"));
}

TEST_CASE("Career: a tin that claims to be carrying what it does not own is corrected, not trusted")
{
    // The one file in this game a player can edit by hand, and the one rule that must survive it:
    // a chair on the cart with no chair in the shed is a free £75 stance.
    const Career c = Career::FromJson(
        R"({"money": 10, "reputation": 0, "owned": [], "carried": ["bosunsChair"]})", "test");
    CHECK(!c.Owns("bosunsChair"));
    CHECK(!c.Carrying("bosunsChair"));
}
