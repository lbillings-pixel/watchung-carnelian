"""Verify the pipeline outputs: files exist, CRS/bbox are right, the structural model is consistent with the
map, and the numbers baked into layers.json match the paper. Exit code 1 on any failure.

  .venv/Scripts/python.exe scripts/verify_pipeline.py
"""
import json
import os
import sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "data", "processed")
fails = 0


def check(cond, msg):
    global fails
    print(("  ok   " if cond else "  FAIL ") + msg)
    if not cond:
        fails += 1


# ---- terrain ----
meta = json.load(open(os.path.join(P, "terrain", "terrain.json")))
check(meta["crs"] == "EPSG:26918", "terrain CRS EPSG:26918")
bb = meta["bbox_utm"]
check((bb["west"], bb["south"], bb["east"], bb["north"]) == (540500.0, 4494500.0, 554500.0, 4506500.0), "terrain bbox")
check(meta["width"] == 3500 and meta["height"] == 3000 and meta["cell_size_m"] == 4.0, "terrain grid 3500x3000 @ 4 m")
r16 = os.path.join(P, "terrain", "heightmap_4m.r16")
check(os.path.getsize(r16) == 3500 * 3000 * 2, "heightmap_4m.r16 size")
hm = np.fromfile(r16, dtype=np.uint16).reshape(3000, 3500).astype(float) / 65535 * (meta["z_max_m"] - meta["z_min_m"]) + meta["z_min_m"]
check(10.0 < meta["z_min_m"] < 20.0 and 170.0 < meta["z_max_m"] < 185.0, "elevation range plausible for the Watchungs (%.1f-%.1f m)" % (meta["z_min_m"], meta["z_max_m"]))
from PIL import Image
rgb = np.array(Image.open(os.path.join(P, "terrain", "heightmap_4m_rgb.png")))
dec = (rgb[..., 0].astype(int) * 256 + rgb[..., 1]) / 65535 * (meta["z_max_m"] - meta["z_min_m"]) + meta["z_min_m"]
check(np.abs(dec - hm).max() < 0.01, "packed RGB heightmap decodes to the r16 within 1 cm")
for n in ["bedrock_units_4m.png", "surficial_class_4m.png", "hillshade_4m.png"]:
    im = Image.open(os.path.join(P, "terrain", n))
    check(im.size == (3500, 3000), n + " on the terrain grid")

# ---- vectors ----
import geopandas as gpd
V = os.path.join(P, "vectors")
bu = gpd.read_file(os.path.join(V, "bedrock_units.geojson"))
units = set(bu["unit"])
check({"Jp", "Jpg", "Jps", "Jf", "Jo", "Jt", "JTrp"} <= units, "bedrock units include Jp, Jpg, Jps, Jf, Jo, Jt, JTrp (got %s)" % sorted(units))
tb = bu.total_bounds
check(tb[0] >= -7000.5 and tb[2] <= 7000.5 and tb[1] >= -6000.5 and tb[3] <= 6000.5, "bedrock polygons clipped to the local bbox")
su = gpd.read_file(os.path.join(V, "surficial_units.geojson"))
cls = set(su["cls"])
check({"weathered_basalt", "basalt_colluvium", "alluvium", "pre_illinoian_till", "terminal_moraine", "glacial_lake_passaic"} <= cls, "surficial classes present")
st = gpd.read_file(os.path.join(V, "streams.geojson"))
check((st["name"] == "Green Brook").sum() > 10, "Green Brook flowlines present")
check(st["name"].str.startswith("Stirling Brook").sum() > 3, "Stirling Brook flowlines tagged")
sites = gpd.read_file(os.path.join(V, "sample_sites.geojson"))
check(len(sites) == 2 and set(sites["code"]) == {"GBR", "SGB"}, "two sample-site zones")
# sample sites must lie on Preakness (Jp or Jpg) in the map
from shapely.geometry import Point
jp = bu[bu.unit.isin(["Jp", "Jpg"])].geometry.union_all()
for _, s in sites.iterrows():
    check(jp.contains(s.geometry), "%s zone centre lies on mapped Preakness Basalt" % s["code"])
# GBR gabbroid proximity: the paper says the sites are underlain by gabbroid in the upper first flow
jpg = bu[bu.unit == "Jpg"].geometry.union_all()
for _, s in sites.iterrows():
    d = jpg.distance(s.geometry)
    # GBR: Fig. 2 draws the gabbroid lens ~430 m farther SW than the digital DGS15-1 polygon (ASSUMPTIONS A-G9);
    # report the distance, fail only if the paper/map disagreement grows beyond 600 m.
    check(d < 600.0, "%s zone centre within 600 m of a mapped Jpg polygon (%.0f m; GBR known offset ~430 m, see REVIEW_GUIDE)" % (s["code"], d))
md = gpd.read_file(os.path.join(V, "mindat_localities.geojson"))
check(len(md) == 5 and set(md["tier"]) == {"mindat_reported"}, "5 Mindat localities, all tier mindat_reported")
# Mindat Stirling Brook vs paper SGB zone: should be within ~1 km
sgb = sites[sites.code == "SGB"].geometry.iloc[0]
msb = md[md.mindat_id == 12185].geometry.iloc[0]
check(sgb.distance(msb) < 1000.0, "Mindat Stirling Brook point within 1 km of the Fig. 2 SGB zone (%.0f m)" % sgb.distance(msb))
gbr = sites[sites.code == "GBR"].geometry.iloc[0]
mgb = md[md.mindat_id == 437482].geometry.iloc[0]
check(gbr.distance(mgb) < 1500.0, "Mindat Green Brook point within 1.5 km of the Fig. 2 GBR zone (%.0f m)" % gbr.distance(mgb))

# ---- volumes ----
man = json.load(open(os.path.join(P, "volumes", "layers.json")))
pl = man["plane"]
check(6.0 <= pl["dip_deg"] <= 15.0, "dip within the GMS 04-02 range 6-15 (%.1f deg; section A-A' reads 9.3-9.7)" % pl["dip_deg"])
check(abs(pl["dip_deg"] - 9.5) < 0.01, "dip is the value measured on the GMS 04-02 section (9.5)")
fo = man.get("fold", {})
fc = fo.get("check", {})
check(fo.get("type") == "piecewise_cosine" and len(fo.get("control_u_m", [])) == 3, "folded reference surface present (cylindrical piecewise-cosine flexure, 3 control points)")
check(abs(fc.get("base_median_m", 99)) < 2.0 and abs(fc.get("top_median_m", 99)) < 2.0 and abs(fc.get("jo_jf_median_m", 99)) < 2.0,
      "folded base honours the Jf/Jp, Jp/Jps and Jo/Jf traces (median residuals %.1f / %.1f / %.1f m)" % (fc.get("base_median_m", 99), fc.get("top_median_m", 99), fc.get("jo_jf_median_m", 99)))
check(fc.get("min_dip_deg", 0) > 2.0 and fc.get("max_dip_deg", 99) <= 15.0, "local dip of the folded surface stays gentle (%.1f-%.1f deg; GMS limbs 6-15)" % (fc.get("min_dip_deg", 0), fc.get("max_dip_deg", 0)))
check(fo.get("control_u_m", [0])[0] <= -100.0 and fc.get("u_sgb_m", -1) > 0.0, "9.5 deg holds at GBR and across SGB (flexure starts %d m up-dip of GBR; SGB at u=%+.0f)" % (fo.get("control_u_m", [0])[0], fc.get("u_sgb_m", 0)))
check("flat_plane" in man and abs(man["flat_plane"]["a"]) < 1e-9, "untilted (flat) stack present")
L = {e["key"]: e for e in man["layers"]}
paper = {  # true thicknesses the paper states (ASSUMPTIONS A-G5)
    "feltville": 144.5, "feltville_aureole": 0.5, "glass_rind": 0.025, "amygdaloidal_top": 2.5, "jps1": 2.5,
    "feltville_lacustrine_1": 3.0, "feltville_lacustrine_2": 3.0, "glass_rich_gabbroid": 24.0,
}
for k, v in paper.items():
    check(abs(L[k]["thickness_m"] - v) < 1e-6, "%s thickness %s m" % (k, v))
check(abs(L["orange_mountain"]["thickness_m"] - 218.0) < 1.0, "Orange Mountain 218 m (GMS 04-02: about 715 ft)")
first_flow_top = L["jps1"]["base_offset_m"]
check(125.0 <= first_flow_top <= 145.0, "first flow drawn %g m (paper 125-145; Puffer & Volkert 140-180)" % first_flow_top)
check(abs(L["second_flow_base"]["thickness_m"] + L["second_flow"]["thickness_m"] - 70.0) < 1e-6, "second flow 70 m")
check(abs(L["upper_preakness"]["base_offset_m"] + L["upper_preakness"]["thickness_m"] - 315.0) < 1e-6, "Preakness total 315 m")
check(first_flow_top - 36.0 <= L["glass_rich_gabbroid"]["base_offset_m"] and L["glass_rich_gabbroid"]["base_offset_m"] + 24.0 <= first_flow_top - 12.0, "glass-rich gabbroid within 12-36 m below the flow top")
za = man.get("zone_a", {})
keys = za.get("keys", [])
check(len(keys) == 6 and all(k in L for k in keys), "candidate zone A drawn as a set of 6 vesicle-rich sheets")
sheets = [L[k] for k in keys]
check(all(0.01 <= e["thickness_m"] <= 3.0 for e in sheets), "every sheet 1 cm-3 m thick (Puffer & Volkert 2001 type 1 range)")
check(all(first_flow_top - 40.0 <= e["base_offset_m"] and e["base_offset_m"] + e["thickness_m"] <= first_flow_top - 2.5 for e in sheets), "every sheet inside the upper 40 m, below the amygdaloidal top")
tops = sorted(((e["base_offset_m"], e["base_offset_m"] + max(e["thickness_m"], e.get("display_thickness_m", 0))) for e in sheets))
check(all(tops[i][1] <= tops[i + 1][0] + 1e-6 for i in range(len(tops) - 1)), "sheets do not overlap at display thickness (cap %g m)" % sheets[0].get("display_max_m", 0))
ves = [e.get("vesicle_pct", 0) for e in sorted(sheets, key=lambda e: -e["base_offset_m"])]
check(ves[1] == 19 and ves[-1] == 2 and all(ves[i] >= ves[i + 1] for i in range(1, len(ves) - 1)), "vesicularity falls with depth: 19 %% in the uppermost Puffer & Volkert sheet to 2 %% at 36 m (%s)" % ves)
check(any(abs(e["base_offset_m"] + e["thickness_m"] - 140.0) < 1e-6 for e in sheets), "one sheet tops at 140 m (Table 1 vesicular-gabbroid sample height)")
g = L["gabbroid"]
check(g["variable"] and abs(g["thickness_m"] - 82.0) < 1e-6 and abs(g["thickness_at_sgb_m"] - 49.0) < 1e-6, "gabbroid lens 82 m at GBR, 49 m at SGB (paper section 4.1)")
check(abs(g["base_offset_m"] + g["thickness_m"] - 140.0) < 1e-6, "gabbroid top at 140 m above base (Table 1 vesicular-gabbroid height)")
# both sample-site zones must sit inside the modelled lens (ground elevation vs. the folded surfaces)
hm_meta = meta
def ground(x, y):
    col = int(np.clip((x + 7000.0) / 4.0, 0, 3499)); row = int(np.clip((6000.0 - y) / 4.0, 0, 2999))
    return hm[row, col]
cu, cd = fo["control_u_m"], fo["control_delta_m"]
ox, oy = fo["origin_xy"]; ddx, ddy = fo["down_dip_unit_xy"]
g0 = np.tan(np.radians(pl["dip_deg"]))
def delta(u):
    if u >= cu[0]:
        return cd[0], 0.0
    for i in range(len(cu) - 1):
        if cu[i] > u >= cu[i + 1]:
            Ls = cu[i] - cu[i + 1]; sfr = (cu[i] - u) / Ls
            return cd[i] + (cd[i + 1] - cd[i]) * (1 - np.cos(np.pi * sfr)) / 2, -(cd[i + 1] - cd[i]) * np.pi / (2 * Ls) * np.sin(np.pi * sfr)
    return cd[-1], 0.0
for _, s in sites.iterrows():
    u = (s.geometry.x - ox) * ddx + (s.geometry.y - oy) * ddy
    d, dd = delta(u)
    kk = np.sqrt(1.0 + (-g0 + dd) ** 2)
    off = (ground(s.geometry.x, s.geometry.y) - (pl["a"] * s.geometry.x + pl["b"] * s.geometry.y + pl["c"] + d)) / kk
    lo = g["base_offset_m"] if s["code"] == "GBR" else g["base_offset_at_sgb_m"]
    check(lo <= off <= 140.0, "%s ground inside the modelled gabbroid lens (%.0f m above base; lens %.0f-140 m)" % (s["code"], off, lo))
for e in man["layers"]:
    check(os.path.exists(os.path.join(P, "volumes", e["file"])), "glb exists: " + e["file"])
    check(os.path.exists(os.path.join(P, "volumes", e["file_flat"])), "flat glb exists: " + e["file_flat"])
    if e["thickness_m"] < man["thicken"]["thin_limit_m"] and not e.get("variable"):
        check("file_thick" in e and os.path.exists(os.path.join(P, "volumes", e["file_thick"])), "pre-thickened glb exists: " + e.get("file_thick", e["key"]))
    check(e["tier"] in ("observed", "inferred", "illustrative"), "tier set: " + e["key"])
    check(len(e["refs"]) > 0, "paper reference set: " + e["key"])

# ---- glacial limits (OFM 69 fig. 1) and cover thickness ----
gl = gpd.read_file(os.path.join(V, "glacial_limits.geojson"))
check(set(gl["code"]) == {"M1", "M2"}, "glacial limit lines M1 and M2 digitised from OFM 69 Figure 1")
m1 = gl[gl.code == "M1"].geometry.iloc[0]
qpt = gpd.read_file(os.path.join(V, "glacial_features.geojson"))
qpt = qpt[qpt["feature"] == "pre_illinoian_till"]
xs, ys = np.array(m1.xy[0]), np.array(m1.xy[1]); o = np.argsort(xs)
north = all(c.y > np.interp(c.x, xs[o], ys[o]) for c in qpt.geometry.centroid)
check(north, "every pre-Illinoian till polygon lies north of M1")
sg = sites[sites.code == "SGB"].geometry.iloc[0]
check(sg.y < np.interp(sg.x, xs[o], ys[o]), "SGB zone lies south of M1 (paper section 4.1)")
cov = Image.open(os.path.join(P, "terrain", "cover_thickness_4m.png"))
check(cov.size == (3500, 3000), "cover_thickness_4m.png on the terrain grid")
cj = json.load(open(os.path.join(P, "terrain", "cover.json")))
check(cj["classes"]["basalt_colluvium"]["tmax_m"] == 18.0 and cj["classes"]["alluvium"]["tmax_m"] == 3.0, "cover maxima: colluvium 18 m, alluvium 3 m (paper section 4.1)")

# ---- charts ----
for n in ["ree_pattern.png", "d18o_global.png", "table4_temps.png", "table1_alteration.png", "table2_crystallite.png"]:
    check(os.path.exists(os.path.join(P, "charts", n)), "chart " + n)

# ---- narration (round 4): one clip per tour beat, cues inside their clips, known layer keys ----
NJ = os.path.join(ROOT, "godot", "data", "narration", "narration.json")
check(os.path.exists(NJ), "narration.json present (scripts/build_narration.py)")
if os.path.exists(NJ):
    nar = json.load(open(NJ, encoding="utf-8"))
    import re as _re
    sys.path.insert(0, os.path.join(ROOT, "scripts"))
    import narration_script as NS
    layer_keys = {e["key"] for e in man["layers"]}
    check(set(nar["chapters"]) == set(NS.SCRIPT) == {"basement", "feltville", "eruption", "precipitation", "burial", "erosion", "present", "worm"}, "narration covers the eight chapters")
    check(300.0 < nar["total_s"] < 1200.0, "total narration %.1f min (5-20 min)" % (nar["total_s"] / 60.0))
    nclips = 0
    for cid, ch in nar["chapters"].items():
        # beat count must match the chapter script's tour_beats (count the beat(...) calls, or the W dicts)
        src = open(os.path.join(ROOT, "godot", "chapters", {"basement": "Ch1Basement", "feltville": "Ch2Feltville", "eruption": "Ch3Eruption", "precipitation": "Ch4Precipitation", "burial": "Ch5Burial", "erosion": "Ch6Erosion", "present": "Ch7Present", "worm": "Ch8Worm"}[cid] + ".gd"), encoding="utf-8").read()
        nb = len(_re.findall(r"^		beat\(", src, flags=_re.M)) or len(_re.findall(r'^		\{"t": S_', src, flags=_re.M))
        check(nb == len(ch["beats"]) == len(NS.SCRIPT[cid]), "%s: %d beats in the chapter, %d clips, %d script entries" % (cid, nb, len(ch["beats"]), len(NS.SCRIPT[cid])))
        for i, b in enumerate(ch["beats"]):
            f = os.path.join(ROOT, "godot", b["file"].replace("res://", ""))
            ok = os.path.exists(f) and 1.0 < b["duration"] < 60.0
            check(ok, "%s beat %d: clip %s, %.1f s" % (cid, i + 1, os.path.basename(f), b["duration"]))
            nclips += 1
            for c in b["cues"]:
                check(0.0 <= c["t"] <= b["duration"], "%s beat %d cue '%s' at %.1f s inside the clip" % (cid, i + 1, c["phrase"], c["t"]))
                for k in c.get("layers", []):
                    check(k == "zone_a" or k in layer_keys, "%s beat %d cue layer key known: %s" % (cid, i + 1, k))
            ends = [st["end"] for st in b["sentences"]]
            check(all(b["sentences"][j + 1]["start"] >= ends[j] for j in range(len(ends) - 1)), "%s beat %d sentences in order" % (cid, i + 1))
    check(nclips == sum(len(v) for v in NS.SCRIPT.values()), "%d narration clips" % nclips)

print("verify_pipeline:", "PASS" if fails == 0 else "FAIL (%d)" % fails)
sys.exit(1 if fails else 0)
