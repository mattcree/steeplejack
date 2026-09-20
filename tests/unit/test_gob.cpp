// The gob — FELL-001, the statics a felling is played against.
//
// docs/01-gdd/06-felling-system.md: "It stands as long as the centre of gravity stays inside the
// support polygon formed by the remaining bearing cells plus the props, with a safety margin."
// These are that sentence, as arithmetic, plus the things the design says must be true of it: the
// lean decides which way it wants to go, props buy back what the brick gave up, and a chimney that
// still feels safe is one that will not fall.

#include "doctest.h"

#include "Gob.h"
#include "Tuning.h"

#include <cmath>
#include <filesystem>
#include <string>

using sj::Gob;
using sj::GobStatus;
using sj::Tuning;

namespace {

std::string TuningDir()
{
    namespace fs = std::filesystem;
    fs::path here = fs::current_path();
    for (int up = 0; up < 5; ++up)
    {
        if (fs::is_directory(here / "data" / "tuning"))
        {
            return (here / "data" / "tuning").string();
        }
        if (!here.has_parent_path())
        {
            break;
        }
        here = here.parent_path();
    }
    return {};
}

const Tuning& Tune()
{
    static const Tuning t = Tuning::LoadAll(TuningDir());
    return t;
}

// The Waterside chimney: 70 m, 3.2 m at the base, 32 segments of 4 courses, 14 props.
Gob Waterside(float leanDeg = 0.3f, float leanBearing = 284.0f, int32_t dud = -1)
{
    return Gob(32, 4, 3.2f, 70.0f, 900.0f, leanDeg, leanBearing, 14, dud, Tune());
}

// Cut an arc of `degrees` centred on a bearing, all courses through.
void CutArc(Gob& g, float centreDeg, float degrees)
{
    for (int32_t s = 0; s < g.Segments(); ++s)
    {
        float d = std::fabs(g.SegmentBearing(s) - centreDeg);
        d = (d > 180.0f) ? 360.0f - d : d;
        if (d <= degrees * 0.5f)
        {
            for (int32_t c = 0; c < g.Courses(); ++c)
            {
                g.Cut(s, c);
            }
        }
    }
}

constexpr float kSegmentDeg = 360.0f / 32.0f;

}  // namespace

TEST_CASE("Gob: an uncut ring is safe, and the lean is where the weight already sits")
{
    Gob g = Waterside();
    CHECK(g.Status(Tune()) == GobStatus::Safe);
    CHECK(g.Margin() > Tune().GetF("gobSafeMarginM"));

    // 0.3 degrees over 70 m is 18 cm off the axis, towards the lean's bearing.
    const sj::Vec2 cog = g.CentreOfGravity();
    CHECK(std::sqrt(cog.x * cog.x + cog.y * cog.y) == doctest::Approx(0.183f).epsilon(0.05));
    const float bearing = std::atan2(cog.x, cog.y) * 57.29578f;
    CHECK(((bearing < 0.0f) ? bearing + 360.0f : bearing) == doctest::Approx(284.0f).epsilon(0.01));
}

TEST_CASE("Gob: cutting into the side eats the margin, and cutting far enough drops it")
{
    Gob g = Waterside();
    const float start = g.Margin();
    float last = start;
    for (float arc : {40.0f, 80.0f, 120.0f, 160.0f})
    {
        CutArc(g, 284.0f, arc);   // the fall line: the way it already leans, which is the way it wants to go
        const float now = g.Margin();
        CAPTURE(arc);
        CHECK(now <= last + 0.001f);   // never improves by cutting
        last = now;
    }
    CHECK(last < start);
    CHECK(g.CutArcDegrees() >= 160.0f - kSegmentDeg);   // whole segments; 160 deg lands on 14 of 32
    CHECK(g.CutCentreBearing() == doctest::Approx(284.0f).epsilon(0.05));
}

TEST_CASE("Gob: props are what let you take out more brick than the brick would allow")
{
    // "Props are the reason you can remove far more brick than statics alone would allow."
    // Eighteen segments of thirty-two - 200 degrees - is well past what a crescent can hold: the
    // chord runs outside the middle and there is nothing under the weight. With a prop in every
    // hole it stands. This wants more props than Waterside authors, which is the point: the prop
    // count is how a level sets how far you are allowed to go.
    const int32_t kDeep = 18;
    Gob bare(32, 4, 3.2f, 70.0f, 900.0f, 0.3f, 284.0f, 0, -1, Tune());
    Gob propped(32, 4, 3.2f, 70.0f, 900.0f, 0.3f, 284.0f, kDeep, -1, Tune());
    for (Gob* g : {&bare, &propped})
    {
        for (int32_t i = 0; i < kDeep; ++i)
        {
            const int32_t s = (19 + i) % 32;
            for (int32_t c = 0; c < g->Courses(); ++c)
            {
                g->Cut(s, c);
            }
            g->SetProp(s);
        }
        g->Settle(Tune());
    }
    CHECK(bare.Status(Tune()) == GobStatus::Collapse);
    CHECK(bare.Margin() < 0.0f);
    CHECK(propped.Margin() > bare.Margin());
    CHECK(propped.Status(Tune()) != GobStatus::Collapse);
}

TEST_CASE("Gob: inside the prop budget it is the cut arc that decides, not the props")
{
    // Worth knowing, and it surprised me: Waterside authors 14 props and a 14-segment cut is 160
    // degrees, so a correctly worked gob props every hole it makes and the props still do not move
    // the margin - each is carrying about 30 kN of its 40 kN, which leaves it a shorter lever than
    // the crescent already has. Props here buy you the load path and the cascade, not the statics.
    // Going deeper is what props buy, and going deeper is what the budget forbids.
    Gob bare = Waterside();
    CutArc(bare, 284.0f, 160.0f);
    Gob propped = Waterside();
    CutArc(propped, 284.0f, 160.0f);
    int32_t set = 0;
    for (int32_t s = 0; s < propped.Segments(); ++s)
    {
        set += propped.At(s, 0).removed && propped.SetProp(s) ? 1 : 0;
    }
    propped.Settle(Tune());
    CHECK(set == 14);                       // the budget is exactly the arc
    CHECK(propped.PropsLeft() == 0);
    CHECK(propped.PropLoadKN(0) > 0.0f);
    CHECK(propped.PropLoadKN(0) < Tune().GetF("gobPropCapacityKN"));
    CHECK(propped.Margin() == doctest::Approx(bare.Margin()));
}

TEST_CASE("Gob: a prop is worth less than the brick it replaced")
{
    // It holds the weight up; it does very little against the topple. So propping every cell you
    // cut still loses you margin — you cannot prop your way back to an uncut ring.
    Gob g = Waterside();
    const float uncut = g.Margin();
    CutArc(g, 284.0f, 140.0f);
    for (int32_t s = 0; s < g.Segments(); ++s)
    {
        if (g.At(s, 0).removed)
        {
            g.SetProp(s);
        }
    }
    g.Settle(Tune());
    CHECK(g.Margin() < uncut);
}

TEST_CASE("Gob: a prop goes in behind the cut, never in front of it, and one to a segment")
{
    Gob g = Waterside();
    CHECK_FALSE(g.SetProp(0));          // nothing cut there yet
    g.Cut(0, 0);
    CHECK(g.SetProp(0));
    CHECK_FALSE(g.SetProp(0));          // already propped
    CHECK(g.PropsLeft() == 13);
}

TEST_CASE("Gob: the props run out, and that is the budget the level authored")
{
    Gob g = Waterside();
    int32_t set = 0;
    for (int32_t s = 0; s < g.Segments(); ++s)
    {
        g.Cut(s, 0);
        set += g.SetProp(s) ? 1 : 0;
    }
    CHECK(set == 14);
    CHECK(g.PropsLeft() == 0);
}

TEST_CASE("Gob: overloaded props split, and a split one hands its load to the rest")
{
    // Three props under the whole weight: 300 kN each against a 40 kN prop.
    Gob g(32, 4, 3.2f, 70.0f, 900.0f, 0.0f, 0.0f, 14, -1, Tune());
    for (int32_t s = 0; s < g.Segments(); ++s)
    {
        for (int32_t c = 0; c < g.Courses(); ++c)
        {
            g.Cut(s, c);
        }
    }
    for (int32_t s : {0, 8, 16})
    {
        CHECK(g.SetProp(s));
    }
    g.Settle(Tune());
    int32_t split = 0;
    for (const sj::Prop& p : g.Props())
    {
        split += p.split ? 1 : 0;
    }
    CHECK(split == 3);            // every one of them: nothing else is holding the chimney up
    CHECK(g.Margin() < 0.0f);     // and with them gone it is over
}

TEST_CASE("Gob: an authored dud prop splits under any load at all")
{
    Gob g = Waterside(0.3f, 284.0f, 0);   // the first prop set is the dud
    for (int32_t s : {0, 8})              // far enough apart that neither inherits the other's load
    {
        for (int32_t c = 0; c < g.Courses(); ++c)
        {
            g.Cut(s, c);   // right through, so the prop is really carrying the segment
        }
        CHECK(g.SetProp(s));
    }
    CHECK(g.PropLoadKN(0) < Tune().GetF("gobPropCapacityKN"));   // well within a sound prop
    g.Settle(Tune());
    CHECK(g.Props()[0].split);
    CHECK_FALSE(g.Props()[1].split);
}

TEST_CASE("Gob: a prop that splits leans on its neighbours, and can take them with it")
{
    // Every prop in a finished gob is carrying about 28 kN of a 40 kN prop. There is not 28 kN of
    // slack in the one next door, so a prop going means the next one goes: that is the cascade the
    // design wants, and the reason a dud is worth authoring.
    Gob g = Waterside(0.3f, 284.0f, 0);
    for (int32_t s = 0; s < 3; ++s)
    {
        for (int32_t c = 0; c < g.Courses(); ++c)
        {
            g.Cut(s, c);
        }
        CHECK(g.SetProp(s));
    }
    g.Settle(Tune());
    int32_t split = 0;
    for (const sj::Prop& p : g.Props())
    {
        split += p.split ? 1 : 0;
    }
    CHECK(split > 1);   // the dud did not go alone
}

TEST_CASE("Gob: the bands are the design's, and a finished gob sits in uneasy")
{
    // "CoG margin in the UNEASY band (that's correct - a chimney that feels totally safe won't
    // fall)." The bands are the chord of the bare crescent: cut 160 degrees of a 3.2 m ring and
    // the margin is 0.56 m, the middle of UNEASY. Cut the design's arc, prop it, and check.
    Gob g = Waterside();
    CutArc(g, 284.0f, 160.0f);
    for (int32_t s = 0; s < g.Segments(); ++s)
    {
        if (g.At(s, 0).removed)
        {
            g.SetProp(s);
        }
    }
    g.Settle(Tune());
    const float m = g.Margin();
    CAPTURE(m);
    CHECK(g.Status(Tune()) == GobStatus::Uneasy);
    CHECK(m < Tune().GetF("gobSafeMarginM"));
    CHECK(m > Tune().GetF("gobCriticalMarginM"));
}

TEST_CASE("Gob: the bands run the right way as the cut deepens")
{
    GobStatus worst = GobStatus::Safe;
    for (float arc : {60.0f, 120.0f, 150.0f, 170.0f, 190.0f})
    {
        Gob g = Waterside();
        CutArc(g, 284.0f, arc);
        CAPTURE(arc);
        CHECK(static_cast<int>(g.Status(Tune())) >= static_cast<int>(worst));   // never improves
        worst = g.Status(Tune());
    }
    CHECK(worst == GobStatus::Collapse);
}

TEST_CASE("Gob: mortar can be tougher on one side, as a level authors it")
{
    Gob g = Waterside();
    g.SetMortarAsymmetry(200.0f, 0.35f);
    int32_t at200 = 0, at20 = 0;
    for (int32_t s = 0; s < g.Segments(); ++s)
    {
        at200 = (std::fabs(g.SegmentBearing(s) - 200.0f) < 6.0f) ? s : at200;
        at20 = (std::fabs(g.SegmentBearing(s) - 20.0f) < 6.0f) ? s : at20;
    }
    CHECK(g.At(at200, 0).strength < g.At(at20, 0).strength);
}
