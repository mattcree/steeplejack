#include "Band.h"

#include "Tuning.h"

#include <algorithm>
#include <cmath>

namespace sj {

namespace {

constexpr float kTiny = 1.0e-4f;     // literal: float comparison tolerance

// How far apart two bolts are round the ring, as a fraction of the way round: 0 is the same bolt,
// 1 is dead opposite. That is the number the star sequence is trying to keep at 1.
float Apart(int32_t a, int32_t b, int32_t n)
{
    if (n <= 1)
    {
        return 1.0f;
    }
    const int32_t raw = std::abs(a - b) % n;
    const int32_t round_the_other_way = std::min(raw, n - raw);
    return static_cast<float>(round_the_other_way) / (static_cast<float>(n) * 0.5f);
}

}  // namespace

void Band::Begin(int32_t bolts, const Tuning&)
{
    tension_.assign(static_cast<std::size_t>(std::max(bolts, 1)), 0.0f);
    order_.clear();
    sequence_ = 1.0f;
}

bool Band::Tighten(int32_t bolt, float amount, const Tuning& t)
{
    if (bolt < 0 || bolt >= static_cast<int32_t>(tension_.size()))
    {
        return false;
    }
    const auto u = static_cast<std::size_t>(bolt);
    tension_[u] = std::min(tension_[u] + std::max(amount, 0.0f), 1.0f);

    // The order, judged against the bolt you have just done — and only that one.
    //
    // A first attempt averaged the distance over the last four, on the reasoning that a fitter
    // thinks "opposite the ones I have just done" rather than "opposite the last one". It does not
    // work, and the reason is worth writing down: over any four consecutive picks of a permutation
    // that covers the whole ring, the mean distance comes out the same whatever order you use. The
    // star and working round in sequence both scored 0.625 and the verb had no puzzle in it.
    //
    // What actually separates them is the step. Round the ring, the bolt before is always the one
    // next door — a quarter of the way, every time. On the star it is always about three quarters.
    if (!order_.empty())
    {
        const float here = Apart(bolt, order_.back(), static_cast<int32_t>(tension_.size()));
        // Eased, so one pair done the wrong way about is a wobble rather than a verdict.
        sequence_ = sequence_ * (1.0f - t.GetF("bandSequenceWeight"))
                    + here * t.GetF("bandSequenceWeight");
    }
    order_.push_back(bolt);
    return true;
}

BandState Band::State(const Tuning& t) const noexcept
{
    BandState s{};
    s.bolts = static_cast<int32_t>(tension_.size());
    if (s.bolts == 0)
    {
        return s;
    }

    s.tightest = *std::max_element(tension_.begin(), tension_.end());
    s.slackest = *std::min_element(tension_.begin(), tension_.end());
    const float seat = t.GetF("bandSeatTension");
    for (const float v : tension_)
    {
        if (v >= seat)
        {
            ++s.tightened;
        }
    }

    // Ovality is two things added together, and both are real. The spread — how unevenly the ring
    // is pulled up at all — and the ORDER, because steel drawn in behind you while it still stands
    // off in front is oval even if every bolt ends up at the same number.
    const float spread = s.tightest - s.slackest;
    const float from_order = (1.0f - sequence_) * t.GetF("bandSequenceWeight");
    s.ovality = std::clamp(spread * (1.0f - t.GetF("bandSequenceWeight")) + from_order, 0.0f, 1.0f);

    const bool all_up = s.slackest >= seat - kTiny;
    if (s.ovality > t.GetF("bandOvalFailAt"))
    {
        s.fit = BandFit::Oval;
    }
    else if (all_up)
    {
        s.fit = BandFit::Seated;
        s.seated = true;
    }
    else if (s.tightest < kTiny)
    {
        s.fit = BandFit::Loose;
    }
    else
    {
        s.fit = BandFit::True;
    }
    return s;
}

}  // namespace sj
