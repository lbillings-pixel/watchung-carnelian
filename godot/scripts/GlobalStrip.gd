extends Control
## Global timeline strip: Proterozoic -> today on a nonlinear (log years-before-present) scale, with the
## chapter spans and the current chapter highlighted.

const TICKS := [[1.3e9, "1.3 Ga"], [1.0e9, "1 Ga"], [5.0e8, "500 Ma"], [2.5e8, "250 Ma"], [2.01e8, "201 Ma"], [1.0e8, "100 Ma"], [2.3e7, "Miocene 23"], [5.3e6, "Pliocene 5.3"], [2.6e6, "Pleist. 2.6"], [1.0e5, "100 ka"], [2.0e4, "20 ka"], [0.0, "today"]]


func _draw() -> void:
	var w := size.x
	var h := size.y
	var y0 := 8.0
	var bar_h := 16.0
	draw_rect(Rect2(0, y0, w, bar_h), Color(0.2, 0.22, 0.26))
	var font := ThemeDB.fallback_font
	for i in Timeline.chapters.size():
		var ch = Timeline.chapters[i]
		var x0 := Timeline.strip_x(ch.strip_from) * w
		var x1 := Timeline.strip_x(ch.strip_to) * w
		var cur := i == Timeline.current
		var col := Color(0.95, 0.6, 0.2, 1.0) if cur else Color(0.45, 0.55, 0.7, 0.9)
		draw_rect(Rect2(x0, y0 + 1, maxf(x1 - x0, 3.0), bar_h - 2), col)
		draw_string(font, Vector2(x0 + 2, y0 + 12), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK if cur else Color.WHITE)
		if cur:
			var xt := x0 + (x1 - x0) * Timeline.t
			draw_line(Vector2(xt, y0 - 4), Vector2(xt, y0 + bar_h + 4), Color.WHITE, 2.0)
	for tk in TICKS:
		var x := Timeline.strip_x(tk[0]) * w
		draw_line(Vector2(x, y0 + bar_h), Vector2(x, y0 + bar_h + 4), Color(0.8, 0.8, 0.8), 1.0)
		draw_string(font, Vector2(x - 14, y0 + bar_h + 16), tk[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.85, 0.85))
	draw_string(font, Vector2(4, h - 2), "Global strip: log scale in years before present (Illustrative placement of chapters; 201 Ma is Observed)", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.6, 0.65))
