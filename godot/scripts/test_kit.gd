# The shed, and the one stance that is a thing rather than a technique.
#
# Two failures this is here to stop coming back, both found by playing rather than by testing:
#
#  1. Every stance in the table was available on every job, so the bosun's chair — £75, twenty
#     seconds to rig, the only stance in the game that costs no grip at all — was something a
#     player arrived at by pressing Q four times having never heard of one. It read as a bug.
#
#  2. Q both advanced the stance and cancelled a rig in progress. The way anybody asks for a
#     stance four steps up the table is to press Q four times, and doing that rigged, cancelled,
#     rigged and cancelled, leaving them exactly where they started with no explanation. That is
#     what "sitting in a chair seems impossible here" actually was.
#
#   make godot-script SCRIPT=res://scripts/test_kit.gd

extends SceneTree

const ONE_HAND := 0
const BELTED := 3
const CHAIR := 4

var failures := 0


func _init() -> void:
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame

	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var jack = player.jack
	_put_on_ladder(player, chimney, 18.0)
	await physics_frame

	# --- no chair on the job, so no chair on the chimney ----------------------------------------
	player.has_chair = false
	jack.set_stance(BELTED)
	player._cycle_stance()
	await physics_frame
	_check(player.rigging_to < 0, "with no chair on the cart, Q does not start rigging one")
	_check(jack.get_stance() == ONE_HAND,
		"it drops back to the bottom of the table instead, which is instant and always available")

	# --- with one, it is exactly the stance the table describes ---------------------------------
	player.has_chair = true
	jack.set_stance(BELTED)
	player._cycle_stance()
	await physics_frame
	_check(player.rigging_to == CHAIR, "with a chair on the cart, Q rigs it")
	var want: float = jack.stance_setup_seconds(CHAIR)
	_check(absf(player.rig_total - want) < 0.01, "and it takes the %.0f s the table says" % want)

	# --- and pressing Q again does not undo it ---------------------------------------------------
	#
	# The whole complaint, in one assertion: a second press while rigging must not leave the player
	# standing where they started. From the top of the table it comes off, which is the cancel and
	# has to stay instant — the fastest way out of a stance you cannot afford must never itself
	# cost five seconds.
	player._cycle_stance()
	await physics_frame
	_check(jack.get_stance() == ONE_HAND and player.rigging_to < 0,
		"Q from the top of the table comes off it, instantly")

	# --- mashing Q from the bottom arrives at the chair ------------------------------------------
	#
	# Four presses in four frames, which is how a player asks for something four steps up. Before
	# this it rigged and cancelled twice and arrived nowhere.
	jack.set_stance(ONE_HAND)
	player._cancel_rig()
	for i in 4:
		player._cycle_stance()
		await physics_frame
	_check(player.rig_want == CHAIR, "four quick presses of Q ask for the chair")
	_check(player.rigging_to < CHAIR,
		"and he starts at the bottom of the table, not at the chair — which is the whole point")

	# --- and holding still gets you into it ------------------------------------------------------
	#
	# The other half of "seems impossible": that the seconds can actually be served. Rigging the
	# chair straight from one hand is twenty seconds at eight grip a second and nobody has a
	# hundred and sixty grip, which is why it must be climbed rather than jumped to: 1.5 s at 8,
	# 3 s at 4, 5 s at 4, then the twenty at 1, because by then he is belted on.
	var rungs := 0.0
	for st in [1, 2, 3, 4]:
		rungs += jack.stance_setup_seconds(st)
	var guard := int(rungs * 60.0) + 240
	while player.rigging_to >= 0 and guard > 0:
		guard -= 1
		await physics_frame
	_check(jack.get_stance() == CHAIR,
		"and standing still for the %.0f s of it puts him in it, with grip to spare" % rungs)
	_check(jack.grip() > 0.0, "he did not run out of hand on the way up the table")
	_check(jack.stance_drain_rate(CHAIR) <= 0.01,
		"which is what it was for: no grip going out at all")

	await _the_whole_chain()

	print("KIT: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


## Shed to van to chimney, through the real screens and the real tin.
##
## Every part of this is covered somewhere — Career::Buy in doctest, the stance gate above — and
## none of that says the chain works. It runs through three scenes and a file on disk, and the way
## it breaks is that one of them writes the tin and the next one does not read it: the player buys
## a chair, sees it on the cart, arrives on the chimney without one, and the game has no way to
## tell them why.
func _the_whole_chain() -> void:
	var tin := "user://test_kit_career.json"
	var seed_tin := FileAccess.open(tin, FileAccess.WRITE)
	seed_tin.store_string('{"money": 400, "reputation": 30}')
	seed_tin.close()

	var yard: Node = load("res://scenes/yard.tscn").instantiate()
	yard.career_path = tin
	root.add_child(yard)
	await process_frame
	yard.shed_open = true
	yard.shed_row = yard.SHED.find("bosunsChair")
	yard.shed_choose()
	_check(yard.jack.career_owns("bosunsChair"), "bought a chair in the yard")
	_check(absf(float(yard.career.get("money", 0.0)) - 325.0) < 0.5,
		"and £75 came out of the tin, not nothing and not twice")
	yard.free()

	var board: Node = load("res://scenes/jobs.tscn").instantiate()
	board.career_path = tin
	root.add_child(board)
	await process_frame
	_check(board.jack.career_owns("bosunsChair"), "the board reads the same tin the yard wrote")
	board.open_van()
	_check(board.jack.career_carrying("bosunsChair"), "and it is on the cart, because you bought it")

	# Left in the shed, which is the state that has to survive the trip just as much as taking it.
	board.van_toggle("bosunsChair")
	_check(not board.jack.career_carrying("bosunsChair"), "the van can leave it behind")
	board.van_toggle("bosunsChair")
	_check(board.jack.career_carrying("bosunsChair"), "and pick it up again")
	board.free()

	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	var kit_player: Node = world.get_node("Player")
	kit_player.career_path = tin
	root.add_child(world)
	await physics_frame
	_check(kit_player.has_chair, "and the chimney knows there is a chair on the job")
	_check(kit_player.jack.kit_chair(), "the sim knows it too, which is what the stance asks")
	world.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(tin))


func _put_on_ladder(player: Node, chimney: Node, height: float) -> void:
	player.ladder_top = maxf(player.ladder_top, height + 2.0)
	chimney.set_ladder_top(player.ladder_top)
	var foot: Vector3 = chimney.global_position + chimney.face_point(height)
	var out: Vector3 = foot - chimney.global_position
	out.y = 0.0
	player.global_position = foot + out.normalized() * player.BODY_OFF_LADDER
	player.set_height_m(height)
	player.on_ladder = true
	player._shuffle = 0.0
	player._remount_block = 0.0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
