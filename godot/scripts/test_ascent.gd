# The whole ascent, played — the Grey Box from the field to the cap, through the real verbs.
#
# Every other test proves a part. This one proves the parts make a game: that a careful player who
# does only what the HUD tells them can get from standing in the field to standing on the top. It
# walks to the cradle, takes a ladder and dogs, climbs, picks a joint above him by looking at it,
# sounds it, drives a dog into it with real hammer blows, lashes the next section by going round,
# hauls more up on the gin wheel when he runs out, belts on when his hands need to be free, brews
# up when his nerve goes, and keeps going until he is on the cap.
#
# It plays like a careful player, not a perfect one: it skips joints that sound bad, keeps its spans
# short, and never cheats — no setting the height, no seating a dog without striking it, no filling
# the bag without hauling. If any verb in the loop breaks, this is the test that says so, because it
# is the only one that needs all of them to work at once.
#
#   make godot-script SCRIPT=res://scripts/test_ascent.gd

extends SceneTree

const MAX_SECONDS := 60.0 * 30.0     # game time; a careful climb is well under this
const SPAN_WANTED := 4.6             # metres between dogs: into Flex — twelve sections in the cradle do not reach 55 m at rigid spans

var failures := 0
var player: Node
var chimney: Node
var jack
var t := 0.0
var log_lines: Array[String] = []
var debug_looks := false


func _init() -> void:
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	player = world.get_node("Player")
	chimney = world.get_node("Chimney")
	jack = player.jack
	# Faster than real time, the same game time: the fall and the brews are timed in game seconds.
	Engine.physics_ticks_per_second = 60

	await _walk_to(chimney.global_position + chimney.FACE * (chimney.radius_at(0.0) + 4.5))
	_check(player.at_cradle(), "walked to the cradle")
	player._pick_up()
	_check(player.carrying_ladder and player.dogs_carried > 0, "took a ladder and a bag of dogs")

	await _walk_to(chimney.global_position + chimney.face_point(0.0)
		+ (chimney.face_point(0.0).normalized() * player.BODY_OFF_LADDER))
	await _wait(10)
	_check(player.on_ladder, "got on the ladder")

	var anchors_seated := 0
	var sections := 0
	var hauls := 0
	var guard := 0
	while not player.at_top and t < MAX_SECONDS and guard < 400:
		guard += 1
		if not player.on_ladder:
			_note("fell off at %.0f m: %s" % [player.fall_from_m, player.fall_reason])
			break

		# Nerve going? Belt on and brew up, as a careful player would.
		if jack.nerve() < 35.0:
			await _rig_stance(3)
			player._recover(player.REC_TEA)
			await _wait(int(13.0 * 60.0))

		# Up to the top of what is built.
		await _climb_to(player.ladder_top - 0.05)
		if player.at_top:
			break
		# The last section reaches the cap: climb off onto it.
		if player.ladder_top >= chimney.height_m - 0.1:
			player.climb_input = 1.0
			await _wait(60)
			player.climb_input = 0.0
			break

		# A dog as high as he can reach, in a joint that sounds sound or fair.
		var target_h: float = minf(_top_dog() + SPAN_WANTED, player.height_m() + 1.9)
		if guard % 5 == 1:
			_note("t=%.0fs at %.1f m, top %.1f, top dog %.1f, %d dogs, grip %.0f, nerve %.0f" % [
				t, player.height_m(), player.ladder_top, _top_dog(), player.dogs_carried,
				jack.grip(), jack.nerve()])
		if player.dogs_carried <= 0:
			if not await _haul():
				_note("could not haul at %.0f m" % player.height_m())
				break
			hauls += 1
			continue
		# Stand where the joint is at chest height, as a player would to hammer into it. If nothing
		# good is there, try shorter spans — the Grey Box's perished top is written so that "spans get
		# short exactly when the cap is in sight", and a careful player takes the short span rather
		# than the bad joint.
		var jid := -1
		var tried_h := target_h
		while tried_h >= _top_dog() + 1.6 and jid < 0:
			await _climb_to(clampf(tried_h - 0.6, 0.0, player.ladder_top - 0.05))
			jid = await _find_good_joint(tried_h)
			if jid < 0:
				tried_h -= 0.5
		if jid < 0:
			_note("no good joint anywhere from %.1f down to %.1f m" % [target_h, tried_h])
			break
		var drove := await _drive(jid)
		player.aim_override = Vector3.INF
		if not drove:
			continue
		anchors_seated += 1

		# A section to lash to it: carried, or hauled up.
		if not player.carrying_ladder:
			if not await _haul():
				_note("could not haul a section at %.0f m" % player.height_m())
				break
			hauls += 1
		if await _lash():
			sections += 1

	_note("%.0f s of game time, %d dogs, %d sections, %d hauls, top %.1f m" % [
		t, anchors_seated, sections, hauls, player.ladder_top])
	for l in log_lines:
		print("  --    %s" % l)
	_check(player.at_top, "reached the top of the %.0f m stack" % chimney.height_m)
	_check(sections >= 8, "by building it — %d sections lashed" % sections)
	print("ASCENT: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(0 if failures == 0 else 1)


# --- the verbs, played ---------------------------------------------------------------------------

func _walk_to(at: Vector3) -> void:
	for i in 60 * 40:
		var d: Vector3 = at - player.global_position
		d.y = 0.0
		if d.length() < 0.5 or player.on_ladder:
			break
		# Face where we are going and walk forward, the way W does.
		player._yaw = atan2(-d.x, -d.z)
		player.walk_input = Vector2(0.0, 1.0)
		await _step()
	player.walk_input = Vector2.ZERO


func _climb_to(h: float) -> void:
	player.climb_input = 1.0 if h > player.height_m() else -1.0
	for i in 60 * 60:
		if absf(player.height_m() - h) < 0.12 or not player.on_ladder or player.at_top:
			break
		if player.climb_input > 0.0 and player.height_m() >= player.ladder_top - 0.05:
			break
		await _step()
	player.climb_input = 0.0


## The top of the structure: the highest dog a section is lashed to. Not the highest dog in the wall
## — the old fixtures are dogs too, and 30-42 m up.
func _top_dog() -> float:
	return maxf(jack.stack_top(), 0.0)


## Sweep the eyes over the joints within reach, nearest the wanted height first, and take the first
## one that sounds good enough. That is what a player does: look at a joint, see it outlined, tap it,
## and move on if it knocks dull.
##
## The first version looked along the ladder's line at a handful of offsets and took whatever was
## outlined. Up in the perished top that found nothing, while a count showed four to twelve sound
## joints within reach at every height — they were just further round the face than it looked.
func _find_good_joint(h: float) -> int:
	var hands: Vector3 = player.global_position + Vector3.UP * 0.55
	var reach: float = jack.tuning_f("tapTestMaxRangeMetres", 2.5)
	var candidates: Array = []
	for j in player.face._joints:
		if j["occupied"] or player.face.under_ladder(j):
			continue
		if int(j.get("tapped", -1)) >= 0 and int(j["tapped"]) < _wanted(h):
			continue   # already sounded, and not good enough
		var at: Vector3 = (j["pos"] as Vector3) + chimney.global_position
		if at.distance_to(hands) > reach - 0.1:
			continue
		if float(j["height"]) < _top_dog() + 1.0:
			continue   # too low to buy any height
		candidates.append(j)
	candidates.sort_custom(func(a, b):
		return absf(float(a["height"]) - h) < absf(float(b["height"]) - h))

	for j in candidates.slice(0, 30):
		var id: int = j["id"]
		_aim_at((j["pos"] as Vector3) + chimney.global_position)
		await _wait(3)
		if player.target_id != id:
			if debug_looks:
				var got: Dictionary = player.face.joint(player.target_id) if player.target_id >= 0 else {}
				_note("  wanted %d at %s, got %d at %s, side %.2f" % [id, str(j["pos"]),
					player.target_id, str(got.get("pos", "-")), player._cam_side])
			continue
		if int(jack.joint(id).get("tapped", -1)) < 0:
			player._tap()
			await _wait(int(jack.tuning_f("tapTestSeconds", 0.8) * 60.0) + 2)
		if int(jack.joint(id).get("tapped", -1)) >= _wanted(h):
			return id
	return -1


## Fair will do low down; up in the fixtures and the perished top a careful player takes only sound,
## because a slip onto the line shock-loads the dog to 3 kN and a Fair one is rated 2.5.
func _wanted(h: float) -> int:
	return 3 if h >= 30.0 else 2


## Look at a point on the wall. Through the player's aim seam rather than by steering the camera:
## the mouse-to-ray step is test_face's to prove, and working out the camera's over-the-shoulder
## geometry by hand here cost an hour and never pointed at the joint it meant.
func _aim_at(target: Vector3) -> void:
	player.aim_override = target


## Drive a dog: into work mode on the joint, and strike until it seats or bends.
func _drive(id: int) -> bool:
	# Still looking where the tap was made, so the outline is still on it.
	if player.target_id != id:
		_note("  drive %d: outline moved to %d" % [id, player.target_id])
		return false
	var dogs_before: int = player.dogs_carried
	player._toggle_work_mode()
	if not player.work_mode:
		_note("  drive %d: no work mode — %s" % [id, player.message])
		return false
	for blow in 20:
		player.aim = Vector2.ZERO          # a steady hand: the margin is the wobble, not the aim
		player.drawing = true
		player.swing_power = 0.85
		await _wait(8)
		player._release_strike()
		if debug_looks:
			_note("    blow %d: depth %.2f grip %.0f work %s" % [blow, player.dog_depth, jack.grip(), player.work_mode])
		await _wait(int(jack.tuning_f("hammerStrikeCooldownSeconds", 0.55) * 60.0))
		if not player.work_mode:
			break
		# Grip going: back out, hold on, come back to it.
		if jack.grip() < 25.0:
			player._toggle_work_mode()
			await _wait(int(4.0 * 60.0))
			if player.target_id == id:
				player._toggle_work_mode()
			else:
				break
	if player.work_mode:
		player._toggle_work_mode()
	if not jack.joint(id).get("occupied", false):
		_note("  drive %d: 20 blows and not seated, depth %s" % [id, str(jack.joint(id).get("depth", "?"))])
	return jack.joint(id).get("occupied", false) and not player.bent_joints.has(id) \
		and player.dogs_carried < dogs_before


## Lash the carried section to the top dog: belted on, go round six times, tie off.
func _lash() -> bool:
	if not player.has_lashable_anchor():
		return false
	await _rig_stance(3)
	await _wait(int(2.0 * 60.0))   # let grip come back
	player._lash()
	if not player.lashing:
		return false
	var ideal: float = 1.0 / jack.tuning_f("lashSecondsPerWrapIdeal", 1.4)
	var a := 0.0
	for i in 60 * 14:
		a += TAU * ideal / 60.0
		player.lash_mouse(Vector2(cos(a), sin(a)) * 12.0)
		await _step()
		if int(jack.lash_state()["wraps"]) >= 6:
			break
	var top_before: float = player.ladder_top
	player._tie_off()
	await _wait(2)
	await _rig_stance(0)
	return player.ladder_top > top_before


## Rig the gin wheel on the top dog and haul a section and dogs up, steering against the swing.
func _haul() -> bool:
	await _rig_stance(3)
	if player.gin_joint < 0 or absf(player.height_m() + 0.55 - player.gin_height) >= player.GIN_REACH:
		player.gin_joint = -1
		player._gin_wheel()
	if player.gin_joint < 0:
		return false
	await _wait(int(2.0 * 60.0))
	var was_carrying: bool = player.carrying_ladder
	if was_carrying:
		return true
	for attempt in 3:
		player._gin_wheel()
		if not player.hauling:
			return false
		player.climb_input = 1.0
		for i in 60 * 120:
			var v: float = float(player.haul.get("swing_vel", 0.0))
			player._haul_dx = -signf(v) * 60.0
			await _step()
			if not player.hauling:
				break
		player.climb_input = 0.0
		if player.carrying_ladder:
			await _rig_stance(0)
			return true
	return false


func _rig_stance(stance: int) -> void:
	if jack.get_stance() == stance:
		return
	if stance < jack.get_stance():
		jack.set_stance(stance)
		return
	# Rest first. Rigging is work, and it drains at the stance you are leaving — half again as fast
	# with a section on your shoulder. The first run of this test rigged a belt on 52 grip carrying a
	# ladder, slipped halfway through, and the line shock-loaded a Fair dog into letting go at 50 m.
	# Which is the game working, and the player being careless.
	for i in 60 * 10:
		if jack.grip() >= 92.0:
			break
		await _step()
	for i in 5:
		if jack.get_stance() == stance:
			break
		player._cycle_stance()
		await _wait(int((jack.stance_setup_seconds(jack.get_stance() + 1) + 0.3) * 60.0))


func _step() -> void:
	t += 1.0 / 60.0
	await physics_frame


func _wait(frames: int) -> void:
	for i in frames:
		await _step()


func _note(s: String) -> void:
	log_lines.append(s)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    %s" % what)
	else:
		printerr("  FAIL  %s" % what)
		failures += 1
