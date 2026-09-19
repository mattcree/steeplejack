# Rigging a stance — the trade the climbing system is built on.
#
# 02-climbing-system.md §5 calls it the player's real choice: rush this one-handed, or spend the
# seconds to rig something better. Every stance used to be instant, so there was no choice in it —
# belting on cost nothing, which also made METER-005's whole clipped-or-not distinction free.
#
# The rule lives in the sim (`grip::SetupSeconds`, `grip::NeedsRigging`, tested in test_grip.cpp).
# This is about the part only the running game can be wrong about: that the timer actually runs,
# that it costs grip while it does, and above all that it can be interrupted — a half-rigged belt
# must never count as a rigged one.
#
#   make godot-script SCRIPT=res://scripts/test_stance.gd

extends SceneTree

const ONE_HAND := 0
const HOOKED_LEG := 1
const CLIPPED := 2

var failures := 0


func _init() -> void:
	var scene: PackedScene = load("res://scenes/steeplejack.tscn")
	var world: Node = scene.instantiate()
	root.add_child(world)
	await physics_frame

	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var jack = player.jack

	# --- on the ground there is nothing to rig to -----------------------------------------------
	player.on_ladder = false
	jack.set_stance(ONE_HAND)
	player._cycle_stance()
	await physics_frame
	_check(player.rigging_to < 0, "you cannot rig a stance standing in a field")
	_check(jack.get_stance() == ONE_HAND, "and it does not quietly change anyway")

	# --- on the stack it takes the time the table says -------------------------------------------
	_put_on_ladder(player, chimney, 18.0)
	await physics_frame
	var want: float = jack.stance_setup_seconds(HOOKED_LEG)
	_check(want > 0.0, "a hooked leg costs %.1f s to rig" % want)

	player._cycle_stance()
	await physics_frame
	_check(player.rigging_to == HOOKED_LEG, "Q starts rigging the next stance up")
	_check(jack.get_stance() == ONE_HAND, "and you are not in it yet")

	# Rigging is work: a hand is off, so it costs grip. Without this a climber with nothing left
	# could belt on to recover, and the meter would heal itself exactly when it is meant to bite.
	var grip_before: float = jack.grip()
	await _wait(10)
	_check(jack.grip() < grip_before, "and it drains grip while you do it (%.1f -> %.1f)"
		% [grip_before, jack.grip()])

	# --- and it finishes ----------------------------------------------------------------------
	await _wait(int(want * 60.0) + 20)
	_check(player.rigging_to < 0, "the rig completes")
	_check(jack.get_stance() == HOOKED_LEG, "and you are in the stance: %s" % jack.stance_name())

	# --- dropping back down is instant ------------------------------------------------------------
	jack.set_stance(4)   # the chair, the top of the table
	player._cycle_stance()   # wraps to one hand, which is a downgrade
	await physics_frame
	_check(player.rigging_to < 0, "coming out of a stance takes no rigging")
	_check(jack.get_stance() == ONE_HAND,
		"and happens at once — the way out of a stance you cannot afford must not take five seconds")

	# --- interruption is the one that matters -----------------------------------------------------
	# A belt half passed round a stack holds nothing. If a rig survived the player climbing away
	# from it, the cost would be a formality you could start and walk off.
	jack.set_stance(ONE_HAND)
	_put_on_ladder(player, chimney, 18.0)
	player._cycle_stance()
	await physics_frame
	_check(player.rigging_to >= 0, "rigging again")

	var mid: int = player.rigging_to
	player.set_height_m(player.height_m() + 0.4)   # he climbs away from it
	await physics_frame
	_check(player.rigging_to < 0, "climbing off the spot interrupts the rig")
	_check(jack.get_stance() != mid, "and a half-rigged stance is not a rigged one")

	# Leaving the ladder does too, which is the same rule reached a different way.
	player._cycle_stance()
	await physics_frame
	_check(player.rigging_to >= 0, "rigging once more")
	player.on_ladder = false
	await physics_frame
	_check(player.rigging_to < 0, "stepping off the ladder interrupts it as well")

	print("STANCE: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


func _put_on_ladder(player: Node, chimney: Node, height: float) -> void:
	player.ladder_top = maxf(player.ladder_top, height + 2.0)
	chimney.set_ladder_top(player.ladder_top)
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
