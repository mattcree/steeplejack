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
	"ivy": Color(0.13, 0.17, 0.10),
	"existing-band": Color(0.16, 0.13, 0.12),
	"wind-band": Color(0.34, 0.25, 0.19),
	"internal": Color(0.20, 0.20, 0.22),
	# The MVP level's own four. They were all falling through to the default, so the grey box —
	# the level the whole MVP test is run on — was one flat colour top to bottom and its four
	# bands were invisible. The legend only works if it covers the levels being played.
	"salt-bloom": Color(0.44, 0.42, 0.38),
	"old-fixtures": Color(0.24, 0.20, 0.18),
	"perished": Color(0.38, 0.32, 0.24),
}

## Weathering, top to bottom. The level file carries `sootTo` and `bleachFrom` and nothing read
## them, so the stack was one flat colour per band and looked like a cardboard tube. Soot at the
## foot and sun-bleach at the head is most of what makes brickwork read as brickwork from 60 m.
const SOOT_TINT := Color(0.09, 0.08, 0.07)
const BLEACH_TINT := Color(0.62, 0.58, 0.52)


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
		mat.albedo_color = _weathered(BAND_COLOURS.get(b["type"], Color(0.3, 0.26, 0.24)),
			(from + to) * 0.5)
		mat.roughness = 0.95
		mesh.material = mat

		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		inst.position = Vector3(0, (from + to) * 0.5, 0)
		add_child(inst)

	_cap()

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

	_cradle()
	_setup_multimesh(_ladders, Color(0.42, 0.30, 0.17))
	_setup_multimesh(_dogs, Color(0.18, 0.17, 0.16))
	add_child(_ladders)
	add_child(_dogs)
	set_ladder_top(_ladder_top)


## Sooted at the foot, bleached at the head, per the level's weathering block.
func _weathered(base: Color, h: float) -> Color:
	var t: float = clampf(h / maxf(height_m, 1.0), 0.0, 1.0)
	var soot: float = clampf(1.0 - t / 0.25, 0.0, 1.0)
	var bleach: float = clampf((t - 0.75) / 0.25, 0.0, 1.0)
	return base.lerp(SOOT_TINT, soot * 0.7).lerp(BLEACH_TINT, bleach * 0.35)


## The corbelled oversail: the flared collar every mill chimney has at the top.
##
## Without it the stack simply stopped, as a flat disc, and the top of a seventy metre climb looked
## like a mesh that had run out. The top is the thing the whole game is about arriving at.
func _cap() -> void:
	var r: float = radius_at(height_m)
	var courses := 4
	for i in courses:
		var flare: float = 1.0 + 0.10 * float(i + 1)
		var mesh := CylinderMesh.new()
		mesh.top_radius = r * flare
		mesh.bottom_radius = r * (flare - 0.10)
		mesh.height = 0.55
		mesh.radial_segments = 32
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _weathered(BAND_COLOURS["plain"], height_m).lightened(0.06)
		mat.roughness = 0.9
		mesh.material = mat
		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		inst.position = Vector3(0, height_m + 0.275 + 0.55 * i, 0)
		add_child(inst)

	# And the flue. A chimney with a solid top is a post.
	var flue := CylinderMesh.new()
	flue.top_radius = r * 0.62
	flue.bottom_radius = r * 0.62
	flue.height = 3.0
	flue.radial_segments = 24
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.03)
	dark.roughness = 1.0
	flue.material = dark
	var hole := MeshInstance3D.new()
	hole.mesh = flue
	hole.position = Vector3(0, height_m + 0.6, 0)
	add_child(hole)


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


## The cradle: the stack of materials at the foot, and the one place you can pick anything up.
##
## The HUD has been saying "the materials are in the cradle at the foot of the stack" since the verb
## existed, and there was nothing there to see. An affordance the player is told about and cannot
## point at is worse than one that is never mentioned — they go looking for it, find bare ground,
## and conclude the game is broken rather than that they are standing in the right place.
func _cradle() -> void:
	var at := FACE * (_base_r + 4.5)
	var node := Node3D.new()
	node.name = "Cradle"
	node.position = at
	add_child(node)

	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color(0.42, 0.30, 0.17)
	timber.roughness = 0.92

	# Spare ladder sections, stacked flat. The pile is the level's ladder allowance made visible.
	for i in 5:
		var m := BoxMesh.new()
		m.size = Vector3(0.44, 0.09, 5.0)
		m.material = timber
		var inst := MeshInstance3D.new()
		inst.mesh = m
		inst.position = Vector3(0.0, 0.05 + 0.10 * i, 0.0)
		inst.rotation.y = deg_to_rad(4.0 * i)
		node.add_child(inst)

	# The dog crate, and a brazier, because a jack's pitch has a fire on it.
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.18, 0.17, 0.16)
	iron.roughness = 0.75

	var crate := BoxMesh.new()
	crate.size = Vector3(1.1, 0.5, 0.8)
	crate.material = iron
	var c := MeshInstance3D.new()
	c.mesh = crate
	c.position = Vector3(1.4, 0.25, 1.6)
	node.add_child(c)

	var pot := CylinderMesh.new()
	pot.top_radius = 0.34
	pot.bottom_radius = 0.26
	pot.height = 0.7
	pot.material = iron
	var b := MeshInstance3D.new()
	b.mesh = pot
	b.position = Vector3(-1.5, 0.35, 1.2)
	node.add_child(b)

	var glow := OmniLight3D.new()
	glow.position = Vector3(-1.5, 0.75, 1.2)
	glow.light_color = Color(1.0, 0.62, 0.28)
	glow.light_energy = 3.0
	glow.omni_range = 7.0
	node.add_child(glow)


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
