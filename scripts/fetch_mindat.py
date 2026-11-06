"""Fetch the Mindat records behind the app's Mindat-reported markers through the Mindat API (api.mindat.org/v1).

Needs a key: the environment variable MINDAT_API_KEY, or the file tools/mindat_key.txt (git-ignored). The app never
calls the API; this script runs in the pipeline and writes static data:
  data/processed/vectors/mindat_localities.geojson   the existing 5 markers, enriched with api_* properties
                                                     (mineral list, short description, coordinates as served,
                                                     level, last modified) - positions are NOT changed
  data/processed/vectors/mindat_minerals.json        property cards for Chalcedony, Carnelian, Moganite, Quartz
  data/processed/vectors/mindat_nj_carnelian.json    every New Jersey locality that lists Carnelian, with whether
                                                     it lies inside the study area (from the API, by scanning the
                                                     state's localities with expand=geomaterials)
Raw responses are kept in data/raw/mindat/. Mindat data: CC BY-NC-SA 4.0; cite Ralph et al. (2025), American
Mineralogist 110(6) 833-844. Run:  .venv/Scripts/python.exe scripts/fetch_mindat.py [--no-scan]
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "data", "raw", "mindat")
VEC = os.path.join(ROOT, "data", "processed", "vectors")
API = "https://api.mindat.org/v1/"
MINERALS = {"Chalcedony": 960, "Carnelian": 9333, "Moganite": 2739, "Quartz": 3337}
CARNELIAN = 9333
UA = "watchung-carnelian-pipeline/0.8 (research app; contact via repository)"


def key():
    k = os.environ.get("MINDAT_API_KEY", "").strip()
    p = os.path.join(ROOT, "tools", "mindat_key.txt")
    if not k and os.path.exists(p):
        k = open(p, encoding="utf-8").read().strip()
    if not k:
        sys.exit("no Mindat API key: set MINDAT_API_KEY or write tools/mindat_key.txt")
    return k


KEY = None


def get(path, params=None, tries=8):
    url = API + path + ("?" + urllib.parse.urlencode(params) if params else "")
    for i in range(tries):
        req = urllib.request.Request(url, headers={"Authorization": "Token " + KEY, "User-Agent": UA, "Accept": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read().decode("utf-8"))
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
            code = getattr(e, "code", 0)
            if (code in (502, 503, 504, 429) or code == 0) and i + 1 < tries:
                time.sleep(min(5.0 * (i + 1), 40.0))   # the origin times out now and then; wait it out
                continue
            raise
    return None


def save_raw(name, obj):
    os.makedirs(RAW, exist_ok=True)
    json.dump(obj, open(os.path.join(RAW, name), "w", encoding="utf-8"), indent=1)


def study_bbox():
    """lon/lat bounds of the terrain bbox (UTM 18N) with a small margin."""
    from pyproj import Transformer
    meta = json.load(open(os.path.join(ROOT, "godot", "data", "terrain", "terrain.json"), encoding="utf-8"))
    bb = meta["bbox_utm"]
    tr = Transformer.from_crs("EPSG:26918", "EPSG:4326", always_xy=True)
    lons, lats = [], []
    for e, n in [(bb["west"], bb["south"]), (bb["east"], bb["south"]), (bb["west"], bb["north"]), (bb["east"], bb["north"])]:
        lo, la = tr.transform(e, n)
        lons.append(lo)
        lats.append(la)
    return min(lons) - 0.01, max(lons) + 0.01, min(lats) - 0.01, max(lats) + 0.01


def main():
    global KEY
    KEY = key()
    today = time.strftime("%Y-%m-%d")
    names = {}
    if "--scan-only" in sys.argv:
        scan(today)
        return

    def mineral_name(mid):
        if mid not in names:
            rec = get("geomaterials/%d/" % mid, {"fields": "id,name,entrytype_text"})
            names[mid] = rec["name"]
            time.sleep(0.3)
        return names[mid]

    # 1. the markers' records
    gj_path = os.path.join(VEC, "mindat_localities.geojson")
    gj = json.load(open(gj_path, encoding="utf-8"))
    for f in gj["features"]:
        mid = int(f["properties"]["mindat_id"])
        rec = get("localities/%d/" % mid, {"expand": "geomaterials"})
        save_raw("locality_%d.json" % mid, rec)
        mins = [mineral_name(m) for m in rec.get("geomaterials", [])]
        p = f["properties"]
        p["api_minerals"] = "; ".join(sorted(mins)) if mins else "(none listed)"
        p["api_description"] = rec.get("description_short", "") or ""
        p["api_lat"] = rec.get("latitude")
        p["api_lon"] = rec.get("longitude")
        p["api_level"] = rec.get("level")
        p["api_modified"] = (rec.get("datemodify") or rec.get("dateadd") or "")[:10]
        p["api_fetched"] = today
        print("locality %d: %s | %s" % (mid, rec["txt"], p["api_minerals"]))
        time.sleep(0.5)
    json.dump(gj, open(gj_path, "w", encoding="utf-8"), indent=1)
    cl_path = os.path.join(VEC, "mindat_county_level.json")
    cl = json.load(open(cl_path, encoding="utf-8"))
    for e in cl:
        rec = get("localities/%d/" % int(e["mindat_id"]), {"expand": "geomaterials"})
        save_raw("locality_%d.json" % int(e["mindat_id"]), rec)
        e["api_mineral_count"] = len(rec.get("geomaterials", []))
        e["api_lists_carnelian"] = CARNELIAN in rec.get("geomaterials", [])
        e["api_fetched"] = today
        time.sleep(0.5)
    json.dump(cl, open(cl_path, "w", encoding="utf-8"), indent=1)

    # 2. mineral cards
    cards = {}
    fields = "id,name,mindat_formula,entrytype_text,varietyof,hmin,hmax,dmeas,lustre,colour,diapheny,csystem,description_short,aboutname,updttime"
    for nm, mid in MINERALS.items():
        rec = get("geomaterials/%d/" % mid, {"fields": fields})
        save_raw("geomaterial_%d.json" % mid, rec)
        var_of = rec.get("varietyof") or 0
        cards[nm] = {
            "mindat_id": mid, "url": "https://www.mindat.org/min-%d.html" % mid,
            "formula": (rec.get("mindat_formula") or "").replace("<sub>", "").replace("</sub>", ""),
            "entry_type": rec.get("entrytype_text", ""), "variety_of": mineral_name(var_of) if var_of else "",
            "hardness": (("%g" % rec["hmax"]) if rec["hmin"] == rec["hmax"] else "%g-%g" % (rec["hmin"], rec["hmax"])) if rec.get("hmax") else "",
            "specific_gravity": rec.get("dmeas", "") if rec.get("dmeas") not in ("0", "", None) else "",
            "lustre": rec.get("lustre", ""), "colour": rec.get("colour", ""), "diapheny": rec.get("diapheny", ""),
            "crystal_system": rec.get("csystem", ""), "description": rec.get("description_short", ""),
            "about_name": rec.get("aboutname", ""), "updated": (rec.get("updttime") or "")[:10], "fetched": today,
        }
        print("mineral %s: formula %s, hardness %s, SG %s" % (nm, cards[nm]["formula"], cards[nm]["hardness"], cards[nm]["specific_gravity"]))
        time.sleep(0.5)
    json.dump(cards, open(os.path.join(VEC, "mindat_minerals.json"), "w", encoding="utf-8"), indent=1)

    # 3. every New Jersey locality that lists Carnelian
    if "--no-scan" in sys.argv:
        return
    scan(today)


def scan(today):
    """Scan New Jersey's localities (the API serves 10 a page) for ones listing Carnelian; resumable."""
    lo0, lo1, la0, la1 = study_bbox()
    os.makedirs(RAW, exist_ok=True)
    prog_path = os.path.join(RAW, "nj_scan_progress.json")
    found = []
    page = 1
    seen = 0
    if os.path.exists(prog_path):
        prog = json.load(open(prog_path, encoding="utf-8"))
        found, page, seen = prog["found"], prog["page"], prog["seen"]
        print("resuming at page %d (%d seen, %d found)" % (page, seen, len(found)))
    url_params = {"txt": "New Jersey", "country": "USA", "expand": "geomaterials", "page_size": 100,
                  "fields": "id,txt,latitude,longitude,level,geomaterials,datemodify"}
    while True:
        url_params["page"] = page
        res = get("localities/", url_params)
        for r in res.get("results", []):
            seen += 1
            if ", New Jersey, USA" not in r.get("txt", "") and not r.get("txt", "").endswith("New Jersey, USA"):
                continue
            if CARNELIAN in (r.get("geomaterials") or []):
                lat, lon = r.get("latitude") or 0.0, r.get("longitude") or 0.0
                inside = bool(lat and lon and lo0 <= lon <= lo1 and la0 <= lat <= la1)
                found.append({"mindat_id": r["id"], "name": r["txt"], "lat": lat, "lon": lon, "level": r.get("level"),
                              "in_study_area": inside, "url": "https://www.mindat.org/loc-%d.html" % r["id"],
                              "modified": (r.get("datemodify") or "")[:10]})
        print("page %d: %d localities seen, %d list carnelian" % (page, seen, len(found)), flush=True)
        if not res.get("next"):
            break
        page += 1
        json.dump({"found": found, "page": page, "seen": seen}, open(prog_path, "w", encoding="utf-8"))
        time.sleep(0.4)
    out = {"fetched": today, "query": "localities with txt 'New Jersey' listing Carnelian (Mindat id 9333); study area = the app's terrain bbox",
           "study_bbox_lonlat": [lo0, lo1, la0, la1], "localities": sorted(found, key=lambda e: e["name"])}
    json.dump(out, open(os.path.join(VEC, "mindat_nj_carnelian.json"), "w", encoding="utf-8"), indent=1)
    save_raw("nj_carnelian_scan.json", out)
    print("%d New Jersey localities list carnelian; %d inside the study area" % (len(found), sum(1 for e in found if e["in_study_area"])))


if __name__ == "__main__":
    main()
