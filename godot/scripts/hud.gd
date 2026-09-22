# The HUD, to docs/01-gdd/03-meters-grip-nerve.md#hud.
#
#   "Minimal and diegetic-ish. Bottom-left, two thin arcs around the hand icon. Grip: a fast,
#    responsive arc. Flashes at 20. Nerve: a slow arc that visibly breathes. [...] No minimap.
#    No objective marker. The objective is at the top; you can see it."
#
# Two departures from that, both deliberate and both learned the hard way. The arcs fade to a ghost
# rather than to nothing: a meter faded to zero is a meter the player never learns they have. And
# the verbs are listed with the *reason* each one is unavailable, because every action in this game
# is gated on state you cannot see — is a dog seated, have I read this joint — and a greyed-out row
# with no reason teaches nothing.

extends Control

# ---------------------------------------------------------------- the palette
#
# There was not one. Every colour in this file was written where it was used, so the red that means
# "this is about to kill you" and the red that means "you have no dogs left" were different reds,
# and nothing was reliably louder than anything else. Colour, weight and size are the only three
# things a HUD has to say "look here first", and a HUD that spends them at random has none of them.
#
# Four levels of voice, and three meanings. Nothing outside this block should name a colour.
const INK := Color(0.96, 0.94, 0.90)          ## the thing you are meant to read
const DIM := Color(0.82, 0.80, 0.77)          ## context for it
const FAINT := Color(0.70, 0.68, 0.66)        ## there if you look, quiet if you do not
const GHOST := Color(0.62, 0.60, 0.58)        ## present but unavailable

const GOOD := Color(0.56, 0.80, 0.50)         ## it is right
const WATCH := Color(0.95, 0.76, 0.33)        ## it is working, and you should know
const DANGER := Color(0.95, 0.33, 0.25)       ## it is wrong, now

const GRIP_COL := Color(0.88, 0.76, 0.44)
const NERVE_COL := Color(0.44, 0.60, 0.80)
const CHALK := Color(0.92, 0.88, 0.80)

## A type scale, so size means importance instead of meaning whatever was typed.
const H1 := 30      ## the one thing on the screen
const H2 := 19      ## a heading, or a verdict
const BODY := 15
const SMALL := 13
const TINY := 11

const HAND := Vector2(96, -104)
const GRIP_R := 44.0
const NERVE_R := 56.0
const FADE_ABOVE := 85.0
const REST_ALPHA := 0.22
const Q_KEY := "Q"
## VERB-002: the pip is visible for 0.6 s after a tap, then gone.
const PIP_SECONDS := 0.6

@onready var player: Node = get_node("../Player")

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_process(true)


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or player.jack == null:
		return
	var jack: Jack = player.jack
	var hand := Vector2(HAND.x, size.y + HAND.y)
	var now := float(Time.get_ticks_msec()) / 1000.0

	_draw_scrim()
	_draw_vignette(jack)

	var grip: float = jack.grip()
	var nerve: float = jack.nerve()
	var nerve_max: float = maxf(jack.nerve_max(), 1.0)
	var busy: bool = player.work_mode

	var grip_a := maxf(REST_ALPHA, _ease((FADE_ABOVE - grip) / 25.0))
	var nerve_a := maxf(REST_ALPHA, _ease((FADE_ABOVE - (nerve / nerve_max) * 100.0) / 25.0))
	if busy:
		grip_a = 1.0
		nerve_a = 0.85

	# Grip is the fast one. Below the tremor threshold it flashes — the telegraph, on screen.
	var grip_col := Color(0.86, 0.74, 0.42, grip_a)
	if jack.tremoring():
		var pulse := 0.55 + 0.45 * sin(now * 9.0)
		grip_col = Color(0.92, 0.28, 0.20, grip_a * pulse)

	# Nerve is the slow one, and it breathes: the character's chest, not a progress bar.
	var breath := 1.0 + 0.035 * sin(now * (0.55 + 0.30 * jack.nerve_band()) * PI)

	# --- the body, bottom left ------------------------------------------------------------------
	#
	# Bars, not arcs. Two arcs at different radii cannot be compared at a glance and two bars on a
	# shared scale can, and the pair costs about seventy pixels of height where the arcs cost a
	# hundred and twenty. That mattered: everything in this HUD used to hang off HAND and the whole
	# bottom-left corner was six things stacked twenty pixels apart.
	var bar := Vector2(HAND.x + 34.0, size.y - 118.0)
	_draw_meter(bar, "GRIP", grip / 100.0, grip_col, grip_a, jack.tremoring())
	_draw_meter(bar + Vector2(0.0, 40.0), "NERVE", nerve / nerve_max,
		Color(0.42, 0.58, 0.78, nerve_a), nerve_a, false)
	# The nerve bar breathes, which is the visual half of rule 8 for the breathing audio and was
	# the one thing the arcs did better than a bar would.
	_draw_kit(bar + Vector2(0.0, 74.0), breath)

	_draw_stack_gauge(jack)
	_draw_wind(jack, Vector2(size.x - 108.0, 86.0))
	_draw_hold_line()
	_draw_conductor(jack)
	_draw_band(jack)
	_draw_survey(jack)
	_draw_plumb(jack)
	# The way out, on the jobs that do not end on the cap. Without it a player who has just
	# finished a conductor run at the foot of the chimney has no idea the job is over.
	if not player.settlement.is_empty() and not player.at_top:
		_centre("the job is done  ·  [enter] to go home", size.y - 96.0, Color(INK, 0.92), H2)

	# Only once there is something to span *from*. With no dogs driven, the span is measured from
	# the ground and reads "62.0 m span — about to buckle" at the top of a ladder that is lashed all
	# the way down. True, useless, and permanently on screen in alarm red.
	if player.span_warning != "" and jack.anchor_count() > 0 and not player.at_top and player.on_ladder:
		var buckle: bool = player.span_warning.contains("buckle")
		var col := Color(0.95, 0.30, 0.22, 0.6 + 0.4 * sin(now * 7.0)) if buckle else Color(0.92, 0.70, 0.35, 0.9)
		_label(player.span_warning, Vector2(GAUGE_X + 20.0, size.y - 150.0), col, 13)

	# --- what you can do, and what is stopping you ----------------------------------------------
	_draw_steps()
	_draw_markers()

	var rows := _affordances()
	var row_y := size.y - 44 - 17 * (rows.size() - 1)
	for row in rows:
		var text: String = "[%s]  %s" % [row[0], row[1]]
		if not row[2] and row[3] != "":
			text += " — " + row[3]
		var col := Color(0.93, 0.90, 0.84, 0.88) if row[2] else Color(0.72, 0.70, 0.68, 0.66)
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		_label(text, Vector2(size.x - w - 28, row_y), col, 13)
		row_y += 17

	# The transient line fades out rather than sitting there for ever. Two permanent instructions
	# saying different things — one at the top, one in the middle — is how the player learns to stop
	# reading either.
	var ttl: float = player.message_ttl()
	if ttl > 0.0:
		# At the top edge, clear of him and of the warnings. At two-thirds down it landed on his back in every
		# ladder frame, and in work mode on the joint he was hammering.
		_centre(player.message, size.y * 0.075, Color(0.94, 0.91, 0.86, 0.92 * _ease(ttl * 3.0)), 16)

	if player.work_mode:
		_draw_work(jack)
	elif not player.lashing:
		# Not while lashing. The caption and its bracket sit on the joint, the lashing panel sits
		# in the middle of the screen, and on any frame where the joint is roughly ahead of you
		# those are the same pixels — a frame taken mid-lash has "weathered mortar — looks fair"
		# printed through the middle of the turn counter. Two true things in one place read as
		# neither, and while the rope is going round the joint's verdict is not the question.
		_draw_target_caption()

	_draw_pip(jack)

	if player.rigging_to >= 0:
		_draw_rig(jack)

	if player.lashing:
		_draw_lash(jack)

	if player.options_open:
		_draw_options()
	elif not player.mouse_captured() and DisplayServer.get_name() != "headless" \
			and not player.falling and player.fade_in <= 0.0:
		# Never silently dead: with the mouse out of the window the view does not move, so say why.
		_centre("click to look around", size.y * 0.5 + 60.0, Color(0.95, 0.93, 0.88, 0.85), 16)

	if player.hauling:
		_draw_haul()

	_draw_stack_warnings()
	_draw_fuse()
	_draw_recovery(jack, hand)
	if player.at_top:
		_draw_top()

	# Rule 8: every audio cue has a visual fallback. This one is not optional in a second way too —
	# the fairness table makes the gust's 1.2 s warning the thing that separates a fair failure from
	# a bug, and a warning only some players receive is not a warning.
	if jack.gust_tell():
		_draw_gust_tell(jack)

	# Over everything, because for 900 ms nothing else on this screen matters.
	if player.jack.slip_in_progress():
		_draw_slip(jack)

	_draw_fall_cut()

	# There is no objective marker because the objective is the top and you can see it. But you
	# cannot see the *rule*, so it is said once and then never again.
	# It yields to the transient line. Two centred instructions 60 px apart, both in white, both
	# reading like they matter, is how a player learns to read neither — and it is exactly what a
	# frame taken mid-lash showed: "lashing — hold the left button" stacked over "Climb the stack".
	if player._now < 14.0 and not player.at_top and player.message_ttl() <= 0.0 and not player.lashing:
		var fade := Color(0.92, 0.90, 0.86, 0.85 * _ease((14.0 - player._now) / 3.0))
		_centre("Climb the stack. You can only go as high as you have built.", size.y * 0.14, fade)
		# On a felling, this climb is Act 2 and not the job. A player who took the letter off the
		# board arrives here without being told why, and the top of a chimney they are about to
		# demolish is a strange place to be for no stated reason.
		if String(player.jack.level_archetype()) == "FELL":
			_centre("She is to come down. Strip her out first — bands off, conductor down — "
				+ "and then you can cut her.", size.y * 0.14 + 30.0, fade)


func _next_step() -> String:
	if player.at_top or player.recovering != player.REC_NONE or player.falling or player.fade_in > 0.3:
		return ""
	if player.jack.slip_in_progress():
		return ""
	if player.rigging_to >= 0 or player.lashing or player.hauling:
		return ""
	# A section failing under him owns the screen. Advice about lashing is noise while it goes.
	if player.stack_info.get("buckling", false):
		return ""
	if player.work_mode:
		return "Line the dog up, then hold the left button to draw — release to strike."

	# --- on the ground: the order of things ---------------------------------------------------------
	# Walking to the stack with nothing in your hands is walking there to come back, so the first
	# line sends him to the cradle, and only then to the ladder.
	if not player.on_ladder:
		if player.at_cradle() and (not player.carrying_ladder or player.dogs_carried == 0):
			return "Take a ladder and fill the dog bag.  [F]"
		if not player.carrying_ladder and player.dogs_carried == 0 and player.ladders_at_base > 0:
			return ("Your stack is still up. Take a ladder from the cradle and climb it again."
				if player.fall_reason != "" else
				"Walk to the cradle at the foot of the stack — the timber by the fire.")
		return "Climb on — the standing ladder at the foot of the stack."

	# --- on the ladder --------------------------------------------------------------------------------
	if player.has_lashable_anchor() and player.carrying_ladder:
		return "Lash the ladder to your top dog [R] — then hold the left button and go round."
	if player.has_lashable_anchor() and not player.carrying_ladder:
		return ("Haul a section up to it [G]." if player.gin_joint >= 0
			else "A dog to lash to, and no ladder: rig a gin wheel on it [G], or fetch one from the cradle.")
	if player.dogs_carried == 0:
		return "Bag is empty. Haul some up [G], or climb down to the cradle."
	# Where the next dog goes is the thing a new player gets wrong: near the top of what is built,
	# as high as he can reach, so the next section goes as high as it can. A dog at his feet on the
	# first rung is a dog that buys nothing.
	if player.height_m() < player.ladder_top - 1.2 and player.target_span() < 3.0:
		return "Climb up what you've built — the next dog wants to be about 4 m above your last one."
	if player.target_id < 0:
		return "Look up at the brickwork above you to pick a joint."
	var span: float = player.target_span()
	if span > 0.0 and span < 1.5:
		return "Too close to your last dog to buy much height — look higher."
	if not player.target_tapped():
		return "Tap it to hear what it is worth [E] — or trust your eye and drive a dog [right mouse]."
	return "Drive a dog into that joint, or look for a better one.  [right mouse]"


## The loop, as a list: what gets the next section up, what is done, and what is next.
##
## The first person to play it could not see the order of things — "how do I get the next ladder
## up?" — because the only guidance was one line of advice at a time. The list is the same state
## that line reads, laid out whole: every section goes up the same four steps, and the one to do
## now is the bright one, with the advice for it underneath.
const STEPS := [
	"Get a ladder section",
	"Climb to the top of the ladder",
	"Drive a dog into the marked band above the top",
	"Lash the section to that dog",
]

## A conductor job is a different list of four, because it is a different job — and the laddering
## one was still on screen the whole way down a run, telling a man with a reel of copper on his
## belt to go and fetch a ladder section.
const RUN_STEPS := [
	"Ladder her to the top",
	"Fix the terminal at the apex  [F]",
	"Run the tape down, a clip about every metre  [F]",
	"Dig the earth pit at the foot of her  [F]",
]


## A banding job, and a straightening. Same fault as the conductor one had before it was fixed:
## an archetype without its own list gets the laddering list, which tells a man with a spanner to
## go and fetch a ladder section.
const BAND_STEPS := [
	"Ladder her past the top band",
	"Stand level with a band",
	"Go round her and pull the bolts up  [B]",
	"Opposite pairs — work round and she goes oval",
]

const PLUMB_STEPS := [
	"Ladder her to where you want the hinge",
	"Dial the cut  [X] — read what it will do",
	"Aim SHORT of plumb; she keeps going for weeks",
	"Cut her  [F], then she comes back in her own time",
]


## And a survey, which is the first job anybody plays. It was left on the laddering list — the one
## archetype I did not give its own — so the tutorial told a new player to fetch ladder sections
## and said nothing whatever about the four things wrong with the chimney it had just asked them
## to go and find.
const LOOK_STEPS := [
	"Ladder her — you cannot read what you cannot reach",
	"Look about as you climb. Some of it is just there to see",
	"Sound the joints  [E] — some of it can only be heard",
	"Get on the cap. The last of it is only visible from up there",
]


func _look_state_steps() -> Array:
	var r: Dictionary = player.jack.survey_report()
	var found: int = int(r.get("found", 0))
	var total: int = maxi(int(r.get("total", 1)), 1)
	var laddered: bool = player.ladder_top > 5.0
	var looked: bool = found > 0
	var sounded: bool = player.taps_made > 0
	var topped: bool = player.top_reached or bool(r.get("complete", false))
	var done := [laddered, looked, sounded, topped]
	var current := 0
	for i in 4:
		current = i
		if not done[i]:
			break
	return [done, current]


func _band_state_steps() -> Array:
	var index: int = player._band_here()
	var laddered: bool = player.ladder_top > 8.0
	var here: bool = index >= 0
	var pulling := false
	var seated := false
	if here:
		var st: Dictionary = player.jack.band_state(index)
		pulling = int(st.get("tightened", 0)) > 0 or float(st.get("tightest", 0.0)) > 0.0
		seated = bool(st.get("seated", false))
	var done := [laddered, here, pulling, seated]
	var current := 0
	for i in 4:
		current = i
		if not done[i]:
			break
	return [done, current]


func _plumb_state_steps() -> Array:
	var st: Dictionary = player.jack.plumb_state()
	var laddered: bool = player.ladder_top > 6.0
	var dialled: bool = player.plumb_take_out > 2.0
	var cut: bool = player.plumb_cut_done
	var rested: bool = cut and not bool(st.get("settling", false))
	var done := [laddered, dialled, cut, rested]
	var current := 0
	for i in 4:
		current = i
		if not done[i]:
			break
	return [done, current]


## Which four steps are on screen, and how far through them he is. Returns [steps, done, current].
func _run_state() -> Array:
	var st: Dictionary = player.jack.conductor_state(maxf(player.height_m(), 0.0))
	var laddered: bool = player.ladder_top >= float(player.jack.total_height()) - 1.5
	var terminal: bool = bool(st.get("terminal", false))
	var down: bool = terminal and player.height_m() < 2.0
	var earthed: bool = float(st.get("earth_ohms", -1.0)) >= 0.0
	var done := [laddered, terminal, down, earthed]
	var current := 0
	for i in 4:
		if not done[i]:
			current = i
			break
		current = 3
	return [done, current]


func _step_state() -> Array:
	var has_section: bool = player.carrying_ladder or player.lashing
	var dog_in: bool = player.has_lashable_anchor()
	var at_top_of_ladder: bool = player.on_ladder and player.height_m() >= player.ladder_top - 1.3
	var done := [has_section, at_top_of_ladder or dog_in, dog_in, false]
	# The dog can come before the section: drive it, then haul the section up to it. So a missing
	# section is the step to do whenever it is missing and the dog is in.
	var current := 3
	if not has_section and (dog_in or not player.on_ladder or player.dogs_carried == 0):
		current = 0
	elif not done[1] and not dog_in:
		current = 1
	elif not dog_in:
		current = 2
	return [done, current]


func _draw_steps() -> void:
	if player.at_top or player.falling or player.fade_in > 0.3 or player.options_open:
		return
	# Not while the rope is going round. Both of these are "what to do next", the lashing panel is
	# the more specific of the two, and a frame taken mid-lash has one plate laid over the other
	# with the darkening doubled where they cross.
	if player.lashing:
		return
	if player.jack.slip_in_progress() or player.stack_info.get("buckling", false):
		return
	var steps: Array = STEPS
	var state := _step_state()
	if player.conductor_job:
		steps = RUN_STEPS
		state = _run_state()
	elif player.band_job:
		steps = BAND_STEPS
		state = _band_state_steps()
	elif player.plumb_job:
		steps = PLUMB_STEPS
		state = _plumb_state_steps()
	elif player.survey_job:
		steps = LOOK_STEPS
		state = _look_state_steps()
	var done: Array = state[0]
	var current: int = state[1]
	var built: int = player.jack.stack_sections().size()
	var total: int = built + int(player.ladders_at_base) + (1 if player.carrying_ladder else 0)
	# Clear of the stack gauge, which now owns the left edge. At 28 the checklist sat straight on
	# top of the dogs it is telling you to drive.
	var x := GAUGE_X + 108.0
	var y := size.y * 0.26
	var header := "NEXT SECTION   %d of %d up" % [built, total]
	if player.conductor_job:
		header = "THE RUN"
	elif player.band_job:
		header = "THE BANDS"
	elif player.plumb_job:
		header = "BRINGING HER BACK"
	elif player.survey_job:
		var rep: Dictionary = player.jack.survey_report()
		header = "THE REPORT   %d of %d" % [int(rep.get("found", 0)), int(rep.get("total", 0))]
	# Laid out first, drawn second, so the plate underneath can be the size of what is on it.
	#
	# It used to draw straight onto the world, and the world it draws onto is a brick chimney in
	# sunlight: a frame taken mid-climb has "2. Look about as you climb" in pale grey running over
	# three courses of red brick and a shadow, and the outline on each glyph is not enough — an
	# outline saves a letter, it cannot save a paragraph. The plate can, and it costs one rect.
	var rows: Array = [[header, Color(0.95, 0.93, 0.88, 0.85), 13, 0.0, 22.0]]
	for i in steps.size():
		var now: bool = i == current
		var mark := "✓" if done[i] and not now else ("▶" if now else "·")
		var col := Color(0.98, 0.96, 0.90, 0.98) if now else (
			Color(0.74, 0.84, 0.70, 0.88) if done[i] else Color(0.78, 0.76, 0.72, 0.70))
		rows.append(["%s  %d. %s" % [mark, i + 1, steps[i]], col, 15 if now else 13, 0.0,
			22.0 if now else 19.0])
		if not now:
			continue
		# The advice line, but only where it is about this step: the old single-line guidance
		# runs a step ahead in places, and advice about tapping under "climb to the top" was
		# exactly the confusion this list is here to end.
		var special: bool = player.conductor_job or player.band_job or player.plumb_job \
			or player.survey_job
		var detail := "" if special else _next_step()
		if player.conductor_job and i == 0:
			detail = "She has to be laddered before any of it goes on"
		if i == 1 and not special:
			detail = "Climb up what you've built  [W]" if player.on_ladder else detail
		if detail != "":
			rows.append([detail, Color(0.94, 0.86, 0.64, 0.95), 13, 24.0, 20.0])
		# Only on the stack-building checklist. It is keyed on the step *index*, and every
		# archetype has a step 4 — so on a banding job "opposite pairs, work round and she goes
		# oval" was being explained with a sentence about lashing a ladder to a dog.
		if i == 3 and not special and not player.lashing:
			rows.append(["the new section stands on your ladder; the rope ties it to the dog",
				Color(0.84, 0.82, 0.78, 0.80), 12, 24.0, 18.0])

	var w := 0.0
	var h := 10.0
	for row in rows:
		w = maxf(w, float(row[3]) + _font.get_string_size(String(row[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(row[2])).x)
		h += float(row[4])
	draw_rect(Rect2(Vector2(x - 14.0, y - 20.0), Vector2(w + 28.0, h + 14.0)),
		Color(0.05, 0.05, 0.06, 0.42))
	# A rule down the left edge rather than a border all the way round. It gives the block an
	# origin without drawing a box in the middle of a view somebody climbed to look at.
	draw_rect(Rect2(Vector2(x - 14.0, y - 20.0), Vector2(2.0, h + 14.0)),
		Color(0.86, 0.84, 0.78, 0.30))
	for row in rows:
		_label(String(row[0]), Vector2(x + float(row[3]), y), row[1], int(row[2]))
		y += float(row[4])


## Pointers in the world for the step in hand: the cradle when the job is on the ground, the dog to
## lash to, the dog to hang the gin wheel on, and a label on the band where the next dog goes.
func _draw_markers() -> void:
	if player.at_top or player.falling or player.fade_in > 0.3 or player.options_open:
		return
	if player.jack.slip_in_progress() or player.lashing or player.hauling or player.work_mode:
		return
	var state := _step_state()
	var current: int = state[1]
	var t: float = player._now
	var pulse := 0.6 + 0.4 * sin(t * 4.0)
	var chalk := Color(0.863, 0.910, 0.941, 0.95 * pulse)

	if not player.on_ladder and current == 0 and not player.at_cradle():
		_pointer(player.chimney.cradle_point() + Vector3.UP * 1.4, "the cradle — ladders and dogs  [F]", chalk)
	elif not player.on_ladder and player.carrying_ladder and player.dogs_carried > 0:
		var foot: Vector3 = player.chimney.global_position + player.chimney.face_point(1.2)
		_pointer(foot, "the ladder — climb  [W]", chalk)

	if player.on_ladder:
		var jid: int = player.lash_dog_joint()
		if jid >= 0 and player.carrying_ladder:
			_ring_at_joint(jid, "lash here  [R]", chalk)
		elif jid >= 0 and not player.carrying_ladder:
			_ring_at_joint(jid, "rig the gin wheel here  [G], then haul a section up", chalk)
		elif current == 2:
			var band: Vector2 = player.next_dog_band()
			if band.y > band.x:
				var mid: Vector3 = player.chimney.global_position + player.chimney.face_point((band.x + band.y) * 0.5)
				_pointer(mid + (player.chimney.global_position - mid).normalized() * 0.2,
					"next dog goes in this band", chalk, false)


func _pointer(world: Vector3, text: String, col: Color, arrow := true) -> void:
	if player.camera.is_position_behind(world):
		return
	var at: Vector2 = player.camera.unproject_position(world)
	at.x = clampf(at.x, 80.0, size.x - 80.0)
	at.y = clampf(at.y, 60.0, size.y - 140.0)
	if arrow:
		var tip := at
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-10, -16), tip + Vector2(10, -16)]), col)
		at.y -= 22.0
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_label(text, Vector2(at.x - w * 0.5, at.y - 4.0), col, 14)


func _ring_at_joint(jid: int, text: String, col: Color) -> void:
	var on = _on_screen(jid)
	if on == null:
		return
	var at: Vector2 = on
	var r: float = 16.0 + 3.0 * sin(float(player._now) * 4.0)
	draw_arc(at, r, 0, TAU, 32, col, 2.5)
	draw_arc(at, r + 7.0, 0, TAU, 32, Color(col.r, col.g, col.b, col.a * 0.4), 1.5)
	_label(text, at + Vector2(r + 12.0, 5.0), col, 14)


## [key, verb, available, why-not]
func _affordances() -> Array:
	if player.at_top or player.falling or player.fade_in > 0.3:
		return []
	if player.jack.slip_in_progress():
		return [["SPACE", "grab", true, ""]]
	if player.rigging_to >= 0:
		return [[Q_KEY, "stop rigging", true, ""]]
	if player.lashing or player.hauling:
		return []
	if player.work_mode:
		return [
			["mouse", "place the dog", true, ""],
			["hold LMB", "draw, release to strike", true, ""],
			["RMB", "back out", true, ""],
		]
	if not player.on_ladder:
		return [
			["WASD", "walk", true, ""],
			["mouse", "look", true, ""],
			["F", "take a ladder and dogs", player.at_cradle(), "only at the cradle, at the foot of the stack"],
			[Q_KEY, "stance — rig it on the stack", false, "you rig a stance up there, not down here"],
			["F1", "motion and vertigo options", true, ""],
		]
	var has_target: bool = player.target_id >= 0
	var sounded: bool = player.target_tapped()
	var rows := [
		["W/S", "climb", true, ""],
		["E", "sound this joint" if not sounded else "sound it again", has_target,
			"no joint in reach — look at the brickwork"],
		["RMB", _drive_label(), has_target and player.dogs_carried > 0,
			"no joint in reach" if not has_target else "no dogs in the bag"],
		["R", _r_label(), _r_live(), _r_why()],
		["F", _f_label(), _f_live(), _f_why()],
		[Q_KEY, _next_stance_label(), true, ""],
		["B", _b_label(), player.band_job and player._band_here() >= 0,
			"stand level with a band to work on it"],
		["X", "dial the cut — %.0f mm, brings her back %.2f m" % [player.plumb_take_out,
			float(player.plumb_here().get("brings_back", 0.0))] if player.plumb_job else "",
			player.plumb_job and not player.plumb_cut_done, "she is cut"],
		["T", "brew up", jack_free_hands(),
			"you need both hands — belt on first"],
		["G", _gin_label(), true, ""],
		["C / V", "a cigarette  ·  look at the view (hold)", true, ""],
	]
	# A key with nothing to say on this job is not dimmed, it is absent. The list is what THIS job
	# wants, not an index of everything the game can do.
	var out := []
	for r in rows:
		if String(r[1]) != "":
			out.append(r)
	return out


## R is lash-the-next-one with a ladder on your shoulder and take-this-one-off without. The same
## key doing the job and its reverse, and the list has to say which it is doing or the whole
## striking stage is invisible — the verb shipped before this did and there was nothing on screen
## that mentioned it existed.
func _r_label() -> String:
	if player.conductor_job:
		return "lash the next ladder"
	# Empty-handed on a ladder, R is ALWAYS the striking verb — including when it is refused, or
	# the label says one thing and the reason beside it explains the other.
	if not player.carrying_ladder and player.on_ladder:
		return "take this ladder off and lower it"
	return "lash the next ladder"


func _r_live() -> bool:
	if not player.carrying_ladder and player.on_ladder \
			and int(player.jack.section_to_strike(player.height_m())) >= 0:
		return true
	return player.has_lashable_anchor() and player.carrying_ladder


func _r_why() -> String:
	if not player.carrying_ladder and player.on_ladder:
		var why := String(player.jack.why_not_strike(player.height_m()))
		if why != "" and why != "nothing left to take down":
			return why
	return "you are not carrying one" if not player.carrying_ladder \
		else "needs a dog seated above you"


## And F is the gear: draw the dog in reach, or fill the bag at the cradle — or, on a conductor
## job, the run itself.
func _f_label() -> String:
	if player.plumb_job:
		return "she is cut — now she comes back" if player.plumb_cut_done \
			else "cut her here, %.0f mm out" % player.plumb_take_out
	if player.conductor_job:
		var st: Dictionary = player.jack.conductor_state(maxf(player.height_m(), 0.0))
		if player.at_cradle():
			return "dig the earth pit and test her"
		if not bool(st.get("terminal", false)):
			return "fix the terminal"
		return "clip the tape here"
	if player.at_cradle():
		return "fill the bag from the cradle"
	return "draw the dog in reach"


func _f_live() -> bool:
	if player.plumb_job:
		return player.on_ladder and not player.plumb_cut_done
	if player.conductor_job:
		return true
	if player.at_cradle():
		return player.dogs_at_base > 0 or player.ladders_at_base > 0
	return player.on_ladder and int(player.jack.dog_to_draw(player.height_m())) >= 0


func _f_why() -> String:
	if player.plumb_job:
		return "she is cut — you only get one" if player.plumb_cut_done \
			else "you cut her from the ladder"
	if player.at_cradle():
		return "nothing left to take"
	if not player.on_ladder:
		return "the materials are in the cradle"
	for i in range(int(player.jack.anchor_count()), 0, -1):
		var w := String(player.jack.why_not_draw(i, player.height_m()))
		if w != "" and w != "you have had that one out":
			return w
	return "no dog in reach"


## The two archetype keys. They only appear on the jobs that use them — a list of everything the
## game can do would be a manual, and what this list is for is what THIS job wants next.
func _b_label() -> String:
	if not player.band_job:
		return ""
	var index: int = player._band_here()
	if index < 0:
		return "pull a bolt up"
	var st: Dictionary = player.jack.band_state(index)
	return "pull this bolt up — %d of %d, %s" % [int(st.get("tightened", 0)),
		int(st.get("bolts", 0)), String(st.get("fit_name", "")).to_lower()]


func _gin_label() -> String:
	if player.gin_joint < 0:
		return "rig the gin wheel on a dog in reach"
	if absf(player.shoulders().y - player.gin_height) < player.GIN_REACH:
		return "haul a section up" if not player.carrying_ladder else "haul (lash the one you have first)"
	return "move the gin wheel up to a dog in reach"


## "drive a dog into it — a 4.3 m span, flexing". The span a dog there would make, and what the
## table makes of it, before the dog goes in. MVP criterion 4 asks whether players *voluntarily*
## take the risky span, and nobody can volunteer for a risk they cannot see.
func _drive_label() -> String:
	var span: float = player.target_span()
	if span <= 0.0:
		return "drive a dog into it"
	var band: int = player.jack.classify_span(span)
	var what: String = ["rigid", "flexing", "swaying", "it will buckle"][clampi(band, 0, 3)]
	return "drive a dog into it — a %.1f m span, %s" % [span, what]


func jack_free_hands() -> bool:
	return player.jack.get_stance() >= 3


## What Q costs and what it buys, spelled out before it is pressed rather than after.
##
## This is the one decision the climbing system is built on — rush it one-handed or spend the time —
## and the player cannot make it at all if the price is invisible.
func _next_stance_label() -> String:
	var jack: Jack = player.jack
	var here: int = jack.get_stance()
	var want: int = (here + 1) % 5
	# The same skip the verb makes. A key hint that names a stance Q will not go to is worse than
	# no hint: it is the game telling you about equipment you have not got.
	if want == player.STANCE_CHAIR and not player.has_chair:
		want = 0
	var name: String = jack.stance_name_of(want)
	if not jack.stance_needs_rigging(here, want):
		return "back to %s — instant" % name
	# One decimal under ten seconds. A hooked leg takes 1.5 s and "2 s to rig" is a different
	# number from the one the game charges.
	var secs: float = jack.stance_setup_seconds(want)
	var shown: String = ("%.1f" % secs) if secs < 10.0 else ("%.0f" % secs)
	return "%s — %s s to rig, %.0f grip a second" % [name, shown, jack.stance_drain_rate(want)]


func _draw_work(jack: Jack) -> void:
	# Centred on the joint the dog is going into, not the middle of the screen. The reticle was
	# attached to nothing, so the player aimed at a circle and the dog went wherever he happened to
	# be standing.
	var on = _on_screen(player.work_joint)
	var eye: Vector2 = on if on != null else Vector2(size.x * 0.5, size.y * 0.44)
	var px_per_deg := 10.0
	var tolerance: float = jack.tuning_f("hammerMaxAngleErrorDegrees", 12.0) * px_per_deg

	# The tolerance ring: inside it a strike is clean, outside it bends dogs. A ring rather than a
	# number, so the player watches the wobble eat their margin instead of reading it.
	draw_arc(eye, tolerance, 0, TAU, 64, Color(0.85, 0.85, 0.90, 0.30), 1.5)

	var err: float = player.aim.length()
	var q := clampf(1.0 - err / 12.0, 0.0, 1.0)
	var tip: Vector2 = eye + player.aim * px_per_deg
	var mark := Color(0.95, 0.35, 0.25).lerp(Color(0.55, 0.85, 0.45), q)
	draw_line(tip + Vector2(-9, 0), tip + Vector2(9, 0), mark, 2.0)
	draw_line(tip + Vector2(0, -9), tip + Vector2(0, 9), mark, 2.0)

	if player.swing_power > 0.0:
		draw_arc(eye, tolerance + 22.0, PI * 0.75, PI * 0.75 + TAU * 0.5 * player.swing_power,
			32, Color(0.90, 0.72, 0.30, 0.95), 5.0)

	var bar_w := 180.0
	var bar := Vector2(eye.x - bar_w * 0.5, eye.y + tolerance + 54.0)
	draw_rect(Rect2(bar - Vector2(1, 1), Vector2(bar_w + 2, 8)), Color(0, 0, 0, 0.47))
	draw_rect(Rect2(bar, Vector2(bar_w * player.dog_depth, 6)), Color(0.80, 0.71, 0.47, 0.94))
	_centre("dog %.0f%%   %.1f° off" % [player.dog_depth * 100.0, err], bar.y + 20,
		Color(0.85, 0.83, 0.80, 0.85), 13)

	# How long this stance buys you, counted down in seconds. The flashing arc says "soon" and this
	# says "four" — and the fairness contract is that the player can explain the fall afterwards,
	# which means knowing before it that they were spending something and how much was left.
	var left: float = jack.seconds_of_work_left()
	if left >= 0.0 and left < 12.0:
		var urgency := clampf(1.0 - left / 12.0, 0.0, 1.0)
		_centre("%.0f s of grip left in this stance" % ceilf(left), bar.y + 40,
			Color(0.92, 0.72 - 0.4 * urgency, 0.35 - 0.2 * urgency, 0.75 + 0.25 * urgency), 13)


## Where a joint is on screen, or null if it is behind the camera.
func _on_screen(id: int):
	if id < 0 or player.face == null:
		return null
	var j: Dictionary = player.face.joint(id)
	if j.is_empty():
		return null
	var world: Vector3 = (j["pos"] as Vector3) + player.chimney.global_position
	if player.camera.is_position_behind(world):
		return null
	return player.camera.unproject_position(world)


## What the joint he is pointing at looks like, and what his chalk says about it, beside the joint.
##
## The wall's tells are drawn on the brick — salt bloom, cracks, a clean line — but a new player
## has no way to know that the white crust *means* anything. So the caption names what the eye is
## seeing, in the words a jack would use, and says "looks": the tell is only as reliable as the
## band's visualReadReliability, and the caption must not promise more than the brick does. The
## second line is the chalk, which is the player's own knowledge, bought with a tap.
##
## Words, not colours, for the same reason the pip is shapes: the tier cannot live in a hue.
const LOOKS := ["cracked across — looks unsafe",
	"salt bloom — the mortar looks perished",
	"weathered mortar — looks fair",
	"clean, hard mortar — looks sound"]
const HEARD := ["chalked: it rattled — cracked", "chalked: a dead thud — perished",
	"chalked: a knock — fair", "chalked: it rang — sound"]


func _draw_target_caption() -> void:
	# Not while a panel of its own is up: rigging, lashing and hauling each draw one, and the caption
	# landed on top of the rigging ring.
	if not player.on_ladder or player.target_id < 0 or player.lashing or player.hauling \
			or player.rigging_to >= 0:
		return
	var on = _on_screen(player.target_id)
	if on == null:
		return
	var j: Dictionary = player.face.joint(player.target_id)
	if j.is_empty():
		return
	var at: Vector2 = on
	# Corners round the joint, big enough to find at a glance: the 3D bracket on the brick is the
	# precise one, this is the one that says "here" from across the screen.
	var half := Vector2(30, 13)
	var pulse := 0.75 + 0.25 * sin(player._now * 5.0)
	var col := Color(0.863, 0.910, 0.941, 0.95 * pulse)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var c := at + Vector2(half.x * sx, half.y * sy)
			draw_line(c, c - Vector2(9.0 * sx, 0), col, 2.0)
			draw_line(c, c - Vector2(0, 7.0 * sy), col, 2.0)

	var lines: Array = []
	var seen: int = int(j.get("look", -1))
	if seen >= 0 and seen < LOOKS.size():
		lines.append(LOOKS[seen])
	var heard: int = int(j.get("tapped", -1))
	lines.append(HEARD[heard] if heard >= 0 and heard < HEARD.size() else "not sounded yet — [E] to tap it")
	var span: float = player.target_span()
	if span > 0.0:
		lines.append("a dog here: %.1f m above your last" % span)

	# On the side of the joint away from him, so it never sits on his head — and off the screen
	# edge, back the other way.
	var widest := 0.0
	for l in lines:
		widest = maxf(widest, _font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
	var him: Vector2 = player.camera.unproject_position(player.global_position + Vector3.UP * 1.0)
	var right := at.x >= him.x
	var x := at.x + half.x + 12.0 if right else at.x - half.x - 12.0 - widest
	if x + widest > size.x - 12.0:
		x = at.x - half.x - 12.0 - widest
	elif x < 12.0:
		x = at.x + half.x + 12.0
	var y := at.y - 4.0
	for i in lines.size():
		var c2 := Color(0.95, 0.93, 0.88, 0.92) if i != 1 or heard >= 0 else Color(0.80, 0.78, 0.74, 0.8)
		_label(lines[i], Vector2(x, y + 16.0 * i), c2, 13)


## The tap pip — VERB-002. Drawn **at the joint that was tapped**, not in a panel, for 0.6 s.
##
## Four shapes, from the sim, never colours: a ring for sound, a square for fair, a triangle for
## perished, a broken cross for cracked. Under it, the envelope of the sound that just played —
## a short spike for a ring, a long low hump for a thud, a spike and a second burst for a rattle —
## so a player who can hear learns to connect the shape to the sound, and one who cannot gets the
## same information the sound carried. The rattle's second event is drawn as a second event.
func _draw_pip(jack: Jack) -> void:
	var t: Dictionary = player.last_tap
	if t.is_empty():
		return
	var age: float = player._now - float(t["at"])
	if age > PIP_SECONDS:
		return
	var at = _on_screen(int(t["id"]))
	if at == null:
		return
	var a := 1.0 - _ease(age / PIP_SECONDS) * 0.9
	var c := Color(0.96, 0.97, 0.99, a)
	var shadow := Color(0, 0, 0, a * 0.55)
	var centre: Vector2 = (at as Vector2) + Vector2(0, -64)
	var r := 11.0

	for pass_col in [shadow, c]:
		var o := Vector2(1.5, 1.5) if pass_col == shadow else Vector2.ZERO
		match int(t["pip"]):
			0:   # sound: a ring
				draw_arc(centre + o, r, 0, TAU, 28, pass_col, 3.0)
			1:   # fair: a square
				draw_rect(Rect2(centre + o - Vector2(r, r), Vector2(r, r) * 2.0), pass_col, false, 3.0)
			2:   # perished: a triangle
				var tri := PackedVector2Array([centre + o + Vector2(0, -r * 1.1),
					centre + o + Vector2(r * 1.05, r * 0.8), centre + o + Vector2(-r * 1.05, r * 0.8),
					centre + o + Vector2(0, -r * 1.1)])
				draw_polyline(tri, pass_col, 3.0)
			_:   # cracked: a broken cross
				draw_line(centre + o + Vector2(-r, -r), centre + o + Vector2(-2, -2), pass_col, 3.0)
				draw_line(centre + o + Vector2(3, 3), centre + o + Vector2(r, r), pass_col, 3.0)
				draw_line(centre + o + Vector2(r, -r), centre + o + Vector2(-r, r), pass_col, 3.0)

	# The envelope, underneath.
	var env := PackedVector2Array()
	var w := 46.0
	var base := centre + Vector2(-w * 0.5, 30)
	for i in 24:
		var u := float(i) / 23.0
		var v := 0.0
		match int(t["pip"]):
			0: v = exp(-u * 9.0)                       # ring: sharp, short
			1: v = 0.75 * exp(-u * 5.0)                # knock: softer, longer
			2: v = 0.45 * exp(-u * 2.2) * minf(u * 8.0, 1.0)   # thud: no transient, long
			_: v = exp(-u * 11.0) + (0.55 * exp(-(u - 0.3) * 7.0) if u > 0.3 else 0.0)   # rattle
		env.append(base + Vector2(u * w, -v * 14.0))
	draw_polyline(env, Color(c.r, c.g, c.b, a * 0.8), 2.0)


## The cut to black, and the one sentence. The fairness contract: "the player must always be able
## to say, in one sentence, why that went wrong." So the sentence is on the black, in the sim's own
## words, before anything else happens — and then the next morning, and the stack still standing.
func _draw_fall_cut() -> void:
	var black: float = player.fall_black
	var back: float = player.fade_in
	if black > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, black))
		if black >= 1.0:
			var y := size.y * 0.42
			_centre("You fell %.0f m." % player.fall_from_m, y, Color(0.95, 0.93, 0.90, 0.95), 28)
			_centre(player.fall_reason, y + 38.0, Color(0.86, 0.84, 0.80, 0.9), 16)
	elif back > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, clampf(back, 0.0, 1.0)))
		_centre("The next morning. Your stack is still up there.", size.y * 0.42,
			Color(0.95, 0.93, 0.90, clampf(back * 1.4, 0.0, 0.95)), 18)


## Getting nerve back: a ring round the nerve arc filling as it comes, with what it is.
func _draw_recovery(jack: Jack, hand: Vector2) -> void:
	if player.recovering == player.REC_NONE:
		return
	var p: float = jack.recover_progress()
	var names := {1: "brewing up", 2: "a cigarette", 3: "looking at the view"}
	draw_arc(hand, NERVE_R + 10.0, -PI * 0.5, -PI * 0.5 + TAU * p, 48,
		Color(0.72, 0.84, 0.95, 0.9), 3.0)
	_label(names.get(player.recovering, ""), Vector2(HAND.x - 30, hand.y - NERVE_R - 22),
		Color(0.80, 0.88, 0.96, 0.9), 13)
	# The brew's line, as a subtitle. Said once, at the start, and left up while the tea lasts.
	if player.recovering == player.REC_TEA and player.tea_line != "":
		_centre("\u201c%s\u201d" % player.tea_line, size.y * 0.78, Color(0.95, 0.93, 0.88, 0.9), 17)


## The top. The HUD steps back and the climb is summed up, once.
##
## This is the player's own answer to what the MVP playtest is asking: did they still tap at the
## tenth dog (the taps), did they take the risky span (the long spans), did the verbs have a curve
## (the ratings). Shown plainly, as facts about their climb, with no score attached — a score would
## turn a climb into a grade.
func _draw_top() -> void:
	var s: Dictionary = player.top_summary
	var age: float = player._now - player.top_since
	var a := clampf((age - 1.5) / 1.5, 0.0, 1.0)   # after the camera has had its moment
	if a <= 0.0 or s.is_empty():
		return
	var y := size.y * 0.16
	_centre("The top.", y, Color(0.97, 0.95, 0.90, 0.95 * a), 34)
	var mins := int(float(s["seconds"])) / 60
	var secs := int(float(s["seconds"])) % 60
	_centre("%.0f m   ·   %d:%02d" % [float(s["height"]), mins, secs], y + 36.0,
		Color(0.90, 0.88, 0.84, 0.85 * a), 16)
	var b := clampf((age - 3.0) / 1.5, 0.0, 1.0)
	var lines := [
		"%d dogs — %d sound, %d fair, %d poor%s" % [s["dogs"], s["sound"], s["fair"], s["poor"],
			(", %d bent" % s["bent"]) if int(s["bent"]) > 0 else ""],
		"%d joints sounded   ·   %d long span%s taken" % [s["taps"], s["long_spans"],
			"" if int(s["long_spans"]) == 1 else "s"],
		"%d sections   ·   %d quick hitch%s" % [s["sections"], s["hitches"],
			"" if int(s["hitches"]) == 1 else "es"],
	]
	for i in lines.size():
		_centre(lines[i], y + 76.0 + 22.0 * i, Color(0.86, 0.84, 0.80, 0.8 * b), 14)

	# What the job paid, and the way out. A climb that ends with no way back to the board is a
	# scene you can reach, not a job you can finish.
	var c := clampf((age - 4.5) / 1.5, 0.0, 1.0)
	if c <= 0.0:
		return
	var paid: Dictionary = player.settlement
	var money := y + 76.0 + 22.0 * float(lines.size()) + 18.0
	if player.stripped_out:
		_centre("bands off, conductor down. She is ready to come down.", money,
			Color(0.95, 0.93, 0.88, 0.9 * c), 16)
		_centre("enter — back to the board, and then back here with a bar and a match",
			money + 30.0, Color(0.86, 0.84, 0.80, 0.6 * c), 13)
		return
	if not paid.is_empty():
		var fee := float(paid.get("fee", 0.0))
		var rep := int(paid.get("reputation_delta", 0))
		var said := "a favour, and he will remember it" if fee <= 0.0 else "£%d" % int(fee)
		if rep > 0:
			said += "   ·   +%d to your name" % rep
		if not bool(paid.get("first_time", true)):
			said += "   (you have done this one before)"
		_centre(said, money, Color(0.95, 0.93, 0.88, 0.9 * c), 16)
	_centre("enter — back to the board", money + 30.0,
		Color(0.86, 0.84, 0.80, 0.6 * c), 13)
	_centre("[S] back over the edge   ·   [V] look at the view", y + 160.0,
		Color(0.78, 0.76, 0.72, 0.6 * b), 13)


## The stack's warnings. The fairness table: "Ladder buckled — fair, because the span was over 8 m
## and the HUD said so." So the HUD says so, loudly, for the whole of the 8 seconds, with the time
## left as a bar that empties — and says the one thing to do about it.
# ---------------------------------------------------------------- the wind
#
# The wind had no direction. It was a number of metres per second, so the game could tell you a
# gust was coming and never which way it would push you — and which quarter the weather is in is
# the first thing a jack knows about a day, before its speed and long before any gust.
#
# What this has to replace is a whole sense. On a ladder you feel the push on one cheek, hear it
# in the rope, and watch it move the ladder before it moves you. None of that reaches a player
# through a screen, so it becomes an instrument: a rose that says where it is coming from relative
# to the way you are facing, how hard, and whether it is getting up or dying away.

const ROSE_R := 26.0
const WIND_CALM := 3.0        ## m/s below which it is just weather, not a force
const WIND_STIFF := 12.0      ## and above which it is the thing you are fighting


func _draw_wind(jack: Jack, at: Vector2) -> void:
	var w: Dictionary = jack.wind_state(maxf(player.height_m(), 0.0))
	if w.is_empty():
		return
	var speed := float(w.get("speed", 0.0))
	var hard: float = clampf((speed - WIND_CALM) / (WIND_STIFF - WIND_CALM), 0.0, 1.0)
	var tell := bool(w.get("tell", false))
	var gust := float(w.get("gust", 0.0))

	# Loud only when it deserves to be. A dial that is bright in a flat calm has spent the one
	# thing it had to say about a gale.
	var live: float = maxf(hard, maxf(gust, 1.0 if tell else 0.0))
	var colour := FAINT.lerp(WATCH, hard)
	if tell or gust > 0.0:
		colour = DANGER
	var a: float = 0.62 + 0.38 * live

	# A disc of shade under it, because this dial spends its life against a bright sky and a pale
	# roofscape. Quiet is a thing the dial says; invisible is a thing the sky does to it.
	draw_circle(at, ROSE_R + 3.0, Color(0.04, 0.04, 0.05, 0.34 + 0.16 * live))

	# The rose, and north on it, so the bearing is readable as a bearing and not only as a push.
	draw_arc(at, ROSE_R, 0.0, TAU, 40, Color(GHOST, 0.5 + 0.3 * live), 1.0)
	var yaw: float = player._yaw if "_yaw" in player else 0.0
	for q in range(4):
		var u := Vector2(sin(deg_to_rad(90.0 * q) - yaw), -cos(deg_to_rad(90.0 * q) - yaw))
		# North gets the long tick, so the rose still has an orientation in the frames where the
		# arrow is lying across the letter.
		var inner := ROSE_R - (8.0 if q == 0 else 4.0)
		draw_line(at + u * inner, at + u * ROSE_R, Color(GHOST, 0.7 if q == 0 else 0.45), 1.0)
	_label("N", _north_label_at(at), Color(GHOST, 0.62), TINY)

	# Which way it is pushing HIM, not which way it is pushing north: the rose is turned by the way
	# he is facing, because that is the only frame in which "it is on your left" means anything.
	var from_deg := float(w.get("bearing", 0.0))
	var facing := rad_to_deg(player._yaw if "_yaw" in player else 0.0)
	var rel := deg_to_rad(from_deg - facing + 180.0)   # +180: the arrow flies the way it blows
	var dir := Vector2(sin(rel), -cos(rel))
	var tail := at - dir * (ROSE_R - 4.0)
	var tip := at + dir * (ROSE_R - 4.0) * (0.45 + 0.55 * live)
	draw_line(tail, tip, Color(colour, a), 2.0 + 2.5 * live)
	var wing := dir.rotated(PI * 0.82) * 8.0
	draw_line(tip, tip + wing, Color(colour, a), 2.0)
	draw_line(tip, tip + dir.rotated(-PI * 0.82) * 8.0, Color(colour, a), 2.0)

	# The number, and whether it is getting up or dying away. The arrow says where; a climber still
	# wants to know how much, and a rising wind is a different decision from a falling one.
	var trend := float(w.get("trend", 0.0))
	var arrow := "" if is_zero_approx(trend) else ("  rising" if trend > 0.0 else "  easing")
	_label("%.0f m/s%s" % [speed, arrow], at + Vector2(ROSE_R + 12.0, 5.0), Color(colour, a), SMALL)

	# The gust's 1.2 seconds, as a ring closing round the rose. Rule 8's visual half of the audio
	# tell, in the one place the player is already looking to read the weather.
	if tell:
		var p: float = clampf(float(w.get("tell_progress", 0.0)), 0.0, 1.0)
		draw_arc(at, ROSE_R + 5.0, -PI * 0.5, -PI * 0.5 + TAU * p, 36, DANGER, 3.0)


## Where "N" sits on an egocentric rose: opposite the way he is facing, turning as he turns. Inside
## the rim, not outside it — outside, the letter swings round into whatever the dial is sitting
## next to, and "N" plus "4 m/s" reads as one word.
func _north_label_at(at: Vector2) -> Vector2:
	var t: float = -(player._yaw if "_yaw" in player else 0.0)
	var u := Vector2(sin(t), -cos(t))
	return at + u * (ROSE_R - 15.0) - Vector2(3.5, -4.0)


## Which way the wind has him, and which way to pull. Rule 7: the drift costs grip past halfway, so
## it has to be readable before halfway — and it has to say what to DO about it, because the first
## playtest of the sideways shift asked, fairly, why he was moving at all.
##
## Drawn under the crosshair rather than in a corner, because it is something you correct while
## looking at the wall, not a stat you consult.
const LINE_W := 92.0
const LINE_FREE := 0.5      ## the share of the drift that costs nothing (MetersGrip.cpp agrees)


func _draw_hold_line() -> void:
	if player.jack == null or not player.on_ladder or player.falling or player.at_top:
		return
	var limit: float = player.jack.tuning_f("windPushMaxLeanMetres", 0.30)
	var off: float = clampf(player.wind_lean / maxf(limit, 0.01), -1.0, 1.0)
	if absf(off) < 0.04:
		return
	var mid := Vector2(size.x * 0.5, size.y * 0.5 + 84.0)

	# The track, and the two points on it where holding stops being free.
	draw_line(mid - Vector2(LINE_W, 0.0), mid + Vector2(LINE_W, 0.0), Color(GHOST, 0.3), 2.0)
	for sgn in [-1.0, 1.0]:
		var x: float = mid.x + sgn * LINE_W * LINE_FREE
		draw_line(Vector2(x, mid.y - 4.0), Vector2(x, mid.y + 4.0), Color(WATCH, 0.4), 1.0)

	var past: float = maxf(absf(off) - LINE_FREE, 0.0) / (1.0 - LINE_FREE)
	var col := FAINT.lerp(DANGER, past)
	var at := Vector2(mid.x + off * LINE_W, mid.y)
	draw_line(mid, at, Color(col, 0.5 + 0.5 * past), 3.0)
	draw_circle(at, 5.0, Color(col, 0.7 + 0.3 * past))

	# The instruction, and only once it is worth acting on. A prompt that is always there is
	# wallpaper by the second chimney.
	if past > 0.0:
		var key := "A" if off > 0.0 else "D"
		_centre("[%s]  hold your line" % key, mid.y + 26.0, Color(col, 0.55 + 0.45 * past), SMALL)

## "Am I happy on this ladder?" — CLIMB-007, on screen.
##
## Every other warning in this HUD is about the section under his feet this second. This is the
## whole structure, judged the way a jack judges it: by looking down it and asking what would
## happen if he came off the top. It is always there, it is one line, and it is the only place in
## the game that has ever said a stack is wrong before it proves it.
func _draw_ladder_verdict(jack: Jack, at: Vector2) -> void:
	if jack.anchor_count() <= 0:
		return
	var v: Dictionary = jack.stack_survey()
	if v.is_empty():
		return
	var name_ := String(v.get("verdict_name", "SOUND"))
	var colour := GOOD
	if name_ == "NOT RIGHT":
		colour = DANGER
	elif name_ == "WORKING":
		colour = WATCH

	# A bar of the colour, then the word, then why. The bar is there because a word in a colour is
	# a word you have to read; a bar is a thing you see.
	draw_rect(Rect2(at.x, at.y - 11.0, 3.0, 14.0), colour)
	_label("the ladder: %s" % name_, Vector2(at.x + 10.0, at.y), colour, BODY)
	var why := String(v.get("reason", ""))
	if why != "":
		_label(why, Vector2(at.x + 10.0, at.y + 18.0), Color(colour, 0.72), SMALL)

	# The number that decides every fall in this game, which used to appear nowhere until after it
	# had already decided one.
	if not bool(v.get("holds_a_fall", true)):
		_label("a fall puts %.1f kN on a dog rated %.1f" % [
			float(v.get("shock_kn", 0.0)), float(v.get("first_to_go_capacity", 0.0))],
			Vector2(at.x + 10.0, at.y + 36.0), Color(DANGER, 0.85), SMALL)


func _draw_stack_warnings() -> void:
	var st: Dictionary = player.stack_info
	if st.is_empty():
		return
	if st.get("buckling", false):
		var left: float = st.get("buckle_left", 0.0)
		var limit: float = player.jack.tuning_f("buckleSecondsUnderLoad", 8.0)
		var t := float(Time.get_ticks_msec()) / 1000.0
		var pulse := 0.65 + 0.35 * sin(t * (8.0 + 10.0 * (1.0 - left / limit)))
		var y := size.y * 0.22
		_centre("THIS SECTION IS BOWING", y, Color(0.98, 0.42, 0.30, pulse), 26)
		_centre("%.1f s — get off it, up or down" % left, y + 28.0, Color(0.96, 0.90, 0.84, 0.92), 16)
		var w := 320.0
		var at := Vector2((size.x - w) * 0.5, y + 44.0)
		draw_rect(Rect2(at, Vector2(w, 6)), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(at, Vector2(w * clampf(left / limit, 0.0, 1.0), 6)), Color(0.98, 0.42, 0.30, 0.9))

	# A quick hitch walking off its dog. Slow, and shown as distance so it reads as a fact about the
	# rope rather than as a timer.
	if int(st.get("lashing", 0)) == 1 and float(st.get("drift_cm", 0.0)) > 0.2:
		var drift: float = st["drift_cm"]
		var off: float = st.get("walk_off_cm", 15.0)
		var col := Color(0.92, 0.70, 0.35, 0.9) if drift < off * 0.7 else Color(0.98, 0.42, 0.30, 0.95)
		var hand := Vector2(HAND.x, size.y + HAND.y)
		_label("hitch walking — %.1f of %.0f cm" % [drift, off],
			Vector2(HAND.x + NERVE_R + 26, hand.y + 62), col, 13)


## The fuse. 02-climbing-system.md: "On a cascade, the HUD flashes each anchor as it goes, bottom of
## screen, like a fuse burning." One mark per dog that pulled, lit in the order they went, so a
## cascade is something the player watches happen and can read back afterwards — which is the
## only way it can be fair.
func _draw_fuse() -> void:
	var fuse: Array = player.fuse
	if fuse.is_empty():
		return
	var now: float = player._now
	var last: float = float(fuse[fuse.size() - 1]["at"])
	if now - last > 6.0:
		return
	var n := fuse.size()
	var step := 34.0
	var y := size.y - 150.0
	var x0 := size.x * 0.5 - step * float(n - 1) * 0.5
	for i in n:
		var f: Dictionary = fuse[i]
		var lit: bool = now >= float(f["at"])
		var age: float = now - float(f["at"])
		var p := Vector2(x0 + step * i, y)
		if lit:
			var flare := clampf(1.0 - age / 0.5, 0.0, 1.0)
			draw_circle(p, 9.0 + 8.0 * flare, Color(0.98, 0.52, 0.22, 0.35 * flare))
			draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), Color(0.98, 0.42, 0.30, 0.95), 3.0)
			draw_line(p + Vector2(7, -7), p + Vector2(-7, 7), Color(0.98, 0.42, 0.30, 0.95), 3.0)
			_label("%.0f m" % float(f["height"]), p + Vector2(-14, 26), Color(0.92, 0.88, 0.84, 0.85), 12)
		else:
			draw_arc(p, 7.0, 0, TAU, 16, Color(0.9, 0.88, 0.84, 0.35), 1.5)
		if i < n - 1:
			draw_line(p + Vector2(10, 0), p + Vector2(step - 10, 0), Color(0.9, 0.88, 0.84, 0.25), 1.0)


## The swing meter — VERB-007. A pendulum the player can read at a glance: the rope hanging from
## a pivot at the current swing angle, the arc it is sweeping, and the foul marks either side. The
## amplitude arc is what matters — it shows how big the swing *is*, where the rope alone would read
## upright at the bottom of every swing, which is exactly when the player needs to know.
func _draw_haul() -> void:
	var h: Dictionary = player.haul
	if h.is_empty():
		return
	var foul: float = h.get("foul_at", 22.0)
	var amp: float = h.get("amplitude", 0.0)
	var ang: float = h.get("swing_deg", 0.0)
	var pivot := Vector2(size.x * 0.5, size.y * 0.16)
	var r := 110.0

	# Scale so the foul marks sit well out, not at the edge of a quarter circle.
	var k := 2.0
	var danger := clampf(amp / foul, 0.0, 1.0)
	var col := Color(0.86, 0.80, 0.62).lerp(Color(0.98, 0.42, 0.30), danger * danger)

	draw_arc(pivot, r, PI * 0.5 - deg_to_rad(foul * k), PI * 0.5 + deg_to_rad(foul * k), 32,
		Color(0.9, 0.88, 0.84, 0.18), 5.0)
	draw_arc(pivot, r, PI * 0.5 - deg_to_rad(amp * k), PI * 0.5 + deg_to_rad(amp * k), 32,
		Color(col.r, col.g, col.b, 0.7), 5.0)
	for sgn in [-1.0, 1.0]:
		var at: float = PI * 0.5 + sgn * deg_to_rad(foul * k)
		draw_line(pivot + Vector2(cos(at), sin(at)) * (r - 10), pivot + Vector2(cos(at), sin(at)) * (r + 10),
			Color(0.98, 0.42, 0.30, 0.9), 3.0)
	var rope_at: float = PI * 0.5 - deg_to_rad(ang * k)
	draw_line(pivot, pivot + Vector2(cos(rope_at), sin(rope_at)) * r, Color(0.95, 0.93, 0.88, 0.9), 2.0)
	draw_circle(pivot + Vector2(cos(rope_at), sin(rope_at)) * r, 7.0, Color(0.95, 0.93, 0.88, 0.95))
	draw_circle(pivot, 4.0, Color(0.95, 0.93, 0.88, 0.8))

	var below: float = player.gin_height - float(h.get("height", 0.0))
	_centre("load %.0f m below   ·   swing %.0f°, fouls at %.0f°" % [below, amp, foul],
		pivot.y + r + 26.0, Color(0.92, 0.90, 0.86, 0.9), 14)
	_centre("hold W to haul   ·   push the mouse against the swing   ·   G to let it go",
		pivot.y + r + 46.0, Color(0.80, 0.78, 0.74, 0.7), 13)


## Lashing — VERB-005.
##
## A ring you go round, with the rope going on as you do. Six notches for six turns, with the hitch
## and the full lashing marked, because the whole decision is "three and go, or six and trust it" and
## the player cannot make it without seeing both. Tension is a second, thinner ring outside that
## visibly bleeds away the moment they stop — which is the thing that teaches them not to.
func _draw_lash(jack: Jack) -> void:
	var st: Dictionary = jack.lash_state()
	var wraps: int = st["wraps"]
	var laid: float = st["laid"]
	var tension: float = st["tension"]
	var hitch := int(jack.tuning_f("lashWrapsQuickHitch", 3))
	var full := int(jack.tuning_f("lashWrapsFull", 6))

	var c := Vector2(size.x * 0.5, size.y * 0.40)
	var r := 64.0

	# A plate under the whole thing. It is a modal verb — nothing else you can do while the rope is
	# going round — so it is allowed to own its part of the screen, and it has to be readable over
	# whatever brickwork happens to be behind it.
	var plate := Rect2(Vector2(c.x - 268.0, c.y - r - 72.0), Vector2(536.0, r * 2.0 + 198.0))
	draw_rect(plate, Color(0.05, 0.05, 0.06, 0.46))
	draw_rect(Rect2(plate.position, Vector2(plate.size.x, 2.0)), Color(0.86, 0.84, 0.78, 0.26))

	# What is going on, in words: the new section is stood on the old one, and the rope is what
	# holds it to the dog. Without this the ring and the count were a minigame about nothing.
	_centre("Roping the new section to the dog", c.y - r - 52.0, Color(0.97, 0.95, 0.90, 0.95), 18)
	_centre("each circle of the mouse is one turn of rope round the dog and the ladder",
		c.y - r - 30.0, Color(0.86, 0.84, 0.80, 0.85), 13)

	# The turn in progress, filling round the ring, from the top, the way a clock hand goes.
	draw_arc(c, r, 0, TAU, 64, Color(0.9, 0.88, 0.84, 0.18), 6.0)
	if laid > 0.0:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * laid, 48, Color(0.86, 0.72, 0.46, 0.95), 6.0)

	# Tension, outside it. Bleeds away when you stop, and you can watch it go.
	draw_arc(c, r + 14.0, -PI * 0.5, -PI * 0.5 + TAU * tension, 48,
		Color(0.66, 0.78, 0.90, 0.55 + 0.4 * tension), 3.0)

	# The count, and what it buys.
	_centre("%d" % wraps, c.y + 12.0, Color(0.97, 0.95, 0.90, 0.95), 38)
	var what := "not enough to hold yet — %d turns makes a hitch" % hitch
	if wraps >= full:
		what = "full lashing — solid. Tie it off [R]"
	elif wraps >= hitch:
		what = "quick hitch — it holds, but creeps. %d turns is solid" % full
	_centre(what, c.y + r + 42.0, Color(0.92, 0.88, 0.82, 0.88), 15)

	# Notches for each turn, with the hitch and the full lashing marked out from the rest.
	var y := c.y + r + 62.0
	var step := 22.0
	var x0 := c.x - step * float(full - 1) * 0.5
	for k in full:
		var p := Vector2(x0 + step * k, y)
		var done := k < wraps
		var col := Color(0.86, 0.72, 0.46, 0.95) if done else Color(0.9, 0.88, 0.84, 0.30)
		var rr := 6.0 if (k + 1 == hitch or k + 1 == full) else 4.0
		if done:
			draw_circle(p, rr, col)
		else:
			draw_arc(p, rr, 0, TAU, 16, col, 1.5)

	var method: String = player.LASH_METHODS[player.lash_method]
	var how := "hold LMB and go round" if method == "rotate" else (
		"tap LMB" if method == "mash" else "hold LMB")
	_centre("%s   ·   [R] tie off   ·   [RMB] let go   ·   [L] %s" % [how, method],
		y + 26.0, Color(0.80, 0.78, 0.74, 0.75), 13)
	if tension < jack.tuning_f("lashTieOffMinTension", 0.45) and wraps >= hitch:
		_centre("the rope is going slack — tie off now and the knot will slip", y + 46.0,
			Color(0.95, 0.62, 0.40, 0.9), 13)


## Rigging a stance. Twenty seconds into a bosun's chair is a long time to stare at nothing.
##
## The bar says how long is left; the line under it says what it is buying. Both matter: the player
## is spending grip *now* against a drain they will pay *later*, and a countdown with no stake
## attached is just a wait.
## What each stance buys you, in the one sentence that explains why anybody would pay for it.
const STANCE_WHY := {
	1: "a leg through the rungs — both hands, and you are still holding on with something",
	2: "a line to the rung above — a slip ends at the end of the line",
	3: "belted to both stiles — both hands free, and almost no grip going out",
	4: "sat in it. No grip at all, and you can work all day where you are",
}


func _draw_rig(jack: Jack) -> void:
	var eye := Vector2(size.x * 0.5, size.y * 0.42)
	var done: float = 1.0 - (player.rig_left / maxf(player.rig_total, 0.01))

	var w := 260.0
	var at := Vector2(eye.x - w * 0.5, eye.y)
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(w + 2, 10)), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(at, Vector2(w * done, 8)), Color(0.82, 0.74, 0.48, 0.95))

	# Where he is now and where he is going, when they differ. The chair is four rungs up the
	# table and is reached by climbing it, so a bar that only ever named the rung in hand would
	# make thirty seconds of rigging look like four separate things that kept restarting.
	var heading := "rigging — %s" % jack.stance_name_of(player.rigging_to)
	if player.rig_want > player.rigging_to:
		heading = "rigging — %s, on the way to %s" % [jack.stance_name_of(player.rigging_to),
			jack.stance_name_of(player.rig_want)]
	_centre(heading, eye.y - 26.0, Color(0.94, 0.91, 0.86, 0.92), 18)
	_centre("%.1f s" % player.rig_left, eye.y + 26.0, Color(0.88, 0.85, 0.80, 0.85), 15)

	var from_rate: float = jack.stance_drain_rate(jack.get_stance())
	var to_rate: float = jack.stance_drain_rate(player.rigging_to)
	_centre("%.0f grip a second becomes %.0f" % [from_rate, to_rate], eye.y + 48.0,
		Color(0.80, 0.78, 0.74, 0.75), 13)
	# What it is *for*, not just what it costs. A twenty-second bar with a grip figure under it
	# tells a player what they are paying and never what they are buying, and the chair is the one
	# stance whose whole reason for existing is the thing the bar does not say: you can stop
	# holding on. It is also the only place in the game that sentence can be read.
	var why: String = STANCE_WHY.get(player.rigging_to, "")
	if why != "":
		_centre(why, eye.y + 70.0, Color(0.84, 0.81, 0.76, 0.80), 14)
		_centre("[Q] to stop  ·  moving or working breaks it", eye.y + 92.0,
			Color(0.72, 0.70, 0.67, 0.68), 13)
	else:
		_centre("[Q] to stop  ·  moving or working breaks it", eye.y + 70.0,
			Color(0.72, 0.70, 0.67, 0.68), 13)


## The gust, arriving. 1.2 seconds, and then it hits your hands.
##
## Drawn along the top edge rather than in the middle, because the player is usually looking at a
## joint and a reticle when it starts and must not have either covered up. It closes inwards from
## both sides, so it reads as something converging on you and gives the remaining time as a length
## rather than as a number nobody will read in a second.
func _draw_gust_tell(jack: Jack) -> void:
	var p: float = jack.gust_tell_progress()
	var col := Color(0.62, 0.74, 0.86, 0.45 + 0.55 * p)

	var margin := 40.0
	var span: float = (size.x * 0.5 - margin) * (1.0 - p)
	var y := 26.0
	draw_line(Vector2(margin, y), Vector2(margin + span, y), col, 3.0 + 3.0 * p)
	draw_line(Vector2(size.x - margin, y), Vector2(size.x - margin - span, y), col, 3.0 + 3.0 * p)

	_centre("gust", y + 16.0, Color(0.88, 0.92, 0.96, 0.5 + 0.5 * p), 16)


## The slip.
##
## A ring that closes, a word, and the key. Three things and no colour dependency between them: the
## ring shrinking is the timer, and someone who cannot tell the red from the gold can still see it
## going. Per docs/01-gdd/14-accessibility.md, nothing here may be the only channel a cue arrives on.
func _draw_slip(jack: Jack) -> void:
	var left: float = jack.slip_window_left()
	var eye := Vector2(size.x * 0.5, size.y * 0.42)

	# Everything else dims. This is not decoration — it is what makes a 900 ms window findable on a
	# screen that also has a chimney, a stack, two meters and five affordances on it.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.02, 0.45 * (1.0 - left * 0.4)))

	var r := 96.0
	draw_arc(eye, r, 0, TAU, 72, Color(0.9, 0.88, 0.85, 0.25), 3.0)
	# Closing clockwise from the top, so "running out" reads the way a clock does.
	draw_arc(eye, r, -PI * 0.5, -PI * 0.5 + TAU * left, 72, Color(0.95, 0.31, 0.22, 0.95), 9.0)

	# And it closes inwards as well as round, so the shape alone carries the time.
	draw_arc(eye, r * (0.25 + 0.55 * left), 0, TAU, 48, Color(0.95, 0.31, 0.22, 0.55), 3.0)

	_centre("GRAB", eye.y - 8.0, Color(0.98, 0.95, 0.90, 0.95), 46)
	_centre("SPACE", eye.y + 34.0, Color(0.95, 0.92, 0.88, 0.88), 20)

	# Why this is happening, in three words, while it happens. Afterwards is too late to learn it.
	_centre("your grip went", eye.y + r + 34.0, Color(0.90, 0.86, 0.82, 0.80), 15)

	# And whether there was ever anything to grab at. A window that is already spent looks exactly
	# like one you missed, unless it says so.
	if not jack.can_slip_save():
		_centre("nothing left to catch with", eye.y + r + 56.0, Color(0.95, 0.45, 0.35, 0.85), 14)



## The conductor run, on screen — the instrument for the archetype.
##
## The verb shipped before this did and the job was unplayable for it: you could pay out tape,
## clip it and pass or fail an inspection with nothing on screen telling you how much tape was
## left, how far the run had wandered, or that it would not pass until the pit was dug. Rule 7
## wants every failure telegraphed, and "the run is already too long" is a failure you can only
## act on if you can watch it coming.
const RUN_W := 210.0


func _draw_conductor(jack: Jack) -> void:
	if not player.conductor_job:
		return
	var st: Dictionary = jack.conductor_state(maxf(player.height_m(), 0.0))
	if st.is_empty():
		return
	var at := Vector2(size.x - RUN_W - 44.0, 150.0)

	draw_rect(Rect2(at - Vector2(14.0, 26.0), Vector2(RUN_W + 28.0, 162.0)),
		Color(0.05, 0.04, 0.03, 0.5))
	_label("THE RUN", at, Color(GHOST, 0.8), TINY)

	# Tape, which is the resource and the clock. A 25 m reel does not reach the bottom of a 28 m
	# chimney and the player is supposed to find that out with time to think about it.
	var left: float = float(st.get("tape_left", 0.0))
	var need: float = maxf(player.height_m(), 0.0)
	var col := GOOD if left > need * 1.15 else (WATCH if left > need else DANGER)
	_label("%.0f m of tape" % left, at + Vector2(0.0, 24.0), col, H2)
	_label("%.0f m still to go down" % need, at + Vector2(0.0, 42.0), Color(FAINT, 0.85), SMALL)
	var frac: float = clampf(left / maxf(need + left, 0.01), 0.0, 1.0)
	draw_rect(Rect2(at + Vector2(0.0, 50.0), Vector2(RUN_W, 6.0)), Color(0.05, 0.04, 0.03, 0.6))
	draw_rect(Rect2(at + Vector2(0.0, 50.0), Vector2(RUN_W * frac, 6.0)), col)

	# The Code's curvature rule, as a bar with its own limit drawn on it. "No more than half as
	# long again as the straight line joining them" is a ratio, so it can be a gauge.
	var wander: float = float(st.get("wander", 1.0))
	var fail: float = player.jack.tuning_f("wanderFailRatio", 1.5)
	var warn: float = player.jack.tuning_f("wanderWarnRatio", 1.2)
	var wcol := GOOD if wander <= warn else (WATCH if wander <= fail else DANGER)
	_label("the line: %.2f" % wander, at + Vector2(0.0, 78.0), wcol, SMALL)
	var track := Rect2(at + Vector2(0.0, 84.0), Vector2(RUN_W, 6.0))
	draw_rect(track, Color(0.05, 0.04, 0.03, 0.6))
	# Scaled so the Code's limit sits at three quarters — the bar is about the limit, not about 2.0.
	var span: float = (fail - 1.0) / 0.75
	draw_rect(Rect2(track.position, Vector2(RUN_W * clampf((wander - 1.0) / span, 0.0, 1.0), 6.0)),
		wcol)
	var mark: float = at.x + RUN_W * clampf((fail - 1.0) / span, 0.0, 1.0)
	draw_line(Vector2(mark, track.position.y - 3.0), Vector2(mark, track.position.y + 9.0),
		Color(DANGER, 0.9), 1.0)

	# And what is still wrong with it. Worst first, one line, because this is a checklist the
	# player is working through rather than a report.
	var why := ""
	if not bool(st.get("terminal", false)):
		why = "no terminal yet — it goes at the very top"
	elif int(st.get("over_tight", 0)) > 0:
		why = "%d pinched — they will fail when it turns cold" % st.get("over_tight", 0)
	elif wander > fail:
		why = "the run is too long for the drop — it will not pass"
	elif float(st.get("earth_ohms", -1.0)) < 0.0:
		why = "no earth yet — dig the pit at the foot of her"
	elif float(st.get("earth_ohms", 0.0)) > player.jack.tuning_f("earthPassOhms", 10.0):
		why = "%.0f ohms — that will not do" % st.get("earth_ohms", 0.0)
	elif int(st.get("too_loose", 0)) > 0:
		why = "%d loose — they will work off in a gale" % st.get("too_loose", 0)
	var name_ := String(st.get("verdict_name", ""))
	var vcol := GOOD if name_ == "SOUND" else (WATCH if name_ == "MARGINAL" else DANGER)
	_label("%d clips  ·  %s" % [st.get("clips", 0), name_], at + Vector2(0.0, 106.0), vcol, SMALL)
	if why != "":
		_label(why, at + Vector2(0.0, 122.0), Color(vcol, 0.8), TINY)


## The band you are on, drawn as the ring it is.
##
## The puzzle is entirely about ORDER round a circle, so the instrument is a circle: every bolt at
## its own bearing, filled as it comes up, with the one in front of you marked and the shape of
## what you have done visible as a shape. A list of numbers could not show "you have pulled one
## side of her up and left the other", which is the only thing a player needs to see.
const RING_R := 46.0


func _draw_band(jack: Jack) -> void:
	if not player.band_job:
		return
	var index: int = player._band_here()
	if index < 0:
		return
	var st: Dictionary = jack.band_state(index)
	if st.is_empty():
		return
	var n: int = maxi(int(st.get("bolts", 8)), 1)
	var at := Vector2(size.x - 118.0, 196.0)

	draw_circle(at, RING_R + 22.0, Color(0.05, 0.04, 0.03, 0.5))
	var fit := String(st.get("fit_name", "LOOSE"))
	var col := GOOD if fit == "SEATED" else (
		DANGER if fit == "OVAL" else (WATCH if fit == "TRUE" else FAINT))

	# The ring itself, drawn out of round in proportion to how out of round it is. The number is
	# on screen too, but the shape is what you read.
	var oval: float = clampf(float(st.get("ovality", 0.0)), 0.0, 1.0)
	var pts := PackedVector2Array()
	for i in 49:
		var a: float = TAU * float(i) / 48.0
		pts.append(at + Vector2(cos(a) * RING_R * (1.0 + oval * 0.5),
			sin(a) * RING_R * (1.0 - oval * 0.5)))
	for i in pts.size() - 1:
		draw_line(pts[i], pts[i + 1], Color(col, 0.55), 2.0)

	var here: int = player._band_bolt_here(index)
	var tension: PackedFloat32Array = st.get("tension", PackedFloat32Array())
	var seat: float = player.jack.tuning_f("bandSeatTension", 0.72)
	for b in n:
		# Bearing zero at the top, going round the way he goes round.
		var a: float = TAU * float(b) / float(n) - PI * 0.5
		var p := at + Vector2(cos(a), sin(a)) * RING_R
		# Each bolt at its OWN tension, because a count cannot show you that the six you have
		# pulled up are all on one side — which is the only thing about an oval band you can act on.
		var pull: float = tension[b] if b < tension.size() else 0.0
		draw_circle(p, 6.0, Color(0.05, 0.04, 0.03, 0.8))
		if pull > 0.0:
			draw_circle(p, 1.5 + 4.5 * clampf(pull, 0.0, 1.0),
				Color(GOOD if pull >= seat else WATCH, 0.9))
		draw_arc(p, 6.0, 0.0, TAU, 12, Color(col, 0.7), 1.5)
		if b == here:
			draw_arc(p, 10.0, 0.0, TAU, 14, Color(INK, 0.9), 2.0)
	# The count in the middle, because "six of twelve" is the one thing the ring cannot say.
	var label := "%d/%d" % [int(st.get("tightened", 0)), n]
	var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, H2).x
	_label(label, at - Vector2(lw * 0.5, -6.0), Color(col, 0.95), H2)

	var words := {"LOOSE": "loose", "TRUE": "coming in true", "OVAL": "going oval",
		"SEATED": "home and true"}
	var word: String = String(words.get(fit, ""))
	var ww: float = _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL).x
	_label(word, at - Vector2(ww * 0.5, -RING_R - 30.0), Color(col, 0.9), SMALL)
	if fit == "OVAL":
		var msg := "work the other side of her"
		var mw: float = _font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, TINY).x
		_label(msg, at - Vector2(mw * 0.5, -RING_R - 46.0), Color(DANGER, 0.85), TINY)


## The report, as it fills — the SURVEY archetype's instrument.
##
## A survey has no resource and no timer; what it has is a list of things that are wrong with a
## chimney and no way of knowing how many you have left to find. So the panel says how many there
## are, which is the only number that makes the job a job rather than a wander, and it says what
## you have got without saying where the rest are.
func _draw_survey(jack: Jack) -> void:
	if not player.survey_job:
		return
	var r: Dictionary = jack.survey_report()
	if r.is_empty() or int(r.get("total", 0)) <= 0:
		return
	var at := Vector2(size.x - 232.0, 150.0)
	var found: int = int(r.get("found", 0))
	var total: int = int(r.get("total", 0))
	var col := GOOD if bool(r.get("complete", false)) else (WATCH if found > 0 else FAINT)

	draw_rect(Rect2(at - Vector2(14.0, 26.0), Vector2(216.0, 86.0)), Color(0.05, 0.04, 0.03, 0.5))
	_label("THE REPORT", at, Color(GHOST, 0.8), TINY)
	_label("%d of %d" % [found, total], at + Vector2(0.0, 26.0), col, H1)
	var w: float = _font.get_string_size("%d of %d" % [found, total],
		HORIZONTAL_ALIGNMENT_LEFT, -1, H1).x
	_label("found", at + Vector2(w + 10.0, 26.0), Color(col, 0.8), SMALL)

	# Ticks rather than a bar: a survey is a list of discrete things, and four of five should look
	# like four of five rather than like eighty per cent.
	for i in total:
		var x: float = at.x + float(i) * 20.0
		var on: bool = i < found
		draw_rect(Rect2(Vector2(x, at.y + 40.0), Vector2(14.0, 5.0)),
			col if on else Color(GHOST, 0.35))
	if bool(r.get("complete", false)):
		_label("that is the lot — go down and tell them",
			at + Vector2(0.0, 62.0), Color(GOOD, 0.85), TINY)


## The plumb line — the STRAIGHTEN archetype's instrument.
##
## The whole verb is deciding, so the instrument is a prediction: where she is now, where a cut
## here at this thickness would put her, and where she will finish once the weeks of overshoot have
## run. All three on one scale, because the entire skill is reading the difference between the
## second and the third.
func _draw_plumb(jack: Jack) -> void:
	if not player.plumb_job:
		return
	var st: Dictionary = jack.plumb_state()
	if st.is_empty():
		return
	var at := Vector2(size.x - 250.0, 150.0)
	var w := 214.0
	draw_rect(Rect2(at - Vector2(14.0, 26.0), Vector2(w + 28.0, 176.0)),
		Color(0.05, 0.04, 0.03, 0.5))
	_label("THE PLUMB LINE", at, Color(GHOST, 0.8), TINY)

	var start: float = float(st.get("lean_at_start", 1.0))
	var now: float = float(st.get("lean_now", 0.0))
	var scale: float = maxf(absf(start), 0.4) * 1.4
	var mid: float = at.x + w * 0.5

	# The scale: plumb in the middle, the way she started at one end.
	draw_line(Vector2(at.x, at.y + 44.0), Vector2(at.x + w, at.y + 44.0), Color(GHOST, 0.4), 2.0)
	draw_line(Vector2(mid, at.y + 34.0), Vector2(mid, at.y + 54.0), Color(INK, 0.8), 2.0)
	_label("plumb", Vector2(mid - 16.0, at.y + 68.0), Color(GHOST, 0.7), TINY)

	# Where she started, faint, so you can see what you have done.
	var sx: float = mid + w * 0.5 * clampf(start / scale, -1.0, 1.0)
	draw_line(Vector2(sx, at.y + 38.0), Vector2(sx, at.y + 50.0), Color(GHOST, 0.5), 2.0)

	# Where she is.
	var nx: float = mid + w * 0.5 * clampf(now / scale, -1.0, 1.0)
	draw_circle(Vector2(nx, at.y + 44.0), 6.0, Color(INK, 0.95))
	_label("%.2f m out" % absf(now), at + Vector2(0.0, 24.0), Color(INK, 0.95), H2)

	if bool(st.get("collapsed", false)):
		_label("she is down", at + Vector2(0.0, 92.0), DANGER, SMALL)
		return

	if not player.plumb_cut_done:
		# The prediction. This is the instrument: a cut here, this deep, lands her THERE — and the
		# overshoot carries her past it, which is why you aim short.
		var p: Dictionary = player.plumb_here()
		var lands: float = start - float(p.get("brings_back", 0.0))
		var over: float = lands - float(p.get("brings_back", 0.0)) \
			* player.jack.tuning_f("straightenOvershootShare", 0.14)
		var lx: float = mid + w * 0.5 * clampf(lands / scale, -1.0, 1.0)
		var ox: float = mid + w * 0.5 * clampf(over / scale, -1.0, 1.0)
		draw_line(Vector2(lx, at.y + 36.0), Vector2(lx, at.y + 52.0), Color(WATCH, 0.9), 2.0)
		# Where the weeks afterwards take her — the one a first-timer does not know about.
		draw_line(Vector2(ox, at.y + 40.0), Vector2(ox, at.y + 48.0), Color(DANGER, 0.85), 3.0)
		draw_line(Vector2(lx, at.y + 44.0), Vector2(ox, at.y + 44.0), Color(DANGER, 0.5), 1.0)

		var risk: float = float(p.get("risk", 0.0))
		var rcol := GOOD if risk < 0.5 else (WATCH if risk < 0.82 else DANGER)
		_label("cut here, %.1f mm out" % player.plumb_take_out,
			at + Vector2(0.0, 92.0), Color(DIM, 0.9), SMALL)
		_label("brings her back %.2f m  [X]" % float(p.get("brings_back", 0.0)),
			at + Vector2(0.0, 110.0), Color(WATCH, 0.9), SMALL)
		_label("and she keeps going after", at + Vector2(0.0, 128.0), Color(DANGER, 0.75), TINY)
		_label("the cut swings her: %s" % ["steady", "she will move", "she will not come back"][
			0 if risk < 0.5 else (1 if risk < 0.82 else 2)],
			at + Vector2(0.0, 146.0), Color(rcol, 0.9), TINY)
	else:
		var settling: bool = bool(st.get("settling", false))
		var sway: float = float(st.get("sway_cm", 0.0))
		_label("on the wedges" if settling else String(st.get("verdict_name", "")),
			at + Vector2(0.0, 92.0), WATCH if settling else GOOD, SMALL)
		if settling:
			_label("the slit is opening and closing %.1f cm" % sway,
				at + Vector2(0.0, 110.0), Color(DANGER if sway > 1.2 else DIM, 0.85), TINY)
			_label("she comes back in her own time", at + Vector2(0.0, 128.0),
				Color(GHOST, 0.8), TINY)
		else:
			_label("%.2f m out when the weeks have run" % absf(float(st.get("lean_when_done", 0.0))),
				at + Vector2(0.0, 110.0), Color(DIM, 0.9), TINY)


# --- the instruments ------------------------------------------------------------------------------

const BAR_W := 200.0
const BAR_H := 9.0
const TREMOR_AT := 0.25          ## where grip starts costing you; drawn, not remembered


## One meter: an icon, a name, a number, and a bar with the danger notch marked.
func _draw_meter(at: Vector2, name_: String, fraction: float, col: Color, alpha: float,
		flashing: bool) -> void:
	var f: float = clampf(fraction, 0.0, 1.0)
	var line := Color(col, maxf(alpha, 0.5))
	if name_ == "GRIP":
		_icon_hand(at + Vector2(0.0, -4.0), line)
	else:
		_icon_pulse(at + Vector2(0.0, -4.0), line)
	_label(name_, at + Vector2(24.0, 0.0), line, TINY)
	var num := "%d" % roundi(f * 100.0)
	var nw: float = _font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL).x
	_label(num, at + Vector2(BAR_W - nw, 0.0), line, SMALL)

	var track := Rect2(at + Vector2(0.0, 6.0), Vector2(BAR_W, BAR_H))
	draw_rect(track, Color(0.05, 0.04, 0.03, 0.55))
	if f > 0.0:
		draw_rect(Rect2(track.position, Vector2(BAR_W * f, BAR_H)), line)
	# The threshold you must not cross, as a mark on the scale rather than a number to recall.
	var notch: float = at.x + BAR_W * TREMOR_AT
	draw_line(Vector2(notch, track.position.y - 2.0), Vector2(notch, track.position.y + BAR_H + 2.0),
		Color(DANGER, 0.85), 1.0)
	if flashing:
		draw_rect(Rect2(track.position - Vector2(1, 1), Vector2(BAR_W + 2, BAR_H + 2)),
			Color(DANGER, 0.5 * alpha), false, 2.0)


## What he is carrying, as counts rather than a sentence. "no ladder   0 dogs in the bag   top 15m"
## was three unrelated facts welded together; these are three chips that dim when empty instead of
## vanishing, so the slot keeps its place and the eye learns where to look.
func _draw_kit(at: Vector2, breath: float) -> void:
	var x := at.x
	x = _chip(Vector2(x, at.y), CHIP_LADDER, 1 if player.carrying_ladder else 0, breath)
	x = _chip(Vector2(x, at.y), CHIP_DOG, player.dogs_carried, breath)
	if player.jack != null and player.jack.anchor_count() > 0:
		x = _chip(Vector2(x, at.y), CHIP_LASH, int(player.jack.anchor_count()), breath)


const CHIP_LADDER := 0
const CHIP_DOG := 1
const CHIP_LASH := 2


func _chip(at: Vector2, kind: int, count: int, _breath: float) -> float:
	var live: bool = count > 0
	var col := Color(CHALK, 0.92) if live else Color(GHOST, 0.42)
	var w := 54.0
	draw_rect(Rect2(at, Vector2(w, 22.0)), Color(0.05, 0.04, 0.03, 0.45 if live else 0.25))
	var mid := at + Vector2(13.0, 11.0)
	match kind:
		CHIP_LADDER: _icon_ladder(mid, col)
		CHIP_DOG:    _icon_dog(mid, col)
		CHIP_LASH:   _icon_lash(mid, col)
	_label("%d" % count, at + Vector2(28.0, 16.0), col, SMALL)
	return at.x + w + 7.0


## The stack gauge — the whole climb, down the left edge.
##
## It replaces four lines of text at once: the height, "top 15m", "the ladder: WORKING" and the
## span band. More than that, it is the image 00-vision.md calls the best the game has — your own
## ladder stack receding below you — turned into something you can read. Height rides the marker
## that says where you are, which is what finally got it out of the bottom-left corner.
const GAUGE_X := 34.0
const GAUGE_W := 26.0
const GAUGE_TOP := 96.0
const GAUGE_BOTTOM := 132.0


func _draw_stack_gauge(jack: Jack) -> void:
	var total: float = maxf(float(jack.total_height()), 1.0)
	var top_y: float = GAUGE_TOP
	var bot_y: float = size.y - GAUGE_BOTTOM
	var span: float = bot_y - top_y

	# The chimney, with its own batter, so the gauge is a picture of THIS stack and not a ruler.
	var pts := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var f: float = float(i) / float(steps)
		var r: float = float(jack.radius_at(f * total))
		pts.append(Vector2(GAUGE_X - GAUGE_W * 0.5 * r / maxf(float(jack.radius_at(0.0)), 0.01),
			bot_y - span * f))
	for i in range(steps, -1, -1):
		var f: float = float(i) / float(steps)
		var r: float = float(jack.radius_at(f * total))
		pts.append(Vector2(GAUGE_X + GAUGE_W * 0.5 * r / maxf(float(jack.radius_at(0.0)), 0.01),
			bot_y - span * f))
	draw_colored_polygon(pts, Color(0.06, 0.05, 0.05, 0.45))
	draw_line(Vector2(GAUGE_X - 13.0, top_y), Vector2(GAUGE_X + 13.0, top_y), Color(GHOST, 0.8), 2.0)
	_label("%.0f" % total, Vector2(GAUGE_X + 18.0, top_y + 4.0), Color(GHOST, 0.7), TINY)

	# The ladder you have built, in the colour of what the whole stack is worth.
	var verdict_col := GOOD
	var survey: Dictionary = jack.stack_survey()
	if not survey.is_empty():
		var n := String(survey.get("verdict_name", "SOUND"))
		verdict_col = DANGER if n == "NOT RIGHT" else (WATCH if n == "WORKING" else GOOD)
	var ladder_y: float = bot_y - span * clampf(player.ladder_top / total, 0.0, 1.0)
	draw_line(Vector2(GAUGE_X + 2.0, bot_y), Vector2(GAUGE_X + 2.0, ladder_y), verdict_col, 3.0)
	draw_line(Vector2(GAUGE_X - 4.0, ladder_y), Vector2(GAUGE_X + 8.0, ladder_y), verdict_col, 2.0)

	# Every dog at its real height, coloured by what it is worth. A bad run of anchors is a
	# pattern here, and a pattern is a thing no sentence can show you.
	var first_to_go: int = int(survey.get("first_to_go", -1))
	for i in jack.anchor_count():
		var a: Dictionary = jack.anchor_at(i)
		if a.is_empty():
			continue
		var ay: float = bot_y - span * clampf(float(a["height"]) / total, 0.0, 1.0)
		var rate := int(a["rate"])
		var c: Color = [DANGER, DANGER, WATCH, GOOD][clampi(rate, 0, 3)]
		var wide: bool = i == first_to_go
		draw_line(Vector2(GAUGE_X - (14.0 if wide else 10.0), ay),
			Vector2(GAUGE_X + (14.0 if wide else 10.0), ay), c, 4.0 if wide else 2.0)

	# Where a fall would put you, and only when the survey says the stack will not hold one.
	if not survey.is_empty() and not bool(survey.get("holds_a_fall", true)):
		var to_y: float = bot_y - span * clampf(float(survey.get("would_fall_to", 0.0)) / total,
			0.0, 1.0)
		var me_y: float = bot_y - span * clampf(maxf(player.height_m(), 0.0) / total, 0.0, 1.0)
		var y := me_y
		while y < to_y:
			draw_line(Vector2(GAUGE_X + 2.0, y), Vector2(GAUGE_X + 2.0, minf(y + 5.0, to_y)),
				Color(DANGER, 0.9), 2.0)
			y += 10.0

	# And him, with the number riding alongside.
	var h: float = maxf(player.height_m(), 0.0)
	var my: float = bot_y - span * clampf(h / total, 0.0, 1.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(GAUGE_X - 24.0, my - 7.0), Vector2(GAUGE_X - 24.0, my + 7.0),
		Vector2(GAUGE_X - 13.0, my)]), Color(INK, 0.95))
	_label("%.0f" % h, Vector2(GAUGE_X + 20.0, my + 10.0), Color(INK, 0.95), H1)
	var hw: float = _font.get_string_size("%.0f" % h, HORIZONTAL_ALIGNMENT_LEFT, -1, H1).x
	_label("m", Vector2(GAUGE_X + 24.0 + hw, my + 10.0), Color(DIM, 0.9), SMALL)
	if player.on_ladder and player.ladder_top > h:
		_label("%.0f m of ladder up" % (player.ladder_top - h),
			Vector2(GAUGE_X + 20.0, my + 26.0), Color(FAINT, 0.8), TINY)


# --- icons ----------------------------------------------------------------------------------------
#
# Stroke paths, drawn with the same draw_line calls everything else here uses. No textures, no
# atlas, nothing to import — which is the only reason a HUD in this project can afford icons at all.

func _icon_hand(at: Vector2, col: Color) -> void:
	for i in 3:
		var x: float = at.x + 4.0 + float(i) * 3.5
		draw_line(Vector2(x, at.y - 1.0), Vector2(x, at.y - 7.0 + float(i) * 0.8), col, 1.6)
	draw_line(Vector2(at.x + 3.0, at.y - 1.0), Vector2(at.x + 3.0, at.y + 3.0), col, 1.6)
	draw_arc(at + Vector2(7.0, 1.0), 5.0, 0.0, PI, 10, col, 1.6)


func _icon_pulse(at: Vector2, col: Color) -> void:
	var p := PackedVector2Array([
		Vector2(at.x, at.y), Vector2(at.x + 3.0, at.y), Vector2(at.x + 5.0, at.y - 5.0),
		Vector2(at.x + 8.0, at.y + 5.0), Vector2(at.x + 10.5, at.y - 2.0),
		Vector2(at.x + 12.5, at.y + 1.0), Vector2(at.x + 16.0, at.y)])
	for i in p.size() - 1:
		draw_line(p[i], p[i + 1], col, 1.6)


func _icon_ladder(at: Vector2, col: Color) -> void:
	draw_line(at + Vector2(-4.0, -7.0), at + Vector2(-4.0, 7.0), col, 1.6)
	draw_line(at + Vector2(4.0, -7.0), at + Vector2(4.0, 7.0), col, 1.6)
	for i in 3:
		var y: float = at.y - 4.0 + float(i) * 4.0
		draw_line(Vector2(at.x - 4.0, y), Vector2(at.x + 4.0, y), col, 1.4)


func _icon_dog(at: Vector2, col: Color) -> void:
	draw_line(at + Vector2(-6.0, 6.0), at + Vector2(2.0, -2.0), col, 1.8)
	draw_line(at + Vector2(2.0, -2.0), at + Vector2(6.0, -6.0), col, 1.8)
	draw_line(at + Vector2(6.0, -6.0), at + Vector2(6.0, -1.0), col, 1.8)


func _icon_lash(at: Vector2, col: Color) -> void:
	draw_arc(at, 6.0, 0.0, TAU, 16, col, 1.5)
	draw_arc(at, 2.6, 0.0, TAU, 10, col, 1.5)

# --- drawing helpers ----------------------------------------------------------------------------

## The four one-pixel passes that put an edge round every glyph in this HUD.
const OUTLINE := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]

func _arc(centre: Vector2, radius: float, fraction: float, width: float, col: Color) -> void:
	if fraction <= 0.0 or col.a <= 0.01:
		return
	# Opening away from the centre of the screen, so the arcs frame the hand rather than point at
	# the action.
	var start := deg_to_rad(128.0)
	var sweep := deg_to_rad(244.0) * clampf(fraction, 0.0, 1.0)
	draw_arc(centre, radius, -start, -start + sweep, 48, col, width)


func _label(text: String, at: Vector2, col: Color, px: int = 15) -> void:
	if col.a <= 0.01:
		return
	# A shadow rather than a panel: legible against sky without putting a box between the player
	# and the thing they climbed up to see.
	#
	# It has to go all the way round, though. A single offset drop only darkens one side of the
	# glyph, and this HUD spends most of its life against bright sky, where the undarkened side is
	# pale ink on pale cloud and the letter loses an edge. Four one-pixel passes cost nothing and
	# are the difference between text you read and text you decipher.
	var halo := Color(0, 0, 0, col.a * 0.55)
	for o in OUTLINE:
		draw_string(_font, at + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, halo)
	draw_string(_font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0, 0, 0, col.a * 0.45))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _centre(text: String, y: float, col: Color, px: int = 15) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_label(text, Vector2((size.x - w) * 0.5, y), col, px)


func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## The scrim: a permanent, very soft darkening of the four edges, under everything else.
##
## This HUD lives against sky, and a British sky at ten in the morning is the brightest thing in
## the frame by a long way. Outlined text survives it — barely — but a gauge drawn in thin lines
## does not, and the top-left stack gauge was a rumour. A shadow on each glyph fixes one glyph;
## it cannot fix a shape. So the edges of the frame get a gradient instead, strongest where the
## instruments actually are, and nothing in the middle third is touched at all: you still look out
## of a clean window at the thing you climbed up to see.
##
## Rule 20: it does not move, pulse or respond to anything. It is part of the frame.
var _scrim: Dictionary = {}

func _scrim_tex(dir: Vector2) -> GradientTexture2D:
	var key := str(dir)
	if _scrim.has(key):
		return _scrim[key]
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 1))
	g.set_color(1, Color(0, 0, 0, 0))
	# Most of the fall happens in the first third, so the band has a dark lip and a long tail
	# rather than a visible straight ramp with an edge you can see.
	g.add_point(0.34, Color(0, 0, 0, 0.30))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.5, 0.5) - dir * 0.5
	t.fill_to = Vector2(0.5, 0.5) + dir * 0.5
	t.width = 8 if dir.y != 0.0 else 128
	t.height = 128 if dir.y != 0.0 else 8
	_scrim[key] = t
	return t


const SCRIM_TOP := 0.20      ## how dark the lip of each band is
const SCRIM_BOTTOM := 0.34
const SCRIM_SIDE := 0.22

func _draw_scrim() -> void:
	var down := Vector2(0, 1)
	var right := Vector2(1, 0)
	draw_texture_rect(_scrim_tex(down), Rect2(0.0, 0.0, size.x, size.y * 0.26),
		false, Color(1, 1, 1, SCRIM_TOP))
	draw_texture_rect(_scrim_tex(-down), Rect2(0.0, size.y * 0.66, size.x, size.y * 0.34),
		false, Color(1, 1, 1, SCRIM_BOTTOM))
	draw_texture_rect(_scrim_tex(right), Rect2(0.0, 0.0, size.x * 0.17, size.y),
		false, Color(1, 1, 1, SCRIM_SIDE))
	draw_texture_rect(_scrim_tex(-right), Rect2(size.x * 0.80, 0.0, size.x * 0.20, size.y),
		false, Color(1, 1, 1, SCRIM_SIDE))


## The tunnel at the edges when nerve is going — 03-meters-grip-nerve.md's "tunnel vignette" in the
## bottom band, a lighter one in the band above. An option, on by default (14-accessibility.md).
## Steady, never pulsing: it deepens as the band drops and that is all it does.
var _vignette_tex: GradientTexture2D

func _draw_vignette(jack: Jack) -> void:
	if player.settings == null or not bool(player.settings.get_value("low_nerve_vignette")):
		return
	var band: int = jack.nerve_band()
	if band < 2 or player.at_top:
		return
	if _vignette_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0))
		g.set_color(1, Color(0, 0, 0, 1))
		g.add_point(0.55, Color(0, 0, 0, 0))
		_vignette_tex = GradientTexture2D.new()
		_vignette_tex.gradient = g
		_vignette_tex.fill = GradientTexture2D.FILL_RADIAL
		_vignette_tex.fill_from = Vector2(0.5, 0.5)
		_vignette_tex.fill_to = Vector2(1.05, 0.5)
		_vignette_tex.width = 256
		_vignette_tex.height = 256
	var a := 0.35 if band == 2 else 0.6
	draw_texture_rect(_vignette_tex, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, a))


## The motion options, F1. A plain list: the one being changed is bright, and the keys are said.
## The options panel's geometry, in one place.
##
## It is here rather than inline in the drawing because the input code has to hit-test exactly the
## rectangles that get drawn. Two copies of "the third row is 70 + 26i pixels down" drift apart the
## first time a row is added, and a menu whose clicks land one row off is worse than one that
## ignores the mouse — which is what this one did.
const OPT_W := 460.0
const OPT_ROW_H := 26.0
const OPT_FIRST_Y := 70.0
const OPT_VALUE_W := 150.0   ## the right-hand strip where the ‹ value › sits


func _options_rect() -> Rect2:
	var h := 64.0 + OPT_ROW_H * float(GameSettings.ROWS.size()) + 40.0
	return Rect2(Vector2((size.x - OPT_W) * 0.5, (size.y - h) * 0.5), Vector2(OPT_W, h))


## What is under a point: `{row, step}`, where step is -1 or +1 if the point is on the value's left
## or right half and 0 if it is on the label. Empty when the point is off the panel entirely.
func options_hit(p: Vector2) -> Dictionary:
	var r := _options_rect()
	if not r.has_point(p):
		return {}
	for i in GameSettings.ROWS.size():
		var y: float = r.position.y + OPT_FIRST_Y + OPT_ROW_H * float(i)
		if p.y >= y - 18.0 and p.y <= y + 6.0:
			var value_left: float = r.position.x + OPT_W - 24.0 - OPT_VALUE_W
			var step := 0
			if p.x >= value_left:
				step = 1 if p.x >= value_left + OPT_VALUE_W * 0.5 else -1
			return {"row": i, "step": step}
	return {}


func _draw_options() -> void:
	var rows: Array = GameSettings.ROWS
	var r := _options_rect()
	var w: float = r.size.x
	var h: float = r.size.y
	var at: Vector2 = r.position
	draw_rect(r, Color(0.05, 0.05, 0.06, 0.86))
	_label("Motion and vertigo", at + Vector2(24, 36), Color(0.96, 0.94, 0.90, 0.95), 18)
	for i in rows.size():
		var y: float = at.y + OPT_FIRST_Y + OPT_ROW_H * float(i)
		var on: bool = i == player.options_row
		var col := Color(0.98, 0.96, 0.92, 0.98) if on else Color(0.78, 0.76, 0.72, 0.8)
		if on:
			draw_rect(Rect2(Vector2(at.x + 12, y - 18), Vector2(w - 24, 24)), Color(1, 1, 1, 0.07))
		_label(String(rows[i][1]), Vector2(at.x + 24, y), col, 14)
		var v: String = player.settings.shown(rows[i][0])
		var vw := _font.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_label(("‹ %s ›" % v) if on else v, Vector2(at.x + w - 24 - vw - (14.0 if on else 0.0), y), col, 14)
	_label("↑↓ or click   ←→ or click the value   F1 close  ·  saved as you go",
		Vector2(at.x + 24, at.y + h - 16),
		Color(0.70, 0.68, 0.64, 0.75), 12)
