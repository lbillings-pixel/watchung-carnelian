extends Node
## Scripted capture: steps through every chapter's start view, mid-scrub states, zoom-path scales, the guided
## tour beats in basic mode (each at its first narration cue, outline on), and a few extras; saves PNGs to the directory given after --capture (default
## ../docs/screenshots relative to the project).  Run windowed (not --headless):
##   Godot --path godot -- --capture [outdir]

var main: Node
var outdir := "../docs/screenshots"
var shots: Array = []


func start(m: Node) -> void:
	main = m
	var args := OS.get_cmdline_user_args()
	var i := args.find("--capture")
	if i >= 0 and i + 1 < args.size() and not args[i + 1].begins_with("--"):
		outdir = args[i + 1]
	outdir = ProjectSettings.globalize_path("res://" + outdir) if not outdir.is_absolute_path() else outdir
	DirAccess.make_dir_recursive_absolute(outdir)
	_run()


func _run() -> void:
	await get_tree().process_frame
	main.hover_enabled = false
	main.ui.info_panel.visible = false
	if "--debug" in OS.get_cmdline_user_args():
		await _debug()
		return
	if "--perf" in OS.get_cmdline_user_args():
		await _perf()
		return
	# ---- the introduction screen ----
	main.ui.show_intro()
	await _settle(6)
	await _shot("intro_screen")
	main.ui.intro_screen.visible = false
	# ---- advanced mode: start / 50 % / 100 % and the zoom path of every chapter ----
	AppState.ui_mode = "advanced"
	for ci in Timeline.chapters.size():
		var ch = Timeline.chapters[ci]
		Timeline.go_to_chapter(ci, false)
		await _settle(8)
		main.camera.finish_flight()
		await _settle(2)
		await _shot("ch%d_start" % (ci + 1))
		Timeline.set_t(0.5)
		await _settle(4)
		main.camera.finish_flight()
		await _settle(2)
		await _shot("ch%d_t50" % (ci + 1))
		Timeline.set_t(1.0)
		await _settle(4)
		main.camera.finish_flight()
		await _settle(2)
		await _shot("ch%d_t100" % (ci + 1))
		Timeline.set_t(0.0)
		for sv in ch.scale_views:
			if sv.has("t"):
				Timeline.set_t(sv["t"])
			await _settle(2)
			main.camera.set_near(sv.get("near", 0.5))
			main.camera.jump_to(sv["pos"], sv["look"])
			await _settle(6)
			await _shot("ch%d_%s" % [ci + 1, sv["name"]])
			main.camera.set_near(0.5)
	# ---- basic mode + guided tour: every beat of every chapter, staged at its first narration cue ----
	AppState.ui_mode = "basic"
	main.tour.on = true
	main.tour.state_changed.emit()
	for ci in Timeline.chapters.size():
		var ch = Timeline.chapters[ci]
		Timeline.go_to_chapter(ci, false)
		await _settle(4)
		for bi in ch.tour_beats.size():
			main.tour.stage_for_capture(ch, bi)
			await _settle(2)
			main.camera.finish_flight()
			await _settle(10)
			await _shot("tour_ch%d_beat%d" % [ci + 1, bi + 1])
		main.camera.set_near(0.5)
	main.tour.stop()
	AppState.ui_mode = "advanced"
	# ---- extras: cross-section, true thickness, ruled-out overlay, exaggeration, cover skin in section ----
	Timeline.go_to_chapter(6, false)
	Timeline.set_t(0.45)
	AppState.cut_enabled = true
	# scenario 1 expressions at the end of the flood
	var ch7 = Timeline.chapters[6]
	ch7.scenario = 0
	for mode in ["both", "colluvium", "bar"]:
		AppState.depletion_mode = mode
		Timeline.set_t(0.96)
		var ga: Vector3 = ch7._anchor["GBR"]["near"]
		main.camera.jump_to(ga + Vector3(16, 10, 18), ga + Vector3(0, 1.2, 0))
		await _settle(6)
		await _shot("extra_scenario1_" + mode)
	ch7.scenario = 1
	AppState.depletion_mode = "both"
	Timeline.set_t(0.45)
	AppState.cut_enabled = true
	AppState.cut_plane = Plane(Vector3(0.65, 0.0, -0.76).normalized(), Vector3(0.65, 0.0, -0.76).normalized().dot(main.gbr))
	main.camera.jump_to(main.gbr + Vector3(0.65, 0.0, -0.76).normalized() * 380.0 + Vector3(0, 110, 0), main.gbr)
	await _settle(8)
	await _shot("extra_cover_skin_section")
	Timeline.go_to_chapter(2, false)
	await _settle(4)
	AppState.cut_enabled = true
	await _settle(6)
	await _shot("extra_cross_section")
	AppState.thicken_on = false
	await _settle(4)
	await _shot("extra_true_thickness")
	AppState.thicken_on = true
	AppState.cut_enabled = false
	Timeline.go_to_chapter(6, false)
	main.ruled_out_on = true
	await _settle(6)
	await _shot("extra_ruled_out_overlay")
	main.ruled_out_on = false
	AppState.vexag = 3.0
	await _settle(6)
	await _shot("extra_vexag3")
	AppState.vexag = 1.0
	# steady-state performance (vsync off so the figure is not capped at the refresh rate)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Timeline.go_to_chapter(6, false)
	await _settle(30)
	shots.append("PERF landscape (chapter 7 start view, cover skin on): fps=%.0f" % await _measure())
	Timeline.go_to_chapter(2, false)
	await _settle(30)
	shots.append("PERF cutaway (chapter 3 start view, flat stack): fps=%.0f" % await _measure())
	var f := FileAccess.open(outdir.path_join("index.txt"), FileAccess.WRITE)
	for s in shots:
		f.store_line(s)
	f.close()
	print("capture done: %d images in %s" % [shots.size(), outdir])
	get_tree().quit()


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	if main.ui.info_panel.visible:
		main.ui.info_pinned = false
		main.ui.info_panel.visible = false
		await _settle(2)
	var img: Variant = main.get_viewport().get_texture().get_image()
	var path := outdir.path_join(name + ".png")
	img.save_png(path)
	shots.append(name + ".png  fps=%.0f" % Engine.get_frames_per_second())
	print("saved", path)


## Round-6 diagnostics (-- --capture <dir> --debug): the chapter-2 interference band with one thing switched off
## per shot, the chapter-7 brook beats and the chapter W flood as the tour stages them.
func _debug() -> void:
	AppState.ui_mode = "basic"
	var g: Vector3 = main.gbr
	main.tour.on = true
	main.tour.state_changed.emit()
	# chapter 2, tour beats 2 and 5: baseline, then grain off, frames off, Orange Mountain off, ghost off, cut off
	Timeline.go_to_chapter(1, false)
	await _settle(4)
	for bi in [1, 4]:
		main.tour.stage_for_capture(Timeline.chapters[1], bi)
		await _settle(2)
		main.camera.finish_flight()
		await _settle(10)
		await _shot("dbg_ch2_b%d_base" % (bi + 1))
		for l in main.volumes.layers:
			l["mat"].set_shader_parameter("grain_amount", 0.0)
		await _settle(4)
		await _shot("dbg_ch2_b%d_nograin" % (bi + 1))
		for l in main.volumes.layers:
			l["mat"].set_shader_parameter("grain_amount", 1.0)
		for k in main.volumes._frames:
			main.volumes._frames[k].visible = false
		await _settle(4)
		await _shot("dbg_ch2_b%d_noframe" % (bi + 1))
		main.volumes.set_era_visibility(["passaic", "feltville", "feltville_lacustrine_1", "feltville_lacustrine_2", "feltville_aureole"])
		await _settle(4)
		await _shot("dbg_ch2_b%d_noOM" % (bi + 1))
		main.volumes.set_era_visibility(["passaic", "orange_mountain", "feltville_lacustrine_1", "feltville_lacustrine_2", "feltville_aureole"])
		await _settle(4)
		await _shot("dbg_ch2_b%d_nofeltville" % (bi + 1))
		main.volumes.set_era_visibility(["passaic", "orange_mountain", "feltville", "feltville_lacustrine_1", "feltville_lacustrine_2", "feltville_aureole"])
		main.terrain.visible = false
		await _settle(4)
		await _shot("dbg_ch2_b%d_noghost" % (bi + 1))
		main.terrain.visible = true
		AppState.cut_enabled = false
		await _settle(4)
		await _shot("dbg_ch2_b%d_nocut" % (bi + 1))
		AppState.cut_enabled = true
	# chapter 7 brook beats and chapter W stages as the tour stages them
	Timeline.go_to_chapter(6, false)
	await _settle(4)
	for bi in [3, 4, 5, 6, 7]:
		main.tour.stage_for_capture(Timeline.chapters[6], bi)
		await _settle(2)
		main.camera.finish_flight()
		await _settle(10)
		await _shot("dbg_ch7_beat%d" % (bi + 1))
	Timeline.go_to_chapter(7, false)
	await _settle(4)
	for bi in [4, 5, 6]:
		main.tour.stage_for_capture(Timeline.chapters[7], bi)
		await _settle(2)
		main.camera.finish_flight()
		await _settle(10)
		await _shot("dbg_ch8_beat%d" % (bi + 1))
	var w8 = Timeline.chapters[7]
	for tt in [0.80, 0.84, 0.88]:
		Timeline.set_t(tt)
		await _settle(4)
		main.camera.finish_flight()
		await _settle(10)
		await _shot("dbg_ch8_flood_%d" % int(tt * 100))
	main.camera.set_near(0.5)
	main.tour.stop()
	print("debug capture done")
	get_tree().quit()


## Performance sweep (-- --capture <dir> --perf): steady-state fps (vsync off) at every chapter's start view and
## at every tour beat as the tour stages it; written to perf.txt in the capture directory.
func _perf() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var lines: Array = []
	if "--probe" in OS.get_cmdline_user_args():
		await _probe(lines)
		var pf := FileAccess.open(outdir.path_join("perf.txt"), FileAccess.WRITE)
		for l in lines:
			pf.store_line(l)
			print(l)
		pf.close()
		get_tree().quit()
		return
	AppState.ui_mode = "advanced"
	for ci in Timeline.chapters.size():
		Timeline.go_to_chapter(ci, false)
		await _settle(6)
		main.camera.finish_flight()
		lines.append("ch%d start view: fps=%.0f" % [ci + 1, await _measure()])
		Timeline.set_t(0.5)
		await _settle(4)
		main.camera.finish_flight()
		lines.append("ch%d t=0.5: fps=%.0f" % [ci + 1, await _measure()])
	AppState.ui_mode = "basic"
	main.tour.on = true
	main.tour.state_changed.emit()
	for ci in Timeline.chapters.size():
		var ch = Timeline.chapters[ci]
		Timeline.go_to_chapter(ci, false)
		await _settle(4)
		for bi in ch.tour_beats.size():
			main.tour.stage_for_capture(ch, bi)
			await _settle(2)
			main.camera.finish_flight()
			lines.append("tour ch%d beat%d: fps=%.0f" % [ci + 1, bi + 1, await _measure()])
		main.camera.set_near(0.5)
	main.tour.stop()
	# playing: the scrubber advancing (every chapter's set_t runs each frame)
	AppState.ui_mode = "advanced"
	for ci in Timeline.chapters.size():
		Timeline.go_to_chapter(ci, false)
		await _settle(6)
		main.camera.finish_flight()
		Timeline.set_t(0.3)
		Timeline.play_speed = 0.03
		Timeline.playing = true
		lines.append("ch%d playing from t=0.3: fps=%.0f (%s)" % [ci + 1, await _measure(), last_detail])
		Timeline.playing = false
	Timeline.play_speed = Timeline.MANUAL_SPEED
	var f := FileAccess.open(outdir.path_join("perf.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
		print(l)
	f.close()
	print("perf sweep done")
	get_tree().quit()


## Where does the time go in the slowest tour state (chapter 3 beat 5)? One thing switched off per measurement.
func _probe(lines: Array) -> void:
	AppState.ui_mode = "basic"
	main.tour.on = true
	main.tour.state_changed.emit()
	var ch3 = Timeline.chapters[2]
	Timeline.go_to_chapter(2, false)
	await _settle(4)
	main.tour.stage_for_capture(ch3, 4)
	await _settle(2)
	main.camera.finish_flight()
	main.tour._cue_expire = 1.0e9   # keep the cue live for the whole probe
	for i in 8:
		lines.append("probe ch3 beat5 base, second %d: fps=%.0f (%s)" % [i + 1, await _measure(), last_detail])
	if "--short" in OS.get_cmdline_user_args():
		return
	var v: Node3D = main.volumes
	if v._shimmer:
		v._shimmer.visible = false
		lines.append("probe shimmer off: fps=%.0f" % await _measure())
		v._shimmer.visible = true
	for k in v._frames:
		v._frames[k].visible = false
	lines.append("probe frames off: fps=%.0f" % await _measure())
	for k in v._frames:
		v._frames[k].visible = true
	lines.append("probe frames back on: fps=%.0f" % await _measure())
	for k in v._frames:
		v._frames[k].material_override.no_depth_test = false
	lines.append("probe frames with depth test: fps=%.0f" % await _measure())
	for k in v._frames:
		v._frames[k].material_override.no_depth_test = true
	for k in v._frames:
		v._frames[k].material_override.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	lines.append("probe frames opaque: fps=%.0f" % await _measure())
	for k in v._frames:
		v._frames[k].material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	main.ui.visible = false
	lines.append("probe ui off: fps=%.0f" % await _measure())
	main.ui.visible = true
	main.set_process(false)
	lines.append("probe Main._process off: fps=%.0f" % await _measure())
	main.set_process(true)
	main.tour.set_process(false)
	lines.append("probe Tour._process off: fps=%.0f" % await _measure())
	main.tour.set_process(true)
	main.extras.visible = false
	lines.append("probe extras off: fps=%.0f" % await _measure())
	main.extras.visible = true
	main.terrain.visible = false
	lines.append("probe terrain off: fps=%.0f" % await _measure())
	main.terrain.visible = true
	main.features.visible = false
	lines.append("probe features off: fps=%.0f" % await _measure())
	main.features.visible = true
	var saved_glow: Dictionary = v.glow.duplicate()
	for k in saved_glow:
		v.set_glow(k, 0.0)
	lines.append("probe glow off: fps=%.0f" % await _measure())
	for k in saved_glow:
		v.set_glow(k, saved_glow[k])
	v.visible = false
	lines.append("probe volumes off: fps=%.0f" % await _measure())
	v.visible = true
	# chapter 7 landscape
	main.tour.stop()
	AppState.ui_mode = "advanced"
	Timeline.go_to_chapter(6, false)
	await _settle(6)
	main.camera.finish_flight()
	lines.append("probe ch7 start base: fps=%.0f" % await _measure())
	AppState.cover_skin = false
	lines.append("probe ch7 cover skin off: fps=%.0f" % await _measure())
	AppState.cover_skin = true
	AppState.color_mode = 0
	lines.append("probe ch7 bedrock colours: fps=%.0f" % await _measure())
	AppState.color_mode = 1
	main.volumes.visible = false
	lines.append("probe ch7 volumes off: fps=%.0f" % await _measure())
	main.volumes.visible = true
	main.features.visible = false
	lines.append("probe ch7 features off: fps=%.0f" % await _measure())
	main.features.visible = true
	main.extras.visible = false
	lines.append("probe ch7 extras off: fps=%.0f" % await _measure())
	main.extras.visible = true
	var sun: DirectionalLight3D = main.get_node("Sun")
	sun.shadow_enabled = false
	lines.append("probe ch7 shadows off: fps=%.0f" % await _measure())
	sun.shadow_enabled = true
	main.terrain.visible = false
	lines.append("probe ch7 terrain off: fps=%.0f" % await _measure())
	main.terrain.visible = true


## Frames per second over one second of steady state (after a short warm-up), measured here.
func _measure() -> float:
	await _settle(20)
	var t0 := Time.get_ticks_usec()
	var n := 0
	var pt := 0.0
	while Time.get_ticks_usec() - t0 < 1000000:
		await get_tree().process_frame
		n += 1
		pt += Performance.get_monitor(Performance.TIME_PROCESS)
	last_detail = "process %.1f ms, draw calls %d, primitives %d" % [pt / maxf(n, 1.0) * 1000.0, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)]
	return float(n) * 1.0e6 / float(Time.get_ticks_usec() - t0)


var last_detail := ""
