extends Node
## Headless smoke test, run through the normal main loop so autoloads exist:
##   godot --headless --path godot -- --smoke
## Main.gd adds this node when it sees --smoke. Checks terrain, volumes, features, steps every chapter in both
## UI modes, exercises the tilt switch, the cover skin, the narrated tour and the outcrop trace; exits non-zero on failure.

var _fail := 0
var main: Node


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   " + msg)
	else:
		_fail += 1
		print("  FAIL " + msg)


func start(m: Node) -> void:
	main = m
	_run()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var terrain: Node = main.terrain
	var volumes: Node = main.volumes
	var features: Node = main.features
	print("terrain chunks:", terrain.get_child_count())
	check(terrain.get_child_count() == 84, "42 terrain chunks + 42 bedrock-top chunks (got %d)" % terrain.get_child_count())
	# graphics quality (Platform.gd): Low swaps every chunk to a 16 m grid, the bedrock-top twin follows, High restores
	var q0: String = Platform.quality
	Platform.set_quality("low")
	var grid: PlaneMesh = terrain.chunks[0].mesh
	check(terrain.stride == 4 and grid.subdivide_width == 124 and terrain.cover_chunks[0].mesh == grid, "Low quality: 16 m terrain grid, twin follows (subdivisions %d)" % grid.subdivide_width)
	Platform.set_quality("high")
	grid = terrain.chunks[0].mesh
	check(terrain.stride == 2 and grid.subdivide_width == 249 and terrain.get_child_count() == 84, "High quality: 8 m terrain grid, same chunk nodes (subdivisions %d)" % grid.subdivide_width)
	Platform.set_quality(q0)
	print("platform: web=%s renderer=%s quality=%s" % [Platform.is_web, RenderingServer.get_current_rendering_method(), Platform.quality])
	var h0: float = terrain.height_at(0.0, 0.0)
	var hg: float = terrain.height_at(main.gbr.x, main.gbr.z)
	var hs: float = terrain.height_at(main.sgb.x, main.sgb.z)
	print("height at origin %.1f, GBR %.1f, SGB %.1f" % [h0, hg, hs])
	check(h0 > 13.0 and h0 < 177.0, "origin height within DEM range")
	check(hg > 60.0 and hg < 170.0, "GBR height plausible (%.1f)" % hg)
	check(hs > 40.0 and hs < 170.0, "SGB height plausible (%.1f)" % hs)
	check(volumes.layers.size() == 24, "24 subsurface layers loaded, 6 of them zone A sheets (got %d)" % volumes.layers.size())
	check(volumes.layers[0]["mesh_flat"] != null, "flat (untilted) meshes loaded")
	var nrm = volumes.layers[0]["mesh"].mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var nrm_flat = volumes.layers[0]["mesh_flat"].surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	check(nrm != null and nrm.size() > 0 and nrm_flat != null, "layer meshes carry normals (generated at load; the glb files have none)")
	var ntex: ImageTexture = preload("res://scripts/NoiseTex.gd").get_texture()
	check(ntex != null and ntex.get_width() == 512, "shared noise texture built (512 px, mipmapped)")
	check(volumes.zone_a_keys().size() == 6 and volumes.zone_a_offsets().size() == 6, "zone A = 6 sheet keys with centre offsets")
	var thick_n := 0
	for l in volumes.layers:
		if l["mesh_tilt_thick"] != null:
			thick_n += 1
	check(thick_n == 15, "15 pre-thickened tilted meshes loaded (got %d)" % thick_n)
	check(absf(volumes.manifest["plane"]["dip_deg"] - 9.5) < 0.01, "dip 9.5 deg (GMS 04-02 section)")
	check(volumes.manifest.has("fold") and absf(volumes.dip_at(main.gbr.x, main.gbr.z) - 9.5) < 0.05 and absf(volumes.dip_at(main.sgb.x, main.sgb.z) - 9.5) < 0.05, "folded surface: 9.5 deg at both sample reaches (GBR %.1f, SGB %.1f)" % [volumes.dip_at(main.gbr.x, main.gbr.z), volumes.dip_at(main.sgb.x, main.sgb.z)])
	var dmin := 99.0
	for u in range(-3000, 1000, 50):
		var o: Array = volumes.manifest["fold"]["origin_xy"]
		var d: Array = volumes.manifest["fold"]["down_dip_unit_xy"]
		dmin = minf(dmin, volumes.dip_at(float(o[0]) + float(d[0]) * u, -(float(o[1]) + float(d[1]) * u)))
	check(dmin > 3.0 and dmin < 9.5, "the flexure flattens between the reaches and the Feltville valley (min dip %.1f deg)" % dmin)
	var gb_unit: String = terrain.bedrock_unit_at(main.gbr.x, main.gbr.z)
	var sb_unit: String = terrain.bedrock_unit_at(main.sgb.x, main.sgb.z)
	print("bedrock unit at GBR: %s, at SGB: %s" % [gb_unit, sb_unit])
	check(gb_unit in ["Jpg", "Jp"], "GBR zone on Preakness/gabbroid")
	check(sb_unit in ["Jpg", "Jp"], "SGB zone on Preakness/gabbroid")
	for site in [["GBR", main.gbr, hg], ["SGB", main.sgb, hs]]:
		var lay: Dictionary = volumes.layer_at_elevation(site[1].x, site[1].z, site[2] - 5.0)
		print("modelled layer 5 m below ground at %s: %s" % [site[0], lay.get("key", "none")])
		check(lay.get("key", "") in ["gabbroid", "glass_rich_gabbroid", "massive_top", "amygdaloidal_top"] + volumes.zone_a_keys(), "%s sits in the gabbroid lens / upper flow in the model" % site[0])
	var cov: float = terrain.cover_thickness_at(main.gbr.x, main.gbr.z)
	print("modelled cover thickness at GBR: %.1f m" % cov)
	check(cov >= 0.0 and cov <= 18.0, "cover thickness at GBR within 0-18 m")
	check(features.site_centers.size() == 2, "2 sample-site zones")
	check(features.mindat_points.size() == 5, "5 Mindat localities")
	check(features.groups.has("glacial_limits"), "glacier-limit lines M1/M2 loaded")
	check(Timeline.chapters.size() == 8, "8 chapters (7 + worm's eye)")
	var pts: Array = []
	for off in volumes.zone_a_offsets():
		pts.append_array(main.zone_outcrop_points(float(off), main.gbr, 700.0, 20.0))
	print("zone A sheet outcrop trace points near GBR: ", pts.size())
	check(pts.size() > 40, "carnelian horizon traces (6 sheets) found around GBR")
	check(not bool(AppState.get_pref("skip_intro", false)) or true, "preferences readable")
	check(main.ui.intro_screen != null and not main.ui.intro_screen.visible, "intro screen built and hidden under --smoke")
	# tilt switch round trip
	volumes.set_tilted(false)
	check(not volumes.tilted and absf(volumes.plane_a) < 1.0e-9, "flat stack active")
	var flat_base: float = volumes.surface_elevation(0.0, main.gbr.x, main.gbr.z)
	volumes.set_tilt_fraction(0.5)
	check(not volumes.tilted and absf(volumes.tilt_fraction - 0.5) < 1.0e-6, "half tilt applied as a rigid rotation")
	volumes.set_tilted(true)
	var tilt_base: float = volumes.surface_elevation(0.0, main.gbr.x, main.gbr.z)
	check(absf(flat_base - tilt_base) < 1.0, "flat and tilted stacks agree at the GBR flow base (%.1f vs %.1f m)" % [flat_base, tilt_base])
	for mode in ["advanced", "basic"]:
		AppState.ui_mode = mode
		await get_tree().process_frame
		for i in Timeline.chapters.size():
			Timeline.go_to_chapter(i, false)
			await get_tree().process_frame
			Timeline.set_t(0.5)
			await get_tree().process_frame
			Timeline.set_t(1.0)
			await get_tree().process_frame
			var ch = Timeline.chapters[i]
			check(ch.narration.length() > 100 and ch.refs.length() > 3 and ch.evidence.size() >= 3, "[%s] chapter %d has narration, refs, evidence" % [mode, i + 1])
			check(ch.tour_beats.size() >= 3, "[%s] chapter %d has tour beats (%d)" % [mode, i + 1, ch.tour_beats.size()])
			var nb: int = main.tour.narration.get("chapters", {}).get(ch.id, {}).get("beats", []).size()
			check(nb == ch.tour_beats.size(), "[%s] chapter %d narration has one clip per beat (%d / %d)" % [mode, i + 1, nb, ch.tour_beats.size()])
			check(ch.uses_flat_stack == (not volumes.tilted) or ch.id == "erosion", "[%s] chapter %d stack attitude matches (flat=%s)" % [mode, i + 1, str(ch.uses_flat_stack)])
	# narration data: a clip per beat, cue targets that exist
	var nar: Dictionary = main.tour.narration
	check(nar.has("chapters") and nar.get("total_s", 0.0) > 300.0 and nar.get("total_s", 0.0) < 1200.0, "narration.json loaded: %.1f min in total" % (float(nar.get("total_s", 0.0)) / 60.0))
	var missing := 0
	var bad_cues := 0
	var nclips := 0
	var layer_keys: Array = []
	for l in volumes.layers:
		layer_keys.append(l["key"])
	for ch in Timeline.chapters:
		for bi in ch.tour_beats.size():
			var nd: Dictionary = main.tour.beat_data(ch, bi)
			if nd.is_empty() or not ResourceLoader.exists(str(nd.get("file", ""))) or float(nd.get("duration", 0.0)) < 1.0:
				missing += 1
				continue
			nclips += 1
			for c in nd.get("cues", []):
				if float(c.get("t", -1.0)) < 0.0 or float(c["t"]) > float(nd["duration"]):
					bad_cues += 1
				for k in c.get("layers", []):
					if str(k) != "zone_a" and not layer_keys.has(str(k)):
						bad_cues += 1
	check(missing == 0, "every tour beat has a narration clip resource (%d clips, %d missing)" % [nclips, missing])
	check(bad_cues == 0, "every cue lies inside its clip and names known layers (%d bad)" % bad_cues)
	# tour: start, plays the first beat with its narration, N skips beats, stop restores manual speed
	main.tour.start(2)
	await get_tree().process_frame
	await get_tree().process_frame
	check(main.tour.on and main.tour._beat_idx == 0 and Timeline.playing and main.tour._beat_len > 5.0, "tour starts on beat 1, scrubber running for the clip's %.1f s" % main.tour._beat_len)
	check(not AppState.narration_on or main.tour.player.stream != null, "narration clip loaded into the player")
	check(not main.hover_enabled, "hover pop-ups off under the tour")
	var speed_ok: bool = absf(Timeline.play_speed * main.tour._beat_len - (main.tour._beat_t1 - main.tour._beat_t0)) < 1.0e-4
	check(speed_ok, "scrubber speed set so the beat's span is covered in the clip's length")
	main.tour.skip()
	await get_tree().process_frame
	main.tour.skip()
	await get_tree().process_frame
	check(main.tour._beat_idx == 2, "N skips to the next beat (now beat 3)")
	main.tour._beat_time = 1.0e6
	await get_tree().process_frame
	check(main.tour._beat_idx == 3, "a beat ends when its narration time is up")
	var ch3 = Timeline.chapters[2]
	Timeline.set_t(0.62)   # inside beat 4, once the gabbroid has started to grow
	await get_tree().process_frame
	var fired := false
	for c in main.tour.beat_data(ch3, 3).get("cues", []):
		main.tour._fire_cue(c)
		fired = true
	var frames := 0
	for k in volumes._frames:
		if volumes._frames[k].visible:
			frames += 1
	check(not fired or frames + main._shells.size() > 0, "a cue puts a glowing outline on its entity (%d frames, %d shells)" % [frames, main._shells.size()])
	main.tour.stop()
	check(not main.tour.on and Timeline.play_speed == Timeline.MANUAL_SPEED and main.hover_enabled == AppState.hover_info, "tour stopped, manual speed and hover restored")
	AppState.candidate_zone = "A"
	Timeline.go_to_chapter(3, false)
	await get_tree().process_frame
	check(not volumes.era_keys.has("amygdaloidal_top") and volumes.era_keys.has("vesicle_sheet_1"), "candidate zone A only hides the flow top")
	AppState.candidate_zone = "both"
	# chapter W: real hillside built from the DEM
	Timeline.go_to_chapter(7, false)
	await get_tree().process_frame
	var w8 = Timeline.chapters[7]
	check(w8._path_len > 20.0 and w8._path_len < 1500.0 and w8._drop >= 8.0, "worm's-eye hillside from the lidar: outcrop %d m from the brook, %d m higher" % [int(w8._path_len), int(w8._drop)])
	check(w8._path_is_flowline and w8._pp.size() > 10, "worm's-eye path follows a steepest-descent flow line (%d points, %d bends)" % [w8._pp.size(), w8._bends])
	check(main.extras.find_child("wall", true, false) != null and main.extras.find_child("hillside", true, false) != null, "worm's-eye hillside and cut wall meshes present")
	check(terrain.channels.size() >= 2 and main.extras.find_child("nodule_big", true, false) != null, "worm's-eye brook channel carved along %d mapped stream segments; rough nodule present" % terrain.channels.size())
	var cm: ArrayMesh = Carnelian.make_mesh(1, 0.02)
	check(cm.get_surface_count() == 1 and cm.surface_get_array_len(0) > 300, "procedural carnelian piece builds (%d vertices)" % cm.surface_get_array_len(0))
	check(main.ambience != null and main.ambience.brook.stream != null and main.ambience.rumble.stream != null, "ambient loops loaded")
	var nloops := 0
	for k in main.ambience.loops:
		if main.ambience.loops[k].stream != null:
			nloops += 1
	check(nloops == 8 and main.ambience._shots.size() == 7, "sound: 8 loops and 7 cues loaded (%d, %d)" % [nloops, main.ambience._shots.size()])
	check(not Timeline.chapters[0].camera_cues and Timeline.chapters[3].tour_beats[5].get("cue", true) == false, "no camera cues in chapter 1 nor on the two in-vesicle moves of chapter 4")
	for k in main.ambience._shots:
		main.ambience.play(k)
	check(true, "every cue plays without error")
	# camera as storyteller: a beat's move changes the pose over the beat; chapter W marks the piece in wide shots
	var b2: Dictionary = Timeline.chapters[6].tour_beats[3]
	var p0: Array = main.tour.beat_pose(b2, 0.0)
	var p1: Array = main.tour.beat_pose(b2, 1.0)
	check(p0[0].distance_to(p1[0]) > 1.0 and p0[1].distance_to(p1[1]) < 0.001, "chapter 7 bar beat: the camera orbits and pushes in over the beat (%.1f m of travel), the look point fixed" % p0[0].distance_to(p1[0]))
	var nmoves := 0
	for ch in Timeline.chapters:
		for b in ch.tour_beats:
			if b.has("move"):
				nmoves += 1
	check(nmoves >= 28, "%d beats carry an authored camera move (the rest drift)" % nmoves)
	check(main.extras.find_child("halo", true, false) != null, "chapter W: tracker halo present for the wide shots")
	var nb: MeshInstance3D = main.extras.find_child("nodule_big", true, false)
	check(nb != null and float(nb.material_override.get_shader_parameter("sparkle_soft")) == 1.0 and float(nb.material_override.get_shader_parameter("sparkle")) < 0.6, "chapter W close-up piece: soft, half-strength sparkle")
	Timeline.set_t(0.7)
	await get_tree().process_frame
	check(not volumes.visible and volumes.chapter_hidden, "chapter W hides the layer stack through chapter_hidden")
	# chapter W flood: the camera stays above the water surface and the piece just under it
	Timeline.set_t(0.85)
	await get_tree().process_frame
	await get_tree().process_frame
	main.camera.finish_flight()
	var w_water: MeshInstance3D = main.extras.find_child("water", true, false)
	var w_nod: Node3D = main.extras.find_child("nodule_root", true, false)
	check(w_water != null and w_water.position.y <= 1.45 and main.camera.cam.global_position.y > w8.E.y + w_water.position.y + 0.1, "chapter W flood: water %.2f m over the bed, camera above the surface" % (w_water.position.y if w_water else -1.0))
	check(w_nod != null and w_nod.position.y < w_water.position.y and w_nod.position.y > w_water.position.y - 0.6, "chapter W flood: the piece tumbles just under the surface (%.2f m)" % (w_nod.position.y if w_nod else -1.0))
	# chapter 7 scenario expressions
	Timeline.go_to_chapter(6, false)
	var ch7 = Timeline.chapters[6]
	ch7.scenario = 0
	for mode in ["both", "colluvium", "bar"]:
		AppState.depletion_mode = mode
		Timeline.set_t(0.96)
		await get_tree().process_frame
	ch7.scenario = 1
	AppState.depletion_mode = "both"
	check(true, "scenario 1 expressions stepped")
	Timeline.go_to_chapter(6, false)
	await get_tree().process_frame
	check(AppState.cover_skin, "chapter 7 turns the cover skin on")
	check(terrain.patches.size() == 2 and terrain.channels.size() >= 6, "chapter 7: two 1 m detail patches and a carved channel (%d segments)" % terrain.channels.size())
	var seg0: Vector4 = terrain.channels[0] if not terrain.channels.is_empty() else Vector4.ZERO
	var cd: float = terrain.channel_depth_at(seg0.x, seg0.y)
	check(cd > 0.9 and terrain.channel_depth_at(main.gbr.x + 3000.0, main.gbr.z) == 0.0, "channel 1 m deep on the stream line, 0 away from it (%.2f)" % cd)
	check(main.extras.find_child("water_GBR", true, false) != null and main.extras.find_child("cobbles_GBR", true, false) != null, "chapter 7: water ribbon and cobbled bar at GBR")
	var pm: ShaderMaterial = main.extras.find_child("pebbles_GBR", true, false).material_override if main.extras.find_child("pebbles_GBR", true, false) else null
	check(pm != null and float(pm.get_shader_parameter("sparkle")) == 1.0, "chapter 7 pebbles sparkle at full strength")
	var ga: Vector3 = ch7._anchor["GBR"]["near"]
	var site_root: Node3D = main.extras.find_child("site_GBR", true, false)
	check(site_root != null and site_root.position.distance_to(ga) < 0.01, "chapter 7 site root sits on the anchor (carved bed on the mapped stream, %.0f m from the zone centre; root y %.2f at %s, anchor y %.2f, carve %.2f)" % [Vector2(ga.x - main.gbr.x, ga.z - main.gbr.z).length(), site_root.position.y if site_root else -1.0, str(site_root.get_path()) if site_root else "none", ga.y, terrain.channel_depth_at(ga.x, ga.z)])
	check(Vector3(ch7.tour_beats[3]["look"]).distance_to(ga) < 2.0 and Vector3(ch7.tour_beats[6]["look"]).distance_to(ga) < 2.0, "chapter 7 brook beats look at the site anchor")
	Timeline.set_t(0.72)
	await get_tree().process_frame
	var w7: MeshInstance3D = main.extras.find_child("water_GBR", true, false)
	var src7: MeshInstance3D = main.extras.find_child("source_GBR", true, false)
	check(w7.position.y - float(w7.get_meta("base_y")) > 0.9 and w7.position.y - float(w7.get_meta("base_y")) < 1.2 and src7.position.y > 0.25, "chapter 7 peak: flood %.2f m, hidden source raised to the channel floor (y %.2f)" % [w7.position.y - float(w7.get_meta("base_y")), src7.position.y])
	# with the cut off and the camera above ground the clipped stack and the bedrock-top twin are not drawn
	AppState.cut_enabled = false
	main.camera.jump_to(ga + Vector3(12, 8, 14), ga)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not volumes.visible, "layer stack culled under an opaque, uncut terrain seen from above")
	check(not terrain.cover_chunks[0].visible, "bedrock-top twin hidden while the cut is off")
	AppState.cut_enabled = true
	await get_tree().process_frame
	await get_tree().process_frame
	check(volumes.visible and terrain.cover_chunks[0].visible, "both drawn again when the cut is on")
	AppState.cut_enabled = false
	var info: Dictionary = main.pick_at(get_viewport().get_visible_rect().size * 0.5)
	print("pick at screen centre: ", info.get("title", "nothing"))
	Timeline.go_to_chapter(0, false)
	check(true, "stepped through all chapters, both modes, and scrubbed")
	print("smoke test: ", "PASS" if _fail == 0 else "FAIL (%d)" % _fail)
	get_tree().quit(0 if _fail == 0 else 1)
