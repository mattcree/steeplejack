# Cutting past her — FELL-003, Act 3's own failure.
#
#   make godot-script SCRIPT=res://scripts/test_went_early.gd
#
# "COLLAPSE margin < 0.10 m — it goes. Now. Wherever it wants." The whole of Act 3 is not cutting
# past that line, and for a while crossing it only turned a word on a panel red. It is the primary
# failure of the act the design calls the heart of the felling, and the fairness contract says it
# has to have a telegraph and then it has to actually happen.

extends SceneTree

const SCRATCH := "user://test-early.json"

var failures := 0


func _init() -> void:
	var w: Node = load("res://scenes/felling.tscn").instantiate()
	w.career_path = SCRATCH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	root.add_child(w)
	await physics_frame
	await physics_frame
	var jack = w.jack
	var ring = w.ring
	w._stripped = true

	_check(String(jack.gob_state().get("status_name", "")) == "SAFE", "she starts standing easy")

	# Cut, and keep cutting, propping nothing. The bands have to come in order on the way down.
	var seen := {}
	var went_at := -1.0
	for i in 26:
		var step: int = (i + 1) / 2
		var seg: int = (int(round(w._peg / 360.0 * float(ring.segments)))
			+ (step if i % 2 == 1 else -step) + int(ring.segments) * 2) % int(ring.segments)
		for c in range(int(ring.courses)):
			jack.gob_cut(seg, c)
		var st: Dictionary = jack.gob_state()
		seen[String(st.get("status_name", ""))] = true
		w._telegraph(0.02)
		if w._fired and went_at < 0.0:
			went_at = float(st.get("margin", 0.0))
			break

	_check(seen.has("UNEASY"), "she passes through UNEASY on the way")
	_check(seen.has("CRITICAL"), "and CRITICAL, which is the warning you get")
	_check(w._fired, "and then she goes, without being lit")
	_check(w._went_early, "and the game knows it was not a felling, it was a collapse")
	_check(went_at < jack.tuning_f("gobCollapseMarginM", 0.1) + 0.01,
		"at a margin of %.2f m, which is the line the design draws" % went_at)

	await physics_frame
	_check(w._caught, "and you were in the hole, because that is where the work is")
	_check(w._settlement.has("injured"), "so it cost you that as well")
	_check(w._settlement.has("went_early"), "and the verdict says which kind of ending this was")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	if failures > 0:
		printerr("WENT EARLY: %d failure(s)" % failures)
	else:
		print("WENT EARLY: cut past her, and she came down on her own.")
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
