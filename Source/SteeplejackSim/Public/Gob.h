#pragma once

// The gob — the hole you cut in the base of a chimney to fell it. FELL-001.
//
// You do not blow a chimney up. You cut a hole in one side at the bottom, replacing the brick you
// take out with timber props as you go, until it stands on a crescent of brick at the back and a
// row of wooden legs at the front. Then you pack the hole with waste timber, light it, and walk
// away: the props burn through and it hinges over the crescent (Fell.h).
//
// ## The model
//
// A ring of `segments` × `courses` cells at the base — the level authors 32 × 4, so 11.25° apiece.
// Each cell carries load until it is removed. A prop stands at a segment and carries load too,
// up to `gobPropCapacityKN`, and splits with a bang if it is asked for more.
//
// ## Why a 40 kN prop is any use under a thousand tons
//
// Waterside weighs about 9,400 kN. A segment of thirty-two is 294 kN of that, and fourteen props
// at 40 kN come to 560 kN between them, so if a prop really had to carry the column above it the
// whole thing would be impossible. It does not: **brickwork arches over the hole**. Load above an
// opening goes round it to the sides, and what is left for the prop is the wall directly above it
// up to the height the arch forms — `gobArchHeightM`, about five metres of it, 22 kN at Waterside.
//
// That is what makes the design's loop — "cut two cells, set a prop, cut two cells" — a rule
// rather than advice. One unpropped hole beside a prop sheds half its share onto it and takes it
// to 33 kN, which it survives. Two, and it is at 44 and it splits. You may run one segment ahead
// of your props. You may not run two.
//
// ## The rule the player is fighting
//
// It stands while the centre of gravity is inside the support polygon — the intact cells and the
// props — with a margin. The margin is the distance from the centre of gravity to the nearest edge
// of that polygon, and it is the whole game of Act 3: cut too much on one side and it goes early,
// with you in the hole. The bands (safe, uneasy, critical) come from tuning, and the design wants
// the player to *finish* in the uneasy band, because a chimney that feels safe will not fall.
//
// The chimney's weight sits off the axis to begin with, because chimneys are never plumb: a lean of
// θ over a height H puts the centre of gravity H/2·tan θ off centre, along the lean's bearing. That
// is why the lean decides which way it wants to go, and why fighting it costs accuracy.

#include "Export.h"
#include "Types.h"

#include <cstdint>
#include <vector>

namespace sj {

class Tuning;

// Where a cell sits and what has happened to it. `strength` is the mortar, 0-1, authored
// asymmetric on purpose: one side of the ring is tougher to cut than the other.
struct GobCell
{
    int16_t seg{}, course{};
    bool    removed{}, propped{};
    float   strength{1.0f};
};

// A timber prop standing in the hole, holding up what the brick used to.
struct Prop
{
    int16_t seg{-1};
    float   loadKN{};
    bool    split{};
    bool    dud{};      // authored to fail: levels may plant one
};

enum class GobStatus : uint8_t { Safe, Uneasy, Critical, Collapse };

// What the base looks like and what it is doing. All the geometry is in metres and bearings in
// degrees clockwise from north, as everywhere else in the project.
class SJ_API Gob
{
public:
    // `weightKN` is what the chimney above the gob weighs; `leanDeg`/`leanBearingDeg` is how it
    // already stands. `dudProp` is the index of a prop that will split under any real load, or -1.
    Gob(int32_t segments, int32_t courses, float baseRadius, float heightM, float weightKN,
        float leanDeg, float leanBearingDeg, int32_t props, int32_t dudProp, const Tuning& t);

    // What the shaft above a gob weighs, from the wall it is made of. Here rather than in the
    // caller because a test fixture and the running game guessing separately at the weight of a
    // chimney is two answers to one question, and the whole prop model hangs off this number.
    static float ShaftWeightKN(float baseRadius, float topRadius, float heightM, const Tuning& t);

    int32_t Segments() const noexcept { return segments_; }
    int32_t Courses() const noexcept { return courses_; }
    float   BaseRadius() const noexcept { return radius_; }
    float   SegmentBearing(int32_t seg) const noexcept;

    const GobCell& At(int32_t seg, int32_t course) const noexcept;
    const std::vector<Prop>& Props() const noexcept { return props_; }
    int32_t PropsLeft() const noexcept;

    // Authoring: one side of the ring tougher than the other. `bias` 0-1 is taken off the strength
    // at `bearingDeg` and added opposite it.
    void SetMortarAsymmetry(float bearingDeg, float bias) noexcept;

    // Cut a cell out. False if there is nothing there to cut.
    bool Cut(int32_t seg, int32_t course);
    // Stand a prop at a segment. False with no props left, or if nothing has been cut there yet:
    // props go in behind you as you cut, which is the loop the design asks for.
    bool SetProp(int32_t seg);

    // How much of the ring has been cut, as an arc in degrees, and where its middle is.
    float CutArcDegrees() const noexcept;
    float CutCentreBearing() const noexcept;

    // The statics. `Margin` is metres from the centre of gravity to the nearest edge of the
    // support polygon; negative means the polygon no longer contains it, which is a collapse.
    //
    // A prop is not worth a brick here. Brickwork bears on the full thickness of the wall and its
    // mortar takes a little tension, so it resists the chimney *tipping over it*; a timber prop
    // bears on a point and only in compression. It holds the weight up and does almost nothing
    // against the topple. So a prop contributes a support point drawn in towards the middle —
    // `gobPropLeverFrac` of the base radius when it is carrying nothing, and nothing at all when it
    // is at capacity. That is what makes the cut arc, not the prop count, decide whether it stands,
    // and it is why the design's margin bands are the chord of the bare crescent: cut 160° of a
    // 3.2 m ring and the margin is 0.56 m, which is the middle of UNEASY, which is where a felling
    // is supposed to finish.
    Vec2 CentreOfGravity() const noexcept;
    Vec2 SupportCentroid() const noexcept;
    // The polygon itself, counter-clockwise, so the HUD can draw the thing the margin is measured
    // against rather than a drawing of its own that agrees with it by luck.
    std::vector<Vec2> SupportHull() const;
    float Margin() const noexcept;
    GobStatus Status(const Tuning& t) const noexcept;

    // Run the split cascade: a prop asked for more than `gobPropCapacityKN` splits, its load sheds
    // to the nearest support each side, and that is how one prop splitting takes the next with it.
    // Loads themselves are always current — cutting and propping redistribute as you go.
    void Settle(const Tuning& t);
    float PropLoadKN(int32_t index) const noexcept;
    // What one segment of the ring is carrying, in kN. Weight is shared round the ring by the
    // standard no-tension rule for an eccentric load — the side it leans towards carries more —
    // and a segment with nothing under it sheds onto its neighbours.
    float SegmentLoadKN(int32_t seg) const noexcept;

private:
    bool  Bearing(int32_t seg) const noexcept;
    Prop* PropAt(int32_t seg) noexcept;
    const Prop* PropAt(int32_t seg) const noexcept;
    void  Distribute() noexcept;
    Vec2  CellPoint(int32_t seg) const noexcept;
    std::vector<Vec2> SupportPoints() const;

    int32_t segments_{}, courses_{};
    float   radius_{}, height_{}, weightKN_{};
    float   leanDeg_{}, leanBearingDeg_{};
    int32_t propBudget_{}, dudProp_{-1};
    float   capacityKN_{}, propLever_{}, archHeight_{};
    std::vector<GobCell> cells_;
    std::vector<Prop>    props_;
    std::vector<float>   segLoad_;
};

}  // namespace sj
