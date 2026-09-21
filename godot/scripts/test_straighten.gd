# Straightening Pitchcombe Mill — the STRAIGHTEN archetype in the running game.
#
# test_straighten.cpp proves the arithmetic and the overshoot. This proves the job: that the level
# loads as a straightening, that dialling the cut changes what the game predicts, that cutting once
# is all you get, and that she settles and pays.
#
#   make godot-script SCRIPT=res://scripts/test_straighten.gd

extends SceneTree

var failures := 0


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _init() -> void:
	root.set_meta("job_level", "11-pitchcombe-mill")
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var jack = player.jack

	_check(player.plumb_job, "Pitchcombe Mill is a straightening")
	var st: Dictionary = jack.plumb_state()
	var out_at_start: float = float(st.get("lean_at_start", 0.0))
	_check(out_at_start > 0.7 and out_at_start < 1.2,
		"she is about three foot out of upright: %.2f m" % out_at_start)

	# --- the plan changes nothing -----------------------------------------------------------
	_put(player, chimney, 12.0)
	var p: Dictionary = player.plumb_here()
	_check(float(p.get("brings_back", 0.0)) > 0.0, "a cut here would bring her back %.2f m"
		% p.get("brings_back", 0.0))
	_check(absf(float(jack.plumb_state().get("lean_now", 0.0)) - out_at_start) < 0.001,
		"and reading that has not moved her")

	# --- dialling it changes what it would do -------------------------------------------------
	var before: float = float(player.plumb_here().get("brings_back", 0.0))
	player._plumb_dial()
	_check(float(player.plumb_here().get("brings_back", 0.0)) > before,
		"dialling the cut deeper brings her back further")

	# --- cut high and a little goes further, and she swings more ------------------------------
	var low: Dictionary = jack.plumb_plan(4.0, 20.0, chimney.radius_at(4.0))
	var high: Dictionary = jack.plumb_plan(30.0, 20.0, chimney.radius_at(30.0))
	_check(float(low.get("brings_back", 0.0)) > float(high.get("brings_back", 0.0)),
		"more shaft above a low cut: %.2f against %.2f"
			% [low.get("brings_back", 0.0), high.get("brings_back", 0.0)])
	_check(float(high.get("risk", 0.0)) > float(low.get("risk", 0.0)),
		"and a high one swings her more")

	# --- aim short of plumb, because she keeps going -------------------------------------------
	var lever: float = float(player.plumb_here().get("leverage", 0.0))
	var exact: float = out_at_start / maxf(lever, 0.000001)
	var wise: float = exact / (1.0 + jack.tuning_f("straightenOvershootShare", 0.14))
	player.plumb_take_out = wise
	_check(player._plumb_cut() == null, "the cut is made")   # void call; the state is the check
	_check(player.plumb_cut_done, "and it is made once")
	var after_cut: Dictionary = jack.plumb_state()
	_check(not bool(after_cut.get("collapsed", false)), "she has not come down")
	_check(bool(after_cut.get("settling", false)), "she is on the wedges")
	_check(float(after_cut.get("sway_cm", 0.0)) > 0.0,
		"and the slit is opening and closing %.1f cm" % after_cut.get("sway_cm", 0.0))

	# A second cut is refused.
	player._plumb_cut()
	_check(player.plumb_cut_done, "a second cut is not a thing you get")

	# --- reaching the top must NOT pay for a job that has not happened ------------------------
	player.career_path = "user://test-plumb-early.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(player.career_path))
	player._settle_the_job()
	_check(player.settlement.is_empty(),
		"climbing her does not pay: the job is not done until she has come back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(player.career_path))

	# --- and she comes back over a day -----------------------------------------------------
	player.career_path = "user://test-plumb-tin.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(player.career_path))
	# Long enough to cover her whole settle at the rate the game runs it — about half a minute of
	# real time, which is the point of it: the sway is a thing you stand and watch.
	for i in 3000:
		player._plumb_tick(1.0 / 60.0)
		if not bool(jack.plumb_state().get("settling", false)):
			break
	_check(not bool(jack.plumb_state().get("settling", false)), "she has come to rest")
	var done: Dictionary = jack.plumb_state()
	_check(String(done.get("verdict_name", "")) == "UPRIGHT",
		"and she is upright: %s, %.2f m out"
			% [done.get("verdict_name", ""), absf(float(done.get("lean_when_done", 0.0)))])
	_check(not player.settlement.is_empty(), "the job settled")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(player.career_path))

	print("STRAIGHTEN: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(1 if failures > 0 else 0)


func _put(player: Node, chimney: Node, height: float) -> void:
	var foot: Vector3 = chimney.global_position + chimney.face_point(height)
	var out: Vector3 = foot - chimney.global_position
	out.y = 0.0
	player.global_position = foot + out.normalized() * player.BODY_OFF_LADDER
	player.set_height_m(height)
	player.on_ladder = true
