# Watchung Carnelian — an explorable 3D time-lapse of the Volkert et al. (2023) argument

A Godot 4 desktop app plus a reproducible Python pipeline that turns public GIS data into a 3D scene of the
Green Brook – Stirling Brook valley (Chatham quadrangle, Newark basin, New Jersey), extrudes the Preakness
Basalt and its neighbours into the subsurface from the paper's thicknesses and the Chatham map's cross-section,
and walks the paper's argument in seven chapters plus a "worm's-eye" chapter that follows one nodule from its
vesicle down the real Green Brook hillside to a gravel bar. Each chapter has its own time scrubber and a narrated
guided tour (a computer-generated voice, subtitles, the camera set for you, and a glowing outline on each entity as it
is first named); there is a global timeline strip, a free camera that goes
underground and into a single vesicle, a basic and an advanced screen, and a certainty tier (Observed / Inferred /
Illustrative / Mindat-reported) on every element.

Primary source: Volkert, R.A., Gorring, M.L., Peck, W.H., Stanford, S.D. (2023). Characterization and Origin of
Basalt-Derived Carnelian in the Mesozoic Newark Basin, New Jersey, USA. *Minerals* 13(10), 1249.
https://doi.org/10.3390/min13101249 (CC BY 4.0 as printed in the PDF).

Also read for the model (supplied 2026-11-05): the Chatham bedrock map GMS 04-02 (Monteverde & Volkert 2005),
the Chatham surficial map OFM 69 (Stanford 2007), Puffer & Volkert (2001), Faust (1978), Steckler et al. (1993),
El-Tabakh et al. (1997) and Rddad et al. (2022); `data/SOURCES.md` and the About panel record what each contributed.

Companion documents: `PLAN.md` (chapters, claims, architecture), `ASSUMPTIONS.md` (every assumption with its
tier and source), `data/SOURCES.md` (every dataset: URL, date, licence).

## Quick start (Windows)

The exported build is in `build/windows/`: run `WatchungCarnelian.exe` (with `WatchungCarnelian.pck` beside it). It opens
with an introduction screen (what the app shows and why the carnelian is a puzzle; "Start the guided tour" or
"Explore on my own"; a box to skip the screen at startup, which About > "Show the introduction screen again" or the
**I** key brings back). The app runs in basic mode; press **Guided tour** (or G) to let it drive, **N** to skip
a beat of the tour, **M** for the advanced screen. Narration, subtitles and hover pop-ups have switches above the
scrubber (remembered between runs).
To see the log, run it from a terminal with `--verbose`, or run `WatchungCarnelian.exe --headless -- --smoke` for the
self-test. It needs a Vulkan-capable GPU (Forward+ renderer). It was built and tested on Windows 10, RTX 4070.

## Web version

The same app runs in a desktop browser (Chrome, Edge or Firefox; Safari best-effort; mouse and keyboard, no phones or
tablets): https://lbillings-pixel.github.io/watchung-carnelian/ . The first visit downloads about 45 MB (the engine and
the data), which the browser then caches. Sound starts with your first click (browsers require one); the intro
screen's buttons provide it. Settings are kept in the browser's storage.

How it differs from the Windows build, all by design and all in `godot/scripts/Platform.gd`:
- **Renderer:** WebGL 2 through Godot's Compatibility renderer instead of Forward+ (Vulkan). The look is close to the
  desktop build, not identical: the sun casts no shadows on the web (with them that renderer washes the scene out
  white), and the lava, grass and sky shade a little differently.
- **Graphics quality:** advanced screen > Display > "Graphics quality". Low (the web default) draws the terrain on a
  16 m grid instead of 8 m (the sample sites keep their 1 m detail), a smaller shadow map, no anti-aliasing, and
  the 3D view at most 1080 pixels tall. High is the Windows default. The choice is remembered.
- **Full screen:** a "Full screen" button in the top bar, or **F** (Esc leaves).
- **Page flags:** `?smoke` runs the self-test in the page (results in the browser's developer console, 135 checks);
  `?fps` shows a frame counter with the quality and 3D resolution. The capture and movie modes are desktop-only.

Publishing: `.github/workflows/web.yml` builds the web version on every push and pull request with the official
Godot 4.7.2 release (downloads checked against pinned SHA-512 sums), runs the smoke test headless, and on `main`
deploys `build/web/` to GitHub Pages. To build it locally:

```
tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path godot --export-release "Web" ../build/web/index.html
.venv/Scripts/python.exe -m http.server 8060 --bind 127.0.0.1 --directory build/web    # then open http://127.0.0.1:8060/
```

The single-threaded web template is used, so no cross-origin-isolation headers are needed and any static host works.
To preview the web renderer without a browser, run the desktop app with
`--rendering-method gl_compatibility` (all the `--` flags work, e.g. `-- --capture <dir> --quick` for eight tour
beats to compare with a Forward+ capture).

## Two screens

- **Basic** (default for the tour): chapter bar, Guided tour button, scrubber with a caption line that says what to
  look at, a short narration ("More detail" expands it), the key (what every colour on screen is right now), a
  one-line certainty legend, orientation aids. Press **M** or "Switch to advanced" for the rest.
- **Advanced**: adds the full narration with inline glossary, the display panel (vertical exaggeration, thickening,
  tier styling, cover skin, surface colour), the cross-section plane, every layer toggle, the ruled-out overlay,
  camera modes and the zoom-path buttons.

**Guided tour** (button or **G**): plays every chapter in order with a spoken narration (round 4). Each chapter is a
sequence of "beats"; for every beat the camera flies to the right place, the narration clip for that beat plays, the
sentence being spoken appears as a subtitle, and the scrubber advances from that beat's position to the next over
exactly the clip's length, so the pacing is the narration's. When the narration first names an entity (a layer, the
fluid, the gravel bar, the glacier limit...) it pulses with a bright outline for five seconds: a frame on the cut face
for a subsurface layer, a rim shell for a scene object, a ground ring for a place. Chapters advance after 2.5 s; the
whole tour is about 11 minutes of narration. **N** (or "Next >") skips the rest of a beat; dragging the scrubber jumps
to the beat that owns the new position; you can orbit at any time (the next beat re-frames the view). While the tour
runs, the chapter text at the left is folded to its title ("Chapter text" unfolds it) and hover pop-ups are off; stop
with the same button. The narration text is in `docs/NARRATION_SCRIPT.md`.

## Controls

| Action | Input |
|---|---|
| Chapters | buttons 1–7 and W (worm's eye) in the top bar, or keys 1–8 |
| Guided tour on/off | "Guided tour" button or G |
| Skip the rest of a beat (tour) | "Next >" button or N |
| Narration voice / subtitles / hover pop-ups / ambient sound | switches above the scrubber (persisted) |
| Introduction screen | I, or About > "Show the introduction screen again" |
| Basic / advanced screen | "Switch to ..." button or M |
| Chapter scrubber | bottom slider; Play/Pause button or Space |
| Orbit camera (default) | left-drag rotate, right/middle-drag pan, wheel zoom |
| Free fly | choose "Free fly" in the top bar: W A S D move, Q/E down/up, hold right mouse to look, Shift fast, wheel changes speed |
| Walk the brook | choose "Walk": W A S D along the ground at eye height, hold right mouse to look |
| Return to the chapter's curated view | "Chapter view" button or R |
| Zoom path (landscape → outcrop → vesicle → microstructure) | buttons in the top bar (vesicle and microstructure live in chapter 4) |
| Cross-section plane | right panel: enable (or C), azimuth, dip, offset, flip side; the camera may go through the cut |
| Vertical exaggeration | right panel slider (1–5×); the value is shown top-right whenever it is not 1× |
| Cover skin | right panel toggle: draws the modelled bedrock top under colluvium / alluvium / till (chapter 7 turns it on); see it in cross-section |
| Candidate precipitation zone | chapter 4 control under the narration: both / A only (six vesicle-rich sheets) / B only (flow top) |
| Flood scenario | chapter 7 control under the narration: source used up vs. replenished (paper's preference); for "used up", how it is expressed (colluvium thins and bar not replenished / colluvium only / bar only) |
| Thin-layer thickening | right panel toggle (or T); default on, ×20, always announced in the legend |
| Certainty-tier styling | right panel toggle (or V) |
| Surface colour | natural (textured; default) / bedrock units / surficial deposits / hillshade |
| Layers | right panel check boxes: streams, contacts, faults, glacial deposit outlines, glacier limits M1/M2, sample-site zones, Mindat localities, every subsurface layer |
| Ruled-out sources overlay | right panel toggle (3D labels + text panel, paper §4.2) |
| Feature info | hover any feature for a panel (switch "Hover info" above the scrubber; never during the tour); click to pin it; click elsewhere or Esc to release; the panel also closes when the mouse leaves the window |
| Evidence panel | button under the narration: the observations and redrawn charts behind the chapter |
| Hide/show panels | H |
| About / attribution | top bar |

Orientation aids (always on): north arrow, scale bar at the ground under the screen centre, camera elevation
and depth below ground, the tier of the selected object, the exaggeration value when it is not 1×, and a notice
when the beds are shown untilted (chapters 2–5 show the stack flat, as deposited; chapter 6 tilts it).

## Study area

- Bounding box, NAD83 / UTM zone 18N (EPSG:26918): **E 540 500 – 554 500, N 4 494 500 – 4 506 500**
  (14 km × 12 km), covering the paper's Figure 2 (≈ 74°30′–74°23.6′ W, 40°37.5′–40°40.5′ N) plus the Orange
  Mountain ridge to the SE and the second Preakness flow ridge to the NW.
- Scene origin = bbox centre, UTM (547 500, 4 500 500). Godot units are metres: x = east, y = elevation
  (NAVD88), z = south.
- Sample-site zones (approximate, from the Fig. 2 asterisks only): GBR ≈ 74°26.0′ W, 40°39.9′ N;
  SGB ≈ 74°28.4′ W, 40°38.7′ N.
- Structure: dip 9.5° toward 323.5° (NW) at both sample reaches, read from the Chatham map's cross-section A-A'
  (`scripts/measure_gms_section.py`), on a gently folded reference surface (a strike-parallel flexure fitted to the
  three mapped contact traces: 3.5° in a trough between the reaches and the Feltville valley, 13.8° beyond it, as the
  section draws toward First Watchung; `ASSUMPTIONS.md` A-G4). The gabbroid lens is 82 m thick at Green Brook and 49 m
  at Stirling Brook with a sharp top 140 m above the flow base; candidate zone A is six vesicle-rich sheets 5–39 m
  below the flow top.

## The tour as a video

`.venv/Scripts/python.exe scripts/render_tour.py [out.mp4]` renders the guided tour to an MP4 (default
`build/tour.mp4`): it runs the app under Godot's movie-writer mode (`--write-movie`, fixed 30 fps, narration and
ambience mixed in, independent of real time) with the app's `--movie` entry point, which starts the tour at
chapter 1 in basic mode and quits at its end, then encodes with the ffmpeg bundled in imageio-ffmpeg.

## Repository notes (GitHub)

The repository keeps the code, the processed data the app runs on, the narration and sound assets, the paper
(CC BY 4.0), the USGS and NJGWS source documents and the Mindat records. It leaves out: the lidar and NHD downloads
(`scripts/download_data.py` refetches them), the two NJGWS quadrangle zips' extracted folders (unzip them in place
after cloning), four publisher-copyrighted journal PDFs with their text extracts (Steckler et al. 1993, El-Tabakh et al. 1997, Puffer & Volkert 2001, Rddad et al. 2022),
the Kokoro TTS model (`tools/kokoro/`), the Godot binaries, the exported build, the screenshots (regenerated by
`--capture`) and the Mindat API key (`tools/mindat_key.txt`).

## Licence

The code, scripts, shaders, narration script and documentation in this repository are released under the MIT
License (see `LICENSE`). The third-party material keeps its own terms, all of which are recorded in
`data/SOURCES.md`: the paper and the text adapted from it (CC BY 4.0, Volkert et al. 2023), the USGS and NJGWS
documents and data (public domain / state publications), the USGS lidar and hydrography (public domain), the NJDEP
map services (credit NJDEP), and the Mindat records (CC BY-NC-SA 4.0, user-contributed; non-commercial).

## Reproducing the build

### 1. Tools

- **Godot 4.7.2-stable** (official standard, non-.NET build), downloaded from the godotengine GitHub releases
  into `tools/godot/`: `Godot_v4.7.2-stable_win64.exe` (editor) and `Godot_v4.7.2-stable_win64_console.exe`
  (same, with a console). Export templates: `tools/godot/Godot_v4.7.2-stable_export_templates.tpz`, unpacked to
  `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
- **Python 3.12** via `uv` (`uv venv --python 3.12 .venv`, then
  `uv pip install --python .venv/Scripts/python.exe -r requirements.txt`). Packages: rasterio, geopandas,
  shapely, pyproj, numpy, scipy, trimesh, PyMuPDF, Pillow, matplotlib, requests, pyogrio, kokoro-onnx, soundfile.
- **Kokoro speech model** (Kokoro-82M v1.0, Apache-2.0; ~350 MB, not committed): `kokoro-v1.0.onnx` and
  `voices-v1.0.bin` from https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.0 into
  `tools/kokoro/`. Only needed to regenerate the narration; the generated clips are committed under
  `godot/assets/narration/`.

### 2. Data pipeline (`scripts/`)

```
.venv/Scripts/python.exe scripts/download_data.py      # DEM tiles, NHD, NJDEP 1:100k layers (1.5 GB)
#   NJGWS 1:24k zips (dgs15-1.zip, dgs10-2.zip) must be fetched in a browser: see data/SOURCES.md
.venv/Scripts/python.exe scripts/build_terrain.py      # mosaic + clip + 4 m resample -> 16-bit heightmaps, hillshade
.venv/Scripts/python.exe scripts/build_geology.py      # clip/reproject vectors -> GeoJSON; unit-ID rasters
.venv/Scripts/python.exe scripts/extract_sources.py    # text from the PDFs in data/raw/sources/<name>/
.venv/Scripts/python.exe scripts/measure_gms_section.py  # dip along the GMS 04-02 cross-section (reported, used in build_volumes)
.venv/Scripts/python.exe scripts/extract_ofm69_limits.py # glacier limits M1/M2 from OFM 69 Figure 1 -> glacial_limits.geojson
.venv/Scripts/python.exe scripts/build_volumes.py      # structural fit (folded surface) + 24 slabs, tilted / pre-thickened / flat -> glTF + layers.json
.venv/Scripts/python.exe scripts/build_cover.py        # modelled cover-thickness field -> cover_thickness_4m.png + cover.json
.venv/Scripts/python.exe scripts/build_charts.py       # evidence charts from the paper's tables
.venv/Scripts/python.exe scripts/build_icon.py         # stylised carnelian artwork -> assets/, godot/assets/ (intro screen, window and exe icon)
.venv/Scripts/python.exe scripts/build_narration.py    # narration script -> godot/assets/narration/*.ogg + godot/data/narration/narration.json + docs/NARRATION_SCRIPT.md
.venv/Scripts/python.exe scripts/build_ambience.py     # synthesised brook and lava-rumble loops -> godot/assets/ambience/
.venv/Scripts/python.exe scripts/verify_pipeline.py    # checks every output
.venv/Scripts/python.exe scripts/fetch_mindat.py       # optional: Mindat API records (needs a key, see below)
.venv/Scripts/python.exe scripts/sync_assets.py        # copies data/processed -> godot/data
```

Raw data lives in `data/raw/` (large DEM tiles are downloaded by the script, not committed); processed assets
in `data/processed/`; the narration clips and timings go straight into `godot/assets/narration/` and
`godot/data/narration/`.

### 3. Godot

```
tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path godot --import            # import assets
tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path godot -- --smoke          # scripted test
tools/godot/Godot_v4.7.2-stable_win64_console.exe --path godot -- --capture                   # screenshots (needs a window)
tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path godot --export-release "Windows Desktop" ../build/windows/WatchungCarnelian.exe
tools/godot/Godot_v4.7.2-stable_win64.exe --path godot --editor                               # open in the editor
tools/godot/Godot_v4.7.2-stable_win64.exe --path godot                                        # run from source
```

`--capture [dir]` shoots the introduction screen, then every chapter's start view, the 50 % and 100 % scrubber
states, each chapter's zoom-path stops, then every guided-tour beat in basic mode (each staged at its first narration
cue, outline on, subtitle shown), then
the cover-skin section, the three scenario-1 expressions, cross-section, true-thickness, ruled-out overlay and 3×
exaggeration views; saves PNGs to `docs/screenshots/` (default) with an `index.txt` that also records the frame rate,
then quits. `--capture <dir> --debug` shoots the round-6 diagnostics (the chapter-2 contact band with one thing
switched off per shot, the chapter-7 brook beats, the chapter W flood); `--capture <dir> --perf` writes `perf.txt`
with a measured frame rate (frames counted over one second, vsync off) for every chapter's start view, every tour
beat, and each chapter playing; add `--probe` for the switch-one-thing-off breakdown of the slowest states.

## Camera and sound under the tour (round 7)

Every tour beat's view is the start of a camera move that runs for the beat's length: a slow orbit and push-in by
default, with authored orbits, dollies, rises and pull-back reveals on most beats (`"move"` in a beat's extras,
read by `Tour.beat_pose`). Flights between beats last 1.6-4.2 s depending on how far they go. Chapter W drives its
own camera with a move per stage, blended at stage changes. Dragging, panning, zooming or steering hands the camera
to you until the next beat. Sound cues are synthesised by `scripts/build_ambience.py` (loops and one-shots in
`godot/assets/ambience`, played by `Ambience.gd`): swoops on flights, a swell when the scale jumps out, a dive when
it jumps in, and beds for chapter W's stages; the **Ambience** switch silences all of it.

## Mindat API (optional)

With a Mindat API key in `tools/mindat_key.txt` (git-ignored) or `MINDAT_API_KEY`, `scripts/fetch_mindat.py` refreshes
the five marker records, the mineral property cards and the list of every New Jersey locality reporting carnelian into
`data/processed/vectors/mindat_*.json` (then `sync_assets.py`). The app reads only those files and never calls the
API; marker positions and their stated precision come from the pages read on 2026-11-04 and are not changed.

## Library and design choices

- **Renderer:** Forward+ (Vulkan) for Windows; the web build uses the Compatibility renderer (see "Web version"). Measured frame rate on the test machine (RTX 4070, 1600×900, vsync off, round 6
  sweep): 289 fps in the chapter-7 landscape with the cover skin on (92 before round 6), 221 fps at the slowest tour
  beat (chapter 3 beat 5; 29 before), nothing under 150 fps; see `docs/perf.txt`. Round 6 replaced per-fragment hash
  noise with one shared mipmapped noise texture, stopped drawing the layer stack where an opaque uncut terrain hides
  it and the bedrock-top twin outside cuts, and made the per-frame growth/glow/erosion setters touch one layer. The scene is ~5.5 M terrain
  triangles plus 24 slabs; the terrain vertex stride (`Terrain.gd: stride`, default 2 = 8 m vertices on a 4 m
  heightmap) is the main knob for slower GPUs.
- **Terrain:** a custom heightmap mesh, not Terrain3D. Flat `PlaneMesh` chunks (42 × 250×250 segments) are
  displaced on the GPU from the 16-bit height packed into the R and G channels of a lossless PNG (Godot's PNG
  importer strips 16-bit greyscale to 8 bits, hence the packing). Reasons: the terrain must be cut by an
  arbitrary cross-section plane, rendered from below ground, drawn as a ghost in pre-modern chapters, and
  partially hidden by an erosion level in chapter 6, all of which are a few lines in our own shader and awkward
  through a plugin's LOD system; and the whole app then has **no third-party addons** to pin.
- **Subsurface:** each stratigraphic layer is a grid slab between two bedding-parallel surfaces (glTF from
  trimesh; the gabbroid lens and the colonnade under it have a variable boundary), cut by today's terrain, the
  cross-section plane, an optional box and the erosion level in the fragment shader. Every layer exists as a
  tilted copy (today's attitude on the folded reference surface, `ASSUMPTIONS.md` A-G4) and a flat copy (levelled
  on the first-flow base at GBR) for the depositional chapters; chapter 6 rotates the flat set rigidly about the
  strike line through GBR before swapping to the tilted set. Thin layers are thickened for display: on the flat
  stack by an affine scale about the base plane (exact there); on the folded stack by swapping in a pre-thickened
  mesh written by the pipeline (`*_thick.glb`), because an affine scale about a plane would displace a thin layer
  by (factor − 1) × the fold's deviation. True geometry is never edited. A `glow` uniform tints layers that are
  still molten in chapters 3 and 5 (cosmetic).
- **Narration:** `scripts/build_narration.py` synthesises `scripts/narration_script.py` with Kokoro (local
  text-to-speech, one clip per beat, sentence by sentence so sentence and cue times are exact) into Ogg Vorbis clips
  and `narration.json`; a cue is a phrase in the text mapped to layer keys, scene node names or a ground ring. Seven
  geological terms carry explicit IPA because the phonemiser stresses them wrongly. The build writes the Ogg files
  in 8192-sample blocks: libsndfile's Vorbis encoder overflows the stack when given a 20 s clip in one call.
- **Outline cues:** `outline.gdshader` redraws a scene object's mesh pushed outward along its normals in world
  space, unlit, additive, pulsing, brightest edge-on (`Main.outline_nodes`); a subsurface layer gets a frame along
  its top and base on the cut face (`Volumes.set_outline`, rebuilt each frame while the cue lasts so it follows a
  growing layer) or the highlight tint when there is no cut.
- **Cover skin:** a second copy of the terrain grid is displaced downward by the modelled cover-thickness field
  (`cover_thickness_4m.png`, A-G8) and drawn hatched in bedrock colours; with the cross-section plane on, the gap
  between it and the land surface is the colluvium / alluvium / till.
- **Tour:** `Tour.gd` steps through each chapter's `tour_beats`; for beat *i* it sets the scrubber to the beat's
  `t`, flies the camera, plays the clip and sets `Timeline.play_speed` so the scrubber reaches beat *i+1*'s `t`
  exactly when the clip (plus 0.4 s) ends; cues fire from the clip clock, subtitles follow the sentence table, and a
  beat without a clip falls back to a reading time from its caption. Manual scrubbing during the tour restarts the
  beat that owns the new position. The worm's-eye chapter keeps the orbit target on the nodule (no beat camera).
- **Worm's-eye hillside:** built at chapter entry from the DEM: a 1:1 swath along a steepest-descent flow line
  (2 m steps, 16 directions) from the highest zone-A outcrop point within 500 m of the GBR zone centre down to the
  first mapped NHD stream line it meets (straightened on the stage; the straight line is the fallback), vertex-coloured
  by the modelled cover field, plus a cut wall coloured by `Volumes.layer_at_elevation` at 0.25 m steps.
- **Preferences:** `user://prefs.cfg` (ConfigFile) holds the intro-screen choice and the narration / subtitles /
  hover-info switches.
- **Water (polish pass):** `water.gdshader` refracts the scene behind it through the screen texture, tints by the
  water depth read from the depth texture, mixes in the sky by fresnel and whitens the shallow edge into foam; two
  scrolling noise layers perturb the normal; turbidity drives the flood look. No hydraulics. The water is a ribbon
  along the mapped flowline at the carved channel's level, so the flood spreads over the low banks by the depth
  test alone.
- **Brook channel and detail patches (polish pass):** around each site the 8 m terrain grid yields (fragment discard
  inside the patch box) to a 1 m `PlaneMesh` patch drawn with the same shader, and a 1 m deep, 7 m wide parabolic
  channel is carved along the NHD flowline (up to 64 segments as shader uniforms; `Terrain.height_at` applies the
  same carve on the CPU so the hillside swath, pebbles and camera agree). The gravel bar is a sloping lens with
  rough grey cobbles and the carnelian pebbles seated on its surface.
- **Carnelian (polish pass):** `Carnelian.gd` builds a rough piece from a noise-displaced, plane-chipped sphere;
  `carnelian.gdshader` gives it banding, a fresnel rim, a wrapped-diffuse and back-light term (cheap translucency)
  and a noisy normal for the rough surface. Used for the chapter-6 pieces, the bar pebbles (as one multimesh) and
  the free nodule in chapter W.
- **Lava (polish pass):** the layer shader draws a darkening noise crust over incandescent cracks that narrow as the
  layer cools; `shimmer.gdshader` refracts the screen above the hottest growing layer for heat haze.
- **Natural terrain (polish pass):** colour mode 3 shades the surficial classes as woods, floodplain, soil and bare
  rock on steep ground, with noise texture and a 14 % tint of the bedrock unit; the fog gives aerial perspective.
- **Labels (polish pass):** each 3D label has a distance band from its natural scale and overlapping labels yield to
  the nearer one, fading in and out (`Main._update_labels`); the basic-mode key groups slabs into formations.
- **Ambience (polish pass):** `Ambience.gd` loops two synthesised beds (`scripts/build_ambience.py`) at levels the
  chapters set each frame, ducked under the narration.
- **Vectors:** NHD streams, map contacts, faults, glacial deposit outlines are draped line meshes
  (`ImmediateMesh`) resampled at 10 m over the heightmap.
- **Pipeline:** rasterio (DEM merge/resample), geopandas/shapely/pyogrio (gdb and GeoPackage reading, clipping,
  rasterising unit IDs), numpy (plane fit), trimesh (glTF), matplotlib (charts), PyMuPDF (paper text/figures).

## Layout

```
PLAN.md ASSUMPTIONS.md README.md
data/raw/        paper PDF + text, DEM tiles, NHD, NJGWS 1:24k gdb zips, NJDEP 1:100k GeoJSON
data/processed/  terrain/ (heightmaps, unit rasters, terrain.json), vectors/ (GeoJSON), volumes/ (glTF + layers.json), charts/
data/SOURCES.md
scripts/         download_data.py build_terrain.py build_geology.py build_volumes.py build_cover.py build_charts.py build_icon.py verify_pipeline.py sync_assets.py
assets/          carnelian.png (stylised artwork); godot/assets/ holds the copies the app and the exe icon use
godot/           project.godot, export_presets.cfg (Windows Desktop, Web), scenes/Main.tscn, scripts/ (Terrain, Volumes, Features, CameraRig, Timeline, Tour, UI, Platform, ...), chapters/Ch1..Ch8, shaders/, data/ (synced assets), tests/smoke.gd
data/raw/sources/ the seven maps/papers supplied for the review (PDF + extracted text each)
build/windows/   exported desktop build
build/web/       exported web build (published by .github/workflows/web.yml)
.github/workflows/web.yml  CI: web export, smoke test, GitHub Pages deploy
docs/screenshots/ capture output
tools/godot/     Godot 4.7.2 editor + export templates
```
