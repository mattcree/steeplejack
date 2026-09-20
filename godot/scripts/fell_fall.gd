## The chimney going over — FELL-003.
##
## Not a physics sim. ADR-0002: deterministic, pre-fractured, hinge-driven. The sim has already
## decided where it goes and where it breaks; this only has to show it, and showing it badly is how
## a felling stops being the moment the whole level was for.
##
## The shaft is rebuilt as one tapered chunk per piece the sim broke it into. They all hinge
## together about the crescent until the break angle, and then each chunk above the break carries on
## a little faster than the one below — which is why the top overtakes and lands beyond the base of
## the fall, and why the debris fan is longer than the chimney is tall.
##
## The one number here that is presentation and not a rule is *when* in the fall each break happens.
## The sim says at what heights it parts; the angles are spread across the back half of the fall
## because that is when the bending stress is worst and because it reads well.
class_name FellFall
extends Node3D

const OVERTAKE_PER_CHUNK := 0.16   ## each piece up turns this much faster once it is free
const FIRST_BREAK_AT := 0.52       ## fraction of the way over before anything parts
const DUST := Color(0.62, 0.58, 0.52)

signal landed
signal broke(height_m: float)

var _chunks: Array[Node3D] = []
var _break_at: Array[float] = []     ## angle, radians, at which each chunk above is released
var _freed: Array[bool] = []
var _pivot := Vector3.ZERO
var _axis := Vector3.RIGHT
var _seconds := 7.5
var _t := 0.0
var _running := false


## `fractures` are heights, highest first, exactly as the sim returned them.
func begin(height_m: float, base_r: float, top_r: float, fall_bearing_deg: float,
		pivot: Vector3, fractures: Array, seconds: float) -> void:
	_seconds = maxf(seconds, 0.1)
	_pivot = pivot
	var b := deg_to_rad(fall_bearing_deg)
	# Tip towards the fall bearing: rotating about this axis carries UP that way.
	_axis = Vector3(cos(b), 0.0, -sin(b)).normalized()

	# Cut heights, bottom to top: [0, lowest break, ..., highest break, top].
	var cuts := [0.0]
	var sorted := fractures.duplicate()
	sorted.sort()
	for h in sorted:
		cuts.append(float(h))
	cuts.append(height_m)

	for i in range(cuts.size() - 1):
		var lo := float(cuts[i])
		var hi := float(cuts[i + 1])
		var chunk := _make_chunk(lo, hi, base_r, top_r, height_m)
		add_child(chunk)
		_chunks.append(chunk)
		_freed.append(false)
	# Chunk 0 never breaks off anything below it, so it has no angle of its own.
	var breaks := _chunks.size() - 1
	for i in range(_chunks.size()):
		if i == 0:
			_break_at.append(0.0)
		else:
			var f: float = FIRST_BREAK_AT + (1.0 - FIRST_BREAK_AT) * (float(breaks - i) / maxf(float(breaks), 1.0))
			_break_at.append(deg_to_rad(90.0) * f)
	_t = 0.0
	_running = true


func _make_chunk(lo: float, hi: float, base_r: float, top_r: float, height_m: float) -> Node3D:
	var holder := Node3D.new()
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = lerpf(base_r, top_r, lo / maxf(height_m, 1.0))
	cyl.top_radius = lerpf(base_r, top_r, hi / maxf(height_m, 1.0))
	cyl.height = hi - lo
	cyl.radial_segments = 20
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.29, 0.25)
	mat.roughness = 0.95
	mesh.material_override = mat
	mesh.position = Vector3(0.0, (lo + hi) * 0.5, 0.0)
	holder.add_child(mesh)
	holder.set_meta("lo", lo)
	return holder


## The angle it has turned through, 0 upright to PI/2 flat. Accelerates, because it does.
func angle() -> float:
	var f: float = clampf(_t / _seconds, 0.0, 1.0)
	return deg_to_rad(90.0) * f * f


func running() -> bool:
	return _running


func _process(dt: float) -> void:
	if not _running:
		return
	_t += dt
	var a := angle()
	for i in _chunks.size():
		var chunk := _chunks[i]
		var turn := a
		if i > 0 and a > _break_at[i]:
			if not _freed[i]:
				_freed[i] = true
				broke.emit(float(chunk.get_meta("lo", 0.0)))
			# Free, and turning faster than the stub it left behind.
			turn = _break_at[i] + (a - _break_at[i]) * (1.0 + OVERTAKE_PER_CHUNK * float(i))
		chunk.transform = _hinged(minf(turn, deg_to_rad(120.0)))
	if _t >= _seconds:
		_running = false
		landed.emit()


## Rotate about the hinge, not about the origin. Built explicitly rather than by chaining
## translated()/rotated(), which compose in an order that looks right and is not: the first version
## of this laid the chimney flat sideways and slid it across the field.
func _hinged(turn: float) -> Transform3D:
	var basis := Basis(_axis, turn)
	return Transform3D(basis, _pivot - basis * _pivot)
