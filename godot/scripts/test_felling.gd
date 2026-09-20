# A whole felling, played headlessly — FELL-003.
#
#   make godot-script SCRIPT=res://scripts/test_felling.gd
#
# The felling mode is the half of the game with no climbing in it, and a bot that can work a gob
# from the first brick to the verdict is the only thing that says the mode is a mode and not a pile
# of scripts. It cuts on the corridor, props behind itself, watches the margin fall through the
# design's bands, pegs the line and lights it.
#
# It also holds the line the mode is built on: everything it asserts is read back from `Jack`, so
# if a rule ever migrates out of the sim and into a .gd file, this test goes on passing while
# `make check` stops being able to see the rule at all. That is the failure to watch for.

extends SceneTree

var failures := 0


func _init() -> void:
	var world: Node = load("res://scenes/felling.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame

	var jack = world.jack
	var ring = world.ring
	var hud = world.hud

	# --- it starts as a chimney, standing ---------------------------------------------------------
	var st: Dictionary = jack.gob_state()
	_check(int(st.get("segments", 0)) == 32 and int(st.get("courses", 0)) == 4,
		"the level's gob: %d segments x %d courses" % [st.get("segments", 0), st.get("courses", 0)])
	_check(int(st.get("props_left", 0)) == 14, "and its 14 props")
	_check(String(st.get("status_name", "")) == "SAFE", "an uncut chimney is SAFE")
	_check(float(st.get("cut_arc", 1.0)) == 0.0, "with no gob in it yet")

	# --- the corridor is where it has to go -------------------------------------------------------
	var peg: float = world._peg
	_check(peg >= 250.0 and peg <= 320.0, "pegs start in the level's corridor, at %03d deg" % peg)

	# --- you can walk the site, not just circle it ------------------------------------------------
	var keep_out: float = float(jack.structure().get("base_radius", 3.2))
	_check(world._range() > keep_out, "you are standing off the chimney, not inside it")
	var was: Vector3 = world._at
	world._at = world._on_bearing(92.0, 30.0)   # over at the pump house
	_check(world._range() > 25.0, "and you can walk right out to the pump house, 30 m away")
	_check(world._aimed_cell().is_empty(), "from where you cannot reach the brickwork")
	world._at = was

	# --- a prop will not go in in front of the cut ------------------------------------------------
	var seg := _seg_at(ring, peg)
	_check(not jack.gob_prop(seg), "a prop will not stand where nothing has been cut")

	# --- cut the gob, propping behind ------------------------------------------------------------
	# "Props go in behind you as you cut: the loop is cut two cells -> set a prop -> cut two cells."
	# The order matters and the sim will punish getting it wrong: take all four courses out of a
	# segment before the prop is in and the segment is carrying nothing for a moment, so its 28 kN
	# sheds onto the neighbours - and the prop next door is already at 70% of what a prop can take,
	# so it splits, and its load goes the same way, and the front of the gob unzips. The prop goes
	# in before the last course comes out. That is why it is the loop.
	var order := _arc_segments(ring, peg, 14)
	var margins := []
	for s in order:
		for c in range(ring.courses - 1):
			_check_quiet(jack.gob_cut(s, c), "cut %d/%d" % [s, c])
		_check_quiet(jack.gob_prop(s), "propped %d" % s)
		_check_quiet(jack.gob_cut(s, ring.courses - 1), "last course out of %d" % s)
		margins.append(float(jack.gob_state().get("margin", 0.0)))
	st = jack.gob_state()
	_check(int(st.get("props_left", 99)) == 0, "fourteen segments took exactly fourteen props")
	_check(int(st.get("props_split", 1)) == 0, "and none of them split, because each went in before the last course came out")
	_check(float(st.get("cut_arc", 0.0)) >= 150.0, "the gob is %.0f deg of arc" % st.get("cut_arc", 0.0))

	var fell_all_the_way := true
	for i in range(1, margins.size()):
		if margins[i] > margins[i - 1] + 0.001:
			fell_all_the_way = false
	_check(fell_all_the_way, "the margin never improved while brick came out")
	_check(String(st.get("status_name", "")) == "UNEASY",
		"a finished gob sits UNEASY at %.2f m — where the design says a felling should finish"
			% st.get("margin", 0.0))

	# --- the HUD is drawing the sim's polygon, not one of its own ---------------------------------
	var hull = st.get("support_hull", PackedVector2Array())
	_check(hull.size() >= 3, "the support polygon has %d corners for the HUD to draw" % hull.size())

	# --- the telegraphs, which rule 7 says ship with the failure -----------------------------------
	# A gob whose only warning is a word on a panel fails the fairness contract. Every band has to
	# be louder, dustier and shakier than the one before it, and every cue has to exist to be played.
	var foley: Node = world.get_node("Foley")
	for name in ["mortarTick", "groan", "propCreak", "propSplit", "crack", "roar", "crash", "cheer"]:
		_check(foley.cue_stream(name) != null, "there is a sound for %s" % name)
	var worse := ["SAFE", "UNEASY", "CRITICAL", "COLLAPSE"]
	var rising := true
	for i in range(1, worse.size()):
		if float(world.TICKS_PER_SECOND[worse[i]]) <= float(world.TICKS_PER_SECOND[worse[i - 1]]):
			rising = false
		if float(world.SHAKE_M[worse[i]]) <= float(world.SHAKE_M[worse[i - 1]]):
			rising = false
		if i > 1 and float(world.GROAN_EVERY[worse[i]]) >= float(world.GROAN_EVERY[worse[i - 1]]):
			rising = false
	_check(rising, "each band ticks faster, groans oftener and shakes harder than the one before")
	_check(float(world.SHAKE_HZ) <= 3.0, "and nothing on screen moves faster than 3 Hz (rule 20)")
	world._telegraph(0.02)
	_check(world._dust != null and world._dust.emitting,
		"the gob is shedding dust, which is what the ticking looks like (rule 8)")

	# --- Act 1, the survey, which costs five minutes and buys nine degrees ------------------------
	_check(not world.surveyed(), "you start not knowing the lean — it is not written on the chimney")
	var blind: float = float(jack.fell_predict(peg, 0.0, false).get("accuracy", 0.0))
	world._at = world._on_bearing(20.0, 18.0)
	world._plumb()
	_check(not world.surveyed(), "one plumb reading is not a survey")
	world._at = world._on_bearing(35.0, 18.0)
	world._plumb()
	_check(not world.surveyed(), "and neither are two from nearly the same place")
	world._at = world._on_bearing(140.0, 18.0)
	world._plumb()
	_check(world.surveyed(), "two readings well apart, and you have her lean")
	var known: float = float(jack.fell_predict(peg, 0.0, true).get("accuracy", 0.0))
	_check(absf(blind - known - jack.tuning_f("fallAccuracyUnsurveyedDegrees", 0.0)) < 0.01,
		"which is worth %.0f degrees of cone" % (blind - known))

	# --- Act 2's trade: metres off the top, paid for in daylight -----------------------------------
	var shift: Dictionary = jack.fell_shift(0.0)
	_check(float(shift.get("shift", 0.0)) > 0.0,
		"the level gives you %d minutes of daylight" % int(float(shift.get("shift", 0.0)) / 60.0))
	_check(float(shift.get("spent", 0.0)) > 0.0,
		"and the gob has already cost %d of them" % int(float(shift.get("spent", 0.0)) / 60.0))
	_check(float(shift.get("left", 0.0)) > 0.0, "with some left to argue over")
	var cap: float = float(shift.get("max_reduction", 0.0))
	_check(cap > 0.0 and cap < float(jack.structure().get("height", 70.0)) * 0.5,
		"you may take %.0f m off by hand — the perished top, not the whole chimney" % cap)
	var tight: float = float(jack.fell_predict(peg, cap, true).get("accuracy", 0.0))
	var loose: float = float(jack.fell_predict(peg, 0.0, true).get("accuracy", 0.0))
	_check(tight < loose, "taking it tightens the cone, %.1f deg -> %.1f deg" % [loose, tight])
	_check(float(jack.fell_shift(cap).get("left", 0.0)) < float(shift.get("left", 0.0)),
		"and costs you the daylight to do it")
	world._height_removed = 0.0
	world._take_off(2.0)
	_check(world._height_removed == 2.0, "two metres off, through the real action")
	world._take_off(1000.0)
	_check(world._height_removed <= cap, "and it will not let you take more than she has")
	world._height_removed = 0.0

	# --- the pegs are the commitment ---------------------------------------------------------------
	world._pegs.clear()
	world._at = world._on_bearing(peg, 20.0)
	world._drive_peg()
	_check(world._pegs.size() == 1, "one peg in")
	world._at = world._on_bearing(peg, 22.0)
	world._drive_peg()
	_check(world._pegs.size() == 1, "a second peg two metres from the first is not a line")
	world._at = world._on_bearing(peg, 46.0)
	world._drive_peg()
	_check(world._pegs.size() == 2, "two pegs, well apart, and the line is in")
	_check(abs(_delta(world._peg, peg)) < 1.0,
		"and it runs out from the chimney at %03d deg" % world._peg)

	# --- what it will do, before you light it ------------------------------------------------------
	var pred: Dictionary = jack.fell_predict(peg, 0.0, world.surveyed())
	_check(abs(_delta(float(pred.get("fall_bearing", 0.0)), peg)) < 20.0,
		"it is predicted to land %03d deg, %.1f off the pegs"
			% [pred.get("fall_bearing", 0.0), pred.get("error", 0.0)])
	_check(float(pred.get("accuracy", 0.0)) > 0.0, "with a cone of +-%.1f deg" % pred.get("accuracy", 0.0))
	_check(float(pred.get("debris_length", 0.0)) > float(jack.structure().get("height", 70.0)),
		"and a fan that throws further than the chimney is tall (%.0f m)" % pred.get("debris_length", 0.0))

	# --- light it ---------------------------------------------------------------------------------
	world._fire()
	await physics_frame
	var out: Dictionary = world._outcome
	_check(not out.is_empty(), "it went")
	_check(hud.outcome.is_empty(),
		"and the verdict is not up yet — it is for after it lands, not for the moment you light it")
	_check(String(out.get("grade_name", "")) != "WILD",
		"graded %s, %.1f deg off the pegs" % [out.get("grade_name", ""), out.get("error", 0.0)])
	var fractures: Array = out.get("fractures", [])
	_check(fractures.size() >= 2 and fractures.size() <= 4,
		"it broke in %d places, at %s" % [fractures.size(), fractures])
	_check(bool(out.get("clean_break", false)), "she broke up nicely: %d chunks" % out.get("chunks", 0))
	_check(out.get("struck", []).is_empty(), "and hit nothing on the way down")

	# --- and the fall is a fall, not a teleport ----------------------------------------------------
	_check(world._fall != null and world._fall.running(), "the chimney is on its way over")
	var before: float = world._fall.angle()
	await _wait(30)
	_check(world._fall.angle() > before,
		"turning: %.1f deg -> %.1f deg" % [rad_to_deg(before), rad_to_deg(world._fall.angle())])

	# --- and when it is down, the verdict ---------------------------------------------------------
	var seconds: float = float(jack.tuning_f("fellHingeSecondsToGround", 7.5))
	await _wait(int(seconds * 65.0))
	_check(not world._fall.running(), "it is down")
	_check(hud.outcome.is_empty(),
		"and still no scorecard over it — you are meant to be watching the dust")
	await _wait(int((float(world.CHEER_AFTER) + 0.5) * 65.0))
	_check(not hud.outcome.is_empty(), "and when the cheer comes, the verdict with it")

	# --- and the loop closes -----------------------------------------------------------------------
	# A mode you can only leave by killing the process is a scene, not a job.
	world._back_to_the_board()
	await physics_frame
	await physics_frame
	var now: Node = root.get_child(root.get_child_count() - 1)
	_check(now.has_method("scene_for"), "enter takes you back to the board")

	if failures > 0:
		printerr("FELLING: %d failure(s)" % failures)
	else:
		print("FELLING: a chimney surveyed, cut, propped, pegged and dropped.")
	quit(1 if failures > 0 else 0)


## The segment nearest a bearing.
func _seg_at(ring, bearing: float) -> int:
	return int(round(bearing / 360.0 * float(ring.segments))) % ring.segments


## `count` segments centred on a bearing, worked outwards from the middle the way you would cut
## them: the fall line first, then alternately each side of it.
func _arc_segments(ring, bearing: float, count: int) -> Array:
	var mid := _seg_at(ring, bearing)
	var out := [mid]
	var step := 1
	while out.size() < count:
		out.append((mid + step + ring.segments) % ring.segments)
		if out.size() < count:
			out.append((mid - step + ring.segments) % ring.segments)
		step += 1
	return out


func _delta(from: float, to: float) -> float:
	var d := fmod(to - from + 360.0, 360.0)
	return d - 360.0 if d > 180.0 else d


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1


func _check_quiet(ok: bool, what: String) -> void:
	if not ok:
		printerr("  FAIL  %s" % what)
		failures += 1
