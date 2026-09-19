# The working face: the joints around the jack, drawn as what they look like.
#
# docs/01-gdd/15-working-the-face.md is the spec, and its principle is the whole of this file:
# **every verb acts on a thing you can see, and its result stays on that thing.**
#
# The first playable build got every rule right and none of this. Pressing E changed a number and
# printed a line; no joint could be seen; the hammer's reticle floated in the middle of the screen
# attached to nothing. So this draws, for the patch of wall within reach:
#
#   - every candidate joint, showing its **visual tell** — which is the sim's `look`, a reading that
#     lies a little, never the truth (see JointGrid.h on why that lives in the sim)
#   - a bracket round the joint being pointed at
#   - a chalk mark beside every joint the player has tapped, which stays for the shift
#   - a dog standing out of every joint one was driven into
#
# Everything is a MultiMesh per kind, rebuilt only when the jack has moved far enough to matter or
# something on the face changed. The whole patch is a dozen draw calls.

class_name Face
extends Node3D

## How much wall around him is drawn joint by joint. A little more than reach, so the joints just
## out of it are visible as something to climb towards rather than popping in as you arrive.
const WINDOW := 3.2
## Move this far and the patch is rebuilt.
const REBUILD_EVERY := 0.25
## Marks sit this far proud of the face so they do not fight the brick shader for the same depth.
const PROUD := 0.006

## JointTier, worst first, as everywhere else in the project.
const CRACKED := 0
const PERISHED := 1
const FAIR := 2
const SOUND := 3

## The one accent colour the art direction allows, reserved for the player's own work.
## 13-art-direction.md: "the player's intentions remain the only bright thing in the world."
const CHALK := Color(0.863, 0.910, 0.941)

var jack
var target_id := -1

var _built_at := -999.0
var _dirty := true
var _joints: Array = []            ## what is currently drawn, from jack.joints_near
var _by_id := {}

var _look: Array[MultiMeshInstance3D] = []
var _bloom: MultiMeshInstance3D
var _crack: MultiMeshInstance3D
var _chalk_tick: MultiMeshInstance3D
var _chalk_stroke: MultiMeshInstance3D
var _chalk_cross: MultiMeshInstance3D
var _chalk_bar: MultiMeshInstance3D
var _dogs: MultiMeshInstance3D
var _lugs: MultiMeshInstance3D
var _bracket: Node3D
var _work_dog: MeshInstance3D
var _work_id := -1
var _work_depth := 0.0
var _bent: MultiMeshInstance3D
## Set by the player: joints with a dog bent into them.
var bent_ids := {}
## Dogs started and left part-driven, by how far in: the spike stands out by what is left to drive.
var started_ids := {}
## Set by the player: joints a dog was torn out of. A scar, and the joint is spent.
var pulled_ids := {}
## The old fixtures: joint id -> rust. Drawn as dogs gone orange and flaking in proportion — the
## telegraph for a dog nobody can rate.
var fixture_rust := {}
var _rusty: Array[MultiMeshInstance3D] = []
var _scars: MultiMeshInstance3D

## Anchor pips — UI-001. One at every dog on the stack, in the world rather than on the screen, so
## the player reads what he is hanging from by looking down at it. Shape and word, never colour
## alone, and a fixed size on screen so the pip on a dog twenty metres below is as legible as the
## one at his hand. The shapes are the tap pip's: a ring is sound, a square fair, a triangle poor.
var _pips := {}                  ## anchor index -> Label3D
var _pip_sig := ""
const PIP_TEXT := ["✕ pulled", "▲ poor", "■ fair", "● sound"]

## Rope round a dog's lug: {joint id: wraps} for finished lashings, plus the one going on now.
var _kept_lashes := {}
var _lash_id := -1
var _lash_wraps := 0
var _lash_laid := 0.0
var _rope: MultiMeshInstance3D
var _rope_live: MultiMeshInstance3D
const ROPE := Color(0.64, 0.53, 0.35)
const WRAP_PITCH := 0.024        ## height between turns of the coil


func _ready() -> void:
	# The tells. Each is a short stretch of bed joint, in the colour and width its condition gives
	# it. They are deliberately similar at a glance and different on inspection — the look narrows
	# a joint to about two tiers, and a tell that shouted would make the tap test pointless.
	_look.append(_bank(Vector2(0.24, 0.016), _lit(Color(0.13, 0.12, 0.11))))    # cracked: dark, open
	_look.append(_bank(Vector2(0.26, 0.030), _lit(Color(0.60, 0.53, 0.39))))    # perished: wide, sandy
	_look.append(_bank(Vector2(0.22, 0.020), _lit(Color(0.23, 0.19, 0.15))))    # fair: stained
	_look.append(_bank(Vector2(0.20, 0.011), _lit(Color(0.36, 0.35, 0.33))))    # sound: thin, crisp

	# Salt bloom round a perished-looking joint: the white crust that is the classic sign of mortar
	# that has been wet for decades.
	_bloom = _bank(Vector2(0.36, 0.16), _soft(Color(0.90, 0.89, 0.84, 0.42)))
	# A hairline running out of a cracked-looking joint into the brick either side.
	_crack = _bank(Vector2(0.30, 0.005), _lit(Color(0.07, 0.06, 0.06)))

	# Chalk. Shapes, never colours — the same rule as the tap pip, for the same reason.
	_chalk_tick = _bank(Vector2(0.07, 0.012), _chalk())
	_chalk_stroke = _bank(Vector2(0.10, 0.012), _chalk())
	_chalk_cross = _bank(Vector2(0.10, 0.012), _chalk())
	_chalk_bar = _bank(Vector2(0.10, 0.010), _chalk())

	# Dogs: the spike, and the lug the ladder lashes to.
	_dogs = _bank_box(Vector3(0.05, 0.05, 0.22), _lit(Color(0.20, 0.19, 0.18), 0.55))
	_lugs = _bank_box(Vector3(0.10, 0.03, 0.03), _lit(Color(0.22, 0.21, 0.20), 0.5))

	_bracket = _make_bracket()
	add_child(_bracket)
	_bracket.visible = false

	# The dog being driven, drawn at its real depth. The depth bar is the fallback; the dog going
	# into the wall is the reading.
	_work_dog = MeshInstance3D.new()
	var wd := BoxMesh.new()
	wd.size = Vector3(0.05, 0.05, 0.22)
	wd.material = _lit(Color(0.24, 0.23, 0.22), 0.5)
	_work_dog.mesh = wd
	_work_dog.visible = false
	add_child(_work_dog)

	# Rope: one torus per turn round the lug. Finished lashings in one bank, the one going on now in
	# another, so the live coil can be rebuilt every frame without touching the rest of the stack.
	var torus := TorusMesh.new()
	torus.inner_radius = 0.030
	torus.outer_radius = 0.046
	torus.rings = 10
	torus.ring_segments = 6
	torus.material = _lit(ROPE, 0.95)
	_rope = _wrap(torus)
	_rope_live = _wrap(torus)

	# Rusted dogs, in three grades of rust. Read at close range, as the design says it should be:
	# from the ladder the lightly rusted and the flaking are plainly different, and from the ground
	# they are all just old dogs.
	for grade in 3:
		var c := Color(0.30, 0.22, 0.17).lerp(Color(0.62, 0.30, 0.12), float(grade) / 2.0)
		_rusty.append(_bank_box(Vector3(0.05, 0.05, 0.22), _lit(c, 0.95)))

	# Where a dog was torn out: a dark, spalled hole. The cascade happened here and the wall says so.
	_scars = _bank(Vector2(0.16, 0.10), _lit(Color(0.07, 0.06, 0.05)))

	# A bent dog: the spike kinked, standing out of a joint it has spoiled.
	_bent = _bank_box(Vector3(0.045, 0.045, 0.16), _lit(Color(0.30, 0.20, 0.14), 0.7))


## Joints closer than this to the ladder's centre line are under it. The stiles are 0.44 m apart
## and a hammer cannot reach past them, and a dog there would be one the ladder cannot be lashed to
## — the lashing runs from a stile out to a lug beside it.
const UNDER_LADDER := 0.30


## Whether a joint is hidden behind the ladder.
func under_ladder(j: Dictionary) -> bool:
	if jack == null:
		return false
	var n: Vector3 = j["normal"]
	# How far round the face from the climbing line, in metres: the chord between this joint's
	# normal and the ladder's, times the radius. Near enough for 30 cm.
	var b: float = deg_to_rad(jack.climb_bearing())
	var ladder_n := Vector3(sin(b), 0.0, -cos(b))
	var r: float = Vector2(j["pos"].x, j["pos"].z).length()
	return n.distance_to(ladder_n) * r < UNDER_LADDER


## Rebuild if he has moved far enough, or the face changed.
func update_for(height: float) -> void:
	if jack == null:
		return
	update_pips()
	if not _dirty and absf(height - _built_at) < REBUILD_EVERY:
		return
	_built_at = height
	_dirty = false
	_joints = jack.joints_near(height, jack.climb_bearing(), WINDOW)
	_by_id.clear()
	for j in _joints:
		_by_id[j["id"]] = j
	_rebuild()


## Every dog on the stack gets a pip. Rebuilt only when a dog is added or one pulls.
func update_pips() -> void:
	if jack == null:
		return
	var sig := ""
	for i in jack.anchor_count():
		var a: Dictionary = jack.anchor_at(i)
		sig += "%d:%d:%s;" % [i, int(a["rate"]), str(a.get("failed", false))]
	if sig == _pip_sig:
		return
	_pip_sig = sig
	for i in jack.anchor_count():
		var a: Dictionary = jack.anchor_at(i)
		var jid: int = int(a.get("joint", -1))
		var j := joint(jid) if jid >= 0 else {}
		if j.is_empty():
			continue
		var label: Label3D = _pips.get(i)
		if label == null:
			label = Label3D.new()
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.fixed_size = true
			label.pixel_size = 0.0011
			label.font_size = 30
			label.outline_size = 10
			label.outline_modulate = Color(0.05, 0.04, 0.03, 0.85)
			label.no_depth_test = false
			label.render_priority = 5
			add_child(label)
			_pips[i] = label
		var failed: bool = a.get("failed", false)
		var rate: int = 0 if failed else clampi(int(a["rate"]), 0, 3)
		label.text = PIP_TEXT[rate]
		# An old fixture is shown as what it is — unrated — and never as what it holds. The fairness
		# table: "the fixture is unrated, never mislabelled". Its rust, on the dog itself, is the tell.
		# Chalk for the sound ones, a warning for the rest, a flare for the pulled. The words and
		# the shapes carry it; the colour is only a help.
		label.modulate = [Color(0.98, 0.45, 0.32), Color(0.96, 0.72, 0.40),
			Color(0.90, 0.88, 0.80), CHALK][rate]
		if a.get("fixture", false) and not failed:
			label.text = "? unrated"
			label.modulate = Color(0.86, 0.66, 0.48)
		var n: Vector3 = j["normal"]
		label.global_position = (j["pos"] as Vector3) + n * 0.45 + Vector3.UP * 0.18


## Something on the face changed — a tap, a dog. Redraw on the next update.
func touch() -> void:
	_dirty = true


func joint(id: int) -> Dictionary:
	if _by_id.has(id):
		return _by_id[id]
	return jack.joint(id) if jack != null else {}


## The lashing going on now: `wraps` turns and `laid` of the next round the dog at `id`.
func set_lash(id: int, wraps: int, laid: float, _tension: float) -> void:
	_lash_id = id
	_lash_wraps = wraps
	_lash_laid = laid
	var xs: Array = []
	if id >= 0:
		var j := joint(id)
		if not j.is_empty():
			xs = _coil(j, wraps)
			if laid > 0.02:
				# The turn going on, growing round the lug as the rope is laid.
				var t: Transform3D = _coil_turn(j, wraps)
				xs.append(Transform3D(t.basis.scaled(Vector3(laid, 1.0, laid)), t.origin))
	_fill(_rope_live, xs)


## A finished lashing stays on the stack. You can count them, and a hitch looks like three turns.
func keep_lash(id: int, wraps: int) -> void:
	if id < 0:
		return
	_kept_lashes[id] = wraps
	touch()


func _coil(j: Dictionary, wraps: int) -> Array:
	var xs: Array = []
	for k in wraps:
		xs.append(_coil_turn(j, k))
	return xs


func _coil_turn(j: Dictionary, k: int) -> Transform3D:
	var n: Vector3 = j["normal"]
	# Round the lug, which stands 0.21 m off the face, climbing up the lug turn by turn.
	var origin: Vector3 = j["pos"] + n * 0.19 + Vector3.UP * (float(k) - 2.5) * WRAP_PITCH
	return Transform3D(Basis(), origin)


## The dog going in: at `id`, `depth` of the way home. -1 hides it.
func set_work(id: int, depth: float) -> void:
	_work_id = id
	_work_depth = depth
	if id < 0:
		_work_dog.visible = false
		return
	var j := joint(id)
	if j.is_empty():
		_work_dog.visible = false
		return
	_work_dog.visible = true
	# The spike is 0.22 m. Unstarted, it stands its full length out of the joint; home, only the lug
	# end shows. So the length sticking out *is* the depth, readable without the bar.
	var out := 0.11 + 0.20 * (1.0 - clampf(depth, 0.0, 1.0))
	_work_dog.global_transform = _on_face(j, Vector2.ZERO, out - 0.11)


## Point at a joint. -1 hides the bracket.
func set_target(id: int) -> void:
	target_id = id
	if id < 0:
		_bracket.visible = false
		return
	var j := joint(id)
	if j.is_empty():
		_bracket.visible = false
		return
	_bracket.visible = true
	_bracket.global_transform = _on_face(j, Vector2.ZERO, PROUD * 3.0)


func _process(_dt: float) -> void:
	# A slow breath on the bracket, so the eye finds it without it shouting. It is the same for
	# every joint: the game shows you where you are pointing, never what you should choose.
	if _bracket.visible:
		var t := float(Time.get_ticks_msec()) / 1000.0
		_bracket.scale = Vector3.ONE * (1.0 + 0.06 * sin(t * 4.0))


# --- building ------------------------------------------------------------------------------------

func _rebuild() -> void:
	var look: Array = [[], [], [], []]
	var bloom: Array = []
	var crack: Array = []
	var tick: Array = []
	var stroke: Array = []
	var cross: Array = []
	var bar: Array = []
	var dogs: Array = []
	var lugs: Array = []
	var bent: Array = []
	var scars: Array = []
	var rusty: Array = [[], [], []]

	for j in _joints:
		if under_ladder(j) and not j["occupied"]:
			continue   # hidden by the ladder, and not a joint anyone can use
		var seen: int = j["look"]
		if pulled_ids.has(j["id"]):
			scars.append(_on_face(j, Vector2.ZERO, PROUD))
		elif j["occupied"] and fixture_rust.has(j["id"]):
			var grade := clampi(int(float(fixture_rust[j["id"]]) / 0.17), 0, 2)
			rusty[grade].append(_on_face(j, Vector2.ZERO, 0.11))
			lugs.append(_on_face(j, Vector2(0.0, 0.0), 0.21))
		elif j["occupied"] and bent_ids.has(j["id"]):
			bent.append(_on_face(j, Vector2(0.02, -0.03), 0.07, deg_to_rad(38.0)))
		elif started_ids.has(j["id"]):
			var left := 0.11 * (1.0 - clampf(float(started_ids[j["id"]]), 0.0, 1.0))
			dogs.append(_on_face(j, Vector2.ZERO, 0.11 + left))
			lugs.append(_on_face(j, Vector2(0.0, 0.0), 0.21 + left))
		elif j["occupied"]:
			# A driven dog: the spike standing out of the joint, and the lug across its end.
			dogs.append(_on_face(j, Vector2.ZERO, 0.11))
			lugs.append(_on_face(j, Vector2(0.0, 0.0), 0.21))
		else:
			look[seen].append(_on_face(j, Vector2.ZERO, PROUD))
			if seen == PERISHED:
				bloom.append(_on_face(j, Vector2(0.0, -0.02), PROUD * 0.5))
			elif seen == CRACKED:
				crack.append(_on_face(j, Vector2(0.10, 0.03), PROUD, deg_to_rad(28.0)))
				crack.append(_on_face(j, Vector2(-0.11, -0.025), PROUD, deg_to_rad(-22.0)))

		# Chalk, beside the joint, for whatever the player learned by tapping it.
		var learned: int = j["tapped"]
		if learned >= 0:
			var at := Vector2(0.17, 0.06)
			match learned:
				SOUND:
					tick.append(_on_face(j, at + Vector2(-0.022, -0.012), PROUD * 2.0, deg_to_rad(-45.0)))
					tick.append(_on_face(j, at + Vector2(0.022, 0.012), PROUD * 2.0, deg_to_rad(55.0), 1.6))
				FAIR:
					stroke.append(_on_face(j, at, PROUD * 2.0))
				PERISHED:
					cross.append(_on_face(j, at, PROUD * 2.0, deg_to_rad(45.0)))
					cross.append(_on_face(j, at, PROUD * 2.0, deg_to_rad(-45.0)))
				CRACKED:
					# A cross with a bar under it: "no", underlined. Cracked never holds.
					cross.append(_on_face(j, at, PROUD * 2.0, deg_to_rad(45.0)))
					cross.append(_on_face(j, at, PROUD * 2.0, deg_to_rad(-45.0)))
					bar.append(_on_face(j, at + Vector2(0.0, -0.065), PROUD * 2.0))

	for k in 4:
		_fill(_look[k], look[k])
	_fill(_bloom, bloom)
	_fill(_crack, crack)
	_fill(_chalk_tick, tick)
	_fill(_chalk_stroke, stroke)
	_fill(_chalk_cross, cross)
	_fill(_chalk_bar, bar)
	_fill(_dogs, dogs)
	_fill(_lugs, lugs)
	_fill(_bent, bent)
	_fill(_scars, scars)
	for grade in 3:
		_fill(_rusty[grade], rusty[grade])

	var rope: Array = []
	for id in _kept_lashes:
		if pulled_ids.has(id):
			continue
		var kj := joint(id)
		if not kj.is_empty():
			rope.append_array(_coil(kj, _kept_lashes[id]))
	_fill(_rope, rope)

	if target_id >= 0:
		set_target(target_id)


## A transform lying on the face at a joint, offset along the face by `along` (x round the stack,
## y up), standing `out` metres off it, rotated `spin` in the plane of the wall.
func _on_face(j: Dictionary, along: Vector2, out: float, spin: float = 0.0,
		stretch: float = 1.0) -> Transform3D:
	var n: Vector3 = j["normal"]
	# Chosen so that tangent × up = normal. The other perpendicular makes a left-handed basis, which
	# mirrors every quad — and a mirrored quad faces the wall, so the whole face was built, filled
	# with 132 joints, and back-face culled to nothing. It looked exactly like a face that had not
	# been built at all.
	var tangent := Vector3(n.z, 0.0, -n.x).normalized()
	var basis := Basis(tangent, Vector3.UP, n)
	if spin != 0.0:
		basis = basis * Basis(Vector3(0, 0, 1), spin)
	if stretch != 1.0:
		basis = basis.scaled(Vector3(stretch, 1.0, 1.0))
	var origin: Vector3 = j["pos"] + tangent * along.x + Vector3.UP * along.y + n * out
	return Transform3D(basis, origin)


func _fill(node: MultiMeshInstance3D, xforms: Array) -> void:
	var mm := node.multimesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])


# --- meshes and materials ------------------------------------------------------------------------

func _bank(size: Vector2, mat: Material) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = mat
	return _wrap(quad)


func _bank_box(size: Vector3, mat: Material) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	return _wrap(box)


func _wrap(mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _lit(col: Color, rough: float = 1.0) -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m


func _soft(col: Color) -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	return m


func _chalk() -> Material:
	# Unshaded, slightly emissive: chalk reads bright in shadow as well as in sun, and it has to,
	# because the shadowed side of the stack is where half the climbing is done.
	var m := StandardMaterial3D.new()
	m.albedo_color = CHALK
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Four corner ticks round a joint. Not a box: a box would hide the joint it is pointing at, and
## the whole point is to look at that joint.
func _make_bracket() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.92)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true   # never hidden by the dog or the brick it is pointing at
	var w := 0.17
	var h := 0.085
	var arm := 0.05
	var thick := 0.008
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for horizontal in [true, false]:
				var q := QuadMesh.new()
				q.size = Vector2(arm, thick) if horizontal else Vector2(thick, arm)
				q.material = mat
				var mi := MeshInstance3D.new()
				mi.mesh = q
				var off := Vector3(sx * (w - (arm * 0.5 if horizontal else 0.0)),
					sy * (h - (0.0 if horizontal else arm * 0.5)), 0.0)
				mi.position = off
				root.add_child(mi)
	return root
