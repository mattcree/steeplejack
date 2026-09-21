# The end of it — and the two things in it that have to be true.
#
# The sequence is the campaign's whole payoff, so the assertions are about honesty rather than
# about pixels: the town it drives through has to be the one the player actually made, and the
# tally has to count what the career actually was.
extends SceneTree

const TIN := "user://test-ending.json"

var failures := 0


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _init() -> void:
	var jobs := []
	for i in range(7):
		jobs.append({"id": "job-%d" % i, "paid": 400.0, "error": 1.0, "failed": false})
	var f := FileAccess.open(TIN, FileAccess.WRITE)
	f.store_string(JSON.stringify({"money": 900.0, "reputation": 70, "day": 61,
		"engineParts": 41, "jobs": jobs}))
	f.close()

	# --- it is only offered when she is finished ------------------------------------------------
	var yard: Node = load("res://scenes/yard.tscn").instantiate()
	yard.career_path = TIN
	root.add_child(yard)
	await process_frame
	var keys := []
	for r in yard.rows:
		keys.append(String(r[0]))
	_check(yard.engine_done(), "forty-one pieces is a finished engine")
	_check(keys.has("steam"), "so the yard offers to steam her: %s" % str(keys))

	yard.queue_free()
	await process_frame

	# A career with nothing bought does not get the offer. An option greyed out for a whole
	# campaign is a countdown, and this should arrive rather than approach.
	var poor := "user://test-ending-poor.json"
	var g := FileAccess.open(poor, FileAccess.WRITE)
	g.store_string('{"money": 20.0, "reputation": 4, "jobs": []}')
	g.close()
	var yard2: Node = load("res://scenes/yard.tscn").instantiate()
	yard2.career_path = poor
	root.add_child(yard2)
	await process_frame
	var keys2 := []
	for r in yard2.rows:
		keys2.append(String(r[0]))
	_check(not keys2.has("steam"), "and an unfinished one does not: %s" % str(keys2))
	yard2.queue_free()
	await process_frame

	# --- the town is the one the player made ------------------------------------------------
	var end: Node = load("res://scenes/ending.tscn").instantiate()
	end.career_path = TIN
	root.add_child(end)
	await process_frame

	_check(not end.chimneys.is_empty(), "there is a town: %d chimneys" % end.chimneys.size())
	var gone := 0
	for c in end.chimneys:
		if bool(c[2]):
			gone += 1
	_check(gone == 7, "and seven of them are not there any more, one per job: %d" % gone)

	# Spread rather than bunched: the absence only means anything next to something standing.
	var first_standing := -1
	var last_gone := -1
	for i in end.chimneys.size():
		if bool(end.chimneys[i][2]):
			last_gone = i
		elif first_standing < 0:
			first_standing = i
	_check(last_gone > first_standing,
		"the gaps are spread through the town, not bunched at the start")

	# --- the tally counts what happened -----------------------------------------------------
	_check(end.lines.size() >= 4, "there is a tally")
	_check(String(end.lines[0][0]) == "7", "seven jobs: %s" % end.lines[0][0])
	_check(String(end.lines[1][0]) == "61", "sixty-one days: %s" % end.lines[1][0])
	_check(String(end.lines[2][0]) == "£2800", "and what it paid: %s" % end.lines[2][0])
	_check(String(end.lines[lines_last(end)][1]).contains("because of you"),
		"and it ends where it should")

	# --- it goes at its own pace ---------------------------------------------------------------
	_check(end.progress() < 0.02, "it starts at the beginning")
	end._t = end.RUN_SECONDS * 0.5
	_check(absf(end.progress() - 0.5) < 0.02, "and runs to time")

	end.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TIN))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(poor))
	print("ENDING: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(1 if failures > 0 else 0)


func lines_last(end: Node) -> int:
	return end.lines.size() - 1
