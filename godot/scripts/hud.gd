# The HUD, to docs/01-gdd/03-meters-grip-nerve.md#hud.
#
#   "Minimal and diegetic-ish. Bottom-left, two thin arcs around the hand icon. Grip: a fast,
#    responsive arc. Flashes at 20. Nerve: a slow arc that visibly breathes. [...] No minimap.
#    No objective marker. The objective is at the top; you can see it."
#
# Two departures from that, both deliberate and both learned the hard way. The arcs fade to a ghost
# rather than to nothing: a meter faded to zero is a meter the player never learns they have. And
# the verbs are listed with the *reason* each one is unavailable, because every action in this game
# is gated on state you cannot see — is a dog seated, have I read this joint — and a greyed-out row
# with no reason teaches nothing.

extends Control

const HAND := Vector2(96, -104)
const GRIP_R := 44.0
const NERVE_R := 56.0
const FADE_ABOVE := 85.0
const REST_ALPHA := 0.22
const Q_KEY := "Q"
## VERB-002: the pip is visible for 0.6 s after a tap, then gone.
const PIP_SECONDS := 0.6

@onready var player: Node = get_node("../Player")

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_process(true)


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or player.jack == null:
		return
	var jack: Jack = player.jack
	var hand := Vector2(HAND.x, size.y + HAND.y)
	var now := float(Time.get_ticks_msec()) / 1000.0

	var grip: float = jack.grip()
	var nerve: float = jack.nerve()
	var nerve_max: float = maxf(jack.nerve_max(), 1.0)
	var busy: bool = player.work_mode

	var grip_a := maxf(REST_ALPHA, _ease((FADE_ABOVE - grip) / 25.0))
	var nerve_a := maxf(REST_ALPHA, _ease((FADE_ABOVE - (nerve / nerve_max) * 100.0) / 25.0))
	if busy:
		grip_a = 1.0
		nerve_a = 0.85

	# Grip is the fast one. Below the tremor threshold it flashes — the telegraph, on screen.
	var grip_col := Color(0.86, 0.74, 0.42, grip_a)
	if jack.tremoring():
		var pulse := 0.55 + 0.45 * sin(now * 9.0)
		grip_col = Color(0.92, 0.28, 0.20, grip_a * pulse)

	# Nerve is the slow one, and it breathes: the character's chest, not a progress bar.
	var breath := 1.0 + 0.035 * sin(now * (0.55 + 0.30 * jack.nerve_band()) * PI)

	_arc(hand, GRIP_R, 1.0, 1.5, Color(0, 0, 0, 0.35 * grip_a))
	_arc(hand, NERVE_R, 1.0, 1.5, Color(0, 0, 0, 0.35 * nerve_a))
	_arc(hand, GRIP_R, grip / 100.0, 4.0, grip_col)
	_arc(hand, NERVE_R * breath, nerve / nerve_max, 3.0, Color(0.42, 0.58, 0.78, nerve_a))

	if player._now < 30.0:
		var a := _ease((30.0 - player._now) / 5.0) * 0.55
		_label("grip", Vector2(HAND.x - 20, hand.y + GRIP_R + 14), Color(0.86, 0.74, 0.42, a))
		_label("nerve", Vector2(HAND.x + 30, hand.y + NERVE_R + 14), Color(0.42, 0.58, 0.78, a))

	# --- where you are ---------------------------------------------------------------------------
	var info_x := HAND.x + NERVE_R + 26
	# His FEET, not the capsule's middle. `global_position.y` is his waist and reads 0.9 m high —
	# the same off-by-a-body-height that the sim was fixed for and the HUD never was, so the number
	# on screen disagreed with every number in the level file.
	# Floored at zero: standing on the ground printed "-0 m", and a negative height is the kind of
	# small wrongness that makes a player stop trusting every other number on the screen.
	_label("%.0f m" % maxf(player.height_m(), 0.0), Vector2(info_x, hand.y - 20), Color(0.94, 0.92, 0.88, 0.92))
	if player.on_ladder:
		var where: String = jack.stance_name()
		var band: String = jack.band_type_at(player.height_m())
		if band != "":
			where += "  ·  " + band
		_label(where, Vector2(info_x, hand.y), Color(0.80, 0.78, 0.74, 0.70), 13)

	var stock := "%s   %d dogs in the bag   top %.0fm" % [
		"ladder on your shoulder" if player.carrying_ladder else "no ladder",
		player.dogs_carried, player.ladder_top]
	_label(stock, Vector2(info_x, hand.y + 22), Color(0.78, 0.76, 0.72, 0.85), 13)

	# Only once there is something to span *from*. With no dogs driven, the span is measured from
	# the ground and reads "62.0 m span — about to buckle" at the top of a ladder that is lashed all
	# the way down. True, useless, and permanently on screen in alarm red.
	if player.span_warning != "" and jack.anchor_count() > 0 and not player.at_top and player.on_ladder:
		var buckle: bool = player.span_warning.contains("buckle")
		var col := Color(0.95, 0.30, 0.22, 0.6 + 0.4 * sin(now * 7.0)) if buckle else Color(0.92, 0.70, 0.35, 0.9)
		_label(player.span_warning, Vector2(info_x, hand.y + 42), col, 13)

	# --- what you can do, and what is stopping you ----------------------------------------------
	var next_step := _next_step()
	_centre(next_step, size.y - 96, Color(0.95, 0.93, 0.88, 0.90))

	var rows := _affordances()
	var row_y := size.y - 44 - 17 * (rows.size() - 1)
	for row in rows:
		var text: String = "[%s]  %s" % [row[0], row[1]]
		if not row[2] and row[3] != "":
			text += " — " + row[3]
		var col := Color(0.93, 0.90, 0.84, 0.88) if row[2] else Color(0.64, 0.62, 0.60, 0.48)
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		_label(text, Vector2(size.x - w - 28, row_y), col, 13)
		row_y += 17

	# The transient line fades out rather than sitting there for ever. Two permanent instructions
	# saying different things — one at the top, one in the middle — is how the player learns to stop
	# reading either.
	var ttl: float = player.message_ttl()
	if ttl > 0.0:
		_centre(player.message, size.y * 0.66, Color(0.94, 0.91, 0.86, 0.92 * _ease(ttl * 3.0)))

	if player.work_mode:
		_draw_work(jack)

	_draw_pip(jack)

	if player.rigging_to >= 0:
		_draw_rig(jack)

	if player.lashing:
		_draw_lash(jack)

	if player.hauling:
		_draw_haul()

	_draw_stack_warnings()
	_draw_fuse()
	_draw_recovery(jack, hand)
	if player.at_top:
		_draw_top()

	# Rule 8: every audio cue has a visual fallback. This one is not optional in a second way too —
	# the fairness table makes the gust's 1.2 s warning the thing that separates a fair failure from
	# a bug, and a warning only some players receive is not a warning.
	if jack.gust_tell():
		_draw_gust_tell(jack)

	# Over everything, because for 900 ms nothing else on this screen matters.
	if player.jack.slip_in_progress():
		_draw_slip(jack)

	_draw_fall_cut()

	# There is no objective marker because the objective is the top and you can see it. But you
	# cannot see the *rule*, so it is said once and then never again.
	if player._now < 14.0 and not player.at_top:
		_centre("Climb the stack. You can only go as high as you have built.",
			size.y * 0.14, Color(0.92, 0.90, 0.86, 0.85 * _ease((14.0 - player._now) / 3.0)))


func _next_step() -> String:
	if player.at_top or player.recovering != player.REC_NONE or player.falling or player.fade_in > 0.3:
		return ""
	if player.jack.slip_in_progress():
		return ""
	if player.rigging_to >= 0 or player.lashing or player.hauling:
		return ""
	# A section failing under him owns the screen. Advice about lashing is noise while it goes.
	if player.stack_info.get("buckling", false):
		return ""
	if player.work_mode:
		return "Line the dog up, then hold the left button to draw — release to strike."

	# --- on the ground: the order of things ---------------------------------------------------------
	# Walking to the stack with nothing in your hands is walking there to come back, so the first
	# line sends him to the cradle, and only then to the ladder.
	if not player.on_ladder:
		if player.at_cradle() and (not player.carrying_ladder or player.dogs_carried == 0):
			return "Take a ladder and fill the dog bag.  [F]"
		if not player.carrying_ladder and player.dogs_carried == 0 and player.ladders_at_base > 0:
			return ("Your stack is still up. Take a ladder from the cradle and climb it again."
				if player.fall_reason != "" else
				"Walk to the cradle at the foot of the stack — the timber by the fire.")
		return "Climb on — the standing ladder at the foot of the stack."

	# --- on the ladder --------------------------------------------------------------------------------
	if player.has_lashable_anchor() and player.carrying_ladder:
		return "Lash the ladder to your top dog [R] — then hold the left button and go round."
	if player.has_lashable_anchor() and not player.carrying_ladder:
		return ("Haul a section up to it [G]." if player.gin_joint >= 0
			else "A dog to lash to, and no ladder: rig a gin wheel on it [G], or fetch one from the cradle.")
	if player.dogs_carried == 0:
		return "Bag is empty. Haul some up [G], or climb down to the cradle."
	# Where the next dog goes is the thing a new player gets wrong: near the top of what is built,
	# as high as he can reach, so the next section goes as high as it can. A dog at his feet on the
	# first rung is a dog that buys nothing.
	if player.height_m() < player.ladder_top - 1.2 and player.target_span() < 3.0:
		return "Climb up what you've built — the next dog wants to be about 4 m above your last one."
	if player.target_id < 0:
		return "Look up at the brickwork above you to pick a joint."
	var span: float = player.target_span()
	if span > 0.0 and span < 1.5:
		return "Too close to your last dog to buy much height — look higher."
	if not player.target_tapped():
		return "Tap it to hear what it is worth [E] — or trust your eye and drive a dog [right mouse]."
	return "Drive a dog into that joint, or look for a better one.  [right mouse]"


## [key, verb, available, why-not]
func _affordances() -> Array:
	if player.at_top or player.falling or player.fade_in > 0.3:
		return []
	if player.jack.slip_in_progress():
		return [["SPACE", "grab", true, ""]]
	if player.rigging_to >= 0:
		return [[Q_KEY, "stop rigging", true, ""]]
	if player.lashing or player.hauling:
		return []
	if player.work_mode:
		return [
			["mouse", "place the dog", true, ""],
			["hold LMB", "draw, release to strike", true, ""],
			["RMB", "back out", true, ""],
		]
	if not player.on_ladder:
		return [
			["WASD", "walk", true, ""],
			["mouse", "look", true, ""],
			["F", "take a ladder and dogs", player.at_cradle(), "only at the cradle, at the foot of the stack"],
			[Q_KEY, "stance — rig it on the stack", false, "you rig a stance up there, not down here"],
		]
	var has_target: bool = player.target_id >= 0
	var sounded: bool = player.target_tapped()
	return [
		["W/S", "climb", true, ""],
		["E", "sound this joint" if not sounded else "sound it again", has_target,
			"no joint in reach — look at the brickwork"],
		["RMB", _drive_label(), has_target and player.dogs_carried > 0,
			"no joint in reach" if not has_target else "no dogs in the bag"],
		["R", "lash the next ladder", player.has_lashable_anchor() and player.carrying_ladder,
			"you are not carrying one" if not player.carrying_ladder else "needs a dog seated above you"],
		[Q_KEY, _next_stance_label(), true, ""],
		["T", "brew up", jack_free_hands(),
			"you need both hands — belt on first"],
		["G", _gin_label(), true, ""],
		["C / V", "a cigarette  ·  look at the view (hold)", true, ""],
	]


func _gin_label() -> String:
	if player.gin_joint < 0:
		return "rig the gin wheel on a dog in reach"
	if absf(player.height_m() + 0.55 - player.gin_height) < player.GIN_REACH:
		return "haul a section up" if not player.carrying_ladder else "haul (lash the one you have first)"
	return "move the gin wheel up to a dog in reach"


## "drive a dog into it — a 4.3 m span, flexing". The span a dog there would make, and what the
## table makes of it, before the dog goes in. MVP criterion 4 asks whether players *voluntarily*
## take the risky span, and nobody can volunteer for a risk they cannot see.
func _drive_label() -> String:
	var span: float = player.target_span()
	if span <= 0.0:
		return "drive a dog into it"
	var band: int = player.jack.classify_span(span)
	var what: String = ["rigid", "flexing", "swaying", "it will buckle"][clampi(band, 0, 3)]
	return "drive a dog into it — a %.1f m span, %s" % [span, what]


func jack_free_hands() -> bool:
	return player.jack.get_stance() >= 3


## What Q costs and what it buys, spelled out before it is pressed rather than after.
##
## This is the one decision the climbing system is built on — rush it one-handed or spend the time —
## and the player cannot make it at all if the price is invisible.
func _next_stance_label() -> String:
	var jack: Jack = player.jack
	var here: int = jack.get_stance()
	var want: int = (here + 1) % 5
	var name: String = jack.stance_name_of(want)
	if not jack.stance_needs_rigging(here, want):
		return "back to %s — instant" % name
	# One decimal under ten seconds. A hooked leg takes 1.5 s and "2 s to rig" is a different
	# number from the one the game charges.
	var secs: float = jack.stance_setup_seconds(want)
	var shown: String = ("%.1f" % secs) if secs < 10.0 else ("%.0f" % secs)
	return "%s — %s s to rig, %.0f grip a second" % [name, shown, jack.stance_drain_rate(want)]


func _draw_work(jack: Jack) -> void:
	# Centred on the joint the dog is going into, not the middle of the screen. The reticle was
	# attached to nothing, so the player aimed at a circle and the dog went wherever he happened to
	# be standing.
	var on = _on_screen(player.work_joint)
	var eye: Vector2 = on if on != null else Vector2(size.x * 0.5, size.y * 0.44)
	var px_per_deg := 10.0
	var tolerance: float = jack.tuning_f("hammerMaxAngleErrorDegrees", 12.0) * px_per_deg

	# The tolerance ring: inside it a strike is clean, outside it bends dogs. A ring rather than a
	# number, so the player watches the wobble eat their margin instead of reading it.
	draw_arc(eye, tolerance, 0, TAU, 64, Color(0.85, 0.85, 0.90, 0.30), 1.5)

	var err: float = player.aim.length()
	var q := clampf(1.0 - err / 12.0, 0.0, 1.0)
	var tip: Vector2 = eye + player.aim * px_per_deg
	var mark := Color(0.95, 0.35, 0.25).lerp(Color(0.55, 0.85, 0.45), q)
	draw_line(tip + Vector2(-9, 0), tip + Vector2(9, 0), mark, 2.0)
	draw_line(tip + Vector2(0, -9), tip + Vector2(0, 9), mark, 2.0)

	if player.swing_power > 0.0:
		draw_arc(eye, tolerance + 22.0, PI * 0.75, PI * 0.75 + TAU * 0.5 * player.swing_power,
			32, Color(0.90, 0.72, 0.30, 0.95), 5.0)

	var bar_w := 180.0
	var bar := Vector2(eye.x - bar_w * 0.5, eye.y + tolerance + 54.0)
	draw_rect(Rect2(bar - Vector2(1, 1), Vector2(bar_w + 2, 8)), Color(0, 0, 0, 0.47))
	draw_rect(Rect2(bar, Vector2(bar_w * player.dog_depth, 6)), Color(0.80, 0.71, 0.47, 0.94))
	_centre("dog %.0f%%   %.1f° off" % [player.dog_depth * 100.0, err], bar.y + 20,
		Color(0.85, 0.83, 0.80, 0.85), 13)

	# How long this stance buys you, counted down in seconds. The flashing arc says "soon" and this
	# says "four" — and the fairness contract is that the player can explain the fall afterwards,
	# which means knowing before it that they were spending something and how much was left.
	var left: float = jack.seconds_of_work_left()
	if left >= 0.0 and left < 12.0:
		var urgency := clampf(1.0 - left / 12.0, 0.0, 1.0)
		_centre("%.0f s of grip left in this stance" % ceilf(left), bar.y + 40,
			Color(0.92, 0.72 - 0.4 * urgency, 0.35 - 0.2 * urgency, 0.75 + 0.25 * urgency), 13)


## Where a joint is on screen, or null if it is behind the camera.
func _on_screen(id: int):
	if id < 0 or player.face == null:
		return null
	var j: Dictionary = player.face.joint(id)
	if j.is_empty():
		return null
	var world: Vector3 = (j["pos"] as Vector3) + player.chimney.global_position
	if player.camera.is_position_behind(world):
		return null
	return player.camera.unproject_position(world)


## The tap pip — VERB-002. Drawn **at the joint that was tapped**, not in a panel, for 0.6 s.
##
## Four shapes, from the sim, never colours: a ring for sound, a square for fair, a triangle for
## perished, a broken cross for cracked. Under it, the envelope of the sound that just played —
## a short spike for a ring, a long low hump for a thud, a spike and a second burst for a rattle —
## so a player who can hear learns to connect the shape to the sound, and one who cannot gets the
## same information the sound carried. The rattle's second event is drawn as a second event.
func _draw_pip(jack: Jack) -> void:
	var t: Dictionary = player.last_tap
	if t.is_empty():
		return
	var age: float = player._now - float(t["at"])
	if age > PIP_SECONDS:
		return
	var at = _on_screen(int(t["id"]))
	if at == null:
		return
	var a := 1.0 - _ease(age / PIP_SECONDS) * 0.9
	var c := Color(0.96, 0.97, 0.99, a)
	var shadow := Color(0, 0, 0, a * 0.55)
	var centre: Vector2 = (at as Vector2) + Vector2(0, -64)
	var r := 11.0

	for pass_col in [shadow, c]:
		var o := Vector2(1.5, 1.5) if pass_col == shadow else Vector2.ZERO
		match int(t["pip"]):
			0:   # sound: a ring
				draw_arc(centre + o, r, 0, TAU, 28, pass_col, 3.0)
			1:   # fair: a square
				draw_rect(Rect2(centre + o - Vector2(r, r), Vector2(r, r) * 2.0), pass_col, false, 3.0)
			2:   # perished: a triangle
				var tri := PackedVector2Array([centre + o + Vector2(0, -r * 1.1),
					centre + o + Vector2(r * 1.05, r * 0.8), centre + o + Vector2(-r * 1.05, r * 0.8),
					centre + o + Vector2(0, -r * 1.1)])
				draw_polyline(tri, pass_col, 3.0)
			_:   # cracked: a broken cross
				draw_line(centre + o + Vector2(-r, -r), centre + o + Vector2(-2, -2), pass_col, 3.0)
				draw_line(centre + o + Vector2(3, 3), centre + o + Vector2(r, r), pass_col, 3.0)
				draw_line(centre + o + Vector2(r, -r), centre + o + Vector2(-r, r), pass_col, 3.0)

	# The envelope, underneath.
	var env := PackedVector2Array()
	var w := 46.0
	var base := centre + Vector2(-w * 0.5, 30)
	for i in 24:
		var u := float(i) / 23.0
		var v := 0.0
		match int(t["pip"]):
			0: v = exp(-u * 9.0)                       # ring: sharp, short
			1: v = 0.75 * exp(-u * 5.0)                # knock: softer, longer
			2: v = 0.45 * exp(-u * 2.2) * minf(u * 8.0, 1.0)   # thud: no transient, long
			_: v = exp(-u * 11.0) + (0.55 * exp(-(u - 0.3) * 7.0) if u > 0.3 else 0.0)   # rattle
		env.append(base + Vector2(u * w, -v * 14.0))
	draw_polyline(env, Color(c.r, c.g, c.b, a * 0.8), 2.0)


## The cut to black, and the one sentence. The fairness contract: "the player must always be able
## to say, in one sentence, why that went wrong." So the sentence is on the black, in the sim's own
## words, before anything else happens — and then the next morning, and the stack still standing.
func _draw_fall_cut() -> void:
	var black: float = player.fall_black
	var back: float = player.fade_in
	if black > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, black))
		if black >= 1.0:
			var y := size.y * 0.42
			_centre("You fell %.0f m." % player.fall_from_m, y, Color(0.95, 0.93, 0.90, 0.95), 28)
			_centre(player.fall_reason, y + 38.0, Color(0.86, 0.84, 0.80, 0.9), 16)
	elif back > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, clampf(back, 0.0, 1.0)))
		_centre("The next morning. Your stack is still up there.", size.y * 0.42,
			Color(0.95, 0.93, 0.90, clampf(back * 1.4, 0.0, 0.95)), 18)


## Getting nerve back: a ring round the nerve arc filling as it comes, with what it is.
func _draw_recovery(jack: Jack, hand: Vector2) -> void:
	if player.recovering == player.REC_NONE:
		return
	var p: float = jack.recover_progress()
	var names := {1: "brewing up", 2: "a cigarette", 3: "looking at the view"}
	draw_arc(hand, NERVE_R + 10.0, -PI * 0.5, -PI * 0.5 + TAU * p, 48,
		Color(0.72, 0.84, 0.95, 0.9), 3.0)
	_label(names.get(player.recovering, ""), Vector2(HAND.x - 30, hand.y - NERVE_R - 22),
		Color(0.80, 0.88, 0.96, 0.9), 13)
	# The brew's line, as a subtitle. Said once, at the start, and left up while the tea lasts.
	if player.recovering == player.REC_TEA and player.tea_line != "":
		_centre("\u201c%s\u201d" % player.tea_line, size.y * 0.78, Color(0.95, 0.93, 0.88, 0.9), 17)


## The top. The HUD steps back and the climb is summed up, once.
##
## This is the player's own answer to what the MVP playtest is asking: did they still tap at the
## tenth dog (the taps), did they take the risky span (the long spans), did the verbs have a curve
## (the ratings). Shown plainly, as facts about their climb, with no score attached — a score would
## turn a climb into a grade.
func _draw_top() -> void:
	var s: Dictionary = player.top_summary
	var age: float = player._now - player.top_since
	var a := clampf((age - 1.5) / 1.5, 0.0, 1.0)   # after the camera has had its moment
	if a <= 0.0 or s.is_empty():
		return
	var y := size.y * 0.16
	_centre("The top.", y, Color(0.97, 0.95, 0.90, 0.95 * a), 34)
	var mins := int(float(s["seconds"])) / 60
	var secs := int(float(s["seconds"])) % 60
	_centre("%.0f m   ·   %d:%02d" % [float(s["height"]), mins, secs], y + 36.0,
		Color(0.90, 0.88, 0.84, 0.85 * a), 16)
	var b := clampf((age - 3.0) / 1.5, 0.0, 1.0)
	var lines := [
		"%d dogs — %d sound, %d fair, %d poor%s" % [s["dogs"], s["sound"], s["fair"], s["poor"],
			(", %d bent" % s["bent"]) if int(s["bent"]) > 0 else ""],
		"%d joints sounded   ·   %d long span%s taken" % [s["taps"], s["long_spans"],
			"" if int(s["long_spans"]) == 1 else "s"],
		"%d sections   ·   %d quick hitch%s" % [s["sections"], s["hitches"],
			"" if int(s["hitches"]) == 1 else "es"],
	]
	for i in lines.size():
		_centre(lines[i], y + 76.0 + 22.0 * i, Color(0.86, 0.84, 0.80, 0.8 * b), 14)
	_centre("[S] back over the edge   ·   [V] look at the view", y + 160.0,
		Color(0.78, 0.76, 0.72, 0.6 * b), 13)


## The stack's warnings. The fairness table: "Ladder buckled — fair, because the span was over 8 m
## and the HUD said so." So the HUD says so, loudly, for the whole of the 8 seconds, with the time
## left as a bar that empties — and says the one thing to do about it.
func _draw_stack_warnings() -> void:
	var st: Dictionary = player.stack_info
	if st.is_empty():
		return
	if st.get("buckling", false):
		var left: float = st.get("buckle_left", 0.0)
		var limit: float = player.jack.tuning_f("buckleSecondsUnderLoad", 8.0)
		var t := float(Time.get_ticks_msec()) / 1000.0
		var pulse := 0.65 + 0.35 * sin(t * (8.0 + 10.0 * (1.0 - left / limit)))
		var y := size.y * 0.22
		_centre("THIS SECTION IS BOWING", y, Color(0.98, 0.42, 0.30, pulse), 26)
		_centre("%.1f s — get off it, up or down" % left, y + 28.0, Color(0.96, 0.90, 0.84, 0.92), 16)
		var w := 320.0
		var at := Vector2((size.x - w) * 0.5, y + 44.0)
		draw_rect(Rect2(at, Vector2(w, 6)), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(at, Vector2(w * clampf(left / limit, 0.0, 1.0), 6)), Color(0.98, 0.42, 0.30, 0.9))

	# A quick hitch walking off its dog. Slow, and shown as distance so it reads as a fact about the
	# rope rather than as a timer.
	if int(st.get("lashing", 0)) == 1 and float(st.get("drift_cm", 0.0)) > 0.2:
		var drift: float = st["drift_cm"]
		var off: float = st.get("walk_off_cm", 15.0)
		var col := Color(0.92, 0.70, 0.35, 0.9) if drift < off * 0.7 else Color(0.98, 0.42, 0.30, 0.95)
		var hand := Vector2(HAND.x, size.y + HAND.y)
		_label("hitch walking — %.1f of %.0f cm" % [drift, off],
			Vector2(HAND.x + NERVE_R + 26, hand.y + 62), col, 13)


## The fuse. 02-climbing-system.md: "On a cascade, the HUD flashes each anchor as it goes, bottom of
## screen, like a fuse burning." One mark per dog that pulled, lit in the order they went, so a
## cascade is something the player watches happen and can read back afterwards — which is the
## only way it can be fair.
func _draw_fuse() -> void:
	var fuse: Array = player.fuse
	if fuse.is_empty():
		return
	var now: float = player._now
	var last: float = float(fuse[fuse.size() - 1]["at"])
	if now - last > 6.0:
		return
	var n := fuse.size()
	var step := 34.0
	var y := size.y - 150.0
	var x0 := size.x * 0.5 - step * float(n - 1) * 0.5
	for i in n:
		var f: Dictionary = fuse[i]
		var lit: bool = now >= float(f["at"])
		var age: float = now - float(f["at"])
		var p := Vector2(x0 + step * i, y)
		if lit:
			var flare := clampf(1.0 - age / 0.5, 0.0, 1.0)
			draw_circle(p, 9.0 + 8.0 * flare, Color(0.98, 0.52, 0.22, 0.35 * flare))
			draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), Color(0.98, 0.42, 0.30, 0.95), 3.0)
			draw_line(p + Vector2(7, -7), p + Vector2(-7, 7), Color(0.98, 0.42, 0.30, 0.95), 3.0)
			_label("%.0f m" % float(f["height"]), p + Vector2(-14, 26), Color(0.92, 0.88, 0.84, 0.85), 12)
		else:
			draw_arc(p, 7.0, 0, TAU, 16, Color(0.9, 0.88, 0.84, 0.35), 1.5)
		if i < n - 1:
			draw_line(p + Vector2(10, 0), p + Vector2(step - 10, 0), Color(0.9, 0.88, 0.84, 0.25), 1.0)


## The swing meter — VERB-007. A pendulum the player can read at a glance: the rope hanging from
## a pivot at the current swing angle, the arc it is sweeping, and the foul marks either side. The
## amplitude arc is what matters — it shows how big the swing *is*, where the rope alone would read
## upright at the bottom of every swing, which is exactly when the player needs to know.
func _draw_haul() -> void:
	var h: Dictionary = player.haul
	if h.is_empty():
		return
	var foul: float = h.get("foul_at", 22.0)
	var amp: float = h.get("amplitude", 0.0)
	var ang: float = h.get("swing_deg", 0.0)
	var pivot := Vector2(size.x * 0.5, size.y * 0.16)
	var r := 110.0

	# Scale so the foul marks sit well out, not at the edge of a quarter circle.
	var k := 2.0
	var danger := clampf(amp / foul, 0.0, 1.0)
	var col := Color(0.86, 0.80, 0.62).lerp(Color(0.98, 0.42, 0.30), danger * danger)

	draw_arc(pivot, r, PI * 0.5 - deg_to_rad(foul * k), PI * 0.5 + deg_to_rad(foul * k), 32,
		Color(0.9, 0.88, 0.84, 0.18), 5.0)
	draw_arc(pivot, r, PI * 0.5 - deg_to_rad(amp * k), PI * 0.5 + deg_to_rad(amp * k), 32,
		Color(col.r, col.g, col.b, 0.7), 5.0)
	for sgn in [-1.0, 1.0]:
		var at: float = PI * 0.5 + sgn * deg_to_rad(foul * k)
		draw_line(pivot + Vector2(cos(at), sin(at)) * (r - 10), pivot + Vector2(cos(at), sin(at)) * (r + 10),
			Color(0.98, 0.42, 0.30, 0.9), 3.0)
	var rope_at: float = PI * 0.5 - deg_to_rad(ang * k)
	draw_line(pivot, pivot + Vector2(cos(rope_at), sin(rope_at)) * r, Color(0.95, 0.93, 0.88, 0.9), 2.0)
	draw_circle(pivot + Vector2(cos(rope_at), sin(rope_at)) * r, 7.0, Color(0.95, 0.93, 0.88, 0.95))
	draw_circle(pivot, 4.0, Color(0.95, 0.93, 0.88, 0.8))

	var below: float = player.gin_height - float(h.get("height", 0.0))
	_centre("load %.0f m below   ·   swing %.0f°, fouls at %.0f°" % [below, amp, foul],
		pivot.y + r + 26.0, Color(0.92, 0.90, 0.86, 0.9), 14)
	_centre("hold W to haul   ·   push the mouse against the swing   ·   G to let it go",
		pivot.y + r + 46.0, Color(0.80, 0.78, 0.74, 0.7), 13)


## Lashing — VERB-005.
##
## A ring you go round, with the rope going on as you do. Six notches for six turns, with the hitch
## and the full lashing marked, because the whole decision is "three and go, or six and trust it" and
## the player cannot make it without seeing both. Tension is a second, thinner ring outside that
## visibly bleeds away the moment they stop — which is the thing that teaches them not to.
func _draw_lash(jack: Jack) -> void:
	var st: Dictionary = jack.lash_state()
	var wraps: int = st["wraps"]
	var laid: float = st["laid"]
	var tension: float = st["tension"]
	var hitch := int(jack.tuning_f("lashWrapsQuickHitch", 3))
	var full := int(jack.tuning_f("lashWrapsFull", 6))

	var c := Vector2(size.x * 0.5, size.y * 0.40)
	var r := 64.0

	# The turn in progress, filling round the ring, from the top, the way a clock hand goes.
	draw_arc(c, r, 0, TAU, 64, Color(0.9, 0.88, 0.84, 0.18), 6.0)
	if laid > 0.0:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * laid, 48, Color(0.86, 0.72, 0.46, 0.95), 6.0)

	# Tension, outside it. Bleeds away when you stop, and you can watch it go.
	draw_arc(c, r + 14.0, -PI * 0.5, -PI * 0.5 + TAU * tension, 48,
		Color(0.66, 0.78, 0.90, 0.55 + 0.4 * tension), 3.0)

	# The count, and what it buys.
	_centre("%d" % wraps, c.y + 12.0, Color(0.97, 0.95, 0.90, 0.95), 38)
	var what := "not enough to hold"
	if wraps >= full:
		what = "full lashing"
	elif wraps >= hitch:
		what = "quick hitch — it will walk"
	_centre(what, c.y + r + 42.0, Color(0.92, 0.88, 0.82, 0.88), 15)

	# Notches for each turn, with the hitch and the full lashing marked out from the rest.
	var y := c.y + r + 62.0
	var step := 22.0
	var x0 := c.x - step * float(full - 1) * 0.5
	for k in full:
		var p := Vector2(x0 + step * k, y)
		var done := k < wraps
		var col := Color(0.86, 0.72, 0.46, 0.95) if done else Color(0.9, 0.88, 0.84, 0.30)
		var rr := 6.0 if (k + 1 == hitch or k + 1 == full) else 4.0
		if done:
			draw_circle(p, rr, col)
		else:
			draw_arc(p, rr, 0, TAU, 16, col, 1.5)

	var method: String = player.LASH_METHODS[player.lash_method]
	var how := "hold LMB and go round" if method == "rotate" else (
		"tap LMB" if method == "mash" else "hold LMB")
	_centre("%s   ·   [R] tie off   ·   [RMB] let go   ·   [L] %s" % [how, method],
		y + 26.0, Color(0.80, 0.78, 0.74, 0.75), 13)
	if tension < jack.tuning_f("lashTieOffMinTension", 0.45) and wraps >= hitch:
		_centre("the rope is going slack — tie off now and the knot will slip", y + 46.0,
			Color(0.95, 0.62, 0.40, 0.9), 13)


## Rigging a stance. Twenty seconds into a bosun's chair is a long time to stare at nothing.
##
## The bar says how long is left; the line under it says what it is buying. Both matter: the player
## is spending grip *now* against a drain they will pay *later*, and a countdown with no stake
## attached is just a wait.
func _draw_rig(jack: Jack) -> void:
	var eye := Vector2(size.x * 0.5, size.y * 0.42)
	var done: float = 1.0 - (player.rig_left / maxf(player.rig_total, 0.01))

	var w := 260.0
	var at := Vector2(eye.x - w * 0.5, eye.y)
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(w + 2, 10)), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(at, Vector2(w * done, 8)), Color(0.82, 0.74, 0.48, 0.95))

	_centre("rigging — %s" % jack.stance_name_of(player.rigging_to), eye.y - 26.0,
		Color(0.94, 0.91, 0.86, 0.92), 18)
	_centre("%.1f s" % player.rig_left, eye.y + 26.0, Color(0.88, 0.85, 0.80, 0.85), 15)

	var from_rate: float = jack.stance_drain_rate(jack.get_stance())
	var to_rate: float = jack.stance_drain_rate(player.rigging_to)
	_centre("%.0f grip a second becomes %.0f" % [from_rate, to_rate], eye.y + 48.0,
		Color(0.80, 0.78, 0.74, 0.75), 13)
	_centre("[Q] to stop", eye.y + 70.0, Color(0.72, 0.70, 0.67, 0.65), 13)


## The gust, arriving. 1.2 seconds, and then it hits your hands.
##
## Drawn along the top edge rather than in the middle, because the player is usually looking at a
## joint and a reticle when it starts and must not have either covered up. It closes inwards from
## both sides, so it reads as something converging on you and gives the remaining time as a length
## rather than as a number nobody will read in a second.
func _draw_gust_tell(jack: Jack) -> void:
	var p: float = jack.gust_tell_progress()
	var col := Color(0.62, 0.74, 0.86, 0.45 + 0.55 * p)

	var margin := 40.0
	var span: float = (size.x * 0.5 - margin) * (1.0 - p)
	var y := 26.0
	draw_line(Vector2(margin, y), Vector2(margin + span, y), col, 3.0 + 3.0 * p)
	draw_line(Vector2(size.x - margin, y), Vector2(size.x - margin - span, y), col, 3.0 + 3.0 * p)

	_centre("gust", y + 16.0, Color(0.88, 0.92, 0.96, 0.5 + 0.5 * p), 16)


## The slip.
##
## A ring that closes, a word, and the key. Three things and no colour dependency between them: the
## ring shrinking is the timer, and someone who cannot tell the red from the gold can still see it
## going. Per docs/01-gdd/14-accessibility.md, nothing here may be the only channel a cue arrives on.
func _draw_slip(jack: Jack) -> void:
	var left: float = jack.slip_window_left()
	var eye := Vector2(size.x * 0.5, size.y * 0.42)

	# Everything else dims. This is not decoration — it is what makes a 900 ms window findable on a
	# screen that also has a chimney, a stack, two meters and five affordances on it.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.02, 0.45 * (1.0 - left * 0.4)))

	var r := 96.0
	draw_arc(eye, r, 0, TAU, 72, Color(0.9, 0.88, 0.85, 0.25), 3.0)
	# Closing clockwise from the top, so "running out" reads the way a clock does.
	draw_arc(eye, r, -PI * 0.5, -PI * 0.5 + TAU * left, 72, Color(0.95, 0.31, 0.22, 0.95), 9.0)

	# And it closes inwards as well as round, so the shape alone carries the time.
	draw_arc(eye, r * (0.25 + 0.55 * left), 0, TAU, 48, Color(0.95, 0.31, 0.22, 0.55), 3.0)

	_centre("GRAB", eye.y - 8.0, Color(0.98, 0.95, 0.90, 0.95), 46)
	_centre("SPACE", eye.y + 34.0, Color(0.95, 0.92, 0.88, 0.88), 20)

	# Why this is happening, in three words, while it happens. Afterwards is too late to learn it.
	_centre("your grip went", eye.y + r + 34.0, Color(0.90, 0.86, 0.82, 0.80), 15)

	# And whether there was ever anything to grab at. A window that is already spent looks exactly
	# like one you missed, unless it says so.
	if not jack.can_slip_save():
		_centre("nothing left to catch with", eye.y + r + 56.0, Color(0.95, 0.45, 0.35, 0.85), 14)


# --- drawing helpers ----------------------------------------------------------------------------

func _arc(centre: Vector2, radius: float, fraction: float, width: float, col: Color) -> void:
	if fraction <= 0.0 or col.a <= 0.01:
		return
	# Opening away from the centre of the screen, so the arcs frame the hand rather than point at
	# the action.
	var start := deg_to_rad(128.0)
	var sweep := deg_to_rad(244.0) * clampf(fraction, 0.0, 1.0)
	draw_arc(centre, radius, -start, -start + sweep, 48, col, width)


func _label(text: String, at: Vector2, col: Color, px: int = 15) -> void:
	if col.a <= 0.01:
		return
	# A shadow rather than a panel: legible against sky without putting a box between the player
	# and the thing they climbed up to see.
	draw_string(_font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0, 0, 0, col.a * 0.6))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _centre(text: String, y: float, col: Color, px: int = 15) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_label(text, Vector2((size.x - w) * 0.5, y), col, px)


func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
