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
	_label("%.0f m" % player.height_m(), Vector2(info_x, hand.y - 20), Color(0.94, 0.92, 0.88, 0.92))
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
	if player.span_warning != "" and jack.anchor_count() > 0:
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

	if player.rigging_to >= 0:
		_draw_rig(jack)

	# Over everything, because for 900 ms nothing else on this screen matters.
	if player.jack.slip_in_progress():
		_draw_slip(jack)

	# There is no objective marker because the objective is the top and you can see it. But you
	# cannot see the *rule*, so it is said once and then never again.
	if player._now < 14.0:
		_centre("Climb the stack. You can only go as high as you have built.",
			size.y * 0.14, Color(0.92, 0.90, 0.86, 0.85 * _ease((14.0 - player._now) / 3.0)))


func _next_step() -> String:
	if player.jack.slip_in_progress():
		return ""
	if player.rigging_to >= 0:
		return ""
	if player.fall_reason != "":
		return "Your stack is still up. Climb it again."
	if player.work_mode:
		return "Line the dog up, then hold the left button to draw — release to strike."
	if player.at_cradle() and (not player.carrying_ladder or player.dogs_carried == 0):
		return "Take a ladder and fill the dog bag.  [F]"
	if not player.on_ladder:
		return "Walk to the foot of the stack and climb on."
	if player.has_lashable_anchor() and player.carrying_ladder:
		return "Lash the ladder to that dog, then climb it.  [R]"
	if player.has_lashable_anchor() and not player.carrying_ladder:
		return "Nothing to lash — climb down to the cradle for a ladder."
	if player.dogs_carried == 0:
		return "Bag is empty. Climb down to the cradle for more dogs."
	if player.tap_pip < 0 or absf(player.tapped_at - player.global_position.y) >= 1.5:
		return "Sound the brickwork to hear what the joint is worth.  [E]"
	return "Drive a dog into that joint.  [right mouse]"


## [key, verb, available, why-not]
func _affordances() -> Array:
	if player.jack.slip_in_progress():
		return [["SPACE", "grab", true, ""]]
	if player.rigging_to >= 0:
		return [[Q_KEY, "stop rigging", true, ""]]
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
	var tapped: bool = player.tap_pip >= 0 and absf(player.tapped_at - player.height_m()) < 1.5
	return [
		["W/S", "climb", true, ""],
		["E", "sound the brickwork", true, ""],
		["RMB", "dog in", tapped and player.dogs_carried > 0,
			"sound the joint first" if not tapped else "no dogs left"],
		["R", "lash the next ladder", player.has_lashable_anchor() and player.carrying_ladder,
			"you are not carrying one" if not player.carrying_ladder else "needs a dog seated above you"],
		[Q_KEY, _next_stance_label(), true, ""],
	]


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
	var eye := Vector2(size.x * 0.5, size.y * 0.44)
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
