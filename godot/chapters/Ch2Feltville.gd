extends Chapter
## Chapter 2: Feltville deposition. Source: section 2; GMS 04-02 unit description. Shown on the UNTILTED stack
## (beds were flat at deposition), boxed to a 6 x 5 km block around GBR; today's surface is a ghost.

var _label: Label3D
var _cut_normal := Vector3(0.65, 0.0, -0.76).normalized()
const BOX := Vector3(3000, 0, 2500)


func _init() -> void:
	id = "feltville"
	title = "2. Feltville Formation deposition"
	short_title = "2"
	uses_flat_stack = true
	narration = "Before the Preakness erupted, 145 m of reddish-brown fluvial sandstone, siltstone and silty shale (the Feltville Formation) accumulated on the Orange Mountain Basalt. Near its base are two 3 m sequences of black carbonaceous shale, limestone and calcareous siltstone from shallow to deep lakes. This is the floor the first Preakness flow will land on; its top 0.5 m will be baked by that flow. The beds are shown flat, as they were laid down; today's 9.5 degree tilt came later."
	basic_narration = "Rivers lay down 145 m of red sandstone and siltstone on the Orange Mountain Basalt, with two thin black lake beds near the base. This flat floor is what the first Preakness lava will land on. Today's land surface is shown as a faint ghost for orientation."
	refs = "section 2 [22-24]; Fig. 2; GMS 04-02 (450-483 ft)"
	strip_from = 201.6e6
	strip_to = 201.0e6
	scrub_label = "Feltville section deposited (0 -> 145 m)"
	scrub_units = "metres of section (Observed thickness; rate and duration not given)"
	scrub_marks = [[0.0, "0 m: on Orange Mountain Basalt"], [0.14, "~20 m: lacustrine sequence 1"], [0.24, "~35 m: lacustrine sequence 2"], [1.0, "145 m: top of Feltville"]]
	evidence = [
		{"text": "145 m thick; fine- to coarse-grained sandstone, siltstone, silty shale of quartz, white mica and feldspar; fluvial. The Chatham map gives 450-483 ft.", "ref": "section 2 [22,23]; GMS 04-02"},
		{"text": "Two 3 m lacustrine sequences near the base (each 'as much as 10 ft' on the map): dark gray-black carbonaceous shale, light-gray limestone, calcareous siltstone, gray/olive shale (Washington Valley Member).", "ref": "section 2 [22-24]; GMS 04-02"},
		{"text": "Uppermost ~0.5 m thermally altered at the Preakness contact ('several inches' on the map).", "ref": "section 2; GMS 04-02"},
		{"text": "Feltville hydrocarbons record a later burial temperature of 90-130 C.", "ref": "section 5.3 [87]"},
		{"text": "Ruled out as the silica source: fluidised-sand injection would have left sediment-filled fractures in the basalt, which are not observed; dissolution of detrital quartz remains possible but is not the paper's preferred option.", "ref": "section 5.1"},
	]
	tiers = {"Observed": "Thickness, lithologies, the two lacustrine sequences, the 0.5 m aureole; that the beds were deposited flat.",
		"Illustrative": "Where exactly the lacustrine sequences sit ('near the base' -> drawn at ~20 and ~35 m), the depositional duration, the flat paleo-surface, and the 6 x 5 km block the stack is drawn in."}


func enter(main: Node, animate: bool) -> void:
	var g: Vector3 = main.gbr
	var base: float = main.volumes.surface_elevation(-145.0, g.x, g.z)
	start_look = Vector3(g.x, base + 60.0, g.z)
	start_pos = start_look + _cut_normal * 2400.0 + Vector3(0, 72, 0)
	tour_beats = [
		beat(0.0, "The floor: Orange Mountain Basalt (218 m, three flows). Beds are shown flat, as deposited; the box is 6 x 5 km around GBR.", start_pos, start_look, [], {"move": {"dolly": [1.5, 1.0], "orbit": 12.0}}),
		beat(0.03, "Rivers spread reddish-brown sand and silt across the floodplain: the Feltville Formation begins.", Vector3(g.x, base + 30.0, g.z) + _cut_normal * 1400.0 + Vector3(0, 42, 0), Vector3(g.x, base + 30.0, g.z)),
		beat(0.13, "A lake forms: 3 m of black carbonaceous shale, limestone and calcareous siltstone (lacustrine sequence 1).", Vector3(g.x, base + 22.0, g.z) + _cut_normal * 500.0 + Vector3(0, 15, 0), Vector3(g.x, base + 22.0, g.z), ["feltville_lacustrine_1"]),
		beat(0.23, "A second 3 m lake sequence about 15 m higher; both carry fish, reptile and plant fossils (map text).", Vector3(g.x, base + 36.0, g.z) + _cut_normal * 500.0 + Vector3(0, 15, 0), Vector3(g.x, base + 36.0, g.z), ["feltville_lacustrine_2"]),
		beat(0.35, "Fluvial red beds continue to 145 m (Observed thickness; the rate and duration are not given).", Vector3(g.x, base + 90.0, g.z) + _cut_normal * 1600.0 + Vector3(0, 48, 0), Vector3(g.x, base + 90.0, g.z), ["feltville"], {"move": {"orbit": 22.0, "dolly": [1.25, 0.85]}}),
		beat(0.98, "Top of the Feltville: the surface the first Preakness flow will bake (0.5 m aureole).", Vector3(g.x, base + 145.0, g.z) + _cut_normal * 700.0 + Vector3(0, 21, 0), Vector3(g.x, base + 145.0, g.z), ["feltville_aureole"]),
	]
	super.enter(main, animate)
	main.clear_extras()
	AppState.cut_enabled = true
	AppState.cut_plane = Plane(_cut_normal, _cut_normal.dot(g))
	main.volumes.set_clip_to_terrain(false)
	main.volumes.set_box_clip(true, g - BOX - Vector3(0, 1.0e6, 0), g + BOX + Vector3(0, 1.0e6, 0))
	main.terrain.set_ghost(true)
	main.features.set_group_filter(["sites"])
	main.volumes.set_era_visibility(["passaic", "orange_mountain", "feltville", "feltville_lacustrine_1", "feltville_lacustrine_2", "feltville_aureole"])
	_label = main.make_label("Beds shown FLAT, as deposited (today's 9.5 deg tilt came with later folding). Today's land surface = ghost, for orientation only.", Vector3(g.x, base + 330.0, g.z - 1200.0), AppState.TIER_COLORS["illustrative"], 56, 1.0)


func set_t(t: float, main: Node) -> void:
	var v: Node3D = main.volumes
	v.set_growth("feltville", maxf(t, 0.002))
	v.set_growth("feltville_lacustrine_1", ramp(t, 0.14, 0.16))
	v.set_growth("feltville_lacustrine_2", ramp(t, 0.24, 0.26))
	v.set_growth("feltville_aureole", ramp(t, 0.975, 0.99))   # appears during the last beat


func scrub_text(t: float) -> String:
	return "%d m of Feltville deposited" % int(round(t * 145.0))


func exit(main: Node) -> void:
	AppState.cut_enabled = false
	main.volumes.reset_growth()
	main.volumes.set_clip_to_terrain(true)
	main.volumes.set_box_clip(false)
	main.terrain.set_ghost(false)
	main.features.set_group_filter([])
	main.volumes.set_era_visibility([])
	main.clear_extras()
