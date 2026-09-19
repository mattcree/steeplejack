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
const TURN_RATE := 12.0

## The stride of the run clip, in metres per second. Playback is scaled by how fast he is actually
## travelling, so his feet keep up with the ground instead of skating over it. Eyeballed — if the
## feet slip forwards, raise it; if he moonwalks, lower it.
const RUN_CLIP_SPEED := 4.6

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

const SLIP_NONE := 0
const SLIP_SAVED := 1
const SLIP_FELL := 2

@onready var jack: Jack = Jack.new()
@onready var boom: SpringArm3D = $Boom
@onready var body: Node3D = $Body
@onready var anim: AnimationPlayer = $Body/AnimationPlayer
@onready var chimney: Chimney = get_node("../Chimney")
@onready var foley: Foley = get_node_or_null("../Foley")

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
var drift_phase := 0.0

var on_ladder := false
var _yaw := 0.0
var _pitch := -0.1
var _spawn := Vector3.ZERO
var _fell_from := 0.0
var _playing := ""
var _shuffle := 0.0              ## How far sideways off the ladder line he has worked himself.
var _remount_block := 0.0
var _now := 0.0                  ## Seconds since the shift started. The HUD's clock, not the sim's.
var _climb_rate := 0.0           ## Metres per second up the ladder this frame; drives the clip.
var rigging_to := -1             ## Stance being rigged, or -1. The HUD draws the ring.
var rig_left := 0.0              ## Seconds of it still to do.
var rig_total := 0.0
var _rig_at := 0.0               ## The height he was at when he started. Moving off it breaks it.
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
	var tuning_dir := ProjectSettings.globalize_path("res://../data/tuning")
	var level_path := ProjectSettings.globalize_path("res://../data/levels/06-waterside.json")
	if not jack.load(tuning_dir, level_path):
		push_error("could not start: %s" % jack.get_last_error())
		get_tree().quit(1)
		return

	# glTF animations import unlooped, so idle and run play once and then he freezes mid-stride.
	# Nothing warns about this; the character simply stops a second or two after you start.
	for clip in ["idle", "run"]:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

	# The model has no climb, and this is a game about climbing.
	var skel: Skeleton3D = body.get_node_or_null(ClimbClip.SKELETON)
	if skel != null:
		ClimbClip.install(anim, skel)

	_spawn = global_position
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
			_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.2, 0.6)

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

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E: _tap()
			KEY_R: _lash()
			KEY_F: _pick_up()
			KEY_Q: _cycle_stance()
			KEY_SPACE: _space()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_toggle_work_mode()
		elif event.button_index == MOUSE_BUTTON_LEFT and work_mode:
			drawing = true
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and drawing:
			_release_strike()


func _physics_process(dt: float) -> void:
	_now += dt
	boom.rotation = Vector3(_pitch, _yaw, 0.0)

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
	if on_ladder and not within_reach:
		_step_off("off the ladder")

	if work_mode:
		velocity = Vector3.ZERO
	elif on_ladder:
		_climb(dt, ladder_world)
	else:
		_walk(dt)

	_step_sim(dt)
	_read_slip()
	_update_rig(dt)
	_update_work(dt)
	_animate()


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
			# is what makes the next dog measurably harder.
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
		_fall_to_ground("you had one hand on a rung and nothing else. Nothing caught you.")
		return

	if r.get("caught", false):
		# The line held. You are still on the stack, three seconds of clipping on well spent.
		fall_reason = ""
		_say("the line held — %.1f kN on a dog rated %.1f kN. Get back on." % [
			r["shock_kn"], r["capacity_kn"]])
		return

	_fall_to_ground("the dog let go: %.1f kN of shock load on one rated %.1f kN." % [
		r["shock_kn"], r["capacity_kn"]])


## The fall. **The stack stays up** — it is the checkpoint, and the whole reason a fall stings
## without wiping the twenty-five minutes you spent building it. You come back the next day and
## climb what you already built.
func _fall_to_ground(why: String) -> void:
	fall_reason = why
	_say("%s You come back the next day — your stack is still up there." % why)
	jack.new_shift()
	global_position = _spawn
	velocity = Vector3.ZERO
	on_ladder = false
	work_mode = false
	drawing = false
	_cancel_rig()
	_shuffle = 0.0
	_remount_block = REMOUNT_DELAY
	_fell_from = 0.0
	_slipping = false


func _climb(dt: float, ladder_world: Vector3) -> void:
	velocity = Vector3.ZERO
	var up := _key(KEY_W) - _key(KEY_S)
	var side := _key(KEY_D) - _key(KEY_A)

	var rate: float = (jack.tuning_f("climbSpeedMetresPerSecond", 1.6) if up >= 0.0
		else jack.tuning_f("slideSpeedMetresPerSecond", 2.4))
	var before := height_m()
	set_height_m(clampf(before + up * rate * dt, 0.0, ladder_top))
	_climb_rate = (height_m() - before) / maxf(dt, 0.0001)

	# Working yourself sideways off the stile. This has to accumulate: the first version recomputed
	# the offset from the key every frame, so it never got further than one step and you could never
	# leave.
	_shuffle += side * SHUFFLE_SPEED * dt
	if absf(_shuffle) > SHUFFLE_OFF:
		_step_off("stepped off the ladder")
		return

	# The ladder has his body: the only thing he controls is how far up it he is. Shuffling sideways
	# carries him off it, which at the foot of the stack is simply stepping off.
	var held := ladder_world
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

	if is_on_floor():
		if was_airborne and _fell_from - height_m() > KILLING_FALL:
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
		jack.shock("nearMiss")


func _fall(metres: float) -> void:
	_fall_to_ground("you dropped %.0f m onto hard ground." % metres)


## The yaw that points the model along `dir`.
##
## Mannequiny is modelled facing +Z, while a Godot node's forward is -Z. Everything that turns him
## goes through here so that offset is stated once, rather than being wrong in two places — which is
## what it was: he ran backwards facing the camera, and faced away from the wall on the ladder.
func _face(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)


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
	if on_ladder:
		want = "climb"
	elif not is_on_floor():
		want = "air_jump"
	elif speed > 0.6:
		want = "run"
	if want != _playing and anim.has_animation(want):
		anim.play(want, 0.25)
		_playing = want

	if want == "climb":
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
	jack.set_context(h, 9.0, carrying_ladder, work_mode or _slipping or rigging_to >= 0)
	if foley != null:
		foley.set_height(h)
	jack.set_exposure(2 if _slipping else (1 if on_ladder else 0))   # Hanging, Ladder, Platform
	jack.step(dt)

	# The span you are standing on: from the highest dog below you to where you are. The entire risk
	# economy — longer spans mean fewer anchors, which is faster, right up until the section bows.
	var below: float = jack.highest_anchor_below(h)
	var span: float = h - maxf(below, 0.0)
	var band: int = jack.classify_span(span)
	span_warning = "" if band == 0 else "%.1fm span — %s" % [span, jack.span_name(band)]


# --- the verbs -----------------------------------------------------------------------------------

func _tap() -> void:
	if not on_ladder:
		_say("you have to be on the ladder to sound the brickwork")
		return
	var r: Dictionary = jack.tap(height_m(), false)
	tap_reading = r["tier_name"]
	tap_pip = r["pip"]
	tapped_at = height_m()
	# The sound *is* the reading. The pip beside it is the visual fallback that rule 8 requires, and
	# is what a player who cannot hear the difference reads instead — never the only channel.
	if foley != null:
		foley.tap(r["tier"])
	_say("tapped: %s" % tap_reading)


func _toggle_work_mode() -> void:
	if work_mode:
		work_mode = false
		drawing = false
		swing_power = 0.0
		return
	if not on_ladder:
		_say("you have to be on the ladder")
		return
	if not has_tapped_here():
		_say("sound the joint first — E")
		return
	if dogs_carried <= 0:
		_say("no dogs in the bag")
		return
	work_mode = true
	work_height = height_m()
	dog_depth = 0.0
	aim = Vector2.ZERO
	_say("mouse places the dog, hold to draw, release to strike")


func _update_work(dt: float) -> void:
	if not work_mode:
		return
	if drawing:
		swing_power = clampf(swing_power + dt * 1.6, 0.0, 1.0)
	# Wobble is computed in one place, by the sim, and it eats your margin while you hold the draw.
	drift_phase += dt * 2.3
	var w: float = jack.wobble_deg(0.0)
	aim.x += sin(drift_phase) * w * dt
	aim.y += cos(drift_phase * 0.7) * w * dt


func _release_strike() -> void:
	drawing = false
	var swing_at_release := swing_power
	var err := aim.length()
	var r: Dictionary = jack.strike(work_height, dog_depth, swing_power, err, TOOL_CONDITION)
	dog_depth = clampf(dog_depth + r["depth_gain"], 0.0, 1.0)
	swing_power = 0.0

	if foley != null:
		# Pitched by how hard he swung, so a half-drawn blow sounds like one.
		foley.cue("hammer", 0.85 + 0.3 * (1.0 - swing_at_release))

	if r["bent"]:
		if foley != null:
			foley.cue("bent")
		dogs_carried -= 1
		_say("bent it. %d dogs left" % dogs_carried)
		work_mode = false
		return

	if dog_depth >= jack.seat_depth():
		if foley != null:
			foley.cue("seated")
		var a: Dictionary = jack.seat_anchor(work_height, dog_depth, r["spalled"])
		dogs_carried -= 1
		chimney.add_dog(work_height)
		_say("dog seated at %.0fm — %s, %.1f kN" % [work_height, a["rate_name"], a["capacity_kn"]])
		work_mode = false
	else:
		_say("%.0f%% in" % (dog_depth * 100.0))


func _lash() -> void:
	if not carrying_ladder:
		_say("you are not carrying a ladder — go down to the cradle"
			if ladders_at_base > 0 else "no ladder sections left")
		return
	var best: float = jack.highest_anchor_below(height_m() + 100.0)
	var rise: float = jack.tuning_f("ladderLengthMetres", 5.0) - jack.tuning_f("ladderMinOverlapMetres", 1.0)
	if best < 0.0 or best + 0.1 < ladder_top - rise:
		_say("nothing to lash to — get a dog in above you")
		return
	ladder_top = minf(best + rise, chimney.height_m)
	chimney.set_ladder_top(ladder_top)
	carrying_ladder = false
	_say("lashed — the ladder tops out at %.0fm. %d left in the cradle" % [ladder_top, ladders_at_base])


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


func has_lashable_anchor() -> bool:
	var best: float = jack.highest_anchor_below(height_m() + 100.0)
	var rise: float = jack.tuning_f("ladderLengthMetres", 5.0) - jack.tuning_f("ladderMinOverlapMetres", 1.0)
	return best >= 0.0 and best + 0.1 >= ladder_top - rise


func has_tapped_here() -> bool:
	return tap_pip >= 0 and absf(tapped_at - height_m()) < 1.5
