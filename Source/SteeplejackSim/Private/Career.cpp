// What you have made and what you are trusted with — CAREER-001. See Career.h.

#include "Career.h"

#include "Fell.h"
#include "Json.h"
#include "Tuning.h"

#include <algorithm>
#include <sstream>

namespace sj {
namespace {

constexpr float kNoMoney = 0.0f;   // literal: a job cannot leave you owing

int32_t Rep(const Tuning& t, const char* key)
{
    return t.GetI(std::string("reputation.") + key);
}

}  // namespace

int32_t Career::Stars(const Tuning& t) const noexcept
{
    int32_t stars = 0;
    for (int32_t i = 0; i < 5; ++i)   // literal: five stars, as the board draws them
    {
        const std::string key = "reputation.starThresholds." + std::to_string(i);
        if (!t.Has(key))
        {
            break;
        }
        if (reputation_ >= t.GetI(key))
        {
            stars = i + 1;
        }
    }
    return stars;
}

bool Career::CanTake(int32_t gateStars, const Tuning& t) const noexcept
{
    return Stars(t) >= gateStars;
}

bool Career::Done(const std::string& levelId) const noexcept
{
    for (const JobRecord& j : jobs_)
    {
        if (j.id == levelId && !j.failed)
        {
            return true;
        }
    }
    return false;
}

float Career::BestErrorDegrees(const std::string& levelId) const noexcept
{
    float best = -1.0f;
    for (const JobRecord& j : jobs_)
    {
        if (j.id == levelId && !j.failed && (best < 0.0f || j.errorDegrees < best))
        {
            best = j.errorDegrees;
        }
    }
    return best;
}

Settlement Career::Settle(const std::string& levelId, float feeGbp, const FellOutcome& outcome,
                          const Tuning& t)
{
    Settlement s;
    s.firstTime = !Done(levelId);
    s.failed = outcome.catastrophe;
    s.bonusGbp = outcome.bonusGbp;
    s.damagesGbp = outcome.penaltyGbp;
    s.feeGbp = s.firstTime ? feeGbp : feeGbp * t.GetF("replayFeeFraction");

    if (s.failed)
    {
        // No fee for a job that ended with a chapel in the road. The reputation still moves, and
        // it moves whether or not this is the first time: that is the asymmetry.
        s.feeGbp = kNoMoney;
        s.paidGbp = kNoMoney;
        s.reputationDelta = Rep(t, "catastrophicCollateral");
    }
    else
    {
        s.paidGbp = std::max(s.feeGbp + s.bonusGbp - s.damagesGbp, kNoMoney);
        if (s.firstTime)
        {
            s.reputationDelta += (outcome.grade == FellGrade::Perfect) ? Rep(t, "jobPerfect")
                                                                      : Rep(t, "jobCompleted");
        }
        // Losses are not first-time only. Breaking somebody's greenhouse costs you every time.
        if (outcome.grade == FellGrade::Wild)
        {
            s.reputationDelta += Rep(t, "wildFell");
        }
        if (s.damagesGbp > 0.0f)
        {
            s.reputationDelta += Rep(t, "damageMinor");
        }
    }

    money_ += s.paidGbp;
    reputation_ = std::clamp(reputation_ + s.reputationDelta, 0, t.GetI("reputation.max"));
    jobs_.push_back(JobRecord{levelId, s.paidGbp, outcome.errorDegrees, s.failed});
    return s;
}

Settlement Career::SettleClimb(const std::string& levelId, float feeGbp, bool reachedTop,
                               const Tuning& t)
{
    Settlement s;
    s.firstTime = !Done(levelId);
    s.failed = !reachedTop;
    s.feeGbp = s.firstTime ? feeGbp : feeGbp * t.GetF("replayFeeFraction");

    if (s.failed)
    {
        s.feeGbp = kNoMoney;
        s.paidGbp = kNoMoney;
        s.reputationDelta = Rep(t, "abandoned");
    }
    else
    {
        s.paidGbp = std::max(s.feeGbp, kNoMoney);
        if (s.firstTime)
        {
            s.reputationDelta = Rep(t, "jobCompleted");
        }
    }

    money_ += s.paidGbp;
    reputation_ = std::clamp(reputation_ + s.reputationDelta, 0, t.GetI("reputation.max"));
    jobs_.push_back(JobRecord{levelId, s.paidGbp, 0.0f, s.failed});
    return s;
}

std::string Career::ToJson() const
{
    std::ostringstream out;
    out << "{\n  \"money\": " << money_ << ",\n  \"reputation\": " << reputation_
        << ",\n  \"jobs\": [";
    for (std::size_t i = 0; i < jobs_.size(); ++i)
    {
        const JobRecord& j = jobs_[i];
        out << (i ? ",\n    " : "\n    ") << "{\"id\": \"" << j.id << "\", \"paid\": " << j.paidGbp
            << ", \"error\": " << j.errorDegrees << ", \"failed\": " << (j.failed ? "true" : "false")
            << "}";
    }
    out << (jobs_.empty() ? "" : "\n  ") << "]\n}\n";
    return out.str();
}

Career Career::FromJson(const std::string& json, const std::string& origin)
{
    Career c;
    const JsonValue doc = JsonValue::Parse(json, origin);
    c.money_ = static_cast<float>(doc.At("money").AsNumber());
    c.reputation_ = static_cast<int32_t>(doc.At("reputation").AsNumber());
    if (doc.Has("jobs"))
    {
        for (const JsonValue& j : doc.At("jobs").Elements())
        {
            c.jobs_.push_back(JobRecord{
                j.At("id").AsString(),
                static_cast<float>(j.At("paid").AsNumber()),
                static_cast<float>(j.At("error").AsNumber()),
                j.At("failed").AsBool(),
            });
        }
    }
    return c;
}

}  // namespace sj
