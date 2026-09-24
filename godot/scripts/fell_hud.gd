## The felling HUD — FELL-003.
##
## A felling is a bet you cannot take back, so the whole job of this thing is to make sure the
## player knows what they are betting before they light it. Three panels:
##
##   * **The plan**, bottom right. The ring seen from above, drawn from the sim's own support
##     polygon rather than from a drawing of its own that agrees with it by luck: the brick that is
##     left, the props and how hard they are working, where the weight actually is, the pegged fall
##     line, the predicted one with its cone, and the debris fan over the neighbours.
##   * **The state**, top left. What step you are on and what the chimney thinks of it.
##   * **What you are pointing at**, middle. Because "press E to work" is a rejected PR.
##
## Every colour here has a word beside it and every audio cue a mark on the plan, per rules 7 and 8.
extends Control

const STEPS := [
	"Strip her out first — bands off, conductor down. That is a climb, from the board",
	"Walk round and read the lean with the plumb bob [B] — twice, from well apart",
	"Cut the gob on the fall line — hold the chimney's own lean in mind",
	"Prop behind you as you go — the prop goes in BEFORE the last course comes out",
	"Watch the margin. Finish UNEASY, not SAFE — safe does not fall",
	"Drive two pegs down the line you want [P]",
	"Pack the gob — hold [F] — then light it [L] and RUN",
]

## What a felling costs you in daylight, and the one thing you can spend it on for accuracy.
const TRADE := "[ ] and [ ] take metres off the top: tighter cone, less of your day"

const PLAN_SIZE := 250.0      ## the site plan: the fan, the neighbours, the line
const GOB_SIZE := 250.0       ## the gob detail: the ring itself, which is 6 m across
const PLAN_MARGIN := 20.0

const BAND_COLOUR := {
	"SAFE": Color(0.55, 0.78, 0.50),
	"UNEASY": Color(0.92, 0.80, 0.35),
	"CRITICAL": Color(0.95, 0.52, 0.22),
	"COLLAPSE": Color(0.92, 0.26, 0.22),
}
const BAND_WORDS := {
	"SAFE": "standing easy — it will not fall like this",
	"UNEASY": "working, and that is where you want it",
	"CRITICAL": "moving. Get out of the hole",
	"COLLAPSE": "going. Now.",
}

const INK := Color(0.93, 0.91, 0.87)
const DIM := Color(0.93, 0.91, 0.87, 0.55)
const BRICK := Color(0.52, 0.40, 0.33)
const TIMBER := Color(0.78, 0.62, 0.34)
const TIMBER_HOT := Color(0.90, 0.42, 0.18)
const HULL := Color(0.45, 0.62, 0.82, 0.30)
const WEIGHT := Color(0.98, 0.95, 0.60)
const PEGS := Color(0.60, 0.85, 0.95)
const FAN := Color(0.95, 0.52, 0.22, 0.16)
const HAZARD := Color(0.95, 0.35, 0.30)

var jack: Jack
var ring: GobRing
var state := {}
var prediction := {}
var outcome := {}
var settlement := {}
var went_early := false
var peg_bearing := 0.0
var height_removed := 0.0
var aim_seg := -1
var aim_course := -1
var aim_verb := ""
var message := ""
var message_until := 0.0
var step := 0
var surveyed := false
var sightings := 0
var pegs := 0
var standing_at := Vector2.ZERO
var level_name := ""
var shift := {}
var act4 := 0
var packing := 0.0
var burn_left := 0.0
var safe_line := 0.0
var range_out := 0.0
var caught := false
var stripped := false
var work_progress := 0.0
var timetable := {}
var train_line := ""

var _font: Font
var _plan_scale := 1.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_process(true)


func _process(_dt: float) -> void:
	queue_redraw()


func say(text: String, seconds: float = 3.0) -> void:
	message = text
	message_until = Time.get_ticks_msec() / 1000.0 + seconds


func _draw() -> void:
	if jack == null:
		return
	_draw_steps()
	_draw_state()
	_draw_aim()
	_draw_act4()
	_draw_plan()
	_draw_message()
	if not outcome.is_empty():
		_draw_verdict()


# ---------------------------------------------------------------- panels

## Where the step list ends and the state panel starts. Derived rather than written down: the list
## grew by one when Act 4 landed and the hard-coded divider ended up through the middle of it.
func _state_top() -> float:
	return 50.0 + 19.0 * float(STEPS.size()) + 16.0


## How tall the state block is, from the same conditionals that draw it.
##
## Worked out rather than guessed because the panel used to be one fixed 620 by 500 slab covering
## the checklist, the margin, the clock and the line all at once — four different questions inside
## one black rectangle, which is the definition of a wall of text. Two plates sized to what is on
## them reads as two things.
func _state_height() -> float:
	if state.is_empty():
		return 0.0
	var h := 24.0 + 30.0 + 20.0                  # status, the big margin, gob and props
	if int(state.get("props_split", 0)) > 0:
		h += 19.0
	h += 26.0 + 19.0                             # the lean, the pegs
	if not timetable.is_empty():
		h += 22.0
	if not shift.is_empty():
		h += 22.0 + 26.0                         # the clock, its bar, the trade note
	if not prediction.is_empty():
		h += 32.0 + 18.0
		if not (prediction.get("threatened", []) as Array).is_empty():
			h += 19.0
	return h + 22.0


## The width both plates take: the longest line on either of them, and no more. It was a flat 620,
## which is a third of the screen held open for a panel whose longest row is four hundred.
func _panel_width() -> float:
	var w := _font.get_string_size("FELLING — %s" % level_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	for step in STEPS:
		w = maxf(w, _font.get_string_size("x %s" % step, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
	return w + 48.0


func _draw_steps() -> void:
	# A scrim. The first render of this put pale text straight onto a bright sky and half of it
	# could not be read, which for a panel whose whole job is telling you what to do is fatal.
	var w := _panel_width()
	draw_rect(Rect2(0, 0, w, _state_top() - 10.0), Color(0.05, 0.05, 0.06, 0.55))
	var below := _state_height()
	if below > 0.0:
		draw_rect(Rect2(0, _state_top() + 4.0, w, below), Color(0.05, 0.05, 0.06, 0.55))
	# The weight on the top edge, like every other panel in the game. This is the climax screen and
	# it was the one that still looked like a different game's.
	draw_rect(Rect2(0, 0, w, 2), Color(0.86, 0.72, 0.36, 0.55))
	var y := 26.0
	draw_string(_font, Vector2(24, y), "FELLING — %s" % level_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
	y += 24.0
	for i in STEPS.size():
		var done := i < step or (i == 0 and stripped)
		var here := i == step
		var colour := INK if here else (DIM if not done else Color(0.55, 0.78, 0.50, 0.7))
		# The same three marks the climbing checklist uses, which are the same three a jack chalks
		# on a joint: a tick for done, an arrow for the one in hand, a dot for not yet. This screen
		# used "x" for done, which everywhere else in this game — and on every chimney in it —
		# means the opposite.
		var mark := "✓" if done and not here else ("▶" if here else "·")
		draw_string(_font, Vector2(24, y), "%s  " % mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)
		# The keys in these lines were written as "[B]", "[P]", "[hold F]" — bare letters in
		# brackets, on the climax screen of a game whose control list has drawn keys as keys for a
		# day. `Keycap.inline` renders the sentence with its keys turned into keys wherever they
		# fall in it, and leaves the words alone.
		Keycap.inline(self, _font, String(STEPS[i]), Vector2(44, y), colour, 13)
		y += 19.0


func _draw_state() -> void:
	if state.is_empty():
		return
	var name_ := String(state.get("status_name", "SAFE"))
	var colour: Color = BAND_COLOUR.get(name_, INK)
	var y := _state_top()
	draw_rect(Rect2(24, y + 10.0, _panel_width() - 48.0, 3), colour)
	y += 34.0
	draw_string(_font, Vector2(24, y), "%s — %s" % [name_, BAND_WORDS.get(name_, "")],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, colour)
	# The margin, big, because it is the number that decides whether she stands up while you are
	# still cutting. It was thirteen pixels in the middle of a sentence with the prop count, which
	# is the same fault the climbing HUD had: everything the same size means nothing is important.
	y += 30.0
	var margin: float = float(state.get("margin", 0.0))
	draw_string(_font, Vector2(24, y), "%+.2f" % margin, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, colour)
	var mw: float = _font.get_string_size("%+.2f" % margin, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	draw_string(_font, Vector2(24 + mw + 8, y), "m of margin", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(colour, 0.75))
	y += 20.0
	draw_string(_font, Vector2(24, y),
		"gob %.0f° on %03d°    props %d left, %d standing" % [
			float(state.get("cut_arc", 0.0)),
			int(state.get("cut_centre", 0.0)), int(state.get("props_left", 0)),
			int(state.get("props_standing", 0))],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
	var split := int(state.get("props_split", 0))
	if split > 0:
		y += 19.0
		draw_string(_font, Vector2(24, y), "%d prop%s split" % [split, "" if split == 1 else "s"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, HAZARD)

	y += 26.0
	if surveyed:
		draw_string(_font, Vector2(24, y), "lean surveyed — two plumb readings taken",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.78, 0.50))
	else:
		draw_string(_font, Vector2(24, y),
			"lean NOT surveyed (%d reading%s) — the cone is wider for it" % [
				sightings, "" if sightings == 1 else "s"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.52, 0.22))
	y += 19.0
	draw_string(_font, Vector2(24, y), "%d of 2 pegs in" % pegs, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		PEGS if pegs >= 2 else DIM)

	# The line, if you walked out and read the board. If you did not, there is nothing here and
	# the game never mentions it — which is the design's instruction, word for word.
	if not timetable.is_empty():
		y += 22.0
		var due: bool = bool(timetable.get("train_due", false))
		draw_string(_font, Vector2(24, y),
			"%s: next train about %d min%s" % [train_line.replace("_", " "),
				int(float(timetable.get("minutes_until", 0.0))),
				"  — ONE IS DUE WHILE SHE COMES DOWN" if due else ""],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, HAZARD if due else DIM)

	if not shift.is_empty():
		y += 22.0
		var left: float = float(shift.get("left", 0.0))
		var whole: float = maxf(float(shift.get("shift", 1.0)), 1.0)
		var clock := INK if left > whole * 0.25 else Color(0.95, 0.52, 0.22)
		draw_string(_font, Vector2(24, y),
			"daylight %d min left of %d    %.0f m off the top" % [
				int(left / 60.0), int(whole / 60.0), height_removed],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, clock)
		# The bar, because a number counting down is not a feeling and a bar emptying is.
		draw_rect(Rect2(24, y + 8, 320.0, 4), Color(0.25, 0.24, 0.23))
		draw_rect(Rect2(24, y + 8, 320.0 * clampf(left / whole, 0.0, 1.0), 4), clock)
		# Clear of the bar. At +16 the note was drawn straight through it.
		y += 26.0
		draw_string(_font, Vector2(24, y), TRADE, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)

	if not prediction.is_empty():
		# And the other number the whole job is scored on: how far off your own line she will go.
		# The prediction and the pegs stay small; the error between them is the answer.
		y += 32.0
		var err: float = float(prediction.get("error", 0.0))
		var acc: float = float(prediction.get("accuracy", 0.0))
		var ecol := Color(0.55, 0.78, 0.50) if err <= acc * 0.5 else (
			PEGS if err <= acc else HAZARD)
		draw_string(_font, Vector2(24, y), "%.1f°" % err, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ecol)
		var ew: float = _font.get_string_size("%.1f°" % err, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		draw_string(_font, Vector2(24 + ew + 8, y), "off the line you pegged",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ecol, 0.75))
		y += 18.0
		draw_string(_font, Vector2(24, y),
			"predicted %03d° ±%.1f°    pegged %03d°" % [
				int(prediction.get("fall_bearing", 0.0)), acc, int(peg_bearing)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, PEGS)
		var threatened: Array = prediction.get("threatened", [])
		if not threatened.is_empty():
			y += 19.0
			draw_string(_font, Vector2(24, y), "in the fan: %s" % ", ".join(threatened),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, HAZARD)


func _draw_aim() -> void:
	var c := size * 0.5
	draw_line(c - Vector2(7, 0), c + Vector2(7, 0), DIM, 1.0)
	draw_line(c - Vector2(0, 7), c + Vector2(0, 7), DIM, 1.0)
	# The bite you have on the cell you are working. A ring, at the crosshair, because that is
	# where you are looking and you cannot look anywhere else without losing it.
	if work_progress > 0.0:
		var steps := 28
		var arc: float = TAU * clampf(work_progress, 0.0, 1.0)
		for i in steps:
			var a0: float = -PI * 0.5 + arc * float(i) / float(steps)
			var a1: float = -PI * 0.5 + arc * float(i + 1) / float(steps)
			draw_line(c + Vector2(cos(a0), sin(a0)) * 20.0,
				c + Vector2(cos(a1), sin(a1)) * 20.0, TIMBER, 3.0)
	if aim_verb == "" or going:
		return
	draw_multiline_string(_font, Vector2(c.x - 230, c.y + 34), aim_verb,
		HORIZONTAL_ALIGNMENT_CENTER, 460, 14, -1, INK)


func _draw_message() -> void:
	if message == "" or Time.get_ticks_msec() / 1000.0 > message_until:
		return
	# Out of the way of the run panel, which is the only thing that matters while it is up.
	var y: float = size.y - (232.0 if act4 == BURNING else 120.0)
	# `draw_string` does not wrap — it *clips*. The width argument is a cut, not a margin, so the
	# opening line of a felling ("Take the job from the board and climb her first") arrived on
	# screen as "...Take the job fro" and stopped. A truncated sentence is not a rough edge, it is
	# an instruction the player cannot follow.
	const WIDE := 760.0
	var lines: int = _font.get_multiline_string_size(message, HORIZONTAL_ALIGNMENT_CENTER, WIDE,
		16).y > 22.0 and 2 or 1
	var plate := Rect2(Vector2(size.x * 0.5 - WIDE * 0.5 - 16.0, y - 26.0),
		Vector2(WIDE + 32.0, 14.0 + 22.0 * float(lines) + 10.0))
	draw_rect(plate, Color(0.05, 0.05, 0.06, 0.55))
	draw_multiline_string(_font, Vector2(size.x * 0.5 - WIDE * 0.5, y), message,
		HORIZONTAL_ALIGNMENT_CENTER, WIDE, 16, -1, INK)


# ---------------------------------------------------------------- Act 4
#
# Pack, light, run. The burn is the timer and the safe line is the finish, and both have to be on
# the screen while you are sprinting away from a chimney with your back to it.

const PACKING := 1
const MATCH := 2
const BURNING := 3


## True from the moment she starts moving. Everything that offers you a *choice* goes off the
## screen then — you have made all of them, and what is left is watching.
var going := false

func _draw_act4() -> void:
	# Nothing to strike once she is already going. A frame taken mid-collapse had
	# "[L] strike a match" printed over "she's broken at 38 m", over the line about shielding the
	# match from the wind: three messages in one place, two of them about a decision that is
	# thirty metres of falling brickwork too late.
	if going:
		return
	var c := Vector2(size.x * 0.5, size.y - 150.0)
	if act4 == PACKING:
		draw_string(_font, Vector2(c.x - 220, c.y), "packing the gob — hold F",
			HORIZONTAL_ALIGNMENT_CENTER, 440, 16, INK)
		draw_rect(Rect2(c.x - 160, c.y + 12, 320, 8), Color(0.2, 0.19, 0.18))
		draw_rect(Rect2(c.x - 160, c.y + 12, 320 * clampf(packing, 0.0, 1.0), 8), TIMBER)
		draw_string(_font, Vector2(c.x - 220, c.y + 42),
			"a full gob burns fast and clean; a light one smoulders, and it costs you the fall",
			HORIZONTAL_ALIGNMENT_CENTER, 440, 12, DIM)
	elif act4 == MATCH:
		draw_string(_font, Vector2(c.x - 260, c.y), "[L] strike a match",
			HORIZONTAL_ALIGNMENT_CENTER, 520, 18, INK)
		draw_string(_font, Vector2(c.x - 260, c.y + 26),
			"the wind will have it unless you put yourself between",
			HORIZONTAL_ALIGNMENT_CENTER, 520, 13, DIM)
	elif act4 == BURNING:
		# The two numbers that matter, large, because you are running.
		var clear: bool = range_out >= safe_line
		var colour := Color(0.55, 0.85, 0.50) if clear else HAZARD
		draw_string(_font, Vector2(c.x - 300, c.y - 30), "RUN",
			HORIZONTAL_ALIGNMENT_CENTER, 600, 40, HAZARD)
		draw_string(_font, Vector2(c.x - 300, c.y + 6),
			"%0.0f s        %0.0f m of %0.0f" % [maxf(burn_left, 0.0), range_out, safe_line],
			HORIZONTAL_ALIGNMENT_CENTER, 600, 22, colour)
		draw_string(_font, Vector2(c.x - 300, c.y + 34),
			"behind the line" if clear else "still inside the line",
			HORIZONTAL_ALIGNMENT_CENTER, 600, 14, colour)
	if caught and not outcome.is_empty():
		draw_string(_font, Vector2(size.x * 0.5 - 340, 320), "YOU WERE INSIDE THE LINE",
			HORIZONTAL_ALIGNMENT_CENTER, 680, 26, HAZARD)


# ---------------------------------------------------------------- the two plans
#
# Two panels, because they are two scales. The site is eighty metres across and the gob is six, and
# one drawing that fits the fan makes the ring four pixels wide — which is what the first render of
# this HUD did, and it made the thing you spend twenty minutes on invisible.

func _site_origin() -> Vector2:
	return Vector2(size.x - PLAN_MARGIN - PLAN_SIZE * 0.5, size.y - PLAN_MARGIN - PLAN_SIZE * 0.5)


func _gob_origin() -> Vector2:
	return _site_origin() - Vector2(0.0, PLAN_SIZE * 0.5 + 10.0 + GOB_SIZE * 0.5)


## Metres to pixels about a panel's centre. North is up and bearings run clockwise, which is what
## the sim means and what a compass means.
func _at(origin: Vector2, v: Vector2, scale: float) -> Vector2:
	return origin + Vector2(v.x, -v.y) * scale


func _on_bearing(bearing_deg: float, metres: float) -> Vector2:
	var b := deg_to_rad(bearing_deg)
	return Vector2(sin(b) * metres, cos(b) * metres)


func _panel(origin: Vector2, side: float, title: String) -> void:
	draw_rect(Rect2(origin - Vector2(side, side) * 0.5, Vector2(side, side)),
		Color(0.05, 0.05, 0.06, 0.78))
	draw_string(_font, origin + Vector2(-side * 0.5 + 8, -side * 0.5 + 17), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
	draw_string(_font, origin + Vector2(side * 0.5 - 16, -side * 0.5 + 17), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)


func _draw_plan() -> void:
	if state.is_empty():
		return
	_draw_site()
	_draw_gob()


func _exclusions() -> Array:
	return get_meta("exclusions", []) as Array


# ---------------------------------------------------------------- the site

func _draw_site() -> void:
	var o := _site_origin()
	var radius := float(state.get("base_radius", 3.2))
	var reach: float = maxf(float(prediction.get("debris_length", 0.0)), 40.0)
	for e in _exclusions():
		reach = maxf(reach, float(e.get("distance", 0.0)) * 1.1)
	var scale: float = (PLAN_SIZE * 0.5 - 14.0) / maxf(reach, 1.0)
	_panel(o, PLAN_SIZE, "the site — %d m across" % int(reach * 2.0))

	# The fan first, so everything else sits on top of it.
	if not prediction.is_empty():
		var bearing := float(prediction.get("fall_bearing", 0.0))
		var half := float(prediction.get("debris_half_angle", 18.0))
		var length := float(prediction.get("debris_length", 0.0))
		var pts := PackedVector2Array([_at(o, Vector2.ZERO, scale)])
		for i in 17:
			pts.push_back(_at(o, _on_bearing(bearing - half + 2.0 * half * float(i) / 16.0, length), scale))
		draw_colored_polygon(pts, FAN)
		# The far edge, because "getting the length right matters as much as the bearing".
		for i in 16:
			draw_line(_at(o, _on_bearing(bearing - half + 2.0 * half * float(i) / 16.0, length), scale),
				_at(o, _on_bearing(bearing - half + 2.0 * half * float(i + 1) / 16.0, length), scale),
				Color(0.95, 0.52, 0.22, 0.6), 1.5)

	var threatened: Array = prediction.get("threatened", [])
	for e in _exclusions():
		var p := _at(o, _on_bearing(float(e.get("bearing", 0.0)), float(e.get("distance", 0.0))), scale)
		var hit: bool = String(e.get("id", "")) in threatened
		var colour := HAZARD if hit else DIM
		draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), colour, not hit)
		var label := String(e.get("id", "")).replace("_", " ")
		if bool(e.get("catastrophic", false)):
			label += " (!)"
		draw_string(_font, p + Vector2(7, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, colour)

	# The pegs, the prediction, and the cone between them.
	draw_line(_at(o, Vector2.ZERO, scale), _at(o, _on_bearing(peg_bearing, reach), scale), PEGS, 1.5)
	draw_string(_font, _at(o, _on_bearing(peg_bearing, reach * 0.88), scale) + Vector2(3, -4),
		"pegs", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, PEGS)
	if not prediction.is_empty():
		var bearing := float(prediction.get("fall_bearing", 0.0))
		var acc := float(prediction.get("accuracy", 0.0))
		draw_line(_at(o, Vector2.ZERO, scale), _at(o, _on_bearing(bearing, reach * 0.9), scale),
			Color(0.95, 0.82, 0.35), 2.0)
		for edge in [bearing - acc, bearing + acc]:
			draw_line(_at(o, Vector2.ZERO, scale), _at(o, _on_bearing(edge, reach * 0.9), scale),
				Color(0.95, 0.82, 0.35, 0.5), 1.0)

	# The line you have to be behind, and where you are relative to it.
	if safe_line > 0.0:
		var ring := PackedVector2Array()
		for i in 49:
			ring.push_back(_at(o, _on_bearing(360.0 * float(i) / 48.0, safe_line), scale))
		for i in 48:
			draw_line(ring[i], ring[i + 1], Color(0.92, 0.84, 0.40, 0.45), 1.0)

	# The chimney, to scale, so the fan has something to come out of.
	draw_circle(_at(o, Vector2.ZERO, scale), maxf(radius * scale, 2.0), Color(0.52, 0.40, 0.33))
	# And you, because a survey you walk needs you on the map.
	var me := _at(o, standing_at, scale)
	draw_circle(me, 3.0, INK)
	draw_string(_font, me + Vector2(5, -4), "you", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DIM)


# ---------------------------------------------------------------- the gob

func _draw_gob() -> void:
	if jack == null or ring == null:
		return
	var o := _gob_origin()
	var radius := float(state.get("base_radius", 3.2))
	var scale: float = (GOB_SIZE * 0.5 - 30.0) / maxf(radius, 0.5)
	_panel(o, GOB_SIZE, "the gob — %.1f m across" % (radius * 2.0))

	# The polygon the margin is actually measured against, straight from the sim.
	var hull: PackedVector2Array = state.get("support_hull", PackedVector2Array())
	if hull.size() >= 3:
		var pts := PackedVector2Array()
		for v in hull:
			pts.push_back(_at(o, v, scale))
		draw_colored_polygon(pts, HULL)
		for i in pts.size():
			draw_line(pts[i], pts[(i + 1) % pts.size()], Color(0.55, 0.72, 0.92, 0.8), 1.5)

	var segments := int(state.get("segments", 32))
	var courses := int(state.get("courses", 4))
	var arc := 360.0 / float(segments)
	for seg in segments:
		var bearing := 360.0 * float(seg) / float(segments)
		var intact := 0
		for course in courses:
			if not bool(jack.gob_cell(seg, course).get("removed", false)):
				intact += 1
		var a := _at(o, _on_bearing(bearing - arc * 0.45, radius), scale)
		var b := _at(o, _on_bearing(bearing + arc * 0.45, radius), scale)
		if intact > 0:
			# Thickness says how much of the wall is left there — a segment part cut still bears.
			draw_line(a, b, BRICK, 2.0 + 5.0 * float(intact) / float(courses))
		else:
			draw_line(a, b, Color(0.22, 0.20, 0.19), 2.0)

		var p: Dictionary = jack.gob_prop_at(seg)
		if not bool(p.get("present", false)):
			continue
		var at := _at(o, _on_bearing(bearing, radius * 0.82), scale)
		if bool(p.get("split", false)):
			draw_line(at - Vector2(4, 4), at + Vector2(4, 4), HAZARD, 2.0)
			draw_line(at - Vector2(4, -4), at + Vector2(4, -4), HAZARD, 2.0)
		else:
			# Going orange is a prop near its capacity: the visual fallback for the groan (rule 8).
			draw_circle(at, 3.5, TIMBER_HOT.lerp(TIMBER, float(p.get("reserve", 1.0))))

	# Where the weight is, and where the fall line runs out of the hole.
	draw_line(_at(o, Vector2.ZERO, scale), _at(o, _on_bearing(peg_bearing, radius * 1.5), scale),
		Color(PEGS.r, PEGS.g, PEGS.b, 0.5), 1.0)
	if aim_seg >= 0:
		draw_circle(_at(o, _on_bearing(360.0 * float(aim_seg) / float(segments), radius * 1.22), scale),
			3.5, INK)
	var cog: Vector2 = state.get("cog", Vector2.ZERO)
	draw_circle(_at(o, cog, scale), 4.0, WEIGHT)
	draw_string(_font, _at(o, cog, scale) + Vector2(7, -5), "weight", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 10, WEIGHT)


# ---------------------------------------------------------------- the verdict

func _draw_verdict() -> void:
	var grade := "SHE WENT EARLY" if went_early else String(outcome.get("grade_name", "WILD"))
	var colour: Color = {
		"PERFECT": Color(0.55, 0.85, 0.50), "GOOD": Color(0.80, 0.85, 0.45),
		"ACCEPTABLE": Color(0.90, 0.78, 0.35), "WILD": HAZARD,
	}.get(grade, HAZARD if went_early else INK)
	var lines := _verdict_lines()

	# Sized from what it has to say, not from a number written down once. Three separate times
	# tonight a fixed height has been right when it was typed and wrong one edit later — the step
	# list, the state panel, and this, which ended up printing the money over its own footer.
	# Measured from what each line actually takes once it is wrapped, not from a line count.
	# "you hit: ..." grows with the number of things in the fan, and on a bad drop that is the
	# sentence the player most needs to read.
	const WIDE := 660.0
	var rows: Array = []
	var body := 0.0
	for line in lines:
		var tall: float = 22.0 if String(line) == "" else maxf(
			_font.get_multiline_string_size(String(line), HORIZONTAL_ALIGNMENT_CENTER,
				WIDE - 40.0, 15).y, 22.0)
		rows.append([String(line), tall])
		body += tall
	var high: float = 60.0 + body + 34.0
	var panel := Rect2(size.x * 0.5 - WIDE * 0.5, size.y - high - 36.0, WIDE, high)
	draw_rect(panel, Color(0.05, 0.05, 0.06, 0.88))

	var y := panel.position.y + 36.0
	draw_string(_font, Vector2(panel.position.x, y), grade, HORIZONTAL_ALIGNMENT_CENTER,
		panel.size.x, 26, colour)
	y += 34.0
	for row in rows:
		var line := String(row[0])
		draw_multiline_string(_font, Vector2(panel.position.x + 20.0, y), line,
			HORIZONTAL_ALIGNMENT_CENTER, WIDE - 40.0, 15, -1,
			INK if line.begins_with("fee") or line.begins_with("no fee") else DIM)
		y += float(row[1])
	draw_string(_font, Vector2(panel.position.x, panel.position.y + panel.size.y - 14),
		"enter — back to the board        R — the same chimney again",
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 12, DIM)


## What the job did, in the order you would want to hear it: where it went, how it broke, what it
## touched, what it paid, and only then what it cost you.
func _verdict_lines() -> Array:
	var lines := []
	if went_early:
		lines.append("you cut past her and she came down on her own, where the hole pointed")
	lines.append_array([
		"it went to %03d°, %.1f° off your pegs" % [
			float(outcome.get("fall_bearing", 0.0)), float(outcome.get("error", 0.0))],
		"broke into %d, %s" % [int(outcome.get("chunks", 1)),
			"she broke up nicely" if bool(outcome.get("clean_break", false))
				else "one piece, harder to clear"],
	])
	var struck: Array = outcome.get("struck", [])
	if struck.is_empty():
		lines.append("nothing in the fan was touched")
	else:
		lines.append("you hit: %s" % ", ".join(struck))
	if bool(outcome.get("catastrophe", false)):
		lines.append("that one was never going to be forgiven")
	lines.append("")

	if settlement.is_empty():
		lines.append("bonus £%d    damages £%d" % [
			int(outcome.get("bonus", 0.0)), int(outcome.get("penalty", 0.0))])
		return lines
	if bool(settlement.get("failed", false)):
		lines.append("no fee. £%d of damage. %d off your name." % [
			int(float(settlement.get("damages", 0.0))),
			-int(settlement.get("reputation_delta", 0))])
		return lines

	var rep := int(settlement.get("reputation_delta", 0))
	var name_ := "" if rep == 0 else ("    +%d to your name" % rep if rep > 0
		else "    %d off your name" % rep)
	lines.append("fee £%d    bonus £%d    damages £%d%s" % [
		int(float(settlement.get("fee", 0.0))), int(float(settlement.get("bonus", 0.0))),
		int(float(settlement.get("damages", 0.0))), name_])
	if float(settlement.get("before_dark", 0.0)) > 0.0:
		lines.append("done before dark, with %d minutes to spare"
			% int(float(settlement.get("daylight_left", 0.0)) / 60.0))
	elif settlement.has("daylight_left") and float(settlement.get("daylight_left", 1.0)) <= 0.0:
		lines.append("the light went before you did — no bonus for the day")
	lines.append("£%d in the tin" % int(float(settlement.get("paid", 0.0))))
	# These two were nested inside the injury branch, so "a job you have done before" only ever
	# appeared if you had also been hurt doing it.
	if not bool(settlement.get("first_time", true)):
		lines.append("(a job you have done before — it pays, but it does not make your name)")
	if settlement.has("injured"):
		lines.append("and you were under it when it came down — %d off your name, and you were lucky"
			% -int(settlement.get("injured", 0)))
	return lines
