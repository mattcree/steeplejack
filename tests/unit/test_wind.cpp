// Wind and the gust tell — ENV-003.
//
// One of these tests matters more than the rest of the file. The fairness table in
// 10-failure-and-difficulty.md allows "a gust blew you off" as a fair failure **only if the 1.2 s
// audio tell played first**, and says in terms that otherwise it is a bug. That is not a feeling,
// it is a property: the gust's mechanical strength must be exactly zero for the whole of the
// pre-roll. `Gust strength is zero for the whole of the tell` is that sentence as an assertion, and
// it is the reason this module has phases rather than a wind value that ramps.

#include "doctest.h"

#include "Level.h"
#include "Rng.h"
#include "Tuning.h"
#include "Types.h"
#include "Wind.h"

#include <filesystem>
#include <string>

using sj::GustPhase;
using sj::Rng;
using sj::Tuning;
using sj::WeatherSpec;
using sj::WindModel;

namespace {

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

const sj::LevelData& Greybox()
{
    static const sj::LevelData l =
        sj::LevelData::LoadFrom(DataDir("levels") + "/00-greybox.json");
    return l;
}

WeatherSpec Gusty()
{
    WeatherSpec w;
    w.windBase = 4.0f;
    w.windAtHeight = {{0.0f, 1.0f}, {50.0f, 2.0f}};
    w.hasGusts = true;
    w.gustEverySecondsMin = 10.0f;
    w.gustEverySecondsMax = 12.0f;
    return w;
}

}  // namespace

// ---------------------------------------------------------------- the level's own weather

TEST_CASE("Wind: the level file's weather block is actually read")
{
    // It was in every level from the day levels existed and nothing parsed it, so the game passed a
    // hard-coded 9 m/s at every height of every level and the profile a designer wrote did nothing.
    const WeatherSpec& w = Greybox().Weather();
    CHECK(w.windBase == doctest::Approx(3.0f));
    CHECK(w.hasGusts);
    CHECK(w.gustEverySecondsMin == doctest::Approx(50.0f));
    CHECK(w.gustEverySecondsMax == doctest::Approx(95.0f));
}

TEST_CASE("Wind: a null gust interval means a sheltered level, not a gust every frame")
{
    // `"gustIntervalSeconds": null` is how a level says it has no gusts. Read as a range it would
    // be [0, 0] — a gust on every step — which is the difference between a calm level and an
    // unplayable one.
    const sj::LevelData back =
        sj::LevelData::LoadFrom(DataDir("levels") + "/01-back-yard.json");
    CHECK_FALSE(back.Weather().hasGusts);

    WindModel wind;
    Rng rng(7);
    wind.Begin(back.Weather(), rng, Tune());
    for (int i = 0; i < 60 * 600; ++i)   // ten minutes
    {
        wind.Step(sj::kTick, back.Weather(), rng, Tune());
    }
    CHECK(wind.Phase() == GustPhase::Calm);
    CHECK(wind.Strength() == doctest::Approx(0.0f));
    CHECK(wind.SecondsToNextGust() < 0.0f);
}

TEST_CASE("Wind: speed follows the authored height curve and holds flat outside it")
{
    const WeatherSpec w = Gusty();
    CHECK(w.WindAt(0.0f) == doctest::Approx(4.0f));
    CHECK(w.WindAt(50.0f) == doctest::Approx(8.0f));
    CHECK(w.WindAt(25.0f) == doctest::Approx(6.0f));   // halfway up, halfway between

    // Held, not extrapolated. A level that gives a curve to its own top has said everything it
    // means to; carrying on past it invents weather nobody designed.
    CHECK(w.WindAt(-5.0f) == doctest::Approx(4.0f));
    CHECK(w.WindAt(500.0f) == doctest::Approx(8.0f));

    // And it is higher up than down, which is the entire reason nerve scales with altitude.
    CHECK(w.WindAt(50.0f) > w.WindAt(0.0f));
}

// ---------------------------------------------------------------- the fairness property

TEST_CASE("Wind: gust strength is zero for the whole of the tell")
{
    // **The one that matters.** The fairness table allows being blown off only if the 1.2 s cue
    // played first. If strength ever rose while `Tell()` was true, the warning would arrive with
    // the thing it warns about, and the failure would be unfair by the project's own definition.
    const WeatherSpec w = Gusty();
    WindModel wind;
    Rng rng(11);
    wind.Begin(w, rng, Tune());

    bool saw_tell = false;
    float tell_seconds = 0.0f;
    for (int i = 0; i < 60 * 120; ++i)
    {
        wind.Step(sj::kTick, w, rng, Tune());
        if (wind.Tell())
        {
            saw_tell = true;
            tell_seconds += sj::kTick;
            REQUIRE(wind.Strength() == doctest::Approx(0.0f));
        }
    }
    REQUIRE(saw_tell);

    // And the tell is as long as the design says, summed over every gust in two minutes.
    const float per_gust = Tune().GetF("gustPreRollSeconds");
    CHECK(per_gust == doctest::Approx(1.2f));
    const int gusts = static_cast<int>(tell_seconds / per_gust + 0.5f);
    CHECK(gusts >= 1);
    CHECK(tell_seconds == doctest::Approx(static_cast<float>(gusts) * per_gust).epsilon(0.05));
}

TEST_CASE("Wind: nothing bites without a tell in front of it")
{
    // The same property from the other side: every step on which the gust has any strength must
    // have been preceded by a complete tell. This is what a caller actually depends on.
    const WeatherSpec w = Gusty();
    WindModel wind;
    Rng rng(29);
    wind.Begin(w, rng, Tune());

    float tell_run = 0.0f;
    bool any_bite = false;
    for (int i = 0; i < 60 * 200; ++i)
    {
        wind.Step(sj::kTick, w, rng, Tune());
        if (wind.Tell())
        {
            tell_run += sj::kTick;
        }
        else if (wind.Strength() > 0.0f)
        {
            any_bite = true;
            // A full pre-roll happened, and it happened immediately before this.
            CHECK(tell_run >= Tune().GetF("gustPreRollSeconds") - sj::kTick * 2.0f);
        }
        else if (wind.Phase() == GustPhase::Calm)
        {
            tell_run = 0.0f;   // calm again; the next gust needs its own warning
        }
    }
    CHECK(any_bite);
}

TEST_CASE("Wind: the phases run in order and come back to calm")
{
    const WeatherSpec w = Gusty();
    WindModel wind;
    Rng rng(3);
    wind.Begin(w, rng, Tune());

    // Walk one gust through, recording the order the phases arrive in.
    std::vector<GustPhase> seen;
    GustPhase last = GustPhase::Calm;
    for (int i = 0; i < 60 * 60 && seen.size() < 4; ++i)
    {
        wind.Step(sj::kTick, w, rng, Tune());
        if (wind.Phase() != last)
        {
            last = wind.Phase();
            seen.push_back(last);
        }
    }
    REQUIRE(seen.size() == 4);
    CHECK(seen[0] == GustPhase::Building);
    CHECK(seen[1] == GustPhase::Blowing);
    CHECK(seen[2] == GustPhase::Easing);
    CHECK(seen[3] == GustPhase::Calm);
}

TEST_CASE("Wind: a gust raises the wind it is gusting over, not a fixed amount")
{
    // The same gust on a sheltered level and an exposed one should not be the same event.
    const WeatherSpec w = Gusty();
    WindModel calm_wind;
    Rng rng(5);
    calm_wind.Begin(w, rng, Tune());
    const float steady = calm_wind.SpeedAt(50.0f, w, Tune());
    CHECK(steady == doctest::Approx(w.WindAt(50.0f)));

    // Run until it is actually blowing, then compare.
    for (int i = 0; i < 60 * 120 && calm_wind.Strength() <= 0.0f; ++i)
    {
        calm_wind.Step(sj::kTick, w, rng, Tune());
    }
    REQUIRE(calm_wind.Strength() > 0.0f);
    const float gusting = calm_wind.SpeedAt(50.0f, w, Tune());
    CHECK(gusting > steady);
    CHECK(gusting == doctest::Approx(steady * (1.0f + Tune().GetF("gustWindMultiplier"))));

    // And it is still stronger at the top than at the bottom while gusting.
    CHECK(calm_wind.SpeedAt(50.0f, w, Tune()) > calm_wind.SpeedAt(0.0f, w, Tune()));
}

TEST_CASE("Wind: the same seed gusts at the same moments")
{
    // ADR-0003. Gust timing comes from a caller-supplied stream, so a recorded shift replays with
    // the same weather; an ambient RNG here would desynchronise every replay ever taken.
    const WeatherSpec w = Gusty();
    auto run = [&](uint64_t seed) {
        WindModel wind;
        Rng rng(seed);
        wind.Begin(w, rng, Tune());
        std::vector<int> bites;
        for (int i = 0; i < 60 * 300; ++i)
        {
            wind.Step(sj::kTick, w, rng, Tune());
            if (wind.Tell())
            {
                bites.push_back(i);
            }
        }
        return bites;
    };

    CHECK(run(1234) == run(1234));
    CHECK(run(1234) != run(9999));
}
