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

	# --- the mouse does not move the board --------------------------------------------------------
	#
	# Reported from play as "the mouse makes the job list scroll". The window used to be centred on
	# whatever was selected, and hovering selects — so moving the pointer down the list selected
	# the next card, which scrolled the board, which put a different card under the pointer. With
	# five jobs it was a twitch. With fifteen the list crawls away from you.
	board.selected = 0
	board.scroll_top = 0
	board.van_open = false
	var shown: int = board.rows_shown()
	if board.jobs.size() > shown:
		var last_slot := Vector2(board.CARD_X + 40.0,
			board.BOARD_TOP + board.CARD_STEP * float(shown - 1) + 20.0)
		var hover := InputEventMouseMotion.new()
		hover.position = last_slot
		board._input(hover)
		await process_frame
		_check(board.selected == shown - 1,
			"hovering the bottom card selects it (%d)" % board.selected)
		_check(board.visible_rows().x == 0,
			"and the board has not moved (top is %d)" % board.visible_rows().x)
		# Hover again at the same point: it must still be the same job.
		var was: int = board.selected
		board._input(hover)
		await process_frame
		_check(board.selected == was, "and hovering the same place twice is the same job")

		# The keyboard does move it, because that is how you get to the rest of them.
		board.selected = board.jobs.size() - 1
		board.reveal(board.selected)
		_check(board.visible_rows().x > 0,
			"arrowing to the last letter brings the board down to it (%d)"
				% board.visible_rows().x)
		# And the wheel, because a list of fifteen letters wants one.
		var top_before: int = board.visible_rows().x
		board.scroll_by(-2)
		_check(board.visible_rows().x == maxi(top_before - 2, 0),
			"the wheel moves it two (%d -> %d)" % [top_before, board.visible_rows().x])
		board.scroll_top = 0
		board.selected = 0

	# --- every job explains itself ---------------------------------------------------------------
	#
	# The designer played it and said none of it made any sense — bands, jigs, the lot. The letter
	# is the client asking for work in his own words, which says what he wants and nothing about
	# how it is done. The trade note is the other half. A level whose archetype has no note ships a
	# job the player has no way to understand, and that is the single most expensive kind of gap
	# this game can have.
	var seen := {}
	for job in board.jobs:
		seen[String(job["archetype"])] = true
	for arch in seen:
		_check(Trade.note(arch) != "",
			"a %s job explains what a %s job is" % [arch, arch])
		_check(Trade.what_it_is(arch) != "",
			"and says it again in one line where the instrument is")
		var note := Trade.note(arch)
		_check(note.length() > 120,
			"and does it in more than a label (%d characters)" % note.length())

	# --- no archetype follows itself ---------------------------------------------------------
	# Four of thirteen levels were fellings and two ran back to back. Variety is not more verbs, it
	# is better spacing of the verbs there are.
	var run_prev := ""
	var doubled := ""
	for job in board.jobs:
		var a := String(job["archetype"])
		if String(job["id"]).begins_with("00-"):
			continue   # the grey box is a tool, not a job, and sorts last on its own
		if a == run_prev:
			doubled = a
		run_prev = a
	_check(doubled == "", "no archetype follows itself down the board (%s)"
		% ("none" if doubled == "" else doubled))

	var earlier := -1
	var ordered := true
	for job in board.jobs:
		if int(job["order"]) < earlier:
			ordered = false
		earlier = int(job["order"])
	_check(ordered, "and the rest are in the order a career would meet them")

	# --- the mouse ------------------------------------------------------------------------------
	#
	# The board shipped with no hit-testing at all: every mouse event fell through to a keyboard
	# guard and was dropped, so clicking a card did nothing whatever and the whole screen looked
	# broken. Geometry the drawing and the clicking share, and a test that a click lands on the
	# card it is over.
	var rows: Vector2i = board.visible_rows()
	_check(rows.y > 0, "the board is showing %d of %d cards" % [rows.y, board.jobs.size()])

	var on_first := Vector2(board.CARD_X + 40.0, board.BOARD_TOP + 20.0)
	_check(board.card_at(on_first) == rows.x,
		"a point on the first card is the first card (%d)" % board.card_at(on_first))
	if rows.y > 1:
		var on_second := Vector2(board.CARD_X + 40.0, board.BOARD_TOP + board.CARD_STEP + 20.0)
		_check(board.card_at(on_second) == rows.x + 1, "and the next one is the next one")
		# In the gap between two cards, which is board and not a job.
		var between := Vector2(board.CARD_X + 40.0,
			board.BOARD_TOP + board.CARD_H + board.CARD_GAP * 0.5)
		_check(board.card_at(between) < 0, "and the gap between them is not a job")
	_check(board.card_at(Vector2(board.CARD_X + board.CARD_W + 80.0, board.BOARD_TOP + 20.0)) < 0,
		"nor is the letter beside them")

	# And a click selects the card it is over.
	if rows.y > 1:
		board.van_open = false
		board.selected = rows.x
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = Vector2(board.CARD_X + 40.0, board.BOARD_TOP + board.CARD_STEP + 20.0)
		board._input(click)
		await process_frame
		_check(board.selected == rows.x + 1,
			"clicking the second card selects it (%d)" % board.selected)
		_check(board.van_open, "and opens the van, which is what enter does")


	for job in board.jobs:
		if String(job["id"]) == "07-kershaws-yard":
			_check(String(job["archetype"]) == "FELL", "Kershaw's is a felling")
			_check(int(job["fee"]) == 1250, "worth £%d" % int(job["fee"]))
			_check(not job["briefing"].get("lines", []).is_empty(),
				"and the letter that came with it is on the board")

	# --- each job goes to the half of the game the work is actually in -------------------------
	# A felling with its bands still on is a climb. The board sends you where the day's work is
	# rather than making you guess which half of the game today is.
	for job in board.jobs:
		if String(job["archetype"]) != "FELL":
			_check(String(board.scene_for(job)).contains("steeplejack"),
				"%s is a %s job and opens the climb" % [job["id"], job["archetype"]])
			continue
		_check(String(board.scene_for(job)).contains("steeplejack"),
			"%s still wants stripping, so it opens the climb" % job["id"])
		board.jack.career_mark_stripped(String(job["id"]))
		_check(String(board.scene_for(job)).contains("felling"),
			"and once she is stripped it opens the felling")

	# --- the letters that have not arrived yet -------------------------------------------------
	# A reputation gate is a rule about what the player may do, so the answer comes from the sim.
	# But a gate you could not reach even by doing every job that EXISTS is a gap in the level set
	# rather than something the player has failed to earn, and the board has to tell those apart —
	# twelve levels were designed and not all of them have data yet.
	#
	# This used to assert that Kershaw's three-star gate was one of those gaps, which was true when
	# five levels shipped. Chapel Street and Brigg's Dyeworks make it earnable, so the same code
	# now correctly calls it a gate. The property being tested is the TELLING APART, not which side
	# any particular job happens to fall on this week.
	for i in board.jobs.size():
		if String(board.jobs[i]["id"]) == "07-kershaws-yard":
			board.selected = i
	_check(int(board.career.get("stars", 0)) == 1, "a new jack has one star")
	_check(board._reachable_stars() >= 3,
		"and the jobs that exist can now earn three: %d" % board._reachable_stars())
	_check(not board.unearnable(board.jobs[board.selected]),
		"so Kershaw's gate is a real gate now, not a gap in the level set")
	_check(board.locked(board.jobs[board.selected]),
		"and it is properly shut until he has earned it")

	# A gate he could reach and has not is a real lock, and stays shut.
	var reachable := {"id": "x", "gate": 2, "archetype": "FELL", "fee": 100, "height": 40.0,
		"shift": 90, "name": "x", "order": 3, "briefing": {}}
	_check(board.locked(reachable), "a two-star gate he could earn is properly shut")
	_check(not board.unearnable(reachable), "and is not pretending to be a gap")

	# Earn it. The tin is text, so this is what a career three jobs in looks like.
	# (career_load also clears the stripped marks set above, which is what we want here.)
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
	board.jack.career_mark_stripped("07-kershaws-yard")
	board._take_it()
	await process_frame
	await process_frame
	var started: Node = root.get_child(root.get_child_count() - 1)
	_check(started.has_method("_plumb"),
		"taking a stripped FELL job opened the felling and not the climb")
	_check(String(started.jack.level_name()).contains("Kershaw"),
		"on the chimney the card named: %s" % started.jack.level_name())
	_check(not is_instance_valid(board) or board.is_queued_for_deletion(),
		"and the board got out of the way")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test-career-board.json"))
	if failures > 0:
		printerr("JOBS: %d failure(s)" % failures)
	else:
		await _the_van()
	print("JOBS: a board of letters, and taking one starts the right half of the game.")
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1


## The van — the loadout decision, and the one number it exists to make legible.
func _the_van() -> void:
	var board: Node = load("res://scenes/jobs.tscn").instantiate()
	board.career_path = "user://test-career-van.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(board.career_path))
	root.add_child(board)
	await process_frame

	# Pick the Grey Box, which has a known 55 m and a known fourteen-ladder hint.
	for i in board.jobs.size():
		if String(board.jobs[i]["id"]).contains("greybox"):
			board.selected = i
	var job: Dictionary = board.jobs[board.selected]

	_check(not board.van_open, "the van is shut until you take a job")
	board.open_van()
	_check(board.van_open, "and enter opens it rather than setting off")

	# Sections are stock, not a dial. The van reports what you own; it does not ask.
	_check(board.van_ladders == board.jack.career_ladders(),
		"the van is loaded with what you own: %d sections" % board.van_ladders)

	# --- a chimney you have not got the ladders for is one you cannot take ----------------------
	#
	# This is the whole reason the shop exists, and the refusal has to say what to do about it:
	# a closed door with no handle is a bug with good manners.
	var want: int = int(job["ladders"])
	_check(want > board.jack.career_ladders(),
		"the Grey Box wants %d sections and you own %d" % [want, board.jack.career_ladders()])
	_check(board.short_by(job) == want - board.jack.career_ladders(),
		"so you are %d short" % board.short_by(job))
	board.van_said = ""
	board._take_it()
	await process_frame
	_check(not root.has_meta("job_level") or String(root.get_meta("job_level")) != String(job["id"]),
		"and she will not let you set off")
	_check(board.van_said.contains("short") or board.van_said.contains("sections"),
		"saying why, and where to fix it: %s" % board.van_said)

	# Buy the difference and she lets you go.
	board.jack.career_load('{"money": 9000, "reputation": 60}')
	_check(board.jack.career_buy_ladders(want), "bought %d sections" % want)
	_check(board.short_by(job) == 0, "and now nothing is short")

	# A felling whose bands are already off is ground work, so it needs no ladders at all.
	for j in board.jobs:
		if String(j["archetype"]) == "FELL":
			board.jack.career_mark_stripped(String(j["id"]))
			_check(board.short_by(j) == 0,
				"a stripped felling asks for no sections — it is a bar and a match")
			break

	# What turns up at the chimney is what you own. Read the number first: taking the job frees
	# the board, and asking a freed node what it owns is how this test learned that lesson.
	var owned_now: int = board.jack.career_ladders()
	board.selected = board.jobs.find(job)
	board.open_van()
	board._take_it()
	await process_frame
	_check(int(root.get_meta("job_ladders", -1)) == owned_now,
		"the job is told what you own: %d sections" % root.get_meta("job_ladders", -1))
	_check(int(root.get_meta("job_dogs", -1)) > 0, "and dogs, which cost nothing and never run out")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test-career-van.json"))
