// Recording a run — CORE-006. See Recorder.h.
//
// The file format, written for size first because a replay is attached to every bug report:
//
//     {"format":1,"level":"00-greybox","seed":"1234","tuning":"0d5b…","ticks":3600,
//      "intents":[[dt,slotKind,a,b,target,repeat], …]}
//
// * `dt` is the row's start tick minus the previous row's, so ticks cost a digit or two.
// * `slotKind` is slot × 32 + kind, where slot is the intent's index within its tick. Order inside
//   a tick is part of the run — Move then Look is not Look then Move — and the slot is how it
//   survives the run-length encoding below.
// * `repeat` covers a run of consecutive ticks carrying the same intent in the same slot: a held
//   climb key for four seconds is one row, not 240.
// * Trailing fields at their defaults (a = 0, b = 0, target = −1, repeat = 1) are left off.
// * The seed is a string: a uint64 does not survive a JSON number, which is a double.
// * Floats are written shortest-round-trip and checked: the reader parses a double and narrows
//   it, and a replay that is off by one ulp is not a replay.

#include "Recorder.h"

#include <charconv>
#include <cmath>
#include <cstring>
#include <cstddef>
#include <string>
#include <system_error>

namespace sj {
namespace {

constexpr int32_t kSlotStride = 32;   // literal: IntentKind has 19 values; the slot sits above them
constexpr int32_t kFormat = 1;
constexpr std::size_t kRowBytesGuess = 24;   // literal: a typical row, for one up-front reserve

void AppendFloat(std::string& out, float v)
{
    char buf[32];
    auto r = std::to_chars(buf, buf + sizeof(buf), v);
    double back = 0.0;
    std::from_chars(buf, r.ptr, back);
    if (static_cast<float>(back) != v)
    {
        // The shortest float spelling read back as a double and narrowed to a different float —
        // a double rounding. The double spelling of the same value is exact.
        r = std::to_chars(buf, buf + sizeof(buf), static_cast<double>(v));
    }
    out.append(buf, r.ptr);
}

// Zero, and not negative zero: −0.0 == 0.0, so leaving "defaults" off by comparing with == turned
// a recorded −0.0 into +0.0 on the way back.
bool IsDefault(float v) noexcept
{
    return v == 0.0f && !std::signbit(v);
}

// The same intent to the bit, for extending a run. Intent's own == says −0.0 is 0.0, which is right
// for a caller and wrong here: a run that swallowed the one tick with −0.0 would replay +0.0.
bool Same(const Intent& x, const Intent& y) noexcept
{
    return x.kind == y.kind && x.target == y.target &&
           std::memcmp(&x.a, &y.a, sizeof(float)) == 0 && std::memcmp(&x.b, &y.b, sizeof(float)) == 0;
}

void AppendEscaped(std::string& out, const std::string& s)
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

}  // namespace

Recorder::Recorder(std::string levelId, uint64_t seed, std::string tuningHash)
    : levelId_(std::move(levelId)), seed_(seed), tuningHash_(std::move(tuningHash))
{
}

void Recorder::Record(int32_t tick, const IntentBuffer& intents)
{
    if (tick <= lastTick_)
    {
        return;   // out of order or twice: the first recording of a tick stands
    }
    const bool next = (tick == lastTick_ + 1);
    lastTick_ = tick;
    if (!next)
    {
        open_.clear();
    }
    open_.resize(intents.size(), -1);
    for (std::size_t slot = 0; slot < intents.size(); ++slot)
    {
        const int32_t runIndex = open_[slot];
        if (runIndex >= 0)
        {
            Row& run = rows_[static_cast<std::size_t>(runIndex)];
            if (Same(run.intent, intents[slot]) && run.start + run.repeat == tick)
            {
                ++run.repeat;
                continue;
            }
        }
        rows_.push_back(Row{tick, static_cast<int32_t>(slot), intents[slot], 1});
        open_[slot] = static_cast<int32_t>(rows_.size() - 1);
    }
}

std::string Recorder::ToJson() const
{
    std::string out;
    out.reserve(rows_.size() * kRowBytesGuess);
    out += "{\"format\":" + std::to_string(kFormat) + ",\"level\":";
    AppendEscaped(out, levelId_);
    out += ",\"seed\":\"" + std::to_string(seed_) + "\",\"tuning\":";
    AppendEscaped(out, tuningHash_);
    out += ",\"ticks\":" + std::to_string(lastTick_ + 1) + ",\"intents\":[";

    int32_t prev = 0;
    bool first = true;
    for (const Row& row : rows_)
    {
        if (!first)
        {
            out += ',';
        }
        first = false;
        out += '[' + std::to_string(row.start - prev) + ',' +
               std::to_string(row.slot * kSlotStride + static_cast<int32_t>(row.intent.kind));
        prev = row.start;

        // Trailing defaults are dropped; anything before a non-default field is written.
        const bool repeat = row.repeat != 1;
        const bool target = repeat || row.intent.target != -1;
        const bool b = target || !IsDefault(row.intent.b);
        const bool a = b || !IsDefault(row.intent.a);
        if (a) { out += ','; AppendFloat(out, row.intent.a); }
        if (b) { out += ','; AppendFloat(out, row.intent.b); }
        if (target) { out += ',' + std::to_string(row.intent.target); }
        if (repeat) { out += ',' + std::to_string(row.repeat); }
        out += ']';
    }
    out += "]}";
    return out;
}

}  // namespace sj
