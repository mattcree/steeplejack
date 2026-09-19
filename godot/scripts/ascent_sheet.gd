# The whole climb as a contact sheet: test_ascent's bot, photographed every thirty seconds.
#
# One frame of a pose (make shot) cannot show what the game looks like across a climb — the
# bands changing, the stack going up, the haul, the top. This plays the real ascent under a
# virtual display and saves a frame at a fixed interval of game time, so the jank is visible in
# order. The test itself is untouched: this only listens to its clock.
#
#   make ascent-sheet            # frames in build/ascent-sheet/

extends "res://scripts/test_ascent.gd"

const EVERY_SECONDS := 30.0
const OUT_DIR := "res://../build/ascent-sheet"

var _next := 0.0


func _step() -> void:
	await super()
	if t < _next:
		return
	_next += EVERY_SECONDS
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/ascent-%04d.png" % [ProjectSettings.globalize_path(OUT_DIR), int(t)])
