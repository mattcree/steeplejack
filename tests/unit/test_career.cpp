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
