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
	await _three_steps()

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


## Putting a dog in is three things, and you can see which one you are on.
##
## 16-how-it-was-actually-done.md gives the sequence and the game only ever drew the third of it:
## chisel the hole, drive a wooden plug into it, drive the dog into the plug. The hold on the
## right button was one unbroken "dog 42%" from first tap to seated, and the plug — which is where
## most of the hold comes from, and which the research is emphatic about — appeared out of nowhere
## the instant the dog went home.
func _three_steps() -> void:
	# The stages are in order and they cover the whole of the work.
	_check(Face.WORK_CHISEL_TO > 0.0 and Face.WORK_CHISEL_TO < Face.WORK_PLUG_TO
		and Face.WORK_PLUG_TO < 1.0,
		"the hole, the plug and the dog take the work in that order")

	_check(Face.work_phase(0.0) == 0, "a fresh joint is a chisel and a hole")
	_check(Face.work_phase(Face.WORK_CHISEL_TO - 0.01) == 0, "still cutting just before the hole is out")
	_check(Face.work_phase(Face.WORK_CHISEL_TO) == 1, "and the moment it is, the plug goes in")
	_check(Face.work_phase(Face.WORK_PLUG_TO - 0.01) == 1, "which takes until the plug is home")
	_check(Face.work_phase(Face.WORK_PLUG_TO) == 2, "and only then does the dog go into it")
	_check(Face.work_phase(1.0) == 2, "right up to seated")

	# And the world shows the one you are on — the hole from the first tap, the plug only once
	# there is a hole to put it in, the dog only once the plug is home.
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var face: Node = world.get_node("Face")
	# A joint that exists. Ids are the sim's and do not start at zero on every chimney.
	var chimney: Node = world.get_node("Chimney")
	var jid: int = world.get_node("Player").jack.nearest_joint(
		chimney.global_position + chimney.face_point(6.0) + Vector3(0, 0, 0.45), 1.5)
	_check(jid >= 0, "found a joint to work on: %d" % jid)

	face.set_work(jid, 0.05)
	_check(face._work_hole.visible, "chiselling: there is a hole")
	_check(not face._work_plug.visible and not face._work_dog.visible,
		"and no plug and no dog, because neither has been touched yet")

	face.set_work(jid, (Face.WORK_CHISEL_TO + Face.WORK_PLUG_TO) * 0.5)
	_check(face._work_plug.visible, "plugging: the plug is in the hole")
	_check(not face._work_dog.visible, "and the dog is still on his belt")

	face.set_work(jid, 0.9)
	_check(face._work_dog.visible and face._work_plug.visible,
		"dogging: the dog goes into the plug, which is still there")

	face.set_work(-1, 0.0)
	_check(not face._work_hole.visible and not face._work_plug.visible
		and not face._work_dog.visible, "and none of it is left on the screen afterwards")
	world.free()
