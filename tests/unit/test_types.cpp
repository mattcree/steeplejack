// Types tests — CORE-004.
//
// Types.h has no behaviour, so there is nothing here to test in the usual sense. What these
// tests pin down is the part of a plain struct that is still a contract and can still break
// silently: its default values, and the order of its enums.
//
// Both matter more than they look. A zero-initialised Anchor that defaulted to jointId 0 and
// AnchorRate::Sound would be an anchor that holds a climber's weight and is attached to joint
// zero — reachability and load-sharing would both believe it. And the enums are ordered
// worst-to-best on purpose so that `tier >= JointTier::Fair` reads the way the words do;
// reorder them and every such comparison inverts without failing to compile.

#include "doctest.h"

#include "Types.h"

#include <cstdint>
#include <string>
#include <type_traits>

using namespace sj;

TEST_CASE("Types: Acceptance 4: a default-constructed value of each type has known defaults")
{
    SUBCASE("Vec2 and Vec3 zero")
    {
        const Vec2 a{};
        const Vec3 b{};
        CHECK(a.x == 0.0f);
        CHECK(a.y == 0.0f);
        CHECK(b.x == 0.0f);
        CHECK(b.y == 0.0f);
        CHECK(b.z == 0.0f);
    }

    SUBCASE("Joint is an unoccupied, cracked joint at the origin")
    {
        const Joint j{};
        CHECK(j.id == 0);
        CHECK(j.pos.x == 0.0f);
        CHECK(j.pos.y == 0.0f);
        CHECK(j.pos.z == 0.0f);
        CHECK(j.normal.x == 0.0f);
        CHECK(j.normal.y == 0.0f);
        CHECK(j.normal.z == 0.0f);
        CHECK(j.height == 0.0f);
        CHECK(j.quality == 0.0f);
        CHECK(j.tier == JointTier::Cracked);
        CHECK_FALSE(j.occupied);
    }

    SUBCASE("Anchor defaults to unplaced and failed, never to a usable anchor")
    {
        const Anchor a{};
        CHECK(a.jointId == -1);        // -1, not 0: 0 is a real joint id
        CHECK(a.rate == AnchorRate::Failed);
        CHECK(a.height == 0.0f);
        CHECK(a.depth == 0.0f);
        CHECK(a.spall == 0.0f);
        CHECK(a.capacityKN == 0.0f);
        CHECK(a.loadKN == 0.0f);
        CHECK_FALSE(a.freeFixture);
    }

    SUBCASE("Section defaults to unattached, undamaged and not buckling")
    {
        const Section s{};
        CHECK(s.lowerAnchor == -1);
        CHECK(s.upperAnchor == -1);
        CHECK(s.span == 0.0f);
        CHECK(s.condition == 1.0f);    // 1 is pristine; a zeroed Section is not a ruined one
        CHECK(s.buckleTimer == -1.0f); // negative means "not buckling", so 0 cannot mean it
        CHECK(s.lashing == Lashing::None);
    }

    SUBCASE("Meters defaults to an empty two-meter state on a platform")
    {
        const Meters m{};
        CHECK(m.grip == 0.0f);
        CHECK(m.nerve == 0.0f);
        CHECK(m.nerveMax == 0.0f);
        CHECK(m.stance == Stance::OneHand);
        CHECK(m.exposure == Exposure::Platform);
    }

    SUBCASE("MeterContext defaults to still, dry, bare-handed and uninjured")
    {
        const MeterContext c{};
        CHECK(c.height == 0.0f);
        CHECK(c.windSpeed == 0.0f);
        CHECK_FALSE(c.carryingLadder);
        CHECK_FALSE(c.wet);
        CHECK_FALSE(c.cold);
        CHECK_FALSE(c.gloves);
        REQUIRE(c.injury != nullptr);          // never null: callers strcmp it without a guard
        CHECK(std::string(c.injury).empty());
    }

    SUBCASE("StrikeResult defaults to a blow that did nothing")
    {
        const StrikeResult r{};
        CHECK(r.depthGain == 0.0f);
        CHECK(r.spalled == 0.0f);
        CHECK_FALSE(r.bent);
        CHECK_FALSE(r.seated);
    }
}

TEST_CASE("Types: graded enums run worst to best, so ordering comparisons read correctly")
{
    CHECK(JointTier::Cracked < JointTier::Perished);
    CHECK(JointTier::Perished < JointTier::Fair);
    CHECK(JointTier::Fair < JointTier::Sound);

    CHECK(AnchorRate::Failed < AnchorRate::Poor);
    CHECK(AnchorRate::Poor < AnchorRate::Fair);
    CHECK(AnchorRate::Fair < AnchorRate::Sound);

    // Stance runs least to most secure, Lashing least to most restraint, Exposure least to
    // most exposed, SpanBand stiffest to least stiff. Each is load-bearing for a threshold
    // test somewhere downstream.
    CHECK(Stance::OneHand < Stance::HookedLeg);
    CHECK(Stance::Clipped < Stance::Belted);
    CHECK(Stance::Belted < Stance::Chair);

    CHECK(Lashing::None < Lashing::Hitch);
    CHECK(Lashing::Hitch < Lashing::Full);

    CHECK(Exposure::Platform < Exposure::Ladder);
    CHECK(Exposure::Hanging < Exposure::Overhang);

    CHECK(SpanBand::Rigid < SpanBand::Flex);
    CHECK(SpanBand::Flex < SpanBand::Sway);
    CHECK(SpanBand::Sway < SpanBand::Buckle);
}

TEST_CASE("Types: the zero value of every enum is its first, safest state")
{
    // Guarantees that a memset-zeroed or brace-initialised struct lands on the conservative
    // end of each scale rather than in the middle of one.
    CHECK(static_cast<uint8_t>(JointTier::Cracked) == 0);
    CHECK(static_cast<uint8_t>(AnchorRate::Failed) == 0);
    CHECK(static_cast<uint8_t>(Stance::OneHand) == 0);
    CHECK(static_cast<uint8_t>(Lashing::None) == 0);
    CHECK(static_cast<uint8_t>(Exposure::Platform) == 0);
    CHECK(static_cast<uint8_t>(SpanBand::Rigid) == 0);
}

TEST_CASE("Types: every enum is one byte, so replay frames stay layout-stable")
{
    // The replay format (CORE-006) and the determinism gate compare these structs
    // byte-for-byte. Widening an enum silently changes the padding of everything holding it.
    static_assert(std::is_same_v<std::underlying_type_t<JointTier>, uint8_t>);
    static_assert(std::is_same_v<std::underlying_type_t<AnchorRate>, uint8_t>);
    static_assert(std::is_same_v<std::underlying_type_t<Stance>, uint8_t>);
    static_assert(std::is_same_v<std::underlying_type_t<Lashing>, uint8_t>);
    static_assert(std::is_same_v<std::underlying_type_t<Exposure>, uint8_t>);
    static_assert(std::is_same_v<std::underlying_type_t<SpanBand>, uint8_t>);
    CHECK(sizeof(JointTier) == 1);
}

TEST_CASE("Types: Acceptance 1 and 3: aggregate initialisation sets fields in declared order")
{
    // If a field is ever added, reordered or retyped, this stops compiling — which is the
    // point. The interfaces doc fixes these field lists and this is what holds them.
    const Joint j{7, Vec3{1.0f, 2.0f, 3.0f}, Vec3{0.0f, 0.0f, 1.0f},
                  12.5f, 0.8f, JointTier::Sound, true};
    CHECK(j.id == 7);
    CHECK(j.pos.y == 2.0f);
    CHECK(j.normal.z == 1.0f);
    CHECK(j.height == 12.5f);
    CHECK(j.quality == 0.8f);
    CHECK(j.tier == JointTier::Sound);
    CHECK(j.occupied);

    const Anchor a{j.id, 12.5f, 0.06f, 0.01f, AnchorRate::Fair, 9.0f, 3.2f, false};
    CHECK(a.jointId == 7);
    CHECK(a.capacityKN == 9.0f);
    CHECK(a.loadKN == 3.2f);

    const Section s{0, 1, 4.0f, 0.9f, -1.0f, Lashing::Hitch};
    CHECK(s.upperAnchor == 1);
    CHECK(s.span == 4.0f);
    CHECK(s.lashing == Lashing::Hitch);

    const Meters m{0.4f, 0.7f, 1.0f, Stance::Clipped, Exposure::Hanging};
    CHECK(m.grip == 0.4f);
    CHECK(m.stance == Stance::Clipped);

    const MeterContext c{30.0f, 8.0f, false, true, true, false, "cracked_rib"};
    CHECK(c.height == 30.0f);
    CHECK(c.wet);
    CHECK(std::string(c.injury) == "cracked_rib");

    const StrikeResult r{0.012f, 0.0f, false, true};
    CHECK(r.depthGain == 0.012f);
    CHECK(r.seated);
}

TEST_CASE("Types: Acceptance 3: designated initialisers name fields, so a rename breaks loudly")
{
    const Meters m{.grip = 0.5f, .nerve = 0.25f, .nerveMax = 1.0f,
                   .stance = Stance::Belted, .exposure = Exposure::Overhang};
    CHECK(m.nerve == 0.25f);
    CHECK(m.exposure == Exposure::Overhang);
}

TEST_CASE("Types: the fixed timestep is 60 Hz and catch-up is bounded")
{
    CHECK(kTick == doctest::Approx(1.0 / 60.0));
    CHECK(kMaxCatchUpSteps > 0);

    // The bound is what stops a long stall from spiralling: one frame can never spend more
    // than this much simulated time catching up, however long it was stalled.
    CHECK(static_cast<double>(kTick) * kMaxCatchUpSteps < 1.0);
}

TEST_CASE("Types: these are data — no constructors, no virtuals, no inheritance")
{
    // Mirrors the static_asserts in Types.h. Kept here too so the rule is visible to someone
    // reading the tests to find out what the types promise.
    static_assert(std::is_aggregate_v<Joint>);
    static_assert(std::is_trivially_copyable_v<Anchor>);
    static_assert(std::is_standard_layout_v<Section>);
    static_assert(!std::is_polymorphic_v<Meters>);
    static_assert(std::is_trivially_copyable_v<StrikeResult>);
    CHECK(std::is_aggregate_v<MeterContext>);
}
