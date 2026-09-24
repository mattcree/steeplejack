# Lashing, in the running game — VERB-005's flow and VERB-006's input methods.
#
# test_lash.cpp proves the rope. This proves the verb is one: that R no longer lashes a section
# instantly and perfectly — the "Press E to work" the anti-pillars name — and that nothing holds
# until the player has actually gone round enough times.
#
#   make godot-script SCRIPT=res://scripts/test_lash_game.gd

extends SceneTree

var failures := 0


func _init() -> void:
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame

	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var jack = player.jack

	# A dog above him, a ladder on his shoulder, on the stack.
	jack.seat_anchor(9.0, 1.0, 0.0)
	_put_on_ladder(player, chimney, 7.0)
	player.ladder_top = 8.0
	chimney.set_ladder_top(8.0)
	player.carrying_ladder = true
	jack.set_stance(3)   # belted, so grip lasts long enough to lash in
	await _wait(3)

	# --- R starts it; it does not finish it ------------------------------------------------------
	var top_before: float = player.ladder_top
	player._lash()
	await physics_frame
	_check(player.lashing, "R starts lashing")
	_check(absf(player.ladder_top - top_before) < 0.01, "and does not lash anything by itself")
	_check(player.carrying_ladder, "he is still holding the section")
	_check(player.lash_joint >= 0, "the rope goes to a real dog in a real joint")

	# --- tying off too early holds nothing -------------------------------------------------------
	player._tie_off()
	await physics_frame
	_check(not player.lashing, "tying off ends the lashing")
	_check(absf(player.ladder_top - top_before) < 0.01,
		"but under three turns the section is not lashed — nothing holds")
	_check(player.carrying_ladder, "and he still has it")

	# --- going round lays rope -------------------------------------------------------------------
	# Real mouse motion: a circle drawn at the ideal rate, the heading turning a few degrees a frame.
	player._lash()
	var ideal: float = 1.0 / jack.tuning_f("lashSecondsPerWrapIdeal", 1.4)
	var angle := 0.0
	for i in int(4.5 * 60.0):
		angle += TAU * ideal / 60.0
		player.lash_mouse(Vector2(cos(angle), sin(angle)) * 12.0)
		await physics_frame
	var st: Dictionary = jack.lash_state()
	_check(st["wraps"] >= 3, "drawing circles lays turns (%d in 4.5 s)" % st["wraps"])

	# --- a straight back-and-forth wiggle lays nothing -------------------------------------------
	# The exploit the first version had: wrapf maps both halves of a reversal to -PI, so every waggle
	# counted as a full turn in the same direction.
	for i in 30:
		await physics_frame   # let the last circle's rate die away
	var before: int = jack.lash_state()["wraps"]
	var laid_before: float = jack.lash_state()["laid"]
	player._lash_heading = INF
	for i in 180:
		player.lash_mouse(Vector2(14.0 if i % 8 < 4 else -14.0, 0.0))
		await physics_frame
	var after: Dictionary = jack.lash_state()
	_check(after["wraps"] == before and float(after["laid"]) <= laid_before + 0.05,
		"waggling back and forth is not going round, and lays no rope (%d -> %d, %.2f -> %.2f)"
			% [before, after["wraps"], laid_before, after["laid"]])

	# --- switching method mid-lash keeps the rope that is on -------------------------------------
	var kept: int = jack.lash_state()["wraps"]
	player.lash_method = 2   # hold
	await physics_frame
	_check(jack.lash_state()["wraps"] == kept,
		"changing input method mid-lash keeps every turn already on (VERB-006 acceptance 3)")
	player.lash_method = 0

	# --- and tying off lashes the section --------------------------------------------------------
	for i in int(3.0 * 60.0):
		angle += TAU * ideal / 60.0
		player.lash_mouse(Vector2(cos(angle), sin(angle)) * 12.0)
		await physics_frame
	player._tie_off()
	await physics_frame
	_check(not player.carrying_ladder, "tied off, the section is on the stack")
	_check(player.ladder_top > top_before + 1.0,
		"and the ladder goes higher (%.1f -> %.1f m)" % [top_before, player.ladder_top])
	_check(player.sections.size() == 1 and player.sections[0]["lashing"] >= 1,
		"and the stack remembers how it was lashed")

	# --- the rope goes round BOTH of them ---------------------------------------------------------
	#
	# A lashing binds two members crossing at right angles: the ladder's stile, which is vertical,
	# and the dog, which is an iron spike out of the wall. Every turn used to be laid round the
	# same vertical axis — a coil round the stile, binding it to nothing at all. The dog was not in
	# the knot, on any frame, in any job, and the verb the entire climb depends on was tying a
	# ladder to thin air.
	var face: Node = world.get_node_or_null("Face")
	_check(face != null, "there is a face to lash to")
	if face != null and player.lash_joint >= 0:
		var j: Dictionary = face.joint(player.lash_joint)
		_check(not j.is_empty(), "and the joint it went round is a real one")
		if not j.is_empty():
			var a0: Vector3 = face._wrap_frame(j, 0)["axis"]
			var a1: Vector3 = face._wrap_frame(j, 1)["axis"]
			var a2: Vector3 = face._wrap_frame(j, 2)["axis"]
			_check(absf(a0.dot(a1)) < 0.2,
				"turn 1 and turn 2 are square to each other (dot %.2f)" % a0.dot(a1))
			_check(absf(a0.dot(a2)) > 0.9,
				"and turn 3 is back round the stile, so it alternates")
			print("        the lashing sits at %.2f m, %.2f m off the face, turns %.3f m across"
				% [(j["pos"] as Vector3).y, 0.10, face.WRAP_R * 2.0])
			_check(a0.dot(Vector3.UP) > 0.9, "the stile turns lie flat, round a vertical rail")
			_check(absf(a1.dot(Vector3.UP)) < 0.2,
				"and the dog turns stand on edge, round a spike out of the wall")

	_done()


func _done() -> void:
	print("LASH: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
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
