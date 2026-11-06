extends Node3D
## Lidar terrain: chunked flat grids displaced on the GPU from the packed 16-bit heightmap.
## Coordinates: x = UTM east - 547500, z = 4500500 - UTM north, y = elevation (m NAVD88).

const CHUNK_SEGMENTS := 250
var meta: Dictionary
var unit_ids: Dictionary
var mat: ShaderMaterial
var height_img: Image
var z_min: float
var z_max: float
var origin_xz: Vector2
var size_xz: Vector2
var cell := 4.0
var stride := 2   # vertex every `stride` cells (2 -> 8 m)
var width: int
var height: int


func _ready() -> void:
	meta = AppState.load_json("res://data/terrain/terrain.json")
	unit_ids = AppState.load_json("res://data/terrain/unit_ids.json")
	z_min = meta["z_min_m"]
	z_max = meta["z_max_m"]
	cell = meta["cell_size_m"]
	width = int(meta["width"])
	height = int(meta["height"])
	var bb: Dictionary = meta["bbox_utm"]
	var o: Dictionary = meta["scene_origin_utm"]
	origin_xz = Vector2(bb["west"] - o["east"], o["north"] - bb["north"])
	size_xz = Vector2(bb["east"] - bb["west"], bb["north"] - bb["south"])

	var height_tex: Texture2D = load("res://data/terrain/heightmap_4m_rgb.png")
	height_img = height_tex.get_image()
	if height_img.is_compressed():
		height_img.decompress()
	var bedrock_tex: Texture2D = load("res://data/terrain/bedrock_units_4m.png")
	var surf_tex: Texture2D = load("res://data/terrain/surficial_class_4m.png")
	var cover_tex: Texture2D = load("res://data/terrain/cover_thickness_4m.png")
	cover_meta = AppState.load_json("res://data/terrain/cover.json")

	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("height_tex", height_tex)
	mat.set_shader_parameter("bedrock_tex", bedrock_tex)
	mat.set_shader_parameter("surf_tex", surf_tex)
	mat.set_shader_parameter("cover_tex", cover_tex)
	mat.set_shader_parameter("cover_scale_m", float(cover_meta.get("scale_m_per_level", 0.2)))
	mat.set_shader_parameter("origin_xz", origin_xz)
	mat.set_shader_parameter("size_xz", size_xz)
	mat.set_shader_parameter("tex_size", Vector2(width, height))
	mat.set_shader_parameter("cell", cell)
	mat.set_shader_parameter("z_min", z_min)
	mat.set_shader_parameter("z_max", z_max)
	mat.set_shader_parameter("bedrock_colors", _color_table(unit_ids["bedrock"]))
	mat.set_shader_parameter("surf_colors", _color_table(unit_ids["surficial"]))
	mat.set_shader_parameter("noise_tex", preload("res://scripts/NoiseTex.gd").get_texture())
	_build_chunks()
	bedrock_mat = mat.duplicate()
	bedrock_mat.set_shader_parameter("cover_mode", 1)
	for c in get_children():
		if c is MeshInstance3D:
			var b := MeshInstance3D.new()
			b.mesh = c.mesh
			b.material_override = bedrock_mat
			b.position = c.position
			b.custom_aabb = c.custom_aabb
			b.visible = false
			b.name = "bedrock_" + c.name
			cover_chunks.append(b)
	for b in cover_chunks:
		add_child(b)
	AppState.changed.connect(_apply_state)
	_apply_state()


func _color_table(d: Dictionary) -> PackedColorArray:
	var arr := PackedColorArray()
	arr.resize(16)
	for i in 16:
		arr[i] = Color(0.8, 0.8, 0.8, 1.0)
	for k in d:
		var e: Dictionary = d[k]
		var id := int(e["id"])
		if id >= 0 and id < 16:
			arr[id] = Color.html(e["color"])
	return arr


func _build_chunks() -> void:
	var seg_m := cell * stride
	var chunk_m := seg_m * CHUNK_SEGMENTS
	var nx := int(ceil(size_xz.x / chunk_m))
	var nz := int(ceil(size_xz.y / chunk_m))
	for i in nx:
		for j in nz:
			var w := minf(chunk_m, size_xz.x - i * chunk_m)
			var h := minf(chunk_m, size_xz.y - j * chunk_m)
			var pm := PlaneMesh.new()
			pm.size = Vector2(w, h)
			pm.subdivide_width = int(round(w / seg_m)) - 1
			pm.subdivide_depth = int(round(h / seg_m)) - 1
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = mat
			mi.position = Vector3(origin_xz.x + i * chunk_m + w * 0.5, 0.0, origin_xz.y + j * chunk_m + h * 0.5)
			mi.custom_aabb = AABB(Vector3(-w * 0.5, z_min - 10.0, -h * 0.5), Vector3(w, z_max - z_min + 20.0, h))
			mi.name = "chunk_%d_%d" % [i, j]
			add_child(mi)


## Every terrain material: the coarse grid, its bedrock-top twin, and the detail patches' pairs.
func _mats() -> Array:
	var out: Array = [mat]
	if bedrock_mat != null:
		out.append(bedrock_mat)
	for p in patches:
		out.append(p["mat"])
		out.append(p["bed_mat"])
	return out


func _apply_state() -> void:
	var p := AppState.cut_plane
	_update_twin()
	for m in _mats():
		if m == null:
			continue
		m.set_shader_parameter("color_mode", AppState.color_mode)
		m.set_shader_parameter("cut_enabled", AppState.cut_enabled)
		m.set_shader_parameter("cut_plane", Vector4(p.normal.x, p.normal.y, p.normal.z, p.d))
		m.set_shader_parameter("vexag", AppState.vexag)


var bedrock_mat: ShaderMaterial
var cover_chunks: Array = []
var cover_meta: Dictionary = {}
var cover_skin := false
var _cover_img: Image


## Show the modelled bedrock top under the surficial cover (the cover becomes a visible skin in cross-section).
func set_cover_skin(on: bool) -> void:
	cover_skin = on
	_update_twin()
	mat.set_shader_parameter("surface_alpha", 1.0)


var _cam_underground := false


## The twin (bedrock top under the cover) lies wholly under the opaque surface: it can only show in a cut or
## from underground, so it is drawn only then (round 6; it doubled the terrain's vertex load in every view).
func _update_twin() -> void:
	var show := cover_skin and not ghost and (AppState.cut_enabled or _cam_underground)
	for b in cover_chunks:
		b.visible = show
	for p in patches:
		p["bed"].visible = show


func set_camera_underground(under: bool) -> void:
	if under != _cam_underground:
		_cam_underground = under
		_update_twin()


## Chapter 7 'source used up' scenario: scale the colluvium/alluvium thickness around a site (1 = as mapped).
func set_cover_depletion(center: Vector3, radius: float, scale: float) -> void:
	for m in _mats():
		m.set_shader_parameter("deplete_center", center)
		m.set_shader_parameter("deplete_radius", radius)
		m.set_shader_parameter("deplete_scale", scale)


## Modelled cover thickness (metres) at world x,z (A-G8 taper of the OFM 69 extents and maxima).
func cover_thickness_at(x: float, z: float) -> float:
	if _cover_img == null:
		_cover_img = (load("res://data/terrain/cover_thickness_4m.png") as Texture2D).get_image()
		if _cover_img.is_compressed():
			_cover_img.decompress()
	var c := clampi(int((x - origin_xz.x) / cell), 0, width - 1)
	var r := clampi(int((z - origin_xz.y) / cell), 0, height - 1)
	return round(_cover_img.get_pixel(c, r).r * 255.0) * float(cover_meta.get("scale_m_per_level", 0.2))


func set_pulse(p: float) -> void:
	for m in _mats():
		m.set_shader_parameter("pulse", p)


## Ground elevation (true metres, no exaggeration) at world x,z; bilinear from the 4 m grid.
func height_at(x: float, z: float) -> float:
	var fx := (x - origin_xz.x) / cell - 0.5
	var fz := (z - origin_xz.y) / cell - 0.5
	fx = clampf(fx, 0.0, width - 1.001)
	fz = clampf(fz, 0.0, height - 1.001)
	var c0 := int(floor(fx))
	var r0 := int(floor(fz))
	var tx := fx - c0
	var tz := fz - r0
	var h00 := _h(c0, r0)
	var h10 := _h(c0 + 1, r0)
	var h01 := _h(c0, r0 + 1)
	var h11 := _h(c0 + 1, r0 + 1)
	var e := lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)
	if not channels.is_empty():
		e -= channel_depth_at(x, z)
	return e


## ---- brook channel and detail patches (polish pass; Illustrative, A-G20) ----
var channels: Array = []           # Array[Vector4] x0, z0, x1, z1 (world) along the mapped stream near the sites
var channel_depth := 1.0
var channel_halfwidth := 3.5
var patches: Array = []            # [{node, bed, mat, bed_mat, box: Rect2}]
var _channel_bbox := Rect2()


## Carve the brook along these stream segments (world xz pairs). [] removes the carve.
func set_channels(segs: Array) -> void:
	channels = segs.slice(0, 64)
	var arr := PackedVector4Array()
	for v in channels:
		arr.append(v)
	while arr.size() < 64:
		arr.append(Vector4.ZERO)
	_channel_bbox = Rect2()
	for i in channels.size():
		var v: Vector4 = channels[i]
		var r := Rect2(Vector2(minf(v.x, v.z), minf(v.y, v.w)), Vector2(absf(v.z - v.x), absf(v.w - v.y))).grow(channel_halfwidth)
		_channel_bbox = r if i == 0 else _channel_bbox.merge(r)
	var bb := _channel_bbox
	for m in _mats():
		m.set_shader_parameter("channel_n", channels.size())
		m.set_shader_parameter("channel_segs", arr)
		m.set_shader_parameter("channel_bbox", Vector4(bb.position.x, bb.position.y, bb.end.x, bb.end.y))
		m.set_shader_parameter("channel_depth", channel_depth)
		m.set_shader_parameter("channel_halfwidth", channel_halfwidth)


## Depth of the carved channel at world x,z (0 away from it); same profile as the shader.
func channel_depth_at(x: float, z: float) -> float:
	if channels.is_empty() or not _channel_bbox.has_point(Vector2(x, z)):
		return 0.0
	var best := 1.0e9
	var p := Vector2(x, z)
	for v in channels:
		var a := Vector2(v.x, v.y)
		var ab := Vector2(v.z, v.w) - a
		var t := clampf((p - a).dot(ab) / maxf(ab.dot(ab), 1.0e-6), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	var u := clampf(best / channel_halfwidth, 0.0, 1.0)
	return channel_depth * (1.0 - u * u)


## A fine (1 m) terrain patch replacing the coarse grid in a square around `center` (the brook sites).
func add_detail_patch(center: Vector3, half: float) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(half * 2.0, half * 2.0)
	pm.subdivide_width = int(half * 2.0) - 1
	pm.subdivide_depth = int(half * 2.0) - 1
	var m: ShaderMaterial = mat.duplicate()
	m.set_shader_parameter("is_patch", true)
	var bm: ShaderMaterial = bedrock_mat.duplicate()
	bm.set_shader_parameter("is_patch", true)
	bm.set_shader_parameter("cover_mode", 1)
	var mi := MeshInstance3D.new()
	mi.name = "patch_%d" % patches.size()
	mi.mesh = pm
	mi.material_override = m
	mi.position = Vector3(center.x, 0.0, center.z)
	mi.custom_aabb = AABB(Vector3(-half, z_min - 10.0, -half), Vector3(half * 2.0, z_max - z_min + 20.0, half * 2.0))
	mi.visible = not ghost
	add_child(mi)
	var bi := MeshInstance3D.new()
	bi.name = "patch_bed_%d" % patches.size()
	bi.mesh = pm
	bi.material_override = bm
	bi.position = mi.position
	bi.custom_aabb = mi.custom_aabb
	bi.visible = cover_skin and not ghost and (AppState.cut_enabled or _cam_underground)
	add_child(bi)
	patches.append({"node": mi, "bed": bi, "mat": m, "bed_mat": bm, "box": Rect2(center.x - half, center.z - half, half * 2.0, half * 2.0)})
	_push_patch_boxes()
	_apply_state()
	set_channels(channels)


func clear_detail_patches() -> void:
	for p in patches:
		p["node"].queue_free()
		p["bed"].queue_free()
	patches.clear()
	_push_patch_boxes()


func _push_patch_boxes() -> void:
	var arr := PackedVector4Array()
	for p in patches:
		var b: Rect2 = p["box"]
		arr.append(Vector4(b.position.x, b.position.y, b.end.x, b.end.y))
	while arr.size() < 4:
		arr.append(Vector4.ZERO)
	for m in _mats():
		m.set_shader_parameter("patch_n", patches.size())
		m.set_shader_parameter("patch_boxes", arr)


func _h(c: int, r: int) -> float:
	var px := height_img.get_pixel(mini(c, width - 1), mini(r, height - 1))
	return (round(px.r * 255.0) * 256.0 + round(px.g * 255.0)) / 65535.0 * (z_max - z_min) + z_min


func bedrock_unit_at(x: float, z: float) -> String:
	return _unit_at(x, z, "res://data/terrain/bedrock_units_4m.png", unit_ids["bedrock"], "_bedrock_img")


func surficial_class_at(x: float, z: float) -> String:
	return _unit_at(x, z, "res://data/terrain/surficial_class_4m.png", unit_ids["surficial"], "_surf_img")


var _bedrock_img: Image
var _surf_img: Image


func _unit_at(x: float, z: float, path: String, table: Dictionary, cache: String) -> String:
	var img: Image = get(cache)
	if img == null:
		img = (load(path) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		set(cache, img)
	var c := clampi(int((x - origin_xz.x) / cell), 0, width - 1)
	var r := clampi(int((z - origin_xz.y) / cell), 0, height - 1)
	var id := int(round(img.get_pixel(c, r).r * 255.0))
	for k in table:
		if int(table[k]["id"]) == id:
			return k
	return ""


func set_highlight(center: Vector3, radius: float) -> void:
	for m in _mats():
		m.set_shader_parameter("highlight_center", center)
		m.set_shader_parameter("highlight_radius", radius)


var ghost_mat: ShaderMaterial
var ghost := false


## Draw today's surface as a faint reference (used by the pre-modern chapters).
func set_ghost(on: bool) -> void:
	if ghost_mat == null:
		ghost_mat = ShaderMaterial.new()
		ghost_mat.shader = load("res://shaders/terrain_ghost.gdshader")
		for k in ["height_tex", "origin_xz", "size_xz", "tex_size", "z_min", "z_max"]:
			ghost_mat.set_shader_parameter(k, mat.get_shader_parameter(k))
	ghost = on
	for c in get_children():
		if c is MeshInstance3D and not cover_chunks.has(c) and not c.name.begins_with("patch"):
			c.material_override = ghost_mat if on else mat
	for p in patches:
		p["node"].visible = not on
	_update_twin()


func set_erosion(level: float, valley_level: float) -> void:
	for m in _mats():
		m.set_shader_parameter("erosion_level", level)
		m.set_shader_parameter("erosion_level_valley", valley_level)
