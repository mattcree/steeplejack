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
#include "Career.h"
#include "Fell.h"
#include "Gob.h"
#include "JointGrid.h"
#include "Level.h"
#include "Meters.h"
#include "Recovery.h"
#include "Rng.h"
#include "Slip.h"
#include "Band.h"
#include "Conductor.h"
#include "Stack.h"
#include "Survey.h"
#include "Wind.h"
#include "Verbs/Haul.h"
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
	// The ladder sections the job comes with, from the level's loadoutHint. 0 if it does not say.
	int64_t loadout_ladders() const;
	// And the dogs, from the same place. 0 if it does not say.
	int64_t loadout_dogs() const;
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

	// --- getting your nerve back — METER-004 ----------------------------------------------------
	/** On a staging or the top: nerve comes back on its own. */
	void set_on_platform(bool on) { on_platform = on; }
	/** 1 tea, 2 cigarette, 3 view. Returns why not, or "" if it has started. */
	godot::String recover_start(int action, bool both_hands_free, bool facing_out);
	void recover_interrupt();
	int64_t recover_action() const { return static_cast<int64_t>(recovery.action); }
	double recover_progress() const;

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
	/** Something let go under him. 02-climbing-system.md §6: "When grip hits zero, or an anchor
	 *  fails under you, you get a slip." Opens the window if the budget allows, and costs nerve. */
	void slip_now();
	/** Something knocked his hand: grip down by `amount`. A load swinging into him, say. */
	void grip_hit(double amount);
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

	// The checkpoint — CLIMB-006. The stack as JSON, and back. Restoring re-marks every anchor's
	// joint as occupied, so the face shows the dogs where they were. False, with get_last_error(),
	// for a checkpoint from another level, an edited level file, or an unknown version.
	godot::String save_stack() const;
	bool restore_stack(const godot::String& json);
	// Every section: {upper_joint, upper_height, lashing, failed}. For redrawing a restored stack.
	godot::Array stack_sections() const;

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

	// --- the stack — CLIMB-001/002 ----------------------------------------------------------------
	// Where the anchor loop's decisions come due. Sections are lashed between dogs; the climber's
	// weight goes into the dogs below him; a dog loaded past its rating pulls, and a cascade can
	// follow. The game layer steps it and reacts; it decides none of it.

	/** Lash a section to the dog at `dog_height`, from the highest intact dog below it. */
	int64_t stack_lash(double dog_height, int64_t lashing);
	/** Highest intact lashed dog, or 0 with no sections. The ladder tops out `rise` above it. */
	double stack_top() const;
	/**
	 * One step with the climber at `height` (on_ladder false for nobody on it). Returns
	 * `{failed: [dog heights, in order], section_failed: bool, buckling: bool, buckle_left: s,
	 *   span: m, band: int, drift_cm: cm, walk_off_cm: cm, lashing: int, flex_m: m,
	 *   section_lower: m, section_upper: m}`.
	 */
	godot::Dictionary stack_step(double dt, double height, bool on_ladder);
	/** How the section at this height is doing, without stepping anything. */
	godot::Dictionary stack_section_at(double height) const;
	// --- striking: the way down ----------------------------------------------------------------
	/** Why the section above `height` cannot come off, or "" if it can. */
	godot::String why_not_strike(double height) const;
	/** The section whose foot is within reach at `height`, or -1. */
	int64_t section_to_strike(double height) const;
	/** Take it off. Returns true if it came. */
	bool strike_section(int64_t section, double height);
	/** The dog within reach at `height` that could be drawn, or -1. */
	int64_t dog_to_draw(double height) const;
	/** Why that dog cannot be drawn, or "" if it can. */
	godot::String why_not_draw(int64_t anchor, double height) const;
	/** Draw it. `{drew, bent}` — bent means it broke coming out and is not coming home. */
	godot::Dictionary draw_dog(int64_t anchor, double height);
	/** Dogs still in the brickwork, and whether every ladder is down. */
	int64_t dogs_left_in() const;
	bool all_struck() const;

	/** Whether the dog at this index (anchor_at's) has pulled. */
	bool anchor_failed(int64_t index) const;

	// --- hauling — VERB-007 ----------------------------------------------------------------------
	/** Hook a load at the foot, under a gin wheel at `top_m`. */
	void haul_begin(double top_m);
	/**
	 * One step. `pull` 0..1, `steer` -1..1. Returns
	 * `{height, swing_deg, amplitude, foul_at, fouled, arrived}`.
	 */
	godot::Dictionary haul_step(double dt, double pull, double steer, double wind_ms, double load_kg);

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
	/** Dogs in the wall, not counting the ground. Index 0 is the first dog driven. */
	int64_t anchor_count() const { return static_cast<int64_t>(stack.AnchorCount()) - 1; }
	godot::Dictionary anchor_at(int64_t index) const;
	/** The highest sound anchor at or below a height, or -1. */
	double highest_anchor_below(double height) const;

	// --- the span economy ----------------------------------------------------------------------
	int64_t classify_span(double span) const;
	godot::String span_name(int64_t band) const;
	double grip_drain_multiplier(int64_t band) const;
	double nerve_drain_multiplier(int64_t band) const;

	// --- felling — FELL-001/002 ------------------------------------------------------------------
	// The demolition mode. The gob lives here for the same reason the stack does: it is the rule,
	// not the picture of it, and a .gd file asking "is this still standing" must not be allowed to
	// have an opinion.
	/**
	 * What the level says this chimney is: `{height, base_radius, top_radius, lean_degrees,
	 * lean_bearing, seed}`. The felling mode needs the lean before it can do anything, and a .gd
	 * file re-reading the level file to find it would be two sources of one truth.
	 */
	godot::Dictionary structure() const;
	/**
	 * Start a gob at the base of the level's chimney. Everything about the chimney — its height,
	 * its taper, its lean and what it weighs — comes from the level and the tuning, so there is
	 * nothing here for a .gd file to get wrong.
	 */
	void gob_begin(int64_t segments, int64_t courses, int64_t props, int64_t dud_index);
	/**
	 * One side of the ring tougher to cut than the other, as a level authors it. `bias` 0-1 comes
	 * off the mortar strength at `bearing_deg` and goes on opposite it.
	 */
	void gob_mortar_asymmetry(double bearing_deg, double bias);
	/** Take a cell out. False if there is nothing there. */
	bool gob_cut(int64_t seg, int64_t course);
	/** Stand a prop. False with none left, or if nothing has been cut at that segment yet. */
	bool gob_prop(int64_t seg);
	/** Whether the next prop off the stack is the knotty one the level planted. */
	bool gob_next_prop_is_dud() const;
	/**
	 * `{margin, status, status_name, cut_arc, cut_centre, props_left, props_set, segments,
	 *   courses, cog, support_centroid, base_radius}`. Safe every frame.
	 */
	godot::Dictionary gob_state() const;
	/** How many seconds of work this cell is, from its mortar and its course. */
	double gob_seconds_to_cut(int64_t seg, int64_t course) const;
	/** `{removed, propped, strength, bearing}` for one cell. */
	godot::Dictionary gob_cell(int64_t seg, int64_t course) const;
	/** `{present, load_kn, split, dud, reserve}` for the prop at a segment. */
	godot::Dictionary gob_prop_at(int64_t seg) const;
	/** Set the day and the neighbours. Exclusions as an Array of Dictionaries. */
	void fell_site(double wind_ms, double wind_bearing_deg, double safe_line_m, int64_t seed,
	               const godot::Array& exclusions);
	/**
	 * `{fall_bearing, error, accuracy, debris_half_angle, debris_length, threatened}` — call it
	 * while the player cuts, which is what makes the gob legible.
	 */
	godot::Dictionary fell_predict(double peg_bearing_deg, double height_removed_m,
	                               bool surveyed, double packing_quality = 1.0) const;
	/**
	 * Light it. `{fall_bearing, error, grade, grade_name, fractures, chunks, clean_break, struck,
	 * catastrophe, bonus, penalty}`.
	 */
	godot::Dictionary fell_run(double peg_bearing_deg, double height_removed_m,
	                           bool surveyed, double packing_quality = 1.0) const;
	/**
	 * The main line's timetable, if the level has one: `{minutes_since, minutes_until, train_due}`
	 * for a fall happening `window_s` after this minute of the shift.
	 */
	godot::Dictionary fell_timetable(double minute_of_shift, double window_s, double every_minutes,
	                                 double first_at_minute) const;
	/** How long the packing burns, between the level's authored seconds. */
	double fell_burn_seconds(double packing_quality, double min_s, double max_s) const;
	/** Whether this attempt at a match takes, in this wind. Deterministic on the level's seed. */
	bool fell_match_takes(double wind_ms, bool sheltered, int64_t attempt) const;

	/**
	 * What the day has cost so far and what is left of it: `{spent, shift, left, per_metre,
	 * max_reduction}`, all seconds and metres. Counts the cells actually out and the props
	 * actually standing, so a .gd file cannot get the arithmetic wrong by counting its own way.
	 */
	godot::Dictionary fell_shift(double height_removed_m) const;

	// --- the career — CAREER-001 -----------------------------------------------------------------
	// The money in the tin and whether anyone will have you back. The job board reads this to
	// decide which letters have arrived, which is a rule and not a drawing.
	/** Load the tin from JSON, or start empty if the text is missing or unreadable. */
	void career_load(const godot::String& json);
	/** The tin as text a person could read. Write it wherever you like. */
	godot::String career_json() const;
	/** `{money, reputation, stars, jobs}` — jobs is an Array of `{id, paid, error, failed}`. */
	godot::Dictionary career_state() const;
	// --- the survey ---------------------------------------------------------------------------
	/** Load the defects for this job: `[{id, height, bearing, discovery}]`. */
	void survey_begin(const godot::Array& defects);
	/** Look about from here. Returns the index of what he has just found, or -1. */
	int64_t survey_look(double height, int64_t bearing, bool at_top, bool sounded);
	/** Every defect and whether it has been found. */
	godot::Array survey_defects() const;
	/** How much of the survey he has: `{total, found, share, complete}`. */
	godot::Dictionary survey_report() const;

	// --- banding ------------------------------------------------------------------------------
	/** Start a band of `bolts` segments at `height`. */
	void band_begin(int64_t index, int64_t bolts);
	/** Pull one bolt up. Returns false for a bolt that is not on it. */
	bool band_tighten(int64_t index, int64_t bolt, double amount);
	/** How it reads: fit, ovality, how many are up, and the order you have been working in. */
	godot::Dictionary band_state(int64_t index) const;

	// --- the conductor run --------------------------------------------------------------------
	/** Start a run with `reels` reels of tape on the van. */
	void conductor_begin(int64_t reels);
	/** The terminal, set at the apex. Without it there is no system, only an attraction. */
	void conductor_set_terminal();
	/** Fix a clip: where, how much tape it took to get there, how hard it was driven. */
	bool conductor_fix(double height, double tape_paid, double tightness);
	/** Make the earth at the foot of it. */
	void conductor_earth(double plate_square_feet, bool wet, bool coke);
	/** The run as it stands, judged from `height`. */
	godot::Dictionary conductor_state(double height) const;

	// --- what the district remembers ----------------------------------------------------------
	/** Heights of the dogs you left in this chimney last time. */
	godot::PackedFloat32Array career_left_in(const godot::String& job_id) const;
	/** Remember what is still in it now — every dog not drawn, plus the ones that snapped. */
	void career_remember_left_in(const godot::String& job_id);
	/** Put the ones you left last time back in the wall, rustier. Returns how many went in. */
	int64_t plant_left_in(const godot::String& job_id, double rust);

	/** The yard: advance the calendar, and buy a part for the engine. */
	void career_sleep();
	bool career_buy_engine_part(double cost);
	/** Whether a level's letter has arrived, for a `reputationGate` in stars. */
	bool career_can_take(int64_t gate_stars) const;
	/**
	 * The most stars the built content could get you: what you have, plus a *perfectly* done job
	 * for every id in `job_ids` you have not done. A gate above this is a gap in the level set rather
	 * than something the player has failed to earn — see Career.h.
	 */
	int64_t career_reachable_stars(const godot::Array& job_ids) const;
	/** Inside the line when it went, or off a ladder. Returns the reputation it cost. */
	int64_t career_injured();
	/** Whether this job has been done successfully before. */
	bool career_done(const godot::String& job_id) const;
	/** Whether this felling's Act 2 — bands off, conductor down — has been climbed already. */
	bool career_stripped(const godot::String& job_id) const;
	void career_mark_stripped(const godot::String& job_id);
	/** What kind of job this level is: SURVEY, FELL, TOP and the rest, from the level file. */
	godot::String level_archetype() const;
	/**
	 * Settle the felling just run. `{fee, bonus, damages, paid, reputation_delta, failed,
	 * first_time}`. Uses the outcome the sim produced, not one a script made up.
	 */
	godot::Dictionary career_settle(const godot::String& job_id, double fee_gbp,
	                                double peg_bearing_deg, double height_removed_m, bool surveyed,
	                                double packing_quality = 1.0, double extra_bonus_gbp = 0.0);
	/** Settle the climbing half: you got to the top of it, or you did not. Same shape. */
	godot::Dictionary career_settle_climb(const godot::String& job_id, double fee_gbp,
	                                      bool reached_top);

	/**
	 * "Am I happy on this ladder?" — CLIMB-007. A judgement about the whole stack rather than
	 * about the section underfoot: `{verdict, verdict_name, reason, holds_a_fall, shock_kn,
	 * first_to_go, first_to_go_height, first_to_go_capacity, cascade_depth, would_fall_to,
	 * longest_span, worst_band, hitches, poor_anchors}`.
	 */
	godot::Dictionary stack_survey() const;

	/**
	 * The wind as something with a direction — FEEL-001. `{speed, bearing, trend, gust, tell,
	 * tell_progress, seconds_to_gust}`. Bearing is the quarter it blows FROM, clockwise from north.
	 */
	godot::Dictionary wind_state(double height) const;

	/** A tuned number, for the presentation layer to read rather than invent. */
	// How far off his line the wind has him, 0 to 1 of the allowed drift.
	void set_wind_lean(double fraction);
	// Metres a second the wind is shoving him along the rung; positive is to his right.
	double wind_side_push(double height, double facing_deg) const;
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
	/** Stack anchor index -> rust, for the old fixtures. What the renderer shows, never the rating. */
	std::map<int32_t, float> fixture_rust;
	sj::LashState lashing{};
	sj::HaulState hauling{};
	float haul_top{0.0f};

	std::unique_ptr<sj::Tuning> tuning;
	std::unique_ptr<sj::LevelData> level;
	std::string level_id;            // the file's stem, which is what a checkpoint is keyed on
	std::string level_fingerprint;   // save::LevelFingerprint of the file's bytes
	sj::Meters meters{};
	sj::MeterContext context{};
	sj::Stack stack{};
	godot::String last_error;

	sj::WindModel wind{};
	sj::Conductor conductor{};
	std::vector<sj::Band> bands;
	sj::Survey survey;
	/** The weather's own substream, forked once, so adding a subsystem cannot shift its values. */
	std::unique_ptr<sj::Rng> weather_rng;

	sj::RecoveryState recovery{};
	bool on_platform{false};

	sj::SlipModel slip{};
	sj::SlipOutcome outcome{sj::SlipOutcome::None};
	bool grab_latched{false};
	/** In-level seconds. The slip's budget and window are absolute times against this. */
	float now{0.0f};

	// The gob, when there is one. A felling level has one; a climbing level never touches it.
	std::unique_ptr<sj::Gob> gob;
	sj::FellSite fell;
	sj::Career career;
};

}  // namespace steeplejack
