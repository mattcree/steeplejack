# The motion options — A11Y-001, the acceptance that a command can check.
#
# Defaults (sway and bob off), every row taking effect the moment it changes, the settings file
# round trip, and the two fall options doing what the table says. Acceptance 5 — the level is
# completable with every option off — is test_ascent, which runs with the defaults; 6, no flashing
# above 3 Hz, is a read of every pulse in the HUD, recorded in the task file.
#
#   godot --path godot --headless --script res://scripts/test_options.gd

extends SceneTree

const SCRATCH := "user://test-settings.cfg"
var failures := 0


func _init() -> void:
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var p: Node = world.get_node("Player")
	var s: GameSettings = p.settings

	_check(s.get_value("camera_sway") == false, "camera sway defaults to off")
	_check(s.get_value("head_bob") == false, "head bob defaults to off")
	_check(s.get_value("fall_time_dilation") == true and s.get_value("fall_camera") == "cinematic",
		"the fall is cinematic by default")

	# Every row, stepped through the same path the overlay uses, applies at once.
	s.step("fov", 1)
	await physics_frame
	_check(is_equal_approx(p.camera.fov, 80.0) or p.camera.fov > 77.0, "FOV applies without a restart (%.1f)" % p.camera.fov)
	for i in 10:
		s.step("fov", -1)
	_check(float(s.get_value("fov")) == 60.0, "FOV stops at 60")

	p._pitch = -1.3
	s.step("reduce_look_down", 1)
	_check(p._pitch >= -deg_to_rad(60.0) - 0.001, "reduce look-down pulls the view up to -60 at once")
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(0, 5000)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	p._unhandled_input(ev)
	_check(p._pitch >= -deg_to_rad(60.0) - 0.001, "and the mouse cannot take it past -60")

	# Screen shake at 0: a hammer kick moves nothing.
	for i in 4:
		s.step("screen_shake", -1)
	p._kick = 0.05
	await physics_frame
	_check(absf(p.camera.h_offset - p._cam_side) < 0.0001 and absf(p.camera.v_offset) < 0.0001,
		"screen shake at 0% is no shake")

	# Sway on, at the worst band: the view rolls. Off: level.
	s.step("camera_sway", 1)
	var ch: Node3D = world.get_node("Chimney")
	var foot: Vector3 = ch.global_position + ch.face_point(6.0)
	var out: Vector3 = foot - ch.global_position
	out.y = 0.0
	p.global_position = foot + out.normalized() * p.BODY_OFF_LADDER
	p.set_height_m(6.0)
	p.on_ladder = true
	p.jack.shock("bellStrike"); p.jack.shock("bellStrike"); p.jack.shock("anchorFail")
	var rolled := 0.0
	for i in 120:
		await physics_frame
		rolled = maxf(rolled, absf(p.camera.rotation.z))
	_check(rolled > 0.005, "camera sway on rolls the view at low nerve (%.3f rad, band %d, on ladder %s)" % [rolled, p.jack.nerve_band(), p.on_ladder])
	s.step("camera_sway", 1)
	await physics_frame
	_check(absf(p.camera.rotation.z) < 0.0001, "and off, it is level (%.4f)" % p.camera.rotation.z)
	p.on_ladder = false

	# Fall camera minimal: an immediate cut, no slow motion.
	s.step("fall_camera", 1)
	_check(s.get_value("fall_camera") == "minimal", "the fall camera goes to minimal")
	_check(p._fall_cuts_at_once() and not p._fall_slowed(), "minimal means an immediate cut, at full speed")
	s.step("fall_camera", 1)
	s.step("fall_time_dilation", 1)
	_check(p._fall_cuts_at_once() and not p._fall_slowed(), "time dilation off is also an immediate cut")
	s.step("fall_time_dilation", 1)
	_check(not p._fall_cuts_at_once() and p._fall_slowed(), "and both back on is the cinematic fall")

	# The overlay: F1 opens it, arrows change the chosen row, and nothing reaches the climb.
	var f1 := InputEventKey.new()
	f1.keycode = KEY_F1
	f1.pressed = true
	p._unhandled_input(f1)
	_check(p.options_open, "F1 opens the options")
	p.options_row = 1
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	p._unhandled_input(right)
	_check(s.get_value("head_bob") == true, "right arrow changes the chosen row")
	var e := InputEventKey.new()
	e.keycode = KEY_E
	e.pressed = true
	_check(p._options_input(e), "and a verb key does not get through while it is open")
	p._unhandled_input(f1)
	_check(not p.options_open, "F1 closes it")

	# Persistence, on a scratch file so the player's own settings are never touched.
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	var a := GameSettings.new(SCRATCH)
	a.set_value("fov", 90.0)
	a.set_value("reduce_look_down", true)
	var b := GameSettings.new(SCRATCH)
	_check(float(b.get_value("fov")) == 90.0 and b.get_value("reduce_look_down") == true,
		"settings persist across a restart")
	var f := FileAccess.open(SCRATCH, FileAccess.WRITE)
	f.store_string("[motion]\ncamera_sway=\"yes please\"\n")
	f.close()
	var c := GameSettings.new(SCRATCH)
	_check(c.get_value("camera_sway") == false, "a mistyped value in the file does not switch sway on")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))

	print("OPTIONS: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		failures += 1
		printerr("  FAIL  %s" % what)
