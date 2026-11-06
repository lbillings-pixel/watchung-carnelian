extends Chapter
## Chapter 3 (deep): Preakness first-flow eruption, ~201 Ma. Source: section 2, 5.2, Table 1, Fig. 3;
## Puffer & Volkert 2001 (sheet positions); GMS 04-02 and Faust 1978 (columns). Untilted stack in a block.

var _labels: Array = []
var _columns: MultiMeshInstance3D
var _pillows: MultiMeshInstance3D
var _cut_normal := Vector3(0.65, 0.0, -0.76).normalized()
const BOX := Vector3(3000, 0, 2500)
const GROW := {   # key -> [t0, t1] growth window (zone A sheets added in enter())
	"glass_rind": [0.08, 0.1], "pillow_zone": [0.1, 0.25], "columnar_zone": [0.28, 0.55], "gabbroid": [0.55, 0.7],
	"glass_rich_gabbroid": [0.72, 0.8], "massive_top": [0.85, 0.9], "amygdaloidal_top": [0.9, 1.0],
}
var _grow := {}


func _init() -> void:
	id = "eruption"
	title = "3. Preakness eruption, ~201 Ma"
	short_title = "3"
	uses_flat_stack = true
	narration = "The first Preakness flow (125-145 m here; 140-180 m regionally) erupts onto the Feltville floodplain. Here it meets standing water: the base forms [pillow] lobes over a 3-10 m interval against a layer of basaltic glass, then cools into slender [columnar joints]. Inside the thick flow, [fractionation] builds a coarse [gabbroid] lens (82 m under Green Brook, 49 m under Stirling Brook) that traps rising gas as [vesicle]-rich sheets and holds dark red or black glass in its upper 12-36 m; the top freezes as a 2.5 m [amygdaloidal] crust. Scrub the eruption; the cross-section plane through GBR is already on."
	basic_narration = "Lava 145 m thick pours over the Feltville floodplain and into shallow water: pillows and glass at the base, columns above, a thick coarse-grained gabbroid lens in the upper half that traps gas bubbles and glass, and a bubbly crust on top. The cut face runs through the Green Brook site."
	refs = "section 2 [25-30]; section 5.2; Table 1; Fig. 3a-c; Puffer & Volkert 2001; GMS 04-02"
	strip_from = 201.0e6
	strip_to = 200.99e6
	scrub_label = "Eruption -> cooled, differentiated first flow (duration not given by the paper)"
	scrub_units = "illustrative sequence, not time"
	scrub_marks = [[0.0, "Feltville floor, shallow water"], [0.08, "Glass rind and pillows (subaqueous base)"], [0.28, "Colonnade: columnar-jointed basalt"], [0.55, "Gabbroid lens by fractionation"], [0.72, "Gas trapped: vesicle-rich sheets, glass-rich band"], [0.9, "Amygdaloidal flow top"], [1.0, "Flow cooled"]]
	evidence = [
		{"text": "Zircon U-Pb age 201 +/- 0.03 Ma; 315 m total Preakness (about 1,040 ft on the map), >= 3 flows; high-Fe quartz-normative tholeiite.", "ref": "section 2 [25], Table 1; GMS 04-02"},
		{"text": "First flow 125-145 m (140-180 m along its 70 km strike); base with vertical slender prismatic columns <= 0.5 m wide, 6 m long resting on the Feltville ('radiating slender columns 2 to 24 in. wide' on the map; Faust: columns 15-30 cm wide, 2.4-3 m high in the colonnade).", "ref": "section 2 [27]; Puffer & Volkert 2001; GMS 04-02; Faust 1978"},
		{"text": "Base pillowed and vesicular in the study area (local subaqueous eruption): pillows 0.6-0.9 m over a 3-10 m interval, with gray/brown basaltic glass <= 2.5 cm.", "ref": "section 2 [22,28-30]"},
		{"text": "Gabbroid: concordant layers <= 80 m in the middle and upper first flow; sharp tops, gradational bases; formed by fractionation; crystals to 2 cm. Calculated 82 m at Green Brook, 49 m at Stirling Brook. Puffer & Volkert: the Berkeley Heights lens (up to 96 m, cored by five wells) makes up most of the upper half of the flow.", "ref": "section 2 [26], section 4.1, Fig. 2, Fig. 3a; Puffer & Volkert 2001"},
		{"text": "Thin vesicular gabbroid sheets (1 cm-3 m) lie 12-36 m below the vesicular flow top; the uppermost is highly vesicular black vitreous glass; pore space falls from ~19 % to 2 % with depth; host basalt vesicles are rare below ~40 m beneath the top.", "ref": "Puffer & Volkert 2001; paper section 2, Fig. 3b, Table 1 (vesicular gabbroid 140 m above base)"},
		{"text": "Thick gabbroid has 3 m intervals with 2-10 mm vesicles making up to 19 % of the rock: gabbroid formed a barrier and trapped rising gas. Fine basalt elsewhere has < 0.2 vol% vesicles.", "ref": "section 5.2 [26]"},
		{"text": "Top: blocky, massive basalt capped by a ~2.5 m highly vesicular, amygdaloidal layer (map: vesiculated zones as much as 8 ft; Puffer & Volkert: 3-6 m scoriaceous top).", "ref": "section 2, Fig. 3c; GMS 04-02; Puffer & Volkert 2001"},
		{"text": "Alteration chemistry rises in the gabbroid and flow top (LOI 1.8-2.5 wt.%, Na2O gain, CaO/Sr loss).", "ref": "Table 1, section 5.2"},
	]
	tiers = {"Observed": "All thicknesses and dimensions quoted; the mapped gabbroid (Jpg) and Jps1 outcrops; Table 1 chemistry; sheet depths from Puffer & Volkert's cores.",
		"Inferred": "That gabbroid acted as a gas trap; that degassing was rapid (from the scarcity of vesicles low in the flow); the along-strike interpolation of the lens thickness.",
		"Illustrative": "The eruption sequence as animated, its duration, the glow, pillow and column models, the block extent."}
	charts = ["res://data/charts/table1_alteration.png"]
	key_items = [{"name": "Incandescent = still molten (cosmetic cue)", "color": Color(1.0, 0.45, 0.08), "tier": "illustrative"}]


func enter(main: Node, animate: bool) -> void:
	var g: Vector3 = main.gbr
	var v: Node3D = main.volumes
	var base: float = v.surface_elevation(0.0, g.x, g.z)
	var top: float = v.surface_elevation(145.0, g.x, g.z)
	var zone_a: Array = v.zone_a_keys()
	_grow = GROW.duplicate()
	for k in zone_a:
		_grow[k] = [0.75, 0.85]
	start_look = Vector3(g.x, base + 60.0, g.z)
	start_pos = start_look + _cut_normal * 1500.0 + Vector3(0, 45, 0)
	scale_views = [
		{"name": "landscape", "pos": Vector3(g.x, base + 60.0, g.z) + _cut_normal * 4500.0 + Vector3(0, 135, 0), "look": Vector3(g.x, base + 60.0, g.z)},
		{"name": "outcrop_cutaway", "pos": Vector3(g.x, base + 70.0, g.z) + _cut_normal * 420.0 + Vector3(0, 13, 0), "look": Vector3(g.x, base + 70.0, g.z)},
		{"name": "inside_flow", "pos": Vector3(g.x, base + 6.0, g.z) + _cut_normal * 40.0 + Vector3(0, 3, 0), "look": Vector3(g.x, base + 6.0, g.z) - _cut_normal * 60.0},
	]
	tour_beats = [
		beat(0.0, "The Feltville floodplain, partly under shallow water. The cut face runs NW-SE through the Green Brook site.", start_pos, start_look, [], {"move": {"dolly": [1.6, 1.0], "rise": 60.0}}),
		beat(0.07, "Lava meets standing water: a glass rind (2.5 cm) and pillow lobes 0.6-0.9 m across form the base over 3-10 m (Observed sizes, Illustrative placement).", Vector3(g.x, base + 4.0, g.z) + _cut_normal * 22.0 + Vector3(0, 3, 0), Vector3(g.x, base + 5.0, g.z), ["glass_rind", "pillow_zone"], {"move": {"dolly": [1.5, 0.8], "orbit": 18.0}}),
		beat(0.27, "The colonnade: the lower flow cools into slender columns no more than 0.5 m wide and 6 m long.", Vector3(g.x, base + 40.0, g.z) + _cut_normal * 380.0 + Vector3(0, 11, 0), Vector3(g.x, base + 40.0, g.z), ["columnar_zone"]),
		beat(0.54, "Fractionation inside the still-molten interior builds the gabbroid lens: coarse crystals to 2 cm, 82 m thick here, 49 m at Stirling Brook, sharp top at 140 m.", Vector3(g.x, base + 100.0, g.z) + _cut_normal * 900.0 + Vector3(0, 27, 0), Vector3(g.x, base + 100.0, g.z), ["gabbroid"], {"move": {"orbit": 28.0, "dolly": [1.2, 0.9]}}),
		beat(0.71, "Gas rising through the flow is trapped under the coarse gabbroid: six thin vesicle-rich sheets (up to 19 % bubbles 2-10 mm, 5-39 m below the top) and a glass-rich band 12-36 m below the top. This is where the carnelian will grow.", Vector3(g.x, top - 20.0, g.z) + _cut_normal * 260.0 + Vector3(0, 8, 0), Vector3(g.x, top - 20.0, g.z), zone_a + ["glass_rich_gabbroid"], {"move": {"orbit": 30.0, "dolly": [1.3, 0.85]}}),
		beat(0.89, "The flow top freezes as a 2.5 m vesicular, amygdaloidal crust (candidate zone B).", Vector3(g.x, top - 3.0, g.z) + _cut_normal * 220.0 + Vector3(0, 7, 0), Vector3(g.x, top - 3.0, g.z), ["amygdaloidal_top"]),
		beat(0.99, "The first flow has cooled: 145 m of basalt with a gabbroid lens in its upper half.", Vector3(g.x, base + 70.0, g.z) + _cut_normal * 1500.0 + Vector3(0, 45, 0), Vector3(g.x, base + 70.0, g.z), [], {"move": {"dolly": [0.75, 1.3], "rise": 120.0}}),
	]
	super.enter(main, animate)
	main.clear_extras()
	v.set_clip_to_terrain(false)
	v.set_box_clip(true, g - BOX - Vector3(0, 1.0e6, 0), g + BOX + Vector3(0, 1.0e6, 0))
	main.terrain.set_ghost(true)
	main.features.set_group_filter(["sites"])
	v.set_era_visibility(["passaic", "orange_mountain", "feltville", "feltville_lacustrine_1", "feltville_lacustrine_2", "feltville_aureole",
		"glass_rind", "pillow_zone", "columnar_zone", "gabbroid", "glass_rich_gabbroid", "massive_top", "amygdaloidal_top"] + zone_a)
	AppState.cut_enabled = true
	AppState.cut_plane = Plane(_cut_normal, _cut_normal.dot(g))
	_build_detail(main)
	_labels = [
		main.make_label("Cross-section through the GBR zone; beds flat as erupted (the tilt came later)", Vector3(g.x, top + 120.0, g.z), AppState.TIER_COLORS["illustrative"], 52, 0.8),
	]


func _build_detail(main: Node) -> void:
	var v: Node3D = main.volumes
	var g: Vector3 = main.gbr
	var base_y: float = v.surface_elevation(0.0, g.x, g.z)
	_columns = MultiMeshInstance3D.new()
	_columns.name = "columns"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var prism := CylinderMesh.new()
	prism.radial_segments = 6
	prism.top_radius = 0.25
	prism.bottom_radius = 0.25
	prism.height = 6.0
	mm.mesh = prism
	mm.instance_count = 400
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var along := _cut_normal.cross(Vector3.UP).normalized()   # strike of the cut face
	for i in mm.instance_count:
		var q: Vector3 = g + along * rng.randf_range(-140.0, 140.0) + _cut_normal * rng.randf_range(-0.6, 0.6)
		var x: float = q.x
		var z: float = q.z
		var y: float = v.surface_elevation(6.5 + 3.0, x, z)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, y, z)))
	_columns.multimesh = mm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.45, 0.48, 0.5)
	_columns.material_override = cm
	_columns.custom_aabb = AABB(Vector3(-7000, -500, -6000), Vector3(14000, 1000, 12000))
	main.extras.add_child(_columns)
	_pillows = MultiMeshInstance3D.new()
	_pillows.name = "pillows"
	var pm := MultiMesh.new()
	pm.transform_format = MultiMesh.TRANSFORM_3D
	var sph := SphereMesh.new()
	sph.radius = 0.4
	sph.height = 0.8
	pm.mesh = sph
	pm.instance_count = 600
	for i in pm.instance_count:
		var q: Vector3 = g + along * rng.randf_range(-140.0, 140.0) + _cut_normal * rng.randf_range(-0.5, 0.5)
		var x: float = q.x
		var z: float = q.z
		var y: float = v.surface_elevation(0.3 + rng.randf() * 6.0, x, z)
		var s := 0.75 + rng.randf() * 0.4
		pm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(s, s * 0.8, s)), Vector3(x, y, z)))
	_pillows.multimesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.3, 0.33, 0.36)
	_pillows.material_override = pmat
	_pillows.custom_aabb = AABB(Vector3(-7000, -500, -6000), Vector3(14000, 1000, 12000))
	main.extras.add_child(_pillows)
	main.make_label("pillows 0.6-0.9 m (Observed size, Illustrative placement)", g + _cut_normal * 3.0 + Vector3(0, 4.0, 0) + along * 40.0, AppState.TIER_COLORS["observed"], 40, 0.25)
	main.make_label("columnar joints <= 0.5 m x 6 m (Observed size, Illustrative placement)", g + _cut_normal * 3.0 + Vector3(0, 12.0, 0) + along * 40.0, AppState.TIER_COLORS["observed"], 40, 0.25)


func set_t(t: float, main: Node) -> void:
	var v: Node3D = main.volumes
	for k in _grow:
		var w: Array = _grow[k]
		v.set_growth(k, ramp(t, w[0], w[1]))
		# incandescent while growing, cooling over the next 15 % of the scrubber
		var gl := 0.0
		if t >= w[0]:
			gl = 1.0 - ramp(t, w[1], w[1] + 0.15)
		v.set_glow(k, gl)
	if _pillows:
		_pillows.visible = t >= 0.1
		_columns.visible = t >= 0.3
	_molten_cues(main, v)


## Heat shimmer over the hottest growing layer and a low rumble while anything is molten (polish pass).
func _molten_cues(main: Node, v: Node3D) -> void:
	var g: Vector3 = main.gbr
	var best := 0.0
	var top_y := 0.0
	for k in _grow:
		var gl: float = v.glow.get(k, 0.0)
		if gl > best:
			best = gl
			var e: Dictionary = v.layer_info(k)
			top_y = v.surface_elevation(v.layer_base(e, g.x, g.z) + (v.layer_top(e, g.x, g.z) - v.layer_base(e, g.x, g.z)) * float(v.growth.get(k, 1.0)), g.x, g.z)
	v.set_shimmer(top_y, best, g, Vector2(BOX.x * 2.0, BOX.z * 2.0))
	main.ambience.set_levels(0.0, best)


func exit(main: Node) -> void:
	main.volumes.set_shimmer(0.0, 0.0, Vector3.ZERO, Vector2.ONE)
	main.ambience.set_levels(0.0, 0.0)
	main.volumes.reset_growth()
	main.volumes.set_clip_to_terrain(true)
	main.volumes.set_box_clip(false)
	main.terrain.set_ghost(false)
	main.features.set_group_filter([])
	main.volumes.set_era_visibility([])
	AppState.cut_enabled = false
	main.clear_extras()
	_labels.clear()
	_pillows = null
	_columns = null
