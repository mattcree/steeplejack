#pragma once

// The fall — FELL-002. Gob.h cuts the hole; this drops the chimney into it.
//
// The whole of a felling is a bet the player makes at the survey and cannot take back: two pegs in
// the ground saying "it will land there". Everything after that — the lean they measured, the arc
// they cut, the metres they took off by hand, the wind on the day — moves the real answer towards
// or away from those pegs, and then it falls once.
//
// ## Where it actually goes
//
// Three things pull on the fall line and it goes where their sum points:
//
//   * **The gob.** A chimney falls into the hole you cut. This is the player's instrument and it
//     has the most authority, which is what makes cutting the gob the game.
//   * **The lean.** "The chimney wants to fall along its lean. Fighting it costs you accuracy."
//     Each degree of lean pulls with `fallLeanPullPerDegree` percent of the gob's authority, so a
//     negligible lean is a rounding error and 2.1° is nearly half the argument.
//   * **The wind**, weakly, per metre per second.
//
// This is deterministic — ADR-0002 — so the same site, gob and plan always fall the same way. The
// seed only shakes out the fractures, and it comes from the level, so a given level's chimney
// always breaks up the same way too. There is no dice roll anywhere the player can feel one.
//
// ## Why it is never exactly right
//
// `Accuracy` is the half-angle of the cone the HUD draws, and it is an honest prediction of the
// error, not a fudge applied to it: the fall really does land inside it. It widens with the lean
// being fought, with height, and with a gob too narrow to steer with; it narrows by
// `fallAccuracyPerFiveMetresRemoved` for every five metres taken off by hand, which is the trade
// Act 2 exists to offer — "every metre taken by hand is 40 seconds of your daylight".

#include "Export.h"

#include <cstdint>
#include <string>
#include <vector>

namespace sj {

class Gob;
class Tuning;

// Something on the site that must not be hit. `value` is pounds; a catastrophic one has no price
// and fails the job.
struct Exclusion
{
    std::string id;
    float       bearingDeg{};
    float       distanceM{};
    float       valueGbp{};
    bool        catastrophic{};
};

// The chimney and its day. Bearings clockwise from north, metres, m/s.
struct FellSite
{
    float heightM{};
    float baseRadiusM{};
    float leanDeg{};
    float leanBearingDeg{};
    float windSpeedMps{};
    float windBearingDeg{};
    float safeLineDistanceM{};
    std::vector<Exclusion> exclusions;
    uint32_t seed{};
};

// What the player committed to: where the pegs are, what they took off the top first, and whether
// they did the survey at all.
//
// `surveyed` is the whole of Act 1. A chimney's lean is not written on it — you read it with a
// plumb bob from two positions round the base, and until you have, you are guessing at the one
// thing that decides which way it wants to go. You can fell without surveying. It costs you
// `fallAccuracyUnsurveyedDegrees` of cone, and the design's whole first act is the argument for
// spending five minutes not doing that.
struct FellPlan
{
    float pegBearingDeg{};
    float heightRemovedM{};
    bool  surveyed{true};
    // How well the gob was packed with waste timber before it was lit, 0-1. "Poor packing = slow
    // burn = the chimney drops before the props are fully gone = worse accuracy." So it costs you
    // twice: a badly packed gob burns longer, which is more time to get clear, and lands wider.
    float packingQuality{1.0f};
};

enum class FellGrade : uint8_t { Wild, Acceptable, Good, Perfect };

// What the HUD shows before the match is lit. Every number here is one the player can change.
struct FellPrediction
{
    float fallBearingDeg{};     // where it will really go
    float errorDegrees{};       // how far that is off the pegs
    float accuracyDegrees{};    // half-angle of the cone drawn round it
    float debrisHalfAngleDeg{};
    float debrisLengthM{};

    // Is this thing inside the fan? Bearing and distance from the base, as the level authors them.
    bool Threatens(const Exclusion& e) const noexcept;
};

// What happened. `fractureHeightsM` are where the shaft broke, highest first.
struct FellOutcome
{
    float fallBearingDeg{};
    float errorDegrees{};
    FellGrade grade{FellGrade::Wild};
    std::vector<float>       fractureHeightsM;
    std::vector<std::string> struck;
    int32_t chunks{1};
    bool    cleanBreak{};
    bool    catastrophe{};
    float   bonusGbp{};
    float   penaltyGbp{};
};

// No state: a felling is a function of the site, the hole and the plan.
class SJ_API Fell
{
public:
    // What the survey and the gob say will happen. Safe to call every frame while cutting — this
    // is what makes the gob legible, and the design leans on it: the player watches the cone
    // swing as they take brick out.
    static FellPrediction Predict(const FellSite& site, const Gob& gob, const FellPlan& plan,
                                  const Tuning& t);

    // Light it. Runs the hinge, breaks the shaft where the bending stress says, and scores it.
    static FellOutcome Run(const FellSite& site, const Gob& gob, const FellPlan& plan,
                           const Tuning& t);

    // Where the shaft breaks, highest first. A rod hinging about its base has an angular rate that
    // grows as it goes over, and the bending stress at height h goes as rate² × h — so the stress
    // is worst high up and late, the top lets go first, and the piece above it overtakes the rest
    // and lands beyond the base of the fall. That is why a felled chimney throws debris further
    // than its own height, and it is the reason the debris fan is 1.15 × height and not 1.0.
    static std::vector<float> FractureHeights(float shaftHeightM, const Tuning& t);

    // What a day's work has cost, in seconds of shift. Every cell out, every prop in and every
    // metre taken off the top is time, and the level authors how much of it you have.
    //
    // This is the trade Act 2 exists for and the design is emphatic about it: "the game tells you
    // your predicted accuracy improves by ~1.5 degrees per 5 m removed... every metre taken by hand
    // is 40 seconds of your daylight. This is a real strategic choice and it should be presented as
    // one at the survey." Accuracy is bought with daylight; there is no other currency for it.
    static float ShiftCostSeconds(int32_t cellsCut, int32_t propsSet, float heightRemovedM,
                                  const Tuning& t);
    // The most you are allowed to take off by hand: the perished top, not the whole chimney.
    static float MaxHeightReductionM(float heightM, const Tuning& t);

    // How long the packing burns before the props go, between the level's authored range. A gob
    // packed well burns fast and clean; one packed badly smoulders, and the design is explicit
    // that the smoulder is what costs you the fall. The seconds are the player's to run in.
    static float BurnSeconds(float packingQuality, float minSeconds, float maxSeconds);

    // Whether a match will take, in this wind, sheltered or not. Deterministic on the seed, so a
    // level's match behaves the same way every time you play it — a coin flip you cannot learn is
    // not tension, it is a coin flip.
    static bool MatchTakes(float windMps, bool sheltered, uint32_t seed, int32_t attempt,
                           const Tuning& t);

    // The main line you cannot close for more than twenty minutes. Trains come on a timetable and
    // a chimney takes a while to reach the ground, so the question is whether one is passing in
    // the window between the props going and the dust settling.
    //
    // The design is specific that this is optional and unannounced: "the railway timetable is on a
    // board at the site office. Reading the board is optional and the game never mentions it."
    // Which means it has to be *learnable* — arithmetic on a published timetable, not a surprise —
    // and that is why it takes the minute rather than a seed.
    static bool TrainInTheWindow(float minuteOfShift, float windowSeconds, float everyMinutes,
                                 float firstAtMinute);
    // How long after the last train, in minutes. What the board on the wall tells you.
    static float MinutesSinceTrain(float minuteOfShift, float everyMinutes, float firstAtMinute);

    // Signed difference between two bearings, in (-180, 180].
    static float BearingDelta(float fromDeg, float toDeg) noexcept;
};

}  // namespace sj
