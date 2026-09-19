// The checkpoint — CLIMB-006. See the save:: block at the end of Stack.h.
//
//     {"version":1,"level":"00-greybox","levelFile":"9f2c…",
//      "anchors":[[joint,height,depth,spall,rate,capacityKN,loadKN,free,failed], …],
//      "sections":[[lower,upper,span,condition,buckleTimer,lashing,failed,driftCm], …]}
//
// Positional arrays rather than objects: a 28-section stack is a few kilobytes instead of a few
// dozen, and the field order is fixed by the version number. Floats are written shortest-round-
// trip and checked, as the replay format does, so a restored stack is the same stack to the bit —
// a 0.1 kN difference in a Poor dog's capacity is a different fall.

#include "Stack.h"

#include "Json.h"

#include <charconv>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <string>
#include <utility>
#include <vector>

namespace sj::save {
namespace {

constexpr int32_t kVersion = 1;

enum AnchorField : std::size_t { kJoint, kHeight, kDepth, kSpall, kRate, kCapacity, kLoad, kFree,
                                 kAnchorFailed, kAnchorFields };
enum SectionField : std::size_t { kLower, kUpper, kSpan, kCondition, kBuckle, kLashing,
                                  kSectionFailed, kDrift, kSectionFields };

void AppendFloat(std::string& out, float v)
{
    char buf[32];   // literal: longer than any float or double spelling
    auto r = std::to_chars(buf, buf + sizeof(buf), v);
    double back = 0.0;
    std::from_chars(buf, r.ptr, back);
    if (static_cast<float>(back) != v || std::signbit(static_cast<float>(back)) != std::signbit(v))
    {
        r = std::to_chars(buf, buf + sizeof(buf), static_cast<double>(v));
    }
    out.append(buf, r.ptr);
}

void AppendString(std::string& out, const std::string& s)
{
    out += '"';
    for (char c : s)
    {
        if (c == '"' || c == '\\')
        {
            out += '\\';
        }
        out += c;
    }
    out += '"';
}

int32_t Int(const JsonValue& v, const char* what)
{
    const double d = v.AsNumber();
    if (std::floor(d) != d)
    {
        throw SaveError(std::string("checkpoint: ") + what + " is not a whole number");
    }
    return static_cast<int32_t>(d);
}

float Float(const JsonValue& v) { return static_cast<float>(v.AsNumber()); }

bool Flag(const JsonValue& v, const char* what)
{
    const int32_t i = Int(v, what);
    if (i != 0 && i != 1)
    {
        throw SaveError(std::string("checkpoint: ") + what + " must be 0 or 1");
    }
    return i == 1;
}

}  // namespace

std::string LevelFingerprint(const std::string& levelFileText)
{
    // FNV-1a, 64-bit. Not cryptographic and does not need to be: it answers "is this the file the
    // checkpoint was built on", and a collision needs someone to be trying.
    uint64_t h = 14695981039346656037ULL;   // literal: the FNV-1a 64-bit offset basis
    for (unsigned char c : levelFileText)
    {
        h ^= c;
        h *= 1099511628211ULL;               // literal: the FNV-1a 64-bit prime
    }
    char buf[20];                            // literal: sixteen hex digits and room over
    const auto r = std::to_chars(buf, buf + sizeof(buf), h, 16);
    return std::string(buf, r.ptr);
}

std::string SerialiseStack(const Stack& stack, const std::string& levelId,
                           const std::string& levelFingerprint)
{
    std::string out = "{\"version\":" + std::to_string(kVersion) + ",\"level\":";
    AppendString(out, levelId);
    out += ",\"levelFile\":";
    AppendString(out, levelFingerprint);

    out += ",\"anchors\":[";
    for (int32_t i = 0; i < stack.AnchorCount(); ++i)
    {
        const Anchor& a = stack.AnchorAt(i);
        out += (i == 0) ? "[" : ",[";
        out += std::to_string(a.jointId) + ',';
        AppendFloat(out, a.height);     out += ',';
        AppendFloat(out, a.depth);      out += ',';
        AppendFloat(out, a.spall);      out += ',';
        out += std::to_string(static_cast<int32_t>(a.rate)) + ',';
        AppendFloat(out, a.capacityKN); out += ',';
        AppendFloat(out, a.loadKN);     out += ',';
        out += a.freeFixture ? "1," : "0,";
        out += stack.AnchorFailed(i) ? "1]" : "0]";
    }

    out += "],\"sections\":[";
    for (int32_t i = 0; i < stack.SectionCount(); ++i)
    {
        const Section& s = stack.SectionAt(i);
        out += (i == 0) ? "[" : ",[";
        out += std::to_string(s.lowerAnchor) + ',' + std::to_string(s.upperAnchor) + ',';
        AppendFloat(out, s.span);        out += ',';
        AppendFloat(out, s.condition);   out += ',';
        AppendFloat(out, s.buckleTimer); out += ',';
        out += std::to_string(static_cast<int32_t>(s.lashing)) + ',';
        out += stack.SectionFailed(i) ? "1," : "0,";
        AppendFloat(out, stack.SectionDriftCm(i));
        out += ']';
    }
    out += "]}";
    return out;
}

Stack RestoreStack(const std::string& json, const std::string& levelId,
                   const std::string& levelFingerprint)
{
    const JsonValue doc = JsonValue::Parse(json, "checkpoint");
    const int32_t version = Int(doc.At("version"), "version");
    if (version != kVersion)
    {
        throw SaveError("checkpoint: version " + std::to_string(version) +
                        " is not one this build can read (it reads version " +
                        std::to_string(kVersion) + ")");
    }
    if (doc.At("level").AsString() != levelId)
    {
        throw SaveError("checkpoint: this stack was built on " + doc.At("level").AsString() +
                        ", not " + levelId);
    }
    if (doc.At("levelFile").AsString() != levelFingerprint)
    {
        throw SaveError("checkpoint: the level file for " + levelId + " has changed since this "
                        "stack was built (" + doc.At("levelFile").AsString() + ", now " +
                        levelFingerprint + ") — its dogs may no longer be in joints that exist");
    }

    std::vector<Anchor> anchors;
    std::vector<bool> anchorFailed;
    for (const JsonValue& row : doc.At("anchors").Elements())
    {
        if (row.Size() != kAnchorFields)
        {
            throw SaveError("checkpoint: an anchor needs " + std::to_string(kAnchorFields) +
                            " fields, this one has " + std::to_string(row.Size()));
        }
        Anchor a;
        a.jointId = Int(row.At(kJoint), "joint");
        a.height = Float(row.At(kHeight));
        a.depth = Float(row.At(kDepth));
        a.spall = Float(row.At(kSpall));
        const int32_t rate = Int(row.At(kRate), "rate");
        if (rate < 0 || rate > static_cast<int32_t>(AnchorRate::Sound))
        {
            throw SaveError("checkpoint: anchor rate " + std::to_string(rate) + " is unknown");
        }
        a.rate = static_cast<AnchorRate>(rate);
        a.capacityKN = Float(row.At(kCapacity));
        a.loadKN = Float(row.At(kLoad));
        a.freeFixture = Flag(row.At(kFree), "free");
        anchors.push_back(a);
        anchorFailed.push_back(Flag(row.At(kAnchorFailed), "failed"));
    }
    if (anchors.empty() || anchors.front().jointId != -1)
    {
        throw SaveError("checkpoint: anchor 0 must be the ground");
    }

    std::vector<Section> sections;
    std::vector<bool> sectionFailed;
    std::vector<float> drift;
    const auto anchorCount = static_cast<int32_t>(anchors.size());
    for (const JsonValue& row : doc.At("sections").Elements())
    {
        if (row.Size() != kSectionFields)
        {
            throw SaveError("checkpoint: a section needs " + std::to_string(kSectionFields) +
                            " fields, this one has " + std::to_string(row.Size()));
        }
        Section s;
        s.lowerAnchor = Int(row.At(kLower), "lower");
        s.upperAnchor = Int(row.At(kUpper), "upper");
        if (s.lowerAnchor < 0 || s.lowerAnchor >= anchorCount ||
            s.upperAnchor < 0 || s.upperAnchor >= anchorCount)
        {
            throw SaveError("checkpoint: a section is lashed to an anchor that is not in the stack");
        }
        s.span = Float(row.At(kSpan));
        s.condition = Float(row.At(kCondition));
        s.buckleTimer = Float(row.At(kBuckle));
        const int32_t lashing = Int(row.At(kLashing), "lashing");
        if (lashing < 0 || lashing > static_cast<int32_t>(Lashing::Full))
        {
            throw SaveError("checkpoint: lashing " + std::to_string(lashing) + " is unknown");
        }
        s.lashing = static_cast<Lashing>(lashing);
        sections.push_back(s);
        sectionFailed.push_back(Flag(row.At(kSectionFailed), "failed"));
        drift.push_back(Float(row.At(kDrift)));
    }

    return Stack::Restore(std::move(anchors), std::move(anchorFailed), std::move(sections),
                          std::move(sectionFailed), std::move(drift));
}

}  // namespace sj::save
