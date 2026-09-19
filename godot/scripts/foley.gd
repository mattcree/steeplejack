# Every sound in the game, synthesised at load from data/audio/foley.json.
#
# The MVP lists audio and says "**Not optional.**", and the climbing system doc is blunter than
# that: the four tap sounds *are* the read-the-brickwork mechanic, and the tap test is the game's
# signature sound. There has been none of it, because a .wav is a binary asset and binary assets are
# the half of this project that agents cannot author or review.
#
# So: no .wav files. The cues are written as envelopes in a JSON file and rendered into buffers
# here. That is only possible because the design doc specifies them as envelopes in the first place
# — "bright transient, ~120 ms decay", "no transient, ~400 ms, low-passed" — which is a synth patch
# written in English. A real sound designer replaces all of this and should; until then the game has
# ears instead of not having them.
#
# ## What cannot be checked by listening
#
# Nobody on this side of the build can hear it, so `test_audio.gd` measures instead: that the four
# taps really do differ in decay length and in brightness, in the *direction* the table specifies.
# That is a weaker claim than "they sound right" and a much stronger one than "a stream exists".

class_name Foley
extends Node

const PATH := "res://../data/audio/foley.json"

## Decay figures in the design doc are the **audible tail** — "bright transient, ~120 ms decay"
## means it is over in about 120 ms, not that it is 60 dB down by then. Reading them as a -60 dB
## time made the sound tap audibly over in 23 ms, which is a click rather than a ring, and made
## every figure in the table a fifth of what its author meant. ln(20) is the -26 dB point, which is
## about where a tap stops existing for a listener over a wind bed.
const AUDIBLE_TAIL := 2.9957

var _spec := {}
var _taps: Array[AudioStreamWAV] = []
var _one_shot := {}
var _wind: AudioStreamWAV

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _wind_player: AudioStreamPlayer

## Tier order is JointTier's: cracked, perished, fair, sound. Worst first, as every enum in this
## project is, so an index from the sim can be used directly without a lookup that could be wrong.
const TIER_KEYS := ["cracked", "perished", "fair", "sound"]


func _ready() -> void:
	_spec = _load()
	if _spec.is_empty():
		return

	for key in TIER_KEYS:
		_taps.append(_render(_spec["taps"][key]))
	for key in ["hammer", "bent", "seated"]:
		_one_shot[key] = _render(_spec[key])
	_wind = _render_wind(_spec["wind"])
	_one_shot["gustTell"] = _render_gust_tell(_spec["gustTell"])

	# A small pool, because a player already playing cannot be reused and the tap test is meant to
	# be something you do constantly.
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

	_wind_player = AudioStreamPlayer.new()
	_wind_player.stream = _wind
	_wind_player.volume_db = _spec["wind"]["groundDb"]
	add_child(_wind_player)
	_wind_player.play()


func _load() -> Dictionary:
	var f := FileAccess.open(ProjectSettings.globalize_path(PATH), FileAccess.READ)
	if f == null:
		push_error("foley: cannot read %s" % PATH)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("foley: %s is not an object" % PATH)
		return {}
	return parsed


# --- playing --------------------------------------------------------------------------------------

## Sound the brickwork. `tier` is JointTier: 0 cracked .. 3 sound.
func tap(tier: int) -> void:
	if tier >= 0 and tier < _taps.size():
		_play(_taps[tier])


func cue(name: String, pitch: float = 1.0) -> void:
	if _one_shot.has(name):
		_play(_one_shot[name], pitch)


## The height mix — AUD-003. The ground goes quiet and the wind takes over, which is most of what
## altitude actually sounds like and the cheapest altitude cue there is.
func set_height(metres: float) -> void:
	if _wind_player == null:
		return
	var w: Dictionary = _spec["wind"]
	var t: float = clampf(metres / maxf(w["refHeightM"], 1.0), 0.0, 1.0)
	_wind_player.volume_db = lerpf(w["groundDb"], w["topDb"], t)


func _play(stream: AudioStreamWAV, pitch: float = 1.0) -> void:
	if _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.play()


# --- synthesis -------------------------------------------------------------------------------------

## One struck-object cue: a transient, some decaying partials, some noise, optionally a rattle.
##
## This is a modal synth in twenty lines. Brick and mortar ring at a handful of frequencies and die
## away; how fast they die and how much transient is in front of them is exactly what the ear reads
## as "sound" versus "perished", which is why the design doc could specify it as numbers.
func _render(p: Dictionary) -> AudioStreamWAV:
	var rate: int = int(_spec.get("sampleRate", 22050))
	var decay: float = float(p["decayMs"]) / 1000.0
	# Long enough to hold the whole tail. A cue clipped before it has decayed clicks.
	var seconds: float = decay * 1.45 + 0.05
	var n := int(seconds * rate)

	var rng := RandomNumberGenerator.new()
	# Fixed, so the same brick makes the same noise on every machine and in every recording.
	rng.seed = hash(str(p["partials"]) + str(p["decayMs"]))

	var buf := PackedFloat32Array()
	buf.resize(n)

	var tau: float = decay / AUDIBLE_TAIL
	var lp_a: float = _one_pole(float(p["lowpassHz"]), rate)
	var lp := 0.0
	var partials: Array = p["partials"]
	var noise_amt: float = float(p["noise"])
	var transient: float = float(p["transient"])
	var rattle: float = float(p.get("rattle", 0.0))
	var rattle_at: float = float(p.get("rattleDelayMs", 0.0)) / 1000.0
	var rattle_hz: float = float(p.get("rattleHz", 100.0))

	for i in n:
		var t := float(i) / rate
		var env: float = exp(-t / tau)
		var v := 0.0

		# The partials. Each one a touch shorter than the one below it, which is what real struck
		# objects do and what stops the tail sounding like an organ.
		for k in partials.size():
			var f: float = partials[k]
			v += sin(TAU * f * t) * exp(-t / (tau * (1.0 - 0.18 * k))) / float(k + 2)

		# The attack. A few milliseconds of noise is most of what "bright transient" means.
		v += rng.randf_range(-1.0, 1.0) * transient * exp(-t / 0.004)
		# And the body noise — the sound of it being a lump of fired clay and not a bell.
		v += rng.randf_range(-1.0, 1.0) * noise_amt * env * 0.5

		# The rattle: a loose face buzzing after the strike. This is the whole tell for a cracked
		# joint and it is a *second event*, deliberately, because an ear finds two events far more
		# reliably than it finds a timbre.
		if rattle > 0.0 and t > rattle_at:
			var since := t - rattle_at
			var buzz: float = 0.5 + 0.5 * sign(sin(TAU * rattle_hz * since))
			v += rng.randf_range(-1.0, 1.0) * rattle * buzz * exp(-since / (tau * 0.7))

		lp += (v - lp) * lp_a
		# No second envelope here. Every term above already carries its own — the partials decay at
		# tau, the body noise at tau, the transient in four milliseconds — and multiplying the sum by
		# `env` a second time squared the decay and made every cue half the length its table asked
		# for. It looked right and measured wrong, which is the whole reason test_audio exists.
		buf[i] = clampf(lp, -1.0, 1.0)

	return _to_stream(buf, rate, false)


## The wind bed: filtered noise with a slow swell, looped.
func _render_wind(w: Dictionary) -> AudioStreamWAV:
	var rate: int = int(_spec.get("sampleRate", 22050))
	var n := int(float(w["loopSeconds"]) * rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210

	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp_a: float = _one_pole(float(w["lowpassHz"]), rate)
	var lp := 0.0
	var gust_hz: float = float(w["gustHz"])
	var depth: float = float(w["gustDepth"])

	for i in n:
		var t := float(i) / rate
		lp += (rng.randf_range(-1.0, 1.0) - lp) * lp_a
		var swell: float = 1.0 - depth * 0.5 * (1.0 - cos(TAU * gust_hz * t))
		# Faded at both ends and crossed over, so the loop point is not a click. The loop is four
		# seconds and a click every four seconds is the most noticeable thing in a mix.
		var edge: float = minf(1.0, minf(t, float(w["loopSeconds"]) - t) / 0.25)
		buf[i] = clampf(lp * 3.0 * swell * edge, -1.0, 1.0)

	var s := _to_stream(buf, rate, true)
	return s


## The gust warning: filtered noise whose cutoff sweeps up over the pre-roll.
##
## Not a tone. A rising note is a UI sound and this is weather arriving — the player has to read it
## as "something is coming at me", not as "the game would like your attention". Sweeping the filter
## rather than the pitch is what makes noise sound like it is approaching.
##
## Its length is the design's pre-roll and nothing else, because the fairness contract is about
## *that* duration: a cue that runs short leaves a gap in which the gust is unannounced.
func _render_gust_tell(g: Dictionary) -> AudioStreamWAV:
	var rate: int = int(_spec.get("sampleRate", 22050))
	var seconds: float = float(g["seconds"])
	var n := int(seconds * rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150

	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var from_hz: float = float(g["fromHz"])
	var to_hz: float = float(g["toHz"])
	var gain: float = float(g["gain"])

	for i in n:
		var t := float(i) / rate
		var u: float = t / maxf(seconds, 0.001)
		# Cutoff sweeps on a curve rather than linearly, so most of the brightening happens late and
		# the cue is still arriving when the gust lands.
		var cutoff: float = lerpf(from_hz, to_hz, u * u)
		var a: float = _one_pole(cutoff, rate)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * a
		# Swells in, and does not fall away at the end: it hands straight over to the gust.
		var env: float = smoothstep(0.0, 0.35, u) * (0.45 + 0.55 * u)
		buf[i] = clampf(lp * env * gain * 4.0, -1.0, 1.0)

	return _to_stream(buf, rate, false)


func _one_pole(cutoff_hz: float, rate: int) -> float:
	# The usual one-pole smoothing coefficient. Not a filter anyone would ship, and entirely enough
	# to put four hundred hertz between a ring and a thud.
	return clampf(1.0 - exp(-TAU * cutoff_hz / float(rate)), 0.0, 1.0)


func _to_stream(buf: PackedFloat32Array, rate: int, looping: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var v := int(clampf(buf[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)

	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	if looping:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = buf.size()
	return s


# --- what the tests measure, since nobody here can listen -------------------------------------------

func tap_stream(tier: int) -> AudioStreamWAV:
	return _taps[tier] if tier >= 0 and tier < _taps.size() else null


func cue_stream(name: String) -> AudioStreamWAV:
	return _one_shot.get(name)


func wind_stream() -> AudioStreamWAV:
	return _wind
