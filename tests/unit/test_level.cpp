// Level tests — CORE-008.
//
// The interesting test in this file is the last one. `LevelData::Validate()` and
// `tools/validate_data.py` enforce the same rules for different moments — the Python one in a
// pre-commit hook with no compiler, the C++ one in the game — and two implementations of one rule
// set is exactly the arrangement that drifts. So the last test runs both over the same fixtures and
// compares. Everything above it is there to make a failure in that test easy to localise.

#include "doctest.h"

#include "Json.h"
#include "Level.h"

#include <algorithm>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

using sj::BandSpec;
using sj::JsonError;
using sj::LevelData;

namespace {

std::filesystem::path RepoRoot()
{
    namespace fs = std::filesystem;
    fs::path here = fs::current_path();
    for (int up = 0; up < 5; ++up)
    {
        if (fs::is_directory(here / "data" / "levels") && fs::is_directory(here / "tools"))
        {
            return here;
        }
        if (!here.has_parent_path())
        {
            break;
        }
        here = here.parent_path();
    }
    return {};
}

LevelData Waterside()
{
    return LevelData::LoadFrom((RepoRoot() / "data" / "levels" / "06-waterside.json").string());
}

std::vector<std::filesystem::path> Fixtures()
{
    std::vector<std::filesystem::path> out;
    const std::filesystem::path dir = RepoRoot() / "tests" / "fixtures" / "levels";
    if (!std::filesystem::is_directory(dir))
    {
        return out;
    }
    for (const auto& entry : std::filesystem::directory_iterator(dir))
    {
        if (entry.path().extension() == ".json")
        {
            out.push_back(entry.path());
        }
    }
    std::sort(out.begin(), out.end());
    return out;
}

// Run the Python validator on one file and return its error count, or -1 if it could not be run.
int PythonErrorCount(const std::filesystem::path& level)
{
    const std::string command = "cd '" + RepoRoot().string() +
                                "' && python3 tools/validate_data.py --level '" + level.string() +
                                "' 2>/dev/null";
    FILE* pipe = popen(command.c_str(), "r");
    if (pipe == nullptr)
    {
        return -1;
    }
    char buffer[256] = {};
    std::string out;
    while (std::fgets(buffer, sizeof(buffer), pipe) != nullptr)
    {
        out += buffer;
    }
    const int status = pclose(pipe);
    if (status == -1 || out.empty())
    {
        return -1;
    }
    // "N error(s)"
    try
    {
        return std::stoi(out);
    }
    catch (const std::exception&)
    {
        return -1;
    }
}

}  // namespace

TEST_CASE("Level: Acceptance 1: both shipped levels load and validate clean")
{
    REQUIRE_MESSAGE(!RepoRoot().empty(), "could not locate the repo root from the working directory");

    for (const auto& entry :
         std::filesystem::directory_iterator(RepoRoot() / "data" / "levels"))
    {
        if (entry.path().extension() != ".json")
        {
            continue;
        }
        const LevelData level = LevelData::LoadFrom(entry.path().string());

        CHECK_FALSE(level.Id().empty());
        CHECK(level.TotalHeight() > 0.0f);
        CHECK_FALSE(level.Bands().empty());

        const std::vector<std::string> errors = level.Validate();
        INFO("level: ", entry.path().filename().string());
        for (const std::string& e : errors)
        {
            INFO("  ", e);
        }
        CHECK(errors.empty());
    }
}

TEST_CASE("Level: Acceptance 5: BandAt(37.0) on 06-waterside is the existing-band")
{
    const LevelData level = Waterside();

    CHECK(level.BandAt(37.0f).type == "existing-band");

    // The boundaries, because a half-open range is the difference between standing on the ivy and
    // standing in it. 36.0 is where existing-band starts; 52.0 is where it ends.
    CHECK(level.BandAt(35.9f).type == "ivy");
    CHECK(level.BandAt(36.0f).type == "existing-band");
    CHECK(level.BandAt(51.9f).type == "existing-band");
    CHECK(level.BandAt(52.0f).type == "wind-band");

    CHECK(level.BandAt(0.0f).type == "plain");
    CHECK(level.BandAt(level.TotalHeight()).type == "wind-band");   // the top belongs to the top band
}

TEST_CASE("Level: a height outside the structure throws rather than guessing a band")
{
    const LevelData level = Waterside();

    // Returning the nearest band would put a climber in brickwork that is not there, and every
    // caller downstream would believe it.
    CHECK_THROWS_AS(level.BandAt(-1.0f), JsonError);
    CHECK_THROWS_AS(level.BandAt(level.TotalHeight() + 1.0f), JsonError);
}

TEST_CASE("Level: the structure and site parse into typed data")
{
    const LevelData level = Waterside();

    CHECK(level.Id() == "06-waterside");
    CHECK(level.Archetype() == "FELL");
    CHECK(level.TotalHeight() == doctest::Approx(70.0f));
    CHECK(level.Structure().type == "chimney");
    CHECK(level.Structure().baseRadius == doctest::Approx(3.2f));
    CHECK(level.Structure().courseHeight == doctest::Approx(0.075f));
    CHECK(level.Structure().weatherSeed == 4471u);

    CHECK(level.Site().hasCorridor);
    CHECK(level.Site().exclusions.size() == 2);
    CHECK(level.Site().safeLineDistance > 0.0f);

    // Bands in file order, contiguous, reaching the top.
    REQUIRE(level.Bands().size() == 4);
    CHECK(level.Bands().front().from == doctest::Approx(0.0f));
    CHECK(level.Bands().back().to == doctest::Approx(level.TotalHeight()));
    for (std::size_t i = 1; i < level.Bands().size(); ++i)
    {
        CHECK(level.Bands()[i].from == doctest::Approx(level.Bands()[i - 1].to));
    }
}

TEST_CASE("Level: a fall corridor that wraps through north still contains its bearings")
{
    // 340 -> 20 is a real corridor and the naive `lo <= b <= hi` rejects every bearing in it. The
    // Python validator has the same branch; this is the case that would diverge first.
    sj::SiteSpec site;
    site.hasCorridor = true;
    site.corridorFrom = 340;
    site.corridorTo = 20;

    CHECK(site.InCorridor(350));
    CHECK(site.InCorridor(10));
    CHECK(site.InCorridor(0));
    CHECK_FALSE(site.InCorridor(180));
    CHECK_FALSE(site.InCorridor(21));
    CHECK_FALSE(site.InCorridor(339));

    sj::SiteSpec plain;
    plain.hasCorridor = true;
    plain.corridorFrom = 250;
    plain.corridorTo = 320;
    CHECK(plain.InCorridor(285));
    CHECK_FALSE(plain.InCorridor(10));
}

TEST_CASE("Level: Acceptance 2: a 25 m plain band fails the Ascent Beat Rule")
{
    const LevelData level =
        LevelData::LoadFrom((RepoRoot() / "tests/fixtures/levels/plain-band-too-long.json").string());

    const std::vector<std::string> errors = level.Validate();
    REQUIRE(errors.size() == 1);
    CHECK(errors[0].find("Ascent Beat Rule") != std::string::npos);
    CHECK(errors[0].find("25.0m") != std::string::npos);
}

TEST_CASE("Level: Acceptance 3: a quality distribution summing to 1.35 fails")
{
    const LevelData level =
        LevelData::LoadFrom((RepoRoot() / "tests/fixtures/levels/quality-sums-wrong.json").string());

    const std::vector<std::string> errors = level.Validate();
    REQUIRE(errors.size() == 1);
    // Four decimal places, as validate_data.py prints it: a distribution wrong by 0.002 must
    // not round to "1.0" in the message that says it is not 1.0.
    CHECK(errors[0].find("quality sums to 1.3500") != std::string::npos);
    CHECK(errors[0].find("must be 1.0") != std::string::npos);
}

TEST_CASE("Level: Acceptance 4: an exclusion inside the fall corridor fails")
{
    const LevelData level = LevelData::LoadFrom(
        (RepoRoot() / "tests/fixtures/levels/exclusion-in-corridor.json").string());

    const std::vector<std::string> errors = level.Validate();
    REQUIRE(errors.size() == 1);
    CHECK(errors[0].find("fall corridor") != std::string::npos);
    CHECK(errors[0].find("unwinnable") != std::string::npos);
}

TEST_CASE("Level: bands that do not meet, and bands that stop short of the top")
{
    const LevelData gap =
        LevelData::LoadFrom((RepoRoot() / "tests/fixtures/levels/bands-not-contiguous.json").string());
    REQUIRE(gap.Validate().size() == 1);
    CHECK(gap.Validate()[0].find("contiguous") != std::string::npos);

    const LevelData shortOfTop =
        LevelData::LoadFrom((RepoRoot() / "tests/fixtures/levels/bands-short-of-top.json").string());
    REQUIRE(shortOfTop.Validate().size() == 1);
    CHECK(shortOfTop.Validate()[0].find("but the structure is") != std::string::npos);
}

TEST_CASE("Level: a FELL level with the safe line too close fails")
{
    const LevelData level =
        LevelData::LoadFrom((RepoRoot() / "tests/fixtures/levels/safe-line-too-close.json").string());

    const std::vector<std::string> errors = level.Validate();
    REQUIRE(errors.size() == 1);
    CHECK(errors[0].find("safeLineDistance") != std::string::npos);
    CHECK(errors[0].find("1.5x height") != std::string::npos);
}

TEST_CASE("Level: Validate never throws, whatever it is handed")
{
    // A broken level must be *reportable*, not fatal: the editor tooling has to be able to show a
    // designer what is wrong with the file they are editing, and it cannot do that from a crash.
    CHECK_NOTHROW((void)LevelData::Parse(R"({})", "empty.json").Validate());
    CHECK_NOTHROW((void)LevelData::Parse(R"({"bands": []})", "nobands.json").Validate());
    CHECK_NOTHROW((void)LevelData::Parse(R"({"archetype": "FELL"})", "fell.json").Validate());
    CHECK_NOTHROW((void)LevelData::Parse(R"({"bands": [{"from": 0, "to": 5}]})", "t.json").Validate());

    // A FELL level with no corridor at all is an error, not a crash.
    const std::vector<std::string> errors =
        LevelData::Parse(R"({"archetype": "FELL"})", "fell.json").Validate();
    CHECK(errors.size() >= 1);
}

TEST_CASE("Level: Acceptance 6: C++ Validate() and validate_data.py agree on every fixture")
{
    // The test this file exists for. Two implementations of one rule set is the arrangement that
    // drifts, and it drifts silently: each one keeps passing its own tests while they diverge.
    const std::vector<std::filesystem::path> fixtures = Fixtures();
    REQUIRE_MESSAGE(fixtures.size() >= 6, "fixtures missing from tests/fixtures/levels");

    int compared = 0;
    for (const std::filesystem::path& fixture : fixtures)
    {
        const int python = PythonErrorCount(fixture);
        if (python < 0)
        {
            WARN_MESSAGE(false, "could not run validate_data.py — parity unchecked for "
                                    << fixture.filename().string());
            continue;
        }
        ++compared;

        const std::size_t cpp = LevelData::LoadFrom(fixture.string()).Validate().size();
        INFO("fixture: ", fixture.filename().string());
        CHECK(static_cast<int>(cpp) == python);
    }

    // If python could not be run at all, this test proves nothing and must say so rather than
    // passing quietly — the same rule TEST-003 applied to filtered test gates.
    CHECK_MESSAGE(compared > 0, "validate_data.py could not be run for any fixture");
}
