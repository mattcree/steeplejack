# Hands and feet on the rungs — the climb as a climber does it, not as a clip.
#
# The climb used to be a canned cycle played faster or slower with his speed, so a hand landed on a
# rung only by coincidence and the first person to play it called it "a very wrong animation". Here
# every hand and foot is *planted* on a real rung of the real ladder (chimney.gd's own geometry: a
# rung every RUNG_GAP, the stiles RAIL_GAP apart) and stays there, and the body moves between them.
# When a limb's rung falls too far behind where the body wants it, that limb lets go, arcs out
# from the ladder, and takes the next rung. Limbs move in diagonal pairs — left hand with right
# foot, then right hand with left foot — and a pair only moves while the other is holding, which is
# the whole of what makes it read as climbing and not as swimming.
#
# The solve is Godot's TwoBoneIK3D, one per limb, over whatever the AnimationPlayer left: the clip
# gives the torso and the resting shape, the IK puts the hands and feet where the rungs are. The
# hammer arm lets go of its rung while it taps or strikes, so those clips still play.

class_name RungGrip
extends Node

const HAND_ABOVE_FEET := [1.78, 1.50]   ## each pair's hand rung, above the feet: staggered a rung apart so the pairs alternate
const FOOT_ABOVE_FEET := [0.22, 0.50]   ## and its foot rung. Where a relaxed body holds them; see _step on the stretch when climbing fast
const HAND_SPREAD := 0.15               ## off the ladder's centre line, along the rung
const FOOT_SPREAD := 0.12
const HAND_PROUD := 0.035               ## the wrist sits a little in front of the rung it grips
const FOOT_LIFT := 0.06                 ## the ankle sits above the rung the sole is on
const HAND_ON_WALL_ABOVE_FEET := 1.55   ## at the head of the ladder, where a hand goes on the brick
const WALL_PALM := 0.06                 ## the wrist, off the face of the brick
const MIN_ANKLE_ABOVE_FEET := 0.20     ## the lowest a straight leg puts the ankle, plus a little bend
const MAX_DROP := 0.35                  ## the most the drawn body settles at the head of the ladder
const STEP_SECONDS := 0.16               ## one reach, rung to rung
const STEP_ARC := 0.10                  ## how far off the ladder a moving limb swings
const FADE_RATE := 10.0                 ## how fast a limb takes hold or lets go, per second

# Limbs: 0 hand.l, 1 hand.r, 2 foot.l, 3 foot.r. Pairs: A = hand.l + foot.r, B = hand.r + foot.l.
const CHAINS := [
	["upperarm.l", "lowerarm.l", "hand.l"],
	["upperarm.r", "lowerarm.r", "hand.r"],
	["thigh.l", "calf.l", "foot.l"],
	["thigh.r", "calf.r", "foot.r"],
]
const PAIR := [0, 1, 1, 0]
const SIDE := [-1.0, 1.0, -1.0, 1.0]    ## which side of the ladder's centre, along its tangent

var player: Node3D
var chimney: Node3D
var skeleton: Skeleton3D

var _ik: Array[TwoBoneIK3D] = []
var _target: Array[Node3D] = []
var _pole: Array[Node3D] = []
var _rung := [0, 0, 0, 0]           ## the rung index each limb holds
var _from := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _moving := -1                   ## the pair in the air, or -1
var _step_t := 0.0
var _grip := [0.0, 0.0, 0.0, 0.0]   ## IK influence per limb, eased
var _was_on := false


func setup(p: Node3D, c: Node3D, skel: Skeleton3D) -> void:
	player = p
	chimney = c
	skeleton = skel
	for i in 4:
		var target := Node3D.new()
		target.name = "RungTarget%d" % i
		target.top_level = true
		add_child(target)
		var pole := Node3D.new()
		pole.name = "RungPole%d" % i
		pole.top_level = true
		add_child(pole)
		var ik := TwoBoneIK3D.new()
		ik.name = "RungIK%d" % i
		skeleton.add_child(ik)
		ik.setting_count = 1
		ik.set_root_bone_name(0, CHAINS[i][0])
		ik.set_middle_bone_name(0, CHAINS[i][1])
		ik.set_end_bone_name(0, CHAINS[i][2])
		ik.set_target_node(0, ik.get_path_to(target))
		ik.set_pole_node(0, ik.get_path_to(pole))
		ik.influence = 0.0
		_ik.append(ik)
		_target.append(target)
		_pole.append(pole)


## Where on the ladder a limb holds a given rung, in the world.
func _rung_point(limb: int, index: int) -> Vector3:
	if limb < 2 and index > _top_rung():
		# Flat on the brick, a little above the shoulder and wider than the rungs.
		var hh: float = _feet() + HAND_ON_WALL_ABOVE_FEET
		var wall: Vector3 = chimney.global_position + chimney.FACE * chimney.radius_at(hh) + Vector3(0, hh, 0)
		return wall + Vector3(0, 0, 1) * float(SIDE[limb]) * HAND_SPREAD * 1.6 + _out() * WALL_PALM
	var h: float = maxf(index, 0) * chimney.RUNG_GAP
	var base: Vector3 = chimney.global_position + chimney.face_point(h) + chimney.bow_at(h)
	var out := _out()
	var along := Vector3(0, 0, 1)   # chimney.gd lays the stiles out along world Z
	if limb < 2:
		return base + along * float(SIDE[limb]) * HAND_SPREAD + out * HAND_PROUD
	return base + along * float(SIDE[limb]) * FOOT_SPREAD + Vector3.UP * FOOT_LIFT


func _out() -> Vector3:
	var o: Vector3 = player.global_position - chimney.global_position
	o.y = 0.0
	return o.normalized() if o.length() > 0.01 else Vector3.RIGHT


## The rung a limb wants at this height of the feet. A foot never wants one above the top of the
## ladder. A hand that would is given `top + 1`, which _rung_point reads as "flat on the brick": at
## the head of a section there is no rung left to hold, and a steeplejack steadies himself on the
## wall. (The reach-ahead first had a hand closing on air a rung past the last section lashed.)
func _wanted(limb: int, feet: float) -> int:
	var above: float = HAND_ABOVE_FEET[PAIR[limb]] if limb < 2 else FOOT_ABOVE_FEET[PAIR[limb]]
	var top := _top_rung()
	var want := maxi(roundi((feet + above) / chimney.RUNG_GAP), 0)
	return mini(want, top + 1 if limb < 2 else top)


func _top_rung() -> int:
	return floori(maxf(float(player.get("ladder_top")) - 0.05, 0.0) / chimney.RUNG_GAP)


## How far the drawn body settles below the capsule at the head of the ladder, so that its feet
## stand on the top rung. A leg cannot put the ankle lower than ~0.15 m above the capsule's feet,
## and at the top the capsule stands level with the last rung, so without this the feet hung
## short of the only rung there is. Drawing only: the game's height and reach are unchanged.
func body_drop() -> float:
	if not _was_on:
		return 0.0
	var top_h: float = _top_rung() * chimney.RUNG_GAP
	var lowest := top_h + FOOT_LIFT - MIN_ANKLE_ABOVE_FEET
	return clampf(float(player.call("height_m")) - lowest, 0.0, MAX_DROP)


## The feet the grip works from: the drawn body's, settled at the top.
func _feet() -> float:
	return float(player.call("height_m")) - body_drop()


## Whether a limb is on the wall rather than a rung.
func on_wall(limb: int) -> bool:
	return limb < 2 and _rung[limb] > _top_rung()


## Once a physics tick, after the player has moved. `holding` says which limbs are on the ladder
## at all: an arm that is tapping, striking or lashing is doing that instead.
func update(dt: float, on_ladder: bool, holding: Array) -> void:
	var feet: float = _feet()
	if on_ladder and not _was_on:
		# Taking hold: every limb straight onto its rung, so he does not start by reaching from
		# wherever the walk cycle left him.
		for i in 4:
			_rung[i] = _wanted(i, feet)
			_from[i] = _rung_point(i, _rung[i])
		_moving = -1
	_was_on = on_ladder

	if on_ladder:
		_step(dt, feet, float(player.get("_climb_rate")))

	for i in 4:
		var want: float = 1.0 if on_ladder and holding[i] else 0.0
		_grip[i] = move_toward(_grip[i], want, dt * FADE_RATE)
		_ik[i].influence = _grip[i]
		_ik[i].active = _grip[i] > 0.0
		_place(i, dt)


func _step(dt: float, feet: float, rate: float) -> void:
	if _moving >= 0:
		_step_t += dt / STEP_SECONDS
		if _step_t >= 1.0:
			_moving = -1
		return
	# Which pair is furthest behind, and is it far enough behind to be worth a reach?
	var worst := -1
	var worst_gap := 0
	for pair in 2:
		var gap := 0
		for i in 4:
			if PAIR[i] == pair:
				gap = maxi(gap, absi(_wanted(i, feet) - _rung[i]))
		if gap > worst_gap:
			worst_gap = gap
			worst = pair
	if worst < 0 or worst_gap < 1:
		return
	# At the full climb speed the holding pair does get stretched — the body rises 0.3 m during one
	# reach — and that is right: a climber pulling up fast straightens the arm he is pulling on. The
	# rungs are placed for the body at rest, and the stretch is allowed while he moves (test_grip).
	# Reach for where the body will be, not where it is: by the time this pair has its rung and the
	# other pair has had its turn, he has climbed two reaches further. Aimed at the present, the
	# holding pair was left behind a moving body and stretched past the length of an arm.
	var ahead: float = feet + rate * STEP_SECONDS * 2.0
	_moving = worst
	_step_t = 0.0
	for i in 4:
		if PAIR[i] == worst:
			_from[i] = _target[i].global_position
			_rung[i] = _wanted(i, ahead)


func _place(limb: int, _dt: float) -> void:
	var to: Vector3 = _rung_point(limb, _rung[limb])
	var at: Vector3 = to
	if _moving == PAIR[limb] and _step_t < 1.0:
		var u: float = smoothstep(0.0, 1.0, _step_t)
		at = (_from[limb] as Vector3).lerp(to, u) + _out() * STEP_ARC * sin(PI * _step_t)
	_target[limb].global_position = at
	# Elbows low and a little out, knees towards the ladder: the bend a body on a ladder makes. The
	# first poles sat beside and behind the shoulders and put the elbows up by his ears.
	var out := _out()
	var along: Vector3 = Vector3(0, 0, 1) * float(SIDE[limb])
	var root: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(
		skeleton.find_bone(CHAINS[limb][0])).origin
	if limb < 2:
		_pole[limb].global_position = root + along * 0.25 + out * 0.05 - Vector3.UP * 0.8
	else:
		_pole[limb].global_position = root - out * 0.3 + along * 0.04 - Vector3.UP * 0.6


## For tests: the world position a limb's target is at, and whether that limb is mid-reach.
func limb_target(limb: int) -> Vector3:
	return _target[limb].global_position


func limb_rung(limb: int) -> int:
	return _rung[limb]


func reaching_pair() -> int:
	return _moving
