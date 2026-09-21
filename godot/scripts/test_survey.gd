# Surveying Hollin Bank — the SURVEY archetype in the running game.
#
# test_survey.cpp proves the four ways of finding a thing. This proves the job: that a survey level
# loads its defects at all, that climbing past one finds it, that a tap defect needs the tap, and
# that the report fills up.
#
#   make godot-script SCRIPT=res://scripts/test_survey.gd

extends SceneTree

var failures := 0


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _init() -> void:
	root.set_meta("job_level", "08-hollin-bank")
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var jack = player.jack

	_check(player.survey_job, "Hollin Bank is a survey job")
	var defects: Array = jack.survey_defects()
	_check(defects.size() == 4, "with four things wrong with her: %d" % defects.size())
	_check(int(jack.survey_report().get("found", -1)) == 0, "and none of them found yet")

	# --- a visual one is found by being there -----------------------------------------------
	var visual := {}
	var tap := {}
	var summit := {}
	var traverse := {}
	for d in defects:
		match String((d as Dictionary).get("discovery", "")):
			"visual": visual = d
			"tap": tap = d
			"summit": summit = d
			"traverse": traverse = d
	_check(not visual.is_empty() and not tap.is_empty() and not summit.is_empty()
		and not traverse.is_empty(), "one of each kind")

	_put(player, chimney, float(visual["height"]), 0.0)
	player._survey_look(false)
	_check(int(jack.survey_report().get("found", 0)) == 1,
		"climbing past the visual one finds it")

	# --- a tap one is not ---------------------------------------------------------------------
	_put(player, chimney, float(tap["height"]), 0.0)
	player._survey_look(false)
	_check(int(jack.survey_report().get("found", 0)) == 1,
		"standing next to the one you have to hear does not find it")
	player._survey_look(true)
	_check(int(jack.survey_report().get("found", 0)) == 2,
		"sounding it does")

	# --- the far side one wants you round her -------------------------------------------------
	_put(player, chimney, float(traverse["height"]), 0.0)
	player._survey_look(false)
	var before: int = int(jack.survey_report().get("found", 0))
	# Round to its bearing. Bearings are relative to the climbing line and _shuffle is metres
	# along the face, so the conversion is through the radius he is at.
	var rad: float = float(chimney.radius_at(float(traverse["height"])))
	player._shuffle = deg_to_rad(float(traverse["bearing"])) * rad
	player._survey_look(false)
	_check(int(jack.survey_report().get("found", 0)) > before,
		"working round her finds the one on the far side")

	# --- and the summit one is why you go to the top ------------------------------------------
	_put(player, chimney, float(summit["height"]), 0.0)
	player.at_top = false
	player._survey_look(false)
	var not_yet: int = int(jack.survey_report().get("found", 0))
	player.at_top = true
	player._survey_look(false)
	_check(int(jack.survey_report().get("found", 0)) > not_yet,
		"and standing on the cap finds the last of them")

	var r: Dictionary = jack.survey_report()
	_check(bool(r.get("complete", false)), "that is the lot: %d of %d" % [r["found"], r["total"]])
	_check(absf(float(r.get("share", 0.0)) - 1.0) < 0.001, "a whole survey")

	# --- and the report is what you are paid for ----------------------------------------------
	player.career_path = "user://test-survey-tin.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(player.career_path))
	player._settle_the_job()
	_check(not player.settlement.is_empty(), "a finished survey settles")
	_check(float(player.settlement.get("fee", 0.0)) > 0.0,
		"and pays the full fee for a full report: £%.0f" % player.settlement.get("fee", 0.0))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(player.career_path))

	print("SURVEY: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(1 if failures > 0 else 0)


func _put(player: Node, chimney: Node, height: float, shuffle: float) -> void:
	var foot: Vector3 = chimney.global_position + chimney.face_point(height)
	var out: Vector3 = foot - chimney.global_position
	out.y = 0.0
	player.global_position = foot + out.normalized() * player.BODY_OFF_LADDER
	player.set_height_m(height)
	player.on_ladder = true
	player._shuffle = shuffle
