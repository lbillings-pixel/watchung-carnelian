extends Chapter
## Chapter W ("worm's eye"): follow one hypothetical piece of carnelian from its vesicle at 201 Ma to a gravel
## bar today.  A stage east of the study area with its own scales: the nodule is drawn 8 mm while it grows and
## 3 cm once free; the vesicle block and the overburden are schematic; the HILLSIDE IS THE REAL GREEN BROOK VALLEY
## SIDE, a 1:1 lidar swath along a steepest-descent flow line from the highest nearby outcrop of the zone A sheets
## down to the brook at GBR, skinned with the modelled colluvium thickness and cut open along the path so the
## modelled layers show on the wall (the stage straightens the flow line; the profile is the real one).
## Sizes, depths and the order of events are the paper's (sections 4.1-4.3, 5.2-5.3) and the Chatham maps';
## the path, the durations and the schematic parts are Illustrative (A-G16).

const E := Vector3(12500, 0, 0)       # stage centre, east of the bbox (= the brook at GBR on the stage)
const SWATH := 36.0                   # half-width of the hillside swath (m)
const WALL_DEPTH := 30.0              # depth of the cut wall below the surface (m)
var _nodes := {}
var _chunk: Node3D
var _labels: Array = []
var _stage := -1
var _cam_from: Array = [Vector3.ZERO, Vector3.ZERO]   # pose at the last stage change (the blend starts there)
var _cam_blend := 1.0
var _user_cam := false
var _halo: MeshInstance3D
var _water_mat: ShaderMaterial
var _path: PackedVector3Array = PackedVector3Array()   # stage-local surface points from the outcrop to the brook
var _path_len := 0.0
var _src_world := Vector3.ZERO
var _drop := 0.0
var _downstream := 1.0                # +1 / -1 along the stage z axis
var _brook_y := 0.0                   # stage-local brook level
var _pp: PackedVector2Array = PackedVector2Array()    # world xz of the path, outcrop (0) -> brook (last), PATH_STEP apart
var _ptan: PackedVector2Array = PackedVector2Array()  # unit tangents along it, pointing toward the brook
var _path_is_flowline := false        # true when the path is a steepest-descent flow line on the lidar (else straight)
var _bends := 0                       # tangent changes > 15 deg along the flow line
var _brook_name := "the brook"        # NHD name of the stream the flow line reaches
var _brook_dist := 0.0                # distance of that point from the GBR zone centre (m)
var _stream_names: PackedStringArray = PackedStringArray()
const PATH_STEP := 2.0
# stage boundaries on the scrubber
const S_VESICLE := 0.0
const S_BURIAL := 0.15
const S_TILT := 0.3
const S_FREE := 0.45
const S_SLOPE := 0.6
const S_FLOOD := 0.78
const S_BAR := 0.92


func _init() -> void:
	id = "worm"
	title = "W. Worm's-eye view: one piece of carnelian, 201 Ma to today"
	short_title = "W"
	owns_camera = true
	narration = "A single hypothetical nodule, followed from the gas bubble it grew in to the gravel bar where a collector might pick it up: grown in a vesicle of the upper first flow at 201 Ma, buried under the second flow and hundreds of metres of Towaco red beds (90-130 C), tilted 9.5 degrees with the Watchung syncline, exhumed by Miocene-Pleistocene erosion, freed from the weathering outcrop into colluvium, carried down the slope, rolled into the brook by a flood (subangular to subrounded, 1-5.5 cm) and left in a gravel bar on gabbroid pavement. The hillside is the real Green Brook valley side from the lidar, 1:1, along the steepest-descent flow line from the highest nearby outcrop of the zone A sheets down to the brook; the vesicle block and the overburden are schematic."
	basic_narration = "Follow one piece of carnelian: born in a gas bubble in the hot flow, buried deep, tilted, dug out by erosion, dropped down the real Green Brook hillside, rolled by a flood and finally resting in a gravel bar. The camera stays with the piece; drag to look around it."
	refs = "sections 4.1-4.3, 5.2, 5.3; Fig. 3-4; GMS 04-02; OFM 69; lidar DEM"
	strip_from = 201.0e6
	strip_to = 0.0
	scrub_label = "One nodule's path: vesicle -> burial -> tilt -> exhumation -> slope -> flood -> gravel bar"
	scrub_units = "illustrative sequence (the paper gives the order and the sizes, not the durations)"
	scrub_marks = [[S_VESICLE, "201 Ma: grows in a vesicle of the upper flow"], [S_BURIAL, "Buried under >300 m of rock, 90-130 C"], [S_TILT, "Tilted 9.5 deg with the Watchung syncline"], [S_FREE, "Erosion reaches the horizon: weathering frees the nodule"], [S_SLOPE, "Creeps downslope in colluvium on the real valley side"], [S_FLOOD, "Flood: rolled and chipped in the brook"], [S_BAR, "Rests in a gravel bar on gabbroid pavement"]]
	start_pos = E + Vector3(0.05, 0.03, 0.06)
	start_look = E
	evidence = [
		{"text": "Carnelian grew in vesicles (vesicle molds and attachment surfaces), with glauberite before it and botryoidal tops; vesicles 2-10 mm, up to 19 % of vesicle-rich gabbroid intervals.", "ref": "section 4.3, 5.2"},
		{"text": "Burial: second flow (70 m), Preakness to 315 m, Towaco up to ~380 m; Feltville heated to 90-130 C.", "ref": "section 2, 5.3; GMS 04-02"},
		{"text": "Tilt 6-15 degrees on the Watchung syncline limbs, 9.5 degrees at Green Brook on the map section.", "ref": "GMS 04-02"},
		{"text": "Exhumation: Miocene plain above the summits removed in the Pliocene-Pleistocene; valleys cut up to 100 ft after the pre-Illinoian glaciation.", "ref": "section 4.2; OFM 69"},
		{"text": "Colluvium up to 18 m of angular basalt debris in clayey silt-sand; repeated deposition in glacial periods; carnelian also found in slope wash. The hillside here is the lidar surface along a steepest-descent flow line from the modelled outcrop of the zone A sheets to the mapped brook, with the modelled cover thickness (OFM 69 maxima, Illustrative taper).", "ref": "section 4.1; OFM 69; NHD; ASSUMPTIONS A-G8, A-G16"},
		{"text": "Pebbles subangular to subrounded, 1.0-5.5 cm, little abraded (so not far travelled); gravel bars entirely Preakness basalt and gabbroid, on gabbroid pavement; finds continue after decades, so floods keep delivering.", "ref": "section 4.2, 4.3; Fig. 3d-e, 4a"},
	]
	tiers = {"Observed": "Sizes (vesicle, nodule, pebble rounding), thicknesses, temperatures, the dip, the gravel-bar setting; the hillside shape (lidar, 1:1).",
		"Inferred": "That the nodule's source is the upper flow (zone A sheets); the mixing fluids; the flood replenishment; where the sheets meet the surface.",
		"Illustrative": "The vesicle block and overburden, the path, the durations, the colluvium thickness, the channel, bar and water geometry."}
	key_items = [
		{"name": "The followed nodule (8 mm growing, 3 cm free)", "color": Color(0.85, 0.15, 0.06), "tier": "illustrative"},
		{"name": "Gabbroid host rock / vesicle (schematic block)", "color": Color(0.35, 0.33, 0.33), "tier": "observed"},
		{"name": "Overburden (second flow, Towaco; schematic)", "color": Color(0.6, 0.55, 0.55), "tier": "observed"},
		{"name": "Hillside: lidar surface, colluvium (brown) over rock (grey)", "color": Color(0.72, 0.64, 0.48), "tier": "observed"},
		{"name": "Cut wall: modelled layers; red = zone A sheets", "color": Color(0.85, 0.33, 0.3), "tier": "inferred"},
		{"name": "Brook water (cosmetic)", "color": Color(0.3, 0.45, 0.6), "tier": "illustrative"},
	]
	tour_beats = [
		{"t": S_VESICLE, "caption": "201 Ma. Inside a gas bubble 8 mm across in the upper first flow: silica from the mixing fluids builds the nodule, fibre by fibre, over a glauberite crystal."},
		{"t": S_BURIAL, "caption": "The second flow, the rest of the Preakness and the Towaco red beds pile on: the nodule sits several hundred metres down at 90-130 C."},
		{"t": S_TILT, "caption": "The Watchung syncline folds: the rock around the nodule tilts 9.5 degrees to the north-west."},
		{"t": S_FREE, "caption": "Erosion cuts the Green Brook valley down to the horizon. Frost, roots and water loosen the vesicular rock; the nodule falls free at the real outcrop of the sheets."},
		{"t": S_SLOPE, "caption": "It creeps and washes down the real valley side (lidar, 1:1) in basalt colluvium, with angular basalt debris."},
		{"t": S_FLOOD, "caption": "A flood sweeps it into the brook: rolled and chipped to a subangular-subrounded pebble, 1-5.5 cm like the ones collected."},
		{"t": S_BAR, "caption": "The water drops and leaves it in a gravel bar of basalt and gabbroid cobbles on gabbroid pavement, where it can be found."},
	]


func enter(main: Node, animate: bool) -> void:
	super.enter(main, animate)
	main.clear_extras()
	_stage = -1
	_cam_blend = 1.0
	_user_cam = false
	if not main.camera.user_moved.is_connected(_on_user_cam):
		main.camera.user_moved.connect(_on_user_cam)
	_build(main)
	main.camera.set_near(0.001)
	main.volumes.chapter_hidden = true
	main.terrain.visible = false
	main.features.visible = false


func _mat(c: Color, emissive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.5
	return m


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


func _build(main: Node) -> void:
	var ex: Node3D = main.extras
	var stage := Node3D.new()
	stage.name = "stage"
	stage.position = E
	ex.add_child(stage)
	_nodes["stage"] = stage
	# --- vesicle block (rock cube 0.06 m with an 8 mm cavity) ---
	var rock := Node3D.new()
	rock.name = "rock"
	stage.add_child(rock)
	_nodes["rock"] = rock
	var rb := BoxMesh.new()
	rb.size = Vector3(0.06, 0.06, 0.06)
	var rm := _mat(Color(0.35, 0.33, 0.33, 0.3))
	rm.cull_mode = BaseMaterial3D.CULL_FRONT
	_mesh(rock, rb, Vector3.ZERO, rm, "block")
	var cs := SphereMesh.new()
	cs.radius = 0.004
	cs.height = 0.008
	var cm := _mat(Color(0.2, 0.18, 0.18, 0.5))
	cm.cull_mode = BaseMaterial3D.CULL_FRONT
	_mesh(rock, cs, Vector3.ZERO, cm, "cavity")
	var gb := BoxMesh.new()
	gb.size = Vector3(0.0015, 0.006, 0.001)
	var gl := _mesh(rock, gb, Vector3(-0.0012, -0.0004, 0.0008), _mat(Color(0.85, 0.88, 0.8, 0.9)), "glauberite")
	gl.rotation = Vector3(0.3, 0.4, 0.5)
	_nodes["glauberite"] = gl
	# --- overburden: a tall dark column of rock above the block (burial stage) ---
	var ob := BoxMesh.new()
	ob.size = Vector3(0.5, 0.5, 0.5)
	var obn := _mesh(stage, ob, Vector3(0, 0.28, 0), _mat(Color(0.6, 0.55, 0.55, 0.35)), "overburden")
	obn.visible = false
	_nodes["overburden"] = obn
	# --- the real hillside ---
	var hill := Node3D.new()
	hill.name = "hill"
	stage.add_child(hill)
	hill.visible = false
	_nodes["hill"] = hill
	_build_hillside(main, hill)
	# --- the nodule ---
	_chunk = Node3D.new()
	_chunk.name = "nodule_root"
	stage.add_child(_chunk)
	# the nodule: a botryoidal dome while it grows in the vesicle (grown surface, smooth), and a rough
	# subangular piece 3 cm across once it is free (polish pass: Carnelian.gd, carnelian.gdshader)
	var nmat: ShaderMaterial = Carnelian.material(3, 0.004)
	nmat.set_shader_parameter("grain", 0.35)
	nmat.set_shader_parameter("sparkle", 0.5)   # close-up: soft and slow (round 10)
	nmat.set_shader_parameter("sparkle_soft", 1.0)
	var nod := _mesh(_chunk, Carnelian.make_mesh(3, 0.004, 0, 0.35), Vector3.ZERO, nmat, "nodule")
	nod.scale = Vector3(1.0, 0.9, 1.0)
	var bmat: ShaderMaterial = Carnelian.material(8, 0.015)
	bmat.set_shader_parameter("sparkle", 0.5)
	bmat.set_shader_parameter("sparkle_soft", 1.0)
	var bn := _mesh(_chunk, Carnelian.make_mesh(8, 0.015, 5, 1.0), Vector3.ZERO, bmat, "nodule_big")
	bn.visible = false
	_nodes["nodule_big"] = bn
	# a soft glowing halo marks the piece when the camera pulls back (the piece is 3 cm; the wide shot is 35 m)
	var hs := SphereMesh.new()
	hs.radius = 1.0
	hs.height = 2.0
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.albedo_color = Color(1.0, 0.4, 0.08, 0.6)   # mixed, not additive: it must read on the cream slope
	hm.no_depth_test = true
	hm.render_priority = 12
	_halo = _mesh(_chunk, hs, Vector3.ZERO, hm, "halo")
	_halo.visible = false
	_labels = [
		main.make_label("Real valley side (lidar, 1:1) along the flow line from the zone A outcrop to %s, %d m from the GBR zone centre\ncolluvium from the modelled cover field; the wall shows the modelled layers" % [_brook_name, int(_brook_dist)], E + Vector3(-_path_len * 0.5, _drop + 14.0, 12.0), AppState.TIER_COLORS["observed"], 48, 0.4),
		main.make_label("", E, Color(1.0, 0.9, 0.7), 40, 0.02),
	]
	_labels[0].visible = false


## World -> stage-local: the brook at GBR becomes the origin; the path from the outcrop runs along -x; across = z.
func _frame(main: Node) -> Dictionary:
	var g: Vector3 = main.gbr
	var gy: float = main.terrain.height_at(g.x, g.z)
	# source: the outcrop point of any zone A sheet within 500 m that stands highest above the brook (the sheets
	# crop out low on the valley sides here: no trace point around GBR is more than ~12 m above the brook)
	var best := Vector3.INF
	var bscore := -1.0e9
	for off in main.volumes.zone_a_offsets():
		for p in main.zone_outcrop_points(float(off), g, 500.0, 12.0):
			var q: Vector3 = p
			var d := Vector2(q.x - g.x, q.z - g.z).length()
			if d < 40.0:
				continue
			var score := (q.y - gy) - d * 0.002   # prefer height; break ties toward the brook
			if score > bscore:
				bscore = score
				best = q
	if best == Vector3.INF:
		best = g + Vector3(-120.0, 0.0, -90.0)
		best.y = main.terrain.height_at(best.x, best.z)
	_src_world = best
	# the path: a steepest-descent flow line on the lidar from the outcrop down to the brook (round 4); if the
	# descent does not reach brook level near GBR (a pit in the DEM, say) the straight line is used instead
	var streams := _stream_points_near(main, Vector2(g.x, g.z), 1200.0)
	var line := _descend(main, Vector2(best.x, best.z), streams)
	var endp: Vector2 = line[line.size() - 1]
	var d_stream := _min_dist(endp, streams)
	_path_is_flowline = line.size() >= 3 and d_stream < 10.0 and endp.distance_to(Vector2(g.x, g.z)) < 450.0
	_brook_dist = endp.distance_to(Vector2(g.x, g.z))
	# carve the brook channel along the mapped stream where the path meets it (polish pass); the swath and the
	# wall sample height_at, so they show the channel
	var segs: Array = load("res://chapters/Ch7Present.gd").stream_segments(main, Vector3(endp.x, 0.0, endp.y), 60.0)
	main.terrain.set_channels(segs)
	var ni := _nearest_index(endp, streams)
	_brook_name = _stream_names[ni] if (ni >= 0 and ni < _stream_names.size() and _stream_names[ni] != "" and _stream_names[ni] != "unnamed") else "an unnamed NHD stream"
	print("worm flow line: %d steps, reaches %s %.0f m from the GBR zone centre (%.1f m from the NHD line), %.1f m below the outcrop%s" % [line.size(), _brook_name, _brook_dist, d_stream, best.y - main.terrain.height_at(endp.x, endp.y), "" if _path_is_flowline else "; REJECTED, straight path used"])
	if not _path_is_flowline:
		line = PackedVector2Array([Vector2(best.x, best.z), Vector2(g.x, g.z)])
	_resample(line)
	var gb := Vector3(_pp[_pp.size() - 1].x, 0.0, _pp[_pp.size() - 1].y)   # where the path meets the brook
	var gby: float = main.terrain.height_at(gb.x, gb.z)
	var ax: Vector2 = _ptan[_ptan.size() - 1]        # along the path at the brook (stage +x)
	var acr := Vector2(-ax.y, ax.x)                  # across (stage +z)
	# downstream: the across direction along which the brook bed drops
	var ya: float = main.terrain.height_at(gb.x + acr.x * 40.0, gb.z + acr.y * 40.0)
	var yb: float = main.terrain.height_at(gb.x - acr.x * 40.0, gb.z - acr.y * 40.0)
	_downstream = 1.0 if ya <= yb else -1.0
	_drop = best.y - gby
	_brook_y = 0.0
	return {"g": gb, "gy": gby, "ax": ax, "acr": acr}


## NHD stream vertices (world xz) within `radius` of `c`, from the draped stream meshes' pick data (names kept
## in _stream_names, index-aligned).
func _stream_points_near(main: Node, c: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	_stream_names = PackedStringArray()
	var grp: Node = main.features.groups.get("streams", null)
	if grp == null or not grp.has_meta("pick"):
		return out
	for item in grp.get_meta("pick"):
		var nm: String = str(item["info"].get("title", "")).replace("Stream: ", "")
		for q in item["pts"]:
			var v := Vector2(q.x, q.z)
			if v.distance_to(c) < radius:
				out.append(v)
				_stream_names.append(nm)
	return out


static func _nearest_index(p: Vector2, pts: PackedVector2Array) -> int:
	var d := 1.0e9
	var best := -1
	for i in pts.size():
		var dd := p.distance_to(pts[i])
		if dd < d:
			d = dd
			best = i
	return best


static func _min_dist(p: Vector2, pts: PackedVector2Array) -> float:
	var d := 1.0e9
	for q in pts:
		d = minf(d, p.distance_to(q))
	return d


## Steepest descent on the lidar from p0 (world xz), PATH_STEP at a time over 16 directions, until the path is
## within 6 m of a mapped stream line, no neighbour is lower (a pit), or 2 km have been walked.
func _descend(main: Node, p0: Vector2, streams: PackedVector2Array) -> PackedVector2Array:
	var ter: Node = main.terrain
	var pts := PackedVector2Array([p0])
	var p := p0
	var h: float = ter.height_at(p.x, p.y)
	for i in 1000:
		var bestp := p
		var besth := h
		for k in 16:
			var ang := TAU * float(k) / 16.0
			var q := p + Vector2(cos(ang), sin(ang)) * PATH_STEP
			var hq: float = ter.height_at(q.x, q.y)
			if hq < besth - 1.0e-4:
				besth = hq
				bestp = q
		if bestp == p:
			break
		p = bestp
		h = besth
		pts.append(p)
		if not streams.is_empty() and _min_dist(p, streams) < 6.0:
			break
	return pts


## Resample a polyline (world xz) every PATH_STEP along its length into _pp / _ptan; sets _path_len and _bends.
func _resample(line: PackedVector2Array) -> void:
	var total := 0.0
	for i in range(1, line.size()):
		total += line[i - 1].distance_to(line[i])
	_path_len = maxf(total, PATH_STEP)
	_pp = PackedVector2Array()
	_ptan = PackedVector2Array()
	var n := int(ceil(_path_len / PATH_STEP))
	var seg := 0
	var seg_start := 0.0
	for i in n + 1:
		var u := minf(float(i) * PATH_STEP, total)
		while seg < line.size() - 2 and seg_start + line[seg].distance_to(line[seg + 1]) < u:
			seg_start += line[seg].distance_to(line[seg + 1])
			seg += 1
		var a := line[seg]
		var b := line[mini(seg + 1, line.size() - 1)]
		var sl := maxf(a.distance_to(b), 1.0e-6)
		_pp.append(a.lerp(b, clampf((u - seg_start) / sl, 0.0, 1.0)))
		_ptan.append((b - a) / sl)
	# smooth the tangents a little so the swath does not kink at every 2 m step
	var sm := PackedVector2Array()
	for i in _ptan.size():
		var t := Vector2.ZERO
		for k in range(-3, 4):
			t += _ptan[clampi(i + k, 0, _ptan.size() - 1)]
		sm.append(t.normalized() if t.length() > 1.0e-6 else _ptan[i])
	_ptan = sm
	_bends = 0
	for i in range(1, _ptan.size()):
		if _ptan[i - 1].angle_to(_ptan[i]) > deg_to_rad(15.0):
			_bends += 1


## Stage (s_along, s_across) -> world xz. s_along runs from -_path_len (outcrop) to 0 (brook) along the path and
## straight on beyond either end; s_across is measured along the local normal of the path.
func _to_stage(fr: Dictionary, s_along: float, s_across: float) -> Vector3:
	var u := s_along + _path_len
	var base: Vector2
	var tan: Vector2
	var last := _pp.size() - 1
	if u <= 0.0:
		tan = _ptan[0]
		base = _pp[0] + tan * u
	elif u >= _path_len:
		tan = _ptan[last]
		base = _pp[last] + tan * (u - _path_len)
	else:
		var f := u / PATH_STEP
		var i := clampi(int(floor(f)), 0, last - 1)
		base = _pp[i].lerp(_pp[i + 1], f - float(i))
		tan = _ptan[i].lerp(_ptan[i + 1], f - float(i)).normalized()
	var nrm := Vector2(-tan.y, tan.x)
	var w := base + nrm * s_across
	return Vector3(w.x, 0.0, w.y)


func _build_hillside(main: Node, hill: Node3D) -> void:
	var fr := _frame(main)
	var gy: float = fr["gy"]
	var ter: Node = main.terrain
	var vol: Node = main.volumes
	var x0 := -_path_len - 20.0
	var x1 := 30.0
	var step := 2.0
	var nx := int((x1 - x0) / step) + 1
	var nz := int(SWATH * 2.0 / step) + 1
	# surface swath: full width in the brook reach (x > -14), far half (z <= 0) along the hillside path
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for i in nx:
		var row: Array = []
		for j in nz:
			var sx := x0 + i * step
			var sz := -SWATH + j * step
			var w := _to_stage(fr, sx, sz)
			var y: float = ter.height_at(w.x, w.z) - gy
			var cov: float = ter.cover_thickness_at(w.x, w.z)
			row.append([Vector3(sx, y, sz), cov])
		grid.append(row)
	var col_cov := Color(0.72, 0.64, 0.48)
	var col_rock := Color(0.58, 0.6, 0.62)
	var col_bed := Color(0.49, 0.49, 0.49)
	for i in nx - 1:
		for j in nz - 1:
			var sx := x0 + i * step
			var sz := -SWATH + j * step
			if sx < -14.0 and sz >= 0.0:
				continue   # near half removed along the path: the cut wall is drawn at z = 0
			var quad: Array = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
			var p0: Vector3 = quad[0][0]
			var p1: Vector3 = quad[1][0]
			var p3: Vector3 = quad[3][0]
			var nrm := (p1 - p0).cross(p3 - p0).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			for tri in [[0, 1, 2], [0, 2, 3]]:   # clockwise seen from above = front face up
				for k in tri:
					var v: Vector3 = quad[k][0]
					var c: float = quad[k][1]
					var colr := col_cov if c > 0.3 else col_rock
					if sx >= -14.0 and absf(v.y) < 1.2:
						colr = col_bed   # the brook bed: gabbroid pavement
					st.set_color(colr)
					st.set_normal(nrm)
					st.add_vertex(v)
	var smat := StandardMaterial3D.new()
	smat.vertex_color_use_as_albedo = true
	smat.cull_mode = BaseMaterial3D.CULL_DISABLED
	smat.disable_receive_shadows = true
	var surf := MeshInstance3D.new()
	surf.name = "hillside"
	surf.mesh = st.commit()
	surf.material_override = smat
	surf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hill.add_child(surf)

	_path = PackedVector3Array()
	var n := int(_path_len / 1.0)
	for i in n + 1:
		var sx := -_path_len + i * (_path_len / n)
		var w := _to_stage(fr, sx, 0.0)
		_path.append(Vector3(sx, ter.height_at(w.x, w.z) - gy, 0.0))
	# cut wall at z = 0 along the hillside: colluvium over the modelled layers (true thicknesses)
	var wt := SurfaceTool.new()
	wt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dy := 0.25
	var ny := int(WALL_DEPTH / dy) + 1
	var cols: Array = []
	var nwx := int((-14.0 - x0) / step) + 1
	for i in nwx:
		var sx := x0 + i * step
		var w := _to_stage(fr, sx, 0.0)
		var ys: float = ter.height_at(w.x, w.z)
		var cov: float = ter.cover_thickness_at(w.x, w.z)
		var column: Array = []
		for k in ny:
			var y := ys - k * dy
			var colr := col_cov
			if k * dy > cov:
				var e: Dictionary = vol.layer_at_elevation(w.x, w.z, y)
				colr = Color.html(e["color"]) if not e.is_empty() else col_rock
				if e.get("group", "") == "zone_a":
					colr = Color(0.9, 0.25, 0.2)
			column.append([Vector3(sx, y - gy, 0.0), colr])
		cols.append(column)
	for i in nwx - 1:
		for k in ny - 1:
			var q: Array = [cols[i][k], cols[i + 1][k], cols[i + 1][k + 1], cols[i][k + 1]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for m in tri:
					wt.set_color(q[m][1])
					wt.set_normal(Vector3(0, 0, 1))
					wt.add_vertex(q[m][0])
	var wall := MeshInstance3D.new()
	wall.name = "wall"
	wall.mesh = wt.commit()
	var wm := StandardMaterial3D.new()
	wm.vertex_color_use_as_albedo = true
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	wm.disable_receive_shadows = true
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall.material_override = wm
	if cols.size() > 6 and cols[6].size() > 12:
		print("worm wall sample colour at 3 m depth: ", cols[6][12][1])
	hill.add_child(wall)
	# brook: water slab across the stage at the channel level (the carved bed is y = 0 here; the depth test against
	# the swath floods the low banks as the level rises), gravel bar downstream of the entry point with cobbles
	var bar_root := Node3D.new()
	bar_root.name = "bar"
	bar_root.position = Vector3(1.5, 0.0, 12.0 * _downstream)
	hill.add_child(bar_root)
	var bar := SphereMesh.new()
	bar.radius = 4.0
	bar.height = 1.4
	var bmesh := _mesh(bar_root, bar, Vector3.ZERO, _mat(Color(0.46, 0.45, 0.44)), "bar_lens")
	bmesh.scale = Vector3(1.0, 1.0, 0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var cob := MultiMeshInstance3D.new()
	var cmm := MultiMesh.new()
	cmm.transform_format = MultiMesh.TRANSFORM_3D
	cmm.mesh = Carnelian.make_mesh(31, 0.5, 3, 1.0)
	cmm.instance_count = 70
	for i in cmm.instance_count:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 3.7
		var px := cos(ang) * r
		var pz := sin(ang) * r * 0.7
		var sc := 0.08 + rng.randf() * 0.18
		var q := 1.0 - (px * px) / 16.0 - (pz * pz) / 7.84
		var y := 0.7 * sqrt(maxf(q, 0.0)) + sc * 0.3
		var b := Basis.from_euler(Vector3(rng.randf() * 3.0, rng.randf() * 3.0, 0.0)).scaled(Vector3(sc, sc * 0.7, sc * 0.85))
		cmm.set_instance_transform(i, Transform3D(b, Vector3(px, y, pz)))
	cob.multimesh = cmm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.36, 0.37, 0.39)
	cmat.roughness = 0.95
	cob.material_override = cmat
	bar_root.add_child(cob)
	var wb := BoxMesh.new()
	wb.size = Vector3(40, 0.05, SWATH * 2.0)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://shaders/water.gdshader")
	_water_mat.set_shader_parameter("noise_tex", preload("res://scripts/NoiseTex.gd").get_texture())
	_water_mat.set_shader_parameter("ripple_scale", 0.6)
	_water_mat.set_shader_parameter("flow_dir", PI * 0.5 * _downstream)
	_water_mat.set_shader_parameter("depth_scale", 3.0)
	_water_mat.set_shader_parameter("foam_width", 0.1)
	_water_mat.set_shader_parameter("color", Color(0.10, 0.22, 0.28))      # a bluer, darker brook on the stage
	_water_mat.set_shader_parameter("sky_color", Color(0.52, 0.62, 0.72))
	var wn := _mesh(hill, wb, Vector3(0.0, 0.4, 0.0), _water_mat, "water")
	_nodes["water"] = wn


func _surface_y(sx: float) -> float:
	if _path.is_empty():
		return 0.0
	var u := clampf((sx + _path_len) / maxf(_path_len, 0.001), 0.0, 1.0) * (_path.size() - 1)
	var i := clampi(int(floor(u)), 0, _path.size() - 2)
	return lerpf(_path[i].y, _path[i + 1].y, u - i)


func _stage_of(t: float) -> int:
	if t < S_BURIAL:
		return 0
	if t < S_TILT:
		return 1
	if t < S_FREE:
		return 2
	if t < S_SLOPE:
		return 3
	if t < S_FLOOD:
		return 4
	if t < S_BAR:
		return 5
	return 6


func set_t(t: float, main: Node) -> void:
	if _chunk == null:
		return
	var st := _stage_of(t)
	var rock: Node3D = _nodes["rock"]
	var hill: Node3D = _nodes["hill"]
	var ob: MeshInstance3D = _nodes["overburden"]
	var gl: MeshInstance3D = _nodes["glauberite"]
	var big: MeshInstance3D = _nodes["nodule_big"]
	var small: MeshInstance3D = _chunk.get_node("nodule")
	var pos := Vector3.ZERO
	var dist := 0.03
	var info := ""
	rock.visible = st <= 3
	ob.visible = st == 1 or st == 2
	hill.visible = st >= 3
	big.visible = st >= 3
	small.visible = st < 3
	gl.visible = t < 0.1
	rock.rotation.z = 0.0
	rock.position = Vector3.ZERO
	var src := Vector3(-_path_len, _surface_y(-_path_len), 0.0)   # the outcrop on the stage
	match st:
		0:
			var g := ramp(t, 0.02, 0.13)
			_chunk.scale = Vector3(1.0, maxf(g, 0.02), 1.0)
			pos = Vector3(0, -0.0038 + 0.0038 * g, 0)
			dist = 0.03
			info = "vesicle 8 mm; carnelian grows from the floor (Observed textures)"
		1:
			_chunk.scale = Vector3.ONE
			pos = Vector3.ZERO
			dist = 0.03 + 0.6 * ramp(t, S_BURIAL, S_TILT)
			ob.scale = Vector3(1.0, 0.2 + 1.8 * ramp(t, S_BURIAL, S_TILT), 1.0)
			info = "buried under the second flow + Towaco: ~%d m of rock, 90-130 C" % int(50 + 500 * ramp(t, S_BURIAL, S_TILT))
		2:
			_chunk.scale = Vector3.ONE
			pos = Vector3.ZERO
			dist = 0.6
			rock.rotation.z = -deg_to_rad(9.5) * ramp(t, S_TILT, S_FREE)
			ob.rotation.z = rock.rotation.z
			info = "tilt %.1f deg NW (GMS 04-02 section)" % (9.5 * ramp(t, S_TILT, S_FREE))
		3:
			var u := smoothstep(0.0, 1.0, ramp(t, S_FREE, S_SLOPE))   # eased: it works loose, then drops gently
			# the block sits in the wall at the outcrop; the nodule drops out onto the slope
			rock.position = src + Vector3(0.0, -0.3, -0.03)
			rock.rotation.z = -deg_to_rad(9.5)
			pos = src.lerp(src + Vector3(0.6, _surface_y(-_path_len + 0.6) - src.y, 0.05), u)
			pos.y = maxf(pos.y, _surface_y(pos.x) + 0.015)
			_chunk.scale = Vector3.ONE
			dist = 0.5
			info = "freed by weathering at the outcrop of the zone A sheets, %d m above the brook (colluvium here %.1f m)" % [int(_drop), main.terrain.cover_thickness_at(_src_world.x, _src_world.z)]
		4:
			var u := ramp(t, S_SLOPE, S_FLOOD)
			var ue := smoothstep(0.0, 1.0, u)   # eased: starts and ends slowly (the camera pulls back to a wide shot)
			var sx := lerpf(-_path_len + 0.6, -1.5, ue)
			pos = Vector3(sx, _surface_y(sx) + 0.015, 0.05 + 0.3 * ue)
			dist = 0.7
			info = "creeping downslope in colluvium on the real valley side: %d of %d m travelled, %d m lower (Illustrative pace)" % [int(u * _path_len), int(_path_len), int(src.y - pos.y)]
		5:
			var u := ramp(t, S_FLOOD, S_BAR)
			# tumbling just under the flood surface (1.4 m over the bed here; the bed along the brook is not flat,
			# so the flood has to be this deep to cover it) so it stays visible through the muddy water
			pos = Vector3(-1.5, 0.95, 0.35).lerp(Vector3(1.5, 1.25, 12.0 * _downstream), u)
			pos.y += 0.1 * absf(sin(u * 18.0))
			_chunk.rotation = Vector3(u * 12.0, u * 7.0, 0.0)
			dist = 0.7
			info = "flood: rolled and chipped (subangular-subrounded, 1-5.5 cm)"
		6:
			pos = Vector3(1.5, 0.86, 12.0 * _downstream)
			_chunk.rotation = Vector3(0.6, 0.3, 0.0)
			dist = 0.6
			info = "in a gravel bar on gabbroid pavement (Observed setting, Fig. 3d-e)"
	_chunk.position = pos
	if _water_mat:
		var flood := ramp(t, S_FLOOD, S_FLOOD + 0.05) * (1.0 - ramp(t, S_BAR - 0.03, S_BAR))
		_water_mat.set_shader_parameter("turbidity", 0.3 * flood)   # muddy but see-through
		_water_mat.set_shader_parameter("speed", 1.0 + 4.0 * flood)
		var w: MeshInstance3D = _nodes["water"]
		w.position.y = 0.4 + 1.0 * flood   # Illustrative flood: 1 m over the brook
		# sound design (round 7, A-G23; round 8 dropped the drips, cracks and gravel): each stage has its bed
		var amb: Node = main.ambience
		amb.set_level("brook", (0.3 + 0.7 * flood) if st >= 4 else 0.0)
		amb.set_level("rush", flood if st >= 4 else 0.0)
		amb.set_level("shimmer", 1.0 if st == 0 else 0.0)
		amb.set_level("bubble", (ramp(t, 0.02, 0.05) * (1.0 - ramp(t, 0.12, S_BURIAL))) if st == 0 else 0.0)
		amb.set_level("pressure", (0.35 if st == 0 else 0.0) + ((0.4 + 0.6 * ramp(t, S_BURIAL, S_TILT)) if st == 1 else 0.0))
		amb.set_level("grind", 1.0 if st == 2 else 0.0)
		amb.set_level("weather", 1.0 if st == 3 else (0.5 if st == 4 else 0.0))
	_labels[0].visible = st >= 3
	_labels[1].text = info
	_labels[1].position = E + pos + Vector3(0, dist * 0.35, 0)
	_labels[1].pixel_size = dist * 0.0012
	# camera as storyteller (round 7): every stage has its own move (orbit, push-in, the big pull-back on the
	# slope); on a stage change the pose blends over 1.8 s from where the camera was, so a moving piece never
	# runs out of frame; dragging hands the camera to the user until the next stage
	var cam: Node3D = main.camera
	var target: Vector3 = E + pos
	var su := _stage_u(t, st)
	if st != _stage:
		_stage = st
		cam.set_near(0.001 if dist < 0.1 else 0.02)
		_cam_from = [cam.cam.global_position, cam.target]
		_cam_blend = 0.0 if Timeline.playing else 1.0
		_user_cam = false
		_stage_sfx(main, st)
	var want: Array = _stage_pose(st, su, target, dist)
	if _user_cam:
		cam.target = target
		cam._apply_orbit()
	else:
		_cam_blend = minf(_cam_blend + (main.get_process_delta_time() / 1.8 if Timeline.playing else 1.0), 1.0)
		var wgt := smoothstep(0.0, 1.0, _cam_blend)
		var fp: Vector3 = Vector3(_cam_from[0]).lerp(want[0], wgt)
		var fl: Vector3 = Vector3(_cam_from[1]).lerp(want[1], wgt)
		cam.drive(fp, fl)
	if _halo:
		var cd: float = cam.cam.global_position.distance_to(target)
		_halo.visible = cd > 3.0 and st >= 3
		if _halo.visible:
			var r := cd * 0.02 * (0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.004))
			_halo.scale = Vector3.ONE * r / maxf(_chunk.scale.x, 1.0e-6)
			_labels[1].position = E + pos + Vector3(0, maxf(dist * 0.35, cd * 0.1), 0)   # the caption clears the halo


## 0..1 through stage `st` of the scrubber.
func _stage_u(t: float, st: int) -> float:
	var bounds: Array = [[0.0, S_BURIAL], [S_BURIAL, S_TILT], [S_TILT, S_FREE], [S_FREE, S_SLOPE], [S_SLOPE, S_FLOOD], [S_FLOOD, S_BAR], [S_BAR, 1.0]]
	return ramp(t, float(bounds[st][0]), float(bounds[st][1]))


## The camera pose a stage wants at `su` (0..1 through it): [position, look-at].
func _stage_pose(st: int, su: float, target: Vector3, dist: float) -> Array:
	var e := smoothstep(0.0, 1.0, su)
	var off := Vector3(0.8, 0.5, 0.9) * dist if st < 3 else Vector3(0.45, 0.55, 1.0) * dist
	var orbit := 0.0
	var look := target
	match st:
		0:   # the nodule grows: circle it slowly and push in
			orbit = 50.0
			off *= lerpf(1.3, 0.9, e)
		1:   # burial: the view widens with the overburden (dist grows), circling
			orbit = 40.0
		2:   # tilt: circle so the lean reads, climbing a little
			orbit = 35.0
			off.y += 0.25 * dist * e
		3:   # freed: push in on the outcrop as it works loose
			orbit = 25.0
			off *= lerpf(1.2, 0.8, e)
		4:   # the slope: pull back to a wide shot of the whole valley side, hold, then come back in at the brook
			var d := 0.7
			if su < 0.25:
				d = lerpf(0.7, 35.0, smoothstep(0.0, 1.0, su / 0.25))
			elif su < 0.8:
				d = 35.0
			else:
				d = lerpf(35.0, 1.2, smoothstep(0.0, 1.0, (su - 0.8) / 0.2))
			off = Vector3(0.35, 0.6, 0.9) * d
			orbit = 30.0
		5:   # the flood: above the surface, circling the tumbling piece
			off = Vector3(0.5, 1.2, 0.9) * dist
			orbit = 40.0
		6:   # at rest in the bar: circle and settle into a close-up
			orbit = 50.0
			off *= lerpf(1.0, 0.45, e)
	off = off.rotated(Vector3.UP, deg_to_rad(orbit) * e)
	return [target + off, look]


## One-shot cues at the start of a stage.
func _stage_sfx(main: Node, st: int) -> void:
	if not Timeline.playing:
		return
	match st:
		0:
			main.ambience.play("glint")
		2:
			main.ambience.play("thud")
		5:
			main.ambience.play("whoosh_long", -4.0)
		6:
			main.ambience.play("settle")


func _on_user_cam() -> void:
	_user_cam = true


func exit(main: Node) -> void:
	if main.camera.user_moved.is_connected(_on_user_cam):
		main.camera.user_moved.disconnect(_on_user_cam)
	_halo = null
	main.camera.set_near(0.5)
	main.ambience.set_levels(0.0, 0.0)
	main.terrain.set_channels([])
	main.volumes.chapter_hidden = false
	main.terrain.visible = true
	main.features.visible = true
	main.clear_extras()
	_nodes.clear()
	_chunk = null
	_labels.clear()
	_water_mat = null
	_path = PackedVector3Array()
	_pp = PackedVector2Array()
	_ptan = PackedVector2Array()
