extends Node
## Technical terms defined inline the first time they appear in a chapter.

## Mindat property cards (data/vectors/mindat_minerals.json, fetched by scripts/fetch_mindat.py; CC BY-NC-SA 4.0)
## are appended to the chalcedony, carnelian and moganite entries when present.
static var _cards: Dictionary = {}
static var _cards_loaded := false


static func mindat_card(name: String) -> String:
	if not _cards_loaded:
		_cards_loaded = true
		var d: Variant = AppState.load_json("res://data/vectors/mindat_minerals.json")
		if d is Dictionary:
			_cards = d
	if not _cards.has(name):
		return ""
	var c: Dictionary = _cards[name]
	var parts: Array = []
	if str(c.get("formula", "")) != "":
		parts.append(str(c["formula"]))
	if str(c.get("variety_of", "")) != "":
		parts.append("a variety of " + str(c["variety_of"]))
	if str(c.get("hardness", "")) != "":
		parts.append("hardness " + str(c["hardness"]))
	if str(c.get("specific_gravity", "")) != "":
		parts.append("SG " + str(c["specific_gravity"]))
	if str(c.get("diapheny", "")) != "":
		parts.append(str(c["diapheny"]).to_lower())
	if parts.is_empty():
		return ""
	return " [Mindat: %s; CC BY-NC-SA]" % ", ".join(parts)


const TERMS := {
	"gabbroid": "gabbroid: coarse-grained rock (pyroxene and plagioclase crystals up to 2 cm) that formed inside the basalt flow by fractionation; same minerals as the basalt, coarser texture (§2)",
	"amygdaloidal": "amygdaloidal: full of amygdules, former gas bubbles (vesicles) now filled with secondary minerals",
	"vesicle": "vesicle: a gas bubble frozen into cooling lava; here 2–10 mm across, up to 19 % of the rock in some gabbroid intervals (§5.2)",
	"colluvium": "colluvium: loose, angular rock debris that crept or washed down a slope (here basalt pebbles and cobbles in clayey silt, up to 18 m thick, §4.1)",
	"alluvium": "alluvium: sediment laid down by a stream (here silty sand to clayey silt up to 3 m, and gravel bars, §4.1)",
	"chalcedony": "chalcedony: microcrystalline, fibrous quartz; carnelian is its red (hematite-bearing) variety (§1, §4.4)",
	"moganite": "moganite: a silica polymorph (same SiO2, different structure) intergrown with the quartz fibres; ≥5 % here (§4.4)",
	"glauberite": "glauberite: a sodium-calcium sulfate salt (Na2Ca(SO4)2) that crystallised from brine before the carnelian and later dissolved, leaving molds (§4.3)",
	"devitrification": "devitrification: breakdown of volcanic glass into crystalline material; it releases silica into the fluid (§5.1)",
	"meteoric water": "meteoric water: water from rain and snow that has soaked into the ground; cool, dilute and (here) slightly alkaline (§5.3)",
	"hydrothermal fluid": "hydrothermal fluid: hot water circulating at depth; here acidic, Cl/F-bearing, 100–280 °C where it was heated (§5.1)",
	"δ18O": "δ18O: the ratio of oxygen-18 to oxygen-16 relative to ocean water, in per mil (‰); it records the water the mineral grew from and the temperature (§4.6)",
	"REE": "REE (rare earth elements): lanthanum to lutetium; HREE enrichment means the heavy ones (Gd–Lu) are concentrated relative to the light ones (§4.5)",
	"HREE": "HREE enrichment: heavy rare earths concentrated relative to light ones; a fingerprint of acidic, halogen-rich fluids (§4.5, §5.3)",
	"Eu anomaly": "Eu anomaly: europium depleted relative to its neighbours Sm and Gd (Eu/Eu* = 0.02 here, a very large negative anomaly, §4.5)",
	"pillow": "pillow lava: bulbous lobes (0.6–0.9 m here) formed when lava erupts under water (§2)",
	"columnar joints": "columnar joints: vertical cooling cracks that split basalt into prisms (≤0.5 m wide, 6 m long here, §2)",
	"length-fast": "length-fast chalcedony: the fibres' slow optical axis is across the fibre (c-axis perpendicular to fibre length); diagnostic of ordinary chalcedony as opposed to quartzine (§4.4)",
	"botryoidal": "botryoidal: a bubbly, grape-cluster surface texture produced by radiating fibre growth (§4.3)",
	"tholeiitic": "tholeiitic basalt: silica-saturated basalt typical of flood-basalt provinces (§2)",
	"half-graben": "half-graben: a basin bounded by a major fault on one side (here the border fault on the west), with the beds tilted toward it (§2)",
	"fractionation": "fractionation: separation of early-formed crystals from the remaining melt, changing its composition (§2)",
	"albitization": "albitization: replacement of calcium-rich plagioclase by sodium-rich albite by hot fluids (§5.2)",
	"erratic": "erratic: a boulder carried by a glacier from a distant source (§4.1)",
	"till": "till: unsorted sediment deposited directly by glacier ice (§4.1)",
	"terminal moraine": "terminal moraine: the ridge of till marking the farthest advance of a glacier (§4.1)",
	"paragenesis": "paragenesis: the order in which minerals formed (§5.2)",
	"Scherrer": "crystallite size (Scherrer equation): size of coherently diffracting domains estimated from X-ray peak width (§3)",
}

var _seen := {}


func reset_chapter() -> void:
	_seen.clear()


## Returns the definition the first time a term is requested in the current chapter, else "".
func first_use(term: String) -> String:
	if _seen.has(term):
		return ""
	_seen[term] = true
	return define(term)


const MINDAT_TERMS := {"chalcedony": "Chalcedony", "moganite": "Moganite", "carnelian": "Carnelian"}


func define(term: String) -> String:
	var d: String = TERMS.get(term, "")
	if d != "" and MINDAT_TERMS.has(term):
		d += mindat_card(MINDAT_TERMS[term])
	return d
