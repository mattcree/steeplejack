// `make watch` — run the simulation and print what it is doing. TOOL-001.
//
// This is not a test and it asserts nothing. It exists so that a human can read a tuning change as
// *behaviour*. meters.json says one-handed grip drain is 8/s; what that means is "about twelve
// seconds of work before you must stop and hold on", against a hundred seconds for a belt round
// the stack. A table cannot show you that. This can, in a second, with no engine and no GPU.
//
// It also exists so that "verified by running it" in a task's Outcome is a claim a reviewer can
// check. Twice this was written citing a harness in a scratch directory, which is worth less than
// no claim at all.
//
// Everything below drives the real sj::SimClock and the real sj::grip::Step. Nothing here
// reimplements a rule — if it did, it would be showing you a different game from the one that
// ships, which is the one failure mode a demonstration must not have.

#include "Clock.h"
#include "Meters.h"
#include "Tuning.h"

#include <cinttypes>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <string>
#include <vector>

namespace {

// Elapsed time is derived from the step count, never accumulated. Adding kTick in a loop is the
// exact float-accumulation mistake CORE-005 exists to remove, and the first draft of this harness
// reproduced it — reporting "45.0 s" after 2703 steps, which is 45.05 s.
double SecondsFor(long long steps)
{
    return static_cast<double>(steps) * static_cast<double>(sj::kTick);
}

const char* StanceName(sj::Stance s)
{
    switch (s)
    {
    case sj::Stance::OneHand:   return "one hand on rung";
    case sj::Stance::HookedLeg: return "hooked leg";
    case sj::Stance::Clipped:   return "clipped safety line";
    case sj::Stance::Belted:    return "belt round the stack";
    case sj::Stance::Chair:     return "bosun's chair";
    }
    return "?";
}

std::string Bar(float value, float max, int width)
{
    const int filled = (max <= 0.0f)
                           ? 0
                           : static_cast<int>((value / max) * static_cast<float>(width) + 0.5f);
    std::string out;
    for (int i = 0; i < width; ++i)
    {
        out += (i < filled) ? "#" : ".";
    }
    return out;
}

std::string FindTuningDir()
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

struct Phase
{
    const char* what;
    sj::Stance  stance;
    bool        working;
    double      seconds;
};

}  // namespace

int main(int argc, char** argv)
{
    const std::string dir = (argc > 1) ? argv[1] : FindTuningDir();
    if (dir.empty())
    {
        std::printf("could not find data/tuning — run from the repo, or pass the path\n");
        return 1;
    }

    const sj::Tuning tuning = sj::Tuning::LoadAll(dir);
    const float max = tuning.GetF("gripMax");

    std::printf("Steeplejack — grip, stepped at 60 Hz by the real SimClock.\n");
    std::printf("tuning %s from %s\n\n", tuning.Hash().substr(0, 12).c_str(), dir.c_str());

    // --- what each stance buys, before watching one --------------------------------------------
    // This is the table from 02-climbing-system.md, computed rather than quoted, so it is the
    // game's answer and not the document's.
    std::printf("  what a stance buys you, at full grip:\n");
    sj::MeterContext quote{};
    quote.working = true;
    for (const sj::Stance s : {sj::Stance::OneHand, sj::Stance::HookedLeg, sj::Stance::Clipped,
                               sj::Stance::Belted, sj::Stance::Chair})
    {
        sj::Meters m{};
        m.stance = s;
        m.grip = max;
        const float left = sj::grip::SecondsOfWorkLeft(m, quote, tuning);
        std::printf("    %-22s %5.1f grip/s   %s\n", StanceName(s),
                    static_cast<double>(sj::grip::DrainRate(s, quote, tuning)),
                    (left < 0.0f) ? "works indefinitely"
                                  : (std::to_string(static_cast<int>(left)) + "s of work").c_str());
    }
    std::printf("\n");

    // --- a shift ------------------------------------------------------------------------------
    const std::vector<Phase> shift = {
        {"climbing to the staging", sj::Stance::OneHand,   false,  3.0},
        {"one-handed, chipping",    sj::Stance::OneHand,   true,   9.0},
        {"holding on, both hands",  sj::Stance::OneHand,   false,  3.0},
        {"hooked a leg through",    sj::Stance::HookedLeg, true,   8.0},
        {"belted on, both hands",   sj::Stance::Belted,    true,   8.0},
        {"back to one hand, tired", sj::Stance::OneHand,   true,  14.0},
    };

    sj::SimClock clock;
    sj::Meters m{};
    m.grip = max;
    m.stance = sj::Stance::OneHand;

    sj::MeterContext ctx{};
    ctx.height = 34.0f;
    ctx.windSpeed = 9.0f;

    long long totalSteps = 0;
    long long lastPrintStep = -60;
    long long tremorStep = -1;
    long long slipStep = -1;

    for (const Phase& p : shift)
    {
        std::printf("-- %s (%s)\n", p.what, StanceName(p.stance));
        m.stance = p.stance;
        ctx.working = p.working;

        const long long phaseEnd = totalSteps + static_cast<long long>(p.seconds * 60.0);
        while (totalSteps < phaseEnd)
        {
            // A real frame, as the engine hands one over. The clock decides how many sim steps
            // that is owed — this loop never assumes.
            const int steps = clock.Advance(1.0f / 60.0f);
            for (int i = 0; i < steps && totalSteps < phaseEnd; ++i)
            {
                sj::grip::Step(m, sj::kTick, ctx, tuning);
                if (ctx.working)
                {
                    // The caller owns this accumulator; grip::Step takes the context by const
                    // reference on purpose. Nothing in the sim advances it yet — see METER-001.
                    ctx.workedSeconds += sj::kTick;
                }
                ++totalSteps;

                // The telegraph interval is from the tremor that *preceded this slip*, not from
                // the first tremor of the session. Grip recovers, so the shake can clear and come
                // back; latching the first one and subtracting reports an interval that never
                // happened. Caught in review by raising gripTremorThreshold, which made the tool
                // claim 28.62s of warning where the real figure was a few seconds.
                if (slipStep < 0)
                {
                    if (sj::grip::Tremor(m, tuning))
                    {
                        if (tremorStep < 0)
                        {
                            tremorStep = totalSteps;
                        }
                    }
                    else
                    {
                        tremorStep = -1;   // recovered; the next shake starts a new warning
                    }

                    if (sj::grip::Slipping(m))
                    {
                        slipStep = totalSteps;
                    }
                }
            }

            if (totalSteps - lastPrintStep >= 60)
            {
                lastPrintStep = totalSteps;
                const float left = sj::grip::SecondsOfWorkLeft(m, ctx, tuning);
                std::printf("   t=%5.2fs  grip [%s] %5.1f  %s%s\n",
                            SecondsFor(totalSteps), Bar(m.grip, max, 24).c_str(),
                            static_cast<double>(m.grip),
                            sj::grip::Tremor(m, tuning) ? "TREMOR  " : "        ",
                            (left < 0.0f) ? "(never drains)"
                                          : (std::string("~") +
                                             std::to_string(static_cast<int>(left)) +
                                             "s of work left").c_str());
            }
        }
    }

    // --- the fairness contract, as a timestamp ------------------------------------------------
    std::printf("\n");
    if (tremorStep > 0 && slipStep > 0)
    {
        std::printf("  telegraph: hands began to shake at t=%.2fs; grip gone at t=%.2fs.\n",
                    SecondsFor(tremorStep), SecondsFor(slipStep));
        std::printf("             %.2fs of warning — rule 7 says the failure must announce itself\n"
                    "             before it happens, and this is that, measured.\n",
                    SecondsFor(slipStep - tremorStep));
    }

    std::printf("\n  %" PRId64 " steps = %.2fs simulated, %" PRId64 " dropped, alpha %.3f\n",
                static_cast<int64_t>(totalSteps), SecondsFor(totalSteps),
                static_cast<int64_t>(clock.DroppedSteps()),
                static_cast<double>(clock.Alpha()));
    return 0;
}
