extends Chapter
## Chapter 5: flow-top exposure, Jps1, second flow, burial. Source: section 2, 4.1, 5.3; GMS 04-02 (Jps 6-25 ft,
## Towaco ~1,250 ft); Puffer & Volkert 2001 (Jps 2-8 m, second flow 80 m). Untilted stack in a block.

var _label: Label3D
var _cut_normal := Vector3(0.65, 0.0, -0.76).normalized()
const BOX := Vector3(3000, 0, 2500)
const GROW := {"jps1": [0.25, 0.38], "second_flow_base": [0.4, 0.45], "second_flow": [0.45, 0.62], "upper_preakness": [0.65, 0.82], "towaco": [0.85, 1.0]}


func _init() -> void:
	id = "burial"
	title = "5. Flow-top exposure, second flow and burial"
	short_title = "5"
	uses_flat_stack = true
	narration = "The first flow's top is exposed at the surface long enough for about 2 m of reddish-brown fluvial siltstone and shale (Jps1) to settle on its vesicular crust. Then the ~70 m second flow erupts over it, massive basalt with pipe vesicles at its base, followed by the rest of the Preakness and the Towaco Formation (about 380 m on the Chatham map). Burial heats the Feltville to 90-130 C, a constraint the paper uses when testing fluid temperatures."
	basic_narration = "The lava top sits at the surface long enough to collect 2 m of river silt, then a second 70 m flow, the rest of the Preakness and hundreds of metres of Towaco red beds bury it. Deep burial warms the rocks to 90-130 C. The carnelian in the flow top is now sealed a few hundred metres down."
	refs = "section 2; section 4.1; section 5.3 [87]; Fig. 3c; GMS 04-02; Puffer & Volkert 2001"
	strip_from = 200.98e6
	strip_to = 150.0e6
	scrub_label = "Exposure (length unknown) -> Jps1 -> second flow -> burial under upper Preakness and Towaco"
	scrub_units = "illustrative sequence; only thicknesses are Observed"
	scrub_marks = [[0.0, "First-flow top exposed, eroding"], [0.25, "Jps1: ~2-3 m fluvial siltstone/shale"], [0.4, "Second flow erupts (~70 m)"], [0.65, "Upper Preakness flows (to 315 m total)"], [0.85, "Towaco Formation (~380 m)"], [1.0, "Buried: Feltville at 90-130 C"]]
	evidence = [
		{"text": "Flows separated by ~2-3 m of thin-bedded reddish-brown fluvial siltstone and shale (Jps1) deposited on the first flow's top (map: 6-25 ft; Puffer & Volkert: 2-8 m).", "ref": "section 2, Fig. 2, Fig. 3c; GMS 04-02; Puffer & Volkert 2001"},
		{"text": "The valley's western part marks the eroded top of the first flow, subaerially exposed at 201 Ma long enough for ~2 m of sediment to accumulate before the second flow.", "ref": "section 4.1"},
		{"text": "Second flow 70 m (80 m regionally): massive basalt with pipe vesicles at the base, widely spaced blocky columns above, a few very thin gabbroid layers.", "ref": "section 2; Puffer & Volkert 2001"},
		{"text": "Preakness total 315 m, at least three flows; Towaco Formation maximum about 1,250 ft (381 m); Hook Mountain Basalt about 360 ft above it.", "ref": "section 2; GMS 04-02"},
		{"text": "Burial temperature 90-130 C from thermally mature hydrocarbons in the Feltville.", "ref": "section 5.3 [87]"},
	]
	tiers = {"Observed": "Jps1 thickness and lithology; second-flow thickness and base features; 315 m total; the Towaco maximum; the burial temperature.",
		"Illustrative": "The exposure interval's length, the burial timing, the third-flow thickness (filler), and that the ground was flat."}
	key_items = [{"name": "Incandescent = still molten (cosmetic cue)", "color": Color(1.0, 0.45, 0.08), "tier": "illustrative"}]


func enter(main: Node, animate: bool) -> void:
	var g: Vector3 = main.gbr
	var v: Node3D = main.volumes
	var top: float = v.surface_elevation(145.0, g.x, g.z)
	start_look = Vector3(g.x, top + 120.0, g.z)
	start_pos = start_look + _cut_normal * 2600.0 + Vector3(0, 78, 0)
	tour_beats = [
		beat(0.0, "The cooled first flow lies open to the sky: its vesicular top weathers and erodes (exposure length unknown).", Vector3(g.x, top, g.z) + _cut_normal * 800.0 + Vector3(0, 24, 0), Vector3(g.x, top, g.z), ["amygdaloidal_top"], {"move": {"orbit": 20.0, "dolly": [1.3, 0.95]}}),
		beat(0.24, "A river lays 2-3 m of reddish siltstone and shale (Jps1) on the flow top: proof the top was a land surface.", Vector3(g.x, top + 2.0, g.z) + _cut_normal * 300.0 + Vector3(0, 9, 0), Vector3(g.x, top + 2.0, g.z), ["jps1"]),
		beat(0.4, "The second flow erupts over it: massive basalt with pipe vesicles at its base, about 70 m thick.", Vector3(g.x, top + 35.0, g.z) + _cut_normal * 700.0 + Vector3(0, 21, 0), Vector3(g.x, top + 35.0, g.z), ["second_flow_base", "second_flow"], {"move": {"dolly": [1.4, 0.85], "orbit": 15.0}}),
		beat(0.64, "More flows bring the Preakness to 315 m in total.", Vector3(g.x, top + 120.0, g.z) + _cut_normal * 1500.0 + Vector3(0, 45, 0), Vector3(g.x, top + 120.0, g.z), ["upper_preakness"]),
		beat(0.84, "The Towaco Formation (about 380 m of red beds) buries everything; the carnelian horizon is now several hundred metres down.", Vector3(g.x, top + 200.0, g.z) + _cut_normal * 2600.0 + Vector3(0, 78, 0), Vector3(g.x, top + 200.0, g.z), ["towaco"], {"move": {"dolly": [0.8, 1.4], "rise": 250.0}}),
		beat(0.97, "Burial heating: the Feltville reaches 90-130 C (hydrocarbon maturity), a ceiling for the fluids that formed the carnelian.", Vector3(g.x, top - 100.0, g.z) + _cut_normal * 2600.0 + Vector3(0, 78, 0), Vector3(g.x, top - 100.0, g.z), ["feltville"]),
	]
	super.enter(main, animate)
	main.clear_extras()
	AppState.cut_enabled = true
	AppState.cut_plane = Plane(_cut_normal, _cut_normal.dot(g))
	v.set_clip_to_terrain(false)
	v.set_box_clip(true, g - BOX - Vector3(0, 1.0e6, 0), g + BOX + Vector3(0, 1.0e6, 0))
	main.terrain.set_ghost(true)
	main.features.set_group_filter(["sites"])
	v.set_era_visibility(["passaic", "orange_mountain", "feltville", "feltville_aureole", "glass_rind", "pillow_zone", "columnar_zone", "gabbroid",
		"glass_rich_gabbroid", "massive_top", "amygdaloidal_top", "jps1", "second_flow_base", "second_flow", "upper_preakness", "towaco"] + v.zone_a_keys())
	_label = main.make_label("", Vector3(g.x, top + 520.0, g.z), Color(1.0, 0.8, 0.5), 60, 1.0)


func set_t(t: float, main: Node) -> void:
	var v: Node3D = main.volumes
	for k in GROW:
		var w: Array = GROW[k]
		v.set_growth(k, ramp(t, w[0], w[1]))
		var gl := 0.0
		if k in ["second_flow_base", "second_flow", "upper_preakness"] and t >= w[0]:
			gl = 1.0 - ramp(t, w[1], w[1] + 0.12)
		v.set_glow(k, gl)
	if _label:
		_label.text = "Burial heating: Feltville reaches 90-130 C (Observed, from hydrocarbon maturity)" if t >= 0.95 else ""
	var g: Vector3 = main.gbr
	var best := 0.0
	var top_y := 0.0
	for k in GROW:
		var gl: float = v.glow.get(k, 0.0)
		if gl > best:
			best = gl
			var e: Dictionary = v.layer_info(k)
			top_y = v.surface_elevation(v.layer_base(e, g.x, g.z) + (v.layer_top(e, g.x, g.z) - v.layer_base(e, g.x, g.z)) * float(v.growth.get(k, 1.0)), g.x, g.z)
	v.set_shimmer(top_y, best, g, Vector2(BOX.x * 2.0, BOX.z * 2.0))
	main.ambience.set_levels(0.0, best)


func exit(main: Node) -> void:
	AppState.cut_enabled = false
	main.volumes.set_shimmer(0.0, 0.0, Vector3.ZERO, Vector2.ONE)
	main.ambience.set_levels(0.0, 0.0)
	main.volumes.reset_growth()
	main.volumes.set_clip_to_terrain(true)
	main.volumes.set_box_clip(false)
	main.terrain.set_ghost(false)
	main.features.set_group_filter([])
	main.volumes.set_era_visibility([])
	main.clear_extras()
