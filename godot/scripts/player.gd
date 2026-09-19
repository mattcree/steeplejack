# The jack.
#
# Input, camera, body. Every rule it obeys lives in SteeplejackSim behind the Jack binding: grip and
# nerve are stepped there, the stance table comes from meters.json, the structure comes from the
# level file. This script converts input into intent and reads sim state back out. It decides
# nothing — if a number here decides something, it is in the wrong file.
#
# Heights are measured at his FEET. The capsule's origin is at his middle, and every number in this
# game — the span, the anchors, the level file — is a height off the ground. Getting that wrong put
# him a metre in the air and every comparison against ladder_top out by the same.

extends CharacterBody3D

const CAPSULE_HALF := 0.9        ## Origin to feet.
const WALK_SPEED := 4.2
const ACCEL := 22.0
const FRICTION := 14.0
const GRAVITY := 22.0
const JUMP_SPEED := 6.0
const MOUSE_SENS := 0.0025
const SHOULDER_HEIGHT := 0.55   ## above his origin, which is his middle, not his feet
const ARM_REACH := 0.85          ## shoulder to hammer face
const LEAN_MAX := 0.75           ## the most he shifts on the rungs to get there
const LEAN_RATE := 14.0          ## fast enough to arrive before the tap's contact at 0.16 s
const WALL_FOLLOW_DELAY := 1.5   ## seconds after the mouse last moved before the ladder view squares up
const WALL_FOLLOW_RATE := 1.2    ## how fast it does, per second — a drift, not a snap
const TURN_RATE := 12.0

## The stride of the run clip, in metres per second. Playback is scaled by how fast he is actually
## travelling, so his feet keep up with the ground instead of skating over it. Eyeballed — if the
## feet slip forwards, raise it; if he moonwalks, lower it.
const RUN_CLIP_SPEED := 4.6

const BOOM_LENGTH := 3.0
const BOOM_SIDE := 0.65
const WORK_BOOM_LENGTH := 1.4        ## 11-camera-controls-feel.md, "pulls in to 1.4 m"
const WORK_BOOM_SIDE := 0.55
const TOP_BOOM_LENGTH := 4.0
const FALL_BOOM_LENGTH := 6.5
const FALL_FOV_WIDEN := 16.0         ## 11-camera-controls-feel.md, "pulls out to 4 m"
## How fast the camera settles on a new framing. Quick enough to be there before the first blow.
const CAMERA_SETTLE := 7.0

## How long a change of clip takes to blend in, in real seconds.
const CLIP_BLEND := 0.22

## When in the tap the hammer meets the brick. The result lands here, not on the keypress: a sound
## that plays before the arm has moved is a sound from nowhere.
const TAP_CONTACT := ClimbClip.TAP_CONTACT
## How close to where you are looking a joint must be to be the one you are pointing at. Wide
## enough that looking straight up the ladder — which is where the camera naturally sits — still
## finds a joint beside the stiles: the ones under the ladder are not offered, so the nearest
## usable joint to the ladder's centre line is 0.3-0.5 m off it.
const AIM_SLACK := 0.8

const LADDER_REACH := 0.9        ## You are on a ladder when you can hold it.
const BODY_OFF_LADDER := 0.40
const MOUNT_HEIGHT := 1.6        ## You get on a ladder from the ground, not by brushing past it.
const SHUFFLE_SPEED := 1.3       ## Metres per second sideways along the face.
const SHUFFLE_OFF := 0.7         ## Shuffle this far and you are off it.
const REMOUNT_DELAY := 0.8       ## After stepping off, long enough to walk away before it grabs you.
const KILLING_FALL := 4.0        ## Metres. Below this you land; above it you do not.

const DOG_BAG := 6
const CRADLE_RADIUS := 8.0
const TOOL_CONDITION := 0.85

## What the sim's last step decided about the slip. Mirrors sj::SlipOutcome.
## Move further than this while rigging and the rig is off. Enough slack for the odd physics nudge,
## far less than a rung.
const RIG_HOLD_STILL_M := 0.12

## How long a line stays up. Long enough to read twice, short enough that it is never a fixture.
const MESSAGE_SECONDS := 6.0

## The most the mouse's heading can turn between two movements and still be going round.
const LASH_MAX_TURN_PER_MOVE := PI * 0.5

## Lashing's own order, from the sim.
const LASHING_NONE := 0
const LASHING_HITCH := 1
const LASHING_FULL := 2

const SLIP_NONE := 0
const SLIP_SAVED := 1
const SLIP_FELL := 2

@onready var jack: Jack = Jack.new()
@onready var boom: SpringArm3D = $Boom
@onready var body: Node3D = $Body
@onready var anim: AnimationPlayer = $Body/AnimationPlayer
@onready var chimney: Chimney = get_node("../Chimney")
@onready var foley: Foley = get_node_or_null("../Foley")
@onready var face: Face = get_node_or_null("../Face")
@onready var camera: Camera3D = $Boom/Camera

var ladder_top := 5.0
var carrying_ladder := false
var dogs_carried := 0
var ladders_at_base := 12
var dogs_at_base := 14

var tap_reading := ""
var tap_pip := -1
var tapped_at := -100.0
var message := ""
var message_at := 0.0         ## When it was said. A line that never expires is a line that lies.
var span_warning := ""

var work_mode := false
var aim := Vector2.ZERO
var swing_power := 0.0
var drawing := false
var dog_depth := 0.0
var work_height := 0.0
var work_joint := -1             ## The joint the dog is going into. Everything in work mode acts on it.

## The joint he is pointing at. Everything on the ladder acts on it — see 15-working-the-face.md.
var target_id := -1
var tapping := 0.0               ## Seconds of the tap action left. A tap is an action, not an event.
var _tap_joint := -1
var _tap_landed := false
## The last tap's result, for the pip drawn at the joint. {id, pip, tier, at}.
var last_tap := {}
## Joints with a dog bent into them. Wasted material should be something you can look at.
var bent_joints := {}
## Dogs started and left: joint id to how far in. Stepping back to rest mid-drive used to reset the
## dog to nothing, so on a hard joint and a tired arm a dog could never be seated — the ascent test
## hammered one joint for half an hour of game time finding that out.
var started_dogs := {}

## Lashing — VERB-005. A mode, like work: the rope is going round and nothing else is.
var lashing := false
var lash_joint := -1             ## the dog the new section is being lashed to
var lash_rate := 0.0             ## turns a second, whatever the input method
var lash_new_top := 0.0          ## where the section will top out if it holds
## VERB-006: rotate, mash or hold. Every one becomes the same turn rate in the sim.
const LASH_METHODS := ["rotate", "mash", "hold"]
var lash_method := 0
var _lash_spin := 0.0            ## signed radians the mouse has turned through this frame
var _lash_heading := INF
var _lash_signed := 0.0          ## smoothed signed turn rate; a back-and-forth wiggle cancels out
var _lash_presses: Array[float] = []
## Every section lashed, bottom to top: {top, lashing, slipping, joint}.
var sections: Array = []

## The stack, as of the last step: span, band, buckling, drift. What the HUD reads.
var stack_info := {}
## Dogs that have pulled, in the order they went, for the fuse. {height, at}.
var fuse: Array = []
## The standing ladder at the foot, before anything is lashed.
const STANDING_TOP := 5.0

## Recovery — METER-004. Mirrors the sim's action so the HUD and the camera can follow it.
const REC_NONE := 0
const REC_TEA := 1
const REC_CIG := 2
const REC_VIEW := 3
var recovering := REC_NONE
var tea_line := ""
## What he says over a brew. The GDD: "the character says something". Same few, every time, in
## turn — it becomes a comfort, which is the design's word for it.
const TEA_LINES := [
	"Right. That's better.",
	"Wind's getting up.",
	"Not a bad view, this.",
	"Somebody's had a go at that joint and made a mess of it.",
	"Nearly there. Nearly.",
]
var _tea_count := 0

## The top — MVP criterion 1: "the top means something". Once per ascent.
var at_top := false
var top_reached := false
var top_summary := {}            ## what the climb added up to, for the card
var top_since := 0.0
const TOP_REACH := 0.6           ## this close to the top of the stack, with ladder to it, and you are there
const TOP_FOV_WIDEN := 10.0      ## 11-camera-controls-feel.md: "wide FOV" at the top
var _base_fov := 72.0
## Every tap the player made, and every span they took. The MVP playtest measures both — criterion 2
## asks whether they still tap at anchor 10, criterion 4 whether they take the risky span — and the
## top is where a player sees their own answer.
var taps_made := 0
var long_spans := 0
var drift_phase := 0.0

var on_ladder := false
var _yaw := 0.0
var _body_base := Vector3.ZERO   ## the body's resting place under the player; the lean is added to it
var _lean := Vector3.ZERO        ## world-space shift towards the joint being tapped or worked
var _mouse_at := -100.0          ## When the player last turned the view; the ladder camera waits for them.
var _pitch := -0.1
var _spawn := Vector3.ZERO
var _fell_from := 0.0
var _playing := ""
var _shuffle := 0.0              ## How far sideways off the ladder line he has worked himself.
var _remount_block := 0.0
var _now := 0.0                  ## Seconds since the shift started. The HUD's clock, not the sim's.
var _climb_rate := 0.0           ## Metres per second up the ladder this frame; drives the clip.
var _blend_left := 0.0           ## Real seconds of clip blend still to run.
var _rung_count := 0
## Stands in for W/S when non-zero. A headless test cannot press a key, and a test of "frozen stops
## you climbing" that cannot press the climb key passes whether the rule works or not.
var climb_input := 0.0
## The same for walking: x is right, y is forward, relative to the camera. For a test that plays.
var walk_input := Vector2.ZERO
## And for looking: a world point to aim at instead of the camera's ray. INF when unused.
var aim_override := Vector3.INF
var _carried_ladder: Node3D      ## the section on his back, shown only while he is carrying one

## The fall — 02-climbing-system.md §6 and CAM-002: "Camera goes wide, time dilates ~40%, the ladder
## stack you built streaks past you, and it cuts to black before impact."
var falling := false
var fall_from_m := 0.0
var fall_black := 0.0            ## 0..1, the cut
var fade_in := 0.0               ## 1..0, coming back the next day
var _fall_t := 0.0
var _black_held := 0.0
const FALL_TIME_SCALE := 0.6
const FALL_CUT_ABOVE := 3.0      ## metres off the ground at which it cuts. Before impact, always.
const FALL_LONGEST := 2.4        ## game seconds, whatever the height
const FALL_BLACK_HOLD := 1.4
## A11Y-001 / CAM-002 acceptance 4: no slow motion and no camera snap, just the cut. For players the
## wide spinning fall would make ill — and it must not change a single outcome, only what is shown.
var motion_minimal := false

## The gin wheel — VERB-007. A pulley lashed to a dog, a rope to the yard.
var gin_joint := -1
var gin_height := 0.0
var hauling := false
var haul := {}                   ## the sim's last word on the load
var _haul_dx := 0.0              ## mouse sideways this frame: the hand on the rope
var haul_steer := 0.0
var _gin: Node3D                 ## wheel, rope and load, drawn in the world
const GIN_REACH := 2.2           ## how close to the wheel he has to be to work the rope
const HAUL_STEER_GAIN := 0.02    ## mouse pixels a frame to a full push on the rope
var _kick := 0.0                 ## Camera impulse from a hammer blow, decaying.
var _cam_yaw := 0.0              ## Where the camera actually is, easing towards where it wants to be.
var _cam_pitch := -0.1
var _cam_side := BOOM_SIDE
var boom_length := BOOM_LENGTH   ## Where the camera sits when not working. A var so a shot can set it.
var rigging_to := -1             ## Stance being rigged, or -1. The HUD draws the ring.
var rig_left := 0.0              ## Seconds of it still to do.
var rig_total := 0.0
var _rig_at := 0.0               ## The height he was at when he started. Moving off it breaks it.
var _gust_told := false          ## Rising edge of the tell, so the cue fires once per gust.
var _slipping := false           ## Mirrors the sim, so the rising edge can be acted on once.
var fall_reason := ""            ## The one sentence the player must be able to say themselves.


## Say something, and remember when. See `message_ttl`.
func _say(what: String) -> void:
	message = what
	message_at = _now


## How much life is left in the current message, 1 down to 0.
##
## The opening line — "walk to the foot of the stack" — was still on screen sixty metres up, because
## nothing ever cleared it. A stale instruction is worse than none: the player reads it, looks for
## what it describes, and cannot find it.
func message_ttl() -> float:
	if message == "":
		return 0.0
	return clampf(1.0 - (_now - message_at) / MESSAGE_SECONDS, 0.0, 1.0)


func height_m() -> float:
	return global_position.y - CAPSULE_HALF


func set_height_m(h: float) -> void:
	global_position.y = h + CAPSULE_HALF


func _ready() -> void:
	_body_base = body.position
	var tuning_dir := ProjectSettings.globalize_path("res://../data/tuning")
	# The MVP is one grey-box 55 m chimney in an empty field and this is it. 06-waterside is an M4
	# felling level and was being played as if it were the MVP build, which is four bands and
	# fifteen metres off-spec. `--level` overrides it: `make shot LEVEL=06-waterside`.
	var level_path := ProjectSettings.globalize_path("res://../data/levels/%s.json" % _level_id())
	if not jack.load(tuning_dir, level_path):
		push_error("could not start: %s" % jack.get_last_error())
		get_tree().quit(1)
		return

	# glTF animations import unlooped, so idle and run play once and then he freezes mid-stride.
	# Nothing warns about this; the character simply stops a second or two after you start.
	for clip in ["idle", "run"]:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

	# The model has no climb, and this is a game about climbing. Nor a tap, nor a hammer blow.
	var skel: Skeleton3D = body.get_node_or_null(ClimbClip.SKELETON)
	if skel != null:
		ClimbClip.install(anim, skel)
		_give_hammer(skel)
		_carried_ladder = _make_carried_ladder(skel)
	if face != null:
		face.jack = jack
		for i in jack.anchor_count():
			var a: Dictionary = jack.anchor_at(i)
			if a.get("fixture", false):
				face.fixture_rust[int(a["joint"])] = float(a["rust"])

	_spawn = global_position
	_base_fov = camera.fov
	var town: Town = get_node_or_null("../Town")
	if town != null:
		town.build(jack.level_name())
	chimney.build(jack)
	# After the build, not before: the chimney's height is zero until then, so aiming at the top of
	# it aimed at the ground and the opening shot came out flat and pointed at a field.
	_look_at_stack()
	chimney.set_ladder_top(ladder_top)
	# Only when there is a window to capture it in. A headless server has no mouse, and asking for
	# one there hangs the process with no output at all, which is a miserable thing to debug.
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_say("%s. Walk to the foot of the stack." % jack.level_name())
	print("steeplejack: %s — %.0f m, %d bands, tuning %s" % [
		jack.level_name(), jack.total_height(), jack.band_count(), jack.tuning_hash().substr(0, 12)])


## Point the camera at the stack, and tilt up enough to see the top of it.
##
## He used to spawn looking wherever the scene file happened to leave him, which was at an empty
## field with the chimney off to one side. The first frame of a game about climbing something tall
## has one job.
## Which level to play. Defaults to the MVP grey box; `--level <id>` picks another.
func _level_id() -> String:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--level" and i + 1 < args.size():
			return args[i + 1]
	return "00-greybox"


## Square the view up to the wall in front of him, looking a little up.
##
## On a round stack "in front" changes as he climbs, and the first frames rendered from the ladder
## were edge-on: the camera kept the yaw it had in the yard, the ladder sat on the chimney's
## silhouette, and the joint he was pointing at was a sliver of brick against the sky. Nothing on
## the wall can be read at that angle, and reading the wall is the game.
func face_the_wall() -> void:
	var to := chimney.global_position - global_position
	to.y = 0.0
	if to.length() < 0.01:
		return
	_yaw = atan2(-to.x, -to.z)
	_pitch = 0.12


## While he climbs with the view left alone, it drifts back square to the wall. Not while he is
## steering it — a camera that fights the mouse is worse than an edge-on one — and never mid-verb,
## which is camera rule 1: this is only called from the plain climb.
func _follow_wall(dt: float) -> void:
	if _now - _mouse_at < WALL_FOLLOW_DELAY:
		return
	# Only while he is moving on the ladder. Stopped, he may be studying a joint round to the side,
	# and pulling the view off it would be taking the choice out of his hands.
	if climb_input == 0.0 and _key(KEY_W) - _key(KEY_S) == 0.0:
		return
	var to := chimney.global_position - global_position
	to.y = 0.0
	if to.length() < 0.01:
		return
	var want := atan2(-to.x, -to.z)
	var k := clampf(dt * WALL_FOLLOW_RATE, 0.0, 1.0)
	_yaw = lerp_angle(_yaw, want, k)


func _look_at_stack() -> void:
	var to := chimney.global_position - global_position
	to.y = 0.0
	if to.length() < 0.01:
		return
	# The boom's forward is -Z, so this is the yaw that puts the stack in front of it.
	_yaw = atan2(-to.x, -to.z)
	# Aim between the foot and the top rather than at either. The camera's vertical half-angle is
	# about 36 degrees, and the top of a 70 m stack seen from 70 m out is 45 degrees up — level with
	# the horizon it is simply off the top of the screen, which is what the first frame of this game
	# looked like.
	_pitch = clampf(atan2(chimney.height_m, to.length()) * 0.42, 0.0, 0.7)
	_cam_yaw = _yaw
	_cam_pitch = _pitch
	body.rotation.y = _face(to.normalized())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if work_mode:
			# In work mode the mouse stops steering your head and starts steering the hammer. That
			# separation is the whole feel of the verb: you are holding on with one hand.
			aim.x = clampf(aim.x + event.relative.x * 0.12, -18.0, 18.0)
			aim.y = clampf(aim.y + event.relative.y * 0.12, -18.0, 18.0)
		else:
			# The camera orbits; the body does not turn with it. The body turns to face where it is
			# going, which is most of what makes a third-person character look like it has weight.
			_yaw -= event.relative.x * MOUSE_SENS
			_mouse_at = _now
			# Down to 77 degrees: steep enough to pick a joint at your own feet. At 69 the lowest
			# joint a climber could point at was level with his boots, and the next dog for a
			# rigid span is often lower than that.
			_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.35, 0.6)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)

	# The grab is latched in the sim rather than polled in _physics_process, because a key that
	# goes down and up between two physics frames is still a grab the player made, and losing that
	# one would be the most infuriating bug this feature could have. It is taken before anything
	# else looks at the input: while you are coming off a ladder, no other verb means anything.
	if jack.slip_in_progress():
		var pressed_grab: bool = (event is InputEventKey and event.pressed and not event.echo
			and event.keycode == KEY_SPACE)
		var clicked_grab: bool = (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT)
		if pressed_grab or clicked_grab:
			jack.grab()
		return

	if lashing:
		_lash_input(event)
		return
	if hauling:
		if event is InputEventMouseMotion:
			_haul_dx += event.relative.x
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
			_stop_haul("you let the rope run — the load goes back to the yard")
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E: _tap()
			KEY_R: _lash()
			KEY_F: _pick_up()
			KEY_Q: _cycle_stance()
			KEY_G: _gin_wheel()
			KEY_T: _recover(REC_TEA)
			KEY_C: _recover(REC_CIG)
			KEY_V: _recover(REC_VIEW)
			KEY_SPACE: _space()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_toggle_work_mode()
		elif event.button_index == MOUSE_BUTTON_LEFT and work_mode:
			drawing = true
			# The hammer goes up as the draw starts: anticipation, the first thing on the feel list.
			if anim.has_animation("windup"):
				anim.play("windup", 0.05)
				anim.speed_scale = 1.0
				_playing = "windup"
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and drawing:
			_release_strike()


func _physics_process(dt: float) -> void:
	_now += dt
	_update_camera(dt)

	# Hanging by one hand. Nothing he does moves him and no verb is available; the only input that
	# means anything is the grab, and _step_sim is what closes the window on it. Stepping the sim
	# is not optional here — the window is the sim's and it expires there, not on a timer in this
	# script, which is why this early return still goes through it.
	if _slipping:
		velocity = Vector3.ZERO
		_step_sim(dt)
		_read_slip()
		_animate()
		return

	var ladder_world: Vector3 = chimney.global_position + chimney.face_point(height_m())
	var to_ladder := Vector2(global_position.x - ladder_world.x, global_position.z - ladder_world.z)
	var within_reach := to_ladder.length() < LADDER_REACH + BODY_OFF_LADDER

	# You get on a ladder from the ground, and not for a moment after you have just got off it.
	# Without the delay, stepping off at the foot re-attached on the very next frame — you were
	# standing next to it, on the floor, within reach, which is exactly the mounting condition.
	_remount_block = maxf(0.0, _remount_block - dt)
	if (not on_ladder and within_reach and height_m() <= MOUNT_HEIGHT and is_on_floor()
			and _remount_block <= 0.0):
		on_ladder = true
		_shuffle = 0.0
		_say("on the ladder")
		face_the_wall()
	if on_ladder and not within_reach:
		_step_off("off the ladder")

	if falling and fall_black > 0.0:
		velocity = Vector3.ZERO
	elif at_top:
		_on_top(dt)
	elif work_mode or lashing or hauling:
		velocity = Vector3.ZERO
	elif on_ladder:
		_climb(dt, ladder_world)
		_follow_wall(dt)
	else:
		_walk(dt)

	_step_sim(dt)
	_read_slip()
	_update_rig(dt)
	_update_face()
	_update_tap(dt)
	_update_work(dt)
	_update_lash(dt)
	_update_haul(dt)
	_update_stack(dt)
	_update_recovery()
	_update_fall(dt)
	if _carried_ladder != null:
		# On his back whenever he has one and is not holding it up to lash it — then it is the
		# translucent section on the stack instead, and it cannot be in two places.
		_carried_ladder.visible = carrying_ladder and not lashing
	_animate()
	_update_lean(dt)


## What the sim decided about the slip on the step that just ran.
##
## The rising edge is acted on here and nowhere else: a slip cancels work mode, because a man whose
## hand has come off is not still lining a dog up, and leaving the hammer live through a slip meant
## you could strike while falling.
func _read_slip() -> void:
	var now_slipping: bool = jack.slip_in_progress()
	if now_slipping and not _slipping:
		work_mode = false
		drawing = false
		swing_power = 0.0
		_cancel_rig()
		_say("")
	_slipping = now_slipping

	match jack.last_slip_outcome():
		SLIP_SAVED:
			# Hanging one-handed with almost nothing left. The nerve cost is the real one, and it
			# is what makes the next dog measurably harder. If the ladder under him went, he caught
			# the top of what is still standing.
			if height_m() > ladder_top:
				set_height_m(ladder_top)
			_say("caught it. Hanging one-handed — get your other hand back on.")
			fall_reason = ""
		SLIP_FELL:
			_came_off()


## The window closed with no grab. What happens next is decided by what you were tied to, which is
## a decision you made minutes ago with the anchor rating on screen in front of you.
func _came_off() -> void:
	_slipping = false
	var r: Dictionary = jack.fall(height_m())

	if not r.get("tied_on", false):
		_begin_fall("you had one hand on a rung and nothing else. Nothing caught you.")
		return

	for h in r.get("cascade", []):
		fuse.append({"height": h, "at": _now + 0.18 * fuse.size()})
	if not r.get("cascade", []).is_empty():
		ladder_top = clampf(maxf(STANDING_TOP, jack.stack_top() + _rise()) if jack.stack_top() > 0.0
			else STANDING_TOP, 0.0, chimney.height_m)
		chimney.set_ladder_top(ladder_top)
		if face != null:
			face.touch()

	if r.get("caught", false):
		# The line held. You are still on the stack, three seconds of clipping on well spent.
		fall_reason = ""
		_say("the line held — %.1f kN on a dog rated %.1f kN. Get back on." % [
			r["shock_kn"], r["capacity_kn"]])
		return

	_begin_fall("the dog let go: %.1f kN of shock load on one rated %.1f kN." % [
		r["shock_kn"], r["capacity_kn"]])


## The fall. **The stack stays up** — it is the checkpoint, and the whole reason a fall stings
## without wiping the twenty-five minutes you spent building it. You come back the next day and
## climb what you already built.
func _fall_to_ground(why: String) -> void:
	fall_reason = why
	# Said on the black, by the fall card, and again as the next morning comes up. A third time here
	# would be the same sentence under the other two.
	_say("")
	jack.new_shift()
	global_position = _spawn
	velocity = Vector3.ZERO
	on_ladder = false
	work_mode = false
	drawing = false
	_cancel_rig()
	if lashing:
		_abandon_lash("")
	_shuffle = 0.0
	_remount_block = REMOUNT_DELAY
	_fell_from = 0.0
	_slipping = false


func _climb(dt: float, ladder_world: Vector3) -> void:
	velocity = Vector3.ZERO
	var up := _key(KEY_W) - _key(KEY_S)
	if climb_input != 0.0:
		up = climb_input
	var side := _key(KEY_D) - _key(KEY_A)

	# Frozen: 03-meters-grip-nerve.md, "you cannot move up. You can only descend, or recover nerve
	# in place." Nerve never kills you; it stops you, at the height it gave out, and the only ways
	# on are down or a brew.
	if up > 0.0 and jack.frozen():
		up = 0.0
		if message_ttl() <= 0.0:
			_say("frozen — you can't make yourself go up. Get your nerve back, or go down")

	var rate: float = (jack.tuning_f("climbSpeedMetresPerSecond", 1.6) if up >= 0.0
		else jack.tuning_f("slideSpeedMetresPerSecond", 2.4))
	var before := height_m()
	set_height_m(clampf(before + up * rate * dt, 0.0, ladder_top))

	# Up the last rung onto the cap, if the ladder goes that far.
	if up > 0.0 and ladder_top >= chimney.height_m - 0.1 \
			and height_m() >= chimney.height_m - TOP_REACH:
		_arrive_at_top()
		return
	_climb_rate = (height_m() - before) / maxf(dt, 0.0001)

	# A knock on every rung he passes, hand and boot alternately. The climb had no sound at all,
	# and a ladder under a man is not silent.
	var rung_gap: float = chimney.RUNG_GAP
	if foley != null and floor(before / rung_gap) != floor(height_m() / rung_gap) and _climb_rate > -3.0:
		_rung_count += 1
		foley.cue("rung", 0.92 + 0.12 * float(_rung_count % 2))

	# The slide down: S is fast, and it is the reward for the climb. Loud, a rush, and a thump at
	# the bottom (camera and feel, non-negotiable 6). Nothing did any of that.
	if foley != null:
		foley.set_slide(clampf(-_climb_rate / rate, 0.0, 1.0) if up < 0.0 else 0.0)
		if up < 0.0 and before > 0.4 and height_m() <= 0.05:
			foley.cue("thump")
			_kick = 0.02

	# Working yourself sideways off the stile. This has to accumulate: the first version recomputed
	# the offset from the key every frame, so it never got further than one step and you could never
	# leave.
	_shuffle += side * SHUFFLE_SPEED * dt
	if absf(_shuffle) > SHUFFLE_OFF:
		_step_off("stepped off the ladder")
		return

	# The ladder has his body: the only thing he controls is how far up it he is. Shuffling sideways
	# carries him off it, which at the foot of the stack is simply stepping off.
	# He is on the ladder, so he goes where it goes: out with it as it bows.
	var held := ladder_world + chimney.bow_at(height_m())
	held.y = global_position.y
	var out := held - chimney.global_position
	out.y = 0.0
	out = out.normalized()
	var tangent := Vector3(-out.z, 0.0, out.x)
	global_position = held + out * BODY_OFF_LADDER + tangent * _shuffle
	body.global_rotation.y = _face(-out)   # into the brickwork, not away from it

	if height_m() <= 0.02 and up < 0.0:
		_step_off("off the ladder")


func _walk(dt: float) -> void:
	var f := _key(KEY_W) - _key(KEY_S)
	var r := _key(KEY_D) - _key(KEY_A)
	if walk_input != Vector2.ZERO:
		r = walk_input.x
		f = walk_input.y
	# Movement is relative to where the camera is looking, which is what every third-person game
	# does and what hands expect.
	var wish := Basis(Vector3.UP, _yaw) * Vector3(r, 0.0, -f)
	if wish.length() > 1.0:
		wish = wish.normalized()

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if wish.length() > 0.01:
		flat = flat.move_toward(wish * WALK_SPEED, ACCEL * dt)
		# Turn to face travel rather than snapping. The lag is most of what reads as weight.
		body.rotation.y = lerp_angle(body.rotation.y, _face(wish), clampf(TURN_RATE * dt, 0.0, 1.0))
	else:
		flat = flat.move_toward(Vector3.ZERO, FRICTION * dt)

	velocity.x = flat.x
	velocity.z = flat.z
	velocity.y -= GRAVITY * dt

	var was_airborne := not is_on_floor()
	move_and_slide()

	# Off the ladder and dropping further than a man survives: it becomes the fall, and it cuts to
	# black before he lands, rather than being discovered on landing.
	if not is_on_floor() and not falling and _fell_from - height_m() > KILLING_FALL:
		_begin_fall("you let go at %.0f m." % _fell_from)
	if is_on_floor():
		if was_airborne and not falling and _fell_from - height_m() > KILLING_FALL:
			_fall(_fell_from - height_m())
		_fell_from = height_m()


## Space means the obvious thing for wherever he is: on the ground it is a jump, on a ladder it is
## letting go. You pressed it expecting a jump and got dropped down the stack.
func _space() -> void:
	if on_ladder:
		_let_go()
	elif is_on_floor():
		velocity.y = JUMP_SPEED
		_fell_from = height_m()


## The one place he leaves the ladder, so the cooldown can never be forgotten at one of them.
func _step_off(why: String) -> void:
	on_ladder = false
	_shuffle = 0.0
	_remount_block = REMOUNT_DELAY
	_fell_from = height_m()
	_say(why)


func _let_go() -> void:
	if not on_ladder:
		return
	var h := height_m()
	_step_off("you let go" if h > KILLING_FALL else "off the ladder")
	if h > KILLING_FALL:
		jack.shock("startle")   # "nearMiss" was never a shock the tuning knew; it logged an error and did nothing


func _fall(metres: float) -> void:
	_fall_to_ground("you dropped %.0f m onto hard ground." % metres)


## He is off, and nothing is going to catch him.
func _begin_fall(why: String) -> void:
	if falling:
		return
	falling = true
	fall_reason = why
	fall_from_m = maxf(_fell_from, height_m())
	_fall_t = 0.0
	_black_held = 0.0
	fall_black = 0.0
	on_ladder = false
	work_mode = false
	drawing = false
	_cancel_rig()
	if lashing:
		_abandon_lash("")
	if recovering != REC_NONE:
		jack.recover_interrupt()
		recovering = REC_NONE
	# A little way off the wall, so he falls past the stack rather than scraping down it.
	var out := global_position - chimney.global_position
	out.y = 0.0
	velocity = out.normalized() * 1.6
	_say("")
	if not motion_minimal:
		Engine.time_scale = FALL_TIME_SCALE
	if foley != null:
		foley.cue("gustTell", 0.7)   # the rush of it; the same noise as wind arriving, lower


func _update_fall(dt: float) -> void:
	if not falling:
		fade_in = move_toward(fade_in, 0.0, dt * 0.8)
		return
	_fall_t += dt
	# Cut before impact, always. The design is explicit, and there is nothing to be gained by showing
	# the landing that the player would not rather imagine.
	if fall_black <= 0.0 and (height_m() < FALL_CUT_ABOVE or _fall_t > FALL_LONGEST
			or is_on_floor() or motion_minimal):
		fall_black = 0.01
		Engine.time_scale = 1.0
		velocity = Vector3.ZERO
	if fall_black > 0.0:
		fall_black = minf(1.0, fall_black + dt * 8.0)
		velocity = Vector3.ZERO
		_black_held += dt
		if _black_held >= FALL_BLACK_HOLD:
			falling = false
			fall_black = 0.0
			fade_in = 1.0
			_fall_to_ground(fall_reason)


## The yaw that points the model along `dir`.
##
## Mannequiny is modelled facing +Z, while a Godot node's forward is -Z. Everything that turns him
## goes through here so that offset is stated once, rather than being wrong in two places — which is
## what it was: he ran backwards facing the camera, and faced away from the wall on the ladder.
func _face(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)


## Leaning into the joint. The tap reaches tapTestMaxRangeMetres, 2.5 m, and an arm with a
## hammer on the end reaches about 0.85 m. So on anything but the nearest joints the arm swung
## at empty air half a metre short, the tap "landed" on nothing, and the player could not tell what
## he had just tapped. It is the complaint the prototype got first: you need to see where you are
## tapping.
##
## The range is a tuning target and not this file's to change. Instead the body leans: shifted
## along the wall, up or across towards the joint, by what the arm cannot cover, so the hammer
## arrives where the sound comes from. It is drawn only. The sim's position does not move, and
## nothing about reach, grip or the ladder changes.
func _update_lean(dt: float) -> void:
	if body == null:
		return
	var want := Vector3.ZERO
	var jid := -1
	if tapping > 0.0:
		jid = _tap_joint
	elif work_mode:
		jid = work_joint
	if jid >= 0 and face != null and on_ladder:
		var j: Dictionary = face.joint(jid)
		if not j.is_empty():
			var at: Vector3 = (j["pos"] as Vector3) + chimney.global_position
			var shoulder := global_position + Vector3.UP * SHOULDER_HEIGHT
			var need := at - shoulder
			# Never into the wall or away from it: along the face and up or down only.
			var n: Vector3 = j["normal"]
			n.y = 0.0
			if n.length() > 0.01:
				n = n.normalized()
				need -= n * need.dot(n)
			var short := need.length() - ARM_REACH * 0.6
			if short > 0.0:
				want = need.normalized() * minf(short, LEAN_MAX)
	_lean = _lean.lerp(want, clampf(dt * LEAN_RATE, 0.0, 1.0))
	body.position = _body_base + global_transform.basis.inverse() * _lean


func _animate() -> void:
	if anim == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	# Match the cycle to the ground he is covering. A run clip played at a fixed rate while the
	# character accelerates is the thing that reads as feet skating.
	anim.speed_scale = clampf(speed / RUN_CLIP_SPEED, 0.55, 1.8) if speed > 0.6 else 1.0
	# Three clips is the whole vocabulary this model has that suits the game. There is no climbing
	# animation in it, so on the ladder he holds still rather than pretending — a run cycle on a
	# ladder reads worse than stillness.
	var want := "idle"
	# A tap or a blow plays through to its end before the ladder takes him back.
	if (_playing == "tap" or _playing == "strike") and anim.is_playing() \
			and anim.current_animation == _playing:
		return
	# Holding the draw holds the hammer up. The wind-up clip ends in that pose and stays there.
	if _playing == "windup" and drawing:
		return
	# In work mode between blows he holds the ladder and the dog; no climbing stride.
	if work_mode and _playing != "climb":
		if anim.has_animation("climb"):
			anim.play("climb", CLIP_BLEND)
			_playing = "climb"
			_blend_left = CLIP_BLEND
	if work_mode:
		anim.speed_scale = 1.0 if _blend_left > 0.0 else 0.0
		_blend_left = maxf(0.0, _blend_left - get_physics_process_delta_time())
		return
	if on_ladder:
		want = "climb"
	elif not is_on_floor():
		want = "air_jump"
	elif speed > 0.6:
		want = "run"
	if want != _playing and anim.has_animation(want):
		anim.play(want, CLIP_BLEND)
		_playing = want
		_blend_left = CLIP_BLEND

	# The blend into a clip runs at the clip's speed_scale, not in real time. So a climb stride
	# slowed to a tenth for a man standing still turned a quarter-second blend out of idle into
	# two and a half seconds, and he hung there with his arms out sideways in a pose neither clip
	# contains. Full speed until the blend is done, then the ladder drives the stride.
	_blend_left = maxf(0.0, _blend_left - get_physics_process_delta_time())
	if want == "climb" and _blend_left > 0.0:
		anim.speed_scale = 1.0
	elif want == "climb":
		# The cycle follows the ladder, not the clock: he reaches when he moves and holds the rung
		# he is on when he does not. A climb cycle running while the player stands still is the
		# ladder equivalent of feet skating.
		var climb_speed: float = jack.tuning_f("climbSpeedMetresPerSecond", 1.6)
		# Floored rather than allowed to reach zero. A speed_scale of 0 freezes the *blend* out of
		# idle as well as the cycle, so standing still on a ladder left him halfway between the two
		# poses with his arms out sideways — a pose neither clip contains. At a tenth speed the
		# stride takes seventeen seconds, which reads as a man shifting his weight rather than as a
		# man climbing, and the blend finishes.
		var scale := clampf(absf(_climb_rate) / maxf(climb_speed, 0.01), 0.1, 2.0)
		anim.speed_scale = -scale if _climb_rate < -0.01 else scale


func _key(k: Key) -> float:
	return 1.0 if Input.is_key_pressed(k) else 0.0


func _step_sim(dt: float) -> void:
	var h := maxf(height_m(), 0.0)
	# `working` means a hand is off the ladder, which during a slip is not a figure of speech. Left
	# as work_mode alone, grip recovered through the whole 900 ms — so the meter that had just run
	# out was visibly refilling while the player scrambled for the key.
	#
	# The wind is the level's own, at this height, with whatever the gust is adding. It used to be a
	# hard-coded 9 m/s everywhere, which made every level's authored wind profile decorative — and
	# wind is a term in both the nerve drain and the wobble, so it was a difficulty dial the
	# designer had and the game ignored.
	jack.set_context(h, jack.wind_at(h), carrying_ladder,
		work_mode or _slipping or rigging_to >= 0 or tapping > 0.0 or lashing or hauling)
	if foley != null:
		foley.duck(recovering == REC_TEA, dt)
		foley.set_height(h)
		# Breathing with the nerve band, from the stack upward; at the foot nobody is frightened.
		foley.set_breath(jack.nerve_band(), (on_ladder or at_top) and h > 6.0)
		if not on_ladder:
			foley.set_slide(0.0)

	# The 1.2 second warning, once per gust. The fairness table allows a gust to blow you off only
	# if this played first, so it is fired from the sim's own phase and never from a timer here.
	var telling: bool = jack.gust_tell()
	if telling and not _gust_told:
		if foley != null:
			foley.cue("gustTell")
	_gust_told = telling
	jack.set_exposure(2 if _slipping else (1 if on_ladder else 0))   # Hanging, Ladder, Platform
	jack.set_on_platform(at_top)
	jack.step(dt)

	# The span you are standing on: from the highest dog below you to where you are. The entire risk
	# economy — longer spans mean fewer anchors, which is faster, right up until the section bows.
	var below: float = jack.highest_anchor_below(h)
	var span: float = h - maxf(below, 0.0)
	# The span of the section he is actually on, dog to dog, once there is one. That is the number
	# the table is written against and the one that can buckle.
	if stack_info.get("section", -1) >= 0:
		span = float(stack_info["span"])
	var band: int = jack.classify_span(span)
	span_warning = "" if band == 0 else "%.1fm span — %s" % [span, jack.span_name(band)]


# --- the verbs -----------------------------------------------------------------------------------

## What he is pointing at, and the patch of wall around him.
##
## The target is the joint nearest where the camera is looking, and only one his hand can reach.
## Not the best joint in reach: choosing is the skill, and the bracket is the same for every tier.
func _update_face() -> void:
	if face == null:
		return
	face.update_for(maxf(height_m(), 0.0))
	if work_mode:
		face.set_target(work_joint)
		face.set_work(work_joint, dog_depth)
		return
	face.set_work(-1, 0.0)
	target_id = _find_target() if on_ladder and not _slipping else -1
	face.set_target(target_id)


func _find_target() -> int:
	var reach: float = jack.tuning_f("tapTestMaxRangeMetres", 2.5)
	var hands := global_position + Vector3.UP * 0.55   # shoulder height; the origin is his middle
	var from := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - camera.global_transform.basis.z * 14.0)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	# Looking at the wall: the joint where you are looking. Looking away from it — at the view, say
	# — the joint straight in front of his chest, so there is always something sensible to tap on a
	# ladder and never a dead key.
	var aim_at: Vector3 = hit["position"] if not hit.is_empty() else (
		hands + (chimney.global_position - hands).normalized() * 0.6)
	# A test that plays says where it is looking directly. Only the mouse-to-ray step is skipped —
	# test_face covers that — and every rule after it (reach, the ladder, occupied) still applies.
	if aim_override.is_finite():
		aim_at = aim_override
	aim_at.y = clampf(aim_at.y, hands.y - reach, hands.y + reach)
	# The nearest usable joint to where you are looking. Not simply the nearest: a joint under the
	# ladder is nearest surprisingly often, because the ladder goes up exactly where you look.
	var best := -1
	var best_d := AIM_SLACK
	for j in face._joints:
		if j["occupied"] or face.under_ladder(j):
			continue
		var d: float = ((j["pos"] as Vector3) + chimney.global_position).distance_to(aim_at)
		if d < best_d:
			best_d = d
			best = j["id"]
	var id := best
	if id < 0:
		return -1
	var j: Dictionary = face.joint(id)
	if j.is_empty():
		return -1
	if ((j["pos"] as Vector3) + chimney.global_position).distance_to(hands) > reach:
		return -1
	return id


func _tap() -> void:
	if not on_ladder:
		_say("you sound the brickwork from the ladder")
		return
	if tapping > 0.0:
		return
	if target_id < 0:
		_say("no joint in reach — look at the brickwork")
		return
	# A tap is an action, with an arm that moves and a moment it lands. The result arrives at
	# contact, not on the keypress.
	tapping = jack.tuning_f("tapTestSeconds", 0.8)
	_tap_joint = target_id
	_tap_landed = false
	_aim_hammer_at(target_id)
	if anim.has_animation("tap"):
		anim.play("tap", 0.06)
		anim.speed_scale = 1.0
		_playing = "tap"


func _update_tap(dt: float) -> void:
	if tapping <= 0.0:
		return
	var total: float = jack.tuning_f("tapTestSeconds", 0.8)
	tapping -= dt
	if not _tap_landed and total - tapping >= TAP_CONTACT:
		_tap_landed = true
		var r: Dictionary = jack.tap_joint(_tap_joint, false)
		if r.is_empty():
			return
		tap_reading = r["tier_name"]
		tap_pip = r["pip"]
		tapped_at = height_m()
		last_tap = {"id": _tap_joint, "pip": r["pip"], "tier": r["tier"], "at": _now}
		taps_made += 1
		# The sound *is* the reading. The pip and the chalk are the visual fallbacks rule 8
		# requires — never the only channel, and never a colour.
		if foley != null:
			foley.tap(r["tier"])
		_dust_at(_tap_joint, 6)
		if face != null:
			face.touch()
	if tapping <= 0.0:
		tapping = 0.0


func _toggle_work_mode() -> void:
	if work_mode:
		work_mode = false
		drawing = false
		swing_power = 0.0
		if work_joint >= 0 and dog_depth > 0.0:
			started_dogs[work_joint] = dog_depth
			if face != null:
				face.started_ids[work_joint] = dog_depth
				face.touch()
		return
	if not on_ladder:
		_say("you drive a dog from the ladder")
		return
	if target_id < 0:
		_say("no joint in reach — look at the brickwork")
		return
	if dogs_carried <= 0:
		_say("no dogs in the bag")
		return
	# No "sound it first". Tapping is information you can buy for 0.8 s and some grip, and skipping
	# it is a real choice — the fairness contract's second kind of failure is exactly "information
	# you could have got for a known cost and chose not to", and MVP criterion 2 measures whether
	# players *still choose* to tap at anchor #10. Forcing it deleted the choice both depend on.
	work_mode = true
	work_joint = target_id
	_aim_hammer_at(work_joint)
	var j: Dictionary = face.joint(work_joint)
	work_height = j.get("height", height_m())
	# Back to a dog already started: it is where it was left.
	dog_depth = float(started_dogs.get(work_joint, 0.0))
	started_dogs.erase(work_joint)
	if face != null and face.started_ids.has(work_joint):
		face.started_ids.erase(work_joint)
		face.touch()
	aim = Vector2.ZERO
	if jack.joint(work_joint).get("tapped", -1) < 0:
		_say("you have not sounded this one")


func _update_work(dt: float) -> void:
	if not work_mode:
		return
	if drawing:
		swing_power = clampf(swing_power + dt * 1.6, 0.0, 1.0)
	# Wobble is computed in one place, by the sim, and it eats your margin while you hold the draw.
	drift_phase += dt * 2.3
	# The gust, at last. `wobble_deg` has taken this argument since METER-003 and the only caller
	# passed zero, so a gust could not move your hands — which is most of what a gust is for.
	var w: float = jack.wobble_deg(jack.gust_strength())
	aim.x += sin(drift_phase) * w * dt
	aim.y += cos(drift_phase * 0.7) * w * dt


func _release_strike() -> void:
	drawing = false
	if work_joint < 0:
		work_mode = false
		return
	var swing_at_release := swing_power
	var err := aim.length()
	var r: Dictionary = jack.strike_joint(work_joint, dog_depth, swing_power, err, TOOL_CONDITION)
	if r.is_empty():
		work_mode = false
		return
	dog_depth = clampf(dog_depth + r["depth_gain"], 0.0, 1.0)
	swing_power = 0.0

	if anim.has_animation("strike"):
		anim.play("strike", 0.04)
		anim.speed_scale = 1.0
		_playing = "strike"
	_dust_at(work_joint, 4 + int(10.0 * swing_at_release))
	# The hit, felt: a couple of pixels of camera kick, harder for a harder blow. Camera and feel
	# §3 asks for 2-3 px; this is that, and nothing more — a shake that moves the aim would be a
	# second, invisible wobble.
	_kick = 0.012 * (0.4 + swing_at_release)

	if foley != null:
		# Pitched by how hard he swung, so a half-drawn blow sounds like one.
		foley.cue("hammer", 0.85 + 0.3 * (1.0 - swing_at_release))

	if r["bent"]:
		if foley != null:
			foley.cue("bent")
		dogs_carried -= 1
		# It stays in the wall, bent, and the joint is spoiled — it cannot take another.
		bent_joints[work_joint] = true
		jack.spoil_joint(work_joint)
		if face != null:
			face.bent_ids[work_joint] = true
			face.touch()
		_say("bent it. %d dogs left" % dogs_carried)
		work_mode = false
		return

	if dog_depth >= jack.seat_depth():
		if foley != null:
			foley.cue("seated")
		var a: Dictionary = jack.seat_anchor_joint(work_joint, dog_depth, r["spalled"])
		if a.is_empty():
			work_mode = false
			return
		dogs_carried -= 1
		if face != null:
			face.touch()
		_say("dog seated — %s, %.1f kN" % [a["rate_name"], a["capacity_kn"]])
		work_mode = false


## The camera. Third person, over the right shoulder; in work mode, in close on the joint.
##
## 11-camera-controls-feel.md: "Working (one-handed verbs): pulls in to 1.4 m, focuses the hands."
## Without it the jack's own back hid the hammer, the dog and the joint — the three things the verb
## is about. The move happens on entering the verb and is held, never during it: camera rule 1 is
## "never auto-rotate while the player is mid-verb", and the mouse is steering the hammer by then.
func _update_camera(dt: float) -> void:
	var yaw := _yaw
	var pitch := _pitch
	var length := boom_length
	var side := BOOM_SIDE

	if work_mode and work_joint >= 0 and face != null and not has_meta("shot_wide"):
		var j: Dictionary = face.joint(work_joint)
		if not j.is_empty():
			var joint_at: Vector3 = (j["pos"] as Vector3) + chimney.global_position
			var d: Vector3 = joint_at - boom.global_position
			yaw = atan2(-d.x, -d.z)
			pitch = atan2(d.y, Vector2(d.x, d.z).length())
			length = WORK_BOOM_LENGTH
			# Over whichever shoulder the joint is on, so his body is never between the lens and
			# the dog.
			var right := boom.global_transform.basis.x
			# Plus however far he has leant towards it: the lean moves him into the line from the
			# lens to the dog, and the first frames of it had the back of his head over the joint.
			side = (WORK_BOOM_SIDE + _lean.length()) \
				* (1.0 if right.dot(joint_at - global_position) >= 0.0 else -1.0)

	# The top: pulls out to 4 m, drops to eye level, widens. And slowly — this is the one camera move
	# in the game that is allowed to take its time, because the player has earned the view and
	# nothing is asking them to do anything.
	# The brew: the camera settles to a slow fixed framing outward, over the town. The one camera in
	# the game that is allowed to take its time alongside the top, because it is a rest.
	if recovering == REC_TEA and not at_top:
		var away := global_position - chimney.global_position
		away.y = 0.0
		away = away.normalized()
		yaw = atan2(-away.x, -away.z) + 0.35
		pitch = -0.12
		length = 3.2

	# The haul: 02-climbing-system.md §4, "the camera looks down the rope. This is the shot that sells
	# the height, and it's free because the player isn't moving."
	if hauling and gin_joint >= 0 and face != null:
		var gj: Dictionary = face.joint(gin_joint)
		if not gj.is_empty():
			var gn: Vector3 = gj["normal"]
			# Facing the wall, so the arm swings the camera out over the drop rather than into the
			# ladder: pointed outward, the spring arm sat on the wall side, hit the ladder and
			# crushed in until the whole frame was rails and the back of his head.
			yaw = atan2(gn.x, gn.z) + 0.30
			pitch = -1.0
			length = 4.5
			side = -0.6

	# The fall camera: snaps wide, character centred, the stack in frame above him as he drops past
	# it. The one camera that *snaps* rather than eases — a fall is not a moment for a gentle pan.
	var snap := false
	if falling and not motion_minimal and fall_black <= 0.0:
		length = FALL_BOOM_LENGTH
		pitch = 0.22
		side = 0.0
		snap = true

	var fov := _base_fov
	if falling and not motion_minimal:
		fov = _base_fov + FALL_FOV_WIDEN
	if at_top:
		length = TOP_BOOM_LENGTH
		fov = _base_fov + TOP_FOV_WIDEN
		side = 0.0
	camera.fov = lerpf(camera.fov, fov, clampf(dt * 1.2, 0.0, 1.0))

	var slow: bool = at_top or recovering == REC_TEA
	var k := clampf(dt * (CAMERA_SETTLE * 0.25 if slow else CAMERA_SETTLE), 0.0, 1.0)
	if snap:
		k = clampf(dt * 20.0, 0.0, 1.0)
	_cam_yaw = lerp_angle(_cam_yaw, yaw, k)
	_cam_pitch = lerpf(_cam_pitch, pitch, k)
	boom.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)
	boom.spring_length = lerpf(boom.spring_length, length, k)
	_cam_side = lerpf(_cam_side, side, k)

	# The impact frame. Decays in a few frames; small enough never to move the aim.
	_kick = move_toward(_kick, 0.0, dt * 0.12)
	camera.h_offset = _cam_side + randf_range(-_kick, _kick)
	camera.v_offset = randf_range(-_kick, _kick)


## Point the hammer clips at a joint, so the blow lands where the player chose.
func _aim_hammer_at(id: int) -> void:
	var skel: Skeleton3D = body.get_node_or_null(ClimbClip.SKELETON)
	if skel == null or face == null or id < 0:
		return
	var j: Dictionary = face.joint(id)
	if j.is_empty():
		return
	ClimbClip.aim_hammer(anim, skel, (j["pos"] as Vector3) + chimney.global_position)


## T, C, V: get your nerve back. Refused with the reason when it cannot start.
func _recover(what: int) -> void:
	if recovering != REC_NONE:
		jack.recover_interrupt()
		recovering = REC_NONE
		return
	if not on_ladder and not at_top:
		_say("you get your nerve back up there, not on the ground")
		return
	# Both hands free: a belt round the stack, the chair, or standing on the top.
	var hands_free: bool = at_top or jack.get_stance() >= 3
	var why: String = jack.recover_start(what, hands_free, _facing_out())
	if why != "":
		_say(why)
		return
	recovering = what
	match what:
		REC_TEA:
			tea_line = TEA_LINES[_tea_count % TEA_LINES.size()]
			_tea_count += 1
			_say("")
		REC_CIG:
			_say("a cigarette — five off your nerve for the rest of the shift")
		REC_VIEW:
			_say("")


func _update_recovery() -> void:
	if recovering == REC_NONE:
		return
	# Finished, in the sim.
	if jack.recover_action() == REC_NONE:
		recovering = REC_NONE
		tea_line = ""
		return
	# Anything else he does breaks it off. It keeps what it had given.
	var moving: bool = absf(_climb_rate) > 0.01 or work_mode or lashing or _slipping or tapping > 0.0
	var view_let_go: bool = recovering == REC_VIEW and not Input.is_key_pressed(KEY_V) \
		and DisplayServer.get_name() != "headless"
	if moving or view_let_go:
		jack.recover_interrupt()
		recovering = REC_NONE
		tea_line = ""


## Whether the camera is looking away from the stack — out, at the view.
func _facing_out() -> bool:
	var fwd := -camera.global_transform.basis.z
	fwd.y = 0.0
	var away := global_position - chimney.global_position
	away.y = 0.0
	if fwd.length() < 0.01 or away.length() < 0.01:
		return false
	return fwd.normalized().dot(away.normalized()) > 0.3


## He is up. Onto the cap, turned to face out over the town, and the camera goes wide.
##
## The first time, the climb is summed up on screen — dogs by rating, the long spans taken, the time
## — because that is the player's own answer to the questions the MVP playtest is asking them, and
## the top is the one moment they will read it. After that it is just the view.
func _arrive_at_top() -> void:
	at_top = true
	on_ladder = false
	top_since = _now
	work_mode = false
	_cancel_rig()
	if lashing:
		_abandon_lash("")
	# Standing on the oversail, a little in from the edge, facing away from the stack's axis.
	var out := global_position - chimney.global_position
	out.y = 0.0
	out = out.normalized()
	var r: float = chimney.radius_at(chimney.height_m)
	global_position = chimney.global_position + out * (r * 1.05) \
		+ Vector3.UP * (chimney.height_m + 2.2 + CAPSULE_HALF)
	body.rotation.y = _face(out)
	velocity = Vector3.ZERO
	# The camera behind him and looking the way he is: out, over the town.
	_yaw = atan2(-out.x, -out.z)
	_pitch = -0.06

	if not top_reached:
		top_reached = true
		top_summary = _summarise_climb()
		jack.shock("startle")   # the wind at the top, first time; it is supposed to catch you
		_say("")


func _on_top(dt: float) -> void:
	velocity = Vector3.ZERO
	if _key(KEY_S) > 0.0:
		# Back over the edge and onto the ladder.
		at_top = false
		var out := global_position - chimney.global_position
		out.y = 0.0
		var foot: Vector3 = chimney.global_position + chimney.face_point(chimney.height_m - 1.0)
		var fo := foot - chimney.global_position
		fo.y = 0.0
		global_position = foot + fo.normalized() * BODY_OFF_LADDER
		set_height_m(minf(ladder_top, chimney.height_m) - 1.0)
		on_ladder = true
		_remount_block = 0.0
		_say("back over the edge")


func _summarise_climb() -> Dictionary:
	var by_rate := [0, 0, 0, 0]   # failed, poor, fair, sound
	for i in jack.anchor_count():
		var a: Dictionary = jack.anchor_at(i)
		by_rate[clampi(int(a["rate"]), 0, 3)] += 1
	return {
		"height": chimney.height_m,
		"seconds": _now,
		"dogs": jack.anchor_count(),
		"sound": by_rate[3], "fair": by_rate[2], "poor": by_rate[1], "failed": by_rate[0],
		"bent": bent_joints.size(),
		"taps": taps_made,
		"long_spans": long_spans,
		"sections": sections.size(),
		"hitches": sections.filter(func(x): return x["lashing"] == LASHING_HITCH).size(),
	}


## The stack — CLIMB-001 and 002. Where a decision made ten minutes ago comes due.
##
## Each step the sim loads the dogs under him and reports what went. The game only reacts: shortens
## the ladder to what is still standing, burns the fuse, and — if what went was under him — slips
## him, because §6 of the climbing system is explicit that an anchor failing under you is a slip.
func _update_stack(dt: float) -> void:
	stack_info = jack.stack_step(dt, maxf(height_m(), 0.0), on_ladder and not _slipping)
	chimney.set_bow(stack_info.get("section_lower", 0.0), stack_info.get("section_upper", 0.0),
		_bow_now() if on_ladder else 0.0)

	var failed: Array = stack_info.get("failed", [])
	var went: bool = stack_info.get("any_section_failed", false) or not failed.is_empty()
	if not went:
		return

	for h in failed:
		fuse.append({"height": h, "at": _now + 0.18 * fuse.size()})
		var jid := _joint_of_anchor_at(float(h))
		if face != null and jid >= 0:
			face.pulled_ids[jid] = true
	if face != null:
		face.touch()
	if foley != null:
		foley.cue("bent", 0.8)

	var was_top := ladder_top
	ladder_top = clampf(maxf(STANDING_TOP, jack.stack_top() + _rise()) if jack.stack_top() > 0.0
		else STANDING_TOP, 0.0, chimney.height_m)
	chimney.set_ladder_top(ladder_top)

	var why := ""
	if not failed.is_empty():
		why = "%d dog%s pulled — the stack above %.0f m is down" % [
			failed.size(), "" if failed.size() == 1 else "s", float(failed[failed.size() - 1])]
	elif stack_info.get("buckling", false) or stack_info.get("band", 0) == 3:
		why = "the section buckled"
	else:
		why = "the hitch walked off the dog"
	_say(why)

	# Under him? Then he is coming off.
	if on_ladder and (height_m() > ladder_top + 0.05 or stack_info.get("section_failed", false)):
		fall_reason = why
		jack.slip_now()
	elif ladder_top < was_top:
		pass   # it went above him: the way up is gone, and he can see it from here


func _rise() -> float:
	return jack.tuning_f("ladderLengthMetres", 5.0) - jack.tuning_f("ladderMinOverlapMetres", 1.0)


## How far the section he is on is bowing right now. Deflection under a point load peaks with the
## load at mid-span, so the ladder bounces as he climbs through the middle of a long section — the
## flex the span table promises, "visible, the ladder bounces as you climb", without a word of UI.
func _bow_now() -> float:
	var lo: float = stack_info.get("section_lower", 0.0)
	var hi: float = stack_info.get("section_upper", 0.0)
	if hi <= lo:
		return 0.0
	var u := clampf((height_m() - lo) / (hi - lo), 0.0, 1.0)
	return float(stack_info.get("flex_m", 0.0)) * sin(PI * u)


## G: rig the gin wheel on your highest dog, or — standing by it — haul the next load up.
func _gin_wheel() -> void:
	if not on_ladder:
		_say("you rig a gin wheel from the ladder")
		return
	var near_wheel: bool = gin_joint >= 0 and absf(height_m() + 0.55 - gin_height) < GIN_REACH
	if gin_joint < 0 or (not near_wheel and _top_dog_in_reach() >= 0):
		var jid := _top_dog_in_reach()
		if jid < 0:
			_say("the gin wheel lashes to a dog — drive one in within reach first")
			return
		gin_joint = jid
		gin_height = float(face.joint(jid).get("height", height_m()))
		_say("gin wheel lashed to the dog at %.0f m. G by it to haul" % gin_height)
		_build_gin()
		return
	if not near_wheel:
		_say("the gin wheel is at %.0f m — get to it" % gin_height)
		return
	if carrying_ladder:
		_say("you have a section already — lash it before you haul another")
		return
	if ladders_at_base <= 0:
		_say("nothing left in the cradle to haul")
		return
	hauling = true
	haul_steer = 0.0
	_haul_dx = 0.0
	jack.haul_begin(gin_height)
	_say("hauling — hold W to pull, and push the mouse against the swing")


## The highest seated dog his hand can reach.
func _top_dog_in_reach() -> int:
	var best := -1
	var best_h := -1.0
	var hands := height_m() + 0.55
	for i in jack.anchor_count():
		var a: Dictionary = jack.anchor_at(i)
		if a.get("failed", false):
			continue
		var h: float = a["height"]
		if absf(h - hands) <= GIN_REACH and h > best_h:
			best_h = h
			best = int(a.get("joint", -1))
	return best


func _update_haul(dt: float) -> void:
	if _gin != null:
		_draw_gin()
	if not hauling:
		return
	var pull := 1.0 if (_key(KEY_W) > 0.0 or climb_input > 0.0) else 0.0
	# The hand on the rope, from the mouse. Eased, so a flick is a push and not a teleport.
	var want := clampf(_haul_dx * HAUL_STEER_GAIN / maxf(dt * 60.0, 0.01), -1.0, 1.0)
	_haul_dx = 0.0
	haul_steer = lerpf(haul_steer, want, clampf(dt * 12.0, 0.0, 1.0))
	var load_kg: float = jack.tuning_f("ladderMassKg", 18.0) + 6.0   # a section and a bag of dogs
	haul = jack.haul_step(dt, pull, haul_steer, jack.wind_at(gin_height), load_kg)

	if haul.get("fouled", false):
		var near_him: bool = float(haul["height"]) > gin_height - 4.0
		if near_him:
			# It came round and hit him. 02-climbing-system.md §4: nerve −20, grip −40.
			jack.shock("haulHit")
			jack.grip_hit(40.0)
			_stop_haul("the load swung into you — it goes back down to the yard")
		else:
			if foley != null:
				foley.cue("bent", 0.6)
			_stop_haul("it fouled on the brickwork and slipped back down — steer against the swing")
		return
	if haul.get("arrived", false):
		hauling = false
		carrying_ladder = true
		ladders_at_base -= 1
		while dogs_carried < DOG_BAG and dogs_at_base > 0:
			dogs_carried += 1
			dogs_at_base -= 1
		if foley != null:
			foley.cue("seated", 0.8)
		_say("up — a section and a bag of dogs off the hook. %d left in the cradle" % ladders_at_base)


func _stop_haul(why: String) -> void:
	hauling = false
	haul = {}
	_say(why)


func _build_gin() -> void:
	if _gin != null:
		_gin.queue_free()
	_gin = Node3D.new()
	get_parent().add_child(_gin)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.25, 0.25, 0.26)
	iron.metallic = 0.5
	iron.roughness = 0.5
	var hemp := StandardMaterial3D.new()
	hemp.albedo_color = Color(0.64, 0.53, 0.35)
	hemp.roughness = 0.95
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.46, 0.33, 0.19)

	var wheel := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.09
	tm.outer_radius = 0.15
	tm.material = iron
	wheel.mesh = tm
	wheel.name = "Wheel"
	_gin.add_child(wheel)

	var rope := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = 1.0
	cm.material = hemp
	rope.mesh = cm
	rope.name = "Rope"
	_gin.add_child(rope)

	var bundle := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 5.0, 0.12)   # a ladder section, hung by its end
	bm.material = wood
	bundle.mesh = bm
	bundle.name = "Load"
	_gin.add_child(bundle)


## The wheel on its dog; while hauling, the rope and the load swinging on it.
func _draw_gin() -> void:
	var j: Dictionary = face.joint(gin_joint) if face != null else {}
	if j.is_empty():
		return
	var n: Vector3 = j["normal"]
	var wheel_at: Vector3 = (j["pos"] as Vector3) + chimney.global_position + n * 0.34 + Vector3.UP * 0.25
	var wheel: Node3D = _gin.get_node("Wheel")
	wheel.global_position = wheel_at
	wheel.global_rotation = Vector3(0.0, atan2(n.x, n.z), PI * 0.5)

	var rope: Node3D = _gin.get_node("Rope")
	var load_node: Node3D = _gin.get_node("Load")
	rope.visible = hauling
	load_node.visible = hauling
	if not hauling or haul.is_empty():
		return
	# The load hangs off the wheel on a pendulum in the wall's normal plane: positive swing is away
	# from the wall, and swinging back past vertical is swinging into the brickwork.
	var length := maxf(wheel_at.y - float(haul["height"]), 0.5)
	var a := deg_to_rad(float(haul["swing_deg"]))
	var load_at := wheel_at + n * sin(a) * length - Vector3.UP * cos(a) * length
	# The section hangs 2.5 m above its hook point, except in the last metres under the wheel, where
	# that would put its middle on the wheel and leave look_at nothing to look along.
	load_node.global_position = load_at - (load_at - wheel_at).normalized() * minf(2.5, length - 0.1)
	load_node.look_at_from_position(load_node.global_position, wheel_at, n.cross(Vector3.UP))
	load_node.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	rope.global_position = (wheel_at + load_at) * 0.5
	rope.look_at_from_position(rope.global_position, wheel_at, n.cross(Vector3.UP))
	rope.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	rope.scale = Vector3(1.0, wheel_at.distance_to(load_at), 1.0)


## A puff of mortar dust at a joint.
func _dust_at(id: int, amount: int) -> void:
	if face == null or id < 0:
		return
	var j: Dictionary = face.joint(id)
	if j.is_empty():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(amount * 2, 6)
	p.lifetime = 0.9
	p.explosiveness = 0.95
	p.direction = j["normal"]
	p.spread = 55.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, -1.2, 0)
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.08
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.67, 0.58)
	mat.roughness = 1.0
	m.material = mat
	p.mesh = m
	get_parent().add_child(p)
	p.global_position = (j["pos"] as Vector3) + chimney.global_position + (j["normal"] as Vector3) * 0.03
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


## A ladder section across his back.
##
## Camera and feel's first non-negotiable: "A ladder section on his back changes his silhouette
## and his gait." It was a line of HUD text — "ladder on your shoulder" — and nothing else, so
## the thing he had walked to the cradle for, and would walk back down for, was invisible. Five
## metres of it, slung diagonally, sticking out well past him either side, because that is what
## five metres of ladder does.
func _make_carried_ladder(skel: Skeleton3D) -> Node3D:
	var att := BoneAttachment3D.new()
	att.bone_name = "spine_02"
	skel.add_child(att)

	var root := Node3D.new()
	# On the right shoulder, running fore and aft along the way he walks, front end a little up so it
	# clears the ground. Slung across his back it swept the ground behind him like a boom.
	root.position = Vector3(-0.20, 0.30, 0.0)
	root.rotation = Vector3(deg_to_rad(78.0), 0.0, 0.0)
	att.add_child(root)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.46, 0.33, 0.19)
	wood.roughness = 0.9
	var length := 5.0
	for side in [-0.22, 0.22]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.06, length, 0.06)
		rm.material = wood
		rail.mesh = rm
		rail.position = Vector3(0.0, 0.0, side)
		root.add_child(rail)
	var h := -length * 0.5 + 0.28
	while h < length * 0.5:
		var rung := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.045, 0.045, 0.44)
		gm.material = wood
		rung.mesh = gm
		rung.position = Vector3(0.0, h, 0.0)
		root.add_child(rung)
		h += 0.28
	att.visible = false
	return att


## A hammer in his right hand. He was tapping and driving with nothing in it.
func _give_hammer(skel: Skeleton3D) -> void:
	var grip := BoneAttachment3D.new()
	grip.bone_name = "hand.r"
	skel.add_child(grip)

	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.22, 0.22, 0.23)
	iron.metallic = 0.6
	iron.roughness = 0.45
	var ash := StandardMaterial3D.new()
	ash.albedo_color = Color(0.55, 0.40, 0.24)
	ash.roughness = 0.8

	# A club hammer, not a tack hammer. It has to read at 4 m against brick and a ladder, and the
	# first one — a 12 cm head on a 3 cm handle, true to a jack's tapping hammer — was lost in both.
	# The steel is lighter than it would be for the same reason: it has to separate from the stack.
	iron.albedo_color = Color(0.46, 0.47, 0.50)
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.018
	hm.bottom_radius = 0.022
	hm.height = 0.36
	hm.material = ash
	handle.mesh = hm
	handle.position = Vector3(0.0, 0.13, 0.0)
	grip.add_child(handle)

	var head := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.17, 0.065, 0.065)
	bm.material = iron
	head.mesh = bm
	head.position = Vector3(0.03, 0.30, 0.0)
	grip.add_child(head)


## R: start lashing the ladder you are carrying to the highest dog in the wall.
##
## It was a keypress that lashed the section instantly and perfectly — "Press E to work", an
## interaction the player could not do better or worse, which the anti-pillars name. Now it is the
## one continuous physical input in the game: you wrap the rope by going round.
func _lash() -> void:
	if not carrying_ladder:
		_say("you are not carrying a ladder — go down to the cradle"
			if ladders_at_base > 0 else "no ladder sections left")
		return
	if not on_ladder:
		_say("you lash a ladder from the ladder")
		return
	var best: float = _lash_dog_height()
	var rise: float = jack.tuning_f("ladderLengthMetres", 5.0) - jack.tuning_f("ladderMinOverlapMetres", 1.0)
	if best < 0.0 or best + 0.1 < ladder_top - rise:
		_say("nothing to lash to — get a dog in above you, within reach")
		return
	if best + rise <= ladder_top + 0.5:
		_say("that dog is too low — a section lashed there reaches no higher. Drive one near the top")
		return
	lashing = true
	lash_joint = _joint_of_anchor_at(best)
	lash_new_top = minf(best + rise, chimney.height_m)
	lash_rate = 0.0
	_lash_signed = 0.0
	_lash_spin = 0.0
	_lash_heading = INF
	_lash_presses.clear()
	jack.lash_begin()
	chimney.set_ghost(ladder_top, lash_new_top)
	_say("lashing — %s" % _lash_how())


func _lash_how() -> String:
	match LASH_METHODS[lash_method]:
		"mash": return "tap the left button to wrap, R to tie off"
		"hold": return "hold the left button to wrap, R to tie off"
		_: return "hold the left button and go round in circles, R to tie off"


func _lash_input(event: InputEvent) -> void:
	var method: String = LASH_METHODS[lash_method]
	if event is InputEventMouseMotion and method == "rotate" \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		lash_mouse(event.relative)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and method == "mash":
			_lash_presses.append(_now)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_abandon_lash("you let the rope go")
	if event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_lash_heading = INF
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R: _tie_off()
			KEY_L:
				# VERB-006 acceptance 3: switching mid-lash does not corrupt the lashing. The rope
				# already round the stile stays round it; only the way more goes on changes.
				lash_method = (lash_method + 1) % LASH_METHODS.size()
				_lash_heading = INF
				_say("wrapping by %s — %s" % [LASH_METHODS[lash_method], _lash_how()])


## One mouse movement while wrapping. The heading of the motion turns through a full circle for
## every circle drawn, so the heading's change is the rope going round.
##
## Reversals are thrown away. A straight back-and-forth flips the heading by half a turn, and
## `wrapf` maps *both* halves of that flip to -PI — so the first version counted every waggle as a
## full turn in the same direction, and waving the mouse to and fro lashed a ladder faster than
## drawing circles. A real circle turns the heading a few degrees a frame; nothing a hand does while
## going round jumps by more than a right angle, so anything that does is not rotation.
func lash_mouse(rel: Vector2) -> void:
	if rel.length() <= 1.5:
		return
	var heading := rel.angle()
	if _lash_heading != INF:
		var turn := wrapf(heading - _lash_heading, -PI, PI)
		if absf(turn) < LASH_MAX_TURN_PER_MOVE:
			_lash_spin += turn
	_lash_heading = heading


func _update_lash(dt: float) -> void:
	if not lashing:
		return
	var instant := 0.0
	match LASH_METHODS[lash_method]:
		"rotate":
			instant = (_lash_spin / TAU) / maxf(dt, 0.0001)
			_lash_spin = 0.0
		"mash":
			while not _lash_presses.is_empty() and _now - _lash_presses[0] > 1.0:
				_lash_presses.pop_front()
			instant = jack.lash_rate_from_mash(float(_lash_presses.size()))
		"hold":
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				instant = jack.lash_rate_from_hold()
	# Smoothed, and signed for the rotate case: going round either way is a turn, going back and
	# forth is not.
	_lash_signed = lerpf(_lash_signed, instant, clampf(dt * 6.0, 0.0, 1.0))
	lash_rate = absf(_lash_signed)
	var wraps_before: int = jack.lash_state()["wraps"]
	jack.lash_step(dt, lash_rate)
	if foley != null and int(jack.lash_state()["wraps"]) > wraps_before:
		foley.cue("creak", 0.9 + 0.05 * float(wraps_before))   # each turn a touch tighter
	if face != null:
		var st: Dictionary = jack.lash_state()
		face.set_lash(lash_joint, st["wraps"], st["laid"], st["tension"])


func _tie_off() -> void:
	var kind: int = jack.lash_tie_off()
	var st: Dictionary = jack.lash_state()
	if kind == LASHING_NONE:
		_abandon_lash("%d turns will not hold a ladder — it takes %d" % [
			st["wraps"], int(jack.tuning_f("lashWrapsQuickHitch", 3))])
		return

	lashing = false
	chimney.set_ghost(0.0, 0.0)
	ladder_top = lash_new_top
	chimney.set_ladder_top(ladder_top)
	carrying_ladder = false
	sections.append({"top": ladder_top, "lashing": kind, "slipping": st["slipping"],
		"joint": lash_joint})
	var dog_h: float = face.joint(lash_joint).get("height", ladder_top) if face != null else ladder_top
	var sec: int = jack.stack_lash(_anchor_height_of_joint(lash_joint, dog_h), kind)
	if sec >= 0 and float(jack.stack_section_at(dog_h - 0.01).get("span", 0.0)) > \
			jack.tuning_f("spanSoftMetres", 4.0):
		long_spans += 1
	if face != null:
		face.keep_lash(lash_joint, st["wraps"])
		face.set_lash(-1, 0, 0.0, 0.0)
	if foley != null:
		foley.cue("seated", 0.7)

	var what := "full lashing — it will not move" if kind == LASHING_FULL else (
		"quick hitch — it will walk off the dog, a few cm a minute")
	if st["slipping"]:
		what = "tied off slack — the knot is slipping. Re-tie it before you trust it"
	_say("%s. Tops out at %.0f m" % [what, ladder_top])


func _abandon_lash(why: String) -> void:
	lashing = false
	chimney.set_ghost(0.0, 0.0)
	if face != null:
		face.set_lash(-1, 0, 0.0, 0.0)
	_say(why)


## The height the sim recorded for the dog in a joint.
func _anchor_height_of_joint(joint_id: int, fallback: float) -> float:
	for i in jack.anchor_count():
		var a: Dictionary = jack.anchor_at(i)
		if int(a.get("joint", -1)) == joint_id:
			return float(a["height"])
	return fallback


## The joint a seated dog is in, by the dog's height.
func _joint_of_anchor_at(height: float) -> int:
	for i in jack.anchor_count():
		var a: Dictionary = jack.anchor_at(i)
		if absf(float(a["height"]) - height) < 0.01:
			return int(a.get("joint", -1))
	return -1


func _pick_up() -> void:
	if not at_cradle():
		_say("the materials are in the cradle at the foot of the stack")
		return
	var took := false
	while dogs_carried < DOG_BAG and dogs_at_base > 0:
		dogs_carried += 1
		dogs_at_base -= 1
		took = true
	if not carrying_ladder and ladders_at_base > 0:
		carrying_ladder = true
		ladders_at_base -= 1
		took = true
	_say(("ladder on your shoulder, %d dogs in the bag" % dogs_carried) if took else "nothing left to take")


## Q asks for the next stance up the table. Getting there takes the time the table says.
##
## Every stance used to be instant, which quietly deleted the choice the climbing system is built
## on — belting on cost nothing, so there was never a reason not to, and the slip-save's whole
## clipped-or-not distinction was free. Rigging is work: a hand is off, so it drains at the stance
## you are *leaving*, which is also what stops a climber with nothing left belting on to recover.
func _cycle_stance() -> void:
	var here: int = jack.get_stance()
	var want: int = (here + 1) % 5

	if rigging_to >= 0:
		_say("stopped rigging")
		_cancel_rig()
		return

	if not jack.stance_needs_rigging(here, want):
		# Dropping back down the table. Unclipping is quick, and it has to be: the fastest way out
		# of a stance you cannot afford must never itself take five seconds.
		jack.set_stance(want)
		_say(jack.stance_name())
		return

	if not on_ladder:
		_say("rig a stance on the stack, not on the ground")
		return

	rigging_to = want
	rig_total = jack.stance_setup_seconds(want)
	rig_left = rig_total
	_rig_at = height_m()
	if rig_total <= 0.0:
		_finish_rig()
		return
	_say("rigging %s — %.1f s" % [jack.stance_name_of(want), rig_total])


func _cancel_rig() -> void:
	rigging_to = -1
	rig_left = 0.0
	rig_total = 0.0


func _finish_rig() -> void:
	var to := rigging_to
	_cancel_rig()
	if to >= 0:
		jack.set_stance(to)
		_say(jack.stance_name())


## Tick the rigging. Moving or working breaks it — you cannot pass a rope round a stack with the
## hand you are climbing with, and half a lashing is no lashing.
##
## The interrupt is "he moved", not "a climb key is down". The two are nearly the same thing and the
## first is the one that is actually true: it does not care how he was moved, it cannot be fooled by
## a key held against a clamp, and it is the only one a test can drive without synthesising input.
func _update_rig(dt: float) -> void:
	if rigging_to < 0:
		return
	if not on_ladder or work_mode or absf(height_m() - _rig_at) > RIG_HOLD_STILL_M:
		_say("rigging interrupted")
		_cancel_rig()
		return
	rig_left -= dt
	if rig_left <= 0.0:
		_finish_rig()


# --- what the HUD asks ---------------------------------------------------------------------------

func at_cradle() -> bool:
	var flat := Vector2(global_position.x - chimney.global_position.x,
		global_position.z - chimney.global_position.z)
	return height_m() < 2.0 and flat.length() < chimney.radius_at(0.0) + CRADLE_RADIUS


## A dog that a section lashed to would take higher than the ladder already goes. One that would
## not is not worth lashing to — a new player drives a dog at his feet, lashes, and the ladder goes
## no higher, having spent a section on nothing.
func has_lashable_anchor() -> bool:
	var best: float = _lash_dog_height()
	var rise: float = _rise()
	return best >= 0.0 and best + 0.1 >= ladder_top - rise and best + rise > ladder_top + 0.5


## The highest intact dog he can get a rope round: within reach of his hands.
##
## It was the highest dog *anywhere*, which was harmless while every dog was one he had driven —
## and stopped being harmless the moment the old fixtures put dogs in the wall at 30-42 m. Standing
## at 5 m, R lashed a section to a fixture thirty-seven metres above him and the ladder jumped to
## 45.8 m. A lashing is a rope tied by hand, so the dog has to be where his hand is. Found by
## test_ascent, the test that plays the whole climb.
func _lash_dog_height() -> float:
	var hands := height_m() + 0.55
	var reach: float = jack.tuning_f("tapTestMaxRangeMetres", 2.5)
	var best := -1.0
	for i in jack.anchor_count():
		var a: Dictionary = jack.anchor_at(i)
		if a.get("failed", false) or int(a.get("rate", 0)) == 0:
			continue
		var h: float = a["height"]
		if absf(h - hands) <= reach and h > best:
			best = h
	return best


## Whether the joint he is pointing at has been sounded.
## The span a dog in the targeted joint would make, from the top of the ladder structure — the
## single most important risk number in the game, shown before the dog goes in rather than after.
## -1 with no target.
func target_span() -> float:
	if target_id < 0 or face == null:
		return -1.0
	var h: float = float(face.joint(target_id).get("height", -1.0))
	if h < 0.0:
		return -1.0
	return h - maxf(jack.stack_top(), 0.0)


func target_tapped() -> bool:
	return target_id >= 0 and jack.joint(target_id).get("tapped", -1) >= 0


func has_tapped_here() -> bool:
	return tap_pip >= 0 and absf(tapped_at - height_m()) < 1.5
