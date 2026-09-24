# The yard — the hub, and the two things in it that touch the tin.
#
# The engine is the campaign's whole payoff and it is bought with money that has to survive a
# restart, so the assertions that matter are: buying refuses rather than borrows, a part actually
# leaves the tin, and both the calendar and the engine come back after a reload.
extends SceneTree

const SCRATCH := "user://test-yard.json"

var failures := 0


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	var packed: PackedScene = load("res://scenes/yard.tscn")
	_check(packed != null, "the yard scene loads")
	if packed == null:
		_done()
		return

	var yard: Node = packed.instantiate()
	yard.career_path = SCRATCH
	root.add_child(yard)
	await process_frame

	_check(not yard.stages.is_empty(), "the engine's stages come out of economy.json: %d"
		% yard.stages.size())
	# Not index 0: the first stage is "strip and assess", which has no parts and costs nothing,
	# so the first thing there is to BUY is the one after it.
	_check(int(yard.stages[yard.stage_index()].get("parts", 0)) > 0,
		"a new career is at the first stage with anything to buy: '%s'"
			% yard.stages[yard.stage_index()].get("name", ""))
	_check(yard.next_part_cost() > 0.0, "and the next piece has a price: £%.0f"
		% yard.next_part_cost())

	# --- skint ------------------------------------------------------------------------------------
	var parts_before: int = int(yard.career.get("engine_parts", 0))
	yard.choose("engine")
	_check(int(yard.career.get("engine_parts", 0)) == parts_before,
		"a man with nothing buys nothing")
	_check(float(yard.career.get("money", 0.0)) >= 0.0,
		"and is not put into debt for it: £%.0f" % yard.career.get("money", 0.0))

	# --- paid -------------------------------------------------------------------------------------
	# A season's worth of money, written into the tin the way a settled job would.
	var doc := {"money": 900.0, "reputation": 9, "jobs": []}
	var f := FileAccess.open(SCRATCH, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc))
	f.close()
	yard._load_career()
	_check(float(yard.career.get("money", 0.0)) > 0.0,
		"with £%.0f in the tin" % yard.career.get("money", 0.0))

	var money_before: float = float(yard.career.get("money", 0.0))
	var cost: float = yard.next_part_cost()
	yard.choose("engine")
	_check(int(yard.career.get("engine_parts", 0)) == 1, "a piece of her is bought")
	_check(absf(float(yard.career.get("money", 0.0)) - (money_before - cost)) < 0.01,
		"and it came out of the money: £%.0f -> £%.0f"
			% [money_before, yard.career.get("money", 0.0)])

	# --- the calendar -------------------------------------------------------------------------
	var day_before: int = int(yard.career.get("day", 0))
	yard.choose("kettle")
	_check(int(yard.career.get("day", 0)) == day_before + 1,
		"the kettle puts a day by: %d" % yard.career.get("day", 0))

	# --- and it survives coming back ---------------------------------------------------------
	yard.queue_free()
	await process_frame
	var again: Node = packed.instantiate()
	again.career_path = SCRATCH
	root.add_child(again)
	await process_frame
	_check(int(again.career.get("engine_parts", 0)) == 1, "the engine is still bought next time")
	_check(int(again.career.get("day", 0)) == day_before + 1, "and the day is still gone")

	# --- and the shelf, which is the half of the yard that is not bought ----------------------
	again.jack.career_keep("01-back-yard", "a chalked brick out of the perished course")
	again.jack.career_keep("01-back-yard", "something else entirely")
	var kept: Array = again.jack.career_salvage()
	_check(kept.size() == 1, "one thing per job, and going back does not get you a second: %d"
		% kept.size())
	_check(String((kept[0] as Dictionary).get("what", "")).contains("chalked brick"),
		"and it is the thing that job was about")

	# --- the click geometry is the drawn geometry ---------------------------------------------
	var origin: Vector2 = again._rows_origin()
	for i in again.rows.size():
		_check(again.row_at(origin + Vector2(10.0, again.ROW_GAP * float(i))) == i,
			"a click on row %d finds it" % i)
	_check(again.row_at(Vector2(4.0, 4.0)) == -1, "and a click on the wall finds nothing")

	# --- the skyline is the save file -----------------------------------------------------------
	#
	# 19-the-complete-game.md: the melancholy is that the world shrinks as you get better at your
	# job. That is only worth saying if it is TRUE, and it was not — every completed job took a
	# chimney off the skyline, so running a lightning conductor down one demolished it, and so did
	# reading one.
	_check(again.stack_state("x", "FELL", true) == "felled",
		"a felling takes her off the skyline")
	_check(again.stack_state("x", "TOP", true) == "shortened",
		"topping her out leaves a shorter chimney, not a gap")
	_check(again.stack_state("x", "CONDUCTOR", true) == "standing",
		"a conductor run leaves her standing — you made her safer")
	_check(again.stack_state("x", "BAND", true) == "standing", "and so does banding her")
	_check(again.stack_state("x", "SURVEY", true) == "standing", "and so does reading her")
	_check(again.stack_state("x", "FELL", false) == "standing",
		"a felling you have not done yet has not happened")

	var district: Array = again._district()
	_check(district.size() >= 10, "the town has %d chimneys in it" % district.size())
	var all_known := true
	for lvl in district:
		if not (again.stack_state(String(lvl["id"]), String(lvl["archetype"]), true)
				in ["standing", "felled", "shortened"]):
			all_known = false
	_check(all_known, "and every archetype in the level set resolves to a state it can draw")

	again.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	_done()


func _done() -> void:
	print("YARD: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(1 if failures > 0 else 0)
