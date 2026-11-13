class_name Story
extends RefCounted

const FILE := "user://save/story.json"
const BEATS := ["prologue", "look", "bridge", "night", "job", "work", "monday", "reflection", "done"]
const SCENES := {"prologue": "res://scenes/opening.tscn", "look": "res://scenes/creator.tscn",
	"bridge": "res://scenes/opening.tscn", "night": "res://scenes/office_intro.tscn",
	"job": "res://scenes/office_intro.tscn", "work": "res://scenes/office_intro.tscn", "monday": "res://scenes/office.tscn",
	"reflection": "res://scenes/office.tscn", "done": "res://scenes/office.tscn"}

static var beat := "prologue"
static var opening_done := false
static var unlocked: Array = []
static var colors: Array = []
static var birthday := ""
static var chapter := "office"
static var day := 1

static var flags := {}
static var _loaded := false

static func exists() -> bool:
	return FileAccess.file_exists(FILE)

static func forget() -> void:
	beat = "prologue"
	opening_done = false
	unlocked = []
	colors = []
	birthday = ""
	chapter = "office"
	day = 1
	flags = {}
	_loaded = false

static func load_saved() -> void:
	if _loaded:
		return
	_loaded = true
	Hero.load_saved()
	if not exists():
		if Hero.exists():
			beat = "done"
			opening_done = true
			unlocked = ["all"]
			save()
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if not (d is Dictionary):
		return
	beat = str(d.get("beat", beat)) if str(d.get("beat", beat)) in BEATS else "prologue"
	opening_done = bool(d.get("opening_done", false))
	unlocked = Array(d.get("unlocked", []))
	colors = Array(d.get("colors", []))
	birthday = str(d.get("birthday", ""))
	chapter = str(d.get("chapter", chapter))
	day = int(d.get("day", day))
	flags = d.get("flags", {}) if d.get("flags", {}) is Dictionary else {}

	if Hero.job == "" and str(d.get("job", "")) != "":
		Hero.job = str(d["job"])

static func save() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FILE.get_base_dir()))
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "opening_done": opening_done, "beat": beat, "job": Hero.job,
		"name": Hero.name, "birthday": birthday, "unlocked": unlocked, "colors": colors, "chapter": chapter,
		"day": day, "flags": flags}, "\t"))

static func new_story() -> void:
	"""Start the story over (settings: "Bắt đầu câu chuyện mới"; --new-story in tests). The look goes back
	to the neutral one and nobody at the office knows the hero."""
	_loaded = true
	beat = "prologue"
	opening_done = false
	unlocked = []
	colors = []
	birthday = ""
	chapter = "office"
	day = 1
	flags = {}
	Hero.name = ""
	Hero.gender = ""
	Hero.job = "dev"
	Hero.save()
	Looks.save(Hero.start_look())
	Bonds.reset()
	save()

static func set_beat(b: String) -> void:
	beat = b
	if b == "done":
		opening_done = true
	save()

static func reached(b: String) -> bool:
	"""Has the story got to beat b (or past it)?"""
	return BEATS.find(beat) >= BEATS.find(b)

static func unlock(what: String) -> void:
	if not what in unlocked:
		unlocked.append(what)
		save()

static func set_flag(key: String, value) -> void:
	flags[key] = value
	save()

static func flag(key: String, default = null):
	return flags.get(key, default)

static func is_unlocked(what: String) -> bool:
	return "all" in unlocked or what in unlocked

static func scene() -> String:
	"""The scene a player in the middle of the opening comes back to."""
	return SCENES.get(beat, SCENES["done"])
