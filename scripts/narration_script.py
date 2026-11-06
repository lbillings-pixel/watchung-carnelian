"""The guided tour's narration script (round 4).

One entry per chapter (keyed by the chapter id used in godot/chapters/*.gd), one beat per tour beat, in the same
order as the chapter's `tour_beats`.  The spoken text is adapted from the chapter overview texts and the beat
captions, rewritten to be read aloud; everything factual in it comes from Volkert et al. (2023), the Chatham
maps (GMS 04-02, OFM 69), Puffer & Volkert (2001) and the cited fluid studies, as logged in ASSUMPTIONS.md.

Each beat is {"text": ..., "cues": [(phrase, target), ...]}.  A cue fires when the narration first reaches
`phrase` (matched case-insensitively inside the text; the phrase must occur) and pulses a glowing outline on the
target for a few seconds:
  "layers": subsurface layer keys from layers.json ("zone_a" = all six vesicle-rich sheets)
  "nodes":  names of nodes the chapter builds under Extras (see the chapter scripts) or "features:<group>"
  "ring":   a ground ring: ["gbr", r] / ["sgb", r] (sample-site centres) or [x, z, r] in scene metres
Pronunciation fixes for the speech engine are in PHONEME_FIXES (IPA, Kokoro's alphabet).
"""

VOICE = "af_heart"      # Kokoro voice (grade A in the Kokoro voice list); see build_narration.py --voice
SPEED = 0.95            # a touch slower than the engine's default for a documentary pace

# word -> IPA used instead of the engine's own phonemisation (espeak-ng gets these wrong or oddly stressed)
PHONEME_FIXES = {
    "Pleistocene": "plˈaɪstɛsˌiːn",
    "amygdaloidal": "əmˌɪɡdəlˈɔɪdəl",
    "chalcedony": "kælsˈɛdəni",
    "columnar": "kəlˈʌmnɚ",
    "botryoidal": "bˌɑːtɹiˈɔɪdəl",
    "moganite": "mˈoʊɡənˌaɪt",
    "Illinoian": "ˌɪlɪnˈɔɪən",
    # user review, round 4: "buh-sahlt", "my-oh-seen", "ply-steh-seen"
    "basalt": "bəsˈɑːlt",
    "basaltic": "bəsˈɑːltɪk",
    "Miocene": "mˈaɪoʊsˌiːn",
    "Pliocene": "plˈaɪoʊsˌiːn",
}


def L(*keys):
    return {"layers": list(keys)}


def N(*names):
    return {"nodes": list(names)}


def R(where, r):
    return {"ring": [where, r] if isinstance(where, str) else [where[0], where[1], r]}


def LN(layers, nodes):
    return {"layers": list(layers), "nodes": list(nodes)}


SCRIPT = {
    # ------------------------------------------------------------------ 1. basement (5 beats)
    "basement": [
        {"text": "Let's start a long way back, and a little to the west. This block is a schematic, not to scale: "
                 "the ancient Highlands gneiss that lies beneath and beyond the edge of the basin, more than a billion "
                 "years old. Inside it sit deposits of magnetite, rich in uranium, thorium and rare earth elements.",
         "cues": [("Highlands gneiss", N("gneiss")), ("deposits of magnetite", N("magnetite_1", "magnetite_2"))]},
        {"text": "Nearby are younger Neoproterozoic ironstones, carrying hematite, uranium, thorium and tungsten. "
                 "Together with the gneiss and the magnetite, these are the only rocks in New Jersey rich enough in "
                 "those elements to be the source of what we later find in the carnelian.",
         "cues": [("ironstones", N("ironstone"))]},
        {"text": "Around two hundred million years ago the crust stretched and broke. The Newark basin dropped down "
                 "along its border fault and filled with red sediment, and lava flows, the Preakness among them, "
                 "spread across it.",
         "cues": [("border fault", N("border_fault")), ("filled with red sediment", N("basin_fill")),
                  ("the Preakness", N("preakness_schematic"))]},
        {"text": "Rain water sank along the border fault, deep into the hot basement. Fluid inclusions and reset "
                 "fission tracks tell us it reached somewhere between one hundred and two hundred and eighty degrees "
                 "Celsius, turned acidic, and picked up chlorine and fluorine. Water like that strips uranium, "
                 "thorium, niobium, tungsten and rare earths out of the rock.",
         "cues": [("Rain water", N("fluid")), ("border fault, deep", N("border_fault"))]},
        {"text": "Heated and loaded with those elements, the fluid rose again along faults inside the basin, toward "
                 "the young Preakness lava. Nearly every trace element later measured in the carnelian can be traced "
                 "to this journey.",
         "cues": [("the fluid rose", N("fluid")), ("faults inside the basin", N("intrabasinal_fault"))]},
    ],
    # ------------------------------------------------------------------ 2. feltville (6 beats)
    "feltville": [
        {"text": "Now we move to the basin floor itself, a little over two hundred and one million years ago. This "
                 "is a six by five kilometre block around the Green Brook site, with the beds laid flat, as they "
                 "were deposited. The faint ghost above is today's land surface, just for orientation. The floor is "
                 "the Orange Mountain Basalt: more than two hundred metres of older lava, already in place.",
         "cues": [("Green Brook site", R("gbr", 400.0)), ("Orange Mountain Basalt", L("orange_mountain"))]},
        {"text": "Rivers begin to spread reddish-brown sand and silt across the floodplain. This is the Feltville "
                 "Formation.",
         "cues": [("Feltville Formation", L("feltville"))]},
        {"text": "Early on, a lake forms. It leaves three metres of black carbonaceous shale, limestone and "
                 "calcareous siltstone.",
         "cues": [("three metres", L("feltville_lacustrine_1"))]},
        {"text": "A second lake sequence follows about fifteen metres higher. Both carry fossils of fish, reptiles "
                 "and plants.",
         "cues": [("second lake", L("feltville_lacustrine_2"))]},
        {"text": "Then the red river beds just keep coming, until the Feltville is a hundred and forty-five metres "
                 "thick. That thickness is measured. How long it took is not something the sources tell us.",
         "cues": [("red river beds", L("feltville"))]},
        {"text": "And here is the top of the Feltville. The first Preakness flow will land on this surface and bake "
                 "its upper half metre.",
         "cues": [("top of the Feltville", L("feltville_aureole"))]},
    ],
    # ------------------------------------------------------------------ 3. eruption (7 beats)
    "eruption": [
        {"text": "Two hundred and one million years ago. The Feltville floodplain lies partly under shallow water, "
                 "and our cut face runs from north-west to south-east through the Green Brook site.",
         "cues": [("Green Brook site", R("gbr", 400.0))]},
        {"text": "Lava arrives and meets standing water. Where it chills it forms a glass rind only a couple of "
                 "centimetres thick, and pillow lobes, each about the size of a beach ball, pile up through the "
                 "lowest few metres of the flow.",
         "cues": [("glass rind", L("glass_rind")), ("pillow lobes", LN(["pillow_zone"], ["pillows"]))]},
        {"text": "Above the pillows, the lower flow cools into the colonnade: slender columns no more than half a "
                 "metre wide and six metres long.",
         "cues": [("colonnade", LN(["columnar_zone"], ["columns"]))]},
        {"text": "The flow is thick, and its interior stays molten for a long time. Crystals settle and sort, and "
                 "build a coarse-grained lens called gabbroid: eighty-two metres thick here, forty-nine at Stirling "
                 "Brook. It is the thickest gabbroid in the basin, and it is the reason carnelian turns up here and "
                 "nowhere else.",
         "cues": [("lens called gabbroid", L("gabbroid"))]},
        {"text": "Gas rising through the flow is trapped beneath that coarse barrier. It collects in six thin "
                 "vesicle-rich sheets in the upper forty metres, with up to nineteen percent bubbles, around a band "
                 "rich in black glass. Keep an eye on these sheets. This is where the carnelian will grow.",
         "cues": [("vesicle-rich sheets", L("zone_a")), ("black glass", L("glass_rich_gabbroid"))]},
        {"text": "The top of the flow freezes as a crust two and a half metres thick and full of bubbles: the "
                 "amygdaloidal flow top. The paper names it as the other candidate for the carnelian's birthplace.",
         "cues": [("amygdaloidal flow top", L("amygdaloidal_top"))]},
        {"text": "And then it is done. A hundred and forty-five metres of basalt, cooled, with a gabbroid lens in "
                 "its upper half.",
         "cues": [("gabbroid lens", L("gabbroid"))]},
    ],
    # ------------------------------------------------------------------ 4. precipitation (8 beats)
    "precipitation": [
        {"text": "This is the heart of the story. Hot, acidic fluid, shown as the red particles, rises from depth "
                 "along the columns and faults into the upper part of the first flow.",
         "cues": [("red particles", N("hydro"))]},
        {"text": "From above, cool, more alkaline rain water sinks to meet it: the blue particles. Where they mix, "
                 "the temperature settles mostly between twenty and eighty degrees, and the water turns neutral to "
                 "slightly alkaline. That mixing zone is the coloured field.",
         "cues": [("blue particles", N("meteor")), ("coloured field", N("field"))]},
        {"text": "Glass in the gabbroid breaks down and releases silica into the mix. Now, where exactly did the "
                 "carnelian form? The paper offers two candidates and does not choose between them: zone A, the "
                 "six vesicle-rich sheets, and zone B, the bubbly flow top.",
         "cues": [("Glass in the gabbroid", L("glass_rich_gabbroid")), ("zone A", L("zone_a")),
                  ("zone B", L("amygdaloidal_top"))]},
        {"text": "Let's go inside. This is one gas bubble, eight millimetres across, in the uppermost sheet; the "
                 "view is about a centimetre and a half wide. A crystal of glauberite, a sodium calcium sulphate, "
                 "is already sitting in it.",
         "cues": [("crystal of glauberite", N("glauberite"))]},
        {"text": "Silica begins to come out of solution. Fibres of chalcedony nucleate on the bumpy floor of the "
                 "bubble and grow upward.",
         "cues": [("Fibres of chalcedony", N("carnelian"))]},
        {"text": "As the fill thickens, its top takes the grape-like, botryoidal shape seen on the real pieces. "
                 "Tiny inclusions of hematite give it the red colour. This is carnelian.",
         "cues": [("botryoidal shape", N("bots"))]},
        {"text": "Later, the glauberite dissolves and leaves a mold. It is this order of events, bubble, then "
                 "glauberite, then carnelian, that the paper reads from the textures.",
         "cues": [("glauberite dissolves", N("glauberite"))]},
        {"text": "Under the microscope, at two thousand times, the carnelian shows bundles of length-fast fibres "
                 "rising from the attachment band, crossed by rhythmic extinction bands. This is the texture that "
                 "confirmed the growth sequence.",
         "cues": [("Under the microscope", N("micro"))]},
    ],
    # ------------------------------------------------------------------ 5. burial (6 beats)
    "burial": [
        {"text": "The first flow now lies open to the sky. Its bubbly top weathers and erodes. For how long, we do "
                 "not know.",
         "cues": [("bubbly top", L("amygdaloidal_top"))]},
        {"text": "A river lays two to three metres of reddish siltstone and shale on it. That thin layer is proof "
                 "that the flow top was once a land surface.",
         "cues": [("siltstone and shale", L("jps1"))]},
        {"text": "Then the second Preakness flow erupts over it: massive basalt, with pipe vesicles at its base, "
                 "about seventy metres thick.",
         "cues": [("second Preakness flow", L("second_flow", "second_flow_base"))]},
        {"text": "More flows follow, until the Preakness is three hundred and fifteen metres thick in total.",
         "cues": [("More flows", L("upper_preakness"))]},
        {"text": "Then the Towaco Formation, nearly four hundred metres of red beds, buries everything. The "
                 "carnelian horizon is now several hundred metres down.",
         "cues": [("Towaco Formation", L("towaco"))]},
        {"text": "Deep burial warms the rocks. Hydrocarbons in the Feltville show that it reached ninety to a hundred "
                 "and thirty degrees, a ceiling the paper uses when it tests the fluid temperatures.",
         "cues": [("Feltville", L("feltville"))]},
    ],
    # ------------------------------------------------------------------ 6. erosion (6 beats)
    "erosion": [
        {"text": "Time to tilt. As the Watchung syncline folds, the whole stack rotates about nine and a half "
                 "degrees toward the north-west. The attitude comes from the Chatham map's cross-section. When it "
                 "happened, the paper does not say.",
         "cues": [("whole stack", L("gabbroid", "feltville", "orange_mountain"))]},
        {"text": "Uplift follows. By the middle to late Miocene a broad river plain lies at or above the highest "
                 "basalt summits, more than fifty metres above where the carnelian sites are today.",
         "cues": [("river plain", N("plain"))]},
        {"text": "Then, through the Pliocene and Pleistocene, the rivers cut down. The deep valley on the soft "
                 "Feltville red beds, between the two basalt ridges, forms first.",
         "cues": [("deep valley", R((1500.0, 500.0), 900.0)), ("soft Feltville", L("feltville"))]},
        {"text": "Only later do headwater tributaries, Green Brook and Stirling Brook, bite back into the Preakness "
                 "ridge. Their valley sides reach the carnelian horizon: the six sheets, outlined here.",
         "cues": [("Green Brook", R("gbr", 450.0)), ("carnelian horizon", L("zone_a"))]},
        {"text": "Where the horizon meets the surface, marked by the red dots, pieces of carnelian weather out, then "
                 "creep and wash down the slope into Green Brook. The pieces are drawn three metres across so that "
                 "you can see them at this scale.",
         "cues": [("red dots", N("trace")), ("pieces of carnelian", N("pebbles"))]},
        {"text": "And this is today's surface, from the lidar. The carnelian horizon still runs through the valley "
                 "sides, hidden under soil and rock debris.",
         "cues": [("carnelian horizon", L("zone_a"))]},
    ],
    # ------------------------------------------------------------------ 7. present (8 beats)
    "present": [
        {"text": "Ice came close, twice. In the early Pleistocene a glacier stopped at the dashed line marked M one. "
                 "Its till survives in the headwaters of Green Brook's north-eastern tributary. Stirling Brook lies "
                 "two kilometres south of that line.",
         "cues": [("Its till", R((1300.0, -2600.0), 700.0)), ("Stirling Brook", R("sgb", 400.0))]},
        {"text": "Much later, the late Wisconsinan ice sheet built its terminal moraine and dammed glacial Lake "
                 "Passaic, at the line marked M two, well to the north. Neither glacier reached the carnelian brooks.",
         "cues": [("terminal moraine", R((-3500.0, -5000.0), 1200.0))]},
        {"text": "Today, at Green Brook, the cut face shows the cover: colluvium up to eighteen metres thick and "
                 "alluvium up to three, resting on the bedrock top. The trace of the carnelian horizon runs along "
                 "the valley sides beneath it.",
         "cues": [("cut face", R("gbr", 120.0)), ("trace of the carnelian horizon", LN(["zone_a"], ["trace"]))]},
        {"text": "Down at the brook, a gravel bar of basalt and gabbroid cobbles rests on a pavement of gabbroid. "
                 "Among the cobbles are the carnelian pebbles, one to five and a half centimetres across, drawn "
                 "larger here.",
         "cues": [("gravel bar", N("cobbles_GBR")), ("carnelian pebbles", N("pebbles_GBR"))]},
        {"text": "A flood rises, and muddy water covers the bar.",
         "cues": []},
        {"text": "At peak flow the current scours the alluvium off the bed and exposes the hidden bedrock source, "
                 "the outline you see here. This is the paper's second scenario.",
         "cues": [("hidden bedrock source", N("source_GBR"))]},
        {"text": "As the water drops, fresh pebbles are left in the bar, or not. Under the first scenario the source "
                 "is largely gone and the supply thins with every flood. Under the second, floods keep delivering. "
                 "You can switch between them in the panel at the left.",
         "cues": [("fresh pebbles", N("pebbles_GBR"))]},
        {"text": "After the flood. The paper prefers replenishment: collectors have kept finding carnelian here for "
                 "decades.",
         "cues": []},
    ],
    # ------------------------------------------------------------------ W. worm (7 beats)
    "worm": [
        {"text": "Finally, let's follow one piece. Two hundred and one million years ago, inside a bubble eight "
                 "millimetres across in the upper first flow, silica from the mixing fluids builds a nodule, fibre "
                 "by fibre, beside a glauberite crystal.",
         "cues": [("builds a nodule", N("nodule")), ("glauberite crystal", N("glauberite"))]},
        {"text": "The second flow, the rest of the Preakness and the Towaco red beds pile on top. The nodule sits "
                 "several hundred metres down, at ninety to a hundred and thirty degrees.",
         "cues": [("pile on top", N("overburden"))]},
        {"text": "The Watchung syncline folds, and the rock around the nodule tilts nine and a half degrees to the "
                 "north-west.",
         "cues": [("rock around the nodule", N("block"))]},
        {"text": "Erosion cuts the Green Brook valley down to the horizon. Frost, roots and water loosen the "
                 "vesicular rock, and the nodule falls free at the real outcrop of the sheets, on the real hillside.",
         "cues": [("nodule falls free", N("nodule_big"))]},
        {"text": "It creeps and washes down the valley side, which is the actual Green Brook slope from the lidar, "
                 "at one to one, in a blanket of angular basalt debris. The cut wall beside the path shows the "
                 "modelled layers underneath.",
         "cues": []},   # the hillside and wall fill the view here; a rim shell on them washes the whole slope
        {"text": "A flood sweeps it into the brook. Rolled and chipped, it becomes a subangular to subrounded "
                 "pebble, one to five centimetres, like the ones collected.",
         "cues": [("A flood", N("water"))]},
        {"text": "The water drops and leaves it in a gravel bar of basalt and gabbroid cobbles on gabbroid pavement, "
                 "where someone might find it.",
         "cues": [("gravel bar", N("bar"))]},
    ],
}
