#include "Jack.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "Rng.h"
#include "Slip.h"
#include "Wind.h"
#include "Verbs/Hammer.h"
#include "Verbs/Tap.h"
#include "Wobble.h"

#include <algorithm>
#include <cstdint>
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

	ClassDB::bind_method(D_METHOD("wind_at", "height"), &Jack::wind_at);
	ClassDB::bind_method(D_METHOD("gust_tell"), &Jack::gust_tell);
	ClassDB::bind_method(D_METHOD("gust_tell_progress"), &Jack::gust_tell_progress);
	ClassDB::bind_method(D_METHOD("gust_strength"), &Jack::gust_strength);
	ClassDB::bind_method(D_METHOD("level_has_gusts"), &Jack::level_has_gusts);

	ClassDB::bind_method(D_METHOD("set_difficulty", "difficulty"), &Jack::set_difficulty);
	ClassDB::bind_method(D_METHOD("get_difficulty"), &Jack::get_difficulty);
	ClassDB::bind_method(D_METHOD("grab"), &Jack::grab);
	ClassDB::bind_method(D_METHOD("slip_in_progress"), &Jack::slip_in_progress);
	ClassDB::bind_method(D_METHOD("slip_window_left"), &Jack::slip_window_left);
	ClassDB::bind_method(D_METHOD("slip_window_seconds"), &Jack::slip_window_seconds);
	ClassDB::bind_method(D_METHOD("can_slip_save"), &Jack::can_slip_save);
	ClassDB::bind_method(D_METHOD("last_slip_outcome"), &Jack::last_slip_outcome);
	ClassDB::bind_method(D_METHOD("fall", "height"), &Jack::fall);
	ClassDB::bind_method(D_METHOD("new_shift"), &Jack::new_shift);

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
		level = std::make_unique<sj::LevelData>(sj::LevelData::LoadFrom(level_path.utf8().get_data()));
		meters = sj::nerve::FreshShift(*tuning);
		meters.stance = sj::Stance::OneHand;
		meters.exposure = sj::Exposure::Platform;
		anchors.clear();
		// A new shift is a new clock and a new budget. Without this, loading a second level
		// inherits the first one's cooldown and the first slip of the new level is unsaveable.
		now = 0.0f;
		// The weather gets its own substream off the level's seed, so the gusts are the same on
		// every machine and in every replay, and so that adding another subsystem later cannot
		// shift them (Rng::Fork is const for exactly that reason).
		weather_rng = std::make_unique<sj::Rng>(
			sj::Rng(level->Structure().weatherSeed).Fork(0x57494E44u));   // literal: 'WIND'
		wind.Begin(level->Weather(), *weather_rng, *tuning);
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

void Jack::set_difficulty(int difficulty)
{
	slip.SetDifficulty(static_cast<sj::Difficulty>(std::clamp(difficulty, 0, 2)));
}

void Jack::grab()
{
	grab_latched = true;
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
	sj::Anchor tied{};
	for (const sj::Anchor& a : anchors)
	{
		if (a.rate != sj::AnchorRate::Failed && static_cast<double>(a.height) <= height + 0.01
		    && a.height >= tied.height)
		{
			tied = a;
		}
	}

	const sj::FallResult r = sj::ResolveFall(meters, tied, *tuning);
	d["tied_on"] = sj::IsTiedOn(meters.stance);
	d["caught"] = r.caught;
	d["anchor_failed"] = r.anchorFailed;
	d["shock_kn"] = static_cast<double>(r.shockLoadKN);
	d["capacity_kn"] = static_cast<double>(r.capacityKN);
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

sj::Joint Jack::joint_at(double height) const
{
	sj::Joint j{};
	j.height = static_cast<float>(height);
	// Seeded from the height alone, to a centimetre. Tapping a joint and then driving into it must
	// consult the same brickwork; re-rolling between the two would make the tap test a lie.
	sj::Rng rng(static_cast<uint64_t>(height * 100.0) ^ 0x5D3Bu);
	j.quality = rng.RangeFloat(0.2f, 0.95f);
	if (tuning) { j.tier = sj::tap::TierOf(j.quality, *tuning); }
	return j;
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
	const sj::Anchor a = sj::anchor::Make(joint_at(height), static_cast<float>(depth),
	                                      static_cast<float>(spall), *tuning);
	anchors.push_back(a);
	d["rate"] = static_cast<int64_t>(a.rate);
	d["rate_name"] = String(RateName(a.rate));
	d["capacity_kn"] = static_cast<double>(a.capacityKN);
	d["height"] = static_cast<double>(a.height);
	return d;
}

Dictionary Jack::anchor_at(int64_t index) const
{
	Dictionary d;
	if (index < 0 || index >= static_cast<int64_t>(anchors.size())) { return d; }
	const sj::Anchor& a = anchors[static_cast<size_t>(index)];
	d["rate"] = static_cast<int64_t>(a.rate);
	d["rate_name"] = String(RateName(a.rate));
	d["capacity_kn"] = static_cast<double>(a.capacityKN);
	d["height"] = static_cast<double>(a.height);
	return d;
}

double Jack::highest_anchor_below(double height) const
{
	double best = -1.0;
	for (const sj::Anchor& a : anchors)
	{
		if (a.rate != sj::AnchorRate::Failed && static_cast<double>(a.height) <= height + 0.01)
		{
			best = std::max(best, static_cast<double>(a.height));
		}
	}
	return best;
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
