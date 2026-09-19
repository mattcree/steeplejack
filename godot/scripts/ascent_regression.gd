# The Grey Box, climbed and compared — TEST-002.
#
# test_ascent.gd's bot climbs the level with the real verbs. At a fixed frame rate and the level's
# own seed that climb is deterministic, so its outcome — how long it took, every dog and its
# rating, every span, what grip and nerve were left at the top — is a fingerprint of the game's
# balance. This compares it with the one recorded in data/replays/, and on any difference prints
# the fields that moved, before and after.
#
# That is the point of it: a tuning change becomes a readable diff of two climbs. When the change
# is meant, re-record (`make record`) and put the diff in the commit — the diff is the justification.
#
#   make test-replay          # compare
#   make record               # re-record
#
# The "expert" here is the bot, not a recorded human run: ADR-0003's intent replay needs the
# verbs to live in the sim, and today their orchestration is in player.gd. See TEST-002's outcome.

extends "res://scripts/test_ascent.gd"

const RECORDING := "res://../data/replays/00-greybox-expert.replay"


func _finished(counts: Dictionary) -> void:
	var now := _outcome(counts)
	var path := ProjectSettings.globalize_path(RECORDING)
	if OS.get_cmdline_user_args().has("--record"):
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(now, "  ", false) + "\n")
		f.close()
		print("REPLAY: recorded %s" % RECORDING.get_file())
		return
	if not FileAccess.file_exists(path):
		failures += 1
		printerr("  FAIL  no recording at %s — run `make record`" % RECORDING)
		return
	var then: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var diffs: Array = []
	_diff("", then, now, diffs)
	if diffs.is_empty():
		print("REPLAY: ok — the climb matches the recording")
		return
	failures += 1
	printerr("  FAIL  the climb differs from the recording in %d field(s):" % diffs.size())
	for d in diffs:
		printerr("          %s" % d)
	printerr("        If that change is meant, `make record` and put this diff in the commit.")
	print("REPLAY: %d field(s) changed" % diffs.size())


## What the climb came to. Rounded where the game is continuous, so the recording is a statement
## about balance rather than about the last bit of a float.
func _outcome(counts: Dictionary) -> Dictionary:
	var anchors: Array = []
	for i in range(1, jack.anchor_count()):
		var a: Dictionary = jack.anchor_at(i)
		if a.get("fixture", false):
			continue
		anchors.append({"height": snappedf(float(a["height"]), 0.01), "rating": str(a["rate_name"]),
			"failed": bool(a.get("failed", false))})
	var spans: Array = []
	var below := 0.0
	for sec in jack.stack_sections():
		var h := float(sec["upper_height"])
		spans.append({"span": snappedf(h - below, 0.01), "lashing": int(sec["lashing"])})
		below = h
	return {
		"level": jack.level_name(),
		"reached_top": player.at_top,
		"game_seconds": snappedf(t, 0.1),
		"sections": counts["sections"],
		"hauls": counts["hauls"],
		"dogs": counts["dogs"],
		"grip_at_end": snappedf(jack.grip(), 0.1),
		"nerve_at_end": snappedf(jack.nerve(), 0.1),
		"anchors": anchors,
		"spans": spans,
	}


## Field by field, naming the path to each difference: `anchors[3].rating: Sound -> Fair`.
func _diff(at: String, a: Variant, b: Variant, out: Array) -> void:
	if a is Dictionary and b is Dictionary:
		var keys := {}
		for k in a:
			keys[k] = true
		for k in b:
			keys[k] = true
		for k in keys:
			var here: String = ("%s.%s" % [at, k]) if at != "" else str(k)
			if not a.has(k):
				out.append("%s: (absent) -> %s" % [here, b[k]])
			elif not b.has(k):
				out.append("%s: %s -> (absent)" % [here, a[k]])
			else:
				_diff(here, a[k], b[k], out)
	elif a is Array and b is Array:
		if a.size() != b.size():
			out.append("%s: %d entries -> %d" % [at, a.size(), b.size()])
		for i in mini(a.size(), b.size()):
			_diff("%s[%d]" % [at, i], a[i], b[i], out)
	elif (a is float or a is int) and (b is float or b is int):
		# JSON reads every number back as a float; 11 and 11.0 are the same count.
		if not is_equal_approx(float(a), float(b)):
			out.append("%s: %s -> %s" % [at, a, b])
	elif a != b:
		out.append("%s: %s -> %s" % [at, a, b])
