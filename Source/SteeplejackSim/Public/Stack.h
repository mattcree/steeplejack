#pragma once

// The ladder stack — CLIMB-001 — and the load it carries — CLIMB-002.
//
// This is where the anchor loop's decisions come due. Until it existed they never did: the HUD said
// "12.0 m span — about to buckle" and nothing ever buckled, a Poor dog and a Sound one played
// identically, and a quick hitch "walked off the anchor" only in a message. The whole risk economy
// of the ascent was text. MVP criterion 4 — do players voluntarily take the risky span — cannot be
// measured against a span that carries no risk.
//
// ## The stack
//
// Anchors (dogs in the wall) and sections (ladders lashed between them). Anchor 0 is the ground: it
// holds anything, and the first section stands on it. A section's span is the distance between its
// two anchors, and the span table in climbing.json is the whole risk economy in one place.
//
// ## Load
//
// A climber's weight goes into the anchors below him, not evenly: the nearest takes most, and each
// one further down a fixed fraction of the one above (`loadShareFalloff`), normalised so the shares
// sum to the load. So the Poor dog you accepted at 20 m is nearly unloaded by the time you are at 60
// — **until something above it lets go**, and then it is the next one down.
//
// ## Failure
//
// An anchor fails when the load on it passes its rated capacity. The load on it is its share,
// times the dynamic multiplier of the span he is on (a swaying 7 m section hits its anchors 1.4
// times as hard), times `dynamicLoadFactor` if what arrived was a shock rather than a climber.
//
// When one fails, its load becomes a shock on the next one down. Each failure absorbs some of that
// shock — the dog tearing out of the mortar, the ladder flexing — so a cascade can stop: it runs
// until it reaches an anchor rated to take what is left of it, or reaches the ground. The failure
// order is returned so the HUD can burn it down the screen like a fuse, and there is no randomness
// anywhere in this module — the player must always be able to trace a cascade, and a cascade that
// could go differently twice cannot be traced.
//
// ## Buckling and walking
//
// A section over `spanBuckleMetres` bows under load and fails after `buckleSecondsUnderLoad` — a
// timer, not an instant, because the fairness contract wants a warning the player can act on. Step
// off it and the timer resets. A quick hitch walks under load at `lashHitchDriftCmPerMinute`, and
// once it has walked `lashHitchWalkOffCm` the lashing comes off the dog.

#include "Export.h"
#include "Types.h"

#include <cstdint>
#include <stdexcept>
#include <string>
#include <vector>

namespace sj {

class Tuning;

// What a step found. Anchors in failure order; sections that let go this step.
struct StackEvents
{
    std::vector<int32_t> failedAnchors;
    std::vector<int32_t> failedSections;
    int32_t              buckling{-1};       // the section counting down, or -1
    float                buckleSecondsLeft{-1.0f};
};

// What a survey of the whole stack found — CLIMB-007.
//
// Everything else in this module answers "what is happening to the section he is standing on".
// Nothing answered the question a jack actually asks, which is **"am I happy on this ladder?"** —
// a judgement about the whole structure, made by looking down it, not by standing on one rung of
// it. A stack can be perfectly quiet under a climber and still be one dog away from coming down.
//
// The question is made concrete by asking the only one that matters: **if he came off the top,
// what would happen?** That is a cascade, and the cascade model is already here and deterministic,
// so the survey is a read-only walk of it.
enum class StackVerdict : uint8_t { Sound, Working, NotRight };

struct StackSurvey
{
    StackVerdict verdict{StackVerdict::Sound};

    // The dog that would go first in a fall from the top, and the arithmetic that decides it.
    int32_t firstToGo{-1};
    float   firstToGoHeightM{};
    float   firstToGoCapacityKN{};
    float   shockAtTopKN{};

    // How far the cascade would run, and what it would cost.
    int32_t cascadeDepth{};
    float   wouldFallToM{};      // the height the stack would be left standing at

    // What is wrong with it as a structure, whether or not he ever falls.
    int32_t longestSection{-1};
    float   longestSpanM{};
    SpanBand worstBand{SpanBand::Rigid};
    int32_t hitches{};           // quick hitches still in the stack
    int32_t poorAnchors{};       // dogs in the structure that a fall from the top would pull

    // `Sound` means the stack would hold a fall from the top and has nothing marginal in it.
    bool HoldsAFall() const noexcept { return firstToGo < 0; }
};

class SJ_API Stack
{
public:
    // A stack with only the ground in it: anchor 0, which holds anything.
    Stack() noexcept;

    int32_t AddAnchor(const Anchor& a);
    int32_t AddSection(int32_t lowerAnchor, int32_t upperAnchor, Lashing lashing);

    int32_t AnchorCount() const noexcept { return static_cast<int32_t>(anchors_.size()); }
    int32_t SectionCount() const noexcept { return static_cast<int32_t>(sections_.size()); }
    const Anchor& AnchorAt(int32_t i) const noexcept;
    const Section& SectionAt(int32_t i) const noexcept;
    bool AnchorFailed(int32_t i) const noexcept;
    // Whether a ladder is lashed to this anchor. Only those carry load: a dog driven into the wall
    // and never lashed to holds nothing up, however good it is. The ground always counts.
    bool InStructure(int32_t i) const noexcept;
    // The highest intact anchor a section is lashed to, or the ground. Where the next section's
    // lower end is.
    int32_t TopOfStructure() const noexcept;
    bool SectionFailed(int32_t i) const noexcept;
    float SectionDriftCm(int32_t i) const noexcept;

    float SpanOf(int32_t section) const noexcept;
    SpanBand Band(int32_t section, const Tuning& t) const noexcept;

    // How far a section bows at mid-span under a load, in metres. Rigid below the soft span in all
    // but name — the curve is steep enough that 3 m is millimetres and 5 m is several centimetres,
    // which is what CLIMB-001's acceptance asks for and what the span table's "rigid / flex" means.
    float FlexDeflectionM(int32_t section, float loadKN, const Tuning& t) const noexcept;

    // The highest height any intact section reaches. What you can climb to.
    float TopHeight() const noexcept;

    // The section a climber at this height is standing on: the highest intact one whose lower
    // anchor is at or below him. -1 on the ground or above the stack.
    int32_t SectionAt(float height) const noexcept;

    // Share of `totalKN` carried by each anchor, for a climber on `atSection`. Indexed by anchor;
    // anchors above him, or failed, carry nothing. Sums to totalKN.
    std::vector<float> Shares(int32_t atSection, float totalKN, const Tuning& t) const;

    // Look down the whole thing and say whether it is right — CLIMB-007. Read-only: it walks the
    // same cascade `Shock` would, on a copy, and changes nothing.
    //
    // `loadKN` is the climber. The shock it tests with is `loadKN * dynamicLoadFactor`, which is
    // the number that decides every fall in this game and which the player has never been shown.
    StackSurvey Survey(float loadKN, const Tuning& t) const;

    // One fixed step with a climber of `loadKN` on `loadedSection` (-1 for nobody). Runs
    // buckling, walking and anchor loading, and any cascade that follows. Deterministic.
    StackEvents Step(float dt, int32_t loadedSection, float loadKN, const Tuning& t);

    // A shock arriving at an anchor — a climber caught by the safety line, say. Fails it if it
    // exceeds capacity, and cascades. Returns anchors in failure order; empty if it held.
    std::vector<int32_t> Shock(int32_t anchor, float shockKN, const Tuning& t);

    // Anchor `failed` has let go and `shockKN` arrives at the next one down. Runs the cascade and
    // returns every anchor that goes, in order — `failed` first. CLIMB-002's interface.
    std::vector<int32_t> Cascade(int32_t failed, float shockKN, const Tuning& t);

    // A stack exactly as a checkpoint describes it — CLIMB-006. The vectors are per anchor and per
    // section, and must agree in length; anchor 0 must be the ground. Validation of the file is the
    // caller's (save::RestoreStack); this only assembles.
    static Stack Restore(std::vector<Anchor> anchors, std::vector<bool> anchorFailed,
                         std::vector<Section> sections, std::vector<bool> sectionFailed,
                         std::vector<float> driftCm);

private:
    void FailAnchor(int32_t i);

    std::vector<Anchor>  anchors_;
    std::vector<bool>    anchorFailed_;
    std::vector<Section> sections_;
    std::vector<bool>    sectionFailed_;
    std::vector<float>   driftCm_;
};

// The checkpoint — CLIMB-006. The stack is the game's only save: no save points, no flags, the
// progress is the structure the player built. Serialise the stack, never the player: on resume he
// starts at the foot of his own ladders with the shift reset.
namespace save {

class SJ_API SaveError : public std::runtime_error
{
public:
    using std::runtime_error::runtime_error;
};

// A fingerprint of the level file's bytes. A checkpoint records the one it was built on, and a
// changed level refuses to restore rather than hanging the old route on a different wall.
SJ_API std::string LevelFingerprint(const std::string& levelFileText);

SJ_API std::string SerialiseStack(const Stack& stack, const std::string& levelId,
                                  const std::string& levelFingerprint);

// Throws SaveError: an unknown version, a different level or level file, or a stack that does not
// hang together (a section on an anchor that does not exist).
SJ_API Stack RestoreStack(const std::string& json, const std::string& levelId,
                          const std::string& levelFingerprint);

}  // namespace save
}  // namespace sj
