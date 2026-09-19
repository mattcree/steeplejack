# The checkpoint, end to end — CLIMB-006 in the game.
#
# Build a stack, let the game write its checkpoint, then start the game again and check the stack
# is where it was left: the same top, the same sections, the dogs showing in the wall, and the
# sections off the cradle's count. Then the two ways it must refuse: an edited level, and a job
# already finished.
#
#   godot --path godot --headless --script res://scripts/test_checkpoint.gd

extends SceneTree

const PATH := "user://test-checkpoint.json"
var failures := 0


func _init() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

	# --- the first shift: build three sections and go home -------------------------------------
	var first := await _start()
	var p1: Node = first.get_node("Player")
	var jack1: Jack = p1.jack
	var cradle_before: int = p1.ladders_at_base
	for h in [4.0, 8.0, 12.0]:
		var d: Dictionary = jack1.seat_anchor(h, 1.0, 0.0)
		jack1.stack_lash(float(d.get("height", h)), 2)
	p1._write_checkpoint()
	_check(FileAccess.file_exists(PATH), "the stack was written to disk")
	var top1: float = jack1.stack_top()
	var anchors1: int = jack1.anchor_count()
	first.queue_free()
	await process_frame

	# --- the next morning ------------------------------------------------------------------------
	var second := await _start()
	var p2: Node = second.get_node("Player")
	var jack2: Jack = p2.jack
	_check(jack2.stack_top() == top1, "the top dog is where it was (%.2f, was %.2f)" % [jack2.stack_top(), top1])
	_check(jack2.anchor_count() == anchors1, "every anchor is back, fixtures included")
	_check(jack2.stack_sections().size() == 3, "three sections")
	_check(p2.ladder_top > 12.0, "the ladder reaches above the top dog (%.1f m)" % p2.ladder_top)
	_check(p2.ladders_at_base == cradle_before - 3, "and those three are not in the cradle any more")
	var occupied := 0
	for i in range(1, jack2.anchor_count()):
		var a: Dictionary = jack2.anchor_at(i)
		if not a.get("fixture", false) and bool(jack2.joint(int(a["joint"])).get("occupied", false)):
			occupied += 1
	_check(occupied == 3, "the three dogs show in the wall (%d)" % occupied)
	_check(p2.message.begins_with("Your stack is where you left it"), "and he is told so")

	# --- an edited checkpoint is refused, and the file is left alone -----------------------------
	second.queue_free()
	await process_frame
	var text := FileAccess.get_file_as_string(PATH)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text.replace("\"levelFile\":\"", "\"levelFile\":\"0"))
	f.close()
	var third := await _start()
	var p3: Node = third.get_node("Player")
	_check(p3.jack.stack_sections().is_empty(), "a checkpoint for a changed level is not restored")
	_check(FileAccess.file_exists(PATH), "and it is not deleted either — it is someone's climb")

	# --- the top clears it -------------------------------------------------------------------------
	p3._checkpointing = true
	p3._arrive_at_top()
	_check(not FileAccess.file_exists(PATH), "reaching the top clears the checkpoint")
	third.queue_free()
	await process_frame

	print("CHECKPOINT: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


func _start() -> Node:
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	world.get_node("Player").checkpoint_path = PATH
	root.add_child(world)
	await physics_frame
	return world


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		failures += 1
		printerr("  FAIL  %s" % what)
