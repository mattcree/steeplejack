// Getting your nerve back — METER-004. Its verify line is `make test-unit FILTER=recovery`, so the
// names start with "Recovery:" and match.

#include "doctest.h"

#include "Meters.h"
#include "Recovery.h"
#include "Tuning.h"
#include "Types.h"

#include <filesystem>
#include <string>

using sj::MeterContext;
using sj::Meters;
using sj::Recovery;
using sj::RecoveryState;
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

Meters Shaken()
{
    Meters m = sj::nerve::FreshShift(Tune());
    m.nerve = 20.0f;
    return m;
}

MeterContext At(float height)
{
    MeterContext c{};
    c.height = height;
    return c;
}

float RunToEnd(RecoveryState& s, Meters& m)
{
    float t = 0.0f;
    while (!sj::recover::Step(s, m, sj::kTick, Tune()) && t < 60.0f)
    {
        t += sj::kTick;
    }
    return t + sj::kTick;
}

}  // namespace

TEST_CASE("Recovery: acceptance 1, each action restores its amount over its duration")
{
    for (Recovery a : {Recovery::Tea, Recovery::Cigarette, Recovery::View})
    {
        Meters m = Shaken();
        const float before = m.nerve;
        RecoveryState s{};
        sj::recover::Begin(s, a, m, Tune());
        const float took = RunToEnd(s, m);
        CAPTURE(static_cast<int>(a));
        CHECK(took == doctest::Approx(sj::recover::Duration(a, Tune())).epsilon(0.02));
        CHECK(m.nerve - before == doctest::Approx(sj::recover::Amount(a, Tune())).epsilon(0.01));
    }
    // And the numbers are the design doc's.
    CHECK(Tune().GetF("recover.teaAmount") == doctest::Approx(40.0f));
    CHECK(Tune().GetF("recover.teaSeconds") == doctest::Approx(12.0f));
}

TEST_CASE("Recovery: acceptance 2, a cigarette takes 5 off the ceiling, for the shift")
{
    Meters m = Shaken();
    const float ceiling = m.nerveMax;
    RecoveryState s{};
    sj::recover::Begin(s, Recovery::Cigarette, m, Tune());
    CHECK(m.nerveMax == doctest::Approx(ceiling - 5.0f));
    (void)RunToEnd(s, m);
    CHECK(m.nerveMax == doctest::Approx(ceiling - 5.0f));   // it does not come back

    // And a second one takes another five. The player who smokes their way up arrives with less.
    sj::recover::Begin(s, Recovery::Cigarette, m, Tune());
    CHECK(m.nerveMax == doctest::Approx(ceiling - 10.0f));
}

TEST_CASE("Recovery: acceptance 3, no brew without both hands free, and it says why")
{
    const Meters m = Shaken();
    const sj::Refusal no = sj::recover::CanStart(Recovery::Tea, m, At(30.0f), false, true, Tune());
    CHECK_FALSE(no.ok());
    CHECK_FALSE(no.why.empty());
    CHECK(sj::recover::CanStart(Recovery::Tea, m, At(30.0f), true, true, Tune()).ok());
    // The cigarette is the one that works anywhere.
    CHECK(sj::recover::CanStart(Recovery::Cigarette, m, At(30.0f), false, false, Tune()).ok());
}

TEST_CASE("Recovery: acceptance 4, a tea break cut short keeps what it gave")
{
    Meters m = Shaken();
    const float before = m.nerve;
    RecoveryState s{};
    sj::recover::Begin(s, Recovery::Tea, m, Tune());
    const float half = Tune().GetF("recover.teaSeconds") * 0.5f;
    for (float t = 0.0f; t < half; t += sj::kTick)
    {
        (void)sj::recover::Step(s, m, sj::kTick, Tune());
    }
    sj::recover::Interrupt(s);
    const float kept = m.nerve - before;
    CHECK(kept == doctest::Approx(Tune().GetF("recover.teaAmount") * 0.5f).epsilon(0.03));
    // And nothing more after it stops.
    (void)sj::recover::Step(s, m, 1.0f, Tune());
    CHECK(m.nerve - before == doctest::Approx(kept));
}

TEST_CASE("Recovery: acceptance 5, the view is out and high up")
{
    const Meters m = Shaken();
    CHECK_FALSE(sj::recover::CanStart(Recovery::View, m, At(8.0f), true, true, Tune()).ok());
    CHECK_FALSE(sj::recover::CanStart(Recovery::View, m, At(40.0f), true, false, Tune()).ok());
    CHECK(sj::recover::CanStart(Recovery::View, m, At(40.0f), true, true, Tune()).ok());
}

TEST_CASE("Recovery: nothing recovers past the ceiling")
{
    Meters m = sj::nerve::FreshShift(Tune());
    m.nerve = m.nerveMax - 1.0f;
    RecoveryState s{};
    sj::recover::Begin(s, Recovery::Tea, m, Tune());
    (void)RunToEnd(s, m);
    CHECK(m.nerve == doctest::Approx(m.nerveMax));
}

TEST_CASE("Recovery: standing on a platform or getting low recovers on its own")
{
    CHECK(sj::recover::PassiveRate(At(50.0f), false, Tune()) == doctest::Approx(0.0f));
    CHECK(sj::recover::PassiveRate(At(50.0f), true, Tune())
          == doctest::Approx(Tune().GetF("recover.platformStandPerSecond")));
    CHECK(sj::recover::PassiveRate(At(10.0f), false, Tune())
          == doctest::Approx(Tune().GetF("recover.descendBelow20mPerSecond")));
}
