# A conductor run down Chapel Street, in the game — the CONDUCTOR archetype end to end.
#
# test_conductor.cpp proves the Code's rules. This proves the job: that the level opens as a
# conductor job at all, that F at the apex sets the terminal and F on the way down clips, that the
# tape runs out where the level says it should, and that the earth pit at the bottom is what
# decides whether any of it counts.
#
#   make godot-script SCRIPT=res://scripts/test_conductor.gd

extends SceneTree

var failures := 0


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _init() -> void:
	root.set_meta("job_level", "02-chapel-street")
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var jack = player.jack

	_check(String(jack.level_name()).contains("Chapel"),
		"the level is Chapel Street: %s" % jack.level_name())
	_check(player.conductor_job, "and the game knows it is a conductor job")
	var top: float = float(jack.total_height())
	_check(absf(top - 28.0) < 0.1, "twenty-eight metres of it: %.0f" % top)

	# --- the terminal has to be at the apex --------------------------------------------------
	_put_on_ladder(player, chimney, 10.0)
	player._conductor_act()
	_check(not bool(jack.conductor_state(10.0).get("terminal", false)),
		"a terminal ten metres down is refused")

	_put_on_ladder(player, chimney, top)
	player._conductor_act()
	_check(bool(jack.conductor_state(top).get("terminal", false)),
		"and at the top it goes on")
	_check(int(jack.conductor_state(top).get("clips", 0)) == 1,
		"which is the first fixing of the run")

	# --- down, clipping as he goes -------------------------------------------------------------
	var h := top
	var clipped := 1
	while h > 0.5:
		h -= 1.0
		_put_on_ladder(player, chimney, h)
		player.tape_paid = 1.0          # a straight metre of tape for a straight metre of drop
		player.swing_power = 0.55       # square in the middle of the band
		var before: int = int(jack.conductor_state(h).get("clips", 0))
		player._conductor_act()
		if int(jack.conductor_state(h).get("clips", 0)) > before:
			clipped += 1
		else:
			break

	var st: Dictionary = jack.conductor_state(maxf(h, 0.0))
	_check(clipped > 20, "he gets a long way down before the reels go: %d clips" % clipped)
	_check(float(st.get("wander", 9.0)) < 1.2,
		"a straight run stays straight: %.2f" % st.get("wander", -1.0))
	_check(int(st.get("over_tight", -1)) == 0, "nothing pinched")

	# --- the earth is what decides it ------------------------------------------------------------
	_check(String(jack.conductor_state(0.0).get("verdict_name", "")) == "FAILED",
		"unearthed, the run does not pass — which is the honest answer, not a bug")
	player.global_position = chimney.global_position + Vector3(chimney.radius_at(0.0) + 0.6, 0.9, 0.0)
	player.set_height_m(0.0)
	player._conductor_earth()
	var done: Dictionary = jack.conductor_state(0.0)
	_check(float(done.get("earth_ohms", -1.0)) > 0.0,
		"the pit is dug and tested: %.1f ohms" % done.get("earth_ohms", -1.0))
	_check(float(done.get("earth_ohms", 99.0)) <= 10.0, "and it passes")

	# --- and the pit is where a conductor job actually ends ---------------------------------
	_check(not player.settlement.is_empty(),
		"a run that passes pays at the BOTTOM, not at the cap")
	_check(not bool(player.settlement.get("failed", true)), "and it counts as done")

	print("CONDUCTOR: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(1 if failures > 0 else 0)


func _put_on_ladder(player: Node, chimney: Node, height: float) -> void:
	var foot: Vector3 = chimney.global_position + chimney.face_point(height)
	var out: Vector3 = foot - chimney.global_position
	out.y = 0.0
	player.global_position = foot + out.normalized() * player.BODY_OFF_LADDER
	player.set_height_m(height)
	player.on_ladder = true
