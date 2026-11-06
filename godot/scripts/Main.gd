extends Node3D
## Scene root: wires terrain / volumes / features / camera / UI, registers the chapters, handles picking,
## and runs the scripted capture mode (--capture).

@onready var world: Node3D = $World
@onready var terrain: Node3D = $World/Terrain
@onready var volumes: Node3D = $World/Volumes
@onready var features: Node3D = $World/Features
@onready var extras: Node3D = $World/Extras
@onready var camera: Node3D = $CameraRig
@onready var ui: CanvasLayer = $UI

const CHAPTER_SCRIPTS := [
	"res://chapters/Ch1Basement.gd", "res://chapters/Ch2Feltville.gd", "res://chapters/Ch3Eruption.gd",
	"res://chapters/Ch4Precipitation.gd", "res://chapters/Ch5Burial.gd", "res://chapters/Ch6Erosion.gd",
	"res://chapters/Ch7Present.gd", "res://chapters/Ch8Worm.gd",
]
var tour: Node
var ambience: Node
var _pulse_t := 0.0

var hover_info := {}
var hover_enabled := true   # hover pop-ups: off under the guided tour, the capture, or by the user's toggle
var _hover_timer := 0.0
var ruled_out_on := false:
	set(v):
		ruled_out_on = v
		_update_ruled_out()
var _ruled_out_nodes: Array = []
var gbr: Vector3
var sgb: Vector3


func _ready() -> void:
	camera.terrain = terrain
	Timeline.main = self
	gbr = features.site_centers.get("GBR", Vector3(426, 100, -1224))
	sgb = features.site_centers.get("SGB", Vector3(-2941, 90, 1017))
	for p in CHAPTER_SCRIPTS:
		var s: Script = load(p)
		Timeline.register(s.new())
	AppState.changed.connect(_on_state)
	_on_state()
	tour = load("res://scripts/Tour.gd").new()
	tour.name = "Tour"
	add_child(tour)
	tour.setup(self)
	ambience = load("res://scripts/Ambience.gd").new()
	ambience.name = "Ambience"
	add_child(ambience)
	ambience.setup(self)
	ui.setup(self)
	for n in features.find_children("*", "GeometryInstance3D", true, false):
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # rings and names must not shadow the slabs
	hover_enabled = AppState.hover_info
	AppState.changed.connect(func(): if not tour.on: hover_enabled = AppState.hover_info)
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		var cap: Node = load("res://scripts/Capture.gd").new()
		add_child(cap)
		cap.start(self)
	elif "--movie" in args:
		# the tour as a film (scripts/render_tour.py runs this under --write-movie): basic mode, narration,
		# subtitles and ambience on, no intro, no hover; the tour starts at chapter 1 and the app quits at its end
		AppState.ui_mode = "basic"
		AppState.narration_on = true
		AppState.subtitles_on = true
		AppState.ambience_on = true
		hover_enabled = false
		ui.intro_screen.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		tour.state_changed.connect(func():
			if not tour.on and Timeline.current == Timeline.chapters.size() - 1:
				get_tree().create_timer(2.0).timeout.connect(func(): get_tree().quit()))
		get_tree().create_timer(1.5).timeout.connect(func(): tour.start(0))
	elif "--smoke" in args:
		var sm: Node = load("res://tests/smoke.gd").new()
		add_child(sm)
		sm.start(self)
	else:
		Timeline.go_to_chapter(0, false)
		if not bool(AppState.get_pref("skip_intro", false)):
			ui.show_intro()


func _on_state() -> void:
	world.scale.y = AppState.vexag
	terrain.set_cover_skin(AppState.cover_skin)


func _unhandled_input(event: InputEvent) -> void:
	if tour.on:
		return   # no pop-ups while the narrated tour runs (the user asked for an uncluttered screen)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var info: Dictionary = pick_at(event.position)
		if not info.is_empty():
			AppState.selected = info
			ui.show_info(info, event.position, true)
	elif event is InputEventMouseMotion and hover_enabled:
		_hover_timer = 0.12


func _process(dt: float) -> void:
	_update_labels()
	var cp: Vector3 = camera.cam.global_position
	terrain.set_camera_underground(terrain.visible and cp.y < terrain.height_at(cp.x, cp.z) * AppState.vexag)
	_pulse_t += dt
	var pulse := 0.5 + 0.5 * sin(_pulse_t * 2.6)   # softer pulse (polish pass)
	volumes.set_pulse(pulse)
	terrain.set_pulse(pulse)
	for sh in _shells:
		if is_instance_valid(sh):
			sh.material_override.set_shader_parameter("pulse", pulse)
	if _hover_timer > 0.0:
		_hover_timer -= dt
		if _hover_timer <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			var pos := get_viewport().get_mouse_position()
			var info: Dictionary = pick_at(pos)
			ui.show_info(info, pos, false)


## Everything the user can point at, in priority order: Mindat markers, sample sites, line features,
## subsurface layer (if the ray meets a layer before the ground, or the camera is underground), ground.
func pick_at(screen_pos: Vector2) -> Dictionary:
	var cam: Camera3D = camera.cam
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var vex := AppState.vexag
	# ground hit by ray march
	var p := from
	var ground_hit := Vector3.INF
	var step := maxf(2.0, (from.y - terrain.height_at(from.x, from.z) * vex) * 0.01)
	var below_start: bool = from.y < terrain.height_at(from.x, from.z) * vex
	for i in 4000:
		p += dir * step
		if absf(p.x) > 7100.0 or absf(p.z) > 6100.0:
			if not below_start:
				break
		var g: float = terrain.height_at(p.x, p.z) * vex
		if (not below_start and p.y <= g) or (below_start and p.y >= g):
			ground_hit = p
			break
	# markers
	for mp in features.mindat_points:
		if features.groups["mindat"].visible and _ray_dist(from, dir, mp["pos"]) < mp["radius"] * 0.5:
			return mp["info"]
	for code in features.site_centers:
		var c: Vector3 = features.site_centers[code]
		if features.groups["sites"].visible and _ray_dist(from, dir, c) < 300.0:
			return features.groups["sites"].get_node(code).get_meta("info")
	var line_info: Dictionary = features.pick(from, dir)
	if not line_info.is_empty():
		return line_info
	# subsurface: step along the ray through the layers until the ground (or 3 km) and report the first layer entered
	var q := from
	var layer_info := {}
	var reach := 3000.0 if below_start else (ground_hit.distance_to(from) if ground_hit != Vector3.INF else 0.0)
	var s := 0.0
	while s < reach:
		q = from + dir * s
		var g: float = terrain.height_at(q.x, q.z) * vex
		if q.y < g:
			var e: Dictionary = volumes.layer_at_elevation(q.x, q.z, q.y / vex)
			if not e.is_empty() and AppState.is_layer_visible(e["key"]):
				layer_info = _layer_info(e, q)
				break
		s += 5.0
	if below_start and not layer_info.is_empty():
		return layer_info
	if ground_hit != Vector3.INF:
		var bu: String = terrain.bedrock_unit_at(ground_hit.x, ground_hit.z)
		var sc: String = terrain.surficial_class_at(ground_hit.x, ground_hit.z)
		var bname: String = terrain.unit_ids["bedrock"].get(bu, {}).get("name", bu)
		var sname: String = terrain.unit_ids["surficial"].get(sc, {}).get("name", "(unmapped)")
		var cov: float = terrain.cover_thickness_at(ground_hit.x, ground_hit.z)
		var below: Dictionary = volumes.layer_at_elevation(ground_hit.x, ground_hit.z, ground_hit.y / vex - 1.0 - cov)
		return {"title": "Ground: %s" % bname, "tier": "observed",
			"body": "Elevation %.0f m. Mapped bedrock unit %s (NJGWS 1:24k, Observed). Surficial cover: %s (OFM 69, Observed extent); modelled cover thickness here %.1f m (Illustrative taper of the OFM 69 maximum, A-G8).\nModelled layer just below the cover: %s (%s)." % [ground_hit.y / vex, bu, sname, cov, below.get("name", "-"), AppState.tier_name(below.get("tier", ""))],
			"ref": "NJGWS DGS15-1 / DGS10-2; paper Fig. 2, section 4.1", "pos": ground_hit}
	return layer_info


func _layer_info(e: Dictionary, at: Vector3) -> Dictionary:
	var base_here: float = volumes.layer_base(e, at.x, at.z)
	var top_here: float = volumes.layer_top(e, at.x, at.z)
	var tilt_note := "" if volumes.tilted else "; shown UNTILTED here (beds were flat at deposition; today's tilt came with the later folding)"
	var dip_note := ""
	if volumes.tilted:
		dip_note = "; local dip of the modelled surface here %.1f deg (9.5 deg from the GMS 04-02 section at the sample reaches, gently flexed between them and the Feltville valley so that all three mapped contact traces are honoured, ASSUMPTIONS A-G4)" % volumes.dip_at(at.x, at.z)
	return {"title": e["name"], "tier": e["tier"], "key": e["key"],
		"body": "%s\nTrue thickness here %s m (base %.1f m above the first-flow base). Modelled as a bedding-parallel slab%s%s. At this point the layer's top is at %.0f m elevation." % [e["note"], _fmt(top_here - base_here), base_here, dip_note, tilt_note, volumes.surface_elevation(top_here, at.x, at.z)],
		"ref": e["refs"], "pos": at}


static func _fmt(v: float) -> String:
	return ("%.3f" % v) if v < 0.1 else (("%.1f" % v) if v < 10.0 else ("%.0f" % v))


func _ray_dist(o: Vector3, d: Vector3, p: Vector3) -> float:
	var t := (p - o).dot(d)
	if t < 0.0:
		return 1.0e9
	return (o + d * t).distance_to(p)


## Ruled-out sources overlay (paper section 4.2)
const RULED_OUT := [
	["Imported through trade", "Carnelian would be more widespread, pieces show no working, and the Lenape lithic record has chert, flint and jasper but no carnelian.", "section 4.2"],
	["A sedimentary source", "No carnelian nodules or siliceous layers in any Newark basin sedimentary formation (outcrop or drill core); no carnelian clasts in conglomerates; no sedimentary remnants in the carnelian gravels.", "section 4.2"],
	["Orange Mountain Basalt", "Not recognised there despite a quarry exposing the whole formation <2 km SE; the deep Feltville valley formed before the carnelian valleys, so nothing from Orange Mountain or Feltville could reach them.", "section 4.2"],
	["Glacial transport", "Sites lie south of the Wisconsinan terminal moraine and outside glacial lakes; Stirling Brook is south of the early Pleistocene limit with no erratics; the glaciated NE Green Brook tributary has till but no carnelian.", "section 4.1, 4.2"],
	["The Miocene regional river", "Its plain lay at or above the summits, >50 m above the sites; its gravel was wholly removed in Pliocene-Pleistocene valley cutting; pieces are too little abraded for long transport.", "section 4.2"],
]


func _update_ruled_out() -> void:
	for n in _ruled_out_nodes:
		n.queue_free()
	_ruled_out_nodes.clear()
	if not ruled_out_on:
		return
	# 3D markers: Orange Mountain ridge, Feltville valley, moraine/till, Miocene plain, trade (at sites)
	var marks := [
		[Vector3(3200, 0, 2600), "Orange Mountain Basalt (Jo): ruled out", AppState.TIER_COLORS["observed"]],
		[Vector3(1800, 0, 1300), "Feltville valley formed first: blocks Jo/Jf input", AppState.TIER_COLORS["inferred"]],
		[Vector3(1500, 0, -4200), "Glaciated ground: till, no carnelian", AppState.TIER_COLORS["observed"]],
		[gbr, "Trade import: ruled out (unworked pieces, tiny area)", AppState.TIER_COLORS["inferred"]],
	]
	for m in marks:
		var lbl := Label3D.new()
		var p: Vector3 = m[0]
		lbl.text = m[1]
		lbl.position = Vector3(p.x, terrain.height_at(p.x, p.z) + 120.0, p.z)
		lbl.font_size = 72
		lbl.pixel_size = 0.9
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.modulate = m[2]
		lbl.outline_size = 18
		extras.add_child(lbl)
		_ruled_out_nodes.append(lbl)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(14000, 12000)
	plane.mesh = pm
	plane.position = Vector3(0, 185.0, 0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.9, 0.75, 0.4, 0.18)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material_override = mat
	extras.add_child(plane)
	_ruled_out_nodes.append(plane)
	var lbl2 := Label3D.new()
	lbl2.text = "Miocene river plain (Illustrative level, 185 m): ruled out as a source"
	lbl2.position = Vector3(-3000, 215, 3000)
	lbl2.font_size = 72
	lbl2.pixel_size = 0.9
	lbl2.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl2.no_depth_test = true
	lbl2.modulate = AppState.TIER_COLORS["illustrative"]
	lbl2.outline_size = 18
	extras.add_child(lbl2)
	_ruled_out_nodes.append(lbl2)


## Helper for chapters: a Label3D in the world. Labels scale with camera distance (see _update_labels)
## so they stay ~14 px tall whatever the scale.  Polish pass: each label has a distance band (meta "max_dist",
## derived from its natural scale: close-up labels vanish once the camera is far from them; landscape labels
## never do) and labels that would overlap on screen yield to the nearer one; both fade rather than pop.
var labels: Array = []


func register_label(l: Label3D) -> void:
	labels.append(l)
	if not l.has_meta("base_mod"):
		l.set_meta("base_mod", l.modulate)
	if not l.has_meta("max_dist"):
		l.set_meta("max_dist", 1.0e12)


func _update_labels() -> void:
	var cam: Camera3D = camera.cam
	var cp: Vector3 = cam.global_position
	var k := tan(deg_to_rad(cam.fov) * 0.5) * 2.0 * 14.0 / 900.0
	var order: Array = []
	for i in range(labels.size() - 1, -1, -1):
		var l = labels[i]
		if not is_instance_valid(l) or l.is_queued_for_deletion():
			labels.remove_at(i)
			continue
		var d := cp.distance_to(l.global_position)
		var ps := maxf(d * k / float(l.font_size), 0.00002)
		if absf(ps - l.pixel_size) > ps * 0.01:
			l.pixel_size = ps
		order.append([d, l])
	order.sort_custom(func(a, b): return a[0] < b[0])
	var placed: Array = []   # screen rects of the labels kept
	var dt := get_process_delta_time()
	for it in order:
		var d: float = it[0]
		var l: Label3D = it[1]
		var want := 1.0
		if d > float(l.get_meta("max_dist", 1.0e12)) or not l.visible:
			want = 0.0
		elif cam.is_position_behind(l.global_position):
			want = 0.0
		else:
			var sp := cam.unproject_position(l.global_position)
			var lines: PackedStringArray = l.text.split("\n")
			var longest := 0
			for ln in lines:
				longest = maxi(longest, ln.length())
			var r := Rect2(sp - Vector2(longest * 3.6, lines.size() * 8.0), Vector2(longest * 7.2, lines.size() * 16.0))
			for pr in placed:
				if r.intersects(pr):
					want = 0.0
					break
			if want > 0.0:
				placed.append(r)
		var base: Color = l.get_meta("base_mod", l.modulate)
		var a := move_toward(l.modulate.a, want * base.a, dt * 4.0)
		l.modulate = Color(base.r, base.g, base.b, a)
		l.outline_modulate.a = a


func make_label(text: String, pos: Vector3, color: Color, size := 64, pixel := 0.8) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = pixel
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = color
	l.outline_size = 16
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # text must not shadow the slabs
	# distance band from the label's natural scale: landscape labels (pixel >= 0.8) always, others up to
	# 5000 x their pixel size in metres (a 0.08 close-up label dies 400 m out)
	l.set_meta("max_dist", 1.0e12 if pixel >= 0.8 else pixel * 5000.0)
	register_label(l)
	extras.add_child(l)
	return l


func clear_extras() -> void:
	clear_outlines()
	for c in extras.get_children():
		if not _ruled_out_nodes.has(c):
			extras.remove_child(c)   # at once, so a chapter re-entered in the same frame can reuse its node names
			c.queue_free()


## ---- glowing shells for the tour's cues (presentation only) ----
var _shells: Array = []
var _shell_shader: Shader
var _shell_color := Color(0.6, 0.95, 1.0)   # scene objects: cool white-cyan; layers get gold frames; places an orange ring


## Wrap every mesh under the named nodes in a glowing shell. Names are looked up under Extras first (any depth),
## then as a Features group ("features:<group>" also works). `margin` is the outward push in world metres.
func outline_nodes(names: Array, margin: float, color := Color(0.6, 0.95, 1.0)) -> void:
	if _shell_shader == null:
		_shell_shader = load("res://shaders/outline.gdshader")
	_shell_color = color
	for nm in names:
		var n: Node = null
		var s := str(nm)
		if s.begins_with("features:"):
			n = features.groups.get(s.substr(9), null)
		else:
			n = extras.find_child(s, true, false)
			if n == null and features.groups.has(s):
				n = features.groups[s]
		if n == null:
			continue
		_shell_tree(n, margin)


func _shell_tree(n: Node, margin: float) -> void:
	# the shell's outward push is capped by the entity's own size (a 5 cm pebble must not wear a 20 cm halo)
	if n is MeshInstance3D and n.name != "shell" and n.visible and n.mesh != null:
		var sz: float = n.mesh.get_aabb().get_longest_axis_size() * n.global_transform.basis.get_scale().x
		var sh := MeshInstance3D.new()
		sh.name = "shell"
		sh.mesh = n.mesh
		sh.material_override = _shell_material(minf(margin, sz * 0.15))
		sh.custom_aabb = n.custom_aabb
		n.add_child(sh)
		_shells.append(sh)
	elif n is MultiMeshInstance3D and n.name != "shell" and n.visible and n.multimesh != null and n.multimesh.mesh != null:
		var isc: float = n.multimesh.get_instance_transform(0).basis.get_scale().x if n.multimesh.instance_count > 0 else 1.0
		var sz: float = n.multimesh.mesh.get_aabb().get_longest_axis_size() * isc * n.global_transform.basis.get_scale().x
		var sh := MultiMeshInstance3D.new()
		sh.name = "shell"
		sh.multimesh = n.multimesh
		sh.material_override = _shell_material(minf(margin, sz * 0.15))
		sh.custom_aabb = n.custom_aabb
		n.add_child(sh)
		_shells.append(sh)
	for c in n.get_children():
		if c.name != "shell":
			_shell_tree(c, margin)


func _shell_material(margin: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shell_shader
	m.set_shader_parameter("margin", margin)
	m.set_shader_parameter("color", _shell_color)
	m.set_shader_parameter("strength", 0.6)
	m.set_shader_parameter("cut_enabled", false)
	m.set_shader_parameter("clip_to_terrain", false)
	m.render_priority = 10
	return m


func clear_outlines() -> void:
	for sh in _shells:
		if is_instance_valid(sh):
			sh.queue_free()
	_shells.clear()


## Outcrop trace of the horizon at perpendicular offset `off` as line segments (marching squares on the field
## ground - surface over a grid of `step` m): pairs of world points, draped on the ground. Polish pass: replaces
## the dot cloud of zone_outcrop_points for drawing.
func zone_outcrop_segments(off: float, center: Vector3, radius: float, step := 16.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := int(radius * 2.0 / step) + 1
	var f: Array = []
	for i in n:
		var row := PackedFloat32Array()
		for j in n:
			var x := center.x - radius + i * step
			var z := center.z - radius + j * step
			row.append(terrain.height_at(x, z) - volumes.surface_elevation(off, x, z))
		f.append(row)
	for i in n - 1:
		for j in n - 1:
			var x0 := center.x - radius + i * step
			var z0 := center.z - radius + j * step
			if Vector2(x0 + step * 0.5 - center.x, z0 + step * 0.5 - center.z).length() > radius:
				continue
			var v := [f[i][j], f[i + 1][j], f[i + 1][j + 1], f[i][j + 1]]   # corners: (0,0) (1,0) (1,1) (0,1)
			var pts: Array = []
			var corners := [Vector2(x0, z0), Vector2(x0 + step, z0), Vector2(x0 + step, z0 + step), Vector2(x0, z0 + step)]
			for e in 4:
				var a: float = v[e]
				var b: float = v[(e + 1) % 4]
				if (a < 0.0) != (b < 0.0):
					var t := a / (a - b)
					var pa: Vector2 = corners[e]
					var pb: Vector2 = corners[(e + 1) % 4]
					pts.append(pa.lerp(pb, t))
			if pts.size() >= 2:
				for q in [pts[0], pts[1]]:
					out.append(Vector3(q.x, terrain.height_at(q.x, q.y), q.y))
				if pts.size() == 4:
					for q in [pts[2], pts[3]]:
						out.append(Vector3(q.x, terrain.height_at(q.x, q.y), q.y))
	return out


## Points on today's surface, within `radius` of `center`, where the bedding-parallel surface at perpendicular
## offset `off` above the first-flow base meets the ground (the outcrop trace of that horizon). Grid step in m.
func zone_outcrop_points(off: float, center: Vector3, radius: float, step := 16.0) -> Array:
	var out: Array = []
	var n := int(radius * 2.0 / step)
	for i in n:
		for j in n:
			var x := center.x - radius + i * step
			var z := center.z - radius + j * step
			if Vector2(x - center.x, z - center.z).length() > radius:
				continue
			var gy: float = terrain.height_at(x, z)
			var sy: float = volumes.surface_elevation(off, x, z)
			if absf(gy - sy) < 2.5:
				out.append(Vector3(x, gy, z))
	return out
