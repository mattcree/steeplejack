#pragma once

// Every tuned number in the game — CORE-007.
//
// Rule 4 says no magic numbers in SteeplejackSim. A rule like that only survives contact with
// a deadline if reading tuning is *easier* than typing the number, so this is deliberately one
// class, one loader and three getters, with no setup and no schema to declare.
//
//     const Tuning t = Tuning::LoadAll("data/tuning");
//     const float drain = t.GetF("gripDrainPerSecond.oneHand");
//
// Two properties are load-bearing beyond convenience:
//
// * **A missing key throws.** It never returns zero. A silently-zero tuning value in a
//   balance-driven game is the worst available failure mode: the game still runs, the number is
//   wrong, and nothing points at the cause. The exception names the key, the nearest key that
//   does exist, and the files that were searched.
// * **Hash() is stamped into every replay.** A tuning change that invalidates a recorded replay
//   then fails loudly at playback instead of quietly producing a different outcome. See ADR-0003.
//
// Keys are dotted paths into the JSON — "gripDrainPerSecond.oneHand" — and are matched ignoring
// case and underscores, so snake_case and camelCase spellings of the same key are the same key.

#include <cstdint>
#include <map>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace sj {

// Thrown by LoadAll for unreadable or malformed JSON, and by the getters for a missing key or a
// key of the wrong type. Always carries enough to fix the problem without a debugger.
class TuningError : public std::runtime_error
{
public:
    explicit TuningError(const std::string& what) : std::runtime_error(what) {}
};

class Tuning
{
public:
    // Reads every *.json in `dir`. Throws TuningError if the directory has no tuning files, if
    // any file is malformed, or if two keys in different files collide once normalised.
    static Tuning LoadAll(const std::string& dir);

    // Parse JSON text directly. LoadAll is built on this; tests use it to build a Tuning without
    // touching the filesystem. `origin` is the name reported in error messages.
    static Tuning Parse(const std::string& json, const std::string& origin);

    float   GetF(std::string_view key) const;   // any number
    int32_t GetI(std::string_view key) const;   // a number with no fractional part
    bool    GetB(std::string_view key) const;   // a JSON true/false

    bool Has(std::string_view key) const noexcept;

    // sha256 of the canonical form of every key and value. Stable across runs and across key
    // spellings; changes if any value changes.
    std::string Hash() const;

    // Every key, in canonical (normalised) form, sorted. For diagnostics and tests.
    std::vector<std::string> Keys() const;

    // The files this Tuning was loaded from, in load order. Named in error messages.
    const std::vector<std::string>& Sources() const noexcept { return sources_; }

private:
    enum class Kind : uint8_t { Number, Bool, String };

    struct Value
    {
        Kind        kind{Kind::Number};
        double      number{};
        bool        boolean{};
        std::string text;
        std::string origin;    // the file this value came from
        std::string spelling;  // the key as actually written, for error messages
    };

    const Value& Find(std::string_view key, const char* wanted) const;
    [[noreturn]] void ThrowMissing(std::string_view key, const char* wanted) const;

    std::map<std::string, Value> values_;
    std::vector<std::string>     sources_;
};

}  // namespace sj
