// Anchor rating — VERB-004, the acceptance by number.
//
// A rating is the whole risk model of the ascent in one number, and the player is always told it.
// So the rules here are the ones the player is trusting: a cracked joint never holds, spalling
// never helps, the capacities are the table's.

#include "doctest.h"

#include "Anchor.h"
#include "Level.h"
#include "Rng.h"
#include "Tuning.h"
#include "Types.h"
#include "Verbs/Hammer.h"

#include <filesystem>
#include <string>

using sj::AnchorRate;
using sj::Joint;
using sj::Tuning;

namespace {

std::string DataDir(const char* sub)
{
    namespace fs = std::filesystem;
    fs::path here = fs::current_path();
    for (int up = 0; up < 5; ++up)
    {
        if (fs::is_directory(here / "data" / sub))
        {
            return (here / "data" / sub).string();
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
    static const Tuning t = Tuning::LoadAll(DataDir("tuning"));
    return t;
}

float Seat() { return Tune().GetF("dogSeatDepthFraction"); }

Joint Of(float quality)
{
    Joint j{};
    j.quality = quality;
    return j;
}

// A quality in the middle of each tier's band, from the tuning's own bounds.
float Mid(sj::JointTier tier)
{
    const float cracked = Tune().GetF("jointQualityTierBounds.cracked");
    const float perished = Tune().GetF("jointQualityTierBounds.perished");
    const float fair = Tune().GetF("jointQualityTierBounds.fair");
    switch (tier)
    {
    case sj::JointTier::Cracked:  return cracked * 0.5f;
    case sj::JointTier::Perished: return (cracked + perished) * 0.5f;
    case sj::JointTier::Fair:     return (perished + fair) * 0.5f;
    case sj::JointTier::Sound:    return (fair + 1.0f) * 0.5f;
    }
    return 0.0f;
}

}  // namespace

TEST_CASE("Anchor: acceptance 1, all four ratings are reachable, spalling included")
{
    CHECK(sj::anchor::Rate(Of(Mid(sj::JointTier::Sound)), 1.0f, 0.0f, Tune()) == AnchorRate::Sound);
    CHECK(sj::anchor::Rate(Of(Mid(sj::JointTier::Fair)), Seat(), 0.0f, Tune()) == AnchorRate::Fair);
    CHECK(sj::anchor::Rate(Of(Mid(sj::JointTier::Perished)), Seat(), 0.0f, Tune()) == AnchorRate::Poor);
    CHECK(sj::anchor::Rate(Of(Mid(sj::JointTier::Cracked)), 1.0f, 0.0f, Tune()) == AnchorRate::Failed);

    // The spalled-brick path: a Sound joint driven hard enough to split the brick rates lower.
    const Joint sound = Of(Mid(sj::JointTier::Sound));
    CHECK(sj::anchor::Rate(sound, 1.0f, 0.5f, Tune()) < AnchorRate::Sound);

    // The bent-dog path is not a rating: a bent dog gains nothing and is lost (VERB-003), and the
    // game spoils the joint rather than seating it. What this module guarantees is that a strike
    // which bends leaves the dog where it was — it can never be the blow that seats it.
    const sj::StrikeResult bent = sj::hammer::Strike(sound, Seat() - 0.01f, 1.0f, 30.0f, 1.0f, Tune());
    CHECK(bent.bent);
    CHECK(bent.depthGain == 0.0f);
    CHECK_FALSE(bent.seated);
}

TEST_CASE("Anchor: acceptance 2, a cracked joint rates Failed at any depth and any spall")
{
    // Right across the cracked band, including its very top, where the depth bonus used to lift
    // a cracked joint into Poor.
    const float top = Tune().GetF("jointQualityTierBounds.cracked");
    for (float q = 0.0f; q < top; q += top / 50.0f)
    {
        for (float depth = Seat(); depth <= 1.0f; depth += 0.05f)
        {
            CAPTURE(q);
            CAPTURE(depth);
            CHECK(sj::anchor::Rate(Of(q), depth, 0.0f, Tune()) == AnchorRate::Failed);
        }
    }
}

TEST_CASE("Anchor: acceptance 3, an under-seated dog rates one tier below what its joint allows")
{
    const float shallow = Seat() - 0.05f;
    CHECK(sj::anchor::Rate(Of(Mid(sj::JointTier::Sound)), shallow, 0.0f, Tune()) == AnchorRate::Fair);
    CHECK(sj::anchor::Rate(Of(Mid(sj::JointTier::Fair)), shallow, 0.0f, Tune()) == AnchorRate::Poor);
    CHECK(sj::anchor::Rate(Of(Mid(sj::JointTier::Perished)), shallow, 0.0f, Tune()) == AnchorRate::Failed);
    CHECK(sj::anchor::Rate(Of(Mid(sj::JointTier::Cracked)), shallow, 0.0f, Tune()) == AnchorRate::Failed);
}

TEST_CASE("Anchor: acceptance 4, the capacities are climbing.json's, exactly")
{
    CHECK(sj::anchor::CapacityKN(AnchorRate::Sound, Tune()) == Tune().GetF("anchorCapacityKN.sound"));
    CHECK(sj::anchor::CapacityKN(AnchorRate::Fair, Tune()) == Tune().GetF("anchorCapacityKN.fair"));
    CHECK(sj::anchor::CapacityKN(AnchorRate::Poor, Tune()) == Tune().GetF("anchorCapacityKN.poor"));
    CHECK(sj::anchor::CapacityKN(AnchorRate::Failed, Tune()) == Tune().GetF("anchorCapacityKN.failed"));
    // And the GDD's table, so a tuning edit that breaks the design shows up here too.
    CHECK(sj::anchor::CapacityKN(AnchorRate::Sound, Tune()) == doctest::Approx(5.0f));
    CHECK(sj::anchor::CapacityKN(AnchorRate::Fair, Tune()) == doctest::Approx(2.5f));
    CHECK(sj::anchor::CapacityKN(AnchorRate::Poor, Tune()) == doctest::Approx(1.0f));
}

TEST_CASE("Anchor: acceptance 5, more spall never improves a rating")
{
    // Every joint quality, every seated and unseated depth, spall stepped from none to total.
    for (float q = 0.0f; q <= 1.0f; q += 0.02f)
    {
        for (float depth = 0.5f; depth <= 1.0f; depth += 0.1f)
        {
            AnchorRate prev = sj::anchor::Rate(Of(q), depth, 0.0f, Tune());
            for (float spall = 0.02f; spall <= 1.0f; spall += 0.02f)
            {
                const AnchorRate r = sj::anchor::Rate(Of(q), depth, spall, Tune());
                CAPTURE(q);
                CAPTURE(depth);
                CAPTURE(spall);
                CHECK(r <= prev);
                prev = r;
            }
        }
    }
}

TEST_CASE("Anchor: acceptance 6, old fixtures are the same for the same level and seed")
{
    const sj::LevelData level = sj::LevelData::LoadFrom(DataDir("levels") + "/00-greybox.json");
    const sj::Rng seed(level.Structure().weatherSeed);
    const auto a = sj::anchor::OldFixtures(level, seed, Tune());
    const auto b = sj::anchor::OldFixtures(level, seed, Tune());
    REQUIRE(!a.empty());
    REQUIRE(a.size() == b.size());
    for (std::size_t i = 0; i < a.size(); ++i)
    {
        CHECK(a[i].height == b[i].height);
        CHECK(a[i].rust == b[i].rust);
    }
    // And a different seed moves the rust: the fixtures are drawn, not hard-coded.
    const auto c = sj::anchor::OldFixtures(level, sj::Rng(level.Structure().weatherSeed + 1), Tune());
    bool differs = false;
    for (std::size_t i = 0; i < a.size() && i < c.size(); ++i)
    {
        differs = differs || a[i].rust != c[i].rust;
    }
    CHECK(differs);
}
