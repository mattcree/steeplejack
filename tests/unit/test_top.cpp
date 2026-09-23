// Taking her down by hand — the TOP archetype's rules.
//
// The verb is a release window, so the things worth pinning are the three outcomes and the two
// facts that make it a skill rather than a reflex test: the give point belongs to the brick and
// not to the attempt, and sounding one first widens the window you have to hit.

#include "doctest.h"

#include "Top.h"
#include "Tuning.h"

#include <filesystem>
#include <string>

using sj::Prise;
using sj::Stroke;
using sj::Top;
using sj::TopVerdict;
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

// Lever until the load is `to`, in small steps, the way a player holding a button does.
void LeverTo(Top& top, float to, const Tuning& t)
{
    for (int i = 0; i < 2000 && top.State().load < to; ++i)
    {
        top.Lever(0.01f, t);
    }
}

}  // namespace

TEST_CASE("Top: releasing in the window takes the brick out whole")
{
    const Tuning& t = Tune();
    Top top;
    top.Begin(40.0f, 25.0f, 1234u, t);
    top.Seat();

    const float give = top.State().give;
    LeverTo(top, give, t);
    CHECK(top.State().stroke == Stroke::Given);
    CHECK(top.Release(t) == Prise::Clean);
    CHECK(top.State().clean == 1);
    CHECK(top.State().snapped == 0);
}

TEST_CASE("Top: letting go before the give does nothing, and letting go after it snaps her")
{
    const Tuning& t = Tune();
    Top top;
    top.Begin(40.0f, 25.0f, 99u, t);

    top.Seat();
    LeverTo(top, top.State().give * 0.5f, t);
    CHECK(top.Release(t) == Prise::Nothing);

    top.Seat();
    // Well past it — the joint has let go and you are now bending the brick.
    LeverTo(top, 1.0f, t);
    CHECK(top.Release(t) == Prise::Snapped);
    CHECK(top.State().snapped == 1);

    // Nothing that came to nothing counts either way. A miss is time, not a mark against you.
    CHECK(top.State().clean == 0);
}

TEST_CASE("Top: the give belongs to the brick, not to the attempt")
{
    // The whole read-ahead skill rests on this. If a brick's mortar changed between attempts
    // there would be nothing to learn by sounding it, and nothing to read by looking at a course.
    const Tuning& t = Tune();
    Top a;
    a.Begin(40.0f, 25.0f, 7u, t);
    const float first = a.State().give;

    Top b;
    b.Begin(40.0f, 25.0f, 7u, t);
    CHECK(b.State().give == doctest::Approx(first));

    // And sounding it does not move it either — it only tells you where it already was.
    b.Sound();
    CHECK(b.State().give == doctest::Approx(first));

    // A different seed is a different chimney.
    Top c;
    c.Begin(40.0f, 25.0f, 8u, t);
    CHECK(c.State().give != doctest::Approx(first));
}

TEST_CASE("Top: sounding a joint first buys you a wider window")
{
    const Tuning& t = Tune();
    const float per_ms = 1.0f / (t.GetF("prisePerBrickSeconds") * 1000.0f);
    const float blind = per_ms * t.GetF("giveWindowMs.base");
    const float known = per_ms * t.GetF("giveWindowMs.sharpBolster");
    REQUIRE(known > blind);

    // A release this far past the give is inside the sounded window and outside the blind one,
    // so the same stroke is a clean brick or a broken one depending only on whether you looked.
    const float over = (blind + known) * 0.5f;

    Top blind_go;
    blind_go.Begin(40.0f, 25.0f, 21u, t);
    blind_go.Seat();
    LeverTo(blind_go, blind_go.State().give + over, t);
    CHECK(blind_go.Release(t) == Prise::Snapped);

    Top sounded;
    sounded.Begin(40.0f, 25.0f, 21u, t);
    sounded.Sound();
    sounded.Seat();
    LeverTo(sounded, sounded.State().give + over, t);
    CHECK(sounded.Release(t) == Prise::Clean);
}

TEST_CASE("Top: she gets shorter as the courses come off")
{
    const Tuning& t = Tune();
    Top top;
    top.Begin(40.0f, 25.0f, 3u, t);
    const float course = t.GetF("courseHeightMetres");
    const int per_course = static_cast<int>(
        t.GetF("interactiveBricksPerMetre") * course + 0.5f);
    REQUIRE(per_course > 0);

    CHECK(top.HeightNowM() == doctest::Approx(40.0f));
    CHECK(top.ToGoM() == doctest::Approx(15.0f));

    for (int i = 0; i < per_course; ++i)
    {
        top.Seat();
        LeverTo(top, top.State().give, t);
        REQUIRE(top.Release(t) == Prise::Clean);
    }
    CHECK(top.HeightNowM() == doctest::Approx(40.0f - course));
    CHECK(top.ToGoM() == doctest::Approx(15.0f - course));
    CHECK_FALSE(top.Done());
}

TEST_CASE("Top: the flue fills, and then it jams")
{
    const Tuning& t = Tune();
    Top top;
    top.Begin(40.0f, 25.0f, 5u, t);
    CHECK_FALSE(top.State().jammed);

    for (int i = 0; i < t.GetI("jamAfterBricksMost"); ++i)
    {
        top.Drop(true, t);
    }
    CHECK(top.State().jammed);
    CHECK(top.State().flueFullShare > 0.0f);

    // Dropping a weight down on a rope and hauling it back clears it.
    top.ClearJam();
    CHECK_FALSE(top.State().jammed);

    // Over the side does not fill the flue. It is a hazard on the ground instead, which the
    // level decides about, not this.
    const float before = top.State().flueFullShare;
    top.Drop(false, t);
    CHECK(top.State().flueFullShare == doctest::Approx(before));
}

TEST_CASE("Top: the grade is the share that came out whole, and a job left standing is abandoned")
{
    const Tuning& t = Tune();
    Top top;
    top.Begin(26.0f, 25.0f, 11u, t);   // a metre of her, to keep the test quick

    // Not finished is not a grade, however well it was going.
    CHECK(top.Judge(1.0f, t) == TopVerdict::Abandoned);

    int guard = 0;
    while (!top.Done() && guard++ < 5000)
    {
        top.Seat();
        LeverTo(top, top.State().give, t);
        top.Release(t);
    }
    REQUIRE(top.Done());
    CHECK(top.CleanShare() == doctest::Approx(1.0f));
    CHECK(top.Judge(1.0f, t) == TopVerdict::Craftsman);

    // And finishing in the dark is not finishing.
    CHECK(top.Judge(0.0f, t) == TopVerdict::Abandoned);
}
