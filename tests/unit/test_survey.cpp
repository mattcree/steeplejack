// Going up to look at it — the SURVEY archetype.
//
// Three levels have shipped with `mission.defects` authored and nothing reading them, so a survey
// job has been "climb to the top" with a briefing promising something else. These pin the four
// ways a thing can be found, because the discovery method is the entire texture of the archetype:
// if TAP can be satisfied by standing near it, the tap test has no job here, and if TRAVERSE can
// be satisfied from the near side there is no reason to go round.

#include "doctest.h"

#include "Survey.h"
#include "Tuning.h"

#include <filesystem>
#include <string>
#include <vector>

using sj::Defect;
using sj::FindBy;
using sj::Survey;
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

Defect At(const char* id, float h, int32_t bearing, FindBy how)
{
    Defect d{};
    d.id = id;
    d.height = h;
    d.bearing = bearing;
    d.how = how;
    return d;
}

}  // namespace

TEST_CASE("Survey: the level file's words become the four ways of finding a thing")
{
    CHECK(sj::FindByName("visual") == FindBy::Visual);
    CHECK(sj::FindByName("tap") == FindBy::Tap);
    CHECK(sj::FindByName("summit") == FindBy::Summit);
    CHECK(sj::FindByName("traverse") == FindBy::Traverse);
    // Anything the game does not know is looked at rather than ignored — a defect nobody can find
    // is worse than one found the easy way.
    CHECK(sj::FindByName("haruspicy") == FindBy::Visual);
}

TEST_CASE("Survey: a visual defect wants you close and on the right side of her")
{
    const Tuning& t = Tune();
    Survey s;
    s.Begin({At("cracked_course", 7.0f, 0, FindBy::Visual)});

    CHECK(s.Look(20.0f, 0, false, false, t) == -1);    // right side, far too high
    CHECK(s.Look(7.0f, 180, false, false, t) == -1);   // right height, other side of her
    CHECK(s.Look(7.0f, 0, false, false, t) == 0);      // there it is
    CHECK(s.Report().found == 1);
    // And it is not found twice.
    CHECK(s.Look(7.0f, 0, false, false, t) == -1);
}

TEST_CASE("Survey: a tap defect cannot be found by standing next to it")
{
    const Tuning& t = Tune();
    Survey s;
    s.Begin({At("perished_band", 9.0f, 0, FindBy::Tap)});

    // This is the assertion that gives the tap test a job in this archetype. Looking is not enough
    // — the note tells you and the eye cannot.
    CHECK(s.Look(9.0f, 0, false, false, t) == -1);
    CHECK(s.Look(9.0f, 0, false, true, t) == 0);
}

TEST_CASE("Survey: a summit defect is what makes the climb the job")
{
    const Tuning& t = Tune();
    Survey s;
    s.Begin({At("jackdaw_nest", 12.0f, 0, FindBy::Summit)});

    CHECK(s.Look(11.5f, 0, false, true, t) == -1);   // half a metre short, and tapping does not help
    CHECK(s.Look(12.0f, 0, true, false, t) == 0);    // on the cap
}

TEST_CASE("Survey: a traverse defect is off your line, and that is the point of it")
{
    const Tuning& t = Tune();
    Survey s;
    // Bearings are relative to the climbing line, because that is the only frame a man on one
    // ladder has. 22 degrees round is well inside what shuffling along the face can reach and
    // well outside the window, so it cannot be found by standing where you were.
    s.Begin({At("missing_clip", 8.5f, 22, FindBy::Traverse)});

    CHECK(s.Look(8.5f, 0, false, false, t) == -1);
    CHECK(s.Look(8.5f, -22, false, false, t) == -1);   // round the wrong way
    CHECK(s.Look(8.5f, 22, false, false, t) == 0);
}

TEST_CASE("Survey: the report is a fraction, not a pass")
{
    const Tuning& t = Tune();
    Survey s;
    s.Begin({
        At("a", 5.0f, 0, FindBy::Visual),
        At("b", 9.0f, 0, FindBy::Tap),
        At("c", 12.0f, 0, FindBy::Summit),
        At("d", 8.5f, 22, FindBy::Traverse),
    });

    CHECK(s.Report().total == 4);
    CHECK(s.Report().found == 0);
    CHECK(s.Report().share == doctest::Approx(0.0f));
    CHECK_FALSE(s.Report().complete);

    REQUIRE(s.Look(5.0f, 0, false, false, t) == 0);
    REQUIRE(s.Look(9.0f, 0, false, true, t) == 1);
    CHECK(s.Report().share == doctest::Approx(0.5f));
    // Half a survey is half a survey. It is not a failure and it is not a pass.
    CHECK_FALSE(s.Report().complete);

    REQUIRE(s.Look(12.0f, 0, true, false, t) == 2);
    REQUIRE(s.Look(8.5f, 22, false, false, t) == 3);
    CHECK(s.Report().complete);
    CHECK(s.Report().share == doctest::Approx(1.0f));
}

TEST_CASE("Survey: bearings wrap, so north is not three hundred and sixty degrees from north")
{
    const Tuning& t = Tune();
    Survey s;
    s.Begin({At("x", 6.0f, 350, FindBy::Visual)});
    // Ten degrees apart, not three hundred and fifty.
    CHECK(s.Look(6.0f, 0, false, false, t) == 0);
}
