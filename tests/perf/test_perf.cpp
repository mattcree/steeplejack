// The sim step budget — CORE-005's gate: one tick of the sim in under half a millisecond.
//
// "One tick" is what the game runs every 1/60 s, taken from Jack::step and Jack::stack_step: the
// wind, both meters, passive and active recovery, the slip model, and the ladder stack stepping
// under a climber. The stack is 28 sections, twice the Grey Box, so the budget holds with room.
//
// Timed over many ticks and judged on the mean, with a generous margin for a busy CI machine: the
// point is to catch an accidental O(n²), not to benchmark.

#include "doctest.h"

#include "Anchor.h"
#include "Level.h"
#include "Meters.h"
#include "Recovery.h"
#include "Rng.h"
#include "Slip.h"
#include "Stack.h"
#include "Tuning.h"
#include "Types.h"
#include "Wind.h"

#include <chrono>
#include <filesystem>
#include <string>

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

}  // namespace

TEST_CASE("Perf: one tick of the sim — wind, meters, recovery, slip, a 28-section stack — under 0.5 ms")
{
    const sj::Tuning t = sj::Tuning::LoadAll(DataDir("tuning"));
    const sj::LevelData level = sj::LevelData::LoadFrom(DataDir("levels") + "/00-greybox.json");

    sj::Stack stack;
    int32_t below = 0;
    for (int i = 1; i <= 28; ++i)
    {
        sj::Anchor a{};
        a.height = 4.0f * static_cast<float>(i);
        a.rate = sj::AnchorRate::Sound;
        a.capacityKN = sj::anchor::CapacityKN(a.rate, t);
        const int32_t id = stack.AddAnchor(a);
        stack.AddSection(below, id, sj::Lashing::Full);
        below = id;
    }

    sj::Rng rng(level.Structure().weatherSeed);
    sj::WindModel wind;
    wind.Begin(level.Weather(), rng, t);
    sj::Meters meters = sj::nerve::FreshShift(t);
    sj::MeterContext ctx{};
    ctx.height = 100.0f;
    ctx.windSpeed = 9.0f;
    ctx.working = true;
    sj::RecoveryState recovery{};
    sj::SlipModel slip;

    constexpr int kTicks = 6000;   // a hundred seconds of play
    float now = 0.0f;
    int events = 0;
    const auto t0 = std::chrono::steady_clock::now();
    for (int i = 0; i < kTicks; ++i)
    {
        now += sj::kTick;
        wind.Step(sj::kTick, level.Weather(), rng, t);
        sj::grip::Step(meters, sj::kTick, ctx, t);
        sj::nerve::Step(meters, sj::kTick, ctx, t);
        meters.nerve += sj::recover::PassiveRate(ctx, false, t) * sj::kTick;
        (void)sj::recover::Step(recovery, meters, sj::kTick, t);
        if (sj::grip::Slipping(meters))
        {
            slip.BeginSlip(now, t);
        }
        (void)slip.Resolve(now, false, meters, t);
        const sj::StackEvents ev = stack.Step(sj::kTick, stack.SectionCount() - 1, 1.2f, t);
        events += static_cast<int>(ev.failedAnchors.size());
        meters.grip = 100.0f;   // keep him on: a fall ends the interesting part of the tick
    }
    const double ms = std::chrono::duration<double, std::milli>(
                          std::chrono::steady_clock::now() - t0).count() / kTicks;
    MESSAGE("one sim tick: " << ms * 1000.0 << " µs (budget 500 µs)");
    CHECK(events == 0);   // a Sound stack under one climber holds; the loop did real work, not a fall
    CHECK(ms < 0.5);
}
