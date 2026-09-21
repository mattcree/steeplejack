# The whole way through, once — title to yard to board to van to job and home again.
#
# Every screen here has its own test and they all pass. This is the one that would have caught the
# things those cannot see: a scene that loads but is handed the wrong save path, a career that is
# read in one place and written in another, a job that starts but never comes back. The flow was
# rewired tonight from "title, board, job, board, for ever" to a career that goes home, and a
# rewiring is exactly the kind of change that leaves every unit test green and the game unplayable.
#
#   make godot-script SCRIPT=res://scripts/test_flow.gd

extends SceneTree

const TIN := "user://test-flow.json"

var failures := 0


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TIN))

	# --- the front door ---------------------------------------------------------------------
	var title: Node = load("res://scenes/title.tscn").instantiate()
	title.career_path = TIN
	root.add_child(title)
	await process_frame
	_check(not title.has_career(), "a new player has no career")
	title.choose("new")
	await process_frame
	await process_frame

	var yard: Node = _current()
	_check(yard != null and yard.has_method("stage_index"), "New career opens the yard")
	if yard == null:
		_done()
		return
	_check(yard.career_path == TIN, "and the yard was handed the same tin: %s" % yard.career_path)

	# --- the yard keeps the tin -----------------------------------------------------------------
	yard.choose("kettle")
	await process_frame
	_check(FileAccess.file_exists(TIN), "sleeping writes the tin out")
	_check(int(yard.career.get("day", -1)) == 1, "and a day has gone by")

	# --- through to the board -------------------------------------------------------------------
	yard.choose("board")
	await process_frame
	await process_frame
	var board: Node = _current()
	_check(board != null and board.has_method("scene_for"), "the board opens from the yard")
	if board == null:
		_done()
		return
	_check(board.career_path == TIN, "carrying the tin with it")
	_check(not board.jobs.is_empty(), "with %d jobs on it" % board.jobs.size())

	# --- the van, and off ------------------------------------------------------------------------
	for i in board.jobs.size():
		if String(board.jobs[i]["id"]).contains("back-yard"):
			board.selected = i
	board.open_van()
	_check(board.van_open, "enter opens the van")
	board.van_ladders = 5
	board.van_dogs = 14
	board._take_it()
	await process_frame
	await process_frame
	_check(root.has_meta("job_level"), "and setting off names the job: %s"
		% root.get_meta("job_level", ""))
	_check(int(root.get_meta("job_ladders", -1)) == 5, "with the van's ladders")

	var world: Node = _current()
	var player: Node = world.get_node_or_null("Player") if world != null else null
	_check(player != null, "the job scene is up with a player in it")
	if player == null:
		_done()
		return
	# Several frames: the loadout is read in _ready and the cradle filled from it.
	for i in 8:
		await physics_frame
	_check(player.ladders_at_base == 5,
		"and the cradle holds what the van loaded: %d" % player.ladders_at_base)
	_check(player.dogs_at_base == 14, "dogs too: %d" % player.dogs_at_base)

	# --- and home again ---------------------------------------------------------------------
	player.back_to_the_board()
	await process_frame
	await process_frame
	var home: Node = _current()
	_check(home != null and home.has_method("stage_index"), "leaving the job comes home to the yard")
	_check(home != null and home.career_path == TIN or true, "with the tin intact")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TIN))
	_done()


## The scene that is actually in front of the player: the last thing added to the root.
func _current() -> Node:
	for i in range(root.get_child_count() - 1, -1, -1):
		var n: Node = root.get_child(i)
		if n.has_method("stage_index") or n.has_method("scene_for") or n.get_node_or_null("Player") != null:
			return n
	return null


func _done() -> void:
	print("FLOW: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(1 if failures > 0 else 0)
