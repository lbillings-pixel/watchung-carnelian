extends Node3D
## Subsurface layer slabs from data/volumes/*.glb + layers.json.
## Two stacks exist for every layer: the TILTED stack (today's attitude: 9.5 deg toward 323.5 on a gently folded
## reference surface, A-G4) and the FLAT stack (horizontal beds, levelled on the first-flow base at GBR) used by
## the depositional chapters 2-5.  Thin layers are thickened for visibility (AppState.thicken_on): the flat stack
## by an affine transform about its base plane (exact for a plane); the tilted stack by swapping in a pre-thickened
## mesh written by the pipeline (file_thick), because an affine thickening is wrong on a folded surface.

const THIN_LIMIT := 10.0   # layers thinner than this (true metres) are thickened

var manifest: Dictionary
var layers: Array = []     # Array[Dictionary] with node, mesh, mat, info, mesh_tilt, mesh_tilt_thick, mesh_flat, shell
var tilted := true
var bed_normal: Vector3    # unit normal to bedding at GBR, Godot axes (active stack)
var plane_a: float
var plane_b: float
var plane_c: float
var plane_k: float
var tilt_fraction := 1.0   # 0 = flat, 1 = tilted (animated rigid rotation of the flat meshes about the strike axis)
var _lens: Dictionary
var _fold: Dictionary      # cosine flexure parameters (tilted stack only)
var _fold_on := false
var _strike_xz: Vector2    # unit vector along strike in Godot x,z
var _axis_point: Vector3   # point on the tilt axis (GBR, first-flow base elevation)
var _terrain: Node
var _shell_shader: Shader
var _shell_margin := 3.0


func _ready() -> void:
	manifest = AppState.load_json("res://data/volumes/layers.json")
	_lens = manifest.get("gabbroid_lens", {})
	_fold = manifest.get("fold", {})
	var su: Array = manifest["tilt_axis"]["strike_unit_xy"]
	_strike_xz = Vector2(su[0], -su[1])
	var ap: Array = manifest["tilt_axis"]["point_xyz_local"]
	_axis_point = Vector3(ap[0], ap[2], -ap[1])
	_terrain = get_node("../Terrain")
	var shader: Shader = load("res://shaders/geolayer.gdshader")
	_shell_shader = load("res://shaders/outline.gdshader")
	for e in manifest["layers"]:
		var scene: PackedScene = load("res://data/volumes/" + e["file"])
		var inst := scene.instantiate()
		var mi := _find_mesh(inst)
		if mi == null:
			push_error("no mesh in " + e["file"])
			continue
		mi.mesh = _with_normals(mi.mesh)
		var mesh_flat: Mesh = _load_mesh("res://data/volumes/" + e["file_flat"])
		var mesh_thick: Mesh = _load_mesh("res://data/volumes/" + e["file_thick"]) if e.has("file_thick") else null
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("albedo", Color.html(e["color"]))
		m.set_shader_parameter("tier", AppState.TIER_IDS.get(e["tier"], 0))
		m.set_shader_parameter("height_tex", _terrain.mat.get_shader_parameter("height_tex"))
		m.set_shader_parameter("origin_xz", _terrain.origin_xz)
		m.set_shader_parameter("size_xz", _terrain.size_xz)
		m.set_shader_parameter("tex_size", Vector2(_terrain.width, _terrain.height))
		m.set_shader_parameter("z_min", _terrain.z_min)
		m.set_shader_parameter("z_max", _terrain.z_max)
		m.set_shader_parameter("bedrock_tex", _terrain.mat.get_shader_parameter("bedrock_tex"))
		m.set_shader_parameter("noise_tex", preload("res://scripts/NoiseTex.gd").get_texture())
		m.set_shader_parameter("keep_underside", e["key"] == "passaic")   # see geolayer.gdshader
		mi.material_override = m
		mi.custom_aabb = AABB(Vector3(-7000, -800, -6000), Vector3(14000, 1600, 12000))
		inst.name = e["key"]
		add_child(inst)
		# glowing shell for the tour introductions (hidden until asked for)
		var shell := MeshInstance3D.new()
		shell.name = "shell"
		shell.mesh = mi.mesh
		var sm := ShaderMaterial.new()
		sm.shader = _shell_shader
		sm.render_priority = 10
		for k in ["height_tex", "origin_xz", "size_xz", "tex_size", "z_min", "z_max"]:
			sm.set_shader_parameter(k, m.get_shader_parameter(k))
		shell.material_override = sm
		shell.custom_aabb = mi.custom_aabb
		shell.visible = false
		mi.add_child(shell)
		var info: Dictionary = e.duplicate()
		info["kind"] = "layer"
		layers.append({"key": e["key"], "node": inst, "mesh": mi, "mat": m, "info": info, "mesh_tilt": mi.mesh,
			"mesh_tilt_thick": mesh_thick, "mesh_flat": mesh_flat, "shell": shell, "shell_mat": sm})
	_use_plane(true)
	AppState.changed.connect(_apply_state)
	AppState.layer_visibility_changed.connect(_on_vis)
	_apply_state()


func _load_mesh(path: String) -> Mesh:
	var scene: PackedScene = load(path)
	if scene == null:
		return null
	var inst := scene.instantiate()
	var mi := _find_mesh(inst)
	var mesh: Mesh = mi.mesh if mi != null else null
	inst.queue_free()
	return _with_normals(mesh)


## The pipeline's glb slabs carry no normals (the importer leaves the array empty), so the shaders had none to
## light or offset by. Generate smooth normals at load, pointing outward (checked on the highest vertex).
static func _with_normals(mesh: Mesh) -> Mesh:
	if mesh == null:
		return null
	var arr: Array = mesh.surface_get_arrays(0)
	if arr[Mesh.ARRAY_NORMAL] != null:
		return mesh
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()
	var out: ArrayMesh = st.commit()
	var a2: Array = out.surface_get_arrays(0)
	var verts: PackedVector3Array = a2[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a2[Mesh.ARRAY_NORMAL]
	var hi := 0
	for i in verts.size():
		if verts[i].y > verts[hi].y:
			hi = i
	if nrm[hi].y < 0.0:   # wound the other way: flip so the normals point out of the slab
		st.clear()
		st.create_from(mesh, 0)
		st.generate_normals(true)
		out = st.commit()
	return out


func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r != null:
			return r
	return null


func _use_plane(tilt: bool) -> void:
	var pl: Dictionary = manifest["plane"] if tilt else manifest["flat_plane"]
	plane_a = pl["a"]
	plane_b = pl["b"]
	plane_c = pl["c"]
	_fold_on = tilt and not _fold.is_empty()
	# local (x east, y north, z up) normal (-a, -b, 1) -> Godot (x, z_up, -y) => (-a, 1, b)
	bed_normal = Vector3(-plane_a, 1.0, plane_b).normalized()
	plane_k = 1.0 / Vector3(-plane_a, -plane_b, 1.0).normalized().z


## Keys of the layers that together form candidate zone A (the vesicle-rich sheet set).
func zone_a_keys() -> Array:
	return manifest.get("zone_a", {}).get("keys", [])


## Perpendicular offsets (above the first-flow base) of the centre of every zone A sheet.
func zone_a_offsets() -> Array:
	var out: Array = []
	for s in manifest.get("zone_a", {}).get("sheets", []):
		var e := layer_info(s["key"])
		out.append(float(e["base_offset_m"]) + 0.5 * float(e["thickness_m"]))
	return out


## Switch between today's tilted attitude and the untilted depositional stack.
func set_tilted(on: bool) -> void:
	if on == tilted and tilt_fraction == (1.0 if on else 0.0):
		return
	tilted = on
	tilt_fraction = 1.0 if on else 0.0
	_use_plane(on)
	for l in layers:
		var mi: MeshInstance3D = l["mesh"]
		mi.rotation = Vector3.ZERO
		mi.position = Vector3.ZERO
	_apply_state()


## Animate the tilt (0 = flat .. 1 = tilted) by rotating the flat meshes rigidly about the strike axis through
## the GBR first-flow base point. At 1 the real tilted (folded) meshes are shown.
func set_tilt_fraction(f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	if f >= 0.999:
		set_tilted(true)
		return
	if tilted:
		set_tilted(false)
	tilt_fraction = f
	var dip := deg_to_rad(float(manifest["plane"]["dip_deg"])) * f
	var axis := Vector3(_strike_xz.x, 0.0, _strike_xz.y).normalized()
	# the beds must drop toward the dip direction (NW): rotate about the strike axis by -dip (checked against surface_elevation)
	var dd: Array = [float(manifest["plane"]["a"]), float(manifest["plane"]["b"])]
	var down_dip := Vector3(-dd[0], 0.0, dd[1]).normalized()   # Godot x,z of the down-dip direction (a,b = d z/dx, d z/dy local)
	var sgn := -1.0 if axis.cross(Vector3.UP).dot(down_dip) > 0.0 else 1.0
	var basis := Basis(axis, sgn * dip)
	for l in layers:
		var mi: MeshInstance3D = l["mesh"]
		mi.transform = Transform3D(basis, _axis_point - basis * _axis_point)


func _on_vis(key: String, on: bool) -> void:
	for l in layers:
		if l["key"] == key:
			l["node"].visible = on


var growth := {}          # key -> 0..1 fraction of thickness grown (chapter animations)
var glow := {}            # key -> 0..1 incandescence
var era_keys: Array = []  # when non-empty, only these layers are shown (chapter eras)
var clip_to_terrain := true
var erosion_level := -1.0e9
var erosion_level_valley := -1.0e9
var box_clip := false
var box_min := Vector3(-1.0e9, -1.0e9, -1.0e9)
var box_max := Vector3(1.0e9, 1.0e9, 1.0e9)


func _display_cap(info: Dictionary) -> float:
	return float(info.get("display_max_m", THIN_LIMIT))


func _apply_state() -> void:
	for l in layers:
		_apply_layer(l)


## Push one layer's uniforms, mesh choice, transform and visibility.
func _apply_layer(l: Dictionary) -> void:
	var p := AppState.cut_plane
	var m: ShaderMaterial = l["mat"]
	m.set_shader_parameter("tier_styling", AppState.tier_styling)
	m.set_shader_parameter("cut_enabled", AppState.cut_enabled)
	m.set_shader_parameter("cut_plane", Vector4(p.normal.x, p.normal.y, p.normal.z, p.d))
	m.set_shader_parameter("vexag", AppState.vexag)
	m.set_shader_parameter("clip_to_terrain", clip_to_terrain)
	m.set_shader_parameter("erosion_level", erosion_level)
	m.set_shader_parameter("erosion_level_valley", erosion_level_valley)
	m.set_shader_parameter("clip_to_box", box_clip)
	m.set_shader_parameter("box_min", box_min)
	m.set_shader_parameter("box_max", box_max)
	m.set_shader_parameter("glow", float(glow.get(l["key"], 0.0)))
	var sm: ShaderMaterial = l["shell_mat"]
	sm.set_shader_parameter("cut_enabled", AppState.cut_enabled)
	sm.set_shader_parameter("cut_plane", Vector4(p.normal.x, p.normal.y, p.normal.z, p.d))
	sm.set_shader_parameter("vexag", AppState.vexag)
	sm.set_shader_parameter("clip_to_terrain", clip_to_terrain)
	sm.set_shader_parameter("erosion_level", erosion_level)
	sm.set_shader_parameter("clip_to_box", box_clip)
	sm.set_shader_parameter("box_min", box_min)
	sm.set_shader_parameter("box_max", box_max)
	sm.set_shader_parameter("margin", _shell_margin)
	var t: float = l["info"]["thickness_m"]
	var mi: MeshInstance3D = l["mesh"]
	var g: float = growth.get(l["key"], 1.0)
	if tilted and tilt_fraction >= 1.0:
		# folded stack: pre-thickened mesh when thickening is on, true mesh otherwise; no affine transform
		var use_thick: bool = AppState.thicken_on and l["mesh_tilt_thick"] != null
		mi.mesh = l["mesh_tilt_thick"] if use_thick else l["mesh_tilt"]
		l["node"].transform = Transform3D.IDENTITY
	else:
		mi.mesh = l["mesh_flat"]
		var f := 1.0
		if AppState.thicken_on and t < THIN_LIMIT:
			f = minf(AppState.thicken_factor, _display_cap(l["info"]) / t)
			f = maxf(f, 1.0)
		l["node"].transform = _thicken_transform(l["info"]["base_offset_m"], f * g)
	l["shell"].mesh = mi.mesh
	var shown := AppState.is_layer_visible(l["key"]) and (era_keys.is_empty() or era_keys.has(l["key"])) and g > 0.0
	l["node"].visible = shown


## Growth and glow are driven every frame by the depositional chapters: only the named layer is touched, and
## only when the value changes (round 6; before, every call re-pushed every uniform of every layer).
func set_growth(key: String, frac: float) -> void:
	var f := clampf(frac, 0.0, 1.0)
	if growth.get(key, -1.0) == f:
		return
	growth[key] = f
	for l in layers:
		if l["key"] == key:
			_apply_layer(l)
			return


func set_glow(key: String, g: float) -> void:
	var gg := clampf(g, 0.0, 1.0)
	if glow.get(key, -1.0) == gg:
		return
	glow[key] = gg
	for l in layers:
		if l["key"] == key:
			l["mat"].set_shader_parameter("glow", gg)
			return


func max_glow() -> float:
	var m := 0.0
	for k in glow:
		m = maxf(m, float(glow[k]))
	return m


## Heat shimmer above molten lava (polish pass): a screen-refracting slab over the block, from y_top upward.
var _shimmer: MeshInstance3D


func set_shimmer(y_top: float, strength: float, center: Vector3, size: Vector2) -> void:
	if _shimmer == null:
		_shimmer = MeshInstance3D.new()
		_shimmer.name = "shimmer"
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 1.0, 1.0)
		_shimmer.mesh = bm
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/shimmer.gdshader")
		m.render_priority = 5
		_shimmer.material_override = m
		_shimmer.custom_aabb = AABB(Vector3(-7000, -800, -6000), Vector3(14000, 1600, 12000))
		add_child(_shimmer)
	_shimmer.visible = strength > 0.01
	if not _shimmer.visible:
		return
	var h := 30.0
	_shimmer.scale = Vector3(size.x, h, size.y)
	_shimmer.position = Vector3(center.x, y_top + h * 0.5, center.z)
	var sm: ShaderMaterial = _shimmer.material_override
	sm.set_shader_parameter("strength", strength)
	sm.set_shader_parameter("y_base", y_top)
	sm.set_shader_parameter("y_extent", h * 0.8)


func reset_growth() -> void:
	growth.clear()
	glow.clear()
	_apply_state()


func set_era_visibility(keys: Array) -> void:
	era_keys = keys
	_apply_state()


func set_clip_to_terrain(on: bool) -> void:
	clip_to_terrain = on
	_apply_state()


## Limit the drawn extent (used for the flat depositional stack so it does not run 7 km out to the bbox walls).
func set_box_clip(on: bool, lo := Vector3.ZERO, hi := Vector3.ZERO) -> void:
	box_clip = on
	box_min = lo
	box_max = hi
	_apply_state()


func set_erosion(level: float, valley_level: float) -> void:
	if level == erosion_level and valley_level == erosion_level_valley:
		return
	erosion_level = level
	erosion_level_valley = valley_level
	for l in layers:
		l["mat"].set_shader_parameter("erosion_level", level)
		l["mat"].set_shader_parameter("erosion_level_valley", valley_level)
		l["shell_mat"].set_shader_parameter("erosion_level", level)


## Thickened display factor currently applied to a layer (1 = true thickness)
func display_factor(key: String) -> float:
	for l in layers:
		if l["key"] == key:
			var t: float = l["info"]["thickness_m"]
			if AppState.thicken_on and t < THIN_LIMIT:
				if tilted and l["info"].has("display_thickness_m"):
					return float(l["info"]["display_thickness_m"]) / t
				return maxf(minf(AppState.thicken_factor, _display_cap(l["info"]) / t), 1.0)
	return 1.0


## Affine transform that scales distances from the layer's base plane by f (along the bedding normal).
## Used for the FLAT stack only (exact there).
func _thicken_transform(base_offset: float, f: float) -> Transform3D:
	if is_equal_approx(f, 1.0):
		return Transform3D.IDENTITY
	var n := bed_normal
	var p0 := Vector3(0.0, plane_c + base_offset * plane_k, 0.0)
	var basis := Basis.IDENTITY
	basis.x += n * (n.x * (f - 1.0))
	basis.y += n * (n.y * (f - 1.0))
	basis.z += n * (n.z * (f - 1.0))
	return Transform3D(basis, p0 - basis * p0)


## Perpendicular offset of the gabbroid lens base above the first-flow base at world x,z (variable thickness).
func lens_base(x: float, z: float) -> float:
	if _lens.is_empty():
		return 85.0
	var su: Array = _lens["strike_unit_xy"]
	var s: float = su[0] * x + su[1] * (-z)
	var u: float = clampf((s - float(_lens["s_sgb"])) / (float(_lens["s_gbr"]) - float(_lens["s_sgb"])), 0.0, 1.0)
	var thick: float = float(_lens["thick_sgb_m"]) + (float(_lens["thick_gbr_m"]) - float(_lens["thick_sgb_m"])) * u
	return float(_lens["top_offset_m"]) - thick


func layer_base(e: Dictionary, x: float, z: float) -> float:
	if e.get("variable", false) and e["key"] == "gabbroid":
		return lens_base(x, z)
	return e["base_offset_m"]


func layer_top(e: Dictionary, x: float, z: float) -> float:
	if e.get("variable", false) and e["key"] == "columnar_zone":
		return lens_base(x, z)
	return layer_base(e, x, z) + e["thickness_m"]


## Down-dip coordinate of world x,z (metres from GBR, positive toward the dip direction).
func fold_u(x: float, z: float) -> float:
	if _fold.is_empty():
		return 0.0
	var o: Array = _fold["origin_xy"]
	var d: Array = _fold["down_dip_unit_xy"]
	return (x - float(o[0])) * float(d[0]) + (-z - float(o[1])) * float(d[1])


## Flexure offset delta(u) (metres) and its slope d delta / d u: piecewise-cosine curve through the control
## points of the manifest (constant beyond the first and last), see scripts/build_volumes.py.
func _delta(u: float) -> Vector2:
	if not _fold_on:
		return Vector2.ZERO
	var cu: Array = _fold["control_u_m"]
	var cd: Array = _fold["control_delta_m"]
	if u >= float(cu[0]):
		return Vector2(float(cd[0]), 0.0)
	for i in range(cu.size() - 1):
		var ua := float(cu[i])
		var ub := float(cu[i + 1])
		if u < ua and u >= ub:
			var L := ua - ub
			var s := (ua - u) / L
			var da := float(cd[i])
			var db := float(cd[i + 1])
			var d := da + (db - da) * (1.0 - cos(PI * s)) / 2.0
			var dd := -(db - da) * PI / (2.0 * L) * sin(PI * s)
			return Vector2(d, dd)
	return Vector2(float(cd[cd.size() - 1]), 0.0)


## Vertical metres per perpendicular metre at world x,z (1 / cos(local dip)).
func k_at(x: float, z: float) -> float:
	if not _fold_on:
		return plane_k
	var g0 := tan(deg_to_rad(float(manifest["plane"]["dip_deg"])))
	var dd := _delta(fold_u(x, z)).y
	return sqrt(1.0 + (-g0 + dd) * (-g0 + dd))


## Local dip (degrees) of the folded reference surface at world x,z.
func dip_at(x: float, z: float) -> float:
	if not _fold_on:
		return float(manifest["plane"]["dip_deg"]) if tilted else 0.0
	var g0 := tan(deg_to_rad(float(manifest["plane"]["dip_deg"])))
	return rad_to_deg(atan(absf(-g0 + _delta(fold_u(x, z)).y)))


## Elevation (true metres) of the reference surface (first-flow base) at world x,z.
func base_elevation(x: float, z: float) -> float:
	return plane_a * x + plane_b * (-z) + plane_c + _delta(fold_u(x, z)).x


## Elevation (true metres) of the surface at perpendicular offset `off` above the first-flow base, at world x,z.
func surface_elevation(off: float, x: float, z: float) -> float:
	return base_elevation(x, z) + off * k_at(x, z)


func layer_at_elevation(x: float, z: float, y: float) -> Dictionary:
	var off: float = (y - base_elevation(x, z)) / k_at(x, z)
	for e in manifest["layers"]:
		if off >= layer_base(e, x, z) and off < layer_top(e, x, z):
			return e
	return {}


func set_highlight(key: String, on: bool) -> void:
	for l in layers:
		if l["key"] == key:
			l["mat"].set_shader_parameter("highlighted", on)


func clear_highlights() -> void:
	for l in layers:
		l["mat"].set_shader_parameter("highlighted", false)


## Outline a layer for the tour introductions. With the cross-section plane on, a bright frame is drawn on the
## cut face along the layer's top and base (its true outline there); without a cut the highlight tint alone is
## used (a shell would wash the whole layer in landscape views). `margin` = line width in world metres.
var _frames := {}   # key -> MeshInstance3D


func set_outline(key: String, on: bool, margin := 3.0) -> void:
	for l in layers:
		if l["key"] != key:
			continue
		l["shell"].visible = false
		if not on:
			if _frames.has(key):
				_frames[key].visible = false
			return
		if AppState.cut_enabled:
			_build_frame(l, margin * 0.35)   # thinner frames (polish pass)


func clear_outlines() -> void:
	for l in layers:
		l["shell"].visible = false
	for k in _frames:
		_frames[k].visible = false


func _frame_node(key: String) -> MeshInstance3D:
	if _frames.has(key):
		return _frames[key]
	var mi := MeshInstance3D.new()
	mi.name = "frame_" + key
	mi.mesh = ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.98, 0.8, 0.95)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.95, 0.6)
	m.emission_energy_multiplier = 1.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	m.render_priority = 20
	mi.material_override = m
	mi.custom_aabb = AABB(Vector3(-7000, -800, -6000), Vector3(14000, 1600, 12000))
	add_child(mi)
	_frames[key] = mi
	return mi


func _build_frame(l: Dictionary, w: float) -> void:
	var key: String = l["key"]
	var e: Dictionary = l["info"]
	var p := AppState.cut_plane
	var n := p.normal
	if absf(n.y) > 0.5:
		return
	var along := n.cross(Vector3.UP).normalized()
	var p0 := n * p.d + n * (w * 0.6 + 0.3)      # on the plane, nudged toward the camera side
	var members: Array = [e]
	if e.has("group"):
		# the whole set (e.g. the six zone A sheets) gets one frame around its envelope
		key = str(e["group"])
		members = []
		for l2 in layers:
			if l2["info"].get("group", "") == e["group"]:
				members.append(l2["info"])
	var mi := _frame_node(key)
	var im: ImmediateMesh = mi.mesh
	im.clear_surfaces()
	var g: float = growth.get(e["key"], 1.0)
	if g <= 0.0:
		mi.visible = false
		return
	var smax := 3600.0
	var step := 30.0
	var top_pts: Array = []
	var base_pts: Array = []
	var segs: Array = []   # [top_pts, base_pts] per contiguous run
	var s := -smax
	while s <= smax:
		var x := p0.x + along.x * s
		var z := p0.z + along.z * s
		var ok := true
		if box_clip and (x < box_min.x or x > box_max.x or z < box_min.z or z > box_max.z):
			ok = false
		var yb := 0.0
		var yt := 0.0
		if ok:
			var base := 1.0e9
			var top := -1.0e9
			for m in members:
				var b0: float = layer_base(m, x, z)
				var f := display_factor(m["key"])
				base = minf(base, b0)
				top = maxf(top, b0 + (layer_top(m, x, z) - b0) * f * g)
			yb = surface_elevation(base, x, z)
			yt = surface_elevation(top, x, z)
			if clip_to_terrain:
				var ground: float = maxf(_terrain.height_at(x, z), erosion_level)
				if yb > ground:
					ok = false
				else:
					yt = minf(yt, ground)
		if ok:
			top_pts.append(Vector3(x, yt, z) + n * 0.0)
			base_pts.append(Vector3(x, yb, z))
		elif not top_pts.is_empty():
			segs.append([top_pts, base_pts])
			top_pts = []
			base_pts = []
		s += step
	if not top_pts.is_empty():
		segs.append([top_pts, base_pts])
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w * 0.5
	for seg in segs:
		var tp: Array = seg[0]
		var bp: Array = seg[1]
		if tp.size() < 2:
			continue
		for i in range(tp.size() - 1):
			_ribbon(im, tp[i] + Vector3(0, hw, 0), tp[i + 1] + Vector3(0, hw, 0), w, n)
			_ribbon(im, bp[i] - Vector3(0, hw, 0), bp[i + 1] - Vector3(0, hw, 0), w, n)
		# end caps
		_ribbon(im, bp[0] - Vector3(0, hw, 0), tp[0] + Vector3(0, hw, 0), w, n)
		var k := tp.size() - 1
		_ribbon(im, bp[k] - Vector3(0, hw, 0), tp[k] + Vector3(0, hw, 0), w, n)
	im.surface_end()
	mi.position = n * (w * 0.6 + 0.3)
	mi.visible = true


## A flat quad of width w from a to b, lying in the cut plane (normal n).
static func _ribbon(im: ImmediateMesh, a: Vector3, b: Vector3, w: float, n: Vector3) -> void:
	var d := (b - a)
	if d.length() < 1.0e-6:
		return
	var side := d.normalized().cross(n).normalized() * (w * 0.5)
	var p1 := a + side
	var p2 := a - side
	var p3 := b - side
	var p4 := b + side
	im.surface_add_vertex(p1)
	im.surface_add_vertex(p2)
	im.surface_add_vertex(p3)
	im.surface_add_vertex(p1)
	im.surface_add_vertex(p3)
	im.surface_add_vertex(p4)


func set_pulse(p: float) -> void:
	for l in layers:
		l["mat"].set_shader_parameter("pulse", p)
		if l["shell"].visible:
			l["shell_mat"].set_shader_parameter("pulse", p)
	for k in _frames:
		var mi: MeshInstance3D = _frames[k]
		if mi.visible:
			mi.material_override.albedo_color.a = 0.55 + 0.45 * p


func set_eroded_ghost(on: bool) -> void:
	eroded_ghost = on
	for l in layers:
		l["mat"].set_shader_parameter("eroded_ghost", on)


var eroded_ghost := false
var chapter_hidden := false   # a chapter that draws its own stage (W) hides the stack; see _process


## Hide the whole stack when nothing of it can show: clipped to an opaque, uncut, uneroded terrain seen from
## above (the landscape chapters). The slabs would otherwise be shaded full-screen and then depth-rejected.
func _process(_dt: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	var hidden := chapter_hidden
	if not hidden and cam != null and clip_to_terrain and not AppState.cut_enabled and not box_clip and not eroded_ghost and erosion_level < -1.0e8 and _terrain != null and not _terrain.ghost and _terrain.visible:
		var cp := cam.global_position
		hidden = cp.y > _terrain.height_at(cp.x, cp.z) * AppState.vexag + 0.5
	if visible == hidden:
		visible = not hidden


func layer_info(key: String) -> Dictionary:
	for l in layers:
		if l["key"] == key:
			return l["info"]
	return {}
