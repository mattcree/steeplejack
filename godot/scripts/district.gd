# What a career has actually done to the town.
#
# Two screens ask this and they are the two most important pictures the game has: the yard's
# skyline, seen every morning, and the ending's drive through the district past every chimney in
# the game. 19-the-complete-game.md says the melancholy is that the world shrinks as you get better
# at your job, and that the game should not soften it.
#
# Both of them got it wrong, separately and in the same way. Each counted every job in the career
# that had not been failed — so reading a chimney demolished it, banding one demolished it, and
# running a lightning conductor down one demolished it. A jack who had spent a season making
# chimneys SAFER was driven past their stumps in his own credits.
#
# So the question lives in one place now. It is not a hard calculation; it is a calculation that
# must not be made twice, because the second copy is where it goes wrong.

class_name District
extends RefCounted

const LEVELS_DIR := "res://../data/levels"

## Read once. These are menus, and they draw every frame.
static var _levels: Array = []


## Every chimney in the district, in the order a career meets them: {id, archetype, order, name}.
##
## The grey box is left out: it is a tool rather than a job and it is not a chimney in this town.
static func levels() -> Array:
	if not _levels.is_empty():
		return _levels
	# Globalized first. `res://../data` is outside the project and DirAccess will not follow it —
	# it opens nothing, returns no error, and the caller draws an empty sky.
	var base := ProjectSettings.globalize_path(LEVELS_DIR)
	var dir := DirAccess.open(base)
	if dir == null:
		push_error("district: no %s" % LEVELS_DIR)
		return _levels
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var doc = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [base, f]))
		if typeof(doc) != TYPE_DICTIONARY:
			continue
		var id := String(doc.get("id", ""))
		if id.begins_with("00-"):
			continue
		_levels.append({"id": id, "archetype": String(doc.get("archetype", "")),
			"order": int(doc.get("order", 0)), "name": String(doc.get("name", ""))})
	_levels.sort_custom(func(a, b): return int(a["order"]) < int(b["order"]))
	return _levels


## What a career did to one chimney: "standing", "shortened" or "felled".
##
## Banding her, straightening her, running a conductor down her, reading her: she is still there,
## and in three of those four she is there for LONGER because of you. Only a felling takes a
## chimney off the skyline, and topping leaves a shorter one rather than a gap.
static func state(archetype: String, was_done: bool) -> String:
	if not was_done:
		return "standing"
	if archetype == "FELL":
		return "felled"
	if archetype == "TOP":
		return "shortened"
	return "standing"


## The archetype of a job, by its id, or "" if the district has never heard of it.
static func archetype_of(id: String) -> String:
	for lvl in levels():
		if String(lvl["id"]) == id:
			return String(lvl["archetype"])
	return ""


## How many chimneys this career left in each state: {standing, shortened, felled}.
static func tally(career: Dictionary) -> Dictionary:
	var out := {"standing": 0, "shortened": 0, "felled": 0}
	var done := {}
	for j in (career.get("jobs", []) as Array):
		var rec: Dictionary = j
		if not bool(rec.get("failed", false)):
			done[String(rec.get("id", ""))] = true
	for lvl in levels():
		var st := state(String(lvl["archetype"]), done.has(String(lvl["id"])))
		out[st] = int(out[st]) + 1
	return out
