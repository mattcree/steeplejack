#pragma once

// Taking a chimney down by hand, from the top — the TOP archetype.
//
// The one the reference material is most famous for, fully specified in 07-topping-system.md, and
// the one job in the game where **the level geometry shrinks under the player in real time**. You
// stand on what is left of a chimney, prise its bricks off one at a time and drop them down the
// inside of the flue, and the thing you spent twenty minutes climbing gets shorter while you are
// standing on it. Halfway down, your own ladder stack is sticking up above the chimney and you
// have to strike your route home to carry on working.
//
// It exists because a chapel is twenty feet away and she cannot be felled. The briefing says so,
// so "why not just blow it up" is never a question.
//
// ## The verb: PRISE
//
// Four beats, about 1.8 seconds, and the middle two are where the skill is:
//
//     SEAT    the bolster goes into a mortar joint
//     LEVER   push, and resistance builds
//     GIVE    the joint lets go — there is a tick, and a window
//     RELEASE in the window  -> the brick comes out whole      (salvage)
//             before it      -> nothing, and you re-seat       (slower)
//             after it       -> the brick snaps                (rubble, and the flue fills faster)
//
// **The give point varies with the mortar of that particular brick**, and you can read it in
// advance by sounding the joint — but sounding every brick costs you the rate, which is what the
// job is scored on. So the mastery curve is legible and it is the right one: a new hand taps
// everything, an old hand taps one in eight and knows the rest by looking.
//
// ## What it is scored on
//
// Not the money. Clean brick is worth twopence and a whole chimney is about six pounds, which is a
// joke the game makes on purpose — "two hundred and eighty bricks, six pound. Mind, they're lovely
// bricks." What it is scored on is the **share** of brick that came out whole, because that is what
// a jack's reputation was actually made of, and on getting her down before the light goes.

#include "Export.h"

#include <cstdint>
#include <vector>

namespace sj {

class Tuning;

// What a single prise did.
enum class Prise : uint8_t
{
    Nothing,   // released before the give — the bolster comes out and you start again
    Clean,     // out whole, and worth keeping
    Snapped,   // out in pieces
};

// Where the bolster is in the stroke. The HUD draws this and nothing else about the verb.
enum class Stroke : uint8_t { Idle, Seated, Levering, Given };

// How the job reads. Ordered: `>= Rough` is work you would not put your name to.
enum class TopVerdict : uint8_t { Craftsman, Workmanlike, Rough, Abandoned };

struct TopState
{
    Stroke  stroke{Stroke::Idle};
    float   load{};            // 0..1, how hard you are leaning on the bar
    float   give{};            // 0..1, where this brick's give point is. Only known once sounded.
    bool    sounded{};         // whether you tapped this one first
    int32_t bricksLeft{};      // in the course you are on
    int32_t clean{};
    int32_t snapped{};
    float   removedM{};        // how much of her is gone
    float   flueFullShare{};   // 0..1. At 1 the flue is packed and you must carry them down.
    bool    jammed{};
};

class SJ_API Top
{
public:
    // `heightM` how tall she is now, `takeDownToM` how far down the job goes. The seed makes the
    // mortar the same on every machine and in every replay.
    void Begin(float heightM, float takeDownToM, uint64_t seed, const Tuning& t);

    // Sound the joint in front of you. Costs time, and tells you where this brick will give.
    void Sound() noexcept;

    // Put the bolster in. Resets the stroke.
    void Seat() noexcept;

    // Lean on it. Load builds while you hold, and past the give point it keeps building — which
    // is what makes releasing late a snap rather than a miss.
    void Lever(float seconds, const Tuning& t) noexcept;

    // Let go. This is the whole verb.
    Prise Release(const Tuning& t);

    // Drop it down the flue. Bricks that go over the side instead are somebody else's problem and
    // the level decides what they hit.
    void Drop(bool downTheFlue, const Tuning& t) noexcept;

    // Clear a jam, by dropping a weight down on a rope and hauling it back.
    void ClearJam() noexcept;

    const TopState& State() const noexcept { return state_; }

    // How far down she has come, and how far there is to go.
    float HeightNowM() const noexcept { return heightM_ - state_.removedM; }
    float ToGoM() const noexcept;
    bool  Done() const noexcept { return ToGoM() <= 0.0f; }

    // The share of brick that came out whole, 0..1. The grade is this and the clock.
    float CleanShare() const noexcept;
    TopVerdict Judge(float daylightLeftShare, const Tuning& t) const noexcept;

private:
    void       NextBrick(const Tuning& t) noexcept;

    TopState state_{};
    float    heightM_{};
    float    downToM_{};
    uint64_t seed_{};
    int32_t  brickIndex_{};
    int32_t  perCourse_{};
    float    courseM_{};
    int32_t  sinceJam_{};
    int32_t  jamAt_{};
};

}  // namespace sj
