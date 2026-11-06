extends Node3D
## Vector features draped on the terrain: streams, contacts, faults, glacial features, sample-site zones,
## Mindat localities. Each group is a child Node3D keyed for the layer toggles.

var terrain: Node3D
var groups := {}
var site_centers := {}   # code -> Vector3 (world)
var mindat_points := []  # Array of {info, pos}


func _ready() -> void:
	terrain = get_node("../Terrain")
	_lines("streams", "res://data/vectors/streams.geojson", Color(0.15, 0.45, 0.95), 1.5, "observed",
		func(p): return {"title": "Stream: " + (p.get("name", "") if p.get("name", "") != "" else "unnamed"), "tier": "observed",
			"body": "USGS NHD flowline (fcode %s, %.2f km)." % [str(p.get("fcode", "")), float(p.get("lengthkm", 0.0))], "ref": "USGS NHD; paper Fig. 2 (streams)"})
	_lines("contacts", "res://data/vectors/bedrock_contacts.geojson", Color(0.1, 0.1, 0.1), 2.0, "observed",
		func(p): return {"title": "Bedrock contact (%s)" % p.get("kind", ""), "tier": "observed",
			"body": "Mapped contact between bedrock units; location " + str(p.get("kind", "")) + ".", "ref": "NJGWS DGS15-1 / GMS 04-02; paper Fig. 2"})
	_lines("faults", "res://data/vectors/faults.geojson", Color(0.75, 0.05, 0.05), 2.5, "observed",
		func(p): return {"title": "Fault (%s, %s)" % [p.get("kind", ""), p.get("confidence", "")], "tier": "observed",
			"body": "Steeply dipping (70-90 deg), mainly open, unmineralized brittle faults up to 0.5 m wide are common in the study area (paper section 5.2). Drawn as a surface trace only.", "ref": "NJGWS DGS15-1; paper section 5.2, Fig. 2"})
	_polys("glacial", "res://data/vectors/glacial_features.geojson", "observed")
	_limits()
	_sites()
	_mindat()
	AppState.layer_visibility_changed.connect(_on_vis)


var _filter: Array = []   # when non-empty, only these groups may be shown (chapter choice)


func _on_vis(key: String, on: bool) -> void:
	if groups.has(key):
		groups[key].visible = on and (_filter.is_empty() or _filter.has(key))


## Chapters 2-5 and W quieten the scene: only the listed feature groups stay visible. [] restores the user's toggles.
func set_group_filter(allowed: Array) -> void:
	_filter = allowed
	for key in groups:
		groups[key].visible = AppState.is_layer_visible(key) and (_filter.is_empty() or _filter.has(key))


func _group(key: String) -> Node3D:
	if not groups.has(key):
		var g := Node3D.new()
		g.name = key
		add_child(g)
		groups[key] = g
	return groups[key]


func _drape(pts: PackedVector2Array, lift: float) -> PackedVector3Array:
	# resample to <= 10 m spacing and lift above the terrain
	var out := PackedVector3Array()
	for i in pts.size():
		var p := pts[i]
		if i > 0:
			var q := pts[i - 1]
			var d := q.distance_to(p)
			var n := int(d / 10.0)
			for k in range(1, n):
				var r := q.lerp(p, float(k) / n)
				out.append(Vector3(r.x, terrain.height_at(r.x, r.y) + lift, r.y))
		out.append(Vector3(p.x, terrain.height_at(p.x, p.y) + lift, p.y))
	return out


func _coords_to_local(coords: Array) -> PackedVector2Array:
	# GeoJSON local metres (x east, y north) -> world (x, z = -y)
	var out := PackedVector2Array()
	for c in coords:
		out.append(Vector2(c[0], -c[1]))
	return out


func _lines(key: String, path: String, color: Color, width: float, tier: String, info_fn: Callable) -> void:
	var gj = AppState.load_json(path)
	if gj == null:
		return
	var g := _group(key)
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.no_depth_test = false
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = mat
	mi.custom_aabb = AABB(Vector3(-7000, -500, -6000), Vector3(14000, 1000, 12000))
	g.add_child(mi)
	var pick := []
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for f in gj["features"]:
		var geom: Dictionary = f["geometry"]
		var parts: Array = []
		if geom["type"] == "LineString":
			parts = [geom["coordinates"]]
		elif geom["type"] == "MultiLineString":
			parts = geom["coordinates"]
		for part in parts:
			var pts := _drape(_coords_to_local(part), 1.5)
			for i in range(1, pts.size()):
				im.surface_add_vertex(pts[i - 1])
				im.surface_add_vertex(pts[i])
			pick.append({"pts": pts, "info": info_fn.call(f["properties"])})
	im.surface_end()
	g.set_meta("pick", pick)
	g.set_meta("tier", tier)


func _polys(key: String, path: String, tier: String) -> void:
	var gj = AppState.load_json(path)
	if gj == null:
		return
	var g := _group(key)
	var colors := {"pre_illinoian_till": Color(0.35, 0.55, 0.85), "terminal_moraine": Color(0.2, 0.35, 0.7),
		"rahway_till": Color(0.5, 0.65, 0.85), "glacial_lake_passaic": Color(0.6, 0.8, 0.95)}
	var pick := []
	for f in gj["features"]:
		var p: Dictionary = f["properties"]
		var geom: Dictionary = f["geometry"]
		var polys: Array = [geom["coordinates"]] if geom["type"] == "Polygon" else geom["coordinates"]
		var col: Color = colors.get(p.get("feature", ""), Color.GRAY)
		var im := ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = col
		var mi := MeshInstance3D.new()
		mi.mesh = im
		mi.material_override = mat
		mi.custom_aabb = AABB(Vector3(-7000, -500, -6000), Vector3(14000, 1000, 12000))
		g.add_child(mi)
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		for poly in polys:
			for ring in poly:
				var pts := _drape(_coords_to_local(ring), 2.0)
				for i in range(1, pts.size()):
					im.surface_add_vertex(pts[i - 1])
					im.surface_add_vertex(pts[i])
				pick.append({"pts": pts, "info": {"title": str(p.get("name", "")) + " (" + str(p.get("unit", "")) + ")", "tier": tier,
					"body": "Mapped surficial deposit outline (OFM 69, DGS10-2). The published glacier limits M1 / M2 are drawn separately as dashed lines, digitised from OFM 69 Figure 1 (ASSUMPTIONS A-G14).",
					"ref": "NJGWS DGS10-2 (OFM 69); paper section 4.1"}})
		im.surface_end()
	g.set_meta("pick", pick)
	g.set_meta("tier", tier)


## Glacier-margin lines M1 / M2 digitised from OFM 69 Figure 1 (precision ~200 m): bold dashed lines.
func _limits() -> void:
	var gj = AppState.load_json("res://data/vectors/glacial_limits.geojson")
	if gj == null:
		return
	var g := _group("glacial_limits")
	var pick := []
	for f in gj["features"]:
		var p: Dictionary = f["properties"]
		var code: String = str(p.get("code", ""))
		var col := Color(0.25, 0.45, 0.95) if code == "M1" else Color(0.1, 0.2, 0.6)
		var im := ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = col
		var mi := MeshInstance3D.new()
		mi.mesh = im
		mi.material_override = mat
		mi.custom_aabb = AABB(Vector3(-7000, -500, -6000), Vector3(14000, 1000, 12000))
		g.add_child(mi)
		var pts := _drape(_coords_to_local(f["geometry"]["coordinates"]), 4.0)
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		var run := 0.0
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			run += a.distance_to(b)
			if fmod(run, 90.0) < 60.0:   # 60 m dash, 30 m gap
				for off: float in [-6.0, -2.0, 2.0, 6.0]:
					var side: Vector3 = (b - a).cross(Vector3.UP).normalized() * off
					im.surface_add_vertex(a + side)
					im.surface_add_vertex(b + side)
		im.surface_end()
		var title: String = "%s: %s" % [code, p.get("name", "")]
		pick.append({"pts": pts, "info": {"title": title, "tier": "observed",
			"body": "Glacier-margin line as drawn on OFM 69 Figure 1 (Stanford 2007). Digitised from the vector inset and georeferenced on the quadrangle outline: positions are good to about 200 m. The paper (section 4.1) places SGB south of this early Pleistocene limit and the NE Green Brook tributary headwaters inside it; GBR's zone centre falls within 200 m of the line (its tributary drains unglaciated ground).",
			"ref": str(p.get("source", ""))}})
		var lbl := Label3D.new()
		var mid: Vector3 = pts[pts.size() / 2]
		lbl.text = "%s  %s" % [code, "early Pleistocene (pre-Illinoian) limit" if code == "M1" else "late Wisconsinan limit"]
		lbl.font_size = 64
		lbl.pixel_size = 0.8
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.modulate = col.lerp(Color.WHITE, 0.4)
		lbl.outline_size = 18
		lbl.position = mid + Vector3(0, 40, 0)
		g.add_child(lbl)
		get_node("../..").register_label(lbl)
	g.set_meta("pick", pick)
	g.set_meta("tier", "observed")


func _sites() -> void:
	var gj = AppState.load_json("res://data/vectors/sample_sites.geojson")
	var g := _group("sites")
	for f in gj["features"]:
		var p: Dictionary = f["properties"]
		var c: Array = f["geometry"]["coordinates"]
		var x: float = c[0]
		var z: float = -c[1]
		var y: float = terrain.height_at(x, z)
		var r: float = p.get("radius_m", 250.0)
		var tm := TorusMesh.new()
		tm.inner_radius = r - 6.0
		tm.outer_radius = r + 6.0
		tm.rings = 96
		var mi := MeshInstance3D.new()
		mi.mesh = tm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.35, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.1)
		mat.emission_energy_multiplier = 0.8
		mi.material_override = mat
		mi.position = Vector3(x, y + 3.0, z)
		mi.name = p["code"]
		g.add_child(mi)
		var lbl := Label3D.new()
		lbl.text = "%s\n%s" % [p["code"], p["name"]]
		lbl.font_size = 96
		lbl.pixel_size = 0.6
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.modulate = Color(1.0, 0.5, 0.2)
		lbl.outline_size = 24
		lbl.position = Vector3(x, y + 60.0, z)
		g.add_child(lbl)
		get_node("../..").register_label(lbl)
		site_centers[p["code"]] = Vector3(x, y, z)
		mi.set_meta("info", {"title": "%s — %s" % [p["code"], p["name"]], "tier": "observed",
			"body": "Carnelian sample location, shown only as an approximate %d m zone: the paper marks it with an asterisk on Fig. 2 and gives no coordinates. %s" % [int(r), p.get("note", "")],
			"ref": p.get("source", "")})
	g.set_meta("tier", "observed")


func _mindat() -> void:
	var gj = AppState.load_json("res://data/vectors/mindat_localities.geojson")
	var g := _group("mindat")
	for f in gj["features"]:
		var p: Dictionary = f["properties"]
		var c: Array = f["geometry"]["coordinates"]
		var x: float = c[0]
		var z: float = -c[1]
		var y: float = terrain.height_at(x, z)
		var prec: String = p.get("stated_precision", "")
		var r := 500.0
		if prec.find("+/-1 km") >= 0:
			r = 1000.0
		elif prec.find("+/-2 km") >= 0:
			r = 2000.0
		var node := Node3D.new()
		node.position = Vector3(x, y + 4.0, z)
		g.add_child(node)
		# hatched ring: 24 short bars around the uncertainty radius
		var mat := StandardMaterial3D.new()
		mat.albedo_color = AppState.TIER_COLORS["mindat_reported"]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for i in 24:
			var ang := i * TAU / 24.0
			var bar := BoxMesh.new()
			bar.size = Vector3(r * 0.12, 6.0, 8.0)
			var mi := MeshInstance3D.new()
			mi.mesh = bar
			mi.material_override = mat
			mi.position = Vector3(cos(ang) * r, 0.0, sin(ang) * r)
			mi.rotation.y = -ang
			node.add_child(mi)
		var lbl := Label3D.new()
		lbl.text = "Mindat #%d\n%s" % [int(p["mindat_id"]), str(p["name"]).split(",")[0]]
		lbl.font_size = 80
		lbl.pixel_size = 0.6
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.modulate = AppState.TIER_COLORS["mindat_reported"]
		lbl.outline_size = 20
		lbl.position = Vector3(0, 45.0, 0)
		node.add_child(lbl)
		get_node("../..").register_label(lbl)
		var body := "User-contributed record (not an observation of the paper).\nStated position: %s\nMinerals listed: %s\nRock types: %s\nMindat references: %s\nAccessed %s." % [prec, p.get("minerals", ""), p.get("rock_types", ""), p.get("references", ""), p.get("accessed", "")]
		if p.has("api_fetched"):
			# the record as served by the Mindat API (scripts/fetch_mindat.py); the marker's position is unchanged
			body += "\n\nMindat API record (fetched %s, last edited %s): minerals %s." % [p.get("api_fetched", ""), p.get("api_modified", "?"), p.get("api_minerals", "")]
			if str(p.get("api_description", "")) != "":
				body += "\nMindat description: %s" % str(p.get("api_description", ""))
			body += "\nData CC BY-NC-SA 4.0, mindat.org (Hudson Institute of Mineralogy)."
		var info := {"title": "Mindat locality #%d: %s" % [int(p["mindat_id"]), p["name"]], "tier": "mindat_reported",
			"body": body, "ref": str(p.get("url", ""))}
		node.set_meta("info", info)
		mindat_points.append({"info": info, "pos": node.position, "radius": r})
	g.set_meta("tier", "mindat_reported")


## Nearest pickable line feature to a ray (for hover/click). Returns {} or the feature info.
func pick(ray_from: Vector3, ray_dir: Vector3, max_dist := 40.0) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for key in groups:
		var g: Node3D = groups[key]
		if not g.visible or not g.has_meta("pick"):
			continue
		for item in g.get_meta("pick"):
			var pts: PackedVector3Array = item["pts"]
			for i in range(0, pts.size(), 3):
				var d := _ray_point_dist(ray_from, ray_dir, pts[i])
				if d < best_d:
					best_d = d
					best = item["info"]
	return best


func _ray_point_dist(o: Vector3, d: Vector3, p: Vector3) -> float:
	var t := (p - o).dot(d)
	if t < 0.0:
		return 1.0e9
	var tol := 0.004 * t   # angular tolerance grows with distance
	return (o + d * t).distance_to(p) / maxf(tol / 40.0, 1.0)
