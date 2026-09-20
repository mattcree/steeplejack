// "Am I happy on this ladder?" — CLIMB-007.
//
// Every other question this module answers is about the section under his feet right now. This is
// the one a jack actually asks, which is a judgement about the whole structure made by looking
// down it. A stack can be perfectly quiet under a climber and still be one dog away from coming
// down, and until this existed the game had no way to say so — every warning in it was scoped to
// the rung he was standing on.
//
// The question is made answerable by asking the only one that matters: if he came off the top,
// what would happen? That is 1.2 kN of him times a dynamic factor of 2.5 — three kilonewtons, the
// number that decides every fall in this game, which the player had never been shown.

#include "doctest.h"

#include "Meters.h"
#include "Stack.h"
#include "Tuning.h"
#include "Types.h"

#include <filesystem>
#include <string>

using sj::Anchor;
using sj::AnchorRate;
using sj::Lashing;
using sj::SpanBand;
using sj::Stack;
using sj::StackSurvey;
using sj::StackVerdict;
using sj::Tuning;

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

float Load() { return Tune().GetF("playerLoadKN"); }

Anchor Dog(float height, AnchorRate rate)
{
    Anchor a;
    a.height = height;
    a.rate = rate;
    a.capacityKN = Tune().GetF(std::string("anchorCapacityKN.") +
                               (rate == AnchorRate::Sound ? "sound"
                                : rate == AnchorRate::Fair ? "fair"
                                : rate == AnchorRate::Poor ? "poor" : "failed"));
    return a;
}

// A stack of `n` sections, every dog the same rating, every span the same.
Stack Build(int n, AnchorRate rate, float span, Lashing lashing = Lashing::Full)
{
    Stack s;
    int32_t lower = 0;
    for (int i = 1; i <= n; ++i)
    {
        const int32_t a = s.AddAnchor(Dog(span * static_cast<float>(i), rate));
        s.AddSection(lower, a, lashing);
        lower = a;
    }
    return s;
}

}  // namespace

TEST_CASE("Survey: a stack of sound dogs on short spans is right")
{
    const Stack s = Build(6, AnchorRate::Sound, 3.0f);
    const StackSurvey v = s.Survey(Load(), Tune());
    CHECK(v.verdict == StackVerdict::Sound);
    CHECK(v.HoldsAFall());
    CHECK(v.firstToGo == -1);
    CHECK(v.cascadeDepth == 0);
    CHECK(v.hitches == 0);
    CHECK(v.poorAnchors == 0);
    CHECK(v.worstBand == SpanBand::Rigid);
}

TEST_CASE("Survey: acceptance, the shock it tests with is the one that decides every fall")
{
    const Stack s = Build(3, AnchorRate::Sound, 3.0f);
    const StackSurvey v = s.Survey(Load(), Tune());
    CHECK(v.shockAtTopKN ==
          doctest::Approx(Tune().GetF("playerLoadKN") * Tune().GetF("dynamicLoadFactor")));
    CHECK(v.shockAtTopKN == doctest::Approx(3.0f));

    // Which is the whole point: a Sound dog is rated 5 kN and holds it. A Fair dog is rated 2.5
    // and does not, and nothing in the game ever said so before you fell.
    CHECK(Tune().GetF("anchorCapacityKN.sound") > v.shockAtTopKN);
    CHECK(Tune().GetF("anchorCapacityKN.fair") < v.shockAtTopKN);
}

TEST_CASE("Survey: a ladder hung on fair dogs would come down, and says which one goes first")
{
    const Stack s = Build(5, AnchorRate::Fair, 3.0f);
    const StackSurvey v = s.Survey(Load(), Tune());
    CHECK(v.verdict == StackVerdict::NotRight);
    CHECK_FALSE(v.HoldsAFall());
    CHECK(v.firstToGo > 0);
    CHECK(v.firstToGoHeightM == doctest::Approx(15.0f));   // the top one: that is where the line is
    CHECK(v.firstToGoCapacityKN == doctest::Approx(Tune().GetF("anchorCapacityKN.fair")));
    CHECK(v.poorAnchors == 5);   // none of them could take a fall

    // And it says how far it would go. 3.0 kN, retained at 0.65 a step: 3.0, 1.95 — and 1.95 is
    // under a Fair dog's 2.5, so it stops at the second one down. Two dogs, not the whole stack.
    CHECK(v.cascadeDepth == 1);
    CHECK(v.wouldFallToM == doctest::Approx(12.0f));
}

TEST_CASE("Survey: a run of poor dogs unzips, and the survey counts how far")
{
    const Stack s = Build(6, AnchorRate::Poor, 3.0f);
    const StackSurvey v = s.Survey(Load(), Tune());
    CHECK(v.verdict == StackVerdict::NotRight);
    // 3.0 -> 1.95 -> 1.27 -> 0.82, and a Poor dog is 1.0: the first three go, the fourth holds.
    CHECK(v.cascadeDepth == 3);
    CHECK(v.wouldFallToM == doctest::Approx(9.0f));
    CHECK(v.poorAnchors == 6);
}

TEST_CASE("Survey: one bad dog in a good stack is found, wherever it is")
{
    Stack s;
    int32_t lower = 0;
    for (int i = 1; i <= 6; ++i)
    {
        const AnchorRate rate = (i == 4) ? AnchorRate::Fair : AnchorRate::Sound;
        const int32_t a = s.AddAnchor(Dog(3.0f * static_cast<float>(i), rate));
        s.AddSection(lower, a, Lashing::Full);
        lower = a;
    }
    const StackSurvey v = s.Survey(Load(), Tune());
    CHECK(v.poorAnchors == 1);

    // But it would still hold a fall from the top, because the shock never reaches it: the top dog
    // is Sound and stops it dead. It is a thing to know about, not a thing that is about to happen.
    CHECK(v.HoldsAFall());
    CHECK(v.verdict == StackVerdict::Working);
}

TEST_CASE("Survey: a long span is wrong even on perfect dogs, because he has to climb it")
{
    const Stack sway = Build(3, AnchorRate::Sound, 7.0f);
    const StackSurvey v = sway.Survey(Load(), Tune());
    CHECK(v.worstBand == SpanBand::Sway);
    CHECK(v.longestSpanM == doctest::Approx(7.0f));
    CHECK(v.longestSection >= 0);
    CHECK(v.verdict == StackVerdict::NotRight);
    CHECK(v.HoldsAFall());   // it would hold him; it is still not a ladder to be on

    const Stack flex = Build(3, AnchorRate::Sound, 5.0f);
    CHECK(flex.Survey(Load(), Tune()).verdict == StackVerdict::Working);
    CHECK(flex.Survey(Load(), Tune()).worstBand == SpanBand::Flex);
}

TEST_CASE("Survey: quick hitches are counted, because they are the thing you meant to come back to")
{
    const Stack s = Build(4, AnchorRate::Sound, 3.0f, Lashing::Hitch);
    const StackSurvey v = s.Survey(Load(), Tune());
    CHECK(v.hitches == 4);
    CHECK(v.verdict == StackVerdict::Working);
    CHECK(v.HoldsAFall());
}

TEST_CASE("Survey: an empty stack is not a stack, and does not pretend to be wrong")
{
    const Stack empty;
    const StackSurvey v = empty.Survey(Load(), Tune());
    CHECK(v.verdict == StackVerdict::Sound);
    CHECK(v.firstToGo == -1);
    CHECK(v.longestSection == -1);
}

TEST_CASE("Survey: it changes nothing — you can look at a ladder without standing on it")
{
    Stack s = Build(5, AnchorRate::Poor, 3.0f);
    const float before = s.TopHeight();
    const int32_t anchors = s.AnchorCount();
    for (int i = 0; i < 5; ++i)
    {
        const StackSurvey v = s.Survey(Load(), Tune());
        CHECK(v.cascadeDepth == 3);   // and says the same thing every time
    }
    CHECK(s.TopHeight() == doctest::Approx(before));
    CHECK(s.AnchorCount() == anchors);
    for (int32_t i = 0; i < s.AnchorCount(); ++i)
    {
        CHECK_FALSE(s.AnchorFailed(i));
    }
}

TEST_CASE("Survey: a long span finally costs something, which it did not for a year")
{
    // `spanWarnGripDrainMultiplier` 1.3 and `spanDangerNerveMultiplier` 2.0 were computed by
    // anchor:: and passed to nothing at all, so a flexing or swaying ladder was free. They are
    // terms in the meters now, and these are the two numbers the data has always claimed.
    sj::MeterContext rigid;
    rigid.height = 20.0f;
    rigid.working = true;
    sj::MeterContext flex = rigid;
    flex.span = SpanBand::Flex;
    sj::MeterContext sway = rigid;
    sway.span = SpanBand::Sway;

    const float onShort = sj::grip::DrainRate(sj::Stance::OneHand, rigid, Tune());
    const float onLong = sj::grip::DrainRate(sj::Stance::OneHand, flex, Tune());
    CHECK(onLong > onShort);
    CHECK(onLong / onShort ==
          doctest::Approx(Tune().GetF("spanWarnGripDrainMultiplier")).epsilon(0.001));

    sj::Meters m;
    m.nerveMax = 100.0f;
    m.exposure = sj::Exposure::Ladder;
    const float calm = sj::nerve::DrainRate(m, rigid, Tune());
    const float frightening = sj::nerve::DrainRate(m, sway, Tune());
    CHECK(frightening > calm);
    CHECK(frightening / calm ==
          doctest::Approx(Tune().GetF("spanDangerNerveMultiplier")).epsilon(0.001));

    // And a short section is exactly as it was, so nothing that was tuned against the old
    // behaviour has quietly moved.
    CHECK(onShort == doctest::Approx(sj::grip::DrainRate(sj::Stance::OneHand, {}, Tune())
                                     * 1.0f).epsilon(0.001));
}
