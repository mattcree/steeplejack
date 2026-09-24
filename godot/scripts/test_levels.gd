# Every level, opened.
#
# Thirteen level files now, across four archetypes, and a level is the easiest thing in this
# project to get subtly wrong: the schema and the reachability gate catch the data, and nothing at
# all catches "the scene comes up but the player is inside the chimney" or "the mission block names
# a thing the code does not read". This opens every one of them and checks the handful of
# invariants that make a level playable at all.
#
#   make godot-script SCRIPT=res://scripts/test_levels.gd

extends SceneTree

var failures := 0


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _init() -> void:
	var dir := DirAccess.open(ProjectSettings.globalize_path("res://../data/levels"))
	var ids := []
	for name in dir.get_files():
		if name.ends_with(".json"):
			ids.append(name.get_basename())
	ids.sort()
	_check(ids.size() >= 10, "%d level files" % ids.size())

	for id in ids:
		await _open(String(id))

	print("LEVELS: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(1 if failures > 0 else 0)


func _open(id: String) -> void:
	root.set_meta("job_level", id)
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame

	var player: Node = world.get_node_or_null("Player")
	var chimney: Node = world.get_node_or_null("Chimney")
	if player == null or chimney == null:
		_check(false, "%s — no player or chimney" % id)
		world.queue_free()
		await process_frame
		return
	var jack = player.jack

	var ok := true
	var why := ""
	var h: float = float(jack.total_height())
	if h < 5.0:
		ok = false
		why = "height %.1f" % h
	elif int(jack.band_count()) < 1:
		ok = false
		why = "no bands"
	elif player.ladders_at_base < 1:
		ok = false
		why = "nothing in the cradle"
	elif player.dogs_at_base < 1:
		ok = false
		why = "no dogs"
	# He must start outside the chimney, not in it. A radius the level shrank without moving the
	# spawn is the classic way to end up standing inside the brickwork.
	var flat := Vector2(player.global_position.x - chimney.global_position.x,
		player.global_position.z - chimney.global_position.z)
	if ok and flat.length() < float(chimney.radius_at(0.0)) - 0.2:
		ok = false
		why = "spawned inside her (%.1f m from the axis, radius %.1f)" % [
			flat.length(), chimney.radius_at(0.0)]

	var arch := String(jack.level_archetype())

	# Everything a job needs must be reachable from somewhere the player can actually be. This is
	# the general form of two bugs found tonight — one bolt of eight in reach on a banding job,
	# and a job that could be finished but not left — and it is the cheapest possible guard
	# against the next one.
	if ok and arch == "SURVEY":
		var defects: Array = jack.survey_defects()
		for d in defects:
			var one := d as Dictionary
			var dh: float = float(one.get("height", 0.0))
			if dh > float(jack.total_height()) + 0.1:
				ok = false
				why = "a defect at %.1f m on a %.0f m chimney" % [dh, jack.total_height()]
				break
			# How far round he can lean at that height before he steps off the ladder.
			var r: float = maxf(float(chimney.radius_at(dh)), 0.1)
			var reach: float = rad_to_deg(player.SHUFFLE_OFF / r)
			if absf(float(one.get("bearing", 0))) > reach:
				ok = false
				why = "'%s' is %d deg round and he can only lean %.0f" % [
					one.get("id", ""), int(one.get("bearing", 0)), reach]
				break
	if ok and arch == "BAND":
		var bands: Array = player._mission().get("bands", []) as Array
		for b in bands:
			var bh: float = float((b as Dictionary).get("height", 0.0))
			if bh > float(jack.total_height()) - 0.5:
				ok = false
				why = "a band at %.1f m on a %.0f m chimney" % [bh, jack.total_height()]
				break

	# A topping job has to name how far down it goes, or there is no job — only a chimney.
	if ok and arch == "TOP":
		var down: float = float(player._mission().get("takeDownToM", -1.0))
		if down < 0.0:
			ok = false
			why = "a TOP job with no takeDownToM: nothing says when she is finished"
		elif down >= float(jack.total_height()) - 0.5:
			ok = false
			why = "takes her down to %.1f m from %.0f m, which is no work at all" % [
				down, jack.total_height()]

	# And the archetype has to be one the game can actually run.
	#
	# This list is the thing that should have caught TOP: the sim for it was finished, tuned and
	# under test, and there were no Jack bindings and no level naming it, so the guard never fired
	# because nothing ever asked it to. A built archetype only counts when a level points at it.
	if ok and not (arch in ["SURVEY", "FELL", "CONDUCTOR", "BAND", "STRAIGHTEN", "TOP"]):
		ok = false
		why = "archetype %s has no code behind it" % arch

	_check(ok, "%-22s %-10s %5.0f m  %s" % [id, arch, h, why])
	world.queue_free()
	await process_frame
