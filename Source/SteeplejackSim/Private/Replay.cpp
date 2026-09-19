// Playing a recording back — CORE-006. See Replay.h, and Recorder.cpp for the format.

#include "Replay.h"

#include "Json.h"

#include <cmath>
#include <cstddef>
#include <string>

namespace sj {
namespace {

constexpr int32_t kSlotStride = 32;   // literal: must match Recorder.cpp
constexpr int32_t kFormat = 1;
// Where each field sits in a row; see Recorder.cpp for the format.
enum Field : std::size_t { kTick, kSlotKind, kA, kB, kTarget, kRepeat };
constexpr int32_t kMaxTicks = 60 * 60 * 60 * 4;   // literal: four hours at 60 Hz; past that the file is not a run

int32_t AsInt(const JsonValue& v, const char* what)
{
    const double d = v.AsNumber();
    if (std::floor(d) != d)
    {
        throw ReplayError(std::string("replay: ") + what + " is not a whole number");
    }
    return static_cast<int32_t>(d);
}

}  // namespace

Replay Replay::FromJson(const std::string& text)
{
    const JsonValue doc = JsonValue::Parse(text, "replay");
    if (AsInt(doc.At("format"), "format") != kFormat)
    {
        throw ReplayError("replay: format " + std::to_string(AsInt(doc.At("format"), "format")) +
                          " is not one this build reads (" + std::to_string(kFormat) + ")");
    }

    Replay r;
    r.levelId_ = doc.At("level").AsString();
    r.seed_ = std::stoull(doc.At("seed").AsString());
    r.tuningHash_ = doc.At("tuning").AsString();
    r.length_ = AsInt(doc.At("ticks"), "ticks");
    if (r.length_ < 0 || r.length_ > kMaxTicks)
    {
        throw ReplayError("replay: " + std::to_string(r.length_) + " ticks is out of range");
    }
    r.byTick_.resize(static_cast<std::size_t>(r.length_));

    int32_t start = 0;
    for (const JsonValue& row : doc.At("intents").Elements())
    {
        const std::size_t n = row.Size();
        if (n <= kSlotKind)
        {
            throw ReplayError("replay: an intent row needs at least a tick and a kind");
        }
        start += AsInt(row.At(kTick), "tick");
        const int32_t slotKind = AsInt(row.At(kSlotKind), "kind");
        const int32_t kind = slotKind % kSlotStride;
        const int32_t slot = slotKind / kSlotStride;
        if (kind > static_cast<int32_t>(kLastIntentKind) || slot < 0)
        {
            throw ReplayError("replay: intent kind " + std::to_string(kind) + " is unknown");
        }
        Intent in;
        in.kind = static_cast<IntentKind>(kind);
        if (n > kA) in.a = static_cast<float>(row.At(kA).AsNumber());
        if (n > kB) in.b = static_cast<float>(row.At(kB).AsNumber());
        if (n > kTarget) in.target = AsInt(row.At(kTarget), "target");
        const int32_t repeat = (n > kRepeat) ? AsInt(row.At(kRepeat), "repeat") : 1;
        if (start < 0 || repeat < 1 || start + repeat > r.length_)
        {
            throw ReplayError("replay: intents run past the recorded length");
        }
        for (int32_t k = 0; k < repeat; ++k)
        {
            IntentBuffer& buf = r.byTick_[static_cast<std::size_t>(start + k)];
            const auto at = static_cast<std::size_t>(slot);
            if (buf.size() <= at)
            {
                buf.resize(at + 1);
            }
            buf[at] = in;
        }
    }
    return r;
}

const IntentBuffer& Replay::IntentsAt(int32_t tick) const noexcept
{
    if (tick < 0 || tick >= length_)
    {
        return empty_;
    }
    return byTick_[static_cast<std::size_t>(tick)];
}

void Replay::RequireTuning(const std::string& currentHash) const
{
    if (currentHash != tuningHash_)
    {
        throw ReplayError("replay was recorded against tuning " + tuningHash_ +
                          " but this build's tuning is " + currentHash +
                          " — the same intents would play a different run");
    }
}

}  // namespace sj
