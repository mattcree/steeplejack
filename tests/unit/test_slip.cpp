// Slip, save and fall tests — METER-005.
//
// These exist because the slip is the one place in the game where a reflex decides an outcome, and
// a reflex window that is subtly wrong is not a bug anyone can report. "It felt like I hit it" is
// all the player can tell you. So the window boundaries, the budget, and the cost of a save are
// asserted against the tuning file rather than against numbers typed in here — a designer moving
// the window moves the game and these tests follow; code that stops reading the table fails them
// immediately.
//
// The case that matters most is the one a player never sees coming: grabbing when nothing is
// slipping must not refill grip. Without that, mashing the grab key is free stamina and the entire
// meter is decoration again.

#include "doctest.h"

#include "Meters.h"
#include "Slip.h"
#include "Tuning.h"
#include "Types.h"

#include <filesystem>
#include <string>

using sj::Anchor;
using sj::Difficulty;
using sj::Meters;
using sj::SlipModel;
using sj::SlipOutcome;
using sj::Stance;
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

// A climber mid-shift: full nerve ceiling, some nerve spent, grip gone. The state a slip starts in.
Meters Slipping()
{
    Meters m{};
    m.nerveMax = Tune().GetF("nerveMax");
    m.nerve = m.nerveMax;
    m.grip = 0.0f;
    m.stance = Stance::OneHand;
    return m;
}

float WindowFor(const char* row)
{
    return Tune().GetF(std::string("difficulty.") + row + ".slipSaveWindowMs") / 1000.0f;
}

}  // namespace

// ---------------------------------------------------------------- the window

TEST_CASE("the window is the difficulty table's, in seconds")
{
    CHECK(SlipModel(Difficulty::Jack).WindowSeconds(Tune()) == doctest::Approx(WindowFor("jack")));
    CHECK(SlipModel(Difficulty::Assisted).WindowSeconds(Tune())
          == doctest::Approx(WindowFor("assisted")));
    CHECK(SlipModel(Difficulty::OwdHand).WindowSeconds(Tune())
          == doctest::Approx(WindowFor("owd_hand")));

    // Acceptance 1 names 900 ms on Jack specifically. Asserted against the file so the check is
    // that the *table* says 900, not that this test remembers it.
    CHECK(Tune().GetF("difficulty.jack.slipSaveWindowMs") == doctest::Approx(900.0f));

    // A more generous difficulty must never be a shorter window. The table is hand-edited and the
    // ordering is the only thing that makes the three rows mean "easier" and "harder".
    CHECK(WindowFor("assisted") > WindowFor("jack"));
    CHECK(WindowFor("jack") > WindowFor("owd_hand"));
}

TEST_CASE("climbing.json's loose slip keys agree with the jack row")
{
    // climbing.json carries slipSaveWindowMs and slipSaveCooldownSeconds at the top level, and
    // meters.json carries the same two per difficulty. Two files holding one answer eventually
    // hold two answers. The difficulty table is authoritative and the loose pair is the default;
    // this test is what stops them drifting apart in silence.
    CHECK(Tune().GetF("slipSaveWindowMs")
          == doctest::Approx(Tune().GetF("difficulty.jack.slipSaveWindowMs")));
    CHECK(Tune().GetF("slipSaveCooldownSeconds")
          == doctest::Approx(Tune().GetF("difficulty.jack.slipSaveCooldownSeconds")));
}

TEST_CASE("a slip opens a window and closes it on time")
{
    SlipModel s;
    Meters m = Slipping();
    const float window = s.WindowSeconds(Tune());

    CHECK_FALSE(s.InProgress());
    CHECK(s.BeginSlip(10.0f, Tune()) == doctest::Approx(window));
    CHECK(s.InProgress());

    // Still open a hair before the end.
    CHECK(s.Resolve(10.0f + window * 0.99f, false, m, Tune()) == SlipOutcome::None);
    CHECK(s.InProgress());

    // Closed at the end.
    CHECK(s.Resolve(10.0f + window, false, m, Tune()) == SlipOutcome::Fell);
    CHECK_FALSE(s.InProgress());
}

TEST_CASE("a grab on the last step of the window still counts")
{
    // The frame the player will swear they hit. Checked at exactly the boundary because that is
    // where an ordering mistake between "expired" and "grabbed" shows up and nowhere else.
    SlipModel s;
    Meters m = Slipping();
    const float window = s.WindowSeconds(Tune());

    s.BeginSlip(0.0f, Tune());
    CHECK(s.Resolve(window, true, m, Tune()) == SlipOutcome::Saved);
}

TEST_CASE("a grab after the window has closed does not save you")
{
    SlipModel s;
    Meters m = Slipping();
    const float window = s.WindowSeconds(Tune());

    s.BeginSlip(0.0f, Tune());
    CHECK(s.Resolve(window * 1.001f, true, m, Tune()) == SlipOutcome::Fell);
    CHECK(m.grip == doctest::Approx(0.0f));
}

TEST_CASE("a second trigger does not re-arm a slip already running")
{
    SlipModel s;
    Meters m = Slipping();
    const float window = s.WindowSeconds(Tune());

    s.BeginSlip(0.0f, Tune());
    s.BeginSlip(window * 0.9f, Tune());   // an anchor goes while you are already coming off

    // If the second call had restarted the clock, this would still be open.
    CHECK(s.Resolve(window, false, m, Tune()) == SlipOutcome::Fell);
}

// ---------------------------------------------------------------- what a save costs

TEST_CASE("a save leaves grip at the tuned fraction and takes the nerve shock")
{
    SlipModel s;
    Meters m = Slipping();
    const float before = m.nerve;

    s.BeginSlip(0.0f, Tune());
    REQUIRE(s.Resolve(0.1f, true, m, Tune()) == SlipOutcome::Saved);

    CHECK(m.grip
          == doctest::Approx(Tune().GetF("gripMax") * Tune().GetF("slipSaveGripFraction")));
    CHECK(m.nerve == doctest::Approx(before + Tune().GetF("nerveShock.slipSave")));

    // Acceptance 3 names 15% and −25. Asserted against the data, for the same reason as the window.
    CHECK(Tune().GetF("slipSaveGripFraction") == doctest::Approx(0.15f));
    CHECK(Tune().GetF("nerveShock.slipSave") == doctest::Approx(-25.0f));
}

TEST_CASE("grabbing at nothing is not free grip")
{
    // The one that would ruin the game quietly: if Resolve paid out without a slip in progress,
    // holding the grab key would top your hands up for ever and the meter would decide nothing.
    SlipModel s;
    Meters m = Slipping();

    for (int i = 0; i < 100; ++i)
    {
        CHECK(s.Resolve(static_cast<float>(i) * 0.1f, true, m, Tune()) == SlipOutcome::None);
    }
    CHECK(m.grip == doctest::Approx(0.0f));
    CHECK(m.nerve == doctest::Approx(m.nerveMax));
}

// ---------------------------------------------------------------- the budget

TEST_CASE("the budget is one save per cooldown")
{
    SlipModel s;
    Meters m = Slipping();
    const float cooldown = s.CooldownSeconds(Tune());

    CHECK(s.CanSlipSave(0.0f, Tune()));   // the first slip of a shift is always savable
    s.BeginSlip(0.0f, Tune());
    REQUIRE(s.Resolve(0.1f, true, m, Tune()) == SlipOutcome::Saved);

    // Inside the cooldown there is no window at all — you are falling from the moment you slip,
    // which is the point of the budget.
    CHECK_FALSE(s.CanSlipSave(cooldown * 0.5f, Tune()));
    CHECK(s.BeginSlip(cooldown * 0.5f, Tune()) == doctest::Approx(0.0f));
    CHECK(s.Resolve(cooldown * 0.5f, true, m, Tune()) == SlipOutcome::Fell);

    // Acceptance 2, stated as the design states it.
    CHECK(Tune().GetF("difficulty.jack.slipSaveCooldownSeconds") == doctest::Approx(60.0f));
}

TEST_CASE("the budget comes back")
{
    SlipModel s;
    Meters m = Slipping();
    const float cooldown = s.CooldownSeconds(Tune());

    s.BeginSlip(0.0f, Tune());
    REQUIRE(s.Resolve(0.1f, true, m, Tune()) == SlipOutcome::Saved);

    CHECK(s.CanSlipSave(0.1f + cooldown, Tune()));
    m.grip = 0.0f;
    CHECK(s.BeginSlip(0.1f + cooldown, Tune()) == doctest::Approx(s.WindowSeconds(Tune())));
}

TEST_CASE("a fall does not spend the budget")
{
    // Falling has already cost you the shift. Charging the budget for it as well would mean the
    // save you never got was also the save you cannot have next time.
    SlipModel s;
    Meters m = Slipping();

    s.BeginSlip(0.0f, Tune());
    REQUIRE(s.Resolve(s.WindowSeconds(Tune()), false, m, Tune()) == SlipOutcome::Fell);
    CHECK(s.CanSlipSave(1.0f, Tune()));
}

TEST_CASE("the telegraph fraction runs from one to zero")
{
    SlipModel s;
    const float window = s.WindowSeconds(Tune());

    CHECK(s.WindowFractionLeft(0.0f) == doctest::Approx(0.0f));   // nothing slipping, nothing drawn
    s.BeginSlip(0.0f, Tune());
    CHECK(s.WindowFractionLeft(0.0f) == doctest::Approx(1.0f));
    CHECK(s.WindowFractionLeft(window * 0.5f) == doctest::Approx(0.5f));
    CHECK(s.WindowFractionLeft(window) == doctest::Approx(0.0f));
    CHECK(s.WindowFractionLeft(window * 2.0f) == doctest::Approx(0.0f));   // clamped, never negative
}

// ---------------------------------------------------------------- the fall

TEST_CASE("one hand on a rung is tied to nothing")
{
    CHECK_FALSE(sj::IsTiedOn(Stance::OneHand));
    CHECK_FALSE(sj::IsTiedOn(Stance::HookedLeg));
    CHECK(sj::IsTiedOn(Stance::Clipped));
    CHECK(sj::IsTiedOn(Stance::Belted));
    CHECK(sj::IsTiedOn(Stance::Chair));
}

TEST_CASE("an unclipped fall is not caught and loads nothing")
{
    Meters m = Slipping();
    m.stance = Stance::OneHand;
    const float before = m.nerve;

    Anchor a{};
    a.capacityKN = Tune().GetF("anchorCapacityKN.sound");

    const sj::FallResult r = sj::ResolveFall(m, a, Tune());
    CHECK_FALSE(r.caught);
    CHECK_FALSE(r.anchorFailed);
    CHECK(r.shockLoadKN == doctest::Approx(0.0f));
    CHECK(m.nerve == doctest::Approx(before));   // the shift is over; nerve is not the cost
}

TEST_CASE("a sound anchor holds the shock load and a fair one does not")
{
    // The shock load is the player's weight times the dynamic factor, and the anchor table is
    // what decides. Both come out of the tuning, so this reads as the designer's arithmetic
    // rather than as three numbers agreeing by coincidence.
    const float shock = Tune().GetF("playerLoadKN") * Tune().GetF("dynamicLoadFactor");
    REQUIRE(shock > Tune().GetF("anchorCapacityKN.fair"));
    REQUIRE(shock < Tune().GetF("anchorCapacityKN.sound"));

    Meters m = Slipping();
    m.stance = Stance::Belted;
    Anchor sound{};
    sound.capacityKN = Tune().GetF("anchorCapacityKN.sound");

    const sj::FallResult held = sj::ResolveFall(m, sound, Tune());
    CHECK(held.caught);
    CHECK_FALSE(held.anchorFailed);
    CHECK(held.shockLoadKN == doctest::Approx(shock));
    CHECK(held.capacityKN == doctest::Approx(sound.capacityKN));
    CHECK(m.nerve == doctest::Approx(m.nerveMax + Tune().GetF("nerveShock.caughtByLine")));

    Meters m2 = Slipping();
    m2.stance = Stance::Belted;
    Anchor fair{};
    fair.capacityKN = Tune().GetF("anchorCapacityKN.fair");

    const sj::FallResult gone = sj::ResolveFall(m2, fair, Tune());
    CHECK_FALSE(gone.caught);
    CHECK(gone.anchorFailed);
    CHECK(m2.nerve == doctest::Approx(m2.nerveMax + Tune().GetF("nerveShock.anchorFail")));
}

TEST_CASE("a failed anchor cannot catch you")
{
    Meters m = Slipping();
    m.stance = Stance::Clipped;
    Anchor dud{};   // the default: unplaced, rate Failed, zero capacity

    const sj::FallResult r = sj::ResolveFall(m, dud, Tune());
    CHECK_FALSE(r.caught);
    CHECK(r.anchorFailed);
}
