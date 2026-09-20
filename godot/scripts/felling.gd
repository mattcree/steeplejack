## The felling mode — FELL-003.
##
## The demolition half of the game. You walk the base of a chimney, cut a hole in the side you want
## it to go, prop behind you as you go, watch the margin, peg the line and light it.
##
## This file owns input, the camera, and which of those four things you are doing. It owns no rules:
## whether a cell can come out, whether a prop will stand, how much margin is left and where the
## thing will land are all `Jack`, which is `SteeplejackSim`, which has tests. If you find yourself
## about to write `if margin < 0.3` here, it belongs in the sim.
##
## The level authors all of it — `mission.gob`, `structure.lean*`, `site.exclusions` — and those
## numbers are carried through to `gob_begin`/`fell_site` unexamined. Reading authored data is not
## deciding anything.
extends Node3D

const WALK := 5.0                ## metres per second round the base
const LOOK := 0.0022             ## radians per pixel
const EYE := 1.62
const REACH := 4.5               ## how far you can reach into the brickwork
const ORBIT_MIN := 5.0
const ORBIT_MAX := 26.0     ## while you are working. Watching it go, you stand at the safe line.

@onready var jack: Jack = Jack.new()
@onready var chimney: Chimney = $Chimney
@onready var ring: GobRing = $GobRing
@onready var hud: Control = $HUD
@onready var camera: Camera3D = $Camera

var level_path := "res://../data/levels/06-waterside.json"
var tuning_dir := "res://../data/tuning"

var _orbit := 12.0               ## how far out you are standing
var _around := 104.0             ## your bearing round the base
var _yaw := 0.0
var _pitch := -0.06
var _peg := 284.0
var _height_removed := 0.0
var _step := 0
var _fired := false
var _fall: FellFall
var _outcome := {}
var _authored := {}
var _mouse_wanted := true


func _ready() -> void:
	if not jack.load(ProjectSettings.globalize_path(tuning_dir),
			ProjectSettings.globalize_path(level_path)):
		push_error("felling: could not start: %s" % jack.get_last_error())
		return
	_authored = _read_level()
	_begin_gob()
	chimney.build(jack)
	ring.build(jack)
	_clear_the_pitch()
	hud.jack = jack
	hud.ring = ring
	hud.set_meta("exclusions", _authored.get("exclusions", []))
	_peg = _corridor_centre()
	_around = _peg
	_face_the_chimney()
	_capture(true)
	hud.say("Cut the gob on the side you want it to fall. Aim at the brick and press E.", 6.0)


## Everything the level authored about this felling. Data, carried through, not interpreted.
func _read_level() -> Dictionary:
	var out := {"segments": 32, "courses": 4, "props": 14, "dud": -1,
		"exclusions": [], "safe_line": 100.0, "corridor_from": 0.0, "corridor_to": 360.0,
		"mortar_bearing": -1.0, "mortar_bias": 0.0, "required_reduction": 0.0}
	var f := FileAccess.open(ProjectSettings.globalize_path(level_path), FileAccess.READ)
	if f == null:
		return out
	var doc = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(doc) != TYPE_DICTIONARY:
		return out
	var mission: Dictionary = doc.get("mission", {})
	var gob: Dictionary = mission.get("gob", {})
	out["segments"] = int(gob.get("segments", 32))
	out["courses"] = int(gob.get("courses", 4))
	out["props"] = int(gob.get("props", 14))
	var dud = gob.get("dudPropIndex", null)
	out["dud"] = -1 if dud == null else int(dud)
	var asym = gob.get("mortarAsymmetry", null)
	if typeof(asym) == TYPE_DICTIONARY:
		out["mortar_bearing"] = float(asym.get("bearing", 0.0))
		out["mortar_bias"] = float(asym.get("strengthBias", 0.0))
	out["required_reduction"] = float(mission.get("requiredHeightReduction", 0.0))
	var site: Dictionary = doc.get("site", {})
	out["exclusions"] = site.get("exclusions", [])
	out["safe_line"] = float(site.get("safeLineDistance", 100.0))
	var corridor: Dictionary = site.get("corridor", {})
	out["corridor_from"] = float(corridor.get("fromBearing", 0.0))
	out["corridor_to"] = float(corridor.get("toBearing", 360.0))
	return out


func _begin_gob() -> void:
	# What the chimney is and what it weighs are the sim's — a .gd file working out the mass of a
	# thousand tons of brickwork is a rule in the wrong layer, and the whole prop model hangs off
	# that one number.
	jack.gob_begin(_authored["segments"], _authored["courses"], _authored["props"], _authored["dud"])
	# The wind at the top is the wind that argues with a falling chimney. Its bearing is the
	# level's prevailing one; the sim only uses it as a weak pull on the fall line.
	var s: Dictionary = jack.structure()
	jack.fell_site(jack.wind_at(float(s.get("height", 70.0))), float(s.get("lean_bearing", 0.0)),
		_authored["safe_line"], int(s.get("seed", 0)), _authored["exclusions"])


## A felling is not a climb. The chimney's own base is the gob ring, so the shaft it draws has to
## start above it or the hole you cut is behind a solid wall; and the cradle of spare ladders sits
## exactly where the gob goes, which is the one place on the site you need to be able to see.
func _clear_the_pitch() -> void:
	chimney.position.y = GobRing.COURSE_H * float(ring.courses)
	var cradle := chimney.get_node_or_null("Cradle")
	if cradle != null:
		cradle.queue_free()


func _corridor_centre() -> float:
	var a: float = _authored["corridor_from"]
	var b: float = _authored["corridor_to"]
	if b < a:
		b += 360.0
	return fmod((a + b) * 0.5, 360.0)


# ---------------------------------------------------------------- input

func _capture(on: bool) -> void:
	_mouse_wanted = on
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * LOOK
		_pitch = clampf(_pitch - event.relative.y * LOOK, -1.2, 0.5)
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture(true)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_cut()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_prop()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E: _cut()
			KEY_Q: _prop()
			KEY_P: _drive_pegs()
			KEY_F: _fire()
			KEY_ESCAPE: _capture(false)


func _process(dt: float) -> void:
	if _fired:
		_update_hud()
		return
	var move := Input.get_axis("ui_left", "ui_right")
	var in_out := Input.get_axis("ui_down", "ui_up")
	_around = fmod(_around + move * WALK / maxf(_orbit, 1.0) * dt * 57.2958 + 360.0, 360.0)
	_orbit = clampf(_orbit - in_out * WALK * dt, ORBIT_MIN, ORBIT_MAX)
	_place_camera()
	_update_hud()


func _face_the_chimney() -> void:
	# Standing off at `_around`, looking in at the base. The yaw IS the bearing: a camera at
	# bearing b is at (sin b, cos b) and must look at (-sin b, -cos b), which is exactly where
	# Godot's -Z points when yawed by b. Adding a half turn puts your back to the chimney, which
	# is what the first frame of this scene showed.
	_yaw = deg_to_rad(_around)
	_place_camera()


func _place_camera() -> void:
	var b := deg_to_rad(_around)
	camera.position = Vector3(sin(b) * _orbit, EYE, cos(b) * _orbit)
	camera.rotation = Vector3(_pitch, _yaw, 0.0)


# ---------------------------------------------------------------- what you are pointing at

## Where the crosshair meets the gob ring, or null. A ray against the cylinder the ring sits on:
## cheaper than collision shapes on 128 cells and it cannot miss between them.
func _aim_point():
	var o := camera.global_position - ring.global_position
	var d := -camera.global_transform.basis.z
	var r := ring.radius
	var a := d.x * d.x + d.z * d.z
	if a < 0.0001:
		return null
	var b := 2.0 * (o.x * d.x + o.z * d.z)
	var c := o.x * o.x + o.z * o.z - r * r
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return null
	var root := sqrt(disc)
	var roots := PackedFloat32Array([(-b - root) / (2.0 * a), (-b + root) / (2.0 * a)])
	for t in roots:
		if t > 0.0:
			var hit: Vector3 = o + d * t
			if hit.y >= -0.2 and hit.y <= GobRing.COURSE_H * float(ring.courses) + 0.2:
				return ring.global_position + hit
	return null


func _aimed_cell() -> Array:
	var p = _aim_point()
	if p == null:
		return []
	if camera.global_position.distance_to(p) > _orbit + REACH:
		return []
	return ring.cell_at(p)


# ---------------------------------------------------------------- the verbs

func _cut() -> void:
	if _fired:
		return
	var cell := _aimed_cell()
	if cell.is_empty():
		hud.say("Nothing in reach. Walk in with W and aim at the brickwork.")
		return
	if not jack.gob_cut(cell[0], cell[1]):
		hud.say("That one is already out.")
		return
	ring.refresh()
	_after_change()


func _prop() -> void:
	if _fired:
		return
	var cell := _aimed_cell()
	if cell.is_empty():
		hud.say("Aim at the segment you want propped.")
		return
	if not jack.gob_prop(cell[0]):
		var st: Dictionary = jack.gob_state()
		if int(st.get("props_left", 0)) <= 0:
			hud.say("No props left. That is the budget, and it is the reason to stop cutting.", 5.0)
		else:
			hud.say("A prop goes in behind the cut. Take some brick out of that segment first.", 5.0)
		return
	ring.refresh()
	_after_change()


func _drive_pegs() -> void:
	if _fired:
		return
	_peg = fmod(_around + 180.0, 360.0)   # you sight across the chimney from where you stand
	hud.say("Pegs in at %03d°. That is what you will be scored against." % int(_peg), 4.0)
	_step = 3


func _fire() -> void:
	if _fired:
		return
	var st: Dictionary = jack.gob_state()
	if float(st.get("cut_arc", 0.0)) <= 0.0:
		hud.say("There is no gob to light. Cut one first.")
		return
	_fired = true
	_capture(false)
	var out: Dictionary = jack.fell_run(_peg, _height_removed)
	_outcome = out
	# Act 4: you run. A hard sprint to the safe line at 1.5 x height, and then you turn round and
	# watch. The prototype does not make you run it yet, but it does put you where you would be.
	_orbit = _authored["safe_line"]
	_around = fmod(float(out.get("fall_bearing", 0.0)) + 55.0, 360.0)
	_pitch = 0.22
	_face_the_chimney()
	ring.drop()
	chimney.visible = false
	_fall = FellFall.new()
	add_child(_fall)
	var centroid: Vector2 = st.get("support_centroid", Vector2.ZERO)
	var s: Dictionary = jack.structure()
	_fall.landed.connect(_on_landed)
	_fall.begin(float(s.get("height", 70.0)), float(s.get("base_radius", 3.2)),
		float(s.get("top_radius", 1.9)),
		float(out.get("fall_bearing", 0.0)), Vector3(centroid.x, 0.0, centroid.y),
		out.get("fractures", []), jack.tuning_f("fellHingeSecondsToGround", 7.5))


## The verdict is for afterwards. Putting it up the moment the match is lit covers the one thing
## the whole level was for.
func _on_landed() -> void:
	hud.outcome = _outcome


func _after_change() -> void:
	var st: Dictionary = jack.gob_state()
	if _step < 1 and float(st.get("cut_arc", 0.0)) > 0.0:
		_step = 1
	if _step < 2 and int(st.get("props_standing", 0)) > 0:
		_step = 2
	var name_ := String(st.get("status_name", "SAFE"))
	if name_ == "COLLAPSE":
		hud.say("It is going. You are in the hole.", 6.0)
	elif name_ == "CRITICAL" :
		hud.say("That is moving. Get a prop in or get out.", 4.0)


func _update_hud() -> void:
	var st: Dictionary = jack.gob_state()
	hud.state = st
	hud.prediction = jack.fell_predict(_peg, _height_removed)
	hud.peg_bearing = _peg
	hud.height_removed = _height_removed
	hud.step = _step
	var cell := _aimed_cell()
	if cell.is_empty() or _fired:
		hud.aim_seg = -1
		hud.aim_verb = ""
	else:
		hud.aim_seg = cell[0]
		hud.aim_course = cell[1]
		var c: Dictionary = jack.gob_cell(cell[0], cell[1])
		var p: Dictionary = jack.gob_prop_at(cell[0])
		if bool(p.get("present", false)):
			hud.aim_verb = "propped — %.0f kN on it" % float(p.get("load_kn", 0.0))
		elif bool(c.get("removed", false)):
			hud.aim_verb = "cut away — [RMB] stand a prop here"
		else:
			hud.aim_verb = "course %d, mortar %s — [LMB] cut it out" % [
				cell[1] + 1, "soft" if float(c.get("strength", 1.0)) < 0.9 else "sound"]
