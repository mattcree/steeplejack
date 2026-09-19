// The checkpoint — CLIMB-006, the acceptance by number.
//
// The stacks here are not freshly built. They are stepped under load first, so they carry the
// history a real checkpoint carries: a hitch that has walked, a section part-way through bowing,
// a dog that has let go. A round trip of a pristine stack would prove the easy half.

#include "doctest.h"

#include "Anchor.h"
#include "Stack.h"
#include "Tuning.h"
#include "Types.h"

#include <cstring>
#include <filesystem>
#include <string>

using sj::Anchor;
using sj::AnchorRate;
using sj::Lashing;
using sj::Stack;
using sj::Tuning;
namespace save = sj::save;

namespace {

std::string TuningDir()
{
    namespace fs = std::filesystem;
    fs::path here = fs::current_path();
    for (int up = 0; up < 5; ++up)
    {
        if (fs::is_directory(here / "data" / "tuning"))
        {
            return (here / "data" / "tuning").string();
        }
        if (!here.has_parent_path())
        {
            break;
        }
        here = here.parent_path();
    }
    return {};
}

const Tuning& Tune()
{
    static const Tuning t = Tuning::LoadAll(TuningDir());
    return t;
}

const std::string kLevelText = R"({"id":"00-greybox","heightM":55})";

// `n` sections of mixed spans, ratings and lashings, then lived in: a climber on the top section
// for a while (so the hitch walks and a long span starts to bow), and a shock that pulls a dog.
Stack LivedIn(int n)
{
    Stack s;
    int32_t below = 0;
    float h = 0.0f;
    const AnchorRate rates[] = {AnchorRate::Sound, AnchorRate::Fair, AnchorRate::Poor};
    for (int i = 1; i <= n; ++i)
    {
        h += (i % 5 == 0 && i != n) ? 8.6f : 3.4f + 0.13f * static_cast<float>(i % 4);
        Anchor a{};
        a.jointId = 100 + i * 7;
        a.height = h;
        a.depth = 0.9f + 0.01f * static_cast<float>(i % 3);
        a.spall = 0.05f * static_cast<float>(i % 3);
        a.rate = rates[i % 3];
        a.capacityKN = sj::anchor::CapacityKN(a.rate, Tune());
        a.freeFixture = (i == 3);
        const int32_t id = s.AddAnchor(a);
        s.AddSection(below, id, (i % 4 == 0 || i == n) ? Lashing::Hitch : Lashing::Full);
        below = id;
    }
    for (int i = 0; i < 60 * 20; ++i)
    {
        s.Step(sj::kTick, s.SectionCount() - 1, 0.9f, Tune());
    }
    (void)s.Shock(s.AnchorCount() - 2, 50.0f, Tune());
    return s;
}

bool Bits(float x, float y) { return std::memcmp(&x, &y, sizeof(float)) == 0; }

void CheckSame(const Stack& a, const Stack& b)
{
    REQUIRE(a.AnchorCount() == b.AnchorCount());
    REQUIRE(a.SectionCount() == b.SectionCount());
    for (int32_t i = 0; i < a.AnchorCount(); ++i)
    {
        const Anchor& x = a.AnchorAt(i);
        const Anchor& y = b.AnchorAt(i);
        CAPTURE(i);
        CHECK(x.jointId == y.jointId);
        CHECK(Bits(x.height, y.height));
        CHECK(Bits(x.depth, y.depth));
        CHECK(Bits(x.spall, y.spall));
        CHECK(x.rate == y.rate);
        CHECK(Bits(x.capacityKN, y.capacityKN));
        CHECK(Bits(x.loadKN, y.loadKN));
        CHECK(x.freeFixture == y.freeFixture);
        CHECK(a.AnchorFailed(i) == b.AnchorFailed(i));
        CHECK(a.InStructure(i) == b.InStructure(i));
    }
    for (int32_t i = 0; i < a.SectionCount(); ++i)
    {
        const sj::Section& x = a.SectionAt(i);
        const sj::Section& y = b.SectionAt(i);
        CAPTURE(i);
        CHECK(x.lowerAnchor == y.lowerAnchor);
        CHECK(x.upperAnchor == y.upperAnchor);
        CHECK(Bits(x.span, y.span));
        CHECK(Bits(x.condition, y.condition));
        CHECK(Bits(x.buckleTimer, y.buckleTimer));
        CHECK(x.lashing == y.lashing);
        CHECK(a.SectionFailed(i) == b.SectionFailed(i));
        CHECK(Bits(a.SectionDriftCm(i), b.SectionDriftCm(i)));
        CHECK(a.Band(i, Tune()) == b.Band(i, Tune()));
    }
    CHECK(Bits(a.TopHeight(), b.TopHeight()));
    CHECK(a.TopOfStructure() == b.TopOfStructure());
}

}  // namespace

TEST_CASE("Save: acceptance 1, a lived-in 14-section stack round-trips exactly")
{
    const Stack before = LivedIn(14);
    // The control: this stack really does carry history, so an exact round trip means something.
    bool walked = false, bowing = false, failed = false;
    for (int32_t i = 0; i < before.SectionCount(); ++i)
    {
        walked = walked || before.SectionDriftCm(i) > 0.0f;
        bowing = bowing || before.SectionAt(i).buckleTimer >= 0.0f;
        failed = failed || before.SectionFailed(i);
    }
    for (int32_t i = 0; i < before.AnchorCount(); ++i)
    {
        failed = failed || before.AnchorFailed(i);
    }
    CHECK((walked || bowing));
    CHECK(failed);

    const std::string print = save::LevelFingerprint(kLevelText);
    const Stack after = save::RestoreStack(save::SerialiseStack(before, "00-greybox", print),
                                           "00-greybox", print);
    CheckSame(before, after);

    // And it behaves the same from here: the same load, the same events.
    Stack x = before, y = after;
    for (int i = 0; i < 600; ++i)
    {
        const auto ex = x.Step(sj::kTick, x.SectionCount() - 1, 1.1f, Tune());
        const auto ey = y.Step(sj::kTick, y.SectionCount() - 1, 1.1f, Tune());
        REQUIRE(ex.failedAnchors == ey.failedAnchors);
        REQUIRE(ex.failedSections == ey.failedSections);
        REQUIRE(ex.buckling == ey.buckling);
    }
}

TEST_CASE("Save: acceptance 2, the version is written, and an unknown one is refused by name")
{
    const std::string print = save::LevelFingerprint(kLevelText);
    std::string text = save::SerialiseStack(LivedIn(3), "00-greybox", print);
    REQUIRE(text.rfind("{\"version\":1,", 0) == 0);
    text.replace(0, std::string("{\"version\":1").size(), "{\"version\":7");
    try
    {
        (void)save::RestoreStack(text, "00-greybox", print);
        FAIL("a version-7 checkpoint was read");
    }
    catch (const save::SaveError& e)
    {
        CHECK(std::string(e.what()).find("version 7") != std::string::npos);
    }
}

TEST_CASE("Save: acceptance 3, saving the restored stack gives the same bytes")
{
    const std::string print = save::LevelFingerprint(kLevelText);
    const std::string first = save::SerialiseStack(LivedIn(14), "00-greybox", print);
    const std::string second =
        save::SerialiseStack(save::RestoreStack(first, "00-greybox", print), "00-greybox", print);
    CHECK(first == second);
}

TEST_CASE("Save: acceptance 4, a 28-section stack is under 20 KB")
{
    const std::string text =
        save::SerialiseStack(LivedIn(28), "00-greybox", save::LevelFingerprint(kLevelText));
    MESSAGE("28 sections: " << text.size() << " bytes");
    CHECK(text.size() < 20u * 1024u);
}

TEST_CASE("Save: acceptance 5, a changed level file refuses the old stack")
{
    const std::string text =
        save::SerialiseStack(LivedIn(5), "00-greybox", save::LevelFingerprint(kLevelText));
    const std::string edited = R"({"id":"00-greybox","heightM":56})";
    CHECK(save::LevelFingerprint(edited) != save::LevelFingerprint(kLevelText));
    CHECK_THROWS_AS((void)save::RestoreStack(text, "00-greybox", save::LevelFingerprint(edited)),
                    save::SaveError);
    CHECK_THROWS_AS((void)save::RestoreStack(text, "06-waterside", save::LevelFingerprint(kLevelText)),
                    save::SaveError);
    CHECK_NOTHROW((void)save::RestoreStack(text, "00-greybox", save::LevelFingerprint(kLevelText)));
}

TEST_CASE("Save: a checkpoint that does not hang together is refused, not half-built")
{
    const std::string print = save::LevelFingerprint(kLevelText);
    const std::string head = R"({"version":1,"level":"00-greybox","levelFile":")" + print + "\",";
    // A section lashed to anchor 9 of a two-anchor stack.
    CHECK_THROWS_AS((void)save::RestoreStack(head + R"("anchors":[[-1,0,0,0,3,1000,0,0,0],[5,4,1,0,3,9,0,0,0]],"sections":[[0,9,4,1,-1,2,0,0]]})",
                                             "00-greybox", print), save::SaveError);
    // No ground.
    CHECK_THROWS_AS((void)save::RestoreStack(head + R"("anchors":[[5,4,1,0,3,9,0,0,0]],"sections":[]})",
                                             "00-greybox", print), save::SaveError);
    // A lashing that does not exist.
    CHECK_THROWS_AS((void)save::RestoreStack(head + R"("anchors":[[-1,0,0,0,3,1000,0,0,0],[5,4,1,0,3,9,0,0,0]],"sections":[[0,1,4,1,-1,9,0,0]]})",
                                             "00-greybox", print), save::SaveError);
}
