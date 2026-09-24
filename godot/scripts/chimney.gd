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
## The iron bands, on a banding job: a strap per band and a bolt per bolt.
var _straps: Node3D
var _bolts := MultiMeshInstance3D.new()
var _band_specs: Array = []
## How many sides she has, and what is on top of her. From the level, not from taste.
const SIDES := {"round": 64, "octagonal": 8, "square": 4}
var _sides := 64
var _cap_kind := "corbelled-oversail"


## The circumradius the mesh wants, from the half-width across the flats that the level states.
##
## A level's `baseRadius` is the distance to the *wall*, because that is the number the ladder
## stands off and the joints are laid on. For a round shaft they are the same thing; for a square
## one the corners are 41% further out, and building the mesh at the wall distance would put the
## flats inside the brickwork the player is climbing.
func _mesh_radius(h: float) -> float:
	if _sides >= 32:
		return radius_at(h)
	return radius_at(h) / cos(PI / float(_sides))


## Turned so a flat faces the climbing line. CylinderMesh puts a vertex at angle zero; half a
## segment of spin puts a face centre there instead, and the ladder lies on brickwork rather than
## bridging a corner.
func _profile_spin() -> float:
	return 0.0 if _sides >= 32 else PI / float(_sides)
## The lightning conductor: a terminal at the apex, copper tape down the face, a holdfast at every
## clip, and an earth plate in a pit at the foot.
var _run := MultiMeshInstance3D.new()
var _run_extras: Node3D

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

	# What shape she is. The schema has carried `profile` and `cap` since it was written and
	# nothing has ever read either, so the square chimney in a back yard, the octagonal corn mill
	# and the spire at St Anne's all came out as the same sixty-four-sided tube. Photographs of
	# real mill chimneys are the argument: square and octagonal shafts are everywhere, and the top
	# is where a builder showed off.
	var st: Dictionary = jack.structure()
	_sides = SIDES.get(String(st.get("profile", "round")), 64)
	_cap_kind = String(st.get("cap", "corbelled-oversail"))

	# Out of plumb, if she is. A compass bearing, the same convention the wind uses: north is -Z.
	var deg: float = float(st.get("lean_degrees", 0.0))
	var bearing: float = deg_to_rad(float(st.get("lean_bearing", 0.0)))
	_lean_dir = Vector3(sin(bearing), 0.0, -cos(bearing))
	_lean_top = tan(deg_to_rad(deg)) * height_m

	# One cylinder per band, each tapered to the batter at its own height.
	for i in jack.band_count():
		var b: Dictionary = jack.band(i)
		var from: float = b["from"]
		var to: float = b["to"]
		var mesh := CylinderMesh.new()
		mesh.top_radius = _mesh_radius(to)
		mesh.bottom_radius = _mesh_radius(from)
		mesh.height = to - from
		mesh.radial_segments = _sides

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
		var mid: float = (from + to) * 0.5
		inst.position = Vector3(0, mid, 0) + lean_offset(mid)
		inst.rotation.y = _profile_spin()
		# Tagged so the lean can be changed later without rebuilding the stack: a straightening
		# moves her a few centimetres a day and she has to move while the player is looking.
		inst.set_meta("shaft_at", mid)
		# `from` and `to` as well as the midpoint, so a topping job can clip her back without a
		# rebuild — see `set_top`.
		inst.set_meta("shaft_from", from)
		inst.set_meta("shaft_to", to)
		add_child(inst)

	var before_cap := get_child_count()
	_cap()
	# The cap is the first thing off a chimney you are topping and it has to go when she does.
	for ci in range(before_cap, get_child_count()):
		get_child(ci).set_meta("cap_part", true)

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
			var cmid: float = (lo + hi) * 0.5
			col.position = Vector3(0, cmid, 0) + lean_offset(cmid)
			col.set_meta("shaft_from", lo)
			col.set_meta("shaft_to", hi)
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
## What is on top of her, which on a real chimney is the only place the builder showed off.
##
## Four kinds, all of them already in the level files and none of them ever read: a plain shaft
## that just stops, the corbelled oversail every mill chimney has, a capped one with a slab over
## the flue, and a spire with a finial on it. Photographs are the argument — the tops are what
## make one chimney recognisably not another from half a mile away.
func _cap() -> void:
	var r: float = _mesh_radius(height_m)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = _weathered(BAND_COLOURS["plain"], height_m).lightened(0.06)
	stone.roughness = 0.9

	match _cap_kind:
		"plain":
			# Two courses of header brick and nothing else. A working chimney in a back yard.
			_cap_ring(r * 1.06, r * 1.04, 0.36, height_m + 0.18, stone)
			# `at` is the flue cylinder's CENTRE and the cylinder is 3 m tall, so the top of it
			# lands 1.5 m above whatever you pass. Passed the cap's own top, as this did, the
			# result is a three-metre black tube standing proud of the chimney — a plain-capped
			# stack had a drum on it, wider and darker than her own brickwork, visible from the
			# ground on every job that used this cap. The corbelled branch below has always
			# subtracted the 1.5 and this one never did.
			_flue(r * 0.58, height_m + 0.36 - 1.5)
		"capped":
			# Slabbed over: a flue taken out of service, which is why she is a gasworks job.
			_cap_ring(r * 1.10, r * 1.06, 0.44, height_m + 0.22, stone)
			var lid := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = r * 1.12
			lm.bottom_radius = r * 1.12
			lm.height = 0.22
			lm.radial_segments = _sides
			lm.material = stone
			lid.mesh = lm
			lid.position = Vector3(0, height_m + 0.55, 0) + lean_offset(height_m)
			lid.rotation.y = _profile_spin()
			lid.set_meta("shaft_at", height_m)
			add_child(lid)
		"finial":
			# A spire, not a shaft. She tapers to almost nothing and carries an iron finial, and
			# the whole job at St Anne's is that the last five metres are a spike.
			for i in 3:
				var f: float = 1.0 - 0.22 * float(i)
				_cap_ring(r * (f + 0.10), r * f, 0.5, height_m + 0.25 + 0.5 * float(i), stone)
			var spike := MeshInstance3D.new()
			var sm := CylinderMesh.new()
			sm.top_radius = 0.02
			sm.bottom_radius = 0.09
			sm.height = 2.2
			sm.radial_segments = 8
			var iron := StandardMaterial3D.new()
			iron.albedo_color = Color(0.29, 0.27, 0.25)
			iron.metallic = 0.55
			iron.roughness = 0.45
			sm.material = iron
			spike.mesh = sm
			spike.position = Vector3(0, height_m + 2.8, 0) + lean_offset(height_m)
			spike.set_meta("shaft_at", height_m)
			add_child(spike)
		_:
			# The corbelled oversail: four courses stepping out, which is the one nearly every
			# mill chimney in the country has.
			for i in 4:
				var flare: float = 1.0 + 0.10 * float(i + 1)
				_cap_ring(r * flare, r * (flare - 0.10), 0.55,
					height_m + 0.275 + 0.55 * float(i), stone)
			_flue(r * 0.62, height_m + 0.275 + 0.55 * 3.0 + 0.275 - 1.5 + 0.01)


## One course of the cap: a ring `top` wide at the top and `bottom` at the bottom.
func _cap_ring(top: float, bottom: float, tall: float, at: float,
		mat: StandardMaterial3D) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = tall
	mesh.radial_segments = _sides
	mesh.material = mat
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = Vector3(0, at, 0) + lean_offset(height_m)
	inst.rotation.y = _profile_spin()
	inst.set_meta("shaft_at", height_m)
	add_child(inst)


## The hole. A chimney with a solid top is a post.
func _flue(r: float, at: float) -> void:
	var flue := CylinderMesh.new()
	flue.top_radius = r
	flue.bottom_radius = r
	flue.height = 3.0
	flue.radial_segments = maxi(_sides, 12)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.03)
	dark.roughness = 1.0
	flue.material = dark
	var hole := MeshInstance3D.new()
	hole.mesh = flue
	hole.position = Vector3(0, at, 0) + lean_offset(height_m)
	hole.rotation.y = _profile_spin()
	hole.set_meta("shaft_at", height_m)
	add_child(hole)


const TIMBER := preload("res://shaders/wood.gdshader")

## Sawn softwood, weathered, with the grain running down the length of the piece. The shader takes
## the piece's own size out of the instance transform, so one material does a stile and a rung and
## gets the grain the right way round on both.
## Static, because the carried section is built by player.gd and is the same ladder as the ones on
## the stack. Two definitions of "what a ladder is made of" is how one of them gets left behind.
static func timber(weather: float = 0.42) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TIMBER
	m.set_shader_parameter("weather", weather)
	return m


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
	# Not black. At 0.18 the brazier and the dog crate read as holes cut in the ground — cast iron
	# in daylight is a mid grey with a sheen on it, and these two are the first objects in the
	# game the player walks up to.
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.31, 0.29, 0.28)
	iron.roughness = 0.55
	iron.metallic = 0.4

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


## Take her down to `h` metres. For TOP jobs, where the player removes brickwork while standing on
## it.
##
## This CLIPS rather than rebuilds. `build()` frees every child it has, which would take the
## ladders, the dogs, the bands and the cradle with it — and the player is stood on those. So the
## shaft segments are shortened in place and the ones entirely above the new top are hidden,
## collision included, because a chimney you have taken twelve metres off that still stops you
## walking through the twelve metres is worse than one that never shortened at all.
func set_top(h: float) -> void:
	if h <= 0.0:
		return
	height_m = h
	for child in get_children():
		if bool(child.get_meta("cap_part", false)):
			# She has no cap while she is coming down. A new one goes on at the finish.
			child.visible = false
		if child.has_meta("shaft_from"):
			_clip(child, h, true)
	var solid := get_node_or_null("Solid")
	if solid != null:
		for col in solid.get_children():
			if col.has_meta("shaft_from"):
				_clip(col, h, false)


## One segment, shaft or collision, cut off at `h`.
func _clip(node: Node3D, h: float, is_mesh: bool) -> void:
	var from: float = float(node.get_meta("shaft_from"))
	var to: float = float(node.get_meta("shaft_to"))
	if from >= h:
		node.visible = false
		if not is_mesh and node is CollisionShape3D:
			(node as CollisionShape3D).disabled = true
		return
	node.visible = true
	if not is_mesh and node is CollisionShape3D:
		(node as CollisionShape3D).disabled = false
	var top: float = minf(to, h)
	var tall: float = maxf(top - from, 0.01)
	var mid: float = (from + top) * 0.5
	if is_mesh:
		var mesh: CylinderMesh = (node as MeshInstance3D).mesh as CylinderMesh
		if mesh != null:
			mesh.height = tall
			mesh.top_radius = _mesh_radius(top)
	elif node is CollisionShape3D:
		var shape: CylinderShape3D = (node as CollisionShape3D).shape as CylinderShape3D
		if shape != null:
			shape.height = tall
	node.position = Vector3(0, mid, 0) + lean_offset(mid)


## Where the ladder sits at a height, in local space.
func face_point(h: float) -> Vector3:
	return FACE * (radius_at(h) + LADDER_STANDOFF) + Vector3(0, h, 0) + lean_offset(h)


# --- the lean --------------------------------------------------------------------------------
#
# Pitchcombe Mill is one point one degrees over and the whole job is bringing her back. The level
# has said `leanDegrees: 1.1` since it was written and nothing read it, so the chimney the player
# was sent to straighten stood perfectly plumb — the defining fact of the level, invisible.
#
# It is a **shear**, not a rotation of this node: every axis is still vertical and every height is
# still a height, so `chimney.global_position + chimney.face_point(h)` — which the player, the
# tests and five other scripts all use to find the wall — keeps working untouched. At 1.1° the
# difference between shearing a shaft and tilting it is under a millimetre anywhere on it.
var _lean_dir := Vector3.ZERO
var _lean_top := 0.0            ## how far the head is out of plumb, in metres

## How far out of plumb the shaft is at `h`.
func lean_offset(h: float) -> Vector3:
	if _lean_top == 0.0 or height_m <= 0.0:
		return Vector3.ZERO
	return _lean_dir * (_lean_top * clampf(h / height_m, 0.0, 1.0))


## She is coming back. Called as a straightening settles, so the shaft moves while you watch it.
func set_lean(metres_at_top: float) -> void:
	if absf(metres_at_top - _lean_top) < 0.002:
		return
	_lean_top = metres_at_top
	for child in get_children():
		if child is MeshInstance3D and child.has_meta("shaft_at"):
			child.position.x = lean_offset(float(child.get_meta("shaft_at"))).x
			child.position.z = lean_offset(float(child.get_meta("shaft_at"))).z
	var solid := get_node_or_null("Solid")
	if solid != null:
		for col in solid.get_children():
			if col is CollisionShape3D:
				col.position.x = lean_offset(col.position.y).x
				col.position.z = lean_offset(col.position.y).z
	set_ladder_top(_ladder_top)


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


# --- the lightning conductor ---------------------------------------------------------------------
#
# A conductor job is: a terminal at the very top, then run copper tape down her and clip it as you
# go, then an earth pit at the foot. It shipped with a checklist, a panel that counted the tape
# and the clips, a verdict — and, like the bands, nothing on the chimney. The player set a
# terminal that did not appear, ran a tape that was not there, and clipped it to a wall that never
# showed a single holdfast.
#
# The thing that matters most to get on the screen is the **wander**. The 1881 Code's rule is that
# the run between two points may be no longer than one and a half times the straight line, and
# keeping it straight is the craft — so the tape is drawn through the clips where they actually
# went, laterally as well as vertically. A run that wandered looks like a run that wandered, from
# the ground, for ever.

const TAPE_OFF_LADDER := 0.62   ## clear of the right stile, so it is not inside the ladder
const TAPE_PROUD := 0.035

## `clips` is Vector2(height, lateral offset) per fixing, top first. `head` is where the tape has
## been paid out to below the last clip — the loose end in his hand.
func set_run(clips: Array, head: float, terminal: bool) -> void:
	if _run.multimesh == null:
		_setup_multimesh(_run, Color(0.52, 0.33, 0.16))
		var rm := _run.multimesh.mesh.material as StandardMaterial3D
		# Copper, and not new copper: a run goes green in a season and black in ten.
		rm.albedo_color = Color(0.36, 0.30, 0.20)
		rm.metallic = 0.65
		rm.roughness = 0.44
		add_child(_run)
	if _run_extras == null:
		_run_extras = Node3D.new()
		_run_extras.name = "RunExtras"
		add_child(_run_extras)
	for child in _run_extras.get_children():
		child.queue_free()

	var xs: Array[Transform3D] = []
	var points: Array[Vector3] = []
	for c in clips:
		points.append(_tape_point(float((c as Vector2).x), float((c as Vector2).y)))
	# The loose end, below the last clip. It hangs on the line he is standing on.
	if not clips.is_empty() and head < float((clips[clips.size() - 1] as Vector2).x) - 0.05:
		points.append(_tape_point(head, float((clips[clips.size() - 1] as Vector2).y)))

	for i in range(1, points.size()):
		xs.append_array(_tape_run(points[i - 1], points[i]))
	_run.multimesh.instance_count = xs.size()
	for i in xs.size():
		_run.multimesh.set_instance_transform(i, xs[i])

	# A holdfast at every clip: a copper cleat driven into the joint, which is the thing the
	# player is actually judged on — too hard and it is pinched, too loose and it works off.
	var cleat := StandardMaterial3D.new()
	cleat.albedo_color = Color(0.42, 0.34, 0.22)
	cleat.metallic = 0.5
	cleat.roughness = 0.5
	for c in clips:
		var at := _tape_point(float((c as Vector2).x), float((c as Vector2).y))
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.10, 0.05, 0.13)
		m.mesh = bm
		m.material_override = cleat
		m.position = at + FACE * 0.02
		_run_extras.add_child(m)

	if terminal:
		# The finial: a copper rod standing off the cap, which is the one part of a conductor run
		# anybody on the ground has ever been able to see.
		var rod := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.012
		cy.bottom_radius = 0.026
		cy.height = 1.15
		cy.radial_segments = 8
		rod.mesh = cy
		rod.material_override = cleat
		rod.position = Vector3(0, height_m + 0.62, 0) + FACE * (_top_r * 0.55)
		_run_extras.add_child(rod)


## The earth pit at the foot: a plate in coke, which is where a run ends and is the only part of
## the job that happens on the ground.
func set_earth(ohms: float) -> void:
	if _run_extras == null or ohms < 0.0:
		return
	var pit := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.75
	cy.bottom_radius = 0.75
	cy.height = 0.08
	cy.radial_segments = 16
	pit.mesh = cy
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.13, 0.12, 0.11)
	m.roughness = 0.95
	pit.material_override = m
	pit.position = _tape_point(0.06, 0.0) + FACE * 0.7
	_run_extras.add_child(pit)


## Where the tape sits at a height, `lateral` metres to one side of the climbing line.
func _tape_point(h: float, lateral: float) -> Vector3:
	return face_point(h) + Vector3(0, 0, TAPE_OFF_LADDER + lateral) + FACE * -TAPE_PROUD


## A straight length of tape from `a` to `b`, in short pieces so it hugs the batter.
func _tape_run(a: Vector3, b: Vector3) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var span := (b - a).length()
	if span < 0.01:
		return out
	var pieces := maxi(int(span / 0.5), 1)
	for k in pieces:
		var lo: Vector3 = a.lerp(b, float(k) / float(pieces))
		var hi: Vector3 = a.lerp(b, float(k + 1) / float(pieces))
		var mid := (lo + hi) * 0.5
		var d := hi - lo
		var up := d.normalized()
		var side := up.cross(Vector3(FACE.x, 0.0, FACE.z)).normalized()
		if side.length() < 0.5:
			side = Vector3(0, 0, 1)
		var fwd := side.cross(up)
		# 25 mm by 3 mm — the Code's own section, and flat against the wall.
		out.append(Transform3D(Basis(side * 0.025, up * (d.length() + 0.01), fwd * 0.004), mid))
	return out


# --- the iron bands -----------------------------------------------------------------------------
#
# A banding job is: go up, stand level with a band, and pull its bolts up in a star until she is
# round again. It shipped with a checklist, a ring in the HUD, a bolt count, a verdict — and
# nothing on the chimney. The player was told to stand level with a band that did not exist and
# tighten bolts they could not see, which made the one thing the archetype is *about* — that
# working round the ring pulls her oval and working across it does not — completely invisible.
#
# So the band is a strap round her with a bolt standing out of it at each lug, and **how far a
# bolt stands out is how slack it is**. Pulled home it is a stub; untouched it is a finger's
# length of thread. That is the same trick `Face.set_work` uses for a dog going in, for the same
# reason: a length you can see beats a bar you have to read, and the star pattern becomes a shape
# on the chimney rather than a number in the corner.

const BAND_PROUD_M := 0.035     ## how far the strap stands off the brickwork
const BAND_DEEP := 0.17         ## the strap's own height
const BOLT_OUT_SLACK := 0.20   ## thread showing on a bolt nobody has touched
const BOLT_OUT_HOME := 0.028    ## and on one that is home

## Build the straps. `specs` is the mission's own `bands` list: {height, bolts}.
func set_bands(specs: Array) -> void:
	_band_specs = specs
	if _straps != null:
		_straps.queue_free()
	_straps = Node3D.new()
	_straps.name = "Bands"
	add_child(_straps)

	# Cold iron on sooty brick is two dark things, and the first thing the checklist asks of the
	# player is to *find* a band. So it keeps a little sheen: wrought iron picks the sky up along
	# its length, which is what separates a strap from the wall behind it at forty metres.
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.29, 0.28, 0.28)
	iron.roughness = 0.46
	iron.metallic = 0.55

	for spec in specs:
		var h: float = float((spec as Dictionary).get("height", 0.0))
		var r: float = radius_at(h) + BAND_PROUD_M
		var strap := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r + 0.012     # the batter, over the strap's own depth
		cm.height = BAND_DEEP
		cm.radial_segments = 40
		cm.material = iron
		strap.mesh = cm
		strap.position = Vector3(0, h, 0)
		_straps.add_child(strap)

	_setup_multimesh(_bolts, Color(0.33, 0.31, 0.29))
	if _bolts.get_parent() == null:
		add_child(_bolts)
	set_band_tension(-1, PackedFloat32Array())


## Lay the bolts out. `index` -1 rebuilds every band from whatever `tension` the caller last gave
## each of them; otherwise only that band's tensions are updated.
var _band_tension: Array = []

func set_band_tension(index: int, tension: PackedFloat32Array) -> void:
	while _band_tension.size() < _band_specs.size():
		_band_tension.append(PackedFloat32Array())
	if index >= 0 and index < _band_tension.size():
		_band_tension[index] = tension
	if _bolts.multimesh == null:
		return

	var xs: Array[Transform3D] = []
	for i in _band_specs.size():
		var spec: Dictionary = _band_specs[i]
		var h: float = float(spec.get("height", 0.0))
		var n: int = maxi(int(spec.get("bolts", 8)), 1)
		var r: float = radius_at(h) + BAND_PROUD_M
		var pulls: PackedFloat32Array = _band_tension[i]
		for k in n:
			var t: float = clampf(pulls[k] if k < pulls.size() else 0.0, 0.0, 1.0)
			var out: float = lerpf(BOLT_OUT_SLACK, BOLT_OUT_HOME, t)
			var a: float = TAU * float(k) / float(n)
			var dir := Vector3(sin(a), 0.0, cos(a))
			# Along the radius, so its own length is the thread showing. The mesh is a unit box,
			# so the scale gives the bolt its section and its length in one.
			var basis := Basis(Vector3(dir.z, 0.0, -dir.x), Vector3.UP, dir)
			xs.append(Transform3D(basis * Basis().scaled(Vector3(0.062, 0.062, out)),
				dir * (r + out * 0.5) + Vector3(0, h, 0)))
	_bolts.multimesh.instance_count = xs.size()
	for i in xs.size():
		_bolts.multimesh.set_instance_transform(i, xs[i])


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
##
## `binding` separates the two jobs this one mesh does. Carrying a section past a dog you could
## use, it is a *guide* — "that is where this would go" — and it has to be quiet, because it is on
## the screen for the whole climb and it is a suggestion. With the rope actually going round it is
## the section itself, held against the wall, and then it is the thing you are looking at.
##
## They were the same weight, and at chalk they were both loud: a bright pale ladder hanging over
## you at all times, which reads as a second ladder rather than as advice.
func set_ghost(from: float, to: float, binding: bool = false) -> void:
	var gm := _ghost.multimesh.mesh.material as StandardMaterial3D
	if gm != null:
		gm.albedo_color.a = 0.42 if binding else 0.17
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
