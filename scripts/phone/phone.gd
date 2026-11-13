class_name Phone
extends Node

const CONTACTS := "res://data/phone/contacts.json"
const CALLS := "res://data/phone/calls.json"
const LAYOUT := "res://data/hometown/layout.json"
const PORTRAITS := "res://characters/portraits/"
const FILE := "user://save/phone.json"
const PER_DAY := 2
const GAP := 180.0
const QUIET_FROM := 21.0 * 60.0
const QUIET_TO := 7.0 * 60.0
const CHANCE := 1.0 / 45.0
const RING_SECS := 12.0
const ANSWER_SECS := 12.0
const WALK_PACE := 0.7
const RAIN_SOON := 60.0
const HERO_COLOR := Color("f08aa6")

static var contacts := {}
static var order: Array = []
static var calls := {}
static var day := -1
static var rang_today := 0
static var last_ring := -10000.0
static var done_today: Array = []
static var last_day := {}
static var missed: Array = []
static var history: Array = []
static var hidden: Array = []
static var on_line := false
static var _loaded := false

var map: Node3D
var player: Player
var hud: CallHud
var auto := false
var state := ""
var places := {}
var _events: Node
var _checked := -1
var _own_day := 0
var _last_min := -1.0
var _call := {}
var _ring_t := 0.0
var _ring_snd = null
var _call_t := 0.0
var _pace := 1.0
var _tool := ""
var _force := ""
var _shots := ""
var _shot_t := 0.0
var _shot_n := 0

static func add(parent: Node3D, hero: Player) -> Phone:
	var args := OS.get_cmdline_user_args()
	if not (args.has("--phone") or Stage.arg("--phone-call") != ""):
		return null
	var p := Phone.new()
	p.name = "Phone"
	p.map = parent
	p.player = hero
	parent.add_child(p)
	return p

static func forget() -> void:
	day = -1
	rang_today = 0
	last_ring = -10000.0
	done_today = []
	last_day = {}
	missed = []
	history = []
	hidden = []
	on_line = false
	_loaded = false

static func load_saved() -> void:
	if _loaded:
		return
	_loaded = true
	var c = JSON.parse_string(FileAccess.get_file_as_string(CONTACTS))
	contacts = c.get("contacts", {}) if c is Dictionary else {}
	order = contacts.keys()
	var k = JSON.parse_string(FileAccess.get_file_as_string(CALLS))
	calls.clear()
	for call in (k.get("calls", []) if k is Dictionary else []):
		calls[call["id"]] = call
	var d = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
	if d is Dictionary:
		day = int(d.get("day", -1))
		rang_today = int(d.get("rang_today", 0))
		last_ring = float(d.get("last_ring", -10000.0))
		done_today = Array(d.get("done_today", []))
		last_day = d.get("last_day", {})
		missed = Array(d.get("missed", []))
		history = Array(d.get("history", []))
		hidden = Array(d.get("hidden", []))

static func save() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FILE.get_base_dir()))
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "day": day, "rang_today": rang_today, "last_ring": last_ring,
		"done_today": done_today, "last_day": last_day, "missed": missed, "history": history.slice(-50),
		"hidden": hidden}, "\t"))

static func boxed() -> bool:
	"""The phone is in grandma's cookie box (spec 6.2): only the family gets through."""
	return Story.flag("phone_boxed", false) == true

func _ready() -> void:
	load_saved()
	Clock.load_saved()
	auto = OS.get_cmdline_user_args().has("--phone-auto")
	_force = Stage.arg("--phone-call")
	_shots = Stage.arg("--phone-shots")
	if _shots != "":
		DirAccess.make_dir_recursive_absolute(_shots)
		if map.get("cam_dist") != null:
			map.set("cam_dist", 6.0)
	var lay = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	for p in (lay.get("places", []) if lay is Dictionary else []):
		places[str(p["id"])] = Vector2(float(p["x"]), float(p["z"]))
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	hud = CallHud.new()
	hud.auto = auto
	layer.add_child(hud)
	hud.answer_pressed.connect(answer)
	hud.later_pressed.connect(later)
	hud.hide_toggled.connect(_toggle_hidden)
	if OS.get_cmdline_user_args().has("--phone-contacts"):
		_show_contacts.call_deferred()
	TouchControls.add_action(self, func() -> Dictionary:
		return {"label": tr("PHONE_ANSWER"), "run": answer} if state == "ring" else {}, 60)

func _exit_tree() -> void:
	if state == "ring" and _ring_snd != null:
		Sound.stop(_ring_snd)
	on_line = false
	save()

func now() -> float:
	return Clock.minute if _events != null else VillageLife.minute

func play_day() -> int:
	return Clock.day if _events != null else Clock.day + _own_day

func raining() -> bool:
	return Clock.raining() if _events != null else VillageLife.raining()

func rain_soon() -> bool:
	if raining():
		return true
	if _events == null:
		return false
	var s := Clock.shower()
	return not s.is_empty() and now() >= s[0] - RAIN_SOON and now() < s[1]

func _process(delta: float) -> void:
	if _events == null:
		_events = map.get_node_or_null("HomeEvents")
	var m := now()
	if _events == null and _last_min >= 0.0 and m < _last_min - 600.0:
		_own_day += 1
	_last_min = m
	if _shots != "" and state != "":
		_shot_t += delta
		if _shot_t >= 0.5:
			_shot_t = 0.0
			_shot_n += 1
			get_viewport().get_texture().get_image().save_png(_shots.path_join("ph_%03d.png" % _shot_n))
	if play_day() != day:
		day = play_day()
		rang_today = 0
		done_today.clear()
		last_ring = -10000.0
		save()
	if state == "ring":
		_ring_t += delta
		if _ring_t >= RING_SECS:
			_not_taken("missed")
		return
	if state == "call":
		_call_t += delta
		hud.set_timer(_call_t)
		return
	if int(m) == _checked:
		return
	_checked = int(m)
	if _force != "" and calls.has(_force):
		var f := _force
		_force = ""
		ring(f)
		return
	if busy():
		return
	var story := []
	var pool := []
	for id in calls:
		if can_ring(id):
			(story if calls[id].get("kind", "") == "story" else pool).append(id)
	if not story.is_empty():
		ring(story[0])
		return
	if pool.is_empty() or rang_today >= PER_DAY or m - last_ring < GAP or randf() >= CHANCE:
		return
	var total := 0.0
	for id in pool:
		total += float(calls[id].get("weight", 1))
	var r := randf() * total
	for id in pool:
		r -= float(calls[id].get("weight", 1))
		if r <= 0.0:
			ring(id)
			return

func busy() -> bool:
	"""Not now: an event or a family member coming to fetch, rowing, the bus, in the water, a tool swinging,
	the controls taken (a menu, a cut-scene), someone visiting the village."""
	if _events != null and (str(_events.get("running")) != "" or _events.get("_fetching") == true):
		return true
	var bus = map.get("bus_s_dir")
	var boat = map.get("boat_dir")
	if BoatRow.busy(map) or map.get("_bus_busy") == true or (bus != null and int(bus) != 0) or (boat != null and int(boat) != 0):
		return true
	return not player.controls or player.water != 0 or player.dive != "" or player.busy() or Net.online()

func can_ring(id: String) -> bool:
	var c: Dictionary = calls[id]
	var who := str(c.get("from", ""))
	var p: Dictionary = contacts.get(who, {})
	if p.is_empty() or p.get("has", "start") == "none" or who in hidden or id in done_today:
		return false
	var story: bool = c.get("kind", "") == "story"
	if boxed() and not story and not p.get("family", false):
		return false
	if not story and int(last_day.get(id, -999)) + int(c.get("cooldown_days", 2)) > day:
		return false
	var m := now()
	if not story and (m >= QUIET_FROM or m < QUIET_TO):
		return false
	var w: Dictionary = c.get("when", {})
	var hours: Array = w.get("hours", [])
	if hours.size() == 2 and (m < Clock.parse(str(hours[0])) or m >= Clock.parse(str(hours[1]))):
		return false
	if w.has("chapter") and not Clock.chapter() in Array(w["chapter"]):
		return false
	match str(w.get("weather", "")):
		"rain_soon":
			if not rain_soon():
				return false
		"dry":
			if rain_soon():
				return false
	var far: Dictionary = w.get("far_from", {})
	if not far.is_empty() and places.has(str(far.get("place", ""))):
		var at: Vector2 = places[str(far["place"])]
		if Vector2(player.global_position.x, player.global_position.z).distance_to(at) <= float(far.get("r", 40)):
			return false
	return true

func ring(id: String) -> void:
	_call = calls[id]
	state = "ring"
	on_line = true
	_ring_t = 0.0
	if _call.get("kind", "") != "story":
		rang_today += 1
		last_ring = now()
	done_today.append(id)
	last_day[id] = day
	save()
	_ring_snd = Sound.play("phone.ring")
	var who := str(_call["from"])
	hud.show_ring(name_of(who), color_of(who), face_of(who))
	if auto:
		get_tree().create_timer(2.0).timeout.connect(answer)

func answer() -> void:
	if state != "ring":
		return
	Sound.stop(_ring_snd, 0.1)
	state = "call"
	_call_t = 0.0
	var who := str(_call["from"])
	_log(who, "answered")
	_hold_phone(true)
	hud.show_call()
	await _steps(Array(_call.get("steps", [])), who)
	_hold_phone(false)
	hud.hide_call()
	state = ""
	on_line = false
	_quit_after()

func later() -> void:
	if state == "ring":
		_not_taken("later")

func _not_taken(how: String) -> void:
	Sound.stop(_ring_snd, 0.2)
	var who := str(_call["from"])
	missed.append({"who": who, "call": _call["id"], "day": day, "at": Clock.hhmm(now())})
	_log(who, how)
	save()
	hud.hide_call()
	hud.toast(Lang.t("PHONE_MISSED", {"name": name_of(who)}))
	state = ""
	on_line = false
	_quit_after()

func _quit_after() -> void:
	if OS.get_cmdline_user_args().has("--phone-quit"):
		await get_tree().create_timer(2.0).timeout
		get_tree().quit()

func _steps(steps: Array, who: String) -> void:
	for s in steps:
		if not is_inside_tree():
			return
		if s.has("say"):
			await hud.line(name_of(who), color_of(who), text(s["say"]))
		elif s.has("choice"):
			var opts: Array = s["choice"]
			var texts := []
			var def := 0
			for i in opts.size():
				texts.append(text(opts[i]["text"]))
				if str(opts[i]["id"]) == str(s.get("default", "")):
					def = i
			var o: Dictionary = opts[await hud.choose(texts, def, ANSWER_SECS)]
			if o.has("flag"):
				Story.set_flag(str(o["flag"][0]), o["flag"][1])
			await hud.line(Hero.called(), HERO_COLOR, text(o["text"]))
			await _steps(Array(o.get("then", [])), who)
		elif s.get("hangup", false):
			await hud.line("", Color.WHITE, tr("PHONE_HUNG_UP"))
			return

func _hold_phone(on: bool) -> void:
	"""On a call: the phone to the head (PhoneEar), the tool out of the hand, slower steps; and back after."""
	var c := player.chibi
	if on:
		_tool = c.tool
		if _tool != "":
			c.hold("")
		_pace = player.pace
		player.pace = _pace * WALK_PACE
	else:
		player.pace = _pace
		if _tool != "" and c.tool == "":
			get_tree().create_timer(0.35).timeout.connect(func() -> void:
				if c.tool == "" and state == "":
					c.hold(_tool))
	var ear := PhoneEar.on(c)
	if ear:
		ear.on_call = on

func _log(who: String, how: String) -> void:
	history.append({"who": who, "call": _call.get("id", ""), "day": day, "at": Clock.hhmm(now()), "how": how})

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.physical_keycode:
		KEY_T:
			if state == "ring":
				answer()
			elif state == "call":
				hud.skip()
		KEY_X:
			later()
		KEY_TAB:
			if hud.contacts_open():
				hud.hide_contacts()
			else:
				_show_contacts()
		KEY_ESCAPE:
			if hud.contacts_open():
				hud.hide_contacts()
				get_viewport().set_input_as_handled()

func _show_contacts() -> void:
	var rows := []
	for id in order:
		var p: Dictionary = contacts[id]
		var n := 0
		for m in missed:
			if m["who"] == id and int(m["day"]) == day:
				n += 1
		var rel := tr(str(p.get("rel", "")))
		if rel == name_of(id):
			rel = tr("PHONE_FAMILY")
		rows.append({"id": id, "name": name_of(id), "rel": rel, "color": p.get("color", "#d07a8a"),
			"note": tr(str(p.get("note", ""))), "missed": n, "hideable": p.get("hideable", false),
			"hidden": id in hidden, "none": p.get("has", "start") == "none", "face": face_of(id)})
	hud.show_contacts(rows)

func _toggle_hidden(id: String) -> void:
	if id in hidden:
		hidden.erase(id)
	else:
		hidden.append(id)
	save()
	_show_contacts()

func name_of(who: String) -> String:
	var n = contacts.get(who, {}).get("name", who)
	return text(n) if n is Dictionary else tr(str(n))

func face_of(who: String) -> Texture2D:
	"""Their baked portrait (scripts/phone/portrait_bake.gd), or null: the circle with the initial."""
	var path := PORTRAITS + who + ".png"
	return load(path) if ResourceLoader.exists(path) else null

func color_of(who: String) -> Color:
	return Color(str(contacts.get(who, {}).get("color", "#d07a8a")))

func text(d) -> String:
	"""A line written in the five languages, in the player's (English, then Vietnamese, if it has none)."""
	if d is String:
		return tr(d)
	var t := str(d.get(Lang.current, d.get("en", d.get("vi", ""))))
	return t.replace("{name}", Hero.called())
