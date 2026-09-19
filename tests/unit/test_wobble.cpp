// Wobble — METER-003's acceptance, by number.
//
// The behavioural tests (a better stance is steadier, fear steps in bands, a gust adds) live beside
// the hammer in test_hammer.cpp, because the hammer is what they are about. These are the task's
// own criteria: the formula, the calm baseline, and purity. Criterion 3 — "6x base at the worst" —
// is not here: the tuning gives 13.1x, and which of the two is the target is a question for a
// human (BLOCKED.md, METER-003). Criterion 4 is convention rule 19, in tools/check_conventions.py.

#include "doctest.h"

#include "Meters.h"
#include "Tuning.h"
#include "Wobble.h"

#include <filesystem>
#include <string>

using sj::MeterContext;
using sj::Meters;
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

Meters Calm(sj::Stance stance)
{
    Meters m = sj::nerve::FreshShift(Tune());
    m.grip = 100.0f;
    m.stance = stance;
    return m;
}

}  // namespace

TEST_CASE("Wobble: acceptance 2, belted, calm, full grip and still air is exactly the base")
{
    const float w = sj::WobbleAmplitudeDeg(Calm(sj::Stance::Belted), MeterContext{}, 0.0f, Tune());
    CHECK(w == doctest::Approx(Tune().GetF("baseWobbleDegrees")));
}

TEST_CASE("Wobble: acceptance 1, it is the product of the tuned factors, gust added on")
{
    // Every stance, every nerve band, a grip below the tremor threshold, and a part gust: the
    // answer is what the tuning file says it should be, worked out here independently.
    const float base = Tune().GetF("baseWobbleDegrees");
    const float threshold = Tune().GetF("gripTremorThreshold");
    const float atZero = Tune().GetF("gripWobbleAtZero");
    const char* stances[] = {"oneHand", "hookedLeg", "clipped", "belted", "chair"};
    const struct { float nerve; const char* key; } bands[] = {
        {95.0f, "calm"}, {55.0f, "uneasy"}, {30.0f, "bad"}, {5.0f, "bad"}};

    for (int s = 0; s < 5; ++s)
    {
        for (const auto& b : bands)
        {
            Meters m = Calm(static_cast<sj::Stance>(s));
            m.nerve = b.nerve;
            m.grip = threshold * 0.25f;
            const float gust = 0.4f;
            const float tremor = 1.0f + (1.0f - m.grip / threshold) * (atZero - 1.0f);
            const float want = base * Tune().GetF(std::string("stanceWobbleMultiplier.") + stances[s])
                * Tune().GetF(std::string("nerveWobbleMultiplier.") + b.key) * tremor
                + gust * Tune().GetF("gustWobbleDegrees");
            CAPTURE(stances[s]);
            CAPTURE(b.key);
            CHECK(sj::WobbleAmplitudeDeg(m, MeterContext{}, gust, Tune()) == doctest::Approx(want));
        }
    }
}

TEST_CASE("Wobble: acceptance 5, pure — the same inputs give the same answer, to the bit")
{
    Meters m = Calm(sj::Stance::OneHand);
    m.grip = 7.0f;
    m.nerve = 12.0f;
    MeterContext ctx{};
    ctx.carryingLadder = true;
    const float first = sj::WobbleAmplitudeDeg(m, ctx, 0.8f, Tune());
    for (int i = 0; i < 1000; ++i)
    {
        (void)sj::WobbleAmplitudeDeg(Calm(sj::Stance::Chair), MeterContext{}, 0.1f, Tune());
    }
    CHECK(sj::WobbleAmplitudeDeg(m, ctx, 0.8f, Tune()) == first);
}
