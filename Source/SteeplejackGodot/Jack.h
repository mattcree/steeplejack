// The whole simulation, reachable from GDScript.
//
// One object holds what a climber is: the tuning, the two meters, the world around him, the level
// he is on and the dogs he has driven. The game layer in GDScript owns input, cameras, meshes and
// sound; it owns no rules. Every number that decides anything comes from here, which is the same
// line ADR-0003 drew and the reason the move between engines cost the sim nothing.
//
// If you find yourself about to write `if grip < 20` in a .gd file, the answer belongs in
// SteeplejackSim and a method belongs here.

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include "Anchor.h"
#include "JointGrid.h"
#include "Level.h"
#include "Meters.h"
#include "Rng.h"
#include "Slip.h"
#include "Wind.h"
#include "Verbs/Lash.h"
#include "Tuning.h"
#include "Types.h"

#include <map>
#include <memory>
#include <vector>

namespace steeplejack {

class Jack : public godot::RefCounted
{
	GDCLASS(Jack, godot::RefCounted)

public:
	Jack() = default;
	~Jack() override = default;

	// --- setup ---------------------------------------------------------------------------------
	/** Read the tuning directory and one level file. False on failure; `get_last_error` says why. */
	bool load(const godot::String& tuning_dir, const godot::String& level_path);
	godot::String get_last_error() const { return last_error; }
	godot::String tuning_hash() const;

	// --- the level -----------------------------------------------------------------------------
	double total_height() const;
	double radius_at(double height) const;
	int64_t band_count() const;
	/** `{from, to, type}` for one band. */
	godot::Dictionary band(int64_t index) const;
	godot::String band_type_at(double height) const;
	godot::String level_name() const;

	// --- the world around him ------------------------------------------------------------------
	// Set every frame before `step`. Passed in rather than read from an ambient world, which is
	// what makes the meter maths testable without a world to test it in.
	void set_context(double height, double wind_speed, bool carrying_ladder, bool working);
	void set_exposure(int exposure);
	void set_stance(int stance);
	int64_t get_stance() const { return static_cast<int64_t>(meters.stance); }
	godot::String stance_name() const;
	godot::String stance_name_of(int stance) const;
	/** Seconds of rigging to get into a stance, and whether getting there costs any at all. */
	double stance_setup_seconds(int stance) const;
	bool stance_needs_rigging(int from, int to) const;
	/** Grip per second this stance costs while a hand is off, with every modifier applied. */
	double stance_drain_rate(int stance) const;

	// --- the meters ----------------------------------------------------------------------------
	void step(double dt);
	double grip() const { return static_cast<double>(meters.grip); }
	double nerve() const { return static_cast<double>(meters.nerve); }
	double nerve_max() const { return static_cast<double>(meters.nerveMax); }
	bool tremoring() const;
	bool slipping() const;
	bool frozen() const;
	int64_t nerve_band() const;
	double seconds_of_work_left() const;
	/** A named fright. Unknown events are refused rather than silently ignored. */
	bool shock(const godot::String& event);
	double wobble_deg(double gust) const;

	// --- the weather ---------------------------------------------------------------------------
	// Driven by `step`, from the level file's own weather block. The game layer asks what the wind
	// is; it does not decide, and it does not decide when a gust arrives either.
	/** Wind speed in m/s at a height, gust included. */
	double wind_at(double height) const;
	/** The 1.2 s warning. The cue that makes being blown off a fair failure rather than a bug. */
	bool gust_tell() const;
	/** 0 to 1 through the tell, for a cue that rises rather than one that just plays. */
	double gust_tell_progress() const;
	/** 0 to 1 gust strength. Zero for the whole of the tell, deliberately. */
	double gust_strength() const;
	bool level_has_gusts() const;

	// --- the slip ------------------------------------------------------------------------------
	// Grip reaching zero opens the window inside `step`, and `step` closes it. Neither is something
	// the game layer can forget to do, because a 900 ms window that a script forgets to expire is a
	// player hanging in the air for ever.
	//
	// The grab is latched rather than polled: a key that goes down and up between two physics
	// frames is a grab the player made, and losing it would be the single most infuriating bug
	// this feature could have.
	void set_difficulty(int difficulty);
	int64_t get_difficulty() const { return static_cast<int64_t>(slip.GetDifficulty()); }
	/** The grab input. Call from `_input`; the next `step` reads and clears it. */
	void grab();
	bool slip_in_progress() const { return slip.InProgress(); }
	/** 1 at the moment of the slip falling to 0 at its close. What the closing ring draws. */
	double slip_window_left() const;
	double slip_window_seconds() const;
	bool can_slip_save() const;
	/** What the last `step` decided: 0 nothing, 1 saved, 2 fell. */
	int64_t last_slip_outcome() const { return static_cast<int64_t>(outcome); }

	/**
	 * Resolve a fall against whatever you are tied to at this height.
	 * `{caught, anchor_failed, shock_kn, capacity_kn, tied_on}`.
	 */
	godot::Dictionary fall(double height);

	/**
	 * Come back the next day. Meters back to a fresh shift and the slip budget with them; the
	 * level, the dogs you drove and the ladder you lashed are untouched, because the stack is the
	 * checkpoint and losing it is the one thing a fall must never do.
	 */
	void new_shift();

	// --- the face ------------------------------------------------------------------------------
	// Every joint the player can see, read, tap and drive into comes from the grid, by id. Before
	// the grid a joint was a hash of the height and the level's bands were ignored; see
	// JointGrid.h. What the renderer draws is exactly what the sim thinks the wall is.

	/** Degrees clockwise from north that the ladder climbs. chimney.gd's FACE (-X) is 270. */
	double climb_bearing() const { return kClimbBearing; }
	int64_t joint_count() const { return grid ? grid->Count() : 0; }
	/**
	 * Every joint within `range` of the face at this height and bearing.
	 * Each is `{id, pos, normal, height, look, look_q, occupied, tapped}`: `look` is the tier the
	 * joint *appears* to be (the visual tell, which lies a little), `tapped` is the tier the player
	 * learned by tapping it, or -1. The true tier is deliberately not here.
	 */
	godot::Array joints_near(double height, double bearing_deg, double range) const;
	/** The unoccupied joint nearest a world point, within `max_range`, or -1. */
	int64_t nearest_joint(const godot::Vector3& point, double max_range) const;
	godot::Dictionary joint(int64_t id) const;

	/** Tap a joint by id. `{tier, tier_name, pip, confidence, id}`. Remembers what was learned. */
	godot::Dictionary tap_joint(int64_t id, bool wearing_gloves);
	/** One hammer blow at a joint by id. */
	godot::Dictionary strike_joint(int64_t id, double current_depth, double power,
	                               double angle_error_deg, double tool_condition);
	/** Seat a dog in a joint by id; it is occupied from then on. */
	godot::Dictionary seat_anchor_joint(int64_t id, double depth, double spall);
	/** A dog bent into a joint spoils it: occupied, and holding nothing. */
	void spoil_joint(int64_t id);

	// --- lashing -------------------------------------------------------------------------------
	// One lash in progress at a time, held here so the rope's state is the sim's and not a copy.
	/** Start a fresh lashing. */
	void lash_begin();
	/** One step, at a turn rate. Every input method arrives here as the same number (VERB-006). */
	void lash_step(double dt, double turns_per_second);
	/** `{wraps, tension, laid, tied, slipping}` */
	godot::Dictionary lash_state() const;
	/** Tie off. 0 none, 1 hitch, 2 full — Lashing's own order. `slipping` is in lash_state(). */
	int64_t lash_tie_off();
	double lash_rate_from_mash(double presses_per_second) const;
	double lash_rate_from_hold() const;
	double lash_drift_cm_per_minute(int64_t lashing) const;
	double lash_lay_rate(double turns_per_second) const;

	// --- the verbs -----------------------------------------------------------------------------
	/** Sound the brickwork. `{tier, tier_name, pip, confidence}`. */
	godot::Dictionary tap(double height, bool wearing_gloves);
	/** One hammer blow. `{depth_gain, spalled, bent, seated}`. */
	godot::Dictionary strike(double height, double current_depth, double power,
	                         double angle_error_deg, double tool_condition);
	/** Depth at which a dog holds a ladder. */
	double seat_depth() const;
	/** Drive a dog home and remember it. `{rate, rate_name, capacity_kn, height}`. */
	godot::Dictionary seat_anchor(double height, double depth, double spall);
	int64_t anchor_count() const { return static_cast<int64_t>(anchors.size()); }
	godot::Dictionary anchor_at(int64_t index) const;
	/** The highest sound anchor at or below a height, or -1. */
	double highest_anchor_below(double height) const;

	// --- the span economy ----------------------------------------------------------------------
	int64_t classify_span(double span) const;
	godot::String span_name(int64_t band) const;
	double grip_drain_multiplier(int64_t band) const;
	double nerve_drain_multiplier(int64_t band) const;

	/** A tuned number, for the presentation layer to read rather than invent. */
	double tuning_f(const godot::String& key, double fallback) const;

protected:
	static void _bind_methods();

private:
	/**
	 * The joint at a height. Derived deterministically from the band and the height, so the joint
	 * you tapped is the joint you then drive a dog into — the tap test would be meaningless if the
	 * answer were re-rolled between reading it and acting on it.
	 */
	sj::Joint joint_at(double height) const;
	int32_t joint_id_at(double height) const;
	godot::Dictionary joint_dict(int32_t id) const;

	static constexpr float kClimbBearing = 270.0f;   // west, chimney.gd's FACE

	std::unique_ptr<sj::JointGrid> grid;
	/** What the player has learned by tapping, by joint id. Chalk marks are drawn from this. */
	std::map<int32_t, int32_t> tapped;
	sj::LashState lashing{};

	std::unique_ptr<sj::Tuning> tuning;
	std::unique_ptr<sj::LevelData> level;
	sj::Meters meters{};
	sj::MeterContext context{};
	std::vector<sj::Anchor> anchors;
	godot::String last_error;

	sj::WindModel wind{};
	/** The weather's own substream, forked once, so adding a subsystem cannot shift its values. */
	std::unique_ptr<sj::Rng> weather_rng;

	sj::SlipModel slip{};
	sj::SlipOutcome outcome{sj::SlipOutcome::None};
	bool grab_latched{false};
	/** In-level seconds. The slip's budget and window are absolute times against this. */
	float now{0.0f};
};

}  // namespace steeplejack
