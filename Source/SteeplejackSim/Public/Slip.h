#pragma once

// The slip, the save, and the fall — METER-005.
//
// This is the module that makes the grip meter mean something. Until it existed grip drained,
// the arc went red, it reached zero and nothing whatsoever happened — two meters on screen that
// decided nothing, which is worse than no meters, because the player learns they are decoration
// and stops reading them.
//
// The rule, from docs/01-gdd/02-climbing-system.md#6-falling: when grip hits zero or an anchor
// goes under you, one hand catches. You have 900 ms to grab. Take it and you are hanging
// one-handed at 15% grip with nerve −25; miss it and you fall. **One save per 60 seconds** — the
// budget is what makes the second slip frightening, and it is the whole reason this is a rule and
// not a reflex test.
//
// Time here is **absolute in-level seconds**, not a delta. The fixed-step driver (ADR-0003) owns
// the clock; a module that accumulated its own would produce a different window on a frame hitch,
// and a replay that diverged from the shift it recorded.
//
// What is *not* here, deliberately: the camera, the time dilation, the lurch, the input binding
// and the accessibility motion settings. Those are presentation, they are CAM-002's and
// A11Y-001's, and none of them may change the outcome. Turn every one of them off and the same
// grab at the same moment still saves you.

#include "Export.h"
#include "Types.h"

namespace sj {

class Tuning;

enum class SlipOutcome : uint8_t { None, Saved, Fell };

// The three rows of `difficulty` in meters.json. Difficulty in this game is time pressure and
// margin, never hidden information and never a dice roll — see 10-failure-and-difficulty.md — and
// the slip window is the one reflex element it is allowed to touch.
//
// It lives here because this is the first module that needed it. It belongs in Types.h as soon as
// a second one does.
enum class Difficulty : uint8_t { Assisted, Jack, OwdHand };

// The player's slip state. One per climber, carried across the shift because the cooldown is.
//
// A class rather than a free function over plain data, unlike the meters, because the cooldown is
// genuinely durable state that outlives any one slip. It stays trivially copyable so that a replay
// frame can hold one.
class SJ_API SlipModel
{
public:
    explicit SlipModel(Difficulty difficulty = Difficulty::Jack) noexcept;

    void       SetDifficulty(Difficulty difficulty) noexcept { difficulty_ = difficulty; }
    Difficulty GetDifficulty() const noexcept { return difficulty_; }

    // The tuned window and cooldown for the current difficulty, in seconds.
    float WindowSeconds(const Tuning& t) const noexcept;
    float CooldownSeconds(const Tuning& t) const noexcept;

    // Whether the budget has come round. False during the cooldown after a save.
    bool CanSlipSave(float now, const Tuning& t) const noexcept;

    // A slip starts: grip reached zero, or an anchor went. Returns the window in seconds.
    //
    // **Returns 0 when the budget is spent.** That is not a sentinel to branch on — a budget you
    // have already spent is a zero-length window, and `Resolve` falls you on the first call for
    // exactly the reason it falls you on any other closed window. One code path, so the terrifying
    // case cannot be the one that was never tested.
    //
    // **A slip is an edge, not a level.** Your hand comes off once and cannot come off again until
    // you have got it back on, so calling this every step while grip sits at zero is correct and
    // does nothing after the first. Without that latch a fall — which is exactly what leaves a
    // climber at zero grip — slips him again on the very next step, spends the budget he was just
    // given, and falls him again, for ever. `HandBackOn` is what re-arms it.
    float BeginSlip(float now, const Tuning& t) noexcept;

    // Grip came back. Call every step that grip is above zero; it is the other half of the edge.
    void HandBackOn() noexcept { handOff_ = false; }

    // Whether a hand is currently off — slipping, or left off by a slip that resolved into a fall.
    bool HandIsOff() const noexcept { return handOff_; }

    bool InProgress() const noexcept { return slipping_; }

    // How much of the window is left, 1 at the moment of the slip falling to 0 at its close.
    // What a closing ring on the HUD draws; 0 when nothing is slipping.
    float WindowFractionLeft(float now) const noexcept;

    // Called every step while a slip is in progress, carrying whether the grab input went down.
    //
    //   Saved  the grab landed inside the window. Grip drops to slipSaveGripFraction of its
    //          ceiling, nerve takes the `slipSave` shock, and the cooldown starts *here* — the
    //          budget buys saves, not slips.
    //   Fell   the window closed with no grab, or it was closed before it opened.
    //   None   the window is still open, or nothing was slipping.
    //
    // One call per step with the input in it, rather than a call on the grab and a timer
    // somewhere else. An expiry the presentation layer owns is an expiry that differs between
    // the game and the replay, and it is a game rule living outside the sim.
    SlipOutcome Resolve(float now, bool grabbed, Meters& m, const Tuning& t) noexcept;

private:
    Difficulty difficulty_{Difficulty::Jack};
    bool       handOff_{false};   // the edge latch — see BeginSlip
    bool       slipping_{false};
    float      slipBegan_{0.0f};
    float      window_{0.0f};
    float      windowEnds_{0.0f};   // absolute, not derived — see BeginSlip
    // Negative rather than zero: at now = 0 on the first step of a shift, a zero would read as
    // "saved a moment ago" and refuse the very first slip of the level.
    float      lastSaveAt_{-1.0e9f};   // literal: "never", far enough back that no cooldown reaches it
};

// ---------------------------------------------------------------- the fall

// What the fall found. `caught` is the only field the player feels immediately; the rest is what
// the reckoning screen and the HUD need in order to say *why*, which the fairness contract
// requires them to be able to say in one sentence.
struct FallResult
{
    bool  caught{};          // the safety line held
    bool  anchorFailed{};    // ...or it did not, which is the grimmest moment in the game
    float shockLoadKN{};     // what the anchor saw
    float capacityKN{};      // what it was rated to hold
};

// Resolve a fall against the anchor the climber is tied to.
//
// Clipped, belted or in a chair, you drop to the end of the line and shock-load that anchor at
// `dynamicLoadFactor`. It holds if it was rated to; a Fair dog at 2.5 kN does not hold 3 kN, and
// the player was shown that rating on the pip when they drove it. That is the fairness contract
// paying out: the information was on screen, minutes earlier, and it was ignored.
//
// One hand or a hooked leg is not tied to anything, so `tiedTo` is not read and nothing catches.
//
// Applies the nerve cost of being caught. Nothing here ends the shift or moves the player — that
// is the game layer's, and what it does with an uncaught fall is resume-at-stack.
//
// **Not a cascade.** When the anchor fails, the load does not pass down to the one below it: that
// needs the load-sharing model, which is CLIMB-002's and does not exist yet. Today a failed
// anchor is a fall to the ground, which is the correct outcome for every case a single anchor can
// decide — it is only the *middle* of a chain reaction that is missing.
SJ_API FallResult ResolveFall(Meters& m, const Anchor& tiedTo, const Tuning& t) noexcept;

// Whether this stance has you tied to anything. The line is what you spent three seconds clipping
// on for, and the reason a belt is worth its grip cost.
SJ_API bool IsTiedOn(Stance stance) noexcept;

}  // namespace sj
