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

// Symbol visibility at the UE boundary.
//
// UBT compiles SteeplejackSim as its own shared library with `-fvisibility-ms-compat`, which
// hides a class's out-of-line member functions unless they are explicitly exported — so
// SteeplejackGame fails to link against Tuning::LoadAll and Tuning::Hash with no warning until
// the link step.
//
// UE's own answer is the UBT-generated STEEPLEJACKSIM_API macro, but that expands to DLLEXPORT,
// which is defined in an Unreal header this module must never include (ADR-0004). So: the plain
// compiler attribute, which needs no engine header and expands to nothing when the compiler does
// not support it. The standalone CMake build is unaffected either way.
//
// Known gap: MSVC has no visibility attribute — Windows needs dllexport/dllimport, which differs
// per translation unit and cannot come from one macro defined here. The project builds on Linux
// today. See this task's Outcome; this needs to become a project-wide convention rather than a
// decision made in one header.
#if defined(__GNUC__) || defined(__clang__)
#define SJ_API __attribute__((visibility("default")))
#else
#define SJ_API
#endif

namespace sj {

// Thrown by LoadAll for unreadable or malformed JSON, and by the getters for a missing key or a
// key of the wrong type. Always carries enough to fix the problem without a debugger.
class SJ_API TuningError : public std::runtime_error
{
public:
    explicit TuningError(const std::string& what) : std::runtime_error(what) {}
};

class SJ_API Tuning
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
