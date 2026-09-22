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

## The van. Enter on a job opens it rather than departing, because what you load is the last
## decision of the yard and the first one of the job: twelve ladders for a 55 m chimney commits you
## to spans you have to live with all day, and sixteen is ten more minutes on the rope.
var van_open := false
var van_row := 0
var van_ladders := 0
var van_dogs := 0
var van_said := ""
## Two numbers you set, and then the kit — which is a different kind of decision and reads like
## one: a number goes up and down, a thing is either on the cart or it is not.
##
## Kit on the cart is what makes the verbs that use it legible. The bosun's chair was a stance you
## could reach by pressing Q four times on any job, on any chimney, having never heard of one; now
## it is £75 in the yard and a line on this screen, and by the time you rig one you know what it is
## and why you are carrying it up a chimney.
const VAN_ROWS := ["ladders", "dogs", "gloves", "bosunsChair"]
const KIT_ROWS := ["gloves", "bosunsChair"]
const KIT_NAME := {"gloves": "Gloves", "bosunsChair": "Bosun's chair"}
const KIT_WHY := {
	"gloves": "less out of your hands, and you read the joints a tier worse",
	"bosunsChair": "sit down and work — no grip going out at all. 20 s to rig",
}

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
			"ladders": int(_num((doc.get("loadoutHint", {}) as Dictionary).get("ladders"), 12.0)),
			"dogs": int(_num((doc.get("loadoutHint", {}) as Dictionary).get("dogs"), 24.0)),
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
	if van_open and (event is InputEventMouseButton or event is InputEventMouseMotion):
		var hit: Dictionary = van_hit(event.position)
		if not hit.is_empty():
			van_row = int(hit["row"])
			if event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT and int(hit["step"]) != 0:
				van_step(int(hit["step"]))
		queue_redraw()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if van_open:
		_van_key(event.keycode)
		queue_redraw()
		return
	match event.keycode:
		KEY_DOWN, KEY_S, KEY_RIGHT, KEY_D:
			selected = (selected + 1) % maxi(jobs.size(), 1)
			queue_redraw()
		KEY_UP, KEY_W, KEY_LEFT, KEY_A:
			selected = (selected - 1 + maxi(jobs.size(), 1)) % maxi(jobs.size(), 1)
			queue_redraw()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			open_van()
		KEY_ESCAPE:
			# Back to the yard rather than out of the game. Escape quitting the process from the
			# middle of a career is the kind of thing that only ever happens by accident.
			var yard: Node = load("res://scenes/yard.tscn").instantiate()
			yard.career_path = career_path
			get_tree().root.add_child(yard)
			get_tree().current_scene = yard
			queue_free()


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


## Load the van for this job. Defaults to what the level packed — the reachability gate proves the
## top can be reached with that many ladders, so it is the only number the game can promise.
func open_van() -> void:
	if jobs.is_empty():
		return
	var job: Dictionary = jobs[selected]
	if locked(job):
		return
	van_ladders = maxi(int(job.get("ladders", 0)), 1)
	van_dogs = maxi(int(job.get("dogs", 0)), 1)
	van_row = 0
	van_said = ""
	van_open = true


func _van_key(key: int) -> void:
	match key:
		KEY_ESCAPE:
			van_open = false
		KEY_UP, KEY_W:
			van_row = (van_row - 1 + VAN_ROWS.size()) % VAN_ROWS.size()
		KEY_DOWN, KEY_S:
			van_row = (van_row + 1) % VAN_ROWS.size()
		KEY_LEFT, KEY_A:
			van_step(-1)
		KEY_RIGHT, KEY_D:
			van_step(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_take_it()


func van_step(dir: int) -> void:
	var row: String = VAN_ROWS[van_row]
	if row == "ladders":
		van_ladders = clampi(van_ladders + dir, 1, 40)
		return
	if row == "dogs":
		van_dogs = clampi(van_dogs + dir * 2, 2, 120)
		return
	van_toggle(row)


## A kit row is on or off, and either arrow does the same thing — there is no more or less of a
## chair. Refused rather than silently ignored when it is not in the shed, and the refusal says
## where to get one, because "nothing happened" is the worst answer a menu can give.
func van_toggle(item: String) -> void:
	if not jack.career_owns(item):
		van_said = "%s — £%.0f at the yard. You have not bought a pair yet." % [
			KIT_NAME.get(item, item), jack.career_kit_cost(item)] if item == "gloves" \
			else "%s — £%.0f at the yard. You have not bought one yet." % [
			KIT_NAME.get(item, item), jack.career_kit_cost(item)]
		return
	var taking := not jack.career_carrying(item)
	jack.career_carry(item, taking)
	save_career()
	van_said = "%s %s" % [KIT_NAME.get(item, item), "on the cart" if taking else "left in the shed"]


## What the ladders you are taking mean, in metres of span — the number the decision is actually
## about. Said out loud rather than left for the player to work out at fifty metres.
func van_span(job: Dictionary) -> float:
	var height: float = float(job.get("height", 0.0))
	return height / maxf(float(van_ladders), 1.0)


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
	get_tree().root.set_meta("job_ladders", van_ladders)
	get_tree().root.set_meta("job_dogs", van_dogs)
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
		stars += "★" if s < int(career.get("stars", 0)) else "☆"
	draw_string(_font, Vector2(size.x - 330, 58),
		"£%d in the tin        %s" % [int(float(career.get("money", 0.0))), stars],
		HORIZONTAL_ALIGNMENT_RIGHT, 282, 16, PAPER)

	# Thirteen jobs do not fit on a board, so the board scrolls. It only scrolls when it has to —
	# a list that slides about while you are reading it is worse than one that sits still — and it
	# keeps the selection a card clear of either edge so you can always see what is next.
	var top := 130.0
	var bottom: float = size.y - 64.0
	var step := 118.0
	var shown: int = maxi(int((bottom - top) / step), 1)
	var first: int = clampi(selected - shown / 2, 0, maxi(jobs.size() - shown, 0))
	var y := top
	for i in range(first, mini(first + shown, jobs.size())):
		y = _card(jobs[i], 48.0, y, i == selected)
	# And it says so, because a list that has more in it than it shows must admit that.
	if jobs.size() > shown:
		draw_string(_font, Vector2(48.0, top - 14.0),
			"%d-%d of %d" % [first + 1, mini(first + shown, jobs.size()), jobs.size()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(PAPER.r, PAPER.g, PAPER.b, 0.6))

	draw_string(_font, Vector2(48, size.y - 36),
		"up / down to look through them    enter to take it    esc to leave it",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(PAPER.r, PAPER.g, PAPER.b, 0.5))

	if selected < jobs.size():
		_letter(jobs[selected], 48.0 + CARD_W + 60.0, 130.0)

	# Last, over everything: the van is a decision, and a decision should not share the screen
	# with the thing it is about.
	if van_open:
		_draw_van()


## What the job is called on its own card. Every archetype in 05-mission-types.md gets a word
## here, so a new one appears on the board named rather than misfiled as a survey.
func _kind_of(job: Dictionary) -> String:
	match String(job.get("archetype", "")):
		"FELL":      return "FELLING"
		"CONDUCTOR": return "CONDUCTOR"
		"GILD":      return "GILDING"
		"BAND":      return "BANDING"
		"TOP":       return "TOPPING"
		"MECHANISM": return "MECHANISM"
		"LATTICE":   return "LATTICE"
		"EMERGENCY": return "EMERGENCY"
		"STRAIGHTEN": return "STRAIGHTENING"
		_:           return "SURVEY"


## One job, as a card pinned to the board. Returns the y to carry on from.
func _card(job: Dictionary, x: float, y: float, here: bool) -> float:
	var felling: bool = String(job["archetype"]) == "FELL"
	# The card used to say SURVEY for anything that was not a felling, which was true when there
	# were two kinds of job and became a lie the moment there were three.
	var kind := _kind_of(job)
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
			"%s   %.0f m   %s" % [kind, job["height"], shift],
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
			"%s   %.0f m   %s" % [kind, job["height"], shift],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RED_INK if felling else FADED)
		draw_string(_font, Vector2(x + CARD_W - 120, y + 30), "above your name",
			HORIZONTAL_ALIGNMENT_RIGHT, 104, 11, Color(0.45, 0.40, 0.30))
	if int(job["gate"]) > 0:
		var stars := ""
		for s in 5:
			stars += "★" if s < int(job["gate"]) else "☆"
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


# --- the van ----------------------------------------------------------------------------------
#
# The strategy layer, and the only screen in the game where a decision is made with nothing at
# stake yet. 08-hub-and-meta.md: "There is no 'recommended loadout' button." There is a default —
# what the level packed, which the reachability gate has proved can reach the top — and the rest
# is yours.

const VAN_W := 560.0
const VAN_H := 420.0
const VAN_ROW_H := 54.0


func van_rect() -> Rect2:
	return Rect2(Vector2((size.x - VAN_W) * 0.5, (size.y - VAN_H) * 0.5), Vector2(VAN_W, VAN_H))


## Which row a point is over, and whether it is on the minus or the plus. -1 for neither.
func van_hit(p: Vector2) -> Dictionary:
	var r := van_rect()
	if not r.has_point(p):
		return {}
	for i in VAN_ROWS.size():
		var y: float = r.position.y + 106.0 + VAN_ROW_H * float(i)
		if p.y >= y - 26.0 and p.y <= y + 14.0:
			# A kit row is a switch, so the whole row is the switch. Making the player find an
			# 18-pixel box is a worse version of the same click.
			if VAN_ROWS[i] in KIT_ROWS:
				return {"row": i, "step": 1}
			var step := 0
			if p.x >= r.position.x + VAN_W - 90.0:
				step = 1
			elif p.x >= r.position.x + VAN_W - 170.0:
				step = -1
			return {"row": i, "step": step}
	return {}


func _draw_van() -> void:
	var job: Dictionary = jobs[selected] if not jobs.is_empty() else {}
	var r := van_rect()
	draw_rect(Rect2(r.position - Vector2(6, 6), r.size + Vector2(12, 12)), Color(0, 0, 0, 0.45))
	draw_rect(r, PAPER)

	draw_string(_font, r.position + Vector2(28, 44), "THE VAN",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, FADED)
	draw_string(_font, r.position + Vector2(28, 74), String(job.get("name", "")),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 21, INK)

	for i in VAN_ROWS.size():
		var key: String = VAN_ROWS[i]
		var y: float = r.position.y + 106.0 + VAN_ROW_H * float(i)
		var on: bool = i == van_row
		if on:
			draw_rect(Rect2(Vector2(r.position.x + 16.0, y - 26.0),
				Vector2(VAN_W - 32.0, 36.0)), Color(0.16, 0.14, 0.12, 0.07))
		# A rule between the numbers and the kit. They are answers to different questions and the
		# line is cheaper than a heading.
		if key == KIT_ROWS[0]:
			draw_rect(Rect2(Vector2(r.position.x + 28.0, y - 40.0),
				Vector2(VAN_W - 56.0, 1.0)), Color(0.16, 0.14, 0.12, 0.18))

		if key in KIT_ROWS:
			var owned: bool = jack.career_owns(key)
			var taking: bool = jack.career_carrying(key)
			var col: Color = (INK if on else FADED) if owned else Color(0.16, 0.14, 0.12, 0.3)
			draw_string(_font, Vector2(r.position.x + 28.0, y), String(KIT_NAME.get(key, key)),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col)
			draw_string(_font, Vector2(r.position.x + 28.0, y + 17.0),
				String(KIT_WHY.get(key, "")) if owned
					else "£%.0f at the yard" % jack.career_kit_cost(key),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.16, 0.14, 0.12, 0.45))
			# A drawn box rather than a word: it is the one row on this screen whose state you
			# should be able to take in without reading anything.
			var box := Rect2(Vector2(r.position.x + VAN_W - 132.0, y - 15.0), Vector2(18, 18))
			draw_rect(box, Color(0.16, 0.14, 0.12, 0.5), false, 1.5)
			if taking:
				draw_rect(Rect2(box.position + Vector2(4, 4), Vector2(10, 10)), INK)
			draw_string(_font, Vector2(r.position.x + VAN_W - 104.0, y),
				"on the cart" if taking else ("in the shed" if owned else "not bought"),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
			continue

		var what := "Ladder sections" if key == "ladders" else "Dogs"
		draw_string(_font, Vector2(r.position.x + 28.0, y), what,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK if on else FADED)
		var n: int = van_ladders if key == "ladders" else van_dogs
		draw_string(_font, Vector2(r.position.x + VAN_W - 150.0, y), "‹" if on else " ",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
		draw_string(_font, Vector2(r.position.x + VAN_W - 118.0, y), "%d" % n,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 21, INK)
		draw_string(_font, Vector2(r.position.x + VAN_W - 66.0, y), "›" if on else " ",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)

	# What the choice actually means, in the units the job is in. A player should not have to do
	# this division at fifty metres with one hand on a rung.
	var span := van_span(job)
	var verdict := "rigid"
	var col := Color(0.20, 0.42, 0.24)
	if span > 8.0:
		verdict = "past buckling — she will not hold"
		col = RED_INK
	elif span > 6.0:
		verdict = "swaying"
		col = RED_INK
	elif span > 4.0:
		verdict = "flexing"
		col = Color(0.55, 0.38, 0.10)
	draw_string(_font, Vector2(r.position.x + 28.0, r.position.y + VAN_H - 100.0),
		"%.1f m a section over %.0f m — %s" % [span, float(job.get("height", 0.0)), verdict],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
	draw_string(_font, Vector2(r.position.x + 28.0, r.position.y + VAN_H - 76.0),
		"%d dogs — %s" % [van_dogs,
			"plenty" if van_dogs >= van_ladders * 2 else "you will be going back down for more"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, FADED)
	if van_said != "":
		draw_string(_font, Vector2(r.position.x + 28.0, r.position.y + VAN_H - 48.0), van_said,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.18, 0.14))
	draw_string(_font, Vector2(r.position.x + 28.0, r.position.y + VAN_H - 22.0),
		"↑↓ choose   ←→ or click   ·   enter to set off   ·   esc to think again",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, FADED)
