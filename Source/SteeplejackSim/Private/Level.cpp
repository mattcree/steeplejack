// A level, as data — CORE-008. See Level.h.
//
// Validate() mirrors tools/validate_data.py rule for rule and, where it is cheap, message for
// message. The two exist for different moments — the Python one in a pre-commit hook without a
// compiler, this one in the game — and a divergence between them is a bug in whichever is newer.
// tests/unit/test_level.cpp runs both over the same fixtures and compares the counts.

#include "Level.h"

#include "Json.h"

#include <algorithm>
#include <cmath>
#include <fstream>
#include <sstream>

namespace sj {
namespace {

// These mirror the constants at the top of tools/validate_data.py. They are duplicated rather than
// loaded from tuning because they are *rules*, not balance: the Ascent Beat Rule is a design
// commitment (risk R1), not a number a designer turns down on a Friday.
constexpr float kMaxPlainBandMetres = 20.0f;   // literal: Ascent Beat Rule, validate_data.py
constexpr float kQualityTolerance = 0.001f;    // literal: validate_data.py QUALITY_TOLERANCE
constexpr float kContiguityTolerance = 1e-6f;  // literal: validate_data.py band contiguity epsilon
constexpr float kSafeLineHeightMultiple = 1.5f;  // literal: validate_data.py check_felling
constexpr int32_t kBearingWrap = 360;          // literal: degrees in a circle

// The Python validator formats each number to a specific precision, and the messages are meant to
// be diffable between the two implementations by eye. So the precision is matched per message
// rather than chosen once: "{:.1f}" for heights and spans, "{:.4f}" for a quality sum — where four
// places matter, because a distribution that is wrong by 0.002 must not print as 1.0.
std::string Fmt(float v, int places = 1)
{
    std::ostringstream out;
    out.setf(std::ios::fixed);
    out.precision(places);
    out << v;
    return out.str();
}

constexpr int kQualityPlaces = 4;   // literal: matches validate_data.py's "{:.4f}"

float Number(const JsonValue& v, std::string_view key, float fallback = 0.0f)
{
    if (!v.Has(key))
    {
        return fallback;
    }
    const JsonValue& found = v.At(key);
    return (found.Type() == JsonValue::Kind::Number) ? static_cast<float>(found.AsNumber())
                                                     : fallback;
}

std::string Text(const JsonValue& v, std::string_view key)
{
    if (!v.Has(key))
    {
        return {};
    }
    const JsonValue& found = v.At(key);
    return (found.Type() == JsonValue::Kind::String) ? found.AsString() : std::string{};
}

}  // namespace

bool SiteSpec::InCorridor(int32_t bearing) const noexcept
{
    if (!hasCorridor)
    {
        return false;
    }
    // A corridor may wrap through north: 340 -> 20 is a real corridor and `lo <= b <= hi` would
    // reject every bearing in it. Same branch as validate_data.py's in_corridor().
    const int32_t b = ((bearing % kBearingWrap) + kBearingWrap) % kBearingWrap;
    if (corridorFrom <= corridorTo)
    {
        return b >= corridorFrom && b <= corridorTo;
    }
    return b >= corridorFrom || b <= corridorTo;
}

LevelData LevelData::Parse(const std::string& json, const std::string& origin)
{
    const JsonValue doc = JsonValue::Parse(json, origin);

    LevelData level;
    level.origin_ = origin;
    level.id_ = Text(doc, "id");
    level.name_ = Text(doc, "name");
    level.archetype_ = Text(doc, "archetype");
    level.order_ = static_cast<int32_t>(Number(doc, "order"));

    if (doc.Has("structure"))
    {
        const JsonValue& s = doc.At("structure");
        level.structure_.type = Text(s, "type");
        level.structure_.height = Number(s, "height");
        level.structure_.baseRadius = Number(s, "baseRadius");
        level.structure_.topRadius = Number(s, "topRadius");
        level.structure_.profile = Text(s, "profile");
        level.structure_.cap = Text(s, "cap");
        level.structure_.leanDegrees = Number(s, "leanDegrees");
        level.structure_.leanBearing = static_cast<int32_t>(Number(s, "leanBearing"));
        if (s.Has("jointGrid"))
        {
            const JsonValue& g = s.At("jointGrid");
            level.structure_.courseHeight = Number(g, "courseHeight");
            level.structure_.brickLength = Number(g, "brickLength");
            level.structure_.candidateDensity = Number(g, "candidateDensity");
        }
        if (s.Has("weathering"))
        {
            level.structure_.weatherSeed =
                static_cast<uint64_t>(Number(s.At("weathering"), "seed"));
        }
    }

    if (doc.Has("bands"))
    {
        for (const JsonValue& b : doc.At("bands").Elements())
        {
            BandSpec band;
            band.from = Number(b, "from");
            band.to = Number(b, "to");
            band.type = Text(b, "type");
            if (b.Has("quality"))
            {
                const JsonValue& q = b.At("quality");
                band.sound = Number(q, "sound");
                band.fair = Number(q, "fair");
                band.perished = Number(q, "perished");
                band.cracked = Number(q, "cracked");
            }
            level.bands_.push_back(std::move(band));
        }
    }

    if (doc.Has("site"))
    {
        const JsonValue& s = doc.At("site");
        level.site_.safeLineDistance = Number(s, "safeLineDistance");
        if (s.Has("corridor") && s.At("corridor").Type() == JsonValue::Kind::Object)
        {
            level.site_.hasCorridor = true;
            level.site_.corridorFrom = static_cast<int32_t>(Number(s.At("corridor"), "fromBearing"));
            level.site_.corridorTo = static_cast<int32_t>(Number(s.At("corridor"), "toBearing"));
        }
        if (s.Has("exclusions") && s.At("exclusions").Type() == JsonValue::Kind::Array)
        {
            for (const JsonValue& e : s.At("exclusions").Elements())
            {
                ExclusionSpec ex;
                ex.id = Text(e, "id");
                ex.bearing = static_cast<int32_t>(Number(e, "bearing"));
                ex.distance = static_cast<int32_t>(Number(e, "distance"));
                level.site_.exclusions.push_back(std::move(ex));
            }
        }
    }

    return level;
}

LevelData LevelData::LoadFrom(const std::string& path)
{
    std::ifstream in(path, std::ios::binary);
    if (!in)
    {
        throw JsonError(path, 0, "cannot read level file");
    }
    std::ostringstream buf;
    buf << in.rdbuf();

    // The origin is the bare filename, matching how validate_data.py labels its errors, so the two
    // implementations' messages can be diffed directly.
    const std::size_t slash = path.find_last_of("/\\");
    const std::string name = (slash == std::string::npos) ? path : path.substr(slash + 1);
    return Parse(buf.str(), name);
}

const BandSpec& LevelData::BandAt(float height) const
{
    for (const BandSpec& band : bands_)
    {
        if (band.Contains(height))
        {
            return band;
        }
    }
    // The top of the structure belongs to the top band, which a half-open range would exclude.
    if (!bands_.empty() && std::abs(height - bands_.back().to) <= kContiguityTolerance)
    {
        return bands_.back();
    }
    throw JsonError(origin_, 0,
                    "no band covers height " + Fmt(height) + "m (structure is " +
                    Fmt(structure_.height) + "m)");
}

std::vector<std::string> LevelData::Validate() const
{
    std::vector<std::string> errors;
    const auto err = [&errors, this](const std::string& message)
    {
        errors.push_back(origin_ + ": " + message);
    };

    // --- bands: contiguity, extent, quality sums, and the Ascent Beat Rule -------------------
    float cursor = 0.0f;
    for (std::size_t i = 0; i < bands_.size(); ++i)
    {
        const BandSpec& b = bands_[i];
        const std::string what = "band " + std::to_string(i) + " (" + b.type + ")";

        if (std::abs(b.from - cursor) > kContiguityTolerance)
        {
            err(what + " starts at " + Fmt(b.from) + "m, expected " + Fmt(cursor) +
                "m — bands must be contiguous");
        }
        if (b.to <= b.from)
        {
            err(what + " has non-positive extent");
        }
        cursor = b.to;

        const float total = b.sound + b.fair + b.perished + b.cracked;
        if (std::abs(total - 1.0f) > kQualityTolerance)
        {
            err(what + " quality sums to " + Fmt(total, kQualityPlaces) + ", must be 1.0");
        }

        // The Ascent Beat Rule: no stretch of featureless brickwork long enough to become a
        // corridor. It exists to defend against risk R1 — that climbing is boring.
        if (b.type == "plain" && b.Span() > kMaxPlainBandMetres)
        {
            err(what + " is 'plain' and " + Fmt(b.Span()) + "m long — Ascent Beat Rule allows " +
                Fmt(kMaxPlainBandMetres) + "m max. Split it or give it a character.");
        }
    }
    if (!bands_.empty() && std::abs(cursor - structure_.height) > kContiguityTolerance)
    {
        err("bands cover 0–" + Fmt(cursor) + "m but the structure is " + Fmt(structure_.height) +
            "m tall");
    }

    // --- the fall corridor --------------------------------------------------------------------
    if (!site_.hasCorridor)
    {
        if (archetype_ == "FELL")
        {
            err("FELL level has no site.corridor");
        }
    }
    else
    {
        for (const ExclusionSpec& ex : site_.exclusions)
        {
            if (site_.InCorridor(ex.bearing))
            {
                err("exclusion '" + ex.id + "' at bearing " + std::to_string(ex.bearing) +
                    "° sits inside the fall corridor " + std::to_string(site_.corridorFrom) + "–" +
                    std::to_string(site_.corridorTo) + "° — this level is unwinnable");
            }
        }

        if (archetype_ == "FELL")
        {
            const float required = structure_.height * kSafeLineHeightMultiple;
            if (site_.safeLineDistance < required)
            {
                err("safeLineDistance " + Fmt(site_.safeLineDistance) +
                    "m is under 1.5x height (" + Fmt(required) + "m)");
            }
        }
    }

    return errors;
}

}  // namespace sj
