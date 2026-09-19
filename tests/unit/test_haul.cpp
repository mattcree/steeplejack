// Hauling on the gin wheel — VERB-007.
//
// "Roughly thirty lines of code that carry enormous feel value — get the damping response right and
// it is instantly learnable." These tests are what "right" means, stated as VERB-007's five
// acceptance criteria. The constants in climbing.json were calibrated against them: the two that
// predate the model had no units and failed the criteria either way you read them.

#include "doctest.h"

#include "Tuning.h"
#include "Types.h"
#include "Verbs/Haul.h"

#include <cmath>
#include <filesystem>
#include <string>

using sj::HaulState;
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

constexpr float kTop = 55.0f;

float Ladder()
{
    return Tune().GetF("ladderMassKg");
}

// The steer a good hand gives: against the swing, full.
float Antiphase(const HaulState& s)
{
    return (s.swingVel > 0.0f) ? -1.0f : 1.0f;
}

}  // namespace

TEST_CASE("Haul: acceptance 1, hauling flat out with no hand on the rope fouls inside 15 s")
{
    HaulState s{};
    float t = 0.0f;
    while (!s.fouled && t < 30.0f)
    {
        sj::haul::Step(s, sj::kTick, 1.0f, 0.0f, 0.0f, Ladder(), kTop, Tune());
        t += sj::kTick;
    }
    CAPTURE(t);
    CHECK(s.fouled);
    CHECK(t < 15.0f);
    // And not instantly: a haul that fouls in a second is not a skill, it is a wall.
    CHECK(t > 4.0f);
}

TEST_CASE("Haul: acceptance 2, steering against the swing damps 20 degrees below 5 within 8 s")
{
    HaulState s{};
    s.height = 30.0f;
    s.swingDeg = 20.0f;
    float t = 0.0f;
    while (t < 8.0f && sj::haul::AmplitudeDeg(s, kTop, Tune()) >= 5.0f)
    {
        sj::haul::Step(s, sj::kTick, 0.0f, Antiphase(s), 0.0f, Ladder(), kTop, Tune());
        t += sj::kTick;
    }
    CAPTURE(t);
    CHECK(sj::haul::AmplitudeDeg(s, kTop, Tune()) < 5.0f);
}

TEST_CASE("Haul: steering *with* the swing makes it worse")
{
    // The phase is the whole skill, so the wrong phase has to be wrong.
    HaulState s{};
    s.height = 30.0f;
    s.swingDeg = 10.0f;
    for (int i = 0; i < 180; ++i)
    {
        sj::haul::Step(s, sj::kTick, 0.0f, -Antiphase(s), 0.0f, Ladder(), kTop, Tune());
    }
    CHECK(sj::haul::AmplitudeDeg(s, kTop, Tune()) > 10.0f);
}

TEST_CASE("Haul: patience beats force — a steady hand keeps a full-speed haul clean")
{
    // The verb's lesson. Hauling flat out alone fouls (acceptance 1); hauling flat out with a hand
    // on the rope, steering against the swing, gets the load all the way up.
    HaulState s{};
    float t = 0.0f;
    while (!sj::haul::Arrived(s, kTop) && !s.fouled && t < 120.0f)
    {
        sj::haul::Step(s, sj::kTick, 1.0f, Antiphase(s), 0.0f, Ladder(), kTop, Tune());
        t += sj::kTick;
    }
    CHECK_FALSE(s.fouled);
    CHECK(sj::haul::Arrived(s, kTop));
}

TEST_CASE("Haul: acceptance 3, a heavier load swings up slower and is harder to damp")
{
    auto foul_time = [](float kg) {
        HaulState s{};
        float t = 0.0f;
        while (!s.fouled && t < 120.0f)
        {
            sj::haul::Step(s, sj::kTick, 1.0f, 0.0f, 0.0f, kg, kTop, Tune());
            t += sj::kTick;
        }
        return t;
    };
    CHECK(foul_time(Ladder() * 3.0f) > foul_time(Ladder()));

    auto after_damping = [](float kg) {
        HaulState s{};
        s.height = 30.0f;
        s.swingDeg = 20.0f;
        for (int i = 0; i < 240; ++i)
        {
            sj::haul::Step(s, sj::kTick, 0.0f, Antiphase(s), 0.0f, kg, kTop, Tune());
        }
        return sj::haul::AmplitudeDeg(s, kTop, Tune());
    };
    CHECK(after_damping(Ladder() * 3.0f) > after_damping(Ladder()));
}

TEST_CASE("Haul: acceptance 4, wind pushes the load, and a hand can hold against it")
{
    HaulState calm{};
    calm.height = 20.0f;
    HaulState windy = calm;
    for (int i = 0; i < 300; ++i)
    {
        sj::haul::Step(calm, sj::kTick, 0.0f, 0.0f, 0.0f, Ladder(), kTop, Tune());
        sj::haul::Step(windy, sj::kTick, 0.0f, 0.0f, 12.0f, Ladder(), kTop, Tune());
    }
    CHECK(std::fabs(windy.swingDeg) > std::fabs(calm.swingDeg) + 0.5f);

    // Leaning against it: steer into the wind and the offset comes back towards vertical.
    HaulState held{};
    held.height = 20.0f;
    for (int i = 0; i < 300; ++i)
    {
        const float lean = (held.swingDeg > 0.0f) ? -0.6f : 0.0f;
        sj::haul::Step(held, sj::kTick, 0.0f, lean, 12.0f, Ladder(), kTop, Tune());
    }
    CHECK(std::fabs(held.swingDeg) < std::fabs(windy.swingDeg));
}

TEST_CASE("Haul: acceptance 5, an undriven swing never gains energy over 10,000 steps")
{
    // The explicit integrator fails this: it gains a sliver every swing and eventually flings the
    // load over the pulley. Checked with the air damping taken out, so the integrator is the only
    // thing that could add or remove energy.
    //
    // With the real damping left in, an explicit integrator passes this too — damping removes more
    // than it adds — so the check would be one that cannot fail. Hence a tuning of its own.
    const Tuning undamped = Tuning::Parse(R"({
        "ladderMassKg": 18.0, "haulSpeedMetresPerSecond": 0.9, "haulSwingGainPerSpeed": 1.9,
        "haulSwingDampPerSteerInput": 4.6, "haulFoulAmplitudeDegrees": 90.0,
        "haulAirDampingPerSecond": 0.0, "haulWindDegPerS2PerMs": 0.0 })", "undamped");
    HaulState s{};
    s.height = 25.0f;
    s.swingDeg = 15.0f;
    const float start = sj::haul::AmplitudeDeg(s, kTop, undamped);
    float peak = start;
    for (int i = 0; i < 10000; ++i)
    {
        sj::haul::Step(s, sj::kTick, 0.0f, 0.0f, 0.0f, Ladder(), kTop, undamped);
        peak = std::max(peak, std::fabs(s.swingDeg));
    }
    CHECK(peak <= start * 1.01f);
    CHECK(peak >= start * 0.97f);   // and it has not quietly bled away either: undamped means undamped
    CHECK(std::isfinite(s.swingDeg));

    // And deterministic: the same inputs, the same swing, to the bit.
    HaulState a{}, b{};
    a.height = b.height = 10.0f;
    for (int i = 0; i < 2000; ++i)
    {
        sj::haul::Step(a, sj::kTick, 0.7f, 0.3f, 5.0f, Ladder(), kTop, Tune());
        sj::haul::Step(b, sj::kTick, 0.7f, 0.3f, 5.0f, Ladder(), kTop, Tune());
    }
    CHECK(a.swingDeg == b.swingDeg);
    CHECK(a.height == b.height);
}
