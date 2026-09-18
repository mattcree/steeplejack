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

	# At the foot, stepping off is just walking away.
	player.set_height_m(0.0)
	player.on_ladder = true
	player.global_position += Vector3(3.0, 0.0, 3.0)
	await physics_frame
	_check(not player.on_ladder, "walking away from the foot steps off")

	print("LADDER: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
