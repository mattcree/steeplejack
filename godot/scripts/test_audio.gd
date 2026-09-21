# The four tap sounds, measured — because nobody on this side of the build can hear them.
#
# 02-climbing-system.md is explicit that the taps are a mechanic and not a garnish: they must be
# distinguishable "on laptop speakers, in mono, at low volume", and they must differ on the **attack
# and decay envelope**, not on timbre alone, because timbre is what laptop speakers throw away.
#
# So this measures the two things the doc actually specifies — how long each one rings for, and how
# much high-frequency energy is in it — and asserts they run in the direction the table says. That
# is a weaker claim than "they sound right", which no test can make, and a much stronger one than
# "a stream exists", which is what a test of synthesised audio usually settles for.
#
# The specific failure this exists to catch: a synth parameter edit that makes two tiers converge.
# Nothing else in this project would notice, and the consequence is that the tap test stops being a
# skill and becomes a coin toss — with no error, no crash and no visible symptom.
#
#   make godot-script SCRIPT=res://scripts/test_audio.gd

extends SceneTree

var failures := 0


func _init() -> void:
	var scene: PackedScene = load("res://scenes/steeplejack.tscn")
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame

	var foley = world.get_node_or_null("Foley")
	_check(foley != null, "the scene has a Foley")
	if foley == null:
		_done()
		return

	# Worst to best, JointTier's own order.
	var names := ["cracked", "perished", "fair", "sound"]
	var decay := []
	var bright := []

	for tier in 4:
		var s: AudioStreamWAV = foley.tap_stream(tier)
		_check(s != null, "there is a '%s' tap" % names[tier])
		if s == null:
			_done()
			return
		var pcm := _samples(s)
		_check(pcm.size() > 200, "  and it has %d samples" % pcm.size())
		_check(_peak(pcm) > 0.05, "  and it is not silence (peak %.2f)" % _peak(pcm))
		decay.append(_decay_seconds(pcm, s.mix_rate))
		bright.append(_brightness(pcm))
		print("  --    %-9s rings for %.0f ms, brightness %.3f"
			% [names[tier], decay[tier] * 1000.0, bright[tier]])

	# The synth has to produce the decay the table asks for. Without this the ordering checks below
	# all pass on four sounds that are uniformly five times too short — which is exactly what the
	# first version did, reading "~120 ms decay" as a -60 dB time and rendering a 23 ms click.
	var authored := {"cracked": 260.0, "perished": 400.0, "fair": 200.0, "sound": 120.0}
	for tier in 4:
		var want: float = authored[names[tier]]
		var got: float = decay[tier] * 1000.0
		_check(absf(got - want) < want * 0.35,
			"%s rings for about the %.0f ms the design doc asks for (%.0f ms)"
				% [names[tier], want, got])

	# The headline of the table: a sound joint is a short sharp ring and a perished one is a long
	# dead thud. If those two ever converge the tap test stops being a skill.
	var i_sound := 3
	var i_perished := 1
	_check(decay[i_perished] > decay[i_sound] * 1.8,
		"perished rings far longer than sound (%.0f ms vs %.0f ms)"
			% [decay[i_perished] * 1000.0, decay[i_sound] * 1000.0])
	_check(bright[i_sound] > bright[i_perished] * 1.5,
		"and sound is far brighter than perished (%.3f vs %.3f)"
			% [bright[i_sound], bright[i_perished]])

	# Fair sits between them, which is the only thing that makes it a third reading rather than a
	# coin toss between the two the player can already tell apart.
	_check(decay[2] > decay[3] and decay[2] < decay[1],
		"fair rings longer than sound and shorter than perished (%.0f ms)" % (decay[2] * 1000.0))
	_check(bright[2] < bright[3] and bright[2] > bright[1],
		"and sits between them for brightness (%.3f)" % bright[2])

	# Every pair has to be told apart, not just the extremes. Four sounds where two are twins is
	# three sounds and a bug.
	for a in 4:
		for b in range(a + 1, 4):
			var d_gap: float = absf(decay[a] - decay[b]) / maxf(decay[a], decay[b])
			var b_gap: float = absf(bright[a] - bright[b]) / maxf(bright[a], bright[b])
			_check(d_gap > 0.15 or b_gap > 0.15,
				"%s and %s are tellable apart (decay %.0f%%, brightness %.0f%%)"
					% [names[a], names[b], d_gap * 100.0, b_gap * 100.0])

	# The cracked joint's tell is a *second event* — a loose face buzzing after the strike — because
	# an ear finds two events far more reliably than it finds a timbre. Check the energy really does
	# come back up after the initial strike has died away.
	var cracked := _samples(foley.tap_stream(0))
	_check(_has_second_event(cracked, foley.tap_stream(0).mix_rate),
		"the cracked tap rattles after the strike rather than just decaying")

	# The gust tell. Its *length* is the mechanic: 10-failure-and-difficulty.md allows a gust to
	# blow you off only if a 1.2 s warning played first, so a cue that runs short leaves a window in
	# which the gust is unannounced and the failure is unfair by the project's own definition.
	var tell: AudioStreamWAV = foley.cue_stream("gustTell")
	_check(tell != null, "there is a gust tell")
	if tell != null:
		var secs: float = float(_samples(tell).size()) / tell.mix_rate
		_check(absf(secs - 1.2) < 0.05, "and it is the design's 1.2 s pre-roll (%.2f s)" % secs)
		var pcm := _samples(tell)
		# It has to swell rather than start at full. A cue that is loudest at its start does not
		# read as something arriving.
		var first := _peak_of(pcm, 0, pcm.size() / 4)
		var last := _peak_of(pcm, pcm.size() * 3 / 4, pcm.size())
		_check(last > first * 1.4, "and swells towards the gust (%.2f -> %.2f)" % [first, last])

	# --- the climb: AUD-004 --------------------------------------------------------------------------
	# A rung is a knock, not a ring: short, low, and gone before the next one.
	var rung: AudioStreamWAV = foley.cue_stream("rung")
	_check(rung != null and _peak(_samples(rung)) > 0.05, "there is a rung knock, and it is not silence")
	if rung != null:
		var rd := _decay_seconds(_samples(rung), rung.mix_rate)
		_check(rd < 0.12, "and it is a knock — gone in %.0f ms" % (rd * 1000.0))
	for cue in ["creak", "thump"]:
		var c: AudioStreamWAV = foley.cue_stream(cue)
		_check(c != null and _peak(_samples(c)) > 0.05, "there is a %s, and it is not silence" % cue)

	# The breath and the slide loop, so their seams must not click.
	for pair in [["breath", foley.breath_stream()], ["slide", foley.slide_stream()]]:
		var st: AudioStreamWAV = pair[1]
		_check(st != null and st.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the %s loops" % pair[0])
		if st != null:
			var pcm := _samples(st)
			_check(absf(pcm[0]) < 0.05 and absf(pcm[pcm.size() - 1]) < 0.05,
				"and its seam does not click (%.3f, %.3f)" % [pcm[0], pcm[pcm.size() - 1]])

	# --- the mix has an order, and it is not an accident ----------------------------------------
	#
	# Going down the ladder was the second loudest thing in the game after a chimney hitting the
	# ground, and 14 dB over the hammer you spend the whole shift swinging. A playtest called it
	# earsplitting. These are the two rules that were being broken, as assertions, because a mix
	# drifts back the moment someone wants one sound to "read better".
	var slide_db: float = foley.slide_max_db()
	_check(slide_db < foley.level("hammer"),
		"the slide down is quieter than a hammer blow (%.0f < %.0f dB)" % [slide_db, foley.level("hammer")])
	_check(slide_db < foley.level("crash"),
		"and far quieter than a chimney landing (%.0f < %.0f dB)" % [slide_db, foley.level("crash")])
	# It is continuous and broadband, so it needs headroom a one-shot does not — but it still has
	# to be audible over the knocks of the climb it interrupts, or the descent has no voice at all.
	_check(slide_db > foley.level("rung"),
		"but still over the rung knocks it replaces (%.0f > %.0f dB)" % [slide_db, foley.level("rung")])

	# The sounds you make hundreds of times a shift sit under the ones that happen twice.
	for often in ["rung", "hammer", "taps"]:
		for rare in ["crash", "crack", "propSplit"]:
			_check(foley.level(often) < foley.level(rare),
				"%s (%.0f) sits under %s (%.0f)" % [often, foley.level(often), rare, foley.level(rare)])

	# Breathing quickens as nerve goes. The rate is set by band, and each band is faster.
	var rates := []
	for band in 4:
		foley.set_breath(band, true)
		rates.append(foley.breath_rate())
	_check(rates[0] < rates[1] and rates[1] < rates[2] and rates[2] < rates[3],
		"breathing quickens band by band (%s)" % str(rates))

	# The wind bed has to loop without a click, which is the most noticeable fault a four-second
	# loop can have.
	var wind: AudioStreamWAV = foley.wind_stream()
	_check(wind != null and wind.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the wind bed loops")
	if wind != null:
		var w := _samples(wind)
		_check(absf(w[0]) < 0.05 and absf(w[w.size() - 1]) < 0.05,
			"and is faded at both ends, so the loop point does not click (%.3f, %.3f)"
				% [w[0], w[w.size() - 1]])

	# --- levels: nothing plays at full scale ------------------------------------------------------
	# The synthesis clamps to +-1.0, so a cue with no level set plays as loud as the game can make
	# it. Every one-shot did, and it was the first thing a player said about the sound.
	var master: float = foley.level("master")
	_check(master < 0.0, "the mix has headroom (master %.1f dB)" % master)
	for cue in ["taps", "hammer", "bent", "seated", "rung", "creak", "thump", "gustTell"]:
		_check(foley.level(cue) < -5.0, "%s plays below full scale (%.1f dB)" % [cue, foley.level(cue)])
	_check(foley.level("rung") < foley.level("hammer"), "a boot on a rung is quieter than a hammer blow")

	# The player's volume moves everything, the wind bed included.
	foley.set_volume(1.0)
	foley.set_height(40.0)
	var loud: float = foley.wind_player_db()
	foley.set_volume(0.5)
	var half: float = foley.wind_player_db()
	_check(absf((loud - half) - 6.0) < 0.6, "half volume is 6 dB down on the wind (%.1f -> %.1f)" % [loud, half])
	foley.tap(0)
	_check(absf(foley.last_played_db() - (foley.level("taps") + master + linear_to_db(0.5))) < 0.1,
		"and a tap plays at its level under it (%.1f dB)" % foley.last_played_db())
	foley.set_volume(0.0)
	_check(foley.wind_player_db() < -60.0, "volume off is silence")
	foley.set_volume(0.7)

	_done()


func _done() -> void:
	print("AUDIO: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


# --- measuring ------------------------------------------------------------------------------------

func _samples(s: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var bytes: PackedByteArray = s.data
	out.resize(bytes.size() / 2)
	for i in out.size():
		out[i] = float(bytes.decode_s16(i * 2)) / 32768.0
	return out


func _peak_of(pcm: PackedFloat32Array, from: int, to: int) -> float:
	var m := 0.0
	for i in range(maxi(from, 0), mini(to, pcm.size())):
		m = maxf(m, absf(pcm[i]))
	return m


func _peak(pcm: PackedFloat32Array) -> float:
	var m := 0.0
	for v in pcm:
		m = maxf(m, absf(v))
	return m


## Seconds until the sound has fallen to a twentieth of its peak — roughly where a listener stops
## hearing it, and the thing the design doc's "decay" figures describe.
func _decay_seconds(pcm: PackedFloat32Array, rate: int) -> float:
	var peak := _peak(pcm)
	if peak <= 0.0:
		return 0.0
	var floor_at := peak * 0.05
	for i in range(pcm.size() - 1, -1, -1):
		if absf(pcm[i]) > floor_at:
			return float(i) / rate
	return 0.0


## How much of the signal is high-frequency, as the mean absolute first difference over the mean
## absolute level. A crude spectral centroid and entirely enough to separate a ring from a thud.
func _brightness(pcm: PackedFloat32Array) -> float:
	var energy := 0.0
	var delta := 0.0
	for i in range(1, pcm.size()):
		energy += absf(pcm[i])
		delta += absf(pcm[i] - pcm[i - 1])
	return (delta / energy) if energy > 0.0 else 0.0


## Whether the envelope comes back up after the strike, rather than decaying monotonically. The
## rattle is the cracked joint's whole tell and it has to be a separate event to be one.
func _has_second_event(pcm: PackedFloat32Array, rate: int) -> bool:
	var window := maxi(1, rate / 200)   # 5 ms
	var env := PackedFloat32Array()
	var i := 0
	while i + window < pcm.size():
		var m := 0.0
		for k in window:
			m = maxf(m, absf(pcm[i + k]))
		env.append(m)
		i += window
	if env.size() < 6:
		return false
	# Skip the strike itself, then look for any rise worth 15% of the running level.
	var start := 3
	for j in range(start + 1, env.size()):
		if env[j] > env[j - 1] * 1.15 and env[j] > 0.02:
			return true
	return false


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
