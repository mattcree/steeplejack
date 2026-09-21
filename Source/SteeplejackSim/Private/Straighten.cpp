#include "Straighten.h"

#include "Tuning.h"

#include <algorithm>
#include <cmath>

namespace sj {

namespace {

constexpr float kMmPerMetre = 1000.0f;     // literal: millimetres in a metre
constexpr float kDegToRad = 0.017453292f;  // literal: pi / 180
constexpr float kTiny = 1.0e-5f;           // literal: float comparison tolerance

}  // namespace

void Straighten::Begin(float heightM, float leanDegrees, const Tuning&) noexcept
{
    heightM_ = std::max(heightM, kTiny);
    state_ = StraightenState{};
    // How far the top is out of plumb, which is the number the whole job is about and the one the
    // owner quotes at you: "she is four feet out of upright".
    state_.leanAtTopM = heightM_ * std::sin(leanDegrees * kDegToRad);
    state_.startedAtM = state_.leanAtTopM;
    plan_ = StraightenPlan{};
    cut_ = false;
}

StraightenPlan Straighten::Plan(float cutHeightM, float takeOutMm, float radiusAtCutM,
                                const Tuning& t) const noexcept
{
    StraightenPlan p{};
    p.cutHeightM = std::clamp(cutHeightM, t.GetF("straightenCutMinHeightM"),
                              heightM_ * t.GetF("straightenCutMaxShare"));
    p.takeOutMm = std::max(takeOutMm, 0.0f);

    // Closing a wedge of thickness t across a width w tilts everything above it by t/w, so the top
    // moves (H - h) * t / w. The width the cut acts across is the shaft, not the wall: it is the
    // whole section that hinges.
    const float width = std::max(radiusAtCutM * 2.0f, kTiny);
    const float above = std::max(heightM_ - p.cutHeightM, 0.0f);
    p.leverage = above / (width * kMmPerMetre);
    p.bringsBackM = p.takeOutMm * p.leverage;

    // And the risk, which is why you do not simply cut as high as you can. The higher the cut, the
    // more the shaft above it swings while she comes back.
    p.riskShare = std::clamp(p.cutHeightM / (heightM_ * t.GetF("straightenCutMaxShare")), 0.0f,
                             1.0f) * t.GetF("straightenRiskAtTopShare");
    return p;
}

bool Straighten::Cut(const StraightenPlan& plan, const Tuning& t) noexcept
{
    if (cut_ || plan.takeOutMm <= 0.0f)
    {
        return false;
    }
    plan_ = plan;
    cut_ = true;
    state_.settling = true;
    state_.swayCm = plan.riskShare * t.GetF("straightenSwayCmAtFullRisk");
    // Cut too high and she does not come back, she comes down. The trade's own worst case: a
    // straightening in 1873 that toppled while the man who ordered it was watching from a hill.
    if (plan.riskShare > t.GetF("straightenCollapseRisk"))
    {
        state_.collapsed = true;
        state_.settling = false;
        state_.verdict = PlumbVerdict::Down;
    }
    return true;
}

void Straighten::DrawWedge(float share, const Tuning& t) noexcept
{
    if (!cut_ || state_.collapsed)
    {
        return;
    }
    // Smallest first. Each one lets a little of the movement out, and the set is the whole of it.
    const float want = plan_.bringsBackM * std::clamp(share, 0.0f, 1.0f);
    state_.settledM = std::max(state_.settledM, want);
    state_.leanAtTopM = state_.startedAtM - state_.settledM;
    (void)t;
}

void Straighten::Step(float hours, const Tuning& t) noexcept
{
    if (!cut_ || state_.collapsed || !state_.settling)
    {
        return;
    }
    const float total = std::max(t.GetF("straightenSettleHours"), kTiny);
    const float share = std::clamp(hours / total, 0.0f, 1.0f);
    state_.settledM = std::min(state_.settledM + plan_.bringsBackM * share, plan_.bringsBackM);
    state_.leanAtTopM = state_.startedAtM - state_.settledM;
    // The sway dies away as she comes to rest.
    state_.swayCm *= (1.0f - share);
    if (state_.settledM >= plan_.bringsBackM - kTiny)
    {
        state_.settling = false;
        state_.swayCm = 0.0f;
    }
}

StraightenState Straighten::Settled(const Tuning& t) const noexcept
{
    StraightenState s = state_;
    if (s.collapsed)
    {
        s.verdict = PlumbVerdict::Down;
        return s;
    }
    // The whole movement, plus the weeks of overshoot afterwards — she keeps going the way you
    // sent her. Which is why the aim is a little short of plumb rather than plumb.
    const float full = s.startedAtM - plan_.bringsBackM;
    const float over = plan_.bringsBackM * t.GetF("straightenOvershootShare");
    s.leanAtTopM = full - over;
    s.settledM = plan_.bringsBackM + over;
    s.settling = false;
    s.swayCm = 0.0f;

    const float out = std::fabs(s.leanAtTopM);
    const bool past = (s.leanAtTopM * s.startedAtM) < 0.0f;   // gone over the other way
    if (out <= t.GetF("straightenUprightToleranceM"))
    {
        s.verdict = PlumbVerdict::Upright;
    }
    else if (past)
    {
        // Over the other way is worse than short of it: you have used up the cut and she is now
        // leaning somewhere nobody planned for.
        s.verdict = PlumbVerdict::Worse;
    }
    else if (out <= t.GetF("straightenShortToleranceM"))
    {
        s.verdict = PlumbVerdict::Short;
    }
    else
    {
        s.verdict = PlumbVerdict::Standing;
    }
    return s;
}

}  // namespace sj
