extends Node
## Global display state shared by the scene, the UI and the chapters, plus the few persisted preferences.

signal changed
signal selection_changed(info: Dictionary)
signal layer_visibility_changed(key: String, visible: bool)
signal mode_changed(mode: String)

const PREFS_PATH := "user://prefs.cfg"

## Persisted choices (user://prefs.cfg): narration audio, subtitles, hover pop-ups. Loaded in _ready.
var narration_on := true:
	set(v):
		narration_on = v
		set_pref("narration_on", v)
var subtitles_on := true:
	set(v):
		subtitles_on = v
		set_pref("subtitles_on", v)
var hover_info := true:
	set(v):
		hover_info = v
		set_pref("hover_info", v)
		changed.emit()
var ambience_on := true:
	set(v):
		ambience_on = v
		set_pref("ambience_on", v)


func _ready() -> void:
	narration_on = bool(get_pref("narration_on", true))
	subtitles_on = bool(get_pref("subtitles_on", true))
	hover_info = bool(get_pref("hover_info", true))
	ambience_on = bool(get_pref("ambience_on", true))

## "basic" = streamlined screen (narration, scrubber, key, captions); "advanced" = every panel and control.
var ui_mode := "basic":
	set(v):
		if v == ui_mode:
			return
		ui_mode = v
		mode_changed.emit(v)
var candidate_zone := "both":   # chapter 4: "A", "B" or "both"
	set(v):
		candidate_zone = v
		changed.emit()
var cover_skin := false:
	set(v):
		cover_skin = v
		changed.emit()
## Chapter 7, scenario 1 ("source used up"): how the exhaustion is expressed.
## "colluvium" = the hillside store thins with the flood; "bar" = no hidden source, only the bar stock dwindles;
## "both" = colluvium thins and the bar is not replenished.
var depletion_mode := "both":
	set(v):
		depletion_mode = v
		changed.emit()

const TIER_NAMES := {"observed": "Observed", "inferred": "Inferred", "illustrative": "Illustrative", "mindat_reported": "Mindat-reported"}
const TIER_IDS := {"observed": 0, "inferred": 1, "illustrative": 2, "mindat_reported": 3}
const TIER_COLORS := {
	"observed": Color(0.16, 0.42, 0.72),
	"inferred": Color(0.93, 0.60, 0.17),
	"illustrative": Color(0.55, 0.55, 0.58),
	"mindat_reported": Color(0.55, 0.25, 0.65),
}

var vexag := 1.0:
	set(v):
		vexag = clampf(v, 1.0, 5.0)
		changed.emit()
var thicken_factor := 20.0
var thicken_on := true:
	set(v):
		thicken_on = v
		changed.emit()
var tier_styling := true:
	set(v):
		tier_styling = v
		changed.emit()
var cut_enabled := false:
	set(v):
		cut_enabled = v
		changed.emit()
var cut_plane := Plane(Vector3.UP, 1.0e9):
	set(v):
		cut_plane = v
		changed.emit()
var color_mode := 3:   # 0 bedrock units, 1 surficial, 2 hillshade, 3 natural (textured; polish pass)
	set(v):
		color_mode = v
		changed.emit()
var selected := {}:
	set(v):
		selected = v
		selection_changed.emit(v)

var layer_visible := {}


func set_layer_visible(key: String, on: bool) -> void:
	layer_visible[key] = on
	layer_visibility_changed.emit(key, on)


func is_layer_visible(key: String, default := true) -> bool:
	return layer_visible.get(key, default)


func tier_name(tier: String) -> String:
	return TIER_NAMES.get(tier, tier)


func tier_color(tier: String) -> Color:
	return TIER_COLORS.get(tier, Color.WHITE)


## Persisted preferences (user://prefs.cfg): intro-screen choice, narration, subtitles, hover pop-ups.
func get_pref(key: String, default: Variant) -> Variant:
	var cf := ConfigFile.new()
	if cf.load(PREFS_PATH) != OK:
		return default
	return cf.get_value("prefs", key, default)


func set_pref(key: String, value: Variant) -> void:
	var cf := ConfigFile.new()
	cf.load(PREFS_PATH)
	cf.set_value("prefs", key, value)
	cf.save(PREFS_PATH)


static func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("cannot open " + path)
		return null
	var txt := f.get_as_text()
	f.close()
	var r: Variant = JSON.parse_string(txt)
	if r == null:
		push_error("bad JSON in " + path)
	return r
