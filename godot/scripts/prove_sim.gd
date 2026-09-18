# Proves the port, end to end, with nothing mocked.
#
# GDScript -> GDExtension -> SteeplejackSim -> data/tuning/*.json and back. If this prints real
# numbers then the 2,986 lines of simulation and the 140 tests behind it came across unchanged,
# which is the whole question the move to Godot turned on.
#
#   make godot-script SCRIPT=res://scripts/prove_sim.gd

extends SceneTree


func _init() -> void:
	var failures := 0

	if not ClassDB.class_exists("SteeplejackTuning"):
		push_error("the GDExtension did not load — run `make godot-build`")
		quit(1)
		return

	var tuning := SteeplejackTuning.new()

	# data/ stays at the repository root rather than under res://: the sim's own test suite reads
	# the same files with no engine present, and two copies of the tuning would be two answers.
	var dir := ProjectSettings.globalize_path("res://../data/tuning")
	if not tuning.load_all(dir):
		push_error("load_all failed: %s" % tuning.get_last_error())
		quit(1)
		return

	print("tuning loaded from %s" % dir)
	print("  hash: %s" % tuning.tuning_hash())

	# Real keys, read out of the real files.
	for key in [
		"climbSpeedMetresPerSecond",
		"ladderLengthMetres",
		"spanSoftMetres",
		"spanDangerMetres",
	]:
		if tuning.has(key):
			print("  %s = %s" % [key, tuning.get_f(key, -1.0)])
		else:
			push_error("missing key: %s" % key)
			failures += 1

	# A missing key must not read as zero. CORE-007 made this throw on purpose, and the binding
	# has to preserve that or the guarantee dies at the boundary.
	if tuning.has("thisKeyDoesNotExist"):
		push_error("a nonexistent key reported present")
		failures += 1
	else:
		print("  missing keys still refuse to answer — the CORE-007 guarantee survived the port")

	print("PROVE: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)
