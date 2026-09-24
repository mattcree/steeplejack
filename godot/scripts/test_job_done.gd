# Finishing a job — CAREER-001, the climbing half.
#
#   make godot-script SCRIPT=res://scripts/test_job_done.gd
#
# `test_ascent.gd` proves a bot can climb the Grey Box. This proves the thing that happens at the
# end of that: the job settles, it pays, it goes in the tin, and there is a way back to the board.
# Those are four separate things and every one of them was missing until the career landed — you
# could take The Back Yard and there was no such thing as finishing it.

extends SceneTree

const SCRATCH := "user://test-job-done.json"

var failures := 0


func _init() -> void:
	root.set_meta("job_level", "01-back-yard")
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var player: Node = world.get_node("Player")
	player.career_path = SCRATCH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	var jack = player.jack

	_check(String(jack.level_name()).contains("Back Yard"),
		"the board's choice reached the climb: %s" % jack.level_name())
	_check(player.settlement.is_empty(), "and nothing is settled while he is still on the ground")

	# The top is the job. Put him there the way arriving does.
	player._arrive_at_top()
	await physics_frame

	# He is STANDING on the cap, not falling off it.
	#
	# A chimney cap is a lid and there is no collision under the middle of it, so `is_on_floor()`
	# is false up there — and the clip chooser read that as "in the air" and played air_jump, which
	# is arms up and out for balance. He stood at the top of a hundred-foot chimney, at the
	# emotional peak of the entire game, doing a star jump. Found by rendering a frame of every
	# archetype and looking at them, which is the only way this class of thing is ever found.
	for i in 8:
		await physics_frame
	_check(player.at_top, "he is on the cap")
	_check(player._playing != "air_jump",
		"and he is not in mid-air up there (playing %s)" % player._playing)

	var paid: Dictionary = player.settlement
	_check(not paid.is_empty(), "reaching the top settles the job")
	_check(not bool(paid.get("failed", true)), "and it counts as done")
	_check(bool(paid.get("first_time", false)), "first time out")
	_check(int(paid.get("reputation_delta", 0)) > 0,
		"worth +%d to his name" % int(paid.get("reputation_delta", 0)))
	_check(float(paid.get("fee", -1.0)) == 0.0, "the back yard is a favour and pays nothing")
	_check(jack.career_done("01-back-yard"), "and the tin remembers it")

	# It is on disk, which is what the board will read.
	_check(FileAccess.file_exists(SCRATCH), "written out where the board will find it")
	var f := FileAccess.open(SCRATCH, FileAccess.READ)
	var doc = JSON.parse_string(f.get_as_text())
	f.close()
	_check(typeof(doc) == TYPE_DICTIONARY and int(doc.get("reputation", 0)) > 0,
		"as text, with a reputation in it")

	# Settling twice on one visit would pay twice for one climb.
	player._settle_the_job()
	_check(jack.career_state()["jobs"].size() == 1, "and arriving does not pay him twice")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	if failures > 0:
		printerr("JOB DONE: %d failure(s)" % failures)
	else:
		print("JOB DONE: a climb that ends, pays, and goes back to the board.")
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
