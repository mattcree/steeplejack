#include "Top.h"

#include "Rng.h"
#include "Tuning.h"

#include <algorithm>
#include <cmath>

namespace sj {

namespace {

// One brick's mortar, from the seed and the brick's own number. Not an Rng stream per brick —
// a stream would mean the mortar of brick 400 depends on how many times you sounded brick 12, and
// the whole point of the read-ahead skill is that a brick is what it is before you touch it.
float GiveFor(uint64_t seed, int32_t index, const Tuning& t)
{
    Rng rng(seed ^ (static_cast<uint64_t>(index) * 0x9E3779B97F4A7C15ULL));
    return rng.RangeFloat(t.GetF("giveLo"), t.GetF("giveHi"));
}

}  // namespace

void Top::Begin(float heightM, float takeDownToM, uint64_t seed, const Tuning& t)
{
    heightM_ = heightM;
    downToM_ = takeDownToM;
    seed_ = seed;
    brickIndex_ = 0;
    courseM_ = t.GetF("courseHeightMetres");
    perCourse_ = std::max(1, static_cast<int32_t>(
        std::lround(t.GetF("interactiveBricksPerMetre") * courseM_)));
    sinceJam_ = 0;

    Rng rng(seed ^ 0x70DULL);
    jamAt_ = rng.RangeInt(t.GetI("jamAfterBricksFewest"), t.GetI("jamAfterBricksMost"));

    state_ = TopState{};
    state_.bricksLeft = perCourse_;
    NextBrick(t);
}

void Top::NextBrick(const Tuning& t) noexcept
{
    state_.stroke = Stroke::Idle;
    state_.load = 0.0f;
    state_.sounded = false;
    state_.give = GiveFor(seed_, brickIndex_, t);
}

void Top::Sound() noexcept
{
    state_.sounded = true;
}

void Top::Seat() noexcept
{
    state_.stroke = Stroke::Seated;
    state_.load = 0.0f;
}

void Top::Lever(float seconds, const Tuning& t) noexcept
{
    if (state_.stroke != Stroke::Seated && state_.stroke != Stroke::Levering
        && state_.stroke != Stroke::Given)
    {
        return;
    }
    state_.stroke = Stroke::Levering;
    state_.load = std::min(1.0f, state_.load + seconds * t.GetF("leverLoadPerSecond"));
    if (state_.load >= state_.give)
    {
        // The tick. Past here the joint has let go and you are only loading the brick itself,
        // which is why holding on breaks it.
        state_.stroke = Stroke::Given;
    }
}

Prise Top::Release(const Tuning& t)
{
    if (state_.stroke == Stroke::Idle)
    {
        return Prise::Nothing;
    }
    // A sounded brick gives you a wider window, because you knew it was coming.
    // The window is authored in milliseconds of a real stroke; the load runs 0..1 over
    // `prisePerBrickSeconds`, so a millisecond is worth that much load. Sounding the joint first
    // buys you the sharp-bolster window, because you knew which brick this was.
    const float per_ms = 1.0f / (t.GetF("prisePerBrickSeconds") * 1000.0f);
    const float window = per_ms * (state_.sounded ? t.GetF("giveWindowMs.sharpBolster")
                                                  : t.GetF("giveWindowMs.base"));
    const float over = state_.load - state_.give;

    Prise out = Prise::Nothing;
    if (over >= 0.0f && over <= window)
    {
        out = Prise::Clean;
        ++state_.clean;
    }
    else if (over > window)
    {
        out = Prise::Snapped;
        ++state_.snapped;
    }

    if (out != Prise::Nothing)
    {
        ++brickIndex_;
        --state_.bricksLeft;
        if (state_.bricksLeft <= 0)
        {
            // The course is off. The rest of it resolves itself — 07-topping-system.md is explicit
            // that we are not simulating eight hundred bricks a metre.
            state_.bricksLeft = perCourse_;
            state_.removedM += courseM_;
        }
    }
    NextBrick(t);
    return out;
}

void Top::Drop(bool downTheFlue, const Tuning& t) noexcept
{
    if (!downTheFlue)
    {
        return;   // over the side; what it hits is the level's business, not the flue's
    }
    const float share = 1.0f / std::max(1.0f, static_cast<float>(t.GetI("flueCapacityBricks")));
    state_.flueFullShare = std::min(1.0f, state_.flueFullShare + share);
    ++sinceJam_;
    if (sinceJam_ >= jamAt_)
    {
        state_.jammed = true;
    }
}

void Top::ClearJam() noexcept
{
    state_.jammed = false;
    sinceJam_ = 0;
}

float Top::ToGoM() const noexcept
{
    return std::max(0.0f, (heightM_ - state_.removedM) - downToM_);
}

float Top::CleanShare() const noexcept
{
    const int32_t out = state_.clean + state_.snapped;
    if (out <= 0)
    {
        return 0.0f;
    }
    return static_cast<float>(state_.clean) / static_cast<float>(out);
}

TopVerdict Top::Judge(float daylightLeftShare, const Tuning& t) const noexcept
{
    if (!Done() || daylightLeftShare < t.GetF("daylightNeededShare"))
    {
        return TopVerdict::Abandoned;
    }
    const float share = CleanShare();
    if (share >= t.GetF("craftsmanShare"))
    {
        return TopVerdict::Craftsman;
    }
    if (share >= t.GetF("workmanlikeShare"))
    {
        return TopVerdict::Workmanlike;
    }
    return TopVerdict::Rough;
}

}  // namespace sj
