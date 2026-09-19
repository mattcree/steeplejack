# The working face — docs/01-gdd/15-working-the-face.md.
#
# Every verb acts on a thing you can see, and its result stays on that thing. These are the parts of
# that which break silently: the first version of the face built 132 joints and drew none of them,
# because a left-handed basis back-face culled every mark — and nothing reported anything, because
# nothing was wrong except that the wall was blank.
#
#   make godot-script SCRIPT=res://scripts/test_face.gd

extends SceneTree

var failures := 0


func _init() -> void:
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame

	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var face: Node = world.get_node_or_null("Face")
	var jack = player.jack
	_check(face != null, "the scene has a working face")
	if face == null:
		_done()
		return

	_check(jack.joint_count() > 1000, "the stack has a joint grid (%d joints)" % jack.joint_count())

	# --- on the ladder, looking at the wall ------------------------------------------------------
	_put_on_ladder(player, chimney, 12.0)
	player._yaw = deg_to_rad(-90.0)
	player._cam_yaw = player._yaw
	player._pitch = 0.0
	player._cam_pitch = 0.0
	await _wait(6)

	_check(face._joints.size() > 20, "the patch of wall in reach is drawn (%d joints)" % face._joints.size())
	var drawn := 0
	for k in 4:
		drawn += face._look[k].multimesh.instance_count
	_check(drawn > 20, "and its joints are in the mesh banks (%d)" % drawn)

	# The handedness bug, directly: a mark's quad must face *out* of the wall, or it is culled.
	if face._joints.size() > 0:
		var j: Dictionary = face._joints[0]
		var xf: Transform3D = face._on_face(j, Vector2.ZERO, 0.01)
		_check(xf.basis.determinant() > 0.0, "marks are built with a right-handed basis")
		_check(xf.basis.z.dot(j["normal"]) > 0.99, "and face out of the wall, not into it")

	_check(player.target_id >= 0, "looking at the wall from the ladder targets a joint")
	if player.target_id < 0:
		_done()
		return
	var target: int = player.target_id
	var tj: Dictionary = face.joint(target)
	_check(not face.under_ladder(tj), "and never one hidden behind the ladder")
	var hands: Vector3 = player.global_position + Vector3.UP * 0.55
	var reach: float = jack.tuning_f("tapTestMaxRangeMetres", 2.5)
	_check(((tj["pos"] as Vector3) + chimney.global_position).distance_to(hands) <= reach,
		"and always one his hand can reach")
	_check(face._bracket.visible, "the target is outlined on the wall")

	# --- tapping lands on the joint, at contact --------------------------------------------------
	player._tap()
	await physics_frame
	_check(jack.joint(target)["tapped"] < 0,
		"the tap does not land on the keypress — the arm has not got there yet")
	await _wait(int(ClimbClip.TAP_CONTACT * 60.0) + 3)
	_check(jack.joint(target)["tapped"] >= 0, "it lands at contact, on the joint that was targeted")
	_check(not player.last_tap.is_empty() and player.last_tap["id"] == target,
		"and the pip is for that joint")
	await _wait(2)
	var chalk := 0
	for bank in [face._chalk_tick, face._chalk_stroke, face._chalk_cross]:
		chalk += bank.multimesh.instance_count
	_check(chalk > 0, "and a chalk mark stays beside it")

	# Tapping costs grip, because a hand is off. That is what makes it a choice.
	var before: float = jack.grip()
	player._tap()
	await _wait(20)
	_check(jack.grip() < before, "a tap costs grip while he makes it (%.1f -> %.1f)" % [before, jack.grip()])
	await _wait(40)

	# --- driving a dog goes into the joint that was targeted -------------------------------------
	player.dogs_carried = 3
	var aimed: int = player.target_id
	player._toggle_work_mode()
	_check(player.work_mode, "right mouse on a targeted joint starts work")
	_check(player.work_joint == aimed, "on that joint and no other")
	var seated := false
	for i in 30:
		player.aim = Vector2.ZERO
		player.drawing = true
		player.swing_power = 1.0
		player._release_strike()
		await _wait(3)
		if not player.work_mode:
			seated = jack.joint(aimed)["occupied"]
			break
	_check(seated or player.bent_joints.has(aimed),
		"the blows went into the joint he chose, and it is taken now")
	_check(player.target_id != aimed or not jack.joint(aimed)["occupied"],
		"and it is not offered again for a second dog")

	# No "sound it first": driving an untapped joint is allowed, because skipping the tap is a
	# choice the design measures (MVP criterion 2).
	await _wait(4)
	if player.target_id >= 0 and jack.joint(player.target_id)["tapped"] < 0:
		player._toggle_work_mode()
		_check(player.work_mode, "an unsounded joint can be driven — the tap is a choice, not a gate")
		player._toggle_work_mode()

	_done()


func _done() -> void:
	print("FACE: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


func _put_on_ladder(player: Node, chimney: Node, height: float) -> void:
	player.ladder_top = maxf(player.ladder_top, height + 2.0)
	chimney.set_ladder_top(player.ladder_top)
	var foot: Vector3 = chimney.global_position + chimney.face_point(height)
	var out: Vector3 = foot - chimney.global_position
	out.y = 0.0
	player.global_position = foot + out.normalized() * player.BODY_OFF_LADDER
	player.set_height_m(height)
	player.on_ladder = true
	player._shuffle = 0.0
	player._remount_block = 0.0


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
