// The gob — FELL-001. See Gob.h.

#include "Gob.h"

#include "Tuning.h"

#include <algorithm>
#include <cmath>

namespace sj {
namespace {

constexpr float kDegToRad = 0.017453292f;   // literal: degrees to radians
constexpr float kFullTurn = 360.0f;         // literal: degrees in a turn
constexpr float kTiny = 1e-6f;              // literal: a bearing this small has no direction
constexpr float kFar = 1e9f;                // literal: further than any site
constexpr float kGravity = 9.81f;           // literal: m/s^2
constexpr float kNewtonsPerKN = 1000.0f;    // literal: N in a kN
constexpr float kTau = 6.2831853f;          // literal: a full turn, in radians

Vec2 OnBearing(float bearingDeg, float r) noexcept
{
    const float b = bearingDeg * kDegToRad;
    return Vec2{std::sin(b) * r, std::cos(b) * r};
}

float Cross(const Vec2& a, const Vec2& b) noexcept { return a.x * b.y - a.y * b.x; }

Vec2 Sub(const Vec2& a, const Vec2& b) noexcept { return Vec2{a.x - b.x, a.y - b.y}; }

float Length(const Vec2& v) noexcept { return std::sqrt(v.x * v.x + v.y * v.y); }

// The convex hull of the supports, counter-clockwise. A chimney stands on whatever is left of its
// ring, and the shape that matters is the outline of it, not the individual bricks.
std::vector<Vec2> Hull(std::vector<Vec2> pts)
{
    if (pts.size() < 3)   // literal: a hull needs three points
    {
        return pts;
    }
    std::sort(pts.begin(), pts.end(), [](const Vec2& a, const Vec2& b) {
        return (a.x != b.x) ? (a.x < b.x) : (a.y < b.y);
    });
    std::vector<Vec2> out;
    for (int pass = 0; pass < 2; ++pass)   // literal: lower hull, then upper
    {
        const std::size_t start = out.size();
        for (const Vec2& p : pts)
        {
            while (out.size() >= start + 2 &&
                   Cross(Sub(out[out.size() - 1], out[out.size() - 2]), Sub(p, out[out.size() - 2])) <= 0.0f)
            {
                out.pop_back();
            }
            out.push_back(p);
        }
        out.pop_back();
        std::reverse(pts.begin(), pts.end());
    }
    return out;
}

// Distance from a point to a segment.
float ToSegment(const Vec2& p, const Vec2& a, const Vec2& b) noexcept
{
    const Vec2 ab = Sub(b, a);
    const float len2 = ab.x * ab.x + ab.y * ab.y;
    float t = 0.0f;
    if (len2 > 0.0f)
    {
        t = std::clamp(((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / len2, 0.0f, 1.0f);
    }
    return Length(Sub(p, Vec2{a.x + ab.x * t, a.y + ab.y * t}));
}

}  // namespace

Gob::Gob(int32_t segments, int32_t courses, float baseRadius, float heightM, float weightKN,
         float leanDeg, float leanBearingDeg, int32_t props, int32_t dudProp, const Tuning& t)
    : segments_(std::max(segments, 1)), courses_(std::max(courses, 1)), radius_(baseRadius),
      height_(heightM), weightKN_(weightKN), leanDeg_(leanDeg), leanBearingDeg_(leanBearingDeg),
      propBudget_(std::max(props, 0)), dudProp_(dudProp),
      capacityKN_(t.GetF("gobPropCapacityKN")), propLever_(t.GetF("gobPropLeverFrac")),
      archHeight_(t.GetF("gobArchHeightM"))
{
    cells_.reserve(static_cast<std::size_t>(segments_ * courses_));
    for (int32_t s = 0; s < segments_; ++s)
    {
        for (int32_t c = 0; c < courses_; ++c)
        {
            cells_.push_back(GobCell{static_cast<int16_t>(s), static_cast<int16_t>(c), false, false, 1.0f});
        }
    }
    segLoad_.assign(static_cast<std::size_t>(segments_), 0.0f);
    Distribute();
}

float Gob::ShaftWeightKN(float baseRadius, float topRadius, float heightM, const Tuning& t)
{
    // A hollow tapered cylinder of brickwork: mean circumference times wall thickness times height.
    const float meanR = (baseRadius + topRadius) * 0.5f;
    const float volume = kTau * meanR * t.GetF("gobWallThicknessM") * heightM;
    return volume * t.GetF("gobBrickDensityKgPerM3") * kGravity / kNewtonsPerKN;
}

float Gob::SegmentBearing(int32_t seg) const noexcept
{
    return kFullTurn * static_cast<float>(seg) / static_cast<float>(segments_);
}

const GobCell& Gob::At(int32_t seg, int32_t course) const noexcept
{
    static const GobCell kNone{};
    if (seg < 0 || seg >= segments_ || course < 0 || course >= courses_)
    {
        return kNone;
    }
    return cells_[static_cast<std::size_t>(seg * courses_ + course)];
}

int32_t Gob::PropsLeft() const noexcept
{
    return propBudget_ - static_cast<int32_t>(props_.size());
}

void Gob::SetMortarAsymmetry(float bearingDeg, float bias) noexcept
{
    for (GobCell& c : cells_)
    {
        const float d = (SegmentBearing(c.seg) - bearingDeg) * kDegToRad;
        c.strength = std::clamp(1.0f - bias * std::cos(d), 0.0f, 2.0f);
    }
}

bool Gob::Cut(int32_t seg, int32_t course)
{
    if (seg < 0 || seg >= segments_ || course < 0 || course >= courses_)
    {
        return false;
    }
    GobCell& c = cells_[static_cast<std::size_t>(seg * courses_ + course)];
    if (c.removed)
    {
        return false;
    }
    c.removed = true;
    Distribute();
    return true;
}

bool Gob::SetProp(int32_t seg)
{
    if (seg < 0 || seg >= segments_ || PropsLeft() <= 0)
    {
        return false;
    }
    bool cutHere = false;
    for (int32_t c = 0; c < courses_; ++c)
    {
        cutHere = cutHere || At(seg, c).removed;
        if (At(seg, c).propped)
        {
            return false;   // one prop to a segment
        }
    }
    if (!cutHere)
    {
        return false;   // props go in behind the cut, not in front of it
    }
    for (int32_t c = 0; c < courses_; ++c)
    {
        cells_[static_cast<std::size_t>(seg * courses_ + c)].propped = true;
    }
    const auto index = static_cast<int32_t>(props_.size());
    props_.push_back(Prop{static_cast<int16_t>(seg), 0.0f, false, index == dudProp_});
    Distribute();
    return true;
}

float Gob::CutArcDegrees() const noexcept
{
    int32_t cut = 0;
    for (int32_t s = 0; s < segments_; ++s)
    {
        bool any = false;
        for (int32_t c = 0; c < courses_; ++c)
        {
            any = any || At(s, c).removed;
        }
        cut += any ? 1 : 0;
    }
    return kFullTurn * static_cast<float>(cut) / static_cast<float>(segments_);
}

float Gob::CutCentreBearing() const noexcept
{
    Vec2 sum{0.0f, 0.0f};
    for (int32_t s = 0; s < segments_; ++s)
    {
        for (int32_t c = 0; c < courses_; ++c)
        {
            if (At(s, c).removed)
            {
                const Vec2 p = OnBearing(SegmentBearing(s), 1.0f);
                sum.x += p.x;
                sum.y += p.y;
            }
        }
    }
    if (std::fabs(sum.x) < kTiny && std::fabs(sum.y) < kTiny)
    {
        return 0.0f;
    }
    float deg = std::atan2(sum.x, sum.y) / kDegToRad;
    return (deg < 0.0f) ? deg + kFullTurn : deg;
}

Vec2 Gob::CellPoint(int32_t seg) const noexcept
{
    return OnBearing(SegmentBearing(seg), radius_);
}

bool Gob::Bearing(int32_t seg) const noexcept
{
    for (int32_t c = 0; c < courses_; ++c)
    {
        if (!At(seg, c).removed)
        {
            return true;
        }
    }
    return false;
}

Prop* Gob::PropAt(int32_t seg) noexcept
{
    for (Prop& p : props_)
    {
        if (p.seg == seg)
        {
            return &p;
        }
    }
    return nullptr;
}

const Prop* Gob::PropAt(int32_t seg) const noexcept
{
    return const_cast<Gob*>(this)->PropAt(seg);
}

float Gob::SegmentLoadKN(int32_t seg) const noexcept
{
    if (seg < 0 || seg >= static_cast<int32_t>(segLoad_.size()))
    {
        return 0.0f;
    }
    return segLoad_[static_cast<std::size_t>(seg)];
}

void Gob::Distribute() noexcept
{
    // The share a segment would take if it were still there. For a ring under a weight that sits
    // `e` off the axis, the bearing pressure varies as 1 + (e/R)·cos(angle from the lean) — the
    // standard no-tension distribution. It is a small effect at the leans chimneys really have
    // (0.3° over 70 m is 18 cm on a 3.2 m ring, so ±6%), and it is the reason the lean side of the
    // gob is the side that bites first.
    const Vec2 cog = CentreOfGravity();
    const float e = (radius_ > kTiny) ? std::min(Length(cog) / radius_, 1.0f) : 0.0f;
    const auto n = static_cast<float>(segments_);
    std::vector<float> want(static_cast<std::size_t>(segments_), 0.0f);
    for (int32_t s = 0; s < segments_; ++s)
    {
        const float d = (SegmentBearing(s) - leanBearingDeg_) * kDegToRad;
        want[static_cast<std::size_t>(s)] = (weightKN_ / n) * (1.0f + e * std::cos(d));
    }

    // Anything with nothing under it sheds to the nearest support each side. Walking out rather
    // than spreading it over the whole ring is what makes a gap dangerous to its neighbours
    // instead of to the chimney in general.
    //
    // But only the part of it the arch cannot carry round. Above a hole in a wall the load goes to
    // the sides, and all that is left over the opening is the wall directly above it up to the
    // height the arch forms. That fraction is what a prop is actually under, and it is the whole
    // reason a gob is possible (Gob.h).
    const float arching = (height_ > kTiny) ? std::clamp(archHeight_ / height_, 0.0f, 1.0f) : 1.0f;
    segLoad_.assign(static_cast<std::size_t>(segments_), 0.0f);
    std::vector<bool> holds(static_cast<std::size_t>(segments_), false);
    bool anyBrick = false;
    for (int32_t s = 0; s < segments_; ++s)
    {
        const Prop* p = PropAt(s);
        holds[static_cast<std::size_t>(s)] = Bearing(s) || (p != nullptr && !p->split);
        anyBrick = anyBrick || Bearing(s);
    }
    // With no brick left anywhere there is no arch and nothing to arch to, and the props are under
    // the lot. That is a chimney standing on matchsticks, and it should read as one.
    const float local = anyBrick ? arching : 1.0f;
    for (int32_t s = 0; s < segments_; ++s)
    {
        const bool brick = Bearing(s);
        const float share = want[static_cast<std::size_t>(s)];
        if (brick)
        {
            segLoad_[static_cast<std::size_t>(s)] += share;
            continue;
        }
        // The hole's load arches away to the crescent; only its tributary stays here.
        const float here = share * local;
        if (holds[static_cast<std::size_t>(s)])
        {
            segLoad_[static_cast<std::size_t>(s)] += here;
            continue;
        }
        int32_t left = -1, right = -1;
        for (int32_t step = 1; step <= segments_; ++step)
        {
            const int32_t l = ((s - step) % segments_ + segments_) % segments_;
            const int32_t r = (s + step) % segments_;
            if (left < 0 && holds[static_cast<std::size_t>(l)])
            {
                left = l;
            }
            if (right < 0 && holds[static_cast<std::size_t>(r)])
            {
                right = r;
            }
            if (left >= 0 && right >= 0)
            {
                break;
            }
        }
        if (left < 0 && right < 0)
        {
            continue;   // nothing holds anything: the margin will say so
        }
        if (left < 0 || right < 0)
        {
            const int32_t only = (left < 0) ? right : left;
            segLoad_[static_cast<std::size_t>(only)] += here;
            continue;
        }
        const float half = here * 0.5f;
        segLoad_[static_cast<std::size_t>(left)] += half;
        segLoad_[static_cast<std::size_t>(right)] += half;
    }

    // A prop carries its segment only where the brick has all gone. Where brick remains, the brick
    // is stiffer and takes it, and the prop is along for the ride.
    for (Prop& p : props_)
    {
        p.loadKN = (p.split || Bearing(p.seg)) ? 0.0f : SegmentLoadKN(p.seg);
    }
}

std::vector<Vec2> Gob::SupportPoints() const
{
    std::vector<Vec2> pts;
    // A bearing segment is an arc of brick, not a point on one. Taking its centre would lose half a
    // segment of wall off each end of the crescent — a whole segment of support, which at 32
    // segments is the difference between a gob that stands and one that does not.
    const float half = kFullTurn / static_cast<float>(segments_) * 0.5f;
    for (int32_t s = 0; s < segments_; ++s)
    {
        if (Bearing(s))
        {
            pts.push_back(OnBearing(SegmentBearing(s) - half, radius_));
            pts.push_back(OnBearing(SegmentBearing(s) + half, radius_));
        }
    }
    for (const Prop& p : props_)
    {
        if (p.split || Bearing(p.seg))
        {
            continue;
        }
        // Drawn in towards the middle by what it is carrying: a prop at capacity is worth nothing
        // against the topple (Gob.h).
        const float reserve = (capacityKN_ > kTiny) ? std::clamp(1.0f - p.loadKN / capacityKN_, 0.0f, 1.0f) : 0.0f;
        pts.push_back(OnBearing(SegmentBearing(p.seg), radius_ * propLever_ * reserve));
    }
    return pts;
}

Vec2 Gob::CentreOfGravity() const noexcept
{
    // Chimneys are never plumb: a lean of θ over height H puts the weight H/2·tan θ off the axis,
    // along the lean's bearing. This is why it wants to fall the way it already leans.
    return OnBearing(leanBearingDeg_, height_ * 0.5f * std::tan(leanDeg_ * kDegToRad));
}

Vec2 Gob::SupportCentroid() const noexcept
{
    const std::vector<Vec2> pts = SupportPoints();
    if (pts.empty())
    {
        return Vec2{0.0f, 0.0f};
    }
    Vec2 sum{0.0f, 0.0f};
    for (const Vec2& p : pts)
    {
        sum.x += p.x;
        sum.y += p.y;
    }
    const auto n = static_cast<float>(pts.size());
    return Vec2{sum.x / n, sum.y / n};
}

std::vector<Vec2> Gob::SupportHull() const
{
    return Hull(SupportPoints());
}

float Gob::Margin() const noexcept
{
    const std::vector<Vec2> hull = SupportHull();
    const Vec2 cog = CentreOfGravity();
    if (hull.size() < 3)   // literal: fewer than three supports is not a polygon
    {
        return -1.0f;   // nothing left to stand on
    }
    float nearest = kFar;
    bool inside = true;
    for (std::size_t i = 0; i < hull.size(); ++i)
    {
        const Vec2& a = hull[i];
        const Vec2& b = hull[(i + 1) % hull.size()];
        inside = inside && Cross(Sub(b, a), Sub(cog, a)) >= 0.0f;
        nearest = std::min(nearest, ToSegment(cog, a, b));
    }
    return inside ? nearest : -nearest;
}

GobStatus Gob::Status(const Tuning& t) const noexcept
{
    const float m = Margin();
    if (m < t.GetF("gobCollapseMarginM"))
    {
        return GobStatus::Collapse;
    }
    if (m < t.GetF("gobCriticalMarginM"))
    {
        return GobStatus::Critical;
    }
    if (m < t.GetF("gobSafeMarginM"))
    {
        return GobStatus::Uneasy;
    }
    return GobStatus::Safe;
}

void Gob::Settle(const Tuning& t)
{
    // A prop asked for more than it can carry splits, with a bang, and the load it was carrying
    // goes to the nearest support each side — which is how one prop splitting takes the next one
    // with it. A dud goes whatever it is carrying, which is the point of authoring one.
    const float capacity = t.GetF("gobPropCapacityKN");
    for (int32_t pass = 0; pass <= segments_; ++pass)   // literal: one pass per segment bounds a cascade all the way round
    {
        Distribute();
        bool broke = false;
        for (Prop& p : props_)
        {
            if (p.split || Bearing(p.seg))
            {
                continue;
            }
            if (p.loadKN > capacity || p.dud)
            {
                p.split = true;
                p.loadKN = 0.0f;
                broke = true;
            }
        }
        if (!broke)
        {
            return;
        }
    }
}

float Gob::PropLoadKN(int32_t index) const noexcept
{
    if (index < 0 || index >= static_cast<int32_t>(props_.size()))
    {
        return 0.0f;
    }
    return props_[static_cast<std::size_t>(index)].loadKN;
}

}  // namespace sj
