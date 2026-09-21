// Running a lightning conductor — the CONDUCTOR archetype.
//
// The rules here are almost all quotations from the 1881 Lightning Rod Conference Code of Rules,
// which reads more like a game design document than a safety standard. Two of them are the whole
// archetype: the run may not be more than half as long again as the straight line it covers, and a
// fixing must not be driven so tight that the rod cannot move when it is cold. Both are tested by
// name here, because both will look like arbitrary numbers to whoever tunes this next and neither
// of them is.

#include "doctest.h"

#include "Conductor.h"
#include "Tuning.h"

#include <filesystem>
#include <string>

using sj::Conductor;
using sj::RunVerdict;
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

// A clean run down from `top` to the ground: a clip every metre, tape paid out straight, driven
// to the middle of the band.
Conductor GoodRun(float top, float reel)
{
    const Tuning& t = Tune();
    Conductor c;
    c.Begin(reel, t);
    c.SetTerminal();
    const float mid = (t.GetF("clipTightMin") + t.GetF("clipTightMax")) * 0.5f;
    c.Fix(top, 0.0f, mid, t);
    for (float h = top - 1.0f; h >= 0.0f; h -= 1.0f)
    {
        c.Fix(h, 1.0f, mid, t);
    }
    c.Earth(t.GetF("earthPlateSquareFeetMin"), true, true, t);
    return c;
}

}  // namespace

TEST_CASE("Conductor: a straight run, properly fixed and earthed, passes")
{
    const Tuning& t = Tune();
    Conductor c = GoodRun(20.0f, 40.0f);
    const sj::ConductorRun v = c.Judge(0.0f, t);

    CHECK(v.verdict == RunVerdict::Sound);
    CHECK(v.wanderRatio == doctest::Approx(1.0f));
    CHECK(v.overTight == 0);
    CHECK(v.tooLoose == 0);
    CHECK(v.earthOhms <= t.GetF("earthPassOhms"));
}

TEST_CASE("Conductor: the Code's curvature rule is the one that fails a wandering run")
{
    const Tuning& t = Tune();
    // "In no case should the length of the rod between two points be more than half as long again
    // as the straight line joining them." Twenty metres of drop, thirty-two metres of tape.
    Conductor c;
    c.Begin(60.0f, t);
    c.SetTerminal();
    const float mid = (t.GetF("clipTightMin") + t.GetF("clipTightMax")) * 0.5f;
    c.Fix(20.0f, 0.0f, mid, t);
    for (float h = 19.0f; h >= 0.0f; h -= 1.0f)
    {
        c.Fix(h, 1.6f, mid, t);
    }
    c.Earth(t.GetF("earthPlateSquareFeetMin"), true, true, t);

    const sj::ConductorRun v = c.Judge(0.0f, t);
    CHECK(v.wanderRatio > t.GetF("wanderFailRatio"));
    CHECK(v.verdict == RunVerdict::Failed);
}

TEST_CASE("Conductor: a little slack is marginal, not a failure")
{
    const Tuning& t = Tune();
    Conductor c;
    c.Begin(60.0f, t);
    c.SetTerminal();
    const float mid = (t.GetF("clipTightMin") + t.GetF("clipTightMax")) * 0.5f;
    c.Fix(20.0f, 0.0f, mid, t);
    for (float h = 19.0f; h >= 0.0f; h -= 1.0f)
    {
        c.Fix(h, 1.3f, mid, t);   // between the warn ratio and the Code's limit
    }
    c.Earth(t.GetF("earthPlateSquareFeetMin"), true, true, t);

    const sj::ConductorRun v = c.Judge(0.0f, t);
    CHECK(v.wanderRatio > t.GetF("wanderWarnRatio"));
    CHECK(v.wanderRatio < t.GetF("wanderFailRatio"));
    CHECK(v.verdict == RunVerdict::Marginal);
}

TEST_CASE("Conductor: driving a fixing home hard is a failure, not a virtue")
{
    const Tuning& t = Tune();
    Conductor c;
    c.Begin(40.0f, t);
    c.SetTerminal();
    const float mid = (t.GetF("clipTightMin") + t.GetF("clipTightMax")) * 0.5f;
    c.Fix(10.0f, 0.0f, mid, t);
    for (float h = 9.0f; h >= 0.0f; h -= 1.0f)
    {
        c.Fix(h, 1.0f, mid, t);
    }
    c.Earth(t.GetF("earthPlateSquareFeetMin"), true, true, t);
    REQUIRE(c.Judge(0.0f, t).verdict == RunVerdict::Sound);

    // One holdfast driven past the band. "The holdfasts should not be driven in so tightly as to
    // pinch the rod, or prevent the contraction and expansion produced by changes of temperature."
    c.Fix(0.0f, 0.5f, 1.0f, t);
    const sj::ConductorRun v = c.Judge(0.0f, t);
    CHECK(v.overTight == 1);
    CHECK(v.verdict == RunVerdict::Failed);
}

TEST_CASE("Conductor: a loose fixing is a worry rather than a fail")
{
    const Tuning& t = Tune();
    Conductor c = GoodRun(10.0f, 40.0f);
    c.Fix(0.0f, 0.2f, 0.0f, t);
    const sj::ConductorRun v = c.Judge(0.0f, t);
    CHECK(v.tooLoose == 1);
    CHECK(v.verdict == RunVerdict::Marginal);
}

TEST_CASE("Conductor: the reel runs out, and running out ends the run where it is")
{
    const Tuning& t = Tune();
    Conductor c;
    c.Begin(t.GetF("reelMetres"), t);
    c.SetTerminal();
    const float mid = (t.GetF("clipTightMin") + t.GetF("clipTightMax")) * 0.5f;
    c.Fix(28.0f, 0.0f, mid, t);

    int fixed = 0;
    for (float h = 27.0f; h >= 0.0f; h -= 1.0f)
    {
        if (!c.Fix(h, 1.0f, mid, t))
        {
            break;
        }
        ++fixed;
    }
    // A 25 m reel does not reach the bottom of a 28 m chimney, which is the archetype's
    // complication and is meant to be discovered on the way down.
    CHECK(fixed == 25);
    CHECK(c.State().tapeLeftM == doctest::Approx(0.0f));
}

TEST_CASE("Conductor: no terminal at the apex is no system at all")
{
    const Tuning& t = Tune();
    Conductor c = GoodRun(10.0f, 40.0f);
    REQUIRE(c.Judge(0.0f, t).verdict == RunVerdict::Sound);

    Conductor bare;
    bare.Begin(40.0f, t);
    const float mid = (t.GetF("clipTightMin") + t.GetF("clipTightMax")) * 0.5f;
    bare.Fix(10.0f, 0.0f, mid, t);
    for (float h = 9.0f; h >= 0.0f; h -= 1.0f)
    {
        bare.Fix(h, 1.0f, mid, t);
    }
    bare.Earth(t.GetF("earthPlateSquareFeetMin"), true, true, t);
    // Worse than nothing: it still attracts the strike and gives it nowhere to go.
    CHECK(bare.Judge(0.0f, t).verdict == RunVerdict::Failed);
}

TEST_CASE("Conductor: the earth is where a job passes in March and fails in August")
{
    const Tuning& t = Tune();
    const float plate = t.GetF("earthPlateSquareFeetMin");

    Conductor wet;
    wet.Begin(40.0f, t);
    wet.Earth(plate, true, true, t);
    CHECK(wet.State().earthOhms <= t.GetF("earthPassOhms"));

    // "The hole must be so deep that the earth surrounding the plate shall never be dry."
    Conductor dry;
    dry.Begin(40.0f, t);
    dry.Earth(plate, false, true, t);
    CHECK(dry.State().earthOhms > wet.State().earthOhms);
    CHECK(dry.State().earthOhms > t.GetF("earthPassOhms"));

    // And the coke packing is not decoration either.
    Conductor bare;
    bare.Begin(40.0f, t);
    bare.Earth(plate, true, false, t);
    CHECK(bare.State().earthOhms > wet.State().earthOhms);

    // Half the copper the Code asks for is worse than all of it.
    Conductor small;
    small.Begin(40.0f, t);
    small.Earth(plate * 0.5f, true, true, t);
    CHECK(small.State().earthOhms > wet.State().earthOhms);
}

TEST_CASE("Conductor: a gap too big between fixings fails however straight the run is")
{
    const Tuning& t = Tune();
    Conductor c;
    c.Begin(60.0f, t);
    c.SetTerminal();
    const float mid = (t.GetF("clipTightMin") + t.GetF("clipTightMax")) * 0.5f;
    const float jump = t.GetF("clipSpacingMaxMetres") + 1.0f;
    c.Fix(20.0f, 0.0f, mid, t);
    c.Fix(20.0f - jump, jump, mid, t);
    for (float h = 20.0f - jump - 1.0f; h >= 0.0f; h -= 1.0f)
    {
        c.Fix(h, 1.0f, mid, t);
    }
    c.Earth(t.GetF("earthPlateSquareFeetMin"), true, true, t);

    const sj::ConductorRun v = c.Judge(0.0f, t);
    CHECK(v.longestGapM > t.GetF("clipSpacingMaxMetres"));
    // Not a wander in sight — the run is as straight as tape gets — and it still does not pass.
    CHECK(v.wanderRatio <= t.GetF("wanderWarnRatio"));
    CHECK(v.verdict == RunVerdict::Failed);
}
