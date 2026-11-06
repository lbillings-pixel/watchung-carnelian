# DATA SOURCES

All accessed 2026-11-04 unless noted. Coordinates in the processed outputs are NAD83 / UTM 18N (EPSG:26918)
offset to the scene origin (E 547 500, N 4 500 500).

## Primary paper

Volkert, R.A., Gorring, M.L., Peck, W.H., Stanford, S.D. (2023). Characterization and Origin of Basalt-Derived
Carnelian in the Mesozoic Newark Basin, New Jersey, USA. *Minerals* 13(10), 1249.
https://doi.org/10.3390/min13101249 — PDF from https://mdpi-res.com/d_attachment/minerals/minerals-13-01249/article_deploy/minerals-13-01249.pdf
(the MDPI HTML page blocks scripted access). Licence: CC BY 4.0 as printed in the PDF.
Stored: `raw/paper/minerals-13-01249.pdf`, extracted text `raw/paper/paper_text.txt`, page renders and figure
images under `raw/paper/`.

## Elevation

**USGS 3DEP 1 m DEM**, project *NJ_NE6County_B23* (lidar 2023; published on The National Map 2026-09-17).
Four tiles, each 10 km × 10 km, EPSG:26918, 1 m cells, float32 metres (NAVD88):
`USGS_1M_18_x54y450`, `x54y451`, `x55y450`, `x55y451` (`_NJ_NE6County_B23.tif`), 1.30 GB total, from
`https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/1m/Projects/NJ_NE6County_B23/TIFF/`.
Found through the TNM Access API (`https://tnmaccess.nationalmap.gov/api/v1/products`). Public domain (USGS).
Stored: `raw/dem/`. Processed: `processed/terrain/heightmap_4m.{r16,png}`, `hillshade_4m.png`, `terrain.json`.

## Hydrography

**USGS National Hydrography Dataset (NHD) Best Resolution, HU4 0203** (published 2023-12-12), GeoPackage,
EPSG:4269. `https://prd-tnm.s3.amazonaws.com/StagedProducts/Hydrography/NHD/HU4/GPKG/NHD_H_0203_HU4_GPKG.zip`
(125 MB). Public domain. Stored `raw/nhd/`. Processed `processed/vectors/streams.geojson`, `waterbodies.geojson`.
Note: Green Brook carries a GNIS name; Stirling Brook does not (tagged by position, ASSUMPTIONS A-H2).

## Bedrock geology (1:24,000)

**NJGWS DGS15-1, Bedrock Geology of New Jersey, scale 1:24,000**, Chatham quadrangle file geodatabase
(`Chatham.gdb`: BedrockUnits, Contacts, Faults, Folds; EPSG:3424 NJ State Plane ft). This is the digital
compilation of Monteverde & Volkert (2005) GMS 04-02, the map the paper's Fig. 2 is modified from.
Catalogue entry: https://gisdata-njdep.opendata.arcgis.com/documents/njdep::dgs15-1-bedrock-geology-of-new-jersey-scale-124000/about
Download: `https://nj.gov/dep/gis/digidownload/zips/OpenData/njgws/dgs15-1.zip` (5.5 MB, all quadrangles);
per-quadrangle zips are also listed at https://dep.nj.gov/njgws/digital-data/dgs15-1/.
**Access note:** nj.gov and dep.nj.gov sit behind a bot-protection layer that returns HTTP 403 to scripted
clients (curl, requests). The zip was downloaded through the user's own browser in this session and placed in
`raw/njgws_24k/`. `scripts/download_data.py` documents this and does not attempt it.
Licence/credit: NJDEP GIS data; "any maps, publications, reports, or other documents produced ... will credit the
NJDEP's Geographic Information System (GIS) as the source of the data" (NJDEP metadata). Credited in the About panel.

## Surficial geology (1:24,000)

**NJGWS DGS10-2, Surficial Geology of New Jersey, scale 1:24,000**, Chatham quadrangle (`Chatham.gdb`:
SurficialUnits, BedrockContours; EPSG:3424). Digital compilation of Stanford (2007) OFM 69.
Download: `https://nj.gov/dep/gis/digidownload/zips/OpenData/njgws/dgs10-2.zip` (27 MB). Same access note and
credit as above. Stored `raw/njgws_24k/`. Processed `processed/vectors/surficial_units.geojson`,
`glacial_features.geojson`, `processed/terrain/surficial_class_4m.png`.

## Statewide 1:100,000 geology (fallback, not used for geometry)

NJDEP ArcGIS REST service `https://mapsdep.nj.gov/arcgis/rest/services/Features/Geology/MapServer`, layers
14 (Bedrock Geology, DGS04-6), 25 (Surficial Geology, DGS07-2), 6 (Faults). Queried as GeoJSON in EPSG:26918 for
an envelope around the study area. Stored `raw/njdep_100k/*.geojson`. Credit NJDEP.

## Mindat

mindat.org, read as public pages through the browser on 2026-11-04 (no API key then). On 2026-11-06 the user
supplied a Mindat API key (kept in `tools/mindat_key.txt`, git-ignored, or `MINDAT_API_KEY`); `scripts/fetch_mindat.py`
then fetched, through `api.mindat.org/v1`, the five marker records (`expand=geomaterials`: the minerals Mindat lists
now, the short description, coordinates as served, last-edit date), the two county records, property cards for
Chalcedony (960), Carnelian (9333), Moganite (2739) and Quartz (3337), and every New Jersey locality listing
Carnelian (a scan of the state's localities with `expand=geomaterials`; the `loc-by-min` endpoint timed out). Marker
positions and their stated precision were not changed. Raw responses: `raw/mindat/`. The app never calls the API.
robots.txt was read first; `/search.php` is disallowed and was not used; the crawl delay was respected.
Pages read 2026-11-04: `min-9333` (Carnelian, locality list), `loc-12185` (Stirling Brook "Carnelian Creek"),
`loc-437482` (Green Brook, Berkeley Heights), `loc-233622` (Cory's Brook), `loc-156348` (Watchung),
`loc-175647` (Berkeley Heights), `loc-23780` (Bergen County), `loc-17427` (Morris County).
Mindat data are user-contributed and are shown in the app as their own "Mindat-reported" class.
Attribution as required by Mindat: "Mindat.org is an outreach project of the Hudson Institute of Mineralogy";
cite Ralph, J. et al. (2025) Mindat.org: The open access mineralogy database to accelerate data-intensive
geoscience research. *American Mineralogist* 110(6), 833–844. doi:10.2138/am-2024-9486. Mindat data licence:
CC BY-NC-SA 4.0 (private, non-commercial use). Processed `processed/vectors/mindat_localities.geojson`,
`mindat_county_level.json`.

## Software

- Python 3.12 (uv-managed) with rasterio, geopandas, shapely, pyproj, numpy, scipy, trimesh, PyMuPDF, Pillow,
  matplotlib (versions pinned in `requirements.txt`).
- Godot 4.7.2-stable (official build, `tools/godot/`).

## Maps and papers supplied 2026-11-05 (stored under `raw/sources/<name>/`, text in `<name>_text.txt`)

| Folder | Citation | Use in the model | Licence / access |
|---|---|---|---|
| `gms04-2` | Monteverde, D.H. & Volkert, R.A. (2005). Bedrock Geologic Map of the Chatham Quadrangle, Morris, Union and Somerset Counties, NJ. NJGS Geologic Map Series GMS 04-02, 1:24,000. | Dip from cross-section A-A' (`scripts/measure_gms_section.py`); unit thicknesses; structure note. | NJ Geological Survey publication (state government); map sheet PDF supplied by the user. |
| `ofm69` | Stanford, S.D. (2007). Surficial Geology of the Chatham Quadrangle, Morris, Union and Somerset Counties, NJ. NJGS Open-File Map OFM 69, 1:24,000, with pamphlet. | Glacier limits M1/M2 digitised from Figure 1 (`scripts/extract_ofm69_limits.py`); unit thickness maxima for the cover field (`scripts/build_cover.py`). | NJ Geological Survey publication; PDF supplied by the user. |
| `puffer2001` | Puffer, J.H. & Volkert, R.A. (2001). Pegmatoid and gabbroid layers in Jurassic Preakness and Hook Mountain Basalts, Newark Basin, New Jersey. J. Geol. 109, 585-601. doi:10.1086/321963 | Positions of the vesicular gabbroid sheets and the glass-rich band; Berkeley Heights lens; first-flow and Jps thickness ranges. | University of Chicago Press, subscription; copy supplied by the user for this analysis. Not redistributed. |
| `steckler1993` | Steckler, M.S., Omar, G.I., Karner, G.D., Kohn, B.P. (1993). Pattern of hydrothermal circulation within the Newark basin from fission-track analysis. Geology 21, 735-738. | Chapter 1 fluid temperatures and the border-fault downwelling zone. | GSA, subscription; copy supplied by the user. Not redistributed. |
| `eltabakh1997` | El-Tabakh, M., Riccioni, R., Schreiber, B.C. (1997). Evolution of Late Triassic rift basin evaporites (Passaic Formation): Newark Basin, Eastern North America. Sedimentology 44, 767-790. | Anhydrite inclusion temperatures; glauberite pseudomorphs. | Wiley, subscription; copy supplied by the user. Not redistributed. |
| `rddad2022` | Rddad, L. et al. (2022). Unraveling the fluid flow evolution and precipitation mechanisms in calcite veins in relation to Pangea rifting, Newark Basin, USA. Geochemistry 82, 125918. | Mixing model and temperatures for chapters 1 and 4. | Elsevier, subscription; copy supplied by the user. Not redistributed. |
| `faust1978` | Faust, G.T. (1978). Joint systems in the Watchung basalt flows, New Jersey. USGS Professional Paper 864-B. | Column dimensions (chapter 3). | USGS, public domain. |

Derived outputs: `processed/vectors/glacial_limits.geojson` (M1, M2; ~200 m precision), `processed/terrain/cover_thickness_4m.png`
+ `cover.json` (modelled cover thickness, 0.2 m per level), `processed/volumes/*_flat.glb` (untilted stack), and the
re-fitted `processed/volumes/layers.json` (dip 9.5 deg toward 323.5, reference plane = Jp/Jps).
