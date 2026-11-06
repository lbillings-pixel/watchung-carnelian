extends Chapter
## Chapter 1 (schematic): Proterozoic basement and rift fluids. Source: section 5.1, Fig. 1; Steckler et al. 1993,
## El-Tabakh et al. 1997, Rddad et al. 2022 (read). A not-to-scale schematic block west of the study area.

var _nodes: Array = []
var _particles: Array = []
var _path: PackedVector3Array
var _labels: Array = []
const W := Vector3(-11500, 0, 0)   # schematic centre, west of the bbox


func _init() -> void:
	id = "basement"
	title = "1. Proterozoic basement and rift fluids (schematic)"
	short_title = "1"
	camera_cues = false
	narration = "West of the basin's border fault, and buried beneath it, lie Mesoproterozoic [Highlands gneisses] with magnetite deposits and Neoproterozoic hematitic ironstones. During Triassic-Jurassic rifting, meteoric water sank along the border [half-graben] fault, was heated to roughly 100-280 C, turned acidic and Cl/F-bearing, leached U, Th, Nb, Ta, W, REE and Fe from those rocks, and rose along intrabasinal faults. This is the paper's proposed source of nearly every trace element in the carnelian; it is drawn here schematically, not to scale."
	basic_narration = "Where the carnelian's trace elements came from: rain water sank along the basin's western border fault, was heated to 100-280 C in old Highlands gneiss and iron ores, leached uranium, thorium, niobium, tungsten and rare earths from them, and rose again along faults inside the basin. Schematic, not to scale."
	refs = "section 5.1; Fig. 1; Steckler et al. 1993; El-Tabakh et al. 1997; Rddad et al. 2022"
	strip_from = 1.3e9
	strip_to = 190.0e6
	scrub_label = "Schematic time: basement (1.3 Ga) -> rifting and fluid circulation (Triassic-Jurassic)"
	scrub_units = "illustrative"
	scrub_marks = [[0.0, "Mesoproterozoic gneiss, magnetite"], [0.25, "Neoproterozoic ironstone"], [0.5, "Rifting: border fault, basin fill"], [0.75, "Meteoric water descends, heats"], [1.0, "Hot acidic fluid ascends"]]
	start_pos = Vector3(-11500, 3800, 7800)
	start_look = Vector3(-11500, -700, 0)
	evidence = [
		{"text": "Carnelian Th 8-48 ppm, Nb 68-260 ppm, Ta 14-51 ppm, W 5-19 ppm, U 14-77 ppm (Table 3) vs Preakness basalt/gabbroid Th 2.0, Nb 4.2, Ta 0.35 ppm.", "ref": "section 5.1, Table 3"},
		{"text": "Only Mesoproterozoic/Neoproterozoic Highlands rocks in NJ carry comparable values: felsic gneiss up to 214 ppm U, 650 ppm Th, 100 ppm Nb; magnetite deposits with U, Th, REE; ironstones up to 100 ppm U, 45 ppm Th, 300 ppm W.", "ref": "section 5.1 [60-65]"},
		{"text": "High field strength elements become mobile in acidic or Cl/F-rich fluids; Cl in Highlands amphibole and scapolite, F in fluorapatite of the magnetite deposits.", "ref": "section 5.1 [66-68]"},
		{"text": "Fission tracks: zircon and apatite across the basin were reset (>220 and >120 C) except in a 5-10 km wide zone along the border fault, read as the downwelling limb of a Jurassic convection system carrying 100-250 C fluids.", "ref": "Steckler et al. 1993 (read)"},
		{"text": "Passaic Formation evaporites: fluid inclusions in coarse anhydrite homogenise at 150-280 C (average ~180 C); glauberite and gypsum are preserved as pseudomorphs and molds.", "ref": "El-Tabakh et al. 1997 (read)"},
		{"text": "Calcite veins: trapping temperatures 137-232 C (average ~183 C), salinity 0.4-13 wt% NaCl eq.; a mixing trend between hot, dilute basement-heated meteoric water rising along faults and cooler, more saline formation waters; the pH rose on mixing.", "ref": "Rddad et al. 2022 (read)"},
		{"text": "HREE-enriched patterns (La/Yb)N = 0.01-0.02 and the deep Eu anomaly match leaching by acidic, halogen-rich fluids.", "ref": "section 4.5, 5.3; Fig. 8"},
	]
	tiers = {"Inferred": "Basement as the trace-element source; fluid path, heating, acidity (section 5.1).",
		"Observed": "Trace-element values in carnelian and in Highlands rocks (Table 3, cited work); fluid temperatures from the three cited studies.",
		"Illustrative": "Everything geometric in this schematic: block sizes, fault position, fluid path, timing."}
	charts = ["res://data/charts/ree_pattern.png"]
	key_items = [
		{"name": "Highlands gneiss (schematic block)", "color": Color(0.55, 0.45, 0.6), "tier": "illustrative"},
		{"name": "Magnetite deposits", "color": Color(0.15, 0.15, 0.18), "tier": "inferred"},
		{"name": "Hematitic ironstone", "color": Color(0.55, 0.2, 0.15), "tier": "inferred"},
		{"name": "Newark basin fill", "color": Color(0.78, 0.55, 0.5), "tier": "illustrative"},
		{"name": "Border fault / intrabasinal fault", "color": Color(0.9, 0.15, 0.1), "tier": "inferred"},
		{"name": "Water: blue = cool meteoric, red = heated acidic", "color": Color(0.65, 0.45, 0.6), "tier": "illustrative"},
	]
	tour_beats = [
		beat(0.0, "Schematic block 4.5 km west of the study area: Mesoproterozoic gneiss with magnetite deposits (not to scale).", W + Vector3(-2500, 2600, 7600), W + Vector3(-1500, -600, 0)),
		beat(0.25, "Neoproterozoic hematitic ironstone: with the gneiss and magnetite, the only NJ rocks rich enough in U, Th, Nb, W and REE to be the source.", W + Vector3(-800, 1500, 5200), W + Vector3(-1500, -400, 500)),
		beat(0.5, "Rifting opens the Newark half-graben; basin fill and the Preakness lie east of the border fault.", W + Vector3(1500, 3400, 8200), W + Vector3(0, -700, 0), [], {"move": {"orbit": 25.0, "rise": 400.0, "dolly": [1.2, 0.9]}}),
		beat(0.72, "Meteoric water sinks along the border fault and is heated to 100-280 C (fission tracks, fluid inclusions in the cited studies).", W + Vector3(-1200, 1200, 5600), W + Vector3(300, -1200, 0), [], {"move": {"dolly": [1.4, 0.85], "orbit": 15.0}}),
		beat(0.9, "The hot, acidic, Cl/F-bearing fluid rises along intrabasinal faults toward the Preakness, carrying the leached elements.", W + Vector3(3400, 1300, 4600), W + Vector3(2600, -300, 0)),
	]


func enter(main: Node, animate: bool) -> void:
	super.enter(main, animate)
	main.clear_extras()
	_nodes.clear()
	_particles.clear()
	var ex: Node3D = main.extras
	_nodes.append(_box(ex, W + Vector3(-2800, -1600, 0), Vector3(5200, 2600, 7000), Color(0.55, 0.45, 0.6, 0.9), "gneiss"))
	_nodes.append(_box(ex, W + Vector3(-3200, -700, -1500), Vector3(900, 300, 1200), Color(0.15, 0.15, 0.18, 1.0), "magnetite_1"))
	_nodes.append(_box(ex, W + Vector3(-1800, -900, 1800), Vector3(700, 250, 900), Color(0.15, 0.15, 0.18, 1.0), "magnetite_2"))
	_nodes.append(_box(ex, W + Vector3(-1200, -400, 0), Vector3(600, 160, 2500), Color(0.55, 0.2, 0.15, 1.0), "ironstone"))
	_nodes.append(_box(ex, W + Vector3(2300, -1200, 0), Vector3(5000, 2200, 7000), Color(0.78, 0.55, 0.5, 0.75), "basin_fill"))
	_nodes.append(_box(ex, W + Vector3(2300, 60, 0), Vector3(5000, 120, 7000), Color(0.45, 0.45, 0.47, 0.9), "preakness_schematic"))
	var fault := _box(ex, W + Vector3(-150, -1100, 0), Vector3(60, 2400, 7000), Color(0.9, 0.1, 0.1, 0.8), "border_fault")
	fault.rotation.z = -0.35
	_nodes.append(fault)
	var ibf := _box(ex, W + Vector3(2600, -600, 0), Vector3(40, 1400, 3000), Color(0.9, 0.3, 0.1, 0.8), "intrabasinal_fault")
	ibf.rotation.z = 0.15
	_nodes.append(ibf)
	var fluid := Node3D.new()
	fluid.name = "fluid"
	ex.add_child(fluid)
	_labels = [
		main.make_label("Mesoproterozoic Highlands gneiss\n(U, Th, Nb, REE; Cl in amphibole, scapolite)  [Inferred source]", W + Vector3(-3600, 520, 1800), AppState.TIER_COLORS["inferred"], 60, 1.2),
		main.make_label("magnetite deposits (U, Th, REE; F in fluorapatite)", W + Vector3(-3200, -380, -1500), AppState.TIER_COLORS["inferred"], 48, 1.2),
		main.make_label("Neoproterozoic hematitic ironstone (U, Th, W, Fe)", W + Vector3(-2600, -330, 2600), AppState.TIER_COLORS["inferred"], 48, 1.2),
		main.make_label("Border fault (Fig. 1): meteoric water descends\n(downwelling zone 5-10 km wide: Steckler et al. 1993)", W + Vector3(-150, 1150, 3600), AppState.TIER_COLORS["inferred"], 54, 1.2),
		main.make_label("Intrabasinal extensional faults:\nhot acidic fluid ascends to the Preakness", W + Vector3(2700, 520, 1600), AppState.TIER_COLORS["inferred"], 54, 1.2),
		main.make_label("SCHEMATIC, NOT TO SCALE (Illustrative geometry). Real study area is 4.5 km east ->", W + Vector3(0, 1700, 0), AppState.TIER_COLORS["illustrative"], 64, 1.4),
		main.make_label("Heated to ~100-280 C (anhydrite inclusions 150-280, calcite 137-232, fission tracks 100-250)\nacidic, Cl/F-bearing", W + Vector3(1300, -2350, 3600), Color(1.0, 0.5, 0.2), 54, 1.2),
	]
	_path = PackedVector3Array([W + Vector3(-600, 200, 0), W + Vector3(-250, -600, 0), W + Vector3(200, -1700, 0),
		W + Vector3(1300, -2100, 0), W + Vector3(2500, -1500, 0), W + Vector3(2650, -400, 0), W + Vector3(2700, 110, 0)])
	for i in 40:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 70.0
		sm.height = 140.0
		s.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.3, 0.6, 1.0)
		m.emission_enabled = true
		m.emission = Color(0.3, 0.6, 1.0)
		s.material_override = m
		fluid.add_child(s)
		_particles.append({"node": s, "mat": m, "phase": float(i) / 40.0})
	for l in _labels:
		l.visible = false


func _box(ex: Node3D, pos: Vector3, size: Vector3, color: Color, name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = pos
	mi.name = name
	ex.add_child(mi)
	return mi


var _rift_thud := false


func set_t(t: float, main: Node) -> void:
	if _nodes.is_empty():
		return
	_nodes[0].visible = true
	_nodes[1].visible = t >= 0.02
	_nodes[2].visible = t >= 0.02
	_nodes[3].visible = t >= 0.25
	_nodes[4].visible = t >= 0.5
	_nodes[5].visible = t >= 0.5
	_nodes[6].visible = t >= 0.5
	_nodes[7].visible = t >= 0.5
	_labels[0].visible = true
	_labels[1].visible = t >= 0.02
	_labels[2].visible = t >= 0.25
	_labels[3].visible = t >= 0.5
	_labels[4].visible = t >= 0.9
	_labels[5].visible = true
	_labels[6].visible = t >= 0.8
	# sound (round 8): seismic grinding while the crust stretches and breaks, a thud as the border fault opens
	main.ambience.set_level("grind", ramp(t, 0.42, 0.5) * (1.0 - ramp(t, 0.66, 0.76)), 4.0)   # loud: the crust breaks
	main.ambience.set_level("rumble", 0.9 * ramp(t, 0.47, 0.52) * (1.0 - ramp(t, 0.6, 0.72)), 3.0)
	if t >= 0.5 and not _rift_thud and Timeline.playing:
		_rift_thud = true
		main.ambience.play("thud", 3.0)
	elif t < 0.45:
		_rift_thud = false
	var prog := ramp(t, 0.55, 1.0)
	for p in _particles:
		var u: float = fmod(p["phase"] + t * 2.0, 1.0) * prog
		p["node"].visible = t >= 0.55
		var pos := _along(u)
		p["node"].position = pos
		var heat := ramp(u, 0.25, 0.6)
		var col := Color(0.3, 0.6, 1.0).lerp(Color(1.0, 0.35, 0.1), heat)
		p["mat"].albedo_color = col
		p["mat"].emission = col


func _along(u: float) -> Vector3:
	var n := _path.size() - 1
	var f := u * n
	var i := clampi(int(floor(f)), 0, n - 1)
	return _path[i].lerp(_path[i + 1], f - i)


func exit(main: Node) -> void:
	main.clear_extras()
	_nodes.clear()
	_particles.clear()
	_labels.clear()
