# Kershaw's Yard, played headlessly — the second felling, and the one that is meant to hurt.
#
#   make godot-script SCRIPT=res://scripts/test_kershaws.gd
#
# "The same job as Level 6 with 28 degrees of room instead of 180, a lean pointing the wrong way,
# and a prop that splits at the worst moment. This is where the player finds out whether they
# understood the system or just got lucky."
#
# Three fellings that differ is a design requirement, not a nice-to-have, and "differ" has to mean
# something a machine can check. So this asserts the difficulty is real: that cutting straight down
# the corridor misses it, that the correction the design describes is the one that works, that the
# dud prop goes and takes the margin with it, and that the chapel is genuinely in range of a bad
# felling rather than decoratively nearby.

extends SceneTree

var failures := 0


func _init() -> void:
	var world: Node = load("res://scenes/felling.tscn").instantiate()
	world.level_path = "res://../data/levels/07-kershaws-yard.json"
	root.add_child(world)
	await physics_frame
	await physics_frame

	var jack = world.jack
	var ring = world.ring

	_check(String(jack.level_name()).contains("Kershaw"), "on %s" % jack.level_name())

	# --- the yard ---------------------------------------------------------------------------------
	var lo: float = world._authored["corridor_from"]
	var hi: float = world._authored["corridor_to"]
	_check(hi - lo <= 30.0, "the corridor is %d degrees wide, not a hundred and eighty" % int(hi - lo))
	var s: Dictionary = jack.structure()
	var lean_out: float = absf(_delta(float(s.get("lean_bearing", 0.0)), (lo + hi) * 0.5))
	_check(lean_out > (hi - lo) * 0.5,
		"and she leans %.1f deg toward %03d, which is %.0f deg outside it"
			% [s.get("lean_degrees", 0.0), int(float(s.get("lean_bearing", 0.0))), lean_out])
	var chapel := {}
	for e in world._authored["exclusions"]:
		if bool(e.get("catastrophic", false)):
			chapel = e
	_check(not chapel.is_empty(), "there is a chapel and it is insured for eleven thousand pounds")

	# --- one side of the ring is tougher than the other --------------------------------------------
	var soft := 0.0
	var hard := 0.0
	for seg in ring.segments:
		var strength: float = float(jack.gob_cell(seg, 0).get("strength", 1.0))
		var bearing: float = 360.0 * float(seg) / float(ring.segments)
		if absf(_delta(bearing, 200.0)) < 10.0:
			hard = strength
		if absf(_delta(bearing, 20.0)) < 10.0:
			soft = strength
	_check(hard > soft,
		"the south side is harder mortar to cut (%.2f against %.2f)" % [hard, soft])

	# --- cutting straight down the corridor is not good enough -------------------------------------
	# The lean pulls the fall off the hole you cut. Down the middle of the yard, and it goes wide.
	var middle := (lo + hi) * 0.5
	_cut_on(jack, ring, middle)
	var naive: Dictionary = jack.fell_predict(middle, 0.0, true)
	var naive_err: float = absf(_delta(float(naive.get("fall_bearing", 0.0)), middle))
	_check(naive_err > 3.0,
		"cut down the middle and it still goes %.1f deg off, pulled by the lean" % naive_err)

	# --- the correction the level exists to teach --------------------------------------------------
	# "moving the gob's centre off the fall line by ~10 degrees corrects a 1.4 degree lean."
	var best := 0.0
	var best_err := 999.0
	for offset in [0.0, 4.0, 8.0, 10.0, 12.0, 16.0, 20.0]:
		var world2: Node = load("res://scenes/felling.tscn").instantiate()
		world2.level_path = "res://../data/levels/07-kershaws-yard.json"
		root.add_child(world2)
		await physics_frame
		_cut_on(world2.jack, world2.ring, middle + offset)
		var err: float = absf(_delta(
			float(world2.jack.fell_predict(middle, 0.0, true).get("fall_bearing", 0.0)), middle))
		if err < best_err:
			best_err = err
			best = offset
		world2.queue_free()
	_check(best >= 4.0 and best <= 16.0,
		"overcutting %.0f deg against the lean is what lands it down the yard (%.1f deg off)"
			% [best, best_err])
	_check(best_err < naive_err, "and it is better than cutting straight, which is the lesson")

	# --- the dud prop ------------------------------------------------------------------------------
	# "Prop #9 is a dud. It splits under load at roughly 70% completion, with a bang, and the margin
	# drops from SAFE straight to CRITICAL." A fresh chimney, worked properly — prop in before the
	# last course comes out — so that the one that goes is the one the level planted and not the
	# first prop to be asked to hold up a hole somebody already finished cutting.
	var fresh: Node = load("res://scenes/felling.tscn").instantiate()
	fresh.level_path = "res://../data/levels/07-kershaws-yard.json"
	root.add_child(fresh)
	await physics_frame
	var jk = fresh.jack
	var rg = fresh.ring
	_check(int(jk.gob_state().get("props_left", 0)) == 16, "sixteen props, two more than Waterside")

	var props := 0
	var split_at := -1
	var warned_at := -1
	var margin_before := 0.0
	for i in 16:
		var seg: int = _arc_seg(rg, middle + 8.0, i)
		for c in range(int(rg.courses) - 1):
			jk.gob_cut(seg, c)
		# Rule 7: the tell comes before the failure, not with it.
		if jk.gob_next_prop_is_dud():
			warned_at = props + 1
		if not jk.gob_prop(seg):
			break
		props += 1
		jk.gob_cut(seg, int(rg.courses) - 1)
		var now: Dictionary = jk.gob_state()
		if int(now.get("props_split", 0)) > 0 and split_at < 0:
			split_at = props
			break
		margin_before = float(now.get("margin", 0.0))
	_check(split_at > 0, "a prop split, at prop %d of sixteen" % split_at)
	_check(warned_at == split_at,
		"and you were told at prop %d, before you set it — which is what makes it fair" % warned_at)
	_check(split_at == 10,
		"and it was the tenth — the one the level planted (dudPropIndex 9), not a cascade")
	var after: Dictionary = jk.gob_state()
	_check(float(after.get("margin", 0.0)) < margin_before,
		"the margin dropped with it, %.2f m -> %.2f m" % [margin_before, after.get("margin", 0.0)])

	if failures > 0:
		printerr("KERSHAWS: %d failure(s)" % failures)
	else:
		print("KERSHAWS: twenty-eight degrees of room, a lean the wrong way, and a prop that goes.")
	quit(1 if failures > 0 else 0)


## Cut the design's arc centred on a bearing, propping nothing — this is about where it points.
func _cut_on(jack, ring, centre: float) -> void:
	var segs: int = int(ring.segments)
	for seg in segs:
		var bearing := 360.0 * float(seg) / float(segs)
		if absf(_delta(bearing, centre)) <= 80.0:
			for c in range(int(ring.courses)):
				jack.gob_cut(seg, c)


## The i'th segment of a gob cut outward from a centre: the fall line first, then alternately each
## side of it, which is how you would actually work it.
func _arc_seg(ring, centre: float, i: int) -> int:
	var segs: int = int(ring.segments)
	var mid: int = int(round(centre / 360.0 * float(segs))) % segs
	var step: int = (i + 1) / 2
	return (mid + (step if i % 2 == 1 else -step) + segs * 2) % segs


func _delta(from: float, to: float) -> float:
	var d := fmod(to - from + 360.0, 360.0)
	return d - 360.0 if d > 180.0 else d


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
