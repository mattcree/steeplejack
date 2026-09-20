# The felling's eight sounds, measured — because nobody on this side of the build can hear them.
#
#   make godot-script SCRIPT=res://scripts/test_fell_audio.gd
#
# The design says "sound design is 70% of this moment" and then describes the moment precisely:
# "ten seconds of near silence, then a crack, then a long rushing roar, then a ground thump you
# feel in the subwoofer, then bricks raining, then dust, then birds, then — after four or five
# seconds — a distant cheer."
#
# That is a set of claims about length and brightness, which are measurable. This asserts them in
# the direction the design gives, the way `test_audio.gd` does for the four taps. It is a weaker
# claim than "it sounds right", which no test can make, and a much stronger one than "a stream
# exists", which is what a test of synthesised audio usually settles for.
#
# The failure it exists to catch: an envelope edit that makes the groan and the crash converge, or
# leaves the mortar tick as long as the roar. Nothing else here would notice, and the consequence
# is that the chimney stops telling you what it is doing.

extends SceneTree

var failures := 0


func _init() -> void:
	var world: Node = load("res://scenes/felling.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var foley = world.get_node_or_null("Foley")
	_check(foley != null, "the felling has a Foley")
	if foley == null:
		quit(1)
		return

	var cues := ["mortarTick", "groan", "propCreak", "propSplit", "crack", "roar", "crash", "cheer"]
	var length := {}
	var bright := {}
	for name in cues:
		var stream: AudioStreamWAV = foley.cue_stream(name)
		_check(stream != null, "%s was synthesised" % name)
		if stream == null:
			continue
		var pcm := _pcm(stream)
		_check(_peak(pcm) > 0.02, "%s has something in it (peak %.2f)" % [name, _peak(pcm)])
		length[name] = _decay_seconds(pcm, stream.mix_rate)
		bright[name] = _brightness(pcm)

	# --- the ones that have to be short ---------------------------------------------------------
	# Mortar ticking is a grain of lime letting go. If it ever gets long it stops reading as a tick
	# and starts reading as the chimney groaning, which is a different band of the margin.
	_check(length["mortarTick"] < 0.25,
		"a mortar tick is %.2f s — short enough to be a tick" % length["mortarTick"])
	_check(length["mortarTick"] < length["groan"] * 0.25,
		"and a small fraction of the groan (%.2f s), which is the sound it must not become"
			% length["groan"])

	# --- the ones that have to be long ------------------------------------------------------------
	_check(length["roar"] > 2.0, "the roar runs %.1f s" % length["roar"])
	_check(length["crash"] > 1.0, "the ground thump runs %.1f s" % length["crash"])
	_check(length["groan"] > 0.8, "the groan runs %.1f s" % length["groan"])
	_check(length["crack"] < length["roar"],
		"and the crack is a crack (%.2f s), not a second roar" % length["crack"])

	# --- bright and dark --------------------------------------------------------------------------
	# "A ground thump you feel in the subwoofer": everything below 200 Hz and nothing above it. If
	# the crash is ever brighter than the tick, the low end has gone out of the biggest moment.
	_check(bright["crash"] < bright["mortarTick"],
		"the thump is darker than the tick (%.3f against %.3f)"
			% [bright["crash"], bright["mortarTick"]])
	_check(bright["groan"] < bright["crack"],
		"and the groan is darker than the crack, which is what makes one a warning and the other an event")
	_check(bright["propSplit"] > bright["groan"],
		"a prop splitting is a sharp noise, not a low one")

	# --- and they are not all the same thing ------------------------------------------------------
	var seen := {}
	for name in cues:
		var key := "%.2f/%.2f" % [length[name], bright[name]]
		_check(not seen.has(key),
			"%s is its own sound, not a copy of %s" % [name, seen.get(key, "")])
		seen[key] = name

	if failures > 0:
		printerr("FELL AUDIO: %d failure(s)" % failures)
	else:
		print("FELL AUDIO: eight sounds, each doing what the design says it does.")
	quit(1 if failures > 0 else 0)


func _pcm(stream: AudioStreamWAV) -> PackedFloat32Array:
	var bytes := stream.data
	var out := PackedFloat32Array()
	out.resize(bytes.size() / 2)
	for i in out.size():
		out[i] = float(bytes.decode_s16(i * 2)) / 32768.0
	return out


func _peak(pcm: PackedFloat32Array) -> float:
	var m := 0.0
	for v in pcm:
		m = maxf(m, absf(v))
	return m


## Seconds until it has fallen to a twentieth of its peak — roughly where a listener stops hearing
## it, and the thing the design's "decay" figures describe.
func _decay_seconds(pcm: PackedFloat32Array, rate: int) -> float:
	var peak := _peak(pcm)
	if peak <= 0.0:
		return 0.0
	var floor_at := peak * 0.05
	for i in range(pcm.size() - 1, -1, -1):
		if absf(pcm[i]) > floor_at:
			return float(i) / rate
	return 0.0


## A crude spectral centroid — mean absolute first difference over mean absolute level. Entirely
## enough to separate a thump from a tick.
func _brightness(pcm: PackedFloat32Array) -> float:
	var energy := 0.0
	var delta := 0.0
	for i in range(1, pcm.size()):
		energy += absf(pcm[i])
		delta += absf(pcm[i] - pcm[i - 1])
	return (delta / energy) if energy > 0.0 else 0.0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
