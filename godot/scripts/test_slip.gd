# The slip, end to end through the real scene — METER-005.
#
# test_slip.cpp already proves the rule. This proves the *wiring*: that the window a player sees is
# the sim's window, that the key they press reaches it, that the outcome moves the player, and above
# all that a fall does not take the stack down with it. The stack is the checkpoint; losing it to a
# fall would wipe twenty-five minutes and is the one thing this feature must never do.
#
# Godot cannot render headlessly, so this drives the nodes directly. It is not a substitute for
# playing it — it cannot tell you whether 900 ms *feels* like a chance. It is a substitute for
# shipping the same bug twice.
#
#   make godot-script SCRIPT=res://scripts/test_slip.gd

extends SceneTree

var failures := 0


func _init() -> void:
	var scene: PackedScene = load("res://scenes/steeplejack.tscn")
	var world: Node = scene.instantiate()
	root.add_child(world)
	await physics_frame

	var player: Node = world.get_node("Player")
	var jack = player.jack

	# --- nothing slips on its own ---------------------------------------------------------------
	_check(not jack.slip_in_progress(), "a fresh climber is not slipping")
	_check(jack.grip() > 0.0, "and starts with grip in hand (%.0f)" % jack.grip())
	_check(jack.can_slip_save(), "the first slip of a shift is savable")

	# Grabbing at nothing must never pay out. If it did, holding the key would be free grip.
	var before: float = jack.grip()
	for i in 20:
		jack.grab()
		await physics_frame
	_check(jack.grip() <= before + 0.01, "grabbing at nothing does not refill grip")

	# --- the save -------------------------------------------------------------------------------
	_put_on_ladder(player, world, 14.0)
	await _drain(player)
	await physics_frame
	_check(jack.slip_in_progress(), "grip reaching zero opens the window")
	_check(player._slipping, "and the player knows it")

	var window: float = jack.slip_window_seconds()
	_check(window > 0.0, "the window is the difficulty table's (%.2f s)" % window)
	_check(jack.slip_window_left() > 0.9, "and it starts full")

	jack.grab()
	await physics_frame
	_check(not jack.slip_in_progress(), "the grab closes it")
	_check(jack.grip() > 0.0, "and leaves him something to hold on with (%.0f)" % jack.grip())
	_check(player.on_ladder, "still on the ladder after a save")

	# --- the budget -----------------------------------------------------------------------------
	_check(not jack.can_slip_save(), "the budget is spent for the next minute")

	# --- missing it, unclipped ------------------------------------------------------------------
	var top_before: float = player.ladder_top
	var anchors_before: int = jack.anchor_count()
	jack.set_stance(0)   # one hand on a rung: tied to nothing
	await _drain(player)

	# With the budget gone there is no window, so the slip opens and falls inside a single step and
	# `slip_in_progress` is never observably true. That is the point of the budget rather than an
	# oversight: the second slip inside a minute is not a chance you missed, it is no chance at all.
	# The first version of this test asserted the window was open and was wrong about the design.
	# Pressing the key the whole way through proves nobody's reactions can buy their way out.
	var fell := false
	for i in int(window * 120.0) + 20:
		jack.grab()
		await physics_frame
		if not player.on_ladder:
			fell = true
			break
	_check(fell, "the second slip inside a minute falls him with no window at all")
	_check(jack.slip_window_left() <= 0.0, "and there was never anything to grab at")
	_check(player.fall_reason != "", "and he is told why: %s" % player.fall_reason)
	_check(player.height_m() < 2.0, "back at the cradle, not in the air (%.1f m)" % player.height_m())

	# **The whole point.** The structure is the checkpoint and a fall may not touch it.
	_check(absf(player.ladder_top - top_before) < 0.01,
		"the stack is still up: %.0f m, was %.0f m" % [player.ladder_top, top_before])
	_check(jack.anchor_count() == anchors_before,
		"and every dog he drove is still in the wall (%d)" % jack.anchor_count())

	# A new day: grip back, and he can slip again rather than being stuck at zero for ever. This is
	# the loop the edge latch exists to stop — at zero grip, every step would re-slip him.
	_check(jack.grip() > 0.0, "he comes back with his grip (%.0f)" % jack.grip())
	_check(not jack.slip_in_progress(), "and not mid-slip on arrival")
	for i in 30:
		await physics_frame
	_check(not jack.slip_in_progress(), "and does not slip again on his own")

	# --- missing it, belted to a sound dog ------------------------------------------------------
	# The other half of acceptance 4, and the reason clipping on is worth the five seconds. The same
	# miss, the same fall, and a completely different outcome, decided by a rating the player was
	# shown on the pip when they drove the dog.
	await _wait(120)   # let the cooldown lapse so this is a fall, not a budget refusal
	var h := 20.0
	var seated := _seat_sound_dog(player, h)
	_check(seated, "a sound dog goes in at %.0f m" % h)

	if seated:
		_put_on_ladder(player, world, h + 1.0)
		await _drain(player, 3)   # belted to the stack when it runs out
		var caught_on_ladder := false
		for i in int(window * 120.0) + 20:
			await physics_frame
			if player.message.contains("the line held"):
				caught_on_ladder = true
				break
		_check(caught_on_ladder, "belted, the line holds: %s" % player.message)
		_check(player.on_ladder, "and he is still on the stack rather than at the cradle")
		_check(player.fall_reason == "", "which is not a fall, and is not reported as one")

	print("SLIP: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


## Drive a dog home somewhere near `height` and keep it if it rates Sound.
##
## The joint at a height is derived deterministically from the band, so which heights hold a sound
## joint is fixed — but it is fixed by the level file, and hard-coding one here would make this test
## fail the next time somebody edits the level rather than the next time somebody breaks the slip.
func _seat_sound_dog(player: Node, height: float) -> bool:
	for step in 40:
		var h: float = height + float(step) * 0.25
		var a: Dictionary = player.jack.seat_anchor(h, 1.0, 0.0)
		if a.get("rate_name", "") == "sound":
			return true
	return false


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


## Put him on the ladder at a height, with stack lashed up to it.
func _put_on_ladder(player: Node, world: Node, height: float) -> void:
	var chimney: Node = world.get_node("Chimney")
	player.ladder_top = maxf(player.ladder_top, height + 2.0)
	chimney.set_ladder_top(player.ladder_top)
	var foot: Vector3 = chimney.global_position + chimney.face_point(height)
	var out: Vector3 = foot - chimney.global_position
	out.y = 0.0
	player.global_position = foot + out.normalized() * 0.40
	player.set_height_m(height)
	player.on_ladder = true
	player._shuffle = 0.0
	player._remount_block = 0.0


## Work him down to nothing in `stance`. Grip only drains while a hand is off the ladder, which is
## the design — climbing is free and working is not — so this puts him in work mode and waits.
##
## The last stretch is done in the stance under test and the rest in one-hand, because belted drains
## at 1 point a second and a hundred seconds of physics frames is a minute of waiting for a test
## that is not about how long a belt lasts. The stance that matters is the one he is in when it
## runs out.
func _drain(player: Node, stance: int = 0) -> void:
	player.work_mode = true
	player.jack.set_stance(0)   # one hand on a rung: the fastest drain in the table
	for i in 20 * 60:
		if player.jack.grip() <= 2.0:
			break
		await physics_frame
	player.jack.set_stance(stance)
	for i in 20 * 60:
		if player.jack.grip() <= 0.0:
			return
		await physics_frame
	player.work_mode = false


func _check(ok: bool, what: String) -> void:
	if what == "":
		return
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
