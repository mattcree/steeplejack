// Getting your nerve back — METER-004. See Recovery.h.

#include "Recovery.h"

#include "Meters.h"
#include "Tuning.h"

#include <algorithm>

namespace sj::recover {

float Duration(Recovery action, const Tuning& t) noexcept
{
    switch (action)
    {
    case Recovery::Tea:       return t.GetF("recover.teaSeconds");
    case Recovery::Cigarette: return t.GetF("recover.cigaretteSeconds");
    case Recovery::View:      return t.GetF("recover.viewSeconds");
    case Recovery::None:      return 0.0f;
    }
    return 0.0f;
}

float Amount(Recovery action, const Tuning& t) noexcept
{
    switch (action)
    {
    case Recovery::Tea:       return t.GetF("recover.teaAmount");
    case Recovery::Cigarette: return t.GetF("recover.cigaretteAmount");
    case Recovery::View:      return t.GetF("recover.viewAmount");
    case Recovery::None:      return 0.0f;
    }
    return 0.0f;
}

Refusal CanStart(Recovery action, const Meters& m, const MeterContext& ctx, bool bothHandsFree,
                 bool facingOut, const Tuning& t) noexcept
{
    (void)m;
    switch (action)
    {
    case Recovery::Tea:
        // Acceptance 3. A flask, a cup and a lid is two hands; you cannot brew up holding a rung.
        if (!bothHandsFree)
        {
            return {"you need both hands for a brew — belt on, or get to a platform"};
        }
        return {};
    case Recovery::Cigarette:
        return {};   // anywhere. That is the whole of its appeal and the whole of its danger.
    case Recovery::View:
        // Acceptance 5. The view is out, and it is high up; staring at the brickwork from 3 m is not
        // looking at the view.
        if (ctx.height < t.GetF("recover.viewAboveMetres"))
        {
            return {"not high enough to have a view worth looking at"};
        }
        if (!facingOut)
        {
            return {"turn round — the view is behind you"};
        }
        return {};
    case Recovery::None:
        return {"nothing to do"};
    }
    return {"nothing to do"};
}

void Begin(RecoveryState& s, Recovery action, Meters& m, const Tuning& t) noexcept
{
    s = RecoveryState{};
    s.action = action;
    if (action == Recovery::Cigarette)
    {
        // Acceptance 2: the ceiling comes down for the rest of the shift, and it comes down on the
        // first draw. ReduceMax takes the signed penalty as stored.
        nerve::ReduceMax(m, t.GetF("recover.cigaretteMaxNervePenalty"), t);
    }
}

bool Step(RecoveryState& s, Meters& m, float dt, const Tuning& t) noexcept
{
    if (s.action == Recovery::None)
    {
        return false;
    }
    const float total = Duration(s.action, t);
    const float amount = Amount(s.action, t);
    const float step = std::min(dt, std::max(total - s.elapsed, 0.0f));
    s.elapsed += step;

    // Steadily, not at the end, so an interruption keeps what it had given.
    const float grant = (total > 0.0f) ? amount * step / total : 0.0f;
    m.nerve = std::clamp(m.nerve + grant, 0.0f, m.nerveMax);
    s.granted += grant;

    if (s.elapsed >= total)
    {
        s.action = Recovery::None;
        return true;
    }
    return false;
}

void Interrupt(RecoveryState& s) noexcept
{
    s.action = Recovery::None;
}

float Progress(const RecoveryState& s, const Tuning& t) noexcept
{
    const float total = Duration(s.action, t);
    return (total > 0.0f) ? std::clamp(s.elapsed / total, 0.0f, 1.0f) : 0.0f;
}

float PassiveRate(const MeterContext& ctx, bool onPlatform, const Tuning& t) noexcept
{
    float rate = 0.0f;
    if (onPlatform)
    {
        rate += t.GetF("recover.platformStandPerSecond");
    }
    if (ctx.height < t.GetF("recover.descendBelowMetres"))
    {
        rate += t.GetF("recover.descendBelow20mPerSecond");
    }
    return rate;
}

}  // namespace sj::recover
