# The stack, built at runtime from the level file.
#
# Rule 3: no hand-placed level geometry. The scene holds sky, light and a spawn point; the structure
# is generated, from the same data/levels/*.json that the sim parses and `make validate` checks.
# What you see is what the sim thinks the level is, not a second copy of it in a scene file.
#
# One unit is one metre.

class_name Chimney
extends Node3D

## The ladder runs up one face. Everything that climbs must agree on which.
const FACE := Vector3(-1, 0, 0)
const LADDER_STANDOFF := 0.25
const RAIL_GAP := 0.44
const RUNG_GAP := 0.28
const RAIL_THICK := 0.07

var height_m: float = 0.0
var _base_r: float = 1.0
var _top_r: float = 1.0
var _ladder_top: float = 0.0
var _ladders := MultiMeshInstance3D.new()
var _dogs := MultiMeshInstance3D.new()

# Not art direction — a legend. The level file says a band is ivy or a wind band, and until there
# are real materials the stack is striped by band type so you can see the data by looking at it.
const BAND_COLOURS := {
	"plain": Color(0.29, 0.16, 0.11),
	"ivy": Color(0.12, 0.18, 0.09),
	"existing-band": Color(0.15, 0.12, 0.11),
	"wind-band": Color(0.46, 0.39, 0.32),
	"internal": Color(0.20, 0.20, 0.22),
}


func build(jack: Jack) -> void:
	for child in get_children():
		child.queue_free()

	height_m = jack.total_height()
	_base_r = jack.radius_at(0.0)
	_top_r = jack.radius_at(height_m)

	# One cylinder per band, each tapered to the batter at its own height.
	for i in jack.band_count():
		var b: Dictionary = jack.band(i)
		var from: float = b["from"]
		var to: float = b["to"]
		var mesh := CylinderMesh.new()
		mesh.top_radius = jack.radius_at(to)
		mesh.bottom_radius = jack.radius_at(from)
		mesh.height = to - from
		mesh.radial_segments = 32

		var mat := StandardMaterial3D.new()
		mat.albedo_color = BAND_COLOURS.get(b["type"], Color(0.3, 0.26, 0.24))
		mat.roughness = 0.95
		mesh.material = mat

		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		inst.position = Vector3(0, (from + to) * 0.5, 0)
		add_child(inst)

	# Collision. The stack was mesh only, which meant it was scenery rather than a thing: you could
	# walk into it, and letting go of the ladder dropped you straight through seventy metres of
	# brickwork. One cylinder per band, at that band's widest, so the surface is never inside the
	# shape you are standing against.
	var solid := StaticBody3D.new()
	solid.name = "Solid"
	add_child(solid)
	# Cut into short segments rather than one cylinder per band. A cylinder at a band's widest is
	# proud of the brickwork everywhere else, and the climber stands only 0.65 m off the face — the
	# clearance ran out before the taper did.
	const SEGMENT := 4.0
	for i in jack.band_count():
		var b: Dictionary = jack.band(i)
		var from: float = b["from"]
		var to: float = b["to"]
		var steps: int = maxi(1, int(ceil((to - from) / SEGMENT)))
		for k in steps:
			var lo: float = lerpf(from, to, float(k) / steps)
			var hi: float = lerpf(from, to, float(k + 1) / steps)
			var shape := CylinderShape3D.new()
			shape.radius = maxf(jack.radius_at(lo), jack.radius_at(hi))
			shape.height = hi - lo
			var col := CollisionShape3D.new()
			col.shape = shape
			col.position = Vector3(0, (lo + hi) * 0.5, 0)
			solid.add_child(col)

	_setup_multimesh(_ladders, Color(0.42, 0.30, 0.17))
	_setup_multimesh(_dogs, Color(0.18, 0.17, 0.16))
	add_child(_ladders)
	add_child(_dogs)
	set_ladder_top(_ladder_top)


func _setup_multimesh(node: MultiMeshInstance3D, colour: Color) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	box.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = 0
	node.multimesh = mm


## Where the ladder sits at a height, in local space.
func face_point(h: float) -> Vector3:
	return FACE * (radius_at(h) + LADDER_STANDOFF) + Vector3(0, h, 0)


## The batter, for placing geometry. Anything that *decides* something asks the sim instead.
func radius_at(h: float) -> float:
	if height_m <= 0.0:
		return _base_r
	return lerpf(_base_r, _top_r, clampf(h / height_m, 0.0, 1.0))


## Lay ladder as far as the player has lashed it, and no further. The one rule the game is built on
## is that you climb only as high as you have built, so the silhouette is a record of the ascent.
func set_ladder_top(top: float) -> void:
	_ladder_top = top
	if _ladders.multimesh == null:
		return
	if top <= 0.0:
		_ladders.multimesh.instance_count = 0
		return

	var rungs := int(floor(top / RUNG_GAP))
	var transforms: Array[Transform3D] = []

	# Two rails running the whole lashed height, drawn continuously: a seam every five metres reads
	# as a break in the ladder rather than as a joint between sections.
	for side in [-RAIL_GAP * 0.5, RAIL_GAP * 0.5]:
		var p := face_point(top * 0.5) + Vector3(0, 0, side)
		transforms.append(Transform3D(
			Basis().scaled(Vector3(RAIL_THICK, top, RAIL_THICK)), p))

	for i in range(1, rungs + 1):
		var h := i * RUNG_GAP
		transforms.append(Transform3D(
			Basis().scaled(Vector3(RAIL_THICK * 0.8, RAIL_THICK * 0.8, RAIL_GAP)),
			face_point(h)))

	_ladders.multimesh.instance_count = transforms.size()
	for i in transforms.size():
		_ladders.multimesh.set_instance_transform(i, transforms[i])


## A dog standing proud of the brickwork, so you can count them on the way down.
func add_dog(h: float) -> void:
	var mm := _dogs.multimesh
	var n := mm.instance_count
	mm.instance_count = n + 1
	mm.set_instance_transform(n, Transform3D(
		Basis().scaled(Vector3(0.34, 0.07, 0.07)),
		face_point(h) + Vector3(0.18, 0, 0.30)))
