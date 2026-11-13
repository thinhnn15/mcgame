class_name Clock
extends RefCounted

const FILE := "user://save/clock.json"
const CALENDAR := "res://data/hometown/calendar.json"
const DAWN := 6.0 * 60.0
const DUSK := 22.0 * 60.0

const RAIN_ALL_DAY := true
const NOD_OFF := 23.0 * 60.0

static var minute := DAWN
static var day := 1
static var lunar_now: Array = [5, 16]
static var speed := 1.0
static var paused := false
static var weather := ""
static var cal := {}
static var _loaded := false

static func forget() -> void:
	minute = DAWN
	day = 1
	lunar_now = [5, 16]
	weather = ""
	paused = false
	_loaded = false

static func load_saved() -> void:
	if _loaded:
		return
	_loaded = true
	cal = JSON.parse_string(FileAccess.get_file_as_string(CALENDAR))
	Story.load_saved()
	day = maxi(1, Story.day)
	var d = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
	if d is Dictionary and int(d.get("day", -1)) == day:
		minute = float(d.get("minute", DAWN))
		lunar_now = Array(d.get("lunar", today().get("lunar", [5, 16])))
		weather = str(d.get("weather", ""))
	else:
		_start_day()
	if Stage.arg("--day") != "":
		day = maxi(1, int(Stage.arg("--day")))
		_start_day()
	if Stage.arg("--hour") != "":
		minute = float(Stage.arg("--hour")) * 60.0
	if Stage.arg("--clock-speed") != "":
		speed = float(Stage.arg("--clock-speed"))

static func save() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FILE.get_base_dir()))
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "day": day, "minute": minute, "lunar": lunar_now, "weather": weather}, "\t"))
	Story.day = day
	Story.chapter = "que_%d" % chapter()
	Story.save()

static func tick(delta: float) -> void:
	if not paused:
		minute += delta * speed

static func hour() -> float:
	return minute / 60.0

static func hhmm(m := -1.0) -> String:
	var t := minute if m < 0.0 else m
	return "%02d:%02d" % [int(t / 60.0), int(fmod(t, 60.0))]

static func parse(s: String) -> float:
	"""'16:30' -> minutes since midnight."""
	var p := s.split(":")
	return float(p[0]) * 60.0 + (float(p[1]) if p.size() > 1 else 0.0)

static func story_days() -> int:
	return cal.get("days", []).size()

static func free_day() -> bool:
	return day > story_days()

static func today() -> Dictionary:
	"""The calendar's row for this play day; in free play one made up from the lunar date."""
	var days: Array = cal.get("days", [])
	if day <= days.size():
		return days[day - 1]
	var fr: Dictionary = cal.get("free", {})
	var l := _free_lunar()
	return {"chapter": int(fr.get("chapter", 4)), "lunar": l, "rice": 2, "events": [],
		"market": l[1] in Array(fr.get("market_days", []))}

static func lunar() -> Array:
	"""Today's lunar date. Read before anything loaded the clock (the hometown without --events, a still), it
	loads the saved one first, so the sky's moon phase is the save's date and not the default full moon."""
	if not _loaded:
		load_saved()
	return lunar_now

static func chapter() -> int:
	return int(today().get("chapter", 1))

static func market() -> bool:
	return bool(today().get("market", false))

static func shower() -> Array:
	"""Today's summer shower as [start, end] in minutes, or [] (spec 5.7: short and heavy, often while the sun is out)."""
	var s: Array = today().get("shower", [])
	if s.size() < 2:
		return []
	var a := parse(str(s[0]))
	return [a, a + float(s[1])]

static func raining() -> bool:
	"""Is it raining right now: a wet day ("mua", "giong") or inside today's shower."""
	if weather != "":
		return true
	if RAIN_ALL_DAY:
		return not shower().is_empty()
	var s := shower()
	return not s.is_empty() and minute >= s[0] and minute < s[1]

static func rained_today() -> bool:
	"""Has rain fallen today so far: it waters the plots, the same as the watering can."""
	var s := shower()
	return weather != "" or (not s.is_empty() and (RAIN_ALL_DAY or minute >= s[0]))

static func sleep() -> void:
	"""Off to bed (or nodded off): the next play day at dawn."""
	day += 1
	_start_day()
	save()

static func night_to(l: Array, at := DAWN) -> void:
	"""A night inside one play day (Về làng: tối 16 -> sáng 17): the date moves on, the play day stays."""
	lunar_now = l.duplicate()
	minute = at

static func _start_day() -> void:
	var t := today()
	lunar_now = Array(t.get("lunar", [5, 16])).duplicate()
	weather = str(t.get("weather", ""))
	minute = DAWN

static func _free_lunar() -> Array:
	"""Free play: one lunar day a night after the last story day (30-day months)."""
	var days: Array = cal.get("days", [])
	var last: Array = days[-1].get("ends", days[-1]["lunar"]) if not days.is_empty() else [8, 17]
	var n := int(last[0]) * 30 + int(last[1]) - 1 + (day - days.size())
	return [int(n / 30) % 12 if int(n / 30) % 12 != 0 else 12, n % 30 + 1]
