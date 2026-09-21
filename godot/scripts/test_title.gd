# The front door — is there one, does it lead anywhere, and does New Career warn you.
#
# The last of these is the reason this file exists. "New career" over the top of a season someone
# has been playing is the only destructive button in the game, and a destructive button with no
# confirmation is the kind of thing nobody notices until it has happened to them.
extends SceneTree

var failures := 0


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _init() -> void:
	var packed: PackedScene = load("res://scenes/title.tscn")
	_check(packed != null, "the title scene loads")
	if packed == null:
		_done()
		return

	# --- with no career: no Continue, and New goes straight in ---------------------------------
	var fresh_path := "user://test-title-fresh.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fresh_path))
	var title: Node = packed.instantiate()
	title.career_path = fresh_path
	root.add_child(title)
	await process_frame

	_check(not title.has_career(), "a player who has never played has no career to continue")
	var keys: Array = []
	for row in title.rows:
		keys.append(String(row[0]))
	_check(not keys.has("continue"), "so Continue is not offered: %s" % str(keys))
	_check(keys.has("new") and keys.has("options") and keys.has("quit"),
		"and New, Options and Quit are")

	title.choose("new")
	_check(not title.confirming, "New with nothing to lose does not stop to ask")
	title.queue_free()
	await process_frame

	# --- with a career: Continue appears, and New asks first ------------------------------------
	var saved_path := "user://test-title-saved.json"
	var f := FileAccess.open(saved_path, FileAccess.WRITE)
	f.store_string('{"money": 640.0, "reputation": 12, "jobs": []}')
	f.close()

	var t2: Node = packed.instantiate()
	t2.career_path = saved_path
	root.add_child(t2)
	await process_frame

	_check(t2.has_career(), "a season in the tin is a career")
	var keys2: Array = []
	for row in t2.rows:
		keys2.append(String(row[0]))
	_check(keys2[0] == "continue", "Continue is offered, and it is the first thing: %s" % str(keys2))

	t2.choose("new")
	_check(t2.confirming, "New over a career stops and asks before it throws the season away")
	_check(FileAccess.file_exists(saved_path), "and has not deleted anything yet")

	# --- the geometry the mouse uses is the geometry that gets drawn ----------------------------
	var origin: Vector2 = t2._rows_origin()
	for i in t2.rows.size():
		var at := origin + Vector2(10.0, t2.ROW_GAP * float(i))
		_check(t2.row_at(at) == i, "a click on row %d finds row %d" % [i, t2.row_at(at)])
	_check(t2.row_at(Vector2(4.0, 4.0)) == -1, "and a click on the sky finds nothing")

	# --- options are reachable from the front door ----------------------------------------------
	t2.confirming = false
	t2.choose("options")
	_check(t2.options_open, "Options opens from the title")
	var orect: Rect2 = t2._options_rect()
	for i in GameSettings.ROWS.size():
		var oy: float = orect.position.y + t2.OPT_FIRST_Y + t2.OPT_ROW_H * float(i)
		var hit: Dictionary = t2.options_hit(Vector2(orect.position.x + 40.0, oy))
		_check(not hit.is_empty() and int(hit["row"]) == i,
			"and its row %d can be clicked" % i)
	# The value strip steps rather than just selecting, which is what the arrows promise.
	var vy: float = orect.position.y + t2.OPT_FIRST_Y
	var right: Dictionary = t2.options_hit(Vector2(orect.position.x + t2.OPT_W - 40.0, vy))
	var left: Dictionary = t2.options_hit(Vector2(orect.position.x + t2.OPT_W - 140.0, vy))
	_check(int(right.get("step", 0)) == 1, "clicking the right of a value steps it up")
	_check(int(left.get("step", 0)) == -1, "and the left steps it down")

	t2.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fresh_path))
	_done()


func _done() -> void:
	print("TITLE: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(1 if failures > 0 else 0)
