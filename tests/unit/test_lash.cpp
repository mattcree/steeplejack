// Lashing — VERB-005, and VERB-006's input methods.
//
// The verb is where the anchor loop's clearest fast-and-worse decision lives, and its skill is that
// smooth rotation is faster than jerky. That claim is easy to write in a design doc and easy to lose
// in an implementation: a model where only the *average* rate matters rewards mashing and flailing
// exactly as much as a steady hand. So the test that matters is acceptance 2 — the same average
// rate, delivered jerkily, takes at least 40% longer — and it is asserted by simulating both.

#include "doctest.h"

#include "Tuning.h"
#include "Types.h"
#include "Verbs/Lash.h"

#include <cmath>
#include <filesystem>
#include <string>

using sj::Lashing;
using sj::LashState;
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

float IdealRate()
{
    return 1.0f / Tune().GetF("lashSecondsPerWrapIdeal");
}

// Seconds to reach `wraps` with a rate function of time. Caps at ten minutes so a broken model
// fails the test rather than hanging it.
template <typename RateOf>
float SecondsTo(int wraps, RateOf rate_of)
{
    LashState s{};
    float t = 0.0f;
    while (s.wraps < wraps && t < 600.0f)
    {
        sj::lash::Step(s, sj::kTick, rate_of(t), Tune());
        t += sj::kTick;
    }
    return t;
}

}  // namespace

TEST_CASE("Lash: acceptance 1, six steady wraps take about six ideal wraps' time")
{
    const float ideal = IdealRate();
    const float took = SecondsTo(6, [&](float) { return ideal; });
    const float want = 6.0f * Tune().GetF("lashSecondsPerWrapIdeal");
    CHECK(took == doctest::Approx(want).epsilon(0.05));
}

TEST_CASE("Lash: acceptance 2, jerky input takes at least 40% longer for the same average rate")
{
    // Double speed and a dead stop, alternating every half second: the same average turn rate as a
    // steady hand. If only the average mattered this would take the same time, and the verb would
    // reward flailing exactly as much as skill.
    const float ideal = IdealRate();
    const float steady = SecondsTo(6, [&](float) { return ideal; });
    const float jerky = SecondsTo(6, [&](float t) {
        return (std::fmod(t, 1.0f) < 0.5f) ? 2.0f * ideal : 0.0f;
    });
    CAPTURE(steady);
    CAPTURE(jerky);
    CHECK(jerky >= steady * 1.4f);
}

TEST_CASE("Lash: spinning faster than the ideal is not proportionally faster")
{
    // The saturation, directly: three times the rate lays nowhere near three times the rope. It is
    // what makes the jerky case slow, and it is what rope does.
    const float ideal = IdealRate();
    CHECK(sj::lash::LayRate(ideal, Tune()) == doctest::Approx(ideal));
    CHECK(sj::lash::LayRate(3.0f * ideal, Tune()) < 1.6f * ideal);
    CHECK(sj::lash::LayRate(0.0f, Tune()) == doctest::Approx(0.0f));
}

TEST_CASE("Lash: acceptance 3, tension bleeds away when you stop")
{
    LashState s{};
    for (int i = 0; i < 120; ++i)
    {
        sj::lash::Step(s, sj::kTick, IdealRate(), Tune());
    }
    const float working = s.tension;
    REQUIRE(working > 0.5f);

    for (int i = 0; i < 60; ++i)
    {
        sj::lash::Step(s, sj::kTick, 0.0f, Tune());
    }
    CHECK(s.tension < working);
    // And stopping lays no rope.
    const int wraps = s.wraps;
    const float laid = s.laid;
    sj::lash::Step(s, sj::kTick, 0.0f, Tune());
    CHECK(s.wraps == wraps);
    CHECK(s.laid == doctest::Approx(laid));
}

TEST_CASE("Lash: acceptance 4, two turns is not a lashing and says so")
{
    LashState s{};
    s.wraps = 2;
    s.tension = 1.0f;
    CHECK(sj::lash::TieOff(s, Tune()) == Lashing::None);
    CHECK(s.slipping);
    CHECK(s.tied);
}

TEST_CASE("Lash: three is a hitch, six is a full lashing")
{
    LashState hitch{};
    hitch.wraps = Tune().GetI("lashWrapsQuickHitch");
    hitch.tension = 1.0f;
    CHECK(sj::lash::TieOff(hitch, Tune()) == Lashing::Hitch);
    CHECK_FALSE(hitch.slipping);

    LashState full{};
    full.wraps = Tune().GetI("lashWrapsFull");
    full.tension = 1.0f;
    CHECK(sj::lash::TieOff(full, Tune()) == Lashing::Full);
    CHECK_FALSE(full.slipping);
}

TEST_CASE("Lash: tying off slack leaves the knot slipping")
{
    // The mistiming the verb spec warns about. It holds, for now — visible and fixable, not a
    // hidden failure waiting forty metres up.
    LashState s{};
    s.wraps = Tune().GetI("lashWrapsFull");
    s.tension = 0.1f;
    CHECK(sj::lash::TieOff(s, Tune()) == Lashing::Full);
    CHECK(s.slipping);
}

TEST_CASE("Lash: acceptance 5, a hitch drifts and a full lashing does not")
{
    CHECK(sj::lash::DriftPerMinuteCm(Lashing::Hitch, Tune()) > 0.0f);
    CHECK(sj::lash::DriftPerMinuteCm(Lashing::Full, Tune()) == doctest::Approx(0.0f));
    CHECK(sj::lash::DriftPerMinuteCm(Lashing::None, Tune()) == doctest::Approx(0.0f));
}

TEST_CASE("Lash: a tied knot is finished")
{
    LashState s{};
    s.wraps = 6;
    (void)sj::lash::TieOff(s, Tune());
    sj::lash::Step(s, 1.0f, 10.0f * IdealRate(), Tune());
    CHECK(s.wraps == 6);
}

// ---------------------------------------------------------------- VERB-006

TEST_CASE("Lash: VERB-006 acceptance 1 and 2, every input method can finish a full lashing")
{
    // Going round, mashing, and holding. All three must be able to reach six wraps with tension
    // enough to tie off clean — there is no version of this game playable without lashing.
    const float ideal = IdealRate();
    const float mash_rate = sj::lash::RateFromMash(4.0f, Tune());   // four presses a second
    const float hold_rate = sj::lash::RateFromHold(Tune());

    for (float rate : {ideal, mash_rate, hold_rate})
    {
        LashState s{};
        float t = 0.0f;
        while (s.wraps < 6 && t < 60.0f)
        {
            sj::lash::Step(s, sj::kTick, rate, Tune());
            t += sj::kTick;
        }
        CAPTURE(rate);
        CHECK(s.wraps >= 6);
        CHECK(sj::lash::TieOff(s, Tune()) == Lashing::Full);
        CHECK_FALSE(s.slipping);
    }
}

TEST_CASE("Lash: holding is slower than a good hand and faster than a bad one")
{
    // VERB-006's context: "slower than expert rotation, faster than bad rotation, which is the right
    // place for it." Never the best way, never a punishment.
    const float ideal = IdealRate();
    const float expert = SecondsTo(6, [&](float) { return ideal; });
    const float bad = SecondsTo(6, [&](float t) {
        return (std::fmod(t, 1.0f) < 0.5f) ? 2.0f * ideal : 0.0f;
    });
    const float hold = SecondsTo(6, [&](float) { return sj::lash::RateFromHold(Tune()); });
    CAPTURE(expert);
    CAPTURE(hold);
    CAPTURE(bad);
    CHECK(hold > expert);
    CHECK(hold < bad);
}
