#include "Conductor.h"

#include "Tuning.h"

#include <algorithm>
#include <cmath>

namespace sj {

namespace {

constexpr float kNoHeight = -1.0f;      // literal: no clip fixed yet
constexpr float kTiny = 1.0e-4f;        // literal: float comparison tolerance

}  // namespace

void Conductor::Begin(float reelMetres, const Tuning& t) noexcept
{
    run_ = ConductorRun{};
    run_.tapeLeftM = reelMetres > 0.0f ? reelMetres : t.GetF("reelMetres");
    lastHeight_ = kNoHeight;
    topHeight_ = kNoHeight;
    tapeUsed_ = 0.0f;
}

bool Conductor::Fix(float heightM, float tapePaidM, float tightness, const Tuning& t) noexcept
{
    const float paid = std::max(tapePaidM, 0.0f);
    // The reel is finite, and running out is a real way for the job to end rather than an error.
    // It is also the one failure the player can see coming, which is what makes it fair.
    if (paid > run_.tapeLeftM + kTiny)
    {
        return false;
    }

    if (topHeight_ < 0.0f)
    {
        topHeight_ = heightM;
    }
    else
    {
        run_.longestGapM = std::max(run_.longestGapM, std::fabs(lastHeight_ - heightM));
    }

    run_.tapeLeftM -= paid;
    tapeUsed_ += paid;
    lastHeight_ = heightM;
    ++run_.clips;

    // Too tight is not "more secure". A pinched rod cannot move when it is cold and the fixing
    // becomes a hinge; too loose and it works itself off the wall in the first gale. The verb has
    // a right answer in the middle, which is the same shape as driving a dog and is why this
    // archetype reuses the hammer rather than inventing anything.
    if (tightness > t.GetF("clipTightMax"))
    {
        ++run_.overTight;
    }
    else if (tightness < t.GetF("clipTightMin"))
    {
        ++run_.tooLoose;
    }
    return true;
}

void Conductor::Earth(float plateSquareFeet, bool wet, bool coke, const Tuning& t) noexcept
{
    // More copper in the ground is less resistance, and the Code's 18 square feet is the figure
    // the rest is measured against.
    const float wanted = std::max(t.GetF("earthPlateSquareFeetMin"), kTiny);
    const float share = std::max(plateSquareFeet, kTiny) / wanted;
    // Floored so a token scrap of copper cannot read as an open circuit and divide by nothing.
    constexpr float kLeastShare = 0.15f;   // literal: a floor on the divisor, not a design number
    float ohms = t.GetF("earthBaseOhms") / std::max(share, kLeastShare);
    if (!wet)
    {
        // "The hole must be so deep that the earth surrounding the plate shall never be dry." A
        // pit that dries out in summer passes in March and fails in August, which is a real and
        // documented way for a system to be quietly useless.
        ohms *= t.GetF("earthDryPenalty");
    }
    if (!coke)
    {
        ohms *= t.GetF("earthNoCokePenalty");
    }
    run_.earthOhms = ohms;
}

ConductorRun Conductor::Judge(float fromHeightM, const Tuning& t) const noexcept
{
    ConductorRun out = run_;

    // The curvature rule. Tape paid out against the straight line it covers: the Code allows half
    // as long again and no more, whatever the run looks like from the ground.
    const float straight = (topHeight_ > 0.0f) ? std::fabs(topHeight_ - fromHeightM) : 0.0f;
    out.wanderRatio = (straight > kTiny) ? tapeUsed_ / straight : 1.0f;

    const bool wandered = out.wanderRatio > t.GetF("wanderFailRatio");
    const bool gapped = out.longestGapM > t.GetF("clipSpacingMaxMetres");
    const bool earthed = out.earthOhms >= 0.0f && out.earthOhms <= t.GetF("earthPassOhms");

    if (wandered || gapped || !out.terminalSet || !earthed || out.overTight > 0)
    {
        out.verdict = RunVerdict::Failed;
    }
    else if (out.wanderRatio > t.GetF("wanderWarnRatio") || out.tooLoose > 0)
    {
        out.verdict = RunVerdict::Marginal;
    }
    else
    {
        out.verdict = RunVerdict::Sound;
    }
    return out;
}

}  // namespace sj
