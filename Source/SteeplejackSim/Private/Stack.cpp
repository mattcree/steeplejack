// The ladder stack and its load — CLIMB-001 and CLIMB-002. See Stack.h.

#include "Stack.h"

#include "Anchor.h"
#include "Tuning.h"
#include "Verbs/Lash.h"

#include <algorithm>
#include <cmath>
#include <limits>

namespace sj {
namespace {

// The ground holds anything. Not a tuned value — an anchor that cannot fail — so it is the largest
// number there is rather than a big one somebody might one day exceed.
constexpr float kGroundCapacityKN = std::numeric_limits<float>::max();   // literal: the ground
// Two anchors this close in height are at the same height. Float tolerance, not a game number.
constexpr float kSameHeight = 1.0e-4f;   // literal: float comparison tolerance

const Anchor& NullAnchor() noexcept
{
    static const Anchor kNull{};
    return kNull;
}

const Section& NullSection() noexcept
{
    static const Section kNull{};
    return kNull;
}

}  // namespace

Stack::Stack() noexcept
{
    Anchor ground{};
    ground.jointId = -1;
    ground.height = 0.0f;
    ground.rate = AnchorRate::Sound;
    ground.capacityKN = kGroundCapacityKN;
    anchors_.push_back(ground);
    anchorFailed_.push_back(false);
}

int32_t Stack::AddAnchor(const Anchor& a)
{
    anchors_.push_back(a);
    anchorFailed_.push_back(false);
    return static_cast<int32_t>(anchors_.size()) - 1;
}

int32_t Stack::AddSection(int32_t lowerAnchor, int32_t upperAnchor, Lashing lashing)
{
    Section s{};
    s.lowerAnchor = lowerAnchor;
    s.upperAnchor = upperAnchor;
    s.lashing = lashing;
    s.span = std::fabs(AnchorAt(upperAnchor).height - AnchorAt(lowerAnchor).height);
    s.buckleTimer = -1.0f;
    sections_.push_back(s);
    sectionFailed_.push_back(false);
    driftCm_.push_back(0.0f);
    return static_cast<int32_t>(sections_.size()) - 1;
}

const Anchor& Stack::AnchorAt(int32_t i) const noexcept
{
    return (i >= 0 && i < AnchorCount()) ? anchors_[static_cast<std::size_t>(i)] : NullAnchor();
}

const Section& Stack::SectionAt(int32_t i) const noexcept
{
    return (i >= 0 && i < SectionCount()) ? sections_[static_cast<std::size_t>(i)] : NullSection();
}

bool Stack::AnchorFailed(int32_t i) const noexcept
{
    return i < 0 || i >= AnchorCount() || anchorFailed_[static_cast<std::size_t>(i)];
}

bool Stack::InStructure(int32_t i) const noexcept
{
    if (i == 0)
    {
        return true;
    }
    if (AnchorFailed(i))
    {
        return false;
    }
    for (int32_t s = 0; s < SectionCount(); ++s)
    {
        if (!SectionFailed(s) && (sections_[static_cast<std::size_t>(s)].upperAnchor == i
                                  || sections_[static_cast<std::size_t>(s)].lowerAnchor == i))
        {
            return true;
        }
    }
    return false;
}

int32_t Stack::TopOfStructure() const noexcept
{
    int32_t best = 0;
    for (int32_t s = 0; s < SectionCount(); ++s)
    {
        if (SectionFailed(s))
        {
            continue;
        }
        const int32_t u = sections_[static_cast<std::size_t>(s)].upperAnchor;
        if (AnchorAt(u).height > AnchorAt(best).height)
        {
            best = u;
        }
    }
    return best;
}

bool Stack::SectionFailed(int32_t i) const noexcept
{
    return i < 0 || i >= SectionCount() || sectionFailed_[static_cast<std::size_t>(i)];
}

float Stack::SectionDriftCm(int32_t i) const noexcept
{
    return (i >= 0 && i < SectionCount()) ? driftCm_[static_cast<std::size_t>(i)] : 0.0f;
}

float Stack::SpanOf(int32_t section) const noexcept
{
    return SectionAt(section).span;
}

SpanBand Stack::Band(int32_t section, const Tuning& t) const noexcept
{
    return anchor::ClassifySpan(SpanOf(section), t);
}

float Stack::FlexDeflectionM(int32_t section, float loadKN, const Tuning& t) const noexcept
{
    // Steeper than a textbook beam's cube on purpose: the span table says a short span is *rigid*,
    // and a cube leaves 3 m bowing a noticeable centimetre and a half. The exponent is what lets
    // 3 m be millimetres while 5 m is several centimetres (CLIMB-001 acceptance 4).
    const float span = SpanOf(section);
    return t.GetF("ladderFlexCoeffMPerKN") * std::max(loadKN, 0.0f)
           * std::pow(std::max(span, 0.0f), t.GetF("ladderFlexExponent"));
}

float Stack::TopHeight() const noexcept
{
    float top = 0.0f;
    for (int32_t i = 0; i < SectionCount(); ++i)
    {
        if (!SectionFailed(i))
        {
            top = std::max(top, AnchorAt(SectionAt(i).upperAnchor).height);
        }
    }
    return top;
}

int32_t Stack::SectionAt(float height) const noexcept
{
    int32_t best = -1;
    float best_lower = -1.0f;
    for (int32_t i = 0; i < SectionCount(); ++i)
    {
        if (SectionFailed(i))
        {
            continue;
        }
        const float lower = AnchorAt(SectionAt(i).lowerAnchor).height;
        if (lower <= height && lower > best_lower)
        {
            best = i;
            best_lower = lower;
        }
    }
    return best;
}

std::vector<float> Stack::Shares(int32_t atSection, float totalKN, const Tuning& t) const
{
    std::vector<float> out(anchors_.size(), 0.0f);
    if (SectionFailed(atSection))
    {
        out[0] = totalKN;   // nothing on the stack holds him; he is on the ground's account
        return out;
    }

    // Every intact anchor in the structure at or below the top of his section, nearest first. Not
    // every dog in the wall: one nobody lashed a ladder to is holding nothing up.
    const float top = AnchorAt(SectionAt(atSection).upperAnchor).height;
    std::vector<int32_t> below;
    for (int32_t i = 0; i < AnchorCount(); ++i)
    {
        if (InStructure(i) && anchors_[static_cast<std::size_t>(i)].height <= top + kSameHeight)
        {
            below.push_back(i);
        }
    }
    std::sort(below.begin(), below.end(), [&](int32_t a, int32_t b) {
        return anchors_[static_cast<std::size_t>(a)].height > anchors_[static_cast<std::size_t>(b)].height;
    });

    // share(n) = falloff^n, n = anchors below the top, normalised.
    const float falloff = t.GetF("loadShareFalloff");
    float sum = 0.0f;
    float w = 1.0f;
    std::vector<float> weight(below.size());
    for (std::size_t n = 0; n < below.size(); ++n)
    {
        weight[n] = w;
        sum += w;
        w *= falloff;
    }
    for (std::size_t n = 0; n < below.size(); ++n)
    {
        out[static_cast<std::size_t>(below[n])] = (sum > 0.0f) ? totalKN * weight[n] / sum : 0.0f;
    }
    return out;
}

void Stack::FailAnchor(int32_t i)
{
    if (i <= 0 || i >= AnchorCount())
    {
        return;   // the ground does not fail
    }
    anchorFailed_[static_cast<std::size_t>(i)] = true;
    const float h = anchors_[static_cast<std::size_t>(i)].height;
    // Everything hung from it comes off, and everything above it comes down with it. A section
    // stays up only if the stack under it does — and one resting on a section that has gone is
    // resting on nothing.
    for (int32_t s = 0; s < SectionCount(); ++s)
    {
        const Section& sec = sections_[static_cast<std::size_t>(s)];
        if (sec.upperAnchor == i || AnchorAt(sec.lowerAnchor).height >= h - kSameHeight)
        {
            sectionFailed_[static_cast<std::size_t>(s)] = true;
        }
    }
}

std::vector<int32_t> Stack::Cascade(int32_t failed, float shockKN, const Tuning& t)
{
    std::vector<int32_t> order;
    if (failed <= 0 || AnchorFailed(failed))
    {
        return order;
    }
    order.push_back(failed);
    FailAnchor(failed);

    // Down the stack from the one that went, nearest first.
    std::vector<int32_t> below;
    const float h = anchors_[static_cast<std::size_t>(failed)].height;
    for (int32_t i = 0; i < AnchorCount(); ++i)
    {
        if (InStructure(i) && anchors_[static_cast<std::size_t>(i)].height < h)
        {
            below.push_back(i);
        }
    }
    std::sort(below.begin(), below.end(), [&](int32_t a, int32_t b) {
        return anchors_[static_cast<std::size_t>(a)].height > anchors_[static_cast<std::size_t>(b)].height;
    });

    // `shockKN` is what arrives at the next anchor down. Each failure absorbs part of it — the dog
    // tearing out, the ladder flexing — so a cascade can stop: it runs until it reaches an anchor
    // rated for what is left, or the ground.
    const float retained = t.GetF("cascadeShockRetained");
    float shock = shockKN;
    for (int32_t i : below)
    {
        if (i == 0)
        {
            break;   // the ground takes it
        }
        if (shock <= anchors_[static_cast<std::size_t>(i)].capacityKN)
        {
            break;   // acceptance 5: stops at the first anchor that can absorb it
        }
        order.push_back(i);
        FailAnchor(i);
        shock *= retained;
    }
    return order;
}

std::vector<int32_t> Stack::Shock(int32_t anchor, float shockKN, const Tuning& t)
{
    if (anchor <= 0 || AnchorFailed(anchor))
    {
        return {};
    }
    if (shockKN <= anchors_[static_cast<std::size_t>(anchor)].capacityKN)
    {
        return {};
    }
    // It went, and took some of the shock with it; the rest arrives at the next one down.
    return Cascade(anchor, shockKN * t.GetF("cascadeShockRetained"), t);
}

StackEvents Stack::Step(float dt, int32_t loadedSection, float loadKN, const Tuning& t)
{
    StackEvents ev;

    // Only the section he is on is loaded. Every other one's buckle timer resets — acceptance 3:
    // stepping off a bowing section is the warning's whole point, and it has to work.
    for (int32_t s = 0; s < SectionCount(); ++s)
    {
        if (s != loadedSection)
        {
            sections_[static_cast<std::size_t>(s)].buckleTimer = -1.0f;
        }
    }
    if (loadedSection < 0 || SectionFailed(loadedSection))
    {
        return ev;
    }

    Section& sec = sections_[static_cast<std::size_t>(loadedSection)];
    const SpanBand band = Band(loadedSection, t);

    // --- buckling: a timer, not an instant -------------------------------------------------------
    if (band == SpanBand::Buckle)
    {
        if (sec.buckleTimer < 0.0f)
        {
            sec.buckleTimer = t.GetF("buckleSecondsUnderLoad");
        }
        sec.buckleTimer -= dt;
        ev.buckling = loadedSection;
        ev.buckleSecondsLeft = std::max(sec.buckleTimer, 0.0f);
        if (sec.buckleTimer <= 0.0f)
        {
            sectionFailed_[static_cast<std::size_t>(loadedSection)] = true;
            ev.failedSections.push_back(loadedSection);
            return ev;
        }
    }

    // --- a quick hitch walks under load ----------------------------------------------------------
    if (sec.lashing == Lashing::Hitch)
    {
        float& drift = driftCm_[static_cast<std::size_t>(loadedSection)];
        drift += lash::DriftPerMinuteCm(sec.lashing, t) * dt / 60.0f;   // literal: per minute
        if (drift >= t.GetF("lashHitchWalkOffCm"))
        {
            // It has walked off the lug. The section is hanging from nothing.
            sectionFailed_[static_cast<std::size_t>(loadedSection)] = true;
            ev.failedSections.push_back(loadedSection);
            return ev;
        }
    }

    // --- the anchors: each carries its share, harder on a swaying span ---------------------------
    // Snapshot, so the report names only what went *this* step.
    const std::vector<bool> was_failed = sectionFailed_;
    const float dynamic = anchor::DynamicLoadMultiplier(band, t);
    const std::vector<float> share = Shares(loadedSection, loadKN * dynamic, t);
    // Top down, so if two would fail, the higher one goes first and its cascade decides the other.
    std::vector<int32_t> order;
    for (int32_t i = 1; i < AnchorCount(); ++i)
    {
        if (!AnchorFailed(i) && share[static_cast<std::size_t>(i)] > 0.0f)
        {
            order.push_back(i);
        }
    }
    std::sort(order.begin(), order.end(), [&](int32_t a, int32_t b) {
        return anchors_[static_cast<std::size_t>(a)].height > anchors_[static_cast<std::size_t>(b)].height;
    });
    for (int32_t i : order)
    {
        if (AnchorFailed(i))
        {
            continue;
        }
        const float load = share[static_cast<std::size_t>(i)];
        if (load > anchors_[static_cast<std::size_t>(i)].capacityKN)
        {
            // Pulled. What it was holding drops onto the next one down, as a shock.
            const std::vector<int32_t> gone = Cascade(i, load * t.GetF("dynamicLoadFactor"), t);
            ev.failedAnchors.insert(ev.failedAnchors.end(), gone.begin(), gone.end());
            break;
        }
    }
    for (int32_t s = 0; s < SectionCount(); ++s)
    {
        if (sectionFailed_[static_cast<std::size_t>(s)] && !was_failed[static_cast<std::size_t>(s)])
        {
            ev.failedSections.push_back(s);
        }
    }
    return ev;
}

}  // namespace sj
