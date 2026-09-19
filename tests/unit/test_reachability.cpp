// Can a level be climbed? — CORE-009, the acceptance by number.
//
// The shipped levels are solved with their own loadout and the same grid the game builds (the
// level's own seed, the game's climbing line). The broken ones are written here, in full, so each
// says exactly what is wrong with it.

#include "doctest.h"

#include "JointGrid.h"
#include "Level.h"
#include "Reachability.h"
#include "Rng.h"
#include "Tuning.h"

#include <chrono>
#include <filesystem>
#include <string>

using sj::JointGrid;
using sj::LevelData;
using sj::Route;
using sj::Tuning;

namespace {

constexpr float kWest = 270.0f;     // the game's climbing line: chimney.gd's FACE is -X
constexpr float kMaxSpan = 6.0f;    // CORE-009: "spans no worse than 6 m" — the top of Flex

std::string DataDir(const char* leaf)
{
    namespace fs = std::filesystem;
    fs::path here = fs::current_path();
    for (int up = 0; up < 5; ++up)
    {
        if (fs::is_directory(here / "data" / leaf))
        {
            return (here / "data" / leaf).string();
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
    static const Tuning t = Tuning::LoadAll(DataDir("tuning"));
    return t;
}

Route SolveLevel(const LevelData& l, int32_t ladders)
{
    const JointGrid g = JointGrid::Generate(l, sj::Rng(l.Structure().weatherSeed), Tune(), kWest);
    return sj::Solve(g, ladders, kMaxSpan, l.TotalHeight(), kWest, Tune());
}

// A chimney `height` tall with the given bands, as a level file.
LevelData Fixture(float height, const std::string& bands, int ladders)
{
    const std::string h = std::to_string(height);
    const std::string json = R"({
      "id": "fixture", "name": "Fixture", "order": 99, "archetype": "SURVEY",
      "structure": { "type": "chimney", "height": )" + h + R"(, "baseRadius": 2.4, "topRadius": 1.6,
        "profile": "round", "cap": "plain", "leanDegrees": 0.0, "leanBearing": 0,
        "jointGrid": { "courseHeight": 0.075, "brickLength": 0.225, "candidateDensity": 4.0 },
        "weathering": { "seed": 4242 } },
      "bands": [ )" + bands + R"( ],
      "weather": { "windBase": 1.0, "windAtHeight": [[0, 1.0]], "gustIntervalSeconds": null },
      "loadoutHint": { "ladders": )" + std::to_string(ladders) + R"(, "dogs": 40, "rope": 2 }
    })";
    return LevelData::Parse(json, "fixture");
}

std::string Band(float from, float to, const char* quality)
{
    return R"({ "from": )" + std::to_string(from) + R"(, "to": )" + std::to_string(to) +
           R"(, "type": "plain", "quality": )" + quality + " }";
}

const char* kGood = R"({ "sound": 0.7, "fair": 0.3, "perished": 0.0, "cracked": 0.0 })";
const char* kCracked = R"({ "sound": 0.0, "fair": 0.0, "perished": 0.0, "cracked": 1.0 })";

}  // namespace

TEST_CASE("Reachability: acceptance 1 and 4, every shipped level is climbable with its own loadout")
{
    // Every file in data/levels, so a new level is gated the day it is added.
    namespace fs = std::filesystem;
    int levels = 0;
    for (const auto& entry : fs::directory_iterator(DataDir("levels")))
    {
        if (entry.path().extension() != ".json")
        {
            continue;
        }
        const LevelData l = LevelData::LoadFrom(entry.path().string());
        CAPTURE(l.Id());
        REQUIRE(l.LoadoutLadders() > 0);
        const Route r = SolveLevel(l, l.LoadoutLadders());
        CAPTURE(r.reached);
        CAPTURE(r.sections);
        CHECK(r.valid);
        CHECK(r.maxSpan <= kMaxSpan);
        CHECK(r.sections <= l.LoadoutLadders());
        ++levels;
    }
    CHECK(levels >= 2);
}

TEST_CASE("Reachability: acceptance 2, a 9 m band of cracked joints cannot be crossed")
{
    const std::string bands = Band(0.0f, 10.0f, kGood) + ", " + Band(10.0f, 19.0f, kCracked) + ", " +
                              Band(19.0f, 30.0f, kGood);
    const Route r = SolveLevel(Fixture(30.0f, bands, 20), 20);
    CHECK_FALSE(r.valid);
    // It gets as far as the crack and no further — the report says where the level is broken.
    CHECK(r.reached < 19.0f + 1.0f);
    CHECK(r.reached > 10.0f);

    // The control: the same level with the crack healed is climbable.
    const std::string healed = Band(0.0f, 30.0f, kGood);
    CHECK(SolveLevel(Fixture(30.0f, healed, 20), 20).valid);
}

TEST_CASE("Reachability: acceptance 3, too few ladders for the height is not climbable")
{
    const LevelData l = Fixture(40.0f, Band(0.0f, 40.0f, kGood), 3);
    CHECK_FALSE(SolveLevel(l, 3).valid);
    // Four-metre sections from a five-metre standing ladder: 40 m needs nine lashed.
    CHECK(SolveLevel(l, 12).valid);
}

TEST_CASE("Reachability: acceptance 5, a 110 m level solves in under half a second")
{
    const LevelData l = Fixture(110.0f, Band(0.0f, 110.0f, kGood), 40);
    const JointGrid g = JointGrid::Generate(l, sj::Rng(l.Structure().weatherSeed), Tune(), kWest);
    const auto t0 = std::chrono::steady_clock::now();
    const Route r = sj::Solve(g, 40, kMaxSpan, l.TotalHeight(), kWest, Tune());
    const auto ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
    MESSAGE("110 m solved in " << ms << " ms, " << r.sections << " sections");
    CHECK(r.valid);
    CHECK(ms < 500.0);
}

TEST_CASE("Reachability: the span limit is a real limit")
{
    // A 5 m cracked band is crossable at a 6 m span and not at a 4 m one: the solver is reading
    // the limit it is given, not a constant of its own.
    const std::string bands = Band(0.0f, 10.0f, kGood) + ", " + Band(10.0f, 15.0f, kCracked) + ", " +
                              Band(15.0f, 30.0f, kGood);
    const LevelData l = Fixture(30.0f, bands, 20);
    const JointGrid g = JointGrid::Generate(l, sj::Rng(l.Structure().weatherSeed), Tune(), kWest);
    CHECK(sj::Solve(g, 20, 6.0f, 30.0f, kWest, Tune()).valid);
    CHECK_FALSE(sj::Solve(g, 20, 4.0f, 30.0f, kWest, Tune()).valid);
}
