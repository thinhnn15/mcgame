class_name Hero
extends RefCounted

const FILE := "user://hero.json"
const DEFAULT_NAMES := {"m": "Minh", "f": "Lan"}

const START_LOOKS := {
	"m": {"hair": "short", "hair_color": "#2e2320", "eye_style": "classic", "eye_color": "#4a3328", "skin": "#ffd9bd",
		"blush": 0.2,
		"top": {"shape": "longsleeve", "design": "office", "color": "#ffffff", "color_b": "#5d7fc0", "color_c": "#3f5f9e",
			"pattern": "plain", "trim": "#e8eef8"},
		"bottom": {"shape": "pants", "color": "#4a5568", "color_b": "#ffffff", "pattern": "plain", "trim": "#3a4252"},
		"shoes": {"shape": "sneakers", "color": "#ffffff", "color_b": "#ffffff", "pattern": "plain", "trim": "#4a5568"}},
	"f": {},
}

const NEUTRAL_LOOK := {"hair": "messy", "hair_color": "#2e2320",
	"top": {"shape": "longsleeve", "design": "office", "color": "#d9dbe0", "color_b": "#5a5f6e", "color_c": "#474b57",
		"pattern": "plain", "trim": "#c9ccd3"},
	"bottom": {"shape": "pants", "color": "#3a4252", "color_b": "#ffffff", "pattern": "plain", "trim": "#2e3542"},
	"shoes": {"shape": "sneakers", "color": "#2b2b30", "color_b": "#2b2b30", "pattern": "plain", "trim": "#1e1e22"}}
static var name := ""
static var gender := ""
static var job := "dev"
static var _loaded := false
static var new_game := false

static func forget() -> void:
	name = ""
	gender = ""
	job = "dev"
	new_game = false
	_loaded = false

static func load_saved() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(FILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if d is Dictionary:
			name = str(d.get("name", name)).strip_edges().left(16)
			gender = str(d.get("gender", "")) if str(d.get("gender", "")) in ["m", "f"] else ""
			job = "design" if str(d.get("job", job)) == "design" else "dev"

static func save() -> void:
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"name": name, "gender": gender, "job": job}, "\t"))

static func exists() -> bool:
	return FileAccess.file_exists(FILE)

static func called() -> String:
	"""What the hero is called in a line of dialogue: the name, or before the hospital form a neutral word."""
	return name if name != "" else Lang.t("HERO_CALLED")

static func start_look(g := "") -> Dictionary:
	"""The look a new hero starts from: the one neutral office look (docs/opening_spec.md section 7), or the
	old per-gender ones for the creator's Profile tab."""
	var l := Looks.DEFAULT.duplicate(true)
	if g == "":
		l.merge(NEUTRAL_LOOK, true)
	elif g == "f":
		var chars = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
		l.merge(chars["lan"]["look"], true)
	else:
		l.merge(START_LOOKS["m"], true)
	return l
