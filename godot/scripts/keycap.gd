# A key, drawn as a key.
#
# "[E]" is a programmer's notation for a keyboard, not a picture of one. This game already asks the
# player to learn a trade they have never heard of — sounding a joint, seating a dog, pulling a
# band up in a star — and the one thing that should cost them nothing is working out which button
# to press.
#
# The control list on the climbing HUD was done first and had its own copy of this. The felling
# screen, which is the climax of the game, was still writing "[B]" and "[P]" and "hold [F]" in the
# middle of its sentences. So it lives here, and `inline` will render a whole sentence with its
# keys turned into keys wherever they appear in it.

class_name Keycap
extends RefCounted

const H := 17.0
const PAD := 5.0
const GAP := 3.0
const MOUSE_W := 13.0


static func width(font: Font, label: String) -> float:
	return maxf(H, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + PAD * 2.0)


## One cap. Returns how wide it was.
static func cap(ci: CanvasItem, font: Font, label: String, at: Vector2, col: Color) -> float:
	var w := width(font, label)
	ci.draw_rect(Rect2(at, Vector2(w, H)), Color(0.09, 0.09, 0.10, col.a * 0.62), true)
	ci.draw_rect(Rect2(at, Vector2(w, H)), Color(col.r, col.g, col.b, col.a * 0.70), false, 1.0)
	# The lip along the bottom edge. Two pixels, and the whole difference between a keycap and a
	# rectangle with a letter in it.
	ci.draw_line(at + Vector2(2.0, H - 2.0), at + Vector2(w - 2.0, H - 2.0),
		Color(col.r, col.g, col.b, col.a * 0.32), 1.5)
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	ci.draw_string(font, at + Vector2((w - tw) * 0.5, H - 5.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(col.r, col.g, col.b, col.a * 0.95))
	return w


## A mouse seen from above, with the button that matters filled in. "RMB" is three letters the
## player has to decode; a lit right button is not.
static func mouse(ci: CanvasItem, which: String, at: Vector2, col: Color) -> float:
	var body := Rect2(at, Vector2(MOUSE_W, H))
	ci.draw_rect(body, Color(0.09, 0.09, 0.10, col.a * 0.62), true)
	var line := Color(col.r, col.g, col.b, col.a * 0.70)
	ci.draw_rect(body, line, false, 1.0)
	var split := H * 0.42
	ci.draw_line(at + Vector2(0.0, split), at + Vector2(MOUSE_W, split), line, 1.0)
	ci.draw_line(at + Vector2(MOUSE_W * 0.5, 0.0), at + Vector2(MOUSE_W * 0.5, split), line, 1.0)
	var lit := Color(col.r, col.g, col.b, col.a * 0.85)
	if which == "L":
		ci.draw_rect(Rect2(at + Vector2(1.0, 1.0),
			Vector2(MOUSE_W * 0.5 - 1.5, split - 2.0)), lit, true)
	elif which == "R":
		ci.draw_rect(Rect2(at + Vector2(MOUSE_W * 0.5 + 0.5, 1.0),
			Vector2(MOUSE_W * 0.5 - 1.5, split - 2.0)), lit, true)
	return MOUSE_W


## What a control's key draws as: a run of caps, or a mouse with one button lit.
static func glyphs(key: String) -> Array:
	match key:
		"RMB": return [["m", "R"]]
		"LMB": return [["m", "L"]]
		"mouse": return [["m", ""]]
		"WASD": return [["c", "W"], ["c", "A"], ["c", "S"], ["c", "D"]]
		"W/S": return [["c", "W"], ["c", "S"]]
		"C / V": return [["c", "C"], ["c", "V"]]
		_: return [["c", key]]


## How wide a key's glyphs will be, including the gaps between them.
static func run_width(font: Font, key: String) -> float:
	var w := 0.0
	for g in glyphs(key):
		w += (MOUSE_W if g[0] == "m" else width(font, String(g[1]))) + GAP
	return w


## Draw a key's glyphs left to right from `at` (the TOP of the caps). Returns the width used.
static func run(ci: CanvasItem, font: Font, key: String, at: Vector2, col: Color) -> float:
	var x := at.x
	for g in glyphs(key):
		if g[0] == "m":
			x += mouse(ci, String(g[1]), Vector2(x, at.y), col) + GAP
		else:
			x += cap(ci, font, String(g[1]), Vector2(x, at.y), col) + GAP
	return x - at.x


## A whole sentence, with anything in [square brackets] drawn as a key.
##
## "Pack the gob [hold F], light it [L], and RUN" comes out with two keycaps in it and the words
## either side untouched. `at` is the text baseline, as `draw_string` takes it.
static func inline(ci: CanvasItem, font: Font, text: String, at: Vector2, col: Color,
		px: int) -> float:
	var x := at.x
	var rest := text
	while true:
		var open := rest.find("[")
		var shut := rest.find("]", open + 1)
		if open < 0 or shut < 0:
			break
		var before := rest.substr(0, open)
		if before != "":
			ci.draw_string(font, Vector2(x, at.y), before, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
			x += font.get_string_size(before, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var key := rest.substr(open + 1, shut - open - 1).strip_edges()
		# "hold F" is a word and a key. The word stays a word.
		var lead := ""
		var sp := key.rfind(" ")
		if sp > 0:
			lead = key.substr(0, sp + 1)
			key = key.substr(sp + 1)
		if lead != "":
			ci.draw_string(font, Vector2(x, at.y), lead, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
			x += font.get_string_size(lead, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		x += run(ci, font, key, Vector2(x, at.y - H + 4.0), col) + 2.0
		rest = rest.substr(shut + 1)
	if rest != "":
		ci.draw_string(font, Vector2(x, at.y), rest, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		x += font.get_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	return x - at.x
