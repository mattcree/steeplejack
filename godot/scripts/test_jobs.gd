# The job board — the front of the game, headlessly.
#
#   make godot-script SCRIPT=res://scripts/test_jobs.gd
#
# The board is the only thing that knows both halves of the game exist, so it is the only thing
# that can be wrong about either of them. What matters is that every level file shows up without
# being registered anywhere, and that taking a job starts the right scene on the right chimney —
# a FELL job must not open the climb, which would be a silent and very confusing failure.

extends SceneTree

var failures := 0


func _init() -> void:
	var board: Node = load("res://scenes/jobs.tscn").instantiate()
	board.career_path = "user://test-career-board.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(board.career_path))
	root.add_child(board)
	await process_frame

	var ids := []
	for job in board.jobs:
		ids.append(String(job["id"]))
	_check(ids.size() >= 4, "the board found %d jobs without any of them registering" % ids.size())
	_check("06-waterside" in ids and "07-kershaws-yard" in ids, "including both fellings")
	_check("00-greybox" in ids, "and the grey box, which is a tool rather than a job")
	_check(String(board.jobs[board.jobs.size() - 1]["id"]) == "00-greybox",
		"so it sorts last, on its own order of 99")

	var earlier := -1
	var ordered := true
	for job in board.jobs:
		if int(job["order"]) < earlier:
			ordered = false
		earlier = int(job["order"])
	_check(ordered, "and the rest are in the order a career would meet them")

	for job in board.jobs:
		if String(job["id"]) == "07-kershaws-yard":
			_check(String(job["archetype"]) == "FELL", "Kershaw's is a felling")
			_check(int(job["fee"]) == 1250, "worth £%d" % int(job["fee"]))
			_check(not job["briefing"].get("lines", []).is_empty(),
				"and the letter that came with it is on the board")

	# --- each job goes to the half of the game it belongs to ---------------------------------
	for job in board.jobs:
		var want: String = "felling" if String(job["archetype"]) == "FELL" else "steeplejack"
		_check(String(board.scene_for(job)).contains(want),
			"%s is a %s job and opens %s" % [job["id"], job["archetype"], want])

	# --- the letters that have not arrived yet -------------------------------------------------
	# A reputation gate is a rule about what the player may do, so the answer comes from the sim.
	# But a gate you could not reach even by doing every job that exists is a gap in the level set
	# rather than something the player has failed to earn, and the board has to tell those apart:
	# twelve levels were designed, five have data, and every felling is gated above what five jobs
	# can pay. Enforcing that blindly would lock the player out of half the finished game.
	for i in board.jobs.size():
		if String(board.jobs[i]["id"]) == "07-kershaws-yard":
			board.selected = i
	_check(int(board.career.get("stars", 0)) == 1, "a new jack has one star")
	_check(board._reachable_stars() == 2,
		"and every job with data, done, would still only make him two")
	_check(board.unearnable(board.jobs[board.selected]),
		"so Kershaw's three-star gate is a gap, not a gate")
	_check(not board.locked(board.jobs[board.selected]),
		"and he is let through it, with the reason on the card")

	# A gate he could reach and has not is a real lock, and stays shut.
	var reachable := {"id": "x", "gate": 2, "archetype": "FELL", "fee": 100, "height": 40.0,
		"shift": 90, "name": "x", "order": 3, "briefing": {}}
	_check(board.locked(reachable), "a two-star gate he could earn is properly shut")
	_check(not board.unearnable(reachable), "and is not pretending to be a gap")

	# Earn it. The tin is text, so this is what a career three jobs in looks like.
	board.jack.career_load('{"money": 2350, "reputation": 42, "jobs": [' +
		'{"id": "01-back-yard", "paid": 0, "error": 0, "failed": false},' +
		'{"id": "06-waterside", "paid": 1250, "error": 3.0, "failed": false}]}')
	board.career = board.jack.career_state()
	_check(int(board.career.get("stars", 0)) == 3, "forty-two points is three stars")
	_check(not board.locked(board.jobs[board.selected]), "and now Kershaw's letter has arrived")
	_check(not board.unearnable(board.jobs[board.selected]), "properly, this time")
	_check(board.jack.career_done("06-waterside"), "with Waterside behind him")
	_check(not board.jack.career_done("07-kershaws-yard"), "and Kershaw's still to do")

	# --- taking a felling opens the felling ---------------------------------------------------
	board._take_it()
	await process_frame
	await process_frame
	var started: Node = root.get_child(root.get_child_count() - 1)
	_check(started.has_method("_plumb"),
		"taking a FELL job opened the felling and not the climb")
	_check(String(started.jack.level_name()).contains("Kershaw"),
		"on the chimney the card named: %s" % started.jack.level_name())
	_check(not is_instance_valid(board) or board.is_queued_for_deletion(),
		"and the board got out of the way")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test-career-board.json"))
	if failures > 0:
		printerr("JOBS: %d failure(s)" % failures)
	else:
		print("JOBS: a board of letters, and taking one starts the right half of the game.")
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
