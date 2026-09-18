// The slip, the save and the fall — METER-005. See Slip.h for the rule and what is deliberately
// not in it.

#include "Slip.h"

#include "Meters.h"
#include "Tuning.h"

#include <algorithm>
#include <string>

namespace sj {
namespace {

const char* DifficultyKey(Difficulty d) noexcept
{
    switch (d)
    {
    case Difficulty::Assisted: return "difficulty.assisted";
    case Difficulty::Jack:     return "difficulty.jack";
    case Difficulty::OwdHand:  return "difficulty.owd_hand";
    }
    return "difficulty.jack";   // unreachable; the authored default is the safe answer
}

float Tuned(Difficulty d, const char* leaf, const Tuning& t) noexcept
{
    return t.GetF(std::string(DifficultyKey(d)) + "." + leaf);
}

}  // namespace

SlipModel::SlipModel(Difficulty difficulty) noexcept : difficulty_(difficulty) {}

float SlipModel::WindowSeconds(const Tuning& t) const noexcept
{
    // The table is in milliseconds because that is how a designer thinks about a reaction window.
    // Everything else in the sim is seconds, so the conversion happens once, here.
    return Tuned(difficulty_, "slipSaveWindowMs", t) / 1000.0f;   // literal: ms to s
}

float SlipModel::CooldownSeconds(const Tuning& t) const noexcept
{
    return Tuned(difficulty_, "slipSaveCooldownSeconds", t);
}

bool SlipModel::CanSlipSave(float now, const Tuning& t) const noexcept
{
    return (now - lastSaveAt_) >= CooldownSeconds(t);
}

float SlipModel::BeginSlip(float now, const Tuning& t) noexcept
{
    if (handOff_)
    {
        // Already coming off, or left off by the fall this one resolved into. A second trigger
        // buys neither a second window nor a second slip.
        return window_;
    }

    handOff_ = true;
    slipping_ = true;
    slipBegan_ = now;
    window_ = CanSlipSave(now, t) ? WindowSeconds(t) : 0.0f;
    // The end is stored as an absolute time rather than recomputed from a duration every step.
    // `now - slipBegan_ >= window_` is not the same comparison at t=0 and at t=743: the subtraction
    // rounds and the constant does not, so the window closed a step late on a shift that had been
    // running a while. Both sides of `now >= windowEnds_` go through the same rounding.
    windowEnds_ = now + window_;
    return window_;
}

float SlipModel::WindowFractionLeft(float now) const noexcept
{
    if (!slipping_ || window_ <= 0.0f)
    {
        return 0.0f;
    }
    return std::clamp((windowEnds_ - now) / window_, 0.0f, 1.0f);
}

SlipOutcome SlipModel::Resolve(float now, bool grabbed, Meters& m, const Tuning& t) noexcept
{
    if (!slipping_)
    {
        return SlipOutcome::None;
    }

    // The grab is checked before the expiry, so a grab on the very last step of the window counts.
    // The other order loses the frame the player was aiming at, which is the frame they will swear
    // they hit.
    //
    // The `window_ > 0` guard is load-bearing and was a bug without it. A spent budget is a
    // zero-length window, and a zero-length window satisfies `now <= windowEnds_` on the step it
    // opens — so the slip that is supposed to be unsaveable was saved by anyone already holding
    // the key. The budget is the entire reason the second slip is frightening.
    if (window_ > 0.0f && grabbed && now <= windowEnds_)
    {
        slipping_ = false;
        // The cooldown runs from the save, not from the slip: the budget buys saves. Falling does
        // not spend it, because a fall has already cost you the shift.
        lastSaveAt_ = now;

        // Hanging one-handed. Not zero and not full — enough to do something about, which is what
        // makes the save a reprieve you have to act on rather than a reset.
        // 15% of gripMax, not of the *current* ceiling: a MeterContext{} here would read as a
        // climber who has done no work, and on a cold level the cold cap would quietly make the
        // save worth less on the first job of the morning than on the second. The design says
        // 15% of grip, and grip is the tuned number, not a derived one.
        m.grip = t.GetF("gripMax") * t.GetF("slipSaveGripFraction");
        nerve::Shock(m, "slipSave", t);
        return SlipOutcome::Saved;
    }

    if (now >= windowEnds_)
    {
        slipping_ = false;
        return SlipOutcome::Fell;
    }

    return SlipOutcome::None;
}

// ---------------------------------------------------------------- the fall

bool IsTiedOn(Stance stance) noexcept
{
    // A hand on a rung and a leg through it hold *you* up; they tie you to nothing. The three that
    // do are the three you spent time rigging, which is the point of having spent it.
    return stance == Stance::Clipped || stance == Stance::Belted || stance == Stance::Chair;
}

FallResult ResolveFall(Meters& m, const Anchor& tiedTo, const Tuning& t) noexcept
{
    FallResult r{};

    if (!IsTiedOn(m.stance))
    {
        return r;   // nothing to catch you, and nothing loaded
    }

    // A body arrested by a line is not a body hanging on one. `dynamicLoadFactor` is the whole
    // difference between the anchor you thought was adequate and the one that was.
    r.shockLoadKN = t.GetF("playerLoadKN") * t.GetF("dynamicLoadFactor");
    r.capacityKN = tiedTo.capacityKN;
    r.anchorFailed = r.shockLoadKN > tiedTo.capacityKN;
    r.caught = !r.anchorFailed;

    if (r.caught)
    {
        nerve::Shock(m, "caughtByLine", t);
    }
    else
    {
        // It let go. That is a separate fright from the one you were already having, and it is
        // the worst number in the table for a reason.
        nerve::Shock(m, "anchorFail", t);
    }

    return r;
}

}  // namespace sj
