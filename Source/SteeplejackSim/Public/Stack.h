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

    // One fixed step with a climber of `loadKN` on `loadedSection` (-1 for nobody). Runs
    // buckling, walking and anchor loading, and any cascade that follows. Deterministic.
    StackEvents Step(float dt, int32_t loadedSection, float loadKN, const Tuning& t);

    // A shock arriving at an anchor — a climber caught by the safety line, say. Fails it if it
    // exceeds capacity, and cascades. Returns anchors in failure order; empty if it held.
    std::vector<int32_t> Shock(int32_t anchor, float shockKN, const Tuning& t);

    // Anchor `failed` has let go and `shockKN` arrives at the next one down. Runs the cascade and
    // returns every anchor that goes, in order — `failed` first. CLIMB-002's interface.
    std::vector<int32_t> Cascade(int32_t failed, float shockKN, const Tuning& t);

private:
    void FailAnchor(int32_t i);

    std::vector<Anchor>  anchors_;
    std::vector<bool>    anchorFailed_;
    std::vector<Section> sections_;
    std::vector<bool>    sectionFailed_;
    std::vector<float>   driftCm_;
};

}  // namespace sj
