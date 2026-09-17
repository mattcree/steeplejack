// Nerve tests — METER-002.
//
// Nerve is the meter that converts altitude into difficulty, so these tests are mostly about the
// *shape* of the curve rather than any single value: that height raises the drain, that it
// saturates rather than growing forever, that wind and exposure multiply rather than replace, and
// that the four bands land where the design says.
//
// The one that earns its keep is the last: it reads every `nerveShock.*` key out of the tuning
// data and asserts the code knows each one. `Shock()` is `noexcept` by contract, so an unknown
// event silently does nothing — the single silent failure in this module. That test is what makes
// it safe, because the realistic version of the bug is a shock added to the JSON that the code
// never learned about.

#include "doctest.h"

#include "Meters.h"
#include "Tuning.h"

#include <filesystem>
#include <string>
#include <vector>

using sj::Exposure;
using sj::MeterContext;
using sj::Meters;
using sj::Tuning;

namespace {

const Tuning& Tune()
{
    static const Tuning t = []
    {
        namespace fs = std::filesystem;
        fs::path here = fs::current_path();
        for (int up = 0; up < 5; ++up)
        {
            if (fs::is_directory(here / "data" / "tuning"))
            {
                return Tuning::LoadAll((here / "data" / "tuning").string());
            }
            here = here.parent_path();
        }
        return Tuning::LoadAll("data/tuning");
    }();
    return t;
}

MeterContext At(float height, float wind = 0.0f)
{
    MeterContext c{};
    c.height = height;
    c.windSpeed = wind;
    return c;
}

Meters Simulate(Meters m, const MeterContext& ctx, float seconds)
{
    const int steps = static_cast<int>(seconds / sj::kTick);
    for (int i = 0; i < steps; ++i)
    {
        sj::nerve::Step(m, sj::kTick, ctx, Tune());
    }
    return m;
}

}  // namespace

TEST_CASE("Nerve: Acceptance 5: a shift starts at 90, not 100")
{
    const Meters m = sj::nerve::FreshShift(Tune());
    CHECK(m.nerve == doctest::Approx(Tune().GetF("nerveStart")));
    CHECK(m.nerve == doctest::Approx(90.0f));
    CHECK(m.nerveMax == doctest::Approx(Tune().GetF("nerveMax")));
    CHECK(m.nerve < m.nerveMax);   // you begin the day already slightly on edge
}

TEST_CASE("Nerve: Acceptance 1: the drain is base x height x wind x exposure")
{
    // Transcribed from the GDD term by term rather than checked against a precomputed total, so a
    // failure says which term moved.
    Meters m = sj::nerve::FreshShift(Tune());
    m.exposure = Exposure::Ladder;
    const MeterContext ctx = At(40.0f, 15.0f);

    const float expected = Tune().GetF("nerveBaseDrainPerSecond") *
                           sj::nerve::HeightFactor(ctx, Tune()) *
                           sj::nerve::WindFactor(ctx, Tune()) *
                           sj::nerve::ExposureFactor(Exposure::Ladder, Tune());

    CHECK(sj::nerve::DrainRate(m, ctx, Tune()) == doctest::Approx(expected));

    // And the terms themselves, against the doc's numbers: at the reference height the factor is
    // 1, at the reference wind speed the factor is 2 (1 + 15/15).
    CHECK(sj::nerve::HeightFactor(At(40.0f), Tune()) == doctest::Approx(1.0f));
    CHECK(sj::nerve::WindFactor(At(0.0f, 15.0f), Tune()) == doctest::Approx(2.0f));
    CHECK(sj::nerve::WindFactor(At(0.0f, 0.0f), Tune()) == doctest::Approx(1.0f));
}

TEST_CASE("Nerve: Acceptance 2: the height factor clamps to [0.25, 3.0]")
{
    const float lo = Tune().GetF("nerveHeightFactorMin");
    const float hi = Tune().GetF("nerveHeightFactorMax");

    CHECK(sj::nerve::HeightFactor(At(0.0f), Tune()) == doctest::Approx(lo));
    CHECK(sj::nerve::HeightFactor(At(1.0f), Tune()) == doctest::Approx(lo));
    CHECK(sj::nerve::HeightFactor(At(40.0f), Tune()) == doctest::Approx(1.0f));
    CHECK(sj::nerve::HeightFactor(At(120.0f), Tune()) == doctest::Approx(hi));

    // The cap is the point: fear saturates. Without it the tallest level would be unplayable for a
    // reason nobody chose, and a 240 m stack would be twice as bad as a 120 m one.
    CHECK(sj::nerve::HeightFactor(At(240.0f), Tune()) ==
          sj::nerve::HeightFactor(At(120.0f), Tune()));
}

TEST_CASE("Nerve: height is what makes a tall chimney a different game")
{
    // The design claim, stated as a test: without this, a 110 m chimney plays like a 12 m one.
    Meters m = sj::nerve::FreshShift(Tune());
    m.exposure = Exposure::Ladder;

    const float start = m.nerve;
    const float lostLow = start - Simulate(m, At(10.0f), 60.0f).nerve;
    const float lostHigh = start - Simulate(m, At(110.0f), 60.0f).nerve;

    // A minute at 110 m costs more nerve than a minute at 10 m. Without this the chimney's height
    // is set dressing.
    CHECK(lostHigh > lostLow);

    // And by exactly the ratio of the two height factors — nothing else differs between the runs.
    // At 10 m the factor is floored at 0.25; at 110 m it is 2.75, still under the 3.0 cap. So a
    // minute up there costs eleven times what a minute near the ground does.
    const float ratio = sj::nerve::HeightFactor(At(110.0f), Tune()) /
                        sj::nerve::HeightFactor(At(10.0f), Tune());
    CHECK(ratio == doctest::Approx(11.0f));

    // Within 1%, not to the last bit: these are two sums of 3600 float subtractions taken at very
    // different magnitudes, so they do not agree to doctest's default relative epsilon and should
    // not be asked to. The claim being tested is that the ratio of the factors is the ratio of the
    // outcome, which it is.
    CHECK(lostHigh == doctest::Approx(lostLow * ratio).epsilon(0.01));
}

TEST_CASE("Nerve: exposure multiplies, and the four kinds are ordered least to most exposed")
{
    const auto f = [](Exposure e) { return sj::nerve::ExposureFactor(e, Tune()); };

    CHECK(f(Exposure::Platform) == doctest::Approx(Tune().GetF("exposureFactor.platform")));
    CHECK(f(Exposure::Ladder) == doctest::Approx(Tune().GetF("exposureFactor.ladder")));
    CHECK(f(Exposure::Hanging) == doctest::Approx(Tune().GetF("exposureFactor.hanging")));
    CHECK(f(Exposure::Overhang) == doctest::Approx(Tune().GetF("exposureFactor.overhang")));

    // If this ordering inverts, standing on a platform becomes scarier than hanging over an
    // overhang and the meter is telling the player the opposite of the truth.
    CHECK(f(Exposure::Platform) < f(Exposure::Ladder));
    CHECK(f(Exposure::Ladder) < f(Exposure::Hanging));
    CHECK(f(Exposure::Hanging) < f(Exposure::Overhang));
    CHECK(f(Exposure::Platform) == doctest::Approx(1.0f));   // the baseline, by definition
}

TEST_CASE("Nerve: Acceptance 4: the four bands land on the tuned thresholds")
{
    const float calm = Tune().GetF("nerveBands.calm");
    const float uneasy = Tune().GetF("nerveBands.uneasy");
    const float bad = Tune().GetF("nerveBands.bad");

    CHECK(sj::nerve::Band(100.0f, Tune()) == 0);
    CHECK(sj::nerve::Band(calm, Tune()) == 0);          // a threshold is a floor, not a ceiling
    CHECK(sj::nerve::Band(calm - 0.1f, Tune()) == 1);
    CHECK(sj::nerve::Band(uneasy, Tune()) == 1);
    CHECK(sj::nerve::Band(uneasy - 0.1f, Tune()) == 2);
    CHECK(sj::nerve::Band(bad, Tune()) == 2);
    CHECK(sj::nerve::Band(bad - 0.1f, Tune()) == 3);
    CHECK(sj::nerve::Band(0.0f, Tune()) == 3);

    // Monotonic: less nerve is never a calmer band.
    int32_t previous = 0;
    for (float n = 100.0f; n >= 0.0f; n -= 0.5f)
    {
        const int32_t band = sj::nerve::Band(n, Tune());
        CHECK(band >= previous);
        previous = band;
    }
}

TEST_CASE("Nerve: Acceptance 3: every shock in the tuning data is implemented")
{
    // The important test in this file. Shock() is noexcept by contract, so an unknown event does
    // nothing at all — silently. This reads the shock names out of the data and asserts the code
    // knows each one, which catches the realistic version of that bug: someone adds a shock to
    // meters.json and nothing ever fires it.
    std::vector<std::string> found;
    for (const std::string& key : Tune().Keys())
    {
        const std::string prefix = "nerveshock.";
        if (key.rfind(prefix, 0) == 0)
        {
            found.push_back(key.substr(prefix.size()));
        }
    }

    REQUIRE(found.size() == 9);   // six in the GDD table, nine in the data — the data is the spec

    for (const std::string& event : found)
    {
        CHECK(sj::nerve::IsKnownShock(event, Tune()));

        // Every shock costs nerve. A shock with a positive or zero value would be an event that
        // calms you down by frightening you.
        CHECK(sj::nerve::ShockAmount(event, Tune()) < 0.0f);

        Meters m = sj::nerve::FreshShift(Tune());
        const float before = m.nerve;
        sj::nerve::Shock(m, event, Tune());
        CHECK(m.nerve < before);
        CHECK(m.nerve == doctest::Approx(before + sj::nerve::ShockAmount(event, Tune())));
    }
}

TEST_CASE("Nerve: the named shocks cost what the GDD says")
{
    CHECK(sj::nerve::ShockAmount("droppedTool", Tune()) == doctest::Approx(-10.0f));
    CHECK(sj::nerve::ShockAmount("slipSave", Tune()) == doctest::Approx(-25.0f));
    CHECK(sj::nerve::ShockAmount("anchorFail", Tune()) == doctest::Approx(-30.0f));
    CHECK(sj::nerve::ShockAmount("startle", Tune()) == doctest::Approx(-8.0f));
    CHECK(sj::nerve::ShockAmount("haulHit", Tune()) == doctest::Approx(-20.0f));

    // An anchor letting go under you must never cost less than dropping a spanner.
    CHECK(sj::nerve::ShockAmount("anchorFail", Tune()) <
          sj::nerve::ShockAmount("droppedTool", Tune()));
}

TEST_CASE("Nerve: an unknown shock does nothing, and says so rather than throwing")
{
    // The documented silent failure. It is documented because Shock() is noexcept and the
    // alternative on a typo is std::terminate.
    Meters m = sj::nerve::FreshShift(Tune());
    const float before = m.nerve;

    CHECK_FALSE(sj::nerve::IsKnownShock("thereIsNoSuchEvent", Tune()));
    CHECK(sj::nerve::ShockAmount("thereIsNoSuchEvent", Tune()) == doctest::Approx(0.0f));
    sj::nerve::Shock(m, "thereIsNoSuchEvent", Tune());
    CHECK(m.nerve == doctest::Approx(before));
}

TEST_CASE("Nerve: Acceptance 6: the cigarette lowers the ceiling for the rest of the shift")
{
    Meters m = sj::nerve::FreshShift(Tune());
    m.nerve = m.nerveMax;   // topped right up, so the clamp is observable

    const float penalty = 5.0f;   // GDD: cigarette costs 5 max nerve. METER-004 applies it.
    sj::nerve::ReduceMax(m, penalty, Tune());

    CHECK(m.nerveMax == doctest::Approx(Tune().GetF("nerveMax") - penalty));
    CHECK(m.nerve == doctest::Approx(m.nerveMax));   // current nerve comes down with the ceiling

    // And it stays down: stepping does not let nerve drift back above the new ceiling.
    m = Simulate(m, At(5.0f), 1.0f);
    CHECK(m.nerve <= m.nerveMax);

    // The ceiling only ever falls within a shift. A negative penalty is not free headroom.
    const float ceiling = m.nerveMax;
    sj::nerve::ReduceMax(m, -50.0f, Tune());
    CHECK(m.nerveMax == doctest::Approx(ceiling));
}

TEST_CASE("Nerve: at zero the player is frozen — reported, not enforced")
{
    Meters m = sj::nerve::FreshShift(Tune());
    CHECK_FALSE(sj::nerve::Frozen(m));

    sj::nerve::Shock(m, "anchorFail", Tune());
    sj::nerve::Shock(m, "anchorFail", Tune());
    sj::nerve::Shock(m, "anchorFail", Tune());
    CHECK(m.nerve == doctest::Approx(0.0f));
    CHECK(sj::nerve::Frozen(m));
    CHECK(sj::nerve::Band(m.nerve, Tune()) == 3);

    // Frozen means "cannot climb up", and PLAYER-001 owns what that does. Nerve itself does
    // nothing further: it never kills the player, it makes them worse at the job.
    m = Simulate(m, At(80.0f, 10.0f), 10.0f);
    CHECK(m.nerve == doctest::Approx(0.0f));
}

TEST_CASE("Nerve: it never leaves [0, nerveMax], whatever it is fed")
{
    const Exposure exposures[] = {Exposure::Platform, Exposure::Ladder, Exposure::Hanging,
                                  Exposure::Overhang};
    const float heights[] = {0.0f, 12.0f, 40.0f, 110.0f, 1000.0f};
    const float winds[] = {0.0f, 9.0f, 30.0f};

    for (const Exposure e : exposures)
    {
        for (const float h : heights)
        {
            for (const float w : winds)
            {
                Meters m = sj::nerve::FreshShift(Tune());
                m.exposure = e;
                const MeterContext ctx = At(h, w);

                for (int i = 0; i < 600; ++i)
                {
                    sj::nerve::Step(m, sj::kTick, ctx, Tune());
                    REQUIRE(m.nerve >= 0.0f);
                    REQUIRE(m.nerve <= m.nerveMax);
                }
                sj::nerve::Shock(m, "anchorFail", Tune());
                REQUIRE(m.nerve >= 0.0f);
            }
        }
    }
}

TEST_CASE("Nerve: nerve is slow and grip is fast — they are not the same meter twice")
{
    // The two-meter design only works if the timescales differ by an order of magnitude. Grip is
    // seconds-to-minutes; nerve is minutes-to-hours. If a change ever makes nerve comparable to
    // grip, the game has two stamina bars and an anti-pillar.
    Meters m = sj::nerve::FreshShift(Tune());
    m.exposure = Exposure::Hanging;

    const MeterContext exposed = At(110.0f, 12.0f);
    const float nerveDrain = sj::nerve::DrainRate(m, exposed, Tune());

    MeterContext working = exposed;
    working.working = true;
    const float gripDrain = sj::grip::DrainRate(sj::Stance::OneHand, working, Tune());

    CHECK(nerveDrain > 0.0f);
    CHECK(gripDrain > nerveDrain * 5.0f);
}
