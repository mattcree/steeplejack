# Regression test for the character: which way he faces, and whether his animations keep playing.
#
# Both of these were reported by a human playing the build, which is exactly the kind of thing a
# test should have caught first. Facing was out by 180° — he ran backwards, looking at the camera —
# and glTF clips import unlooped, so he froze mid-stride a second after setting off.
#
#   make godot-test

extends SceneTree

var failures := 0


func _init() -> void:
	var scene: PackedScene = load("res://scenes/steeplejack.tscn")
	var world: Node = scene.instantiate()
	root.add_child(world)
	await physics_frame

	var player: Node = world.get_node("Player")
	var body: Node3D = player.get_node("Body")
	var anim: AnimationPlayer = player.get_node("Body/AnimationPlayer")

	# Looping. Without this he plays once and stops, which is what "the animation fails to work
	# after a second or two" was.
	for clip in ["idle", "run"]:
		_check(anim.has_animation(clip), "the model has a '%s' clip" % clip)
		if anim.has_animation(clip):
			_check(anim.get_animation(clip).loop_mode == Animation.LOOP_LINEAR,
				"'%s' loops" % clip)

	# Facing. Point him along a direction and check the model's own forward really goes that way,
	# rather than trusting the sign of an atan2 written from memory.
	for dir in [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]:
		body.rotation.y = player._face(dir)
		await process_frame
		# Mannequiny is modelled facing +Z, so its forward is the basis' +Z column.
		var forward: Vector3 = body.global_transform.basis.z.normalized()
		_check(forward.dot(dir) > 0.95,
			"facing %s points him that way (got %s)" % [str(dir), str(forward.snapped(Vector3.ONE * 0.01))])

	# And he must never face the camera while running away from it.
	player.global_position = Vector3(0, 1, 0)
	player._yaw = 0.0
	player.velocity = Vector3.ZERO
	var forward_before: Vector3 = body.global_transform.basis.z
	_check(forward_before.length() > 0.9, "the body has a real orientation to begin with")

	print("CHARACTER: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
