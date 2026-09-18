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
#include "Level.h"
#include "Meters.h"
#include "Slip.h"
#include "Tuning.h"
#include "Types.h"

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

	std::unique_ptr<sj::Tuning> tuning;
	std::unique_ptr<sj::LevelData> level;
	sj::Meters meters{};
	sj::MeterContext context{};
	std::vector<sj::Anchor> anchors;
	godot::String last_error;

	sj::SlipModel slip{};
	sj::SlipOutcome outcome{sj::SlipOutcome::None};
	bool grab_latched{false};
	/** In-level seconds. The slip's budget and window are absolute times against this. */
	float now{0.0f};
};

}  // namespace steeplejack
