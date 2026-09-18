# The jack.
#
# Input, camera and body. Every rule it obeys lives in SteeplejackSim behind the Jack binding:
# grip and nerve are stepped there, the stance table comes from meters.json, the structure comes
# from the level file. This script converts input into intent and reads sim state back out. It
# decides nothing — if a number here decides something, it is in the wrong file.

extends CharacterBody3D

const WALK_SPEED := 4.5
const MOUSE_SENS := 0.0022
const LADDER_REACH := 1.1        ## You are on a ladder when you can hold it, not when you are near it.
const BODY_OFF_LADDER := 0.42
const DOG_BAG := 6
const CRADLE_RADIUS := 8.0
const TOOL_CONDITION := 0.85

@onready var jack: Jack = Jack.new()
@onready var boom: SpringArm3D = $Boom
@onready var chimney: Chimney = get_node("../Chimney")

# --- the ascent ---------------------------------------------------------------------------------
var ladder_top := 5.0            ## The first section is already standing when you arrive.
var carrying_ladder := false
var dogs_carried := 0
var ladders_at_base := 12
var dogs_at_base := 14

# --- what you have read ------------------------------------------------------------------------
var tap_reading := ""
var tap_pip := -1
var tapped_at := -100.0
var message := ""
var span_warning := ""

# --- work mode ---------------------------------------------------------------------------------
var work_mode := false
var aim := Vector2.ZERO
var swing_power := 0.0
var drawing := false
var dog_depth := 0.0
var work_height := 0.0
var drift_phase := 0.0

var on_ladder := false
var _pitch := 0.0


func _ready() -> void:
	var tuning_dir := ProjectSettings.globalize_path("res://../data/tuning")
	var level_path := ProjectSettings.globalize_path("res://../data/levels/06-waterside.json")
	if not jack.load(tuning_dir, level_path):
		push_error("could not start: %s" % jack.get_last_error())
		get_tree().quit(1)
		return

	chimney.build(jack)
	chimney.set_ladder_top(ladder_top)
	# Only when there is a window to capture it in. A headless server has no mouse, and asking for
	# one there hangs the process with no output at all, which is a miserable thing to debug.
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	message = "%s. Walk to the foot of the stack." % jack.level_name()

	# Say what was loaded. A headless run cannot show a frame, so this line is the only evidence
	# that the level came off disk and the sim is answering.
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
			rotate_y(-event.relative.x * MOUSE_SENS)
			_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.2, 0.6)
			boom.rotation.x = _pitch

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E: _tap()
			KEY_R: _lash()
			KEY_F: _pick_up()
			KEY_Q: _cycle_stance()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_toggle_work_mode()
		elif event.button_index == MOUSE_BUTTON_LEFT and work_mode:
			drawing = true
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and drawing:
			_release_strike()


func _physics_process(dt: float) -> void:
	var h := global_position.y
	var ladder_world: Vector3 = chimney.global_position + chimney.face_point(h)

	# On the ladder when you can hold it. This used to be measured from the chimney's axis with a
	# generous grace, which meant you started climbing from metres away on whatever side you
	# happened to be standing.
	var flat := Vector2(global_position.x - ladder_world.x, global_position.z - ladder_world.z)
	on_ladder = flat.length() < LADDER_REACH and h < chimney.height_m

	if work_mode:
		velocity = Vector3.ZERO
	elif on_ladder:
		var climb: float = jack.tuning_f("climbSpeedMetresPerSecond", 1.6)
		var slide: float = jack.tuning_f("slideSpeedMetresPerSecond", 2.4)
		var up := Input.get_axis("ui_down", "ui_up")
		if up == 0.0:
			up = (1.0 if Input.is_key_pressed(KEY_W) else 0.0) - (1.0 if Input.is_key_pressed(KEY_S) else 0.0)
		velocity = Vector3.ZERO
		var rate: float = climb if up >= 0.0 else slide
		var want := clampf(h + up * rate * dt, 0.0, ladder_top)
		global_position.y = want

		# Holding on: above waist height the ladder has your body and the only thing you control is
		# how far up it you are. Below that you can still walk away from it.
		if want > 0.9:
			var held := ladder_world
			held.y = global_position.y
			var out: Vector3 = (held - chimney.global_position)
			out.y = 0.0
			global_position = held + out.normalized() * BODY_OFF_LADDER
	else:
		var f := (1.0 if Input.is_key_pressed(KEY_W) else 0.0) - (1.0 if Input.is_key_pressed(KEY_S) else 0.0)
		var r := (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
		var dir := (transform.basis * Vector3(r, 0, -f)).normalized()
		velocity.x = dir.x * WALK_SPEED
		velocity.z = dir.z * WALK_SPEED
		if not is_on_floor():
			velocity.y -= 24.0 * dt
		else:
			velocity.y = 0.0
		move_and_slide()

	_step_sim(dt)
	_update_work(dt)


func _step_sim(dt: float) -> void:
	var h := global_position.y
	jack.set_context(maxf(h, 0.0), 9.0, carrying_ladder, work_mode)
	jack.set_exposure(1 if on_ladder else 0)   # Ladder, else Platform
	jack.step(dt)

	# The span you are standing on: from the highest dog below you to the top of the ladder. It is
	# the entire risk economy — longer spans mean fewer anchors, which is faster, right up until
	# the section bows.
	var below: float = jack.highest_anchor_below(h)
	var span: float = h - maxf(below, 0.0)
	var band: int = jack.classify_span(span)
	span_warning = "" if band == 0 else "%.1fm span — %s" % [span, jack.span_name(band)]


# --- the verbs -----------------------------------------------------------------------------------

func _tap() -> void:
	if not on_ladder:
		message = "you have to be on the ladder to sound the brickwork"
		return
	var h := global_position.y
	var r: Dictionary = jack.tap(h, false)
	tap_reading = r["tier_name"]
	tap_pip = r["pip"]
	tapped_at = h
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
	if not _has_tapped_here():
		message = "sound the joint first — E"
		return
	if dogs_carried <= 0:
		message = "no dogs in the bag"
		return
	work_mode = true
	work_height = global_position.y
	dog_depth = 0.0
	aim = Vector2.ZERO
	message = "mouse places the dog, hold to draw, release to strike"


func _update_work(dt: float) -> void:
	if not work_mode:
		return
	if drawing:
		swing_power = clampf(swing_power + dt * 1.6, 0.0, 1.0)
	# The wobble is computed in one place, by the sim, and it eats your margin while you hold the
	# draw. That is the tension of the verb.
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
	var best: float = jack.highest_anchor_below(global_position.y + 100.0)
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
	return global_position.y < 2.0 and flat.length() < chimney.radius_at(0.0) + CRADLE_RADIUS


func has_lashable_anchor() -> bool:
	var best: float = jack.highest_anchor_below(global_position.y + 100.0)
	var rise: float = jack.tuning_f("ladderLengthMetres", 5.0) - jack.tuning_f("ladderMinOverlapMetres", 1.0)
	return best >= 0.0 and best + 0.1 >= ladder_top - rise


func _has_tapped_here() -> bool:
	return tap_pip >= 0 and absf(tapped_at - global_position.y) < 1.5
