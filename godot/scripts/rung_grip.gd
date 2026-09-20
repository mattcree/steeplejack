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
const FOOT_ABOVE_FEET := [0.16, 0.44]   ## and its foot rung, a rung apart. A leg is 0.84 m: lower than 0.15 it cannot reach, higher than this it jack-knifes
const HAND_SPREAD := 0.15               ## off the ladder's centre line, along the rung
const FOOT_SPREAD := 0.12
const HAND_PROUD := 0.035               ## the wrist sits a little in front of the rung it grips
const FOOT_LIFT := 0.06                 ## the ankle sits above the rung the sole is on
const HAND_ON_WALL_ABOVE_FEET := 1.55   ## at the head of the ladder, where a hand goes on the brick
const WALL_PALM := 0.06                 ## the wrist, off the face of the brick
const MIN_ANKLE_ABOVE_FEET := 0.20     ## the lowest a straight leg puts the ankle, plus a little bend
const LEG := 0.84                       ## hip to sole on the rig
const SHIN := 0.42                      ## ankle to knee: half the leg, and how high above a rung
                                        ## the knee wants to sit if the shin is to stand up straight
const KNEE_PROUD := 0.05                ## and how far it leads the foot, off the brickwork
const LEG_SLACK := 0.12                 ## a climbing leg is never locked straight. At 0.04 the
                                        ## measured lower leg came out 0.997 of its own bone length
                                        ## — a locked knee — because the two feet sit a rung apart
                                        ## and the hips were placed for the higher one.
const NEVER_STRAIGHT := 0.96            ## the furthest any limb may be asked to reach, as a fraction
                                        ## of its own bones. A two-bone IK handed a target at exactly
                                        ## chain length locks the joint dead straight, and one past it
                                        ## locks straight AND stops tracking. Both read as a snapped
                                        ## elbow or a backwards knee, so no target is ever allowed
                                        ## that far out: a climber's joints are never locked.
const HIP_ABOVE_FEET := 0.95            ## the rig's hips, above its feet
const MAX_DROP := 0.40                  ## the body never settles further than this below the capsule
const MAX_RISE := 0.16                  ## nor further above it than half a rung                  ## the most the drawn body settles at the head of the ladder
const STEP_SECONDS := 0.16               ## one reach, rung to rung
const STEP_ARC := 0.10                  ## how far off the ladder a moving limb swings
const DROP_RATE := 1.2                  ## metres a second the body settles towards its stance
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
var _reach := [0.0, 0.0, 0.0, 0.0]  ## root to end with the limb straight, measured off the rig

## Debug capture, off unless the capture script asks for it (`make shot CMDS="...,legs"`). A solved
## pose can only be read from inside a SkeletonModifier3D's own pass — read anywhere else it is a
## frame stale or plain wrong, which is how a first attempt at this readout reported every limb 68
## metres from its own shoulder. So RungOrient fills these in while it has the real thing.
var watch_limbs := false
var _watch := ["", "", "", ""]

## Where each chain starts — the shoulder or the hip — in the world. Kept here because a bone's
## solved position can only be read from inside the modifier pass, and `_place()` needs it a frame
## later to know how far it may ask a limb to reach. One frame stale is nothing; reading it at the
## wrong time is not stale but wrong, and silently made the reach clamp a no-op.
var _root := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _have_root := false
var _was_on := false
var _drop := 0.0                    ## how far below the capsule the drawn body sits


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
		_reach[i] = _chain_reach(i)
	# Last on the skeleton, so it turns the hands and feet after the IK has placed them.
	var orient := RungOrient.new()
	orient.name = "RungOrient"
	orient.grip = self
	skeleton.add_child(orient)


## How far this limb reaches with both bones in line, taken from the rig's own rest pose rather
## than a constant, so a re-export that changes the skeleton cannot leave a stale number here.
func _chain_reach(limb: int) -> float:
	var b0 := skeleton.find_bone(CHAINS[limb][0])
	var b1 := skeleton.find_bone(CHAINS[limb][1])
	var b2 := skeleton.find_bone(CHAINS[limb][2])
	if b0 < 0 or b1 < 0 or b2 < 0:
		return LEG
	var p0: Vector3 = skeleton.get_bone_global_rest(b0).origin
	var p1: Vector3 = skeleton.get_bone_global_rest(b1).origin
	var p2: Vector3 = skeleton.get_bone_global_rest(b2).origin
	return p0.distance_to(p1) + p1.distance_to(p2)


## The one rule that makes hyperextension unreachable rather than unlikely: whatever a limb is
## asked to hold, it is asked no further out than its own bones minus a few per cent. A rung that
## is genuinely too far away pulls the hand or foot short of it, which looks like a man not quite
## reaching — the truth — instead of a limb snapping inside out to pretend it got there.
func _within_reach(limb: int, root: Vector3, want: Vector3) -> Vector3:
	var span: float = _reach[limb] * NEVER_STRAIGHT
	var d: Vector3 = want - root
	var l: float = d.length()
	if l <= span or l < 0.0001:
		return want
	return root + d * (span / l)


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
	return _drop


## Where the drawn body should sit: `_hips_above_rung()` over the rung his weight is on.
##
## The rungs are the ladder's and do not move, so the body has to. Fixing the body to the capsule
## instead left the bearing leg folded to half its length — a permanent squat — because which rung
## he was standing on shifted by up to half a rung as he climbed. Now the lower foot's rung sets
## his height, which is also what makes him rise as he pushes up on it: the step is the climb.
## How high the hips sit over the rung the weight is on — derived, not chosen.
##
## A leg is a fixed length, so how far out from the ladder the body stands and how high the hips
## can be are the same number asked twice. Standing 0.30 m out the hips can be 0.78 up; standing
## 0.38 m out they can only be 0.73, and a body that insists on both is a body whose feet cannot
## reach the rung they are supposed to be standing on.
##
## This is why a climber further from the ladder is also lower and more folded, and it is the whole
## reason the legs stopped passing through the rails: they are not straight enough to any more.
func _hips_above_rung() -> float:
	var reach := maxf(LEG - LEG_SLACK, 0.1)
	var out := _standoff()
	return sqrt(maxf(reach * reach - out * out, 0.04))


## How far the drawn body stands off the ladder's line. The player owns both halves of it.
func _standoff() -> float:
	return float(player.BODY_OFF_LADDER) - float(player.CLIMB_IN)


func _wanted_drop() -> float:
	var lower := 2 if _rung[2] <= _rung[3] else 3
	var rung_h: float = maxf(_rung[lower], 0) * chimney.RUNG_GAP
	var want_feet := rung_h + FOOT_LIFT + _hips_above_rung() - HIP_ABOVE_FEET
	return clampf(float(player.call("height_m")) - want_feet, -MAX_RISE, MAX_DROP)


## The feet the grip measures its rungs from: the capsule's, never the drawn body's — the drawn
## body is placed from the rungs, so measuring the rungs from it would chase its own tail.
func _feet() -> float:
	return float(player.call("height_m"))


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
		# Eased, so he rises with the push rather than snapping when a foot takes a new rung.
		_drop = move_toward(_drop, _wanted_drop(), dt * DROP_RATE)
	else:
		_drop = 0.0

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
	var out := _out()
	var along: Vector3 = Vector3(0, 0, 1) * float(SIDE[limb])
	var root: Vector3 = _root[limb] if _have_root else (skeleton.global_transform
		* skeleton.get_bone_global_rest(skeleton.find_bone(CHAINS[limb][0])).origin)
	at = _within_reach(limb, root, at)
	_target[limb].global_position = at
	# Well off the limb's own line, or the bend has no plane to happen in and the joint flips to
	# whichever side it likes: that is what put his knees out sideways and his elbows behind him.
	#
	# An elbow goes down, out and back from the shoulder.
	#
	# A knee goes down and *towards* the brickwork, because that is the only way a human knee
	# bends. This pole was moved out to the far side once, to stop the bent leg driving through
	# the rungs, and it did stop that — by hyperextending him. He climbed on a pair of bird's
	# legs, shin raked back under him, knee pointing out over the town.
	#
	# The clipping was never the knee's fault and the answer was never to break the joint. It is
	# standoff: hips hang back off a ladder far enough that a knee coming forward passes behind
	# the stiles instead of through them. That is what BODY_OFF_LADDER is for, and it is also why
	# the trade packs a ladder off the wall in the first place — "so there's room for your boots
	# to go through on the rungs".
	if limb < 2:
		_pole[limb].global_position = root + along * 0.55 + out * 0.45 - Vector3.UP * 0.35
	else:
		# The knee is aimed from the FOOT, not from the hip, and that is the whole of it.
		#
		# A man on a ladder keeps his shin near enough parallel with the stiles and lets the THIGH
		# do the opening and closing; his torso then sits wherever those two angles put it. Hung off
		# the hip, the pole could not express that — the knee wandered with the body and the raised
		# leg jack-knifed until the shin measured 104 degrees off vertical, which is a shin lying
		# flat. Put the pole where the knee actually belongs, a shin's length above the foot and a
		# hand's breadth off the brick, and the shin stands up on its own at any stance height.
		_pole[limb].global_position = at + Vector3.UP * SHIN + out * KNEE_PROUD + along * 0.03


## For the capture script: every limb's solved geometry as numbers. `straight` is how far the limb
## is actually extended over its own bone length — 1.00 is a locked joint, and NEVER_STRAIGHT is
## what keeps it away from there. `lower-limb` is how far the shin or forearm leans off vertical,
## which is the shape the climb is judged on: a climber's shin stays near enough parallel with the
## stiles and it is the thigh that opens and closes.
## Every frame, from inside the modifier: the real position of each chain's first bone.
func note_roots(skel: Skeleton3D) -> void:
	var xf := skel.global_transform
	for i in 4:
		var b := skel.find_bone(CHAINS[i][0])
		if b >= 0:
			_root[i] = xf * skel.get_bone_global_pose(b).origin
	_have_root = true


func capture(skel: Skeleton3D) -> void:
	var names := ["hand.l", "hand.r", "foot.l", "foot.r"]
	for i in 4:
		var b0 := skel.find_bone(CHAINS[i][0])
		var b1 := skel.find_bone(CHAINS[i][1])
		var b2 := skel.find_bone(CHAINS[i][2])
		if b0 < 0 or b1 < 0 or b2 < 0:
			continue
		var xf := skel.global_transform
		var root: Vector3 = xf * skel.get_bone_global_pose(b0).origin
		var mid: Vector3 = xf * skel.get_bone_global_pose(b1).origin
		var tip: Vector3 = xf * skel.get_bone_global_pose(b2).origin
		var straight: float = root.distance_to(tip) / maxf(_reach[i], 0.001)
		var lower: Vector3 = tip - mid
		var lean: float = rad_to_deg(Vector3.DOWN.angle_to(lower)) if lower.length() > 0.001 else 0.0
		var asked: float = _root[i].distance_to(_target[i].global_position) / maxf(_reach[i], 0.001)
		var drift: float = root.distance_to(_root[i])
		_watch[i] = "%-7s straight %.3f  asked %.3f  infl %.2f  drift %.3f  lower %5.1f deg" % [
			names[i], straight, asked, _grip[i], drift, lean]


func describe_limbs() -> String:
	var out_s := ""
	for i in 4:
		out_s += "\n  " + (_watch[i] if _watch[i] != "" else "%d not captured" % i)
	return out_s


## For tests: the world position a limb's target is at, and whether that limb is mid-reach.
func limb_target(limb: int) -> Vector3:
	return _target[limb].global_position


func limb_rung(limb: int) -> int:
	return _rung[limb]


func reaching_pair() -> int:
	return _moving
