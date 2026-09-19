#pragma once

// Getting your nerve back — METER-004.
//
// Nerve only ever drained. A 55 m climb in wind drains it to nothing — frozen — and there was no way
// back up from there except to fall off. The four recoveries in 03-meters-grip-nerve.md are what
// turn nerve from a countdown into a thing the player manages:
//
//   stand still on a platform     +2/s        a staging, or the top
//   brew up                       +40 / 12 s  a stable stance, both hands free
//   a cigarette                   +18 / 6 s   anywhere — and 5 off your ceiling for the shift
//   get below 20 m                +1.5/s      the height you gave up
//   look at the view, deliberately +12 / 8 s   facing out, high up
//
// The tea break is the design's favourite thing in the game and the cigarette is its temptation:
// fast, works on one hand at 50 m, and every one permanently lowers the most nerve you can have
// until the shift ends. The player who smokes their way up arrives at the top with a smaller tank.
//
// The timed ones grant their nerve steadily over their duration rather than at the end, so
// interrupting one part-way keeps what it had given (acceptance 4) — a tea break cut short by a
// gust is still most of a tea break.

#include "Export.h"
#include "Types.h"

#include <cstdint>
#include <string_view>

namespace sj {

class Tuning;

enum class Recovery : uint8_t { None, Tea, Cigarette, View };

struct RecoveryState
{
    Recovery action{Recovery::None};
    float    elapsed{};
    float    granted{};
};

// Why an action cannot start now, or empty if it can. A reason rather than a bool: acceptance 3
// requires the refusal to be *clear*, and "you cannot do that" teaches nothing.
struct Refusal
{
    std::string_view why;
    bool ok() const noexcept { return why.empty(); }
};

namespace recover {

// Whether `action` can start. `bothHandsFree` is a stance that does not need a hand on the ladder
// (a belt or a chair) or standing on a platform; `facingOut` is looking away from the stack.
SJ_API Refusal CanStart(Recovery action, const Meters& m, const MeterContext& ctx,
                        bool bothHandsFree, bool facingOut, const Tuning& t) noexcept;

// Start it. The cigarette takes its toll on the ceiling here, on the first draw, whether or not it
// is finished — which is when a cigarette takes it.
SJ_API void Begin(RecoveryState& s, Recovery action, Meters& m, const Tuning& t) noexcept;

// One step. Grants nerve steadily; returns true on the step it finishes.
SJ_API bool Step(RecoveryState& s, Meters& m, float dt, const Tuning& t) noexcept;

// Stop part-way. Whatever it had granted, it keeps.
SJ_API void Interrupt(RecoveryState& s) noexcept;

// 0-1 through the current action.
SJ_API float Progress(const RecoveryState& s, const Tuning& t) noexcept;

// Nerve per second recovered just by where you are: on a platform, or below the height at which
// the fear starts. Zero on a ladder high up. Additive with the timed actions.
SJ_API float PassiveRate(const MeterContext& ctx, bool onPlatform, const Tuning& t) noexcept;

SJ_API float Duration(Recovery action, const Tuning& t) noexcept;
SJ_API float Amount(Recovery action, const Tuning& t) noexcept;

}  // namespace recover
}  // namespace sj
