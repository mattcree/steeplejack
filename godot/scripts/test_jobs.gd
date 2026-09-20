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

	# --- taking a felling opens the felling ---------------------------------------------------
	for i in board.jobs.size():
		if String(board.jobs[i]["id"]) == "07-kershaws-yard":
			board.selected = i
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
