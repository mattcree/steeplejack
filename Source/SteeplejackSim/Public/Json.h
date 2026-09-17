#pragma once

// The one JSON reader in SteeplejackSim — CORE-014.
//
// `SteeplejackSim` takes no third-party dependencies by design: it must configure and build with
// nothing but a compiler, no engine and no package manager (ADR-0004). So it needs its own reader,
// and it needs exactly one — CORE-007 wrote a flattening reader inside Tuning.cpp because nothing
// else needed it, and CORE-008 needs a tree. Two readers is how two readers start disagreeing
// about what a number is.
//
// This is a tree, with the flat view built on top:
//
//     const JsonValue doc = JsonValue::Parse(text, "06-waterside.json");
//     for (const JsonValue& band : doc.At("bands").Elements())   // file order, guaranteed
//         Check(band.At("from").AsNumber(), band.At("to").AsNumber());
//
//     doc.ForEachLeaf([](const std::string& path, const JsonValue& v) { ... });  // Tuning's view
//
// Scope is the subset the data actually uses. Anything outside it is rejected loudly rather than
// guessed at: a level or tuning file that this reader silently misreads is worse than one it
// refuses, because the game still starts.

#include <cstdint>
#include <functional>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace sj {

// Always carries the origin file and the line, because a JSON error with neither is a hunt.
class JsonError : public std::runtime_error
{
public:
    JsonError(const std::string& origin, std::size_t line, const std::string& what)
        : std::runtime_error(origin + ":" + std::to_string(line) + ": " + what),
          origin_(origin), line_(line) {}

    const std::string& Origin() const noexcept { return origin_; }
    std::size_t Line() const noexcept { return line_; }

private:
    std::string origin_;
    std::size_t line_;
};

class JsonValue
{
public:
    enum class Kind : uint8_t { Object, Array, Number, String, Bool, Null };

    static JsonValue Parse(const std::string& text, const std::string& origin);

    Kind Type() const noexcept { return kind_; }
    const std::string& Origin() const noexcept { return origin_; }
    std::size_t Line() const noexcept { return line_; }

    bool Has(std::string_view key) const noexcept;

    // Throws rather than returning a default. A level file missing a field it needs should stop
    // the load, not produce a structure that is subtly wrong in a way nothing reports.
    const JsonValue& At(std::string_view key) const;
    const JsonValue& At(std::size_t index) const;

    std::size_t Size() const noexcept;

    double AsNumber() const;
    const std::string& AsString() const;
    bool AsBool() const;

    // File order, not sorted. This is contract, not incidental: level bands are contiguous height
    // ranges and CORE-008 validates each against its neighbour, which is meaningless if the order
    // is whatever a map decided.
    const std::vector<std::pair<std::string, JsonValue>>& Members() const noexcept { return members_; }
    const std::vector<JsonValue>& Elements() const noexcept { return elements_; }

    // Every leaf as (dotted.path, value). Array indices become path segments, so
    // "engine.stages.1.cost" addresses an object inside an array inside an object.
    using LeafVisitor = std::function<void(const std::string&, const JsonValue&)>;
    void ForEachLeaf(const LeafVisitor& visit) const;

    // What this value is, for an error message: "a number", "an object", ...
    const char* KindName() const noexcept;

private:
    friend class JsonReader;
    void Visit(const std::string& path, const LeafVisitor& visit) const;
    [[noreturn]] void FailKind(const char* wanted) const;

    Kind        kind_{Kind::Null};
    double      number_{};
    bool        boolean_{};
    std::string text_;
    std::string origin_;
    std::size_t line_{};

    std::vector<std::pair<std::string, JsonValue>> members_;   // Kind::Object
    std::vector<JsonValue>                         elements_;  // Kind::Array
};

}  // namespace sj
