## The job board — the front of the game.
##
## Two modes had grown up not knowing about each other: one `make` target climbed a chimney and
## another felled one, and nothing joined them. This is the join. It is a board with letters pinned
## to it, one for every level in `data/levels/`, and picking one starts the right scene with that
## level in it — a SURVEY job opens the climb, a FELL job opens the felling.
##
## It reads the level files and nothing else. A new level appears here by existing, which is the
## same property that makes "idea to playable in under thirty minutes" true of everything else
## (AGENTS.md, "Adding things").
extends Control

const LEVELS_DIR := "res://../data/levels"
const CLIMB_SCENE := "res://scenes/steeplejack.tscn"
const FELL_SCENE := "res://scenes/felling.tscn"

const PAPER := Color(0.88, 0.85, 0.78)
const INK := Color(0.16, 0.14, 0.12)
const FADED := Color(0.16, 0.14, 0.12, 0.6)
const RED_INK := Color(0.55, 0.18, 0.14)
const BOARD := Color(0.20, 0.17, 0.14)
const PIN := Color(0.72, 0.28, 0.20)

const CARD_W := 430.0
const CARD_GAP := 26.0

## The tin. Text, in the user directory, like everything else this game persists.
const CAREER_PATH := "user://career.json"

## Where the tin lives; a test points this somewhere else so it does not spend real money.
var career_path := CAREER_PATH

var jobs: Array = []
var selected := 0
var career := {}

@onready var jack: Jack = Jack.new()

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	jack.load(ProjectSettings.globalize_path("res://../data/tuning"),
		ProjectSettings.globalize_path("res://../data/levels/00-greybox.json"))
	load_career()
	jobs = _read_jobs()
	set_process_input(true)
	queue_redraw()


## Every level file, in the order a career would meet them. The grey box sorts last because its
## order is 99 — it is a tool, not a job, and the file says so.
func _read_jobs() -> Array:
	var out: Array = []
	var dir := DirAccess.open(ProjectSettings.globalize_path(LEVELS_DIR))
	if dir == null:
		push_error("jobs: no %s" % LEVELS_DIR)
		return out
	for name in dir.get_files():
		if not name.ends_with(".json"):
			continue
		var f := FileAccess.open(
			"%s/%s" % [ProjectSettings.globalize_path(LEVELS_DIR), name], FileAccess.READ)
		if f == null:
			continue
		var doc = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(doc) != TYPE_DICTIONARY:
			continue
		out.append({
			"id": String(doc.get("id", name.get_basename())),
			"name": String(doc.get("name", "")),
			"order": int(_num(doc.get("order"), 99.0)),
			"archetype": String(doc.get("archetype", "SURVEY")),
			"fee": int(_num(doc.get("fee"), 0.0)),
			"gate": int(_num(doc.get("reputationGate"), 0.0)),
			"shift": int(_num(doc.get("shiftMinutes"), 0.0)),
			"height": _num(doc.get("structure", {}).get("height"), 0.0),
			"briefing": doc.get("briefing", {}),
			"strip_out": not (doc.get("mission", {}).get("stripOut", []) as Array).is_empty(),
		})
	out.sort_custom(func(a, b): return int(a["order"]) < int(b["order"]))
	return out


## A number out of a level file, which may legitimately be `null`. The grey box has no shift —
## it is a tool, not a job — and `int(null)` is a crash, which took the whole board down with it.
func _num(v, fallback: float) -> float:
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return fallback


## Read the tin. A missing one is a new career, not an error — the first time anyone plays, there
## is no file, and that is the normal case rather than the exception.
func load_career() -> void:
	var text := ""
	if FileAccess.file_exists(career_path):
		var f := FileAccess.open(career_path, FileAccess.READ)
		if f != null:
			text = f.get_as_text()
			f.close()
	jack.career_load(text)
	career = jack.career_state()


func save_career() -> void:
	var f := FileAccess.open(career_path, FileAccess.WRITE)
	if f == null:
		push_error("jobs: cannot write %s" % career_path)
		return
	f.store_string(jack.career_json())
	f.close()


## Whether the letter has arrived. The gate is in the level file and the answer is in the sim —
## a .gd file deciding what the player is allowed to do would be a rule in the wrong layer.
##
## A gate you could not reach even by doing every job that exists is not locked, it is a gap: the
## levels that would have earned it are designed and have no data yet. Those are offered, with the
## reason on the card, and they will start enforcing themselves the moment the levels between land.
func locked(job: Dictionary) -> bool:
	if jack.career_can_take(int(job["gate"])):
		return false
	return int(job["gate"]) <= _reachable_stars()


## Marked on the card so the player is not left wondering which kind of closed door this is.
func unearnable(job: Dictionary) -> bool:
	return not jack.career_can_take(int(job["gate"])) and int(job["gate"]) > _reachable_stars()


func _reachable_stars() -> int:
	var ids := []
	for job in jobs:
		ids.append(String(job["id"]))
	return int(jack.career_reachable_stars(ids))


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_DOWN, KEY_S, KEY_RIGHT, KEY_D:
			selected = (selected + 1) % maxi(jobs.size(), 1)
			queue_redraw()
		KEY_UP, KEY_W, KEY_LEFT, KEY_A:
			selected = (selected - 1 + maxi(jobs.size(), 1)) % maxi(jobs.size(), 1)
			queue_redraw()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_take_it()
		KEY_ESCAPE:
			get_tree().quit()


## Which half of the game a job belongs to. A chimney you are surveying is one you climb; a chimney
## you are felling is one you stand at the foot of. Pulled out of `_take_it` so it can be checked
## without starting a scene — a FELL job opening the climb would be a silent and very confusing
## failure, and it is exactly the kind that never gets tested because testing it looks expensive.
func scene_for(job: Dictionary) -> String:
	if String(job.get("archetype", "")) != "FELL":
		return CLIMB_SCENE
	# A felling is two visits. Until her bands are off and her conductor is down she is a climb,
	# and the board sends you where the work actually is rather than making you guess which
	# half of the game today is.
	if bool(job.get("strip_out", false)) and not jack.career_stripped(String(job["id"])):
		return CLIMB_SCENE
	return FELL_SCENE


## Start the job.
func _take_it() -> void:
	if jobs.is_empty():
		return
	var job: Dictionary = jobs[selected]
	if locked(job):
		return
	var packed: PackedScene = load(scene_for(job))
	# On the tree root rather than on the scene, because the climbing scene's root is a plain
	# Node3D with no script on it and the felling scene's is not. One way in for both.
	get_tree().root.set_meta("job_level", String(job["id"]))
	var world: Node = packed.instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BOARD)
	draw_string(_font, Vector2(48, 58), "STEEPLEJACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, PAPER)
	draw_string(_font, Vector2(48, 88), "work going, as it comes in",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(PAPER.r, PAPER.g, PAPER.b, 0.55))

	# The tin, and what anyone thinks of you.
	var stars := ""
	for s in 5:
		stars += "*" if s < int(career.get("stars", 0)) else "."
	draw_string(_font, Vector2(size.x - 330, 58),
		"£%d in the tin        %s" % [int(float(career.get("money", 0.0))), stars],
		HORIZONTAL_ALIGNMENT_RIGHT, 282, 16, PAPER)

	var y := 130.0
	for i in jobs.size():
		y = _card(jobs[i], 48.0, y, i == selected)

	draw_string(_font, Vector2(48, size.y - 36),
		"up / down to look through them    enter to take it    esc to leave it",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(PAPER.r, PAPER.g, PAPER.b, 0.5))

	if selected < jobs.size():
		_letter(jobs[selected], 48.0 + CARD_W + 60.0, 130.0)


## One job, as a card pinned to the board. Returns the y to carry on from.
func _card(job: Dictionary, x: float, y: float, here: bool) -> float:
	var felling: bool = String(job["archetype"]) == "FELL"
	var shut: bool = locked(job)
	var done: bool = jack.career_done(String(job["id"]))
	var h := 92.0
	var card := Rect2(x, y, CARD_W, h)
	var face := Color(PAPER.r, PAPER.g, PAPER.b, 0.30 if shut else (1.0 if here else 0.72))
	draw_rect(card, face)
	if here:
		draw_rect(Rect2(x - 3, y - 3, CARD_W + 6, h + 6), PIN, false, 2.0)
	draw_circle(Vector2(x + CARD_W - 18, y + 16), 5.0, PIN)

	draw_string(_font, Vector2(x + 16, y + 30), String(job["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
	# The grey box has no shift, because it is a tool and not a job.
	var shift := "untimed" if int(job["shift"]) <= 0 else "%d min" % int(job["shift"])
	if not shut and not unearnable(job):
		draw_string(_font, Vector2(x + 16, y + 52),
			"%s   %.0f m   %s" % ["FELLING" if felling else "SURVEY", job["height"], shift],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RED_INK if felling else FADED)
	var fee := "no fee — a favour" if int(job["fee"]) <= 0 else "£%d" % int(job["fee"])
	if done:
		fee += "   (done)"
	elif String(job["archetype"]) == "FELL" and bool(job.get("strip_out", false)):
		fee += "   (strip her out)" if not jack.career_stripped(String(job["id"])) \
			else "   (stripped — go and cut her)"
	draw_string(_font, Vector2(x + 16, y + 74), fee, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(INK.r, INK.g, INK.b, 0.45) if shut else INK)
	if shut:
		draw_string(_font, Vector2(x + 16, y + 52),
			"they will not give this to a %d-star jack" % int(career.get("stars", 0)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RED_INK)
	elif unearnable(job):
		draw_string(_font, Vector2(x + 16, y + 52),
			"%s   %.0f m   %s" % ["FELLING" if felling else "SURVEY", job["height"], shift],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RED_INK if felling else FADED)
		draw_string(_font, Vector2(x + CARD_W - 120, y + 30), "above your name",
			HORIZONTAL_ALIGNMENT_RIGHT, 104, 11, Color(0.45, 0.40, 0.30))
	if int(job["gate"]) > 0:
		var stars := ""
		for s in 5:
			stars += "*" if s < int(job["gate"]) else "."
		draw_string(_font, Vector2(x + CARD_W - 78, y + 74), stars,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, FADED)
	return y + h + CARD_GAP


## The letter that came with it, which is where the job is actually described. The level files
## carry it so this board and the design docs cannot drift apart.
func _letter(job: Dictionary, x: float, y: float) -> void:
	var w: float = size.x - x - 48.0
	var briefing: Dictionary = job["briefing"]
	var lines: Array = briefing.get("lines", [])
	var h: float = 130.0 + float(lines.size()) * 22.0
	draw_rect(Rect2(x, y, w, h), PAPER)
	draw_string(_font, Vector2(x + 26, y + 40), String(job["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 19, INK)
	var ly := y + 74.0
	for line in lines:
		draw_string(_font, Vector2(x + 26, ly), String(line), HORIZONTAL_ALIGNMENT_LEFT,
			int(w - 52), 14, INK)
		ly += 22.0
	var who := String(briefing.get("from", ""))
	if who != "":
		draw_string(_font, Vector2(x + 26, ly + 14), "— %s" % who,
			HORIZONTAL_ALIGNMENT_RIGHT, int(w - 52), 13, FADED)
	# Say which kind of closed door this is, where there is room to say it properly.
	if unearnable(job):
		draw_string(_font, Vector2(x + 26, ly + 44),
			"This is above your name — but the jobs that would have earned it are designed and not "
			+ "built yet, so it is yours to try.",
			HORIZONTAL_ALIGNMENT_LEFT, int(w - 52), 12, Color(0.42, 0.30, 0.16))
	elif locked(job):
		draw_string(_font, Vector2(x + 26, ly + 44),
			"They will not give this to a %d-star jack. Take smaller work first."
				% int(career.get("stars", 0)),
			HORIZONTAL_ALIGNMENT_LEFT, int(w - 52), 12, RED_INK)
