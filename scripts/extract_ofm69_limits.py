"""Digitise the glacier-margin lines M1 (approximate limit of pre-Illinoian glacier) and M2 (limit of late
Wisconsinan glacier) from Figure 1 of OFM 69 (Stanford 2007), which is a vector inset on the map sheet PDF.
Georeferencing: the inset draws the Chatham 7.5' quadrangle outline as a rectangle; its corners are
74 30' / 74 22'30" W and 40 45' / 40 37'30" N.  Output: data/processed/vectors/glacial_limits.geojson
(local metres, EPSG:26918 offset to the scene origin), tier 'observed' for the line as published, with the
digitising precision noted (inset scale ~1:100k; 1 pt ~ 35 m)."""
import json, os, pymupdf, numpy as np
from pyproj import Transformer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PDF = os.path.join(ROOT, "data", "raw", "sources", "ofm69", "ofm69.pdf")
OUT = os.path.join(ROOT, "data", "processed", "vectors", "glacial_limits.geojson")
meta = json.load(open(os.path.join(ROOT, "data", "processed", "terrain", "terrain.json")))
OX, OY = meta["scene_origin_utm"]["east"], meta["scene_origin_utm"]["north"]
INSET = pymupdf.Rect(2880, 190, 3460, 720)
PURPLE = (0.6, 0.25, 0.59)

pg = pymupdf.open(PDF)[0]
quad = None
lines = []
for d in pg.get_drawings():
    r = d["rect"]
    if not r.intersects(INSET):
        continue
    col = d.get("color")
    if col is None:
        continue
    c = tuple(round(v, 2) for v in col)
    pts = []
    for it in d["items"]:
        if it[0] == "l":
            if not pts or pts[-1] != (it[1].x, it[1].y):
                pts.append((it[1].x, it[1].y))
            pts.append((it[2].x, it[2].y))
        elif it[0] == "c":
            pts.append((it[4].x, it[4].y))
    if c == (0.14, 0.12, 0.13) and d.get("width") == 1.0 and r.width > 250 and r.height > 350:
        quad = r
    if c == PURPLE and (d.get("width") or 0) >= 1.9:
        lines.append(pts)
assert quad is not None, "quadrangle outline not found"
print("quad outline rect", quad)
# inset pt -> lon/lat (linear inside the quad outline; the inset is a small-scale index map)
def to_lonlat(x, y):
    lon = -74.5 + (x - quad.x0) / quad.width * 0.125
    lat = 40.75 - (y - quad.y0) / quad.height * 0.125
    return lon, lat
tr = Transformer.from_crs("EPSG:4326", "EPSG:26918", always_xy=True)
feats = []
lines.sort(key=lambda p: p[0][0])   # M1 starts farther west than M2
names = [("M1", "Approximate limit of pre-Illinoian (early Pleistocene) glacier"), ("M2", "Limit of late Wisconsinan glacier")]
for pts, (code, name) in zip(lines, names):
    ll = [to_lonlat(x, y) for x, y in pts]
    xy = [tr.transform(lo, la) for lo, la in ll]
    local = [[round(x - OX, 1), round(y - OY, 1)] for x, y in xy]
    print(code, len(local), "pts; lon/lat first/last", [tuple(round(v, 4) for v in ll[0]), tuple(round(v, 4) for v in ll[-1])])
    feats.append({"type": "Feature", "geometry": {"type": "LineString", "coordinates": local},
                  "properties": {"code": code, "name": name, "tier": "observed",
                                 "source": "Stanford (2007) OFM 69, Figure 1 (vector inset on the map sheet), digitised from the PDF; georeferenced on the quadrangle outline (inset scale ~1:100,000, ~35 m per point; treat positions as +/-200 m)",
                                 "precision_m": 200}})
json.dump({"type": "FeatureCollection", "features": feats}, open(OUT, "w"), indent=1)
print("wrote", OUT)
# check against the pre-Illinoian till polygons: all Qpt should lie on the glaciated (north) side of M1
import geopandas as gpd
from shapely.geometry import LineString, Point
gl = gpd.read_file(os.path.join(ROOT, "data", "processed", "vectors", "glacial_features.geojson"))
m1 = LineString(feats[0]["geometry"]["coordinates"])
qpt = gl[gl["feature"] == "pre_illinoian_till"]
for _, row in qpt.iterrows():
    c = row.geometry.centroid
    # signed side: compare centroid y with the line's y at that x (line runs roughly E-W)
    xs = np.array(m1.xy[0]); ys = np.array(m1.xy[1])
    yl = np.interp(c.x, xs[np.argsort(xs)], ys[np.argsort(xs)])
    print("Qpt polygon at (%.0f, %.0f): %s of M1 by %.0f m" % (c.x, c.y, "north" if c.y > yl else "SOUTH", abs(c.y - yl)))
sites = gpd.read_file(os.path.join(ROOT, "data", "processed", "vectors", "sample_sites.geojson"))
for _, row in sites.iterrows():
    c = row.geometry
    xs = np.array(m1.xy[0]); ys = np.array(m1.xy[1])
    yl = np.interp(c.x, xs[np.argsort(xs)], ys[np.argsort(xs)])
    print("%s zone centre: %s of M1 by %.0f m" % (row["code"], "north" if c.y > yl else "south", abs(c.y - yl)))
