#include "Jack.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "JointGrid.h"
#include "Recovery.h"
#include "Rng.h"
#include "Slip.h"
#include "Stack.h"
#include "Wind.h"
#include "Verbs/Hammer.h"
#include "Verbs/Haul.h"
#include "Verbs/Lash.h"
#include "Verbs/Tap.h"
#include "Wobble.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>

using namespace godot;

namespace steeplejack {
namespace {

const char* StanceName(sj::Stance s)
{
	switch (s)
	{
	case sj::Stance::OneHand:   return "one hand on rung";
	case sj::Stance::HookedLeg: return "leg hooked through";
	case sj::Stance::Clipped:   return "clipped on";
	case sj::Stance::Belted:    return "belted to the stack";
	case sj::Stance::Chair:     return "sat into the chair";
	}
	return "";
}

const char* TierName(sj::JointTier t)
{
	switch (t)
	{
	case sj::JointTier::Cracked:  return "cracked";
	case sj::JointTier::Perished: return "perished";
	case sj::JointTier::Fair:     return "fair";
	case sj::JointTier::Sound:    return "sound";
	}
	return "";
}

const char* RateName(sj::AnchorRate r)
{
	switch (r)
	{
	case sj::AnchorRate::Failed: return "failed";
	case sj::AnchorRate::Poor:   return "poor";
	case sj::AnchorRate::Fair:   return "fair";
	case sj::AnchorRate::Sound:  return "sound";
	}
	return "";
}

}  // namespace

void Jack::_bind_methods()
{
	ClassDB::bind_method(D_METHOD("load", "tuning_dir", "level_path"), &Jack::load);
	ClassDB::bind_method(D_METHOD("get_last_error"), &Jack::get_last_error);
	ClassDB::bind_method(D_METHOD("tuning_hash"), &Jack::tuning_hash);

	ClassDB::bind_method(D_METHOD("total_height"), &Jack::total_height);
	ClassDB::bind_method(D_METHOD("loadout_ladders"), &Jack::loadout_ladders);
	ClassDB::bind_method(D_METHOD("radius_at", "height"), &Jack::radius_at);
	ClassDB::bind_method(D_METHOD("band_count"), &Jack::band_count);
	ClassDB::bind_method(D_METHOD("band", "index"), &Jack::band);
	ClassDB::bind_method(D_METHOD("band_type_at", "height"), &Jack::band_type_at);
	ClassDB::bind_method(D_METHOD("level_name"), &Jack::level_name);

	ClassDB::bind_method(D_METHOD("set_context", "height", "wind_speed", "carrying_ladder", "working"),
	                     &Jack::set_context);
	ClassDB::bind_method(D_METHOD("set_exposure", "exposure"), &Jack::set_exposure);
	ClassDB::bind_method(D_METHOD("set_stance", "stance"), &Jack::set_stance);
	ClassDB::bind_method(D_METHOD("get_stance"), &Jack::get_stance);
	ClassDB::bind_method(D_METHOD("stance_name"), &Jack::stance_name);
	ClassDB::bind_method(D_METHOD("stance_name_of", "stance"), &Jack::stance_name_of);
	ClassDB::bind_method(D_METHOD("stance_setup_seconds", "stance"), &Jack::stance_setup_seconds);
	ClassDB::bind_method(D_METHOD("stance_needs_rigging", "from", "to"), &Jack::stance_needs_rigging);
	ClassDB::bind_method(D_METHOD("stance_drain_rate", "stance"), &Jack::stance_drain_rate);

	ClassDB::bind_method(D_METHOD("step", "dt"), &Jack::step);
	ClassDB::bind_method(D_METHOD("grip"), &Jack::grip);
	ClassDB::bind_method(D_METHOD("nerve"), &Jack::nerve);
	ClassDB::bind_method(D_METHOD("nerve_max"), &Jack::nerve_max);
	ClassDB::bind_method(D_METHOD("tremoring"), &Jack::tremoring);
	ClassDB::bind_method(D_METHOD("slipping"), &Jack::slipping);
	ClassDB::bind_method(D_METHOD("frozen"), &Jack::frozen);
	ClassDB::bind_method(D_METHOD("nerve_band"), &Jack::nerve_band);
	ClassDB::bind_method(D_METHOD("seconds_of_work_left"), &Jack::seconds_of_work_left);
	ClassDB::bind_method(D_METHOD("shock", "event"), &Jack::shock);
	ClassDB::bind_method(D_METHOD("wobble_deg", "gust"), &Jack::wobble_deg);

	ClassDB::bind_method(D_METHOD("set_on_platform", "on"), &Jack::set_on_platform);
	ClassDB::bind_method(D_METHOD("recover_start", "action", "both_hands_free", "facing_out"),
	                     &Jack::recover_start);
	ClassDB::bind_method(D_METHOD("recover_interrupt"), &Jack::recover_interrupt);
	ClassDB::bind_method(D_METHOD("recover_action"), &Jack::recover_action);
	ClassDB::bind_method(D_METHOD("recover_progress"), &Jack::recover_progress);

	ClassDB::bind_method(D_METHOD("wind_at", "height"), &Jack::wind_at);
	ClassDB::bind_method(D_METHOD("gust_tell"), &Jack::gust_tell);
	ClassDB::bind_method(D_METHOD("gust_tell_progress"), &Jack::gust_tell_progress);
	ClassDB::bind_method(D_METHOD("gust_strength"), &Jack::gust_strength);
	ClassDB::bind_method(D_METHOD("level_has_gusts"), &Jack::level_has_gusts);

	ClassDB::bind_method(D_METHOD("set_difficulty", "difficulty"), &Jack::set_difficulty);
	ClassDB::bind_method(D_METHOD("get_difficulty"), &Jack::get_difficulty);
	ClassDB::bind_method(D_METHOD("grab"), &Jack::grab);
	ClassDB::bind_method(D_METHOD("slip_now"), &Jack::slip_now);
	ClassDB::bind_method(D_METHOD("grip_hit", "amount"), &Jack::grip_hit);
	ClassDB::bind_method(D_METHOD("slip_in_progress"), &Jack::slip_in_progress);
	ClassDB::bind_method(D_METHOD("slip_window_left"), &Jack::slip_window_left);
	ClassDB::bind_method(D_METHOD("slip_window_seconds"), &Jack::slip_window_seconds);
	ClassDB::bind_method(D_METHOD("can_slip_save"), &Jack::can_slip_save);
	ClassDB::bind_method(D_METHOD("last_slip_outcome"), &Jack::last_slip_outcome);
	ClassDB::bind_method(D_METHOD("fall", "height"), &Jack::fall);
	ClassDB::bind_method(D_METHOD("new_shift"), &Jack::new_shift);
	ClassDB::bind_method(D_METHOD("save_stack"), &Jack::save_stack);
	ClassDB::bind_method(D_METHOD("restore_stack", "json"), &Jack::restore_stack);
	ClassDB::bind_method(D_METHOD("stack_sections"), &Jack::stack_sections);

	ClassDB::bind_method(D_METHOD("climb_bearing"), &Jack::climb_bearing);
	ClassDB::bind_method(D_METHOD("joint_count"), &Jack::joint_count);
	ClassDB::bind_method(D_METHOD("joints_near", "height", "bearing_deg", "range"), &Jack::joints_near);
	ClassDB::bind_method(D_METHOD("nearest_joint", "point", "max_range"), &Jack::nearest_joint);
	ClassDB::bind_method(D_METHOD("joint", "id"), &Jack::joint);
	ClassDB::bind_method(D_METHOD("tap_joint", "id", "wearing_gloves"), &Jack::tap_joint);
	ClassDB::bind_method(D_METHOD("strike_joint", "id", "current_depth", "power", "angle_error_deg",
	                              "tool_condition"), &Jack::strike_joint);
	ClassDB::bind_method(D_METHOD("seat_anchor_joint", "id", "depth", "spall"),
	                     &Jack::seat_anchor_joint);
	ClassDB::bind_method(D_METHOD("spoil_joint", "id"), &Jack::spoil_joint);

	ClassDB::bind_method(D_METHOD("stack_lash", "dog_height", "lashing"), &Jack::stack_lash);
	ClassDB::bind_method(D_METHOD("stack_top"), &Jack::stack_top);
	ClassDB::bind_method(D_METHOD("stack_step", "dt", "height", "on_ladder"), &Jack::stack_step);
	ClassDB::bind_method(D_METHOD("stack_section_at", "height"), &Jack::stack_section_at);
	ClassDB::bind_method(D_METHOD("anchor_failed", "index"), &Jack::anchor_failed);

	ClassDB::bind_method(D_METHOD("haul_begin", "top_m"), &Jack::haul_begin);
	ClassDB::bind_method(D_METHOD("haul_step", "dt", "pull", "steer", "wind_ms", "load_kg"),
	                     &Jack::haul_step);

	ClassDB::bind_method(D_METHOD("lash_begin"), &Jack::lash_begin);
	ClassDB::bind_method(D_METHOD("lash_step", "dt", "turns_per_second"), &Jack::lash_step);
	ClassDB::bind_method(D_METHOD("lash_state"), &Jack::lash_state);
	ClassDB::bind_method(D_METHOD("lash_tie_off"), &Jack::lash_tie_off);
	ClassDB::bind_method(D_METHOD("lash_rate_from_mash", "presses_per_second"), &Jack::lash_rate_from_mash);
	ClassDB::bind_method(D_METHOD("lash_rate_from_hold"), &Jack::lash_rate_from_hold);
	ClassDB::bind_method(D_METHOD("lash_drift_cm_per_minute", "lashing"), &Jack::lash_drift_cm_per_minute);
	ClassDB::bind_method(D_METHOD("lash_lay_rate", "turns_per_second"), &Jack::lash_lay_rate);

	ClassDB::bind_method(D_METHOD("tap", "height", "wearing_gloves"), &Jack::tap);
	ClassDB::bind_method(D_METHOD("strike", "height", "current_depth", "power", "angle_error_deg",
	                              "tool_condition"), &Jack::strike);
	ClassDB::bind_method(D_METHOD("seat_depth"), &Jack::seat_depth);
	ClassDB::bind_method(D_METHOD("seat_anchor", "height", "depth", "spall"), &Jack::seat_anchor);
	ClassDB::bind_method(D_METHOD("anchor_count"), &Jack::anchor_count);
	ClassDB::bind_method(D_METHOD("anchor_at", "index"), &Jack::anchor_at);
	ClassDB::bind_method(D_METHOD("highest_anchor_below", "height"), &Jack::highest_anchor_below);

	ClassDB::bind_method(D_METHOD("classify_span", "span"), &Jack::classify_span);
	ClassDB::bind_method(D_METHOD("span_name", "band"), &Jack::span_name);
	ClassDB::bind_method(D_METHOD("grip_drain_multiplier", "band"), &Jack::grip_drain_multiplier);
	ClassDB::bind_method(D_METHOD("nerve_drain_multiplier", "band"), &Jack::nerve_drain_multiplier);
	ClassDB::bind_method(D_METHOD("tuning_f", "key", "fallback"), &Jack::tuning_f, DEFVAL(0.0));
}

// Every method below is a firebreak. The sim throws by design — a missing tuning key must never
// read as zero — and an exception crossing a C ABI is undefined behaviour rather than an error
// message. So the loud failure is caught here and converted into something Godot can see.
bool Jack::load(const String& tuning_dir, const String& level_path)
{
	try
	{
		tuning = std::make_unique<sj::Tuning>(sj::Tuning::LoadAll(tuning_dir.utf8().get_data()));
		const std::string path = level_path.utf8().get_data();
		level = std::make_unique<sj::LevelData>(sj::LevelData::LoadFrom(path));
		{
			std::ifstream in(path, std::ios::binary);
			std::stringstream text;
			text << in.rdbuf();
			level_fingerprint = sj::save::LevelFingerprint(text.str());
			level_id = std::filesystem::path(path).stem().string();
		}
		meters = sj::nerve::FreshShift(*tuning);
		meters.stance = sj::Stance::OneHand;
		meters.exposure = sj::Exposure::Platform;
		stack = sj::Stack{};
		// A new shift is a new clock and a new budget. Without this, loading a second level
		// inherits the first one's cooldown and the first slip of the new level is unsaveable.
		now = 0.0f;
		// The weather gets its own substream off the level's seed, so the gusts are the same on
		// every machine and in every replay, and so that adding another subsystem later cannot
		// shift them (Rng::Fork is const for exactly that reason).
		weather_rng = std::make_unique<sj::Rng>(
			sj::Rng(level->Structure().weatherSeed).Fork(0x57494E44u));   // literal: 'WIND'
		wind.Begin(level->Weather(), *weather_rng, *tuning);
		// The face, from the level's own seed, on the grid's own fork — so nothing else in the sim
		// drawing random numbers can move a single joint.
		grid = std::make_unique<sj::JointGrid>(sj::JointGrid::Generate(
			*level, sj::Rng(level->Structure().weatherSeed), *tuning, kClimbBearing));
		tapped.clear();

		// The old fixtures: dogs a previous jack left, already in the wall beside the ladder line,
		// not part of the ladder until somebody lashes to one. Their rating is real and hidden;
		// their rust is what shows.
		fixture_rust.clear();
		for (const sj::FixtureSpec& f :
		     sj::anchor::OldFixtures(*level, sj::Rng(level->Structure().weatherSeed), *tuning))
		{
			const int32_t jid = joint_id_at(static_cast<double>(f.height));
			if (jid < 0) { continue; }
			const sj::Joint& j = grid->ById(jid);
			sj::Anchor a = sj::anchor::Make(j, 1.0f, f.rust, *tuning);
			a.jointId = jid;
			a.height = j.height;
			a.freeFixture = true;
			const int32_t idx = stack.AddAnchor(a);
			grid->SetOccupied(jid, true);
			fixture_rust[idx] = f.rust;
		}
		slip = sj::SlipModel(slip.GetDifficulty());
		outcome = sj::SlipOutcome::None;
		grab_latched = false;
		last_error = String();
		return true;
	}
	catch (const std::exception& e)
	{
		tuning.reset();
		level.reset();
		last_error = String(e.what());
		UtilityFunctions::push_error("jack: ", last_error);
		return false;
	}
}

String Jack::tuning_hash() const
{
	return tuning ? String(tuning->Hash().c_str()) : String();
}

int64_t Jack::loadout_ladders() const
{
	return level ? static_cast<int64_t>(level->LoadoutLadders()) : 0;
}

double Jack::total_height() const
{
	return level ? static_cast<double>(level->TotalHeight()) : 0.0;
}

double Jack::radius_at(double height) const
{
	if (!level) { return 0.0; }
	const sj::StructureSpec& s = level->Structure();
	const float h = static_cast<float>(height);
	const float t = s.height > 0.0f ? std::clamp(h / s.height, 0.0f, 1.0f) : 0.0f;
	return static_cast<double>(s.baseRadius + (s.topRadius - s.baseRadius) * t);
}

int64_t Jack::band_count() const
{
	return level ? static_cast<int64_t>(level->Bands().size()) : 0;
}

Dictionary Jack::band(int64_t index) const
{
	Dictionary d;
	if (!level || index < 0 || index >= static_cast<int64_t>(level->Bands().size())) { return d; }
	const sj::BandSpec& b = level->Bands()[static_cast<size_t>(index)];
	d["from"] = static_cast<double>(b.from);
	d["to"] = static_cast<double>(b.to);
	d["type"] = String(b.type.c_str());
	return d;
}

String Jack::band_type_at(double height) const
{
	if (!level) { return String(); }
	try
	{
		return String(level->BandAt(static_cast<float>(height)).type.c_str());
	}
	catch (const std::exception&)
	{
		// Above the stack. Not an error — the player can stand on top of it.
		return String();
	}
}

String Jack::level_name() const
{
	return level ? String(level->Name().c_str()) : String();
}

void Jack::set_context(double height, double wind_speed, bool carrying_ladder, bool working)
{
	context.height = static_cast<float>(height);
	context.windSpeed = static_cast<float>(wind_speed);
	context.carryingLadder = carrying_ladder;
	context.working = working;
}

void Jack::set_exposure(int exposure)
{
	meters.exposure = static_cast<sj::Exposure>(std::clamp(exposure, 0, 3));
}

void Jack::set_stance(int stance)
{
	meters.stance = static_cast<sj::Stance>(std::clamp(stance, 0, 4));
}

String Jack::stance_name() const
{
	return String(StanceName(meters.stance));
}

void Jack::step(double dt)
{
	if (!tuning) { return; }
	const float d = static_cast<float>(dt);
	now += d;
	if (level && weather_rng)
	{
		wind.Step(d, level->Weather(), *weather_rng, *tuning);
	}
	sj::grip::Step(meters, d, context, *tuning);
	sj::nerve::Step(meters, d, context, *tuning);
	// Getting it back: where you are, and whatever you are doing about it.
	meters.nerve = std::clamp(
		meters.nerve + sj::recover::PassiveRate(context, on_platform, *tuning) * d, 0.0f, meters.nerveMax);
	(void)sj::recover::Step(recovery, meters, d, *tuning);

	// Grip reaching zero is a slip, and the slip opens and closes here rather than in GDScript.
	// Both halves in one place is the only way the window cannot be left open by a script that
	// returned early — and an early return is the normal shape of a _physics_process.
	if (sj::grip::Slipping(meters))
	{
		slip.BeginSlip(now, *tuning);
	}
	else
	{
		// Grip is back, so the hand is back on and he can lose it again. The two calls are the two
		// halves of one edge; dropping this one leaves a climber who slipped once unable to slip
		// for the rest of the shift.
		slip.HandBackOn();
	}
	outcome = slip.Resolve(now, grab_latched, meters, *tuning);
	grab_latched = false;
}

String Jack::save_stack() const
{
	try
	{
		if (!tuning) { return String(); }
		return String(sj::save::SerialiseStack(stack, level_id, level_fingerprint).c_str());
	}
	catch (const std::exception& e)
	{
		UtilityFunctions::push_error("jack: save_stack: ", e.what());
		return String();
	}
}

bool Jack::restore_stack(const String& json)
{
	try
	{
		if (!tuning || !grid) { return false; }
		sj::Stack restored = sj::save::RestoreStack(json.utf8().get_data(), level_id, level_fingerprint);
		stack = std::move(restored);
		for (int32_t i = 1; i < stack.AnchorCount(); ++i)
		{
			const int32_t jid = stack.AnchorAt(i).jointId;
			if (jid >= 0) { grid->SetOccupied(jid, true); }
		}
		return true;
	}
	catch (const std::exception& e)
	{
		last_error = String(e.what());
		return false;
	}
}

Array Jack::stack_sections() const
{
	Array out;
	for (int32_t i = 0; i < stack.SectionCount(); ++i)
	{
		const sj::Section& sec = stack.SectionAt(i);
		const sj::Anchor& up = stack.AnchorAt(sec.upperAnchor);
		Dictionary d;
		d["upper_joint"] = static_cast<int64_t>(up.jointId);
		d["upper_height"] = static_cast<double>(up.height);
		d["lashing"] = static_cast<int64_t>(sec.lashing);
		d["failed"] = stack.SectionFailed(i);
		out.append(d);
	}
	return out;
}

void Jack::new_shift()
{
	if (!tuning) { return; }
	meters = sj::nerve::FreshShift(*tuning);
	meters.exposure = sj::Exposure::Platform;
	// The clock keeps running. It is the cooldown's clock, and a slip-save budget that reset every
	// time you fell would reward falling.
	slip.HandBackOn();
	outcome = sj::SlipOutcome::None;
	grab_latched = false;
}

String Jack::stance_name_of(int stance) const
{
	return String(StanceName(static_cast<sj::Stance>(std::clamp(stance, 0, 4))));
}

double Jack::stance_setup_seconds(int stance) const
{
	if (!tuning) { return 0.0; }
	return static_cast<double>(
		sj::grip::SetupSeconds(static_cast<sj::Stance>(std::clamp(stance, 0, 4)), *tuning));
}

bool Jack::stance_needs_rigging(int from, int to) const
{
	return sj::grip::NeedsRigging(static_cast<sj::Stance>(std::clamp(from, 0, 4)),
	                              static_cast<sj::Stance>(std::clamp(to, 0, 4)));
}

double Jack::stance_drain_rate(int stance) const
{
	if (!tuning) { return 0.0; }
	return static_cast<double>(
		sj::grip::DrainRate(static_cast<sj::Stance>(std::clamp(stance, 0, 4)), context, *tuning));
}

double Jack::wind_at(double height) const
{
	if (!level || !tuning) { return 0.0; }
	return static_cast<double>(
		wind.SpeedAt(static_cast<float>(height), level->Weather(), *tuning));
}

bool Jack::gust_tell() const { return wind.Tell(); }
double Jack::gust_strength() const { return static_cast<double>(wind.Strength()); }
bool Jack::level_has_gusts() const { return level && level->Weather().hasGusts; }

double Jack::gust_tell_progress() const
{
	return tuning ? static_cast<double>(wind.TellProgress(*tuning)) : 0.0;
}

String Jack::recover_start(int action, bool both_hands_free, bool facing_out)
{
	if (!tuning) { return String("no tuning"); }
	const sj::Recovery a = static_cast<sj::Recovery>(std::clamp(action, 0, 3));
	const sj::Refusal r = sj::recover::CanStart(a, meters, context, both_hands_free, facing_out, *tuning);
	if (!r.ok()) { return String(std::string(r.why).c_str()); }
	sj::recover::Begin(recovery, a, meters, *tuning);
	return String();
}

void Jack::recover_interrupt() { sj::recover::Interrupt(recovery); }

double Jack::recover_progress() const
{
	return tuning ? static_cast<double>(sj::recover::Progress(recovery, *tuning)) : 0.0;
}

void Jack::set_difficulty(int difficulty)
{
	slip.SetDifficulty(static_cast<sj::Difficulty>(std::clamp(difficulty, 0, 2)));
}

void Jack::grab()
{
	grab_latched = true;
}

void Jack::grip_hit(double amount)
{
	meters.grip = std::max(0.0f, meters.grip - static_cast<float>(amount));
}

void Jack::slip_now()
{
	if (!tuning) { return; }
	sj::nerve::Shock(meters, "anchorFail", *tuning);
	slip.BeginSlip(now, *tuning);
}

double Jack::slip_window_left() const
{
	return static_cast<double>(slip.WindowFractionLeft(now));
}

double Jack::slip_window_seconds() const
{
	return tuning ? static_cast<double>(slip.WindowSeconds(*tuning)) : 0.0;
}

bool Jack::can_slip_save() const
{
	return tuning && slip.CanSlipSave(now, *tuning);
}

Dictionary Jack::fall(double height)
{
	Dictionary d;
	if (!tuning) { return d; }

	// Whatever you are tied to is the highest dog below you — the same one the ladder is lashed to
	// and the same one the span is measured from. A default Anchor is rate Failed with zero
	// capacity, which is the right answer when there is nothing below you at all.
	int32_t tied_id = -1;
	sj::Anchor tied{};
	for (int32_t i = 1; i < stack.AnchorCount(); ++i)
	{
		const sj::Anchor& a = stack.AnchorAt(i);
		if (!stack.AnchorFailed(i) && static_cast<double>(a.height) <= height + 0.01
		    && a.height >= tied.height)
		{
			tied = a;
			tied_id = i;
		}
	}

	const sj::FallResult r = sj::ResolveFall(meters, tied, *tuning);
	d["tied_on"] = sj::IsTiedOn(meters.stance);
	d["caught"] = r.caught;
	d["anchor_failed"] = r.anchorFailed;
	d["shock_kn"] = static_cast<double>(r.shockLoadKN);
	d["capacity_kn"] = static_cast<double>(r.capacityKN);

	// The half of METER-005 that waited for CLIMB-002. A dog that lets go under the line's shock
	// drops that shock onto the next one down, and the one below that — the grimmest moment in the
	// game, and one the player can trace, because the order comes back.
	Array cascade;
	if (r.anchorFailed && tied_id > 0)
	{
		for (int32_t i : stack.Cascade(tied_id, r.shockLoadKN * tuning->GetF("cascadeShockRetained"),
		                               *tuning))
		{
			cascade.append(static_cast<double>(stack.AnchorAt(i).height));
			if (grid) { grid->SetOccupied(stack.AnchorAt(i).jointId, true); }
		}
	}
	d["cascade"] = cascade;
	return d;
}

bool Jack::tremoring() const { return tuning && sj::grip::Tremor(meters, *tuning); }
bool Jack::slipping() const { return sj::grip::Slipping(meters); }
bool Jack::frozen() const { return sj::nerve::Frozen(meters); }

int64_t Jack::nerve_band() const
{
	return tuning ? static_cast<int64_t>(sj::nerve::Band(meters.nerve, *tuning)) : 0;
}

double Jack::seconds_of_work_left() const
{
	return tuning ? static_cast<double>(sj::grip::SecondsOfWorkLeft(meters, context, *tuning)) : 0.0;
}

bool Jack::shock(const String& event)
{
	if (!tuning) { return false; }
	const std::string name = event.utf8().get_data();
	if (!sj::nerve::IsKnownShock(name, *tuning))
	{
		// Refused rather than ignored: a typo'd shock that silently does nothing is a balance bug
		// nobody ever finds.
		UtilityFunctions::push_error("jack: unknown nerve shock '", event, "'");
		return false;
	}
	sj::nerve::Shock(meters, name, *tuning);
	return true;
}

double Jack::wobble_deg(double gust) const
{
	if (!tuning) { return 0.0; }
	return static_cast<double>(
		sj::WobbleAmplitudeDeg(meters, context, static_cast<float>(gust), *tuning));
}

int32_t Jack::joint_id_at(double height) const
{
	if (!grid || !level) { return -1; }
	// The joint on the climbing line nearest this height. What the height-addressed verbs mean, and
	// all they could ever have meant: before the grid, a height *was* a joint.
	const sj::StructureSpec& s = level->Structure();
	const float h = static_cast<float>(height);
	const float u = s.height > 0.0f ? std::clamp(h / s.height, 0.0f, 1.0f) : 0.0f;
	const float r = s.baseRadius + (s.topRadius - s.baseRadius) * u;
	// Beside the ladder, not under it. The stiles are 0.44 m apart and the lashing runs from a stile
	// out to a lug, so a dog on the ladder's centre line is one no hammer can reach and no rope can
	// be tied to. 0.4 m round the face from the centre line, on the -Z side.
	const float d = 0.4f / std::max(r, 0.1f);   // literal: metres beside the ladder, as radians
	return grid->Nearest(sj::Vec3{-r * std::cos(d), h, -r * std::sin(d)}, 0.6f);   // literal: search
}

sj::Joint Jack::joint_at(double height) const
{
	// Read from the grid, so the band decides the brickwork. This used to be a hash of the height
	// with the band ignored, which made every band on every level play the same.
	if (!grid) { return sj::Joint{}; }
	return grid->ById(joint_id_at(height));
}

Dictionary Jack::joint_dict(int32_t id) const
{
	Dictionary d;
	if (!grid || !tuning) { return d; }
	const sj::Joint& j = grid->ById(id);
	if (j.id < 0) { return d; }
	d["id"] = static_cast<int64_t>(j.id);
	d["pos"] = Vector3(j.pos.x, j.pos.y, j.pos.z);
	d["normal"] = Vector3(j.normal.x, j.normal.y, j.normal.z);
	d["height"] = static_cast<double>(j.height);
	const float look = grid->Apparent(j.id);
	d["look_q"] = static_cast<double>(look);
	d["look"] = static_cast<int64_t>(sj::tap::TierOf(look, *tuning));
	d["occupied"] = j.occupied;
	const auto it = tapped.find(j.id);
	d["tapped"] = static_cast<int64_t>(it == tapped.end() ? -1 : it->second);
	return d;
}

Array Jack::joints_near(double height, double bearing_deg, double range) const
{
	Array out;
	if (!grid) { return out; }
	for (int32_t id : grid->Near(static_cast<float>(height), static_cast<float>(bearing_deg),
	                             static_cast<float>(range)))
	{
		out.append(joint_dict(id));
	}
	return out;
}

int64_t Jack::nearest_joint(const Vector3& point, double max_range) const
{
	if (!grid) { return -1; }
	return grid->Nearest(sj::Vec3{static_cast<float>(point.x), static_cast<float>(point.y),
	                              static_cast<float>(point.z)},
	                     static_cast<float>(max_range));
}

Dictionary Jack::joint(int64_t id) const
{
	return joint_dict(static_cast<int32_t>(id));
}

Dictionary Jack::tap_joint(int64_t id, bool wearing_gloves)
{
	Dictionary d;
	if (!tuning || !grid) { return d; }
	const sj::Joint& j = grid->ById(static_cast<int32_t>(id));
	if (j.id < 0) { return d; }
	const sj::TapResult r = sj::tap::Tap(j, *tuning, wearing_gloves);
	// What the player learned, not what is true — with gloves those differ by design, and the
	// chalk mark records the reading. See docs/01-gdd/15-working-the-face.md.
	tapped[j.id] = static_cast<int32_t>(r.tier);
	d["id"] = static_cast<int64_t>(j.id);
	d["tier"] = static_cast<int64_t>(r.tier);
	d["tier_name"] = String(TierName(r.tier));
	d["confidence"] = static_cast<double>(r.confidence);
	d["pip"] = static_cast<int64_t>(r.pipShape);
	return d;
}

Dictionary Jack::strike_joint(int64_t id, double current_depth, double power,
                              double angle_error_deg, double tool_condition)
{
	Dictionary d;
	if (!tuning || !grid) { return d; }
	const sj::StrikeResult r = sj::hammer::Strike(
		grid->ById(static_cast<int32_t>(id)), static_cast<float>(current_depth),
		static_cast<float>(power), static_cast<float>(angle_error_deg),
		static_cast<float>(tool_condition), *tuning);
	d["depth_gain"] = static_cast<double>(r.depthGain);
	d["spalled"] = static_cast<double>(r.spalled);
	d["bent"] = r.bent;
	d["seated"] = r.seated;
	d["quality"] = static_cast<double>(
		sj::hammer::StrikeQuality(static_cast<float>(angle_error_deg), *tuning));
	return d;
}

void Jack::haul_begin(double top_m)
{
	hauling = sj::HaulState{};
	haul_top = static_cast<float>(top_m);
}

Dictionary Jack::haul_step(double dt, double pull, double steer, double wind_ms, double load_kg)
{
	Dictionary d;
	if (!tuning) { return d; }
	sj::haul::Step(hauling, static_cast<float>(dt), static_cast<float>(pull),
	               static_cast<float>(steer), static_cast<float>(wind_ms),
	               static_cast<float>(load_kg), haul_top, *tuning);
	d["height"] = static_cast<double>(hauling.height);
	d["swing_deg"] = static_cast<double>(hauling.swingDeg);
	d["swing_vel"] = static_cast<double>(hauling.swingVel);
	d["amplitude"] = static_cast<double>(sj::haul::AmplitudeDeg(hauling, haul_top, *tuning));
	d["foul_at"] = static_cast<double>(tuning->GetF("haulFoulAmplitudeDegrees"));
	d["fouled"] = hauling.fouled;
	d["arrived"] = sj::haul::Arrived(hauling, haul_top);
	return d;
}

void Jack::lash_begin() { lashing = sj::LashState{}; }

void Jack::lash_step(double dt, double turns_per_second)
{
	if (!tuning) { return; }
	sj::lash::Step(lashing, static_cast<float>(dt), static_cast<float>(turns_per_second), *tuning);
}

Dictionary Jack::lash_state() const
{
	Dictionary d;
	d["wraps"] = static_cast<int64_t>(lashing.wraps);
	d["tension"] = static_cast<double>(lashing.tension);
	d["laid"] = static_cast<double>(lashing.laid);
	d["tied"] = lashing.tied;
	d["slipping"] = lashing.slipping;
	return d;
}

int64_t Jack::lash_tie_off()
{
	if (!tuning) { return 0; }
	return static_cast<int64_t>(sj::lash::TieOff(lashing, *tuning));
}

double Jack::lash_rate_from_mash(double presses_per_second) const
{
	return tuning ? static_cast<double>(
		sj::lash::RateFromMash(static_cast<float>(presses_per_second), *tuning)) : 0.0;
}

double Jack::lash_rate_from_hold() const
{
	return tuning ? static_cast<double>(sj::lash::RateFromHold(*tuning)) : 0.0;
}

double Jack::lash_drift_cm_per_minute(int64_t lashing_kind) const
{
	return tuning ? static_cast<double>(sj::lash::DriftPerMinuteCm(
		static_cast<sj::Lashing>(std::clamp<int64_t>(lashing_kind, 0, 2)), *tuning)) : 0.0;
}

double Jack::lash_lay_rate(double turns_per_second) const
{
	return tuning ? static_cast<double>(
		sj::lash::LayRate(static_cast<float>(turns_per_second), *tuning)) : 0.0;
}

void Jack::spoil_joint(int64_t id)
{
	if (grid) { grid->SetOccupied(static_cast<int32_t>(id), true); }
}

Dictionary Jack::seat_anchor_joint(int64_t id, double depth, double spall)
{
	Dictionary d;
	if (!tuning || !grid) { return d; }
	const sj::Joint& j = grid->ById(static_cast<int32_t>(id));
	if (j.id < 0) { return d; }
	sj::Anchor a = sj::anchor::Make(j, static_cast<float>(depth), static_cast<float>(spall), *tuning);
	a.jointId = j.id;
	a.height = j.height;
	stack.AddAnchor(a);
	grid->SetOccupied(j.id, true);
	d["rate"] = static_cast<int64_t>(a.rate);
	d["rate_name"] = String(RateName(a.rate));
	// What the same dog would have rated with the brick unbroken: when it is better, the spalling
	// is why this one is not, and the player should be told that rather than left to guess.
	const sj::AnchorRate clean = sj::anchor::Rate(j, static_cast<float>(depth), 0.0f, *tuning);
	d["rate_unspalled"] = static_cast<int64_t>(clean);
	d["rate_unspalled_name"] = String(RateName(clean));
	d["capacity_kn"] = static_cast<double>(a.capacityKN);
	d["height"] = static_cast<double>(a.height);
	d["id"] = static_cast<int64_t>(j.id);
	d["pos"] = Vector3(j.pos.x, j.pos.y, j.pos.z);
	return d;
}

Dictionary Jack::tap(double height, bool wearing_gloves)
{
	Dictionary d;
	if (!tuning) { return d; }
	const sj::TapResult r = sj::tap::Tap(joint_at(height), *tuning, wearing_gloves);
	d["tier"] = static_cast<int64_t>(r.tier);
	d["tier_name"] = String(TierName(r.tier));
	d["confidence"] = static_cast<double>(r.confidence);
	// A shape index, never a colour. Rule 8: the visual fallback for a sound must not be a hue.
	d["pip"] = static_cast<int64_t>(r.pipShape);
	return d;
}

Dictionary Jack::strike(double height, double current_depth, double power,
                        double angle_error_deg, double tool_condition)
{
	Dictionary d;
	if (!tuning) { return d; }
	const sj::StrikeResult r = sj::hammer::Strike(
		joint_at(height), static_cast<float>(current_depth), static_cast<float>(power),
		static_cast<float>(angle_error_deg), static_cast<float>(tool_condition), *tuning);
	d["depth_gain"] = static_cast<double>(r.depthGain);
	d["spalled"] = static_cast<double>(r.spalled);
	d["bent"] = r.bent;
	d["seated"] = r.seated;
	d["quality"] = static_cast<double>(
		sj::hammer::StrikeQuality(static_cast<float>(angle_error_deg), *tuning));
	return d;
}

double Jack::seat_depth() const
{
	return tuning ? static_cast<double>(sj::hammer::SeatDepth(*tuning)) : 1.0;
}

Dictionary Jack::seat_anchor(double height, double depth, double spall)
{
	Dictionary d;
	if (!tuning) { return d; }
	const int32_t jid = joint_id_at(height);
	sj::Anchor a = sj::anchor::Make(joint_at(height), static_cast<float>(depth),
	                                static_cast<float>(spall), *tuning);
	a.jointId = jid;
	stack.AddAnchor(a);
	if (grid && jid >= 0) { grid->SetOccupied(jid, true); }
	d["rate"] = static_cast<int64_t>(a.rate);
	d["rate_name"] = String(RateName(a.rate));
	d["capacity_kn"] = static_cast<double>(a.capacityKN);
	d["height"] = static_cast<double>(a.height);
	return d;
}

Dictionary Jack::anchor_at(int64_t index) const
{
	Dictionary d;
	if (index < 0 || index >= anchor_count()) { return d; }
	const sj::Anchor& a = stack.AnchorAt(static_cast<int32_t>(index) + 1);
	d["failed"] = stack.AnchorFailed(static_cast<int32_t>(index) + 1);
	d["joint"] = static_cast<int64_t>(a.jointId);
	d["fixture"] = a.freeFixture;
	{
		const auto it = fixture_rust.find(static_cast<int32_t>(index) + 1);
		d["rust"] = static_cast<double>(it == fixture_rust.end() ? 0.0f : it->second);
	}
	d["rate"] = static_cast<int64_t>(a.rate);
	d["rate_name"] = String(RateName(a.rate));
	d["capacity_kn"] = static_cast<double>(a.capacityKN);
	d["height"] = static_cast<double>(a.height);
	return d;
}

double Jack::highest_anchor_below(double height) const
{
	double best = -1.0;
	for (int32_t i = 1; i < stack.AnchorCount(); ++i)
	{
		const sj::Anchor& a = stack.AnchorAt(i);
		if (!stack.AnchorFailed(i) && a.rate != sj::AnchorRate::Failed
		    && static_cast<double>(a.height) <= height + 0.01)
		{
			best = std::max(best, static_cast<double>(a.height));
		}
	}
	return best;
}

// --- the stack ------------------------------------------------------------------------------------

namespace {
int32_t StackIndexAt(const sj::Stack& s, double height)
{
	for (int32_t i = 1; i < s.AnchorCount(); ++i)
	{
		if (!s.AnchorFailed(i) && std::fabs(static_cast<double>(s.AnchorAt(i).height) - height) < 0.01)
		{
			return i;
		}
	}
	return -1;
}
}  // namespace

int64_t Jack::stack_lash(double dog_height, int64_t lashing_kind)
{
	const int32_t upper = StackIndexAt(stack, dog_height);
	if (upper < 0) { return -1; }
	// From the top of the stack as it stands — the last dog a ladder was lashed to, or the ground.
	// Not the last dog *driven*: a dog you drove and never lashed to is not part of the ladder, and
	// measuring the span from it would make a 7 m section look like a 30 cm one.
	const int32_t lower = stack.TopOfStructure();
	return stack.AddSection(lower, upper,
		static_cast<sj::Lashing>(std::clamp<int64_t>(lashing_kind, 0, 2)));
}

double Jack::stack_top() const
{
	return static_cast<double>(stack.TopHeight());
}

bool Jack::anchor_failed(int64_t index) const
{
	return stack.AnchorFailed(static_cast<int32_t>(index) + 1);
}

Dictionary Jack::stack_section_at(double height) const
{
	Dictionary d;
	const int32_t sec = stack.SectionAt(static_cast<float>(height));
	d["section"] = static_cast<int64_t>(sec);
	if (sec < 0 || !tuning) { return d; }
	const sj::Section& s = stack.SectionAt(sec);
	d["span"] = static_cast<double>(s.span);
	d["band"] = static_cast<int64_t>(stack.Band(sec, *tuning));
	d["lashing"] = static_cast<int64_t>(s.lashing);
	d["drift_cm"] = static_cast<double>(stack.SectionDriftCm(sec));
	d["walk_off_cm"] = static_cast<double>(tuning->GetF("lashHitchWalkOffCm"));
	d["flex_m"] = static_cast<double>(
		stack.FlexDeflectionM(sec, tuning->GetF("playerLoadKN"), *tuning));
	d["section_lower"] = static_cast<double>(stack.AnchorAt(s.lowerAnchor).height);
	d["section_upper"] = static_cast<double>(stack.AnchorAt(s.upperAnchor).height);
	return d;
}

Dictionary Jack::stack_step(double dt, double height, bool on_ladder)
{
	Dictionary d = stack_section_at(height);
	if (!tuning) { return d; }
	const int32_t sec = on_ladder ? stack.SectionAt(static_cast<float>(height)) : -1;
	const sj::StackEvents ev = stack.Step(static_cast<float>(dt), sec,
	                                      tuning->GetF("playerLoadKN"), *tuning);
	Array failed;
	for (int32_t i : ev.failedAnchors)
	{
		failed.append(static_cast<double>(stack.AnchorAt(i).height));
	}
	d["failed"] = failed;
	bool mine = false;
	for (int32_t f : ev.failedSections)
	{
		mine = mine || f == sec;
	}
	d["section_failed"] = mine;
	d["any_section_failed"] = !ev.failedSections.empty();
	d["buckling"] = ev.buckling >= 0;
	d["buckle_left"] = static_cast<double>(ev.buckleSecondsLeft);
	d["drift_cm"] = static_cast<double>(stack.SectionDriftCm(sec));
	return d;
}

int64_t Jack::classify_span(double span) const
{
	if (!tuning) { return 0; }
	return static_cast<int64_t>(sj::anchor::ClassifySpan(static_cast<float>(span), *tuning));
}

String Jack::span_name(int64_t band) const
{
	switch (static_cast<sj::SpanBand>(band))
	{
	case sj::SpanBand::Rigid:  return String("rigid");
	case sj::SpanBand::Flex:   return String("flexing");
	case sj::SpanBand::Sway:   return String("swaying");
	case sj::SpanBand::Buckle: return String("about to buckle");
	}
	return String();
}

double Jack::grip_drain_multiplier(int64_t band) const
{
	if (!tuning) { return 1.0; }
	return static_cast<double>(
		sj::anchor::GripDrainMultiplier(static_cast<sj::SpanBand>(band), *tuning));
}

double Jack::nerve_drain_multiplier(int64_t band) const
{
	if (!tuning) { return 1.0; }
	return static_cast<double>(
		sj::anchor::NerveDrainMultiplier(static_cast<sj::SpanBand>(band), *tuning));
}

double Jack::tuning_f(const String& key, double fallback) const
{
	if (!tuning) { return fallback; }
	try
	{
		return static_cast<double>(tuning->GetF(key.utf8().get_data()));
	}
	catch (const std::exception& e)
	{
		UtilityFunctions::push_error("jack: ", String(e.what()));
		return fallback;
	}
}

}  // namespace steeplejack
