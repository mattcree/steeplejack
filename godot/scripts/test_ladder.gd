# Regression test for the two faults that made the build unplayable: a height measured at the
# player's waist, and a ladder that grabbed you at any height and would not let go.
#
# Godot cannot render headlessly, so this drives the player node directly and asserts on state.
# It is not a substitute for playing it; it is a substitute for shipping the same bug twice.
#
#   make godot-script SCRIPT=res://scripts/test_ladder.gd

extends SceneTree

var failures := 0


func _init() -> void:
	var scene: PackedScene = load("res://scenes/steeplejack.tscn")
	var world: Node = scene.instantiate()
	root.add_child(world)
	await physics_frame

	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")

	# Height is measured at the feet. On the ground that is zero, not the capsule's half-height.
	_check(absf(player.height_m()) < 0.15, "feet height on the ground is ~0, got %.2f" % player.height_m())

	# Walk him to the foot of the ladder.
	var foot: Vector3 = chimney.global_position + chimney.face_point(0.0)
	var out: Vector3 = (foot - chimney.global_position)
	out.y = 0.0
	player.global_position = foot + out.normalized() * 0.40
	player.set_height_m(0.0)
	await physics_frame
	await physics_frame
	_check(player.on_ladder, "he takes hold of the ladder at its foot")

	# You climb only as high as you have lashed, so the climb clamps to ladder_top. The first
	# version of this test set him at 12 m with 5 m of ladder built and read the clamp as a bug.
	player.set_height_m(6.0)
	await physics_frame
	_check(absf(player.height_m() - player.ladder_top) < 0.1,
		"he cannot climb above what he has built (%.1f m)" % player.ladder_top)

	# Lash more ladder, then up he goes.
	player.ladder_top = 20.0
	chimney.set_ladder_top(20.0)
	player.set_height_m(12.0)
	await physics_frame
	_check(player.on_ladder, "he stays on it at 12 m")
	_check(absf(player.height_m() - 12.0) < 0.6, "12 m reads as 12 m, got %.2f" % player.height_m())

	# And he can get off. This is the one that made it unplayable: letting go re-attached on the
	# very next frame, because attaching only ever asked how close he was.
	player._let_go()
	await physics_frame
	_check(not player.on_ladder, "letting go at 12 m actually lets go")
	await physics_frame
	await physics_frame
	_check(not player.on_ladder, "and he does not get grabbed again while falling past it")

	# At the foot, stepping off is just walking away — and it has to STAY off. Standing next to a
	# ladder, on the floor, within reach is exactly the mounting condition, so without a delay it
	# grabbed you again on the very next frame and you could not leave.
	player.set_height_m(0.0)
	player.on_ladder = true
	player._shuffle = 0.0
	player.global_position += Vector3(3.0, 0.0, 3.0)
	await physics_frame
	_check(not player.on_ladder, "walking away from the foot steps off")

	player.global_position = foot + out.normalized() * 0.40
	player.set_height_m(0.0)
	for i in 4:
		await physics_frame
	_check(not player.on_ladder, "and standing back at the foot does not instantly re-grab you")

	# D moves him right as the player sees it, A left. Through the key's own path (side_input) and
	# judged on screen, because the bug was a sign in world space: D walked him left.
	player.on_ladder = true
	player._shuffle = 0.0
	player._remount_block = 0.0
	var ch: Node3D = chimney
	var rung3: Vector3 = ch.global_position + ch.face_point(3.0)
	var away: Vector3 = rung3 - ch.global_position
	away.y = 0.0
	player.global_position = rung3 + away.normalized() * player.BODY_OFF_LADDER
	player.set_height_m(3.0)
	player.face_the_wall()
	for i in 90:
		await physics_frame   # the camera eases round to the wall
	# The camera rides on him, so he never moves on screen; what matters is which way he moves
	# along the camera's own right-hand axis.
	var right: Vector3 = player.camera.global_transform.basis.x
	var p0: Vector3 = player.global_position
	player.side_input = 1.0
	for i in 12:
		await physics_frame
	player.side_input = 0.0
	var p1: Vector3 = player.global_position
	var went: float = (p1 - p0).dot(right)
	_check(player.on_ladder and went > 0.02, "D shuffles him to the right as the player sees it (%.2f m)" % went)
	player.side_input = -1.0
	for i in 24:
		await physics_frame
	player.side_input = 0.0
	var back: float = (player.global_position - p1).dot(right)
	_check(back < -0.02, "and A to the left (%.2f m)" % back)

	# Shuffling sideways works you off the stile. It has to accumulate; recomputing it from the key
	# each frame meant you never got further than one step.
	for i in 30:
		await physics_frame
	_check(player.on_ladder or true, "")   # settle
	player.on_ladder = true
	player._shuffle = 0.0
	player._remount_block = 0.0
	for i in 60:
		player._shuffle += 0.03
		await physics_frame
		if not player.on_ladder:
			break
	_check(not player.on_ladder, "shuffling sideways works him off the ladder")

	# The stack is solid. It was mesh only, so letting go dropped you through the brickwork.
	var solid: Node = chimney.get_node_or_null("Solid")
	_check(solid != null, "the chimney has a collision body")
	if solid != null:
		_check(solid.get_child_count() > 0, "with a shape for each band (%d)" % solid.get_child_count())

	print("LADDER: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if what == "":
		return
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
