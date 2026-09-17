// Hammer and wobble tests — VERB-003 and METER-003.
//
// The hammer is the skill the game is built on, so these tests are less about arithmetic than
// about whether the *lessons* the design wants the player to learn are actually true of the code:
// that full power is usually wrong, that soft mortar is a trap, and that a worn tool costs you.
// If a tuning change makes a full-power swing optimal, the game has lost its first "I'm good at
// this now" moment and a test should say so.

#include "doctest.h"

#include "Meters.h"
#include "Tuning.h"
#include "Verbs/Hammer.h"
#include "Wobble.h"

#include <filesystem>

using sj::Joint;
using sj::MeterContext;
using sj::Meters;
using sj::StrikeResult;
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

Joint JointOfQuality(float quality)
{
    Joint j{};
    j.quality = quality;
    return j;
}

// Drive a dog with a fixed power and angle until it seats, bends, or we give up.
struct Attempt { int strikes; bool seated; bool bent; float spall; };

Attempt Drive(float quality, float power, float angleErr, float tool = 1.0f)
{
    const Joint j = JointOfQuality(quality);
    float depth = 0.0f;
    Attempt a{0, false, false, 0.0f};
    for (int i = 0; i < 40; ++i)
    {
        const StrikeResult r = sj::hammer::Strike(j, depth, power, angleErr, tool, Tune());
        ++a.strikes;
        a.spall += r.spalled;
        if (r.bent) { a.bent = true; return a; }
        depth += r.depthGain;
        if (r.seated) { a.seated = true; return a; }
    }
    return a;
}

}  // namespace

TEST_CASE("Hammer: a clean angle beats a hard swing — the first thing the player learns")
{
    // The design's claim: "Full-power swings are wrong most of the time. 60-75% power with a clean
    // angle out-performs 100% power." If this inverts, the skill ceiling is gone.
    const Attempt Clean = Drive(0.6f, 0.7f, 0.0f);
    const Attempt Wild = Drive(0.6f, 1.0f, 10.0f);

    CHECK(Clean.seated);
    CHECK(Wild.bent);
}

TEST_CASE("Hammer: a full-power swing at a clean angle is safe — power is not the enemy")
{
    // The lesson is "power without control is wrong", not "never swing hard". A player who lines
    // it up properly should be rewarded for committing.
    const Attempt Committed = Drive(0.6f, 1.0f, 0.0f);
    CHECK(Committed.seated);
    CHECK_FALSE(Committed.bent);
    CHECK(Committed.strikes <= Drive(0.6f, 0.5f, 0.0f).strikes);
}

TEST_CASE("Hammer: soft mortar is the trap — fast to seat, and it spalls while you do it")
{
    const Attempt Perished = Drive(0.1f, 0.7f, 0.0f);   // soft
    const Attempt Sound = Drive(0.9f, 0.7f, 0.0f);      // hard

    CHECK(Perished.seated);
    CHECK(Perished.strikes < Sound.strikes);

    // And it damages the brickwork on the way in, which is what makes it a bad anchor rather than
    // just a quick one.
    CHECK(Perished.spall > Sound.spall);
}

TEST_CASE("Hammer: sound mortar resists and needs several solid strikes")
{
    const Attempt Sound = Drive(0.85f, 0.75f, 0.0f);
    CHECK(Sound.seated);
    CHECK(Sound.strikes >= 3);
}

TEST_CASE("Hammer: a bad angle at low power does not bend the dog")
{
    // bendRisk is power × (1 - quality): a gentle tap at a poor angle wastes time, not material.
    // The player should be able to feel their way in without destroying a dog every attempt.
    const StrikeResult Tap =
        sj::hammer::Strike(JointOfQuality(0.6f), 0.0f, 0.15f, 10.0f, 1.0f, Tune());
    CHECK_FALSE(Tap.bent);
    CHECK(Tap.depthGain >= 0.0f);
}

TEST_CASE("Hammer: strike quality falls off with angle and is zero past the limit")
{
    const float maxErr = Tune().GetF("hammerMaxAngleErrorDegrees");

    CHECK(sj::hammer::StrikeQuality(0.0f, Tune()) == doctest::Approx(1.0f));
    CHECK(sj::hammer::StrikeQuality(maxErr * 0.5f, Tune()) == doctest::Approx(0.5f));
    CHECK(sj::hammer::StrikeQuality(maxErr, Tune()) == doctest::Approx(0.0f));
    CHECK(sj::hammer::StrikeQuality(maxErr * 2.0f, Tune()) == doctest::Approx(0.0f));

    // Sign does not matter: off to the left is as bad as off to the right.
    CHECK(sj::hammer::StrikeQuality(-4.0f, Tune()) ==
          doctest::Approx(sj::hammer::StrikeQuality(4.0f, Tune())));
}

TEST_CASE("Hammer: a worn tool costs strikes without reducing the risk")
{
    const Attempt Good = Drive(0.6f, 0.7f, 0.0f, 1.0f);
    const Attempt Worn = Drive(0.6f, 0.7f, 0.0f, 0.0f);

    CHECK(Good.seated);
    CHECK(Worn.seated);
    CHECK(Worn.strikes > Good.strikes);   // which is why repairing a hammer is worth paying for
}

TEST_CASE("Hammer: spalling rises with depth — the last strikes are the dangerous ones")
{
    const Joint Weak = JointOfQuality(0.15f);
    const StrikeResult Early = sj::hammer::Strike(Weak, 0.05f, 0.7f, 0.0f, 1.0f, Tune());
    const StrikeResult Late = sj::hammer::Strike(Weak, 0.70f, 0.7f, 0.0f, 1.0f, Tune());

    CHECK(Late.spalled > Early.spalled);

    // And a sound joint barely spalls at all, however deep you are.
    const StrikeResult SoundLate =
        sj::hammer::Strike(JointOfQuality(0.95f), 0.70f, 0.7f, 0.0f, 1.0f, Tune());
    CHECK(SoundLate.spalled < Late.spalled);
}

// ---------------------------------------------------------------- wobble

TEST_CASE("Wobble: a better stance is always steadier")
{
    Meters m = sj::nerve::FreshShift(Tune());
    const MeterContext ctx{};

    const auto at = [&](sj::Stance s)
    {
        Meters x = m;
        x.stance = s;
        return sj::WobbleAmplitudeDeg(x, ctx, 0.0f, Tune());
    };

    CHECK(at(sj::Stance::OneHand) > at(sj::Stance::HookedLeg));
    CHECK(at(sj::Stance::HookedLeg) > at(sj::Stance::Clipped));
    CHECK(at(sj::Stance::Clipped) > at(sj::Stance::Belted));
    CHECK(at(sj::Stance::Belted) > at(sj::Stance::Chair));
}

TEST_CASE("Wobble: the tremor threshold is felt in the aim, not just shown on the HUD")
{
    // Rule 7 wants the warning to precede the failure. This is what makes it more than a label:
    // below the threshold your aim visibly degrades, so the telegraph is in the controls.
    Meters m = sj::nerve::FreshShift(Tune());
    m.stance = sj::Stance::Belted;
    const MeterContext ctx{};
    const float threshold = Tune().GetF("gripTremorThreshold");

    m.grip = threshold + 1.0f;
    const float Steady = sj::WobbleAmplitudeDeg(m, ctx, 0.0f, Tune());

    m.grip = threshold - 1.0f;
    const float Shaking = sj::WobbleAmplitudeDeg(m, ctx, 0.0f, Tune());

    m.grip = 0.0f;
    const float Spent = sj::WobbleAmplitudeDeg(m, ctx, 0.0f, Tune());

    CHECK(Shaking > Steady);
    CHECK(Spent > Shaking);
    CHECK(Spent == doctest::Approx(Steady * Tune().GetF("gripWobbleAtZero")));
}

TEST_CASE("Wobble: fear steps in bands, so crossing one is noticeable")
{
    Meters m = sj::nerve::FreshShift(Tune());
    m.stance = sj::Stance::Belted;
    m.grip = Tune().GetF("gripMax");
    const MeterContext ctx{};

    const auto at = [&](float nerveValue)
    {
        Meters x = m;
        x.nerve = nerveValue;
        return sj::WobbleAmplitudeDeg(x, ctx, 0.0f, Tune());
    };

    const float Calm = at(90.0f);
    const float Uneasy = at(50.0f);
    const float Bad = at(30.0f);

    CHECK(Uneasy > Calm);
    CHECK(Bad > Uneasy);
    CHECK(Uneasy == doctest::Approx(Calm * Tune().GetF("nerveWobbleMultiplier.uneasy")));
}

TEST_CASE("Wobble: a gust adds, it does not scale your nerves")
{
    Meters m = sj::nerve::FreshShift(Tune());
    m.stance = sj::Stance::Belted;
    const MeterContext ctx{};

    const float Still = sj::WobbleAmplitudeDeg(m, ctx, 0.0f, Tune());
    const float Gusting = sj::WobbleAmplitudeDeg(m, ctx, 1.0f, Tune());

    CHECK(Gusting == doctest::Approx(Still + Tune().GetF("gustWobbleDegrees")));
}

TEST_CASE("Wobble: at its worst it exceeds the hammer's angle tolerance — that is the point")
{
    // One hand on a rung, gripped with fear, grip gone, in a gust. If this did NOT exceed
    // hammerMaxAngleErrorDegrees, running the meters down would carry no consequence for the job
    // and the two-meter design would be decoration.
    Meters m{};
    m.stance = sj::Stance::OneHand;
    m.grip = 0.0f;
    m.nerve = 5.0f;
    m.nerveMax = 100.0f;
    MeterContext ctx{};
    ctx.carryingLadder = true;

    const float Worst = sj::WobbleAmplitudeDeg(m, ctx, 1.0f, Tune());
    CHECK(Worst > Tune().GetF("hammerMaxAngleErrorDegrees"));
}
