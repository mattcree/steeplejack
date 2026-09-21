// Bringing a leaning chimney back upright — the STRAIGHTEN archetype.
//
// The keystone job, and the only one in the campaign where the skyline is the same at the end as
// at the start. Two properties matter more than the others and both come straight out of the 1885
// case studies rather than out of taste:
//
//   * the arithmetic has to be the arithmetic the trade did — a quarter of an inch at the cut is
//     seven inches at the top of a 132 ft shaft, and the player has to be able to read that BEFORE
//     committing, because the verb is deciding rather than aiming;
//   * and she overshoots afterwards, for weeks, so the aim is not plumb.

#include "doctest.h"

#include "Straighten.h"
#include "Tuning.h"

#include <cmath>
#include <filesystem>
#include <string>

using sj::PlumbVerdict;
using sj::Straighten;
using sj::StraightenPlan;
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

}  // namespace

TEST_CASE("Straighten: the lean is stated the way the owner states it")
{
    const Tuning& t = Tune();
    Straighten s;
    // 48 m and 2.4 degrees over: about two metres out at the top, which is "she is six foot out
    // of upright" in the words anybody would actually use.
    s.Begin(48.0f, 2.4f, t);
    CHECK(s.State().leanAtTopM == doctest::Approx(48.0f * std::sin(2.4f * 0.017453292f)));
    CHECK(s.State().leanAtTopM > 2.0f);
    CHECK(s.State().leanAtTopM < 2.1f);
}

TEST_CASE("Straighten: the leverage is the trade's own arithmetic")
{
    const Tuning& t = Tune();
    Straighten s;
    // The 1875 job: 132 ft (40.2 m) octagonal, platform at 40 ft (12.2 m), wall 2 ft thick at the
    // cut, and "it had been calculated that 1/4 inch would bring the stack back 7 inches at top".
    s.Begin(40.2f, 3.0f, t);
    // A quarter inch is 6.35 mm. For that to give 7 inches (0.178 m) of top movement over the
    // 28 m above the cut, the lever arm is about a metre — which is the RADIUS of a shaft of that
    // size, not its diameter: the course comes out of one side and the uncut side is the hinge.
    const StraightenPlan p = s.Plan(12.2f, 6.35f, 1.0f, t);
    CHECK(p.bringsBackM == doctest::Approx(0.178f).epsilon(0.05));
    // And the plan is pure: reading it changes nothing.
    CHECK(s.State().leanAtTopM == doctest::Approx(s.State().startedAtM));
}

TEST_CASE("Straighten: cut higher and a little goes further, which is the whole decision")
{
    const Tuning& t = Tune();
    Straighten s;
    s.Begin(48.0f, 2.4f, t);

    const StraightenPlan low = s.Plan(4.0f, 6.0f, 1.2f, t);
    const StraightenPlan high = s.Plan(24.0f, 6.0f, 1.2f, t);
    CHECK(low.bringsBackM > high.bringsBackM);      // more shaft above a low cut
    CHECK(low.riskShare < high.riskShare);          // and less swinging about while it comes back
}

TEST_CASE("Straighten: a cut too high does not bring her back, it brings her down")
{
    const Tuning& t = Tune();
    Straighten s;
    s.Begin(48.0f, 2.4f, t);
    // Right at the top of what the method allows. A straightening in 1873 toppled while the man
    // who had ordered it watched from a hill, and the inquest blamed how it was cut.
    const StraightenPlan reckless = s.Plan(48.0f * 0.75f, 8.0f, 1.2f, t);
    CHECK(reckless.riskShare > t.GetF("straightenCollapseRisk"));
    REQUIRE(s.Cut(reckless, t));
    CHECK(s.State().collapsed);
    CHECK(s.Settled(t).verdict == PlumbVerdict::Down);
}

TEST_CASE("Straighten: the wedges come out smallest first and she comes back as they do")
{
    const Tuning& t = Tune();
    Straighten s;
    s.Begin(48.0f, 2.4f, t);
    const float out_at_start = s.State().leanAtTopM;

    const StraightenPlan p = s.Plan(6.0f, 3.0f, 1.2f, t);
    REQUIRE(s.Cut(p, t));
    CHECK(s.State().settling);
    CHECK(s.State().swayCm > 0.0f);   // the slit opening and closing while she moves

    s.DrawWedge(0.5f, t);
    CHECK(s.State().leanAtTopM < out_at_start);
    CHECK(s.State().leanAtTopM > out_at_start - p.bringsBackM);

    s.DrawWedge(1.0f, t);
    CHECK(s.State().leanAtTopM == doctest::Approx(out_at_start - p.bringsBackM));
}

TEST_CASE("Straighten: she settles over about a day, and stops swaying when she stops moving")
{
    const Tuning& t = Tune();
    Straighten s;
    s.Begin(48.0f, 2.4f, t);
    const StraightenPlan p = s.Plan(6.0f, 3.0f, 1.2f, t);
    REQUIRE(s.Cut(p, t));
    CHECK(s.State().swayCm > 0.0f);

    s.Step(t.GetF("straightenSettleHours") * 0.5f, t);
    CHECK(s.State().settling);
    CHECK(s.State().settledM > 0.0f);
    CHECK(s.State().settledM < p.bringsBackM);

    s.Step(t.GetF("straightenSettleHours"), t);
    CHECK_FALSE(s.State().settling);
    CHECK(s.State().swayCm == doctest::Approx(0.0f));
}

TEST_CASE("Straighten: the aim is not plumb, because she keeps going for weeks afterwards")
{
    const Tuning& t = Tune();
    Straighten s;
    s.Begin(48.0f, 2.4f, t);
    const float out_at_start = s.State().leanAtTopM;

    // Cut for EXACTLY the lean, which is the obvious thing to do and is wrong.
    const StraightenPlan p = s.Plan(6.0f, 1.0f, 1.2f, t);
    const float exact_mm = out_at_start / std::max(p.leverage, 1.0e-6f);
    const StraightenPlan perfect = s.Plan(6.0f, exact_mm, 1.2f, t);
    CHECK(perfect.bringsBackM == doctest::Approx(out_at_start).epsilon(0.02));

    Straighten a;
    a.Begin(48.0f, 2.4f, t);
    REQUIRE(a.Cut(perfect, t));
    a.Step(t.GetF("straightenSettleHours") * 2.0f, t);
    // On the day she looks right. Weeks later she is leaning the other way.
    const sj::StraightenState done = a.Settled(t);
    CHECK(done.leanAtTopM < 0.0f);
    CHECK(done.verdict == PlumbVerdict::Worse);

    // Aiming short of plumb by the overshoot is what actually gets her upright.
    Straighten b;
    b.Begin(48.0f, 2.4f, t);
    const float allow = 1.0f + t.GetF("straightenOvershootShare");
    const StraightenPlan wise = b.Plan(6.0f, exact_mm / allow, 1.2f, t);
    REQUIRE(b.Cut(wise, t));
    b.Step(t.GetF("straightenSettleHours") * 2.0f, t);
    CHECK(b.Settled(t).verdict == PlumbVerdict::Upright);
}

TEST_CASE("Straighten: doing too little leaves her standing, and it is not a failure")
{
    const Tuning& t = Tune();
    Straighten s;
    s.Begin(48.0f, 2.4f, t);
    const StraightenPlan timid = s.Plan(6.0f, 0.4f, 1.2f, t);
    REQUIRE(s.Cut(timid, t));
    s.Step(t.GetF("straightenSettleHours") * 2.0f, t);
    const sj::StraightenState done = s.Settled(t);
    CHECK(done.leanAtTopM > 0.0f);          // still over the way she was
    CHECK(done.verdict == PlumbVerdict::Standing);
    CHECK_FALSE(done.collapsed);
}
