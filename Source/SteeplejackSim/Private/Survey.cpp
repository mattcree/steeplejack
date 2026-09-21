#include "Survey.h"

#include "Tuning.h"

#include <algorithm>
#include <cmath>

namespace sj {

namespace {

constexpr float kFullTurn = 360.0f;   // literal: degrees in a turn
constexpr float kHalfTurn = 180.0f;   // literal: degrees in a half turn

// How far apart two bearings are, the short way round.
float BearingGap(int32_t a, int32_t b)
{
    float d = std::fabs(static_cast<float>(a - b));
    d = std::fmod(d, kFullTurn);
    return (d > kHalfTurn) ? kFullTurn - d : d;
}

}  // namespace

FindBy FindByName(const std::string& name) noexcept
{
    if (name == "tap")      { return FindBy::Tap; }
    if (name == "summit")   { return FindBy::Summit; }
    if (name == "traverse") { return FindBy::Traverse; }
    return FindBy::Visual;
}

void Survey::Begin(const std::vector<Defect>& defects)
{
    defects_ = defects;
    for (Defect& d : defects_)
    {
        d.found = false;
    }
}

int32_t Survey::Look(float height, int32_t bearing, bool atTop, bool sounded, const Tuning& t)
{
    for (std::size_t i = 0; i < defects_.size(); ++i)
    {
        Defect& d = defects_[i];
        if (d.found)
        {
            continue;
        }
        const float up = std::fabs(d.height - height);
        const float round_ = BearingGap(d.bearing, bearing);
        bool got = false;
        switch (d.how)
        {
            case FindBy::Visual:
                // Close enough to see it, and on the right side of her.
                got = up <= t.GetF("surveyVisualRangeMetres")
                      && round_ <= t.GetF("surveyTraverseBearingDeg");
                break;
            case FindBy::Tap:
                // The note tells you and the eye cannot. Standing next to it is not finding it.
                got = sounded && up <= t.GetF("surveyTapRangeMetres")
                      && round_ <= t.GetF("surveyTraverseBearingDeg");
                break;
            case FindBy::Summit:
                // Only from the cap, which is what makes the climb the job rather than the trip.
                got = atTop && up <= t.GetF("surveySummitRangeMetres");
                break;
            case FindBy::Traverse:
                // Off your line. A climber cannot get round a chimney — shuffle too far and you
                // step off the ladder — so "traverse" cannot mean the far side and be findable.
                // It means you have to work yourself sideways along the face to see it, which is
                // a real and uncomfortable thing to do, and the window is deliberately tighter
                // than the others so that standing on your line does not find it by accident.
                got = up <= t.GetF("surveyVisualRangeMetres")
                      && round_ <= t.GetF("surveyTraverseWindowDeg");
                break;
        }
        if (got)
        {
            d.found = true;
            return static_cast<int32_t>(i);
        }
    }
    return -1;
}

SurveyReport Survey::Report() const noexcept
{
    SurveyReport r{};
    r.total = static_cast<int32_t>(defects_.size());
    for (const Defect& d : defects_)
    {
        if (d.found)
        {
            ++r.found;
        }
    }
    r.share = (r.total > 0) ? static_cast<float>(r.found) / static_cast<float>(r.total) : 1.0f;
    r.complete = r.total > 0 && r.found == r.total;
    return r;
}

}  // namespace sj
