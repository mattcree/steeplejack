# Photograph a menu — TOOL, not a test.
#
# `make shot` poses the jack on a chimney and takes a picture. Everything that is not the chimney —
# the board, the van, the yard, the shed, the ending — had no equivalent, so every claim about
# those screens was a claim nobody had looked at. This is the other half of the same rule:
# **if you changed something visual and have not looked at a frame of it, you have not finished.**
#
#   make ui-shot UI_SCENE=res://scenes/jobs.tscn CMDS="key:enter,shot the-van"
#   make ui-shot UI_SCENE=res://scenes/yard.tscn CMDS="down,down,enter,shot the-shed"
#   make ui-shot UI_SCENE=res://scenes/yard.tscn CMDS="did 06-waterside,did 12-great-aire,shot town"
#   make ui-shot UI_SCENE=res://scenes/yard.tscn CMDS="part 20,shot engine"   # her, half rebuilt
#
# Commands, comma separated:
#   up down left right enter esc space   one key press
#   wait <n>                             n frames
#   money <£>                            put that much in the tin first
#   own <item>                           buy it before the shot, so the owned state can be seen
#   shot <name>                          write docs/shots/<name>.png
#
# It drives the real `_input` of the real scene, so a screen that cannot be reached by pressing
# these keys is a screen a player cannot reach either — which is a thing worth finding out here.

extends SceneTree

const SHOT_DIR := "res://../docs/shots"
const CAREER := "user://uishot_career.json"

var scene_path := "res://scenes/yard.tscn"
var screen: Node = null
var taken := 0
var _did: Array = []   ## jobs the capture has marked done, for the skyline

const KEYS := {
	"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT,
	"enter": KEY_ENTER, "esc": KEY_ESCAPE, "space": KEY_SPACE,
}


func _init() -> void:
	var cmds := "shot ui"
	var argv := OS.get_cmdline_user_args()
	for i in argv.size():
		if argv[i] == "--scene" and i + 1 < argv.size():
			scene_path = argv[i + 1]
		elif not argv[i].begins_with("--") and (i == 0 or argv[i - 1] != "--scene"):
			cmds = argv[i]

	# A tin of its own. A capture must never spend the player's money — the shed screen is one
	# where the whole point is to photograph a purchase.
	var seed_tin := FileAccess.open(CAREER, FileAccess.WRITE)
	if seed_tin != null:
		seed_tin.store_string('{"money": 400, "reputation": 30}')
		seed_tin.close()

	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("ui-shot: cannot load %s" % scene_path)
		quit(1)
		return
	screen = packed.instantiate()
	if "career_path" in screen:
		screen.career_path = CAREER
	root.add_child(screen)
	await process_frame
	await process_frame

	for raw in cmds.split(",", false):
		await _run(raw.strip_edges())

	print("UI-SHOT: %d frame(s)" % taken)
	quit(0)


func _run(cmd: String) -> void:
	var parts := cmd.split(" ", false)
	if parts.is_empty():
		return
	var verb := parts[0]
	var arg := parts[1] if parts.size() > 1 else ""
	# The whole of the rest of the line, for the verbs whose argument is a sentence. `arg` is the
	# first word, which for `keep a chalked brick out of the perished course` is "a" — and the
	# salvage shelf picks what to DRAW out of that sentence, so five different keepsakes all came
	# out as the same brick.
	var rest := cmd.substr(verb.length()).strip_edges()
	match verb:
		"shot":
			await _shot(arg if arg != "" else "ui")
		"wait":
			await _wait(int(arg) if arg != "" else 10)
		"tick":
			# Push a scene that runs on a clock forward without waiting for it. The ending is 64
			# seconds of road and a tally that reveals a line at a time; a capture that waits for
			# it in real time is a capture nobody takes, so the frames nobody looks at are the
			# ones at the end of it.
			if "_t" in screen:
				screen._t = float(arg)
				screen.queue_redraw()
			await _wait(3)
		"did":
			# Mark a job done, so a career part way through can be photographed — the yard's
			# skyline is the one screen whose whole meaning is what you have already done to the
			# town, and it could only ever be captured on day one with everything still standing.
			# Through career_load, which is the path a save file takes.
			_did.append(arg)
			var j2 = _jack()
			if j2 != null:
				var recs: Array = []
				for id in _did:
					recs.append('{"id": "%s", "paid": 900, "error": 1.0, "failed": false}' % id)
				j2.career_load('{"money": 2400, "reputation": 44, "jobs": [%s]}'
					% ", ".join(recs))
				if "career" in screen:
					screen.career = j2.career_state()
			screen.queue_redraw()
			await _wait(2)
		"part":
			# Buy `arg` pieces of the traction engine, so the yard can be photographed part way
			# through the restoration. She is the game's long carrot and she is drawn
			# progressively — wheels, boiler, motion, brasswork, paint — and every capture of this
			# screen until now was taken on day one with her still under the sheet.
			var j3 = _jack()
			if j3 != null and "next_part_cost" in screen:
				# The tin ONCE, outside the loop. `_tin` goes through career_load, which replaces
				# the whole career — so topping it up between purchases wiped the parts it had
				# just bought and photographed three identical tarpaulins.
				_tin(20000.0)
				if "career" in screen:
					screen.career = j3.career_state()
				for i in int(arg):
					if not j3.career_buy_engine_part(screen.next_part_cost()):
						break
					if "career" in screen:
						screen.career = j3.career_state()
			screen.queue_redraw()
			await _wait(2)
		"keep":
			# Put something on the salvage shelf, so the museum in the yard can be photographed
			# with anything on it. The shelf draws each object as the thing it is — a bolt is a
			# bolt, a coil of copper is a coil of copper — and every capture of the yard until now
			# was taken with the shelf empty and therefore not drawn at all.
			var j4 = _jack()
			if j4 != null:
				j4.career_keep("cap-%d" % _did.size(), rest)
				_did.append(rest)
				if "career" in screen:
					screen.career = j4.career_state()
			screen.queue_redraw()
			await _wait(2)
		"money":
			_tin(float(arg))
		"own":
			# Through the real purchase, so what gets photographed is a state the game can be in.
			var j = _jack()
			if j != null:
				j.career_buy_kit(arg)
				if "career" in screen:
					screen.career = j.career_state()
		_:
			if KEYS.has(verb):
				var ev := InputEventKey.new()
				ev.keycode = KEYS[verb]
				ev.pressed = true
				# The screens read `_input`, not the action map, so this goes in the same way a
				# real keystroke does and takes the same path through the same match statement.
				screen.call_deferred("_input", ev)
				await _wait(3)
			else:
				printerr("ui-shot: no such command '%s'" % verb)


func _jack():
	return screen.jack if "jack" in screen else null


func _tin(money: float) -> void:
	var j = _jack()
	if j == null:
		return
	j.career_load('{"money": %f, "reputation": 30}' % money)
	if "career" in screen:
		screen.career = j.career_state()
	if screen.has_method("_build_rows"):
		screen._build_rows()
	screen.queue_redraw()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	screen.queue_redraw()
	await _wait(4)
	var img: Image = root.get_texture().get_image()
	if img == null:
		printerr("ui-shot: nothing rendered — is there a display?")
		return
	var err := img.save_png("%s/%s.png" % [SHOT_DIR, name])
	if err != OK:
		printerr("ui-shot: could not write %s (%d)" % [name, err])
		return
	taken += 1
	print("  wrote docs/shots/%s.png  (%dx%d)" % [name, img.get_width(), img.get_height()])
