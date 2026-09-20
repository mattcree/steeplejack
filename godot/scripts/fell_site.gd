## The site you are felling into — FELL-004.
##
## The town (town.gd) starts at 120 m and is scenery. This is the 120 m the town leaves out: the
## things the level authored that you can actually hit, the line you have to be behind, the corridor
## you have to drop it down, and the people watching.
##
## It exists because of one line in the design: "the survey is a *map-reading* activity in first
## person, with no overlay map. The player must physically walk to the chapel and look back to judge
## the angle." A pump house that is only a square on a HUD panel is not something you can walk to,
## and the £180 you owe for flattening it is a number rather than a mistake.
##
## Everything here is generated from `data/levels/*.json` — `site.exclusions`, `site.corridor`,
## `site.safeLineDistance`, `site.crowd`. Nothing is placed by hand (rule 3).
class_name FellSite
extends Node3D

const CORRIDOR := Color(0.55, 0.78, 0.50, 0.14)
const CORRIDOR_EDGE := Color(0.62, 0.84, 0.56, 0.5)
const LINE := Color(0.92, 0.84, 0.40)
const STONE := Color(0.48, 0.46, 0.43)
const SLATE := Color(0.22, 0.23, 0.25)
const LIME := Color(0.78, 0.76, 0.70)

## How big a thing is, from what it would cost. A greenhouse is not a chapel, and the player should
## be able to tell which is which from across the field without reading a label.
const SIZE_BY_VALUE := [[0.0, 3.0], [50.0, 5.0], [200.0, 9.0], [1000.0, 16.0]]
const CATASTROPHIC_SIZE := 22.0

var _crowd: MultiMeshInstance3D
var _cheered := false


func build(authored: Dictionary) -> void:
	for e in authored.get("exclusions", []):
		_exclusion(e)
	_corridor(float(authored.get("corridor_from", 0.0)), float(authored.get("corridor_to", 360.0)),
		float(authored.get("safe_line", 100.0)))
	_safe_line(float(authored.get("safe_line", 100.0)))
	_crowd_at(authored.get("crowd", {}), float(authored.get("safe_line", 100.0)))


func _on_bearing(bearing_deg: float, metres: float, y: float = 0.0) -> Vector3:
	var b := deg_to_rad(bearing_deg)
	return Vector3(sin(b) * metres, y, cos(b) * metres)


func _size_for(value: float, catastrophic: bool) -> float:
	if catastrophic:
		return CATASTROPHIC_SIZE
	var out: float = SIZE_BY_VALUE[0][1]
	for step in SIZE_BY_VALUE:
		if value >= float(step[0]):
			out = float(step[1])
	return out


## A building, its name on a board facing the chimney, so you can read it from the gob.
func _exclusion(e: Dictionary) -> void:
	var bearing := float(e.get("bearing", 0.0))
	var distance := float(e.get("distance", 0.0))
	var raw = e.get("value", 0.0)
	var catastrophic := bool(e.get("catastrophic", false)) or str(raw) == "CATASTROPHIC"
	var value: float = 0.0 if catastrophic else float(raw)
	var side := _size_for(value, catastrophic)
	var tall: float = side * 0.55

	var holder := Node3D.new()
	holder.name = String(e.get("id", "exclusion"))
	holder.position = _on_bearing(bearing, distance)
	holder.rotation.y = deg_to_rad(bearing)   # gable end to the chimney
	add_child(holder)

	var walls := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(side, tall, side * 0.7)
	walls.mesh = box
	walls.position.y = tall * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STONE if catastrophic else LIME
	mat.roughness = 0.95
	walls.material_override = mat
	holder.add_child(walls)

	# A pitched roof, because a flat box at 30 m reads as a crate and not as somebody's building.
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(side * 1.06, tall * 0.42, side * 0.76)
	roof.mesh = prism
	roof.position.y = tall + prism.size.y * 0.5
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = SLATE
	rmat.roughness = 0.9
	roof.material_override = rmat
	holder.add_child(roof)

	var board := Label3D.new()
	board.text = String(e.get("id", "")).replace("_", " ")
	if catastrophic:
		board.text += "\n(do not)"
	board.font_size = 64
	board.pixel_size = 0.018
	board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	board.modulate = Color(0.95, 0.42, 0.36) if catastrophic else Color(0.92, 0.90, 0.86)
	board.outline_size = 8
	board.position.y = tall + 2.4
	# Readable when you have walked over to it, gone when you are back at the gob. A nameplate you
	# can read from a hundred and fifty metres is not a nameplate, it is an overlay map, and the
	# design is explicit that this survey has none: the site plan on the HUD is where the names
	# live at that range.
	board.visibility_range_end = 70.0
	board.visibility_range_end_margin = 12.0
	holder.add_child(board)


## The arc you are allowed to drop it down, painted on the grass. At Waterside it is 70 degrees of
## open field and barely matters; at Kershaw's Yard it is 28 degrees with a chapel on one side, and
## then it is the whole level.
func _corridor(from_deg: float, to_deg: float, reach: float) -> void:
	var span := fmod(to_deg - from_deg + 360.0, 360.0)
	if span <= 0.0 or span >= 359.0:
		return
	var steps := maxi(int(span / 3.0), 3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in steps:
		var a0 := from_deg + span * float(i) / float(steps)
		var a1 := from_deg + span * float(i + 1) / float(steps)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(_on_bearing(a0, reach))
		st.add_vertex(_on_bearing(a1, reach))
	st.generate_normals()
	var wedge := MeshInstance3D.new()
	wedge.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CORRIDOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wedge.mesh.surface_set_material(0, mat)
	wedge.position.y = 0.04
	add_child(wedge)

	for edge in [from_deg, to_deg]:
		_rope(Vector3.ZERO, _on_bearing(edge, reach), CORRIDOR_EDGE, 0.10)


## The line you have to be behind when it goes: 1.5 x height, which the level authors.
func _safe_line(distance: float) -> void:
	var posts := 48
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var post := CylinderMesh.new()
	post.top_radius = 0.06
	post.bottom_radius = 0.06
	post.height = 1.1
	post.radial_segments = 5
	mm.mesh = post
	mm.instance_count = posts
	for i in posts:
		var bearing := 360.0 * float(i) / float(posts)
		mm.set_instance_transform(i, Transform3D(Basis(), _on_bearing(bearing, distance, 0.55)))
		mm.set_instance_color(i, LINE)
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	node.material_override = mat
	add_child(node)


func _rope(from: Vector3, to: Vector3, colour: Color, thickness: float) -> void:
	var span := to - from
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(thickness, thickness, span.length())
	mesh.mesh = box
	mesh.position = from + span * 0.5 + Vector3(0.0, 0.5, 0.0)
	mesh.look_at_from_position(mesh.position, mesh.position + span, Vector3.UP)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	add_child(mesh)


## The crowd. They are in the level file — distance, size, whether they react — and they are the
## reason a felling feels public. They are also, at Great Aire, a hazard.
func _crowd_at(crowd: Dictionary, safe_line: float) -> void:
	var count := int(crowd.get("size", 0))
	if count <= 0:
		return
	var distance := float(crowd.get("distance", safe_line * 1.3))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var body := CapsuleMesh.new()
	body.radius = 0.22
	body.height = 1.7
	body.radial_segments = 6
	body.rings = 2
	mm.mesh = body
	mm.instance_count = count
	# Deterministic: the same level puts the same people in the same places, every time.
	var rng := RandomNumberGenerator.new()
	rng.seed = count * 7919 + int(distance)
	for i in count:
		var bearing := rng.randf_range(0.0, 360.0)
		var out := distance + rng.randf_range(-6.0, 6.0)
		mm.set_instance_transform(i, Transform3D(Basis(), _on_bearing(bearing, out, 0.85)))
		var coat := rng.randf()
		mm.set_instance_color(i, Color(0.18 + coat * 0.2, 0.17 + coat * 0.14, 0.16 + coat * 0.1))
	_crowd = MultiMeshInstance3D.new()
	_crowd.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	_crowd.material_override = mat
	add_child(_crowd)


## They react when it lands — "reactsToFall" in the level file. A small jump, all together, which
## at a hundred and forty metres is all you would see of a cheer anyway.
func cheer() -> void:
	_cheered = true


func _process(dt: float) -> void:
	if not _cheered or _crowd == null:
		return
	var mm := _crowd.multimesh
	var t := Time.get_ticks_msec() / 1000.0
	for i in mm.instance_count:
		var x := mm.get_instance_transform(i)
		var phase := float(i) * 0.37
		x.origin.y = 0.85 + absf(sin(t * 4.0 + phase)) * 0.22
		mm.set_instance_transform(i, x)
