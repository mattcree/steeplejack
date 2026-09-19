# The stack's consequences, in the running game — CLIMB-001 and CLIMB-002.
#
# test_stack.cpp proves the load model. This proves the game *reacts*: that a section that buckles
# takes the ladder with it and him too if he was on it, that a pulled dog burns the fuse and leaves
# a scar, and that the warning comes first. Before the stack, every one of these was a line of text
# and nothing happened.
#
#   make godot-script SCRIPT=res://scripts/test_stack_game.gd

extends SceneTree

const FULL := 2

var failures := 0


func _init() -> void:
	await _buckling()
	await _a_poor_dog_pulls()
	print("STACK: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


## An over-long section warns, counts down, and goes — with him on it.
func _buckling() -> void:
	var world := await _world()
	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var jack = player.jack

	var dog: Dictionary = jack.seat_anchor(9.6, 1.0, 0.0)
	var h: float = dog["height"]
	_check(jack.stack_lash(h, FULL) >= 0, "a section lashed to a dog %.1f m up" % h)
	player.ladder_top = h + player._rise()
	chimney.set_ladder_top(player.ladder_top)
	_put_on_ladder(player, chimney, 5.0)
	await _wait(60)

	_check(player.stack_info.get("buckling", false),
		"a %.1f m span under him is buckling — and says so" % float(player.stack_info.get("span", 0.0)))
	_check(float(player.stack_info.get("buckle_left", 0.0)) > 5.0,
		"with most of its 8 seconds still to run: a warning, not a failure")

	# Step off, and it resets.
	player.on_ladder = false
	await _wait(5)
	player.on_ladder = true
	await _wait(2)
	_check(float(player.stack_info.get("buckle_left", 0.0)) > 7.5,
		"stepping off resets it (%.1f s)" % float(player.stack_info.get("buckle_left", 0.0)))

	# Stay on, and it goes, and he goes with it.
	var went := false
	for i in 11 * 60:
		await physics_frame
		if jack.slip_in_progress() or not player.on_ladder or player.fall_reason != "":
			went = true
			break
	_check(went, "stay on it and it buckles, with him on it")
	_check(player.ladder_top <= player.STANDING_TOP + 0.01,
		"and the ladder is down to what still stands (%.1f m)" % player.ladder_top)
	world.queue_free()
	await physics_frame


## The first dog on the stack carries most of him; on a swaying span that is more than a Poor dog
## is rated for.
func _a_poor_dog_pulls() -> void:
	var world := await _world()
	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var jack = player.jack

	# Seated at the minimum depth with a split face: a Poor dog. Searched for rather than asked for,
	# because the game deliberately cannot tell you a joint's truth.
	var poor := {}
	var hh := 6.4
	while hh < 7.8 and poor.is_empty():
		var d: Dictionary = jack.seat_anchor(hh, jack.seat_depth(), 0.45)
		if d.get("rate_name", "") == "poor":
			poor = d
		hh += 0.25
	_check(not poor.is_empty(), "a Poor dog, at %.1f m" % float(poor.get("height", 0.0)))
	if poor.is_empty():
		world.queue_free()
		return
	var h: float = poor["height"]
	jack.stack_lash(h, FULL)
	player.ladder_top = h + player._rise()
	chimney.set_ladder_top(player.ladder_top)
	var top_before: float = player.ladder_top
	_put_on_ladder(player, chimney, 4.0)
	await _wait(6)

	_check(not player.fuse.is_empty(), "loaded on a %.1f m swaying span, it pulls, and the fuse burns"
		% float(player.stack_info.get("span", h)))
	_check(player.ladder_top < top_before,
		"the section it held is down (%.1f -> %.1f m)" % [top_before, player.ladder_top])
	var scarred := false
	for id in player.face.pulled_ids:
		scarred = true
	_check(scarred, "and the wall keeps the scar where it tore out")
	world.queue_free()
	await physics_frame


func _world() -> Node:
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	return world


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
