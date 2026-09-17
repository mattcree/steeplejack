// SimClock tests — CORE-005.
//
// This class is four lines of arithmetic and everything in the project rests on it. If the step
// count drifts with frame rate, every recorded replay becomes unreproducible and the highest-
// leverage test in the project (TEST-002) silently stops meaning anything. So the tests here are
// about *equality of step counts across frame rates*, not about the accumulator's internals.

#include "doctest.h"

#include "Clock.h"

#include <cmath>
#include <limits>

using sj::kMaxCatchUpSteps;
using sj::kTick;
using sj::SimClock;

namespace {

// Feed `seconds` of real time in equal chunks of 1/fps and return the total steps run.
int StepsOverOneSecond(int fps, float seconds = 1.0f)
{
    SimClock clock;
    const float delta = 1.0f / static_cast<float>(fps);
    const int frames = static_cast<int>(std::lround(static_cast<double>(seconds) * fps));

    int total = 0;
    for (int i = 0; i < frames; ++i)
    {
        total += clock.Advance(delta);
    }
    return total;
}

}  // namespace

TEST_CASE("Clock: Acceptance 1: one second is 60 steps at these frame rates")
{
    // The property that matters. A player on a 144 Hz monitor and a player on a 30 Hz one must
    // run the same number of sim steps per second of wall time, or they are playing different
    // games and neither one's replay reproduces on the other's machine.
    //
    // "At these frame rates", not "at any": `1.0f/fps` is not exact, so for some rates the deltas
    // delivered in a nominal second genuinely add up to marginally under 60 ticks of real time and
    // 59 is the correct answer. The named rates below are the ones that matter and they are exact.
    CHECK(StepsOverOneSecond(30) == 60);
    CHECK(StepsOverOneSecond(144) == 60);
    CHECK(StepsOverOneSecond(60) == 60);
    CHECK(StepsOverOneSecond(120) == 60);
}

TEST_CASE("Clock: a frame rate that does not divide the tick still averages out")
{
    // 75 and 100 fps are not integer multiples or divisors of 60, so individual frames run 0, 1
    // or 2 steps. Over a second the total still has to land on 60.
    CHECK(StepsOverOneSecond(75) == 60);
    CHECK(StepsOverOneSecond(100) == 60);
    CHECK(StepsOverOneSecond(90) == 60);
}

TEST_CASE("Clock: step counts stay exact over ten seconds, not just one")
{
    // Not because error compounds — it does not; the float version's deficit is a fixed one-step
    // boundary offset, not a rate. This guards the opposite risk: that the integer conversion in
    // Advance() acquires a per-frame rounding bias, which WOULD compound. Ten seconds is 600 steps.
    CHECK(StepsOverOneSecond(60, 10.0f) == 600);
    CHECK(StepsOverOneSecond(144, 10.0f) == 600);
}

TEST_CASE("Clock: Acceptance 2: alpha stays in [0, 1)")
{
    SimClock clock;
    // Deliberately an awkward delta: not a multiple of the tick, so the accumulator holds a
    // varying remainder every frame.
    for (int i = 0; i < 1000; ++i)
    {
        (void)clock.Advance(0.00713f);
        CHECK(clock.Alpha() >= 0.0f);
        CHECK(clock.Alpha() < 1.0f);
    }
}

TEST_CASE("Clock: alpha is the fraction of a tick left unspent")
{
    SimClock clock;

    (void)clock.Advance(kTick * 0.5f);
    CHECK(clock.Alpha() == doctest::Approx(0.5f));

    // Exactly one tick more: the step is spent, nothing is left over.
    const int steps = clock.Advance(kTick * 0.5f);
    CHECK(steps == 1);
    CHECK(clock.Alpha() == doctest::Approx(0.0f));
}

TEST_CASE("Clock: Acceptance 3: a two-second stall runs at most five steps, not 120")
{
    SimClock clock;
    const int steps = clock.Advance(2.0f);

    CHECK(steps == kMaxCatchUpSteps);
    CHECK(steps == 5);

    // The rest is discarded rather than carried. If it were carried, the next frame would owe
    // those steps plus its own and fall further behind every frame — the spiral of death.
    CHECK(clock.DroppedSteps() > 100);
    CHECK(clock.Alpha() < 1.0f);

    // And the very next normal frame is back to normal, which is the whole point.
    CHECK(clock.Advance(kTick) == 1);
}

TEST_CASE("Clock: a stall does not leave the accumulator holding a backlog")
{
    SimClock a;
    (void)a.Advance(2.0f);

    SimClock b;
    (void)b.Advance(kTick);

    // After the stall is absorbed, the two clocks agree on what a normal frame does. A clock still
    // holding a backlog would run extra steps here.
    for (int i = 0; i < 10; ++i)
    {
        CHECK(a.Advance(kTick) == b.Advance(kTick));
    }
}

TEST_CASE("Clock: a frame shorter than a tick runs no steps and banks the time")
{
    SimClock clock;
    CHECK(clock.Advance(kTick * 0.25f) == 0);
    CHECK(clock.Advance(kTick * 0.25f) == 0);
    CHECK(clock.Advance(kTick * 0.25f) == 0);
    CHECK(clock.Advance(kTick * 0.25f) == 1);   // four quarters is one tick
}

TEST_CASE("Clock: time does not run backwards and one bad frame does not poison the session")
{
    SimClock clock;

    CHECK(clock.Advance(-1.0f) == 0);
    CHECK(clock.Advance(std::numeric_limits<float>::quiet_NaN()) == 0);
    CHECK(clock.Advance(std::numeric_limits<float>::infinity()) == 0);
    CHECK(clock.Alpha() >= 0.0f);
    CHECK(clock.Alpha() < 1.0f);

    // A NaN added to the accumulator would make every later comparison false and the clock would
    // never step again. It still works.
    CHECK(clock.Advance(kTick) == 1);
}

TEST_CASE("Clock: the same delta sequence always produces the same step sequence")
{
    // Determinism, stated directly. Two clocks fed identical deltas must agree step for step —
    // this is the property replay depends on.
    SimClock a;
    SimClock b;
    const float deltas[] = {0.017f, 0.004f, 0.033f, 0.008f, 0.021f, 0.0166f, 0.5f, 0.016f};

    for (int repeat = 0; repeat < 50; ++repeat)
    {
        for (const float d : deltas)
        {
            CHECK(a.Advance(d) == b.Advance(d));
            CHECK(a.Alpha() == b.Alpha());
        }
    }
    CHECK(a.DroppedSteps() == b.DroppedSteps());
}

TEST_CASE("Clock: an absurd delta is clamped rather than overflowing the accumulator")
{
    // The clamp in Advance() needs a delta of ~16666 s to engage, so nothing else in this file
    // reaches it. An uncovered branch in the one class every other test depends on is not a branch
    // worth leaving to chance.
    SimClock clock;
    const int steps = clock.Advance(1e30f);
    CHECK(steps == kMaxCatchUpSteps);
    CHECK(clock.Alpha() >= 0.0f);
    CHECK(clock.Alpha() < 1.0f);

    // And the clock still works afterwards: the accumulator was not left holding garbage.
    CHECK(clock.Advance(kTick) == 1);
}

TEST_CASE("Clock: Reset clears the accumulator and the dropped count")
{
    SimClock clock;
    (void)clock.Advance(2.0f);
    REQUIRE(clock.DroppedSteps() > 0);

    clock.Reset();
    CHECK(clock.DroppedSteps() == 0);
    CHECK(clock.Alpha() == doctest::Approx(0.0f));
}

TEST_CASE("Clock: a nonsense tick falls back to 60 Hz rather than never advancing")
{
    // A zero or negative tick would loop forever or never step. Neither is a useful failure.
    CHECK(SimClock(0.0f).Tick() == doctest::Approx(kTick));
    CHECK(SimClock(-1.0f).Tick() == doctest::Approx(kTick));
    CHECK(SimClock(kTick).Tick() == doctest::Approx(kTick));
}
