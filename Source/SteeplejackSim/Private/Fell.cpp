// The fall — FELL-002. See Fell.h.

#include "Fell.h"

#include "Gob.h"
#include "Rng.h"
#include "Tuning.h"

#include <algorithm>
#include <cmath>

namespace sj {
namespace {

constexpr float kDegToRad = 0.017453292f;   // literal: degrees to radians
constexpr float kHalfTurn = 180.0f;         // literal: degrees in a half turn
constexpr float kFullTurn = 360.0f;         // literal: degrees in a turn
constexpr float kGravity = 9.81f;           // literal: m/s^2, and the chimney is on Earth
constexpr float kPercent = 0.01f;           // literal: the pull weights are percentages
constexpr float kRodRate = 3.0f;            // literal: a uniform rod hinging about its foot has
                                            //          w^2 = 3g/H (1 - cos theta)
constexpr float kFiveMetres = 5.0f;         // literal: the unit the accuracy bonus is quoted in
constexpr float kTenMetres = 10.0f;         // literal: the unit the accuracy penalty is quoted in
constexpr float kTiny = 1e-6f;              // literal: a pull this small has no direction
constexpr int   kSteps = 512;               // literal: hinge steps from upright to ground

float Wrap360(float deg) noexcept
{
    deg = std::fmod(deg, kFullTurn);
    return (deg < 0.0f) ? deg + kFullTurn : deg;
}

}  // namespace

float Fell::BearingDelta(float fromDeg, float toDeg) noexcept
{
    float d = Wrap360(toDeg - fromDeg);
    return (d > kHalfTurn) ? d - kFullTurn : d;
}

bool FellPrediction::Threatens(const Exclusion& e) const noexcept
{
    return std::fabs(Fell::BearingDelta(fallBearingDeg, e.bearingDeg)) <= debrisHalfAngleDeg &&
           e.distanceM <= debrisLengthM;
}

FellPrediction Fell::Predict(const FellSite& site, const Gob& gob, const FellPlan& plan,
                             const Tuning& t)
{
    FellPrediction out;
    const float shaft = std::max(site.heightM - plan.heightRemovedM, 0.0f);

    // Sum the pulls as vectors and take the direction. The gob is the unit the others are quoted
    // against, and it only has authority in proportion to how much of it has been cut: a gob two
    // segments deep does not steer a chimney, and the lean wins.
    const float idealArc = t.GetF("fallGobIdealArcDegrees");
    const float gobPull = (idealArc > kTiny) ? std::min(gob.CutArcDegrees() / idealArc, 1.0f) : 0.0f;
    const float leanPull = t.GetF("fallLeanPullPerDegree") * kPercent * site.leanDeg;
    const float windPull = t.GetF("fallWindPullPerMetreSecond") * kPercent * site.windSpeedMps;

    Vec2 sum{0.0f, 0.0f};
    const auto add = [&sum](float bearingDeg, float weight) {
        const float b = bearingDeg * kDegToRad;
        sum.x += std::sin(b) * weight;
        sum.y += std::cos(b) * weight;
    };
    add(gob.CutCentreBearing(), gobPull);
    add(site.leanBearingDeg, leanPull);
    add(site.windBearingDeg, windPull);

    // Nothing is pulling: an uncut chimney with no lean and no wind is not falling anywhere, and
    // the honest answer is the way it leans, which is the pegs' problem, not ours.
    out.fallBearingDeg = (std::fabs(sum.x) < kTiny && std::fabs(sum.y) < kTiny)
                             ? Wrap360(site.leanBearingDeg)
                             : Wrap360(std::atan2(sum.x, sum.y) / kDegToRad);
    out.errorDegrees = std::fabs(BearingDelta(plan.pegBearingDeg, out.fallBearingDeg));

    // The cone. "Fighting the lean" is the part of the lean that is pulling away from where the
    // player asked it to go — a lean straight down the fall line costs nothing at all, which is
    // why the tutorial felling has a negligible one and Kershaw's Yard has 1.4° pointing the
    // wrong way.
    const float fought = site.leanDeg *
                         (1.0f - std::cos(BearingDelta(site.leanBearingDeg, plan.pegBearingDeg) * kDegToRad)) *
                         0.5f;   // literal: (1-cos)/2 is 0 in line and 1 dead against
    float acc = t.GetF("fallAccuracyBaseDegrees");
    acc += t.GetF("fallAccuracyPerLeanFoughtDegree") * fought;
    acc += t.GetF("fallAccuracyPerTenMetres") * shaft / kTenMetres;
    acc -= t.GetF("fallAccuracyPerFiveMetresRemoved") * plan.heightRemovedM / kFiveMetres;
    if (gob.CutArcDegrees() < idealArc)
    {
        acc += t.GetF("fallAccuracyNarrowGobDegrees");
    }
    out.accuracyDegrees = std::max(acc, t.GetF("fallAccuracyBaseDegrees"));

    out.debrisHalfAngleDeg = t.GetF("fallDebrisHalfAngleDegrees");
    out.debrisLengthM = shaft * t.GetF("fallDebrisLengthFactor");
    return out;
}

std::vector<float> Fell::FractureHeights(float shaftHeightM, const Tuning& t)
{
    // Walk it over. At each angle the shaft is turning at w^2 = 3g/H (1 - cos theta), and the
    // bending stress at height h is coeff * w^2 * h with the threshold taken as 1. Both terms grow
    // as it goes, so the first band to let go is the highest one, and once it has gone the piece
    // below it is a shorter shaft turning at the same rate and the next one down follows. That is
    // the 2-4 breaks the design asks for, and nothing here is random.
    std::vector<float> out;
    const float coeff = t.GetF("fellFractureStressCoeff");
    const float minH = t.GetF("fellFractureMinHeightM");
    // A chimney does not come down as confetti. The shortest piece that can part off is authored,
    // and it is what keeps this to the two to four breaks the design asks for instead of sawing
    // the shaft into every band that happens to be over the threshold.
    const float minChunk = t.GetF("fellFractureMinChunkM");
    if (shaftHeightM <= minH || coeff <= 0.0f)
    {
        return out;
    }
    float intact = shaftHeightM;
    for (int i = 1; i <= kSteps; ++i)
    {
        const float theta = (kHalfTurn * 0.5f) * static_cast<float>(i) / static_cast<float>(kSteps);
        const float w2 = kRodRate * kGravity / shaftHeightM * (1.0f - std::cos(theta * kDegToRad));
        const float band = intact - minChunk;   // the highest place a whole chunk can come off
        if (band < minH)
        {
            break;
        }
        if (coeff * w2 * band > 1.0f)   // literal: the threshold, normalised into the coefficient
        {
            out.push_back(band);
            intact = band;
        }
    }
    return out;
}

FellOutcome Fell::Run(const FellSite& site, const Gob& gob, const FellPlan& plan, const Tuning& t)
{
    const FellPrediction pred = Predict(site, gob, plan, t);
    const float shaft = std::max(site.heightM - plan.heightRemovedM, 0.0f);

    FellOutcome out;
    // It lands inside the cone it promised. The seed is the level's, so a level always falls the
    // same way and a player can learn one — and it is forked off the gob so that cutting a
    // different hole is a different fall, not the same fall pointed elsewhere.
    Rng rng(site.seed);
    Rng shake = rng.Fork(static_cast<uint32_t>(gob.CutArcDegrees()));
    out.fallBearingDeg =
        Wrap360(pred.fallBearingDeg + shake.RangeFloat(-pred.accuracyDegrees, pred.accuracyDegrees));
    out.errorDegrees = std::fabs(BearingDelta(plan.pegBearingDeg, out.fallBearingDeg));

    if (out.errorDegrees <= t.GetF("fellScorePerfectDegrees"))
    {
        out.grade = FellGrade::Perfect;
        out.bonusGbp += t.GetF("fellScorePerfectBonus");
    }
    else if (out.errorDegrees <= t.GetF("fellScoreGoodDegrees"))
    {
        out.grade = FellGrade::Good;
        out.bonusGbp += t.GetF("fellScoreGoodBonus");
    }
    else if (out.errorDegrees <= t.GetF("fellScoreAcceptableDegrees"))
    {
        out.grade = FellGrade::Acceptable;
    }
    else
    {
        out.grade = FellGrade::Wild;
    }

    out.fractureHeightsM = FractureHeights(shaft, t);
    out.chunks = static_cast<int32_t>(out.fractureHeightsM.size()) + 1;
    out.cleanBreak = out.chunks >= t.GetI("fellCleanBreakMinChunks") &&
                     out.chunks <= t.GetI("fellCleanBreakMaxChunks");
    if (out.cleanBreak)
    {
        out.bonusGbp += t.GetF("fellScoreCleanBreakBonus");
    }

    // What it hit. The fan is drawn round where it really went, not where it was predicted to.
    FellPrediction actual = pred;
    actual.fallBearingDeg = out.fallBearingDeg;
    for (const Exclusion& e : site.exclusions)
    {
        if (!actual.Threatens(e))
        {
            continue;
        }
        out.struck.push_back(e.id);
        out.catastrophe = out.catastrophe || e.catastrophic;
        out.penaltyGbp += e.valueGbp;
    }
    return out;
}

}  // namespace sj
