# Hands and feet on the rungs — rung_grip.gd, checked on the solved skeleton.
#
# Not "the IK has a target": the bone itself, after the solve, is where the rung is. A target the
# limb cannot reach is the exact failure this replaced — a hand waving near a rung it never holds.
#
#   godot --path godot --headless --script res://scripts/test_grip.gd

extends SceneTree

const REACH_TOLERANCE := 0.06   ## metres between a solved hand or ankle and its rung, at rest
const STRETCH_TOLERANCE := 0.35 ## the same while climbing flat out, when the holding limbs straighten
const NAMES := ["left hand", "right hand", "left foot", "right foot"]

var failures := 0
var player: Node
var chimney: Node3D
var skel: Skeleton3D


func _init() -> void:
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	player = world.get_node("Player")
	chimney = world.get_node("Chimney")
	skel = player.find_child("Skeleton3D", true, false)
	skel.skeleton_updated.connect(_capture)
	player.ladder_top = 30.0
	chimney.set_ladder_top(30.0)

	# --- standing on the ladder: all four on rungs ------------------------------------------------
	_put_on_ladder(10.0)
	await _frames(40)
	for i in 4:
		var err := _reach_error(i)
		_check(err < REACH_TOLERANCE, "%s is on its rung (%.3f m off)" % [NAMES[i], err])
		var rung_h: float = player.grip.limb_rung(i) * chimney.RUNG_GAP
		_check(absf(rung_h - roundf(rung_h / chimney.RUNG_GAP) * chimney.RUNG_GAP) < 0.001,
			"%s holds a real rung (%.2f m)" % [NAMES[i], rung_h])
	var hands_at: float = player.grip.limb_target(0).y
	_check(player.grip.limb_target(0).y > player.height_m() + 1.2, "the hands are above his head, not at his waist")
	_check(player.grip.limb_target(2).y < player.height_m() + 0.8, "and the feet are down by his feet")

	# --- climbing: limbs move rung to rung, in pairs, always two holding ---------------------------
	var start := []
	for i in 4:
		start.append(player.grip.limb_rung(i))
	var both_pairs_moving := false
	var max_err := 0.0
	player.climb_input = 1.0
	for f in 120:
		await physics_frame
		# While a pair reaches, the other pair must be holding its rung.
		var moving: int = player.grip.reaching_pair()
		if moving >= 0:
			for i in 4:
				if [0, 1, 1, 0][i] != moving:
					max_err = maxf(max_err, _reach_error(i))
	player.climb_input = 0.0
	await _frames(30)
	for i in 4:
		_check(player.grip.limb_rung(i) > start[i],
			"%s moved up the ladder rung by rung (%d -> %d)" % [NAMES[i], start[i], player.grip.limb_rung(i)])
	# Climbing flat out (1.6 m/s) the body rises about 0.3 m during one reach, and the holding pair
	# straightens to follow it — a climber pulling up does exactly that. What must not happen is the
	# holding pair letting go: it stays within a stretched arm of its rung, and is exact once he stops.
	_check(max_err < STRETCH_TOLERANCE,
		"while one pair reaches, the other keeps hold of its rungs (worst stretch %.3f m)" % max_err)
	for i in 4:
		_check(_reach_error(i) < REACH_TOLERANCE, "stopped again, %s is on a rung (%.3f m off)" % [NAMES[i], _reach_error(i)])

	# --- a flexing section carries the hands with it (CLIMB-005 acceptance 2) ----------------------
	# The rungs a hand holds are where the drawn ladder is, bow included; and the bow is the sim's
	# flex (Stack::FlexDeflectionM via stack_step), capped for the eye in chimney.gd. Set within one
	# tick, because the player resets the bow from the sim on the next.
	var r: int = player.grip.limb_rung(0)
	var rh: float = r * chimney.RUNG_GAP
	var straight: Vector3 = player.grip._rung_point(0, r)
	chimney.set_bow(rh - 3.0, rh + 5.0, 0.25)
	var bowed: Vector3 = player.grip._rung_point(0, r)
	var bow: Vector3 = chimney.bow_at(rh)
	_check(bow.length() > 0.05 and (bowed - straight).distance_to(bow) < 0.001,
		"a bowing section carries the hand's rung with it (%.3f m)" % (bowed - straight).length())
	chimney.set_bow(0.0, 0.0, 0.0)

	# --- at the top of the ladder, nothing holds a rung that is not there --------------------------
	player.ladder_top = player.height_m() + 2.0
	chimney.set_ladder_top(player.ladder_top)
	player.climb_input = 1.0
	for f in 240:
		await physics_frame
	player.climb_input = 0.0
	await _frames(30)
	var top_rung := floori((player.ladder_top - 0.05) / chimney.RUNG_GAP)
	for i in [2, 3]:
		_check(player.grip.limb_rung(i) <= top_rung,
			"at the top, %s stands on a real rung (%d, top %d)" % [NAMES[i], player.grip.limb_rung(i), top_rung])
	for i in [0, 1]:
		var on_rung: bool = player.grip.limb_rung(i) <= top_rung
		_check(on_rung or player.grip.on_wall(i),
			"at the top, %s holds a real rung or the brick, never air" % NAMES[i])
	for i in 4:
		_check(_reach_error(i) < REACH_TOLERANCE * 2.0,
			"and %s reaches what it holds (%.3f m off)" % [NAMES[i], _reach_error(i)])

	# --- the hammer hand lets go to tap -----------------------------------------------------------
	# A real tap, through the verb: the hand lets go for the swing and takes its rung back as soon as
	# the swing is over, not after the whole of tapTestSeconds.
	player.ladder_top = 30.0
	await _frames(10)
	_check(player.target_id >= 0, "there is a joint to tap")
	player._tap()
	await _frames(10)
	_check(player.grip._grip[1] < 0.1, "the right hand lets go of its rung to tap")
	_check(player.grip._grip[0] > 0.9, "and the left hand keeps hold")
	await _frames(24)   # the tap clip is 0.42 s
	_check(player.tapping > 0.0, "(the tap itself is still running)")
	_check(player.grip._grip[1] > 0.9, "and the hand is back on its rung once the swing is done")

	# --- off the ladder, the grip lets go entirely -------------------------------------------------
	player.on_ladder = false
	player.global_position += Vector3(3, 0, 0)
	await _frames(20)
	var held := 0
	for i in 4:
		if player.grip._grip[i] > 0.01:
			held += 1
	_check(held == 0, "off the ladder nothing holds a rung")

	print("GRIP: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


func _put_on_ladder(h: float) -> void:
	var foot: Vector3 = chimney.global_position + chimney.face_point(h)
	var out: Vector3 = foot - chimney.global_position
	out.y = 0.0
	player.global_position = foot + out.normalized() * player.BODY_OFF_LADDER
	player.set_height_m(h)
	player.on_ladder = true
	player._shuffle = 0.0
	player.face_the_wall()


## How far the solved end bone is from its target: the wrist for a hand, the ankle for a foot.
##
## Read from the pose captured at `skeleton_updated`, which fires after the IK modifiers have run.
## Reading the skeleton at any other moment gives the animation's pose with the IK undone, which is
## how the first version of this test measured hands half a metre from rungs they were holding.
func _reach_error(limb: int) -> float:
	var bone := skel.find_bone(RungGrip.CHAINS[limb][2])
	var at: Vector3 = skel.global_transform * _solved.get(bone, skel.get_bone_global_pose(bone)).origin
	return at.distance_to(player.grip.limb_target(limb))


var _solved := {}


func _capture() -> void:
	for chain in RungGrip.CHAINS:
		for name in chain:
			var b := skel.find_bone(name)
			_solved[b] = skel.get_bone_global_pose(b)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		failures += 1
		printerr("  FAIL  %s" % what)
