// Nerve — METER-002. See Meters.h for what nerve is for.
//
// Every value is tuned. The formula is the one written in docs/01-gdd/03-meters-grip-nerve.md and
// it is transcribed here term for term, because a nerve curve that quietly differs from the design
// doc is a game that is harder or easier than anyone decided.

#include "Meters.h"

#include "Tuning.h"

#include <algorithm>
#include <string>

namespace sj {
namespace nerve {
namespace {

const char* ExposureKeyFor(Exposure exposure) noexcept
{
    switch (exposure)
    {
    case Exposure::Platform: return "exposureFactor.platform";
    case Exposure::Ladder:   return "exposureFactor.ladder";
    case Exposure::Hanging:  return "exposureFactor.hanging";
    case Exposure::Overhang: return "exposureFactor.overhang";
    }
    return "exposureFactor.overhang";   // unreachable; the worst case is the safe default
}

std::string ShockKeyFor(std::string_view event)
{
    return "nerveShock." + std::string(event);
}

}  // namespace

// ---------------------------------------------------------------- the drain

float HeightFactor(const MeterContext& ctx, const Tuning& t) noexcept
{
    const float reference = t.GetF("nerveHeightRefMetres");
    const float lo = t.GetF("nerveHeightFactorMin");
    const float hi = t.GetF("nerveHeightFactorMax");

    // Clamped at both ends, and the top matters more than the bottom: fear saturates. A 110 m stack
    // is not three times as frightening as a 40 m one forever, and without the cap the tallest
    // level would be unplayable for reasons no designer chose.
    if (reference <= 0.0f)
    {
        return lo;   // a zero reference would divide by nothing; the floor is the safe answer
    }
    return std::clamp(ctx.height / reference, lo, hi);
}

float WindFactor(const MeterContext& ctx, const Tuning& t) noexcept
{
    const float reference = t.GetF("nerveWindRefMetresPerSecond");
    if (reference <= 0.0f)
    {
        return 1.0f;
    }
    // 1 + wind/ref, so still air costs nothing extra rather than costing nothing at all.
    //
    // Negative wind speeds clamp to zero rather than reducing the factor below 1. A wind blowing
    // the other way is still wind; a negative here would be a bug upstream, and letting it make
    // the climber calmer is the wrong way to surface one.
    return 1.0f + (std::max(ctx.windSpeed, 0.0f) / reference);
}

float ExposureFactor(Exposure exposure, const Tuning& t) noexcept
{
    return t.GetF(ExposureKeyFor(exposure));
}

float DrainRate(const Meters& m, const MeterContext& ctx, const Tuning& t) noexcept
{
    return t.GetF("nerveBaseDrainPerSecond") * HeightFactor(ctx, t) * WindFactor(ctx, t) *
           ExposureFactor(m.exposure, t);
}

void Step(Meters& m, float dt, const MeterContext& ctx, const Tuning& t) noexcept
{
    m.nerve -= DrainRate(m, ctx, t) * dt;

    // Clamped to the *current* ceiling, not to nerveMax: the cigarette lowers the ceiling for the
    // rest of the shift and nerve must not drift back above it.
    m.nerve = std::clamp(m.nerve, 0.0f, m.nerveMax);
}

// ---------------------------------------------------------------- shocks

bool IsKnownShock(std::string_view event, const Tuning& t) noexcept
{
    return t.Has(ShockKeyFor(event));
}

float ShockAmount(std::string_view event, const Tuning& t) noexcept
{
    const std::string key = ShockKeyFor(event);
    if (!t.Has(key))
    {
        return 0.0f;
    }
    return t.GetF(key);
}

void Shock(Meters& m, std::string_view event, const Tuning& t) noexcept
{
    // Unknown events do nothing rather than throwing — this function is noexcept by contract, and
    // the alternative on a typo is std::terminate. See the note in Meters.h; test_nerve.cpp guards
    // the realistic case by asserting every nerveShock.* key in the data is known here.
    m.nerve = std::clamp(m.nerve + ShockAmount(event, t), 0.0f, m.nerveMax);
}

// ---------------------------------------------------------------- reported state

int32_t Band(float nerve, const Tuning& t) noexcept
{
    // Thresholds are floors: at exactly 70 you are still calm. Written as >= so a designer moving
    // a boundary moves it to the value they typed rather than to one less than it.
    if (nerve >= t.GetF("nerveBands.calm"))
    {
        return 0;
    }
    if (nerve >= t.GetF("nerveBands.uneasy"))
    {
        return 1;
    }
    if (nerve >= t.GetF("nerveBands.bad"))
    {
        return 2;
    }
    return 3;  // literal: band index, fixed by interfaces.md (0 calm .. 3 bad), not a tunable
}

bool Frozen(const Meters& m) noexcept
{
    return m.nerve <= 0.0f;
}

void ReduceMax(Meters& m, float delta, const Tuning& t) noexcept
{
    (void)t;
    // delta is signed, and the tuned penalties are negative. A positive delta is ignored: the
    // ceiling only ever falls within a shift, so a sign error upstream cannot become free headroom.
    m.nerveMax = std::max(m.nerveMax + std::min(delta, 0.0f), 0.0f);
    m.nerve = std::min(m.nerve, m.nerveMax);
}

Meters FreshShift(const Tuning& t) noexcept
{
    Meters m{};
    m.grip = t.GetF("gripMax");
    m.nerveMax = t.GetF("nerveMax");
    m.nerve = t.GetF("nerveStart");   // 90, not 100 — you are always slightly on edge
    m.stance = Stance::OneHand;
    m.exposure = Exposure::Ladder;
    return m;
}

}  // namespace nerve
}  // namespace sj
