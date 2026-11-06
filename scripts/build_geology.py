"""Clip, reproject and localise the vector geology for the study area, and rasterise unit maps.

Inputs
  data/raw/njgws_24k/dgs15-1/dgs15-1/Chatham.gdb   NJGWS DGS15-1 bedrock 1:24,000 (compiles GMS 04-02)
  data/raw/njgws_24k/dgs10-2/Chatham.gdb           NJGWS DGS10-2 surficial 1:24,000 (compiles OFM 69)
  data/raw/nhd/NHD_H_0203_HU4_GPKG.gpkg            USGS NHD flowlines / waterbodies
Outputs (data/processed/vectors/, GeoJSON, coordinates in scene-local metres:
         x = UTM easting - 547500, y = UTM northing - 4500500; Godot uses (x, elevation, -y))
  bedrock_units, bedrock_contacts, faults, folds, surficial_units, glacial_features, streams,
  waterbodies, sample_sites (paper Fig. 2 asterisks as approximate zones), mindat_localities,
  strike_dip (digitised from paper Fig. 2)
Outputs (data/processed/terrain/)
  bedrock_units_4m.png, surficial_class_4m.png  (8-bit unit-ID rasters on the terrain grid)
  unit_ids.json  (ID -> unit code, name, colour)
"""
import json
import os
import numpy as np
import geopandas as gpd
from shapely.geometry import box, Point, LineString, MultiLineString, mapping
from shapely.affinity import translate
from rasterio import features
from rasterio.transform import from_origin
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "data", "raw")
VEC = os.path.join(ROOT, "data", "processed", "vectors")
TER = os.path.join(ROOT, "data", "processed", "terrain")
os.makedirs(VEC, exist_ok=True)
os.makedirs(TER, exist_ok=True)

CRS = "EPSG:26918"
BBOX = (540500.0, 4494500.0, 554500.0, 4506500.0)   # W, S, E, N
OX, OY = 547500.0, 4500500.0
CELL = 4.0
CLIP = box(*BBOX)

BEDROCK = os.path.join(RAW, "njgws_24k", "dgs15-1", "dgs15-1", "Chatham.gdb")
SURF = os.path.join(RAW, "njgws_24k", "dgs10-2", "Chatham.gdb")
NHD = os.path.join(RAW, "nhd", "NHD_H_0203_HU4_GPKG.gpkg")

# Bedrock unit IDs, display names, NJGS-style colours (hex)
BEDROCK_UNITS = {
    "JTrp": dict(id=1, name="Passaic Formation", color="#C9A79B"),
    "Jo":   dict(id=2, name="Orange Mountain Basalt", color="#9A9A9A"),
    "Jf":   dict(id=3, name="Feltville Formation", color="#E8B4AC"),
    "Jfw":  dict(id=3, name="Feltville Formation (Washington Valley Member)", color="#E8B4AC"),
    "Jp":   dict(id=4, name="Preakness Basalt", color="#B9B9B9"),
    "Jpg":  dict(id=5, name="Preakness Basalt, gabbroid", color="#7E7E7E"),
    "Jps":  dict(id=6, name="Preakness Basalt, sedimentary interbed (Jps1)", color="#E5C7B8"),
    "Jt":   dict(id=7, name="Towaco Formation", color="#D8A8A0"),
    "Jh":   dict(id=8, name="Hook Mountain Basalt", color="#A8A8A8"),
    "Jb":   dict(id=9, name="Boonton Formation", color="#D4B3B3"),
}
# Surficial classes grouped for the app (OFM 69 local units -> class)
SURF_CLASS = {
    "weathered_basalt": dict(id=1, units=["Qwb", "Qwbt", "Qe/Qwb"], name="Weathered basalt", color="#C8B99C"),
    "basalt_colluvium": dict(id=2, units=["Qcb", "Qcbl", "Qe/Qcb", "Qcbl/Qpt"], name="Basalt colluvium", color="#B7A27A"),
    "alluvium": dict(id=3, units=["Qal", "Qcal", "Qaf"], name="Alluvium (and alluvium/colluvium undivided)", color="#F2E6B3"),
    "stream_terrace": dict(id=4, units=["Qst", "Qstu"], name="Stream terrace deposits", color="#EEDFA3"),
    "swamp": dict(id=5, units=["Qs"], name="Swamp and marsh deposits", color="#A9C7B5"),
    "weathered_shale": dict(id=6, units=["Qws", "Qe/Qws", "Qcs", "Tp/Qws"], name="Weathered shale / shale colluvium", color="#D9B8A8"),
    "pre_illinoian_till": dict(id=7, units=["Qpt"], name="Pre-Illinoian (early Pleistocene) till", color="#8FB3D9"),
    "terminal_moraine": dict(id=8, units=["Qtmr"], name="Late Wisconsinan terminal moraine (Rahway till)", color="#4C78B5"),
    "rahway_till": dict(id=9, units=["Qr", "Qrt", "Qry"], name="Rahway till (late Wisconsinan)", color="#7FA3D1"),
    "glacial_lake_passaic": dict(id=10, units=["Qpml", "Qpmd", "Qpmf", "Qe/Qpml", "Qpc", "Qpg", "Qpf"], name="Glacial Lake Passaic deposits", color="#BFD8EE"),
    "eolian": dict(id=11, units=["Qe"], name="Eolian deposits", color="#EFE3C8"),
    "pensauken": dict(id=12, units=["Tp"], name="Pensauken Formation (Neogene fluvial)", color="#E6C27A"),
    "talus": dict(id=13, units=["Qta"], name="Talus", color="#A89F91"),
    "bedrock_outcrop": dict(id=14, units=["r"], name="Extensive bedrock outcrop", color="#9C9C9C"),
}


def strip_z(g):
    if not g.has_z:
        return g
    if g.geom_type == "LineString":
        return LineString([(x, y) for x, y, *_ in g.coords])
    if g.geom_type == "MultiLineString":
        return MultiLineString([LineString([(x, y) for x, y, *_ in p.coords]) for p in g.geoms])
    from shapely import force_2d
    return force_2d(g)


def localise(gdf):
    gdf = gdf.to_crs(CRS)
    gdf = gpd.clip(gdf, CLIP)
    gdf = gdf[~gdf.geometry.is_empty].copy()
    gdf["geometry"] = gdf.geometry.apply(lambda g: translate(strip_z(g), -OX, -OY))
    return gdf


def dump(gdf, name, keep=None):
    gdf = gdf.copy()
    if keep is not None:
        gdf = gdf[[c for c in keep if c in gdf.columns] + ["geometry"]]
    gdf = gdf.set_crs(None, allow_override=True)
    path = os.path.join(VEC, name + ".geojson")
    gdf.to_file(path, driver="GeoJSON")
    print(f"{name:22s} {len(gdf):5d} features")
    return gdf


def rasterise(gdf, id_col, name):
    w = int((BBOX[2] - BBOX[0]) / CELL)
    h = int((BBOX[3] - BBOX[1]) / CELL)
    tr = from_origin(BBOX[0] - OX, BBOX[3] - OY, CELL, CELL)   # local coords
    shapes = [(mapping(g), int(v)) for g, v in zip(gdf.geometry, gdf[id_col]) if not g.is_empty]
    arr = features.rasterize(shapes, out_shape=(h, w), transform=tr, fill=0, dtype="uint8")
    Image.fromarray(arr, mode="L").save(os.path.join(TER, name))
    print("raster", name, arr.shape, "ids", sorted(set(np.unique(arr).tolist())))


def wgs_points(rows, lon_key="lon", lat_key="lat"):
    gdf = gpd.GeoDataFrame(rows, geometry=[Point(r[lon_key], r[lat_key]) for r in rows], crs="EPSG:4326").to_crs(CRS)
    gdf["geometry"] = gdf.geometry.apply(lambda g: translate(g, -OX, -OY))
    return gdf


def main():
    # ---------------- bedrock ----------------
    bu = localise(gpd.read_file(BEDROCK, layer="Chatham_BedrockUnits"))
    bu["unit"] = bu["LOCALUNIT"].str.strip()
    bu["unit_id"] = bu["unit"].map(lambda u: BEDROCK_UNITS[u]["id"])
    bu["name"] = bu["unit"].map(lambda u: BEDROCK_UNITS[u]["name"])
    bu["tier"] = "observed"
    bu["source"] = "NJGWS DGS15-1 (GMS 04-02 Chatham); paper Fig. 2"
    dump(bu, "bedrock_units", ["unit", "unit_id", "name", "tier", "source"])
    rasterise(bu, "unit_id", "bedrock_units_4m.png")

    bc = localise(gpd.read_file(BEDROCK, layer="Chatham_Contacts"))
    bc = bc[bc["TYPE"].str.strip() != "Map boundary"].copy()
    bc["kind"] = bc["EXICON"].str.strip().str.lower()
    bc["tier"] = "observed"
    dump(bc, "bedrock_contacts", ["TYPE", "kind", "tier"])

    bf = localise(gpd.read_file(BEDROCK, layer="Chatham_Faults"))
    bf["kind"] = bf["Kind"].str.strip().replace("", "unspecified")
    bf["confidence"] = bf["ExiCon"].str.strip().str.lower()
    bf["tier"] = "observed"
    dump(bf, "faults", ["kind", "confidence", "tier"])

    fo = localise(gpd.read_file(BEDROCK, layer="Chatham_Folds"))
    fo["kind"] = fo["Kind"].str.strip()
    fo["name"] = fo["Name"].str.strip()
    fo["tier"] = "observed"
    dump(fo, "folds", ["kind", "name", "tier"])

    # ---------------- surficial ----------------
    su = localise(gpd.read_file(SURF, layer="Chatham_SurficialUnits"))
    su["unit"] = su["LOCALUNIT"].str.strip()
    lookup = {u: k for k, v in SURF_CLASS.items() for u in v["units"]}
    su["cls"] = su["unit"].map(lambda u: lookup.get(u, "other"))
    su["cls_id"] = su["cls"].map(lambda c: SURF_CLASS[c]["id"] if c in SURF_CLASS else 0)
    su["name"] = su["LOCALNAME"].str.strip()
    su["tier"] = "observed"
    su["source"] = "NJGWS DGS10-2 (OFM 69 Chatham)"
    dump(su, "surficial_units", ["unit", "cls", "cls_id", "name", "tier", "source"])
    rasterise(su, "cls_id", "surficial_class_4m.png")
    unmapped = sorted(set(su.loc[su.cls == "other", "unit"]))
    if unmapped:
        print("surficial units left unclassed:", unmapped)

    gl = su[su.cls.isin(["pre_illinoian_till", "terminal_moraine", "rahway_till", "glacial_lake_passaic"])].copy()
    gl["feature"] = gl["cls"]
    dump(gl, "glacial_features", ["unit", "feature", "name", "tier", "source"])

    # ---------------- hydrography ----------------
    fl = gpd.read_file(NHD, layer="NHDFlowline", bbox=(-74.56, 40.57, -74.30, 40.76))
    fl = fl[fl.fcode.isin([46006, 46003, 46007, 55800, 33600, 33400])]
    fl = localise(fl).explode(index_parts=False)
    fl["name"] = fl["gnis_name"].fillna("")
    # Stirling Brook is not named in NHD; the unnamed flowlines in the SGB valley are tagged by
    # position (ASSUMPTIONS.md A-H2).  Box is local metres around the SGB zone.
    sb_box = box(544559 - OX - 2500, 4499483 - OY - 1500, 544559 - OX + 1200, 4499483 - OY + 2200)
    is_sb = fl.geometry.intersects(sb_box) & (fl["name"] == "")
    fl.loc[is_sb, "name"] = "Stirling Brook (unnamed in NHD; tagged by position)"
    fl["tier"] = "observed"
    fl["source"] = "USGS NHD Best Resolution HU4 0203"
    dump(fl, "streams", ["name", "fcode", "lengthkm", "tier", "source"])

    wb = localise(gpd.read_file(NHD, layer="NHDWaterbody", bbox=(-74.56, 40.57, -74.30, 40.76)))
    wb["name"] = wb["gnis_name"].fillna("")
    wb["tier"] = "observed"
    dump(wb, "waterbodies", ["name", "fcode", "tier"])

    # ---------------- sample sites (paper Fig. 2 asterisks; approximate zones only) ----------------
    note = ("Position read off the Fig. 2 asterisk by graticule interpolation (the figure's scale bar and graticule disagree by ~8 %, "
            "so +/-300 m); shown as a zone, not a point.")
    gbr_note = note + (" Fig. 2 draws the GBR asterisk at the south-western tip of a gabbroid (Jpg) lens; in the NJGWS DGS15-1 digital "
                       "map the nearest Jpg polygon begins ~430 m to the north-east, i.e. Fig. 2 (modified from that map by the authors) "
                       "extends the gabbroid lens farther south-west than the digital data do. The zone follows the paper.")
    sites = wgs_points([
        dict(code="GBR", name="Green Brook sample area", lon=-74.433, lat=40.665, radius_m=250, tier="observed", note=gbr_note, source="paper Fig. 2, section 4.1"),
        dict(code="SGB", name="Stirling Brook sample area", lon=-74.473, lat=40.645, radius_m=250, tier="observed", note=note, source="paper Fig. 2, section 4.1"),
    ])
    dump(sites, "sample_sites")

    # ---------------- Mindat localities (user-contributed; own class) ----------------
    md = wgs_points([
        dict(mindat_id=12185, name='Stirling Brook ("Carnelian Creek"), Warren Township, Somerset County, NJ',
             lon=-74.47417, lat=40.64366,
             stated_precision="coordinates given to 1 arc-second (~30 m); the page map shows a point only. Treated as +/-500 m.",
             minerals="Magnetite; Moganite; Opal; Quartz (var. Carnelian, Chalcedony, Citrine, Rock Crystal)",
             rock_types="Basalt; Chert",
             references="Speiser (1978) A Quest for New Jersey Minerals, 10; Volkert et al. (2023) Minerals 13(10) 1249",
             tier="mindat_reported", accessed="2026-11-04", url="https://www.mindat.org/loc-12185.html"),
        dict(mindat_id=437482, name="Green Brook, Berkeley Heights, Union County, NJ",
             lon=-74.42472, lat=40.66667,
             stated_precision="coordinates given to the whole arc-minute of latitude (40 deg 40' 0\" N, 74 deg 25' 28\" W). Treated as +/-1 km.",
             minerals="Moganite; Quartz (var. Carnelian)",
             rock_types="Basalt",
             references="Volkert et al. (2023) Minerals 13(10) 1249",
             tier="mindat_reported", accessed="2026-11-04", url="https://www.mindat.org/loc-437482.html"),
        dict(mindat_id=233622, name="Cory's Brook, Warren Township, Somerset County, NJ",
             lon=-74.499, lat=40.641,
             stated_precision="Mindat gives only an ESTIMATED position (40 N, 74 W est., margin ~1 km). The marker is placed on the NHD flowline named Corys Brook; treated as +/-1 km.",
             minerals="Quartz (var. Carnelian, var. Chalcedony)",
             rock_types="(none listed)",
             references="No published reference on Mindat (entry credits a collector). Description: 'Another of the many brooks draining the second Watchung mountain known for Carnelian.'",
             tier="mindat_reported", accessed="2026-11-04", url="https://www.mindat.org/loc-233622.html"),
        dict(mindat_id=156348, name="Watchung (borough), Somerset County, NJ",
             lon=-74.451, lat=40.638,
             stated_precision="Town-level entry (coordinates 'taken from the Chatham topo map'); treated as the whole borough, +/-2 km.",
             minerals="Quartz var. Carnelian (listed for the borough as a region)",
             rock_types="(trap rock / aggregates commodity)",
             references="Ransom (1974) Fossils in America / mineral-locality compilation as cited by Mindat",
             tier="mindat_reported", accessed="2026-11-04", url="https://www.mindat.org/loc-156348.html"),
        dict(mindat_id=175647, name="Berkeley Heights (township), Union County, NJ",
             lon=-74.425, lat=40.683,
             stated_precision="Town-level entry; treated as the whole township, +/-2 km.",
             minerals="Quartz var. Carnelian",
             rock_types="(none listed)",
             references="Blyskal (2013), a collector's account on Mindat of finds in Green Brook in the 1960s",
             tier="mindat_reported", accessed="2026-11-04", url="https://www.mindat.org/loc-175647.html"),
    ])
    # County-level Mindat carnelian listings outside the study area (no marker; shown in the Mindat panel only):
    #   Bergen County, NJ (loc-23780) and Morris County, NJ (loc-17427), both citing Ransom (1974).
    # These disagree with the paper's statement that carnelian is present in New Jersey ONLY along Green Brook
    # and Stirling Brook (paper section 1); see REVIEW_GUIDE.md.
    json.dump([
        dict(mindat_id=23780, name="Bergen County, NJ", level="county", minerals="Quartz var. Carnelian (among many)", references="Ransom (1974)", url="https://www.mindat.org/loc-23780.html", accessed="2026-11-04"),
        dict(mindat_id=17427, name="Morris County, NJ", level="county", minerals="Quartz var. Carnelian, var. Sard, var. Sardonyx (among many)", references="Ransom (1974)", url="https://www.mindat.org/loc-17427.html", accessed="2026-11-04"),
    ], open(os.path.join(VEC, "mindat_county_level.json"), "w"), indent=2)
    dump(md, "mindat_localities")

    # ---------------- strike/dip digitised from Fig. 2 (DGS15-1 has no strike/dip layer) ----------------
    # Fig. 2 graticule in the extracted 701x752 px image: x 74 30' (px 40) -> 74 25' (px 490) = 90 px/arc-min;
    # y 40 40' (px 88) -> 40 37'30" (px 388) = 120 px/arc-min.
    def fig2(px, py):
        return -(74.5 - (px - 40) / 90.0 / 60.0), 40.0 + 40.0 / 60.0 - (py - 88) / 120.0 / 60.0
    rows = []
    for px, py, dip, unit in [(190, 48, 11, "Jt"), (232, 68, 15, "Jt"), (462, 140, 11, "Jo"), (283, 275, 10, "Jf"),
                              (438, 300, 11, "JTrp"), (530, 262, 7, "JTrp"), (568, 285, 8, "JTrp")]:
        lon, lat = fig2(px, py)
        rows.append(dict(dip_deg=dip, dip_dir="NW", strike_deg=45, unit=unit, lon=round(lon, 4), lat=round(lat, 4), tier="observed",
                         note="Digitised by eye from paper Fig. 2; position +/-150 m; strike assumed 045 (parallel to the ridges)"))
    dump(wgs_points(rows), "strike_dip")

    with open(os.path.join(TER, "unit_ids.json"), "w") as f:
        json.dump({"bedrock": BEDROCK_UNITS, "surficial": SURF_CLASS,
                   "grid": {"cell_size_m": CELL, "bbox_utm": BBOX, "scene_origin_utm": [OX, OY]}}, f, indent=2)
    print("done")


if __name__ == "__main__":
    main()
