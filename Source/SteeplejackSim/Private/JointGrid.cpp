// The joint grid — STRUCT-002. See JointGrid.h for what a grid is and why the tell lives here.

#include "JointGrid.h"

#include "Level.h"
#include "Rng.h"
#include "Tuning.h"
#include "Verbs/Tap.h"

#include <algorithm>
#include <array>
#include <cmath>

namespace sj {
namespace {

constexpr float kPi = 3.14159265358979f;         // literal: pi
constexpr float kDegToRad = kPi / 180.0f;        // literal: unit conversion
constexpr uint32_t kGridStream = 0x4A4F494Eu;    // literal: 'JOIN', the grid's RNG fork tag
constexpr uint32_t kTellStream = 0x54454C4Cu;    // literal: 'TELL', the look's RNG fork tag
constexpr std::size_t kTiers = 4;                // literal: JointTier's four members

const Joint& NullJoint() noexcept
{
    // Acceptance 4: a null object, not a null. Tier Cracked and quality 0 on purpose — anything
    // that forgets to check the id and uses this joint anyway gets the worst joint in the game,
    // not a sound one, and a dog driven into it fails loudly rather than holding by accident.
    static const Joint kNull{-1, {}, {}, 0.0f, 0.0f, JointTier::Cracked, true};
    return kNull;
}

// The quality range a tier covers, from jointQualityTierBounds. A joint drawn as "fair" gets a
// quality somewhere in fair's range, so its tier and its quality can never disagree.
void TierRange(JointTier tier, const Tuning& t, float& lo, float& hi) noexcept
{
    const float cracked = t.GetF("jointQualityTierBounds.cracked");
    const float perished = t.GetF("jointQualityTierBounds.perished");
    const float fair = t.GetF("jointQualityTierBounds.fair");
    switch (tier)
    {
    case JointTier::Cracked:  lo = 0.0f;     hi = cracked;  return;
    case JointTier::Perished: lo = cracked;  hi = perished; return;
    case JointTier::Fair:     lo = perished; hi = fair;     return;
    case JointTier::Sound:    lo = fair;     hi = 1.0f;     return;
    }
    lo = 0.0f;
    hi = 1.0f;
}

// Where a bearing is on the face, at a radius.
Vec3 OnFace(float radius, float height, float bearingDeg) noexcept
{
    const float b = bearingDeg * kDegToRad;
    return Vec3{radius * std::sin(b), height, -radius * std::cos(b)};
}

float Dist(const Vec3& a, const Vec3& b) noexcept
{
    const float dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z;
    return std::sqrt(dx * dx + dy * dy + dz * dz);
}

float RadiusAt(const StructureSpec& s, float h) noexcept
{
    const float u = (s.height > 0.0f) ? std::clamp(h / s.height, 0.0f, 1.0f) : 0.0f;
    return s.baseRadius + (s.topRadius - s.baseRadius) * u;
}

// A smooth, deterministic field over the face, for clustering. Low frequency on purpose: a patch
// of good joints should be a patch you can find by following it, not speckle.
float Field(float height, float bearingDeg, float phase) noexcept
{
    const float b = bearingDeg * kDegToRad;
    return 0.5f + 0.25f * std::sin(height * 0.9f + phase)            // literal: patch size, ~7 m
               + 0.25f * std::sin(b * 3.0f + height * 0.35f + phase * 1.7f);   // literal: ditto
}

}  // namespace

JointGrid JointGrid::Generate(const LevelData& level, const Rng& parent, const Tuning& t,
                              float climbBearingDeg)
{
    JointGrid g;
    Rng rng = parent.Fork(kGridStream);
    Rng tell = parent.Fork(kTellStream);

    const StructureSpec& s = level.Structure();
    const float density = (s.candidateDensity > 0.0f) ? s.candidateDensity : 1.0f;
    const float spacing = 1.0f / std::sqrt(density);
    g.rowSpacing_ = spacing;
    const float noise = t.GetF("jointTellNoise");

    // --- lay the joints out, row by row ---------------------------------------------------------
    int32_t row = 0;
    for (float h = spacing * 0.5f; h < s.height; h += spacing, ++row)
    {
        g.rowStart_.push_back(static_cast<int32_t>(g.joints_.size()));
        g.rowHeight_.push_back(h);

        const float r = RadiusAt(s, h);
        const float circumference = 2.0f * kPi * r;
        const int count = std::max(1, static_cast<int>(circumference / spacing));
        const float step = 360.0f / static_cast<float>(count);
        // Half a step on alternate rows. Bonded brickwork, and the reason the grid does not look
        // like a spreadsheet wrapped round a pipe.
        const float offset = (row % 2 == 0) ? 0.0f : step * 0.5f;

        for (int k = 0; k < count; ++k)
        {
            const float bearing = std::fmod(climbBearingDeg + offset + step * static_cast<float>(k),
                                            360.0f);   // literal: degrees in a circle
            Joint j{};
            j.id = static_cast<int32_t>(g.joints_.size());
            j.height = h;
            j.pos = OnFace(r, h, bearing);
            const Vec3 n = OnFace(1.0f, 0.0f, bearing);
            j.normal = Vec3{n.x, 0.0f, n.z};
            g.joints_.push_back(j);
        }
    }
    g.rowStart_.push_back(static_cast<int32_t>(g.joints_.size()));

    // --- assign tiers band by band, stratified ----------------------------------------------------
    for (const BandSpec& band : level.Bands())
    {
        std::vector<int32_t> ids;
        for (const Joint& j : g.joints_)
        {
            if (band.Contains(j.height))
            {
                ids.push_back(j.id);
            }
        }
        if (ids.empty())
        {
            continue;
        }

        // Exactly the counts the band asks for, by largest remainder so they sum to the total.
        const std::array<float, kTiers> share = {band.cracked, band.perished, band.fair,
                                                 band.sound};
        const float total = static_cast<float>(ids.size());
        std::array<int32_t, kTiers> n{};
        std::array<float, kTiers> rem{};
        int32_t assigned = 0;
        for (std::size_t k = 0; k < kTiers; ++k)
        {
            const float want = share[k] * total;
            n[k] = static_cast<int32_t>(std::floor(want));
            rem[k] = want - std::floor(want);
            assigned += n[k];
        }
        while (assigned < static_cast<int32_t>(ids.size()))
        {
            const auto best = static_cast<std::size_t>(
                std::max_element(rem.begin(), rem.end()) - rem.begin());
            ++n[best];
            rem[best] = -1.0f;
            ++assigned;
        }

        std::vector<JointTier> tiers;
        tiers.reserve(ids.size());
        for (std::size_t k = 0; k < kTiers; ++k)
        {
            for (int32_t c = 0; c < n[k]; ++c)
            {
                tiers.push_back(static_cast<JointTier>(k));
            }
        }

        // Shuffle — Fisher-Yates from the grid's own stream.
        for (std::size_t i = tiers.size(); i > 1; --i)
        {
            const auto swap_with =
                static_cast<std::size_t>(rng.RangeInt(0, static_cast<int32_t>(i)));
            std::swap(tiers[i - 1], tiers[swap_with]);
        }

        // Clustering. A permutation, so the proportions above survive it exactly: rank the joints
        // by a smooth field blended with noise, rank the tiers best-first, and pair them up. At 0
        // this is the shuffle; towards 1 the sound joints gather where the field is high.
        if (band.soundJointClustering > 0.0f)
        {
            const float phase = rng.RangeFloat(0.0f, 2.0f * kPi);
            std::vector<std::pair<float, int32_t>> rank;
            rank.reserve(ids.size());
            for (int32_t id : ids)
            {
                const Joint& j = g.joints_[static_cast<std::size_t>(id)];
                const float bearing =
                    std::atan2(j.pos.x, -j.pos.z) / kDegToRad;
                const float f = Field(j.height, bearing, phase);
                const float mix = band.soundJointClustering * f
                                  + (1.0f - band.soundJointClustering) * rng.NextFloat();
                rank.emplace_back(mix, id);
            }
            std::sort(rank.begin(), rank.end(),
                      [](const auto& a, const auto& b) { return a.first > b.first; });
            std::sort(tiers.begin(), tiers.end(),
                      [](JointTier a, JointTier b) { return a > b; });
            for (std::size_t i = 0; i < rank.size(); ++i)
            {
                ids[i] = rank[i].second;
            }
        }

        for (std::size_t i = 0; i < ids.size(); ++i)
        {
            Joint& j = g.joints_[static_cast<std::size_t>(ids[i])];
            j.tier = tiers[i];
            float lo = 0.0f, hi = 1.0f;
            TierRange(j.tier, t, lo, hi);
            j.quality = rng.RangeFloat(lo, hi);
        }

        // Authored joints, on the climbing line, nearest the height asked for.
        //
        // An authored joint is never a candidate for the next one. Without that, the Back Yard's
        // cracked joint at 7.0 m took the joint just moved to 7.2 m to be perished — it was the
        // nearest one, because it had just been put there — and the level lost an authored joint
        // with no error, leaving one fewer lesson on the climbing line than its designer wrote.
        std::vector<bool> authored(g.joints_.size(), false);
        auto force = [&](const std::vector<float>& heights, JointTier tier) {
            for (float want : heights)
            {
                const Vec3 at = OnFace(RadiusAt(s, want), want, climbBearingDeg);
                int32_t best = -1;
                float best_d = 0.0f;
                for (const Joint& j : g.joints_)
                {
                    if (authored[static_cast<std::size_t>(j.id)])
                    {
                        continue;
                    }
                    const float d = Dist(j.pos, at);
                    if (best < 0 || d < best_d)
                    {
                        best = j.id;
                        best_d = d;
                    }
                }
                if (best >= 0)
                {
                    Joint& j = g.joints_[static_cast<std::size_t>(best)];
                    j.tier = tier;
                    float lo = 0.0f, hi = 1.0f;
                    TierRange(tier, t, lo, hi);
                    j.quality = (lo + hi) * 0.5f;   // squarely in the tier, not on its edge
                    // Pinned to the authored height rather than left on the nearest row. Level 1's
                    // cracked joint is "at 7 m" because a designer measured where the player's
                    // hand would be; half a row out is a different joint.
                    j.height = want;
                    j.pos = at;
                    authored[static_cast<std::size_t>(best)] = true;
                }
            }
        };
        force(band.forcePerishedAt, JointTier::Perished);
        force(band.forceCrackedAt, JointTier::Cracked);
    }

    // --- the tell ---------------------------------------------------------------------------------
    // Quality plus a fixed error, blended towards pure noise by the band's reliability. Drawn from
    // its own stream so that changing how the look works cannot move a single joint's truth.
    g.apparent_.resize(g.joints_.size());
    for (const Joint& j : g.joints_)
    {
        float reliability = 1.0f;
        for (const BandSpec& band : level.Bands())
        {
            if (band.Contains(j.height))
            {
                reliability = std::clamp(band.visualReadReliability, 0.0f, 1.0f);
                break;
            }
        }
        const float read = std::clamp(j.quality + tell.RangeFloat(-noise, noise), 0.0f, 1.0f);
        const float blind = tell.NextFloat();
        g.apparent_[static_cast<std::size_t>(j.id)] =
            reliability * read + (1.0f - reliability) * blind;
    }

    return g;
}

const Joint& JointGrid::ById(int32_t id) const noexcept
{
    if (id < 0 || id >= static_cast<int32_t>(joints_.size()))
    {
        return NullJoint();
    }
    return joints_[static_cast<std::size_t>(id)];
}

float JointGrid::Apparent(int32_t id) const noexcept
{
    if (id < 0 || id >= static_cast<int32_t>(apparent_.size()))
    {
        return 0.0f;
    }
    return apparent_[static_cast<std::size_t>(id)];
}

std::vector<int32_t> JointGrid::Near(float height, float bearingDeg, float range) const
{
    std::vector<int32_t> out;
    if (rowHeight_.empty())
    {
        return out;
    }
    const auto lo_row = static_cast<std::size_t>(
        std::lower_bound(rowHeight_.begin(), rowHeight_.end(), height - range) - rowHeight_.begin());
    const auto hi_row = static_cast<std::size_t>(
        std::upper_bound(rowHeight_.begin(), rowHeight_.end(), height + range) - rowHeight_.begin());

    // The point on the face we are measuring from, at the radius of the first joint in range —
    // close enough, since the batter changes the radius by millimetres over a few metres.
    const std::size_t probe_row = std::min(lo_row, rowHeight_.size() - 1);
    const Joint& ref = joints_[static_cast<std::size_t>(rowStart_[probe_row])];
    const float r = std::sqrt(ref.pos.x * ref.pos.x + ref.pos.z * ref.pos.z);
    const Vec3 at = OnFace(r, height, bearingDeg);

    // Authored joints can sit between rows, so widen by a row either side to be sure of them.
    const std::size_t from = (lo_row > 0) ? lo_row - 1 : 0;
    const std::size_t to = std::min(hi_row + 1, rowHeight_.size());
    for (std::size_t row = from; row < to; ++row)
    {
        for (int32_t i = rowStart_[row]; i < rowStart_[row + 1]; ++i)
        {
            if (Dist(joints_[static_cast<std::size_t>(i)].pos, at) <= range)
            {
                out.push_back(i);
            }
        }
    }
    return out;
}

int32_t JointGrid::Nearest(const Vec3& pos, float maxRange) const noexcept
{
    int32_t best = -1;
    float best_d = maxRange;
    for (const Joint& j : joints_)
    {
        if (j.occupied)
        {
            continue;
        }
        const float d = Dist(j.pos, pos);
        if (d <= best_d)
        {
            best = j.id;
            best_d = d;
        }
    }
    return best;
}

void JointGrid::SetOccupied(int32_t id, bool occupied) noexcept
{
    if (id >= 0 && id < static_cast<int32_t>(joints_.size()))
    {
        joints_[static_cast<std::size_t>(id)].occupied = occupied;
    }
}

}  // namespace sj
