// The joint grid — STRUCT-002.
//
// Before this, a joint was a hash of the height and the level's bands were ignored. These tests are
// mostly about the one property that made that invisible: **the band decides the brickwork**. A
// designer who writes `perished: 0.42` has to get a band that is 42% perished, not a band that
// looks exactly like the one below it.

#include "doctest.h"

#include "JointGrid.h"
#include "Level.h"
#include "Rng.h"
#include "Tuning.h"
#include "Types.h"
#include "Verbs/Tap.h"

#include <array>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <string>

using sj::JointGrid;
using sj::JointTier;
using sj::LevelData;
using sj::Rng;
using sj::Tuning;

namespace {

constexpr float kWest = 270.0f;   // the ladder face in the game: chimney.gd's FACE is -X

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

LevelData Level(const char* id)
{
    return LevelData::LoadFrom(DataDir("levels") + "/" + id + ".json");
}

JointGrid Grid(const LevelData& l, uint64_t seed = 1000)
{
    return JointGrid::Generate(l, Rng(seed), Tune(), kWest);
}

bool Same(const sj::Joint& a, const sj::Joint& b)
{
    return a.id == b.id && a.tier == b.tier && a.quality == b.quality && a.height == b.height
           && a.pos.x == b.pos.x && a.pos.z == b.pos.z;
}

}  // namespace

TEST_CASE("JointGrid: acceptance 1, the same seed makes the same grid")
{
    const LevelData l = Level("00-greybox");
    const JointGrid a = Grid(l);
    const JointGrid b = Grid(l);
    REQUIRE(a.Count() == b.Count());
    REQUIRE(a.Count() > 1000);   // a 55 m stack at four joints a square metre is thousands
    for (int32_t i = 0; i < a.Count(); ++i)
    {
        REQUIRE(Same(a.ById(i), b.ById(i)));
        REQUIRE(a.Apparent(i) == b.Apparent(i));
    }
    // And a different seed is a different stack.
    const JointGrid c = Grid(l, 9999);
    int differ = 0;
    for (int32_t i = 0; i < a.Count(); ++i)
    {
        differ += (a.ById(i).tier != c.ById(i).tier) ? 1 : 0;
    }
    CHECK(differ > a.Count() / 10);
}

TEST_CASE("JointGrid: acceptance 2, each band is the distribution its author wrote")
{
    // The bug this replaces: every band played the same. Checked for every band of both MVP levels.
    for (const char* id : {"00-greybox", "01-back-yard"})
    {
        const LevelData l = Level(id);
        const JointGrid g = Grid(l);
        for (const sj::BandSpec& band : l.Bands())
        {
            std::array<int, 4> seen{};
            int total = 0;
            for (int32_t i = 0; i < g.Count(); ++i)
            {
                const sj::Joint& j = g.ById(i);
                if (band.Contains(j.height))
                {
                    ++seen[static_cast<std::size_t>(j.tier)];
                    ++total;
                }
            }
            REQUIRE(total > 0);
            const std::array<float, 4> want = {band.cracked, band.perished, band.fair, band.sound};
            // Authored joints are re-tiered after the draw, so allow for them on top of the 2%.
            const float slack = 0.02f
                + static_cast<float>(band.forceCrackedAt.size() + band.forcePerishedAt.size())
                      / static_cast<float>(total);
            for (std::size_t k = 0; k < 4; ++k)
            {
                const float got = static_cast<float>(seen[k]) / static_cast<float>(total);
                CAPTURE(id);
                CAPTURE(band.type);
                CAPTURE(k);
                CHECK(std::fabs(got - want[k]) <= slack);
            }
        }
    }
}

TEST_CASE("JointGrid: the perished band really is worse than the plain one")
{
    // The same claim as acceptance 2, stated the way a player would notice it.
    const LevelData l = Level("00-greybox");
    const JointGrid g = Grid(l);
    auto sound_share = [&](float lo, float hi) {
        int sound = 0, total = 0;
        for (int32_t i = 0; i < g.Count(); ++i)
        {
            const sj::Joint& j = g.ById(i);
            if (j.height >= lo && j.height < hi)
            {
                sound += (j.tier == JointTier::Sound) ? 1 : 0;
                ++total;
            }
        }
        return static_cast<float>(sound) / static_cast<float>(total);
    };
    CHECK(sound_share(0.0f, 16.0f) > sound_share(42.0f, 55.0f) * 2.5f);
}

TEST_CASE("JointGrid: a joint's tier and quality never disagree")
{
    const JointGrid g = Grid(Level("00-greybox"));
    for (int32_t i = 0; i < g.Count(); ++i)
    {
        const sj::Joint& j = g.ById(i);
        REQUIRE(sj::tap::TierOf(j.quality, Tune()) == j.tier);
    }
}

TEST_CASE("JointGrid: acceptance 3, level 1's authored cracked joint is where it was put")
{
    // The Back Yard puts a cracked joint on the obvious climbing line at 7 m, so that every player
    // meets one early, taps it, and learns what a rattle means before it can hurt them.
    const LevelData l = Level("01-back-yard");
    const JointGrid g = Grid(l);
    const float r = l.Structure().baseRadius
        + (l.Structure().topRadius - l.Structure().baseRadius) * (7.0f / l.Structure().height);
    const sj::Vec3 at{-r, 7.0f, 0.0f};   // west, on the ladder line

    const int32_t id = g.Nearest(at, 0.1f);
    REQUIRE(id >= 0);
    CHECK(g.ById(id).tier == JointTier::Cracked);
    CHECK(std::fabs(g.ById(id).height - 7.0f) <= 0.1f);

    // And the two authored perished ones.
    for (float h : {7.2f, 9.1f})
    {
        const float rh = l.Structure().baseRadius
            + (l.Structure().topRadius - l.Structure().baseRadius) * (h / l.Structure().height);
        const int32_t p = g.Nearest(sj::Vec3{-rh, h, 0.0f}, 0.1f);
        REQUIRE(p >= 0);
        CHECK(g.ById(p).tier == JointTier::Perished);
    }
}

TEST_CASE("JointGrid: acceptance 4, a bad id is a null object and not a crash")
{
    const JointGrid g = Grid(Level("00-greybox"));
    const sj::Joint& none = g.ById(-1);
    CHECK(none.id == -1);
    // The worst joint in the game, so anything that forgets to check fails loudly.
    CHECK(none.tier == JointTier::Cracked);
    CHECK(g.ById(g.Count() + 5).id == -1);
    CHECK(g.Nearest(sj::Vec3{500.0f, 500.0f, 500.0f}, 1.0f) == -1);
}

TEST_CASE("JointGrid: acceptance 5, a 110 m stack generates in under 50 ms")
{
    // Built from the Grey Box with its height doubled, which is the tallest thing in the campaign.
    std::string json = R"({"id":"tall","name":"Tall","order":99,"archetype":"CLIMB",
        "structure":{"type":"chimney","height":110.0,"baseRadius":3.4,"topRadius":1.9,
            "jointGrid":{"courseHeight":0.075,"brickLength":0.225,"candidateDensity":4.0}},
        "bands":[{"from":0.0,"to":110.0,"type":"plain",
            "quality":{"sound":0.6,"fair":0.3,"perished":0.08,"cracked":0.02}}]})";
    const LevelData l = LevelData::Parse(json, "tall");

    const auto t0 = std::chrono::steady_clock::now();   // test code, not the sim: allowed
    const JointGrid g = Grid(l);
    const auto ms = std::chrono::duration<double, std::milli>(
        std::chrono::steady_clock::now() - t0).count();
    CAPTURE(g.Count());
    CHECK(ms < 50.0);
}

TEST_CASE("JointGrid: acceptance 6, another subsystem drawing random numbers moves nothing")
{
    // The grid forks its own stream and never draws from the parent, so any other system taking
    // numbers from the same parent — in any order — cannot shift a single joint. Without that,
    // adding a feature would silently rebuild every chimney in every recorded replay.
    const LevelData l = Level("00-greybox");
    Rng parent(1000);
    const JointGrid before = JointGrid::Generate(l, parent, Tune(), kWest);

    Rng other = parent.Fork(0x57494E44u);   // the weather, say
    for (int i = 0; i < 1000; ++i)
    {
        (void)other.NextU32();
    }
    const JointGrid after = JointGrid::Generate(l, parent, Tune(), kWest);

    REQUIRE(before.Count() == after.Count());
    for (int32_t i = 0; i < before.Count(); ++i)
    {
        REQUIRE(Same(before.ById(i), after.ById(i)));
    }
}

// ---------------------------------------------------------------- the tell

TEST_CASE("JointGrid: the look narrows a joint to about two tiers, and never lies by more")
{
    // 02-climbing-system.md §1: "from 3 m the player can narrow it to two tiers; only the tap test
    // disambiguates." So the look is never exact, and never wildly wrong.
    const LevelData l = Level("00-greybox");
    const JointGrid g = Grid(l);
    const float noise = Tune().GetF("jointTellNoise");

    int exact = 0, total = 0;
    for (int32_t i = 0; i < g.Count(); ++i)
    {
        const sj::Joint& j = g.ById(i);
        if (j.height >= 16.0f)
        {
            continue;   // the plain band only: full reliability
        }
        ++total;
        CHECK(std::fabs(g.Apparent(i) - j.quality) <= noise + 1e-5f);
        exact += (sj::tap::TierOf(g.Apparent(i), Tune()) == j.tier) ? 1 : 0;
    }
    // Usually right, often not — which is the only thing that makes the tap worth its time.
    const float right = static_cast<float>(exact) / static_cast<float>(total);
    CHECK(right > 0.5f);
    CHECK(right < 0.95f);
}

TEST_CASE("JointGrid: in salt bloom the look tells you nothing")
{
    // The Grey Box's salt-bloom band sets visualReadReliability to 0. There the look must carry no
    // information about the truth at all, and the tap is the only instrument. Measured as the
    // correlation between how a joint looks and what it is.
    const JointGrid g = Grid(Level("00-greybox"));
    auto correlation = [&](float lo, float hi) {
        double sx = 0, sy = 0, sxx = 0, syy = 0, sxy = 0;
        int n = 0;
        for (int32_t i = 0; i < g.Count(); ++i)
        {
            const sj::Joint& j = g.ById(i);
            if (j.height < lo || j.height >= hi)
            {
                continue;
            }
            const double x = j.quality, y = g.Apparent(i);
            sx += x; sy += y; sxx += x * x; syy += y * y; sxy += x * y;
            ++n;
        }
        const double cov = sxy / n - (sx / n) * (sy / n);
        const double vx = sxx / n - (sx / n) * (sx / n);
        const double vy = syy / n - (sy / n) * (sy / n);
        return cov / std::sqrt(vx * vy);
    };
    CHECK(correlation(0.0f, 16.0f) > 0.7);           // plain: the look is a good guide
    CHECK(std::fabs(correlation(16.0f, 30.0f)) < 0.15);   // salt bloom: it is noise
}

TEST_CASE("JointGrid: clustering gathers sound joints into patches")
{
    // The Grey Box's perished band clusters its sound joints at 0.7, so that finding one is a clue
    // to where the next is. Measured as how often a sound joint's nearest neighbour is also sound,
    // against the same band with clustering off.
    auto neighbour_rate = [&](float clustering) {
        std::string json = R"({"id":"c","name":"C","order":99,"archetype":"CLIMB",
            "structure":{"type":"chimney","height":20.0,"baseRadius":2.6,"topRadius":2.4,
                "jointGrid":{"courseHeight":0.075,"brickLength":0.225,"candidateDensity":4.0}},
            "bands":[{"from":0.0,"to":20.0,"type":"perished",
                "quality":{"sound":0.2,"fair":0.3,"perished":0.42,"cracked":0.08},
                "params":{"soundJointClustering":)" + std::to_string(clustering) + "}}]}";
        const LevelData l = LevelData::Parse(json, "c");
        const JointGrid g = Grid(l);
        int sound = 0, together = 0;
        for (int32_t i = 0; i < g.Count(); ++i)
        {
            if (g.ById(i).tier != JointTier::Sound)
            {
                continue;
            }
            ++sound;
            int32_t best = -1;
            float best_d = 1e9f;
            for (int32_t k = 0; k < g.Count(); ++k)
            {
                if (k == i)
                {
                    continue;
                }
                const sj::Vec3 a = g.ById(i).pos, b = g.ById(k).pos;
                const float d = (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
                                + (a.z - b.z) * (a.z - b.z);
                if (d < best_d)
                {
                    best_d = d;
                    best = k;
                }
            }
            together += (g.ById(best).tier == JointTier::Sound) ? 1 : 0;
        }
        return static_cast<float>(together) / static_cast<float>(sound);
    };
    CHECK(neighbour_rate(0.7f) > neighbour_rate(0.0f) * 1.5f);
}

TEST_CASE("JointGrid: Near finds what is in reach and nothing else")
{
    const LevelData l = Level("00-greybox");
    const JointGrid g = Grid(l);
    const float reach = Tune().GetF("tapTestMaxRangeMetres");
    const std::vector<int32_t> near = g.Near(20.0f, kWest, reach);
    REQUIRE(near.size() > 20);   // a working position should offer a real choice
    for (int32_t id : near)
    {
        CHECK(std::fabs(g.ById(id).height - 20.0f) <= reach + 1e-4f);
        CHECK(g.ById(id).pos.x < 0.0f);   // all on the west face, near the ladder
    }
}

TEST_CASE("JointGrid: an occupied joint is not offered for a second dog")
{
    const LevelData l = Level("00-greybox");
    JointGrid g = Grid(l);
    const sj::Vec3 at{-2.4f, 10.0f, 0.0f};
    const int32_t first = g.Nearest(at, 2.0f);
    REQUIRE(first >= 0);
    g.SetOccupied(first, true);
    const int32_t second = g.Nearest(at, 2.0f);
    CHECK(second >= 0);
    CHECK(second != first);
}
