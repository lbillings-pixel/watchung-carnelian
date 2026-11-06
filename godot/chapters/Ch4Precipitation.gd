extends Chapter
## Chapter 4 (deep, the heart): carnelian precipitation. Source: sections 4.3, 4.4, 5.1-5.3, Table 4, Fig. 4, 5;
## Rddad et al. 2022 (mixing). Stage A (t 0-0.5): fluids at flow scale. Stage B (t 0.5-1): one vesicle at GBR.
## Untilted stack in a block (the flow is still flat-lying at 201 Ma).

var _hydro: Array = []
var _meteor: Array = []
var _zoneA: Label3D
var _zoneB: Label3D
var _field: MeshInstance3D
var _field_mat: ShaderMaterial
var _ves := {}
var _micro: Node3D
var _cut_normal := Vector3(0.65, 0.0, -0.76).normalized()
var mix_ratio := 0.5
var ves_center: Vector3
var _in_vesicle := false
var _era_zone := ""
const BOX := Vector3(3000, 0, 2500)
const ERA_BASE := ["feltville", "feltville_aureole", "glass_rind", "pillow_zone", "columnar_zone", "gabbroid", "glass_rich_gabbroid", "massive_top"]


func _init() -> void:
	id = "precipitation"
	title = "4. Carnelian precipitation"
	short_title = "4"
	uses_flat_stack = true
	narration = "Hot, acidic, deep [hydrothermal fluid] rises into the altered, volatile-rich upper part of the first flow and mixes with cool, more alkaline [meteoric water]. Basaltic glass in the [gabbroid] breaks down ([devitrification]) and releases silica. The paper does not say exactly where in the upper flow the carnelian grew: both the [vesicle]-rich gabbroid sheets (zone A) and the [amygdaloidal] flow top (zone B) are drawn as candidates. In the second half of the scrubber the view enters one vesicle: [glauberite] crystals are already there; carnelian ([chalcedony] with >= 5 % [moganite]) grows from the vesicular attachment surface below into [botryoidal] domes on top; the glauberite later dissolves and leaves molds."
	basic_narration = "Hot acidic water rising from depth meets cool rain water inside the bubbly upper part of the flow. Glass in the gabbroid dissolves and feeds silica into the mix, which at 20-80 C precipitates as carnelian inside gas bubbles, growing from the bubble floor into grape-like domes. Halfway through, the view dives into one 8 mm bubble."
	refs = "sections 4.3, 4.4, 5.1-5.3; Table 4; Fig. 4, Fig. 5; Rddad et al. 2022"
	strip_from = 201.0e6
	strip_to = 200.98e6
	scrub_label = "Fluid mixing in the upper first flow -> growth in one vesicle (durations not given)"
	scrub_units = "illustrative sequence, not time"
	scrub_marks = [[0.0, "Hot acidic fluid rises along columns / faults"], [0.2, "Meets cool alkaline meteoric water: mixing"], [0.35, "Glass devitrifies, silica released"], [0.5, "In a vesicle: glauberite present"], [0.65, "Chalcedony fibres nucleate on the attachment surface"], [0.8, "Botryoidal top builds"], [0.95, "Glauberite dissolves: molds"]]
	evidence = [
		{"text": "Vesicle molds on lower surfaces (convex upward: an attachment surface on amygdaloidal basalt); botryoidal textures on upper surfaces; glauberite molds up to 4 mm x 1.5 cm.", "ref": "section 4.3, Fig. 4b-d"},
		{"text": "Length-fast parallel fibre bundles nucleating from an attachment band, overlain by rhythmic wrinkle (extinction) bands; 2 mm fields.", "ref": "section 4.4, Fig. 5"},
		{"text": "XRD: alpha-quartz plus moganite (>= 5 %); no opal, cristobalite or calcite. Crystallite size 228-333 A (GBR) vs 434-542 A (SGB); microstrain 0.126-0.184 vs 0.078-0.098 %.", "ref": "section 4.4, Table 2, Fig. 6"},
		{"text": "delta-18O +18.3 to +31.2 per mil (five of six: +27.8 to +31.2); formation temperatures 19-32 C from meteoric water (-5 per mil), 39-56 C seawater, 82-108 C magmatic (+8 per mil); GBR-5 is the outlier.", "ref": "section 4.6, 5.3, Table 4, Fig. 9"},
		{"text": "Paper's interpretation: mainly 20-80 C, not much above ~100 C; neutral to slightly alkaline pH (HREE solubility and Fe-oxide adsorption at pH 6.3-9; U mobile at pH 7-9; moganite precipitates from alkaline, ferric-iron fluids).", "ref": "section 5.3 [78,91-97], section 6"},
		{"text": "Mixing: samples GBR-02-1 -> -3 show falling REE (85 -> 15 ppm), HREE, Nb, Ta, W, consistent with rising pH as the acidic deep fluid is diluted; the delta-18O spread reflects the varying ratio. The same basin-wide mixing (basement-heated dilute water + cooler formation water, pH rising) is recorded by calcite veins at 137-232 C.", "ref": "section 5.3, Table 3; Rddad et al. 2022 (read)"},
		{"text": "Silica source: devitrification/hydrolysis of glass in the gabbroid (glass-rich gabbroid depleted by up to 4.0 Al2O3, 3.0 MgO, 3.0 CaO, 0.7 K2O wt.%). The thickest gabbroid in the basin is why carnelian is only here.", "ref": "section 5.1, Table 1"},
		{"text": "Where the vesicles are: Puffer & Volkert's cores show the vesicular gabbroid sheets confined to the upper ~40 m of the flow (19 % pore space at 12 m below the top, 2 % at 36 m), the host basalt nearly vesicle-free below ~40 m, and a 3-6 m scoriaceous flow top. Zone A is drawn as six such sheets (5-39 m below the top); both candidate zones are inside that envelope.", "ref": "Puffer & Volkert 2001 (read); paper section 5.2, Table 1"},
		{"text": "Colour: hematite inclusions -> red; goethite -> yellow; rutile excluded (TiO2 < 0.012 wt.%).", "ref": "section 4.5 [44,48-50]"},
		{"text": "Timing by paragenesis: basalt crystallisation -> saline minerals (glauberite) -> albitization -> silica; so carnelian 'may have formed contemporaneously with the crystallization of the Preakness at 201 Ma'. Glauberite and gypsum pseudomorphs are known from Passaic evaporites formed from brines later heated to 150-280 C.", "ref": "section 5.2 [17,21]; El-Tabakh et al. 1997 (read)"},
		{"text": "Why the upper flow: vesicle molds are incompatible with growth along joints or faults; the gabbroid shows alteration (LOI, Na2O, CaO, Sr) and trapped gas.", "ref": "section 5.2"},
	]
	tiers = {"Observed": "Carnelian textures, XRD, chemistry, delta-18O and Table 4 calculations; mold and vesicle sizes; sheet depths from cores.",
		"Inferred": "Fluid mixing, temperatures 20-80 C, pH, silica from glass, Proterozoic trace-element source, the upper-flow precipitation site, paragenetic timing.",
		"Illustrative": "Fluid particle paths, the shapes of the T/pH field, the vesicle geometry and growth animation, the mixing-ratio slider mapping, all durations."}
	charts = ["res://data/charts/table4_temps.png", "res://data/charts/d18o_global.png", "res://data/charts/table2_crystallite.png", "res://data/charts/ree_pattern.png"]
	key_items = [
		{"name": "Red particles: hot acidic hydrothermal fluid (rising)", "color": Color(1.0, 0.35, 0.1), "tier": "inferred"},
		{"name": "Blue particles: cool alkaline meteoric water (sinking)", "color": Color(0.3, 0.6, 1.0), "tier": "inferred"},
		{"name": "T / pH field column (red hot-acid to blue cool-alkaline)", "color": Color(0.6, 0.45, 0.55), "tier": "illustrative"},
		{"name": "Carnelian (in the vesicle view)", "color": Color(0.85, 0.18, 0.08), "tier": "observed"},
		{"name": "Glauberite crystal / its mold", "color": Color(0.85, 0.88, 0.8), "tier": "observed"},
	]


func enter(main: Node, animate: bool) -> void:
	var v: Node3D = main.volumes
	var g: Vector3 = main.gbr
	var zone_a: Array = v.zone_a_keys()
	var s2: Dictionary = v.layer_info("vesicle_sheet_2")     # Puffer & Volkert's uppermost (19 %) sheet, 12 m below the top
	var top_a: float = v.surface_elevation(float(s2.get("base_offset_m", 132.0)) + 0.5 * float(s2.get("thickness_m", 1.0)), g.x, g.z)
	var base: float = v.surface_elevation(0.0, g.x, g.z)
	var top: float = v.surface_elevation(145.0, g.x, g.z)
	ves_center = Vector3(g.x + 40.0, top_a, g.z - 30.0)
	start_look = Vector3(g.x, top - 40.0, g.z)
	start_pos = start_look + _cut_normal * 900.0 + Vector3(0, 27, 0)
	var ves_pos := ves_center + Vector3(0.012, 0.009, 0.014)
	var micro_pos := ves_center + Vector3(0.0, 2.5, 6.5)
	var micro_look := ves_center + Vector3(0.0, 2.5, 0.0)
	scale_views = [
		{"name": "landscape", "pos": Vector3(g.x, base + 60.0, g.z) + _cut_normal * 4500.0 + Vector3(0, 135, 0), "look": Vector3(g.x, base + 60.0, g.z)},
		{"name": "outcrop", "pos": Vector3(g.x, top - 40.0, g.z) + _cut_normal * 520.0 + Vector3(0, 16, 0), "look": Vector3(g.x, top - 40.0, g.z), "t": 0.3},
		{"name": "vesicle", "pos": ves_pos, "look": ves_center, "near": 0.001, "t": 0.85},
		{"name": "microstructure", "pos": micro_pos, "look": micro_look, "near": 0.05, "t": 1.0},
	]
	tour_beats = [
		beat(0.0, "Hot, acidic fluid (red) rises from depth along columns and faults into the upper first flow.", Vector3(g.x, top - 60.0, g.z) + _cut_normal * 650.0 + Vector3(0, 20, 0), Vector3(g.x, top - 60.0, g.z), ["gabbroid"], {"move": {"dolly": [1.4, 0.9], "orbit": 15.0}}),
		beat(0.2, "It meets cool, alkaline meteoric water (blue) sinking from above: the mixing zone sits mostly at 20-80 C, pH about 6.5-9.", Vector3(g.x, top - 30.0, g.z) + _cut_normal * 520.0 + Vector3(0, 16, 0), Vector3(g.x, top - 30.0, g.z)),
		beat(0.35, "Glass in the gabbroid devitrifies and releases silica. Two candidate horizons: A, the six vesicle-rich gabbroid sheets; B, the amygdaloidal flow top. The paper does not choose.", Vector3(g.x, top - 15.0, g.z) + _cut_normal * 300.0 + Vector3(0, 9, 0), Vector3(g.x, top - 15.0, g.z), zone_a + ["amygdaloidal_top", "glass_rich_gabbroid"], {"move": {"orbit": 25.0}}),
		beat(0.5, "Inside one 8 mm vesicle (the view is now 1.5 cm across): a glauberite crystal already sits in it.", ves_pos, ves_center, [], {"near": 0.001, "move": {"orbit": 35.0, "dolly": [1.3, 0.9]}}),
		beat(0.65, "Chalcedony fibres nucleate on the bumpy attachment surface at the floor of the bubble and grow upward.", ves_pos, ves_center, [], {"near": 0.001}),
		beat(0.8, "The top builds grape-like (botryoidal) domes; hematite inclusions make it red.", ves_center + Vector3(-0.011, 0.011, 0.012), ves_center, [], {"near": 0.001, "move": {"orbit": 40.0, "dolly": [1.2, 0.75]}, "cue": false}),
		beat(0.93, "The glauberite dissolves and leaves a mold: the order of events the paper reads from the textures.", ves_pos, ves_center, [], {"near": 0.001, "cue": false}),
		beat(0.985, "Under the microscope (x2000, Fig. 5): length-fast fibre bundles rising from the attachment band with rhythmic extinction bands.", micro_pos, micro_look, [], {"near": 0.05}),
	]
	super.enter(main, animate)
	main.clear_extras()
	_in_vesicle = false
	_era_zone = ""
	v.set_clip_to_terrain(false)
	v.set_box_clip(true, g - BOX - Vector3(0, 1.0e6, 0), g + BOX + Vector3(0, 1.0e6, 0))
	main.terrain.set_ghost(true)
	main.features.set_group_filter(["sites"])
	_apply_zone_era(main)
	AppState.cut_enabled = true
	AppState.cut_plane = Plane(_cut_normal, _cut_normal.dot(g))
	_build_fluids(main)
	_build_vesicle(main)
	_build_micro(main)


func _apply_zone_era(main: Node) -> void:
	if AppState.candidate_zone == _era_zone:
		return
	_era_zone = AppState.candidate_zone
	var era: Array = ERA_BASE.duplicate()
	if _era_zone != "B":
		era.append_array(main.volumes.zone_a_keys())
	if _era_zone != "A":
		era.append("amygdaloidal_top")
	main.volumes.set_era_visibility(era)
	if _zoneA:
		_zoneA.visible = _era_zone != "B" and Timeline.t < 0.5
		_zoneB.visible = _era_zone != "A" and Timeline.t < 0.5


func _particle(main: Node, color: Color, r: float) -> Dictionary:
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	s.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.5
	s.material_override = m
	main.extras.add_child(s)
	return {"node": s, "mat": m}


func _build_fluids(main: Node) -> void:
	var v: Node3D = main.volumes
	var g: Vector3 = main.gbr
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var za: Dictionary = v.manifest.get("zone_a", {})
	var zA: float = v.surface_elevation(float(za.get("base_offset_m", 106.0)), g.x, g.z)
	var zB: float = v.surface_elevation(145.0 - 2.5, g.x, g.z)
	var base: float = v.surface_elevation(0.0, g.x, g.z)
	var hydro_root := Node3D.new()
	hydro_root.name = "hydro"
	main.extras.add_child(hydro_root)
	var meteor_root := Node3D.new()
	meteor_root.name = "meteor"
	main.extras.add_child(meteor_root)
	for i in 70:
		var p := _particle(main, Color(1.0, 0.35, 0.1), 2.2)
		p["node"].reparent(hydro_root)
		p["x"] = g.x - 260.0 + rng.randf() * 520.0
		p["z"] = g.z - 260.0 + rng.randf() * 520.0
		p["phase"] = rng.randf()
		p["y0"] = base - 150.0
		p["y1"] = zA + rng.randf() * (zB - zA)
		_hydro.append(p)
	for i in 70:
		var p := _particle(main, Color(0.3, 0.6, 1.0), 2.2)
		p["node"].reparent(meteor_root)
		p["x"] = g.x - 260.0 + rng.randf() * 520.0
		p["z"] = g.z - 260.0 + rng.randf() * 520.0
		p["phase"] = rng.randf()
		p["y0"] = zB + 60.0
		p["y1"] = zA + rng.randf() * (zB - zA)
		_meteor.append(p)
	_zoneA = main.make_label("Candidate zone A: six vesicle-rich gabbroid sheets, 5-39 m below the top (<= 19 % vesicles)  [Inferred]", Vector3(g.x + 300, zA + 30, g.z - 300), AppState.TIER_COLORS["inferred"], 44, 0.45)
	_zoneB = main.make_label("Candidate zone B: amygdaloidal flow top (2.5 m)  [Inferred]", Vector3(g.x - 300, zB + 40, g.z + 300), AppState.TIER_COLORS["inferred"], 44, 0.45)
	_field = MeshInstance3D.new()
	_field.name = "field"
	var bm := BoxMesh.new()
	bm.size = Vector3(560.0, zB + 80.0 - (base - 160.0), 560.0)
	_field.mesh = bm
	_field.position = Vector3(g.x, (zB + 80.0 + base - 160.0) * 0.5, g.z)
	_field_mat = ShaderMaterial.new()
	_field_mat.shader = load("res://shaders/field.gdshader")
	_field_mat.set_shader_parameter("y_bottom", base - 160.0)
	_field_mat.set_shader_parameter("y_top", zB + 80.0)
	_field.material_override = _field_mat
	main.extras.add_child(_field)
	main.make_label("T / pH field: hot acidic below, cool alkaline above; mixing mostly 20-80 C, pH 6.5-9\n(Inferred ranges, Illustrative shape)", Vector3(g.x + 330, zB + 120, g.z + 330), Color(0.95, 0.9, 0.8), 40, 0.45)


func _build_vesicle(main: Node) -> void:
	var root := Node3D.new()
	root.position = ves_center
	main.extras.add_child(root)
	_ves["root"] = root
	var rock := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(0.03, 0.03, 0.03)
	rock.mesh = rb
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.35, 0.33, 0.33, 0.28)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.cull_mode = BaseMaterial3D.CULL_FRONT
	rock.material_override = rm
	root.add_child(rock)
	var cav := MeshInstance3D.new()
	cav.name = "cavity"
	var cs := SphereMesh.new()
	cs.radius = 0.004
	cs.height = 0.008
	cav.mesh = cs
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.22, 0.2, 0.2, 0.55)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.cull_mode = BaseMaterial3D.CULL_FRONT
	cav.material_override = cm
	root.add_child(cav)
	var gl := MeshInstance3D.new()
	gl.name = "glauberite"
	var gb := BoxMesh.new()
	gb.size = Vector3(0.0015, 0.0065, 0.001)
	gl.mesh = gb
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.85, 0.88, 0.8, 0.9)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gl.material_override = gm
	gl.position = Vector3(-0.0012, -0.0005, 0.0008)
	gl.rotation = Vector3(0.3, 0.4, 0.5)
	root.add_child(gl)
	_ves["glauberite"] = gl
	var mold := MeshInstance3D.new()
	mold.mesh = gb
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.12, 0.05, 0.03)
	mold.material_override = mm
	mold.position = gl.position
	mold.rotation = gl.rotation
	mold.visible = false
	root.add_child(mold)
	_ves["mold"] = mold
	var car := MeshInstance3D.new()
	car.name = "carnelian"
	var csph := SphereMesh.new()
	csph.radius = 0.0038
	csph.height = 0.0076
	car.mesh = csph
	var carm: ShaderMaterial = Carnelian.material(7, 0.004)   # translucent banded chalcedony (polish pass)
	carm.set_shader_parameter("grain", 0.35)                  # grown surfaces are smoother than weathered pieces
	carm.set_shader_parameter("sparkle", 0.5)                 # close-up: a soft, slow sparkle (round 10)
	carm.set_shader_parameter("sparkle_soft", 1.0)
	car.material_override = carm
	car.position = Vector3(0, -0.0038, 0)
	root.add_child(car)
	_ves["carnelian"] = car
	var bots := Node3D.new()
	bots.name = "bots"
	root.add_child(bots)
	_ves["bots"] = bots
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 14:
		var b := MeshInstance3D.new()
		var bs := SphereMesh.new()
		var r := 0.0006 + rng.randf() * 0.0007
		bs.radius = r
		bs.height = r * 2.0
		b.mesh = bs
		b.material_override = carm
		var ang := rng.randf() * TAU
		var rr := rng.randf() * 0.0022
		b.position = Vector3(cos(ang) * rr, 0.0, sin(ang) * rr)
		bots.add_child(b)
	var att := Node3D.new()
	att.position = Vector3(0, -0.0038, 0)
	root.add_child(att)
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.3, 0.3, 0.32)
	for i in 20:
		var b := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.0004
		bs.height = 0.0008
		b.mesh = bs
		b.material_override = am
		var ang := rng.randf() * TAU
		var rr := rng.randf() * 0.0025
		b.position = Vector3(cos(ang) * rr, 0.0, sin(ang) * rr)
		att.add_child(b)
	var lbl: Label3D = main.make_label("One vesicle, 8 mm (2-10 mm). Glauberite 1.5 x 6.5 mm (molds to 4 x 15 mm)\nIllustrative geometry of Observed features (Fig. 4)", ves_center + Vector3(0, 0.0075, 0), AppState.TIER_COLORS["illustrative"], 36, 0.00015)
	_ves["label"] = lbl


func _build_micro(main: Node) -> void:
	_micro = Node3D.new()
	_micro.name = "micro"
	_micro.position = ves_center + Vector3(0, 2.5, 0)
	main.extras.add_child(_micro)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var back := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(4.2, 4.2, 0.05)
	back.mesh = bb
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.08, 0.06, 0.06)
	back.material_override = bmat
	back.position = Vector3(0, 0, -0.05)
	_micro.add_child(back)
	var band := MeshInstance3D.new()
	var bandm := BoxMesh.new()
	bandm.size = Vector3(4.0, 0.15, 0.02)
	band.mesh = bandm
	var bandmat := StandardMaterial3D.new()
	bandmat.albedo_color = Color(0.75, 0.72, 0.7)
	band.material_override = bandmat
	band.position = Vector3(0, -1.9, 0)
	_micro.add_child(band)
	for i in 26:
		var x0 := -1.95 + i * 0.155
		var tilt := (rng.randf() - 0.5) * 0.35
		var len := 2.6 + rng.randf() * 1.0
		var nseg := int(len / 0.12)
		for s in nseg:
			var seg := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(0.13, 0.11, 0.02)
			seg.mesh = sm
			var m := StandardMaterial3D.new()
			var bright := (s % 2 == 0)
			m.albedo_color = Color(0.95, 0.35, 0.15) if bright else Color(0.45, 0.12, 0.06)
			seg.material_override = m
			var y := -1.8 + s * 0.12
			seg.position = Vector3(x0 + tilt * (y + 1.8), y, 0)
			seg.rotation.z = tilt
			_micro.add_child(seg)
	main.make_label("Microstructure (Fig. 5, x2000; 2 mm field = 4 m here): length-fast fibre bundles from the attachment band,\nalternating rhythmic extinction bands. Illustrative drawing of Observed features.", ves_center + Vector3(0, 5.0, 0), AppState.TIER_COLORS["illustrative"], 40, 0.01)


var _glint_done := false


func set_t(t: float, main: Node) -> void:
	var v: Node3D = main.volumes
	_apply_zone_era(main)
	var rise := ramp(t, 0.0, 0.3)
	var mixf := ramp(t, 0.2, 0.5)
	for p in _hydro:
		var u: float = fmod(p["phase"] + t * 1.5, 1.0)
		var y: float = lerpf(p["y0"], p["y1"], minf(u, rise))
		p["node"].position = Vector3(p["x"] + sin(u * 20.0) * 4.0, y, p["z"])
		p["node"].visible = t < 0.5
	for p in _meteor:
		var u: float = fmod(p["phase"] + t * 1.5, 1.0)
		var y: float = lerpf(p["y0"], p["y1"], minf(u, mixf))
		p["node"].position = Vector3(p["x"], y, p["z"] + sin(u * 20.0) * 4.0)
		p["node"].visible = t >= 0.18 and t < 0.5
	_field.visible = t >= 0.2 and t < 0.5
	_field_mat.set_shader_parameter("mix", mix_ratio)
	_field_mat.set_shader_parameter("strength", mixf)
	var hl: bool = t >= 0.35 and t < 0.5 and not main.tour.on
	for k in v.zone_a_keys():
		v.set_highlight(k, hl and _era_zone != "B")
	v.set_highlight("amygdaloidal_top", hl and _era_zone != "A")
	v.set_highlight("glass_rich_gabbroid", hl)
	# sound (round 8): the vesicle at depth hums with pressure; a glassy shimmer while the chalcedony grows
	main.ambience.set_level("pressure", 0.5 * ramp(t, 0.5, 0.56) * (1.0 - ramp(t, 0.97, 1.0)))
	main.ambience.set_level("shimmer", ramp(t, 0.6, 0.66) * (1.0 - ramp(t, 0.95, 0.985)))
	main.ambience.set_level("bubble", ramp(t, 0.78, 0.82) * (1.0 - ramp(t, 0.94, 0.97)))   # the botryoidal domes grow
	if t >= 0.6 and not _glint_done and Timeline.playing:
		_glint_done = true
		main.ambience.play("glint")
	elif t < 0.55:
		_glint_done = false
	# the microscope view (the last beat) has no meaningful scale: no scale bar there
	main.ui.orient.scale_bar = t < 0.98
	var g := ramp(t, 0.6, 0.85)
	var car: MeshInstance3D = _ves["carnelian"]
	car.scale = Vector3(1.0, maxf(g, 0.001) * 1.3, 1.0)
	car.visible = t >= 0.6
	var bots: Node3D = _ves["bots"]
	bots.visible = t >= 0.8
	bots.position = Vector3(0, -0.0038 + 0.0038 * 1.3 * g, 0)
	var bs := ramp(t, 0.8, 0.95)
	bots.scale = Vector3(maxf(bs, 0.001), maxf(bs, 0.001), maxf(bs, 0.001))
	var gl: MeshInstance3D = _ves["glauberite"]
	var dis := ramp(t, 0.92, 1.0)
	gl.visible = dis < 1.0
	gl.scale = Vector3.ONE * maxf(1.0 - dis, 0.001)
	_ves["mold"].visible = dis > 0.0
	_ves["root"].visible = t >= 0.5
	_micro.visible = t >= 0.5
	main.volumes.chapter_hidden = t >= 0.5
	main.terrain.visible = t < 0.5
	main.features.visible = t < 0.5
	_zoneA.visible = t < 0.5 and _era_zone != "B"
	_zoneB.visible = t < 0.5 and _era_zone != "A"
	# the vesicle stage only makes sense from inside the vesicle: move the camera there (and back) when the
	# scrubber crosses the half-way point, whatever mode we are in
	if t >= 0.5 and not _in_vesicle:
		_in_vesicle = true
		if main.camera.cam.global_position.distance_to(ves_center) > 1.0 and not main.tour.on:
			main.camera.set_near(0.001)
			main.camera.fly_to(ves_center + Vector3(0.012, 0.009, 0.014), ves_center, 2.0)
	elif t < 0.5 and _in_vesicle:
		_in_vesicle = false
		if not main.tour.on:
			main.camera.set_near(0.5)
			main.camera.fly_to(start_pos, start_look, 2.0)


func exit(main: Node) -> void:
	main.ui.orient.scale_bar = true
	main.volumes.chapter_hidden = false
	main.terrain.visible = true
	main.features.visible = true
	main.volumes.set_clip_to_terrain(true)
	main.volumes.set_box_clip(false)
	main.terrain.set_ghost(false)
	main.features.set_group_filter([])
	main.volumes.set_era_visibility([])
	for k in main.volumes.zone_a_keys() + ["amygdaloidal_top", "glass_rich_gabbroid"]:
		main.volumes.set_highlight(k, false)
	AppState.cut_enabled = false
	main.camera.set_near(0.5)
	main.clear_extras()
	_hydro.clear()
	_meteor.clear()
	_ves.clear()
	_zoneA = null
	_zoneB = null
