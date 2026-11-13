class_name VillageLife
extends Node3D

const DATA := "res://data/village_life.json"
const LAYOUT := "res://data/hometown/layout.json"
const WALK_SPEED := 0.78
const HIDE_AT := 80.0
const SHOW_AT := 70.0

const NO_SHADOW := ["Head_mCheek", "Head_mEye", "Head_mMouth", "Head_mPaint", "Ears", "Apron"]
const NO_SHADOW_PREFIX := ["Nose_", "Shoes_"]
const FAR_SHADOW := ["Body", "Head_mSkin"]
const SHADOW_NEAR := 16.0

const MID_AT := 8.0
const SLOW_AT := 20.0
const MID_STEP := 1.0 / 30.0

const DETAIL_END := 25.0
const DETAIL := ["Head_mCheek", "Head_mPaint"]
const DETAIL_PREFIX := ["Nose_"]
const DETAIL_SUFFIX := ["_Bed"]
const SLOW_STEP := 1.0 / 15.0
const GRANNY := {"hair": "lowbun", "hair_color": "#d6d8de", "eye_style": "elder", "age": 1, "blush": 0.2,
	"bottom": {"shape": "wide", "design": "lanh", "color": "#16171c", "color_b": "#4a4e5a", "color_c": "#ffffff",
		"trim": "#16171c", "pattern": "plain"},
	"shoes": {"shape": "slides", "color": "#7a5a44", "color_b": "#7a5a44", "trim": "#7a5a44", "design": ""}}
const WOMAN := {"hair": "lowbun", "hair_color": "#2e2320", "blush": 0.3,
	"bottom": {"shape": "wide", "design": "", "color": "#2b2d36", "color_b": "#2b2d36", "trim": "#2b2d36", "pattern": "plain"},
	"shoes": {"shape": "slides", "color": "#6a7a8c", "color_b": "#6a7a8c", "trim": "#6a7a8c", "design": ""}}

static var minute := 360.0
static var speed := 1.0
static var weather := ""
static var event := ""

var ground: Callable
var watcher: Node3D
var data := {}
var people := {}
var log_on := false
var _weather_test := ""
var _days := 0.0
var _clock_owner = null
var layout := {}
var flocks := []

static func add(parent: Node3D, ground_at: Callable, player: Node3D) -> VillageLife:
	if OS.get_cmdline_user_args().has("--no-village"):
		return null
	var v := VillageLife.new()
	v.name = "VillageLife"
	v.ground = ground_at
	v.watcher = player
	parent.add_child(v)
	return v

static func hour() -> float:
	return minute / 60.0

static func set_weather(w: String) -> void:
	weather = w

static func set_event(e: String) -> void:
	event = e

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	TouchControls.add_action(self, func() -> Dictionary:
		if _hint_for == "":
			return {}
		return {"label": Lang.t("TC_TALK", {"name": tr(str(people[_hint_for]["spec"].get("name", "")))}),
			"run": talk.bind(_hint_for)}, 30)
	if FileAccess.file_exists(LAYOUT):
		layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	if Stage.arg("--hour") != "":
		minute = float(Stage.arg("--hour")) * 60.0
	log_on = OS.get_cmdline_user_args().has("--village-log")
	if Stage.arg("--village-weather") != "":
		var w := Stage.arg("--village-weather").split("@")
		if w.size() > 1:
			var when := w[1].split("-")
			get_tree().create_timer(float(when[0])).timeout.connect(func():
				weather = w[0]
				_weather_test = w[0])
			if when.size() > 1:
				get_tree().create_timer(float(when[1])).timeout.connect(func():
					weather = ""
					_weather_test = "-")
		else:
			weather = w[0]
			_weather_test = w[0]
	if Stage.arg("--village-event") != "":
		event = Stage.arg("--village-event")
	if Stage.arg("--village-speed") != "":
		speed = float(Stage.arg("--village-speed"))
	for pack in ["village", "farm"]:
		AnimPacks.need(pack)
	if log_on:
		print("village: anim packs in %s (lazy %s)" % [AnimPacks.loaded(), AnimPacks.lazy])
	for pr: Dictionary in data.get("props", []):
		_spawn_prop(pr)
	for f: Dictionary in data.get("flocks", []):
		_spawn_flock(f)
	for id in data["people"]:
		_spawn(id, data["people"][id])
	_setup_talk()
	_setup_footprints()
	if not OS.get_cmdline_user_args().has("--no-village-nav"):
		get_tree().create_timer(1.0).timeout.connect(_bake_nav)

func _spawn(id: String, spec: Dictionary) -> void:
	var look := Looks.DEFAULT.duplicate(true)
	var l: Dictionary = Wardrobe.look_for(id, spec["look"])
	var base: Dictionary = GRANNY if l.get("base", "") == "granny" else WOMAN if l.get("base", "") == "woman" else {}
	for src in [base, l]:
		for k in src:
			if k != "base":
				look[k] = src[k].duplicate(true) if src[k] is Dictionary else src[k]
	var c := Chibi.new()
	c.name = id
	add_child(c)
	c.build(look)
	if not OS.get_cmdline_user_args().has("--no-merge"):
		ChibiMerge.merge(c)
	Wardrobe.add_wear(c, look)
	var first: Array = _row(spec, hour())
	var at := _spot(spec, first[2])
	c.global_position = at[0]
	c.rotation.y = at[1]
	MoodLayer.of(c).set_mood(_mood(spec))
	people[id] = {"chibi": c, "spec": spec, "shown": true, "near": true, "step": 0.0, "acc": 0.0}
	if _at_home_hours(spec):
		people[id]["home"] = true
		c.visible = false
		c.process_mode = Node.PROCESS_MODE_DISABLED
	_setup_look(people[id])
	_shadows(c, true)
	_details(c)
	_live(id)

func _process(delta: float) -> void:
	if _clocked():
		minute = Clock.minute
		weather = Clock.weather if _weather_test == "" else _weather_test.trim_prefix("-")
	else:
		var was := minute
		minute = fmod(minute + delta * speed, 24.0 * 60.0)
		if minute < was:
			_days += 1
		if _weather_test == "":
			_roll_weather()
		else:
			weather = _weather_test.trim_prefix("-")
	if raining() and _rain == null:
		_setup_rain()
	if _rain != null and _rain.on != raining():
		_rain.set_raining(raining())
	if _rain != null and not raining() and not _rain.drops.emitting:
		_rain_dry += delta
		if _rain_dry > 3.0:
			_rain.queue_free()
			_rain = null
	else:
		_rain_dry = 0.0
	if watcher == null:
		return
	if _watcher_last != Vector3.INF and delta > 0.0:
		var mv := watcher.global_position - _watcher_last
		mv.y = 0.0
		_watcher_speed = lerpf(_watcher_speed, mv.length() / delta, 0.3)
	_watcher_last = watcher.global_position
	_now += delta
	for id in people:
		var p: Dictionary = people[id]
		var c: Chibi = p["chibi"]
		if p.get("home", false):
			continue
		var d := c.global_position.distance_to(watcher.global_position)
		if p["shown"] and d > HIDE_AT:
			p["shown"] = false
			c.visible = false
			c.process_mode = Node.PROCESS_MODE_DISABLED
		elif not p["shown"] and d < SHOW_AT:
			p["shown"] = true
			c.visible = true
			c.process_mode = Node.PROCESS_MODE_INHERIT
		if p["shown"]:
			var step := _rate(d)
			if (step > 0.0) != (p["step"] > 0.0):
				_set_slow(c.anim, [c.skel, c.hair_skel], step > 0.0)
			p["step"] = step
			if step > 0.0:
				p["acc"] += delta
				if p["acc"] >= step:
					_step(c.anim, [c.skel, c.hair_skel], p["acc"])
					p["acc"] = 0.0
			_notice(p, d, delta)
			var near := d < SHADOW_NEAR
			if near != p["near"]:
				p["near"] = near
				_shadows(c, near)
			var m := _mood(p["spec"])
			if m != MoodLayer.mood_of(c):
				MoodLayer.of(c).set_mood(m)
	for f: Dictionary in flocks:
		_flock(f, delta)
	_update_hint()
	if Engine.get_process_frames() % 6 == 0:
		_update_step_surface()

const THOC_TEX := "res://props/village/bat_thoc_alb.png"

func _spawn_prop(spec: Dictionary) -> void:
	"""The paddy drying on a tarp (kind "thoc"): a grid hugging the ground, the grain heaped a little in the
	middle, drawn with the toon shader and its painted picture."""
	if spec.get("kind", "") != "thoc" or not ResourceLoader.exists(THOC_TEX):
		return
	var anchor := _anchor(spec)
	var at: Array = spec["at"]
	var size: Array = spec["size"]
	var yaw: float = anchor[1] + deg_to_rad(float(at[2]))
	var centre: Vector3 = anchor[0] + Basis(Vector3.UP, anchor[1]) * Vector3(at[0], 0, at[1])
	var b := Basis(Vector3.UP, yaw)
	var nx := 8
	var nz := 6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid := []
	for j in nz + 1:
		for i in nx + 1:
			var u := float(i) / nx
			var v := float(j) / nz
			var lp := Vector3((u - 0.5) * float(size[0]), 0, (v - 0.5) * float(size[1]))
			var w: Vector3 = centre + b * lp
			var heap := 0.035 * sin(PI * u) * sin(PI * v)
			grid.append([Vector3(w.x, ground.call(w.x, w.z) + 0.025 + heap, w.z) - centre, Vector2(u, v)])
	for j in nz:
		for i in nx:
			var k := j * (nx + 1) + i
			for q in [k, k + 1, k + nx + 2, k, k + nx + 2, k + nx + 1]:
				st.set_uv(grid[q][1])
				st.set_normal(Vector3.UP)
				st.add_vertex(grid[q][0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/toon.gdshader")
	m.set_shader_parameter("has_albedo", true)
	m.set_shader_parameter("albedo_tex", load(THOC_TEX))
	m.set_shader_parameter("rim", 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = HIDE_AT
	add_child(mi)
	mi.global_position = centre

func _rake(c: Chibi, spec: Dictionary, spot: String, alive: Callable) -> void:
	"""Turning the drying paddy: draw the rake across it a while, a breather, a step along the tarp, again."""
	var at := _spot(spec, spot)
	Chores.pick_up(c, "cao_thoc")
	await _walk(c, at[0], at[1], alive)
	var side := 1.0
	while alive.call():
		if not await Chores.run(c, "rake", randi_range(3, 4), alive):
			return
		if not await Chores.idle(c, randf_range(8.0, 16.0), alive):
			return
		Chores.pick_up(c, "cao_thoc")
		var step := Basis(Vector3.UP, at[1]) * Vector3(side * 0.6, 0, 0)
		side = -side
		var to: Vector3 = at[0] + step
		to.y = ground.call(to.x, to.z)
		if not await _walk(c, to, at[1], alive):
			return

const LOOK_NEAR := 4.5
const GREET_NEAR := 2.6
const GREET_AGAIN := 90.0
const STARTLE_NEAR := 1.3
const STARTLE_SPEED := 2.6
const STARTLE_AGAIN := 20.0
var _watcher_last := Vector3.INF
var _now := 0.0
var _watcher_speed := 0.0

func _setup_look(p: Dictionary) -> void:
	var c: Chibi = p["chibi"]
	if c.skel == null or c.skel.find_bone("Head") < 0:
		return
	var target := Marker3D.new()
	c.add_child(target)
	var look := LookAtModifier3D.new()
	look.bone_name = "Head"
	look.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
	look.primary_rotation_axis = Vector3.AXIS_Y
	look.use_secondary_rotation = true
	look.duration = 0.3
	look.transition_type = Tween.TRANS_SINE
	look.ease_type = Tween.EASE_IN_OUT
	look.use_angle_limitation = true
	look.symmetry_limitation = true
	look.primary_limit_angle = deg_to_rad(140.0)
	look.primary_damp_threshold = 0.8
	look.secondary_limit_angle = deg_to_rad(50.0)
	look.secondary_damp_threshold = 0.8
	look.influence = 0.0
	c.skel.add_child(look)
	look.target_node = look.get_path_to(target)
	p["look"] = look
	p["look_at"] = target
	p["greeted"] = -INF
	p["startled"] = -INF

func _notice(p: Dictionary, d: float, delta: float) -> void:
	"""Look at the player near and in front; wave when they come up; start when they run past."""
	var c: Chibi = p["chibi"]
	var look: LookAtModifier3D = p.get("look")
	if look == null:
		return
	var want := 0.0
	var head := watcher.global_position + Vector3(0, 1.0, 0)
	var to := head - c.global_position
	to.y = 0.0
	var fwd := Vector3(sin(c.global_rotation.y), 0, cos(c.global_rotation.y))
	var in_front: bool = to.length() > 0.05 and fwd.dot(to.normalized()) > -0.2
	var resting := c.anim.current_animation == "Act_SitFloor"
	if p.get("talking", false) or (d < LOOK_NEAR and in_front):
		p["look_at"].global_position = head
		want = 1.0 if not resting else 0.6
	look.influence = move_toward(look.influence, want, delta * 3.0)
	if p.get("talking", false):
		return
	var now := _now
	var hands_free := c.anim.current_animation in ["Base_Wait", ""]
	if d < STARTLE_NEAR and _watcher_speed > STARTLE_SPEED and now - p["startled"] > STARTLE_AGAIN:
		p["startled"] = now
		p["greeted"] = now
		if log_on:
			print("village: %s startled (hands free %s)" % [c.name, hands_free])
		if hands_free:
			c.emote("surprised")
		else:
			EmoteFx.play(c, "exclaim")
	elif d < GREET_NEAR and in_front and now - p["greeted"] > GREET_AGAIN:
		p["greeted"] = now
		if log_on:
			print("village: %s greets (hands free %s)" % [c.name, hands_free])
		if hands_free:
			c.emote("wave")
		else:
			EmoteFx.play(c, "note")

const STEP_SURFACE := {0: "co", 1: "bun", 2: "dat", 3: "dat", 4: "gach", 5: "cat", 6: "bun", 7: "dat", 8: "co",
	9: "co", 10: "co", 11: "soi", 12: "gach", 13: "dat", 14: "gach"}
var _ground_body: StaticBody3D
var _kind_at: Callable

func _update_step_surface() -> void:
	if _ground_body == null:
		for n in get_parent().find_children("*", "CollisionShape3D", true, false):
			if (n as CollisionShape3D).shape is HeightMapShape3D and n.get_parent() is StaticBody3D:
				_ground_body = n.get_parent()
				break
		if _ground_body == null:
			return
	if not _kind_at.is_valid():
		return
	var p := watcher.global_position
	var s: String = STEP_SURFACE.get(int(_kind_at.call(p.x, p.z)), "dat")
	if _ground_body.get_meta("surface", "") != s:
		_ground_body.set_meta("surface", s)

const TALK_NEAR := 2.2
const TALK_LEAVE := 4.0
const JOB_LINES := {"sweep": "VL_JOB_SWEEP", "rake": "VL_JOB_RAKE", "water": "VL_JOB_WATER", "feed": "VL_JOB_FEED",
	"rest": "VL_JOB_REST"}
const CLICK_FROM := 14.0
var _hint: Label
var _hint_for := ""
var _pick: ClickPick

func _setup_footprints() -> void:
	"""Prints in the dirt (scripts/npc/footprints.gd) for the player and everyone here; the ground kinds are the
	hometown's (its terrain's material grid, tools/hometown_map.py MATS), read off our parent when it has them."""
	var home := get_parent()
	var terrain = home.get("terrain")
	if terrain == null or not "mats" in terrain:
		return
	var n: int = int(home.get("N"))
	var half: int = int(home.get("HALF"))
	var fp := Footprints.new()
	fp.name = "Footprints"
	fp.ground = ground
	fp.centre = watcher
	fp.kind_at = func(x: float, z: float) -> int:
		var gx := int(round(x)) + half
		var gz := int(round(z)) + half
		if gx < 0 or gz < 0 or gx >= n or gz >= n:
			return -1
		return terrain.mats[gz * n + gx]
	add_child(fp)
	_kind_at = fp.kind_at
	if watcher is Player:
		fp.track((watcher as Player).chibi)
	for id in people:
		fp.track(people[id]["chibi"])

func _setup_talk() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hint = Label.new()
	_hint.theme = UiTheme.make()
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", UiTheme.INK)
	_hint.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.98, 0.95, 0.95), 18, UiTheme.PINK, 3, 14))
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -40
	_hint.visible = false
	layer.add_child(_hint)

	var cam := get_viewport().get_camera_3d()
	if cam != null and watcher is Player:
		_pick = ClickPick.new()
		add_child(_pick)
		_pick.setup(cam, layer)
		for id in people:
			var c: Chibi = people[id]["chibi"]
			_pick.add(func(): return c.global_position + Vector3(0, 0.8, 0),
				func(): return Lang.t("TALK_HOVER", {"name": tr(str(people[id]["spec"].get("name", "")))}),
				_walk_and_talk.bind(id),
				func(): return people[id]["shown"] and not people[id].get("talking", false) 					and (watcher as Player).controls 					and c.global_position.distance_to(watcher.global_position) < CLICK_FROM)
	if Stage.arg("--walk-to") != "" and watcher is Player:
		var w := Stage.arg("--walk-to").split_floats(",")
		get_tree().create_timer(2.0).timeout.connect(func():
			(watcher as Player).go_to(Vector3(w[0], 0, w[1]), OS.get_cmdline_user_args().has("--walk-run"), 0.2, 60.0))
	if Stage.arg("--click") != "":
		get_tree().create_timer(3.0).timeout.connect(_test_click.bind(Stage.arg("--click")))
	if Stage.arg("--talk") != "":
		get_tree().create_timer(3.0).timeout.connect(func(): talk(Stage.arg("--talk")))

func _nearest_talker() -> String:
	if watcher == null or (watcher is Player and not (watcher as Player).controls):
		return ""
	var best := ""
	var best_d := TALK_NEAR
	for id in people:
		var p: Dictionary = people[id]
		if not p["shown"] or p.get("talking", false):
			continue
		var d: float = (p["chibi"] as Chibi).global_position.distance_to(watcher.global_position)
		if d < best_d:
			best_d = d
			best = id
	return best

func _update_hint() -> void:
	if _hint == null:
		return
	var id := _nearest_talker()
	_hint_for = id
	_hint.visible = id != ""
	if id != "":
		_hint.text = Lang.t("VL_TALK_HINT", {"name": tr(str(people[id]["spec"].get("name", "")))})

func _unhandled_input(e: InputEvent) -> void:
	var f: bool = e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).physical_keycode == KEY_F
	var a: bool = e is InputEventJoypadButton and e.pressed and (e as InputEventJoypadButton).button_index == JOY_BUTTON_A
	if (f or a) and _hint_for != "":
		if watcher is Player and (watcher as Player).chibi.tool != "":
			return
		get_viewport().set_input_as_handled()
		talk(_hint_for)

func _test_click(id: String) -> void:
	var cam := get_viewport().get_camera_3d()
	var at := cam.unproject_position((people[id]["chibi"] as Chibi).global_position + Vector3(0, 0.8, 0))
	at = get_viewport().get_screen_transform() * at
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	Input.parse_input_event(mv)
	await get_tree().process_frame
	for down in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = down
		b.position = at
		b.global_position = at
		Input.parse_input_event(b)
		await get_tree().process_frame

func _line(key: String, part: String) -> String:
	"""The person's own line (VL_<NAME>_<part>), or everyone's (VL_ANY_<part>) for someone who has none yet."""
	return key + part if tr(key + part) != key + part else "VL_ANY_" + part

func _walk_and_talk(id: String) -> void:
	"""Clicked from a few steps away: the player walks up to them (the near side), then they talk."""
	var pl := watcher as Player
	var c: Chibi = people[id]["chibi"]
	if log_on:
		print("village: clicked %s" % id)
	var to := pl.global_position - c.global_position
	to.y = 0.0
	if to.length() > TALK_NEAR * 0.7:
		var goal: Vector3 = c.global_position + to.normalized() * 1.0
		var path := PackedVector3Array([goal])
		if nav_map.is_valid():
			var nav := NavigationServer3D.map_get_path(nav_map, pl.global_position, goal, true)
			if nav.size() > 1:
				path = nav.slice(1)
		var res := "arrived"
		for k in path.size():
			res = await pl.go_to(path[k], to.length() > 6.0, 0.3 if k == path.size() - 1 else 0.45)
			if res != "arrived":
				break
		if log_on:
			print("village: walked to %s: %s, %.1f m" % [id, res, pl.global_position.distance_to(c.global_position)])
		if res == "cancelled":
			return
	if pl.global_position.distance_to(c.global_position) < TALK_LEAVE:
		talk(id)

func talk(id: String) -> void:
	"""The person puts down what they're doing, turns to the player and says two things: a hello for the time of
	day, then how they feel (happy, worn out) or what they're busy with; then back to their day."""
	if not people.has(id) or people[id].get("talking", false):
		return
	var p: Dictionary = people[id]
	var c: Chibi = p["chibi"]
	var spec: Dictionary = p["spec"]
	p["talking"] = true
	await get_tree().process_frame
	Chores.put_down(c)
	var to := watcher.global_position - c.global_position
	to.y = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "rotation:y", c.rotation.y + wrapf(atan2(to.x, to.z) - c.rotation.y, -PI, PI), 0.3)
	c.play("Base_Wait", 0.2)
	var bubble := _bubble(p)
	if watcher is Player:
		var pl := watcher as Player
		var back := c.global_position - pl.global_position
		pl.facing = atan2(back.x, back.z)
		pl.create_tween().tween_property(pl, "rotation:y", pl.rotation.y + angle_difference(pl.rotation.y, pl.facing), 0.25)
	await tw.finished
	var key := "VL_%s_" % String(spec.get("name", "")).trim_prefix("CAST_")
	var h := hour()
	var mood := MoodLayer.mood_of(c)
	c.emote("wave" if mood != "met" else "sigh")
	var lines := [_line(key, "SANG" if h < 11.0 else "TRUA" if h < 14.0 else "CHIEU")]
	if mood == "vui" or mood == "met":
		lines.append(_line(key, mood.to_upper()))
	elif JOB_LINES.has(String(_row(spec, h)[1])):
		lines.append(JOB_LINES[String(_row(spec, h)[1])])
	for k: String in lines:
		var text := Lang.t(k)
		var secs := clampf(1.6 + text.length() * 0.06, 2.4, 5.0)
		bubble.show_text(text, secs, false, tr(str(spec.get("name", ""))))
		var t := 0.0
		while t < secs + 0.3:
			await get_tree().process_frame
			t += get_process_delta_time()
			if watcher.global_position.distance_to(c.global_position) > TALK_LEAVE:
				bubble.hide_now()
				break
	p["talking"] = false

const HOME_AT := 18.75
const DOOR_OUT := 0.9

func _home_at(spec: Dictionary) -> float:
	return float(spec.get("home_at", HOME_AT))

func _at_home_hours(spec: Dictionary) -> bool:
	var h := hour()
	return h >= _home_at(spec) or h < float(spec["plan"][0][0])

func _house(spec: Dictionary) -> Array:
	"""[house node or null, the doorway (world), the way out of it (world, flat)], found once."""
	if spec.has("_house"):
		return spec["_house"]
	var near := Vector2.INF
	var a: Dictionary = spec.get("home", {})
	if a.has("house_near"):
		near = Vector2(a["house_near"][0], a["house_near"][1])
	elif spec.get("anchor", {}).has("house_near"):
		near = Vector2(spec["anchor"]["house_near"][0], spec["anchor"]["house_near"][1])
	else:
		var at: Vector3 = _anchor(spec)[0]
		near = Vector2(at.x, at.z)
	var best: Array = []
	var best_d := INF
	for h: Array in layout.get("dress", {}).get("houses", []):
		var d := Vector2(h[0], h[1]).distance_to(near)
		if d < best_d:
			best_d = d
			best = h
	var res := [null, Vector3.ZERO, Vector3.FORWARD]
	if not best.is_empty():
		var origin := Vector3(best[0], ground.call(best[0], best[1]), best[1])
		var fwd := Vector3(sin(deg_to_rad(float(best[2]))), 0, cos(deg_to_rad(float(best[2]))))
		var node: Node3D = null
		for n in get_parent().get_children():
			if n is Node3D and Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z).distance_to(Vector2(best[0], best[1])) < 0.3:
				node = n
				break
		var door := origin + fwd * 3.0
		if node != null:
			var leaves := []
			for leaf_name in ["DoorF_L", "DoorF_R", "DoorF_L1", "DoorF_R1"]:
				var leaf := node.find_child(leaf_name, true, false) as Node3D
				if leaf:
					leaves.append(leaf.global_position)
			if not leaves.is_empty():
				door = Vector3.ZERO
				for lp: Vector3 in leaves:
					door += lp
				door /= leaves.size()
				if leaves.size() == 1:
					door += node.global_basis.x * 0.0
		door.y = ground.call(door.x, door.z)
		res = [node, door, fwd]
		if node != null:
			spec["_house"] = res
	return res

func _go_home(id: String) -> void:
	var p: Dictionary = people[id]
	var c: Chibi = p["chibi"]
	var spec: Dictionary = p["spec"]
	if c.has_meta("laid_tool"):
		Chores.pick_up(c, String(c.get_meta("laid_name", "")))
	if c.tool == "umbrella":
		c.close_umbrella()
	var hs := _house(spec)
	var door: Vector3 = hs[1]
	var out: Vector3 = door + (hs[2] as Vector3) * DOOR_OUT
	out.y = ground.call(out.x, out.z)
	var stay := func() -> bool: return is_inside_tree() and _at_home_hours(spec) and not p.get("talking", false)
	if not await _walk(c, out, atan2(-(hs[2] as Vector3).x, -(hs[2] as Vector3).z), stay):
		return
	if hs[0] != null:
		HomeKit.swing_door(hs[0], "DoorF", true, 0.6)
		await get_tree().create_timer(0.5).timeout
	c.play("Move_Walk", 0.2)
	var tw := c.create_tween()
	tw.tween_property(c, "global_position", door - (hs[2] as Vector3) * 0.4, 0.9)
	await tw.finished
	c.hold("")
	p["home"] = true
	c.visible = false
	c.process_mode = Node.PROCESS_MODE_DISABLED
	if hs[0] != null:
		HomeKit.swing_door(hs[0], "DoorF", false, 0.6)
	if log_on:
		print("village %05.2f %s: home" % [hour(), id])

func _come_out(id: String) -> void:
	var p: Dictionary = people[id]
	var c: Chibi = p["chibi"]
	var spec: Dictionary = p["spec"]
	var hs := _house(spec)
	var door: Vector3 = hs[1]
	var fwd: Vector3 = hs[2]
	if hs[0] != null:
		HomeKit.swing_door(hs[0], "DoorF", true, 0.6)
		await get_tree().create_timer(0.5).timeout
	p["home"] = false
	c.global_position = door - fwd * 0.4
	c.rotation.y = atan2(fwd.x, fwd.z)
	c.process_mode = Node.PROCESS_MODE_INHERIT
	c.visible = p["shown"]
	c.play("Move_Walk", 0.2)
	var out: Vector3 = door + fwd * DOOR_OUT
	out.y = ground.call(out.x, out.z)
	var tw := c.create_tween()
	tw.tween_property(c, "global_position", out, 0.9)
	await tw.finished
	c.play("Base_Wait", 0.2)
	if hs[0] != null:
		HomeKit.swing_door(hs[0], "DoorF", false, 0.6)
	if log_on:
		print("village %05.2f %s: out of the house" % [hour(), id])

const CHAT_NEAR := 3.0
const CHAT_LINES := ["VL_CHAT_1", "VL_CHAT_2", "VL_CHAT_3", "VL_CHAT_4", "VL_CHAT_5", "VL_CHAT_6", "VL_CHAT_7", "VL_CHAT_8"]
const CHAT_REPLIES := ["VL_REPLY_1", "VL_REPLY_2", "VL_REPLY_3", "VL_REPLY_4"]
var _chat_busy := {}
var _chat_said := {}

func _partners(id: String) -> Array:
	var me: Chibi = people[id]["chibi"]
	var out := []
	for o in people:
		if o != id and people[o].get("job", "") == "chat" and not people[o].get("home", false) \
				and (people[o]["chibi"] as Chibi).global_position.distance_to(me.global_position) < CHAT_NEAR:
			out.append(o)
	return out

func _chat(id: String, spot: String, alive: Callable) -> void:
	var p: Dictionary = people[id]
	var c: Chibi = p["chibi"]
	var spec: Dictionary = p["spec"]
	var at := _spot(spec, spot)
	if c.has_meta("laid_tool"):
		Chores.pick_up(c, String(c.get_meta("laid_name", "")))
	c.hold("")
	if not await _walk(c, at[0], at[1], alive):
		return
	var next := _now + randf_range(1.0, 3.0)
	while alive.call():
		await get_tree().process_frame
		var others := _partners(id)
		if others.is_empty():
			if _now > next:
				next = _now + randf_range(8.0, 14.0)
				if not await Chores.idle(c, 1.0, alive):
					return
			continue
		var centre: Vector3 = (people[others[0]]["chibi"] as Chibi).global_position
		var to := centre - c.global_position
		to.y = 0.0
		if to.length() > 0.1:
			c.rotation.y = lerp_angle(c.rotation.y, atan2(to.x, to.z), 1.0 - exp(-get_process_delta_time() * 5.0))
		if _now < next:
			continue
		var group := [id] + others
		group.sort()
		var key: String = group[0]
		if _now < float(_chat_busy.get(key, 0.0)):
			next = _now + randf_range(0.6, 1.4)
			continue
		var reply: bool = p.get("heard", 0.0) > _now - 4.0 and randf() < 0.5
		var said: Array = _chat_said.get(key, [])
		var pool := (CHAT_REPLIES if reply else CHAT_LINES).filter(func(l: String) -> bool: return not l in said)
		var line: String = pool.pick_random() if not pool.is_empty() else (CHAT_REPLIES if reply else CHAT_LINES).pick_random()
		said.append(line)
		_chat_said[key] = said.slice(-5)
		var text := Lang.t(line)
		var secs := clampf(1.6 + text.length() * 0.06, 2.4, 5.0)
		_chat_busy[key] = _now + secs + 0.6
		var bubble := _bubble(p)
		bubble.show_text(text, secs, false, tr(str(spec.get("name", ""))))
		for o in others:
			people[o]["heard"] = _now
			var oc: Chibi = people[o]["chibi"]
			var react: String = ["agree", "laugh", "happy", ""].pick_random() if MoodLayer.mood_of(oc) != "met" else ["agree", "sigh", ""].pick_random()
			if react != "" and oc.anim.current_animation in ["Base_Wait", ""]:
				get_tree().create_timer(0.8).timeout.connect(func(): if is_instance_valid(oc): oc.emote(react))
		next = _now + secs + randf_range(2.0, 5.0)

func _bubble(p: Dictionary) -> SpeechBubble:
	var bubble: SpeechBubble = p.get("bubble")
	if bubble == null:
		bubble = SpeechBubble.new()
		bubble.position.y = 1.72
		bubble.name_color = Color(str(p["spec"].get("color", "#d98c6a")))
		(p["chibi"] as Chibi).add_child(bubble)
		p["bubble"] = bubble
	return bubble

const RAIN := ["mua", "giong"]

static func raining() -> bool:
	return weather in RAIN

func _shelter_spot(spec: Dictionary) -> String:
	"""Where someone waits out the rain: their noon-rest spot (a hiên, the quán: under a roof), if they have one."""
	for r in spec["plan"]:
		if String(r[1]) == "rest":
			return String(r[2])
	return ""

func _shelter(c: Chibi, spec: Dictionary, alive: Callable) -> void:
	"""Rain: the work left where it is, a start at the first drops, the umbrella up, a walk to cover; under the roof
	the umbrella comes down and they stand about (tired) till it stops. With no cover, they wait under the umbrella."""
	Chores.put_down(c)
	c.emote("surprised")
	await get_tree().create_timer(0.9).timeout
	if not alive.call():
		return
	c.open_umbrella()
	var spot := _shelter_spot(spec)
	if spot == "":
		while alive.call():
			await get_tree().process_frame
		c.close_umbrella()
		return
	var at := _spot(spec, spot)
	await _walk(c, at[0], at[1], alive, false)
	c.close_umbrella()
	await get_tree().create_timer(0.6).timeout
	if c.tool == "umbrella":
		c.hold("")
	while alive.call():
		if not await Chores.idle(c, randf_range(20.0, 35.0), alive):
			break

const SHOWERS := {1: [0.35, 14.0, 17.5, 20.0, 45.0], 2: [0.45, 14.0, 17.5, 20.0, 50.0], 3: [0.6, 9.0, 18.0, 40.0, 100.0],
	4: [0.0, 0.0, 0.0, 0.0, 0.0]}
var _rain: Rain
var _rain_dry := 0.0
var _shower := [-1.0, -1.0]
var _rolled_day := -1

func _setup_rain() -> void:
	_rain = Rain.new()
	_rain.name = "VillageRain"
	_rain.follow = watcher
	_rain.chibis = func() -> Array:
		var out := []
		if watcher is Player:
			out.append((watcher as Player).chibi)
		for id in people:
			if not people[id].get("home", false):
				out.append(people[id]["chibi"])
		var ev := get_tree().get_first_node_in_group("home_events")
		if ev != null and "actors" in ev:
			out.append_array(ev.actors.values())
		return out
	add_child(_rain)
	for gp: GPUParticles3D in [_rain.drops, _rain.splash]:
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _chapter() -> int:
	var ch := String(Story.chapter)
	return clampi(int(ch.trim_prefix("que_")), 1, 4) if ch.begins_with("que_") else 1

func _roll_weather() -> void:
	"""Our own showers, when nobody else keeps the weather (no HomeEvents, no test flag)."""
	var day := int(_days)
	if day != _rolled_day:
		_rolled_day = day
		var sh: Array = SHOWERS.get(_chapter(), SHOWERS[1])
		_shower = [-1.0, -1.0]
		if randf() < float(sh[0]):
			var from := randf_range(float(sh[1]), float(sh[2])) * 60.0
			_shower = [from, from + randf_range(float(sh[3]), float(sh[4]))]
		if log_on:
			print("village day %d (chapter %d): shower %s" % [day, _chapter(), "%.2f-%.2f h" % [_shower[0] / 60.0, _shower[1] / 60.0] if _shower[0] >= 0.0 else "none"])
	weather = "mua" if minute >= _shower[0] and minute < _shower[1] and _shower[0] >= 0.0 else ""

const NAV_HALF := 40.0
const NAV_CELL := 1.0
var nav_regions: Array[NavigationRegion3D] = []
var nav_map := RID()

func _bake_nav() -> void:
	"""One region per cluster of people (their spots' centres within NAV_HALF of each other), all on nav_map."""
	var clusters := []
	for id in people:
		var c := Vector3.ZERO
		var n := 0
		for k in people[id]["spec"]["spots"]:
			c += _spot(people[id]["spec"], k)[0]
			n += 1
		if n == 0:
			continue
		c /= n
		var joined := false
		for cl: Array in clusters:
			if (cl[0] / cl[1]).distance_to(c) < NAV_HALF:
				cl[0] += c
				cl[1] += 1
				joined = true
				break
		if not joined:
			clusters.append([c, 1])
	nav_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(nav_map, 0.1)
	NavigationServer3D.map_set_cell_height(nav_map, 0.05)
	NavigationServer3D.map_set_active(nav_map, true)
	for cl: Array in clusters:
		_bake_area(cl[0] / cl[1])
		await get_tree().process_frame

func _bake_area(centre: Vector3) -> void:
	var t_main := Time.get_ticks_usec()
	var nm := NavigationMesh.new()
	nm.cell_size = 0.1
	nm.cell_height = 0.05
	nm.agent_radius = 0.3
	nm.agent_height = 1.4
	nm.agent_max_climb = 0.35
	nm.agent_max_slope = 32.0
	var y0: float = ground.call(centre.x, centre.z)
	nm.filter_baking_aabb = AABB(Vector3(centre.x - NAV_HALF, y0 - 20.0, centre.z - NAV_HALF), Vector3(NAV_HALF * 2, 40.0, NAV_HALF * 2))
	var src := NavigationMeshSourceGeometryData3D.new()

	var faces := PackedVector3Array()
	var steps := int(NAV_HALF * 2 / NAV_CELL)
	var x0 := centre.x - NAV_HALF
	var z0 := centre.z - NAV_HALF
	var h := []
	for j in steps + 1:
		var row := PackedFloat32Array()
		for i in steps + 1:
			row.append(ground.call(x0 + i * NAV_CELL, z0 + j * NAV_CELL))
		h.append(row)
	for j in steps:
		for i in steps:
			var a := Vector3(x0 + i * NAV_CELL, h[j][i], z0 + j * NAV_CELL)
			var b := Vector3(x0 + (i + 1) * NAV_CELL, h[j][i + 1], z0 + j * NAV_CELL)
			var c := Vector3(x0 + (i + 1) * NAV_CELL, h[j + 1][i + 1], z0 + (j + 1) * NAV_CELL)
			var d := Vector3(x0 + i * NAV_CELL, h[j + 1][i], z0 + (j + 1) * NAV_CELL)
			faces.append_array([a, b, c, a, c, d])
	src.add_faces(faces, Transform3D.IDENTITY)

	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(NAV_HALF * 2, 30.0, NAV_HALF * 2)
	q.shape = box
	q.transform = Transform3D(Basis(), Vector3(centre.x, y0, centre.z))
	q.collide_with_areas = false
	var seen := {}
	var blocks := 0
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 2048):
		var body = hit["collider"]
		if not body is StaticBody3D or body == watcher:
			continue
		var owner_id: int = (body as StaticBody3D).shape_find_owner(hit["shape"])
		var key := "%d/%d" % [body.get_instance_id(), owner_id]
		if seen.has(key):
			continue
		seen[key] = true
		var cs := (body as StaticBody3D).shape_owner_get_owner(owner_id) as CollisionShape3D
		if cs == null or cs.shape == null or cs.shape is HeightMapShape3D or cs.shape is WorldBoundaryShape3D:
			continue
		var ab := cs.shape.get_debug_mesh().get_aabb()
		var t := cs.global_transform
		if ab.size.x > NAV_HALF or ab.size.z > NAV_HALF:
			continue
		var pts := PackedVector3Array()
		for corner in [Vector3(ab.position.x, 0, ab.position.z), Vector3(ab.end.x, 0, ab.position.z),
				Vector3(ab.end.x, 0, ab.end.z), Vector3(ab.position.x, 0, ab.end.z)]:
			var w: Vector3 = t * (corner + Vector3(0, ab.position.y, 0))
			pts.append(Vector3(w.x, 0, w.z))
		var bottom: float = (t * ab.position).y
		var top: float = (t * ab.end).y
		src.add_projected_obstruction(pts, minf(bottom, top) - 0.5, absf(top - bottom) + 0.5, false)
		blocks += 1
	var region := NavigationRegion3D.new()
	region.name = "VillageNav"
	add_child(region)
	region.set_navigation_map(nav_map)
	nav_regions.append(region)
	var t0 := Time.get_ticks_msec()
	var main_ms := (Time.get_ticks_usec() - t_main) / 1000.0
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, func():
		region.navigation_mesh = nm
		if log_on:
			print("village nav: %d obstacles, %d polygons, %.1f ms on the main thread, baked in %d ms on a thread" % [
				blocks, nm.get_polygon_count(), main_ms, Time.get_ticks_msec() - t0]))

const ROOST := 18.5
const COOP_DOOR := 0.85

const COOP_PATH := [Vector3(0, 0, 0.52), Vector3(0, 0.38, 0.13), Vector3(0, 0.38, -0.08)]
const COOP_GAP := 0.8
const COOP_QUEUE := 0.3

func _spawn_flock(spec: Dictionary) -> void:
	"""A few hens (and a rooster) roaming a yard: a rectangle [x0, z0, x1, z1] in its anchor's frame, and their
	hen house ("coop": [x, z, yaw] in the same frame; the homes kit's bamboo chuong_ga, as the farm's)."""
	var f := {"spec": spec, "hens": [], "shown": true, "step": 0.0, "acc": 0.0}
	if spec.has("coop"):
		var anchor := _anchor(spec)
		var c: Array = spec["coop"]
		var at: Vector3 = anchor[0] + Basis(Vector3.UP, anchor[1]) * Vector3(c[0], 0, c[1])
		at.y = ground.call(at.x, at.z)
		var yaw: float = anchor[1] + deg_to_rad(float(c[2]))
		f["coop"] = HomeKit.place(self, "chuong_ga", at, rad_to_deg(yaw))
		var door: Vector3 = at + Basis(Vector3.UP, yaw) * Vector3(0, 0, COOP_DOOR)
		door.y = ground.call(door.x, door.z)
		f["door"] = door

		var path := Curve3D.new()
		path.bake_interval = 0.05
		path.add_point(door)
		for q: Vector3 in COOP_PATH:
			path.add_point(at + Basis(Vector3.UP, yaw) * q)
		f["path"] = path
		f["fwd"] = Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
		f["queue"] = []
		f["free_at"] = 0.0
	for i in spec["kinds"].size():
		var at := _in_yard(f, randf(), randf())
		var a := FarmAnimal.spawn(self, spec["kinds"][i], at, randf() * TAU)
		f["hens"].append({"a": a, "kind": spec["kinds"][i], "goal": at, "wait": randf_range(0.5, 4.0), "eat": 0.0,
			"inside": false, "late": randf_range(0.0, 0.25)})
	flocks.append(f)

func _in_yard(f: Dictionary, u: float, v: float) -> Vector3:
	var r: Array = f["spec"]["yard"]
	var anchor := _anchor(f["spec"])
	var p: Vector3 = anchor[0] + Basis(Vector3.UP, anchor[1]) * Vector3(lerpf(r[0], r[2], u), 0, lerpf(r[1], r[3], v))
	p.y = ground.call(p.x, p.z)
	return p

func feed(at: Vector3) -> void:
	"""Grain landed at `at`: the hens of the yard nearest come running and peck there a while."""
	for f: Dictionary in flocks:
		if _in_yard(f, 0.5, 0.5).distance_to(at) > 8.0:
			continue
		for h: Dictionary in f["hens"]:
			var g: Vector3 = at + Vector3(randf_range(-0.45, 0.45), 0, randf_range(-0.45, 0.45))
			g.y = ground.call(g.x, g.z)
			h["goal"] = g
			h["eat"] = randf_range(8.0, 14.0)

func _flock(f: Dictionary, delta: float) -> void:
	"""As the farm's hens (scripts/farm/farm_plot.gd _hens): wander the yard, peck, run to grain."""
	if watcher != null:
		var d := _in_yard(f, 0.5, 0.5).distance_to(watcher.global_position)
		var show: bool = d < (HIDE_AT if f["shown"] else SHOW_AT)
		if show != f["shown"]:
			f["shown"] = show
			for h: Dictionary in f["hens"]:
				h["a"].visible = show and not h.get("inside", false)
				h["a"].process_mode = Node.PROCESS_MODE_INHERIT if show else Node.PROCESS_MODE_DISABLED
		if not show:
			return
		var step := _rate(d)
		if (step > 0.0) != (f["step"] > 0.0):
			for h: Dictionary in f["hens"]:
				_set_slow(h["a"].anim, [], step > 0.0)
		f["step"] = step
		if step > 0.0:
			f["acc"] += delta
			if f["acc"] >= step:
				for h: Dictionary in f["hens"]:
					if not h["inside"]:
						_step(h["a"].anim, [], f["acc"])
				f["acc"] = 0.0
	if f.has("door"):
		var hr := hour()
		if absf(hr - float(f.get("last_h", hr))) > 0.2:
			_coop_snap(f)
		f["last_h"] = hr
	for h: Dictionary in f["hens"]:
		var a: FarmAnimal = h["a"]
		if f.has("door") and _coop_walk(f, h, a, delta):
			continue
		var to: Vector3 = h["goal"] - a.position
		to.y = 0
		if to.length() > 0.12:
			var home: bool = f.has("door") and h["goal"] == f["door"]
			var run: bool = (h["eat"] > 0.0 or home) and to.length() > 0.8
			var sp: float = FarmAnimal.SPEED.get(h["kind"], FarmAnimal.SPEED["ga_mai"])["Run" if run else "Walk"]
			var p: Vector3 = a.position + to.normalized() * minf(sp * delta, to.length())
			p.y = ground.call(p.x, p.z)
			a.position = p
			a.rotation.y = lerp_angle(a.rotation.y, atan2(to.x, to.z), 1.0 - exp(-delta * 8.0))
			a.play("Run" if run else "Walk")
			continue
		if h["eat"] > 0.0:
			h["eat"] -= delta
			a.play("Peck")
			continue
		h["wait"] -= delta
		if h["wait"] > 0.0 or (f.has("door") and hour() >= ROOST + h["late"]):
			if a._loop == "Walk" or a._loop == "Run":
				a.play("Peck" if randf() < 0.5 else "Idle")
			continue
		if raining() and f.has("door"):
			var g: Vector3 = f["door"] + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
			g.y = ground.call(g.x, g.z)
			h["goal"] = g
		else:
			h["goal"] = _in_yard(f, randf(), randf())
		h["wait"] = randf_range(2.0, 6.0)

func _coop_walk(f: Dictionary, h: Dictionary, a: FarmAnimal, delta: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var path: Curve3D = f["path"]
	var length := path.get_baked_length()
	var climb: int = h.get("climb", 0)
	if climb != 0:
		var sp: float = FarmAnimal.SPEED.get(h["kind"], FarmAnimal.SPEED["ga_mai"])["Walk"] * 0.85
		h["s"] = clampf(float(h["s"]) + climb * sp * delta, 0.0, length)
		var p := path.sample_baked(h["s"])
		var ahead := path.sample_baked(clampf(float(h["s"]) + climb * 0.06, 0.0, length))
		var d := ahead - p
		if Vector2(d.x, d.z).length() > 0.005:
			a.rotation.y = lerp_angle(a.rotation.y, atan2(d.x, d.z), 1.0 - exp(-delta * 10.0))
		a.position = p
		h["flap"] = float(h.get("flap", 0.0)) - delta
		if h["flap"] <= 0.0:
			a.play("Walk")
		if climb > 0 and h["s"] >= length:
			h["climb"] = 0
			h["inside"] = true
			a.visible = false
		elif climb < 0 and h["s"] <= 0.0:
			h["climb"] = 0
			h["goal"] = _in_yard(f, randf(), randf())
			h["wait"] = 0.0
		return true
	var q: Array = f["queue"]
	if hour() >= ROOST + h["late"]:
		if h["inside"]:
			return true
		h["eat"] = 0.0
		if not q.has(h):
			q.append(h)
		var i := q.find(h)
		var spot: Vector3 = f["door"] + f["fwd"] * (COOP_QUEUE * i)
		spot.y = ground.call(spot.x, spot.z)
		h["goal"] = spot
		if i == 0 and a.position.distance_to(f["door"]) < 0.15 and now >= float(f["free_at"]):
			q.remove_at(0)
			h["climb"] = 1
			h["s"] = 0.0
			f["free_at"] = now + COOP_GAP
			if a.anim.has_animation("Flap"):
				a.play("Flap", 0.1)
				h["flap"] = 0.45
		return false
	q.erase(h)
	if h["inside"]:
		if now < float(f["free_at"]):
			return true
		f["free_at"] = now + COOP_GAP
		h["inside"] = false
		h["climb"] = -1
		h["s"] = length
		a.position = path.sample_baked(length)
		a.visible = f["shown"]
		return true
	return false

func _coop_snap(f: Dictionary) -> void:
	f["queue"].clear()
	f["free_at"] = 0.0
	for h: Dictionary in f["hens"]:
		var a: FarmAnimal = h["a"]
		h["climb"] = 0
		if hour() >= ROOST + h["late"]:
			h["inside"] = true
			a.visible = false
		elif h["inside"]:
			h["inside"] = false
			a.visible = f["shown"]
			a.position = _in_yard(f, randf(), randf())
			h["goal"] = a.position
			h["wait"] = 0.0

func _rate(d: float) -> float:
	"""Seconds between animation steps at distance d (0: every frame)."""
	return SLOW_STEP if d > SLOW_AT else MID_STEP if d > MID_AT else 0.0

func _set_slow(anim: AnimationMixer, skels: Array, slow: bool) -> void:
	"""Stepped: the clip and the skeletons' modifiers only move when _step says (_rate); else every frame."""
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if slow \
		else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	for sk in skels:
		if sk != null and is_instance_valid(sk):
			(sk as Skeleton3D).modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL if slow \
				else Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE

func _step(anim: AnimationMixer, skels: Array, dt: float) -> void:
	anim.advance(dt)
	for sk in skels:
		if sk != null and is_instance_valid(sk):
			(sk as Skeleton3D).advance(dt)

func _details(c: Chibi) -> void:
	"""The small parts end at DETAIL_END (set before the hometown's _cull_small gives every small thing 45 m)."""
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		var small := n in DETAIL or DETAIL_PREFIX.any(func(pre: String) -> bool: return n.begins_with(pre))
		if small or DETAIL_SUFFIX.any(func(suf: String) -> bool: return n.ends_with(suf)):
			mi.visibility_range_end = DETAIL_END

func _shadows(c: Chibi, near: bool) -> void:
	"""Which of a person's parts cast a shadow (see NO_SHADOW): near, all but the small ones inside the head's
	shadow; far, only the body, the head and the hair."""
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		var cast := not (n in NO_SHADOW or NO_SHADOW_PREFIX.any(func(pre: String) -> bool: return n.begins_with(pre)))
		if cast and not near:
			cast = n in FAR_SHADOW or n.begins_with("Hair_") or n.begins_with("Merged_")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _clocked() -> bool:
	"""Whether the shared Clock (scripts/home/clock.gd) is running here: it is ticked only by HomeEvents, which
	the hometown adds next to this (--events). Looked up once, on the first frame (it is added after us)."""
	if _clock_owner == null:
		_clock_owner = false
		for n in get_parent().get_children():
			if n is HomeEvents:
				_clock_owner = true
	return _clock_owner

func _row(spec: Dictionary, h: float) -> Array:
	"""The plan's row in force at hour h (before the first row: the last one, from the night before)."""
	var plan: Array = spec["plan"]
	var row: Array = plan[-1]
	for r in plan:
		if h >= float(r[0]):
			row = r
	return row

func _until(spec: Dictionary, h: float) -> float:
	"""The hour the row in force at h ends."""
	for r in spec["plan"]:
		if float(r[0]) > h:
			return float(r[0])
	return 22.0

func _mood(spec: Dictionary) -> String:
	if event != "" and data.get("event_mood", {}).has(event):
		return data["event_mood"][event]
	if weather != "" and data.get("weather_mood", {}).has(weather):
		return data["weather_mood"][weather]
	var m := "binh_thuong"
	for r in spec.get("moods", []):
		if hour() >= float(r[0]):
			m = r[1]
	return m

func _spot(spec: Dictionary, name: String) -> Array:
	"""[world position, yaw] of a spot: given in its anchor's frame (the quán, the house), so it follows the map."""
	if ":" in name and people.has(name.get_slice(":", 0)):
		return _spot(people[name.get_slice(":", 0)]["spec"], name.get_slice(":", 1))
	var s: Array = spec["spots"][name]
	var anchor := _anchor(spec)
	var at: Vector3 = anchor[0] + Basis(Vector3.UP, anchor[1]) * Vector3(s[0], 0, s[1])
	var up := float(s[3]) if s.size() > 3 else 0.0
	at.y = ground.call(at.x, at.z) + up
	return [at, anchor[1] + deg_to_rad(float(s[2]))]

func _anchor(spec: Dictionary) -> Array:
	"""[position, yaw] of the place or house a person's spots hang off (none: the world's origin)."""
	if spec.has("_anchor"):
		return spec["_anchor"]
	var a: Dictionary = spec.get("anchor", {})
	var res := [Vector3.ZERO, 0.0]
	if a.has("place"):
		for pl: Dictionary in layout.get("places", []):
			if pl.get("id", "") == a["place"]:
				res = [Vector3(pl["x"], 0, pl["z"]), deg_to_rad(float(pl.get("yaw", 0.0)))]
	elif a.has("house_near"):
		var near := Vector2(a["house_near"][0], a["house_near"][1])
		var best := INF
		for h: Array in layout.get("dress", {}).get("houses", []):
			var d := Vector2(h[0], h[1]).distance_to(near)
			if d < best:
				best = d
				res = [Vector3(h[0], 0, h[1]), deg_to_rad(float(h[2]))]
	spec["_anchor"] = res
	return res

func _live(id: String) -> void:
	"""The person's day, for ever: the row in force, done until its hour is up, then the next."""
	var p: Dictionary = people[id]
	var c: Chibi = p["chibi"]
	var spec: Dictionary = p["spec"]
	await get_tree().create_timer(randf_range(0.0, 1.5)).timeout
	while is_inside_tree():
		if _at_home_hours(spec):
			if not p.get("home", false):
				await _go_home(id)
			await get_tree().process_frame
			continue
		if p.get("home", false):
			await _come_out(id)
		var row := _row(spec, hour())
		var end := _until(spec, hour())
		var wet := raining()
		var alive := func() -> bool: return is_inside_tree() and _row(spec, hour()) == row and not p.get("talking", false) \
				and raining() == wet and not _at_home_hours(spec)
		if log_on:
			print("village %05.2f %s: %s at %s (mood %s) from %s" % [hour(), id, row[1], row[2], MoodLayer.mood_of(c), c.global_position])
		var job := "shelter" if wet and String(row[1]) != "rest" else String(row[1])
		if wet and c.tool == "umbrella" and job != "shelter":
			c.close_umbrella()
		if not wet and c.tool == "umbrella":
			c.close_umbrella()
			await get_tree().create_timer(0.6).timeout
			c.hold("")
		p["job"] = job
		match job:
			"chat":
				await _chat(id, row[2], alive)
			"shelter":
				await _shelter(c, spec, alive)
			"sweep":
				await _sweep(c, spec, row[2], alive)
			"water":
				await _water(c, spec, row[2], alive)
			"feed":
				await _feed(c, spec, row[2], alive)
			"rake":
				await _rake(c, spec, row[2], alive)
			"rest":
				await _rest(c, spec, row[2], alive)
			_:
				await _stand(c, spec, row[2], alive)
		while p.get("talking", false):
			await get_tree().process_frame
		if hour() < end and _row(spec, hour()) == row:
			await get_tree().process_frame

func _sweep(c: Chibi, spec: Dictionary, spot: String, alive: Callable) -> void:
	"""A few strokes, a short stand, a step on along the yard (back and forth round the spot)."""
	var at := _spot(spec, spot)
	Chores.pick_up(c, "choi_tre")
	await _walk(c, at[0], at[1], alive)
	var side := 1.0
	while alive.call():
		if not await Chores.run(c, "sweep", randi_range(3, 5), alive):
			return
		if not await Chores.idle(c, randf_range(6.0, 14.0), alive):
			return
		Chores.pick_up(c, "choi_tre")
		var step := Basis(Vector3.UP, at[1]) * Vector3(side * randf_range(0.5, 0.9), 0, randf_range(-0.3, 0.3))
		side = -side
		var to: Vector3 = at[0] + step
		to.y = ground.call(to.x, to.z)
		if not await _walk(c, to, at[1], alive):
			return

func _water(c: Chibi, spec: Dictionary, spot: String, alive: Callable) -> void:
	var at := _spot(spec, spot)
	Chores.pick_up(c, "binh_tuoi")
	await _walk(c, at[0], at[1], alive)
	var side := 1.0
	while alive.call():
		if not await Chores.run(c, "water", 2, alive):
			return
		var step := Basis(Vector3.UP, at[1]) * Vector3(side * 0.7, 0, 0)
		side = -side
		var to: Vector3 = at[0] + step
		to.y = ground.call(to.x, to.z)
		if not await _walk(c, to, at[1], alive):
			return
		if not await Chores.idle(c, randf_range(4.0, 8.0), alive):
			return
		Chores.pick_up(c, "binh_tuoi")

func _feed(c: Chibi, spec: Dictionary, spot: String, alive: Callable) -> void:
	"""Grain for the hens, once, then standing by watching them peck till the next job."""
	var at := _spot(spec, spot)
	Chores.pick_up(c, "ro_thoc")
	await _walk(c, at[0], at[1], alive)
	if not await Chores.run(c, "feed", 1, alive, feed):
		return
	while alive.call():
		if not await Chores.idle(c, randf_range(20.0, 30.0), alive):
			return

func _stand(c: Chibi, spec: Dictionary, spot: String, alive: Callable) -> void:
	var at := _spot(spec, spot)
	await _walk(c, at[0], at[1], alive)
	while alive.call():
		if not await Chores.idle(c, randf_range(25.0, 40.0), alive):
			return

func _rest(c: Chibi, spec: Dictionary, spot: String, alive: Callable) -> void:
	"""The noon rest: sat on the ground (the hiên, the quán's mat), the tool laid down."""
	var at := _spot(spec, spot)
	await _walk(c, at[0], at[1], alive)
	Chores.put_down(c)
	c.play("Act_SitFloor", 0.3)
	while alive.call():
		await get_tree().process_frame
	c.play("Base_Wait", 0.3)

func _walk(c: Chibi, to: Vector3, yaw: float, alive: Callable, fetch := true) -> bool:
	"""Walk to `to` over the ground - round walls and houses along the village's navigation map when it is baked
	and the way is longer than a few steps - then turn to `yaw` (fetch: pick up the tool laid down first)."""
	var d := to - c.global_position
	d.y = 0.0
	if d.length() > 0.05:
		if fetch and c.has_meta("laid_tool"):
			Chores.pick_up(c, String(c.get_meta("laid_name", "")))
		var legs := [to]
		if d.length() > 2.5 and nav_map.is_valid():
			var path := NavigationServer3D.map_get_path(nav_map, c.global_position, to, true)
			if path.size() > 2 and Vector2(path[-1].x, path[-1].z).distance_to(Vector2(to.x, to.z)) < 1.5:
				legs = Array(path.slice(1, path.size() - 1)) + [to]
		c.play("Move_Walk", 0.2)
		var up1: float = to.y - ground.call(to.x, to.z)
		for li in legs.size():
			var leg: Vector3 = legs[li]
			var from := c.global_position
			var dd := leg - from
			dd.y = 0.0
			if dd.length() < 0.02:
				continue
			c.rotation.y = atan2(dd.x, dd.z)
			var up0: float = from.y - ground.call(from.x, from.z)
			var last := li == legs.size() - 1
			var secs := dd.length() / WALK_SPEED
			var t := 0.0
			while t < secs:
				await get_tree().process_frame
				if not alive.call():
					return false
				t += get_process_delta_time()
				var k := minf(t / secs, 1.0)
				var p := from.lerp(leg, k)
				p.y = ground.call(p.x, p.z) + lerpf(up0, up1 if last else 0.0, k)
				c.global_position = p
	var tw := c.create_tween()
	tw.tween_property(c, "rotation:y", c.rotation.y + wrapf(yaw - c.rotation.y, -PI, PI), 0.35)
	c.play("Base_Wait", 0.2)
	await tw.finished
	return alive.call()

func _exit_tree() -> void:
	if nav_map.is_valid():
		NavigationServer3D.free_rid(nav_map)
