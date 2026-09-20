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
#   climb <m>        on the ladder at that height, with stack lashed up to it at 4 m spans
#   dog <m> [lash]   a dog seated and lashed at that height (lash 1 hitch, 2 full)
#   seat <m>         a dog driven in at that height, nothing lashed to it yet
#   carry            a ladder on the shoulder and a full bag of dogs
#   tap              sound the joint he is pointing at, through the real flow
#   tapall [r]       sound every joint in reach (or r x reach), for a frame of the chalk
#   work [depth]     start driving a dog into the joint he is pointing at
#   draw             hammer raised, mid-draw
#   strike           one blow, caught at contact
#   lash <s> [rate]  carry a section and lash it, going round steadily for s seconds
#   tieoff           tie the lashing off
#   top              all the way up, and onto the cap
#   tea              belt on and brew up
#   fall             come off, untied, from where he is
#   gin              rig the gin wheel on the highest dog in reach, and start a haul
#   haulfor <s> [1]  haul flat out for s seconds, steering against the swing if 1
#   stance <0-4>     one hand / hooked leg / clipped / belted / chair
#   strain <g> <n>   drained meters, to see the telegraphs
#   slip             grip to nothing, so the slip window is open
#   options          the F1 motion options overlay, open
#   walkfor <s>      walk forward for s seconds — mid-stride
#   climbfor <s>     hold W for s seconds (negative for S) — mid-climb, hands moving
#   cam <yaw> <pit>  aim the camera, degrees — NOTE this turns the jack too, because it sets his
#                    facing and the boom follows it. Use it to pose him, not to look at him.
#   orbit <d> <m> [p]  look at him from `d` degrees round his own facing, `m` metres back, pitch `p`.
#                    A free camera that ignores the boom, so it does not turn him: this is the one
#                    for limb geometry, where the whole question is what a leg does side-on.
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

	# `--level <id>` is the player's, not ours. Left in, it would be joined into the last pose
	# command and reported as an unknown verb on every run that picked a level.
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	var script := PackedStringArray()
	var skip := false
	for a in argv:
		if skip:
			skip = false
			continue
		if a == "--level":
			skip = true
			continue
		script.append(a)
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
	var c := float(parts[3]) if parts.size() > 3 else 0.0

	match verb:
		"climb":
			_fill_stack_to(a - 1.0)
			_lash_to(a)
			_put_on_ladder(a)
		"dog":
			# Driven and lashed: the ladder goes up to it, and the stack knows about the section, so
			# a long span between two `dog`s is a long span that can buckle.
			_fill_stack_to(a - 3.0)
			_lash_to(a)
			var d: Dictionary = jack.seat_anchor(a, 1.0, 0.0)
			jack.stack_lash(float(d.get("height", a)), int(b) if b > 0.0 else 2)
			if player.face != null:
				player.face.touch()
		"seat":
			# A dog driven in at that height and nothing lashed to it yet: the moment before a lash.
			var jid: int = jack.nearest_joint(chimney.face_point(a) + chimney.global_position + Vector3(0, 0, 0.45), 1.0)
			if jid >= 0:
				jack.seat_anchor_joint(jid, 1.0, 0.0)
			if player.face != null:
				player.face.touch()
		"carry":
			player.carrying_ladder = true
			player.dogs_carried = player.DOG_BAG
		"tap":
			# Through the real flow, so the frame shows what a player would see: the arm, the dust,
			# the chalk. Taken just after contact unless a wait follows.
			await _wait(2)
			player._tap()
			await _wait(int(ClimbClip.TAP_CONTACT * 60.0) + 2)
		"tapall":
			# Sound every joint in reach, as a player surveying a working position would. For a
			# frame of the chalk marks.
			await _wait(2)
			for j in jack.joints_near(player.height_m(), jack.climb_bearing(),
					jack.tuning_f("tapTestMaxRangeMetres", 2.5) * a if a > 0.0 else 1.2):
				if not j["occupied"]:
					jack.tap_joint(j["id"], false)
			player.face.touch()
		"work":
			await _wait(2)
			player.dogs_carried = maxi(player.dogs_carried, 1)
			player._toggle_work_mode()
			player.dog_depth = a if a > 0.0 else 0.35
			player.aim = Vector2(3.0, -2.0)
		"draw":
			# The hammer up and held, mid-draw.
			player.drawing = true
			player.swing_power = 0.7
			if player.anim.has_animation("windup"):
				player.anim.play("windup", 0.05)
				player._playing = "windup"
			await _wait(24)
		"strike":
			player.drawing = true
			player.swing_power = 0.8
			player._release_strike()
			await _wait(int(ClimbClip.STRIKE_CONTACT * 60.0) + 1)
		"stance":
			jack.set_stance(int(a))
		"strain":
			# Meters are the sim's; there is no setter and there should not be. Work him down to the
			# number instead, which is also the only way the state is one the game can really be in.
			await _drain_to(a, b)
		"slip":
			await _drain_to(0.0, -1.0)
		"options":
			player.options_open = true
		"walkfor":
			# Walk forward for `a` seconds, to catch the run cycle mid-stride.
			player.walk_input = Vector2(0.0, 1.0)
			await _wait(int(absf(a) * 60.0))
			player.walk_input = Vector2.ZERO
		"climbfor":
			# Hold W for `a` seconds (negative: S), to catch him mid-climb, hands moving rung to rung.
			player.climb_input = signf(a) if a != 0.0 else 1.0
			await _wait(int(absf(a) * 60.0))
			player.climb_input = 0.0
		"cam":
			player._yaw = deg_to_rad(a)
			player._pitch = deg_to_rad(b)
			player._cam_yaw = player._yaw
			player._cam_pitch = player._pitch
		"orbit":
			# A camera of our own, parented to nothing and aimed by hand. The boom re-eases towards
			# the player's facing every frame, so setting its rotation does not hold for a capture;
			# and `cam` yaws the jack himself. Neither can photograph a man from the side while he
			# keeps climbing, which is exactly what a knee bending the wrong way needs.
			var eye := Camera3D.new()
			eye.fov = player.get_node("Boom/Camera").fov
			root.add_child(eye)
			var chest: Vector3 = player.global_position + Vector3.UP * 1.1
			var ang: float = player._yaw + deg_to_rad(a)
			var back := Vector3(sin(ang), 0.0, cos(ang)) * maxf(b, 0.5)
			eye.global_position = chest + back + Vector3.UP * (maxf(b, 0.5) * sin(deg_to_rad(c)))
			eye.look_at(chest, Vector3.UP)
			eye.make_current()
		"boom":
			player.get_node("Boom").spring_length = a
			# Hold it: the camera eases towards its own framing every frame.
			player.boom_length = a
		"fov":
			player.get_node("Boom/Camera").fov = a
		"lash":
			# Start lashing and turn at a steady rate for `a` seconds (b turns a second, default the
			# ideal), through the real verb.
			player.carrying_ladder = true
			player._lash()
			var rate: float = b if b > 0.0 else 1.0 / jack.tuning_f("lashSecondsPerWrapIdeal", 1.4)
			for i in int(a * 60.0):
				player._lash_spin += TAU * rate / 60.0
				await physics_frame
		"tieoff":
			player._tie_off()
		"top":
			# All the way up, through the real arrival: ladder to the cap, and step off onto it.
			_lash_to(chimney.height_m)
			player.ladder_top = chimney.height_m
			chimney.set_ladder_top(chimney.height_m)
			_put_on_ladder(chimney.height_m - 0.7)
			player._arrive_at_top()
			player._cam_yaw = player._yaw
			player._cam_pitch = player._pitch
		"gin":
			# Rig the gin wheel on the highest dog in reach and start a haul from the cradle.
			await _wait(2)
			player._gin_wheel()
			player._gin_wheel()
		"haulfor":
			# Haul flat out for `a` seconds; b = 1 steers against the swing like a good hand.
			player.climb_input = 1.0
			for i in int(a * 60.0):
				if b > 0.0 and not player.haul.is_empty():
					var vel_sign := signf(float(player.haul.get("swing_deg", 0.0)))
					player._haul_dx = -vel_sign * 40.0
				await physics_frame
				if not player.hauling:
					break
			player.climb_input = 0.0
		"fall":
			# Off, untied, from where he is — through the real fall.
			player._begin_fall("you had one hand on a rung and nothing else. Nothing caught you.")
		"tea":
			jack.set_stance(3)
			player._recover(player.REC_TEA)
		"wide":
			# Keep the ordinary framing in work mode, to see the whole body rather than the joint.
			player.set_meta("shot_wide", true)
		"wait":
			await _wait(int(a * 60.0))
		"shot":
			await _shot(parts[1] if parts.size() > 1 else "shot")
		_:
			printerr("shot: no such command '%s'" % verb)


# --- posing ---------------------------------------------------------------------------------------

## Lash the stack up to a height, so he can be there at all — you climb only what you have built.
## Rigid 4 m spans up to `height`, the way a careful jack would have built it. Without them
## `climb 20` stood him on one twenty-metre section: every frame at height carried a buckle
## warning, and any shot that waited long enough ended with him on the ground.
func _fill_stack_to(height: float) -> void:
	var h: float = maxf(jack.stack_top(), 0.0) + 4.0
	while h <= height:
		var d: Dictionary = jack.seat_anchor(h, 1.0, 0.0)
		jack.stack_lash(float(d.get("height", h)), 2)
		h = float(d.get("height", h)) + 4.0
	if player.face != null:
		player.face.touch()


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
	player.face_the_wall()


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
