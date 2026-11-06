"""Cover-thickness field for the surficial deposits (colluvium, weathered basalt, alluvium, till, ...).

OFM 69 (Stanford 2007) maps the EXTENT of every surficial unit (Observed, DGS10-2 polygons) and gives a MAXIMUM
thickness per unit in its unit descriptions (Observed), but no thickness grid: bedrock-surface contours are drawn
only below 200 ft, outside the carnelian valleys.  So the thickness field here is a model (Illustrative, A-G8):
inside each polygon the thickness rises linearly with distance from the polygon edge until the unit's maximum is
reached, i.e. T(x) = Tmax * min(1, d_edge / reach).  Edges are feather-thin, interiors reach the published maximum.

Maxima used (metres; OFM 69 unit descriptions unless noted):
  basalt colluvium 18 (blocky phase 'as much as 60 ft'; paper section 4.1 'up to 18 m'); weathered basalt 3
  ('generally less than 10 ft' of weathered material over fractured rock); alluvium 3 (paper 'up to 3 m'; OFM 69
  'as much as 15 ft'); stream terrace 4.5 (15 ft); swamp 3 (generally < 10 ft); weathered shale / shale colluvium
  4.5 (15 ft); pre-Illinoian till 15 (50 ft); terminal moraine / Rahway till 33 (110 ft); Lake Passaic deposits
  24 (lake-bottom 80 ft); fill and anything else 3.
Output: data/processed/terrain/cover_thickness_4m.png (8-bit, 0.2 m per level, 0-51 m) and cover.json.
"""
import json
import os
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TER = os.path.join(ROOT, "data", "processed", "terrain")
meta = json.load(open(os.path.join(TER, "terrain.json")))
units = json.load(open(os.path.join(TER, "unit_ids.json")))["surficial"]
CELL = meta["cell_size_m"]
SCALE = 0.2   # metres per 8-bit level

TMAX = {   # class -> (max thickness m, reach m, source)
    "basalt_colluvium": (18.0, 150.0, "OFM 69 Qcb 'as much as 60 ft'; paper section 4.1 'up to 18 m'"),
    "weathered_basalt": (3.0, 60.0, "OFM 69 Qwb 'generally less than 10 ft' over fractured rock"),
    "alluvium": (3.0, 40.0, "paper section 4.1 'up to 3 m' (OFM 69 Qal 'as much as 15 ft')"),
    "stream_terrace": (4.5, 60.0, "OFM 69 Qst 'as much as 15 ft'"),
    "swamp": (3.0, 60.0, "OFM 69 Qs 'generally less than 10 ft'"),
    "weathered_shale": (4.5, 60.0, "OFM 69 Qws/Qcs 'as much as 15 ft'"),
    "pre_illinoian_till": (15.0, 150.0, "OFM 69 Qpt 'as much as 50 ft'"),
    "terminal_moraine": (33.0, 200.0, "OFM 69 Qtmr 'as much as 110 ft'"),
    "rahway_till": (33.0, 200.0, "OFM 69 Qr 'as much as 110 ft'"),
    "glacial_lake_passaic": (24.0, 300.0, "OFM 69 Qpml lake-bottom 'as much as 80 ft'"),
    "talus": (4.5, 20.0, "OFM 69 Qta 'as much as 15 ft' (apron below the cliffs along Green Brook south of Seelys Pond)"),
    "bedrock_outcrop": (0.0, 1.0, "OFM 69: extensive outcrop, no cover"),
}
DEFAULT = (3.0, 40.0, "default for minor units (fill, beach, eolian): 3 m")

cls = np.array(Image.open(os.path.join(TER, "surficial_class_4m.png")))
thick = np.zeros(cls.shape, dtype=np.float32)
table = {}
for name, e in units.items():
    cid = int(e["id"])
    tmax, reach, src = TMAX.get(name, DEFAULT)
    mask = cls == cid
    if not mask.any():
        continue
    d = ndimage.distance_transform_edt(mask) * CELL      # distance to the nearest non-class cell
    t = tmax * np.minimum(1.0, d / reach)
    thick[mask] = t[mask]
    table[name] = dict(id=cid, tmax_m=tmax, reach_m=reach, source=src, cells=int(mask.sum()),
                       mean_m=float(t[mask].mean()), max_m=float(t[mask].max()))
    print(f"{name:22s} id {cid:2d}  cells {int(mask.sum()):8d}  Tmax {tmax:5.1f} m  reach {reach:4.0f} m  mean {t[mask].mean():4.1f}  max {t[mask].max():4.1f}")
img = np.clip(np.round(thick / SCALE), 0, 255).astype(np.uint8)
Image.fromarray(img).save(os.path.join(TER, "cover_thickness_4m.png"))
json.dump({"scale_m_per_level": SCALE, "model": "T = Tmax * min(1, distance_to_polygon_edge / reach); Illustrative taper of Observed extents and maxima (ASSUMPTIONS A-G8)",
           "classes": table}, open(os.path.join(TER, "cover.json"), "w"), indent=2)
print("wrote cover_thickness_4m.png (max %.1f m) and cover.json" % thick.max())
