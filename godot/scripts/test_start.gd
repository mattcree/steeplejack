# Can the job be started at all?
#
# Four of the thirteen levels could not be. A conductor run is earthed in a pit at the foot of the
# stack and a straightening is cut from the ladder, and both of those were reached through [F]
# *before* it ever offered to hand you a ladder — so on those archetypes the player walked to the
# cradle, pressed F, and picked up nothing. No ladder, no dogs, nothing to climb with.
#
# Every suite in this project tested the middle of its own job. Nothing tested the first ten
# seconds of all of them, which is the one thing every job has in common and the only thing that
# has to work before any of the rest can.
#
#   make godot-script SCRIPT=res://scripts/test_start.gd

extends SceneTree

const LEVELS := ["00-greybox", "01-back-yard", "02-chapel-street", "03-briggs-dyeworks",
	"04-st-annes", "05-corn-mill", "08-hollin-bank", "09-the-gasworks", "11-pitchcombe-mill"]

var failures := 0


func _init() -> void:
	for id in LEVELS:
		await _can_start(id)
	await _can_leave()
	print("START: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


func _can_start(level_id: String) -> void:
	root.set_meta("job_level", level_id)
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame

	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var arch := String(player.jack.level_archetype())

	# Walked to the cradle, which is where the game says the materials are.
	var at: Vector3 = chimney.global_position + chimney.cradle_point()
	player.global_position = Vector3(at.x, player.global_position.y, at.z)
	player.set_height_m(0.0)
	player.on_ladder = false
	await physics_frame
	_check(player.at_cradle(), "%s (%s): the cradle is where you can stand" % [level_id, arch])

	# And pressed F, which is the only way to pick anything up in this game.
	player._pick_up()
	await physics_frame
	_check(player.carrying_ladder,
		"%s (%s): F at the cradle puts a ladder on his shoulder" % [level_id, arch])
	_check(player.dogs_carried > 0,
		"%s (%s): and dogs in the bag (%d)" % [level_id, arch, player.dogs_carried])

	world.free()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1


## And out again. There was no way: the only key that left a level was Enter once the job was
## done, so a player who took the wrong job had the window button and nothing else.
func _can_leave() -> void:
	root.set_meta("job_level", "00-greybox")
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player: Node = world.get_node("Player")

	_check(not player.leaving, "a job does not start by asking whether you want to leave it")

	# Halfway up, nothing finished.
	player.set_height_m(9.0)
	player.on_ladder = true
	await physics_frame
	_check(player.settlement.is_empty() and not player.at_top, "the job is not done")

	player._unhandled_input(_key(KEY_ESCAPE))
	await physics_frame
	_check(player.leaving, "escape asks")

	# Asked twice: saying no puts you back on the ladder rather than throwing the climb away.
	player._unhandled_input(_key(KEY_ESCAPE))
	await physics_frame
	_check(not player.leaving, "and escape again says no, and you are still on her")
	_check(is_instance_valid(world), "with the level still standing")

	# Not while he is in the air. The last thing anybody needs mid-fall is a menu.
	player.falling = true
	player._unhandled_input(_key(KEY_ESCAPE))
	await physics_frame
	_check(not player.leaving, "and it does not ask while he is falling")
	player.falling = false

	world.free()


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e
