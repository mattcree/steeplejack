# The motion and vertigo options — A11Y-001, the table in 14-accessibility.md, row for row.
#
# The game is about being very high up, and that will make some people genuinely unwell. The
# defaults matter more than the options existing: the nerve sway is a good effect and it excludes
# people, so it is opt-in, and so is head bob.
#
# Kept in user://settings.cfg and applied the moment they change — acceptance 4 is "without a
# restart", and a vertigo option you have to restart to try is one nobody tries.
class_name GameSettings
extends RefCounted

signal changed

const PATH := "user://settings.cfg"

## [key, label, kind, default, min, max, step]. kind: "bool", "range", "choice".
const ROWS := [
	["camera_sway", "Camera sway (nerve)", "bool", false],
	["head_bob", "Head bob", "bool", false],
	["fall_time_dilation", "Time dilation on fall", "bool", true],
	["fov", "Field of view", "range", 75.0, 60.0, 100.0, 5.0],
	["low_nerve_vignette", "Vignette on low nerve", "bool", true],
	["reduce_look_down", "Reduce look-down", "bool", false],
	["screen_shake", "Screen shake", "range", 1.0, 0.0, 1.0, 0.25],
	["fall_camera", "Fall camera", "choice", "cinematic", ["cinematic", "minimal"]],
]

var _values := {}
var _path := PATH


func _init(path: String = PATH) -> void:
	_path = path
	for row in ROWS:
		_values[row[0]] = row[3]
	load_file()


func get_value(key: String) -> Variant:
	return _values.get(key)


func set_value(key: String, value: Variant) -> void:
	if not _values.has(key) or _values[key] == value:
		return
	_values[key] = value
	save_file()
	changed.emit()


## One step of a row: toggle a bool, step a range, cycle a choice. `dir` is +1 or -1.
func step(key: String, dir: int) -> void:
	for row in ROWS:
		if row[0] != key:
			continue
		match row[2]:
			"bool":
				set_value(key, not bool(_values[key]))
			"range":
				set_value(key, clampf(float(_values[key]) + dir * float(row[6]), float(row[4]), float(row[5])))
			"choice":
				var opts: Array = row[4]
				var i := opts.find(_values[key])
				set_value(key, opts[(i + dir + opts.size()) % opts.size()])
		return


## What a row says its value is, for the overlay.
func shown(key: String) -> String:
	var v: Variant = _values[key]
	match key:
		"fov":
			return "%d°" % int(v)
		"screen_shake":
			return "%d%%" % int(round(float(v) * 100.0))
	if v is bool:
		return "on" if v else "off"
	return str(v)


func load_file() -> void:
	if _path == "":
		return   # in memory only: a test's settings, which must not be the player's
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK:
		return
	for row in ROWS:
		var key: String = row[0]
		if cfg.has_section_key("motion", key):
			var v: Variant = cfg.get_value("motion", key)
			# A hand-edited file with the wrong type for a row is ignored for that row rather than
			# trusted: a string where a bool goes would turn a vertigo option on.
			if typeof(v) == typeof(row[3]) or (row[2] == "range" and (v is int or v is float)):
				_values[key] = v


func save_file() -> void:
	if _path == "":
		return
	var cfg := ConfigFile.new()
	for key in _values:
		cfg.set_value("motion", key, _values[key])
	cfg.save(_path)
