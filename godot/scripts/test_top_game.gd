# Topping her out, in the running game — the TOP archetype end to end.
#
#   make godot-script SCRIPT=res://scripts/test_top_game.gd
#
# `test_top.cpp` proves the stroke: where a brick gives, what the window is, and that holding on
# past the give point snaps it. This proves the verb is REACHABLE, which is the half that was
# missing — the sim had been finished and under test since TOP-001 and there were no Jack bindings
# for it at all and no level naming the archetype. Three hundred and seventy passing C++ tests and
# not one metre of chimney had ever come down.
#
# So the questions here are the ones a passing sim cannot answer:
#   * does the job start at all when the level says TOP?
#   * can a man on a ladder reach the course he is taking off?
#   * does sounding the joint actually buy him the wider window?
#   * and does the chimney GET SHORTER — because a course coming off that leaves her the height
#     she was is the same bug as a banding job with no bands on it.

extends SceneTree

var failures := 0


func _init() -> void:
	root.set_meta("job_level", "13-shawclough")
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame

	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var jack = player.jack

	_check(String(jack.level_archetype()) == "TOP",
		"the level is a topping job: %s" % jack.level_archetype())
	_check(player.top_job, "so the player started one")

	# She has to be laddered before you can top her out — you cannot work what you cannot reach,
	# which is the first line of every report in the game.
	player.ladder_top = 46.0
	chimney.set_ladder_top(46.0)

	var st: Dictionary = jack.top_state()
	_check(not st.is_empty(), "and the sim is live — top_state() has something in it")
	_check(absf(float(st.get("height_now_m", 0.0)) - 46.0) < 0.01,
		"she is %.1f m to start with" % float(st.get("height_now_m", 0.0)))
	_check(float(st.get("to_go_m", 0.0)) > 11.0,
		"with %.1f m to come off" % float(st.get("to_go_m", 0.0)))

	# --- you work the top of her from just under it ---------------------------------------------
	_put_on_ladder(player, chimney, 20.0)
	await physics_frame
	_check(not player.top_at_work(), "twenty-six metres below the top, he cannot reach the work")
	_check(String(world.get_node("HUD")._top_why()).contains("climb"),
		"and the refusal tells him where to go: %s" % world.get_node("HUD")._top_why())

	_put_on_ladder(player, chimney, 45.2)
	await physics_frame
	_check(player.top_at_work(), "just under the top of her, he can")

	# --- sounding is the verb, and it is worth something ----------------------------------------
	_check(not bool(jack.top_state().get("sounded", false)), "this brick has not been sounded")
	_check(float(jack.top_state().get("give", -1.0)) < 0.0,
		"so the game will not tell him where she gives")
	jack.top_sound()
	_check(bool(jack.top_state().get("sounded", false)), "E sounds it")
	_check(float(jack.top_state().get("give", -1.0)) >= 0.0,
		"and now he knows: she goes at %.2f" % float(jack.top_state().get("give", -1.0)))

	# --- the stroke -----------------------------------------------------------------------------
	player._top_press()
	_check(player.top_working, "holding the button leans him on the bar")
	_check(int(jack.top_state().get("stroke", 0)) == 1, "the bolster is seated")

	# Lean on it until she is just past the give, then let go. That is the whole verb.
	var give: float = float(jack.top_state().get("give", 0.5))
	for i in 400:
		jack.top_lever(0.01)
		if float(jack.top_state().get("load", 0.0)) >= give:
			break
	_check(float(jack.top_state().get("load", 0.0)) >= give,
		"the load builds while he holds: %.2f" % float(jack.top_state().get("load", 0.0)))

	var clean_before: int = int(jack.top_state().get("clean", 0))
	player._top_release_stroke()
	await physics_frame
	_check(not player.top_working, "letting go ends the stroke")
	_check(int(jack.top_state().get("clean", 0)) == clean_before + 1,
		"and released in the window she came away whole")

	# --- holding on past the give is a SNAP, not a miss ------------------------------------------
	# This is the design's best detail and the one thing a player must feel: past the give point you
	# have stopped loading the joint and started loading the brick.
	jack.top_sound()
	player._top_press()
	for i in 4000:
		jack.top_lever(0.01)
		if float(jack.top_state().get("load", 0.0)) >= 1.0:
			break
	var snapped_before: int = int(jack.top_state().get("snapped", 0))
	player._top_release_stroke()
	await physics_frame
	_check(int(jack.top_state().get("snapped", 0)) == snapped_before + 1,
		"holding on to a full load snaps her")

	# --- SHE HAS TO GET SHORTER -----------------------------------------------------------------
	# The whole point, and the half that no sim test can ever fail on.
	# Levered to a full load every time, so every one of these snaps. That is a man taking a
	# chimney down carelessly, and she still has to come down.
	var tall_before: float = chimney.height_m
	var guard := 0
	while float(jack.top_state().get("removed_m", 0.0)) < 1.0 and guard < 4000:
		guard += 1
		jack.top_seat()
		jack.top_lever(100.0)
		jack.top_release()
	player._top_shorten()
	await physics_frame
	_check(float(jack.top_state().get("removed_m", 0.0)) >= 1.0,
		"a metre of her is off: %.2f m" % float(jack.top_state().get("removed_m", 0.0)))
	_check(chimney.height_m < tall_before - 0.5,
		"and the CHIMNEY is shorter for it: %.2f m, was %.2f" % [chimney.height_m, tall_before])

	# --- and the job can be finished ------------------------------------------------------------
	guard = 0
	while not bool(jack.top_state().get("done", false)) and guard < 60000:
		guard += 1
		jack.top_seat()
		jack.top_lever(100.0)
		jack.top_release()
	_check(bool(jack.top_state().get("done", false)),
		"she comes down to the line in %d strokes" % guard)
	player._top_shorten()
	await physics_frame
	_check(absf(chimney.height_m - 34.0) < 1.0,
		"and stands at %.1f m, which is what the mill asked for" % chimney.height_m)
	# TopVerdict is { Craftsman, Workmanlike, Rough, Abandoned } — so LOWER is better and 3 is the
	# job not finished. A first pass asserted `> 0` here and passed while the chimney stood at its
	# full height, because 3 is the failure.
	_check(int(jack.top_judge(0.5)) < 3,
		"with a real grade on it, not an abandonment: %d" % int(jack.top_judge(0.5)))

	# The brickwork above the new top is GONE, not merely invisible. A chimney you have taken
	# twelve metres off that still stops you walking through the twelve metres is worse than one
	# that never shortened at all. Checked here, with her down to the line — a metre in, nothing is
	# yet wholly above the top, it is all mid-clip, and the first version of this check asserted
	# against that moment and failed for a reason that was about the test.
	var solid: Node = chimney.get_node_or_null("Solid")
	_check(solid != null, "she still has collision")
	if solid != null:
		var live := 0
		var dead := 0
		for col in solid.get_children():
			if not col.has_meta("shaft_from"):
				continue
			if float(col.get_meta("shaft_from")) >= chimney.height_m - 0.01:
				dead += 1 if col.disabled else 0
			else:
				live += 1 if not col.disabled else 0
		_check(dead > 0, "%d collision segments above the new top are switched off" % dead)
		_check(live > 0, "%d below it are still there to stand on" % live)

	# --- you hear where the bottom of the flue has got to -----------------------------------------
	#
	# The brick falls the length of what is left of her, above the pile it is landing on, so the
	# wait gets shorter as the flue fills. The meter says the same thing; this says it through the
	# floor while you are looking at your hands.
	_put_on_ladder(player, chimney,
		maxf(float(jack.top_state().get("height_now_m", 34.0)) - 0.7, 1.0))
	await physics_frame
	player._flue_listen()
	var empty_fall: float = player._flue_fall
	_check(empty_fall > 1.0, "a brick takes %.1f s to reach the bottom" % empty_fall)
	for i in 400:
		jack.top_drop(true)
	player._flue_listen()
	_check(player._flue_fall < empty_fall,
		"and less once the flue has filled up under it: %.1f s" % player._flue_fall)

	# --- a packed flue is a STOP, not a different route -------------------------------------------
	#
	# The drop used to be `top_drop(not jammed)`, so the moment the flue packed every brick went
	# over the side instead — silently, with nothing on screen about it. On Ladyshore, which is
	# taken down by hand precisely because there is an infants' school nine metres off her, that
	# is a brick into a playground. The flue is the only road off a chimney you are topping.
	while not bool(jack.top_state().get("jammed", false)):
		jack.top_seat()
		jack.top_lever(100.0)
		jack.top_release()
		jack.top_drop(true)
	_check(bool(jack.top_state().get("jammed", false)), "the flue packs eventually")
	# Stand him under what is left of her: by now she is down to the line and he is still up where
	# the top used to be, which is eleven metres above the work.
	_put_on_ladder(player, chimney,
		maxf(float(jack.top_state().get("height_now_m", 34.0)) - 0.7, 1.0))
	await physics_frame
	_check(player.top_at_work(), "he is back under the course he is working")
	player.top_working = false
	player.message = ""
	player._top_press()
	_check(not player.top_working, "and while it is packed he cannot start another one")
	_check(String(player.message).contains("nowhere to put them"),
		"and is told why: %s" % player.message)
	jack.top_clear_jam()
	player._top_press()
	_check(player.top_working, "cleared, he can work again")
	player.top_working = false

	# --- and it does not pay for the climb --------------------------------------------------------
	# Reaching the cap on a topping job is where the work STARTS. The general settlement path pays
	# the level fee for getting to the top, and topping fell straight into it — the whole £1,040
	# for climbing a chimney and touching nothing.
	player.career_path = "user://test-top-career.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(player.career_path))
	player.settlement = {}
	player._settle_the_job()
	_check(not player.settlement.is_empty(),
		"with her down to the line the job settles")
	var paid: float = float(player.settlement.get("paid", 0.0))
	_check(paid > 0.0, "and it pays: £%.0f" % paid)
	_check(paid < float(player._level_fee()),
		"but less than the full £%d, because most of her came down broken"
			% int(player._level_fee()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(player.career_path))

	if failures > 0:
		printerr("TOP GAME: %d failure(s)" % failures)
	print("TOP GAME: she comes down brick by brick, and she is shorter for it.")
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1


func _put_on_ladder(player: Node, chimney: Node, height: float) -> void:
	var foot: Vector3 = chimney.global_position + chimney.face_point(height)
	var out: Vector3 = foot - chimney.global_position
	out.y = 0.0
	player.global_position = foot + out.normalized() * player.BODY_OFF_LADDER
	player.set_height_m(height)
	player.on_ladder = true
	player._shuffle = 0.0
	player._remount_block = 0.0
