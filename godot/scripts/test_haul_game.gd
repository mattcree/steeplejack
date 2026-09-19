# The gin wheel, in the running game — VERB-007.
#
# test_haul.cpp proves the pendulum. This proves the verb: that the wheel lashes to a real dog, that
# hauling flat out with no hand on the rope fouls and the load goes back down, that a hand steering
# against the swing brings it up, and that what comes up is a section and a bag of dogs in his hands.
#
#   make godot-script SCRIPT=res://scripts/test_haul_game.gd

extends SceneTree

var failures := 0


func _init() -> void:
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var jack = player.jack

	# A real stack: a dog every four metres, each lashed, up to 40. The first version lashed one
	# section from the ground to a dog at 24 m — a 24 m span — and it buckled under him mid-haul,
	# which was the stack doing its job and the test doing it wrong. And the wheel goes high: the
	# swing grows with the length of rope, so a short haul arrives before it can foul, and hauling is
	# a skill that matters the higher you are.
	var h := 4.0
	while h <= 40.0:
		var dog: Dictionary = jack.seat_anchor(h, 1.0, 0.0)
		jack.stack_lash(float(dog["height"]), 2)
		h += 4.0
	player.ladder_top = 42.0
	chimney.set_ladder_top(42.0)
	_put_on_ladder(player, chimney, 39.0)
	jack.set_stance(3)   # belted: hauling is two hands
	await _wait(4)

	player._gin_wheel()
	_check(player.gin_joint >= 0, "G lashes the gin wheel to the dog in reach (%.1f m)" % player.gin_height)

	# --- flat out, no hand on the rope: it fouls, and the load goes back ---------------------------
	var before_ladders: int = player.ladders_at_base
	player._gin_wheel()
	_check(player.hauling, "G by the wheel starts a haul")
	player.climb_input = 1.0
	var fouled := false
	for i in 30 * 60:
		await physics_frame
		if not player.hauling:
			fouled = not player.carrying_ladder
			break
	player.climb_input = 0.0
	_check(fouled, "hauling flat out with no hand on the rope fouls: %s" % player.message)
	_check(player.ladders_at_base == before_ladders, "and nothing arrived")

	# --- with a hand against the swing, it comes up ------------------------------------------------
	player._gin_wheel()
	player.climb_input = 1.0
	var arrived := false
	for i in 60 * 60:
		var v: float = float(player.haul.get("swing_vel", 0.0))
		player._haul_dx = -signf(v) * 60.0
		await physics_frame
		if not player.hauling:
			arrived = player.carrying_ladder
			break
	player.climb_input = 0.0
	_check(arrived, "steering against the swing brings it up: %s" % player.message)
	_check(player.ladders_at_base == before_ladders - 1, "a section out of the cradle")
	_check(player.dogs_carried > 0, "and a bag of dogs with it (%d)" % player.dogs_carried)

	# --- G mid-haul lets the rope run -------------------------------------------------------------------
	player.carrying_ladder = false
	player._gin_wheel()
	await _wait(10)
	var ev := InputEventKey.new()
	ev.keycode = KEY_G
	ev.pressed = true
	player._unhandled_input(ev)
	_check(not player.hauling, "G again lets the rope run")

	print("HAUL: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


func _put_on_ladder(player: Node, chimney: Node, height: float) -> void:
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
