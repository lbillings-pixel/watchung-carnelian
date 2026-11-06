class_name Chapter
extends RefCounted
## Base class for a chapter. Subclasses fill the descriptive fields and implement enter/set_t/exit.
## tour_beats drive the guided tour (basic mode): each beat is {t, caption, view, highlight, ring, ...}
## and is applied by Tour.gd, which shows each beat for the length of its narration clip (data/narration) and
## pulses an outline on each entity when the narration first names it.

var index := 0
var id := ""
var title := ""
var short_title := ""            # for the chapter bar in basic mode
var narration := ""              # 2-3 sentences, with [term] markers for glossary first-use
var basic_narration := ""        # one or two plain sentences for basic mode (falls back to narration)
var refs := ""                   # paper sections / figures / tables
var strip_from := 1.0e9          # years before present where the chapter starts on the global strip
var strip_to := 0.0
var scrub_label := ""            # what the chapter scrubber measures
var scrub_units := ""            # e.g. "Ma", "m of section", "illustrative"
var scrub_marks: Array = []      # [[t, label], ...]
var play_rate := 1.0
var start_pos := Vector3(0, 4000, 6000)
var start_look := Vector3(0, 80, 0)
var evidence: Array = []         # [{text, ref}]
var charts: Array = []           # ["res://data/charts/x.png", ...]
var tiers: Dictionary = {}       # what is Observed / Inferred / Illustrative in this chapter (for the panel)
var scale_views: Array = []      # [{name, pos, look, near}] zoom path stops
var tour_beats: Array = []       # [{t, caption, pos, look, near, highlight:[layer keys], ring:[center, radius], hold}]
var key_items: Array = []        # extra entries for the key panel: [{name, color, tier}]
var uses_flat_stack := false     # chapters 2-5 show the untilted depositional stack
var owns_camera := false         # chapter W drives the camera itself (the tour only captions)
var camera_cues := true          # false: no swoop / swell / dive cues on this chapter's flights (chapter 1)


func enter(main: Node, animate: bool) -> void:
	if animate:
		main.camera.fly_to(start_pos, start_look)
	else:
		main.camera.cam.global_position = start_pos
		main.camera.cam.look_at(start_look, Vector3.UP)
		main.camera.target = start_look
		main.camera.distance = (start_pos - start_look).length()


func set_t(_t: float, _main: Node) -> void:
	pass


func exit(_main: Node) -> void:
	pass


func scrub_text(t: float) -> String:
	for i in range(scrub_marks.size() - 1, -1, -1):
		if t >= scrub_marks[i][0] - 0.001:
			return scrub_marks[i][1]
	return "%d %%" % int(round(t * 100.0))


static func ramp(t: float, a: float, b: float) -> float:
	return clampf((t - a) / maxf(b - a, 1.0e-6), 0.0, 1.0)


## Helper to build a tour beat.
static func beat(t: float, caption: String, pos: Vector3, look: Vector3, highlight: Array = [], extra: Dictionary = {}) -> Dictionary:
	var b := {"t": t, "caption": caption, "pos": pos, "look": look, "highlight": highlight}
	for k in extra:
		b[k] = extra[k]
	return b


## The tour beat active at t (or {}).
func beat_at(t: float) -> Dictionary:
	var cur := {}
	for b in tour_beats:
		if t >= float(b["t"]) - 1.0e-6:
			cur = b
	return cur
