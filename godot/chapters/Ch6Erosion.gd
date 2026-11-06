extends Chapter
## Chapter 6: folding, uplift and erosion to the modern landscape, and where the carnelian goes.
## Source: section 4.1, 4.2; GMS 04-02 (Watchung syncline, limbs 6-15 deg, section A-A' 9.5 deg at Green Brook).
## t 0-0.12: the flat stack tilts to today's attitude (attitude Observed, timing Illustrative).
## t 0.12-1: a flat Illustrative plain descends; the Feltville valley leads; once the carnelian horizon is
## breached beside Green Brook, pieces weather out and travel downslope into the brook (Illustrative tracker).

var _plain: MeshInstance3D
var _plain_mat: StandardMaterial3D
var _label: Label3D
var _pebbles: Array = []      # {node, start, end, y_free}
var _pebble_root: Node3D
var _trace: Node3D
var _cut_normal := Vector3(0.65, 0.0, -0.76).normalized()
var _cut_by_us := false
var _thud_done := false
const PLAIN_Z := 185.0
const TILT_END := 0.12


func _init() -> void:
	id = "erosion"
	title = "6. Tilting, uplift and erosion"
	short_title = "6"
	narration = "Folding of the Watchung syncline tilts the whole stack about 9.5 degrees to the north-west (the attitude is read from the Chatham map's cross-section; when it happened is not part of the paper). Uplift follows. In the middle-late Miocene a regional river plain lay at or above the highest basalt summits, more than 50 m above today's carnelian sites. Pliocene-Pleistocene valley cutting removed it entirely: first the deep valley on the soft Feltville between the Orange Mountain and Preakness ridges, and only later the carnelian valleys, cut by headwater tributaries that never received Orange Mountain or Feltville material. Where the valley side at Green Brook cuts the carnelian horizon, pieces weather out and move downslope into the brook."
	basic_narration = "The stack is tilted 9.5 degrees and lifted; rivers then strip hundreds of metres of rock. The deep valley on the soft Feltville forms first; later the small brooks cut back into the Preakness ridge. When the Green Brook valley side reaches the carnelian horizon, red pebbles weather out and creep and wash down into the brook."
	refs = "section 4.1; section 4.2 [39]; GMS 04-02 structure note and section A-A'"
	strip_from = 150.0e6
	strip_to = 2.0e6
	scrub_label = "Tilting -> Miocene river plain -> Pliocene-Pleistocene valley cutting -> today's surface"
	scrub_units = "illustrative sequence (epoch placement only)"
	scrub_marks = [[0.0, "Watchung syncline folding: stack tilts 9.5 deg NW"], [0.12, "Miocene plain at/above summits (>50 m above sites)"], [0.35, "Feltville valley cut first"], [0.45, "Carnelian valleys cut as headwater tributaries; the horizon is reached"], [0.6, "Carnelian weathers out and moves into Green Brook"], [1.0, "Today's surface"]]
	start_pos = Vector3(3500, 3200, 6500)
	start_look = Vector3(0, 60, -500)
	evidence = [
		{"text": "Both limbs of the Watchung syncline dip gently, 6 to 15 degrees; the map's cross-section draws the Preakness and Feltville contacts at 9.3-9.7 degrees through the Green Brook reach, steepening to 13-14 degrees toward First Watchung Mountain. The model keeps 9.5 degrees at both sample reaches and flexes gently (3.5-13.8 degrees) between them and the Feltville valley so that all three mapped contact traces are honoured.", "ref": "GMS 04-02 structure note and section A-A' (read; measured in scripts/measure_gms_section.py); ASSUMPTIONS A-G4"},
		{"text": "Neogene fluvial gravels (quartz, quartzite, chert) in uplands south of the basalts record a middle-late Miocene river draining south across NE New Jersey.", "ref": "section 4.2 [39]"},
		{"text": "That river plain was at or above the highest basalt summits and >50 m above the carnelian locations; its gravel would have been wholly eroded during Pliocene-Pleistocene valley formation; none is found on the basalt uplands.", "ref": "section 4.2"},
		{"text": "The Feltville valley between the Orange Mountain and Preakness ridges formed first; the carnelian valleys were cut later by headwater tributaries that could not receive Orange Mountain or Feltville material.", "ref": "section 4.1, 4.2"},
		{"text": "After the pre-Illinoian glaciation, valleys were cut as much as 100 ft below the level at which that till was deposited.", "ref": "OFM 69 text (read)"},
		{"text": "Carnelian occurs in gravel bars and, at Stirling Brook, in slope wash: it reaches the brooks from the valley sides (colluvium up to 18 m).", "ref": "section 4.1"},
	]
	tiers = {"Observed": "Today's terrain (lidar), the dip (map section), the gravel composition, the colluvium.",
		"Inferred": "The order: Feltville valley first, carnelian valleys later; the Miocene plain above the summits.",
		"Illustrative": "When the tilting happened; the flat plain at 185 m; the descending erosion surfaces; the pebble tracker paths; all rates and the epoch placement on the strip."}
	key_items = [
		{"name": "Illustrative paleo-surface (descending plain)", "color": Color(0.85, 0.7, 0.4), "tier": "illustrative"},
		{"name": "Carnelian horizon trace (zone A sheets meet today's surface near GBR)", "color": Color(1.0, 0.3, 0.1), "tier": "inferred", "shape": "line"},
		{"name": "Carnelian pieces moving downslope (tracker)", "color": Color(0.85, 0.15, 0.06), "tier": "illustrative"},
	]


func enter(main: Node, animate: bool) -> void:
	var g: Vector3 = main.gbr
	var gy: float = main.terrain.height_at(g.x, g.z)
	var zone_a: Array = main.volumes.zone_a_keys()
	tour_beats = [
		beat(0.0, "Folding of the Watchung syncline tilts the stack 9.5 degrees to the NW (attitude from the Chatham map section; timing not given). The cut face through GBR shows the beds turning.", Vector3(g.x, 40.0, g.z) + _cut_normal * 3200.0 + Vector3(0, 420, 0), Vector3(g.x, 40.0, g.z), [], {"cut": true, "move": {"orbit": 25.0, "dolly": [1.2, 0.9]}}),
		beat(0.12, "Middle-late Miocene: a regional river plain lies at or above the summits, more than 50 m above the future carnelian sites.", Vector3(g.x, 100.0, g.z) + _cut_normal * 3200.0 + Vector3(0, 520, 0), Vector3(g.x, 100.0, g.z), [], {"cut": true}),
		beat(0.3, "Pliocene-Pleistocene: the deep valley on the soft Feltville is cut first, between the two basalt ridges.", Vector3(4200, 2200, 4800), Vector3(1500, 100, 500), [], {"cut": false, "move": {"orbit": 22.0, "rise": 400.0, "dolly": [1.0, 0.85]}}),
		beat(0.45, "Headwater tributaries (Green Brook, Stirling Brook) cut back into the Preakness ridge; the valley sides reach the carnelian horizon (the zone A sheets, pulsing).", g + Vector3(1500, 1100, 1700), Vector3(g.x, 150.0, g.z), zone_a, {"ring": [g, 450.0], "move": {"dolly": [1.5, 0.9], "orbit": 15.0}}),
		beat(0.6, "Pieces of carnelian weather out along the horizon and creep and wash downslope into Green Brook (Illustrative tracker; red dots mark where the sheets meet today's surface).", g + Vector3(650, 420, 750), Vector3(g.x, 140.0, g.z), zone_a, {"ring": [g, 300.0], "move": {"dolly": [1.3, 0.7], "orbit": 20.0}}),
		beat(0.97, "Today's surface (lidar). The carnelian horizon still runs through the valley sides, beneath colluvium and alluvium.", g + Vector3(900, 700, 1100), Vector3(g.x, gy, g.z), zone_a, {"move": {"dolly": [0.7, 1.5], "rise": 350.0, "orbit": 15.0}}),
	]
	super.enter(main, animate)
	main.clear_extras()
	main.volumes.set_clip_to_terrain(true)
	main.volumes.set_box_clip(false)
	main.terrain.set_ghost(true)
	main.volumes.set_era_visibility([])
	AppState.cut_plane = Plane(_cut_normal, _cut_normal.dot(g))
	AppState.cut_enabled = true
	_cut_by_us = true
	_thud_done = false
	_plain = MeshInstance3D.new()
	_plain.name = "plain"
	var pm := PlaneMesh.new()
	pm.size = Vector2(14000, 12000)
	_plain.mesh = pm
	_plain_mat = StandardMaterial3D.new()
	_plain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_plain_mat.albedo_color = Color(0.85, 0.7, 0.4, 0.45)
	_plain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_plain.material_override = _plain_mat
	main.extras.add_child(_plain)
	_label = main.make_label("", Vector3(-2000, PLAIN_Z + 120, 2500), AppState.TIER_COLORS["illustrative"], 64, 1.2)
	_build_tracker(main)


## The outcrop traces of the zone A sheets on today's surface around GBR as traced lines (marching squares on
## the ground-minus-horizon field, drawn as flat ribbons `width` m wide; polish pass), plus the points a pebble
## can start from.
static func build_trace(main: Node, center: Vector3, radius: float, width: float) -> Array:
	var pts: Array = []
	var trace := Node3D.new()
	trace.name = "trace"
	main.extras.add_child(trace)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.32, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.3, 0.1)
	mat.emission_energy_multiplier = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for off in main.volumes.zone_a_offsets():
		var segs: PackedVector3Array = main.zone_outcrop_segments(float(off), center, radius, 12.0)
		for i in range(0, segs.size() - 1, 2):
			var a: Vector3 = segs[i] + Vector3(0, 0.6, 0)
			var b: Vector3 = segs[i + 1] + Vector3(0, 0.6, 0)
			var d := b - a
			if d.length() < 0.01:
				continue
			pts.append(segs[i])
			var side := Vector3(-d.z, 0.0, d.x).normalized() * (width * 0.5)
			var tangent := d.normalized() * (width * 0.3)   # slight overlap so the segments join
			var p1 := a - tangent + side
			var p2 := a - tangent - side
			var p3 := b + tangent - side
			var p4 := b + tangent + side
			for q in [p1, p2, p3, p1, p3, p4]:
				st.set_normal(Vector3.UP)
				st.add_vertex(q)
			any = true
	if any:
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.custom_aabb = AABB(Vector3(-7000, -500, -6000), Vector3(14000, 1000, 12000))
		trace.add_child(mi)
	return [trace, pts]


func _build_tracker(main: Node) -> void:
	var g: Vector3 = main.gbr
	main.volumes.set_tilted(true)   # the trace is computed in today's attitude
	var tr: Array = build_trace(main, g, 700.0, 3.0)
	_trace = tr[0]
	var pts: Array = tr[1]
	main.make_label("Carnelian horizon (six zone A sheets) where it meets today's surface  [Inferred horizon, Illustrative trace]", g + Vector3(0, 150, 0), Color(1.0, 0.45, 0.2), 48, 0.6)
	# pebbles: from random trace points to the brook at GBR
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var gy: float = main.terrain.height_at(g.x, g.z)
	_pebble_root = Node3D.new()
	_pebble_root.name = "pebbles"
	main.extras.add_child(_pebble_root)
	for i in 28:
		if pts.is_empty():
			break
		var s: Vector3 = pts[rng.randi() % pts.size()]
		var e := Vector3(g.x + rng.randf_range(-30.0, 30.0), gy + 0.5, g.z + rng.randf_range(-30.0, 30.0))
		var n: MeshInstance3D = Carnelian.piece(100 + i, 3.0, 4, 1.0, 1.0)   # sparkling: seen en masse   # drawn 3 m across so it reads at valley scale; true pieces are 1-5.5 cm
		n.rotation = Vector3(rng.randf() * 3.0, rng.randf() * 3.0, rng.randf() * 1.0)
		n.visible = false
		_pebble_root.add_child(n)
		_pebbles.append({"node": n, "start": s, "end": e, "y_free": s.y, "delay": rng.randf() * 0.12})


func set_t(t: float, main: Node) -> void:
	var zmin: float = main.terrain.z_min - 5.0
	if t < TILT_END:
		main.volumes.set_tilt_fraction(t / TILT_END)
	else:
		main.volumes.set_tilted(true)
	# sound (round 7): the fold grinds while the stack tilts, and begins with a deep thud
	main.ambience.set_level("grind", (1.0 - ramp(t, TILT_END * 0.85, TILT_END)) if t < TILT_END else 0.0)
	if t > 0.003 and t < TILT_END and not _thud_done:
		_thud_done = true
		main.ambience.play("thud")
	# the cut face is on for the tilt and the plain, off once the valleys form (unless the user re-enables it)
	if t >= 0.3 and _cut_by_us:
		AppState.cut_enabled = false
		_cut_by_us = false
	elif t < 0.3 and not _cut_by_us and not AppState.cut_enabled:
		AppState.cut_enabled = true
		_cut_by_us = true
	var te := ramp(t, TILT_END, 1.0)
	var lvl_valley := lerpf(PLAIN_Z, zmin, ramp(te, 0.05, 0.6))
	var lvl := lerpf(PLAIN_Z, zmin, ramp(te, 0.25, 1.0))
	main.volumes.set_erosion(lvl, lvl_valley)
	main.terrain.set_erosion(lvl, lvl_valley)
	_plain.position.y = lvl
	_plain.visible = t < 0.999
	_plain_mat.albedo_color.a = 0.45 * (1.0 - ramp(te, 0.6, 1.0))
	if t < TILT_END:
		_label.text = "Watchung syncline folding: the stack tilts to 9.5 deg NW (attitude Observed on GMS 04-02; timing Illustrative)"
	elif te < 0.05:
		_label.text = "Miocene regional river plain (Illustrative level %d m): at/above the summits, >50 m above the sites" % int(PLAIN_Z)
	elif te < 0.6:
		_label.text = "Valley cutting on the Feltville first (Inferred order); uplands follow (Illustrative surface at %d m)" % int(lvl)
	elif t < 0.999:
		_label.text = "Carnelian valleys cut as headwater tributaries; remaining cover (Illustrative) at %d m" % int(lvl)
	else:
		_label.text = "Today's surface (Observed: lidar DEM)"
	_label.position.y = maxf(lvl, 60.0) + 120.0
	# tracker: a piece is freed when the erosion surface drops below its outcrop point, then travels to the brook
	var hl := false
	for p in _pebbles:
		var n: MeshInstance3D = p["node"]
		if lvl > float(p["y_free"]) + 2.0:
			n.visible = false
			continue
		hl = true
		var u := ramp(te, 0.42 + float(p["delay"]), 0.92 + float(p["delay"]))
		var s: Vector3 = p["start"]
		var e: Vector3 = p["end"]
		var pos := s.lerp(e, u)
		pos.y = main.terrain.height_at(pos.x, pos.z) + 3.0
		n.position = pos
		n.visible = true
	_trace.visible = te > 0.3
	if not main.tour.on:
		for k in main.volumes.zone_a_keys():
			main.volumes.set_highlight(k, hl)


func exit(main: Node) -> void:
	if _cut_by_us:
		AppState.cut_enabled = false
		_cut_by_us = false
	main.volumes.set_tilted(true)
	main.volumes.set_erosion(-1.0e9, -1.0e9)
	main.terrain.set_erosion(-1.0e9, -1.0e9)
	main.terrain.set_ghost(false)
	for k in main.volumes.zone_a_keys():
		main.volumes.set_highlight(k, false)
	main.clear_extras()
	_pebbles.clear()
	_pebble_root = null
	_plain = null
	_trace = null
