// The fixed-step accumulator — CORE-005. See Clock.h for why the accumulator is an integer.

#include "Clock.h"

#include <cmath>

namespace sj {

SimClock::SimClock(float tick) noexcept
    : tick_(tick > 0.0f ? tick : kTick)   // a zero or negative tick would never advance
{
}

int SimClock::Advance(float realDelta) noexcept
{
    // A NaN or negative delta contributes nothing rather than poisoning the accumulator. One bad
    // frame from a paused debugger or a clock that stepped backwards should cost that frame, not
    // the session.
    if (!std::isfinite(realDelta) || realDelta <= 0.0f)
    {
        return 0;
    }

    // Convert to exact sub-tick units once, in double, and never do float arithmetic on the
    // accumulator again. This is the line that makes 60 steps per second true at every frame rate.
    const double units = (static_cast<double>(realDelta) / static_cast<double>(tick_)) *
                         static_cast<double>(kUnitsPerTick);

    // A single enormous delta is clamped before it reaches the accumulator, so a garbage frame
    // cannot overflow the integer or bank hours of simulated time.
    constexpr double kMaxUnitsPerFrame = static_cast<double>(kUnitsPerTick) * 1000000.0;
    accumulator_ += static_cast<int64_t>(std::llround(std::fmin(units, kMaxUnitsPerFrame)));

    int steps = 0;
    while (accumulator_ >= kUnitsPerTick && steps < kMaxCatchUpSteps)
    {
        accumulator_ -= kUnitsPerTick;
        ++steps;
    }

    // Anything still owed beyond the cap is discarded, not carried. Carrying it is the spiral of
    // death: the next frame would owe those steps plus its own and fall further behind every
    // frame. Dropping simulated time makes a hitch a hitch rather than a death spiral.
    if (accumulator_ >= kUnitsPerTick)
    {
        const int64_t owed = accumulator_ / kUnitsPerTick;
        dropped_ += static_cast<int>(owed);
        accumulator_ -= owed * kUnitsPerTick;
    }

    return steps;
}

float SimClock::Alpha() const noexcept
{
    // accumulator_ is always in [0, kUnitsPerTick) here, so this cannot reach 1.0 and
    // presentation can never be asked to extrapolate past the state the sim has reached.
    return static_cast<float>(static_cast<double>(accumulator_) /
                              static_cast<double>(kUnitsPerTick));
}

int SimClock::DroppedSteps() const noexcept
{
    return dropped_;
}

float SimClock::Tick() const noexcept
{
    return tick_;
}

void SimClock::Reset() noexcept
{
    accumulator_ = 0;
    dropped_ = 0;
}

}  // namespace sj
