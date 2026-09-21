# Coming down — the last act every job was missing.
#
# The sim's rules are proved in test_stack.cpp. This proves the *game* does it: that R with empty
# hands takes a ladder off instead of complaining you have not got one, that F on the ladder draws
# the dog instead of sending you to the cradle, that the sections come back to the cradle and the
# dogs come back to the bag, and — the one that matters — that a player cannot strip the stack out
# from under their own feet.
#
#   make godot-script SCRIPT=res://scripts/test_striking.gd

extends SceneTree

var failures := 0


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _init() -> void:
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var jack = player.jack

	# A stack up to 20 m: dogs every 4 m, every section lashed.
	# A dog seats at the nearest real joint, not at the height you ask for, so the lash has to be
	# told where it actually went. The Grey Box also starts with nine dogs a previous jack left in,
	# which is why the anchor count is not the same as the number we drive.
	var seated: Array = []
	for i in range(1, 6):
		var dog: Dictionary = jack.seat_anchor(4.0 * float(i), jack.seat_depth(), 0.0)
		if dog.is_empty():
			continue
		seated.append(float(dog["height"]))
		jack.stack_lash(float(dog["height"]), 2)
	player._retop()
	await physics_frame

	var sections_before: int = jack.stack_sections().size()
	_check(sections_before == 5, "a stack of %d sections" % sections_before)
	_check(seated.size() == 5, "on %d dogs we drove" % seated.size())
	var left_at_start: int = int(jack.dogs_left_in())

	# --- the safety rule, first ------------------------------------------------------------------
	var top_dog: float = seated[4]
	var mid: float = (seated[3] + top_dog) * 0.5
	_put_on_ladder(player, chimney, mid)
	await physics_frame
	_check(String(jack.why_not_strike(mid)) == "you are standing on it",
		"the ladder under his feet cannot be taken off: '%s'" % jack.why_not_strike(mid))
	# The dog his ladder STANDS on is the one that would drop him, and it is refused by name.
	# (The dog at the ladder's head is a different thing and is allowed — that is the one the trade
	# takes out before lowering the ladder under it.)
	var standing_on: int = -1
	for i in range(1, int(jack.anchor_count()) + 1):
		var a: Dictionary = jack.anchor_at(i - 1)
		if not a.is_empty() and absf(float(a["height"]) - seated[3]) < 0.05:
			standing_on = i
	_check(standing_on > 0, "found the dog his ladder stands on")
	_check(String(jack.why_not_draw(standing_on, mid)) == "there is a ladder standing on it",
		"and it cannot be drawn: '%s'" % jack.why_not_draw(standing_on, mid))

	# --- taking it down, from the foot of each ladder, working downwards --------------------------
	var ladders_before: int = player.ladders_at_base

	# --- take the whole stack down ---------------------------------------------------------------
	#
	# Driven by what the game itself says is available at each height rather than by heights worked
	# out here, because that is what a player does: stand somewhere, see what can come off, do it.
	# It is also the only robust way to test it — the Grey Box starts with nine dogs a previous jack
	# left in, and a dog seats at the nearest real joint rather than where you asked for it.
	var guard := 0
	while not bool(jack.all_struck()) and guard < 80:
		guard += 1
		var acted := false
		# Every height a dog sits at, highest first: stand beside each and take what it offers.
		var heights: Array = []
		for i in range(1, int(jack.anchor_count()) + 1):
			var a: Dictionary = jack.anchor_at(i - 1)
			if not a.is_empty():
				heights.append(float(a["height"]))
		heights.append(0.1)
		heights.sort()
		heights.reverse()
		for h in heights:
			# Placed and acted on in the same breath, with no physics frame between. A frame of
			# gravity moves him off the height the affordance was checked at, and then the verb
			# asks about somewhere he no longer is. Held on the ladder for the same reason: as
			# sections come off the top the stack gets shorter under him and the scene drops him,
			# which is correct behaviour and not what this test is about.
			_put_on_ladder(player, chimney, float(h))
			player.on_ladder = true
			if int(jack.dog_to_draw(float(h))) >= 0:
				player._pick_up()
				acted = true
			_put_on_ladder(player, chimney, float(h))
			player.on_ladder = true
			if int(jack.section_to_strike(float(h))) >= 0:
				player._lash()
				acted = true
			await physics_frame
		if not acted:
			break

	for i in range(jack.stack_sections().size()):
		if String(jack.why_not_strike(0.1)) != "":
			pass
	_check(bool(jack.all_struck()), "every ladder is off the chimney")
	_check(player.struck_sections == 5, "all five sections came down: %d" % player.struck_sections)
	_check(player.ladders_at_base == ladders_before + 5,
		"and all five are in the cradle: %d" % (player.ladders_at_base - ladders_before))
	var dealt: int = player.dogs_recovered + player.dogs_bent_out
	_check(dealt > 0, "dogs were drawn on the way down: %d back, %d snapped"
		% [player.dogs_recovered, player.dogs_bent_out])
	_check(int(jack.dogs_left_in()) == left_at_start - player.dogs_recovered,
		"what is left in the wall is what never came back: %d left, %d recovered, %d snapped"
			% [jack.dogs_left_in(), player.dogs_recovered, player.dogs_bent_out])

	# --- and a struck stack holds nothing up ------------------------------------------------------
	var survey: Dictionary = jack.stack_survey()
	_check(float(survey.get("longest_span", -1.0)) == 0.0,
		"the survey of a bare chimney has no span in it")

	print("STRIKING: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(1 if failures > 0 else 0)


func _put_on_ladder(player: Node, chimney: Node, height: float) -> void:
	var foot: Vector3 = chimney.global_position + chimney.face_point(height)
	var out: Vector3 = foot - chimney.global_position
	out.y = 0.0
	player.global_position = foot + out.normalized() * player.BODY_OFF_LADDER
	player.set_height_m(height)
	player.on_ladder = true
	player._shuffle = 0.0
	player._remount_block = 0.0
