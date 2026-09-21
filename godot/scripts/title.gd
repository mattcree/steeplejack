## The front door.
##
## The game had none. `run/main_scene` pointed at the job board, so it opened on a wall of
## letters with a shift already in progress — no name, no way back to a career, and the only exit
## was Escape quitting the process. A playtest asked for "the traditional start screen and so on,
## and a menu and options and stuff like that that you would expect to have in a game", which is a
## fair description of a thing every game has and this one did not.
##
## It is drawn rather than built out of Controls, like every other screen here, because the whole
## point of this engine choice is that a screen is text in a diff (13-art-direction.md, "no
## hand-placed level geometry"). The skyline below is four numbers and a loop.
extends Control

## The title opens the yard, and the yard opens the board. A career starts at home.
const YARD_SCENE := "res://scenes/yard.tscn"
const CAREER_PATH := "user://career.json"

## Where the tin lives. A test points this somewhere else so it does not read a real career.
var career_path := CAREER_PATH

const SKY_TOP := Color(0.36, 0.42, 0.50)
const SKY_LOW := Color(0.76, 0.72, 0.64)
const SMOKE := Color(0.20, 0.19, 0.18)
const BRICK := Color(0.16, 0.13, 0.12)
const INK := Color(0.96, 0.94, 0.90)
const DIM := Color(0.82, 0.80, 0.77)
const GHOST := Color(0.62, 0.60, 0.58)
const WATCH := Color(0.95, 0.76, 0.33)

const H_TITLE := 74
const H_ROW := 22
const ROW_GAP := 40.0

## Rows are built in `_ready` because Continue is only there when there is something to continue.
var rows: Array = []
var selected := 0
var options_open := false
var options_row := 0
var confirming := false        ## New Game over the top of a career: ask first
var settings: GameSettings

var _font: Font
var _t := 0.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	settings = GameSettings.new()
	_build_rows()
	set_process(true)
	set_process_input(true)
	queue_redraw()


func has_career() -> bool:
	if not FileAccess.file_exists(career_path):
		return false
	var f := FileAccess.open(career_path, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	# An empty or broken tin is not a career to continue, it is a file. Offering Continue and then
	# dropping the player into a fresh career would be worse than not offering it.
	return text.strip_edges().length() > 2


func _build_rows() -> void:
	rows = []
	if has_career():
		rows.append(["continue", "Continue"])
	rows.append(["new", "New career"])
	rows.append(["options", "Options"])
	rows.append(["quit", "Quit"])
	selected = 0


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_mouse(event)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if options_open:
		_options_key(event.keycode)
		queue_redraw()
		return
	if confirming:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_Y:
				_start_new()
			KEY_ESCAPE, KEY_N:
				confirming = false
		queue_redraw()
		return
	match event.keycode:
		KEY_DOWN, KEY_S:
			selected = (selected + 1) % rows.size()
		KEY_UP, KEY_W:
			selected = (selected - 1 + rows.size()) % rows.size()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			choose(String(rows[selected][0]))
		KEY_ESCAPE:
			get_tree().quit()
	queue_redraw()


## Hover picks a row, a click takes it. The options panel in the climb shipped keyboard-only and
## silently swallowed clicks, which read as a broken menu; this one does both from the start.
func _mouse(event: InputEvent) -> void:
	if options_open:
		var hit: Dictionary = options_hit(event.position)
		if not hit.is_empty():
			options_row = int(hit["row"])
			if event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT and int(hit["step"]) != 0:
				settings.step(GameSettings.ROWS[options_row][0], int(hit["step"]))
		queue_redraw()
		return
	if confirming:
		return
	var row := row_at(event.position)
	if row >= 0:
		selected = row
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			choose(String(rows[selected][0]))
	queue_redraw()


func choose(what: String) -> void:
	match what:
		"continue":
			_open_yard()
		"new":
			# Destructive, and it is somebody's whole season. Ask.
			if has_career():
				confirming = true
			else:
				_start_new()
		"options":
			options_open = true
			options_row = 0
		"quit":
			get_tree().quit()


func _start_new() -> void:
	confirming = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(career_path))
	_open_yard()


func _open_yard() -> void:
	var packed: PackedScene = load(YARD_SCENE)
	if packed == null:
		push_error("title: cannot load %s" % YARD_SCENE)
		return
	var yard: Node = packed.instantiate()
	yard.career_path = career_path
	get_tree().root.add_child(yard)
	get_tree().current_scene = yard
	queue_free()


# --- geometry, shared by the drawing and the hit-testing ------------------------------------------
#
# One copy of it, because the climb's options panel had two and a menu whose clicks land one row
# off is worse than one that ignores the mouse.

func _rows_origin() -> Vector2:
	# Low and left, over the dark of the roofs rather than in the middle of the chimneys. Pale
	# text on a pale sky is the fault this project has already fixed twice.
	return Vector2(size.x * 0.09, size.y * 0.68)


func row_at(p: Vector2) -> int:
	var at := _rows_origin()
	for i in rows.size():
		var y: float = at.y + ROW_GAP * float(i)
		if p.y >= y - 22.0 and p.y <= y + 10.0 and p.x >= at.x - 20.0 and p.x <= at.x + 320.0:
			return i
	return -1


const OPT_W := 460.0
const OPT_ROW_H := 26.0
const OPT_FIRST_Y := 70.0
const OPT_VALUE_W := 150.0


func _options_rect() -> Rect2:
	var h := 64.0 + OPT_ROW_H * float(GameSettings.ROWS.size()) + 40.0
	return Rect2(Vector2((size.x - OPT_W) * 0.5, (size.y - h) * 0.5), Vector2(OPT_W, h))


func options_hit(p: Vector2) -> Dictionary:
	var r := _options_rect()
	if not r.has_point(p):
		return {}
	for i in GameSettings.ROWS.size():
		var y: float = r.position.y + OPT_FIRST_Y + OPT_ROW_H * float(i)
		if p.y >= y - 18.0 and p.y <= y + 6.0:
			var value_left: float = r.position.x + OPT_W - 24.0 - OPT_VALUE_W
			var step := 0
			if p.x >= value_left:
				step = 1 if p.x >= value_left + OPT_VALUE_W * 0.5 else -1
			return {"row": i, "step": step}
	return {}


func _options_key(key: int) -> void:
	var n: int = GameSettings.ROWS.size()
	match key:
		KEY_ESCAPE, KEY_F1:
			options_open = false
		KEY_UP, KEY_W:
			options_row = (options_row - 1 + n) % n
		KEY_DOWN, KEY_S:
			options_row = (options_row + 1) % n
		KEY_LEFT, KEY_A:
			settings.step(GameSettings.ROWS[options_row][0], -1)
		KEY_RIGHT, KEY_D, KEY_ENTER, KEY_SPACE:
			settings.step(GameSettings.ROWS[options_row][0], 1)


# --- drawing --------------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SKY_TOP)
	var bands := 26
	for i in bands:
		var f: float = float(i) / float(bands - 1)
		draw_rect(Rect2(Vector2(0.0, size.y * (0.20 + 0.80 * f)), Vector2(size.x, size.y * 0.04)),
			SKY_TOP.lerp(SKY_LOW, f))
	_draw_skyline()

	_centre("STEEPLEJACK", size.y * 0.22, INK, H_TITLE)
	_centre("a trade that is nearly gone", size.y * 0.22 + 46.0, Color(DIM, 0.72), 17)

	if options_open:
		_draw_options()
		return
	if confirming:
		_draw_confirm()
		return

	var at := _rows_origin()
	# A panel of shade under the list. The skyline behind it is the point of the screen, so it is
	# not moved out of the way — but a menu you have to squint at is not a menu, and this project
	# has learned that twice already (the wind rose, and every label in the HUD).
	draw_rect(Rect2(Vector2(at.x - 40.0, at.y - 44.0),
		Vector2(310.0, ROW_GAP * float(rows.size()) + 40.0)), Color(0.05, 0.05, 0.06, 0.55))
	for i in rows.size():
		var y: float = at.y + ROW_GAP * float(i)
		var on: bool = i == selected
		if on:
			# A chalk mark against the row, the same one the tap test leaves on a joint.
			draw_rect(Rect2(Vector2(at.x - 22.0, y - 14.0), Vector2(4.0, 16.0)), WATCH)
		_label(String(rows[i][1]), Vector2(at.x, y), INK if on else Color(DIM, 0.72), H_ROW)

	_label("↑↓ or the mouse   ·   enter to take it",
		Vector2(size.x * 0.09, size.y - 46.0), Color(GHOST, 0.75), 13)


## A mill town at dusk: chimneys of falling height, the far ones hazed into the sky. Deterministic,
## because a title screen that reshuffles itself looks like a bug even when it is not.
##
## The first pass drew every chimney the same width whatever its height, so the tall ones came out
## as masts. A mill chimney is roughly one part wide to eleven or twelve tall, and it tapers an
## inch to the yard — the same batter the chimneys in the game are built to, and the reason the
## silhouette is recognisable at all.
func _draw_skyline() -> void:
	var horizon: float = size.y * 0.78
	_draw_roofs(horizon)
	for rank in 3:
		var haze: float = [0.70, 0.40, 0.0][rank]
		var col := BRICK.lerp(SKY_LOW, haze)
		var y: float = horizon - [26.0, 12.0, 0.0][rank]
		var n: int = 7 + rank * 2
		for i in n:
			var seed_x: float = absf(fmod(sin(float(i * 37 + rank * 91)) * 43758.5453, 1.0))
			var seed_h: float = absf(fmod(sin(float(i * 71 + rank * 13)) * 24634.6345, 1.0))
			var x: float = size.x * (seed_x * 1.06 - 0.03)
			var h: float = size.y * (0.14 + 0.30 * seed_h) * [0.52, 0.74, 1.0][rank]
			var w: float = maxf(h / 11.5, 5.0)          # a chimney's own proportion, not a constant
			var top_w: float = w * 0.70                  # the batter, an inch to the yard
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - w * 0.5, y), Vector2(x + w * 0.5, y),
				Vector2(x + top_w * 0.5, y - h), Vector2(x - top_w * 0.5, y - h)]), col)
			# The oversailing cap: the corbelled courses at the head, and the whole silhouette.
			var cap_w: float = top_w + maxf(w * 0.34, 3.0)
			var cap_h: float = maxf(w * 0.42, 3.0)
			draw_rect(Rect2(Vector2(x - cap_w * 0.5, y - h - cap_h),
				Vector2(cap_w, cap_h)), col)
			if rank == 2 and h > size.y * 0.26:
				_draw_smoke(x, y - h - cap_h, h)


## Terraces, in two ranks of gable ends. It is the same trick as the chimneys — a proportion and a
## loop — and it is what turns a flat dark band into somewhere people live.
func _draw_roofs(horizon: float) -> void:
	draw_rect(Rect2(Vector2(0.0, horizon), Vector2(size.x, size.y - horizon)), BRICK.lerp(SMOKE, 0.5))
	for rank in 2:
		var col := BRICK.lerp(SKY_LOW, 0.34 if rank == 0 else 0.10)
		var y: float = horizon + (4.0 if rank == 0 else 20.0)
		var w: float = 78.0 + 26.0 * float(rank)
		var x: float = -w * absf(fmod(sin(float(rank * 17)) * 1917.0, 1.0))
		while x < size.x + w:
			var vary: float = absf(fmod(sin(x * 0.027 + float(rank) * 5.1) * 6421.0, 1.0))
			# Houses are not all the same width, and a perfectly regular sawtooth reads as a
			# pattern rather than as a street.
			var ww: float = w * (0.74 + 0.52 * vary)
			var h: float = 26.0 + 14.0 * absf(fmod(sin(x * 0.041 + float(rank)) * 8123.0, 1.0))
			# A gable: two pitches and a ridge, which reads as a street end at any size.
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, y), Vector2(x + ww * 0.5, y - h), Vector2(x + ww, y),
				Vector2(x + ww, y + 90.0), Vector2(x, y + 90.0)]), col)
			# And one domestic stack per house, because that is what the skyline actually is.
			var sx: float = x + ww * 0.5
			draw_rect(Rect2(Vector2(sx - 4.0, y - h - 13.0), Vector2(8.0, 13.0)),
				col.lerp(BRICK, 0.45))
			x += ww * 0.94


## Thin, leaning, and fading out. The first pass drew five hard circles per chimney and they came
## out as cotton wool.
func _draw_smoke(x: float, top: float, h: float) -> void:
	for p in 7:
		var pf: float = float(p) / 6.0
		var drift: float = sin(_t * 0.18 + x * 0.01) * 10.0 * pf + pf * pf * 26.0
		draw_circle(Vector2(x + drift, top - 8.0 - pf * (h * 0.30 + 26.0)),
			3.0 + pf * 9.0, Color(SMOKE, 0.10 * (1.0 - pf)))


func _draw_confirm() -> void:
	var w := 520.0
	var h := 150.0
	var at := Vector2((size.x - w) * 0.5, (size.y - h) * 0.5)
	draw_rect(Rect2(at, Vector2(w, h)), Color(0.05, 0.05, 0.06, 0.9))
	_centre("Start a new career?", at.y + 46.0, INK, 22)
	_centre("The season you have going will be gone for good.", at.y + 76.0, Color(DIM, 0.8), 15)
	_centre("[Enter] start over      [Esc] keep it", at.y + 116.0, Color(WATCH, 0.9), 15)


func _draw_options() -> void:
	var rect := _options_rect()
	draw_rect(rect, Color(0.05, 0.05, 0.06, 0.9))
	_label("Motion and vertigo", rect.position + Vector2(24.0, 36.0), INK, 18)
	for i in GameSettings.ROWS.size():
		var y: float = rect.position.y + OPT_FIRST_Y + OPT_ROW_H * float(i)
		var on: bool = i == options_row
		var col := INK if on else Color(DIM, 0.8)
		if on:
			draw_rect(Rect2(Vector2(rect.position.x + 12.0, y - 18.0),
				Vector2(OPT_W - 24.0, 24.0)), Color(1, 1, 1, 0.07))
		_label(String(GameSettings.ROWS[i][1]), Vector2(rect.position.x + 24.0, y), col, 14)
		var v: String = settings.shown(GameSettings.ROWS[i][0])
		var vw: float = _font.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_label(("‹ %s ›" % v) if on else v,
			Vector2(rect.position.x + OPT_W - 24.0 - vw - (14.0 if on else 0.0), y), col, 14)
	_label("↑↓ or click   ←→ or click the value   Esc back  ·  saved as you go",
		Vector2(rect.position.x + 24.0, rect.position.y + rect.size.y - 16.0), Color(GHOST, 0.75), 12)


func _label(text: String, at: Vector2, col: Color, px: int) -> void:
	for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_string(_font, at + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
			Color(0, 0, 0, col.a * 0.55))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _centre(text: String, y: float, col: Color, px: int) -> void:
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_label(text, Vector2((size.x - w) * 0.5, y), col, px)
