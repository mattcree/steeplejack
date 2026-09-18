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
const MOUSE_SENS := 0.0025
const TURN_RATE := 12.0

## The stride of the run clip, in metres per second. Playback is scaled by how fast he is actually
## travelling, so his feet keep up with the ground instead of skating over it. Eyeballed — if the
## feet slip forwards, raise it; if he moonwalks, lower it.
const RUN_CLIP_SPEED := 4.6

const LADDER_REACH := 0.9        ## You are on a ladder when you can hold it.
const BODY_OFF_LADDER := 0.40
const MOUNT_HEIGHT := 1.6        ## You get on a ladder from the ground, not by brushing past it.
const KILLING_FALL := 4.0        ## Metres. Below this you land; above it you do not.

const DOG_BAG := 6
const CRADLE_RADIUS := 8.0
const TOOL_CONDITION := 0.85

@onready var jack: Jack = Jack.new()
@onready var boom: SpringArm3D = $Boom
@onready var body: Node3D = $Body
@onready var anim: AnimationPlayer = $Body/AnimationPlayer
@onready var chimney: Chimney = get_node("../Chimney")

var ladder_top := 5.0
var carrying_ladder := false
var dogs_carried := 0
var ladders_at_base := 12
var dogs_at_base := 14

var tap_reading := ""
var tap_pip := -1
var tapped_at := -100.0
var message := ""
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

	_spawn = global_position
	chimney.build(jack)
	chimney.set_ladder_top(ladder_top)
	# Only when there is a window to capture it in. A headless server has no mouse, and asking for
	# one there hangs the process with no output at all, which is a miserable thing to debug.
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	message = "%s. Walk to the foot of the stack." % jack.level_name()
	print("steeplejack: %s — %.0f m, %d bands, tuning %s" % [
		jack.level_name(), jack.total_height(), jack.band_count(), jack.tuning_hash().substr(0, 12)])


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

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E: _tap()
			KEY_R: _lash()
			KEY_F: _pick_up()
			KEY_Q: _cycle_stance()
			KEY_SPACE: _let_go()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_toggle_work_mode()
		elif event.button_index == MOUSE_BUTTON_LEFT and work_mode:
			drawing = true
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and drawing:
			_release_strike()


func _physics_process(dt: float) -> void:
	boom.rotation = Vector3(_pitch, _yaw, 0.0)

	var ladder_world: Vector3 = chimney.global_position + chimney.face_point(height_m())
	var to_ladder := Vector2(global_position.x - ladder_world.x, global_position.z - ladder_world.z)
	var within_reach := to_ladder.length() < LADDER_REACH + BODY_OFF_LADDER

	# You get on a ladder from the ground. Attaching at whatever height you happen to pass is what
	# made it impossible to step off: you left, and the next frame put you straight back on.
	if not on_ladder and within_reach and height_m() <= MOUNT_HEIGHT and is_on_floor():
		on_ladder = true
		message = "on the ladder"
	if on_ladder and not within_reach:
		on_ladder = false

	if work_mode:
		velocity = Vector3.ZERO
	elif on_ladder:
		_climb(dt, ladder_world)
	else:
		_walk(dt)

	_step_sim(dt)
	_update_work(dt)
	_animate()


func _climb(dt: float, ladder_world: Vector3) -> void:
	velocity = Vector3.ZERO
	var up := _key(KEY_W) - _key(KEY_S)
	var side := _key(KEY_D) - _key(KEY_A)

	var rate: float = (jack.tuning_f("climbSpeedMetresPerSecond", 1.6) if up >= 0.0
		else jack.tuning_f("slideSpeedMetresPerSecond", 2.4))
	set_height_m(clampf(height_m() + up * rate * dt, 0.0, ladder_top))

	# The ladder has his body: the only thing he controls is how far up it he is. Shuffling sideways
	# carries him off it, which at the foot of the stack is simply stepping off.
	var held := ladder_world
	held.y = global_position.y
	var out := held - chimney.global_position
	out.y = 0.0
	out = out.normalized()
	var tangent := Vector3(-out.z, 0.0, out.x)
	global_position = held + out * BODY_OFF_LADDER + tangent * side * 0.9
	body.global_rotation.y = _face(-out)   # into the brickwork, not away from it

	if height_m() <= 0.02 and up < 0.0:
		on_ladder = false
		message = "off the ladder"


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


func _let_go() -> void:
	if not on_ladder:
		return
	on_ladder = false
	_fell_from = height_m()
	if height_m() > KILLING_FALL:
		message = "you let go"
		jack.shock("nearMiss")


func _fall(metres: float) -> void:
	message = "you fell %.0f m. Back to the cradle." % metres
	global_position = _spawn
	velocity = Vector3.ZERO
	on_ladder = false
	_fell_from = 0.0


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
	if not on_ladder and not is_on_floor():
		want = "air_jump"
	elif not on_ladder and speed > 0.6:
		want = "run"
	if want != _playing and anim.has_animation(want):
		anim.play(want, 0.2)
		_playing = want


func _key(k: Key) -> float:
	return 1.0 if Input.is_key_pressed(k) else 0.0


func _step_sim(dt: float) -> void:
	var h := maxf(height_m(), 0.0)
	jack.set_context(h, 9.0, carrying_ladder, work_mode)
	jack.set_exposure(1 if on_ladder else 0)   # Ladder, else Platform
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
		message = "you have to be on the ladder to sound the brickwork"
		return
	var r: Dictionary = jack.tap(height_m(), false)
	tap_reading = r["tier_name"]
	tap_pip = r["pip"]
	tapped_at = height_m()
	message = "tapped: %s" % tap_reading


func _toggle_work_mode() -> void:
	if work_mode:
		work_mode = false
		drawing = false
		swing_power = 0.0
		return
	if not on_ladder:
		message = "you have to be on the ladder"
		return
	if not has_tapped_here():
		message = "sound the joint first — E"
		return
	if dogs_carried <= 0:
		message = "no dogs in the bag"
		return
	work_mode = true
	work_height = height_m()
	dog_depth = 0.0
	aim = Vector2.ZERO
	message = "mouse places the dog, hold to draw, release to strike"


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
	var err := aim.length()
	var r: Dictionary = jack.strike(work_height, dog_depth, swing_power, err, TOOL_CONDITION)
	dog_depth = clampf(dog_depth + r["depth_gain"], 0.0, 1.0)
	swing_power = 0.0

	if r["bent"]:
		dogs_carried -= 1
		message = "bent it. %d dogs left" % dogs_carried
		work_mode = false
		return

	if dog_depth >= jack.seat_depth():
		var a: Dictionary = jack.seat_anchor(work_height, dog_depth, r["spalled"])
		dogs_carried -= 1
		chimney.add_dog(work_height)
		message = "dog seated at %.0fm — %s, %.1f kN" % [work_height, a["rate_name"], a["capacity_kn"]]
		work_mode = false
	else:
		message = "%.0f%% in" % (dog_depth * 100.0)


func _lash() -> void:
	if not carrying_ladder:
		message = ("you are not carrying a ladder — go down to the cradle"
			if ladders_at_base > 0 else "no ladder sections left")
		return
	var best: float = jack.highest_anchor_below(height_m() + 100.0)
	var rise: float = jack.tuning_f("ladderLengthMetres", 5.0) - jack.tuning_f("ladderMinOverlapMetres", 1.0)
	if best < 0.0 or best + 0.1 < ladder_top - rise:
		message = "nothing to lash to — get a dog in above you"
		return
	ladder_top = minf(best + rise, chimney.height_m)
	chimney.set_ladder_top(ladder_top)
	carrying_ladder = false
	message = "lashed — the ladder tops out at %.0fm. %d left in the cradle" % [ladder_top, ladders_at_base]


func _pick_up() -> void:
	if not at_cradle():
		message = "the materials are in the cradle at the foot of the stack"
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
	message = ("ladder on your shoulder, %d dogs in the bag" % dogs_carried) if took else "nothing left to take"


func _cycle_stance() -> void:
	jack.set_stance((jack.get_stance() + 1) % 5)
	message = jack.stance_name()


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
