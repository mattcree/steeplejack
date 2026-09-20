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
	"Walk round and read the lean with the plumb bob [B], twice, from well apart",
	"Cut the gob on the fall line — hold the chimney's own lean in mind",
	"Prop behind you as you go — the prop goes in BEFORE the last course comes out",
	"Watch the margin. Finish UNEASY, not SAFE — safe does not fall",
	"Drive two pegs down the line you want [P], then light it [F]",
]

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
	_draw_plan()
	_draw_message()
	if not outcome.is_empty():
		_draw_verdict()


# ---------------------------------------------------------------- panels

func _draw_steps() -> void:
	# A scrim. The first render of this put pale text straight onto a bright sky and half of it
	# could not be read, which for a panel whose whole job is telling you what to do is fatal.
	draw_rect(Rect2(0, 0, 620, 240), Color(0.05, 0.05, 0.06, 0.55))
	var y := 26.0
	draw_string(_font, Vector2(24, y), "FELLING — Waterside", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
	y += 24.0
	for i in STEPS.size():
		var done := i < step
		var here := i == step
		var colour := INK if here else (DIM if not done else Color(0.55, 0.78, 0.50, 0.7))
		var mark := "x" if done else (">" if here else " ")
		draw_string(_font, Vector2(24, y), "%s %s" % [mark, STEPS[i]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, colour)
		y += 19.0


func _draw_state() -> void:
	if state.is_empty():
		return
	var name_ := String(state.get("status_name", "SAFE"))
	var colour: Color = BAND_COLOUR.get(name_, INK)
	var y := 138.0
	draw_rect(Rect2(24, y, 320, 3), colour)
	y += 24.0
	draw_string(_font, Vector2(24, y), "%s — %s" % [name_, BAND_WORDS.get(name_, "")],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, colour)
	y += 22.0
	draw_string(_font, Vector2(24, y),
		"margin %.2f m    gob %.0f° on %03d°    props %d left, %d standing" % [
			float(state.get("margin", 0.0)), float(state.get("cut_arc", 0.0)),
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

	if not prediction.is_empty():
		y += 22.0
		draw_string(_font, Vector2(24, y),
			"predicted %03d° ±%.1f°    pegged %03d°    off by %.1f°" % [
				int(prediction.get("fall_bearing", 0.0)), float(prediction.get("accuracy", 0.0)),
				int(peg_bearing), float(prediction.get("error", 0.0))],
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
	if aim_verb == "":
		return
	draw_string(_font, Vector2(c.x - 150, c.y + 34), aim_verb,
		HORIZONTAL_ALIGNMENT_CENTER, 300, 14, INK)


func _draw_message() -> void:
	if message == "" or Time.get_ticks_msec() / 1000.0 > message_until:
		return
	draw_string(_font, Vector2(size.x * 0.5 - 300, size.y - 120), message,
		HORIZONTAL_ALIGNMENT_CENTER, 600, 16, INK)


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
	var panel := Rect2(size.x * 0.5 - 260, size.y * 0.5 - 130, 520, 260)
	draw_rect(panel, Color(0.05, 0.05, 0.06, 0.88))
	var grade := String(outcome.get("grade_name", "WILD"))
	var colour: Color = {
		"PERFECT": Color(0.55, 0.85, 0.50), "GOOD": Color(0.80, 0.85, 0.45),
		"ACCEPTABLE": Color(0.90, 0.78, 0.35), "WILD": HAZARD,
	}.get(grade, INK)
	var y := panel.position.y + 42.0
	draw_string(_font, Vector2(panel.position.x, y), grade, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x,
		30, colour)
	y += 40.0
	var lines := [
		"it went to %03d°, %.1f° off your pegs" % [
			float(outcome.get("fall_bearing", 0.0)), float(outcome.get("error", 0.0))],
		"broke into %d, %s" % [int(outcome.get("chunks", 1)),
			"she broke up nicely" if bool(outcome.get("clean_break", false)) else "one piece, harder to clear"],
	]
	var struck: Array = outcome.get("struck", [])
	if struck.is_empty():
		lines.append("nothing in the fan was touched")
	else:
		lines.append("you hit: %s" % ", ".join(struck))
	if bool(outcome.get("catastrophe", false)):
		lines.append("that one was never going to be forgiven")
	lines.append("")
	lines.append("bonus £%d    damages £%d" % [
		int(outcome.get("bonus", 0.0)), int(outcome.get("penalty", 0.0))])
	for line in lines:
		draw_string(_font, Vector2(panel.position.x, y), line, HORIZONTAL_ALIGNMENT_CENTER,
			panel.size.x, 15, INK if line.begins_with("bonus") else DIM)
		y += 24.0
