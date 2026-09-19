// Tap, anchors and the span economy — VERB-001, VERB-004.
//
// The span table is, in the GDD's words, "the entire risk/reward economy of the ascent". These
// tests are mostly about whether that economy actually has the shape the design claims: that
// stretching a span buys you speed and costs you safety, continuously, with a cliff at the end.

#include "doctest.h"

#include "Anchor.h"
#include "Tuning.h"
#include "Verbs/Hammer.h"
#include "Verbs/Tap.h"

#include <algorithm>
#include <filesystem>
#include <vector>

using sj::AnchorRate;
using sj::Joint;
using sj::JointTier;
using sj::SpanBand;
using sj::Tuning;

namespace {

const Tuning& Tune()
{
    static const Tuning t = []
    {
        namespace fs = std::filesystem;
        fs::path here = fs::current_path();
        for (int up = 0; up < 5; ++up)
        {
            if (fs::is_directory(here / "data" / "tuning"))
            {
                return Tuning::LoadAll((here / "data" / "tuning").string());
            }
            here = here.parent_path();
        }
        return Tuning::LoadAll("data/tuning");
    }();
    return t;
}

Joint OfQuality(float q)
{
    Joint j{};
    j.quality = q;
    return j;
}

}  // namespace

TEST_CASE("Tap: the four tiers land on the tuned bounds")
{
    CHECK(sj::tap::TierOf(0.05f, Tune()) == JointTier::Cracked);
    CHECK(sj::tap::TierOf(0.25f, Tune()) == JointTier::Perished);
    CHECK(sj::tap::TierOf(0.55f, Tune()) == JointTier::Fair);
    CHECK(sj::tap::TierOf(0.90f, Tune()) == JointTier::Sound);
}

TEST_CASE("Tap: reading the same joint twice gives the same answer")
{
    // You can re-tap to confirm rather than reroll. A tap test that returned noise would be a
    // slot machine, not a skill.
    const Joint J = OfQuality(0.5f);
    CHECK(sj::tap::Tap(J, Tune(), false).tier == sj::tap::Tap(J, Tune(), false).tier);
}

TEST_CASE("Tap: every reading carries a shape, never only a sound or a colour")
{
    // Rule 8: every audio cue has a visual fallback, and the fallback must not rely on hue.
    std::vector<int32_t> shapes;
    for (const float q : {0.05f, 0.25f, 0.55f, 0.90f})
    {
        const sj::TapResult R = sj::tap::Tap(OfQuality(q), Tune(), false);
        CHECK_FALSE(R.soundId.empty());
        shapes.push_back(R.pipShape);
    }
    // Four distinct shapes for four tiers — a shared shape would make two readings indistinguishable
    // for a player who cannot hear the difference.
    std::sort(shapes.begin(), shapes.end());
    CHECK(std::unique(shapes.begin(), shapes.end()) == shapes.end());
}

TEST_CASE("Tap: gloves cost resolution, and they err in the dangerous direction")
{
    // The grip table says gloves reduce drain but cost a tap-test tier. That trade has to bite:
    // a perished joint reading as fair is what gets someone hurt.
    const Joint Perished = OfQuality(0.25f);
    CHECK(sj::tap::Tap(Perished, Tune(), false).tier == JointTier::Perished);
    CHECK(sj::tap::Tap(Perished, Tune(), true).tier == JointTier::Fair);
    CHECK(sj::tap::Tap(Perished, Tune(), true).confidence <
          sj::tap::Tap(Perished, Tune(), false).confidence);
}

TEST_CASE("Anchor: a dog not driven home rates below what its joint allows")
{
    // This used to assert "not seated holds nothing" — the opposite of VERB-004's acceptance 3,
    // which says one tier lower. The acceptance is the spec; test_anchor.cpp covers it by tier.
    // The game only rates a dog once it is seated, so no play ever hit the difference.
    const float Seat = Tune().GetF("dogSeatDepthFraction");
    CHECK(sj::anchor::Rate(OfQuality(0.95f), Seat - 0.01f, 0.0f, Tune()) <
          sj::anchor::Rate(OfQuality(0.95f), Seat, 0.0f, Tune()));
}

TEST_CASE("Anchor: soft mortar is a trap — it seats fast and rates badly")
{
    // Driven all the way in, a perished joint still gives you a poor anchor. This is the lesson
    // the hammer tests set up, arriving where it actually costs: what you can hang off.
    const AnchorRate Sound = sj::anchor::Rate(OfQuality(0.90f), 1.0f, 0.0f, Tune());
    const AnchorRate Perished = sj::anchor::Rate(OfQuality(0.25f), 1.0f, 0.0f, Tune());

    CHECK(Sound == AnchorRate::Sound);
    CHECK(Perished < Sound);
    CHECK(sj::anchor::CapacityKN(Perished, Tune()) <
          sj::anchor::CapacityKN(Sound, Tune()));
}

TEST_CASE("Anchor: spalling the brick downgrades what you get")
{
    const AnchorRate Clean = sj::anchor::Rate(OfQuality(0.80f), 1.0f, 0.0f, Tune());
    const AnchorRate Split = sj::anchor::Rate(OfQuality(0.80f), 1.0f, 0.35f, Tune());
    CHECK(Split < Clean);
}

TEST_CASE("Anchor: a Sound anchor holds a climber with margin; a Poor one does not")
{
    const float Player = Tune().GetF("playerLoadKN");
    const float Dynamic = Tune().GetF("dynamicLoadFactor");

    CHECK(sj::anchor::CapacityKN(AnchorRate::Sound, Tune()) > Player * Dynamic);
    CHECK(sj::anchor::CapacityKN(AnchorRate::Failed, Tune()) == doctest::Approx(0.0f));

    // A Poor anchor will not hold a standing climber on its own: 1.0 kN against a 1.2 kN body.
    // That is sharper than it first reads and it is worth stating, because "Poor" sounds like
    // "weak but usable" and it is not — a single poor dog is a fall waiting to happen. Poor
    // anchors only become useful *shared*, which is what loadShareFalloff and CLIMB-002 are for,
    // and it is why a jack places several rather than trusting one.
    CHECK(sj::anchor::CapacityKN(AnchorRate::Poor, Tune()) < Player);
    CHECK(sj::anchor::CapacityKN(AnchorRate::Fair, Tune()) > Player);

    // Fair holds you standing but not a shock load — which is what makes a slip on a fair anchor
    // a cascade rather than an inconvenience.
    CHECK(sj::anchor::CapacityKN(AnchorRate::Fair, Tune()) < Player * Dynamic);
}

TEST_CASE("Span: the four bands land on the tuned distances")
{
    CHECK(sj::anchor::ClassifySpan(3.0f, Tune()) == SpanBand::Rigid);
    CHECK(sj::anchor::ClassifySpan(4.0f, Tune()) == SpanBand::Rigid);
    CHECK(sj::anchor::ClassifySpan(5.0f, Tune()) == SpanBand::Flex);
    CHECK(sj::anchor::ClassifySpan(6.0f, Tune()) == SpanBand::Flex);
    CHECK(sj::anchor::ClassifySpan(7.0f, Tune()) == SpanBand::Sway);
    CHECK(sj::anchor::ClassifySpan(8.0f, Tune()) == SpanBand::Sway);
    CHECK(sj::anchor::ClassifySpan(8.5f, Tune()) == SpanBand::Buckle);
}

TEST_CASE("Span: stretching a span costs more the further you push it")
{
    // Monotonic, and that matters: the economy only works if every metre of extra span is worse
    // than the last. A flat region would give the player a free stretch.
    const auto Grip = [](SpanBand b) { return sj::anchor::GripDrainMultiplier(b, Tune()); };
    const auto Nerve = [](SpanBand b) { return sj::anchor::NerveDrainMultiplier(b, Tune()); };
    const auto Load = [](SpanBand b) { return sj::anchor::DynamicLoadMultiplier(b, Tune()); };

    CHECK(Grip(SpanBand::Rigid) == doctest::Approx(1.0f));
    CHECK(Grip(SpanBand::Flex) > Grip(SpanBand::Rigid));
    CHECK(Nerve(SpanBand::Flex) == doctest::Approx(1.0f));   // flex is a grip problem, not a fear one
    CHECK(Nerve(SpanBand::Sway) > Nerve(SpanBand::Flex));
    CHECK(Load(SpanBand::Sway) > Load(SpanBand::Flex));
}

TEST_CASE("Span: a swaying span can overload an anchor that would hold a still climber")
{
    // The cascade in one test. A Poor anchor takes a standing climber. Put it on a swaying span
    // and the dynamic load goes past what it can hold — so a long span does not just feel worse,
    // it converts a survivable mistake into a failure.
    const float Fair = sj::anchor::CapacityKN(AnchorRate::Fair, Tune());
    const float Still = Tune().GetF("playerLoadKN");
    const float Swaying = Still * sj::anchor::DynamicLoadMultiplier(SpanBand::Sway, Tune()) *
                          Tune().GetF("dynamicLoadFactor");
    CHECK(Still < Fair);        // stood on it, a fair anchor is fine
    CHECK(Swaying > Fair);      // on a swaying span, the same anchor is not
}

TEST_CASE("Ascent: a full dog-in, end to end, produces an anchor you can hang a ladder off")
{
    // The loop in miniature: pick a joint, tap it, drive a dog, rate what you got.
    const Joint J = OfQuality(0.75f);
    CHECK(sj::tap::Tap(J, Tune(), false).tier == JointTier::Sound);

    float depth = 0.0f;
    float spall = 0.0f;
    int strikes = 0;
    while (depth < sj::hammer::SeatDepth(Tune()) && strikes < 20)
    {
        const sj::StrikeResult R = sj::hammer::Strike(J, depth, 0.75f, 1.0f, 1.0f, Tune());
        REQUIRE_FALSE(R.bent);
        depth += R.depthGain;
        spall += R.spalled;
        ++strikes;
    }

    const sj::Anchor A = sj::anchor::Make(J, depth, spall, Tune());
    CHECK(A.rate >= AnchorRate::Fair);
    CHECK(A.capacityKN > Tune().GetF("playerLoadKN"));
    CHECK(strikes >= 3);   // a sound joint should cost you some effort
}
