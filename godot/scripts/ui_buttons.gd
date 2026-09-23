# Buttons you can actually click.
#
# Every panel in this game confirmed with Enter and cancelled with Escape and drew neither. That
# is fine for the person who wrote it and hostile to everybody else: a screen that looks like a
# dialog and has no buttons on it reads as broken, and there is no way to find out that Escape is
# the answer except by guessing. The player's note was exact — "do not use keyboard shortcuts as
# the only way to do things."
#
# Keyboard stays, all of it. 14-accessibility.md makes keyboard-only a promise and this does not
# take it back; it adds the other half.
#
# One geometry function, shared by the drawing and the hit-testing. The options panel taught this
# repo that lesson and the jobs board then shipped with the drawing half only, so it is worth
# repeating: two copies of "the second button is 150 pixels along" drift the first time a label
# changes, and a button whose click lands one button over is worse than no button at all.

class_name UiButtons

const PAD_X := 22.0
const PAD_Y := 11.0
const GAP := 14.0


## Where a row of buttons sits, right-aligned to `right` and sitting on `baseline`.
## Returns one Rect2 per label, in the order given.
static func rects(font: Font, labels: Array, px: int, right: float, baseline: float) -> Array:
	var out: Array = []
	var widths: Array = []
	var total := 0.0
	for label in labels:
		var w: float = font.get_string_size(String(label), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x \
			+ PAD_X * 2.0
		widths.append(w)
		total += w
	total += GAP * float(maxi(labels.size() - 1, 0))
	var h: float = float(px) + PAD_Y * 2.0
	var x := right - total
	for i in labels.size():
		out.append(Rect2(Vector2(x, baseline - h), Vector2(float(widths[i]), h)))
		x += float(widths[i]) + GAP
	return out


## Which button a point is over, or -1.
static func hit(boxes: Array, p: Vector2) -> int:
	for i in boxes.size():
		if (boxes[i] as Rect2).has_point(p):
			return i
	return -1


## Draw them. `hot` is the one under the pointer (or keyboard focus), or -1.
##
## `primary` is the one Enter does, drawn filled so the default action is visible without reading:
## on a screen with two ways out, which one is the safe one should not be a question.
static func draw_row(ci: CanvasItem, font: Font, boxes: Array, labels: Array, px: int,
		hot: int, primary: int, ink: Color, face: Color) -> void:
	for i in boxes.size():
		var box: Rect2 = boxes[i]
		var is_primary: bool = i == primary
		var lift: float = 0.14 if i == hot else 0.0
		if is_primary:
			ci.draw_rect(box, Color(face, 0.92 if i == hot else 0.80))
		else:
			ci.draw_rect(box, Color(face, 0.18 + lift))
			ci.draw_rect(box, Color(ink, 0.35 + lift), false, 1.0)
		var label := String(labels[i])
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var col: Color = Color(0.09, 0.08, 0.07) if is_primary else Color(ink, 0.92)
		ci.draw_string(font, box.position + Vector2((box.size.x - w) * 0.5,
			box.size.y - PAD_Y - 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
