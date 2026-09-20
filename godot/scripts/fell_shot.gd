# The felling, rendered to a PNG — FELL-003.
#
#   make fell-shot CMDS="cut 140,prop,shot gob"
#
# Godot's --headless has no renderer at all; under a virtual X display it renders fine, in software,
# a few seconds a frame. AGENTS.md: if you changed something visual and have not looked at a frame
# of it, you have not finished — and a felling is almost entirely a thing you look at.
#
# Commands, comma separated:
#
#   cut <deg>      cut that arc of gob on the pegged line, propping behind as you go
#   ahead <n>      leave n segments unpropped ahead of the props, to see one in trouble
#   peg <deg>      drive the pegs on a bearing
#   stand <deg>    walk round to that bearing
#   back <m>       stand that far off
#   watch <deg>    stand at that angle to the fall line, to see it side on
#   look <deg>     turn the camera by that much from facing the chimney
#   pitch <deg>    tilt it (negative is down)
#   fire           light it
#   wait <s>       let it run
#   shot <name>    write docs/shots/<name>.png

extends SceneTree

var world: Node
var jack
var ring


func _init() -> void:
	world = load("res://scenes/felling.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	jack = world.jack
	ring = world.ring
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	for cmd in _commands():
		var bits: PackedStringArray = String(cmd).strip_edges().split(" ", false)
		if bits.is_empty():
			continue
		var arg := float(bits[1]) if bits.size() > 1 else 0.0
		match bits[0]:
			"cut": await _cut(arg, 0)
			"ahead": await _cut(160.0, int(arg))
			"peg": world._peg = arg
			"stand":
					world._around = arg
					world._face_the_chimney()
			"back":
					world._orbit = arg
					world._face_the_chimney()
			"watch":
					world._around = fmod(world._peg + arg, 360.0)
					world._face_the_chimney()
			"look": world._yaw = deg_to_rad(world._around + arg)
			"pitch": world._pitch = deg_to_rad(arg)
			"fire": world._fire()
			"wait": await _wait(int(arg * 60.0))
			"shot": await _shot(bits[1] if bits.size() > 1 else "felling")
			_: printerr("fell_shot: no such command: %s" % bits[0])
		world._place_camera()
		await process_frame
	quit()


func _commands() -> Array:
	# The Makefile passes CMDS unquoted, so the shell has already split it on spaces. Join it back
	# up before splitting on the commas that were actually meant.
	var joined := " ".join(OS.get_cmdline_user_args())
	var out: Array = []
	for part in joined.split(",", false):
		if String(part).strip_edges() != "":
			out.append(String(part).strip_edges())
	if out.is_empty():
		out = ["cut 160", "shot felling"]
	return out


## Cut an arc on the pegged line, propping behind — `ahead` segments left unpropped at the front,
## which is how you photograph a prop in trouble.
func _cut(arc_deg: float, ahead: int) -> void:
	var count: int = int(round(arc_deg / 360.0 * float(ring.segments)))
	var mid: int = int(round(world._peg / 360.0 * float(ring.segments))) % int(ring.segments)
	var segs: int = int(ring.segments)
	var order: Array = [mid]
	var step := 1
	while order.size() < count:
		order.append((mid + step) % segs)
		if order.size() < count:
			order.append((mid - step + segs) % segs)
		step += 1
	for i in order.size():
		var s: int = order[i]
		for c in range(int(ring.courses) - 1):
			jack.gob_cut(s, c)
		if i < order.size() - ahead:
			jack.gob_prop(s)
		jack.gob_cut(s, int(ring.courses) - 1)
	ring.refresh()
	world._after_change()
	await process_frame


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://../docs/shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s.png" % [dir, name]
	image.save_png(path)
	print("wrote %s (%dx%d)" % [path, image.get_width(), image.get_height()])
