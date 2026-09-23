# Act 2 — the strip-out, and the only place the two halves of the game meet.
#
#   make godot-script SCRIPT=res://scripts/test_strip_out.gd
#
# "Act 2 exists so that a felling level is not 'a puzzle with no climbing in it'. It's also where
# the player's relationship with the chimney becomes personal — you've been all over it before you
# kill it."
#
# So a felling is two visits: climb her and take the bands off, then come back with a bar and a
# match. This is the handoff between them, which crosses both halves of the game and the save in
# between, and there is nowhere else in the build where a bug could hide as well.

extends SceneTree

const SCRATCH := "user://test-strip.json"

var failures := 0


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))

	# --- day one: she will not be cut ---------------------------------------------------------
	var fell: Node = load("res://scenes/felling.tscn").instantiate()
	fell.level_path = "res://../data/levels/06-waterside.json"
	fell.career_path = SCRATCH
	root.add_child(fell)
	await physics_frame
	_check(not fell._stripped, "she still has her bands on")
	_check(fell._step == 0, "and the first thing the list asks for is the strip-out")
	fell._at = fell._on_bearing(fell._peg,
		float(fell.jack.structure().get("base_radius", 3.2)) + 3.0)
	fell._cut()
	_check(float(fell.jack.gob_state().get("cut_arc", 0.0)) == 0.0, "so nothing comes out of her")
	fell.queue_free()
	await physics_frame

	# --- the climb: the other half of the game, the same chimney --------------------------------
	root.set_meta("job_level", "06-waterside")
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var player: Node = world.get_node("Player")
	player.career_path = SCRATCH
	_check(String(player.jack.level_archetype()) == "FELL",
		"the climb knows this one is a felling")
	player._arrive_at_top()
	await physics_frame
	_check(player.stripped_out, "so getting to the top is Act 2, not the job")
	_check(player.settlement.is_empty(),
		"and it does not pay — the fee is the felling's, collected with a match")
	_check(player.jack.career_stripped("06-waterside"), "she is stripped")
	_check(not player.jack.career_done("06-waterside"), "and the job is still to do")
	world.queue_free()
	await physics_frame

	# --- day two: back with a bar ---------------------------------------------------------------
	var again: Node = load("res://scenes/felling.tscn").instantiate()
	again.level_path = "res://../data/levels/06-waterside.json"
	again.career_path = SCRATCH
	root.add_child(again)
	await physics_frame
	_check(again._stripped, "the tin remembers, across both halves and a save in between")
	_check(again._step == 1, "and the list has moved on to the survey")
	again._at = again._on_bearing(again._peg,
		float(again.jack.structure().get("base_radius", 3.2)) + 3.0)
	# Walking moves the camera too — the game does this every frame, and the bar goes in where
	# you are *looking*, not where your feet are. Without it the test aims from the spawn and
	# depends on the spawn being close enough to the brickwork to cut from, which it is not: you
	# now start far enough back to see the whole of her.
	again._place_camera()
	again._cut()
	_check(float(again.jack.gob_state().get("cut_arc", 0.0)) > 0.0, "and now she cuts")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	if failures > 0:
		printerr("STRIP OUT: %d failure(s)" % failures)
	else:
		print("STRIP OUT: climbed her, stripped her, came back and cut her.")
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
