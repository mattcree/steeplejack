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
const OUTER_M := 1100.0
const TERRACES := 260
const MILLS := 44
const STACKS := 26

var _boat: Node3D
var _bus: Node3D
var _boat_t := 0.0
var _bus_t := 0.35


func build(seed_text: String) -> void:
	for child in get_children():
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)

	_river()
	_rows(rng)
	_movers()


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


func _stack_mesh() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.9
	m.bottom_radius = 1.7
	m.height = 1.0
	m.radial_segments = 8
	return m


	var mat := StandardMaterial3D.new()
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
