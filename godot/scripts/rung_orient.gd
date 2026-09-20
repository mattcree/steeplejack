# Hands and feet pointed at what they are holding.
#
# TwoBoneIK3D puts the wrist and the ankle where the rung is; it says nothing about which way they
# face. Left to the clip underneath, a boot stood sideways on its rung and a hand met it edge-on.
# This runs after the IK (it is the last modifier on the skeleton) and turns the four end bones:
# the sole flat on the rung with the toes at the wall, the hand across the rung as a grip.
#
# A SkeletonModifier3D rather than a line in _process, because only a modifier runs inside the
# skeleton's own update — anything written outside it is overwritten by the next pose.

class_name RungOrient
extends SkeletonModifier3D

var grip: RungGrip


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or grip == null:
		return
	grip.note_roots(skel)
	if grip.watch_limbs:
		grip.capture(skel)
	var out: Vector3 = grip._out()          # away from the wall, level
	var along := Vector3(0, 0, 1)           # along a rung: the ladder lies across world Z
	for limb in 4:
		var influence: float = grip._grip[limb]
		if influence <= 0.01:
			continue
		var bone := skel.find_bone(RungGrip.CHAINS[limb][2])
		if bone < 0:
			continue
		# The bone's Y runs along the hand or the foot. A foot points at the wall, level with the
		# rung; a hand points at the wall too, turned so the palm comes down over the rung.
		var forward := -out
		var y := forward if limb >= 2 else (forward - Vector3.UP * 0.35).normalized()
		var z := along if limb >= 2 else (along * float(RungGrip.SIDE[limb]) * -1.0)
		var x := y.cross(z).normalized()
		z = x.cross(y).normalized()
		var want := Basis(x, y, z).orthonormalized()
		var pose := skel.get_bone_global_pose(bone)
		var local_want: Basis = (skel.global_transform.basis.inverse() * want)
		skel.set_bone_global_pose(bone, Transform3D(
			pose.basis.slerp(local_want.orthonormalized(), influence), pose.origin))
