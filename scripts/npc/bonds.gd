class_name Bonds
extends RefCounted

const FILE := "user://bonds.json"
const STORIES := "res://data/office_stories.json"
const HEART_AT := [0, 12, 30, 52, 78, 100]
const MAX := 120

static var points := {}
static var flags := {}
static var told := {}
static var heard_today := {}
static var data := {}
static var _loaded := false

static func forget() -> void:
	points = {}
	flags = {}
	told = {}
	heard_today = {}
	_loaded = false

static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(STORIES):
		var d = JSON.parse_string(FileAccess.get_file_as_string(STORIES))
		if d is Dictionary:
			data = d
	if FileAccess.file_exists(FILE):
		var s = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if s is Dictionary:
			points = s.get("points", {})
			flags = s.get("flags", {})
			told = s.get("told", {})

static func reset() -> void:
	"""A new game: nobody knows the hero yet."""
	points = {}
	flags = {}
	told = {}
	heard_today = {}
	save()

static func save() -> void:
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"points": points, "flags": flags, "told": told}, "\t"))

static func hearts(id: String) -> int:
	ensure()
	var p := int(points.get(id, 0))
	var h := 0
	for i in HEART_AT.size():
		if p >= HEART_AT[i]:
			h = i
	return h

static func add(id: String, pts: int) -> bool:
	"""Closer (or a little further). True when a new heart was reached."""
	ensure()
	var before := hearts(id)
	points[id] = clampi(int(points.get(id, 0)) + pts, 0, MAX)
	save()
	return hearts(id) > before

static func hearts_text(id: String) -> String:
	var h := hearts(id)
	return "♥".repeat(h) + "♡".repeat(5 - h)

static func next_story(id: String) -> Dictionary:
	"""The next untold story this person is ready to tell (by hearts), or {}. One a visit."""
	ensure()
	if heard_today.get(id, false):
		return {}
	var person: Dictionary = data.get("people", {}).get(id, {})
	for s in person.get("stories", []):
		if told.has(s["id"]):
			continue
		return s if hearts(id) >= int(s.get("hearts", 0)) else {}
	return {}

static func remembered_line(id: String) -> Dictionary:
	"""A greeting that recalls something the player chose (for a flag that is set), or {}."""
	ensure()
	var person: Dictionary = data.get("people", {}).get(id, {})
	var lines: Array = person.get("remember", []).filter(func(r): return flags.has(r.get("flag", "")))
	return lines.pick_random() if not lines.is_empty() else {}

static func text(t, speaker: String) -> String:
	"""A {vi, en, ...} text in the current language, with {name} and the vi form of address {xh}."""
	if not (t is Dictionary):
		return str(t)
	var s := str(t.get(Lang.current, t.get("en", "")))
	Hero.load_saved()
	var addr: Dictionary = data.get("address", {}).get(speaker, {})
	if Hero.name == "":
		s = s.replace("{name} 씨", "{name}").replace("{name}先輩", "{name}")

	var xh: String = Hero.name if Hero.name != "" else "bạn"
	return s.replace("{name}", Hero.called()).replace("{xh}", str(addr.get(Hero.gender, xh)))
