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

## NOT the standing chimney's brick shader, which was tried here and is wrong: it weathers by world
## height, so a chimney lying on its side reads as entirely soot and the fall goes black halfway
## down. Dressing the chunks properly wants a shader that weathers along the piece rather than
## along the world, which is a real job and not this one.

const OVERTAKE_PER_CHUNK := 0.16   ## each piece up turns this much faster once it is free
const FIRST_BREAK_AT := 0.52       ## fraction of the way over before anything parts

# "On ground contact, each chunk spawns a short-lived debris burst + dust column. Dust plume
# persists ~40 s and rolls outward. Do not cheap out on the dust." So: a burst where each piece
# lands, and a plume that keeps rolling long after the noise has stopped.
const DUST := Color(0.66, 0.62, 0.55)
const PLUME_SECONDS := 40.0
const BURST_PARTICLES := 220
const PLUME_PARTICLES := 420

signal landed
signal broke(height_m: float)

var _chunks: Array[Node3D] = []
var _break_at: Array[float] = []     ## angle, radians, at which each chunk above is released
var _freed: Array[bool] = []
var _hit: Array[bool] = []
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
		_hit.append(false)
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
	mat.albedo_color = Color(0.38, 0.30, 0.26)
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
		if i > 0 and a > _break_at[i] and not _freed[i]:
			_freed[i] = true
			broke.emit(float(chunk.get_meta("lo", 0.0)))
		chunk.transform = _hinged(minf(_turn_of(i, a), deg_to_rad(120.0)))
	# Each piece throws its dust where it actually hits, not all at the foot of the chimney: the top
	# of a chimney lands a long way out, which is the whole reason the fan is longer than it is tall.
	for i in _chunks.size():
		if _hit[i]:
			continue
		var turn: float = _turn_of(i, a)
		if turn >= deg_to_rad(88.0):
			_hit[i] = true
			_burst(_landing_point(i))
	if _t >= _seconds:
		_running = false
		_plume(_landing_point(_chunks.size() - 1))
		landed.emit()


## Where a chunk's middle ends up once it is flat on the ground.
func _landing_point(i: int) -> Vector3:
	if i < 0 or i >= _chunks.size():
		return _pivot
	var mid: Node3D = _chunks[i].get_child(0)
	return _chunks[i].transform * mid.position


func _turn_of(i: int, a: float) -> float:
	if i > 0 and a > _break_at[i]:
		return _break_at[i] + (a - _break_at[i]) * (1.0 + OVERTAKE_PER_CHUNK * float(i))
	return a


func _dust_material(up: float, out: float, life: float, size: float) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 2.4
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 85.0
	mat.initial_velocity_min = out * 0.4
	mat.initial_velocity_max = out
	mat.gravity = Vector3(0.0, up, 0.0)
	mat.damping_min = 0.6
	mat.damping_max = 1.8
	mat.scale_min = size * 0.5
	mat.scale_max = size
	mat.scale_over_velocity_min = 1.0
	mat.color = Color(DUST.r, DUST.g, DUST.b, 0.42)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(DUST.r, DUST.g, DUST.b, 0.5))
	ramp.set_color(1, Color(DUST.r, DUST.g, DUST.b, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	mat.color_ramp = tex
	return mat


func _dust_mesh(size: float) -> Mesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(DUST.r, DUST.g, DUST.b, 0.45)
	m.disable_receive_shadows = false
	quad.material = m
	return quad


## A short, hard burst where a piece hits the ground.
func _burst(at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.process_material = _dust_material(-1.6, 9.0, 2.6, 3.0)
	p.draw_pass_1 = _dust_mesh(3.0)
	p.amount = BURST_PARTICLES
	p.lifetime = 3.2
	p.one_shot = true
	p.explosiveness = 0.85
	p.position = at
	add_child(p)
	p.emitting = true


## And the plume, which rolls outward and is still there when the birds come back.
func _plume(at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.process_material = _dust_material(-0.25, 4.5, PLUME_SECONDS, 9.0)
	p.draw_pass_1 = _dust_mesh(9.0)
	p.amount = PLUME_PARTICLES
	p.lifetime = PLUME_SECONDS
	p.explosiveness = 0.12
	p.position = at
	add_child(p)
	p.emitting = true


## Rotate about the hinge, not about the origin. Built explicitly rather than by chaining
## translated()/rotated(), which compose in an order that looks right and is not: the first version
## of this laid the chimney flat sideways and slid it across the field.
func _hinged(turn: float) -> Transform3D:
	var basis := Basis(_axis, turn)
	return Transform3D(basis, _pivot - basis * _pivot)
