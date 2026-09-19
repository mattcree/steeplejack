# Put the jack where the test needs him and photograph it.
#
# The one thing missing from this project for too long. Godot's `--headless` has no renderer at all,
# so for three weeks every visual change was shipped on reasoning and the honest answer to "does it
# look right?" was that nobody had looked. Under a virtual X display it renders perfectly well —
# software rasterised via llvmpipe, a few seconds a frame, and the picture is the picture.
#
#   make shot                                  # he is where the level put him
#   make shot CMDS="climb 26,shot at-26m"
#   make shot CMDS="carry,dog 20,climb 21,work,shot dogging-in"
#
# A frame of a man standing in a field proves almost nothing, which is why this takes a pose first.
# The vocabulary is deliberately the same as the one AGENTS.md documents for the old engine, so the
# commands in that file still mean what they say.
#
#   climb <m>        on the ladder at that height, with stack lashed up to it
#   dog <m>          a dog seated at that height, as if driven cleanly
#   carry            a ladder on the shoulder and a full bag of dogs
#   tap              sound the brickwork where he is
#   work             into work mode, hammer up
#   stance <0-4>     one hand / hooked leg / clipped / belted / chair
#   strain <g> <n>   drained meters, to see the telegraphs
#   slip             grip to nothing, so the slip window is open
#   cam <yaw> <pit>  aim the camera, degrees
#   boom <m>         how far back the camera sits
#   fov <deg>        lens
#   wait <s>         let it settle
#   shot <name>      write docs/shots/<name>.png
#
# Commands run in order and a trailing `shot` is implied, so the common case needs no shot command.

extends SceneTree

const SHOT_DIR := "res://../docs/shots"
const SETTLE_FRAMES := 12

var world: Node
var player: Node
var chimney: Node
var jack
var _taken := 0


func _init() -> void:
	var scene: PackedScene = load("res://scenes/steeplejack.tscn")
	world = scene.instantiate()
	root.add_child(world)
	await process_frame

	player = world.get_node("Player")
	chimney = world.get_node("Chimney")
	jack = player.jack

	var script: PackedStringArray = OS.get_cmdline_user_args()
	var line := " ".join(script)
	for raw in line.split(",", false):
		await _run(raw.strip_edges())

	if _taken == 0:
		await _shot("shot")

	print("SHOT: %d frame(s)" % _taken)
	quit(0)


func _run(cmd: String) -> void:
	var parts := cmd.split(" ", false)
	if parts.is_empty():
		return
	var verb := parts[0].to_lower()
	var a := float(parts[1]) if parts.size() > 1 else 0.0
	var b := float(parts[2]) if parts.size() > 2 else 0.0

	match verb:
		"climb":
			_lash_to(a)
			_put_on_ladder(a)
		"dog":
			_lash_to(a)
			jack.seat_anchor(a, 1.0, 0.0)
			chimney.add_dog(a)
		"carry":
			player.carrying_ladder = true
			player.dogs_carried = player.DOG_BAG
		"tap":
			player._tap()
		"work":
			player.work_mode = true
			player.work_height = player.height_m()
			player.dog_depth = 0.35
			player.aim = Vector2(3.0, -2.0)
			player.swing_power = 0.6
		"stance":
			jack.set_stance(int(a))
		"strain":
			# Meters are the sim's; there is no setter and there should not be. Work him down to the
			# number instead, which is also the only way the state is one the game can really be in.
			await _drain_to(a, b)
		"slip":
			await _drain_to(0.0, -1.0)
		"cam":
			player._yaw = deg_to_rad(a)
			player._pitch = deg_to_rad(b)
		"boom":
			player.get_node("Boom").spring_length = a
		"fov":
			player.get_node("Boom/Camera").fov = a
		"wait":
			await _wait(int(a * 60.0))
		"shot":
			await _shot(parts[1] if parts.size() > 1 else "shot")
		_:
			printerr("shot: no such command '%s'" % verb)


# --- posing ---------------------------------------------------------------------------------------

## Lash the stack up to a height, so he can be there at all — you climb only what you have built.
func _lash_to(height: float) -> void:
	player.ladder_top = maxf(player.ladder_top, minf(height + 2.0, chimney.height_m))
	chimney.set_ladder_top(player.ladder_top)


func _put_on_ladder(height: float) -> void:
	var foot: Vector3 = chimney.global_position + chimney.face_point(height)
	var out: Vector3 = foot - chimney.global_position
	out.y = 0.0
	player.global_position = foot + out.normalized() * player.BODY_OFF_LADDER
	player.set_height_m(height)
	player.on_ladder = true
	player._shuffle = 0.0
	player._remount_block = 0.0


## Work him down to a grip and nerve. `nerve < 0` means don't wait for nerve.
func _drain_to(grip: float, nerve_to: float) -> void:
	var was: bool = player.work_mode
	player.work_mode = true
	for i in 60 * 60:
		if jack.grip() <= grip and (nerve_to < 0.0 or jack.nerve() <= nerve_to):
			break
		await physics_frame
	player.work_mode = was


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _shot(name: String) -> void:
	# Two settles, because the spring arm interpolates and the first frame after a pose catches the
	# camera mid-flight. Every automated capture on the last engine came out smeared for want of it.
	await _wait(SETTLE_FRAMES)
	for i in 3:
		await process_frame

	var img: Image = root.get_texture().get_image()
	if img == null:
		printerr("shot: nothing rendered — is there a display?")
		return
	var path := "%s/%s.png" % [SHOT_DIR, name]
	var err := img.save_png(path)
	if err != OK:
		printerr("shot: could not write %s (%d)" % [path, err])
		return
	_taken += 1
	print("  wrote docs/shots/%s.png  (%dx%d)  %.0f m, grip %.0f, nerve %.0f" % [
		name, img.get_width(), img.get_height(), player.height_m(), jack.grip(), jack.nerve()])
