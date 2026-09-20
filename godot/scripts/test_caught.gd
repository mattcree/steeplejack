# Standing inside the line when it goes — FELL-003, Act 4.
#
#   make godot-script SCRIPT=res://scripts/test_caught.gd
#
# The safe line is 1.5 times the height and the burn is the only warning you get. Being inside it
# when the props go is not a scoring modifier: it is how jacks are killed, and the game has to
# treat it as its own thing rather than as a worse grade — it can happen on a felling that went
# perfectly in every other way.

extends SceneTree

const SCRATCH := "user://test-caught.json"

var failures := 0


func _init() -> void:
	var w: Node = load("res://scenes/felling.tscn").instantiate()
	w.career_path = SCRATCH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	root.add_child(w)
	await physics_frame
	await physics_frame

	var ring = w.ring
	var jack = w.jack
	# A gob worked properly, so the only thing wrong with this felling is where he is standing.
	var mid: int = int(round(w._peg / 360.0 * float(ring.segments))) % int(ring.segments)
	for i in 14:
		var step: int = (i + 1) / 2
		var seg: int = (mid + (step if i % 2 == 1 else -step) + int(ring.segments) * 2) % int(ring.segments)
		for c in range(int(ring.courses) - 1):
			jack.gob_cut(seg, c)
		jack.gob_prop(seg)
		jack.gob_cut(seg, int(ring.courses) - 1)
	w._sightings.assign([0.0, 120.0])

	w._packing = w.PACK_SECONDS
	w._packing_quality = 1.0
	w._act4 = w.MATCH
	w._strike_a_match()
	_check(w._act4 == w.BURNING, "lit, and burning")

	# He does not run. He stands at the foot of it and watches.
	w._at = w._on_bearing(w._peg, 20.0)
	var line: float = float(w._authored["safe_line"])
	_check(w._range() < line, "%0.0f m out, and the line is at %0.0f" % [w._range(), line])
	w._burn_left = 0.01
	w._act4_step(0.05)
	await physics_frame

	_check(w._caught, "the props went and he was inside the line")
	_check(w._settlement.has("injured"), "which is its own thing, not a worse grade")
	_check(int(w._settlement.get("injured", 0)) < 0,
		"and it cost him %d off his name" % -int(w._settlement.get("injured", 0)))
	_check(not bool(w._settlement.get("failed", true)),
		"the felling itself was fine — that is the point of it being separate")
	_check(float(w._settlement.get("paid", 0.0)) > 0.0, "and it still paid")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	if failures > 0:
		printerr("CAUGHT: %d failure(s)" % failures)
	else:
		print("CAUGHT: inside the line when she went, and it counts against you.")
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
