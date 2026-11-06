extends Node
## Guided tour, paced by the narration.  Each chapter is a list of beats (Chapter.tour_beats); for every beat the
## tour flies the camera to the beat's view, applies its cut / ring / tinted layers, plays the beat's narration
## clip (godot/assets/narration, timings in data/narration/narration.json) and advances the scrubber from the
## beat's t to the next beat's t over the clip's length.  As the narration first mentions an entity, that entity
## pulses with a glowing outline for a few seconds (the "cues"); the current sentence is shown as a subtitle.
## Beats without a clip fall back to a reading time derived from the caption.  N (or "Next >") skips a beat.

signal caption_changed(text: String)
signal state_changed

var main: Node
var on := false
var narration: Dictionary = {}        # data/narration/narration.json
var player: AudioStreamPlayer
var _beat_idx := -1
var _beat_len := 0.0                  # seconds this beat is shown (clip length + tail, or the reading time)
var _beat_time := 0.0                 # seconds elapsed in the beat
var _beat_t0 := 0.0
var _beat_t1 := 1.0
var _cues: Array = []
var _cue_idx := 0
var _cue_expire := -1.0
var _active_cue: Dictionary = {}
var _sents: Array = []
var _sent_idx := -1
var _advance_timer := 0.0
var _switching := false
const END_DELAY := 2.5                # pause after a chapter's last beat before the next chapter
const FLY := 2.4
# camera as storyteller (round 7): a beat's view is the start of a move that runs for the beat's length; the
# default is a slow drift (10 deg of orbit, a 10 % push-in); chapters give dramatic ones in beat extras:
#   {"move": {"orbit": deg, "dolly": [k0, k1], "rise": m, "look_rise": m, "hold": s}}
const DEFAULT_MOVE := {"orbit": 10.0, "dolly": [1.0, 0.9]}
var _fly_dur := 0.0
var _user_cam := false                # the user took the camera during this beat: no scripted move until the next
var _prev_view := -1.0                # view distance of the previous beat (for the scale-change cues)
const CUE_HOLD := 5.0                 # seconds an entity stays outlined after its mention
const TAIL := 0.4                     # seconds after the clip ends before the next beat


## The camera pose of a beat `u` (0..1) of the way through its move.
static func beat_pose(b: Dictionary, u: float) -> Array:
	var pos: Vector3 = b["pos"]
	var look: Vector3 = b["look"]
	var m: Dictionary = b.get("move", DEFAULT_MOVE)
	var hold: float = float(m.get("hold", 0.0))
	var e: float = smoothstep(0.0, 1.0, clampf(u, 0.0, 1.0))
	if hold > 0.0:
		e = smoothstep(0.0, 1.0, clampf((u - hold) / maxf(1.0 - hold, 1.0e-3), 0.0, 1.0))
	var rel := pos - look
	if m.has("dolly"):
		var d: Array = m["dolly"]
		rel *= lerpf(float(d[0]), float(d[1]), e)
	if m.has("orbit"):
		rel = rel.rotated(Vector3.UP, deg_to_rad(float(m["orbit"])) * e)
	if m.has("rise"):
		rel.y += float(m["rise"]) * e
	if m.has("look_rise"):
		look.y += float(m["look_rise"]) * e
	return [look + rel, look]


func setup(m: Node) -> void:
	main = m
	m.camera.user_moved.connect(func(): _user_cam = true)
	player = AudioStreamPlayer.new()
	player.name = "Narrator"
	add_child(player)
	var nj: Variant = AppState.load_json("res://data/narration/narration.json")
	if nj is Dictionary:
		narration = nj
	Timeline.t_changed.connect(_on_t)
	Timeline.chapter_changed.connect(_on_chapter)


## Narration data for a chapter's beat ({} when there is none).
func beat_data(ch, i: int) -> Dictionary:
	var c: Dictionary = narration.get("chapters", {}).get(ch.id, {})
	var bs: Array = c.get("beats", [])
	return bs[i] if i >= 0 and i < bs.size() else {}


func total_minutes() -> float:
	return float(narration.get("total_s", 0.0)) / 60.0


func start(from_chapter := 0) -> void:
	on = true
	AppState.ui_mode = "basic"
	main.hover_enabled = false
	main.ui.hide_info()
	_beat_idx = -1
	Timeline.go_to_chapter(from_chapter, true)   # -> _on_chapter -> _begin_chapter
	state_changed.emit()


func stop() -> void:
	on = false
	_advance_timer = 0.0
	player.stop()
	main.ambience.stop_all()   # the beds and cues stop with the tour (round 9)
	Timeline.playing = false
	Timeline.play_speed = Timeline.MANUAL_SPEED
	main.hover_enabled = AppState.hover_info
	_clear_marks()
	caption_changed.emit(current_caption())
	state_changed.emit()


func toggle() -> void:
	if on:
		stop()
	else:
		start(maxi(Timeline.current, 0))


## Skip: the rest of this beat (or the pause at the end of a chapter).
func skip() -> void:
	if not on:
		return
	if _advance_timer > 0.0:
		_advance_timer = 0.001
	else:
		_next_beat()


func _clear_marks() -> void:
	main.volumes.clear_highlights()
	main.volumes.clear_outlines()
	main.clear_outlines()
	main.terrain.set_highlight(Vector3.ZERO, 0.0)
	_cue_expire = -1.0


func _on_chapter(_i: int) -> void:
	_beat_idx = -1
	_user_cam = false
	_advance_timer = 0.0
	player.stop()
	if on:
		_begin_chapter()


func _begin_chapter() -> void:
	var ch = Timeline.current_chapter()
	if ch == null:
		return
	_clear_marks()
	Timeline.playing = false
	if ch.tour_beats.is_empty():
		Timeline.play_speed = Timeline.MANUAL_SPEED
		Timeline.playing = true
		return
	_start_beat(0)


func _start_beat(i: int) -> void:
	var ch = Timeline.current_chapter()
	if ch == null:
		return
	if i >= ch.tour_beats.size():
		_end_chapter()
		return
	_switching = true
	_clear_marks()
	player.stop()
	_beat_idx = i
	var b: Dictionary = ch.tour_beats[i]
	_beat_t0 = float(b["t"])
	_beat_t1 = float(ch.tour_beats[i + 1]["t"]) if i + 1 < ch.tour_beats.size() else 1.0
	Timeline.set_t(_beat_t0)
	var d := 0.0
	if b.has("pos") and not ch.owns_camera:
		d = _fly(b)
	if b.has("cut"):
		AppState.cut_enabled = bool(b["cut"])
	_apply_beat_marks(b)
	var nd := beat_data(ch, i)
	_cues = nd.get("cues", [])
	_cue_idx = 0
	_sents = nd.get("sentences", [])
	_sent_idx = -1
	var cap := str(b.get("caption", ""))
	if nd.is_empty():
		_beat_len = d + _reading_time(cap) * float(b.get("hold_scale", 1.0))
		caption_changed.emit(cap)
	else:
		_beat_len = float(nd.get("duration", 10.0)) + TAIL
		caption_changed.emit("")
		if AppState.narration_on and nd.has("file") and ResourceLoader.exists(str(nd["file"])):
			var s: AudioStream = load(str(nd["file"]))
			if s:
				player.stream = s
				player.play()
	_beat_time = 0.0
	var span := _beat_t1 - _beat_t0
	if span > 1.0e-6:
		Timeline.play_speed = (span / _beat_len) / maxf(float(ch.play_rate), 1.0e-6)
		Timeline.playing = true
	else:
		Timeline.play_speed = 0.0
		Timeline.playing = false
	_switching = false


## The beat's own marks: tinted layers and the ground ring (persist for the whole beat).
func _apply_beat_marks(b: Dictionary) -> void:
	main.volumes.clear_highlights()
	for k in b.get("highlight", []):
		main.volumes.set_highlight(k, true)
	if b.has("ring"):
		var r: Array = b["ring"]
		main.terrain.set_highlight(r[0], float(r[1]))
	else:
		main.terrain.set_highlight(Vector3.ZERO, 0.0)


func _end_chapter() -> void:
	var ch = Timeline.current_chapter()
	_clear_marks()
	player.stop()
	Timeline.playing = false
	Timeline.set_t(1.0)
	_beat_idx = ch.tour_beats.size() if ch else 0
	_advance_timer = END_DELAY


func _next_beat() -> void:
	var ch = Timeline.current_chapter()
	if ch == null:
		return
	if _beat_idx + 1 < ch.tour_beats.size():
		_start_beat(_beat_idx + 1)
	else:
		_end_chapter()


## Fly the camera to the start of a beat's move; returns the flight time. The flight lasts longer the farther it
## goes (1.6-4.2 s) and carries a cue: a swoop, or an airy swell / quick dive when the scale changes by 6x or more.
func _fly(b: Dictionary) -> float:
	var pose: Array = beat_pose(b, 0.0)
	var pos: Vector3 = pose[0]
	var look: Vector3 = pose[1]
	main.camera.set_near(float(b.get("near", 0.5)))
	var view: float = maxf((pos - look).length(), 1.0e-4)
	var travel: float = main.camera.cam.global_position.distance_to(pos)
	var dur: float = float(b.get("fly", clampf(1.6 + travel / 2500.0, 1.6, 4.2)))
	var ch = Timeline.current_chapter()
	var cues_ok: bool = (ch == null or bool(ch.camera_cues)) and bool(b.get("cue", true))
	if _prev_view > 0.0 and travel > view * 0.5 and cues_ok:
		var r := view / _prev_view
		if r > 6.0:
			main.ambience.play("vast")
		elif r < 1.0 / 6.0:
			main.ambience.play("dive")
		elif dur >= 2.6:
			main.ambience.play("whoosh_long")
		else:
			main.ambience.play("whoosh_short")
	_prev_view = view
	_fly_dur = dur
	_user_cam = false
	main.camera.fly_to(pos, look, dur)
	return dur


static func _reading_time(text: String) -> float:
	var words := text.split(" ", false).size()
	return clampf(1.5 + 0.32 * words, 4.0, 12.0)


## Outline margin from the view distance (1.2 % of it): the beat's own view if it has one, else the live camera.
func _cue_margin() -> float:
	var ch = Timeline.current_chapter()
	var dist: float = main.camera.distance
	if ch and _beat_idx >= 0 and _beat_idx < ch.tour_beats.size():
		var b: Dictionary = ch.tour_beats[_beat_idx]
		if b.has("pos") and not ch.owns_camera:
			dist = Vector3(b["pos"]).distance_to(b["look"])
	return clampf(dist * 0.012, 0.00005, 60.0)


## A cue: pulse a glowing outline on the entities the narration has just named.
func _fire_cue(c: Dictionary) -> void:
	_clear_cue()
	var mg := _cue_margin()
	for k in c.get("layers", []):
		var keys: Array = main.volumes.zone_a_keys() if str(k) == "zone_a" else [str(k)]
		for kk in keys:
			main.volumes.set_outline(kk, true, mg)
			if not AppState.cut_enabled:
				main.volumes.set_highlight(kk, true)
	if not c.get("nodes", []).is_empty():
		main.outline_nodes(c["nodes"], mg)
	if c.has("ring"):
		var r: Array = c["ring"]
		if r[0] is String:
			var centre: Vector3 = main.sgb if str(r[0]) == "sgb" else main.gbr
			main.terrain.set_highlight(centre, float(r[1]))
		else:
			main.terrain.set_highlight(Vector3(float(r[0]), 0.0, float(r[1])), float(r[2]))
	_cue_expire = _beat_time + CUE_HOLD
	_active_cue = c


## Layer frames depend on the layer's growth and the cut plane: rebuild them while the cue is live.
var _frame_clock := 0.0
var _frame_sig := ""


func _refresh_cue_frames() -> void:
	if _active_cue.is_empty() or not AppState.cut_enabled:
		return
	var sig := "%.6f|%s|%.3f" % [Timeline.t, str(AppState.cut_plane), AppState.vexag]
	if sig == _frame_sig:
		return
	_frame_sig = sig
	var mg := _cue_margin()
	for k in _active_cue.get("layers", []):
		var keys: Array = main.volumes.zone_a_keys() if str(k) == "zone_a" else [str(k)]
		for kk in keys:
			main.volumes.set_outline(kk, true, mg)


func _clear_cue() -> void:
	_active_cue = {}
	main.volumes.clear_outlines()
	main.clear_outlines()
	var ch = Timeline.current_chapter()
	if ch and _beat_idx >= 0 and _beat_idx < ch.tour_beats.size():
		_apply_beat_marks(ch.tour_beats[_beat_idx])
	_cue_expire = -1.0


## Manual scrubbing during the tour: jump to the beat that owns the new position.
func _on_t(t: float) -> void:
	if not on or _switching or _advance_timer > 0.0:
		return
	var ch = Timeline.current_chapter()
	if ch == null or _beat_idx < 0 or _beat_idx >= ch.tour_beats.size():
		return
	if t < _beat_t0 - 0.002 or t > _beat_t1 + 0.002:
		var idx := 0
		for i in ch.tour_beats.size():
			if t >= float(ch.tour_beats[i]["t"]) - 1.0e-6:
				idx = i
		_start_beat(idx)


func current_caption() -> String:
	var ch = Timeline.current_chapter()
	if ch == null:
		return ""
	var b: Dictionary = ch.beat_at(Timeline.t)
	return str(b.get("caption", ""))


## The narration sentence being spoken now ("" outside a narrated beat).
func current_sentence() -> String:
	if _sent_idx >= 0 and _sent_idx < _sents.size():
		return str(_sents[_sent_idx].get("text", ""))
	return ""


func _process(dt: float) -> void:
	if not on:
		return
	if _advance_timer > 0.0:
		_advance_timer -= dt
		if _advance_timer <= 0.0:
			_advance_timer = 0.0
			var nxt := Timeline.current + 1
			if nxt < Timeline.chapters.size():
				Timeline.go_to_chapter(nxt, true)
			else:
				stop()
		return
	var ch = Timeline.current_chapter()
	if ch == null or _beat_idx < 0 or _beat_idx >= ch.tour_beats.size():
		return
	_beat_time += dt
	# the beat's camera move (unless the chapter drives the camera or the user took it)
	if ch.tour_beats[_beat_idx].has("pos") and not ch.owns_camera and not _user_cam and not main.camera.flying:
		var u := clampf((_beat_time - _fly_dur) / maxf(_beat_len - _fly_dur, 0.1), 0.0, 1.0)
		var pose: Array = beat_pose(ch.tour_beats[_beat_idx], u)
		main.camera.drive(pose[0], pose[1])
	# subtitles: the sentence whose start has passed
	if not _sents.is_empty():
		var si := -1
		for i in _sents.size():
			if _beat_time >= float(_sents[i].get("start", 0.0)):
				si = i
		if si != _sent_idx:
			_sent_idx = si
			caption_changed.emit(str(_sents[si].get("text", "")) if (si >= 0 and AppState.subtitles_on) else "")
	# cues
	while _cue_idx < _cues.size() and float(_cues[_cue_idx].get("t", 0.0)) <= _beat_time:
		_fire_cue(_cues[_cue_idx])
		_cue_idx += 1
	if _cue_expire >= 0.0 and _beat_time >= _cue_expire:
		_clear_cue()
	elif _cue_expire >= 0.0:
		_frame_clock += dt
		if _frame_clock >= 0.2:
			_frame_clock = 0.0
			_refresh_cue_frames()
	# hold the scrubber at the beat's end until the narration is over
	if Timeline.playing and Timeline.t >= _beat_t1 - 1.0e-6:
		Timeline.playing = false
		if Timeline.t > _beat_t1:
			Timeline.set_t(_beat_t1)
	if _beat_time >= _beat_len:
		_next_beat()


## Static set-up of one beat for the capture (no audio, no clock): scrubber part-way into the beat, camera
## jumped to the view, the first cue fired and its sentence shown.
func stage_for_capture(ch, i: int) -> void:
	_switching = true
	_clear_marks()
	_beat_idx = i
	var b: Dictionary = ch.tour_beats[i]
	_beat_t0 = float(b["t"])
	_beat_t1 = float(ch.tour_beats[i + 1]["t"]) if i + 1 < ch.tour_beats.size() else 1.0
	var nd := beat_data(ch, i)
	_cues = nd.get("cues", [])
	_sents = nd.get("sentences", [])
	var frac := 0.35
	var cue: Dictionary = _cues[0] if not _cues.is_empty() else {}
	if not cue.is_empty() and nd.has("duration"):
		frac = clampf((float(cue.get("t", 0.0)) + 1.0) / float(nd["duration"]), 0.05, 0.9)
	Timeline.playing = false   # a still: the chapter-driven camera (W) then takes its stage pose at once
	Timeline.set_t(_beat_t0 + (_beat_t1 - _beat_t0) * frac)
	if b.has("cut"):
		AppState.cut_enabled = bool(b["cut"])
	if b.has("pos") and not ch.owns_camera:
		main.camera.set_near(float(b.get("near", 0.5)))
		var pose: Array = beat_pose(b, 0.35)   # part-way into the beat's move
		main.camera.jump_to(pose[0], pose[1])
	_apply_beat_marks(b)
	_beat_time = float(cue.get("t", 0.0)) + 1.0
	if not cue.is_empty():
		_fire_cue(cue)
	var cap := str(b.get("caption", ""))
	if not _sents.is_empty():
		for s in _sents:
			if _beat_time >= float(s.get("start", 0.0)):
				cap = str(s.get("text", ""))
	caption_changed.emit(cap)
	_switching = false
