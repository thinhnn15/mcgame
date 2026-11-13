extends Node3D

const SAVE := "user://save/farm_plot.json"
const BEDS := [[-5, -3, 6], [-2, -3, 6], [1, -3, 6], [4, -3, 6]]
const TOOLS := [["hoe", "FARM_TOOL_HOE"], ["tui_hat", "FARM_TOOL_SEED"], ["binh_tuoi", "FARM_TOOL_WATER"],
	["ro_thoc", "FARM_TOOL_GRAIN"], ["gio_trung", "FARM_TOOL_BASKET"], ["rod", "FARM_TOOL_ROD"]]
const REACH := 0.7
const YARD := Rect2(3.6, -2.6, 3.4, 3.8)
const NEST := Vector3(4.2, 0, -2.2)
const FEEDER := Vector3(4.4, 0, 0.6)
const CHONG := Vector3(-4.3, 0, -2.4)
const CAM_OFF := Vector3(0, 5.2, 6.2)

const CAM_ZOOM := [0.62, 1.75]
const CAM_TURN := 1.7
const COOP_DOOR := Vector3(5.15, 0, -2.0)

const COOP_PATH := [Vector3(5.48, 0.0, -2.0), Vector3(5.87, 0.38, -2.0), Vector3(6.08, 0.38, -2.0)]
const COOP_GAP := 0.8
const ROOST := 18.5
const HOE_STROKES := {1: 2, 2: 1, 3: 1}
const CAN_HOLDS := {1: 3, 2: 15, 3: 30}

const AREA := {1: 1, 2: 3, 3: 5}
const HEN_CAP := 6
const DUCK_HOUSE := Vector3(12.4, 0, -1.25)
const RO := Vector3(-2.2, 0, 3.7)
const BOARD := Vector3(-0.8, 0, 4.5)
const PRICES := "res://data/farm/prices.json"
const COOP_SIDE := Vector3(6.0, 0, -0.75)
const PEN_LAND := Rect2(-4.6, -8.0, 13.2, 13.6)
const PEN_FLAT := Rect2(-10.0, -8.5, 19.5, 13.5)
const HOUSE_AT := Vector3(-1.0, 0, -8.5)

const LANE := Vector3(-13.0, 0, 8.4)

var land: FarmLand
var scenery: FarmScenery
var rain: FarmRain
var fish: FishSchool
var raining := false
var stormy := false
var _roof_rain = null
var player: Player
var cam: Camera3D
var hud: FarmHud
var sun: DirectionalLight3D
var env: Environment
var dry := false
var seeds: Array = []
var _weather_min := -1
var bag := {}
var eggs := 0
var intro_done := false
var tool_i := 0
var _last_tool := 0
var seed_i := 0
var hens := []
var cock := {}
var brood: FarmBrood
var pets: FarmPets
var touch: FarmTouch
var wild: FarmWild
var bank: FarmBank
var tiers := {"cuoc": 1, "binh_tuoi": 1}
var water_left := 3
var fish_used := 0
var seen := {}
var _fish_n0 := 0
var _hits := {}
var _hoe_told := false
var _pets_saved := {}
var _touch_saved := {}
var _grain_was := false
var prices := {}
var seed_n := {}
var ro := {}
var _dry_owed := 0
var _shop_rows := []
var _shop_i := 0
var _hint_key := "FARM_HINT"
var _hint_touch := false
var book: CanvasLayer
var _book_pages := []
var _book_i := 0
var care := {}
var demo_view := []
var _egg_nodes := []
var _cursor: MeshInstance3D
var _busy := false

var cam_yaw := 0.0
var cam_zoom := 1.0
var _cam_zoom_now := 1.0
var _mouse_aim := false
var _click_go := 0
var _click_cell := Vector2i(-999, -999)
var house: FarmHouse
var _sleeping := false
var _night_bugs := []
var _still := []
var pens: FarmPens
var tea: FarmTea
var trau: FarmBuffalo
var days: FarmDays
var bees: FarmBees
var place: FarmPlace = null
var _pens_saved := []
var _pen_kho := {}
var cutscene: FarmCutscene = null
var _coop_path: Curve3D = null
var _coop_free := 0.0
var _cluck_t := 3.0
var _dig_at := Vector2i(-999, -999)
var _dig_t := 0.0
var ducks: DuckHouse = null
var _hens_more := 0
var _t := 0.0
var _frames := 0

func _ready() -> void:
	sun = Stage.setup(self)
	Stage.clouds(true)
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	env = we.environment if we else null
	var args := OS.get_cmdline_user_args()
	dry = args.has("--auto") or args.has("--fishing") or args.has("--hawk") or args.has("--duck") \
		or args.has("--cat") or args.has("--dog") or args.has("--week") or args.has("--book") or args.has("--pens") 		or args.has("--pens-demo") or args.has("--bees-demo") or args.has("--harvest-demo") \
		or args.has("--pets-test")
	Clock.load_saved()
	Progress.load_saved()
	var ds := Stage.arg("--day-secs")
	if ds != "":
		Clock.speed = (Clock.NOD_OFF - Clock.DAWN) / float(ds)
	_refresh_seeds()
	_build_world()
	land = FarmLand.new()
	add_child(land)
	land.setup(BEDS, "co")
	rain = FarmRain.new()
	add_child(rain)
	rain.build(env)
	rain.thunder.connect(_on_thunder)
	cam = Camera3D.new()
	cam.fov = 34.0
	add_child(cam)
	player = Player.new()
	add_child(player)
	player.position = Vector3(0, 0, 3.0)
	player.rotation.y = PI
	player.facing = PI
	player.bounds_box = 33.0
	player.setup(Looks.load_saved(), cam)
	if String(Story.flag("spawn_at", "")) == "farm_house":
		Story.set_flag("spawn_at", "")
		player.position = HOUSE_AT + FarmHouse.DOOR + Vector3(0, FarmHouse.PORCH_H, 0.9)
		player.rotation.y = 0.0
		player.facing = 0.0
	if String(Story.flag("spawn_at", "")) == "farm_lane":
		Story.set_flag("spawn_at", "")
		var into := (Vector3(-6.0, 0, FarmScenery.DITCH_Z) - LANE).normalized()
		player.position = LANE + into * 1.2
		player.rotation.y = atan2(into.x, into.z)
		player.facing = player.rotation.y
	rain.cam = cam
	fish.scarer = player
	Sound.hero = player
	player.tool_pressed.connect(_act)
	player.emote_keys = false
	hud = FarmHud.new()
	PerfHud.add(self)
	days = FarmDays.add(self)
	bank = FarmBank.add(self)

	MiniMap.add(self, player, {"tex": "res://data/farm/mini_map.png", "world": float(FarmScenery.SIZE), "radii": [13.0, 36.0],
		"top": 66.0, "homes": [Vector2(HOUSE_AT.x, HOUSE_AT.z)]})
	tea = FarmTea.add(self)
	trau = FarmBuffalo.add(self)
	hud.tool_tapped.connect(_tap_tool)
	hud.shop_tapped.connect(_tap_shop)
	hud.shop_closed.connect(_shop_close)
	add_child(hud)
	_cursor = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(0.36, 0.36)
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.albedo_color = Color(1, 1, 0.92, 0.45)
	q.material = cm
	_cursor.mesh = q
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cursor)
	for i in 3:
		var a := FarmAnimal.spawn(self, "ga_mai", Vector3(YARD.position.x + 0.8 + i * 0.9, 0, YARD.position.y + 1.5 + i * 0.5), randf() * TAU)
		hens.append({"a": a, "goal": a.position, "wait": randf_range(0.5, 3.0), "fed": false, "eat": 0.0,
			"inside": false, "late": randf_range(0.0, 0.4)})

	var r := FarmAnimal.spawn(self, "ga_trong", Vector3(YARD.position.x + 1.6, 0, YARD.position.y + 2.6), randf() * TAU)
	cock = {"a": r, "goal": r.position, "wait": randf_range(0.5, 3.0), "fed": false, "eat": 0.0, "inside": false, "late": 0.45}
	for i in 4:
		var b := FarmAnimal.spawn(self, "dom_dom", Vector3(-6.5 + randf() * 2.5, 0.5 + randf() * 0.6, -1.5 + randf() * 3.0), randf() * TAU)
		b.visible = false
		b.play.call_deferred("Fly")
		_night_bugs.append(b)
	brood = FarmBrood.new()
	add_child(brood)
	brood.setup(self)
	brood.force = args.has("--brood")
	pets = FarmPets.new()
	add_child(pets)
	pets.setup(self, dry)
	touch = FarmTouch.add(self)
	wild = FarmWild.add(self)
	FishLog.load_saved()
	_fish_n0 = _fish_total()
	prices = JSON.parse_string(FileAccess.get_file_as_string(PRICES))
	for k in prices["start_seeds"]:
		seed_n[k] = int(prices["start_seeds"][k])
	_build_market()
	SoTay.dry = dry
	book = SoTay.panel(self)
	if "--fresh" not in OS.get_cmdline_user_args():
		_load()
	if not dry:
		_home_work_sync()
	_grant_tools.call_deferred()
	pets.from_dict(_pets_saved)
	touch.from_dict(_touch_saved)
	pens = FarmPens.new()
	add_child(pens)
	pens.setup(scenery, PEN_LAND, _pen_blockers(), scenery.paths, player)
	pens.from_dict(_pens_saved)
	if not dry:
		_pen_work_sync()
	bees = FarmBees.new()
	add_child(bees)
	bees.setup(self)
	_grant_hives(false)
	if "--pens" in OS.get_cmdline_user_args():
		_pen_kho = {"chuong_lon": 2, "chuong_bo": 1, "coc_bo": 2}
	elif "--pens-demo" in OS.get_cmdline_user_args():
		_pen_kho = {"coc_bo": 1}
		for row in [["chuong_bo", Vector2(1.0, -6.0)], ["chuong_lon", Vector2(5.5, -6.0)],
				["chuong_lon", Vector2(-3.0, -6.0)], ["coc_bo", Vector2(3.2, 4.3)]]:
			pens.add(row[0], FarmPens.cell_for(row[0], 0, row[1]), 0)
	if "--bees-demo" in OS.get_cmdline_user_args():
		_bees_demo()
	_ensure_place()
	_refresh_seeds()
	if Stage.arg("--hour") != "":
		intro_done = true
	var hawk_now := "--hawk" in OS.get_cmdline_user_args()
	var duck_now := "--duck" in OS.get_cmdline_user_args()
	var cat_now := "--cat" in OS.get_cmdline_user_args()
	var dog_now := "--dog" in OS.get_cmdline_user_args()
	if hawk_now or duck_now or cat_now or dog_now:
		intro_done = true
	_todays_weather()
	_apply_weather()
	fish.reset(FishTable.stock("ao", _fish_ctx()))
	var rod := FishingRod.attach(self, player, fish, _fish_ctx)
	_pick_tool(0)
	if "--fishing" in OS.get_cmdline_user_args():
		intro_done = true
		player.position = Vector3(FarmScenery.POND_C.x - FarmScenery.POND_R.x - 0.45, 0, FarmScenery.POND_C.y)
		player.rotation.y = PI / 2
		player.facing = PI / 2
		_pick_tool(TOOLS.size() - 1)
		rod.auto = true
	if not dry:
		Progress.add_on_open(_opened)
	_hint_touch = TouchControls.active
	hud.set_hint(tr("FARM_HINT_TOUCH" if _hint_touch else "FARM_HINT"))
	_show_eggs()
	_update_bag()
	_update_skills()
	_place_camera(1.0)
	_still = Stage.still_args()
	if "--stats" in OS.get_cmdline_user_args():
		_stats.call_deferred()
	if hawk_now:
		_hawk.call_deferred()
	elif duck_now:
		_cutscene.call_deferred(DuckScene.new(), "FARM_T_DUCK_DONE")
	elif cat_now:
		_cutscene.call_deferred(CatScene.new(), "FARM_T_CAT_DONE")
	elif dog_now:
		_cutscene.call_deferred(DogScene.new(), "FARM_T_DOG_DONE")
	elif "--auto" in OS.get_cmdline_user_args():
		_demo.call_deferred()
	elif "--week" in OS.get_cmdline_user_args():
		_week.call_deferred()
	elif "--harvest-demo" in OS.get_cmdline_user_args():
		_harvest_demo.call_deferred()
	elif "--book" in OS.get_cmdline_user_args():
		var id := Stage.arg("--book") if Stage.arg("--book") not in ["", "--fresh"] and not Stage.arg("--book").begins_with("-") else "dat_co"
		SoTay.write(id)
		_book_pages = SoTay.chapter_pages(Clock.chapter())
		player.controls = false
		_book_i = maxi(0, _book_pages.map(func(p: Dictionary) -> String: return p["id"]).find(id))
		SoTay.show(book, _book_pages, _book_i)
	elif not intro_done and Stage.arg("--hour") == "":
		_intro.call_deferred()

func _build_world() -> void:
	scenery = FarmScenery.new()
	if "--pens" in OS.get_cmdline_user_args() or "--pens-demo" in OS.get_cmdline_user_args():
		scenery.flat = PEN_FLAT
	FarmYard.prepare(scenery)
	FarmFields.prepare(scenery)
	add_child(scenery)
	scenery.build(env)

	fish = FishSchool.make(self, FarmScenery.POND_C, FarmScenery.POND_R, FarmScenery.WATER_Y, scenery.height_at, [])

	Water.add(self, FarmScenery.WATER_Y, scenery.height_at, func(x: float, z: float) -> bool: return FarmScenery.pond_e(x, z) < 1.3 and not FarmScenery.on_deck(x, z))
	Water.add(self, FarmScenery.WATER_Y, scenery.height_at, func(x: float, z: float) -> bool: return absf(z - FarmScenery.DITCH_Z) < 0.8 and not FarmScenery.on_deck(x, z))

	HomeKit.place(self, "chuong_ga", Vector3(6.0, 0, -2.0), -90.0)
	_block(Vector3(6.0, 0.6, -2.0), Vector3(1.4, 1.2, 1.6))
	Furniture.place(self, "o_de_trung", NEST, 0.0)
	Furniture.place(self, "mang_ga", FEEDER, 90.0)
	_chong()

	var ha := HOUSE_AT
	ha.y = scenery.height_at(ha.x, ha.z + FarmHouse.DOOR.z)
	house = FarmHouse.add(self, ha)
	scenery.add_deck(house.transform, Vector2(0.0, (0.9 + FarmHouse.PORCH_Z) / 2), Vector2(FarmHouse.PORCH_X, (FarmHouse.PORCH_Z - 0.9) / 2),
		ha.y + FarmHouse.PORCH_H, FarmHouse.PORCH_RUN)
	FarmYard.build(self, scenery)
	FarmFields.build(self, scenery)

	var vh := DUCK_HOUSE
	vh.y = scenery.height_at(vh.x, vh.z)
	Furniture.place(self, "chuong_vit", vh, 0.0, false)
	_block(vh + Vector3(0, 0.42, -0.05), Vector3(1.24, 0.85, 1.1))

	ducks = DuckHouse.add(self, vh, 0.0, FarmScenery.WATER_Y, FarmScenery.POND_C, FarmScenery.POND_R)

	var stakes := []
	for i in 9:
		if i < 2:
			continue
		stakes.append(Transform3D(Basis(), Vector3(-4.9, 0, -2.6 + i * 0.7)))
	HomeKit._batch(self, "coc_tre", stakes)

	var wild := FarmLand.new()
	add_child(wild)
	wild.setup([[-20, -3, 6], [-17, -3, 6], [-14, -3, 6]], "co")
	var sign_ := Label3D.new()
	sign_.text = tr("FARM_SIGN_KHU2")
	sign_.font_size = 56
	sign_.pixel_size = 0.004
	sign_.modulate = Color("5b4a44")
	sign_.outline_modulate = Color("fff6e6")
	sign_.outline_size = 12
	sign_.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_.position = Vector3(-5.4, 1.1, 1.8)
	add_child(sign_)

func _pen_blockers() -> Array:
	return [[Rect2(-2.6, -1.6, 5.2, 3.2), "PEN_BAD_BED"], [Rect2(3.4, -3.0, 3.8, 4.4), "PEN_BAD_COOP"],
		[Rect2(CHONG.x - 1.3, CHONG.z - 1.0, 2.6, 2.2), "PEN_BAD_THING"],
		[Rect2(RO.x - 0.6, RO.z - 0.6, 1.2, 1.2), "PEN_BAD_THING"],
		[Rect2(BOARD.x - 0.7, BOARD.z - 0.5, 1.4, 1.0), "PEN_BAD_THING"],
		[Rect2(7.2, -6.8, 1.6, 1.6), "PEN_BAD_TREE"],
		[house.footprint() if house != null else Rect2(), "PEN_BAD_THING"]] + FarmYard.blockers() + FarmFields.blockers()

func _block(at: Vector3, size: Vector3) -> void:
	var b := BoxShape3D.new()
	b.size = size
	Props.solid(self, b, at)

func _chong() -> void:

	var at := CHONG
	at.y = scenery.height_at(CHONG.x, CHONG.z)
	Furniture.place(self, "chong_tre", at, 0.0, false)
	_block(CHONG + Vector3(0, 0.25, 0), Vector3(1.9, 0.5, 0.95))

func _pick_tool(i: int) -> void:
	tool_i = posmod(i, TOOLS.size())
	_last_tool = tool_i
	player.chibi.hold(TOOLS[tool_i][0])
	_tool_names()

func _stow() -> void:
	if tool_i >= 0:
		tool_i = -1
		player.chibi.hold("")
		Sound.play_at("bag.put", player.global_position + Vector3(0, 0.8, 0))
		_tool_names()
	else:
		_pick_tool(_last_tool)

func _tool_id() -> String:
	return TOOLS[tool_i][0] if tool_i >= 0 else ""

func _tool_names() -> void:
	var rows := []
	for t in TOOLS:
		var id: String = t[0]
		var tier := int(tiers.get({"hoe": "cuoc"}.get(id, id), 1))
		var row := {"icon": _icon("tools", "%s_%d" % [id, tier]) if tier > 1 and _icon("tools", "%s_%d" % [id, tier]) \
				else _icon("tools", id), "name": tr(t[1])}
		if id == "tui_hat":
			var has := not seeds.is_empty()
			row["name"] = tr(t[1]) % (_seed_name(seeds[seed_i]) if has else "–")
			row["count"] = int(seed_n[seeds[seed_i]]) if has else 0
			row["badge"] = _icon("crops", seeds[seed_i]) if has else null
			row["dim"] = not has
		elif id == "binh_tuoi":
			row["water"] = Vector2i(water_left, CAN_HOLDS[tier])
			row["dim"] = water_left == 0
		rows.append(row)
	hud.set_tools(rows, tool_i)

static var _icons := {}

func _icon(group: String, id: String) -> Texture2D:
	var path := "res://ui/icons/%s/%s.svg" % [group, id]
	if not _icons.has(path):
		_icons[path] = load(path) if ResourceLoader.exists(path) else null
	return _icons[path]

func _refresh_seeds() -> void:
	var cur: String = seeds[seed_i] if seed_i < seeds.size() else ""
	seeds = []
	for row in Progress.unlocks().get("items", []):
		if row["type"] != "seed" or not Crops.table().has(row["id"]) or not Progress.met(row["unlock"]):
			continue
		var cr: Dictionary = Crops.table()[row["id"]]
		if int(cr["footprint"][0]) == 1 and int(cr["footprint"][1]) == 1 and cr["trellis"] == null \
				and int(seed_n.get(row["id"], 0)) > 0:
			seeds.append(row["id"])
	seed_i = maxi(0, seeds.find(cur))
	if hud:
		_tool_names()

func _seed_name(id: String) -> String:
	var key: String = Crops.table()[id]["name"]
	if tr(key) != key:
		return tr(key)
	for row in Progress.unlocks()["items"]:
		if row["id"] == id:
			return str(row["vi"]).get_slice(" (", 0)
	return id

func _xp(action: String) -> void:
	if dry:
		return
	var sk: String = Progress.skill_of(action)
	var before := Progress.level(sk) if sk != "" else 0
	Progress.act(action)
	_update_skills()
	if sk != "" and Progress.level(sk) > before:
		hud.toast(tr("FARM_T_LEVEL") % [tr(str(Progress.skills()["skills"][sk]["name"])), Progress.level(sk)], 3.0)
		if sk == "chan_nuoi":
			_grant_hives(true)
		if sk == "lam_ruong":
			_grant_tools()

func _upgrade(tool: String, tier: int, line: String) -> void:
	if int(tiers.get(tool, 1)) >= tier:
		return
	tiers[tool] = tier
	if tool == "binh_tuoi":
		water_left = int(CAN_HOLDS[tier])
	_tool_names()
	hud.toast(line, 4.0)
	Sound.play("ui.click")
	if not dry:
		_save()

func _grant_tools() -> void:
	for gid: String in prices.get("gifts", {}):
		var g: Dictionary = prices["gifts"][gid]
		for row in Progress.unlocks().get("items", []):
			if row["id"] == gid and Progress.met(row["unlock"]) and int(tiers.get(g["tool"], 1)) < int(g["tier"]):
				_upgrade(str(g["tool"]), int(g["tier"]), tr("FARM_T_GIFT_" + gid.to_upper()))

func _opened(row: Dictionary) -> void:
	hud.toast(tr("EV_OPENED") % str(row.get("vi", row["id"])).get_slice(" (", 0), 4.0)
	if row["type"] == "seed":
		_refresh_seeds()

func _exit_tree() -> void:
	Progress.remove_on_open(_opened)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if land != null and not _sleeping:
			_save()

func _todays_weather() -> bool:
	var args := OS.get_cmdline_user_args()
	var was := [raining, stormy]
	raining = Clock.raining()
	stormy = Clock.weather == "giong"
	if args.has("--rain") or args.has("--storm"):
		raining = true
		stormy = args.has("--storm")
	elif args.has("--sun"):
		raining = false
		stormy = false
	return was != [raining, stormy]

func _unhandled_input(e: InputEvent) -> void:
	if book.visible:
		_book_input(e)
		return
	if (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_J) 			or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_Y):
		if player.controls and not _busy and _shop_rows.is_empty():
			_book_pages = SoTay.chapter_pages(Clock.chapter())
			_book_i = 0
			player.controls = false
			SoTay.show(book, _book_pages, _book_i)
			get_viewport().set_input_as_handled()
			return
	if not _shop_rows.is_empty():
		_shop_input(e)
		return
	if days.menu_input(e):
		return
	if not player.controls or _busy:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] 			and not (place and place.active):
		cam_zoom = clampf(cam_zoom * (0.9 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.9), CAM_ZOOM[0], CAM_ZOOM[1])
		get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseMotion and not TouchControls.active:
		_mouse_aim = true
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not TouchControls.active:
		_mouse_aim = true
		var mc := _mouse_cell(e.position)
		if mc.x > -900 and _aim_tool():
			get_viewport().set_input_as_handled()
			_act_at(mc)
			return
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		if k >= KEY_1 and k < KEY_1 + TOOLS.size():
			var i := k - KEY_1
			if i == tool_i and TOOLS[i][0] == "tui_hat":
				seed_i = (seed_i + 1) % maxi(1, seeds.size())
				_tool_names()
			elif i == tool_i:
				_stow()
			else:
				_pick_tool(i)
		elif k == KEY_TAB:
			_pick_tool((tool_i if tool_i >= 0 else _last_tool - 1) + 1)
		elif k == KEY_X:
			_stow()
	elif e is InputEventJoypadButton and e.pressed:
		if e.button_index == JOY_BUTTON_DPAD_RIGHT:
			_pick_tool((tool_i if tool_i >= 0 else _last_tool - 1) + 1)
		elif e.button_index == JOY_BUTTON_DPAD_LEFT:
			_pick_tool((tool_i if tool_i >= 0 else _last_tool + 1) - 1)
		elif e.button_index == JOY_BUTTON_DPAD_DOWN:
			_stow()
		elif e.button_index == JOY_BUTTON_DPAD_UP and _tool_id() == "tui_hat":
			seed_i = (seed_i + 1) % maxi(1, seeds.size())
			_tool_names()

func _forward() -> Vector3:
	return Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))

func _row_dir() -> int:
	var f := _forward()
	return -1 if f.z < -0.3 else 1

func _target() -> Vector2i:
	return land.cell_at(player.global_position + _forward() * REACH)

func _aim_tool() -> bool:
	return _tool_id() in ["hoe", "tui_hat", "binh_tuoi", "gio_trung"]

func _mouse_cell(m: Vector2) -> Vector2i:
	var o := cam.project_ray_origin(m)
	var d := cam.project_ray_normal(m)
	if d.y > -0.01:
		return Vector2i(-999, -999)
	var p := o + d * ((land.global_position.y + FarmLand.TOP - o.y) / d.y)
	var c := land.cell_at(p)
	return c if land.piece_of(c).x >= 0 else Vector2i(-999, -999)

func _aim_cell() -> Vector2i:
	if _click_cell.x > -900:
		return _click_cell
	if _mouse_aim and _aim_tool():
		var mc := _mouse_cell(get_viewport().get_mouse_position())
		if mc.x > -900:
			return mc
	return _target()

func _act_at(c: Vector2i) -> void:
	_click_go += 1
	var me := _click_go
	_click_cell = c
	var p := land.cell_pos(c)
	var d := p - player.global_position
	d.y = 0
	if d.length() > REACH + 0.2 or d.length() < REACH - 0.35:
		var back := -d.normalized() if d.length() > 0.05 else Vector3(0, 0, 1)
		var res: String = await player.go_to(p + back * REACH, false, 0.06, 12.0)
		if me != _click_go:
			return
		if res != "arrived":
			_click_cell = Vector2i(-999, -999)
			return
	if _busy or not player.controls or not _aim_tool():
		_click_cell = Vector2i(-999, -999)
		return
	d = p - player.global_position
	d.y = 0
	if d.length() > 0.05:
		player.facing = atan2(d.x, d.z)
		player.rotation.y = player.facing
	_busy = true
	match _tool_id():
		"hoe": await _hoe(c)
		"tui_hat": await _sow(c)
		"binh_tuoi": await _water(c)
		"gio_trung": await _pick(c)
	_busy = false
	if me == _click_go:
		_click_cell = Vector2i(-999, -999)

func _near(p: Vector3, r: float) -> bool:
	var d := player.global_position - p
	d.y = 0
	return d.length() < r

func _act() -> void:
	if _busy:
		return
	if pets.use(player.global_position + _forward() * 0.6):
		return
	if bees.use(player.global_position):
		return
	if await _care():
		return
	if _market_use():
		return
	if await days.use(player.global_position):
		return
	if tea.use(player.global_position):
		return
	if _near(LANE, 1.6):
		_go_village()
		return
	if _near_door():
		_go_house()
		return
	if _near(CHONG, 1.6):
		_sleep(false)
		return
	if _mouse_aim and _aim_tool() and _mouse_cell(get_viewport().get_mouse_position()).x > -900:
		_act_at(_mouse_cell(get_viewport().get_mouse_position()))
		return
	_busy = true
	var t := _tool_id()
	var c := _target()
	match t:
		"hoe": await _hoe(c)
		"tui_hat": await _sow(c)
		"binh_tuoi": await _water(c)
		"ro_thoc": await _grain()
		"gio_trung": await _pick(c)
	_busy = false

func _clip(name: String, at: int, cut: int) -> bool:
	var ch := player.chibi
	ch.use_tool(name)
	var waited := 0.0
	while ch.anim.current_animation != name or ch.anim.current_animation_position < at / 30.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > 4.0 or (ch.anim.current_animation != name and waited > 0.5):
			return false
	_cut_at.call_deferred(name, cut)
	return true

func _cut_at(name: String, cut: int) -> void:
	var ch := player.chibi
	while ch.anim.current_animation == name and ch.anim.current_animation_position < cut / 30.0:
		await get_tree().process_frame
	if ch.anim.current_animation == name:
		ch.anim.play(ch._base_clip, 0.3)

func _hoe(c: Vector2i) -> void:
	if land.piece_of(c).x < 0:
		if await _clip("Tool_Hoe_Hit", 9, 30):
			Sound.play_at("tool.hoe", land.cell_pos(c, 0.05), -4.0)
		return
	if not await _clip("Tool_Hoe_Hit", 9, 40):
		return
	player.chibi.hit_stop(0.06)
	_puff(land.cell_pos(c, 0.1), Color("8d5c3e"), 10)
	Sound.play_at("tool.hoe", land.cell_pos(c, 0.1))
	var was := land.state_at(c)
	var pc := land.piece_of(c)
	if was == "co" and int(_hits.get(pc, 0)) + 1 < int(HOE_STROKES[int(tiers["cuoc"])]):
		_hits[pc] = int(_hits.get(pc, 0)) + 1
		if not _hoe_told:
			_hoe_told = true
			hud.toast(tr("FARM_T_HOE_HARD"), 2.5)
		return
	_hits.erase(pc)
	var cc := land.owner(c) if land.crops.has(land.owner(c)) else land.owner(land._twin(c))
	if land.crops.has(cc):
		var now := Time.get_ticks_msec() / 1000.0
		if land.ripe(cc):
			hud.toast(tr("FARM_T_PICK_FIRST"), 2.0)
		elif _dig_at == cc and now - _dig_t < 3.0:
			var id := land.dig(cc)
			_dig_at = Vector2i(-999, -999)
			_puff(land.cell_pos(cc, 0.15), Color("6f9a4a"), 12)
			hud.toast(tr("FARM_T_DUG") % _seed_name(id), 2.0)
		else:
			_dig_at = cc
			_dig_t = now
			hud.toast(tr("FARM_T_DIG_AGAIN"), 2.5)
		return
	var n := int(AREA[int(tiers["cuoc"])])
	if n > 1:
		var any := false
		for cc2: Vector2i in land.row_of(c, n, _row_dir()):
			var w := land.state_at(cc2)
			if land.hoe(cc2, false):
				any = true
				if cc2 != c:
					_puff(land.cell_pos(cc2, 0.1), Color("8d5c3e"), 6)
				if w != "xoi":
					_xp("nho_co" if w == "co" else "cuoc")
		land.redraw()
		if not any:
			hud.toast(tr("FARM_T_PLANTED"))
		elif was == "co":
			_note("dat_co")
		return
	if not land.hoe(c):
		hud.toast(tr("FARM_T_PLANTED"))
	elif was == "co":
		_note("dat_co")
	elif was != "xoi":
		_xp("nho_co" if was == "co" else "cuoc")

func _sow(c: Vector2i) -> void:
	var st := land.state_at(c)
	if st == "co":
		hud.toast(tr("FARM_T_WEEDS"))
		return
	if st == "" or land.crops.has(land.owner(c)):
		hud.toast(tr("FARM_T_PLANTED") if land.crops.has(land.owner(c)) else tr("FARM_T_NOTHING"))
		return
	if seeds.is_empty():
		hud.toast(tr("FARM_T_NO_SEEDS"), 2.5)
		return
	var id: String = seeds[seed_i]
	if await _clip("Tool_Seed_Sow", 28, 38) and land.sow(c, id):
		Sound.play_at("tool.seed", land.cell_pos(c, 0.1))
		seed_n[id] = int(seed_n[id]) - 1
		if int(seed_n[id]) <= 0:
			hud.toast(tr("FARM_T_SEED_OUT") % _seed_name(id), 2.5)
			_refresh_seeds()
		_tool_names()
		_xp("gieo")

func _water(c: Vector2i) -> void:
	var at := player.global_position + _forward() * 0.8
	if FarmScenery.pond_e(at.x, at.z) < 1.5 or absf(at.z - FarmScenery.DITCH_Z) < 1.0:
		if await _clip("Tool_Seed_Sow", 28, 38):
			_puff(at + Vector3(0, 0.1, 0), Color("bfe3f2"), 14)
			Sound.play_at("water.plop", at)
			water_left = int(CAN_HOLDS[int(tiers["binh_tuoi"])])
			hud.toast(tr("FARM_T_CAN_FULL"), 1.8)
			_note("nuoc_muong")
			_tool_names()
		return
	var st := land.state_at(c)
	if st == "co":
		hud.toast(tr("FARM_T_WEEDS"))
		return
	if st == "uot" and int(AREA[int(tiers["binh_tuoi"])]) == 1:
		hud.toast(tr("FARM_T_WATERED"))
		return
	if water_left <= 0:
		hud.toast(tr("FARM_T_CAN_EMPTY"), 2.5)
		return
	if not await _clip("Tool_Water_Pour", 24, 50):
		return
	Sound.play_at("tool.water", land.cell_pos(c, 0.3))
	if st != "":
		var n := int(AREA[int(tiers["binh_tuoi"])])
		var did := 0
		for cc2: Vector2i in (land.row_of(c, n, _row_dir()) if n > 1 else [c]):
			if water_left <= 0:
				break
			if land.water(cc2, false):
				_puff(land.cell_pos(cc2, 0.5), Color("bfe3f2"), 18 if cc2 == c else 10, true)
				water_left -= 1
				did += 1
				_xp("tuoi")
		if did > 0:
			land.redraw()
			_tool_names()

func _grain() -> void:
	if not await _clip("Tool_Grain_Scatter", 24, 40):
		return
	var at := player.global_position + _forward() * 1.2
	_puff(at + Vector3(0, 0.6, 0), Color("e9c35a"), 16, true)
	Sound.play_at("grain.scatter", at)
	if ducks and FarmScenery.pond_e(at.x, at.z) < 1.8:
		var r := ducks.feed(at)
		if r == "asleep":
			hud.toast(tr("FARM_T_DUCKS_ASLEEP"))
		elif r == "first":
			hud.toast(tr("FARM_T_DUCKS_FED"))
			_xp("cho_an")
		return
	var near_yard := YARD.grow(2.0).has_point(Vector2(at.x, at.z))
	if near_yard and hens.all(func(h: Dictionary) -> bool: return h.inside):
		hud.toast(tr("FARM_T_HENS_ASLEEP"))
		return
	for h in _flock():
		if near_yard:
			h.goal = at + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
			h.eat = 4.0
	if near_yard:
		var first: bool = not hens[0].fed
		for h in hens:
			h.fed = true
		if first:
			hud.toast(tr("FARM_T_FED"))
			_xp("cho_an")

func _pick(c: Vector2i) -> void:
	if ducks and _near(DUCK_HOUSE, 1.5):
		if ducks.eggs <= 0:
			hud.toast(tr("FARM_T_NO_DUCK_EGG"))
			return
		if await _clip("Tool_Egg_Pick", 19, 46):
			Sound.play_at("egg.pick", DUCK_HOUSE + Vector3(0, 0.3, 0.4))
			ducks.take_egg()
			_gain("FARM_DUCK_EGG", 1)
			_xp("thu_san_pham")
		return
	if _near(NEST, 1.3):
		if brood.sitting >= 0:
			hud.toast(tr("FARM_T_BROODING"), 2.5)
			return
		if eggs <= 0:
			hud.toast(tr("FARM_T_NO_EGG"))
			return
		if await _clip("Tool_Egg_Pick", 19, 46):
			Sound.play_at("egg.pick", NEST + Vector3(0, 0.3, 0))
			eggs -= 1
			_gain("FARM_EGG", 1)
			_xp("thu_san_pham")
			_show_eggs()
		return
	c = land.owner(c)
	if not land.crops.has(c):
		hud.toast(tr("FARM_T_NOTHING"))
		return
	if not land.ripe(c):
		hud.toast(tr("FARM_T_NOT_RIPE"))
		return
	if await _clip("Tool_Egg_Pick", 19, 46):
		Sound.play_at("harvest.pick", land.cell_pos(c, 0.2))
		var got := land.harvest(c)
		if not got.is_empty():
			if bees.pollinated(c):
				got.n += 1
				hud.toast(tr("BEE_T_POLLEN"), 1.6)
			_gain(Crops.table()[got.crop]["name"], got.n)
			_xp("thu_hoach")

func _gain(key: String, n: int) -> void:
	Sound.play_at("bag.put", player.global_position + Vector3(0, 0.8, 0))
	bag[key] = bag.get(key, 0) + n
	_update_bag()
	hud.toast(tr("FARM_T_GOT") % [n, tr(key)], 1.4)

func _update_bag() -> void:
	hud.set_bag(bag)

func _puff(at: Vector3, col: Color, n: int, fall := false) -> void:
	var p := CPUParticles3D.new()
	var s := Props.sphere(0.03)
	s.material = Props.mat(col)
	p.mesh = s
	p.amount = n
	p.one_shot = true
	p.explosiveness = 0.85
	p.lifetime = 0.7
	p.direction = Vector3.DOWN if fall else Vector3.UP
	p.spread = 40.0 if fall else 50.0
	p.initial_velocity_min = 0.3 if fall else 0.8
	p.initial_velocity_max = 0.9 if fall else 1.6
	p.gravity = Vector3(0, -6, 0)
	p.local_coords = false
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.4).timeout.connect(p.queue_free)

func _show_eggs() -> void:
	for n in _egg_nodes:
		n.queue_free()
	_egg_nodes.clear()
	for i in eggs:
		var e := Props.mesh(self, Props.sphere(0.045), Color("f6ead4"), NEST + Vector3(-0.12 + 0.08 * (i % 4), 0.36, 0.05 * (i / 4)),
			Vector3.ZERO, Vector3(1, 1.25, 1))
		_egg_nodes.append(e)

func _process(delta: float) -> void:
	_frames += 1
	if _frames > 3:
		_t += minf(delta, 1.0 / 20.0)
	if _still.size() == 2 and _still[0] != "" and _t >= _still[1] + 0.5:
		_still = []
		print("farm_plot: still")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Stage.still_args()[0])
		get_tree().quit()
		return
	if not _sleeping:
		Clock.tick(delta)
		if Clock.minute >= Clock.NOD_OFF and not _busy:
			_sleep(true)
		elif int(Clock.minute) != _weather_min:
			_weather_min = int(Clock.minute)
			if _todays_weather():
				_apply_weather()
			_minute()
	hud.set_clock(Clock.day, Clock.minute)
	if cutscene == null or not cutscene.own_light:
		_light()
	_update_bed()
	if not cock.is_empty():
		cock.a.visible = cutscene == null and not cock.inside
	brood.step(delta, cutscene != null)
	pets.step(delta, cutscene != null)
	pens.step(delta)
	bees.step(delta, cutscene != null)
	days.step(delta)
	if cutscene == null or not cutscene.drives_hens:
		_hens(delta)
	if _mouse_aim and (player._input_dir().length() > 0.1 or TouchControls.active):
		_mouse_aim = false
	var c := _aim_cell()
	var t := _tool_id()
	var aim := t in ["hoe", "tui_hat", "binh_tuoi", "gio_trung"] and land.piece_of(c).x >= 0 		and (not _near(NEST, 1.3) or c != _target())
	_cursor.visible = aim and demo_view.is_empty()
	if aim:
		_cursor.global_position = land.cell_pos(c, FarmLand.TOP + 0.03)
	scenery.set_pusher(player.global_position)
	rain.follow(cam.global_position)
	var near := "FARM_HINT_RO" if _near(RO, 1.1) else ("FARM_HINT_SEEDS" if _near(BOARD, 1.1) \
		else ("FARM_HINT_OUT" if _near(LANE, 1.6) else ("FARM_HINT_HOUSE" if _near_door() else "FARM_HINT")))
	if near == "FARM_HINT" and _near(CHONG, 1.6) and _rebuilding():
		near = "FARM_HINT_BOME"
	if trau.hint_at(player.global_position) != "" and (near == "FARM_HINT" or player.riding()):
		near = trau.hint_at(player.global_position)
	if near == "FARM_HINT" and bees.hint_at(player.global_position) != "":
		near = bees.hint_at(player.global_position)
	if near == "FARM_HINT" and days.hint_at(player.global_position) != "":
		near = days.hint_at(player.global_position)
	if near == "FARM_HINT" and tea.hint_at(player.global_position) != "":
		near = tea.hint_at(player.global_position)
	var touch: bool = TouchControls.active
	if near == "FARM_HINT" and t == "rod" and not touch:
		near = "FARM_HINT+ROD"
	if near != _hint_key or touch != _hint_touch:
		_hint_key = near
		_hint_touch = touch
		if near == "FARM_HINT+ROD":
			hud.set_hint(tr("FARM_HINT") + "   " + tr("FARM_HINT_ROD"))
		else:
			hud.set_hint(tr(near + "_TOUCH" if touch else near))
	if cutscene == null:
		_place_camera(delta)

func _place_camera(delta: float) -> void:
	if demo_view.size() == 2:
		cam.global_position = cam.global_position.lerp(demo_view[0], 1.0 - exp(-delta * 2.5)) if delta < 1.0 else demo_view[0]
		cam.look_at(demo_view[1], Vector3.UP)
		return
	if place and place.active:
		var pv := place.view()
		cam.global_position = cam.global_position.lerp(pv[0], 1.0 - exp(-delta * 3.0)) if delta < 1.0 else pv[0]
		cam.look_at(cam.global_position - pv[0] + pv[1], Vector3.UP)
		return
	var v := Stage.arg("--view").split_floats(",")
	if v.size() == 6:
		cam.global_position = Vector3(v[0], v[1], v[2])
		cam.look_at(Vector3(v[3], v[4], v[5]), Vector3.UP)
		return
	if delta < 1.0 and player.controls and not _busy and _shop_rows.is_empty() and not book.visible and cutscene == null:
		var turn := int(Input.is_physical_key_pressed(KEY_Q)) - int(Input.is_physical_key_pressed(KEY_E))
		cam_yaw = wrapf(cam_yaw + turn * CAM_TURN * delta, -PI, PI)
	_cam_zoom_now = lerpf(_cam_zoom_now, cam_zoom, 1.0 - exp(-delta * 9.0)) if delta < 1.0 else cam_zoom
	var off := CAM_OFF.rotated(Vector3.UP, cam_yaw) * _cam_zoom_now
	var want := player.global_position + off
	cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-delta * 6.0)) if delta < 1.0 else want
	cam.look_at(cam.global_position - off + Vector3(0, 0.5, 0), Vector3.UP)

func _light() -> void:
	var h := Clock.hour()
	var dayk := pow(clampf(sin((h - 4.6) / 15.6 * PI), 0.0, 1.0), 0.55)
	var dusk := clampf(1.0 - absf(h - 18.0) / 1.5, 0.0, 1.0) + clampf(1.0 - absf(h - 6.2) / 1.0, 0.0, 1.0) * 0.6
	sun.rotation = Vector3(-deg_to_rad(12.0 + 60.0 * dayk), deg_to_rad(-30.0 + (h - 12.0) * 8.0), 0)
	sun.light_energy = 0.18 + 0.62 * dayk
	sun.light_color = Color(1.0, 0.97, 0.92).lerp(Color(1.0, 0.62, 0.38), clampf(dusk * 1.2, 0.0, 1.0)).lerp(Color(0.6, 0.68, 0.95), (1.0 - dayk) * 0.8)
	if env:
		env.fog_light_color = Color(0.86, 0.90, 0.93).lerp(Color(0.98, 0.78, 0.62), clampf(dusk, 0.0, 1.0)).lerp(Color(0.32, 0.36, 0.5), 1.0 - dayk)
	if env:
		env.ambient_light_energy = 0.35 + 0.65 * dayk
		env.background_energy_multiplier = 0.25 + 0.75 * dayk
		env.fog_density = 0.0022
	if raining:
		sun.light_energy *= 0.32
		sun.light_color = sun.light_color.lerp(Color(0.78, 0.82, 0.9), 0.7)
		if env:
			env.ambient_light_energy *= 0.85
			env.background_energy_multiplier *= 0.55
			env.fog_density = 0.008
			env.fog_light_color = env.fog_light_color.lerp(Color(0.56, 0.61, 0.66), 0.8)
	var night := 1.0 - dayk
	HomeKit.set_night(night)
	for b in _night_bugs:
		b.visible = night > 0.6

func month() -> int:
	if Stage.arg("--month") != "":
		return int(Stage.arg("--month"))
	return int(Clock.lunar()[0])

func _fish_ctx() -> Dictionary:
	return {"hour": Clock.hour(), "month": month(), "lunar_day": int(Clock.lunar()[1]),
		"weather": ("giong" if stormy else "mua") if raining else ""}

func season() -> String:
	var m := month()
	return "he" if m >= 4 and m <= 7 else ("thu" if m >= 8 and m <= 10 else ("xuan" if m == 2 or m == 3 else "dong"))

func _roosting(h: Dictionary) -> bool:
	var hr := Clock.hour()
	return hr >= ROOST + h.late or hr < 5.5

func _flock() -> Array:
	return hens + ([cock] if not cock.is_empty() else [])

func _hens(delta: float) -> void:
	if _coop_path == null:
		_coop_path = Curve3D.new()
		_coop_path.bake_interval = 0.05
		_coop_path.add_point(COOP_DOOR)
		for q: Vector3 in COOP_PATH:
			_coop_path.add_point(q)
	var now := Time.get_ticks_msec() / 1000.0
	_cluck_t -= delta
	if _cluck_t <= 0.0:
		_cluck_t = randf_range(4.0, 10.0)
		var out := hens.filter(func(h: Dictionary) -> bool: return not h.inside and h.a.visible)
		if not out.is_empty():
			Sound.play_at("animal.hen_cluck", out.pick_random().a.global_position + Vector3(0, 0.25, 0))

	var grain := _tool_id() == "ro_thoc" and YARD.grow(2.5).has_point(Vector2(player.global_position.x, player.global_position.z))
	if grain and not _grain_was:
		Sound.play_at("animal.hen_cluck", player.global_position + Vector3(0, 0.3, 0), -4.0, 1.1)
	_grain_was = grain
	for h in _flock():
		var a: FarmAnimal = h.a
		if grain and not h.inside and h.get("climb", 0) == 0 and not _roosting(h) and h.eat <= 0.0 and h.wait < 3.5:
			var me := Vector3(player.global_position.x, 0, player.global_position.z)
			var off := Vector3(a.position.x - me.x, 0, a.position.z - me.z)
			var ring := me + (off.normalized() if off.length() > 0.05 else Vector3(1, 0, 0)) * 0.75
			ring.x = clampf(ring.x, YARD.position.x, YARD.end.x)
			ring.z = clampf(ring.z, YARD.position.y, YARD.end.y)
			if Vector2(h.goal.x - ring.x, h.goal.z - ring.z).length() > 0.3:
				h.goal = ring
				h.wait = 1.0
		if h.get("climb", 0) != 0:
			_climb(h, a, delta)
			continue

		if _roosting(h):
			if h.inside:
				continue
			h.goal = COOP_DOOR
			h.eat = 0.0
			if a.position.distance_to(COOP_DOOR) < 0.2:
				if now >= _coop_free:
					_coop_free = now + COOP_GAP
					h.climb = 1
					h.s = 0.0
					if a.anim.has_animation("Flap"):
						a.play("Flap", 0.1)
						h.flap = 0.45
				elif a._loop == "Walk" or a._loop == "Run":
					a.play("Idle")
				continue
		elif h.inside:
			if now < _coop_free:
				continue
			_coop_free = now + COOP_GAP
			h.inside = false
			a.visible = true
			h.climb = -1
			h.s = _coop_path.get_baked_length()
			a.position = _coop_path.sample_baked(h.s)
			continue
		var to: Vector3 = h.goal - a.position
		to.y = 0
		if to.length() > 0.12:
			var run: bool = (h.eat > 0.0 or grain) and to.length() > 0.8
			var sp: float = FarmAnimal.SPEED[a.kind]["Run" if run else "Walk"]
			a.position += to.normalized() * minf(sp * delta, to.length())
			a.rotation.y = lerp_angle(a.rotation.y, atan2(to.x, to.z), 1.0 - exp(-delta * 8.0))
			a.play("Run" if run else "Walk")
			continue
		if h.eat > 0.0:
			h.eat -= delta
			a.play("Peck")
			continue
		h.wait -= delta
		if h.wait > 0.0 or _roosting(h):
			if a._loop == "Walk" or a._loop == "Run":
				a.play("Peck" if randf() < 0.5 else "Idle")
			continue
		if raining:
			h.goal = Vector3(randf_range(5.0, 5.6), 0, randf_range(-1.4, -0.6))
		else:
			h.goal = Vector3(randf_range(YARD.position.x, YARD.end.x), 0, randf_range(YARD.position.y, YARD.end.y))
		h.wait = randf_range(2.0, 6.0)

func add_hen(at: Vector3) -> void:
	var a := FarmAnimal.spawn(self, "ga_mai", Vector3(at.x, 0, at.z), randf() * TAU)
	hens.append({"a": a, "goal": a.position, "wait": randf_range(0.5, 3.0), "fed": false, "eat": 0.0,
		"inside": false, "late": randf_range(0.0, 0.4)})

func _climb(h: Dictionary, a: FarmAnimal, delta: float) -> void:
	var length := _coop_path.get_baked_length()
	var dir := float(h.climb)
	h.s = clampf(float(h.s) + dir * FarmAnimal.SPEED[a.kind]["Walk"] * 0.85 * delta, 0.0, length)
	var p := _coop_path.sample_baked(h.s)
	var d := _coop_path.sample_baked(clampf(float(h.s) + dir * 0.06, 0.0, length)) - p
	if Vector2(d.x, d.z).length() > 0.005:
		a.rotation.y = lerp_angle(a.rotation.y, atan2(d.x, d.z), 1.0 - exp(-delta * 10.0))
	a.position = p
	h.flap = float(h.get("flap", 0.0)) - delta
	if h.flap <= 0.0:
		a.play("Walk")
	if dir > 0.0 and h.s >= length:
		h.climb = 0
		h.inside = true
		a.visible = false
	elif dir < 0.0 and h.s <= 0.0:
		h.climb = 0
		h.goal = COOP_DOOR + Vector3(-1.0, 0, randf_range(-0.6, 0.6))
		h.wait = 0.0

func _sleep(passed_out: bool) -> void:
	var at_bome := _rebuilding()
	_busy = true
	_sleeping = true
	player.controls = false
	if not passed_out and Clock.minute < Clock.DUSK and not dry:
		Progress.rest("bed_before_22")
	await hud.fade(1.0, 0.9)
	if Clock.rained_today() and not OS.get_cmdline_user_args().has("--sun"):
		land.rain()
	land.next_day()
	var paid_key := _pay() if _owed() > 0 else ""
	var sold := 0
	for k in ro:
		sold += int(ro[k]) * _price_of(k)
	if dry:
		_dry_owed += sold
	else:
		Progress.owe(sold)
	ro = {}
	_ro_show()
	var brood_key := brood.night()
	if brood.grew > 0:
		_hens_more += brood.grew
		hud.toast(tr("FARM_T_GREW") % brood.grew, 3.0)
	if ducks:
		ducks.night()
	for i in hens.size():
		if hens[i].fed and not brood.broody(i):
			eggs = mini(eggs + 1, 8)
		hens[i].fed = false
	_show_eggs()
	water_left = int(CAN_HOLDS[int(tiers["binh_tuoi"])]) if Clock.rained_today() else water_left
	if dry:
		Clock.day += 1
		Clock._start_day()
	else:
		Clock.sleep()
		Progress.new_day()
		Progress.announce()
		_home_work_sync()
		_pen_work_sync()
	_refresh_seeds()
	_todays_weather()
	_apply_weather()
	_fish_n0 = _fish_total()
	fish_used = 0
	care = {}
	for h in hens:
		h.late = randf_range(0.0, 0.4)
	var pet_key := pets.morning()
	var bee_key := bees.night()
	_update_skills()
	_tool_names()
	fish.reset(FishTable.stock("ao", _fish_ctx()))
	_light()
	if at_bome:
		var into := (Vector3(-6.0, 0, FarmScenery.DITCH_Z) - LANE).normalized()
		player.position = LANE + into * 1.2
		player.rotation.y = atan2(into.x, into.z)
	else:
		player.position = CHONG + Vector3(0, 0, 1.2)
		player.rotation.y = 0.0
	player.facing = player.rotation.y
	_place_camera(1.0)
	_save()
	await get_tree().create_timer(0.4).timeout
	await hud.fade(0.0, 0.9)
	var hello := "FARM_T_LATE" if passed_out else ("FARM_T_RAIN" if raining else "FARM_T_MORNING")
	if at_bome and not passed_out:
		hello = "FARM_T_MORNING_BOME"
	hud.toast(tr(hello), 3.0)
	if not cock.is_empty():
		_crow.call_deferred()
	for k in [paid_key, brood_key, pet_key, bee_key]:
		if k != "":
			await get_tree().create_timer(3.2).timeout
			hud.toast(tr(k), 3.5)
	player.controls = true
	_sleeping = false
	_busy = false

func _rebuilding() -> bool:
	return int(Story.flag("nha_dang_xay", 0)) > 0

static func _home_work_sync() -> void:
	if ClassDB.class_exists("HomeWork"):
		ClassDB.class_call_static("HomeWork", "sync")

func _pen_work_sync() -> void:
	if pens == null or not ClassDB.class_exists("PenWork"):
		return
	ClassDB.class_call_static("PenWork", "sync")
	for row in ClassDB.class_call_static("PenWork", "take_built"):
		pens.finish_build(row)
	pens.refresh_sites()
	_ensure_place()

func _go_village() -> void:
	if dry:
		hud.toast(tr("FARM_HINT_OUT"), 2.0)
		return
	_busy = true
	player.controls = false
	_save()
	Story.set_flag("spawn_at", "farm_gate")
	await hud.fade(1.0, 0.6)
	get_tree().change_scene_to_file("res://scenes/hometown.tscn")

func _near_door() -> bool:
	return house != null and house.building == 0 and _near(HOUSE_AT + FarmHouse.DOOR, 0.9)

func _go_house() -> void:
	if dry:
		hud.toast(tr("FARM_HINT_HOUSE"), 2.0)
		return
	_busy = true
	player.controls = false
	_save()
	Engine.set_meta("nha_trong_room", "san_truoc" if house.level >= 3 else "nha_cu")
	Engine.set_meta("nha_trong_from", "farm")
	await hud.fade(1.0, 0.6)
	get_tree().change_scene_to_file("res://scenes/nha_trong.tscn")

func _care() -> bool:
	var t := _tool_id()
	if _near(COOP_SIDE, 0.9):
		var h := Clock.hour()
		if h >= 18.0 and not care.has("herd") and hens.any(func(x: Dictionary) -> bool: return not x.inside):
			care["herd"] = true
			for x in hens:
				x.late = h - ROOST - 0.01
			hud.toast(tr("FARM_T_HERD"), 2.5)
			_xp("lua_ve_chuong")
			return true
		if h < 18.0 and not care.has("sweep"):
			care["sweep"] = true
			_busy = true
			await _clip("Tool_Hoe_Hit", 9, 30)
			_puff(COOP_SIDE + Vector3(0, 0.15, -0.3), Color("c9b48a"), 12)
			_busy = false
			hud.toast(tr("FARM_T_SWEEP"), 2.0)
			_xp("don_chuong")
			return true
	if t == "ro_thoc" or _near(NEST, 1.3):
		return false
	var at := player.global_position + _forward() * 0.6
	for i in _flock().size():
		var x: Dictionary = _flock()[i]
		var a: FarmAnimal = x.a
		var key := "pat:%d" % i
		if a.visible and not x.inside and not care.has(key) and Vector2(a.position.x - at.x, a.position.z - at.z).length() < 0.55:
			care[key] = true
			hud.toast(tr(touch.hen(x)), 1.8)
			_xp("vuot_ve")
			return true
	return false

var _ro_node: Node3D
var _ro_veg: Node3D

func _build_market() -> void:

	var mid := (RO + BOARD) * 0.5
	var along := Vector2(BOARD.x - RO.x, BOARD.z - RO.z)
	var yaw := -rad_to_deg(atan2(along.y, along.x))
	mid.y = scenery.height_at(mid.x, mid.z)
	var stall := Furniture.place(self, "sap_tre", mid, yaw, false)
	var top := BoxShape3D.new()
	top.size = Vector3(1.9, 0.7, 0.62)
	Props.solid(stall, top, Vector3(0, 0.35, 0))
	var y := mid.y + 0.635
	_ro_node = Furniture.place(self, "ro_rau", Vector3(RO.x, y, RO.z), 20.0, false)
	_ro_veg = Props.mesh(self, Props.sphere(0.13), Color("7fae4e"), Vector3(RO.x, y + 0.2, RO.z), Vector3.ZERO, Vector3(1.3, 0.55, 1.0))
	_ro_veg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ro_show()
	for g in _ro_node.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _ro_show() -> void:
	if _ro_veg:
		_ro_veg.visible = not ro.is_empty()

func _price_of(key: String) -> int:
	var dp := days.price_of(key) if days else 0
	if dp <= 0 and tea:
		dp = tea.price_of(key)
	if dp > 0:
		return dp
	var sell: Dictionary = prices["sell"]
	if key == "fish" or key == "FARM_EGG":
		return int(sell["fish" if key == "fish" else "egg"])
	if key == "FARM_DUCK_EGG":
		return int(sell.get("duck_egg", 0))
	if key.begins_with("MAT_ONG_"):
		return int(sell.get(key.to_lower(), 0))
	for id in Crops.table():
		if Crops.table()[id]["name"] == key:
			return int(sell.get(id, 0))
	return 0

func _market_use() -> bool:
	if _near(RO, 1.1):
		var room := int(Progress.skills()["money"]["stall_village"]["items_per_day"])
		for k in ro:
			room -= int(ro[k])
		if room <= 0:
			hud.toast(tr("FARM_T_RO_FULL"), 2.5)
			return true
		var n := 0
		for k in bag.keys():
			if _price_of(k) <= 0:
				continue
			var take := mini(int(bag[k]), room - n)
			if take > 0:
				bag[k] = int(bag[k]) - take
				ro[k] = int(ro.get(k, 0)) + take
				n += take
		var f := mini(fish_in_hand(), room - n)
		if f > 0:
			fish_used += f
			ro["fish"] = int(ro.get("fish", 0)) + f
			n += f
		for k in bag.keys():
			if int(bag[k]) <= 0:
				bag.erase(k)
		_update_bag()
		_ro_show()
		hud.toast(tr("FARM_T_RO_PUT") % n if n > 0 else tr("FARM_T_RO_NOTHING"), 2.5)
		return true
	if _near(BOARD, 1.1):
		_shop_rows = []
		var basic := Clock.day < int(prices.get("basic_until_day", 28))
		for row in Progress.unlocks().get("items", []):
			if row["type"] == "seed" and prices["seed_packet"].has(row["id"]) and Progress.met(row["unlock"]) \
					and (not basic or row["unlock"].get("start", false)):
				_shop_rows.append(row["id"])
		for row in Progress.unlocks().get("items", []):
			var t: Dictionary = prices.get("tools", {}).get(row["id"], {})
			if not t.is_empty() and Progress.met(row["unlock"]) and int(tiers[t["tool"]]) == int(t["tier"]) - 1:
				_shop_rows.append("tool:" + str(row["id"]))
		_shop_i = 0
		player.controls = false
		_shop_draw()
		return true
	return false

func _shop_draw() -> void:
	var rows := []
	for id: String in _shop_rows:
		if id.begins_with("tool:"):
			var tid := id.substr(5)
			rows.append(tr("FARM_SHOP_TOOL_ROW") % [tr("TOOL_" + tid.to_upper()), int(prices["tools"][tid]["price"])])
			continue
		rows.append(tr("FARM_SHOP_ROW") % [_seed_name(id), int(prices["seed_packet"][id][1]), int(prices["seed_packet"][id][0]),
			int(seed_n.get(id, 0))])
	hud.shop(tr("FARM_SHOP_TITLE") % Progress.money(), rows, _shop_i,
		tr("FARM_SHOP_HINT_TOUCH" if TouchControls.active else "FARM_SHOP_HINT"))

func _shop_input(e: InputEvent) -> void:
	var up := false
	var down := false
	var buy := false
	var close := false
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		up = k in [KEY_W, KEY_UP]
		down = k in [KEY_S, KEY_DOWN]
		buy = k in [KEY_F, KEY_SPACE, KEY_ENTER]
		close = k in [KEY_ESCAPE, KEY_Q, KEY_BACKSPACE]
	elif e is InputEventJoypadButton and e.pressed:
		up = e.button_index == JOY_BUTTON_DPAD_UP
		down = e.button_index == JOY_BUTTON_DPAD_DOWN
		buy = e.button_index == JOY_BUTTON_A
		close = e.button_index == JOY_BUTTON_B
	if up or down:
		_shop_i = posmod(_shop_i + (1 if down else -1), _shop_rows.size())
		_shop_draw()
	elif buy:
		_shop_buy()
	elif close:
		_shop_close()
	get_viewport().set_input_as_handled()

func _shop_buy() -> void:
	var id: String = _shop_rows[_shop_i]
	if id.begins_with("tool:"):
		var tid := id.substr(5)
		var t: Dictionary = prices["tools"][tid]
		if dry or Progress.spend(int(t["price"])):
			_upgrade(str(t["tool"]), int(t["tier"]), tr("FARM_T_TOOL_GOT") % tr("TOOL_" + tid.to_upper()))
			_shop_rows.remove_at(_shop_i)
			if _shop_rows.is_empty():
				_shop_close()
				return
			_shop_i = mini(_shop_i, _shop_rows.size() - 1)
		else:
			hud.toast(tr("FARM_T_POOR"), 2.0)
		_shop_draw()
		return
	var p: Array = prices["seed_packet"][id]
	if dry or Progress.spend(int(p[0])):
		seed_n[id] = int(seed_n.get(id, 0)) + int(p[1])
		hud.toast(tr("FARM_T_BOUGHT") % [_seed_name(id), int(p[1])], 2.0)
		_refresh_seeds()
	else:
		hud.toast(tr("FARM_T_POOR"), 2.0)
	_shop_draw()

func _shop_close() -> void:
	if _shop_rows.is_empty():
		return
	_shop_rows = []
	hud.close_shop()
	player.controls = true

func _tap_tool(i: int) -> void:
	if not player.controls or _busy:
		return
	if i == tool_i and TOOLS[i][0] == "tui_hat":
		seed_i = (seed_i + 1) % maxi(1, seeds.size())
		_tool_names()
	elif i == tool_i:
		_stow()
	else:
		_pick_tool(i)

func _tap_shop(i: int) -> void:
	if _shop_rows.is_empty():
		return
	if i == _shop_i:
		_shop_buy()
	else:
		_shop_i = i
		_shop_draw()

func _note(id: String) -> void:
	if SoTay.write(id):
		get_tree().create_timer(3.4).timeout.connect(func() -> void: hud.toast(tr("SOTAY_NEW"), 3.0))

func _book_input(e: InputEvent) -> void:
	var step := 0
	var close := false
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		step = 1 if k in [KEY_D, KEY_RIGHT] else (-1 if k in [KEY_A, KEY_LEFT] else 0)
		close = k in [KEY_J, KEY_ESCAPE, KEY_Q]
	elif e is InputEventJoypadButton and e.pressed:
		step = 1 if e.button_index == JOY_BUTTON_DPAD_RIGHT else (-1 if e.button_index == JOY_BUTTON_DPAD_LEFT else 0)
		close = e.button_index in [JOY_BUTTON_Y, JOY_BUTTON_B]
	if step != 0:
		_book_i = posmod(_book_i + step, _book_pages.size())
		SoTay.show(book, _book_pages, _book_i)
	elif close:
		book.visible = false
		player.controls = true
	get_viewport().set_input_as_handled()

func _owed() -> int:
	return _dry_owed if dry else Progress.owed()

func _pay() -> String:
	var n := _dry_owed if dry else Progress.pay_owed()
	_dry_owed = 0
	if n > 0:
		_note("ro_me")
	return tr("FARM_T_PAID") % [n, Progress.money()]

func _minute() -> void:
	if pets.vang_stays:
		_note("cho_vang")
	if pets.muop_stays:
		_note("meo")
	if not brood.chicks.is_empty():
		_note("ga_ap")
	if _owed() > 0 and Clock.hour() >= 18.0:
		hud.toast(_pay(), 4.0)
	if Clock.hour() >= 16.0:
		var k := pets.evening(fish_in_hand())
		if k != "":
			hud.toast(tr(k), 3.5)
	if cutscene != null or _busy or not player.controls or dry:
		return
	var h := Clock.hour()
	if not seen.has("hawk") and h >= 8.5 and h < 10.5 and not raining and not cock.is_empty() \
			and hens.size() >= 3 and brood.chicks.size() >= 6:
		_play_once("hawk")
	elif not seen.has("dog") and raining and h >= 18.3 and h < 19.5 and brood.chicks.size() >= 8 \
			and pets.vang_stays and Progress.hearts("cho_vang") >= 4:
		_play_once("dog")
	elif not seen.has("cat") and h >= 18.0 and h < 20.5 and fish_today() >= 10 and pets.muop_stays:
		_play_once("cat")

func _play_once(id: String) -> void:
	seen[id] = Clock.day
	_save()
	match id:
		"hawk": _hawk()
		"dog": _cutscene(DogScene.new(), "FARM_T_DOG_DONE")
		"cat": _cutscene(CatScene.new(), "FARM_T_CAT_DONE")

func _fish_total() -> int:
	var n := 0
	for k in FishLog.caught:
		n += int(FishLog.caught[k].get("n", 0))
	return n

func fish_today() -> int:
	return _fish_total() - _fish_n0

func fish_in_hand() -> int:
	return fish_today() - fish_used

func _update_skills() -> void:
	var rows := []
	var lv: Array = Progress.skills()["levels"]
	for sk in ["lam_ruong", "chan_nuoi", "cau_ca"]:
		var l := Progress.level(sk)
		var x := float(Progress.xp().get(sk, 0))
		var frac := 1.0 if l + 1 >= lv.size() else (x - float(lv[l])) / maxf(1.0, float(lv[l + 1]) - float(lv[l]))
		rows.append([tr(str(Progress.skills()["skills"][sk]["name"])), l, clampf(frac, 0.0, 1.0)])
	hud.set_skills(rows)

func _crow() -> void:
	await get_tree().create_timer(1.8).timeout
	if cutscene == null and cock.a.visible:
		cock.a.play("Crow")
		Sound.play_at("animal.rooster_crow", cock.a.global_position)

func _apply_weather() -> void:
	rain.set_on(raining)
	rain.storm = raining and stormy

	_update_bed()
	if raining and _roof_rain == null:
		_roof_rain = Sound.play_at("rain.roof", CHONG + Vector3(0, 2.1, 0))
	elif not raining and _roof_rain != null:
		Sound.stop(_roof_rain, 2.0)
		_roof_rain = null
	scenery.set_wet(1.0 if raining else 0.0)
	if raining:
		land.rain()
		for h in hens:
			h.wait = 0.0

func _update_bed() -> void:
	var h := Clock.hour()
	var s := season()
	var bed := "farm_rain"
	if not raining:
		if h >= 5.3 and h < 18.6:
			bed = "farm_day" if s == "he" else "farm_day_calm"
		else:
			bed = "farm_night" if s == "he" or s == "thu" else "farm_night_calm"
	Sound.ambience(bed, 4.0)

func _on_thunder(near: bool) -> void:
	if near:
		for h in _flock():
			(h.a as FarmAnimal).play("Flap")

func _hawk() -> void:
	player.position = Vector3(1.6, 0, -0.5)
	player.rotation.y = PI / 2
	player.facing = PI / 2
	cutscene = HawkScene.new()
	add_child(cutscene)
	await cutscene.play(self)
	for h in hens:
		h.goal = (h.a as FarmAnimal).position
		h.wait = randf_range(1.0, 3.0)
	cutscene.queue_free()
	cutscene = null
	hud.toast(tr("FARM_T_HAWK_DONE"), 3.0)

func _cutscene(scene: FarmCutscene, toast_key: String) -> void:
	cutscene = scene
	add_child(scene)
	await scene.play(self)
	scene.queue_free()
	cutscene = null
	hud.toast(tr(toast_key), 3.0)

func _intro() -> void:
	player.controls = false
	for k in ["FARM_INTRO_1", "FARM_INTRO_2", "FARM_INTRO_3"]:
		await Narrator.say(k)
	intro_done = true
	player.controls = true
	_save()

func _stats() -> void:
	"""--stats: what each top-level part of the scene draws (instances, surfaces, triangles), then quit."""
	await get_tree().create_timer(1.0).timeout
	for top in get_children():
		var n := 0
		var surf := 0
		var tris := 0
		for g in [top] + top.find_children("*", "GeometryInstance3D", true, false):
			if not g is GeometryInstance3D or not (g as Node3D).is_visible_in_tree():
				continue
			var m: Mesh = null
			var copies := 1
			if g is MeshInstance3D:
				m = g.mesh
			elif g is MultiMeshInstance3D and g.multimesh:
				m = g.multimesh.mesh
				copies = g.multimesh.instance_count
			if m == null:
				continue
			n += 1
			surf += m.get_surface_count()
			tris += m.get_faces().size() / 3 * copies
		if n > 0:
			print("stats %-22s nodes %3d surfaces %3d tris %6d" % [top.name, n, surf, tris])
	get_tree().quit()

func _ensure_place() -> void:
	if place != null or (pens.pens.is_empty() and _pen_kho.is_empty() and not FarmPens.can_build_any()):
		return
	place = FarmPlace.new()
	add_child(place)
	place.setup(pens, cam, player)
	place.kho = _pen_kho
	place.toggled.connect(func(on: bool) -> void: hud.visible = not on)

func _grant_hives(tell: bool) -> void:
	if not bees.enabled():
		return
	var want := FarmBees.allowed()
	if "--bees" in OS.get_cmdline_user_args():
		want = 3
	var kho: Dictionary = place.kho if place else _pen_kho
	var have := bees.hives().size() + int(kho.get("to_ong", 0))
	if want <= have:
		return
	kho["to_ong"] = int(kho.get("to_ong", 0)) + want - have
	if place:
		place._fill_kho()
	else:
		_ensure_place()
	if tell:
		hud.toast(tr("BEE_T_LEARNT"), 4.0)

func _bees_demo() -> void:
	var p := pens.add("to_ong", FarmPens.cell_for("to_ong", 0, Vector2(3.0, 1.75)), 0, false)
	player.position = Vector3(2.2, 0, 3.0)
	p.data = {"fill": 1.0, "kind": "bach_hoa"}
	var flowery := ["ot", "cuc_van_tho", "ca_tim", "huong_duong"]
	var k := 0
	for b: Array in BEDS:
		for r in int(b[2]):
			for di in 2:
				var c := Vector2i(int(b[0]) + di, int(b[1]) + r)
				var id: String = flowery[(k / 4) % flowery.size()]
				land.hoe(c)
				land.plant(c, id, 3 if id in ["huong_duong", "cuc_van_tho"] else 2)
				k += 1
	land.redraw()
	if OS.get_environment("MC_BEE_TEST") != "":
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
			intro_done = true
			player.position = p.node.global_position + Vector3(-0.6, 0, -0.05)
			player.rotation.y = PI / 2
			player.facing = PI / 2
			if OS.get_environment("MC_BEE_TEST") == "smoke":
				player.position = p.node.global_position + Vector3(0, 0, 0.7)
				player.rotation.y = PI
				player.facing = PI
			bees.use(player.global_position)
			if OS.get_environment("MC_BEE_TEST") == "face":
				get_tree().create_timer(2.0).timeout.connect(func() -> void:
					player.rotation.y = 0.0
					player.facing = 0.0
					demo_view = [player.global_position + Vector3(0.3, 1.3, 1.6), player.global_position + Vector3(0, 0.95, 0)]))

func _save() -> void:
	if dry:
		return
	DirAccess.make_dir_recursive_absolute("user://save")
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"day": Clock.day, "land": land.to_dict(), "bag": bag, "eggs": eggs,
			"intro_done": intro_done, "brood": brood.to_dict(), "pets": pets.to_dict(), "touch": touch.to_dict(), "tiers": tiers,
			"water_left": water_left, "seen": seen, "seed_n": seed_n, "ro": ro, "pens": pens.to_dict(),
			"pen_kho": place.kho if place else _pen_kho, "hens_more": _hens_more,
			"ducks": ducks.to_dict() if ducks else {}, "days": days.to_dict(), "tea": tea.to_dict(),
			"trau": trau.to_dict()}, " "))
	Clock.save()

func _load() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if not d is Dictionary:
		return
	bag = d.get("bag", {})
	for k in bag:
		bag[k] = int(bag[k])
	eggs = int(d.get("eggs", 0))
	intro_done = bool(d.get("intro_done", false))
	for i in clampi(int(d.get("hens_more", 0)), 0, HEN_CAP - hens.size()):
		add_hen(Vector3(randf_range(YARD.position.x, YARD.end.x), 0, randf_range(YARD.position.y, YARD.end.y)))
	_hens_more = hens.size() - 3
	if ducks:
		ducks.from_dict(d.get("ducks", {}))
	brood.from_dict(d.get("brood", {}))
	_pets_saved = d.get("pets", {})
	_touch_saved = d.get("touch", {})
	for k in d.get("tiers", {}):
		tiers[k] = int(d["tiers"][k])
	water_left = int(d.get("water_left", CAN_HOLDS[int(tiers["binh_tuoi"])]))
	seen = d.get("seen", {})
	if d.has("seed_n"):
		seed_n = {}
		for k in d["seed_n"]:
			seed_n[k] = int(d["seed_n"][k])
	ro = d.get("ro", {})
	_pens_saved = d.get("pens", [])
	days.from_dict(d.get("days", {}))
	tea.from_dict(d.get("tea", {}))
	trau.from_dict(d.get("trau", {}))
	_pen_kho = d.get("pen_kho", {})
	_ro_show()
	land.from_dict(d.get("land", {}))

	for i in clampi(Clock.day - int(d.get("day", Clock.day)), 0, 30):
		land.next_day()

func _demo() -> void:
	"""Four days in a minute and a half: hoe two bed pieces, sow, water, feed the hens, sleep; water and pick an
	egg; water; then pick the ripe cải ngọt. Quits at the end."""
	Clock.speed = 6.0
	intro_done = true
	var tm := func(s: float): return get_tree().create_timer(s).timeout
	await tm.call(0.8)
	var cells := [Vector2i(-2, 2), Vector2i(-1, 2), Vector2i(-2, 1), Vector2i(-1, 1)]
	for c in [Vector2i(-2, 2), Vector2i(-2, 1)]:
		await _work(c, 0)
	seed_i = 0
	for c in cells:
		await _work(c, 1)
	for c in [Vector2i(-2, 2), Vector2i(-2, 1)]:
		await _work(c, 2)
	await player.go_to(FEEDER + Vector3(-1.6, 0, 0.2))
	_face(Vector3(1, 0, 0))
	await _use(3)
	await tm.call(2.5)
	for d in 3:
		await player.go_to(CHONG + Vector3(0, 0, 1.2))
		await _sleep(false)
		await tm.call(1.0)
		if d < 2:
			for c in [Vector2i(-2, 2), Vector2i(-2, 1)]:
				await _work(c, 2)
			if d == 0:
				await player.go_to(NEST + Vector3(0, 0, 0.9))
				_face(Vector3(0, 0, -1))
				await _use(4)
	for c in cells:
		await _work(c, 4)
	await tm.call(2.0)
	print("farm_plot demo: done on day %d, bag %s" % [Clock.day, bag])
	get_tree().quit()

func _harvest_demo() -> void:
	"""(10/11, Màn chơi; the user: "trồng 1 vài nông sản, và thu hoạch cho tôi xem") --harvest-demo --fresh: dry. Hoe
	two bed pieces, sow four crops (cải ngọt, ớt, cà tím, ngô), water, sleep the nights through (watered each
	morning), then pick each one with the camera close. Quits at the end."""
	intro_done = true
	Clock.minute = 7.0 * 60.0
	var tm := func(s: float): return get_tree().create_timer(s).timeout
	var plan := [[Vector2i(-2, 2), "cai_ngot"], [Vector2i(-1, 2), "ot"], [Vector2i(1, 2), "ca_tim"], [Vector2i(2, 2), "ngo"]]
	seeds = []
	for pr in plan:
		seed_n[pr[1]] = 5
		seeds.append(pr[1])
	_tool_names()
	water_left = 99
	await tm.call(1.0)
	for c in [Vector2i(-2, 2), Vector2i(-2, 2), Vector2i(1, 2), Vector2i(1, 2)]:
		await _work(c, 0)
	for k in plan.size():
		seed_i = k
		_tool_names()
		await _work(plan[k][0], 1)
	for pr in plan:
		await _work(pr[0], 2)
	await tm.call(0.6)
	var mid := land.cell_pos(Vector2i(0, 2))
	for night in 5:
		await _night()
		for pr in plan:
			land.water(pr[0], false)
		land.redraw()
		demo_view = [mid + Vector3(0, 1.6, 2.6), mid + Vector3(0, 0.2, 0)]
		await tm.call(1.6)
		demo_view = []
	for pr in plan:
		print("  %s ripe %s" % [pr[1], land.ripe(pr[0])])
	for pr in plan:
		var c: Vector2i = pr[0]
		await player.go_to(land.cell_pos(c) + Vector3(0, 0, REACH))
		_face(Vector3(0, 0, -1))
		var at := land.cell_pos(c)
		demo_view = [at + Vector3(2.1, 1.55, -2.0), at + Vector3(0, 0.6, 0.4)]
		await tm.call(1.0)
		await _use(4)
		await tm.call(1.4)
	demo_view = []
	await tm.call(2.0)
	print("farm_plot harvest demo: done on day %d, bag %s" % [Clock.day, bag])
	get_tree().quit()

func _week() -> void:
	"""--week: the first week in about two minutes (dry): six play days, the clock moved on by hand."""
	intro_done = true
	brood.force = true
	Clock.speed = 2.0
	var tm := func(s: float): return get_tree().create_timer(s).timeout
	var cells := [Vector2i(-2, 2), Vector2i(-1, 2), Vector2i(-2, 1), Vector2i(-1, 1)]
	Clock.minute = 6.5 * 60.0
	await tm.call(1.5)

	for c in [Vector2i(-2, 2), Vector2i(-2, 2), Vector2i(-2, 1), Vector2i(-2, 1)]:
		await _work(c, 0)
	for c in cells:
		await _work(c, 1)
	water_left = 1
	_tool_names()
	await _work(Vector2i(-2, 2), 2)
	await _work(Vector2i(-2, 1), 2)
	await tm.call(1.2)
	await player.go_to(Vector3(-1.0, 0, 5.6))
	_face(Vector3(0, 0, 1))
	await _use(2)
	await _work(Vector2i(-2, 1), 2)
	await _feed_hens()
	await _put_bowl()
	for d in 2:
		await _night()
		await _feed_hens()
		if d == 1:
			await player.go_to(NEST + Vector3(0, 0, 0.9))
			_face(Vector3(0, 0, -1))
			await _use(4)
		await _put_bowl()
		if d == 1:
			_fish_n0 -= 1
			Clock.minute = 17.0 * 60.0
			await tm.call(4.5)
			await _leave_fish()
	await _night()
	await tm.call(6.0)
	await _feed_hens()
	await _leave_fish()
	await _night()
	await _feed_hens()
	Clock.minute = 18.4 * 60.0
	await player.go_to(CHONG + Vector3(1.2, 0, 1.6))
	demo_view = [CHONG + Vector3(1.6, 2.2, 3.6), CHONG + Vector3(0.2, 0.5, 0)]
	await tm.call(5.0)
	demo_view = []
	await _night()
	await tm.call(4.0)
	var mum: Vector3 = hens[0].a.position if brood.chicks.is_empty() else hens[brood.chicks[0].mum].a.position
	await player.go_to(mum + Vector3(-1.4, 0, 1.0))
	_face(mum - player.global_position)
	demo_view = [mum + Vector3(-1.0, 1.9, 3.2), mum + Vector3(0, 0.2, 0)]
	await tm.call(8.0)
	print("farm_plot week: done on day %d, chicks %d, vang %s, muop %s" % [Clock.day, brood.chicks.size(), pets.vang_stays, pets.muop_stays])
	get_tree().quit()

func _night() -> void:
	await player.go_to(CHONG + Vector3(0, 0, 1.2))
	await _sleep(false)
	await get_tree().create_timer(2.0).timeout

func _feed_hens() -> void:
	await player.go_to(FEEDER + Vector3(-1.6, 0, 0.2))
	_face(Vector3(1, 0, 0))
	await _use(3)
	await get_tree().create_timer(1.0).timeout

func _put_bowl() -> void:
	if pets.vang_stays:
		return
	await player.go_to(FarmPets.BOWL + Vector3(0.8, 0, -0.5))
	_face(FarmPets.BOWL - player.global_position)
	await _act()
	await player.go_to(Vector3(-0.6, 0, 0.2))
	_face(FarmPets.BOWL - player.global_position)
	demo_view = [Vector3(-1.2, 3.4, 9.4), Vector3(-3.4, 0.3, 3.6)]
	await get_tree().create_timer(8.0).timeout
	demo_view = []

func _leave_fish() -> void:
	_fish_n0 -= 1
	Clock.minute = maxf(Clock.minute, 16.5 * 60.0)
	await player.go_to(FarmPets.DISH + Vector3(0, 0, 0.9))
	_face(Vector3(0, 0, -1))
	await _act()
	await get_tree().create_timer(2.0).timeout

func _face(d: Vector3) -> void:
	player.rotation.y = atan2(d.x, d.z)
	player.facing = player.rotation.y

func _use(i: int) -> void:
	if tool_i != i:
		_pick_tool(i)
		await get_tree().create_timer(0.25).timeout
	await _act()
	while _busy or player.busy():
		await get_tree().process_frame

func _work(c: Vector2i, i: int) -> void:
	"""Walk to stand south of cell c facing it (-z), then use tool i on it."""
	await player.go_to(land.cell_pos(c) + Vector3(0, 0, REACH))
	_face(Vector3(0, 0, -1))
	await _use(i)
