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

	# A bent dog: the spike kinked, standing out of a joint it has spoiled.
	_bent = _bank_box(Vector3(0.045, 0.045, 0.16), _lit(Color(0.30, 0.20, 0.14), 0.7))


## Rebuild if he has moved far enough, or the face changed.
func update_for(height: float) -> void:
	if jack == null:
		return
	if not _dirty and absf(height - _built_at) < REBUILD_EVERY:
		return
	_built_at = height
	_dirty = false
	_joints = jack.joints_near(height, jack.climb_bearing(), WINDOW)
	_by_id.clear()
	for j in _joints:
		_by_id[j["id"]] = j
	_rebuild()


## Something on the face changed — a tap, a dog. Redraw on the next update.
func touch() -> void:
	_dirty = true


func joint(id: int) -> Dictionary:
	if _by_id.has(id):
		return _by_id[id]
	return jack.joint(id) if jack != null else {}


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

	for j in _joints:
		var seen: int = j["look"]
		if j["occupied"] and bent_ids.has(j["id"]):
			bent.append(_on_face(j, Vector2(0.02, -0.03), 0.07, deg_to_rad(38.0)))
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
