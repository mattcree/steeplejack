#pragma once

// The shared vocabulary of the sim — CORE-004.
//
// Contract-first: these are the types eight sim modules pass between each other, fixed in
// docs/03-tech/interfaces.md before any of those modules exist so that they can be written
// in parallel by agents who never talk to each other. Changing anything here is a breaking
// change to that contract, not a local edit.
//
// Data only. No constructors, no virtuals, no inheritance, no methods — aggregate
// initialisation and nothing else. Behaviour lives in the module that owns it: a Joint does
// not know how it is tapped, an Anchor does not know how it is loaded. The static_asserts at
// the bottom of this file hold that line against future edits.
//
// Units, per the interfaces doc: degrees for angles, bearings clockwise from north, metres
// for distance, kN for force, kg for mass, seconds for time.

#include <cstdint>
#include <type_traits>

namespace sj {

// ---------------------------------------------------------------- vocabulary

struct Vec2 { float x, y; };

// Ours, deliberately no engine's vector. SteeplejackSim builds standalone under CMake with no
// engine present; the conversion to Godot's types happens once, in Source/SteeplejackGodot.
struct Vec3 { float x, y, z; };

// The sim steps at a fixed 60 Hz regardless of frame rate — see ADR-0003. Render
// interpolation between steps is CORE-005's problem, not the sim's.
constexpr float kTick = 1.0f / 60.0f;

// A frame that stalls longer than this stops trying to catch up and drops the time instead,
// so a hitch cannot spiral into a spiral of death.
constexpr int kMaxCatchUpSteps = 5;

// ---------------------------------------------------------------- enums
//
// Ordered worst-to-best where there is an order, so comparisons read the way the words do
// and a widening of the scale appends rather than renumbers.

enum class JointTier  : uint8_t { Cracked, Perished, Fair, Sound };
enum class AnchorRate : uint8_t { Failed, Poor, Fair, Sound };
enum class Stance     : uint8_t { OneHand, HookedLeg, Clipped, Belted, Chair };
enum class Lashing    : uint8_t { None, Hitch, Full };
enum class Exposure   : uint8_t { Platform, Ladder, Hanging, Overhang };
enum class SpanBand   : uint8_t { Rigid, Flex, Sway, Buckle };

// ---------------------------------------------------------------- structs

// A mortar joint in the brickwork: somewhere a tool can bite. `quality` is the hidden truth
// the tap test reads through; `tier` is what the player has learned about it so far.
struct Joint
{
    int32_t   id{};
    Vec3      pos{}, normal{};
    float     height{}, quality{};
    JointTier tier{};
    bool      occupied{};
};

// A driven fixture. Defaults to an unplaced, failed anchor so that a zero-initialised Anchor
// can never be mistaken for one that holds weight.
struct Anchor
{
    int32_t    jointId{-1};
    float      height{}, depth{}, spall{};
    AnchorRate rate{AnchorRate::Failed};
    float      capacityKN{}, loadKN{};
    bool       freeFixture{};
};

// The span between two anchors. `buckleTimer` counts down once buckling starts; negative
// means not buckling, which is why it does not default to zero.
struct Section
{
    int32_t lowerAnchor{-1}, upperAnchor{-1};
    float   span{}, condition{1.0f}, buckleTimer{-1.0f};
    Lashing lashing{Lashing::None};
};

// The two meters and nothing else — a third meter is an anti-pillar. Grip is the short one,
// nerve the long one; see docs/04-production/glossary.md.
struct Meters
{
    float    grip{}, nerve{}, nerveMax{};
    Stance   stance{};
    Exposure exposure{};
};

// Everything outside the player that bears on how fast the meters move. Passed in by the
// caller each step rather than read from an ambient world, so meter maths stays testable
// without a world to test it in.
struct MeterContext
{
    float       height{}, windSpeed{};
    bool        carryingLadder{}, wet{}, cold{}, gloves{};
    const char* injury{""};   // "" | "cracked_rib" | "bad_ankle"

    // True while a hand is off the ladder — that is, while the player is *working*. Grip drains
    // only then, and recovers only when it is false; see 03-meters-grip-nerve.md. It defaults to
    // false so a zero-initialised context describes someone holding on with both hands, which is
    // the safe reading: a default that meant "working" would drain a climber nobody is moving.
    //
    // Added by METER-001. The interfaces doc fixed MeterContext before any meter existed and had
    // no way to express this, so grip could only ever drain and never recover.
    bool        working{};

    // Seconds of work done this shift. Only the cold cap reads it: max grip is held at
    // gripModifiers.coldMaxCap until coldWarmupSeconds of work have been done.
    float       workedSeconds{};
};

// One hammer blow's effect on a joint. `seated` is the terminal success; `bent` is the
// terminal failure; both can be false while the fixture is still going in.
struct StrikeResult
{
    float depthGain{}, spalled{};
    bool  bent{}, seated{};
};

// ---------------------------------------------------------------- the data rule
//
// These types cross module boundaries, get memcpy'd into replay frames and get compared
// byte-for-byte by the determinism gate. A constructor, a virtual or a base class would
// break all three quietly. Break it loudly here instead.

#define SJ_REQUIRE_PLAIN_DATA(T)                                                      \
    static_assert(std::is_aggregate_v<T>,          #T " must stay an aggregate");     \
    static_assert(std::is_trivially_copyable_v<T>, #T " must stay trivially copyable"); \
    static_assert(std::is_standard_layout_v<T>,    #T " must stay standard layout")

SJ_REQUIRE_PLAIN_DATA(Vec2);
SJ_REQUIRE_PLAIN_DATA(Vec3);
SJ_REQUIRE_PLAIN_DATA(Joint);
SJ_REQUIRE_PLAIN_DATA(Anchor);
SJ_REQUIRE_PLAIN_DATA(Section);
SJ_REQUIRE_PLAIN_DATA(Meters);
SJ_REQUIRE_PLAIN_DATA(MeterContext);
SJ_REQUIRE_PLAIN_DATA(StrikeResult);

#undef SJ_REQUIRE_PLAIN_DATA

}  // namespace sj
