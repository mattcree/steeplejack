## The end of it.
##
## 19-the-complete-game.md, on what a player keeps: "when it's complete, you can steam it. The
## credits sequence is driving it, very slowly, out of the yard and through the town, past every
## chimney in the game — most of which are no longer there, because you took them down."
##
## It is the only screen in the game that is not asking the player for anything. It goes at its own
## pace, it cannot be hurried, and the one thing it does is count up what the season actually was —
## including the parts that are not achievements. Chimneys that are gone are gone. Dogs left in
## other people's walls are still in them.
extends Control

const YARD_SCENE := "res://scenes/yard.tscn"
const CAREER_PATH := "user://career.json"

var career_path := CAREER_PATH

const SKY_TOP := Color(0.42, 0.44, 0.47)
const SKY_LOW := Color(0.82, 0.76, 0.66)
const FAR := Color(0.44, 0.40, 0.38)
const NEAR := Color(0.17, 0.15, 0.14)
const ROAD := Color(0.24, 0.22, 0.20)
const INK := Color(0.96, 0.94, 0.90)
const DIM := Color(0.82, 0.80, 0.77)
const GHOST := Color(0.62, 0.60, 0.58)
const GREEN := Color(0.22, 0.44, 0.28)
const BRASS := Color(0.85, 0.72, 0.36)
const SMOKE := Color(0.22, 0.21, 0.20)

## How long the whole thing takes, in seconds. Slow on purpose: it is a traction engine.
const RUN_SECONDS := 64.0
## Metres of town, in drawing units, that go by in that time.
const ROAD_LENGTH := 9200.0

@onready var jack: Jack = Jack.new()

var career := {}
var chimneys: Array = []       ## [x, height, felled, topped]
var lines: Array = []          ## the tally, revealed one at a time
var _t := 0.0
var _font: Font
var _done := false


func _ready() -> void:
	_font = ThemeDB.fallback_font
	jack.load(ProjectSettings.globalize_path("res://../data/tuning"),
		ProjectSettings.globalize_path("res://../data/levels/00-greybox.json"))
	_load_career()
	_build_town()
	_build_tally()
	set_process(true)
	set_process_input(true)


func _load_career() -> void:
	var text := ""
	if FileAccess.file_exists(career_path):
		var f := FileAccess.open(career_path, FileAccess.READ)
		if f != null:
			text = f.get_as_text()
			f.close()
	jack.career_load(text)
	career = jack.career_state()


## The district, laid out along the road. One chimney per job you took, felled or not, plus the
## ones nobody ever sent you to — because a town is not only the parts of it you worked on.
func _build_town() -> void:
	chimneys = []
	# What he actually took down, not what he was paid for. This counted every job in the career
	# that had not been failed, so a season of conductor runs and bandings drove him past their
	# stumps — the yard's skyline had the identical bug, separately, which is why the answer now
	# lives in District and not in either screen.
	var t: Dictionary = District.tally(career)
	var felled: int = int(t.get("felled", 0))
	var shortened: int = int(t.get("shortened", 0))
	var n := 26
	# Which ones are gone, spread evenly along the road. A stump only means anything next to
	# something still standing, so putting all the felled ones first would drive the player past
	# the absence before the sequence has told them what it is.
	var gone_at := {}
	for k in mini(felled, n):
		gone_at[int(float(k) * float(n) / float(maxi(felled, 1)))] = true
	# And the ones he took the top off, which are still there and are not what they were.
	var cut_at := {}
	for k in mini(shortened, n):
		var slot: int = int(float(k) * float(n) / float(maxi(shortened, 1))) + 1
		if slot < n and not gone_at.has(slot):
			cut_at[slot] = true
	for i in n:
		var seed_x: float = absf(fmod(sin(float(i * 31 + 5)) * 43758.5453, 1.0))
		var seed_h: float = absf(fmod(sin(float(i * 67 + 11)) * 24634.6345, 1.0))
		var tall: float = 170.0 + 300.0 * seed_h
		chimneys.append([
			ROAD_LENGTH * (0.04 + 0.92 * (float(i) / float(n)) + 0.02 * seed_x),
			tall * (0.55 if cut_at.has(i) else 1.0),
			gone_at.has(i),
			cut_at.has(i),
		])


## What the season was. Not a score: the felled chimneys are not an achievement and are not
## presented as one, and the dogs left in other people's walls are counted because they are still
## there whatever anyone thinks about it.
func _build_tally() -> void:
	var jobs: Array = career.get("jobs", []) as Array
	var paid := 0.0
	for j in jobs:
		paid += float((j as Dictionary).get("paid", 0.0))
	var stumps := 0
	for c in chimneys:
		if bool(c[2]):
			stumps += 1
	var kept: int = (jack.career_salvage() as Array).size()
	lines = [
		["%d" % jobs.size(), "jobs, from the back yard to the Great Aire"],
		["%d" % int(career.get("day", 0)), "days of it"],
		["£%.0f" % paid, "in the tin, and most of it in the engine"],
		["%d" % kept, "things on a shelf in the yard that came off them"],
		["%d" % stumps, "chimneys that are not there any more"],
		["", "because of you"],
	]


func _process(dt: float) -> void:
	_t += dt
	if _t > RUN_SECONDS + 9.0 and not _done:
		_done = true
	queue_redraw()


func _input(event: InputEvent) -> void:
	# It cannot be hurried, but it can be left. Escape only, and only back to the yard.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or (_done and event.keycode == KEY_ENTER):
			_home()


func _home() -> void:
	var packed: PackedScene = load(YARD_SCENE)
	if packed == null:
		return
	var yard: Node = packed.instantiate()
	yard.career_path = career_path
	get_tree().root.add_child(yard)
	get_tree().current_scene = yard
	queue_free()


## How far along the road she has got, 0 to 1.
func progress() -> float:
	return clampf(_t / RUN_SECONDS, 0.0, 1.0)


func _draw() -> void:
	var travelled: float = ROAD_LENGTH * progress()
	# The engine sits a third of the way across and the town comes to her, which is the only way
	# to drive nine kilometres of road across sixteen hundred pixels.
	var eye: float = travelled - size.x * 0.32

	for i in 24:
		var f: float = float(i) / 23.0
		draw_rect(Rect2(Vector2(0.0, size.y * 0.03 * float(i)), Vector2(size.x, size.y * 0.04)),
			SKY_TOP.lerp(SKY_LOW, f))

	var horizon: float = size.y * 0.80
	_draw_town(eye, horizon)
	draw_rect(Rect2(Vector2(0.0, horizon), Vector2(size.x, size.y - horizon)), ROAD)
	# Setts, going by. The only thing on screen that says how slowly she is actually moving.
	var sett := 46.0
	var first: float = -fmod(eye, sett)
	var x := first
	while x < size.x + sett:
		draw_line(Vector2(x, horizon + 30.0), Vector2(x, size.y),
			Color(0.0, 0.0, 0.0, 0.10), 2.0)
		x += sett

	_draw_engine(Vector2(size.x * 0.32, horizon + 58.0))
	_draw_tally()

	if _done:
		_centre("[esc]", size.y - 48.0, Color(GHOST, 0.6), 13)


func _draw_town(eye: float, horizon: float) -> void:
	# Terraces first, hazed, so the chimneys have something to stand behind.
	var w := 120.0
	var x: float = -fmod(eye * 0.55, w * 6.0)
	while x < size.x + w * 2.0:
		var vary: float = absf(fmod(sin(x * 0.013) * 6421.0, 1.0))
		var ww: float = w * (0.70 + 0.62 * vary)
		var h: float = 44.0 + 26.0 * absf(fmod(sin(x * 0.031) * 8123.0, 1.0))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, horizon), Vector2(x + ww * 0.5, horizon - h), Vector2(x + ww, horizon),
			Vector2(x + ww, horizon + 14.0), Vector2(x, horizon + 14.0)]),
			FAR.lerp(NEAR, 0.30))
		x += ww * 0.96

	for c in chimneys:
		var cx: float = float(c[0]) - eye
		if cx < -90.0 or cx > size.x + 90.0:
			continue
		var full: float = float(c[1])
		var felled: bool = bool(c[2])
		var h: float = maxf(full * 0.11, 34.0) if felled else full
		var cw: float = maxf(full / 11.5, 7.0)
		var top_w: float = cw * 0.70
		var col := NEAR if not felled else NEAR.lerp(FAR, 0.45)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - cw * 0.5, horizon), Vector2(cx + cw * 0.5, horizon),
			Vector2(cx + top_w * 0.5, horizon - h), Vector2(cx - top_w * 0.5, horizon - h)]), col)
		if not felled:
			draw_rect(Rect2(Vector2(cx - top_w * 0.5 - 3.0, horizon - h - 5.0),
				Vector2(top_w + 6.0, 5.0)), col)
			for q in 5:
				var qf: float = float(q) / 4.0
				draw_circle(Vector2(cx - qf * 40.0 + sin(_t * 0.3 + cx) * 6.0 * qf,
					horizon - h - 16.0 - qf * 46.0), 5.0 + qf * 13.0,
					Color(SMOKE, 0.10 * (1.0 - qf)))
		else:
			# A stump has to read as an ABSENCE rather than as a short chimney, or the one thing
			# this sequence exists to show is invisible. So: rubble spread wide round the base,
			# a ragged top where the courses were taken off, and nothing at all above it.
			draw_rect(Rect2(Vector2(cx - cw * 2.1, horizon - 9.0), Vector2(cw * 4.2, 9.0)),
				col.lerp(FAR, 0.35))
			for b in 7:
				var bx: float = cx + (float(b) - 3.0) * cw * 0.62
				var bh: float = 5.0 + 9.0 * absf(fmod(sin(float(b) * 7.3 + cx) * 311.0, 1.0))
				draw_rect(Rect2(Vector2(bx - cw * 0.26, horizon - 9.0 - bh),
					Vector2(cw * 0.52, bh)), col.lerp(FAR, 0.45))


## Her, finished, in green and red, going about four miles an hour.
func _draw_engine(at: Vector2) -> void:
	var w := 330.0
	var h := 170.0
	var bounce: float = sin(_t * 3.1) * 1.6
	at.y += bounce

	# Smoke, and a lot of it, leaning back down the road she came up.
	for p in 16:
		var pf: float = float(p) / 15.0
		var drift: float = -pf * 150.0 + sin(_t * 0.9 + pf * 5.0) * 14.0 * pf
		draw_circle(Vector2(at.x + w * 0.20 + drift, at.y - h * 1.02 - pf * 120.0),
			7.0 + pf * 34.0, Color(SMOKE, 0.16 * (1.0 - pf)))

	var rear := h * 0.42
	var front := h * 0.24
	# Wheels, and they turn, because a traction engine whose wheels do not turn is a picture.
	var spin: float = -progress() * 46.0
	for k in [[-w * 0.26, rear, 12], [w * 0.30, front, 9]]:
		var c := at + Vector2(float(k[0]), -float(k[1]))
		draw_arc(c, float(k[1]), 0.0, TAU, 30, GREEN, 6.0)
		for s in int(k[2]):
			var a: float = spin + TAU * float(s) / float(k[2])
			draw_line(c, c + Vector2(cos(a), sin(a)) * float(k[1]), Color(GREEN, 0.75), 2.0)

	draw_rect(Rect2(at + Vector2(-w * 0.34, -h * 0.78), Vector2(w * 0.60, h * 0.36)), GREEN)
	draw_rect(Rect2(at + Vector2(w * 0.14, -h * 1.12), Vector2(w * 0.11, h * 0.44)), GREEN)
	draw_rect(Rect2(at + Vector2(w * 0.12, -h * 1.18), Vector2(w * 0.15, h * 0.07)), GREEN)
	# The lining out, which is the last thing you pay for and the first thing anyone sees.
	draw_line(at + Vector2(-w * 0.34, -h * 0.60), at + Vector2(w * 0.26, -h * 0.60),
		Color(0.80, 0.24, 0.20), 3.0)
	draw_circle(at + Vector2(-w * 0.06, -h * 0.86), 6.0, BRASS)
	draw_circle(at + Vector2(w * 0.04, -h * 0.86), 6.0, BRASS)
	# And a man on her, because somebody has to be.
	draw_rect(Rect2(at + Vector2(-w * 0.20, -h * 1.02), Vector2(13.0, 26.0)), Color(0.14, 0.13, 0.12))
	draw_circle(at + Vector2(-w * 0.20 + 6.0, -h * 1.05), 7.0, Color(0.80, 0.72, 0.64))


## The tally, one line at a time, in the last third of the drive.
func _draw_tally() -> void:
	var start := RUN_SECONDS * 0.34
	var gap := 5.2
	for i in lines.size():
		var at_t: float = start + gap * float(i)
		if _t < at_t:
			continue
		var age: float = _t - at_t
		var a: float = clampf(age / 1.4, 0.0, 1.0)
		# They stay up. Nothing here is a notification.
		var y: float = size.y * 0.16 + 46.0 * float(i)
		var big := String(lines[i][0])
		var rest := String(lines[i][1])
		var x: float = size.x * 0.60
		if big != "":
			_label(big, Vector2(x, y), Color(INK, a), 34)
			var bw: float = _font.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
			_label(rest, Vector2(x + bw + 14.0, y), Color(DIM, a * 0.9), 17)
		else:
			_label(rest, Vector2(x, y), Color(DIM, a * 0.9), 17)


func _label(text: String, at: Vector2, col: Color, px: int) -> void:
	if col.a <= 0.01:
		return
	for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_string(_font, at + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
			Color(0, 0, 0, col.a * 0.55))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _centre(text: String, y: float, col: Color, px: int) -> void:
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_label(text, Vector2((size.x - w) * 0.5, y), col, px)
