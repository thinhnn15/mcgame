class_name HomeEvents
extends Node3D

signal _pressed
var _press_near: Callable

const DIR := "res://data/events/"
const CAST := "res://data/hometown/cast.json"
const LAYOUT := "res://data/hometown/layout.json"
const FILE := "user://save/events.json"
const WALK_SPEED := 0.78
const FOLLOW_GAP := 1.6
const STEPS := ["say", "narr", "toast", "cast", "leave", "walk", "go", "pick", "spots", "press", "emote", "face",
	"anim", "sit", "cam", "wait", "fade", "time", "night", "weather", "flag", "give", "mini", "if", "sound",
	"teleport", "hold"]

static var done: Array = []
static var choices := {}
static var carry: Array = []
static var resume := {}
static var seen_spots := {}
static var repeats := {}
static var dry := false
static var trace: Array = []
static var minigames := {}
static var _loaded := false

var map: Node3D
var ground: Callable
var player: Player
var cam: Camera3D
var events := {}
var cast := {}
var places := {}
var actors := {}
var running := ""
var auto := false
var box: TalkBox
var _layer: CanvasLayer
var _hint: Label
var _toast: Label
var _toast_t := 0.0
var _black: ColorRect
var _markers: Array[Label3D] = []
var _followers: Array = []
var _reminded := {}
var _fetching := false
var _free := false
var _checked := -1
var _shots := ""
var _shot_every := 2.5
var _shot_t := 0.0
var _shot_n := 0

static func add(parent: Node3D, ground_at: Callable, hero: Player) -> HomeEvents:
	var args := OS.get_cmdline_user_args()
	if not (args.has("--events") or Stage.arg("--event") != ""):
		return null
	var e := HomeEvents.new()
	e.name = "HomeEvents"
	e.add_to_group("home_events")
	e.map = parent
	e.ground = ground_at
	e.player = hero
	parent.add_child(e)
	return e

static func forget() -> void:
	done = []
	choices = {}
	carry = []
	resume = {}
	seen_spots = {}
	repeats = {}
	_loaded = false

static func load_saved() -> void:
	if _loaded:
		return
	_loaded = true
	var d = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else null
	if d is Dictionary:
		done = Array(d.get("done", []))
		choices = d.get("choices", {})
		carry = Array(d.get("carry", []))
		resume = d.get("resume", {})
		seen_spots = d.get("seen_spots", {})
		repeats = d.get("repeats", {})

static func save() -> void:
	if dry:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FILE.get_base_dir()))
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "done": done, "choices": choices, "carry": carry, "resume": resume,
		"seen_spots": seen_spots, "repeats": repeats}, "\t"))

static func load_events() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string(DIR + f))
			if d is Dictionary:
				out[d["id"]] = d
			else:
				push_error("HomeEvents: %s is not valid JSON" % f)
	return out

static func choice(event_id: String, key: String, default = null):
	"""What the player picked in an event (later events and the dinner table read it back)."""
	load_saved()
	return choices.get(event_id + "." + key, default)

func _ready() -> void:
	load_saved()
	Clock.load_saved()
	Progress.load_saved()
	if not dry:
		_home_work_sync()
	events = load_events()
	cast = JSON.parse_string(FileAccess.get_file_as_string(CAST))
	auto = OS.get_cmdline_user_args().has("--events-auto")
	TouchControls.add_action(self, func() -> Dictionary:
		if not _press_near.is_valid() or not _press_near.call():
			return {}
		return {"label": tr("TC_DO"), "run": _pressed.emit}, 50)
	_shots = Stage.arg("--events-shots")
	_shot_every = float(Stage.arg("--shot-every", "2.5"))
	if _shots != "":
		DirAccess.make_dir_recursive_absolute(_shots)
	if not dry:
		_read_places()
		cam = map.get("cam") if map else null
		_build_ui()
		Progress.add_on_open(_opened)
	var one := Stage.arg("--event")
	if one != "" and events.has(one):
		_jump_to(one)
		_run.call_deferred(one, int(Stage.arg("--event-scene", "0")))
	elif not resume.is_empty() and events.has(str(resume.get("id", ""))):
		_run.call_deferred(str(resume["id"]), int(resume.get("scene", 0)))

func _exit_tree() -> void:
	Progress.remove_on_open(_opened)
	if not dry:
		Clock.save()

func _process(delta: float) -> void:
	Clock.tick(delta)
	VillageLife.minute = Clock.minute
	VillageLife.weather = Clock.weather
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.visible = false
	for f in _followers:
		_follow_step(f, delta)
	if _shots != "" and running != "":
		_shot_t += delta
		if _shot_t >= _shot_every:
			_shot_t = 0.0
			_shot_n += 1
			get_viewport().get_texture().get_image().save_png(_shots.path_join("ev_%03d.png" % _shot_n))
	if running != "" or _fetching or Phone.on_line or int(Clock.minute) == _checked:
		return
	_checked = int(Clock.minute)
	if Clock.minute >= Clock.NOD_OFF:
		_sleep(true)
		return
	for id in todays():
		if _due(id):
			_run(id, 0)
			return
		if _fetching:
			return

func todays() -> Array:
	"""Today's events not yet done: the calendar's, yesterday's carried over, and the chapter's any-day ones."""
	var out: Array = []
	for id in Array(Clock.today().get("events", [])) + carry:
		if events.has(id) and not id in done and not id in out:
			out.append(id)
	for id in events:
		if not id in done and not id in out and _any_day_ok(id, events[id].get("when", {})):
			out.append(id)
	return out

func _any_day_ok(id: String, w: Dictionary) -> bool:
	"""An any-day event: its chapter (or chapter_from on), not before from_lunar, after its moments, and with
	lunar_days only on those lunar days, free_slot only once the day's calendar events are done, repeat once a play
	day (calendar.json _doc; events 19 dem_ao_do*, xem_ao_do and 22 hang_mu_t1)."""
	if not w.get("any_day", false):
		return false
	if w.get("repeat", false) and int(repeats.get(id, {}).get("day", -1)) == Clock.day:
		return false
	if w.has("flag_day"):
		var fd := int(Story.flag(str(w["flag_day"]), -1))
		if fd < 0 or fd > Clock.day:
			return false
	if w.has("day_after_flag"):
		if int(Story.flag(str(w["day_after_flag"]), -9)) + 1 != Clock.day:
			return false
	if w.has("flag_is"):
		var fi: Dictionary = w["flag_is"]
		for k in fi:
			if not Array(fi[k]).has(str(Story.flag(str(k), ""))):
				return false
	if w.has("flag_min"):
		var fm: Dictionary = w["flag_min"]
		for k in fm:
			if int(Story.flag(str(k), 0)) < int(fm[k]):
				return false
	if w.has("today_flag"):
		if int(Story.flag(str(w["today_flag"]), -9)) != Clock.day:
			return false
	if w.has("stock_min"):
		if not ClassDB.class_exists("Stock"):
			return false
		var sm: Dictionary = w["stock_min"]
		for k in sm:
			if int(ClassDB.class_call_static("Stock", "count", str(k))) < int(sm[k]):
				return false
	if w.has("lunar_days"):
		var today_l := int(Clock.lunar()[1])
		if not Array(w["lunar_days"]).any(func(x): return int(x) == today_l):
			return false
	if w.has("chapter_from"):
		if Clock.chapter() < int(w["chapter_from"]):
			return false
	elif int(w.get("chapter", 0)) != Clock.chapter():
		return false
	if w.has("from_lunar") and not Clock.free_day():
		var l: Array = Clock.lunar()
		var f: Array = w["from_lunar"]
		if int(l[0]) * 100 + int(l[1]) < int(f[0]) * 100 + int(f[1]):
			return false
	if w.has("after_moments"):
		var have: Array = Progress.moments()
		for m in w["after_moments"]:
			if not m in have:
				return false
	if w.get("free_slot", false):
		for e in Array(Clock.today().get("events", [])) + carry:
			if e != id and events.has(e) and not e in done:
				return false
	return true

func _due(id: String) -> bool:
	var ev: Dictionary = events[id]
	var w: Dictionary = ev.get("when", {})
	var from := Clock.parse(str(w.get("from", "06:00"))) if not id in carry else Clock.parse(str(w.get("carry_from", "06:00")))
	var until := Clock.parse(str(w.get("until", "22:00")))
	var t := Clock.minute
	if t < from:
		return false
	if w.has("start_by") and t > Clock.parse(str(w["start_by"])) and not id in carry:
		return false
	var rem: Dictionary = ev.get("remind", {})
	if not rem.is_empty() and not _reminded.has(id):
		_reminded[id] = true
		toast(_line(str(rem.get("line", "")), str(rem.get("who", ""))), 5.0)
	var st = ev.get("start", "auto")
	if st is String and st == "auto" or id in carry:
		return true
	var where: Array = _where(st.get("place", ""), st)
	if not where.is_empty() and _hero_pos().distance_to(where[0]) < float(st.get("r", 8.0)):
		return true
	_point_at(where)
	var fetch: Dictionary = ev.get("fetch", {})
	if not fetch.is_empty() and t >= from + float(fetch.get("after", 30)):
		_fetch(id, fetch, where)
		return false
	if t >= until and not id in carry and not w.get("any_day", false):
		if not fetch.is_empty():
			_fetch(id, fetch, where)
		else:
			carry.append(id)
			save()
	return false

func _fetch(id: String, fetch: Dictionary, where: Array) -> void:
	"""Late: someone from the family comes to find the hero, says a word, and they go together (a fade)."""
	_fetching = true
	var who := str(fetch.get("who", "me"))
	await _cast_at(who, _near_hero(2.0))
	await _say(who, str(fetch.get("line", "EV_FETCH_" + who.to_upper())), "smile")
	box.close()
	await _fade(1.0, 0.6)
	if not where.is_empty():
		_put_hero(where[0], where[1])
	_drop(who)
	await _fade(0.0, 0.6)
	_fetching = false
	_run(id, 0)

func _sleep(nodded_off: bool) -> void:
	"""The night: Progress counts the day's rest, the clock moves to the next play day."""
	_fetching = true
	if nodded_off:
		toast(tr("EV_NOD_OFF"), 3.0)
	elif Clock.minute < Clock.DUSK:
		Progress.rest("bed_before_22")
	await _fade(1.0, 1.2)
	Clock.sleep()
	Progress.new_day()
	Progress.announce()
	_home_work_sync()
	carry = carry.filter(func(c): return not c in done)
	_reminded = {}
	save()
	await get_tree().create_timer(0.6).timeout
	await _fade(0.0, 1.2)
	toast("%s · %d/%d" % [tr("EV_DAY_CARD") % Clock.day, Clock.lunar()[1], Clock.lunar()[0]], 4.0)
	_fetching = false

static func _home_work_sync() -> void:
	"""The builder's book (C++ HomeWork): a booked job finished the morning after its work day, a missed day moved,
	the story's own house levels taken in. Called by name so a build without the class (iOS before the Mac rebuild)
	still runs."""
	if ClassDB.class_exists("HomeWork"):
		ClassDB.class_call_static("HomeWork", "sync")

func _unhandled_input(e: InputEvent) -> void:
	if dry:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode in [KEY_F, KEY_SPACE, KEY_ENTER]:
			_pressed.emit()
		elif e.physical_keycode == KEY_F9 and running == "" and not _fetching:
			_sleep(false)
	elif e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_A:
		_pressed.emit()

func _run(id: String, from_scene: int) -> void:
	var ev: Dictionary = events[id]
	running = id
	_log("== %s (%s)" % [id, ev.get("status", "")])
	Clock.paused = true
	VillageLife.set_event(str(ev.get("mood_event", id)))
	_hero_controls(false)
	var scenes: Array = ev.get("scenes", [])
	var packs := _packs_in(ev) if not dry else []
	if scenes.is_empty():
		toast(tr("EV_STUB") % tr(str(ev.get("title", id))), 4.0)
		await _wait(2.0)
	for i in range(from_scene, scenes.size()):
		resume = {"id": id, "scene": i}
		save()
		_log("-- scene %s" % scenes[i].get("id", i))
		await _steps(scenes[i].get("steps", []), id)
	_reward(ev.get("rewards", {}))
	if ev.get("when", {}).get("repeat", false):
		var n := int(repeats.get(id, {}).get("n", 0)) + 1
		repeats[id] = {"day": Clock.day, "n": n}
		var at_n: Dictionary = ev.get("count_moments", {})
		if at_n.has(str(n)) and not dry:
			Progress.moment(str(at_n[str(n)]))
	else:
		done.append(id)
	carry.erase(id)
	resume = {}
	save()
	if not dry:
		Clock.save()
	await _wrap_up(ev)
	for p in packs:
		AnimPacks.release(p)
	running = ""
	_log("== %s done" % id)
	if ev.get("then_sleep", false) and not dry:
		await _sleep(false)
	if OS.get_cmdline_user_args().has("--events-quit") and not dry:
		get_tree().quit()

func _packs_in(ev: Dictionary) -> Array:
	"""The clip packs (scripts/anim_packs.gd) this event plays, loaded now so no step hitches: those of its anim
	clips and held tools, its own pack (its id, if it has one), and any it lists ("packs", for its mini-games).
	Returns the ones loaded here, to release when it is over (village/farm stay: VillageLife loaded them)."""
	var want := {str(ev.get("id", "")): true}
	for p in ev.get("packs", []):
		want[str(p)] = true
	var walk := func(steps: Array, me: Callable) -> void:
		for s in steps:
			if s.get("do") == "anim":
				want[AnimPacks.pack_of(str(s["clip"]))] = true
			elif s.get("do") == "hold" and str(s.get("item", "")) != "":
				want[AnimPacks.pack_of("Tool_Grip_" + str(s["item"]))] = true
			for k in ["steps", "then", "else"]:
				me.call(s.get(k, []), me)
			for o in s.get("options", []) + s.get("spots", []):
				me.call(o.get("steps", []), me)
	for sc in ev.get("scenes", []):
		walk.call(sc.get("steps", []), walk)
	var had := AnimPacks.loaded()
	var mine := []
	for p in want:
		if p != "" and not p in had:
			AnimPacks.need(p)
			if p in AnimPacks.loaded():
				mine.append(p)
	return mine

func _wrap_up(ev: Dictionary) -> void:
	if box:
		box.close()
	for who in actors.keys():
		if not who in Array(ev.get("keep", [])):
			_drop(who)
	_followers.clear()
	_clear_markers()
	if map and "fixed_view" in map:
		map.fixed_view = false
	VillageLife.set_event("")
	Clock.paused = false
	_hero_controls(true)
	if not dry:
		await get_tree().process_frame

func _steps(steps: Array, id: String) -> void:
	for s in steps:
		await _step(s, id)

func _step(s: Dictionary, id: String) -> void:
	var what := str(s.get("do", ""))
	if what != "say" and box and box.visible:
		box.close()
	if dry:
		trace.append("%s %s" % [what, JSON.stringify(s).substr(0, 120)])
	match what:
		"say":
			await _say(str(s["who"]), str(s["line"]), str(s.get("face", "")))
		"narr":
			await _narr(str(s["line"]))
		"toast":
			toast(_line(str(s["line"]), str(s.get("who", ""))), float(s.get("secs", 3.0)))
		"cast":
			await _cast_at(str(s["who"]), _where(s.get("at", "hero"), s))
		"leave":
			_drop(str(s["who"]))
		"walk":
			if s.get("wait", true):
				await _walk(str(s["who"]), _where(s["to"], s))
			else:
				_walk(str(s["who"]), _where(s["to"], s))
		"go":
			await _go(s)
		"pick":
			await _pick(s, id)
		"spots":
			await _spots(s, id)
		"press":
			await _press(s)
		"emote":
			var c := _chibi(str(s["who"]))
			if c:
				c.emote(str(s["kind"]))
			await _wait(float(s.get("secs", 0.0)))
		"face":
			var c := _chibi(str(s["who"]))
			if c:
				c._override = Vector2i(int(s.get("eye", -1)), int(s.get("mouth", -1)))
				c._override_until = c._time + float(s.get("secs", 1.5))
			await _wait(float(s.get("hold", 0.0)))
		"anim":
			var c := _chibi(str(s["who"]))
			if c:
				c.play(str(s["clip"]), 0.25)
			await _wait(float(s.get("secs", 0.0)))
		"sit":
			if str(s["who"]) == "hero":
				if not dry:
					player.set_sitting(bool(s.get("on", true)))
			else:
				var c := _chibi(str(s["who"]))
				if c:
					c.play("Act_SitFloor" if s.get("on", true) else "Base_Wait", 0.3)
		"cam":
			await _cam(s)
		"wait":
			await _wait(float(s.get("secs", 1.0)))
		"fade":
			await _fade(float(s.get("to", 1.0)), float(s.get("secs", 0.6)))
		"time":
			Clock.minute = Clock.parse(str(s["set"]))
		"night":
			await _fade(1.0, 1.0)
			Clock.night_to(Array(s["to"]), Clock.parse(str(s.get("at", "06:00"))))
			await _wait(float(s.get("secs", 1.0)))
			await _fade(0.0, 1.0)
		"weather":
			_weather(str(s.get("set", "")))
		"flag":
			if not dry:
				Story.set_flag(str(s["key"]), s["value"])
			if str(s["key"]) == "cong_trang_trai" and map and map.has_method("set_farm_gate"):
				map.set_farm_gate(str(s["value"]))
		"give":
			_reward(s)
		"mini":
			await _mini(s)
		"if":
			var v = choice(id, str(s["choice"])) if s.has("choice") else Story.flag(str(s.get("flag", "")))
			await _steps(s.get("then", []) if str(v) == str(s.get("is")) else s.get("else", []), id)
		"sound":
			var snd := get_node_or_null("/root/Sound")
			if snd and not dry:
				snd.play(str(s["id"]))
		"teleport":
			var at := _where(s["to"], s)
			if not at.is_empty():
				if str(s.get("who", "hero")) == "hero":
					_put_hero(at[0], at[1])
				else:
					await _cast_at(str(s["who"]), at)
		"hold":
			var c := _chibi(str(s["who"]))
			if c:
				c.hold(str(s.get("item", "")))
		_:
			push_warning("HomeEvents %s: unknown step '%s'" % [id, what])

func _reward(r: Dictionary) -> void:
	if dry:
		trace.append("reward " + JSON.stringify(r))
		return
	if r.has("story"):
		var got: Dictionary = Progress.story(r["story"])
		for sk in got:
			toast("+%d %s" % [got[sk], tr(str(Progress.skills()["skills"][sk]["name"]))], 3.0)
	for who in r.get("hearts", {}):
		Progress.friend(who, int(r["hearts"][who]))
	for m in r.get("moments", []):
		Progress.moment(str(m))
	if r.has("moment"):
		Progress.moment(str(r["moment"]))
	for k in r.get("flags", {}):
		Story.set_flag(k, r["flags"][k])
	if r.has("rest"):
		Progress.rest(str(r["rest"]))
	if r.has("take") and ClassDB.class_exists("Stock"):
		ClassDB.class_call_static("Stock", "take", r["take"])

func _opened(row: Dictionary) -> void:
	toast(tr("EV_OPENED") % str(row.get("vi", row["id"])).get_slice(" (", 0), 4.0)

func _go(s: Dictionary) -> void:
	"""Walk somewhere (a marker over it, a line in the corner); `with`: people who walk along."""
	var at := _where(s["to"], s)
	if dry or at.is_empty():
		return
	for who in s.get("with", []):
		if actors.has(who):
			_followers.append(who)
	_point_at(at, str(s.get("hint", "")))
	await _free_until(func(): return _hero_pos().distance_to(at[0]) < float(s.get("r", 3.0)))
	_followers.clear()
	_clear_markers()

func _pick(s: Dictionary, id: String) -> void:
	"""A choice made in the world: walk up to one of them (the scripts' "chọn đi với ai")."""
	var opts: Array = s["options"]
	var got := 0
	if not dry:
		var ats := []
		for o in opts:
			var a := _where(o["at"], o)
			ats.append(a)
			_marker(a, str(o.get("hint", "")))
		_hint_text(str(s.get("hint", "")))
		await _free_until(func():
			for i in ats.size():
				if not ats[i].is_empty() and _hero_pos().distance_to(ats[i][0]) < float(opts[i].get("r", 2.0)):
					got = i
					return true
			return false)
		_clear_markers()
	choices[id + "." + str(s["key"])] = opts[got].get("set", got)
	save()
	await _steps(opts[got].get("steps", []), id)

func _spots(s: Dictionary, id: String) -> void:
	"""Looking round freely: each spot plays its little scene the first time the hero gets there; it ends after
	`count` spots or `minutes` of game time, whichever comes first (the clock runs meanwhile)."""
	var list: Array = s["spots"]
	var need := int(s.get("count", list.size()))
	var end := Clock.minute + float(s.get("minutes", 60.0))
	var hit := 0
	if dry:
		for sp in list:
			await _steps(sp.get("steps", []), id)
		return
	_hint_text(str(s.get("hint", "")))
	Clock.paused = false
	var idle := 0.0
	while hit < need and Clock.minute < end:
		_hero_controls(true)
		await get_tree().process_frame
		idle += get_process_delta_time()
		if auto and idle > 1.5:
			idle = 0.0
			for sp in list:
				if not seen_spots.has(id + "." + str(sp["id"])):
					var a := _where(sp["at"], sp)
					if not a.is_empty():
						_put_hero(a[0], player.rotation.y)
					break
		for sp in list:
			var key := id + "." + str(sp["id"])
			if seen_spots.has(key):
				continue
			var at := _where(sp["at"], sp)
			if not at.is_empty() and _hero_pos().distance_to(at[0]) < float(sp.get("r", 2.0)):
				seen_spots[key] = true
				hit += 1
				save()
				Clock.paused = true
				_hero_controls(false)
				await _steps(sp.get("steps", []), id)
				if box.visible:
					box.close()
				Clock.paused = false
				break
	Clock.paused = true
	_hint_text("")
	_hero_controls(false)

func _press(s: Dictionary) -> void:
	var at := _where(s.get("at", "hero"), s)
	if dry:
		return
	_point_at(at, str(s.get("hint", "EV_HINT_PRESS")))
	var r := float(s.get("r", 2.0))
	var near := func(): return at.is_empty() or _hero_pos().distance_to(at[0]) < r
	_hero_controls(true)
	while true:
		if auto:
			if not at.is_empty() and not near.call():
				_put_hero(at[0] + Vector3(0.7, 0, 0.4), player.rotation.y)
			await _wait(0.8)
			break
		_press_near = near
		await _pressed
		if near.call():
			break
	_press_near = Callable()
	_hero_controls(false)
	_clear_markers()

func _free_until(cond: Callable) -> void:
	_hero_controls(true)
	if map and "fixed_view" in map:
		map.fixed_view = false
	var t := 0.0
	while not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		if auto and t > 1.0:
			for a in _markers:
				_put_hero(a.global_position - Vector3(0, 2.2, 0), player.rotation.y)
				break
	_hero_controls(false)
	_hint_text("")

func _mini(s: Dictionary) -> void:
	var id := str(s["id"])
	if minigames.has(id) and not dry:
		await (minigames[id] as Callable).call(self, s)
	else:
		toast(tr("EV_MINI_TODO") % tr(str(s.get("title", id))), 3.0)
		await _wait(2.5)

func _line(key: String, who := "") -> String:
	if dry:
		return key
	var t := tr(key)
	t = t.replace("{name}", Hero.called())
	return ("%s: %s" % [tr(str(cast["people"][who]["name"])), t]) if who != "" and cast["people"].has(who) else t

func _say(who: String, key: String, face: String) -> void:
	if dry:
		return
	var p: Dictionary = cast["people"].get(who, {})
	var c := _chibi(who)
	if c and who != "hero":
		box.set_speaker(c)
		var d := player.global_position - c.global_position
		c.rotation.y = atan2(d.x, d.z)
	await box.say(tr(str(p.get("name", who))), tr(key).replace("{name}", Hero.called()),
		Color(str(p.get("color", "#d07a8a"))), TalkBox.FACES.get(face, {}))

func _narr(key: String) -> void:
	if dry:
		return
	await get_node("/root/Narrator").say_text(tr(key).replace("{name}", Hero.called()))

func toast(text: String, secs := 3.0) -> void:
	if dry or text == "":
		return
	_toast.text = text
	_toast.visible = true
	_toast_t = secs

func _hint_text(key: String) -> void:
	if dry:
		return
	_hint.text = tr(key) if key != "" else ""
	_hint.visible = key != ""

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_black = ColorRect.new()
	_black.color = Color(0.06, 0.05, 0.08, 0.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)
	box = TalkBox.new()
	if auto:
		TalkBox.auto_secs = 1.2
	_layer.add_child(box)
	box.close()
	for i in 2:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_color_override("font_color", Color("fffaf2"))
		l.add_theme_color_override("font_outline_color", Color("5b4a44"))
		l.add_theme_constant_override("outline_size", 10)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_CENTER_TOP)
		l.position = Vector2(-600, 110 + i * 56)
		l.size = Vector2(1200, 50)
		l.visible = false
		_layer.add_child(l)
		if i == 0:
			_hint = l
		else:
			_toast = l

func _fade(to: float, secs: float) -> void:
	if dry:
		return
	var tw := create_tween()
	tw.tween_property(_black, "color:a", to, secs)
	await tw.finished

func _wait(secs: float) -> void:
	if dry or secs <= 0.0:
		return
	await get_tree().create_timer(secs).timeout

func _log(t: String) -> void:
	if dry:
		trace.append(t)
	elif OS.get_cmdline_user_args().has("--events-log"):
		print("[events %s] %s" % [Clock.hhmm(), t])

func _read_places() -> void:
	var lay = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	for p in lay.get("places", []):
		var x := float(p["x"])
		var z := float(p["z"])
		places[p["id"]] = [Vector3(x, ground.call(x, z), z), deg_to_rad(float(p.get("yaw", 0)))]

func _where(at, s := {}) -> Array:
	"""[position, yaw] of: a place id ("nha_bo_me"), "hero", "@who" (someone on the map), or [x, z]; moved by
	s.off = [x, z] metres in that thing's own frame (as the yard files: the house at the origin, its front +z),
	turned by s.yaw degrees."""
	if dry:
		return [Vector3.ZERO, 0.0]
	var base := []
	if at is Array:
		base = [Vector3(at[0], ground.call(at[0], at[1]), at[1]), 0.0]
	elif str(at) == "hero":
		base = [player.global_position, player.rotation.y]
	elif str(at).begins_with("@"):
		var c := _chibi(str(at).substr(1))
		base = [c.global_position, c.rotation.y] if c else []
	elif places.has(str(at)):
		base = places[str(at)]
	if base.is_empty():
		push_warning("HomeEvents: no place '%s'" % str(at))
		return []
	var p: Vector3 = base[0]
	var yaw: float = base[1]
	var off: Array = s.get("off", [])
	if off.size() == 2:
		p += Basis(Vector3.UP, yaw) * Vector3(float(off[0]), 0.0, float(off[1]))
		p.y = ground.call(p.x, p.z)
	if s.has("yaw"):
		yaw += deg_to_rad(float(s["yaw"]))
	return [p, yaw]

func _near_hero(d: float) -> Array:
	if dry:
		return [Vector3.ZERO, 0.0]
	var b := Basis(Vector3.UP, player.rotation.y)
	var p := player.global_position + b * Vector3(0.8, 0, d)
	p.y = ground.call(p.x, p.z)
	return [p, player.rotation.y + PI]

func _hero_pos() -> Vector3:
	return player.global_position if player else Vector3.ZERO

func _put_hero(p: Vector3, yaw: float) -> void:
	if dry:
		return
	player.global_position = p + Vector3(0, 0.2, 0)
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO

func _hero_controls(on: bool) -> void:
	_free = on
	if player and not dry:
		player.controls = on
		if not on:
			player.stop_going()

func _chibi(who: String) -> Chibi:
	if dry:
		return null
	if who == "hero":
		return player.chibi
	if actors.has(who):
		return actors[who]
	var v := map.get_node_or_null("VillageLife") if map else null
	if v and v.people.has(who):
		return v.people[who]["chibi"]
	return null

func _cast_at(who: String, at: Array) -> void:
	"""Bring someone on (or move them) at [position, yaw]."""
	if dry or at.is_empty():
		return
	if not actors.has(who):
		var p: Dictionary = cast["people"].get(who, {})
		if p.is_empty():
			push_warning("HomeEvents: nobody called '%s' in cast.json" % who)
			return
		var c := Chibi.new()
		c.name = "Ev_" + who
		map.add_child(c)
		c.build(_look(p["look"]))
		actors[who] = c
		await get_tree().process_frame
	var ch: Chibi = actors[who]
	ch.global_position = at[0]
	ch.rotation.y = at[1]
	ch.play("Base_Wait", 0.0)

func _look(l: Dictionary) -> Dictionary:
	var look := Looks.DEFAULT.duplicate(true)
	for src in [cast["bases"].get(str(l.get("base", "")), {}), l]:
		for k in src:
			if k != "base":
				look[k] = src[k].duplicate(true) if src[k] is Dictionary else src[k]
	return look

func _drop(who: String) -> void:
	if actors.has(who):
		actors[who].queue_free()
		actors.erase(who)

func _walk(who: String, at: Array) -> void:
	"""Straight over the ground to `at`, then turn to its yaw (the hero walks by itself: Player.go_to)."""
	if dry or at.is_empty():
		return
	if who == "hero":
		await player.go_to(at[0], false, 0.3, 30.0)
		return
	var c := _chibi(who)
	if c == null:
		return
	var from := c.global_position
	var d: Vector3 = at[0] - from
	d.y = 0.0
	if d.length() > 0.05:
		c.rotation.y = atan2(d.x, d.z)
		c.play("Move_Walk", 0.2)
		var secs := d.length() / WALK_SPEED
		var t := 0.0
		while t < secs and is_instance_valid(c):
			await get_tree().process_frame
			t += get_process_delta_time()
			var p := from.lerp(at[0], minf(t / secs, 1.0))
			p.y = ground.call(p.x, p.z)
			c.global_position = p
	if is_instance_valid(c):
		var tw := c.create_tween()
		tw.tween_property(c, "rotation:y", c.rotation.y + wrapf(float(at[1]) - c.rotation.y, -PI, PI), 0.35)
		c.play("Base_Wait", 0.2)
		await tw.finished

func _follow_step(who: String, delta: float) -> void:
	var c: Chibi = actors.get(who)
	if c == null:
		return
	var to := _hero_pos() - c.global_position
	to.y = 0.0
	var gap := to.length()
	if gap > FOLLOW_GAP + 0.6:
		var step := to.normalized() * minf(gap - FOLLOW_GAP, delta * (WALK_SPEED * (2.0 if gap > 6.0 else 1.25)))
		var p := c.global_position + step
		p.y = ground.call(p.x, p.z)
		c.global_position = p
		c.rotation.y = lerp_angle(c.rotation.y, atan2(to.x, to.z), 1.0 - exp(-delta * 8.0))
		if c.anim and c.anim.current_animation != "Move_Walk":
			c.play("Move_Walk", 0.2)
	elif c.anim and c.anim.current_animation == "Move_Walk":
		c.play("Base_Wait", 0.25)

func _cam(s: Dictionary) -> void:
	"""A shot: the camera at `from` [x, up, z] metres off the thing looked at (in its own frame), over `secs`;
	{"free": true} gives the camera back to the map."""
	if dry or cam == null:
		return
	if s.get("free", false):
		map.fixed_view = false
		return
	var at := _where(s.get("at", "hero"), s)
	if at.is_empty():
		return
	var look: Vector3 = at[0] + Vector3(0, float(s.get("up", 1.0)), 0)
	var f: Array = s.get("from", [2.5, 1.6, 4.5])
	var pos := look + Basis(Vector3.UP, at[1]) * Vector3(float(f[0]), float(f[1]), float(f[2]))
	map.fixed_view = true
	var secs := float(s.get("secs", 0.0))
	if s.has("fov"):
		cam.fov = float(s["fov"])
	if secs <= 0.0:
		cam.global_position = pos
		cam.look_at(look, Vector3.UP)
		return
	var p0 := cam.global_position
	var q0 := cam.global_basis.get_rotation_quaternion()
	var tmp := Transform3D(Basis(), pos).looking_at(look, Vector3.UP)
	var q1 := tmp.basis.get_rotation_quaternion()
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float):
		cam.global_position = p0.lerp(pos, k)
		cam.global_basis = Basis(q0.slerp(q1, k)), 0.0, 1.0, secs)
	if s.get("wait", true):
		await tw.finished

func _weather(w: String) -> void:
	Clock.weather = w
	VillageLife.set_weather(w)
	if dry:
		return
	if map.has_method("set_weather"):
		map.set_weather(w)

func _marker(at: Array, hint := "") -> void:
	if dry or at.is_empty():
		return
	var m := Label3D.new()
	m.text = "▼"
	m.font_size = 96
	m.outline_size = 18
	m.modulate = Color("ffd23f")
	m.outline_modulate = Color("5b4a44")
	m.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.fixed_size = true
	m.pixel_size = 0.0006
	add_child(m)
	m.global_position = at[0] + Vector3(0, 2.2, 0)
	var tw := m.create_tween().set_loops()
	tw.tween_property(m, "position:y", m.position.y + 0.25, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(m, "position:y", m.position.y, 0.6).set_trans(Tween.TRANS_SINE)
	_markers.append(m)
	if hint != "":
		_hint_text(hint)

func _point_at(at: Array, hint := "") -> void:
	if dry or at.is_empty() or not _markers.is_empty():
		return
	_marker(at, hint)

func map_marks() -> Array:
	"""Where the ▼ markers are (world points), for the mini-map (scripts/home/mini_map.gd)."""
	var out := []
	for m in _markers:
		if is_instance_valid(m):
			out.append(m.global_position)
	return out

func cinematic() -> bool:
	"""An event is playing a scene the hero doesn't walk in: the mini-map steps aside."""
	return running != "" and not _free

func _clear_markers() -> void:
	for m in _markers:
		m.queue_free()
	_markers.clear()
	_hint_text("")

func _jump_to(id: String) -> void:
	"""--event id: the play day it is on and its hour, the day's earlier events counted as done."""
	for i in Clock.story_days():
		if id in Array(Clock.cal["days"][i].get("events", [])):
			Clock.day = i + 1
			Clock._start_day()
			break
	Clock.minute = Clock.parse(str(events[id].get("when", {}).get("from", "06:00")))
	if Stage.arg("--hour") != "":
		Clock.minute = float(Stage.arg("--hour")) * 60.0
	done.erase(id)
	resume = {}
	var st = events[id].get("start", "auto")
	var at := _where(st.get("place", ""), st) if st is Dictionary else []
	if not at.is_empty():
		_put_hero(at[0], at[1])
