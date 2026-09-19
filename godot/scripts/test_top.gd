# The top, and getting your nerve back — MVP criterion 1 and METER-004, in the running game.
#
#   make godot-script SCRIPT=res://scripts/test_top.gd

extends SceneTree

var failures := 0


func _init() -> void:
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var jack = player.jack

	# --- a brew needs both hands; a cigarette does not -------------------------------------------
	_put_on_ladder(player, chimney, 30.0)
	player.ladder_top = 34.0
	chimney.set_ladder_top(34.0)
	jack.set_stance(0)
	await _wait(3)
	player._recover(player.REC_TEA)
	_check(player.recovering == player.REC_NONE, "no brew holding on with one hand")
	_check(player.message.contains("both hands"), "and it says why: \"%s\"" % player.message)
	jack.set_stance(3)
	player._recover(player.REC_TEA)
	_check(player.recovering == player.REC_TEA, "belted on, he brews up")
	var before: float = jack.nerve()
	await _wait(120)
	_check(jack.nerve() > before, "and gets his nerve back (%.1f -> %.1f)" % [before, jack.nerve()])
	player._climb_rate = 1.0
	player.set_height_m(31.0)
	await _wait(2)
	player._climb_rate = 0.0
	# Climbing breaks it off — through the real check, which reads the climb rate the frame sets.

	# --- frozen, you cannot go up ----------------------------------------------------------------
	player.recovering = player.REC_NONE
	jack.recover_interrupt()
	while jack.nerve() > 0.5:
		jack.shock("bellStrike")
	_check(jack.frozen(), "nerve gone: frozen")
	var h: float = player.height_m()
	player.climb_input = 1.0
	await _wait(30)
	_check(player.height_m() <= h + 0.01, "and cannot climb (%.2f -> %.2f)" % [h, player.height_m()])
	# The control: the same input with nerve back does climb. Without it the check above would pass
	# for a player who could not climb at all.
	jack.new_shift()
	await _wait(30)
	_check(player.height_m() > h + 0.3, "while with his nerve back the same input climbs (%.2f -> %.2f)"
		% [h, player.height_m()])
	player.climb_input = 0.0

	# --- the top, once --------------------------------------------------------------------------
	jack.new_shift()
	player.ladder_top = chimney.height_m
	chimney.set_ladder_top(chimney.height_m)
	_put_on_ladder(player, chimney, chimney.height_m - 0.7)
	player._arrive_at_top()
	await _wait(3)
	_check(player.at_top, "up the last rung and onto the cap")
	_check(player.top_reached and not player.top_summary.is_empty(), "the climb is summed up")
	_check(player.height_m() > chimney.height_m, "standing on it, not in it (%.1f m)" % player.height_m())
	var first: Dictionary = player.top_summary
	player.at_top = false
	player._arrive_at_top()
	_check(player.top_summary == first, "and the reveal happens once per ascent, not every time")
	await _wait(60)
	_check(absf(player.camera.fov - (player._base_fov + player.TOP_FOV_WIDEN)) < 4.0,
		"the camera widens up there (%.0f°)" % player.camera.fov)

	print("TOP: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


func _put_on_ladder(player: Node, chimney: Node, height: float) -> void:
	var foot: Vector3 = chimney.global_position + chimney.face_point(height)
	var out: Vector3 = foot - chimney.global_position
	out.y = 0.0
	player.global_position = foot + out.normalized() * player.BODY_OFF_LADDER
	player.set_height_m(height)
	player.on_ladder = true
	player.at_top = false
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
