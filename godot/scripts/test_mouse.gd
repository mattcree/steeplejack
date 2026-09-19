# The mouse comes back — a real window is needed, so this runs under a virtual display:
#
#   xvfb-run -a godot --path godot --audio-driver Dummy --script res://scripts/test_mouse.gd
#
# Leaving the window drops the capture. It used to stay dropped: mouse-look dead until Esc twice.
extends SceneTree

var failures := 0


func _init() -> void:
	if DisplayServer.get_name() == "headless":
		print("MOUSE: skipped — needs a display (make test-mouse runs it under xvfb)")
		quit(0)
		return
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	for i in 10:
		await process_frame
	var p: Node = world.get_node("Player")
	_check(p.mouse_captured(), "the game starts with the mouse captured")

	# Out of the window: the capture drops, as it does on alt-tab or a click outside.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame
	_check(not p.mouse_captured(), "(losing the window frees the mouse)")

	# Back in, and a click takes it again — without also starting a hammer draw.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(400, 300)
	Input.parse_input_event(click)
	for i in 3:
		await process_frame
	_check(p.mouse_captured(), "a click in the window takes the mouse back")
	_check(not p.drawing, "and the click is spent on that, not on a hammer draw")

	# Focus coming back does it too, with no click.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for i in 3:
		await process_frame
	_check(p.mouse_captured(), "coming back to the window takes the mouse back")

	# But not if he let it go on purpose.
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	for i in 3:
		await process_frame
	_check(not p.mouse_captured(), "Esc lets it go")
	p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for i in 3:
		await process_frame
	_check(not p.mouse_captured(), "and coming back to the window does not take it from him")

	print("MOUSE: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		failures += 1
		printerr("  FAIL  %s" % what)
