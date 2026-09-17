// Grip tests — METER-001.
//
// The stance table is the difficulty dial for the entire game, so these tests are mostly about
// one question: does the number a designer types into meters.json become the number the player
// feels? Every drain rate is checked against the file rather than against a constant here, so
// a tuning change moves the game and does not break the tests, while a *code* change that stops
// reading tuning breaks them immediately.

#include "doctest.h"

#include "Meters.h"
#include "Tuning.h"

#include <filesystem>
#include <string>

using sj::MeterContext;
using sj::Meters;
using sj::Stance;
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

// A climber at full grip in the given stance, working.
Meters Working(Stance s)
{
    Meters m{};
    m.stance = s;
    m.grip = Tune().GetF("gripMax");
    return m;
}

MeterContext Busy()
{
    MeterContext c{};
    c.working = true;
    return c;
}

// Run `seconds` of simulated work at 60 Hz and return the meters.
Meters Simulate(Meters m, const MeterContext& ctx, float seconds)
{
    const int steps = static_cast<int>(seconds / sj::kTick);
    for (int i = 0; i < steps; ++i)
    {
        sj::grip::Step(m, sj::kTick, ctx, Tune());
    }
    return m;
}

}  // namespace

TEST_CASE("Grip: Acceptance 1: every stance drains at exactly the rate in meters.json")
{
    const MeterContext ctx = Busy();

    CHECK(sj::grip::DrainRate(Stance::OneHand, ctx, Tune()) ==
          doctest::Approx(Tune().GetF("gripDrainPerSecond.oneHand")));
    CHECK(sj::grip::DrainRate(Stance::HookedLeg, ctx, Tune()) ==
          doctest::Approx(Tune().GetF("gripDrainPerSecond.hookedLeg")));
    CHECK(sj::grip::DrainRate(Stance::Clipped, ctx, Tune()) ==
          doctest::Approx(Tune().GetF("gripDrainPerSecond.clipped")));
    CHECK(sj::grip::DrainRate(Stance::Belted, ctx, Tune()) ==
          doctest::Approx(Tune().GetF("gripDrainPerSecond.belted")));
    CHECK(sj::grip::DrainRate(Stance::Chair, ctx, Tune()) ==
          doctest::Approx(Tune().GetF("gripDrainPerSecond.chair")));
}

TEST_CASE("Grip: the stance table runs best-to-worst, which is the design's whole claim")
{
    const MeterContext ctx = Busy();
    const auto rate = [&ctx](Stance s) { return sj::grip::DrainRate(s, ctx, Tune()); };

    // A better stance is never worse. If this inverts, spending 20 s rigging a chair buys nothing
    // and the central trade of the game is broken — without any test failing on a drain value.
    CHECK(rate(Stance::OneHand) > rate(Stance::HookedLeg));
    CHECK(rate(Stance::HookedLeg) >= rate(Stance::Clipped));
    CHECK(rate(Stance::Clipped) > rate(Stance::Belted));
    CHECK(rate(Stance::Belted) > rate(Stance::Chair));
    CHECK(rate(Stance::Chair) == doctest::Approx(0.0f));
}

TEST_CASE("Grip: one-handed work gives about the twelve-second window the design promises")
{
    // docs/01-gdd/03-meters-grip-nerve.md: "you have about twelve seconds of one-handed work
    // before you must stop and hold on". 100 grip at 8/s is 12.5 s. If a tuning change breaks
    // this, the rhythm of the whole game has changed and someone should have meant it.
    const Meters m = Working(Stance::OneHand);
    const float window = sj::grip::SecondsOfWorkLeft(m, Busy(), Tune());
    CHECK(window > 10.0f);
    CHECK(window < 15.0f);

    // And it really runs out on schedule.
    CHECK(Simulate(m, Busy(), 12.0f).grip > 0.0f);
    CHECK(sj::grip::Slipping(Simulate(m, Busy(), 13.0f)));
}

TEST_CASE("Grip: Acceptance 2: full recovery from zero takes about four seconds")
{
    Meters m = Working(Stance::OneHand);
    m.grip = 0.0f;

    MeterContext holding{};   // working == false: both hands on the rung
    const float max = Tune().GetF("gripMax");

    CHECK(Simulate(m, holding, 3.0f).grip < max);
    CHECK(Simulate(m, holding, 4.1f).grip == doctest::Approx(max));

    // 100 / 25 per second is 4 s exactly. Stated as a range because the number is tuning's to move.
    CHECK(max / sj::grip::RecoverRate(Tune()) == doctest::Approx(4.0f));
}

TEST_CASE("Grip: it drains only while a hand is off the ladder")
{
    const Meters m = Working(Stance::OneHand);

    MeterContext holding{};
    holding.working = false;
    CHECK(Simulate(m, holding, 5.0f).grip == doctest::Approx(Tune().GetF("gripMax")));

    CHECK(Simulate(m, Busy(), 5.0f).grip < Tune().GetF("gripMax"));
}

TEST_CASE("Grip: Acceptance 3: every modifier in meters.json is implemented")
{
    const float base = sj::grip::DrainRate(Stance::OneHand, Busy(), Tune());

    auto with = [](auto&& set)
    {
        MeterContext c{};
        c.working = true;
        set(c);
        return sj::grip::DrainRate(Stance::OneHand, c, Tune());
    };

    CHECK(with([](MeterContext& c) { c.carryingLadder = true; }) ==
          doctest::Approx(base * Tune().GetF("gripModifiers.carryingLadder")));
    CHECK(with([](MeterContext& c) { c.wet = true; }) ==
          doctest::Approx(base * Tune().GetF("gripModifiers.wet")));
    CHECK(with([](MeterContext& c) { c.injury = "cracked_rib"; }) ==
          doctest::Approx(base * Tune().GetF("gripModifiers.crackedRib")));

    // Gloves are the one modifier that *helps* — and cost a tap-test tier, which is VERB-001's
    // side of the same trade. A lovely deal, and it should stay a deal.
    CHECK(with([](MeterContext& c) { c.gloves = true; }) < base);
    CHECK(with([](MeterContext& c) { c.gloves = true; }) ==
          doctest::Approx(base * Tune().GetF("gripModifiers.gloves")));

    // Modifiers compound rather than overriding each other.
    CHECK(with([](MeterContext& c) { c.wet = true; c.carryingLadder = true; }) ==
          doctest::Approx(base * Tune().GetF("gripModifiers.wet") *
                          Tune().GetF("gripModifiers.carryingLadder")));

    // An unrelated injury changes nothing — the string is matched, not merely tested for presence.
    CHECK(with([](MeterContext& c) { c.injury = "bad_ankle"; }) == doctest::Approx(base));
}

TEST_CASE("Grip: cold caps the ceiling until you have worked long enough to warm up")
{
    MeterContext cold{};
    cold.cold = true;
    const float cap = Tune().GetF("gripModifiers.coldMaxCap");
    const float max = Tune().GetF("gripMax");
    const float warmup = Tune().GetF("gripModifiers.coldWarmupSeconds");

    CHECK(sj::grip::MaxGrip(cold, Tune()) == doctest::Approx(cap));
    CHECK(cap < max);

    // Recovery stops at the cap, not at full: the winter feeling is that grip will not fill.
    Meters m{};
    m.grip = 0.0f;
    CHECK(Simulate(m, cold, 10.0f).grip == doctest::Approx(cap));

    cold.workedSeconds = warmup;
    CHECK(sj::grip::MaxGrip(cold, Tune()) == doctest::Approx(max));

    cold.workedSeconds = warmup - 1.0f;
    CHECK(sj::grip::MaxGrip(cold, Tune()) == doctest::Approx(cap));

    // Warm weather ignores workedSeconds entirely.
    MeterContext warm{};
    CHECK(sj::grip::MaxGrip(warm, Tune()) == doctest::Approx(max));
}

TEST_CASE("Grip: Acceptance 4: the tremor warning arrives before the failure, not with it")
{
    // The fairness contract: every failure has a telegraph. A tremor that only appeared at zero
    // would be an announcement, not a warning.
    Meters m = Working(Stance::OneHand);
    const float threshold = Tune().GetF("gripTremorThreshold");

    CHECK_FALSE(sj::grip::Tremor(m, Tune()));

    m.grip = threshold + 1.0f;
    CHECK_FALSE(sj::grip::Tremor(m, Tune()));

    m.grip = threshold - 1.0f;
    CHECK(sj::grip::Tremor(m, Tune()));
    CHECK_FALSE(sj::grip::Slipping(m));   // warned, not yet failing — the point

    m.grip = 0.0f;
    CHECK(sj::grip::Tremor(m, Tune()));

    // And there is real time between the warning and the slip: threshold/rate seconds of it.
    Meters warned = Working(Stance::OneHand);
    warned.grip = threshold;
    CHECK(sj::grip::SecondsOfWorkLeft(warned, Busy(), Tune()) > 2.0f);
}

TEST_CASE("Grip: Acceptance 5: at zero it reports a slip and does not resolve one")
{
    Meters m = Working(Stance::OneHand);
    CHECK_FALSE(sj::grip::Slipping(m));

    m = Simulate(m, Busy(), 30.0f);
    CHECK(m.grip == doctest::Approx(0.0f));
    CHECK(sj::grip::Slipping(m));

    // Still zero, still slipping, still not resolved: the slip window, the grab input and the fall
    // are METER-005's. The meter must not quietly acquire a second responsibility.
    m = Simulate(m, Busy(), 5.0f);
    CHECK(m.grip == doctest::Approx(0.0f));
    CHECK(sj::grip::Slipping(m));
}

TEST_CASE("Grip: Acceptance 6: grip never leaves [0, max], whatever it is fed")
{
    // A property test over the awkward combinations rather than a single happy path. Grip is read
    // by every verb, so one out-of-range value would propagate as a plausible wrong number.
    const Stance stances[] = {Stance::OneHand, Stance::HookedLeg, Stance::Clipped,
                              Stance::Belted, Stance::Chair};
    const float deltas[] = {sj::kTick, 0.5f, 2.0f, 0.0f};

    for (const Stance s : stances)
    {
        for (const float dt : deltas)
        {
            for (int coldBit = 0; coldBit < 2; ++coldBit)
            {
                for (int workBit = 0; workBit < 2; ++workBit)
                {
                    Meters m{};
                    m.stance = s;
                    m.grip = Tune().GetF("gripMax");

                    MeterContext c{};
                    c.cold = (coldBit == 1);
                    c.working = (workBit == 1);
                    c.wet = true;
                    c.carryingLadder = true;

                    for (int i = 0; i < 400; ++i)
                    {
                        sj::grip::Step(m, dt, c, Tune());
                        REQUIRE(m.grip >= 0.0f);
                        REQUIRE(m.grip <= sj::grip::MaxGrip(c, Tune()));
                    }
                }
            }
        }
    }
}

TEST_CASE("Grip: the same inputs always give the same result")
{
    // Determinism, stated directly: no clock, no randomness, no hidden state. This is what lets a
    // recorded shift replay (ADR-0003).
    const Meters start = Working(Stance::HookedLeg);
    MeterContext c = Busy();
    c.wet = true;

    CHECK(Simulate(start, c, 3.0f).grip == Simulate(start, c, 3.0f).grip);

    // And stepping twice by dt equals stepping once by 2*dt, so the result does not depend on how
    // the caller chose to slice time.
    Meters a = start;
    sj::grip::Step(a, 0.1f, c, Tune());
    sj::grip::Step(a, 0.1f, c, Tune());
    Meters b = start;
    sj::grip::Step(b, 0.2f, c, Tune());
    CHECK(a.grip == doctest::Approx(b.grip));
}
