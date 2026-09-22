# The town below — ENV-002, and the reason the height means anything.
#
# Half of the MVP's question is "is the height impressive?", and a grey chimney standing in a white
# void answers it dishonestly. Nothing here is detail for its own sake: it is **parallax**, which is
# the strongest height cue there is. A flat plane gives you none, so from 26 m the last build looked
# exactly like 2 m, and the whole point of the game was invisible.
#
# Rule 3: generated from a seed, never hand-placed. The seed is the level's name, so Waterside's
# town is Waterside's town on every machine and in every replay, and a different level gets a
# different one for free.
#
# Cheap on purpose — three MultiMeshes and two moving props, which is four draw calls for the whole
# world. Colours are the art direction's palette (13-art-direction.md) and nothing else: brick for
# what is near enough to read as brick, soot for everything the air has taken the colour out of.

class_name Town
extends Node3D

const BRICK      := Color(0.42, 0.23, 0.17)   # #8C4A32, knocked back for distance
const BRICK_PALE := Color(0.75, 0.52, 0.40)   # #C08466
const SOOT       := Color(0.17, 0.15, 0.14)   # #2B2724
const SOOT_WARM  := Color(0.25, 0.23, 0.21)   # #403A35
const SLATE      := Color(0.20, 0.21, 0.23)

## Nothing stands closer than this: the site has to stay clear, and a building you can walk into
## is a building somebody has to model properly.
const INNER_M := 120.0
## The site: the works the chimney belongs to, between the yard and the town. It is the answer to
## "why is this chimney here", which the level never gave — a stack in an empty field with a ring
## of distant boxes round it reads as a test scene, because that is what it was.
const SITE_FROM := 22.0
const SITE_TO := 108.0
const OUTER_M := 1100.0
const TERRACES := 260
const MILLS := 44
const STACKS := 26

var _boat: Node3D
var _bus: Node3D
var _boat_t := 0.0
var _bus_t := 0.35


## `approach` is where the player starts, in this node's space. Everything on the site keeps clear
## of the line from there to the stack — which is the walk in, the establishing shot, and the first
## two minutes of the level. The first version did not, and the seed put a four-storey mill exactly
## on the spawn: the game opened with the camera inside a brown wall.
var _approach := Vector3.ZERO

func build(seed_text: String, approach: Vector3 = Vector3.ZERO) -> void:
	for child in get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	_approach = Vector3(approach.x, 0.0, approach.z)

	_river()
	_site(rng)
	_rows(rng)
	_movers()


## How far a point is from the walk in. The corridor is a segment from the spawn to the stack, not
## a ray: a building directly behind the player is fine, and one beyond the chimney is fine.
func _off_approach(at: Vector3) -> float:
	if _approach.length() < 1.0:
		return INF
	var here := Vector3(at.x, 0.0, at.z)
	var t: float = clampf(here.dot(_approach) / _approach.length_squared(), 0.0, 1.0)
	return here.distance_to(_approach * t)


## What the chimney was built to draw for. A boiler house at its foot, the mill it served, a yard
## wall with a gate in it, and the spoil of a working site.
##
## All of it outside SITE_FROM, so the ladders, the cradle and the whole first minute of the game
## still happen on clear ground — and all of it inside the town's INNER_M, which is the gap that
## made the level read as a chimney standing in a field. Placed off the seed like everything else
## (rule 3), so the Grey Box's works is the Grey Box's works on every machine.
const APPROACH_CLEAR_M := 34.0

func _site(rng: RandomNumberGenerator) -> void:
	# The boiler house. It is the reason for the flue, so it sits against the stack and its long
	# axis points at it — the one building in the level whose placement is not arbitrary. It goes
	# on the far side of the stack from the spawn, so the walk in is a walk towards a chimney with
	# a works behind it rather than a walk into the back of a mill.
	var away: float = atan2(-_approach.z, -_approach.x) if _approach.length() > 1.0 \
		else rng.randf_range(0.0, TAU)
	var bearing: float = away + rng.randf_range(-0.5, 0.5)
	var out := Vector3(cos(bearing), 0.0, sin(bearing))
	var across := Vector3(-out.z, 0.0, out.x)

	_works(out * (SITE_FROM + 9.0), Vector3(19.0, 6.2, 13.0), 2.4, bearing,
		BRICK.lerp(SOOT, 0.55))

	# The mill itself: long, four storeys, windows too far off to model and too far off to miss.
	var mill_at: Vector3 = out * (SITE_FROM + 34.0) + across * rng.randf_range(-14.0, 14.0)
	_works(mill_at, Vector3(46.0, 15.0, 17.0), 4.0, bearing + PI * 0.5, BRICK.lerp(SOOT, 0.4))

	# The engine house, at right angles to the mill, and a weaving shed with a saw-tooth roof —
	# which from the top of a chimney is the shape that says "this is a mill town" and nothing else.
	var shed_at: Vector3 = -across * (SITE_FROM + 26.0) + out * rng.randf_range(-10.0, 18.0)
	if _off_approach(shed_at) >= APPROACH_CLEAR_M:
		_slab(shed_at + Vector3(0, 2.6, 0), Vector3(38.0, 5.2, 26.0), bearing, SOOT_WARM)
		for i in 7:
			var u := (float(i) - 3.0) * 3.6
			_roof(shed_at + across * u + Vector3(0, 5.2, 0), Vector3(3.4, 1.7, 26.2), bearing,
				SLATE)

	# The yard wall, in runs. The gate is not placed — it is the run the walk in goes through,
	# which is the only place a gate could honestly be.
	for i in 16:
		var a := TAU * float(i) / 16.0
		var r := SITE_TO * 0.62
		var at := Vector3(cos(a) * r, 1.15, sin(a) * r)
		if _off_approach(at) < 9.0:
			continue
		_slab(at, Vector3(r * TAU / 16.0 * 0.92, 2.3, 0.45), -a, BRICK.lerp(SOOT, 0.66))

	# Spoil, stacked brick, and the rubbish of a site that has been worked for a hundred years.
	# Draws are taken whether the position is used or not, so the seed stays in step.
	for i in 22:
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(SITE_FROM - 6.0, SITE_TO)
		var w := rng.randf_range(1.4, 4.2)
		var h := rng.randf_range(0.6, 1.8)
		var squat := rng.randf_range(0.5, 1.1)
		var yaw := rng.randf_range(0.0, TAU)
		var tint := rng.randf()
		var at := Vector3(cos(a) * r, h * 0.5, sin(a) * r)
		# Knee-high, so it may stand much closer to the walk in than a building may.
		if _off_approach(at) < 5.0:
			continue
		_slab(at, Vector3(w, h, w * squat), yaw, SOOT_WARM.lerp(BRICK, tint))


## A building with a roof on it, if it is clear of the walk in. Silently dropped if it is not: a
## site with a gap in it is a site, and a mill on the spawn is the level opening with the camera
## inside a brown wall — which is exactly what the first seeded version did.
func _works(at: Vector3, size: Vector3, ridge: float, yaw: float, col: Color) -> void:
	if _off_approach(at) < APPROACH_CLEAR_M + size.x * 0.5:
		return
	_slab(at + Vector3(0, size.y * 0.5, 0), size, yaw, col)
	_roof(at + Vector3(0, size.y, 0), Vector3(size.x + 0.4, ridge, size.z + 0.4), yaw, SLATE)


## One box, placed. Not a MultiMesh: these are a dozen buildings that each want their own colour,
## and _bank's whole note is about why per-instance colour does not work here.
func _slab(at: Vector3, size: Vector3, yaw: float, col: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.96
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.material = mat
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.transform = Transform3D(Basis(Vector3.UP, yaw), at)
	add_child(m)


## A pitched roof: a prism, which is a box turned 45° and squashed. Flat-topped boxes are why the
## old town read as a bar chart — nothing in a mill town has a flat roof except the mill pond.
func _roof(at: Vector3, size: Vector3, yaw: float, col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var ridge_a := Vector3(-hx, size.y, 0.0)
	var ridge_b := Vector3(hx, size.y, 0.0)
	var c := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	# Two pitches and two gables. Wound so the outside faces out — the other winding gives a roof
	# you can see the underside of and nothing else, which is a very confusing five minutes.
	for tri in [[c[3], c[2], ridge_b], [c[3], ridge_b, ridge_a],
			[c[1], c[0], ridge_a], [c[1], ridge_a, ridge_b],
			[c[0], c[3], ridge_a], [c[2], c[1], ridge_b]]:
		var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		for v in tri:
			st.set_normal(nrm)
			st.add_vertex(v)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	st.set_material(mat)
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.transform = Transform3D(Basis(Vector3.UP, yaw), at)
	add_child(m)


## The water the bleachworks is named after. A long dark ribbon, because a river read from 50 m is
## a shape and a value, not a surface.
func _river() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2400, 46)
	var mat := StandardMaterial3D.new()
	# Rough and barely metallic. A mirror-smooth river reflects the whole sky and reads as a white
	# gash cut through the town, which is what it was.
	mat.albedo_color = Color(0.13, 0.16, 0.17)
	mat.roughness = 0.45
	mat.metallic = 0.1
	mesh.material = mat

	var m := MeshInstance3D.new()
	m.mesh = mesh
	# Just clear of the site, running past rather than through it.
	m.position = Vector3(0.0, 0.06, -150.0)
	m.rotation.y = deg_to_rad(9.0)
	add_child(m)


func _rows(_rng: RandomNumberGenerator) -> void:
	# Terraces: long, low, tight together. A mill town from above is stripes, and the stripes are
	# what turn into a pattern when you finally look down from the top. Two banks rather than one
	# so the roofline is not all the same value — see the note on _bank about why the variation is
	# per bank and not per instance.
	_bank(_box(), TERRACES / 2, BRICK.lerp(SOOT, 0.45), 11, _terrace)
	_bank(_box(), TERRACES / 2, BRICK.lerp(SOOT, 0.72), 12, _terrace)
	# And their roofs. Same seed, same bank size, so every roof lands on the terrace it belongs to
	# without a second list of positions to keep in step with the first. Flat-topped boxes are what
	# made the old skyline read as a bar chart; a mill town from above is slate, and slate is the
	# one surface up there that changes value as the light moves.
	_bank(_prism(), TERRACES / 2, SLATE, 11, _terrace_roof)
	_bank(_prism(), TERRACES / 2, SLATE.lerp(SOOT, 0.4), 12, _terrace_roof)

	# Mills: the big sheds. Fewer, wider, and they break the terraces up.
	_bank(_box(), MILLS, SOOT_WARM, 21, func(r):
		var a: float = r.randf_range(0.0, TAU)
		var d: float = r.randf_range(INNER_M + 20.0, OUTER_M)
		var h: float = r.randf_range(12.0, 34.0)
		return [Vector3(cos(a) * d, h * 0.5, sin(a) * d),
			Vector3(r.randf_range(30.0, 58.0), h, r.randf_range(18.0, 34.0)),
			r.randf_range(0.0, TAU)])

	# Other stacks. The one thing that tells you how tall yours is, because it is the only object
	# out there whose size the player already knows.
	_bank(_stack_mesh(), STACKS, SOOT, 31, func(r):
		var a: float = r.randf_range(0.0, TAU)
		var d: float = r.randf_range(INNER_M + 40.0, OUTER_M)
		var h: float = r.randf_range(20.0, 58.0)
		return [Vector3(cos(a) * d, h * 0.5, sin(a) * d), Vector3(1.0, h, 1.0), 0.0])


## The roof that goes on the terrace this same seed just produced. It draws from the generator in
## exactly the same order, which is the whole trick: two banks with one seed stay in step for free.
func _terrace_roof(r: RandomNumberGenerator) -> Array:
	var t := _terrace(r)
	var size: Vector3 = t[1]
	var at: Vector3 = t[0]
	return [Vector3(at.x, size.y, at.z), Vector3(size.x, 2.1, size.z + 0.5), t[2]]


func _terrace(r: RandomNumberGenerator) -> Array:
	var a: float = r.randf_range(0.0, TAU)
	var d: float = r.randf_range(INNER_M, OUTER_M)
	var h: float = r.randf_range(5.5, 9.0)
	var run: float = r.randf_range(24.0, 70.0)
	return [Vector3(cos(a) * d, h * 0.5, sin(a) * d), Vector3(run, h, 7.0),
		snappedf(a, PI * 0.5) + r.randf_range(-0.12, 0.12)]


## One MultiMesh, one draw call, `count` instances of one colour placed by `place` — which returns
## [origin, scale, yaw].
##
## The colour is on the material and not per instance. `MultiMesh.use_colors` plus
## `vertex_color_use_as_albedo` is the obvious way to vary them and it does nothing here: a probe
## that set the material albedo to pure red rendered every box pure red, so the instance colours
## were being ignored and every building had been drawing at the material's default white. That is
## what "the town is washed out" actually was — not the fog, not the exposure, not the aerial
## perspective, all three of which got adjusted while chasing it. Variation comes from splitting a
## bank in two instead, which costs one draw call and cannot silently do nothing.
func _bank(mesh: Mesh, count: int, colour: Color, bank_seed: int, place: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = bank_seed

	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count

	for i in count:
		var p: Array = place.call(rng)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, p[2]).scaled(p[1]), p[0]))

	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	# The town is scenery. Shadowing 300 boxes costs a lot and buys a smear at this distance.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _box() -> Mesh:
	var m := BoxMesh.new()
	m.size = Vector3.ONE
	return m


## A unit prism: a ridged roof one metre each way, for a MultiMesh to scale.
func _prism() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-0.5, 1.0, 0.0)
	var b := Vector3(0.5, 1.0, 0.0)
	var c := [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5),
		Vector3(-0.5, 0, 0.5)]
	for tri in [[c[3], c[2], b], [c[3], b, a], [c[1], c[0], a], [c[1], a, b],
			[c[0], c[3], a], [c[2], c[1], b]]:
		var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		for v in tri:
			st.set_normal(nrm)
			st.add_vertex(v)
	return st.commit()


func _stack_mesh() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.9
	m.bottom_radius = 1.7
	m.height = 1.0
	m.radial_segments = 8
	return m


## Two things that move, which is ENV-002's second acceptance criterion and the cue that does the
## most work. A static town below you is a photograph; one with a bus crawling along a road in it is
## a place you are a long way above.
func _movers() -> void:
	_boat = _prop(Vector3(11.0, 2.2, 3.4), Color(0.24, 0.27, 0.24))
	_bus = _prop(Vector3(9.0, 3.2, 2.6), Color(0.85, 0.25, 0.18))   # sodium red: findable from 55 m


func _prop(size: Vector3, col: Color) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	mesh.material = mat
	var m := MeshInstance3D.new()
	m.mesh = mesh
	add_child(m)
	return m


func _process(dt: float) -> void:
	if _boat == null:
		return
	# Slow. A boat that crosses the visible world in ten seconds reads as a toy, and the parallax
	# only works if the motion is slow enough that you notice it rather than watch it.
	_boat_t = fposmod(_boat_t + dt * 0.006, 1.0)
	_bus_t = fposmod(_bus_t + dt * 0.017, 1.0)

	var along := lerpf(-900.0, 900.0, _boat_t)
	_boat.position = Vector3(along, 1.4, -150.0 + along * 0.158)
	_boat.rotation.y = deg_to_rad(9.0)

	var road := lerpf(700.0, -700.0, _bus_t)
	_bus.position = Vector3(road, 1.9, 190.0)
