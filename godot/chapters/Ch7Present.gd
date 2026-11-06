extends Chapter
## Chapter 7 (deep): glaciation and the present day; the cover skin; the flood scrubber; the two scenarios.
## Source: section 4.1, 4.2, 6, Fig. 3d-f; OFM 69 (limits M1/M2, unit thickness maxima).

var scenario := 1          # 0 = source used up (colluvial supply thins), 1 = floods keep replenishing (paper favours 1)
var _pebbles := {}
var _bars := {}
var _water := {}
var _water_mats := {}
var _labels: Array = []
var _cover_label: Label3D
var _trace: Node3D
var _rng := RandomNumberGenerator.new()
var _cut_normal := Vector3(0.65, 0.0, -0.76).normalized()
var _source := {}
var _bar_root := {}        # site -> Node3D holding the bar (so the pebbles can be seated on it)
var _flow := {}            # site -> flow direction (radians) along the channel
var _mode_by_us := true    # the chapter drives the colour mode unless the user picked one in this chapter
var _anchor := {}          # site -> {near: Vector3 (carved bed on the mapped stream), fdir: float}


func _init() -> void:
	id = "present"
	title = "7. Glaciation and the present day"
	short_title = "7"
	narration = "Ice reached the area twice. The early Pleistocene (pre-Illinoian) advance stopped at limit M1 of the Chatham surficial map: it left [till] in the headwaters of Green Brook's northeastern tributary, but Stirling Brook lies 2 km south of that limit with no [erratic]s, and the southwestern tributary where GBR sits drains unglaciated ground; the late Wisconsinan [terminal moraine] (limit M2) and glacial Lake Passaic lie farther north. Today weathered basalt and [colluvium] up to 18 m, and [alluvium] up to 3 m, mantle the slopes (the cover skin shows a modelled thickness); gravel bars of Preakness basalt and gabbroid rest on gabbroid stream-bed pavement and hold carnelian pebbles 1.0-5.5 cm across. The scrubber runs one flood: water rises, scours the alluvium off hidden bedrock, and delivers fresh pebbles, or not, depending on which of the paper's two scenarios you pick."
	basic_narration = "Glaciers came close but never covered the carnelian brooks (the dashed lines are the two ice limits from the Chatham map). Today a skin of weathered basalt, colluvium (up to 18 m) and stream alluvium (up to 3 m) hides the bedrock. In the second half, one flood scours the gravel bar at Green Brook: either fresh carnelian is delivered from a hidden source (the paper's preference) or the supply is running out."
	refs = "section 4.1, 4.2, 6; Fig. 3d-f; OFM 69 (Figure 1 limits; unit descriptions)"
	strip_from = 2.0e6
	strip_to = 0.0
	scrub_label = "Glacial limits overlay -> present day (cover skin) -> one flood event (hours)"
	scrub_units = "first half: glacial history (overlay); second half: one flood, illustrative hours"
	scrub_marks = [[0.0, "Early Pleistocene (pre-Illinoian) glacial limit M1"], [0.2, "Late Wisconsinan limit M2: terminal moraine, glacial Lake Passaic"], [0.4, "Present: colluvium, alluvium, gravel bars (cover skin)"], [0.55, "Flood rising"], [0.7, "Peak: alluvium scoured, bedrock source exposed"], [0.85, "Receding: fresh pebbles in the bars"], [1.0, "After the flood"]]
	evidence = [
		{"text": "Sites lie south of the Wisconsinan terminal moraine and outside glacial lake basins.", "ref": "section 4.1"},
		{"text": "SGB is south of the early Pleistocene glacial limit; no erratics in its basin. On OFM 69 Figure 1 the limit (M1) passes about 2 km north of the SGB zone and within 200 m of the GBR zone centre.", "ref": "section 4.1; OFM 69 Figure 1 (digitised, +/-200 m)"},
		{"text": "Headwaters of Green Brook's NE tributary are inside that limit (till occurs there) but no carnelian is in the till; the SW tributary (GBR) drains unglaciated terrain with no erratics.", "ref": "section 4.1 [35]"},
		{"text": "Pre-Illinoian till occurs as erosional remnants in upland valleys on Second Watchung Mountain; its distribution, and its absence to the south and west, fix the limit M1. The deposits are older than 788 ka and probably Pliocene.", "ref": "OFM 69 text (read)"},
		{"text": "Veneer of weathered basalt and colluvium up to 18 m (angular-subangular basalt pebbles/cobbles in clayey silt-sand); up to 3 m alluvium on footslopes and floodplains. OFM 69: blocky basalt colluvium 'as much as 60 ft'; weathered basalt generally < 10 ft over fractured rock to 60 ft; alluvium as much as 15 ft; talus along Green Brook south of Seelys Pond as much as 15 ft.", "ref": "section 4.1 [35]; OFM 69 unit descriptions (read)"},
		{"text": "Thick colluvium has deeply weathered interiors under a fresh-clast surface layer: repeated deposition during glacial periods, weathering during interglacials.", "ref": "OFM 69 (read)"},
		{"text": "Carnelian mainly in fluvial gravel bars on gabbroid pavement; bars are entirely Preakness basalt and gabbroid; at Stirling Brook also in fine alluvium and slope wash on a terrace.", "ref": "section 4.1, Fig. 3d-f"},
		{"text": "Pebbles 1.0-5.5 cm, subangular to subrounded (medium to very coarse pebble gravel).", "ref": "section 4.3, Fig. 4a"},
		{"text": "Two scenarios for no carnelian in outcrop: (1) the bedrock source is largely eroded away, what remains is in the gravels; (2) carnelian is still being eroded from a source now hidden under stream-bed alluvium and is replenished during erosive floods. The paper prefers (2) because finds continue after decades of collecting. Scenario 1 can be expressed three ways here (colluvial store thinning, bar stock dwindling, or both); all are Illustrative.", "ref": "section 4.2"},
	]
	tiers = {"Observed": "Mapped till, moraine, lake deposits, colluvium, alluvium (OFM 69 extents and maxima); the limit lines M1/M2 as published; stream channels (NHD); pebble sizes; gravel composition.",
		"Inferred": "That the carnelian is locally derived and not glacial; scenario 2 preferred.",
		"Illustrative": "The cover-thickness taper inside each polygon, the flood hydrograph, pebble counts and positions, the hidden-source outline, the colluvial-supply decline in scenario 1."}
	charts = []
	key_items = [
		{"name": "Bedrock top under the cover (cover skin, hatched)", "color": Color(0.5, 0.5, 0.5), "tier": "illustrative"},
		{"name": "Carnelian horizon trace (zone A sheets at today's surface)", "color": Color(1.0, 0.3, 0.1), "tier": "inferred", "shape": "line"},
		{"name": "Carnelian pebbles in the gravel bar (1-5.5 cm, drawn larger)", "color": Color(0.85, 0.15, 0.06), "tier": "observed"},
		{"name": "Flood water (cosmetic ripples; level and turbidity Illustrative)", "color": Color(0.3, 0.45, 0.6), "tier": "illustrative"},
	]


func enter(main: Node, animate: bool) -> void:
	var g: Vector3 = main.gbr
	var gy: float = main.terrain.height_at(g.x, g.z)
	start_pos = Vector3(-800, 3600, 5200)
	start_look = Vector3(-800, 80, -600)
	# the brook (polish pass): carve the channel along the mapped stream near both sites and draw the ground there
	# on fine 1 m patches so the channel, the bar and the water sit in a real valley floor
	var segs: Array = []
	for c in [g, main.sgb]:
		var ss: Array = stream_segments(main, c, 110.0)
		while ss.size() > 30:   # the shader holds 64 segments for both sites
			var half: Array = []
			for i in range(0, ss.size() - 1, 2):
				half.append(Vector4(ss[i].x, ss[i].y, ss[i + 1].z, ss[i + 1].w))
			ss = half
		segs.append_array(ss)
	main.terrain.set_channels(segs)
	main.terrain.clear_detail_patches()   # re-entering the chapter must not stack patches
	main.terrain.add_detail_patch(g, 70.0)
	main.terrain.add_detail_patch(main.sgb, 70.0)
	# the brook views look at the site anchor: the carved bed on the mapped stream nearest the zone centre (the
	# bar, pavement, source and water are built there; the zone centre itself may be up the valley side)
	_anchor["GBR"] = site_anchor(main, g)
	_anchor["SGB"] = site_anchor(main, main.sgb)
	var ga: Vector3 = _anchor["GBR"]["near"]
	var sa: Vector3 = _anchor["SGB"]["near"]
	scale_views = [
		{"name": "landscape", "pos": Vector3(-800, 3600, 5200), "look": Vector3(-800, 80, -600), "t": 0.2},
		{"name": "brook_gbr", "pos": ga + Vector3(11, 7, 13), "look": ga + Vector3(0, 1.2, 0), "t": 0.45},
		{"name": "flood_peak", "pos": ga + Vector3(11, 7, 13), "look": ga + Vector3(0, 1.2, 0), "t": 0.7},
		{"name": "brook_sgb", "pos": sa + Vector3(11, 7, 13), "look": sa + Vector3(0, 1.2, 0), "t": 1.0},
	]
	var zone_a: Array = main.volumes.zone_a_keys()
	tour_beats = [
		beat(0.0, "Early Pleistocene: ice stops at limit M1 (dashed). Its till survives in the NE Green Brook headwaters; Stirling Brook lies 2 km south of it.", Vector3(-300, 3400, 4600), Vector3(-300, 80, -900), [], {"move": {"orbit": 15.0, "dolly": [1.1, 0.9]}}),
		beat(0.2, "Late Wisconsinan: the terminal moraine and glacial Lake Passaic (limit M2) stay well north of both brooks.", Vector3(-2500, 3000, 3000), Vector3(-2500, 80, -2500)),
		beat(0.4, "Today at Green Brook: the cut face shows the cover skin (colluvium up to 18 m, alluvium up to 3 m) over the bedrock top; the carnelian horizon trace runs along the valley sides.", Vector3(g.x, gy - 12.0, g.z) + _cut_normal * 240.0 + Vector3(0, 40, 0), Vector3(g.x, gy - 12.0, g.z), zone_a, {"cut": true, "move": {"dolly": [1.3, 0.9], "orbit": 15.0}}),
		beat(0.5, "The gravel bar on gabbroid pavement: basalt and gabbroid cobbles with carnelian pebbles 1-5.5 cm (drawn larger).", ga + Vector3(11, 7, 13), ga + Vector3(0, 1.2, 0), [], {"cut": false, "move": {"orbit": 45.0, "dolly": [1.4, 0.8]}}),
		beat(0.55, "A flood rises: muddy water covers the bar.", ga + Vector3(14, 9, 16), ga + Vector3(0, 1.5, 0), [], {"move": {"rise": 6.0, "orbit": 25.0}}),
		beat(0.7, "Peak flow scours the alluvium off the bed and exposes the hidden bedrock source (scenario 2).", ga + Vector3(12, 8, 14), ga + Vector3(0, 1.2, 0), [], {"move": {"dolly": [1.2, 0.7], "orbit": -30.0}}),
		beat(0.85, "As the water drops, fresh pebbles are left in the bar, or not: choose the scenario under the narration.", ga + Vector3(10, 6, 12), ga + Vector3(0, 1.0, 0), [], {"move": {"dolly": [1.3, 0.55]}}),
		beat(0.98, "After the flood. The paper prefers replenishment: finds continue after decades of collecting.", ga + Vector3(16, 10, 18), ga + Vector3(0, 1.2, 0), [], {"move": {"dolly": [0.6, 1.8], "rise": 12.0, "orbit": 20.0}}),
	]
	super.enter(main, animate)
	main.clear_extras()
	AppState.color_mode = 1
	_mode_by_us = true
	AppState.cover_skin = true
	AppState.cut_plane = Plane(_cut_normal, _cut_normal.dot(g))
	for k in ["glacial", "glacial_limits", "streams", "sites", "mindat"]:
		if main.features.groups.has(k):
			main.features.groups[k].visible = AppState.is_layer_visible(k)
	_rng.seed = 21
	for site in ["GBR", "SGB"]:
		var c: Vector3 = g if site == "GBR" else main.sgb
		_build_site(main, site, c)
	_build_trace(main)
	_labels = [
		main.make_label("Early Pleistocene (pre-Illinoian) till: inside limit M1  [Observed polygons; M1 from OFM 69 fig. 1]", Vector3(1200, 0, -4300), AppState.TIER_COLORS["observed"], 60, 1.0),
		main.make_label("Late Wisconsinan terminal moraine (Rahway till) and glacial Lake Passaic deposits; limit M2  [Observed]", Vector3(-3500, 0, -5000), AppState.TIER_COLORS["observed"], 60, 1.0),
		main.make_label("SGB: 2 km south of limit M1, no erratics  [Observed]", main.sgb, AppState.TIER_COLORS["observed"], 54, 0.9),
		main.make_label("GBR: southwestern tributary, unglaciated terrain  [Observed]", g, AppState.TIER_COLORS["observed"], 54, 0.9),
		main.make_label("NE tributary headwaters: inside limit M1, till present, no carnelian reported  [Observed]", Vector3(1300, 0, -2600), AppState.TIER_COLORS["observed"], 54, 0.9),
	]
	for l in _labels:
		l.position.y = main.terrain.height_at(l.position.x, l.position.z) + 150.0
	_cover_label = main.make_label("", g + Vector3(60, 40, -40), Color(1.0, 0.9, 0.7), 40, 0.3)


func _build_trace(main: Node) -> void:
	var g: Vector3 = main.gbr
	var tr: Array = load("res://chapters/Ch6Erosion.gd").build_trace(main, g, 700.0, 1.6)
	_trace = tr[0]
	main.make_label("Carnelian horizon (six zone A sheets) at today's surface, under the cover  [Inferred horizon, Illustrative trace]", g + Vector3(0, 120, 0), Color(1.0, 0.45, 0.2), 48, 0.6)


## The mapped stream (NHD flowline) nearest `c`, as channel segments (world xz pairs) within `radius`.
static func stream_segments(main: Node, c: Vector3, radius: float) -> Array:
	var pts: PackedVector3Array = stream_points(main, c, radius)
	var out: Array = []
	for i in range(1, pts.size()):
		out.append(Vector4(pts[i - 1].x, pts[i - 1].z, pts[i].x, pts[i].z))
	return out


## Points of the single flowline that passes nearest `c`, within `radius` of it, in order along the line.
static func stream_points(main: Node, c: Vector3, radius: float) -> PackedVector3Array:
	var grp: Node = main.features.groups.get("streams", null)
	var best_item: Dictionary = {}
	var best_d := 1.0e9
	if grp != null and grp.has_meta("pick"):
		for item in grp.get_meta("pick"):
			for q in item["pts"]:
				var d := Vector2(q.x - c.x, q.z - c.z).length()
				if d < best_d:
					best_d = d
					best_item = item
	var out := PackedVector3Array()
	if best_item.is_empty():
		return out
	for q in best_item["pts"]:
		if Vector2(q.x - c.x, q.z - c.z).length() <= radius:
			out.append(q)
	return out


## The site anchor: the mapped-stream vertex nearest `c` at the carved bed level, and the flow direction there
## (radians, downhill along the line). The bar, pavement, source, water and the brook camera views use it.
static func site_anchor(main: Node, c: Vector3) -> Dictionary:
	var ter: Node = main.terrain
	var line: PackedVector3Array = stream_points(main, c, 110.0)
	var near := Vector3(c.x, 0.0, c.z)
	var fdir := 0.6
	if line.size() >= 2:
		var bi := 0
		var bd := 1.0e9
		for i in line.size():
			var d := Vector2(line[i].x - c.x, line[i].z - c.z).length()
			if d < bd:
				bd = d
				bi = i
		near = line[bi]
		var i0 := maxi(bi - 2, 0)
		var i1 := mini(bi + 2, line.size() - 1)
		var dv := Vector2(line[i1].x - line[i0].x, line[i1].z - line[i0].z)
		if ter.height_at(line[i1].x, line[i1].z) > ter.height_at(line[i0].x, line[i0].z):
			dv = -dv   # water runs downhill
		fdir = atan2(dv.y, dv.x)
	near.y = ter.height_at(near.x, near.z)   # carved channel floor
	return {"near": near, "fdir": fdir, "line": line}


func _build_site(main: Node, site: String, c: Vector3) -> void:
	var ter: Node = main.terrain
	var an: Dictionary = _anchor[site] if _anchor.has(site) else site_anchor(main, c)
	var line: PackedVector3Array = an["line"]
	var near: Vector3 = an["near"]
	var fdir: float = an["fdir"]
	_flow[site] = fdir
	var bed: float = near.y
	var root := Node3D.new()
	root.name = "site_" + site
	root.position = Vector3(near.x, bed, near.z)
	main.extras.add_child(root)
	var along := Vector3(cos(fdir), 0.0, sin(fdir))
	var across := Vector3(-along.z, 0.0, along.x)
	# gravel bar: a sloping lens on the inside of the channel, half under water, cobbles seated on it
	var bar_root := Node3D.new()
	bar_root.name = "bar_" + site
	bar_root.position = across * 2.2 + along * 6.0 + Vector3(0, 0.15, 0)
	bar_root.rotation.y = -fdir
	root.add_child(bar_root)
	_bar_root[site] = bar_root
	var bar := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 6.0
	bm.height = 1.5
	bar.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.46, 0.45, 0.44)
	bmat.roughness = 1.0
	bar.material_override = bmat
	bar.scale = Vector3(1.0, 1.0, 0.6)
	bar_root.add_child(bar)
	_bars[site] = bar
	# cobbles of basalt and gabbroid on the bar (grey rough pieces, 10-30 cm)
	var cob := MultiMeshInstance3D.new()
	cob.name = "cobbles_" + site
	var cmm := MultiMesh.new()
	cmm.transform_format = MultiMesh.TRANSFORM_3D
	cmm.mesh = Carnelian.make_mesh(31, 0.5, 3, 1.0)
	cmm.instance_count = 90
	for i in cmm.instance_count:
		var ang := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 5.6
		var px := cos(ang) * r
		var pz := sin(ang) * r * 0.6
		var sc := 0.1 + _rng.randf() * 0.2
		var y := _bar_height(px, pz) + sc * 0.3
		var b := Basis.from_euler(Vector3(_rng.randf() * 3.0, _rng.randf() * 3.0, 0.0)).scaled(Vector3(sc, sc * 0.7, sc * 0.85))
		cmm.set_instance_transform(i, Transform3D(b, Vector3(px, y, pz)))
	cob.multimesh = cmm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.36, 0.37, 0.39)
	cmat.roughness = 0.95
	cob.material_override = cmat
	bar_root.add_child(cob)
	# gabbroid pavement: the channel floor
	var pav := MeshInstance3D.new()
	pav.name = "pavement_" + site
	var pm := BoxMesh.new()
	pm.size = Vector3(30, 0.3, 7)
	pav.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.44, 0.45, 0.46)
	pmat.roughness = 0.9
	pav.material_override = pmat
	pav.position = Vector3(0, -0.1, 0)
	pav.rotation.y = -fdir
	root.add_child(pav)
	var src := MeshInstance3D.new()
	src.name = "source_" + site
	_source[site] = src
	var sm := BoxMesh.new()
	sm.size = Vector3(10, 1.0, 6)
	src.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.85, 0.2, 0.1, 0.25)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	src.material_override = smat
	src.position = Vector3(6, -1.0, 2)
	root.add_child(src)
	main.make_label("Hidden bedrock source under stream-bed alluvium\n(scenario 2, Illustrative outline)", root.position + Vector3(6, 3.0, 2), AppState.TIER_COLORS["illustrative"], 36, 0.08)
	# carnelian pebbles seated on the bar: rough pieces (polish pass), 1-5.5 cm true size, drawn larger
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "pebbles_" + site
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Carnelian.make_mesh(5, 1.0, 4, 1.0)
	mm.instance_count = 60
	for i in mm.instance_count:
		mm.set_instance_transform(i, _pebble_xform(i))
	mmi.multimesh = mm
	mmi.material_override = Carnelian.material(5, 1.0, 1.0)   # sparkling: seen en masse (round 8)
	bar_root.add_child(mmi)
	_pebbles[site] = mmi
	# water: a ribbon along the mapped stream at the channel level; the depth test against the fine patch does
	# the flooding (where the level rises above the banks the water shows there)
	var water := MeshInstance3D.new()
	water.name = "water_" + site
	water.mesh = _ribbon_mesh(line, 22.0)
	var wmat := ShaderMaterial.new()
	wmat.shader = load("res://shaders/water.gdshader")
	wmat.set_shader_parameter("noise_tex", preload("res://scripts/NoiseTex.gd").get_texture())
	wmat.set_shader_parameter("ripple_scale", 1.2)
	wmat.set_shader_parameter("flow_dir", fdir)
	wmat.set_shader_parameter("depth_scale", 1.0)
	wmat.set_shader_parameter("foam_width", 0.3)
	water.material_override = wmat
	water.custom_aabb = AABB(Vector3(-200, -20, -200), Vector3(400, 40, 400))
	root.add_child(water)
	var cen := Vector3.ZERO
	for p in line:
		cen += p
	cen /= maxf(line.size(), 1.0)
	water.position = Vector3(cen.x - near.x, 0.45, cen.z - near.z)
	water.set_meta("base_y", 0.45)
	_water[site] = water
	_water_mats[site] = wmat
	main.make_label("%s gravel bar on gabbroid pavement: basalt + gabbroid cobbles, carnelian pebbles 1.0-5.5 cm (Observed)" % site, root.position + Vector3(-4, 4.5, -6), AppState.TIER_COLORS["observed"], 36, 0.08)
	if site == "SGB":
		var terrace := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(30, 1.5, 12)
		terrace.mesh = tm
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(0.86, 0.78, 0.6)
		terrace.material_override = tmat
		terrace.position = Vector3(-10, 1.2, 14)
		root.add_child(terrace)
		main.make_label("Stirling Brook: carnelian also in fine alluvium and slope wash on a terrace (Observed, Fig. 3f)", root.position + Vector3(-10, 5, 14), AppState.TIER_COLORS["observed"], 36, 0.08)


## Height of the bar's upper surface at bar-local x, z (the lens is a squashed sphere r 6 x 0.75 x 3.6).
static func _bar_height(px: float, pz: float) -> float:
	var q := 1.0 - (px * px) / 36.0 - (pz * pz) / 12.96
	return 0.75 * sqrt(maxf(q, 0.0))


func _pebble_xform(i: int) -> Transform3D:
	var ang := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * 5.0
	var px := cos(ang) * r
	var pz := sin(ang) * r * 0.6
	var s := 0.03 + _rng.randf() * 0.05   # drawn 3-8 cm (true 1-5.5 cm) so they read beside the cobbles
	var b := Basis.from_euler(Vector3(_rng.randf() * 3.0, _rng.randf() * 3.0, 0.0)).scaled(Vector3(s, s * 0.75, s * 0.85))
	return Transform3D(b, Vector3(px, _bar_height(px, pz) + s * 0.45, pz))


## A flat ribbon of `width` m along a polyline (world points), with the vertices at y = 0 (the node sets the level).
static func _ribbon_mesh(line: PackedVector3Array, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3.ZERO
	for p in line:
		c += p
	c /= maxf(line.size(), 1.0)
	for i in range(1, line.size()):
		var a := Vector3(line[i - 1].x - c.x, 0.0, line[i - 1].z - c.z)
		var b := Vector3(line[i].x - c.x, 0.0, line[i].z - c.z)
		var d := b - a
		if d.length() < 0.01:
			continue
		var side := Vector3(-d.z, 0.0, d.x).normalized() * (width * 0.5)
		var ext := d.normalized() * 2.0
		var p1 := a - ext + side
		var p2 := a - ext - side
		var p3 := b + ext - side
		var p4 := b + ext + side
		for q in [p1, p2, p3, p1, p3, p4]:
			st.set_normal(Vector3.UP)
			st.add_vertex(q)
	var mesh := st.commit()
	return mesh


func set_t(t: float, main: Node) -> void:
	var f: Node3D = main.features
	if f.groups.has("glacial"):
		f.groups["glacial"].visible = AppState.is_layer_visible("glacial") and t < 0.4
	var want_mode := 1 if t < 0.4 else 3   # surficial colours for the glacial story, the natural look for today
	if AppState.color_mode != want_mode and _mode_by_us:
		AppState.color_mode = want_mode
	for i in _labels.size():
		_labels[i].visible = t < 0.4 if i < 2 else true
	var rise := ramp(t, 0.5, 0.7) * (1.0 - ramp(t, 0.7, 0.95))
	main.ambience.set_levels((0.35 + 0.65 * rise) if t >= 0.4 else 0.0, 0.0)
	main.ambience.set_level("rush", rise)
	# the rings around the zone centres are hidden in the brook close-ups (the camera stands inside them)
	for k in ["sites", "mindat"]:
		if f.groups.has(k):
			f.groups[k].visible = AppState.is_layer_visible(k) and t < 0.45
	for site in _water:
		var w: MeshInstance3D = _water[site]
		w.position.y = float(w.get_meta("base_y", 0.45)) + rise * 1.1   # Illustrative flood: 1.1 m over the brook
		w.visible = t >= 0.4
		_water_mats[site].set_shader_parameter("turbidity", 0.6 * rise)   # muddy but still see-through
		_water_mats[site].set_shader_parameter("speed", 1.0 + 3.0 * rise)
		var bar: MeshInstance3D = _bars[site]
		bar.scale.y = 1.0 - 0.6 * ramp(t, 0.6, 0.72) + 0.6 * ramp(t, 0.78, 0.95)
		var mmi: MultiMeshInstance3D = _pebbles[site]
		var n_before := 30
		var n := n_before
		var mode := AppState.depletion_mode
		if scenario == 0 and mode != "colluvium":
			n = int(round(lerpf(n_before, 22, ramp(t, 0.78, 0.95))))   # some carried off downstream, none replaced
		elif scenario == 0:
			n = int(round(lerpf(n_before, 36, ramp(t, 0.78, 0.95))))   # a thinning colluvial store still delivers a little
		else:
			n = int(round(lerpf(n_before, 60, ramp(t, 0.78, 0.95))))
		mmi.multimesh.visible_instance_count = n
		mmi.visible = t >= 0.4
		if _source.has(site):
			# the hidden bedrock source is scenario 2's idea; under scenario 1 it fades out. At the peak the scour
			# "exposes" it: the outline rises through the bed to the channel floor (Illustrative)
			var expose := ramp(t, 0.62, 0.72) * (1.0 - ramp(t, 0.85, 0.95))
			var srcn: MeshInstance3D = _source[site]
			srcn.position.y = lerpf(-1.0, 0.3, expose)
			var sm: StandardMaterial3D = srcn.material_override
			sm.albedo_color.a = (0.25 + 0.3 * expose) if scenario == 1 else 0.25 * (1.0 - ramp(t, 0.5, 0.7))
	# scenario 1: the colluvial supply around GBR thins with the flood (Illustrative decline of an Observed maximum)
	var cov: float = main.terrain.cover_thickness_at(main.gbr.x, main.gbr.z)
	var deplete := 1.0
	if scenario == 0 and AppState.depletion_mode != "bar":
		deplete = 1.0 - 0.45 * ramp(t, 0.6, 0.95)
	main.terrain.set_cover_depletion(main.gbr, 400.0, deplete)
	if _cover_label:
		if t < 0.4:
			_cover_label.text = ""
		elif scenario == 0:
			var how: String = {"both": "colluvial store thinning and no replenishment of the bar", "colluvium": "colluvial store thinning around GBR", "bar": "no hidden source; the bar's stock dwindles"}[AppState.depletion_mode]
			_cover_label.text = "Scenario 1 (source used up), expressed as: %s (Illustrative)\n%.0f %% of the mapped cover left around GBR; modelled cover at the bar: %.1f m" % [how, deplete * 100.0, cov * deplete]
		else:
			_cover_label.text = "Scenario 2: source hidden under alluvium, replenished by floods (paper's preference)\nmodelled cover at the bar: %.1f m (colluvium max 18 m, alluvium max 3 m)" % cov
	_trace.visible = t >= 0.4 and t < 0.5   # hidden during the brook close-ups (the dots are 1.2 m, the pebbles 1-5 cm)
	if not main.tour.on:
		for k in main.volumes.zone_a_keys():
			main.volumes.set_highlight(k, t >= 0.4 and t < 0.5)


func scrub_text(t: float) -> String:
	for i in range(scrub_marks.size() - 1, -1, -1):
		if t >= scrub_marks[i][0] - 0.001:
			var s: String = scrub_marks[i][1]
			if t >= 0.5:
				s += "  [scenario %d: %s]" % [scenario + 1, "source used up, supply thinning" if scenario == 0 else "floods replenish (paper's preference)"]
			return s
	return ""


func exit(main: Node) -> void:
	AppState.color_mode = 3
	AppState.cover_skin = false
	AppState.cut_enabled = false
	main.ambience.set_levels(0.0, 0.0)
	for k in ["sites", "mindat"]:
		if main.features.groups.has(k):
			main.features.groups[k].visible = AppState.is_layer_visible(k)
	_anchor.clear()
	main.terrain.set_cover_depletion(Vector3.ZERO, 0.0, 1.0)
	main.terrain.clear_detail_patches()
	main.terrain.set_channels([])
	_bar_root.clear()
	_flow.clear()
	for k in main.volumes.zone_a_keys():
		main.volumes.set_highlight(k, false)
	main.clear_extras()
	_source.clear()
	_pebbles.clear()
	_bars.clear()
	_water.clear()
	_water_mats.clear()
	_labels.clear()
	_cover_label = null
	_trace = null
	if main.features.groups.has("glacial"):
		main.features.groups["glacial"].visible = AppState.is_layer_visible("glacial")
