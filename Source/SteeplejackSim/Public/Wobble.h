#pragma once

// How steady your hands are — METER-003.
//
// **This is the only place wobble is computed.** Every skill verb reads it; a verb that works out
// its own wobble is rejected in review, because the moment two of them disagree the player is
// being told two different stories about the same hands. A verb that needs to be harder takes a
// multiplier — it does not reimplement this.
//
// Wobble is where the two meters actually bite. Grip and nerve do not damage you; they make your
// hands worse, and this is the number that "worse" means. It is the mechanism behind the whole
// two-meter design: run either one down and the job gets harder rather than the health bar getting
// shorter.

#include "Export.h"
#include "Types.h"

namespace sj {

class Tuning;

// Reticle drift in degrees. Larger is worse.
//
// base × stance × nerve band × grip tremor, plus the wind. `gust` is 0-1, the current gust
// strength from ENV-003; pass 0 in still air.
SJ_API float WobbleAmplitudeDeg(const Meters& m, const MeterContext& ctx, float gust,
                                const Tuning& t) noexcept;

}  // namespace sj
