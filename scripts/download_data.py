"""Download the raw public datasets used by the pipeline.

Run from the project root:  .venv/Scripts/python.exe scripts/download_data.py [--skip-dem]

Everything downloaded here is recorded in data/SOURCES.md.  The NJGWS 1:24,000
quadrangle zips (dgs15-1.zip, dgs10-2.zip) sit behind a bot-protection layer on
nj.gov that refuses plain HTTP clients; they were fetched manually in a browser
and dropped into data/raw/njgws_24k/ (see SOURCES.md).  This script covers the
sources that are reachable with a plain HTTP client.
"""
import argparse
import os
import sys
import requests

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "data", "raw")

# USGS 3DEP 1 m DEM tiles (NAD83 / UTM 18N, EPSG:26918), project NJ_NE6County_B23
# (lidar flown 2023, published 2026-09-17 on The National Map).  Tile names give the
# upper-left corner in 10 km units; these four cover the study area bbox.
DEM_BASE = "https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/1m/Projects/NJ_NE6County_B23/TIFF/"
DEM_TILES = [
    "USGS_1M_18_x54y450_NJ_NE6County_B23.tif",
    "USGS_1M_18_x54y451_NJ_NE6County_B23.tif",
    "USGS_1M_18_x55y450_NJ_NE6County_B23.tif",
    "USGS_1M_18_x55y451_NJ_NE6County_B23.tif",
]

# USGS NHD Best Resolution, hydrologic unit 0203 (Lower Hudson–Long Island; includes
# the Passaic and Raritan basins that drain the study area).
NHD_URL = "https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/NHD/HU4/GPKG/NHD_H_0203_HU4_GPKG.zip"

# NJDEP statewide 1:100,000 geology layers, queried from the public ArcGIS REST
# service as GeoJSON in EPSG:26918 for a generous envelope around the study area.
NJDEP_LAYERS = {
    "bedrock_100k": 14,
    "surficial_100k": 25,
    "faults_100k": 6,
}
NJDEP_QUERY = ("https://mapsdep.nj.gov/arcgis/rest/services/Features/Geology/MapServer/{id}/query"
               "?geometry=-74.55,40.60,-74.30,40.80&geometryType=esriGeometryEnvelope&inSR=4326"
               "&spatialRel=esriSpatialRelIntersects&outFields=*&returnGeometry=true&outSR=26918&f=geojson")


def fetch(url, dest):
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        print("exists ", dest)
        return
    print("get    ", url)
    with requests.get(url, stream=True, timeout=120) as r:
        r.raise_for_status()
        tmp = dest + ".part"
        with open(tmp, "wb") as f:
            for chunk in r.iter_content(1 << 20):
                f.write(chunk)
        os.replace(tmp, dest)
    print("saved  ", dest, os.path.getsize(dest) // 1_000_000, "MB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-dem", action="store_true")
    a = ap.parse_args()
    os.makedirs(os.path.join(RAW, "dem"), exist_ok=True)
    os.makedirs(os.path.join(RAW, "nhd"), exist_ok=True)
    os.makedirs(os.path.join(RAW, "njdep_100k"), exist_ok=True)
    for name, lid in NJDEP_LAYERS.items():
        fetch(NJDEP_QUERY.format(id=lid), os.path.join(RAW, "njdep_100k", name + ".geojson"))
    fetch(NHD_URL, os.path.join(RAW, "nhd", os.path.basename(NHD_URL)))
    if not a.skip_dem:
        for t in DEM_TILES:
            fetch(DEM_BASE + t, os.path.join(RAW, "dem", t))


if __name__ == "__main__":
    main()
