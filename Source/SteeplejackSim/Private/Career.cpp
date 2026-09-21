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

int32_t Career::StarsAfter(int32_t extraPoints, const Tuning& t) const noexcept
{
    Career ahead = *this;
    ahead.reputation_ = std::clamp(reputation_ + std::max(extraPoints, 0), 0,
                                   t.GetI("reputation.max"));
    return ahead.Stars(t);
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

bool Career::Stripped(const std::string& levelId) const noexcept
{
    return std::find(stripped_.begin(), stripped_.end(), levelId) != stripped_.end();
}

void Career::MarkStripped(const std::string& levelId)
{
    if (!Stripped(levelId))
    {
        stripped_.push_back(levelId);
    }
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
                          const Tuning& t, float extraBonusGbp)
{
    Settlement s;
    s.firstTime = !Done(levelId);
    s.failed = outcome.catastrophe;
    s.bonusGbp = outcome.bonusGbp + std::max(extraBonusGbp, 0.0f);
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

int32_t Career::Injured(const Tuning& t)
{
    const int32_t delta = Rep(t, "injured");
    reputation_ = std::clamp(reputation_ + delta, 0, t.GetI("reputation.max"));
    return delta;
}

const std::vector<float>& Career::LeftIn(const std::string& levelId) const noexcept
{
    static const std::vector<float> none;
    for (const auto& entry : leftIn_)
    {
        if (entry.first == levelId)
        {
            return entry.second;
        }
    }
    return none;
}

void Career::RememberLeftIn(const std::string& levelId, const std::vector<float>& heights)
{
    for (auto& entry : leftIn_)
    {
        if (entry.first == levelId)
        {
            // Replaced rather than added to: what is in that chimney now is what you left this
            // time, not the sum of every visit. A dog you went back for is a dog that is gone.
            entry.second = heights;
            return;
        }
    }
    leftIn_.emplace_back(levelId, heights);
}

bool Career::BuyEnginePart(float costGbp) noexcept
{
    if (costGbp < 0.0f || costGbp > money_)
    {
        return false;
    }
    money_ -= costGbp;
    ++engineParts_;
    return true;
}

std::string Career::ToJson() const
{
    std::ostringstream out;
    out << "{\n  \"money\": " << money_ << ",\n  \"reputation\": " << reputation_
        << ",\n  \"day\": " << day_ << ",\n  \"engineParts\": " << engineParts_
        << ",\n  \"jobs\": [";
    for (std::size_t i = 0; i < jobs_.size(); ++i)
    {
        const JobRecord& j = jobs_[i];
        out << (i ? ",\n    " : "\n    ") << "{\"id\": \"" << j.id << "\", \"paid\": " << j.paidGbp
            << ", \"error\": " << j.errorDegrees << ", \"failed\": " << (j.failed ? "true" : "false")
            << "}";
    }
    out << (jobs_.empty() ? "" : "\n  ") << "],\n  \"leftIn\": [";
    for (std::size_t i = 0; i < leftIn_.size(); ++i)
    {
        out << (i ? ",\n    " : "\n    ") << "{\"id\": \"" << leftIn_[i].first << "\", \"at\": [";
        for (std::size_t k = 0; k < leftIn_[i].second.size(); ++k)
        {
            out << (k ? ", " : "") << leftIn_[i].second[k];
        }
        out << "]}";
    }
    out << (leftIn_.empty() ? "" : "\n  ") << "],\n  \"stripped\": [";
    for (std::size_t i = 0; i < stripped_.size(); ++i)
    {
        out << (i ? ", " : "") << "\"" << stripped_[i] << "\"";
    }
    out << "]\n}\n";
    return out.str();
}

Career Career::FromJson(const std::string& json, const std::string& origin)
{
    Career c;
    const JsonValue doc = JsonValue::Parse(json, origin);
    c.money_ = static_cast<float>(doc.At("money").AsNumber());
    c.reputation_ = static_cast<int32_t>(doc.At("reputation").AsNumber());
    // Optional, so a tin written before the yard existed still loads — day nought, no engine.
    if (doc.Has("day"))
    {
        c.day_ = static_cast<int32_t>(doc.At("day").AsNumber());
    }
    if (doc.Has("engineParts"))
    {
        c.engineParts_ = static_cast<int32_t>(doc.At("engineParts").AsNumber());
    }
    if (doc.Has("leftIn"))
    {
        for (const JsonValue& e : doc.At("leftIn").Elements())
        {
            std::vector<float> at;
            for (const JsonValue& v : e.At("at").Elements())
            {
                at.push_back(static_cast<float>(v.AsNumber()));
            }
            c.leftIn_.emplace_back(e.At("id").AsString(), at);
        }
    }
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
    if (doc.Has("stripped"))
    {
        for (const JsonValue& s : doc.At("stripped").Elements())
        {
            c.stripped_.push_back(s.AsString());
        }
    }
    return c;
}

}  // namespace sj
