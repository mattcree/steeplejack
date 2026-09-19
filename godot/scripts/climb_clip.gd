# The climb, built as a clip rather than poked into bones every frame.
#
# Mannequiny ships idle, run, fall and some fighting, and no climb — and this is a game about
# climbing. A man on a ladder with his arms at his sides and his feet in mid-air was the single
# thing that made the build read as broken no matter what else was right.
#
# The lesson carried over from the last engine was **do not set bone rotations from gameplay code**;
# pose the character with an AnimationPlayer playing whole clips. That lesson is kept. What Godot
# allows that the last engine did not is *building* a clip from a table, once, at load — so this is
# still an AnimationPlayer playing a whole clip, and the clip is authored in text next to everything
# else instead of in a tool nobody on this project has.
#
# ## Why the pose is written as directions and not as angles
#
# The obvious way is a table of Euler deltas per bone. It was tried first and it is unworkable: the
# axis that raises a shoulder is not the axis that raises a hip, the rig's rest orientations are
# arbitrary, and there is no way to find any of them except by guessing, rendering a frame, and
# guessing again. The first attempt put both arms out sideways.
#
# So each bone instead names **where it should point, in model space**, which is a thing a person
# can reason about without knowing anything about the rig: the reaching forearm points up and into
# the wall, the trailing thigh points down. The solve turns that into the bone's local rotation by
# asking which rotation takes the bone's rest direction — the direction its own child sits in — onto
# the target. That needs the parent's posed orientation, so bones are solved down the chain in
# skeleton order, which is already parent-first.
#
# Mannequiny faces **+Z**, and he faces the brickwork, so "into the wall" is +Z and "up" is +Y.

class_name ClimbClip

const SKELETON := "root/Skeleton3D"

## One full stride, both hands. Slow: a jack on a ladder is not in a hurry, and a fast cycle under a
## slow climb is what reads as skating.
const STRIDE_SECONDS := 1.7

## bone -> [where it points reaching, where it points trailing], in model space.
##
## The reach pose is left hand high on a rung with the right knee coming up; the trail pose is that
## mirrored, which is what makes the loop a climb rather than a twitch.
const AIM := {
	# Reaching arm: up the ladder and into it. Trailing arm: holding a rung at chest height.
	"upperarm.l": [Vector3(0.22, 0.90, 0.38), Vector3(0.34, 0.16, 0.93)],
	"lowerarm.l": [Vector3(0.06, 0.84, 0.54), Vector3(0.10, -0.12, 0.99)],
	"upperarm.r": [Vector3(-0.34, 0.16, 0.93), Vector3(-0.22, 0.90, 0.38)],
	"lowerarm.r": [Vector3(-0.10, -0.12, 0.99), Vector3(-0.06, 0.84, 0.54)],

	# Trailing leg straight and taking the weight; leading leg with the knee up and the shin down
	# onto the next rung.
	"thigh.l":    [Vector3(0.10, -0.97, 0.20), Vector3(0.22, -0.42, 0.88)],
	"calf.l":     [Vector3(0.06, -0.99, 0.10), Vector3(0.10, -0.96, -0.27)],
	"thigh.r":    [Vector3(-0.22, -0.42, 0.88), Vector3(-0.10, -0.97, 0.20)],
	"calf.r":     [Vector3(-0.10, -0.96, -0.27), Vector3(-0.06, -0.99, 0.10)],

	# Leaning in. A climber's weight is over his feet and his chest is near the rungs, not upright
	# like a man waiting for a bus.
	"spine_01":   [Vector3(0.0, 0.97, 0.26), Vector3(0.0, 0.97, 0.26)],
	"spine_02":   [Vector3(0.0, 0.98, 0.20), Vector3(0.0, 0.98, 0.20)],
}

## Which child each posed bone points at. A bone has no direction of its own; it has the direction
## its child sits in, and that is what gets aimed.
const CHILD := {
	"upperarm.l": "lowerarm.l", "lowerarm.l": "hand.l",
	"upperarm.r": "lowerarm.r", "lowerarm.r": "hand.r",
	"thigh.l": "calf.l", "calf.l": "foot.l",
	"thigh.r": "calf.r", "calf.r": "foot.r",
	"spine_01": "spine_02", "spine_02": "neck_01",
}


static func install(ap: AnimationPlayer, skel: Skeleton3D) -> void:
	if ap.has_animation("climb"):
		return

	var reach := _solve(skel, 0)
	var trail := _solve(skel, 1)

	var a := Animation.new()
	a.length = STRIDE_SECONDS
	a.loop_mode = Animation.LOOP_LINEAR

	for bone in AIM:
		if not reach.has(bone):
			continue
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, "%s:%s" % [SKELETON, bone])
		a.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
		# Three keys, not two: the loop must come back to where it started, or the last frame snaps
		# to the first and the cycle hitches once a stride.
		a.rotation_track_insert_key(t, 0.0, reach[bone])
		a.rotation_track_insert_key(t, STRIDE_SECONDS * 0.5, trail[bone])
		a.rotation_track_insert_key(t, STRIDE_SECONDS, reach[bone])

	var lib: AnimationLibrary = ap.get_animation_library(&"")
	if lib == null:
		lib = AnimationLibrary.new()
		ap.add_animation_library(&"", lib)
	lib.add_animation(&"climb", a)


## Local rotations for every posed bone in pose `which` (0 reach, 1 trail).
##
## Walks the whole skeleton in order so that each bone's parent orientation is known by the time it
## is reached — that is the part a per-bone Euler table cannot do, and the reason the arms came out
## sideways when it was tried.
static func _solve(skel: Skeleton3D, which: int) -> Dictionary:
	var out := {}
	var model: Array[Basis] = []
	model.resize(skel.get_bone_count())

	for idx in skel.get_bone_count():
		var parent := skel.get_bone_parent(idx)
		var parent_basis: Basis = model[parent] if parent >= 0 else Basis()
		var rest: Basis = Basis(skel.get_bone_rest(idx).basis.get_rotation_quaternion())
		var local := rest

		var name := skel.get_bone_name(idx)
		if AIM.has(name):
			var child := skel.find_bone(CHILD[name])
			if child >= 0:
				# Where this bone points when nothing is posed, in its own space.
				var rest_dir: Vector3 = skel.get_bone_rest(child).origin.normalized()
				# Where we want it to point, brought out of model space into the parent's.
				var want: Vector3 = (parent_basis.inverse() * (AIM[name][which] as Vector3)).normalized()
				if rest_dir.length_squared() > 0.0 and want.length_squared() > 0.0:
					local = Basis(Quaternion(rest_dir, want))
					out[name] = local.get_rotation_quaternion()

		model[idx] = parent_basis * local

	return out
