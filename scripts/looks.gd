class_name Looks
extends RefCounted

const DEFAULT := {
	"skin": "#ffd6c4",
	"hair": "buns",
	"hair_color": "#6b4330",
	"eye_style": "classic",
	"eye_color": "#7a4a2a",
	"blush": 0.35,
	"top": {"shape": "tee", "color": "#ff9fb8", "color_b": "#ffffff", "pattern": "stripes", "trim": "#ffffff"},
	"bottom": {"shape": "shorts", "color": "#7fb4ff", "color_b": "#ffffff", "pattern": "plain", "trim": "#5d8fe0"},
	"shoes": {"shape": "sneakers", "color": "#ffffff", "color_b": "#ffffff", "pattern": "plain", "trim": "#ff8fa8"},
}

const HAT_COLORS := {
	"beanie_cat": ["#f3ece2", "#e6d8c4", "#ffb6c8"],
	"beanie_bear": ["#b07a50", "#9a6640", "#f2d2b0"],
	"beanie_bunny": ["#fbf8f4", "#f2e6ee", "#ffb6c8"],
	"guard_cap": ["#3b4a6b", "#2a3550", "#ffffff"],
	"rain_hat": ["#ffd23f", "#f2b62c", "#ffffff"],
	"helmet": ["#d8343c", "#2a2a2e", "#ffffff"],
	"moicoi": ["#6b7f4e", "#4f5f38", "#ffffff"],
	"cap": ["#e05050", "#be4444", "#ffffff"],
}

const ACC_COLORS := {
	"bow": ["#ff8fb0", "#ff6f96"],
	"strawberry_clip": ["#e8434d", "#58a85a"],
	"star_clip": ["#ffd36e", "#ffb84d"],
	"claw_clip": ["#f2a38c", "#fff1e0"],
}

const SHAPE_COLORS := {"raincoat": ["#ffd23f", "#f2b62c"]}

const SKINS := ["#ffe8d6", "#ffd9bd", "#f2c29a", "#d9a074", "#b47a52", "#8a5a3c"]
const HAIR_COLORS := ["#2e2320", "#6b4330", "#a8693c", "#e8c27a", "#f2a6c0", "#8fb7ff", "#9edb9a", "#c9a2ff", "#f5f0e6"]
const EYE_COLORS := ["#3a2a24", "#7a4a2a", "#4f86c6", "#4aa56a", "#b05aa8", "#d9822b"]
const CLOTH_COLORS := ["#ffffff", "#ff9fb8", "#ffb27a", "#ffe17a", "#a8e6a1", "#7fd3e6", "#7fb4ff", "#c4a3ff", "#5a5f7a", "#e06464"]
const PATTERNS := ["plain", "stripes", "dots", "check", "flowers"]

const DESIGNS := {
	"sailor": [["tee", "longsleeve", "dress"], ["#f4f6fb", "#2d3f74", "#d8434f"]],
	"gingham": [["tee", "longsleeve", "dress", "shirt"], ["#fffaf4", "#e0505a", "#ffffff"]],
	"soc": [["shirt", "tee", "longsleeve"], ["#f4f2ec", "#5d7fb0", "#ffffff"]],
	"cardigan": [["longsleeve"], ["#d9b24a", "#6b4a2e", "#fbf6ec"]],
	"office": [["longsleeve", "tee", "shirt"], ["#f7f8fb", "#2f3a63", "#e9eef7"]],
	"vest": [["longsleeve"], ["#f4f6fb", "#3b4256", "#8c2f39"]],
	"argyle": [["longsleeve", "tee"], ["#2f4f7a", "#e6b84c", "#f4f0e6"]],
	"raglan": [["tee", "longsleeve"], ["#fbfaf6", "#304a86", "#e0503c"]],
	"heart": [["tee", "longsleeve", "dress", "hoodie"], ["#fbf7f0", "#ff8fb0", "#ffffff"]],
	"strawberry": [["tee", "dress", "longsleeve"], ["#fff6e8", "#e8434d", "#58a85a"]],
	"floral": [["tee", "longsleeve", "dress", "shirt", "baba"], ["#efe9df", "#6f8a80", "#9fb6aa"]],
	"nordic": [["longsleeve", "hoodie"], ["#c8383e", "#fbf4ea", "#2f6a4a"]],
	"apron": [["dress"], ["#8fc3ef", "#fdfbf6", "#ffffff"]],
	"tricolor": [["tee", "longsleeve", "dress", "hoodie"], ["#fbf2e2", "#7fcfb8", "#f08a74"]],
	"bear": [["tee", "hoodie", "longsleeve"], ["#f7e6c8", "#a8693c", "#3a2a24"]],
	"denim": [["pants", "shorts", "rolled", "capri"], ["#3f6699", "#ffffff", "#ffffff", "#e0a050"]],
	"lanh": [["wide"], ["#16171c", "#4a4e5a", "#ffffff"]],
	"tartan": [["skirt", "pants", "shorts", "skirt_pleat", "skirt_midi"], ["#c23a3a", "#283c6a", "#f2d04a"]],
	"esports": [["tee", "longsleeve"], ["#d4202e", "#16171c", "#d9b45a"]],
	"football": [["tee", "polo"], ["#d32a1f", "#f7f6f2", "#1a1a1e"]],
	"track": [["pants", "shorts", "rolled", "jogger"], ["#2f3a56", "#e8e8ee", "#ffffff"]],
	"cargo": [["pants", "shorts", "rolled", "jogger", "capri"], ["#b39a6a", "#5a4a30", "#ffffff"]],
	"scallop": [["skirt"], ["#f6b6c8", "#fdf7f2", "#ffffff"]],
}
const TOP_DESIGNS := ["", "sailor", "gingham", "soc", "office", "vest", "cardigan", "argyle", "raglan", "heart", "strawberry", "floral", "nordic", "apron",
	"tricolor", "bear", "esports", "football"]
const BOTTOM_DESIGNS := ["", "denim", "tartan", "track", "cargo", "scallop", "lanh"]

const EYE_STYLES := ["classic", "round", "sparkle", "calm", "cat", "puppy", "smiley", "cool", "lashes", "sleepy", "elder",
	"button", "dot", "innocent", "cheery", "dreamy", "sharp", "gentle", "glossy", "sly", "lowerlash",
	"monolid", "crease", "aegyo", "tired", "winged", "wide", "ringed", "tearmole"]

static func load_saved() -> Dictionary:
	if FileAccess.file_exists("user://look.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("user://look.json"))
		if d is Dictionary:
			return from(d)
	return DEFAULT.duplicate(true)

static func from(d: Dictionary) -> Dictionary:
	"""A look from a save or from another player: missing keys get defaults, an unknown hairstyle (one no
	longer shipped, or one only a newer build has) falls back to the default."""
	var l := DEFAULT.duplicate(true)
	l.merge(d, true)
	if not shapes("hair").has(str(l.get("hair", ""))):
		l["hair"] = DEFAULT["hair"]
	return l

static func with_value(base: Dictionary, key: String, value) -> Dictionary:
	var l := base.duplicate(true)
	var path := key.split(".")
	if path.size() == 2:
		var d: Dictionary = l.get(path[0], {}).duplicate()
		d[path[1]] = value
		if path[1] == "design" and DESIGNS.has(value):

			var spec: Array = DESIGNS[value]
			if not (spec[0] as Array).has(str(d.get("shape", ""))):
				d["shape"] = spec[0][0]
			d["color"] = spec[1][0]
			d["color_b"] = spec[1][1]
			d["color_c"] = spec[1][2]
			d["trim"] = spec[1][1]
			d["pattern"] = "plain"
			if spec[1].size() > 3:
				d["stitch"] = spec[1][3]
			else:
				d.erase("stitch")
		elif path[1] == "shape" and SHAPE_COLORS.has(value):
			d["color"] = SHAPE_COLORS[value][0]
			d["trim"] = SHAPE_COLORS[value][1]
			d["design"] = ""
			d["pattern"] = "plain"
		elif path[0] == "acc" and path[1] == "shape" and ACC_COLORS.has(value):
			d["color"] = ACC_COLORS[value][0]
			d["trim"] = ACC_COLORS[value][1]
		elif path[0] == "hat" and path[1] == "shape" and HAT_COLORS.has(value):
			var hc: Array = HAT_COLORS[value]
			d["color"] = hc[0]
			d["trim"] = hc[1]
			d["color_c"] = hc[2]
		elif path[1] == "pattern":
			d["design"] = ""
		l[path[0]] = d
	else:
		l[key] = value
	return l

static func option_name(value: String) -> String:
	var key := "LOOK_" + (value if value != "" else "none").to_upper()
	var s := TranslationServer.translate(key)
	return value if s == key else s

static func save(look: Dictionary) -> void:
	var f := FileAccess.open("user://look.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(look, "\t"))

static func shapes(folder: String) -> Array:
	var out := []

	for f in ResourceLoader.list_directory("res://characters/" + folder):
		if f.ends_with(".glb"):
			out.append(f.get_basename())
	out.sort()
	return out
