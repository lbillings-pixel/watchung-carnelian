"""Build the subsurface as bedding-parallel slabs on a gently folded structural surface and export them as glTF
+ a manifest.

Method (ASSUMPTIONS.md A-G4..A-G8):
  1. Attitude.  Dip = 9.5 deg, read off cross-section A-A' of GMS 04-02 (Monteverde & Volkert 2005), which is
     printed with no vertical exaggeration and runs NW-SE through the Green Brook reach: the Jf/Jp and Jo contacts
     are drawn at 9.3-9.7 deg between 8 and 12 km from A (GBR projects to 10.6 km), steepening to 13-14 deg
     toward First Watchung Mountain (scripts/measure_gms_section.py).  Dip direction: fitted by minimising the
     misfit of a fixed-dip plane to the DEM elevations along the mapped Jp/Jps trace (top of the first flow),
     which runs beside both sample reaches.  Only the plane's offset is fitted (a free least-squares fit is
     unusable: the traces follow the valley floor).
  2. Fold.  A single plane cannot honour the mapped traces: at 9.5 deg the Jf/Jp (base) and Jp/Jps (top) traces
     are 188 m apart, more than any published first-flow thickness, so the base plane sat 43 m above the Jf/Jp
     trace (round 2), and the Jo/Jf trace (base of the Feltville, 145 m lower) needs the beds to steepen again
     south-east of the Feltville valley, as the GMS section draws them (13-14 deg toward First Watchung).  The
     reference surface is therefore the 9.5 deg plane plus a CYLINDRICAL (strike-parallel) flexure delta(u) in the
     down-dip coordinate u (origin at GBR, positive NW), a piecewise-cosine curve through control points:
         delta = 0                                for u >= U0 (= -150 m: 9.5 deg holds at GBR and NW, SGB at u=+200)
         cosine blend 0 -> -D1                    U0 .. Ua  (Ua = median u of the Jf/Jp trace)
         cosine blend -D1 -> -D2                  Ua .. Ub  (Ub = median u of the Jo/Jf trace)
         delta = -D2                              for u < Ub
     D1 and D2 are fitted so that the median residual of the Jf/Jp and Jo/Jf traces is zero (the Jp/Jps trace is
     the plane's own reference).  The surface honours all three mapped traces with the paper's thicknesses; the
     resulting minimum and maximum local dips are reported and checked (A-G4).  The fold is a consequence of the
     mapped traces, not a measurement from the section.
  3. Every stratigraphic layer is the region between two bedding-parallel surfaces at the paper's thicknesses
     (offset = perpendicular metres from the first-flow base; vertical thickness = offset / cos(local dip)),
     clipped to the bbox walls and the model floor/ceiling.  The gabbroid lens has a variable thickness (82 m at
     Green Brook, 49 m at Stirling Brook, paper section 4.1; interpolated along strike).  Candidate zone A is a
     SET OF SIX vesicle-rich gabbroid sheets through the upper 40 m of the flow (Puffer & Volkert 2001 type 1
     sheets; Table 1 of the paper), not one interval.
  4. Thin layers are built at TRUE thickness.  For the tilted (folded) stack a second, pre-thickened copy of each
     thin layer is written (`_thick.glb`, display thickness = min(20 x true, per-layer cap)) because the app's
     affine thickening is exact only for the untilted stack; the app swaps meshes instead.
  5. A second, UNTILTED copy of every layer (horizontal beds, levelled on the first-flow base at GBR) is written
     for the depositional chapters (2-5): at deposition the beds were flat; the tilt and the flexure belong to
     the later Watchung-syncline folding and are animated at the start of chapter 6.
  6. Output: data/processed/volumes/<layer>.glb, <layer>_thick.glb (thin layers), <layer>_flat.glb, layers.json.

Local coordinates: x east, y north (metres from the scene origin), z elevation.  The glTF is written in
Godot/glTF axes (x east, y up, z south).
"""
import json
import os
import numpy as np
import geopandas as gpd
import trimesh

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VEC = os.path.join(ROOT, "data", "processed", "vectors")
TER = os.path.join(ROOT, "data", "processed", "terrain")
OUT = os.path.join(ROOT, "data", "processed", "volumes")
os.makedirs(OUT, exist_ok=True)

meta = json.load(open(os.path.join(TER, "terrain.json")))
W, H, CELL = meta["width"], meta["height"], meta["cell_size_m"]
ZMIN, ZMAX = meta["z_min_m"], meta["z_max_m"]
OX, OY = meta["scene_origin_utm"]["east"], meta["scene_origin_utm"]["north"]
BB = meta["bbox_utm"]
XW, XE = BB["west"] - OX, BB["east"] - OX
YS, YN = BB["south"] - OY, BB["north"] - OY
Z_BOTTOM = -450.0      # model floor (illustrative)
Z_TOP = 450.0          # model ceiling for eroded (illustrative) rock
Z_TOP_FLAT = 600.0     # ceiling for the untilted stack (Towaco filler)

hm = np.fromfile(os.path.join(TER, "heightmap_4m.r16"), dtype=np.uint16).reshape(H, W).astype(np.float64)
hm = hm / 65535.0 * (ZMAX - ZMIN) + ZMIN


def dem_at(x, y):
    col = np.clip(((x - XW) / CELL).astype(int), 0, W - 1)
    row = np.clip(((YN - y) / CELL).astype(int), 0, H - 1)
    return hm[row, col]


def sample_line(geom, step=10.0):
    pts = []
    for part in (geom.geoms if geom.geom_type == "MultiLineString" else [geom]):
        n = max(2, int(part.length / step))
        for d in np.linspace(0, part.length, n):
            p = part.interpolate(d)
            pts.append((p.x, p.y))
    return np.array(pts)


DIP_DEG = 9.5         # GMS 04-02 section A-A' (see module docstring); Fig. 2 symbols 7-15; GMS text: limbs 6-15
DIPDIR_DEG = 321.0    # fitted below (scan); NW
FOLD_U0 = -150.0      # flexure starts 150 m SE (up-dip) of GBR: 9.5 deg holds at GBR and NW of it (SGB at u=+200)


def fit_plane(pts, dip_deg=DIP_DEG, dipdir_deg=DIPDIR_DEG):
    """Plane z = a x + b y + c with FIXED attitude (dip, dip direction); only the offset c is fitted
    (median of residuals) to the DEM elevations sampled along the contact trace."""
    x, y = pts[:, 0], pts[:, 1]
    z = dem_at(x, y)
    g = np.tan(np.radians(dip_deg))
    az = np.radians(dipdir_deg)
    a = -g * np.sin(az)
    b = -g * np.cos(az)
    c = float(np.median(z - a * x - b * y))
    rms = float(np.sqrt(np.mean((a * x + b * y + c - z) ** 2)))
    return a, b, c, dip_deg, dipdir_deg, rms


def free_fit(pts):
    x, y = pts[:, 0], pts[:, 1]
    z = dem_at(x, y)
    A = np.c_[x, y, np.ones_like(x)]
    (a, b, c), *_ = np.linalg.lstsq(A, z, rcond=None)
    return float(np.degrees(np.arctan(np.hypot(a, b))))


def contact_between(units, ua, ub):
    A = units[units.unit == ua].geometry.union_all()
    B = units[units.unit == ub].geometry.union_all()
    return A.boundary.intersection(B.boundary)


# ---------------------------------------------------------------------------------------------------------
# Layer stack.  Offsets are TRUE metres perpendicular to bedding, measured from the base of the first flow.
# ---------------------------------------------------------------------------------------------------------
F1 = 145.0          # first flow thickness drawn: paper 125-145 m, Puffer & Volkert (2001) 140-180 m; the map
                    # traces at 9.5 deg give ~188 m on a plane (reported below).  145 satisfies both published ranges.
GAB_TOP = 140.0     # top of the gabbroid lens: Table 1 'vesicular gabbroid' sampled 140 m above base; Puffer &
                    # Volkert: the Berkeley Heights lens forms most of the upper half of the flow, under a 3-6 m
                    # vesicular flow-top zone.  Upper contact sharp (GMS 04-02, paper section 2).
GAB_GBR, GAB_SGB = 82.0, 49.0   # paper section 4.1 (calculated thicknesses at the two sites)
AUREOLE = 0.5
JO_THICK = 218.0    # Orange Mountain Basalt about 715 ft (GMS 04-02 unit description)
JT_THICK = 381.0    # Towaco Formation maximum about 1,250 ft (GMS 04-02); filler to the ceiling
THIN_LIMIT = 10.0   # layers thinner than this get a pre-thickened display copy (x20, capped)
THICKEN = 20.0

# Candidate zone A: vesicle-rich gabbroid sheets (Puffer & Volkert 2001 type 1: 1 cm - 3 m, typically 5-15 cm,
# multiple parallel layers below the 3-6 m vesicular flow top, confined to the upper ~40 m; pore space ~19 % in the
# uppermost sheet falling to 2 % at depth; the thickest sheets deepest; in the Totowa core 12 layers between 12 and
# 36 m below the vesicular top; paper Table 1: 'vesicular gabbroid' sampled 140 m above the base = 5 m below the top;
# paper section 5.2: 3 m intervals with 2-10 mm vesicles up to 19 %).  Depths below the flow top (top of sheet),
# true thickness, vesicularity used for the colour.  Positions inside the envelope are Illustrative (A-G6).
SHEETS = [   # (depth below flow top to the sheet TOP, true thickness, vesicle %, note)
    (5.0, 1.0, 15, "Table 1 'vesicular gabbroid' sample height (140 m above the base)"),
    (12.0, 1.0, 19, "Puffer & Volkert: uppermost sheet, highly vesicular black vitreous glass, ~19 % pore space"),
    (17.0, 0.5, 14, "thin sheet (typical 5-15 cm; drawn 0.5 m)"),
    (22.0, 1.0, 10, "mid-envelope sheet"),
    (28.0, 2.0, 5, "thicker, less vesicular with depth"),
    (36.0, 3.0, 2, "Puffer & Volkert: deepest layer at 36 m, only slightly vesicular; the 3 m maximum"),
]
SHEET_DISPLAY_MAX = 3.0   # display cap so the six sheets stay separate when thickened


def main():
    units = gpd.read_file(os.path.join(VEC, "bedrock_units.geojson"))
    sites = gpd.read_file(os.path.join(VEC, "sample_sites.geojson"))
    gbr = sites[sites.code == "GBR"].geometry.iloc[0]
    sgb = sites[sites.code == "SGB"].geometry.iloc[0]
    # ---- 1. base of Preakness: Jf/Jp contact ----
    jfjp = contact_between(units, "Jf", "Jp")
    pts1 = sample_line(jfjp)
    jpjps = contact_between(units, "Jp", "Jps")
    pts2 = sample_line(jpjps)
    jojf = contact_between(units, "Jo", "Jf")
    pts0 = sample_line(jojf) if not jojf.is_empty else np.zeros((0, 2))
    # dip direction: the value (dip fixed at 9.5) that best fits the Jp/Jps trace, which runs beside both sample
    # reaches; the Jf/Jp trace is reported for comparison
    scan = [(fit_plane(pts2, DIP_DEG, dd)[5], dd) for dd in np.arange(290.0, 341.0, 0.5)]
    dipdir = min(scan)[1]
    dipdir_base = min((fit_plane(pts1, DIP_DEG, dd)[5], dd) for dd in np.arange(290.0, 341.0, 0.5))[1]
    cx, cy = pts2.mean(axis=0)

    def separation(d):
        aa, bb, cc, *_ = fit_plane(pts1, d, dipdir)
        aa2, bb2, cc2, *_ = fit_plane(pts2, d, dipdir)
        return (aa2 * cx + bb2 * cy + cc2 - (aa * cx + bb * cy + cc)) * np.cos(np.radians(d))

    dip = DIP_DEG
    a1, b1, c1, dip, dipdir, rms = fit_plane(pts1, dip, dipdir)
    a2, b2, c2, _, _, rms2 = fit_plane(pts2, dip, dipdir)
    n1 = np.array([-a1, -b1, 1.0]); n1 /= np.linalg.norm(n1)
    sep = separation(dip)
    # Structural reference = the Jp/Jps plane (top of the first flow): the Jps strip is mapped along the valley
    # beside both sample reaches, so it constrains the stack where it matters.  The first-flow base is placed
    # F1 below it; the offset of that base from the fitted Jf/Jp trace plane is reported (A-G4).
    k0 = 1.0 / n1[2]
    a, b = a2, b2
    c = c2 - F1 * k0
    base_misfit = (c - c1) * n1[2]
    print(f"Jf/Jp contact: {len(pts1)} samples; Jp/Jps contact: {len(pts2)} samples; Jo/Jf contact: {len(pts0)} samples")
    print(f"Dip direction {dipdir:.1f} (best offset-fit rms along the Jp/Jps trace; the Jf/Jp trace alone prefers {dipdir_base:.1f}); a free least-squares plane would give {free_fit(pts1):.1f} deg (unconstrained, A-G4)")
    print(f"Dip {dip:.1f} deg from the GMS 04-02 section; the mapped Jf/Jp and Jp/Jps traces are then {sep:.0f} m apart "
          f"(paper 125-145 m, Puffer & Volkert 140-180 m; drawn {F1:.0f} m). Offset-fit rms: base {rms:.0f} m, top {rms2:.0f} m")
    print(f"Plane only: the modelled first-flow base would lie {base_misfit:+.0f} m (perpendicular) from the plane fitted to the Jf/Jp trace")
    for d in (7, 8, 9.5, 11, 13):
        print(f"   dip {d:4} deg -> first-flow separation {separation(d):.0f} m")

    # ---- 2. the flexure ----
    az = np.radians(dipdir)
    down = np.array([np.sin(az), np.cos(az)])              # unit vector toward the dip direction (x east, y north)
    strike = np.array([np.cos(az), -np.sin(az)])           # unit vector along strike (NE-ish)
    g0 = np.tan(np.radians(dip))

    def u_of(x, y):
        return (x - gbr.x) * down[0] + (y - gbr.y) * down[1]

    z1 = dem_at(pts1[:, 0], pts1[:, 1]); z2 = dem_at(pts2[:, 0], pts2[:, 1])
    r1 = z1 - (a * pts1[:, 0] + b * pts1[:, 1] + c)
    r2 = z2 - (a * pts2[:, 0] + b * pts2[:, 1] + c + F1 * k0)
    u1, u2 = u_of(pts1[:, 0], pts1[:, 1]), u_of(pts2[:, 0], pts2[:, 1])
    z0 = dem_at(pts0[:, 0], pts0[:, 1]); u0 = u_of(pts0[:, 0], pts0[:, 1])
    r0 = z0 - (a * pts0[:, 0] + b * pts0[:, 1] + c - 145.0 * k0)
    cu = [FOLD_U0, float(np.median(u1)), float(np.median(u0))]      # control u (descending)
    cd = [0.0, 0.0, 0.0]                                             # control delta (fitted below)

    def delta_c(u, cdv):
        u = np.asarray(u, dtype=float)
        out = np.where(u >= cu[0], cdv[0], cdv[-1])
        for i in range(len(cu) - 1):
            seg = (u < cu[i]) & (u >= cu[i + 1])
            sfrac = (cu[i] - u) / (cu[i] - cu[i + 1])
            blend = cdv[i] + (cdv[i + 1] - cdv[i]) * (1.0 - np.cos(np.pi * np.clip(sfrac, 0, 1))) / 2.0
            out = np.where(seg, blend, out)
        return out

    def ddelta_c(u, cdv):   # d delta / d u
        u = np.asarray(u, dtype=float)
        out = np.zeros_like(u)
        for i in range(len(cu) - 1):
            seg = (u < cu[i]) & (u >= cu[i + 1])
            Lseg = cu[i] - cu[i + 1]
            sfrac = (cu[i] - u) / Lseg
            slope = -(cdv[i + 1] - cdv[i]) * np.pi / (2.0 * Lseg) * np.sin(np.pi * np.clip(sfrac, 0, 1))
            out = np.where(seg, slope, out)
        return out

    # fit D1 (Jf/Jp trace median -> 0) and D2 (Jo/Jf trace median -> 0), alternating
    Ds = np.arange(-120.0, 120.0, 0.25)
    for _ in range(4):
        med = [np.median(r1 - delta_c(u1, [0.0, D, cd[2]])) for D in Ds]
        cd[1] = float(Ds[np.argmin(np.abs(med))])
        med = [np.median(r0 - delta_c(u0, [0.0, cd[1], D])) for D in Ds]
        cd[2] = float(Ds[np.argmin(np.abs(med))])

    def delta(u):
        return delta_c(u, cd)

    def ddelta(u):
        return ddelta_c(u, cd)

    d1 = r1 - delta(u1); d2 = r2 - delta(u2); d0 = r0 - delta(u0)
    uu = np.linspace(-7000.0, 7000.0, 1401)
    dips = np.degrees(np.arctan(np.abs(-g0 + ddelta(uu))))
    fold_check = {"control_u_m": cu, "control_delta_m": cd,
                  "base_median_m": float(np.median(d1)), "base_rms_m": float(np.sqrt(np.mean(d1 ** 2))),
                  "top_median_m": float(np.median(d2)), "top_rms_m": float(np.sqrt(np.mean(d2 ** 2))),
                  "jo_jf_median_m": float(np.median(d0)), "jo_jf_rms_m": float(np.sqrt(np.mean(d0 ** 2))),
                  "min_dip_deg": float(dips.min()), "max_dip_deg": float(dips.max()),
                  "u_sgb_m": float(u_of(sgb.x, sgb.y))}
    print(f"Flexure control points (u, delta): {[(round(x), round(y, 1)) for x, y in zip(cu, cd)]}")
    print(f"   residual medians after the fold: Jf/Jp {fold_check['base_median_m']:+.1f} m (rms {fold_check['base_rms_m']:.0f}), "
          f"Jp/Jps {fold_check['top_median_m']:+.1f} m (rms {fold_check['top_rms_m']:.0f}), Jo/Jf {fold_check['jo_jf_median_m']:+.1f} m (rms {fold_check['jo_jf_rms_m']:.0f})")
    print(f"   local dip {fold_check['min_dip_deg']:.1f}-{fold_check['max_dip_deg']:.1f} deg (GMS limbs 6-15; section 9.3-9.7 at the reaches, 13-14 toward First Watchung); SGB at u={fold_check['u_sgb_m']:.0f}")
    M = -cd[1]

    def ref_z(x, y):            # elevation of the first-flow base (folded reference surface)
        return a * x + b * y + c + delta(u_of(x, y))

    def kfac(x, y):             # vertical metres per perpendicular metre: 1/cos(local dip)
        return np.sqrt(1.0 + (-g0 + ddelta(u_of(x, y))) ** 2)

    # along-strike coordinate for the gabbroid lens thickness (82 m at GBR -> 49 m at SGB, clamped beyond)
    s_gbr = strike @ np.array([gbr.x, gbr.y])
    s_sgb = strike @ np.array([sgb.x, sgb.y])

    def gab_thick(x, y):
        s = strike[0] * x + strike[1] * y
        u = (s - s_sgb) / (s_gbr - s_sgb)
        return GAB_SGB + (GAB_GBR - GAB_SGB) * np.clip(u, 0.0, 1.0)

    def gab_base(x, y):
        return GAB_TOP - gab_thick(x, y)

    # Each entry: key, name, base offset (float or fn), thickness or top (float or fn), tier, colour, refs, note[, extra]
    layers = [
        ("passaic", "Passaic Formation (JTrp)", -AUREOLE - 145.0 + AUREOLE - JO_THICK - 900.0, 900.0, "observed",
         "#C9A79B", "paper Fig. 2; GMS 04-02", "Regionally as much as 11,480 ft (GMS 04-02); drawn as a filler to the model floor."),
        ("orange_mountain", "Orange Mountain Basalt (Jo), ~218 m", -145.0 - JO_THICK, JO_THICK, "observed",
         "#9A9A9A", "GMS 04-02 unit description; paper Fig. 2, section 4.2", "Thickness about 715 ft (218 m) from the Chatham map text; three flows, not subdivided here."),
        ("feltville", "Feltville Formation (Jf), 145 m", -145.0, 145.0 - AUREOLE, "observed",
         "#E8B4AC", "paper section 2; GMS 04-02 (450-483 ft)", "Fluvial red sandstone/siltstone; two 3 m lacustrine sequences near the base (shown inside)."),
        ("feltville_lacustrine_1", "Feltville lacustrine sequence 1 (3 m)", -145.0 + 20.0, 3.0, "observed",
         "#4A4A4A", "paper section 2; GMS 04-02 (each as much as 10 ft, Washington Valley Member)", "'Near the base': position inside the formation is illustrative (A-G6)."),
        ("feltville_lacustrine_2", "Feltville lacustrine sequence 2 (3 m)", -145.0 + 35.0, 3.0, "observed",
         "#4A4A4A", "paper section 2; GMS 04-02", "'Near the base': position inside the formation is illustrative (A-G6)."),
        ("feltville_aureole", "Feltville thermally altered top (0.5 m)", -AUREOLE, AUREOLE, "observed",
         "#B65C3C", "paper section 2 (GMS 04-02: 'several inches')", "Uppermost ~0.5 m thermally altered at the Preakness contact."),
        ("glass_rind", "Basaltic glass layer at the flow base (<= 2.5 cm)", 0.0, 0.025, "observed",
         "#1E1E1E", "paper section 2", "Gray/brown basaltic glass in contact with the pillows. Local (subaqueous) base."),
        ("pillow_zone", "Pillowed, vesicular base (3-10 m)", 0.025, 6.5, "observed",
         "#6F7F8A", "paper section 2", "Pillows 0.6-0.9 m; drawn 6.5 m (range 3-10 m). Local to the study area."),
        ("columnar_zone", "Colonnade: slender columnar-jointed basalt", 6.525, gab_base, "observed",
         "#9FA6AA", "paper section 2, 5.2; GMS 04-02 (columns 2-24 in); Faust 1978", "Columns <= 0.5 m wide, 6 m long; sparsely vesicular (< 0.2 vol%). Its top is the gradational base of the gabbroid lens."),
        ("gabbroid", "Gabbroid lens (Jpg): 82 m at Green Brook, 49 m at Stirling Brook", gab_base, GAB_TOP, "observed",
         "#7E7E7E", "paper section 2, 4.1, Table 1; Puffer & Volkert 2001 (type 3 lens, Berkeley Heights)", "Thickness interpolated along strike between the two calculated values (paper section 4.1) and held beyond them; top sharp at 140 m (Table 1 vesicular-gabbroid height), base gradational. Puffer & Volkert: the Berkeley Heights lens makes up most of the upper half of the flow, up to 96 m."),
        ("glass_rich_gabbroid", "Glass-rich gabbroid band (12-36 m below the flow top)", F1 - 36.0, 24.0, "observed",
         "#4B2E2E", "paper section 2, Table 1, 5.1; Puffer & Volkert 2001 (sheets 12-36 m below the vesicular flow top)", "Dark red/black vitreous glass; the paper's favoured silica source. The zone A sheets lie inside and just above it."),
    ]
    for i, (depth, thick, ves, note) in enumerate(SHEETS):
        shade = 0.55 + 0.45 * (ves / 19.0)     # most vesicular = brightest red
        col = "#%02X%02X%02X" % (int(217 * shade), int(83 * shade), int(79 * shade))
        layers.append(("vesicle_sheet_%d" % (i + 1), "Zone A sheet %d: vesicle-rich gabbroid sheet %g m below the flow top (%g m, ~%d %% vesicles)" % (i + 1, depth, thick, ves),
                       F1 - depth - thick, thick, "inferred", col,
                       "paper section 5.2, Table 1 (140 m); Puffer & Volkert 2001 (type 1 sheets: 1 cm-3 m, upper 40 m, 19 % -> 2 % pore space with depth)",
                       "One of six drawn sheets standing for the set of thin vesicular gabbroid sheets in the upper 40 m (the paper's candidate zone A). %s. Sheet positions inside the envelope are Illustrative; the envelope, thickness range and vesicularity trend are Puffer & Volkert's. Drawn thickness capped at 3 m." % note,
                       {"group": "zone_a", "display_max_m": SHEET_DISPLAY_MAX, "vesicle_pct": ves, "depth_below_top_m": depth}))
    layers += [
        ("massive_top", "Blocky, massive basalt below the flow top", GAB_TOP, F1 - 2.5 - GAB_TOP, "observed",
         "#A3A3A3", "paper section 2", "Uppermost part of the first flow above the gabbroid."),
        ("amygdaloidal_top", "Vesicular, amygdaloidal flow top (~2.5 m): candidate zone B", F1 - 2.5, 2.5, "observed",
         "#E07A5F", "paper section 2, Fig. 3c (GMS 04-02: vesiculated zones as much as 8 ft; Puffer & Volkert: 3-6 m)", "Highly vesicular and amygdaloidal."),
        ("jps1", "Jps1 sedimentary interbed (2-3 m)", F1, 2.5, "observed",
         "#E5C7B8", "paper section 2, 4.1, Fig. 3c (GMS 04-02: 6-25 ft; Puffer & Volkert: 2-8 m)", "Thin-bedded reddish-brown fluvial siltstone and shale on the eroded, exposed flow top."),
        ("second_flow_base", "Second flow base: massive basalt with pipe vesicles", F1 + 2.5, 6.0, "observed",
         "#8E9A9F", "paper section 2", "Overlain by widely spaced blocky columnar joints. 6 m drawn (no thickness given)."),
        ("second_flow", "Second flow (~70 m)", F1 + 2.5 + 6.0, 64.0, "observed",
         "#B9B9B9", "paper section 2 (Puffer & Volkert: 80 m)", "Relatively massive basalt with a few very thin gabbroid layers."),
        ("upper_preakness", "Upper Preakness flows (to 315 m total)", F1 + 2.5 + 70.0, 315.0 - (F1 + 2.5 + 70.0), "illustrative",
         "#C9C9C9", "paper section 2 (GMS 04-02: about 1,040 ft total)", "The paper gives 315 m total and 'at least three flows' but does not describe the third; filler to the total."),
        ("towaco", "Towaco Formation (Jt), ~380 m", 315.0, JT_THICK, "observed",
         "#D8A8A0", "GMS 04-02 (maximum about 1,250 ft); paper Fig. 1-2", "Regional maximum thickness from the Chatham map text; drawn to the model ceiling."),
    ]

    gbr_base_z = float(ref_z(np.array([gbr.x]), np.array([gbr.y]))[0])
    manifest = {"plane": {"a": a, "b": b, "c": c, "dip_deg": dip, "dipdir_deg": dipdir, "rms_m": rms,
                          "check_top_plane": {"rms_m": rms2, "separation_m": sep, "base_misfit_plane_only_m": base_misfit, "reference": "Jp/Jps plane (top of first flow)"},
                          "attitude_source": "dip 9.5 deg measured on GMS 04-02 cross-section A-A' (scripts/measure_gms_section.py); dip direction fitted to the Jp/Jps (first-flow top) trace, which runs beside both sample reaches (A-G4)"},
                "fold": {"type": "piecewise_cosine", "control_u_m": cu, "control_delta_m": cd,
                         "origin_xy": [float(gbr.x), float(gbr.y)], "down_dip_unit_xy": [float(down[0]), float(down[1])],
                         "formula": "S(x,y) = a x + b y + c + delta(u); u = (p - origin) . down_dip; delta = control_delta[0] for u >= control_u[0]; cosine blend between successive control points; control_delta[-1] below the last. Offset surfaces: S + off / cos(local dip).",
                         "check": fold_check,
                         "note": "Cylindrical (strike-parallel) flexure fitted so the modelled first-flow base honours the mapped Jf/Jp and Jo/Jf traces as well as the Jp/Jps trace, with the paper's thicknesses; dip 9.5 deg at and NW of GBR (both sample reaches), flattening between the reaches and the Feltville valley, then steepening toward First Watchung as the GMS section draws (A-G4)."},
                "flat_plane": {"a": 0.0, "b": 0.0, "c": gbr_base_z, "dip_deg": 0.0, "dipdir_deg": dipdir,
                               "note": "untilted stack for the depositional chapters, levelled on the first-flow base at GBR"},
                "first_flow_thickness_drawn_m": F1, "first_flow_thickness_range_m": [125, 145], "first_flow_thickness_puffer_m": [140, 180],
                "gabbroid_lens": {"top_offset_m": GAB_TOP, "thick_gbr_m": GAB_GBR, "thick_sgb_m": GAB_SGB,
                                  "strike_unit_xy": [float(strike[0]), float(strike[1])], "s_gbr": float(s_gbr), "s_sgb": float(s_sgb)},
                "zone_a": {"keys": ["vesicle_sheet_%d" % (i + 1) for i in range(len(SHEETS))],
                           "top_offset_m": F1 - SHEETS[0][0], "base_offset_m": F1 - SHEETS[-1][0] - SHEETS[-1][1],
                           "sheets": [{"key": "vesicle_sheet_%d" % (i + 1), "depth_below_top_m": d, "thickness_m": t, "vesicle_pct": v, "note": n} for i, (d, t, v, n) in enumerate(SHEETS)],
                           "source": "Puffer & Volkert 2001 type 1 sheets (1 cm-3 m, upper 40 m, 19 -> 2 % pore space); paper Table 1 (140 m), section 5.2"},
                "tilt_axis": {"point_xyz_local": [float(gbr.x), float(gbr.y), float(gbr_base_z)], "strike_unit_xy": [float(strike[0]), float(strike[1])]},
                "thicken": {"factor": THICKEN, "thin_limit_m": THIN_LIMIT, "note": "thin layers have a pre-thickened tilted copy (file_thick) at display_thickness_m; the flat stack is thickened by an affine transform in the app"},
                "z_floor": Z_BOTTOM, "z_ceiling": Z_TOP, "z_ceiling_flat": Z_TOP_FLAT, "layers": []}

    NX, NY = 56, 48
    xs = np.linspace(XW, XE, NX + 1)
    ys = np.linspace(YS, YN, NY + 1)
    gx, gy = np.meshgrid(xs, ys)

    def build(key, base, top, refz, kk, zlo, zhi, suffix=""):
        bz = base(gx, gy) if callable(base) else np.full(gx.shape, float(base))
        tz = top(gx, gy) if callable(top) else np.full(gx.shape, float(top))
        rz = refz(gx, gy) if callable(refz) else np.full(gx.shape, float(refz))
        kz = kk(gx, gy) if callable(kk) else np.full(gx.shape, float(kk))
        zb = np.clip(rz + bz * kz, zlo, zhi)
        zt = np.clip(rz + tz * kz, zlo, zhi)
        vb = np.c_[gx.ravel(), gy.ravel(), zb.ravel()]
        vt = np.c_[gx.ravel(), gy.ravel(), zt.ravel()]
        v = np.vstack([vb, vt])
        n = vb.shape[0]
        faces = []

        def idx(i, j, topside):
            return (n if topside else 0) + j * (NX + 1) + i

        for j in range(NY):
            for i in range(NX):
                p00, p10, p01, p11 = idx(i, j, False), idx(i + 1, j, False), idx(i, j + 1, False), idx(i + 1, j + 1, False)
                faces += [[p00, p01, p10], [p10, p01, p11]]                       # bottom (facing down)
                q00, q10, q01, q11 = idx(i, j, True), idx(i + 1, j, True), idx(i, j + 1, True), idx(i + 1, j + 1, True)
                faces += [[q00, q10, q01], [q10, q11, q01]]                       # top (facing up)
        # walls: south (j=0), north (j=NY), west (i=0), east (i=NX)
        for i in range(NX):
            faces += [[idx(i, 0, False), idx(i + 1, 0, False), idx(i, 0, True)], [idx(i + 1, 0, False), idx(i + 1, 0, True), idx(i, 0, True)]]
            faces += [[idx(i, NY, False), idx(i, NY, True), idx(i + 1, NY, False)], [idx(i + 1, NY, False), idx(i, NY, True), idx(i + 1, NY, True)]]
        for j in range(NY):
            faces += [[idx(0, j, False), idx(0, j, True), idx(0, j + 1, False)], [idx(0, j + 1, False), idx(0, j, True), idx(0, j + 1, True)]]
            faces += [[idx(NX, j, False), idx(NX, j + 1, False), idx(NX, j, True)], [idx(NX, j + 1, False), idx(NX, j + 1, True), idx(NX, j, True)]]
        vg = np.c_[v[:, 0], v[:, 2], -v[:, 1]]
        m = trimesh.Trimesh(vertices=vg, faces=np.array(faces), process=False)
        fn = key + suffix + ".glb"
        m.export(os.path.join(OUT, fn))
        return fn

    pt = lambda p: (np.array([[p.x]]), np.array([[p.y]]))
    for entry_t in layers:
        key, name, base, thick_or_top, tier, color, refs, note = entry_t[:8]
        extra = entry_t[8] if len(entry_t) > 8 else {}
        if callable(base) or callable(thick_or_top):
            # variable surfaces: base is an offset or fn; the second item is the TOP offset (float or fn)
            top = thick_or_top
            base_fn = base if callable(base) else (lambda x, y, b=base: np.full(x.shape, float(b)))
            top_fn = top if callable(top) else (lambda x, y, t=top: np.full(x.shape, float(t)))
            thick_gbr = float(top_fn(*pt(gbr))[0, 0] - base_fn(*pt(gbr))[0, 0])
            thick_sgb = float(top_fn(*pt(sgb))[0, 0] - base_fn(*pt(sgb))[0, 0])
            base_off = float(base_fn(*pt(gbr))[0, 0])
            entry = dict(key=key, name=name, base_offset_m=base_off, thickness_m=thick_gbr, variable=True,
                         thickness_at_sgb_m=thick_sgb, base_offset_at_sgb_m=float(base_fn(*pt(sgb))[0, 0]))
        else:
            base_fn, top_fn = base, base + thick_or_top
            entry = dict(key=key, name=name, base_offset_m=float(base), thickness_m=float(thick_or_top), variable=False)
        f_tilt = build(key, base_fn, top_fn, ref_z, kfac, Z_BOTTOM, Z_TOP)
        f_flat = build(key, base_fn, top_fn, gbr_base_z, 1.0, Z_BOTTOM, Z_TOP_FLAT, "_flat")
        entry.update(tier=tier, color=color, refs=refs, note=note, file=f_tilt, file_flat=f_flat)
        entry.update(extra)
        t_true = entry["thickness_m"]
        if not entry["variable"] and t_true < THIN_LIMIT:
            cap = float(extra.get("display_max_m", THIN_LIMIT))
            disp = max(t_true, min(THICKEN * t_true, cap))
            f_thick = build(key, base_fn, base_fn + disp, ref_z, kfac, Z_BOTTOM, Z_TOP, "_thick")
            entry.update(display_thickness_m=disp, file_thick=f_thick)
        manifest["layers"].append(entry)
    with open(os.path.join(OUT, "layers.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    print("wrote", len(layers), "layers (tilted + flat, thin ones also pre-thickened) ->", OUT)

    # Where do the modelled surfaces cut today's terrain?  Report the modelled outcrop of the gabbroid vs mapped Jpg.
    xg, yg = np.meshgrid(np.linspace(XW, XE, 350), np.linspace(YS, YN, 300))
    z = dem_at(xg.ravel(), yg.ravel()).reshape(xg.shape)
    off = (z - ref_z(xg, yg)) / kfac(xg, yg)
    jpg = units[units.unit == "Jpg"].geometry.union_all()
    from shapely.geometry import Point
    inside = np.array([jpg.contains(Point(x, y)) for x, y in zip(xg.ravel(), yg.ravel())]).reshape(xg.shape)
    gb = gab_base(xg, yg)
    in_lens = inside & (off >= gb) & (off <= GAB_TOP)
    print(f"Ground offset above first-flow base inside mapped Jpg: median {np.median(off[inside]):.0f} m, "
          f"10-90 % {np.percentile(off[inside], 10):.0f}-{np.percentile(off[inside], 90):.0f} m; modelled lens spans "
          f"{gb.min():.0f}-{GAB_TOP:.0f} m; {100.0 * in_lens.sum() / max(inside.sum(), 1):.0f} % of mapped Jpg ground lies inside the modelled lens")
    for code, p in (("GBR", gbr), ("SGB", sgb)):
        o = float((dem_at(np.array([p.x]), np.array([p.y]))[0] - ref_z(*pt(p))[0, 0]) / kfac(*pt(p))[0, 0])
        print(f"   {code}: ground {o:.0f} m above the modelled first-flow base (lens {gab_base(p.x, p.y):.0f}-{GAB_TOP:.0f} m, flow top {F1:.0f} m; zone A sheets {manifest['zone_a']['base_offset_m']:.0f}-{manifest['zone_a']['top_offset_m']:.0f} m)")


if __name__ == "__main__":
    main()
