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

const BRICK := preload("res://shaders/brick.gdshader")
const MAX_VISIBLE_BOW := 0.34

var height_m: float = 0.0
var _base_r: float = 1.0
var _top_r: float = 1.0
var _ladder_top: float = 0.0
var _ladders := MultiMeshInstance3D.new()
## Rungs in a bank of their own, because a rung is round and a stile is not. One mesh for both had
## the man climbing a lattice of square sticks, which is the sort of thing you stop seeing after a
## week of looking at it and a player notices in the first four seconds.
var _rungs := MultiMeshInstance3D.new()
var _ghost := MultiMeshInstance3D.new()
## The section bowing under him: between these heights, this far out at mid-span.
var _bow_lo := 0.0
var _bow_hi := 0.0
var _bow := 0.0
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
	"salt-bloom": Color(0.50, 0.37, 0.30),
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
		mesh.radial_segments = 64

		# Brick, courses and all, from the level's own jointGrid numbers. Weathering is done in the
		# shader per pixel now rather than once per band, so soot fades up the stack instead of
		# stepping at each band boundary.
		var mat := ShaderMaterial.new()
		mat.shader = BRICK
		mat.set_shader_parameter("brick_colour", BAND_COLOURS.get(b["type"], Color(0.3, 0.26, 0.24)))
		mat.set_shader_parameter("stack_height", height_m)
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
	_ladders.material_override = _timber()
	_setup_multimesh(_rungs, Color(0.42, 0.30, 0.17), _rung_mesh())
	_rungs.material_override = _timber()
	# The section being lashed: where it will be, not where it is. In timber colour at 45% alpha it
	# was a ladder — a frame taken mid-lash has it reading as solid, indistinguishable from the one
	# the man is standing on, so the whole verb looked like it had already happened. Chalk instead,
	# which is the colour everything provisional is drawn in, and unlit so it does not take the
	# sun and pass for wood at the top of the stack.
	_setup_multimesh(_ghost, Color(0.72, 0.80, 0.88))
	var gm := _ghost.multimesh.mesh.material as StandardMaterial3D
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color.a = 0.42
	add_child(_ghost)
	_setup_multimesh(_dogs, Color(0.18, 0.17, 0.16))
	add_child(_ladders)
	add_child(_rungs)
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
	# Its top a hair above the cap's, so the hole is what you see from the rim. Level with it, the
	# cap's own top face covered the flue and the stack had no hole in it.
	hole.position = Vector3(0, height_m + 0.275 + 0.55 * 3 + 0.275 - 1.5 + 0.01, 0)
	add_child(hole)


const TIMBER := preload("res://shaders/wood.gdshader")

## Sawn softwood, weathered, with the grain running down the length of the piece. The shader takes
## the piece's own size out of the instance transform, so one material does a stile and a rung and
## gets the grain the right way round on both.
func _timber(weather: float = 0.42) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TIMBER
	m.set_shader_parameter("weather", weather)
	return m


## A rung: round, and chamfered nowhere, because it is a turned dowel driven through the stiles.
## Eight sides — at the distance a hand is from it, eight reads as round and sixteen costs twice
## as much for nothing.
func _rung_mesh() -> Mesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.5
	c.bottom_radius = 0.5
	c.height = 1.0
	c.radial_segments = 8
	c.rings = 1
	return c


func _setup_multimesh(node: MultiMeshInstance3D, colour: Color, mesh: Mesh = null) -> void:
	var shape := mesh
	if shape == null:
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colour
		mat.roughness = 0.9
		box.material = mat
		shape = box
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = shape
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

	# Spare ladder sections, stacked flat. The pile is the level's ladder allowance made visible,
	# and it is the first thing in the game the player walks up to and looks at.
	#
	# Unit boxes turned on their side rather than a 5 m box: the timber shader reads the piece's
	# size and direction out of the instance transform, and its grain runs down the piece's local
	# Y. A section lying flat has to be *turned*, not just stretched, or the grain runs across it.
	for i in 5:
		var m := BoxMesh.new()
		m.size = Vector3(0.44, 5.0, 0.11)
		var inst := MeshInstance3D.new()
		inst.mesh = m
		inst.material_override = _timber(0.55)
		inst.position = Vector3(0.0, 0.06 + 0.115 * i, 0.0)
		inst.rotation = Vector3(PI * 0.5, deg_to_rad(4.0 * i), 0.0)
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
		_rungs.multimesh.instance_count = 0
		return

	var rungs := int(floor(top / RUNG_GAP))
	var transforms: Array[Transform3D] = []

	# Rails in rung-length pieces rather than one long box, so a section can bow. The pieces meet
	# end to end with no gap, so a straight ladder still reads as one continuous rail.
	var steps := int(ceil(top / RUNG_GAP))
	for k in steps:
		var lo := k * RUNG_GAP
		var hi := minf((k + 1) * RUNG_GAP, top)
		var mid := (lo + hi) * 0.5
		# Tilted to follow the curve, so a bowed rail is a curve and not a staircase of offset boxes.
		var slope: float = (_bow_at(hi) - _bow_at(lo)).length() * signf(
			_bow_at(hi).dot(FACE) - _bow_at(lo).dot(FACE)) / maxf(hi - lo, 0.001)
		var tilt := Basis(Vector3(0, 0, 1), atan(slope) * -FACE.x)
		for side in [-RAIL_GAP * 0.5, RAIL_GAP * 0.5]:
			# A stile is a plank on edge: narrow across the ladder, deep into the wall, which is
			# the way round that carries the load and the way round a square section does not.
			transforms.append(Transform3D(
				tilt * Basis().scaled(Vector3(RAIL_THICK * 0.72, hi - lo + 0.004,
					RAIL_THICK * 1.32)),
				face_point(mid) + Vector3(0, 0, side) + _bow_at(mid)))

	var rung: Array[Transform3D] = []
	for i in range(1, rungs + 1):
		var h := i * RUNG_GAP
		# The mesh's axis is its Y, so the rung is laid on its side — and its Y is then the run
		# across the ladder, which is exactly the direction the grain has to follow.
		# `rotation * Basis().scaled(v)`, not `rotation.scaled(v)`. Godot's `Basis.scaled` is
		# `from_scale(v) * basis` — it scales in the *parent* frame, after the rotation — so the
		# second form stretches the rung along the world's vertical instead of along its own
		# length, and turns a rung into a disc. It is the form the stiles above already use, and
		# the two are one line apart.
		rung.append(Transform3D(
			Basis(Vector3(1, 0, 0), PI * 0.5) * Basis().scaled(
				Vector3(RAIL_THICK * 0.62, RAIL_GAP + RAIL_THICK * 0.3, RAIL_THICK * 0.62)),
			face_point(h) + _bow_at(h)))

	_ladders.multimesh.instance_count = transforms.size()
	for i in transforms.size():
		_ladders.multimesh.set_instance_transform(i, transforms[i])
	_rungs.multimesh.instance_count = rung.size()
	for i in rung.size():
		_rungs.multimesh.set_instance_transform(i, rung[i])


## The section he is on bows out from the wall by `amount` at mid-span.
##
## Camera and feel §4: "Ladders visibly bend under load, proportional to span. It is a vertex
## shader and a spring, it costs nothing, and it communicates the single most important risk number
## in the game without any UI." Not a shader here — the rungs themselves move — but the same idea:
## a long span is something you see going soft under you before any number says so. Rebuilt only
## when the bow has changed by more than a few millimetres.
func set_bow(lo: float, hi: float, amount: float) -> void:
	if absf(amount - _bow) < 0.003 and absf(lo - _bow_lo) < 0.01 and absf(hi - _bow_hi) < 0.01:
		return
	_bow_lo = lo
	_bow_hi = hi
	_bow = amount
	set_ladder_top(_ladder_top)


func _bow_at(h: float) -> Vector3:
	if _bow <= 0.0 or _bow_hi <= _bow_lo or h < _bow_lo or h > _bow_hi:
		return Vector3.ZERO
	var u := (h - _bow_lo) / (_bow_hi - _bow_lo)
	# Outward, away from the wall: a ladder under load bows away from what it is lashed to.
	#
	# Capped for the eye. The sim's deflection on a buckling 10 m span is a metre and a half, which
	# is true of a ladder that is failing and reads on screen as the renderer failing instead. A
	# third of a metre is already alarming; past it, the bar and the words carry the rest.
	return FACE * minf(_bow, MAX_VISIBLE_BOW) * sin(PI * u)


## Where on the ladder a climber at this height holds on, bow included.
func bow_at(h: float) -> Vector3:
	return _bow_at(h)


## Where the cradle is, in the world: for the marker that points a player at it.
func cradle_point() -> Vector3:
	return global_position + FACE * (_base_r + 4.5)


## The stretch of wall where the next dog should go, drawn on the brick as a chalked band: a faint
## wash between two chalk lines, round the face either side of the ladder. `hi <= lo` hides it.
##
## The one thing a new player could not work out was where to put the next dog. The rules were all
## there — a span of 3 to 6 m above the last dog, within reach, high enough that the new section
## gains height — and none of it was on the wall. Now it is.
var _band: MeshInstance3D
var _band_lo := -1.0
var _band_hi := -1.0
const BAND_HALF_ARC_M := 0.9   ## how far round the face the band reaches, each side of the ladder
const BAND_PROUD := 0.012      ## off the brick, so it does not fight the brick shader for depth


func set_target_band(lo: float, hi: float) -> void:
	if absf(lo - _band_lo) < 0.02 and absf(hi - _band_hi) < 0.02:
		return
	_band_lo = lo
	_band_hi = hi
	if _band == null:
		_band = MeshInstance3D.new()
		_band.name = "TargetBand"
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_use_as_albedo = true
		_band.material_override = m
		_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_band)
	if hi <= lo:
		_band.visible = false
		return
	_band.visible = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wash := Color(0.863, 0.910, 0.941, 0.06)   # a faint wash: at 0.13 it read as a white slab
	var line := Color(0.863, 0.910, 0.941, 0.85)
	_band_strip(st, lo, hi, wash)
	for h in [lo, hi]:
		_band_strip(st, h - 0.012, h + 0.012, line)
	_band.mesh = st.commit()


## One horizontal strip of the wall's surface from `lo` to `hi`, round the face either side of it.
func _band_strip(st: SurfaceTool, lo: float, hi: float, col: Color) -> void:
	var steps := 16
	for i in steps:
		var a0 := _band_angle(i, steps, lo)
		var a1 := _band_angle(i + 1, steps, lo)
		var pts := [_band_point(a0, lo), _band_point(a1, lo), _band_point(a1, hi), _band_point(a0, hi)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.add_vertex(pts[idx])


func _band_angle(i: int, steps: int, h: float) -> float:
	var arc := BAND_HALF_ARC_M / maxf(radius_at(h), 0.1)
	return lerpf(-arc, arc, float(i) / steps)


func _band_point(angle: float, h: float) -> Vector3:
	var r := radius_at(h) + BAND_PROUD
	var face := FACE.rotated(Vector3.UP, angle)
	return face * r + Vector3(0, h, 0)


## The section being lashed, from `from` to `to`, translucent. Zero length hides it.
func set_ghost(from: float, to: float) -> void:
	var mm := _ghost.multimesh
	if mm == null:
		return
	if to <= from:
		mm.instance_count = 0
		return
	var xs: Array[Transform3D] = []
	var span := to - from
	for side in [-RAIL_GAP * 0.5, RAIL_GAP * 0.5]:
		xs.append(Transform3D(Basis().scaled(Vector3(RAIL_THICK, span, RAIL_THICK)),
			face_point(from + span * 0.5) + Vector3(0, 0, side)))
	var h := from + RUNG_GAP
	while h < to:
		xs.append(Transform3D(Basis().scaled(Vector3(RAIL_THICK * 0.8, RAIL_THICK * 0.8, RAIL_GAP)),
			face_point(h)))
		h += RUNG_GAP
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])


## A dog standing proud of the brickwork, so you can count them on the way down.
func add_dog(h: float) -> void:
	var mm := _dogs.multimesh
	var n := mm.instance_count
	mm.instance_count = n + 1
	mm.set_instance_transform(n, Transform3D(
		Basis().scaled(Vector3(0.34, 0.07, 0.07)),
		face_point(h) + Vector3(0.18, 0, 0.30)))
