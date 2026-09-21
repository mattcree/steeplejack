// Tuning tests — CORE-007.
//
// Two things are being tested here that look like plumbing and are not.
//
// The first is that a missing key *throws*. Rule 4 pushes every constant in the game out of the
// code and into these files, which means the loader is now the single point where a balance
// mistake becomes a silent wrong number. A getter that returned 0.0 for a typo would make the
// game keep running and the cause invisible; most of the cases below exist to pin that shut.
//
// The second is Hash(). It is stamped into every replay, so a tuning change that invalidates a
// recorded run fails loudly at playback instead of quietly producing a different outcome
// (ADR-0003). That only works if the digest is real, so it is checked against the FIPS 180-4
// published vectors rather than against itself.

#include "doctest.h"

#include "Tuning.h"

#include <filesystem>
#include <string>

using sj::Tuning;
using sj::TuningError;

namespace {

// The tests run from wherever the harness was launched. Walk up for the repo's data dir rather
// than assuming a working directory.
std::string TuningDir()
{
    namespace fs = std::filesystem;
    fs::path here = fs::current_path();
    for (int up = 0; up < 5; ++up)
    {
        const fs::path candidate = here / "data" / "tuning";
        if (fs::is_directory(candidate))
        {
            return candidate.string();
        }
        if (!here.has_parent_path())
        {
            break;
        }
        here = here.parent_path();
    }
    return {};
}

template <typename F>
std::string MessageOf(const F& f)
{
    try
    {
        f();
    }
    catch (const TuningError& e)
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

// ---------------------------------------------------------------- the real files

TEST_CASE("Tuning: Acceptance 1: all five shipped tuning files load without error")
{
    const std::string dir = TuningDir();
    REQUIRE_MESSAGE(!dir.empty(), "could not locate data/tuning from the working directory");

    const Tuning t = Tuning::LoadAll(dir);

    CHECK(t.Sources().size() == 6);   // + conductor.json, for the CONDUCTOR archetype
    CHECK(t.Keys().size() > 200);   // 235 leaf keys at the time of writing; the point is "lots"

    // One key from each file, so a file silently failing to load cannot pass this test.
    CHECK(t.Has("wanderFailRatio"));             // conductor.json
    CHECK(t.Has("climbSpeedMetresPerSecond"));   // climbing.json
    CHECK(t.Has("gripMax"));                     // meters.json
    CHECK(t.Has("currency"));                    // economy.json
    CHECK(t.Has("gobSegmentsDefault"));          // felling.json
    CHECK(t.Has("interactiveBricksPerMetre"));   // topping.json
    CHECK(t.Has("fractureCountTypical.0"));      // an array, reachable by index

    // economy.json holds an array of objects — the deepest shape in the data. Flattening keeps
    // it reachable without an array accessor on the interface.
    CHECK(t.GetI("engine.stages.1.cost") == 480);
    CHECK(t.Has("engine.stages.1.name"));
    CHECK_FALSE(t.Has("engine.stages.1"));       // not a leaf, so not a key
}

TEST_CASE("Tuning: Acceptance 2: dotted keys reach into nested objects")
{
    const Tuning t = Tuning::LoadAll(TuningDir());

    // The acceptance criterion as written names "grip_drain.one_hand". The shipped data spells
    // that group "gripDrainPerSecond" — see this task's Outcome. The value is the one the
    // criterion means.
    CHECK(t.GetF("gripDrainPerSecond.oneHand") == doctest::Approx(8.0f));
    CHECK(t.GetF("gripDrainPerSecond.chair") == doctest::Approx(0.0f));
    CHECK(t.GetF("anchorCapacityKN.sound") == doctest::Approx(5.0f));
}

TEST_CASE("Tuning: Acceptance 3: snake_case and camelCase are the same key")
{
    const Tuning t = Tuning::LoadAll(TuningDir());

    CHECK(t.GetF("grip_drain_per_second.one_hand") == t.GetF("gripDrainPerSecond.oneHand"));
    CHECK(t.GetF("climb_speed_metres_per_second") == t.GetF("climbSpeedMetresPerSecond"));
    CHECK(t.GetF("GRIPMAX") == t.GetF("gripMax"));
    CHECK(t.Has("span_warn_metres"));
    CHECK(t.Has("spanWarnMetres"));
}

TEST_CASE("Tuning: integers and floats are distinguished")
{
    const Tuning t = Tuning::LoadAll(TuningDir());

    CHECK(t.GetI("slipSaveWindowMs") == 900);
    CHECK(t.GetI("lashWrapsFull") == 6);

    // A whole-numbered float is still a whole number, so GetI accepts it.
    CHECK(t.GetI("gripMax") == 100);

    // A genuinely fractional value is not, and saying so beats truncating in silence.
    CHECK_THROWS_AS(t.GetI("climbAccelSeconds"), TuningError);
    CHECK(MessageOf([&] { (void)t.GetI("climbAccelSeconds"); }).find("not a whole number")
          != std::string::npos);
}

// ---------------------------------------------------------------- the failure mode that matters

TEST_CASE("Tuning: Acceptance 4: a missing key throws, naming the key and where it was sought")
{
    const Tuning t = Tuning::LoadAll(TuningDir());

    CHECK_THROWS_AS(t.GetF("gripMaximum"), TuningError);

    const std::string msg = MessageOf([&] { (void)t.GetF("gripMaximum"); });
    CHECK(msg.find("gripMaximum") != std::string::npos);     // the key
    CHECK(msg.find(".json") != std::string::npos);           // the files searched
    CHECK(msg.find("Did you mean") != std::string::npos);    // the nearest real key
    CHECK(msg.find("gripMax") != std::string::npos);         // ...which is the obvious one
}

TEST_CASE("Tuning: a missing key never returns zero — the whole point of the rule")
{
    const Tuning t = Tuning::Parse(R"({"realKey": 3.0})", "test.json");

    CHECK_THROWS_AS(t.GetF("notAKey"), TuningError);
    CHECK_THROWS_AS(t.GetI("notAKey"), TuningError);
    CHECK_THROWS_AS(t.GetB("notAKey"), TuningError);
    CHECK_FALSE(t.Has("notAKey"));
    CHECK(t.GetF("realKey") == doctest::Approx(3.0f));
}

TEST_CASE("Tuning: asking for the wrong type is an error, not a coercion")
{
    const Tuning t = Tuning::Parse(R"({"n": 2.5, "b": true, "s": "GBP"})", "test.json");

    CHECK(t.GetF("n") == doctest::Approx(2.5f));
    CHECK(t.GetB("b"));

    CHECK_THROWS_AS(t.GetB("n"), TuningError);   // 2.5 is not "truthy"
    CHECK_THROWS_AS(t.GetF("b"), TuningError);   // true is not 1.0
    CHECK_THROWS_AS(t.GetF("s"), TuningError);
    CHECK(t.Has("s"));                           // parsed and present, just not a number
}

TEST_CASE("Tuning: two spellings of one key in one file is a collision, not a silent overwrite")
{
    const std::string msg =
        MessageOf([] { (void)Tuning::Parse(R"({"gripMax": 1.0, "grip_max": 2.0})", "t.json"); });
    CHECK(msg.find("collision") != std::string::npos);
    CHECK(msg.find("gripMax") != std::string::npos);
    CHECK(msg.find("grip_max") != std::string::npos);
}

// ---------------------------------------------------------------- parsing

TEST_CASE("Tuning: the JSON reader accepts what the tuning files actually contain")
{
    const Tuning t = Tuning::Parse(R"({
        "flat": 1.5,
        "negative": -30,
        "exponent": 1e3,
        "yes": true,
        "no": false,
        "text": "GBP",
        "nested": { "deep": { "deeper": 7 } },
        "list": [10, 20, 30],
        "empty": {}
    })", "t.json");

    CHECK(t.GetF("flat") == doctest::Approx(1.5f));
    CHECK(t.GetI("negative") == -30);
    CHECK(t.GetF("exponent") == doctest::Approx(1000.0f));
    CHECK(t.GetB("yes"));
    CHECK_FALSE(t.GetB("no"));
    CHECK(t.GetI("nested.deep.deeper") == 7);
    CHECK(t.GetI("list.1") == 20);        // arrays become indexed keys
    CHECK_FALSE(t.Has("empty"));          // an empty object contributes no leaves
}

TEST_CASE("Tuning: malformed JSON fails with the file and line, not a mystery")
{
    const std::string msg = MessageOf([] {
        (void)Tuning::Parse("{\n  \"a\": 1,\n  \"b\": ,\n}", "broken.json");
    });
    CHECK(msg.find("broken.json") != std::string::npos);
    CHECK(msg.find(":3") != std::string::npos);
}

TEST_CASE("Tuning: null is rejected rather than quietly becoming zero")
{
    const std::string msg = MessageOf([] { (void)Tuning::Parse(R"({"a": null})", "t.json"); });
    CHECK(msg.find("null is not a tuning value") != std::string::npos);
}

TEST_CASE("Tuning: trailing content after the document is an error")
{
    CHECK_THROWS_AS(Tuning::Parse(R"({"a": 1} {"b": 2})", "t.json"), TuningError);
}

TEST_CASE("Tuning: a missing directory is an error, not an empty Tuning")
{
    CHECK_THROWS_AS(Tuning::LoadAll("no/such/directory"), TuningError);
}

// ---------------------------------------------------------------- Hash

TEST_CASE("Tuning: the digest is a real SHA-256, not something that merely looks like one")
{
    // An empty Tuning hashes an empty canonical string, so this is the FIPS 180-4 empty-message
    // vector, checkable against `printf '' | sha256sum`. It exercises padding, and nothing else:
    // one block, zero length field.
    const auto digestOfEmpty = Tuning::Parse("{}", "t.json").Hash();
    CHECK(digestOfEmpty == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
    CHECK(digestOfEmpty.size() == 64);

    // The cases below are known answers computed by an independent SHA-256 over this class's
    // canonical form (see Tuning::Hash). Their job is to exercise what the empty vector cannot:
    // a non-zero length field, and block chaining across more than one 64-byte block.
    //
    // If you deliberately change the canonical form, these digests change and these three lines
    // must be recomputed — that is the cost of pinning the format, and it is the point. If you
    // did NOT change the canonical form and these fail, the SHA-256 itself is broken.

    // 18 canonical bytes: one block, non-zero length field.
    CHECK(Tuning::Parse(R"({"gripMax": 100.0})", "t.json").Hash() ==
          "e69c435899cc88c6e10748adfdc783a2e7e5d35337e54e21eeb3b646145049a7");

    // 53 canonical bytes, spanning all three value kinds, just under the 55-byte boundary where
    // padding stops fitting in the same block.
    CHECK(Tuning::Parse(R"({"alpha": 1.5, "beta": true, "gamma": "GBP", "delta": -30.0})",
                        "t.json").Hash() ==
          "45b6d8dc01e725d1e75627aff5bcce138ad27daec1686e1947383eeb139f7838");

    // 192 canonical bytes: four blocks. This is the one that would catch a broken chaining loop,
    // which the empty-string vector cannot see at all.
    CHECK(Tuning::Parse(R"({"key00": 0.0, "key01": 1.5, "key02": 3.0, "key03": 4.5,
                            "key04": 6.0, "key05": 7.5, "key06": 9.0, "key07": 10.5,
                            "key08": 12.0, "key09": 13.5, "key10": 15.0, "key11": 16.5})",
                        "t.json").Hash() ==
          "6dbf4eec7bd9652817d594846793150a68aaf2c9dcde962e664cc78ef209fa07");
}

TEST_CASE("Tuning: a string value cannot forge an entry boundary in the canonical form")
{
    // Entries are length-prefixed rather than delimited. With a delimiter-based form these two
    // different tunings produce identical canonical bytes and therefore the same digest — which
    // would mean a tuning change that does not change the hash, and a replay that silently no
    // longer reproduces. Length prefixes cannot be forged from inside the payload they measure.
    // The bytes have to be raw, not escaped: the reader rejects \u escapes outright, which is
    // what makes this hard to do by accident and easy to do on purpose.
    const std::string kindTagForString(1, static_cast<char>(2));
    const std::string smuggledJson = "{\"a\": \"\\n1:b" + kindTagForString + "1:x\"}";

    const Tuning smuggled = Tuning::Parse(smuggledJson, "t.json");
    const Tuning honest   = Tuning::Parse(R"({"a": "", "b": "x"})", "t.json");
    CHECK(smuggled.Hash() != honest.Hash());
}

TEST_CASE("Tuning: GetI refuses a value that does not fit in an int32")
{
    const Tuning t = Tuning::Parse(R"({"huge": 1e12, "verySmall": -3e9, "fine": 900})", "t.json");

    CHECK(t.GetI("fine") == 900);

    // Truncating 1e12 yields -2147483648 — a plausible-looking wrong number, which is the exact
    // failure this class exists to prevent.
    CHECK_THROWS_AS(t.GetI("huge"), TuningError);
    CHECK_THROWS_AS(t.GetI("verySmall"), TuningError);
    CHECK(MessageOf([&] { (void)t.GetI("huge"); }).find("32-bit") != std::string::npos);

    // Still readable as a float — the value is fine, it is just not an int32.
    CHECK(t.GetF("huge") == doctest::Approx(1e12f));
}

TEST_CASE("Tuning: Acceptance 5: the hash is stable across loads and across key spellings")
{
    const std::string dir = TuningDir();
    const Tuning a = Tuning::LoadAll(dir);
    const Tuning b = Tuning::LoadAll(dir);
    CHECK(a.Hash() == b.Hash());
    CHECK(a.Hash().size() == 64);

    // Same values, different house style: the same tuning, so the same digest. A replay must not
    // be invalidated by someone renaming a key from camelCase to snake_case.
    const Tuning camel = Tuning::Parse(R"({"gripMax": 100.0, "nerveStart": 90.0})", "t.json");
    const Tuning snake = Tuning::Parse(R"({"grip_max": 100.0, "nerve_start": 90.0})", "t.json");
    CHECK(camel.Hash() == snake.Hash());
}

TEST_CASE("Tuning: Acceptance 5: the hash changes when any value changes")
{
    const Tuning base = Tuning::Parse(R"({"a": 1.0, "b": 2.0, "c": true})", "t.json");

    CHECK(base.Hash() != Tuning::Parse(R"({"a": 1.0, "b": 2.5, "c": true})", "t.json").Hash());
    CHECK(base.Hash() != Tuning::Parse(R"({"a": 1.0, "b": 2.0, "c": false})", "t.json").Hash());
    CHECK(base.Hash() != Tuning::Parse(R"({"a": 1.0, "b": 2.0})", "t.json").Hash());
    CHECK(base.Hash() != Tuning::Parse(R"({"a": 1.0, "b": 2.0, "c": true, "d": 0.0})",
                                       "t.json").Hash());

    // A change far below what printing a float would show still changes the digest, because the
    // canonical form hashes the raw bytes rather than a formatted number.
    const Tuning near = Tuning::Parse(R"({"a": 1.0000000000000002, "b": 2.0, "c": true})",
                                      "t.json");
    CHECK(base.Hash() != near.Hash());
}

TEST_CASE("Tuning: a number and a string that look alike do not hash alike")
{
    CHECK(Tuning::Parse(R"({"a": 1})", "t.json").Hash() !=
          Tuning::Parse(R"({"a": "1"})", "t.json").Hash());
}
