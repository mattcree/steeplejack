## The gob, as brick you can see and point at — FELL-003.
##
## The bottom 1.4 m of the chimney, drawn as the 32 x 4 cells the sim thinks in. Nothing here
## decides anything: every cell's state comes from `Jack.gob_cell`, every prop's from
## `Jack.gob_prop_at`, and the colours are a picture of those. The one job it owns is turning a
## point in the world into a (segment, course), which is what lets the player aim at brick rather
## than at a menu.
##
## One MultiMesh for the cells and one for the props, per the performance budget — a node per cell
## would be 128 nodes rebuilt every time a brick comes out.
class_name GobRing
extends Node3D

const COURSE_H := 0.35          ## metres per course, so four courses is a 1.4 m gob
const CELL_INSET := 0.02        ## a hair of mortar between cells, so you can see them as cells
const PROP_RADIUS := 0.08       ## a timber prop, in metres
const RING_PROUD := 0.02        ## the ring sits a little proud of the shaft above it

# Intact brick, cut away, and propped. Cut cells are not drawn at all — the hole is the point.
#
# Darker than they look written down. These sit at the very foot of the chimney, where the shaft
# above them is at its sootiest, and the first pass rendered as a course of pale stone blocks
# against black brick — a seam exactly where the player spends twenty minutes looking.
const INTACT := Color(0.22, 0.17, 0.15)
const WEAK := Color(0.30, 0.25, 0.17)       ## mortar the level authored soft: paler, limier
const HARD := Color(0.17, 0.13, 0.12)       ## and the tough side is darker and denser
const PROPPED := Color(0.25, 0.20, 0.17)
const TIMBER := Color(0.70, 0.56, 0.32)
const TIMBER_LOADED := Color(0.78, 0.42, 0.20)
const TIMBER_SPLIT := Color(0.30, 0.16, 0.12)

var segments := 32
var courses := 4
var radius := 3.2

var _cells := MultiMeshInstance3D.new()
var _props := MultiMeshInstance3D.new()
var _jack: Jack


func build(jack: Jack) -> void:
	_jack = jack
	var st: Dictionary = jack.gob_state()
	segments = int(st.get("segments", 32))
	courses = int(st.get("courses", 4))
	radius = float(st.get("base_radius", 3.2))

	_setup(_cells, _cell_mesh(), segments * courses)
	_setup(_props, _prop_mesh(), segments)
	add_child(_cells)
	add_child(_props)
	refresh()


func _setup(node: MultiMeshInstance3D, mesh: Mesh, count: int) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	node.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	node.material_override = mat


func _cell_mesh() -> Mesh:
	var arc := TAU / float(segments)
	var box := BoxMesh.new()
	# Wide enough to close the ring at this radius, tall enough for one course.
	box.size = Vector3(radius * arc - CELL_INSET, COURSE_H - CELL_INSET, 0.5)
	return box


func _prop_mesh() -> Mesh:
	var cyl := CylinderMesh.new()
	cyl.top_radius = PROP_RADIUS
	cyl.bottom_radius = PROP_RADIUS
	cyl.height = COURSE_H * float(courses)
	cyl.radial_segments = 6
	return cyl


## Bearing of a segment's middle, clockwise from north, as the sim numbers them.
func segment_bearing(seg: int) -> float:
	return 360.0 * float(seg) / float(segments)


func _point_on(bearing_deg: float, r: float, y: float) -> Vector3:
	var b := deg_to_rad(bearing_deg)
	return Vector3(sin(b) * r, y, cos(b) * r)


## Where a cell sits in the world — the HUD's pointer and the camera's aim both want this.
func cell_point(seg: int, course: int) -> Vector3:
	var y := COURSE_H * (float(course) + 0.5)
	return global_position + _point_on(segment_bearing(seg), radius, y)


## Turn somewhere in the world into the cell nearest it. Returns [seg, course], and course is
## clamped, so looking at the ground under the gob means the bottom course rather than nothing.
func cell_at(point: Vector3) -> Array:
	var local := point - global_position
	var bearing := rad_to_deg(atan2(local.x, local.z))
	if bearing < 0.0:
		bearing += 360.0
	var seg := int(round(bearing / 360.0 * float(segments))) % segments
	var course := clampi(int(floor(local.y / COURSE_H)), 0, courses - 1)
	return [seg, course]


## Read the whole gob back from the sim and redraw it. Cheap enough to call on every change.
func refresh() -> void:
	if _jack == null:
		return
	var arc := TAU / float(segments)
	var i := 0
	for seg in segments:
		var bearing := segment_bearing(seg)
		var b := deg_to_rad(bearing)
		for course in courses:
			var cell: Dictionary = _jack.gob_cell(seg, course)
			var t := Transform3D()
			if bool(cell.get("removed", false)):
				t = t.scaled(Vector3.ZERO)   # the hole is the point
			else:
				var basis := Basis(Vector3.UP, b)
				t = Transform3D(basis, _point_on(bearing, radius + RING_PROUD, COURSE_H * (float(course) + 0.5)))
			_cells.multimesh.set_instance_transform(i, t)
			# Soft mortar reads paler and hard mortar darker, so the asymmetry a level authors is
			# visible before you put a bar in it — which is the tell rule 7 asks for.
			var strength := float(cell.get("strength", 1.0))
			var colour := INTACT.lerp(WEAK, clampf(1.0 - strength, 0.0, 1.0)) if strength <= 1.0 \
				else INTACT.lerp(HARD, clampf(strength - 1.0, 0.0, 1.0))
			if bool(cell.get("propped", false)):
				colour = colour.lerp(PROPPED, 0.5)
			_cells.multimesh.set_instance_color(i, colour)
			i += 1

	for seg in segments:
		var p: Dictionary = _jack.gob_prop_at(seg)
		var t := Transform3D()
		if not bool(p.get("present", false)):
			t = t.scaled(Vector3.ZERO)
			_props.multimesh.set_instance_transform(seg, t)
			continue
		var inset := radius - 0.45   # the prop stands inside the line of the wall, in the hole
		t = Transform3D(Basis(), _point_on(segment_bearing(seg), inset, COURSE_H * float(courses) * 0.5))
		if bool(p.get("split", false)):
			# A split prop is a folded one. Lean it over so a glance at the gob says so.
			t = t.rotated_local(Vector3.FORWARD, 0.5)
			_props.multimesh.set_instance_color(seg, TIMBER_SPLIT)
		else:
			# How hard it is working, as colour. Timber going orange is a prop near its capacity,
			# and the visual fallback for the groan (rule 8).
			var reserve := float(p.get("reserve", 1.0))
			_props.multimesh.set_instance_color(seg, TIMBER_SPLIT.lerp(TIMBER, reserve) if reserve < 0.2 else TIMBER_LOADED.lerp(TIMBER, reserve))
		_props.multimesh.set_instance_transform(seg, t)


## Hide the ring once the chimney is on its way down — the hinge takes over from here.
func drop() -> void:
	_cells.visible = false
	_props.visible = false
