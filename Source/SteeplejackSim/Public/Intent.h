#pragma once

// What the player meant, one tick at a time — CORE-006.
//
// An intent is semantic, never an input event: `HammerRelease(power, angleError)`, not `MouseUp`.
// That is what keeps a replay stable across input remapping and accessibility settings — a player
// who mashes to lash and one who holds produce the same `LashWrap`, and a replay recorded by
// either plays back on a keyboard nobody has configured yet.

#include <cstdint>
#include <vector>

namespace sj {

enum class IntentKind : uint8_t {
    Move, Look, Tap, HammerDraw, HammerRelease, LashWrap, LashTie,
    HaulPull, HaulSteer, Clip, Unclip, SetStance, Climb, Slide,
    SelectTool, Brew, Smoke, LookAtView, GrabSave
};

// The last kind, for range checks on data read from a file.
inline constexpr IntentKind kLastIntentKind = IntentKind::GrabSave;

// Two floats and a target cover every verb: power and angle error for a blow, turns per second and
// nothing for a wrap, the joint id for a tap. Unused fields stay at their defaults, and the file
// format leaves defaults out.
struct Intent
{
    IntentKind kind{};
    float      a{}, b{};
    int32_t    target{-1};

    bool operator==(const Intent&) const = default;
};

using IntentBuffer = std::vector<Intent>;   // reused, never reallocated per tick

}  // namespace sj
