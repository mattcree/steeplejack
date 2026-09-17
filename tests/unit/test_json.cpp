// JSON reader tests — CORE-014.
//
// Two jobs. The first is the ordinary one: parse what the data contains, reject what it does not,
// and say where. The second is the reason the reader was extracted at all — prove the *tree* API
// is adequate for CORE-008 before CORE-008 is written against it. A shared reader that turns out
// not to fit its second caller is worse than two readers, because the second caller then bends
// around it.
//
// tests/unit/test_tuning.cpp is the other half of this file's coverage. It still passes unchanged
// after the extraction, which is what says the flattening behaviour did not drift — including its
// pinned SHA-256 digests, which would move if a single path or value kind changed.

#include "doctest.h"

#include "Json.h"

#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

using sj::JsonError;
using sj::JsonValue;

namespace {

std::string RepoFile(const std::string& relative)
{
    namespace fs = std::filesystem;
    fs::path here = fs::current_path();
    for (int up = 0; up < 5; ++up)
    {
        if (fs::is_regular_file(here / relative))
        {
            return (here / relative).string();
        }
        if (!here.has_parent_path())
        {
            break;
        }
        here = here.parent_path();
    }
    return {};
}

std::string ReadFile(const std::string& path)
{
    std::ifstream in(path, std::ios::binary);
    std::ostringstream buf;
    buf << in.rdbuf();
    return buf.str();
}

template <typename F>
std::string MessageOf(const F& f)
{
    try
    {
        f();
    }
    catch (const JsonError& e)
    {
        return e.what();
    }
    catch (...)
    {
        return "<wrong exception type>";
    }
    return "<no exception>";
}

}  // namespace

// ---------------------------------------------------------------- the subset the data uses

TEST_CASE("Json: parses the value kinds the data actually contains")
{
    const JsonValue d = JsonValue::Parse(R"({
        "flat": 1.5,
        "negative": -30,
        "exponent": 1e3,
        "yes": true,
        "no": false,
        "text": "GBP",
        "nothing": null,
        "nested": { "deep": { "deeper": 7 } },
        "list": [10, 20, 30],
        "empty": {}
    })", "t.json");

    CHECK(d.Type() == JsonValue::Kind::Object);
    CHECK(d.At("flat").AsNumber() == doctest::Approx(1.5));
    CHECK(d.At("negative").AsNumber() == doctest::Approx(-30.0));
    CHECK(d.At("exponent").AsNumber() == doctest::Approx(1000.0));
    CHECK(d.At("yes").AsBool());
    CHECK_FALSE(d.At("no").AsBool());
    CHECK(d.At("text").AsString() == "GBP");
    CHECK(d.At("nothing").Type() == JsonValue::Kind::Null);
    CHECK(d.At("nested").At("deep").At("deeper").AsNumber() == doctest::Approx(7.0));
    CHECK(d.At("list").At(std::size_t{1}).AsNumber() == doctest::Approx(20.0));
    CHECK(d.At("list").Size() == 3);
    CHECK(d.At("empty").Size() == 0);
}

TEST_CASE("Json: null parses rather than throwing — the policy belongs to the caller")
{
    // Tuning refuses a null because a null tuning value reaches a getter as a zero. A level file
    // might legitimately use one. The reader should not decide that for either of them.
    const JsonValue d = JsonValue::Parse(R"({"a": null})", "t.json");
    CHECK(d.At("a").Type() == JsonValue::Kind::Null);
    CHECK(d.Has("a"));
}

TEST_CASE("Json: line comments are accepted, because the data-schemas doc writes these as jsonc")
{
    const JsonValue d = JsonValue::Parse(R"({
        // the comment the doc's own example carries
        "a": 1  // and a trailing one
    })", "t.json");
    CHECK(d.At("a").AsNumber() == doctest::Approx(1.0));
}

// ---------------------------------------------------------------- the tree, for CORE-008

TEST_CASE("Json: Acceptance 5: a real level file parses, and its bands keep file order")
{
    const std::string path = RepoFile("data/levels/06-waterside.json");
    REQUIRE_MESSAGE(!path.empty(), "could not locate data/levels/06-waterside.json");

    const JsonValue level = JsonValue::Parse(ReadFile(path), "06-waterside.json");

    CHECK(level.At("id").AsString() == "06-waterside");
    CHECK(level.At("archetype").AsString() == "FELL");
    CHECK(level.At("structure").At("height").AsNumber() == doctest::Approx(70.0));

    // Order is contract, not incidental: bands are contiguous height ranges and CORE-008 checks
    // each against its neighbour. Sorted or hashed order would make that check meaningless.
    const std::vector<JsonValue>& bands = level.At("bands").Elements();
    REQUIRE(bands.size() == 4);
    CHECK(bands[0].At("type").AsString() == "plain");
    CHECK(bands[1].At("type").AsString() == "ivy");
    CHECK(bands[2].At("type").AsString() == "existing-band");
    CHECK(bands[3].At("type").AsString() == "wind-band");

    // Contiguity, which is one of the rules CORE-008's Validate() has to re-implement. Proving it
    // is expressible here is the point of this test.
    for (std::size_t i = 1; i < bands.size(); ++i)
    {
        CHECK(bands[i].At("from").AsNumber() ==
              doctest::Approx(bands[i - 1].At("to").AsNumber()));
    }
    CHECK(bands.back().At("to").AsNumber() ==
          doctest::Approx(level.At("structure").At("height").AsNumber()));

    // An array of objects nested in an object — the deepest shape in the data.
    CHECK(level.At("site").At("exclusions").Type() == JsonValue::Kind::Array);
}

TEST_CASE("Json: object members keep file order, not sorted order")
{
    const JsonValue d = JsonValue::Parse(R"({"zebra": 1, "apple": 2, "mango": 3})", "t.json");
    REQUIRE(d.Members().size() == 3);
    CHECK(d.Members()[0].first == "zebra");
    CHECK(d.Members()[1].first == "apple");
    CHECK(d.Members()[2].first == "mango");
}

// ---------------------------------------------------------------- the flat view

TEST_CASE("Json: ForEachLeaf yields dotted paths, with array indices as segments")
{
    const JsonValue d = JsonValue::Parse(R"({
        "a": 1,
        "b": { "c": 2 },
        "d": [ { "e": 3 }, { "e": 4 } ],
        "empty": {},
        "emptyList": []
    })", "t.json");

    std::vector<std::string> paths;
    d.ForEachLeaf([&paths](const std::string& p, const JsonValue&) { paths.push_back(p); });

    CHECK(paths == std::vector<std::string>{"a", "b.c", "d.0.e", "d.1.e"});
    // An empty object or array is not a leaf: a key that holds nothing is not a key.
}

// ---------------------------------------------------------------- saying where it went wrong

TEST_CASE("Json: every parse error names the origin file and the line")
{
    const std::string msg = MessageOf([] {
        (void)JsonValue::Parse("{\n  \"a\": 1,\n  \"b\": ,\n}", "broken.json");
    });
    CHECK(msg.find("broken.json") != std::string::npos);
    CHECK(msg.find(":3") != std::string::npos);
}

TEST_CASE("Json: the errors that matter are rejections, not guesses")
{
    CHECK_THROWS_AS(JsonValue::Parse(R"({"a": 1} {"b": 2})", "t.json"), JsonError);
    CHECK_THROWS_AS(JsonValue::Parse(R"({"a": "unterminated)", "t.json"), JsonError);
    CHECK_THROWS_AS(JsonValue::Parse(R"({"a": 1,)", "t.json"), JsonError);
    CHECK_THROWS_AS(JsonValue::Parse(R"({"a": tru})", "t.json"), JsonError);

    // Decoding surrogate pairs wrongly in silence is worse than refusing. The escape is built
    // at runtime rather than written in the source: a compiler may fold a universal character
    // name into its character even inside a raw string literal, and then the test tests nothing.
    const std::string uEscape = std::string("{\"a\": \"") + char(92) + "u0041\"}";
    CHECK(MessageOf([&] { (void)JsonValue::Parse(uEscape, "t.json"); })
              .find("escapes are not supported") != std::string::npos);

    CHECK(MessageOf([] { (void)JsonValue::Parse(R"({"a": "\q"})", "t.json"); })
              .find("unknown escape") != std::string::npos);
}

TEST_CASE("Json: the escapes that are supported round-trip")
{
    const JsonValue d = JsonValue::Parse(R"({"a": "one\ttwo\nthree \"quoted\" back\\slash"})",
                                         "t.json");
    CHECK(d.At("a").AsString() == "one\ttwo\nthree \"quoted\" back\\slash");
}

TEST_CASE("Json: asking for the wrong kind names both what was wanted and what was there")
{
    const JsonValue d = JsonValue::Parse(R"({"n": 1, "s": "x", "list": [1]})", "t.json");

    CHECK(MessageOf([&] { (void)d.At("n").AsString(); }).find("expected a string") !=
          std::string::npos);
    CHECK(MessageOf([&] { (void)d.At("n").AsString(); }).find("found a number") !=
          std::string::npos);
    CHECK_THROWS_AS(d.At("s").AsNumber(), JsonError);
    CHECK_THROWS_AS(d.At("n").AsBool(), JsonError);

    // Indexing an object or keying an array says so rather than returning nothing.
    CHECK_THROWS_AS(d.At(std::size_t{0}), JsonError);
    CHECK_THROWS_AS(d.At("list").At("nope"), JsonError);
}

TEST_CASE("Json: a missing member or a past-the-end index throws rather than defaulting")
{
    const JsonValue d = JsonValue::Parse(R"({"a": 1, "list": [1, 2]})", "t.json");

    CHECK_FALSE(d.Has("nope"));
    CHECK(MessageOf([&] { (void)d.At("nope"); }).find("no member 'nope'") != std::string::npos);
    CHECK(MessageOf([&] { (void)d.At("list").At(std::size_t{5}); }).find("past the end") !=
          std::string::npos);
}
