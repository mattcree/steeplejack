#pragma once

// Getting a steel band round a cracked chimney — the BAND archetype.
//
// 05-mission-types.md §D. A shaft cracks vertically from thermal cycling, lightning and
// settlement, and nothing in brickwork resists hoop tension — unbanded, it separates into staves.
// "It is rare to find any radial brick chimney now in service without several exterior steel
// tension bands in the upper portion."
//
// ## The mechanic, and why it is a good one
//
// A band is segments bolted into a ring and then **post-tensioned by those same bolts**. The trade
// is emphatic that "loose bands are virtually worthless", so the job is not putting the band on,
// it is pulling it up — and the order you pull it up in is the whole puzzle.
//
// Tighten the bolts in sequence round the ring and the steel draws in where you have been and
// stands off where you have not: the band goes **oval** and will not seat. Tighten opposite pairs —
// the star sequence any fitter would use on a flange or a wheel — and it comes in true. That is a
// real constraint, it is entirely about order rather than about timing or aim, and it is the first
// verb in this game that is a *puzzle* rather than a test of the hands.
//
// The failure it produces is also unusually fair: an oval band is visible as it happens, it is
// recoverable if you spot it early by working the other side, and it is only fatal once everything
// is tight.
//
// ## And the one that kills you
//
// The band that is already on the chimney is the hazard. A witnessed failure: the topmost strap of
// a mill chimney let go while a man was kneeling under it, and "from snapping to the strap hitting
// the ground took six seconds". The cause was the bolt — "nothing left of it", so any change of
// temperature worked the band, and "the slightest tap would have snapped it". That is modelled as
// a rusted bolt you can find by sounding it before you put weight anywhere near it.

#include "Export.h"

#include <cstdint>
#include <vector>

namespace sj {

class Tuning;

// How a band reads when you stand back from it.
enum class BandFit : uint8_t { Loose, True, Oval, Seated };

struct BandState
{
    BandFit fit{BandFit::Loose};
    float   tightest{};      // 0..1
    float   slackest{};      // 0..1
    float   ovality{};       // 0 perfectly round, 1 hopeless
    int32_t bolts{};
    int32_t tightened{};     // bolts at or past the seating tension
    bool    seated{};
};

// One steel band round the shaft. `bolts` is how many segments it is made of — the real ones run
// from four segments with two bolts each to a hundred and twenty sections with two hundred and
// forty bolts, so it is per-level data rather than a constant.
class SJ_API Band
{
public:
    void Begin(int32_t bolts, const Tuning& t);

    // Pull one up by `amount` of its travel. Returns false for a bolt that is not there.
    bool Tighten(int32_t bolt, float amount, const Tuning& t);

    // How far round the ring the last few bolts have been from each other — the thing the star
    // sequence is for. 1.0 is dead opposite every time, 0 is working round in order.
    float SequenceQuality() const noexcept { return sequence_; }

    BandState State(const Tuning& t) const noexcept;

    // Every bolt's own tension. The instrument needs this rather than a count, because "six of
    // twelve" cannot show you that the six are all on one side, which is the only thing about an
    // oval band that a player can act on.
    const std::vector<float>& Tensions() const noexcept { return tension_; }

private:
    std::vector<float>   tension_;
    std::vector<int32_t> order_;      // the bolts touched, in the order they were touched
    float                sequence_{1.0f};
};

}  // namespace sj
