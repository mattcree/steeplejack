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

const WALK := 5.2                ## metres per second, walking the site
const SPRINT := 9.0              ## Act 4 step 3: "a hard sprint to the safe line"
const LOOK := 0.0022             ## radians per pixel
const EYE := 1.62
const REACH := 4.5               ## how far you can reach into the brickwork

# The survey — Act 1. "Read it with the plumb bob from two orthogonal positions." Two sightings
# this far apart and you know the lean; one, or two from nearly the same place, and you do not.
const SIGHTINGS_APART_DEG := 55.0
const PEG_MIN_APART_M := 6.0     ## two pegs closer together than this are not a line

@onready var jack: Jack = Jack.new()
@onready var chimney: Chimney = $Chimney
@onready var ring: GobRing = $GobRing
@onready var hud: Control = $HUD
@onready var camera: Camera3D = $Camera
@onready var foley: Node = $Foley
@onready var site: FellSite = $Site

var level_path := "res://../data/levels/06-waterside.json"
var tuning_dir := "res://../data/tuning"

var _at := Vector3(0.0, 0.0, 14.0)   ## where you are standing, on the site
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

# The telegraphs. Rule 7: every failure has one, shipped with the failure. Rule 8: every audio cue
# has a visual fallback. A gob whose only warning was a word on a panel would fail both.
const TICKS_PER_SECOND := {"SAFE": 0.0, "UNEASY": 1.1, "CRITICAL": 3.6, "COLLAPSE": 7.0}
const GROAN_EVERY := {"SAFE": 0.0, "UNEASY": 7.0, "CRITICAL": 2.6, "COLLAPSE": 1.2}
const SHAKE_M := {"SAFE": 0.0, "UNEASY": 0.004, "CRITICAL": 0.022, "COLLAPSE": 0.06}
const SHAKE_HZ := 2.8          ## rule 20: nothing on screen moves faster than 3 Hz
const CHEER_AFTER := 4.6       ## "then - after four or five seconds - a distant cheer"

var _tick_due := 0.0
var _groan_due := 0.0
var _shake := 0.0
var _last_status := "SAFE"
var _split_seen := 0
var _cheered := false
var _dust: GPUParticles3D

# What you have established by walking about with a plumb bob and a bag of pegs.
var _sightings: Array[float] = []
var _pegs: Array[Vector3] = []
var _peg_marks: Node3D


func _ready() -> void:
	if not jack.load(ProjectSettings.globalize_path(tuning_dir),
			ProjectSettings.globalize_path(level_path)):
		push_error("felling: could not start: %s" % jack.get_last_error())
		return
	_authored = _read_level()
	_begin_gob()
	chimney.build(jack)
	ring.build(jack)
	site.build(_authored)
	_clear_the_pitch()
	hud.jack = jack
	hud.ring = ring
	hud.set_meta("exclusions", _authored.get("exclusions", []))
	_peg = _corridor_centre()
	_at = _on_bearing(_peg, 16.0)
	_face_the_chimney()
	_peg_marks = Node3D.new()
	add_child(_peg_marks)
	_build_dust()
	_capture(true)
	hud.say("Cut the gob on the side you want it to fall. Aim at the brick and press E.", 6.0)


## Dust off the gob. This is the visual half of the mortar ticking (rule 8) and the first thing a
## player sees that says the chimney is working, before any number does.
func _build_dust() -> void:
	_dust = GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = jack.structure().get("base_radius", 3.2)
	mat.emission_ring_inner_radius = float(mat.emission_ring_radius) * 0.8
	mat.emission_ring_height = 0.2
	mat.emission_ring_axis = Vector3.UP
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 12.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.7
	mat.gravity = Vector3(0.0, -1.4, 0.0)
	mat.scale_min = 0.03
	mat.scale_max = 0.11
	mat.color = Color(0.72, 0.67, 0.58, 0.5)
	_dust.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var dm := StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.vertex_color_use_as_albedo = true
	dm.albedo_color = Color(0.72, 0.67, 0.58, 0.45)
	quad.material = dm
	_dust.draw_pass_1 = quad
	_dust.amount = 80
	_dust.lifetime = 2.2
	_dust.emitting = false
	_dust.position.y = GobRing.COURSE_H * float(ring.courses)
	add_child(_dust)


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
	var site_block: Dictionary = doc.get("site", {})
	out["exclusions"] = site_block.get("exclusions", [])
	out["safe_line"] = float(site_block.get("safeLineDistance", 100.0))
	var corridor: Dictionary = site_block.get("corridor", {})
	out["corridor_from"] = float(corridor.get("fromBearing", 0.0))
	out["corridor_to"] = float(corridor.get("toBearing", 360.0))
	out["crowd"] = site_block_crowd(site_block)
	return out


## The crowd, if the level authored one that reacts. A level with no crowd gets no people.
func site_block_crowd(site_block: Dictionary) -> Dictionary:
	var crowd: Dictionary = site_block.get("crowd", {})
	return crowd if bool(crowd.get("reactsToFall", true)) else {}


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


func _on_bearing(bearing_deg: float, metres: float) -> Vector3:
	var b := deg_to_rad(bearing_deg)
	return Vector3(sin(b) * metres, 0.0, cos(b) * metres)


## Your bearing from the foot of the chimney, and how far out you are standing.
func _around() -> float:
	return fmod(rad_to_deg(atan2(_at.x, _at.z)) + 360.0, 360.0)


func _range() -> float:
	return Vector2(_at.x, _at.z).length()


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
			KEY_B: _plumb()
			KEY_P: _drive_peg()
			KEY_R: _pull_pegs()
			KEY_F: _fire()
			KEY_ESCAPE: _capture(false)


func _process(dt: float) -> void:
	if _fired:
		_after_the_fall(dt)
		_update_hud()
		return
	# You walk the site. Act 1 is a map-reading activity in first person and you cannot read a map
	# by orbiting a chimney at a fixed distance — the first version of this could not even reach
	# the pump house.
	var side := Input.get_axis("ui_left", "ui_right")
	var fwd := Input.get_axis("ui_down", "ui_up")
	if side != 0.0 or fwd != 0.0:
		var pace: float = SPRINT if Input.is_key_pressed(KEY_SHIFT) else WALK
		var f := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
		var r := Vector3(cos(_yaw), 0.0, -sin(_yaw))
		var step := (f * fwd + r * side).normalized() * pace * dt
		var want := _at + step
		# You cannot walk into the chimney, and you cannot walk off the site.
		var out: float = Vector2(want.x, want.z).length()
		var keep_out: float = float(jack.structure().get("base_radius", 3.2)) + 0.8
		if out >= keep_out and out <= _authored["safe_line"] * 2.2:
			_at = want
	_place_camera()
	_telegraph(dt)
	_update_hud()


## What the chimney is telling you, in dust, timber and noise. The words on the panel are the last
## of the four, not the first: a player who never looks at the HUD should still know.
func _telegraph(dt: float) -> void:
	var st: Dictionary = jack.gob_state()
	var status := String(st.get("status_name", "SAFE"))

	# A prop going is a bang, and you see it fold.
	var split := int(st.get("props_split", 0))
	if split > _split_seen:
		_split_seen = split
		foley.cue("propSplit")
		ring.refresh()
		hud.say("A prop has split. That load is on its neighbours now.", 5.0)

	if status != _last_status:
		_last_status = status
		if status == "CRITICAL" or status == "COLLAPSE":
			foley.cue("crack", 0.85)

	# Mortar ticking, and the dust that is its visual fallback.
	var rate: float = TICKS_PER_SECOND.get(status, 0.0)
	if _dust != null:
		_dust.emitting = rate > 0.0
		_dust.amount_ratio = clampf(rate / 4.0, 0.08, 1.0)
	if rate > 0.0:
		_tick_due -= dt
		if _tick_due <= 0.0:
			_tick_due = 1.0 / rate
			foley.cue("mortarTick", randf_range(0.88, 1.16))

	var groan: float = GROAN_EVERY.get(status, 0.0)
	if groan > 0.0:
		_groan_due -= dt
		if _groan_due <= 0.0:
			_groan_due = groan
			foley.cue("groan", randf_range(0.94, 1.06))

	# And it moves. "visible movement, screen shake" — under 3 Hz, per rule 20.
	_shake = float(SHAKE_M.get(status, 0.0))


func _face_the_chimney() -> void:
	# Looking in at the base from wherever you are standing. The yaw IS the bearing: standing at
	# bearing b you are at (sin b, cos b) and must look at (-sin b, -cos b), which is exactly where
	# Godot's -Z points when yawed by b. Adding a half turn puts your back to the chimney, which
	# is what the first frame of this scene showed.
	_yaw = deg_to_rad(_around())
	_place_camera()


func _place_camera() -> void:
	camera.position = _at + Vector3(0.0, EYE, 0.0)
	if _shake > 0.0:
		var t := Time.get_ticks_msec() / 1000.0 * TAU * SHAKE_HZ
		camera.position += Vector3(sin(t) * _shake, sin(t * 0.7) * _shake, cos(t * 1.3) * _shake)
	camera.rotation = Vector3(_pitch, _yaw, 0.0)


## "then a ground thump you feel in the subwoofer, then bricks raining, then dust, then birds,
## then - after four or five seconds - a distant cheer from the crowd. Then nothing."
func _after_the_fall(dt: float) -> void:
	if _fall == null or _fall.running() or _cheered:
		return
	_tick_due -= dt
	if _tick_due <= -CHEER_AFTER:
		_cheered = true
		foley.cue("cheer")


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
	# You have to be close enough to get a bar into it. Measured from the wall, not from the middle
	# of the chimney, so walking round does not change what you can reach.
	if _range() - float(jack.structure().get("base_radius", 3.2)) > REACH:
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


## Act 1: the plumb bob. "Read it with the plumb bob from two orthogonal positions." One reading
## from one spot tells you a chimney is out of plumb; it does not tell you which way. Two, from far
## enough apart, and you have it — and until you do, the prediction cone carries the penalty the
## sim charges for guessing.
func _plumb() -> void:
	if _fired:
		return
	var here := _around()
	for had in _sightings:
		if absf(_delta(had, here)) < SIGHTINGS_APART_DEG:
			hud.say("You have already read it from about here. Walk round the chimney and read it again.", 5.0)
			return
	_sightings.append(here)
	foley.cue("rung", 1.3)
	if surveyed():
		var s: Dictionary = jack.structure()
		hud.say("Second reading. She leans %.1f° toward %03d° — and that is the way she wants to go."
			% [float(s.get("lean_degrees", 0.0)), int(float(s.get("lean_bearing", 0.0)))], 7.0)
		_step = maxi(_step, 1)
	else:
		hud.say("A reading from %03d°. You need another from at least %d° round." % [
			int(here), int(SIGHTINGS_APART_DEG)], 6.0)


## Whether the lean has actually been established, rather than assumed.
func surveyed() -> bool:
	for i in _sightings.size():
		for j in range(i + 1, _sightings.size()):
			if absf(_delta(_sightings[i], _sightings[j])) >= SIGHTINGS_APART_DEG:
				return true
	return false


## "The player drives in two pegs. This is their public commitment and the thing they are scored
## against." Two pegs, and the line runs from the chimney out through them.
func _drive_peg() -> void:
	if _fired:
		return
	if _pegs.size() >= 2:
		hud.say("Both pegs are in. R pulls them up if you have changed your mind.", 4.0)
		return
	if _pegs.size() == 1 and _at.distance_to(_pegs[0]) < PEG_MIN_APART_M:
		hud.say("Too close to the first peg to be a line. Walk out and drive the second.", 5.0)
		return
	_pegs.append(_at)
	foley.cue("hammer", 1.1)
	_mark_pegs()
	if _pegs.size() == 1:
		hud.say("One peg in. Walk out along the line you want and drive the second.", 5.0)
		return
	# The line the two pegs make, taken outward from the chimney.
	var a := _pegs[0]
	var b := _pegs[1]
	var far: Vector3 = b if Vector2(b.x, b.z).length() > Vector2(a.x, a.z).length() else a
	_peg = fmod(rad_to_deg(atan2(far.x, far.z)) + 360.0, 360.0)
	hud.say("Pegged at %03d°. That is what you will be scored against." % int(_peg), 5.0)
	_step = 3


func _pull_pegs() -> void:
	if _fired:
		return
	_pegs.clear()
	_mark_pegs()
	hud.say("Pegs up.", 2.0)


func _mark_pegs() -> void:
	for child in _peg_marks.get_children():
		child.queue_free()
	for at in _pegs:
		var peg := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.05
		m.bottom_radius = 0.02
		m.height = 0.8
		m.radial_segments = 5
		peg.mesh = m
		peg.position = at + Vector3(0.0, 0.4, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.60, 0.85, 0.95)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		peg.material_override = mat
		_peg_marks.add_child(peg)


func _delta(from: float, to: float) -> float:
	var d := fmod(to - from + 360.0, 360.0)
	return d - 360.0 if d > 180.0 else d


func _fire() -> void:
	if _fired:
		return
	var st: Dictionary = jack.gob_state()
	if float(st.get("cut_arc", 0.0)) <= 0.0:
		hud.say("There is no gob to light. Cut one first.")
		return
	_fired = true
	_capture(false)
	var out: Dictionary = jack.fell_run(_peg, _height_removed, surveyed())
	_outcome = out
	# Act 4: you run. A hard sprint to the safe line at 1.5 x height, and then you turn round and
	# watch. The prototype does not make you run it yet, but it does put you where you would be.
	_at = _on_bearing(fmod(float(out.get("fall_bearing", 0.0)) + 55.0, 360.0), _authored["safe_line"])
	_pitch = 0.22
	_face_the_chimney()
	ring.drop()
	chimney.visible = false
	_fall = FellFall.new()
	add_child(_fall)
	var centroid: Vector2 = st.get("support_centroid", Vector2.ZERO)
	var s: Dictionary = jack.structure()
	foley.cue("crack")
	foley.cue("roar", 0.9)
	if _dust != null:
		_dust.emitting = false
	_shake = 0.0
	_fall.broke.connect(_on_broke)
	_fall.landed.connect(_on_landed)
	_fall.begin(float(s.get("height", 70.0)), float(s.get("base_radius", 3.2)),
		float(s.get("top_radius", 1.9)),
		float(out.get("fall_bearing", 0.0)), Vector3(centroid.x, 0.0, centroid.y),
		out.get("fractures", []), jack.tuning_f("fellHingeSecondsToGround", 7.5))


## The verdict is for afterwards. Putting it up the moment the match is lit covers the one thing
## the whole level was for.
func _on_broke(height_m: float) -> void:
	foley.cue("crack", 1.15)
	hud.say("she's broken at %d m" % int(height_m), 2.0)


func _on_landed() -> void:
	hud.outcome = _outcome
	foley.cue("crash")
	site.cheer()
	_cheered = false


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
	hud.prediction = jack.fell_predict(_peg, _height_removed, surveyed())
	hud.peg_bearing = _peg
	hud.height_removed = _height_removed
	hud.step = _step
	hud.surveyed = surveyed()
	hud.sightings = _sightings.size()
	hud.pegs = _pegs.size()
	hud.standing_at = Vector2(_at.x, _at.z)
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
