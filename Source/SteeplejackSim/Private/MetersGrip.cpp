// Grip — METER-001. See Meters.h for what grip is for.
//
// Every number in here comes from data/tuning/meters.json. That is not ceremony: the stance table
// is the difficulty dial for the whole game, and a designer has to be able to move it during a
// playtest without a programmer (CORE-007's hot reload is the other half of that).

#include "Anchor.h"
#include "Meters.h"

#include "Tuning.h"

#include <algorithm>
#include <cstring>

namespace sj {
namespace grip {
namespace {

// The stance table, keyed the way meters.json spells it. One place, so a new stance is a row in
// the JSON and a line here rather than a hunt through the verbs.
const char* DrainKeyFor(Stance stance) noexcept
{
    switch (stance)
    {
    case Stance::OneHand:   return "gripDrainPerSecond.oneHand";
    case Stance::HookedLeg: return "gripDrainPerSecond.hookedLeg";
    case Stance::Clipped:   return "gripDrainPerSecond.clipped";
    case Stance::Belted:    return "gripDrainPerSecond.belted";
    case Stance::Chair:     return "gripDrainPerSecond.chair";
    }
    return "gripDrainPerSecond.oneHand";   // unreachable; the worst case is the safe default
}

bool HasInjury(const MeterContext& ctx, const char* name) noexcept
{
    return ctx.injury != nullptr && std::strcmp(ctx.injury, name) == 0;
}

}  // namespace

float MaxGrip(const MeterContext& ctx, const Tuning& t) noexcept
{
    const float full = t.GetF("gripMax");
    if (!ctx.cold)
    {
        return full;
    }
    // Cold hands: the ceiling is held down until you have worked long enough to warm up. The
    // player is not told a rule; they notice their grip will not fill, and that the first job of a
    // winter morning is the expensive one.
    const float warmup = t.GetF("gripModifiers.coldWarmupSeconds");
    if (ctx.workedSeconds >= warmup)
    {
        return full;
    }
    return std::min(full, t.GetF("gripModifiers.coldMaxCap"));
}

float SetupSeconds(Stance stance, const Tuning& t) noexcept
{
    switch (stance)
    {
    case Stance::OneHand:   return t.GetF("stanceSetupSeconds.oneHand");
    case Stance::HookedLeg: return t.GetF("stanceSetupSeconds.hookedLeg");
    case Stance::Clipped:   return t.GetF("stanceSetupSeconds.clipped");
    case Stance::Belted:    return t.GetF("stanceSetupSeconds.belted");
    case Stance::Chair:     return t.GetF("stanceSetupSeconds.chair");
    }
    return t.GetF("stanceSetupSeconds.oneHand");   // unreachable; the free one is the safe default
}

bool NeedsRigging(Stance from, Stance to) noexcept
{
    // The enum is ordered worst-to-best (Types.h says so and the static_asserts hold it), so
    // "better" is just "greater" and this does not need its own table to fall out of step with.
    return static_cast<uint8_t>(to) > static_cast<uint8_t>(from);
}

float DrainRate(Stance stance, const MeterContext& ctx, const Tuning& t) noexcept
{
    float rate = t.GetF(DrainKeyFor(stance));

    // Modifiers multiply. A chair drains nothing, so nothing here can make it drain — which is the
    // right behaviour: the point of twenty seconds of rigging is that the weather stops mattering.
    if (ctx.carryingLadder)
    {
        rate *= t.GetF("gripModifiers.carryingLadder");
    }
    if (ctx.wet)
    {
        rate *= t.GetF("gripModifiers.wet");
    }
    if (HasInjury(ctx, "cracked_rib"))
    {
        rate *= t.GetF("gripModifiers.crackedRib");
    }
    if (ctx.gloves)
    {
        // Gloves cost tap-test resolution, which is VERB-001's side of the same trade.
        rate *= t.GetF("gripModifiers.gloves");
    }
    // A ladder that is moving under you is one you hold harder. CLIMB-001 wrote this number and
    // nothing ever read it, which is why a long span used to be free.
    rate *= anchor::GripDrainMultiplier(ctx.span, t);
    return rate;
}

float RecoverRate(const Tuning& t) noexcept
{
    return t.GetF("gripRecoverPerSecond");
}

void Step(Meters& m, float dt, const MeterContext& ctx, const Tuning& t) noexcept
{
    const float ceiling = MaxGrip(ctx, t);

    if (ctx.working)
    {
        m.grip -= DrainRate(m.stance, ctx, t) * dt;
    }
    else
    {
        m.grip += RecoverRate(t) * dt;
    }

    // Clamped every step rather than trusted to stay in range. Grip is read by every verb; one
    // negative value would propagate as a plausible-looking wrong number rather than a crash.
    m.grip = std::clamp(m.grip, 0.0f, ceiling);
}

bool Tremor(const Meters& m, const Tuning& t) noexcept
{
    return m.grip < t.GetF("gripTremorThreshold");
}

bool Slipping(const Meters& m) noexcept
{
    return m.grip <= 0.0f;
}

float SecondsOfWorkLeft(const Meters& m, const MeterContext& ctx, const Tuning& t) noexcept
{
    const float rate = DrainRate(m.stance, ctx, t);
    if (rate <= 0.0f)
    {
        return -1.0f;   // a stance that does not drain; work as long as you like
    }
    return m.grip / rate;
}

}  // namespace grip
}  // namespace sj
