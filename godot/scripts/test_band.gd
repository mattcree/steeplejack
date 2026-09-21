# Banding Brigg's Dyeworks — the BAND archetype in the running game.
#
# test_band.cpp proves the star sequence beats working round the ring. This proves the job: that
# the level opens as a banding job, that which bolt you are on is where you are standing, and that
# the two orders come out differently with a man actually doing them.
#
#   make godot-script SCRIPT=res://scripts/test_band.gd

extends SceneTree

var failures := 0


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures += 1


func _init() -> void:
	root.set_meta("job_level", "03-briggs-dyeworks")
	var world: Node = load("res://scenes/steeplejack.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player: Node = world.get_node("Player")
	var chimney: Node = world.get_node("Chimney")
	var jack = player.jack

	_check(String(jack.level_name()).contains("Brigg"),
		"the level is Brigg's Dyeworks: %s" % jack.level_name())
	_check(player.band_job, "and the game knows it is a banding job")

	var list: Array = player._mission().get("bands", []) as Array
	_check(list.size() == 3, "three bands to get on her: %d" % list.size())
	var first: Dictionary = list[0]
	var n: int = int(first.get("bolts", 0))
	_check(n == 8, "the first has %d bolts" % n)

	# --- you work a band from beside it ---------------------------------------------------------
	_put_on_ladder(player, chimney, 30.0)
	_check(player._band_here() < 0, "nowhere near a band, there is nothing to pull up")
	_put_on_ladder(player, chimney, float(first.get("height", 9.0)))
	_check(player._band_here() == 0, "level with the first one, that is the one you are on")

	# --- which bolt you are on is where you are standing -----------------------------------------
	# Within what a man can actually shuffle before he steps off the ladder — which is the whole
	# point. The first version of this test swept _shuffle through a full turn, well past
	# SHUFFLE_OFF, and so proved that the bolts were reachable from a position the game does not
	# let you be in. Every bolt has to be reachable inside +-SHUFFLE_OFF or the job cannot be done.
	var seen := {}
	var steps := 40
	for k in steps + 1:
		player._shuffle = player.SHUFFLE_OFF * (2.0 * float(k) / float(steps) - 1.0)
		seen[player._band_bolt_here(0)] = true
	_check(seen.size() == n,
		"leaning as far as he can go each way reaches all %d bolts (%d)" % [n, seen.size()])

	# --- the order is the job -------------------------------------------------------------------
	# Round the ring, one bolt after its neighbour.
	for round_ in 8:
		for b in n:
			jack.band_tighten(0, b, jack.tuning_f("bandTightenPerPull", 0.22))
	var round_state: Dictionary = jack.band_state(0)

	# And the star, on the second band, which has its own count.
	var second: Dictionary = list[1]
	var n2: int = int(second.get("bolts", 12))
	var star := []
	var taken := {}
	var at := 0
	for i in n2:
		while taken.has(at % n2):
			at = (at + 1) % n2
		star.append(at % n2)
		taken[at % n2] = true
		at = (at + n2 / 2 + 1) % n2
	for round_ in 8:
		for b in star:
			jack.band_tighten(1, int(b), jack.tuning_f("bandTightenPerPull", 0.22))
	var star_state: Dictionary = jack.band_state(1)

	_check(float(star_state.get("ovality", 1.0)) < float(round_state.get("ovality", 0.0)),
		"the star comes in truer: %.2f against %.2f"
			% [star_state.get("ovality", -1.0), round_state.get("ovality", -1.0)])
	_check(bool(star_state.get("seated", false)), "and it seats")
	_check(not bool(round_state.get("seated", true)), "where working round the ring does not")
	_check(String(round_state.get("fit_name", "")) == "OVAL",
		"it has gone oval: %s" % round_state.get("fit_name", ""))

	# --- and the verb says so at the time -------------------------------------------------------
	_put_on_ladder(player, chimney, float(second.get("height", 26.0)))
	player._shuffle = 0.0
	player._band_act()
	_check(player.band_at == 1, "B pulls up the band you are level with")

	# And the whole band can be worked without ever leaving the ladder.
	var n2b: int = int(jack.band_state(1).get("bolts", 12))
	var touched := {}
	for k in 60:
		player._shuffle = player.SHUFFLE_OFF * (2.0 * float(k) / 59.0 - 1.0)
		touched[player._band_bolt_here(1)] = true
	_check(touched.size() == n2b,
		"and every one of its %d bolts is in reach from the ladder (%d)" % [n2b, touched.size()])

	# --- and the pay is the bands, not the climb ----------------------------------------------
	player.career_path = "user://test-band-tin.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(player.career_path))
	player._settle_the_job()
	_check(not player.settlement.is_empty(), "a banding job settles")
	# One of three seated: it pays, and it does not pay the lot.
	var fee: float = float(player.settlement.get("fee", 0.0))
	_check(fee > 0.0 and fee < float(player._level_fee()) * 0.95,
		"one band of three is not a whole job's money: £%.0f of £%.0f"
			% [fee, player._level_fee()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(player.career_path))

	print("BAND: %s" % ("ok" if failures == 0 else "%d failure(s)" % failures))
	quit(1 if failures > 0 else 0)


func _put_on_ladder(player: Node, chimney: Node, height: float) -> void:
	var foot: Vector3 = chimney.global_position + chimney.face_point(height)
	var out: Vector3 = foot - chimney.global_position
	out.y = 0.0
	player.global_position = foot + out.normalized() * player.BODY_OFF_LADDER
	player.set_height_m(height)
	player.on_ladder = true
