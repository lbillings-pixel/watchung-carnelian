"""Mosaic + clip the USGS 3DEP 1 m DEM tiles to the study bbox and write Godot-ready heightmaps.

Outputs (data/processed/terrain/):
  heightmap_4m.r16      raw little-endian uint16, row-major, north row first  (read by Godot)
  heightmap_4m.png      the same data as a 16-bit greyscale PNG (for inspection / other tools)
  hillshade_4m.png      8-bit hillshade used as the terrain base texture
  heightmap_4m_rgb.png  R,G = high/low byte of the 16-bit height, B = hillshade (what Godot reads)
  terrain.json          grid origin, cell size, size, z-scale, scene-origin offset

Study bbox (NAD83 / UTM 18N, EPSG:26918):  E 540500-554500, N 4494500-4506500.
Scene origin = bbox centre (547500, 4500500).  Godot x = east - 547500, z = 4500500 - north, y = elevation (m).
"""
import glob
import json
import os
import numpy as np
import rasterio
from rasterio.merge import merge
from rasterio.enums import Resampling
from rasterio.warp import reproject
from rasterio.transform import from_origin
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "data", "raw", "dem")
OUT = os.path.join(ROOT, "data", "processed", "terrain")
os.makedirs(OUT, exist_ok=True)

BBOX = dict(west=540500.0, east=554500.0, south=4494500.0, north=4506500.0)
ORIGIN = (547500.0, 4500500.0)   # scene origin, UTM metres
CELL = 4.0                        # output cell size, metres


def main():
    tiles = sorted(glob.glob(os.path.join(RAW, "*.tif")))
    assert tiles, "no DEM tiles in data/raw/dem"
    srcs = [rasterio.open(t) for t in tiles]
    for s in srcs:
        assert s.crs.to_epsg() == 26918, (s.name, s.crs)
    # merge only the bbox window (1 m), then downsample to CELL with averaging
    mosaic, tr = merge(srcs, bounds=(BBOX["west"], BBOX["south"], BBOX["east"], BBOX["north"]), nodata=-999999.0)
    mosaic = mosaic[0].astype(np.float32)
    nodata = srcs[0].nodata
    for s in srcs:
        s.close()
    bad = (mosaic <= -9000) | ~np.isfinite(mosaic)
    if nodata is not None:
        bad |= mosaic == nodata
    print("1 m window", mosaic.shape, "nodata cells", int(bad.sum()))
    mosaic[bad] = np.nan

    w = int(round((BBOX["east"] - BBOX["west"]) / CELL))
    h = int(round((BBOX["north"] - BBOX["south"]) / CELL))
    dst = np.full((h, w), np.nan, dtype=np.float32)
    dst_tr = from_origin(BBOX["west"], BBOX["north"], CELL, CELL)
    reproject(mosaic, dst, src_transform=tr, src_crs="EPSG:26918", src_nodata=np.nan,
              dst_transform=dst_tr, dst_crs="EPSG:26918", dst_nodata=np.nan, resampling=Resampling.average)
    # fill any remaining holes with the nearest valid value (there should be essentially none)
    if np.isnan(dst).any():
        from scipy import ndimage
        idx = ndimage.distance_transform_edt(np.isnan(dst), return_distances=False, return_indices=True)
        dst = dst[tuple(idx)]
    zmin, zmax = float(dst.min()), float(dst.max())
    print("4 m grid", dst.shape, "z range", zmin, zmax)

    # 16-bit quantisation: 0..65535 maps zmin..zmax  (resolution = (zmax-zmin)/65535 m, ~2 mm here)
    q = np.round((dst - zmin) / (zmax - zmin) * 65535.0).astype(np.uint16)
    q.tofile(os.path.join(OUT, "heightmap_4m.r16"))
    Image.fromarray(q).save(os.path.join(OUT, "heightmap_4m.png"))

    # hillshade (sun from NW, 45 deg elevation), 8-bit
    gy, gx = np.gradient(dst, CELL)
    slope = np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(-gx, gy)
    az, alt = np.deg2rad(315.0), np.deg2rad(45.0)
    shade = np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect)
    shade = np.clip(shade, 0, 1)
    shade8 = (shade * 255).astype(np.uint8)
    Image.fromarray(shade8, mode="L").save(os.path.join(OUT, "hillshade_4m.png"))
    # Godot-ready packed heightmap: R = high byte, G = low byte of the 16-bit height, B = hillshade.
    # (Godot's PNG importer strips 16-bit greyscale to 8-bit, so the height is split across two 8-bit channels.)
    rgb = np.dstack([(q >> 8).astype(np.uint8), (q & 255).astype(np.uint8), shade8])
    Image.fromarray(rgb, mode="RGB").save(os.path.join(OUT, "heightmap_4m_rgb.png"))

    meta = {
        "crs": "EPSG:26918",
        "bbox_utm": BBOX,
        "scene_origin_utm": {"east": ORIGIN[0], "north": ORIGIN[1]},
        "cell_size_m": CELL,
        "width": w, "height": h,
        "z_min_m": zmin, "z_max_m": zmax,
        "row_order": "north_first",
        "godot_axes": "x = east - origin.east; z = origin.north - north; y = elevation",
        "source": "USGS 3DEP 1 m DEM, project NJ_NE6County_B23, tiles " + ", ".join(os.path.basename(t) for t in tiles),
        "resampling": "block average 1 m -> 4 m",
    }
    with open(os.path.join(OUT, "terrain.json"), "w") as f:
        json.dump(meta, f, indent=2)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
