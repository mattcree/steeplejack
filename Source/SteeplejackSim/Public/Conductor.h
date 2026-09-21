#pragma once

// Running a lightning conductor down a chimney — the CONDUCTOR archetype.
//
// 05-mission-types.md §B, and the archetype 19-the-complete-game.md argues should be built second,
// because its fiddly bit *is* the descent: it makes the way down the main event, and the way down
// is the half of the trade the game had no way to do until striking landed.
//
// ## Why this is a module and not a script
//
// Everything here decides whether a job passed. A run that wanders fails inspection, a reel that
// runs out ends the shift, and a system that is fitted but does not pass continuity is worse than
// no system at all — "a conductor will make a building more rather than less liable to attract a
// strike". Those are rules, they need testing, and they do not belong in a scene.
//
// ## The rules, and where they come from
//
// The 1881 Lightning Rod Conference Code of Rules, which is remarkably close to a game design
// document. Three of its clauses do all the work here:
//
//  1. **The curvature rule.** "In no case should the length of the rod between two points be more
//     than half as long again as the straight line joining them." That is a *ratio*, which means
//     it is a mechanic: pay out too much tape between fixings, or wander round an obstruction the
//     long way, and the run fails whatever it looks like.
//
//  2. **Fixings are metal, not insulators** — "but the holdfasts should not be driven in so tightly
//     as to pinch the rod, or prevent the contraction and expansion produced by changes of
//     temperature." So the hammer verb the game already has is exactly right, and it has a band
//     rather than a maximum: too loose and it works free, too tight and you have made a hinge that
//     fails the first cold night.
//
//  3. **The earth.** A plate in permanently wet ground packed round with coke, and the whole thing
//     tested. Modern practice puts a number on the pass: ten ohms overall.
//
// And the failure that gives the archetype its dread, from a jack who lived it: a rod through a
// cornice in an undersized hole rusted, expanded and burst the stone, and "the crack being covered
// up with soot this escaped my observation" — forty-eight pounds of it fell on his knee.

#include "Export.h"

#include <cstdint>

namespace sj {

class Tuning;

// One fixing, as it went in.
struct Clip
{
    float heightM{};
    float tapePaidM{};   // tape used since the clip below it
    float tightness{};   // 0 finger-tight .. 1 driven home hard
};

// What the inspector would say. Ordered worst-first, so `>= Failed` reads as "it does not pass".
enum class RunVerdict : uint8_t { Sound, Marginal, Failed };

// The state of a run as it is being made, and the judgement on it when it is finished.
struct ConductorRun
{
    RunVerdict verdict{RunVerdict::Sound};
    float      tapeLeftM{};
    float      wanderRatio{1.0f};   // tape paid out over straight-line distance covered
    int32_t    clips{};
    int32_t    overTight{};         // fixings that will pinch the rod when it is cold
    int32_t    tooLoose{};          // and ones that will work themselves free
    float      longestGapM{};       // the biggest jump between fixings
    float      earthOhms{-1.0f};    // -1 until the pit is made and tested
    bool       terminalSet{};
};

// How much tape a reel holds, and the rest of the numbers, live in `conductor.json`.
class SJ_API Conductor
{
public:
    void Begin(float reelMetres, const Tuning& t) noexcept;

    // Fix a clip. `heightM` is where it went, `tapePaidM` how much tape was let out getting there
    // from the last one, `tightness` how hard it was driven. Returns false when there is not
    // enough tape left to reach — which ends the run where it is, and is a real way to fail.
    bool Fix(float heightM, float tapePaidM, float tightness, const Tuning& t) noexcept;

    // Make the earth. `plateSquareFeet` of copper, `wet` whether the ground stays damp, `coke`
    // whether it was packed. Sets the tested resistance.
    void Earth(float plateSquareFeet, bool wet, bool coke, const Tuning& t) noexcept;

    void SetTerminal() noexcept { run_.terminalSet = true; }

    // The judgement, applied to everything so far.
    const ConductorRun& State() const noexcept { return run_; }
    ConductorRun Judge(float fromHeightM, const Tuning& t) const noexcept;

private:
    ConductorRun run_{};
    float        lastHeight_{-1.0f};
    float        topHeight_{-1.0f};
    float        tapeUsed_{};
};

}  // namespace sj
