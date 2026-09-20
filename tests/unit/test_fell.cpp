// The fall — FELL-002, the bet the player makes at the survey and cannot take back.
//
// docs/01-gdd/06-felling-system.md. These are the design's claims, as arithmetic: a chimney falls
// into the hole you cut, it wants to fall along its lean, fighting the lean costs accuracy, taking
// height off by hand buys it back, and what the fan covers is what you pay for.

#include "doctest.h"

#include "Fell.h"
#include "Gob.h"
#include "Tuning.h"

#include <cmath>
#include <filesystem>
#include <string>

using sj::Exclusion;
using sj::Fell;
using sj::FellGrade;
using sj::FellOutcome;
using sj::FellPlan;
using sj::FellPrediction;
using sj::FellSite;
using sj::Gob;
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

// Waterside: 70 m, lean 0.3 degrees toward 284, open field.
FellSite Waterside()
{
    FellSite s;
    s.heightM = 70.0f;
    s.baseRadiusM = 3.2f;
    s.leanDeg = 0.3f;
    s.leanBearingDeg = 284.0f;
    s.safeLineDistanceM = 105.0f;
    s.seed = 60001u;   // the level's, so a level always falls the same way
    return s;
}

Gob Ring(float leanDeg = 0.3f, float leanBearing = 284.0f)
{
    return Gob(32, 4, 3.2f, 70.0f, 900.0f, leanDeg, leanBearing, 14, -1, Tune());
}

// A worked gob: the design's arc, cut on a bearing, propped as you go.
Gob CutOn(float centreDeg, float arcDeg = 160.0f, float leanDeg = 0.3f, float leanBearing = 284.0f)
{
    Gob g = Ring(leanDeg, leanBearing);
    for (int32_t s = 0; s < g.Segments(); ++s)
    {
        float d = std::fabs(g.SegmentBearing(s) - centreDeg);
        d = (d > 180.0f) ? 360.0f - d : d;
        if (d <= arcDeg * 0.5f)
        {
            for (int32_t c = 0; c < g.Courses(); ++c)
            {
                g.Cut(s, c);
            }
            g.SetProp(s);
        }
    }
    g.Settle(Tune());
    return g;
}

}  // namespace

TEST_CASE("Fell: bearings subtract the short way round")
{
    CHECK(Fell::BearingDelta(10.0f, 20.0f) == doctest::Approx(10.0f));
    CHECK(Fell::BearingDelta(350.0f, 10.0f) == doctest::Approx(20.0f));
    CHECK(Fell::BearingDelta(10.0f, 350.0f) == doctest::Approx(-20.0f));
    CHECK(std::fabs(Fell::BearingDelta(0.0f, 180.0f)) == doctest::Approx(180.0f));
}

TEST_CASE("Fell: a chimney falls into the hole you cut")
{
    const FellSite site = Waterside();
    for (float want : {20.0f, 104.0f, 200.0f, 284.0f, 350.0f})
    {
        const Gob g = CutOn(want);
        FellPlan plan;
        plan.pegBearingDeg = want;
        const FellPrediction p = Fell::Predict(site, g, plan, Tune());
        CAPTURE(want);
        CAPTURE(g.CutCentreBearing());
        // Against the hole's real centre, not the bearing asked for: the ring is 32 segments, so
        // a cut can only land within half a segment of where you aimed it. What is left over that
        // is the lean, and at 0.3 degrees the lean is worth about four.
        CHECK(std::fabs(Fell::BearingDelta(g.CutCentreBearing(), p.fallBearingDeg)) < 5.0f);
    }
}

TEST_CASE("Fell: it wants to fall along its lean, and a big lean drags it off the hole")
{
    // Worth knowing: a lean pointing straight back at the gob does not turn the fall at all, it
    // only argues with it, and the design charges for that in accuracy rather than in bearing.
    // What moves the fall line is a lean across it. So this leans 90 degrees off the hole.
    FellSite site = Waterside();
    site.leanDeg = 2.1f;             // Great Aire
    site.leanBearingDeg = 194.0f;
    FellPlan plan;
    plan.pegBearingDeg = 104.0f;

    const Gob g = CutOn(104.0f, 160.0f, 2.1f, 194.0f);
    const FellPrediction p = Fell::Predict(site, g, plan, Tune());
    const float pulled = std::fabs(Fell::BearingDelta(g.CutCentreBearing(), p.fallBearingDeg));
    CAPTURE(p.fallBearingDeg);
    CHECK(pulled > 20.0f);   // 2.1 degrees of lean is not a rounding error

    // The same gob on a chimney that barely leans goes where it was cut.
    FellSite gentle = Waterside();
    gentle.leanBearingDeg = 194.0f;
    const Gob g2 = CutOn(104.0f, 160.0f, 0.3f, 194.0f);
    const FellPrediction q = Fell::Predict(gentle, g2, plan, Tune());
    CHECK(std::fabs(Fell::BearingDelta(g2.CutCentreBearing(), q.fallBearingDeg)) < pulled * 0.5f);
}

TEST_CASE("Fell: a lean straight back at the gob fights the cut without turning it")
{
    FellSite site = Waterside();
    site.leanDeg = 2.1f;
    site.leanBearingDeg = 284.0f;
    FellPlan plan;
    plan.pegBearingDeg = 104.0f;
    const Gob g = CutOn(104.0f, 160.0f, 2.1f, 284.0f);
    const FellPrediction p = Fell::Predict(site, g, plan, Tune());
    // Barely turned at all - compare the 20-plus degrees a lean across the gob is worth. It is
    // not quite nothing, and that is worth knowing too: a lean pointing back at the hole cancels
    // most of the gob's authority, so what is left of the fall line twitches at whatever is not
    // exactly opposite. Fighting a lean head on does not move the answer, it makes it nervous.
    CHECK(std::fabs(Fell::BearingDelta(g.CutCentreBearing(), p.fallBearingDeg)) < 5.0f);
    // And it costs in the cone, which is the whole of "fighting it costs you accuracy".
    CHECK(p.accuracyDegrees > Tune().GetF("fallAccuracyPerLeanFoughtDegree") * 2.0f);
}

TEST_CASE("Fell: an uncut chimney is not being steered by anything")
{
    // The gob has no authority until it is cut, so the lean is the whole argument.
    const Gob g = Ring();
    FellPlan plan;
    plan.pegBearingDeg = 104.0f;
    const FellPrediction p = Fell::Predict(Waterside(), g, plan, Tune());
    CHECK(p.fallBearingDeg == doctest::Approx(284.0f).epsilon(0.01));
}

TEST_CASE("Fell: fighting the lean costs accuracy, and going with it costs nothing")
{
    FellSite site = Waterside();
    site.leanDeg = 1.4f;             // Kershaw's Yard
    site.leanBearingDeg = 100.0f;

    FellPlan withIt;
    withIt.pegBearingDeg = 100.0f;   // along the lean
    FellPlan against;
    against.pegBearingDeg = 280.0f;  // dead against it

    const Gob g = CutOn(100.0f, 160.0f, 1.4f, 100.0f);
    const float easy = Fell::Predict(site, g, withIt, Tune()).accuracyDegrees;
    const float hard = Fell::Predict(site, g, against, Tune()).accuracyDegrees;
    CAPTURE(easy);
    CAPTURE(hard);
    CHECK(hard > easy);
    CHECK(hard - easy == doctest::Approx(Tune().GetF("fallAccuracyPerLeanFoughtDegree") * 1.4f)
                             .epsilon(0.02));
}

TEST_CASE("Fell: acceptance, every five metres taken off by hand is worth about 1.5 degrees")
{
    // "the game tells you your predicted accuracy improves by ~1.5 degrees per 5 m removed" — and
    // the height itself helps too, so the real gain is a little better than the number quoted.
    FellSite site = Waterside();
    const Gob g = CutOn(284.0f);
    FellPlan none, cut;
    none.pegBearingDeg = cut.pegBearingDeg = 284.0f;
    cut.heightRemovedM = 5.0f;

    const float before = Fell::Predict(site, g, none, Tune()).accuracyDegrees;
    const float after = Fell::Predict(site, g, cut, Tune()).accuracyDegrees;
    CHECK(before - after >= Tune().GetF("fallAccuracyPerFiveMetresRemoved"));
    CHECK(before - after < Tune().GetF("fallAccuracyPerFiveMetresRemoved") * 2.0f);
}

TEST_CASE("Fell: a narrow gob is a gob you cannot steer with")
{
    FellSite site = Waterside();
    FellPlan plan;
    plan.pegBearingDeg = 284.0f;
    const float narrow = Fell::Predict(site, CutOn(284.0f, 60.0f), plan, Tune()).accuracyDegrees;
    const float full = Fell::Predict(site, CutOn(284.0f, 160.0f), plan, Tune()).accuracyDegrees;
    CHECK(narrow - full == doctest::Approx(Tune().GetF("fallAccuracyNarrowGobDegrees")).epsilon(0.01));
}

TEST_CASE("Fell: the debris fan is 18 degrees and 1.15 times the height it fell from")
{
    FellSite site = Waterside();
    FellPlan plan;
    plan.pegBearingDeg = 284.0f;
    plan.heightRemovedM = 10.0f;
    const FellPrediction p = Fell::Predict(site, CutOn(284.0f), plan, Tune());
    CHECK(p.debrisHalfAngleDeg == doctest::Approx(18.0f));
    CHECK(p.debrisLengthM == doctest::Approx(60.0f * 1.15f));   // the shaft, not the chimney

    // "Getting the length right matters as much as the bearing": something straight down the fall
    // line but past the end of the fan is safe, and something nearer is not.
    Exclusion near_{"greenhouse", p.fallBearingDeg, 40.0f, 14.0f, false};
    Exclusion far_{"greenhouse", p.fallBearingDeg, 90.0f, 14.0f, false};
    Exclusion aside{"greenhouse", p.fallBearingDeg + 40.0f, 40.0f, 14.0f, false};
    CHECK(p.Threatens(near_));
    CHECK_FALSE(p.Threatens(far_));
    CHECK_FALSE(p.Threatens(aside));
}

TEST_CASE("Fell: the shaft breaks up, two to four times, and never into confetti")
{
    // "typically 2-4 breaks", "clean (3-4 chunks)". The three authored fellings, plus the one
    // Great Aire becomes after its required 18 m comes off by hand.
    for (float h : {70.0f, 65.0f, 110.0f, 92.0f})
    {
        const std::vector<float> breaks = Fell::FractureHeights(h, Tune());
        CAPTURE(h);
        CHECK(breaks.size() >= 2);
        CHECK(breaks.size() <= 4);
        CHECK(breaks.front() < h);
        for (std::size_t i = 1; i < breaks.size(); ++i)
        {
            CHECK(breaks[i] < breaks[i - 1]);   // highest first
            CHECK(breaks[i - 1] - breaks[i] >= Tune().GetF("fellFractureMinChunkM") - 0.01f);
        }
        CHECK(breaks.back() >= Tune().GetF("fellFractureMinHeightM"));
    }
}

TEST_CASE("Fell: a stump too short to break comes down in one piece")
{
    CHECK(Fell::FractureHeights(Tune().GetF("fellFractureMinHeightM"), Tune()).empty());
    CHECK(Fell::FractureHeights(0.0f, Tune()).empty());
}

TEST_CASE("Fell: a felling scores on how far off the pegs it landed")
{
    FellSite site = Waterside();
    FellPlan plan;
    plan.pegBearingDeg = 284.0f;
    const FellOutcome good = Fell::Run(site, CutOn(284.0f), plan, Tune());
    CAPTURE(good.errorDegrees);
    CHECK(good.grade >= FellGrade::Good);
    CHECK(good.bonusGbp >= Tune().GetF("fellScoreGoodBonus"));
    CHECK(good.chunks >= 3);
    CHECK(good.cleanBreak);
    CHECK(good.struck.empty());

    // Pegs on one side, gob on the other: it lands where the gob says and the pegs were a lie.
    FellPlan wrong;
    wrong.pegBearingDeg = 104.0f;
    const FellOutcome wild = Fell::Run(site, CutOn(284.0f), wrong, Tune());
    CHECK(wild.grade == FellGrade::Wild);
    CHECK(wild.bonusGbp == doctest::Approx(Tune().GetF("fellScoreCleanBreakBonus")));
}

TEST_CASE("Fell: the same site, hole and plan always fall the same way")
{
    // ADR-0002. A felling is a thing a player can learn, and a replay has to reproduce.
    const FellSite site = Waterside();
    FellPlan plan;
    plan.pegBearingDeg = 284.0f;
    const FellOutcome a = Fell::Run(site, CutOn(284.0f), plan, Tune());
    const FellOutcome b = Fell::Run(site, CutOn(284.0f), plan, Tune());
    CHECK(a.fallBearingDeg == doctest::Approx(b.fallBearingDeg));
    CHECK(a.fractureHeightsM.size() == b.fractureHeightsM.size());

    // And it lands inside the cone the HUD promised, which is what makes the cone honest.
    const FellPrediction p = Fell::Predict(site, CutOn(284.0f), plan, Tune());
    CHECK(std::fabs(Fell::BearingDelta(p.fallBearingDeg, a.fallBearingDeg)) <= p.accuracyDegrees);
}

TEST_CASE("Fell: hitting the chapel fails the job, and the greenhouse only costs fourteen pounds")
{
    FellSite site = Waterside();
    FellPlan plan;
    plan.pegBearingDeg = 284.0f;
    const FellPrediction p = Fell::Predict(site, CutOn(284.0f), plan, Tune());
    site.exclusions.push_back(Exclusion{"chapel", p.fallBearingDeg, 22.0f, 0.0f, true});
    site.exclusions.push_back(Exclusion{"greenhouse", p.fallBearingDeg + 5.0f, 40.0f, 14.0f, false});
    site.exclusions.push_back(Exclusion{"pub", p.fallBearingDeg + 150.0f, 30.0f, 999.0f, false});

    const FellOutcome o = Fell::Run(site, CutOn(284.0f), plan, Tune());
    CHECK(o.struck.size() == 2);
    CHECK(o.catastrophe);
    CHECK(o.penaltyGbp == doctest::Approx(14.0f));   // the pub is behind it and lives
}
