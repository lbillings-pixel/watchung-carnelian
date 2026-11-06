"""Copy the processed pipeline outputs into the Godot project (godot/data/).

Run after the build_* scripts:  .venv/Scripts/python.exe scripts/sync_assets.py
"""
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "data", "processed")
DST = os.path.join(ROOT, "godot", "data")

FILES = {
    "terrain": ["heightmap_4m_rgb.png", "bedrock_units_4m.png", "surficial_class_4m.png", "cover_thickness_4m.png", "cover.json", "terrain.json", "unit_ids.json"],
    "vectors": ["bedrock_units.geojson", "bedrock_contacts.geojson", "faults.geojson", "folds.geojson",
                "surficial_units.geojson", "glacial_features.geojson", "streams.geojson", "waterbodies.geojson",
                "sample_sites.geojson", "mindat_localities.geojson", "mindat_county_level.json", "mindat_minerals.json", "mindat_nj_carnelian.json", "strike_dip.geojson", "glacial_limits.geojson"],
    "volumes": None,   # everything
    "charts": None,
}

for sub, names in FILES.items():
    s = os.path.join(SRC, sub)
    d = os.path.join(DST, sub)
    os.makedirs(d, exist_ok=True)
    if not os.path.isdir(s):
        continue
    for n in (names if names else os.listdir(s)):
        if os.path.isfile(os.path.join(s, n)):
            shutil.copy2(os.path.join(s, n), os.path.join(d, n))
            print("copied", sub + "/" + n)
