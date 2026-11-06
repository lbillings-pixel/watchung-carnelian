# PLAN — 3D time-lapse of New Jersey carnelian formation

Primary source throughout: Volkert, R.A., Gorring, M.L., Peck, W.H., Stanford, S.D. (2023).
Characterization and Origin of Basalt-Derived Carnelian in the Mesozoic Newark Basin, New Jersey, USA.
*Minerals* 13(10), 1249. https://doi.org/10.3390/min13101249 (open access; the PDF states CC BY 4.0).
Section references below ("§4.2", "Fig. 2", "Table 4") are to that paper.

## 1. What the app is

A Godot 4 desktop app. One 3D scene of the Green Brook – Stirling Brook valley (Chatham quadrangle,
Newark basin, NJ) built on real lidar terrain and real map contacts, with the subsurface extruded from
the paper's thicknesses and the dip of the Chatham map's cross-section. Seven chapters walk the paper's
argument from the Proterozoic basement to a present-day flood; an eighth, "worm's-eye" chapter follows one
nodule from its vesicle to a gravel bar. Each chapter has its own time scrubber and a set of guided-tour
beats; a global strip shows where it sits in the full history. The screen has a basic and an advanced
mode. Every visible element carries a certainty tier (Observed / Inferred / Illustrative, plus a fourth
"Mindat-reported" class for user-contributed localities) and a reference.

## 2. Study area

- Figure 2 covers ~74°30′ W to ~74°23.6′ W and ~40°37.5′ N to ~40°40.5′ N (read off its graticule).
- App bounding box (with margin for the Orange Mountain ridge to the SE and the second Preakness flow
  ridge to the NW), NAD83 / UTM 18N (EPSG:26918):
  **E 540 500 – 554 500, N 4 494 500 – 4 506 500** (14 km × 12 km). Scene origin = bbox centre
  (547 500, 4 500 500); Godot X = east, Z = south (−north), Y = up, metres.
- Sample-site zones (approximate, from the Figure 2 asterisks only):
  GBR ≈ 74°26.0′ W, 40°39.9′ N (≈ E 547 900, N 4 501 700); SGB ≈ 74°28.4′ W, 40°38.7′ N
  (≈ E 544 600, N 4 499 500). Shown as ~250 m radius zones, never as points.

## 3. Data sources (details, dates and licences in data/SOURCES.md)

| Need | Source | Status |
|---|---|---|
| Elevation | USGS 3DEP 1 m DEM, project NJ_NE6County_B23 (2023 lidar), 4 tiles via The National Map | downloaded |
| Hydrography | USGS NHD Best Resolution, HU4 0203 GeoPackage | downloaded; Green Brook is named, Stirling Brook is an unnamed flowline identified by position |
| Bedrock geology | NJGWS DGS15-1 "Bedrock Geology of NJ 1:24,000" (compiles GMS 04-02 Chatham) | nj.gov blocks scripted HTTP; fetched through the browser if possible, else fallback |
| Bedrock fallback | NJDEP statewide 1:100,000 bedrock (DGS04-6) via ArcGIS REST, plus hand-digitised Jpg / Jps1 / faults from Figure 2 georeferenced to the DEM | downloaded |
| Surficial geology | NJGWS DGS10-2 "Surficial Geology of NJ 1:24,000" (compiles OFM 69 Chatham) | same access issue as bedrock |
| Surficial fallback | NJDEP statewide 1:100,000 surficial (DGS07-2) via ArcGIS REST | downloaded |
| Faults | NJDEP 1:100k faults layer + Figure 2 faults | downloaded |
| Mindat localities | mindat.org public pages (no API key in .env) | read through the browser if reachable; otherwise listed in NEEDED_SOURCES.md |

Fallback rule (integrity rule 7): anything digitised from Figure 2 is tagged lower-confidence in the
app ("Figure-2 digitised") and in ASSUMPTIONS.md.

## 4. Architecture

### Pipeline (`scripts/`, Python 3.12, rasterio / geopandas / shapely / numpy / trimesh)

1. `download_data.py` – fetches DEM tiles, NHD, NJDEP 1:100k layers.
2. `build_terrain.py` – mosaics and clips the DEM to the bbox, resamples to 4 m (3500 × 3000 cells),
   writes `data/processed/terrain/heightmap_16bit.png` + `heightmap.json` (origin, cell size, z range).
3. `build_geology.py` – clips bedrock/surficial/fault/stream vectors to the bbox, reprojects to
   EPSG:26918, translates to scene-local metres, writes GeoJSON to `data/processed/vectors/`.
   Rasterises the bedrock unit map to a unit-ID texture so the terrain surface can be coloured by unit.
4. `build_volumes.py` – builds the subsurface. Dip 9.5° from the GMS 04-02 cross-section
   (`measure_gms_section.py`); dip direction fitted to the Jp/Jps trace; reference plane = top of the
   first flow. Each stratigraphic layer is a grid slab between two bedding-parallel surfaces (the gabbroid
   lens tapers from 82 m at GBR to 49 m at SGB), clipped to the bbox and, on the GPU, to the terrain. Two
   copies: tilted and flat. Exported as glTF with a `layers.json` manifest (name, tier, true thickness,
   reference, colour, variable-thickness parameters).
4b. `extract_sources.py`, `extract_ofm69_limits.py` (glacier limits M1/M2 from the OFM 69 inset),
   `build_cover.py` (modelled cover-thickness field from the OFM 69 extents and maxima).
5. `build_charts.py` – redraws Fig. 8a (REE), Fig. 9 (δ18O), Table 4 (temperatures) as PNGs from the
   paper's tables for the evidence panels.
6. `verify_pipeline.py` – checks every output exists, bbox and CRS are right, the structural fit and every layer
   thickness match the paper, and prints a summary.
7. `sync_assets.py` – copies `data/processed/` into `godot/data/`.

### Godot project (`godot/`, Godot 4.7.2-stable, GDScript, Forward+)

- `Main.tscn` – world root, camera rig, UI.
- Terrain: custom heightmap mesh (chunked ArrayMesh from the 16-bit PNG, with a shader that colours
  by bedrock/surficial unit texture and applies the certainty-tier style). Chosen over Terrain3D because
  the app needs to cut the terrain with an arbitrary clipping plane and dip below it, which is simpler
  with our own mesh and shader than with a plugin's internal LOD system; no addons are required.
- Geology volumes: glTF meshes with a shared `GeoLayer` material shader supporting the cross-section
  plane (discard beyond plane), thickness-exaggeration (vertical scale per layer about its base), and
  tier styling (solid / translucent / dashed-ghost).
- Camera: `CameraRig` with Orbit, Fly, Walk modes and a `ZoomPath` tween through the four scales.
- Time: `Timeline` autoload with the chapter list, per-chapter scrubber range/units, and the global
  nonlinear strip; chapters implement `enter()`, `set_t(t)`, `exit()` and declare `tour_beats`.
- Tour: `Tour.gd` applies beats (camera, pulsing highlights, ground ring, caption) as the scrubber crosses
  them and auto-advances chapters; basic mode strips the screen to narration, scrubber, caption and key.
- Explanation: `InfoPanel` (click/hover), `EvidencePanel`, `Glossary` (first-use inline definitions),
  `Legend` (always visible tiers), `About`.
- Capture mode: `--capture` CLI flag steps through each chapter's start view and the zoom scales and
  saves PNGs to `docs/screenshots/`.

## 5. Chapters → claims → evidence

| # | Chapter | Scrubber | Key claims shown | Paper refs |
|---|---|---|---|---|
| 1 | Proterozoic basement and rift fluids (schematic) | 1.3 Ga → 200 Ma | Highlands gneiss and magnetite deposits, Neoproterozoic ironstone W of border fault; meteoric water descends on border fault, heats to 100–280 °C, acidic, Cl/F-bearing, picks up U, Th, Nb, Ta, W, REE, Fe; rises on intrabasinal faults | §5.1, Fig. 1 |
| 2 | Feltville deposition | 0 → 145 m of section | Fluvial red sandstone/siltstone; two 3 m lacustrine black shale + limestone sequences near the base; upper 0.5 m thermally altered | §2 |
| 3 | Preakness eruption ~201 Ma (deep) | eruption → cooling (illustrative duration) | First flow 125–145 m; locally subaqueous: pillows 0.6–0.9 m over 3–10 m, glass ≤2.5 cm; columnar joints ≤0.5 m × 6 m; gabbroid layers ≤80 m (82 m GB, 49 m SB) by fractionation; glass-rich gabbroid 12–36 m below top; vesicle-rich intervals 3 m with ≤19 % vesicles of 2–10 mm; amygdaloidal top 2.5 m | §2, §5.2, Table 1, Fig. 3 |
| 4 | Carnelian precipitation (deep, heart) | fluid mixing → vesicle fill (illustrative duration) | Hot acidic hydrothermal fluid rises into altered upper first flow, mixes with cool alkaline meteoric water; glass devitrifies and releases silica; two candidate precipitation zones; glauberite first, carnelian from vesicular attachment surface, botryoidal tops, glauberite dissolves to molds; T mostly 20–80 °C, pH neutral–slightly alkaline; δ18O +18.3 to +31.2 ‰ from varied mixing ratio; hematite red, goethite yellow; paragenesis basalt → saline minerals → albitization → silica | §4.3, §4.4, §5.1–5.3, Table 4, Fig. 4, Fig. 5 |
| 5 | Flow-top exposure, second flow, burial | exposure → Jps1 → second flow → burial | ~2 m sediment (Jps1, 2–3 m) on vesicular top; second flow ~70 m with pipe vesicles; burial to 90–130 °C (Feltville hydrocarbons) | §2, §4.1, §5.3 |
| 6 | Tilting, uplift and erosion | folding → Miocene → Pleistocene | Flat stack tilts to 9.5° NW (GMS 04-02 section); Feltville valley forms first; carnelian valleys later as headwater tributaries; Miocene river plain ≥ summit level, >50 m above sites, removed in Pliocene–Pleistocene | §4.1, §4.2 |
| 7 | Glaciation and present day (deep) | glacial limits → present → one flood | SGB south of early Pleistocene limit, no erratics; NE Green Brook tributary headwaters inside limit with till, no carnelian; SW tributary (GBR) unglaciated; colluvium/weathered basalt ≤18 m, alluvium ≤3 m; gravel bars of Preakness + gabbroid on gabbroid pavement; pebbles 1.0–5.5 cm subangular–subrounded; at SB also in terrace alluvium and slope wash; scenario toggle (source exhausted vs. flood replenishment, paper favours 2) | §4.1, §4.2, §6, Fig. 3 |

| W | Worm's-eye view (stage; real GBR hillside) | vesicle → burial → tilt → exhumation → colluvium → flood → gravel bar | one nodule's path; sizes, depths, temperatures, dip and order from the paper and maps; the hillside is the lidar valley side from the zone-A outcrop to the brook; durations not given | §4.1–4.3, §5.2–5.3; GMS 04-02; OFM 69; DEM |

Overlay "Ruled-out sources" (§4.2): trade import; sedimentary source; Orange Mountain Basalt; glacial
transport; Miocene river gravel — each with the paper's reason.

## 6. Certainty tiers (integrity rule 1)

- **Observed** – solid: map contacts, DEM, streams, stated thicknesses, sample-site zones, chemistry.
- **Inferred** – translucent: Preakness source, fluid mixing, Proterozoic trace-element source,
  precipitation zone, paragenetic timing.
- **Illustrative** – ghosted/dashed: eroded rock above today's surface, paleo-surfaces, all durations,
  exact precipitation horizon, the vesicle-scale animation geometry, fluid-field shapes.
- **Mindat-reported** – distinct hatched marker; never shown as Observed.

## 7. Order of work

1. Paper read; this plan. 2. ASSUMPTIONS.md started. 3. Pipeline + verify. 4. Foundation (terrain,
volumes, camera, layers, tiers). 5. Time system. 6. Chapters 3, 4, 7, then 1, 2, 5, 6, then overlay.
7. Explanation layer + evidence panels. 8. Capture, verify numbers, REVIEW_GUIDE.md.
9. (Review round 1, 2026-11-05) Read the supplied maps/papers; refit the structure; untilted depositional
stack; cover skin; glacier limits; basic/advanced screens; guided tour; worm's-eye chapter; cheap visual cues
(lava glow, water).
10. (Review round 2, 2026-11-05) Folded reference surface honouring all three mapped contact traces; zone A as
six sheets; tour slowed with reading holds and per-chapter introductions with glowing shells; startup
introduction screen and exe icon; worm's-eye hillside from the lidar; three expressions of the "source used up"
scenario.
11. (Review round 3, 2026-11-05) Introductions dropped; the tour paced by a generated narration (Kokoro, one clip per
beat) with subtitles and pulsed outlines on first mention; hover pop-ups off under the tour, dismissable otherwise;
worm's-eye path along a steepest-descent flow line.
12. (Polish pass, planned 2026-11-05 from the user's answers) Priorities 1-2 first: (1) water and lava looks:
brook water as a flow-mapped, foamy, refracting surface with a wetted edge; lava with an incandescent interior,
a darkening crust and heat shimmer while a layer is molten; (2) label and text clutter: distance-banded 3D labels
(landscape / outcrop / close), no overlaps, a lighter basic-mode key. Then (3) outline and highlight style: one
colour family per entity type, thinner frames, a traced line instead of the chapter-6 dot band, softer pulse;
(4) brook and bar geometry: a channel cut into the real surface, a sloping bar, water following the thalweg.
Register: "as realistic as cheap tricks allow" (textured rock, foliage-toned terrain, haze, directional light),
with a fallback to a clean diagram if tier styling or labels suffer; the tier legend and certainty cues must
stay legible at every step. Ambient sound, subtle and ducked under the voice: brook in chapters 7 and W, a low
rumble while lava is molten, one more switch beside Narration. No hydrodynamics, no new geology. Delivered 2026-11-05 as round 5 (version 0.5.0): all six items plus the rough translucent carnelian pieces (A-G19 to A-G21).
13. (Review round 5 feedback, 2026-11-05) Fixes: the chapter-2 interference band (z-fighting at slab contact planes;
slabs had no normals), chapter-7 brook beats aimed at the zone centre instead of the stream (and the cue shells on the
pavement and water), chapter W flood camera under the water; the chapter-6 load (per-frame uniform storms, frames
rebuilt every frame). Then the requested optimisation pass: shared noise texture, stack and twin culling, targeted
setters, label and frame throttles; measured with the new --perf sweep (A-G22). Delivered as version 0.6.0.
14. (Review round 6 feedback, 2026-11-06) Camera as storyteller: a move for every tour beat and every chapter W
stage, distance-scaled flights, user takeover; synthesised sound cues for the camera and for chapter W's events
(plus the chapter-6 tilt and the chapter-7 flood); the piece's release slowed; colours more vivid (A-G23). Delivered as
version 0.7.0.
15. (Review round 7 feedback, 2026-11-06) Sound: drips, frost cracks and gravel cut from chapter W; seismic
grinding and a thud for the chapter-1 rifting; pressure and shimmer for the chapter-4 formation. No scale bar in the
microscope view. Carnelian en masse sparkles (chapters 6 and 7). Mindat API (user's key): records, mineral cards and
the New Jersey carnelian locality list fetched by scripts/fetch_mindat.py into static data (A-G24). Version 0.8.0.
16. (Review round 8 feedback, 2026-11-06) Louder chapter-1 seismic bed; sparkle on every piece; no camera cues in
chapter 1 or on chapter 4's in-vesicle moves; a bubbling-magma bed for the botryoidal growth (chapters 4 and W);
Stop tour silences the sound. Mindat: no further functionality planned; the fetch script and data files stay as the
hook for future builds (A-G25). Version 0.9.0; 0.9.1 softened the close-up sparkle (wider glints, slower flicker and breathing, half strength).
