## The yard — the hub the meta layer has been waiting for.
##
## 08-hub-and-meta.md has described this since the beginning and nothing had been built: the game
## went title, job board, chimney, job board, for ever. No day passed, the money went up and bought
## nothing, and the traction engine that the whole ending rests on did not exist.
##
## It is not an open world and must never become one. One small space, a handful of interaction
## points, two to five minutes a visit. What is here now is the three that carry the campaign: the
## board, the kettle and the tarpaulin. The van's loadout and the bench are designed and are not
## faked with a button that says "coming soon" — they will appear when they work.
extends Control

const BOARD_SCENE := "res://scenes/jobs.tscn"
const LEVELS_DIR := "res://../data/levels"
const CAREER_PATH := "user://career.json"

var career_path := CAREER_PATH

const SKY := Color(0.30, 0.31, 0.33)
const WALL := Color(0.24, 0.19, 0.16)
const FLAG := Color(0.17, 0.16, 0.15)
const FIRE := Color(0.96, 0.62, 0.26)
const INK := Color(0.96, 0.94, 0.90)
const DIM := Color(0.82, 0.80, 0.77)
const GHOST := Color(0.62, 0.60, 0.58)
const WATCH := Color(0.95, 0.76, 0.33)
const GOOD := Color(0.56, 0.80, 0.50)
const RUST := Color(0.45, 0.28, 0.18)
const GREEN := Color(0.20, 0.42, 0.26)

const ROW_GAP := 64.0

@onready var jack: Jack = Jack.new()

var rows: Array = []
var selected := 0
var career := {}
var stages: Array = []
var _font: Font
var _t := 0.0
var _said := ""


func _ready() -> void:
	_font = ThemeDB.fallback_font
	jack.load(ProjectSettings.globalize_path("res://../data/tuning"),
		ProjectSettings.globalize_path("res://../data/levels/00-greybox.json"))
	_load_career()
	stages = _engine_stages()
	_build_rows()
	set_process(true)
	set_process_input(true)
	queue_redraw()


## Steaming her only appears when she is finished. It is the last row because it is the last
## thing, and it is not a menu item until then — an option greyed out for a whole campaign is a
## countdown, and this should arrive rather than approach.
func _build_rows() -> void:
	rows = [
		["board", "The board", "see what work there is"],
		["kettle", "The kettle", "turn in, and let a day go by"],
		["shed", "The shed", "what you climb with"],
		["engine", "The tarpaulin", "the engine"],
	]
	if engine_done():
		rows.append(["steam", "Steam her", "take her out on the road"])
	selected = mini(selected, rows.size() - 1)


func _load_career() -> void:
	var text := ""
	if FileAccess.file_exists(career_path):
		var f := FileAccess.open(career_path, FileAccess.READ)
		if f != null:
			text = f.get_as_text()
			f.close()
	jack.career_load(text)
	career = jack.career_state()


func _save_career() -> void:
	var f := FileAccess.open(career_path, FileAccess.WRITE)
	if f == null:
		push_error("yard: cannot write %s" % career_path)
		return
	f.store_string(jack.career_json())
	f.close()


## The engine's stages, straight out of economy.json. Forty-odd parts across five stages, about
## nine thousand pounds against a career's sixteen — finishable on good work, and not at all if you
## spend it on kit and damages.
func _engine_stages() -> Array:
	var path := ProjectSettings.globalize_path("res://../data/tuning/economy.json")
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var doc = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(doc) != TYPE_DICTIONARY:
		return []
	return (doc.get("engine", {}) as Dictionary).get("stages", []) as Array


## Which stage the engine is up to, by how many parts are bought. Returns -1 when it is finished.
func stage_index() -> int:
	var bought: int = int(career.get("engine_parts", 0))
	var seen := 0
	for i in stages.size():
		var need: int = int(stages[i].get("parts", 0))
		if need <= 0:
			continue
		seen += need
		if bought < seen:
			return i
	return -1


## What the next part costs: its stage's cost spread over its parts, rounded to the shilling.
func next_part_cost() -> float:
	var i := stage_index()
	if i < 0:
		return 0.0
	var parts: int = maxi(int(stages[i].get("parts", 1)), 1)
	return roundf(float(stages[i].get("cost", 0)) / float(parts) * 20.0) / 20.0


func engine_done() -> bool:
	return stage_index() < 0 and not stages.is_empty()


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _input(event: InputEvent) -> void:
	if shed_open:
		_shed_input(event)
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		var r := row_at(event.position)
		if r >= 0:
			selected = r
			if event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT:
				choose(String(rows[selected][0]))
		queue_redraw()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
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


func _shed_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		shed_hot = UiButtons.hit(shed_buttons(), event.position)
		if shed_hot >= 0:
			if event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT:
				if shed_hot == 0:
					shed_choose()
				else:
					shed_open = false
					_said = ""
			queue_redraw()
			return
		var r := shed_row_at(event.position)
		if r >= 0:
			shed_row = r
			if event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT:
				shed_choose()
		queue_redraw()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_DOWN, KEY_S:
			shed_row = (shed_row + 1) % SHED.size()
		KEY_UP, KEY_W:
			shed_row = (shed_row - 1 + SHED.size()) % SHED.size()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			shed_choose()
		KEY_ESCAPE:
			shed_open = false
			_said = ""
	queue_redraw()


# --- the shed's geometry, shared by the drawing and the hit-testing ---------------------------
#
# One function, as with the options panel: the second copy of "the third row is 70 + 26i pixels
# down" is the one that drifts, and a menu whose clicks land one row off is worse than one that
# ignores the mouse.

const SHED_W := 560.0
const SHED_ROW_H := 74.0


func shed_rect() -> Rect2:
	var h := 120.0 + SHED_ROW_H * float(SHED.size()) + 64.0
	return Rect2(Vector2((size.x - SHED_W) * 0.5, (size.y - h) * 0.5), Vector2(SHED_W, h))


var shed_hot := -1


## Buy, and get out. Shared with the hit-testing below.
func shed_buttons() -> Array:
	var r := shed_rect()
	return UiButtons.rects(_font, ["Buy", "Back to the yard"], 15,
		r.position.x + r.size.x - 24.0, r.position.y + r.size.y - 14.0)


func shed_row_at(p: Vector2) -> int:
	var r := shed_rect()
	for i in SHED.size():
		var y: float = r.position.y + 120.0 + SHED_ROW_H * float(i)
		if p.y >= y - 28.0 and p.y <= y + 34.0 and r.encloses(Rect2(p, Vector2.ZERO)):
			return i
	return -1


func _draw_shed() -> void:
	var r := shed_rect()
	draw_rect(Rect2(r.position - Vector2(8, 8), r.size + Vector2(16, 16)), Color(0, 0, 0, 0.55))
	draw_rect(r, Color(0.13, 0.12, 0.12))
	_label("THE SHED", r.position + Vector2(28, 46), Color(GHOST, 0.75), 13)
	_label("£%.0f in the tin" % float(career.get("money", 0.0)), r.position + Vector2(28, 80),
		INK, 22)

	for i in SHED.size():
		var item: String = SHED[i]
		var y: float = r.position.y + 120.0 + SHED_ROW_H * float(i)
		var on: bool = i == shed_row
		var owned: bool = jack.career_owns(item)
		if on:
			draw_rect(Rect2(Vector2(r.position.x + 16.0, y - 28.0),
				Vector2(SHED_W - 32.0, 62.0)), Color(1, 1, 1, 0.05))
			draw_rect(Rect2(Vector2(r.position.x + 16.0, y - 28.0), Vector2(3.0, 62.0)), WATCH)
		_label(String(SHED_NAME.get(item, item)), Vector2(r.position.x + 34.0, y),
			INK if on else Color(DIM, 0.75), 20)
		_label(String(SHED_WHY.get(item, "")), Vector2(r.position.x + 34.0, y + 22.0),
			Color(GHOST, 0.8 if on else 0.55), 13)
		var cost: float = jack.career_kit_cost(item)
		var right := Vector2(r.position.x + SHED_W - 118.0, y)
		if item == "ladderSection":
			_label("%d" % jack.career_ladders(), Vector2(right.x - 44.0, y), Color(DIM, 0.9), 17)
			_label("£%.0f" % cost, right,
				Color(WATCH, 0.95) if cost <= float(career.get("money", 0.0))
					else Color(0.72, 0.42, 0.34, 0.9), 20)
		elif owned:
			_label("yours", right, Color(GOOD, 0.9), 17)
		elif cost > float(career.get("money", 0.0)):
			_label("£%.0f" % cost, right, Color(0.72, 0.42, 0.34, 0.9), 20)
		else:
			_label("£%.0f" % cost, right, Color(WATCH, 0.95), 20)

	if _said != "":
		_label(_said, r.position + Vector2(28, r.size.y - 52.0), Color(WATCH, 0.9), 15)
	_label("↑↓ or the mouse", r.position + Vector2(28, r.size.y - 24.0), Color(GHOST, 0.7), 13)
	UiButtons.draw_row(self, _font, shed_buttons(), ["Buy", "Back to the yard"], 15,
		shed_hot, 0, INK, Color(0.78, 0.66, 0.38))


func choose(what: String) -> void:
	match what:
		"board":
			_open_board()
		"kettle":
			jack.career_sleep()
			_save_career()
			career = jack.career_state()
			_said = "morning. day %d." % (int(career.get("day", 0)) + 1)
		"shed":
			_open_shed()
		"engine":
			_buy_part()
		"steam":
			_steam_her()


# --- the shed ---------------------------------------------------------------------------------
#
# Two things, and neither of them is an upgrade: both cost you something. Gloves save your hands
# and blunt your ear for a joint. A chair takes twenty seconds to rig and £75 out of the tin, and
# in exchange you can sit down fifty metres up and work until the light goes.
#
# It exists at all because the verbs it unlocks were unreadable without it. A stance you reach by
# pressing Q until something happens is a stance nobody understands; one you paid for, and then
# chose to put on the cart, is one you know the name of before you ever rig it.

## Ladder sections come first because they are the only thing in here you *have* to buy. The two
## below are choices; sections are the difference between a job you can take and one you cannot.
const SHED := ["ladderSection", "gloves", "bosunsChair"]
const SHED_NAME := {"ladderSection": "A ladder section", "gloves": "A pair of gloves",
	"bosunsChair": "A bosun's chair"}
const SHED_WHY := {
	"ladderSection": "five metres of her. A chimney you have not the sections for is one you cannot take",
	"gloves": "less grip going out of you — and a tier worse at reading a joint by sound",
	"bosunsChair": "sit in it and work. No grip going out at all, and 20 s to rig on the stack",
}

var shed_open := false
var shed_row := 0


func _open_shed() -> void:
	shed_open = true
	shed_row = 0
	_said = ""


func shed_choose() -> void:
	var item: String = SHED[shed_row]
	if item == "ladderSection":
		# Stock, not a one-off. You buy them by the section and you keep them.
		if not jack.career_buy_ladders(1):
			_said = "£%.0f short of another section." % (
				jack.career_kit_cost(item) - float(career.get("money", 0.0)))
			return
		_save_career()
		career = jack.career_state()
		_said = "£%.0f. that is %d sections in the yard." % [
			jack.career_kit_cost(item), jack.career_ladders()]
		return
	if jack.career_owns(item):
		# Owned kit is loaded in the van, not here. Two screens that both decide the same thing is
		# how a player ends up certain they took the chair and arrives without it.
		_said = "you have one. whether it goes up is decided at the van."
		return
	var cost: float = jack.career_kit_cost(item)
	if not jack.career_buy_kit(item):
		_said = "£%.0f short of it." % (cost - float(career.get("money", 0.0)))
		return
	_save_career()
	career = jack.career_state()
	_said = "£%.0f. it's on the cart." % cost


## One part at a time, and refused rather than allowed into debt. A job cannot leave you owing
## money (Career.h) and neither can a boiler tube.
func _buy_part() -> void:
	if engine_done():
		_said = "she's finished. you could steam her."
		return
	var cost := next_part_cost()
	if not jack.career_buy_engine_part(cost):
		_said = "£%.0f short of the next piece." % (cost - float(career.get("money", 0.0)))
		return
	_save_career()
	career = jack.career_state()
	_build_rows()
	var i := stage_index()
	_said = ("that's her done." if engine_done()
		else "£%.0f. %s." % [cost, String(stages[maxi(i, 0)].get("name", "a part"))])


func _steam_her() -> void:
	var packed: PackedScene = load("res://scenes/ending.tscn")
	if packed == null:
		push_error("yard: cannot load the ending")
		return
	var ending: Node = packed.instantiate()
	ending.career_path = career_path
	get_tree().root.add_child(ending)
	get_tree().current_scene = ending
	queue_free()


func _open_board() -> void:
	var packed: PackedScene = load(BOARD_SCENE)
	if packed == null:
		push_error("yard: cannot load %s" % BOARD_SCENE)
		return
	var board: Node = packed.instantiate()
	board.career_path = career_path
	get_tree().root.add_child(board)
	get_tree().current_scene = board
	queue_free()


# --- geometry, shared by the drawing and the hit-testing -------------------------------------------

func _rows_origin() -> Vector2:
	return Vector2(size.x * 0.08, size.y * 0.44)


## One station's panel. Geometry the drawing and the clicking SHARE, so a panel cannot be moved
## without its hit box coming with it — the job board shipped without that once and every click on
## a card fell through to nothing.
func row_rect(i: int) -> Rect2:
	var at := _rows_origin()
	return Rect2(Vector2(at.x - 26.0, at.y + ROW_GAP * float(i) - 30.0), Vector2(428.0, 52.0))


func row_at(p: Vector2) -> int:
	for i in rows.size():
		if row_rect(i).has_point(p):
			return i
	return -1


# --- drawing ---------------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SKY)
	_draw_yard()
	_draw_header()

	# The stations hang. Each one is tied to the one above it and the top one is tied to the sky,
	# which is a ladder stack — the shape this whole game is about — and it is also the rule the
	# man obeys: nothing here floats, and you are only ever as safe as the thing you tied to.
	#
	# What this replaces was one flat grey box laid across the middle of the screen, over the
	# skyline, which is the single image the yard exists to show you.
	var at := _rows_origin()
	for i in rows.size():
		var y: float = at.y + ROW_GAP * float(i)
		var on: bool = i == selected
		var box := row_rect(i)
		var tie_x: float = box.position.x + 26.0
		# The line it hangs from: the bottom of the panel above, or the sky for the first one.
		var from_y: float = row_rect(i - 1).end.y if i > 0 else at.y - 96.0
		draw_line(Vector2(tie_x, from_y), Vector2(tie_x, box.position.y),
			Color(WATCH.r, WATCH.g, WATCH.b, 0.55) if on else Color(GHOST.r, GHOST.g, GHOST.b, 0.34),
			1.0)
		if i == 0:
			# The dog it is all hung off. One shape, and it is the shape the whole game turns on.
			draw_line(Vector2(tie_x - 7.0, from_y), Vector2(tie_x + 7.0, from_y),
				Color(WATCH.r, WATCH.g, WATCH.b, 0.6), 2.0)

		draw_rect(box, Color(0.05, 0.05, 0.06, 0.66 if on else 0.40))
		# The heavy edge is along the TOP, because that is the edge carrying the weight.
		draw_rect(Rect2(box.position, Vector2(box.size.x, 2.0)),
			Color(WATCH.r, WATCH.g, WATCH.b, 0.9) if on
			else Color(GHOST.r, GHOST.g, GHOST.b, 0.22))

		_label(String(rows[i][1]), Vector2(at.x, y), INK if on else Color(DIM, 0.7), 24)
		var note := String(rows[i][2])
		if String(rows[i][0]) == "engine":
			note = _engine_note()
		_label(note, Vector2(at.x, y + 16.0), Color(GHOST, 0.85 if on else 0.55), 13)

	if _said != "" and not shed_open:
		_label(_said, Vector2(at.x, size.y - 62.0), Color(WATCH, 0.9), 16)
	_label("↑↓ or the mouse   ·   enter", Vector2(at.x, size.y - 36.0), Color(GHOST, 0.7), 13)

	if shed_open:
		_draw_shed()


func _engine_note() -> String:
	if stages.is_empty():
		return "under a tarpaulin"
	if engine_done():
		return "finished — every part of her"
	var i := stage_index()
	var bought: int = int(career.get("engine_parts", 0))
	var total := 0
	for st in stages:
		total += int(st.get("parts", 0))
	return "%s  ·  %d of %d pieces  ·  next £%.0f" % [
		String(stages[i].get("name", "")), bought, total, next_part_cost()]


func _draw_header() -> void:
	var x: float = size.x * 0.08
	_label("THE YARD", Vector2(x, 76.0), Color(GHOST, 0.75), 13)
	_label("£%.0f" % float(career.get("money", 0.0)), Vector2(x, 122.0), INK, 46)
	var stars := int(career.get("stars", 0))
	var s := ""
	for i in 5:
		s += "★" if i < stars else "☆"
	_label(s, Vector2(x, 154.0), Color(WATCH, 0.9), 20)
	_label("day %d" % (int(career.get("day", 0)) + 1), Vector2(x + 132.0, 154.0),
		Color(DIM, 0.8), 16)
	var jobs: Array = career.get("jobs", []) as Array
	_label("%d job%s done" % [jobs.size(), "" if jobs.size() == 1 else "s"],
		Vector2(x + 220.0, 154.0), Color(DIM, 0.8), 16)


## A back yard at night: a wall, a fire in a brazier, and a shape under a tarpaulin that gets a
## little less shapeless every time you buy a piece of it.
func _draw_yard() -> void:
	var ground: float = size.y * 0.72
	# Night, and the town behind the wall.
	for i in 22:
		var f: float = float(i) / 21.0
		draw_rect(Rect2(Vector2(0.0, size.y * 0.02 * float(i)), Vector2(size.x, size.y * 0.03)),
			SKY.lerp(Color(0.44, 0.40, 0.38), f * 0.65))
	_draw_town(ground - 190.0)
	draw_rect(Rect2(Vector2(0.0, ground), Vector2(size.x, size.y - ground)), FLAG)
	draw_rect(Rect2(Vector2(0.0, ground - 190.0), Vector2(size.x, 190.0)), WALL)
	# The coping, and a shadow under it. Without them the wall and the flags were two greys
	# meeting, and the yard did not read as a place you are standing in.
	draw_rect(Rect2(Vector2(0.0, ground - 196.0), Vector2(size.x, 7.0)), Color(0.31, 0.26, 0.22))
	draw_rect(Rect2(Vector2(0.0, ground - 189.0), Vector2(size.x, 9.0)), Color(0.0, 0.0, 0.0, 0.22))
	draw_rect(Rect2(Vector2(0.0, ground - 10.0), Vector2(size.x, 10.0)), Color(0.0, 0.0, 0.0, 0.25))
	# Courses, so the wall is brick rather than a block of colour.
	for i in 11:
		var y: float = ground - 190.0 + float(i) * 17.0
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(0.0, 0.0, 0.0, 0.10), 1.0)

	# The brazier, and the only warm light in the game.
	var fx: float = size.x * 0.30
	var flick: float = 0.85 + 0.15 * sin(_t * 5.3) + 0.06 * sin(_t * 11.0)
	for g in 7:
		var gf: float = 1.0 - float(g) / 7.0
		draw_circle(Vector2(fx, ground - 18.0), (10.0 + 52.0 * gf) * flick,
			Color(FIRE, 0.045 * (1.0 - gf) + 0.02))
	draw_rect(Rect2(Vector2(fx - 15.0, ground - 22.0), Vector2(30.0, 22.0)), Color(0.13, 0.11, 0.10))

	_draw_engine(Vector2(size.x * 0.68, ground), 1.0)
	_draw_salvage(ground)


## The skyline, over the yard wall, and the reason this screen exists at all.
##
## A chimney for every job in the district — and a stump for every one you have already taken down.
## 19-the-complete-game.md says the melancholy is that the world shrinks as you get better at your
## job, and that the game should not soften it. This is that sentence as a picture, visible from
## the one place in the game where nothing is trying to kill you.
func _draw_town(base: float) -> void:
	var done := {}
	for j in (career.get("jobs", []) as Array):
		done[String((j as Dictionary).get("id", ""))] = true

	# What you DID to her, not merely that you were paid for her.
	#
	# This used to be `i < felled.size()` — the count of every job in the career, so surveying a
	# chimney took it off the skyline and running a lightning conductor down one demolished it.
	# The picture this screen exists to make is that the trade destroys the world it lives in, and
	# it is not worth making if it is not true: a jack who spends a career on conductors and bands
	# leaves the town exactly as he found it, and should be shown a full skyline.
	var town: Array = District.levels()
	for i in town.size():
		var lvl: Dictionary = town[i]
		var arch := String(lvl.get("archetype", ""))
		var was_done: bool = done.has(String(lvl.get("id", "")))
		var seed_x: float = absf(fmod(sin(float(i * 53 + 7)) * 43758.5453, 1.0))
		var seed_h: float = absf(fmod(sin(float(i * 29 + 3)) * 24634.6345, 1.0))
		var x: float = size.x * (0.05 + 0.90 * seed_x)
		var full: float = 74.0 + 150.0 * seed_h

		var state := District.state(arch, was_done)
		var felled: bool = state == "felled"
		var shortened: bool = state == "shortened"
		var h: float = full
		if felled:
			# Not nothing: a felled chimney leaves a base and a heap, and the heap is the point.
			h = 24.0
		elif shortened:
			h = full * 0.68

		var col := Color(0.19, 0.16, 0.15, 0.9) if felled else Color(0.15, 0.13, 0.13, 0.95)
		var w: float = maxf(full / 11.5, 6.0)
		var top_w: float = w * 0.70
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w * 0.5, base), Vector2(x + w * 0.5, base),
			Vector2(x + top_w * 0.5, base - h), Vector2(x - top_w * 0.5, base - h)]), col)
		# A stack you have topped has no cap on it any more — you took it off to get at her, and
		# the new one is the client's business. That missing cap is the whole tell.
		if not felled and not shortened:
			draw_rect(Rect2(Vector2(x - top_w * 0.5 - 3.0, base - h - 5.0),
				Vector2(top_w + 6.0, 5.0)), col)
		if felled:
			# The spoil, spread where she fell.
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - w * 1.9, base), Vector2(x + w * 1.9, base),
				Vector2(x + w * 0.9, base - 9.0), Vector2(x - w * 1.1, base - 11.0)]),
				Color(0.17, 0.14, 0.13, 0.9))
			_chalk_cross(Vector2(x, base - 26.0), 13.0)


## The mark a jack makes on a thing he has finished with. Two strokes, drawn rather than typed,
## and the same glyph everywhere in this game: a joint that is gone, a job that is done, a chimney
## that is not there any more.
func _chalk_cross(at: Vector2, r: float) -> void:
	var c := Color(0.86, 0.38, 0.28, 0.72)
	draw_line(at + Vector2(-r, -r), at + Vector2(r, r), c, 2.4)
	draw_line(at + Vector2(r, -r), at + Vector2(-r, r), c, 2.4)


## The shelf against the wall, and what is on it.
##
## One thing off every job, and none of it bought. 19-the-complete-game.md: "twelve objects, and
## the yard is a museum of a trade that no longer exists, assembled by the man who ended it." It is
## the counterweight to the engine — that is the thing you buy, this is the thing you remember —
## and between them they are the only two things in this game that get bigger.
func _draw_salvage(ground: float) -> void:
	var kept: Array = jack.career_salvage()
	if kept.is_empty():
		return
	# Clear of the menu panel on the left and the engine on the right; the yard has three
	# things in it and they should not be standing on each other.
	var shelf := Vector2(size.x * 0.31, ground - 70.0)
	var w: float = 44.0 * float(mini(kept.size(), 9))
	draw_rect(Rect2(shelf, Vector2(w + 18.0, 5.0)), Color(0.30, 0.24, 0.19))
	draw_rect(Rect2(shelf + Vector2(0.0, 5.0), Vector2(w + 18.0, 4.0)), Color(0.0, 0.0, 0.0, 0.25))

	for i in mini(kept.size(), 9):
		var what := String((kept[i] as Dictionary).get("what", ""))
		var x: float = shelf.x + 14.0 + 44.0 * float(i)
		var base := Vector2(x, shelf.y)
		# Each one drawn as the thing it is. A brick is a brick and a bolt is a bolt; nothing here
		# is an icon of a category.
		if what.contains("copper"):
			draw_arc(base + Vector2(9.0, -12.0), 10.0, 0.0, TAU, 16, Color(0.72, 0.45, 0.24), 3.0)
			draw_arc(base + Vector2(9.0, -12.0), 5.0, 0.0, TAU, 12, Color(0.72, 0.45, 0.24), 2.5)
		elif what.contains("bolt"):
			draw_rect(Rect2(base + Vector2(6.0, -22.0), Vector2(6.0, 22.0)), Color(0.38, 0.25, 0.18))
			draw_rect(Rect2(base + Vector2(2.0, -26.0), Vector2(14.0, 6.0)), Color(0.42, 0.29, 0.21))
		elif what.contains("wedge"):
			draw_colored_polygon(PackedVector2Array([
				base + Vector2(2.0, 0.0), base + Vector2(20.0, 0.0),
				base + Vector2(6.0, -24.0)]), Color(0.62, 0.60, 0.56))
		else:
			# A brick, chalked or picked up off the ground.
			draw_rect(Rect2(base + Vector2(1.0, -13.0), Vector2(20.0, 13.0)), Color(0.50, 0.28, 0.21))
			if what.contains("chalk"):
				draw_line(base + Vector2(4.0, -9.0), base + Vector2(16.0, -9.0),
					Color(0.90, 0.88, 0.82, 0.9), 2.0)

	_label("%d thing%s off %d job%s" % [kept.size(), "" if kept.size() == 1 else "s",
		kept.size(), "" if kept.size() == 1 else "s"],
		shelf + Vector2(0.0, 30.0), Color(GHOST, 0.65), 12)


## The engine. Under a tarpaulin at first — a shapeless lump with a wheel showing — and revealed a
## stage at a time as it is paid for. It has no mechanical benefit of any kind, which is the whole
## point of it.
func _draw_engine(at: Vector2, scale: float) -> void:
	# How much of her is REVEALED is how much of her is bought, not which stage she is up to. The
	# first stage is "strip and assess" and has no parts in it, so keying the drawing off the stage
	# index showed a brand-new career a pair of wheels it had not paid for.
	var bought: int = int(career.get("engine_parts", 0))
	var done := 0
	var seen := 0
	for st in stages:
		var need: int = int(st.get("parts", 0))
		if need <= 0:
			continue
		seen += need
		if bought >= seen:
			done += 1
		else:
			break
	var w := 300.0 * scale
	var h := 150.0 * scale

	if done <= 0:
		# Under the sheet: a lump, and one wheel rim too proud to hide.
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-w * 0.5, 0.0), at + Vector2(-w * 0.44, -h * 0.62),
			at + Vector2(-w * 0.1, -h * 0.78), at + Vector2(w * 0.22, -h * 0.58),
			at + Vector2(w * 0.5, -h * 0.2), at + Vector2(w * 0.5, 0.0)]),
			Color(0.26, 0.25, 0.22))
		draw_arc(at + Vector2(-w * 0.26, -h * 0.20), h * 0.24, PI, TAU, 18, Color(RUST, 0.8), 3.0)
		_label("under a tarpaulin", at + Vector2(-w * 0.5, 26.0), Color(GHOST, 0.5), 13)
		return

	# Wheels first, then boiler, then motion, then brasswork, then chimney and paint — in the order
	# they are bought, so the yard shows you what your money did. The six part-bearing stages in
	# economy.json are the six things that appear, and the seventh, the boiler certificate, puts
	# her nameplate on: she is not finished until somebody official says she may be lit.
	#
	# She is the only thing in this game that gets BIGGER, and the one object with real colour on
	# it. Drawn as a rectangle, two circles and a stick she was a diagram of a reward rather than
	# one, which for £9,000 and a whole career is not enough of a thing to want.
	var green: bool = done >= 5
	var body := GREEN if green else RUST
	var iron := Color(0.30, 0.28, 0.26, 0.95)
	var brass := Color(0.85, 0.72, 0.36, 0.95)
	var rear := h * 0.42
	var front := h * 0.21
	var rear_c := at + Vector2(-w * 0.24, -rear)
	var front_c := at + Vector2(w * 0.32, -front)

	# --- 1: wheels and axles --------------------------------------------------------------------
	_wheel(rear_c, rear, 12, body, 5.0 * scale)
	_wheel(front_c, front, 8, body, 4.0 * scale)
	# The hornplates: the iron sides she is all built on, and the reason the wheels line up.
	draw_rect(Rect2(at + Vector2(-w * 0.34, -h * 0.50), Vector2(w * 0.66, h * 0.08)),
		Color(iron.r, iron.g, iron.b, 0.9))

	if done < 2:
		_label("under restoration  ·  wheels and axles", at + Vector2(-w * 0.5, 26.0),
			Color(GHOST, 0.6), 13)
		return

	# --- 2: the boiler --------------------------------------------------------------------------
	# The barrel, the smokebox at the front and the firebox at the back: a traction engine is a
	# boiler that happens to have wheels on it, and until it is there she is a cart.
	draw_rect(Rect2(at + Vector2(-w * 0.22, -h * 0.80), Vector2(w * 0.46, h * 0.30)),
		Color(body, 0.95))
	draw_rect(Rect2(at + Vector2(w * 0.20, -h * 0.86), Vector2(w * 0.10, h * 0.36)),
		Color(body.darkened(0.18), 0.95))
	draw_rect(Rect2(at + Vector2(-w * 0.40, -h * 0.90), Vector2(w * 0.20, h * 0.40)),
		Color(body.darkened(0.10), 0.95))

	# --- 3: the motion ---------------------------------------------------------------------------
	# The flywheel is the thing you watch, so it is the thing that has to be there.
	if done >= 3:
		var fly := at + Vector2(-w * 0.02, -h * 0.60)
		_wheel(fly, h * 0.26, 8, iron, 4.0 * scale)
		var crank := fly + Vector2(cos(-0.7), sin(-0.7)) * h * 0.18
		draw_line(crank, at + Vector2(w * 0.20, -h * 0.66), Color(0.74, 0.70, 0.62, 0.95),
			3.5 * scale)
		# The crosshead, sliding on its bars above the boiler.
		draw_rect(Rect2(at + Vector2(w * 0.17, -h * 0.70), Vector2(w * 0.05, h * 0.06)), iron)

	# --- 4: gauges, injector, brasswork ----------------------------------------------------------
	if done >= 4:
		# The steam dome and the safety valve, which are the two brass things on any engine you
		# can see from across a yard.
		draw_arc(at + Vector2(-w * 0.06, -h * 0.80), h * 0.10, PI, TAU, 14, brass, 4.0 * scale)
		draw_rect(Rect2(at + Vector2(-w * 0.34, -h * 0.98), Vector2(w * 0.05, h * 0.09)), brass)
		draw_circle(at + Vector2(-w * 0.26, -h * 0.74), 4.0 * scale, brass)

	# --- 5: canopy, chimney, paint ----------------------------------------------------------------
	if done >= 5:
		# The chimney, with its cap. She is a chimney on wheels, in a game about chimneys, and
		# that is not an accident anybody planned but it is certainly the right object.
		draw_rect(Rect2(at + Vector2(w * 0.22, -h * 1.30), Vector2(w * 0.06, h * 0.46)),
			Color(iron.r, iron.g, iron.b, 0.95))
		draw_rect(Rect2(at + Vector2(w * 0.19, -h * 1.36), Vector2(w * 0.12, h * 0.08)),
			Color(iron.r, iron.g, iron.b, 0.95))
		# The canopy over the footplate, on its posts.
		draw_rect(Rect2(at + Vector2(-w * 0.46, -h * 1.26), Vector2(w * 0.34, h * 0.05)),
			Color(body, 0.95))
		draw_rect(Rect2(at + Vector2(-w * 0.44, -h * 1.26), Vector2(3.0 * scale, h * 0.36)),
			Color(body, 0.9))
		draw_rect(Rect2(at + Vector2(-w * 0.16, -h * 1.26), Vector2(3.0 * scale, h * 0.36)),
			Color(body, 0.9))
		# The lining out. One red line down the length of her is what turns a green machine into a
		# finished one, and it is the last thing anybody does.
		draw_line(at + Vector2(-w * 0.22, -h * 0.66), at + Vector2(w * 0.24, -h * 0.66),
			Color(0.80, 0.24, 0.20, 0.95), 2.5 * scale)
		draw_line(at + Vector2(-w * 0.40, -h * 0.84), at + Vector2(-w * 0.20, -h * 0.84),
			Color(0.80, 0.24, 0.20, 0.95), 2.0 * scale)

	# --- 6: the certificate -----------------------------------------------------------------------
	if engine_done():
		# Her plate. She may be lit.
		draw_rect(Rect2(at + Vector2(-w * 0.14, -h * 0.72), Vector2(w * 0.16, h * 0.10)), brass)
		_label("in steam", at + Vector2(-w * 0.5, 26.0), Color(GOOD, 0.85), 13)
	else:
		var st_name := String(stages[mini(stage_index(), stages.size() - 1)].get("name", ""))
		_label("under restoration  ·  %s" % st_name.to_lower(),
			at + Vector2(-w * 0.5, 26.0), Color(GHOST, 0.6), 13)


## One wheel: a rim, a hub and spokes between them. A traction engine's rear wheel is most of what
## she looks like from the side, and two circles were not it.
func _wheel(c: Vector2, r: float, spokes: int, col: Color, rim: float) -> void:
	draw_arc(c, r, 0.0, TAU, 34, col, rim)
	draw_arc(c, r * 0.20, 0.0, TAU, 12, col, rim * 0.8)
	for i in spokes:
		var a: float = TAU * float(i) / float(spokes)
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * r * 0.20, c + d * (r - rim * 0.5), col, maxf(rim * 0.35, 1.0))


func _label(text: String, at: Vector2, col: Color, px: int) -> void:
	for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_string(_font, at + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
			Color(0, 0, 0, col.a * 0.55))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
