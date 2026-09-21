# The district remembers you — dogs left in a chimney, still in it next time.
#
# 17-the-long-game.md argues this is the most valuable unbuilt idea in the backlog, and the reason
# is that it turns striking into a decision with a deferred cost: leave your gear and you keep the
# daylight, and the chimney is carrying your own ironwork a season later when you come back to it.
#
#   make godot-script SCRIPT=res://scripts/test_district.gd

extends SceneTree

const TIN := "user://test-district.json"

var failures := 0


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TIN))
	var f := FileAccess.open(TIN, FileAccess.WRITE)
	f.store_string('{"money": 400.0, "reputation": 8, "jobs": []}')
	f.close()

	# --- first visit: drive some dogs, draw none, drive away ---------------------------------
	root.set_meta("job_level", "01-back-yard")
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player: Node = world.get_node("Player")
	player.career_path = TIN
	var jack = player.jack

	var before: int = int(jack.anchor_count())
	var drove := 0
	for h in [3.0, 5.0, 7.0, 9.0]:
		var dog: Dictionary = jack.seat_anchor(h, jack.seat_depth(), 0.0)
		if not dog.is_empty():
			drove += 1
	_check(drove == 4, "four dogs driven into the back yard stack")
	_check(int(jack.dogs_left_in()) >= drove,
		"and all of them are in the wall: %d" % jack.dogs_left_in())

	player._remember_what_you_left()
	var left: PackedFloat32Array = jack.career_left_in("01-back-yard")
	_check(left.size() >= drove,
		"the tin remembers %d of them at their own heights" % left.size())
	world.queue_free()
	await process_frame

	# --- second visit: they are still there ------------------------------------------------
	var again: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(again)
	await physics_frame
	var p2: Node = again.get_node("Player")
	p2.career_path = TIN
	# _ready already planted them from the tin the scene was built with; do it explicitly against
	# the test's own tin so the assertion is about the mechanism and not about load order.
	p2.jack.career_load(FileAccess.open(TIN, FileAccess.READ).get_as_text())
	var planted: int = int(p2.jack.plant_left_in("01-back-yard", 0.55))
	_check(planted > 0, "coming back, %d of your own dogs are already in her" % planted)

	var fixtures := 0
	for i in int(p2.jack.anchor_count()):
		var a: Dictionary = p2.jack.anchor_at(i)
		if not a.is_empty() and bool(a.get("fixture", false)) and float(a.get("rust", 0.0)) > 0.4:
			fixtures += 1
	_check(fixtures >= planted, "and they are rusted: %d weathered fixtures" % fixtures)

	# --- and a dog you went back for is a dog that is gone ---------------------------------
	p2.jack.career_remember_left_in("01-back-yard")
	var now: PackedFloat32Array = p2.jack.career_left_in("01-back-yard")
	_check(now.size() > 0, "what is in her now is what is in her now: %d" % now.size())

	again.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TIN))
	print("DISTRICT: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(1 if failures > 0 else 0)
