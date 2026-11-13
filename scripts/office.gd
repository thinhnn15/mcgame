extends Node3D

const ROOM := Vector2(9.0, 7.0)
const WALL_H := 2.8
const FLOOR := Color("d2a97e")
const RUG := Color("bcc6d2")
const WALL := Color("f7f0e4")
const BASE := Color("b98e62")
const FRAME := Color("c9ced8")
const VOID := Color("2b2522")

const SURFACES := {
	"floor": ["floor_wood", Vector2(2.1, 2.1), Color.WHITE],
	"wall": ["wall_plaster", Vector2(1.6, 1.6), WALL],
	"rug": ["carpet_tiles", Vector2(1.0, 1.0), RUG],
	"boss_rug": ["carpet_tiles", Vector2(1.0, 1.0), Color("9aa3b0")],
	"lounge_rug": ["rug_lounge", Vector2(2.4, 1.8), Color.WHITE],
}
const SURFACE_SHADER := preload("res://shaders/toon_surface.gdshader")
var _surface_mats := {}
const CHARS := "res://data/characters.json"

const TIMES := {
	"day": {"sky": ["e3f2ff", "bfe0ff", "a3d2ff"], "city": 0.0, "lit": 0.0, "sun": [0.82, "fff1e0"], "amb": ["dde3f2", 0.3],
		"streak": ["ffd68a", 0.4], "cast": 0.22, "lamp": 0.62, "people": true},
	"sunset": {"sky": ["ffd2a8", "f7a98f", "b98fc4"], "city": 0.25, "lit": 0.12, "sun": [0.6, "ffb27a"], "amb": ["e8d2e6", 0.3],
		"streak": ["ff9a5c", 0.38], "cast": 0.1, "lamp": 0.8, "people": true},
	"night": {"sky": ["3a3f74", "2a2d5e", "1c1d42"], "city": 0.72, "lit": 0.17, "sun": [0.06, "9fb0ff"], "amb": ["3f4475", 0.1],
		"streak": ["", 0.0], "cast": 0.0, "lamp": 0.35, "people": false},
}
var tod: Dictionary = TIMES["day"]
var time_name := "day"
var forced_time := ""
var forced_sit := ""
var hero_back := 0.0

const DESK_X := [-3.4, -2.2, -1.0, 0.2]
const ROW_FRONT := -0.6
const ROW_BACK := -1.3
const HERO_DESK := Vector3(-2.2, 0, ROW_FRONT)
const BOSS_GLASS_X := 2.0
const SEAT_OFF := 0.55
var player: Player
var cam: Camera3D
var world: Node3D
var life: OfficeLife
var work: DeskWork
var morning: Morning
var pick: ClickPick

const FREE_SEATS := [["front", 1], ["front", 2], ["back", 0]]
var still := []
var fixed_view := false
var t := 0.0
var _marker: Label3D

func _ready() -> void:
	time_name = forced_time if forced_time != "" else Stage.arg("--time", "day")
	if not TIMES.has(time_name):
		time_name = "day"
	tod = TIMES[time_name]
	var sit_clip := forced_sit if forced_sit != "" else Stage.arg("--sit")
	hero_back = 0.22 if sit_clip.contains("Slump") else 0.0
	Stage.setup(self)

	var env := (find_child("WorldEnvironment", false, false) as WorldEnvironment).environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = VOID
	env.ambient_light_color = Color(tod["amb"][0])
	env.ambient_light_energy = tod["amb"][1]
	var sun := find_child("Sun", false, false) as DirectionalLight3D
	sun.light_energy *= tod["sun"][0]
	sun.light_color = Color(tod["sun"][1])
	if not tod["people"]:
		env.ambient_light_sky_contribution = 0.05
	world = Node3D.new()
	world.name = "Office"
	add_child(world)
	_build_room()
	_build_window_view()
	_furnish()
	_clutter()
	_light()
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	player = Player.new()
	add_child(player)
	player.position = Vector3(-0.4, 0, 2.5)
	player.rotation.y = PI
	player.facing = player.rotation.y
	player.setup(Looks.load_saved(), cam)
	var at := Stage.arg("--player").split_floats(",")
	if at.size() == 2:
		player.position = Vector3(at[0], 0, at[1])
	var auto := Stage.arg("--auto").split_floats(",")
	if auto.size() == 2:
		player.auto_move = Vector2(auto[0], auto[1])
		if OS.has_environment("MC_LIFE_DEBUG"):
			get_tree().create_timer(4.0).timeout.connect(func(): print("PLAYER at ", player.global_position))
	var sit := forced_sit if forced_sit != "" else Stage.arg("--sit")
	if sit != "":
		var st := seat("front", 1)
		player.position = st[0] + Vector3(0, 0, hero_back)
		player.rotation.y = st[1]
		player.facing = st[1]
		player.controls = false
		player.set_physics_process(false)
		player.chibi.play(sit, 0.0)
	if tod["people"]:
		life = OfficeLife.new()
		add_child(life)
		life.setup(self)
	for c in [player.chibi] + (life.chibis() if life else []):
		_people_layer(c)
	var layer := CanvasLayer.new()
	add_child(layer)
	if forced_time == "" and Stage.arg("--sit") == "":
		pick = ClickPick.new()
		add_child(pick)
		pick.setup(cam, layer)
		if life:
			life.setup_talk(layer, pick)
	if tod["people"] and forced_time == "" and Stage.arg("--sit") == "":
		work = DeskWork.new()
		add_child(work)
		work.setup(self, layer, FREE_SEATS)
		if not OS.get_cmdline_user_args().has("--no-morning"):
			var mo := Morning.new()
			add_child(mo)
			mo.setup(self)
	Narrator.skippable = false
	Narrator.taps = true
	Story.load_saved()
	if work and Story.beat == "monday":
		_monday(layer)
	elif forced_time == "":
		_arrive(layer)
	var v := Stage.arg("--view").split_floats(",")
	if v.size() == 6:
		fixed_view = true
		cam.position = Vector3(v[0], v[1], v[2])
		cam.look_at(Vector3(v[3], v[4], v[5]), Vector3.UP)
	_place_camera(1.0)
	still = Stage.still_args()

func _monday(layer: CanvasLayer) -> void:
	_marker = Label3D.new()
	_marker.text = "▼"
	_marker.font_size = 72
	_marker.pixel_size = 0.004
	_marker.modulate = Color("ff8c69")
	_marker.outline_modulate = Color("fff8ef")
	_marker.outline_size = 14
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.position = seat(FREE_SEATS[0][0], FREE_SEATS[0][1])[0] + Vector3(0, 1.0, 0)
	add_child(_marker)
	Narrator.taps = false
	Narrator.skippable = true
	Narrator.skip_requested.connect(Narrator.clear)
	await get_tree().create_timer(0.5).timeout
	await Narrator.say("NARR_4_1")
	Narrator.skip_requested.disconnect(Narrator.clear)
	Narrator.skippable = false
	Narrator.taps = true
	_arrive(layer, 0.2)

func _arrive(layer: CanvasLayer, delay := 0.6) -> void:
	var place := Label.new()
	place.text = tr("OFFICE_PLACE")
	place.add_theme_font_size_override("font_size", 40)
	place.add_theme_color_override("font_color", Color("fff8ef"))
	place.add_theme_color_override("font_outline_color", Color("8a5a48"))
	place.add_theme_constant_override("outline_size", 12)
	place.anchor_right = 1.0
	place.offset_top = 132
	place.offset_bottom = 202
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place.modulate.a = 0.0
	layer.add_child(place)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(place, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.6)
	tw.tween_property(place, "modulate:a", 0.0, 1.0)
	tw.tween_callback(place.queue_free)
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	if not tod["people"] or bool(cfg.get_value("tips", "office", false)):
		return
	cfg.set_value("tips", "office", true)
	cfg.save("user://settings.cfg")
	var tips := Label.new()
	tips.text = tr("OFFICE_TIPS")
	tips.add_theme_font_size_override("font_size", 24)
	tips.add_theme_color_override("font_color", UiTheme.INK)
	tips.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.98, 0.95, 0.94), 18, Color("f6dccf"), 2, 18))
	tips.anchor_left = 0.5
	tips.anchor_right = 0.5
	tips.anchor_top = 0.9
	tips.anchor_bottom = 0.9
	tips.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tips.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tips.modulate.a = 0.0
	layer.add_child(tips)
	var tt := create_tween()
	tt.tween_interval(delay + 1.2)
	tt.tween_property(tips, "modulate:a", 1.0, 0.5)
	tt.tween_interval(9.0)
	tt.tween_property(tips, "modulate:a", 0.0, 1.0)
	tt.tween_callback(tips.queue_free)

func _build_room() -> void:
	var hx := ROOM.x / 2.0
	var hz := ROOM.y / 2.0
	Props._part(world, world, Props._box(Vector3(ROOM.x, 0.1, ROOM.y)), surface("floor"), Vector3(0, -0.05, 0))
	Props.solid(world, WorldBoundaryShape3D.new(), Vector3.ZERO)

	Props._part(world, world, Props._box(Vector3(ROOM.x + 0.4, 0.3, ROOM.y + 0.4)), Color("cfc6ba"), Vector3(0, -0.2, 0))

	Props._part(world, world, Props._box(Vector3(5.4, 0.012, 4.9)), surface("rug"), Vector3(-1.75, 0.006, -0.75))

	Props._part(world, world, Props._box(Vector3(hx - BOSS_GLASS_X - 0.1, 0.014, hz - 0.8)), surface("boss_rug"),
		Vector3((BOSS_GLASS_X + hx) / 2.0, 0.007, (-hz - 0.7) / 2.0))

	for sx in [-1, 1]:
		var x: float = sx * (hx + 0.1)
		if sx < 0:
			_wall(Vector3(x, 0, -hz), Vector3(x, 0, 2.25))
			_wall(Vector3(x, 0, 3.35), Vector3(x, 0, hz))
			Props._part(world, world, Props._box(Vector3(0.24, WALL_H - 2.1, 1.1)), surface("wall"), Vector3(x, 2.1 + (WALL_H - 2.1) / 2, 2.8))

			Furniture.place(world, "office_door", Vector3(-hx, 0, 2.8), 90.0, false)
		else:
			_wall(Vector3(x, 0, -hz), Vector3(x, 0, hz))

	var z0 := -hz - 0.1
	Props._part(world, world, Props._box(Vector3(ROOM.x + 0.4, 0.75, 0.2)), surface("wall"), Vector3(0, 0.375, z0))
	Props._part(world, world, Props._box(Vector3(ROOM.x + 0.4, 0.06, 0.32)), Color("ffffff"), Vector3(0, 0.78, z0 + 0.05))
	Props._part(world, world, Props._box(Vector3(ROOM.x + 0.4, WALL_H - 2.45, 0.2)), surface("wall"), Vector3(0, 2.45 + (WALL_H - 2.45) / 2, z0))
	var piers := 5
	for i in piers + 1:
		var px := -hx + ROOM.x * i / piers
		Props._part(world, world, Props._box(Vector3(0.3, WALL_H, 0.22)), surface("wall"), Vector3(px, WALL_H / 2, z0))
		if i < piers:
			var cx := px + ROOM.x / piers / 2.0
			Props._part(world, world, Props._box(Vector3(0.05, 1.7, 0.06)), FRAME, Vector3(cx, 1.6, z0))
			Props._part(world, world, Props._box(Vector3(ROOM.x / piers - 0.3, 0.05, 0.06)), FRAME, Vector3(cx, 2.05, z0))
	var wb := BoxShape3D.new()
	wb.size = Vector3(ROOM.x + 0.4, WALL_H, 0.3)
	Props.solid(world, wb, Vector3(0, WALL_H / 2, z0))

	var door := BoxShape3D.new()
	door.size = Vector3(0.3, WALL_H, 1.2)
	Props.solid(world, door, Vector3(-hx - 0.1, WALL_H / 2, 2.8))
	var front := BoxShape3D.new()
	front.size = Vector3(ROOM.x + 0.4, WALL_H, 0.3)
	Props.solid(world, front, Vector3(0, WALL_H / 2, hz + 0.15))

func surface(kind: String, origin := Vector2.INF) -> ShaderMaterial:
	if _surface_mats.has(kind):
		return _surface_mats[kind]
	var s: Array = SURFACES[kind]
	var m := ShaderMaterial.new()
	m.shader = SURFACE_SHADER
	m.set_shader_parameter("tile_alb", load("res://props/surfaces/%s_alb.png" % s[0]))
	m.set_shader_parameter("tile_nrm", load("res://props/surfaces/%s_nrm.png" % s[0]))
	m.set_shader_parameter("has_nrm", true)
	m.set_shader_parameter("tile_size", s[1])
	m.set_shader_parameter("base_color", s[2])
	if origin != Vector2.INF:
		m.set_shader_parameter("tile_origin", origin)
		m.set_shader_parameter("clamp_tile", true)
	_surface_mats[kind] = m
	return m

func _wall(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var mid := (a + b) / 2.0
	var size := Vector3(0.2 if absf(d.x) < 0.01 else d.length(), WALL_H, 0.2 if absf(d.z) < 0.01 else d.length())
	Props._part(world, world, Props._box(size), surface("wall"), mid + Vector3(0, WALL_H / 2, 0))

	var base := Vector3(0.26 if absf(d.x) < 0.01 else d.length() + 0.006, 0.14, 0.26 if absf(d.z) < 0.01 else d.length() + 0.006)
	Props._part(world, world, Props._box(base), BASE, mid + Vector3(0, 0.07, 0))
	var bs := BoxShape3D.new()
	bs.size = size
	Props.solid(world, bs, mid + Vector3(0, WALL_H / 2, 0))

func _build_window_view() -> void:
	var hx := ROOM.x / 2.0
	var z0 := -ROOM.y / 2.0 - 0.2
	var depth := 3.2
	var w := ROOM.x + 0.4
	Props._part(world, world, Props._box(Vector3(w + 4.0, 1.4, 0.05)), Color(tod["sky"][0]), Vector3(0, 1.0, z0 - depth), Vector3.ZERO, Vector3.ONE, false)
	Props._part(world, world, Props._box(Vector3(w + 4.0, 1.5, 0.05)), Color(tod["sky"][1]), Vector3(0, 2.45, z0 - depth), Vector3.ZERO, Vector3.ONE, false)
	Props._part(world, world, Props._box(Vector3(w + 4.0, 1.2, 0.05)), Color(tod["sky"][2]), Vector3(0, 3.8, z0 - depth), Vector3.ZERO, Vector3.ONE, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 10
	var cols := [Color("dfe7f0"), Color("ece2d4"), Color("d5e4da"), Color("e6dcef"), Color("f1e6d3")]
	for row in 2:
		var zc := z0 - 1.0 - row * 1.3
		var x := -hx - 2.2
		while x < hx + 2.2:
			var bw := rng.randf_range(0.7, 1.6) * (1.0 - row * 0.3)
			if x + bw > hx + 2.3:
				break
			var top := rng.randf_range(0.95, 1.55) + row * 0.35 + (0.55 if rng.randf() < 0.15 else 0.0)
			var c: Color = cols[rng.randi() % cols.size()].lerp(Color("d6e8fb"), row * 0.35)
			c = c.lerp(Color(tod["sky"][1]).darkened(0.35), tod["city"])
			Props._part(world, world, Props._box(Vector3(bw, top - 0.4, 0.6)), c, Vector3(x + bw / 2, 0.4 + (top - 0.4) / 2, zc),
				Vector3.ZERO, Vector3.ONE, false)
			var y := top - 0.16
			while y > 0.85:
				Props._part(world, world, Props._box(Vector3(bw * 0.8, 0.07, 0.02)), _city_window(c.darkened(0.15), rng),
					Vector3(x + bw / 2, y, zc + 0.31), Vector3.ZERO, Vector3.ONE, false)
				y -= 0.17
			if rng.randf() < 0.3:
				Props._part(world, world, Props._cyl(0.09, 0.09, 0.14), Color("b8c2cc"), Vector3(x + bw * 0.3, top + 0.07, zc), Vector3.ZERO, Vector3.ONE, false)
			elif rng.randf() < 0.3:
				Props._part(world, world, Props._cyl(0.01, 0.01, 0.3), Color("9aa4ae"), Vector3(x + bw * 0.7, top + 0.15, zc), Vector3.ZERO, Vector3.ONE, false)
			x += bw + rng.randf_range(0.08, 0.35)

	var xf := -hx - 2.2
	while xf < hx + 2.2:
		var fw := rng.randf_range(0.4, 0.9)
		if xf + fw > hx + 2.3:
			break
		var ft := rng.randf_range(1.5, 2.2)
		Props._part(world, world, Props._box(Vector3(fw, ft - 0.4, 0.3)), Color("cfe2f3").lerp(Color(tod["sky"][1]), 0.3 + tod["city"] * 0.6), Vector3(xf + fw / 2, 0.4 + (ft - 0.4) / 2, z0 - 2.9),
			Vector3.ZERO, Vector3.ONE, false)
		xf += fw + rng.randf_range(0.05, 0.2)

	for tw in [[-3.1, 0.9, Color("e3dccf")], [2.4, 1.1, Color("d9e2ea")]]:
		var tx: float = tw[0]
		var twd: float = tw[1]
		var tc: Color = (tw[2] as Color).lerp(Color(tod["sky"][1]).darkened(0.4), tod["city"])
		Props._part(world, world, Props._box(Vector3(twd, 3.6, 0.5)), tc, Vector3(tx, 2.2, z0 - 0.7), Vector3.ZERO, Vector3.ONE, false)
		var yy := 3.8
		while yy > 0.6:
			Props._part(world, world, Props._box(Vector3(twd * 0.82, 0.12, 0.02)), _city_window(tc.darkened(0.13), rng), Vector3(tx, yy, z0 - 0.44),
				Vector3.ZERO, Vector3.ONE, false)
			yy -= 0.26

	var lid := Props.mat(VOID)
	var top := 4.4
	var wide := w + 4.0
	var sky := Props.mat(Color(tod["sky"][1]))
	var street := Props.mat(Color("c3cedd").lerp(Color(tod["sky"][2]), tod["city"]))
	Props._part(world, world, Props._box(Vector3(wide, 0.05, depth + 0.4)), lid, Vector3(0, top, z0 - depth / 2), Vector3.ZERO, Vector3.ONE, false)
	Props._part(world, world, Props._box(Vector3(wide, 0.02, depth + 0.4)), sky, Vector3(0, top - 0.04, z0 - depth / 2), Vector3.ZERO, Vector3.ONE, false)
	Props._part(world, world, Props._box(Vector3(wide, top - WALL_H, 0.05)), lid, Vector3(0, WALL_H + (top - WALL_H) / 2, z0 - 0.03),
		Vector3.ZERO, Vector3.ONE, false)
	Props._part(world, world, Props._box(Vector3(wide, top - WALL_H, 0.02)), sky, Vector3(0, WALL_H + (top - WALL_H) / 2, z0 - 0.07),
		Vector3.ZERO, Vector3.ONE, false)
	Props._part(world, world, Props._box(Vector3(wide, 0.05, depth)), street, Vector3(0, 0.35, z0 - depth / 2), Vector3.ZERO, Vector3.ONE, false)
	Props._part(world, world, Props._box(Vector3(wide, top, 0.05)), sky, Vector3(0, top / 2, z0 - depth - 0.06), Vector3.ZERO, Vector3.ONE, false)
	for sx in [-1, 1]:
		Props._part(world, world, Props._box(Vector3(0.05, top, depth)), lid, Vector3(sx * wide / 2, top / 2, z0 - depth / 2),
			Vector3.ZERO, Vector3.ONE, false)

		var fx: float = sx * (w / 2 + (wide - w) / 4)

		Props._part(world, world, Props._box(Vector3((wide - w) / 2, top, 0.18)), lid, Vector3(fx, top / 2, z0 + 0.035),
			Vector3.ZERO, Vector3.ONE, false)
		Props._part(world, world, Props._box(Vector3((wide - w) / 2, top, 0.02)), sky, Vector3(fx, top / 2, z0 - 0.075),
			Vector3.ZERO, Vector3.ONE, false)
		Props._part(world, world, Props._box(Vector3(0.02, top, depth)), sky, Vector3(sx * (wide / 2 - 0.04), top / 2, z0 - depth / 2),
			Vector3.ZERO, Vector3.ONE, false)

func _city_window(c: Color, rng: RandomNumberGenerator) -> Variant:
	if tod["lit"] > 0.0 and rng.randf() < tod["lit"]:
		return Props.mat_glow(Color("ffe2a0"), Vector3(0.8, 0.62, 0.3))
	return c

func _furnish() -> void:
	OfficeProps.screen_time = {"day": "10:10", "sunset": "17:40", "night": "01:35"}.get(time_name, "10:10")
	var hx := ROOM.x / 2.0
	var hz := ROOM.y / 2.0

	var front_kind := ["code2", "code", "board", "off"]
	var back_kind := ["design", "code2", "board", "off"]
	for i in DESK_X.size():
		var cx: float = DESK_X[i]
		OfficeProps.desk(world, Vector3(cx, 0, ROW_FRONT), 0.0, Color("ffffff"), front_kind[i] if tod["people"] or i == 1 else "off", 2)
		OfficeProps.chair(world, Vector3(cx, 0, ROW_FRONT + SEAT_OFF + (hero_back if i == 1 else 0.0)), 0.0)
		OfficeProps.desk(world, Vector3(cx, 0, ROW_BACK), 180.0, Color("ffd6a0"), back_kind[i] if tod["people"] else "off", 1)
		OfficeProps.chair(world, Vector3(cx, 0, ROW_BACK - SEAT_OFF), 180.0)

	OfficeProps.glass_wall(world, Vector3(BOSS_GLASS_X, 0, -hz), Vector3(BOSS_GLASS_X, 0, -0.7))
	OfficeProps.glass_wall(world, Vector3(BOSS_GLASS_X, 0, -0.7), Vector3(2.3, 0, -0.7))
	OfficeProps.glass_wall(world, Vector3(3.3, 0, -0.7), Vector3(hx, 0, -0.7))
	OfficeProps.blinds(world, Vector3(BOSS_GLASS_X, 0, -hz + 0.1), Vector3(BOSS_GLASS_X, 0, -0.75))
	OfficeProps.blinds(world, Vector3(3.35, 0, -0.7), Vector3(hx - 0.05, 0, -0.7))
	OfficeProps.desk(world, Vector3(3.0, 0, -2.05), 180.0, Color("8c2f39"), "mail" if tod["people"] else "off", 0, OfficeProps.WOOD_DEEP)
	OfficeProps.chair(world, Vector3(3.0, 0, -2.7), 180.0, true)
	OfficeProps.bookshelf(world, Vector3(hx - 0.7, 0, -hz + 0.22), 0.0)
	OfficeProps.kpi_chart(world, Vector3(hx - 0.03, 1.55, -1.3), -90.0)
	OfficeProps.plant(world, Vector3(2.4, 0, -3.15), 1.0)
	Props._part(world, world, Props._box(Vector3(0.12, 0.1, 0.02)), Color("ffd0e0"), Vector3(3.35, OfficeProps.DESK_H + 0.08, -2.2), Vector3(-15, 160, 0))
	Props._part(world, world, Props._box(Vector3(0.34, 0.08, 0.06)), Color("3a3028"), Vector3(3.0, OfficeProps.DESK_H + 0.065, -1.76))
	_print_on("nameplate.png", Vector3(3.0, OfficeProps.DESK_H + 0.065, -1.73), Vector3.BACK, Vector2(0.34, 0.08), 0.02)

	OfficeProps.coffee_corner(world, Vector3(-hx + 0.4, 0, 1.65), 90.0)
	OfficeProps.water_cooler(world, Vector3(-hx + 0.3, 0, 0.75), 90.0)
	OfficeProps.whiteboard(world, Vector3(-hx + 0.04, 1.45, -1.9), 90.0)

	_print_on("deadline.png", Vector3(-hx + 0.044, 1.825, -1.9), Vector3.RIGHT, Vector2(1.6, 0.12), 0.04)

	OfficeProps.company_logo(world, Vector3(-hx, 1.93, 0.75), 90.0)
	_print_on("dept.png", Vector3(-hx + OfficeProps.LOGO_FACE, 1.93 + OfficeProps.LOGO_LINE_Y, 0.75), Vector3.RIGHT,
		Vector2(1.2, 1.2 * 160.0 / 2048.0), 0.02)
	OfficeProps.printer(world, Vector3(hx - 0.32, 0, 1.3), -90.0)
	for z in [0.0, 0.6]:
		OfficeProps.cabinet(world, Vector3(hx - 0.32, 0, z), -90.0)
	OfficeProps.plant(world, Vector3(-hx + 0.45, 0, -3.1))
	OfficeProps.plant(world, Vector3(0.3, 0, 3.15), 1.1)
	var clock_at: Array = {"day": [10, 10], "sunset": [17, 40], "night": [1, 35]}.get(time_name, [10, 10])
	OfficeProps.clock(world, Vector3(-0.9, 2.62, -hz + 0.02), 0.0, clock_at[0], clock_at[1])

	Props._part(world, world, Props._box(Vector3(2.4, 0.012, 1.8)), surface("lounge_rug", Vector2(3.0 - 1.2, 2.35 - 0.9)),
		Vector3(3.0, 0.006, 2.35))
	OfficeProps.sofa(world, Vector3(3.0, 0, 3.05), 180.0)
	OfficeProps.low_table(world, Vector3(3.0, 0, 2.1))
	OfficeProps.floor_lamp(world, Vector3(4.15, 0, 3.15))

	Props._part(world, world, Props._box(Vector3(0.006, 0.42, 0.30)), Color("fbfaf7"), Vector3(-hx + 0.003, 1.75, 2.0))
	_print_on("calendar.png", Vector3(-hx + 0.006, 1.75, 2.0), Vector3.RIGHT, Vector2(0.30, 0.42), 0.01)

func _clutter() -> void:
	var top := OfficeProps.TOP
	var h := HERO_DESK

	_put("paper_stack", h + Vector3(0.4, top, 0.2), 6.0)
	_put("paper_stack", h + Vector3(0.42, top + 0.4, -0.18), -9.0)
	for at in [Vector3(-0.52, 0, 0.06), Vector3(-0.34, 0, 0.12), Vector3(-0.22, 0, 0.3)]:
		_put("coffee_cup", h + at + Vector3(0, top, 0)).scale = Vector3.ONE * 1.15
	_put("noodle_cup", h + Vector3(-0.48, top, 0.26), 20.0)
	_put("energy_can", h + Vector3(0.56, top, 0.3))
	var notes := [[Vector3(-0.29, 0.45, 0), 8.0], [Vector3(-0.29, 0.36, 0), -6.0], [Vector3(0.29, 0.47, 0), -10.0],
		[Vector3(0.29, 0.39, 0), 5.0], [Vector3(-0.12, 0.51, 0), 3.0], [Vector3(0.1, 0.51, 0), -4.0]]
	var note_c := [Color("fff08a"), Color("ffc4d6"), Color("c6f0b0"), Color("fff08a"), Color("bfe3ff"), Color("ffc4d6")]
	for k in notes.size():
		Props._part(world, world, Props._box(Vector3(0.065, 0.065, 0.004)), note_c[k],
			h + OfficeProps.PC + notes[k][0] + Vector3(0, 0, 0.026), Vector3(0, 0, notes[k][1]), Vector3.ONE, false)
	Props._part(world, world, Props._box(Vector3(0.12, 0.09, 0.015)), Color("a8d8a0"), h + Vector3(-0.42, top + 0.04, 0.01), Vector3(-15, 25, 0))

	var tg := Vector3(DESK_X[0], 0, ROW_FRONT)
	_put("small_cactus", tg + Vector3(-0.3, top, 0.22))
	_put("flask", tg + Vector3(0.3, top, 0.24))

	var kh := Vector3(DESK_X[1], 0, ROW_BACK)
	_put("phin_cup", kh + Vector3(0.3, top, -0.22), 180.0)
	_put("candy_bag", kh + Vector3(-0.42, top, -0.25), 200.0)

	var ng := Vector3(DESK_X[2], 0, ROW_BACK)
	_put("strawberry_mug", ng + Vector3(0.38, top, -0.2), 180.0)
	_put("seat_cushion", Vector3(DESK_X[2], 0.5, ROW_BACK - SEAT_OFF - 0.2)).rotation_degrees.x = 10.0

	var mon := top + 0.513
	_put("big_cactus", Vector3(DESK_X[0] - 0.3, 0.9675, ROW_FRONT - 0.36))
	_put("robot_toy", Vector3(DESK_X[0] + 0.12, mon, ROW_FRONT + OfficeProps.PC.z))
	_put("headphones", Vector3(DESK_X[1] - 0.6, 0.9075, ROW_FRONT - 0.45)).scale = Vector3.ONE * 1.3

	_put("strawberry_plush", Vector3(DESK_X[2] - 0.6, 0.9075, ROW_BACK - 0.12), 160.0).scale = Vector3.ONE * 0.8

	for c in [[Vector3(DESK_X[3], 0.72, ROW_FRONT + SEAT_OFF + 0.42), "coat_brown", 0.0],
			[Vector3(DESK_X[3], 0.72, ROW_BACK - SEAT_OFF - 0.42), "coat_blue", 180.0]]:
		var coat := _put("coat", c[0], c[2], c[1])
		coat.rotation_degrees.x = 8.0
		coat.scale = Vector3(1.1, 1.0, 1.0)
	_put("floor_bag", Vector3(0.62, 0, 1.62), 20.0)

	_put("basil_pot", Vector3(0.9, 0.81, -ROOM.y / 2.0 + 0.02))

func _put(name: String, pos: Vector3, yaw := 0.0, skin := "") -> Node3D:
	return Furniture.place(world, name, pos, yaw, false, skin)

func _people_layer(n: Node) -> void:
	for v in n.find_children("*", "VisualInstance3D", true, false):
		(v as VisualInstance3D).layers = 2

func _light() -> void:
	var hx := ROOM.x / 2.0
	var hz := ROOM.y / 2.0
	var piers := 5
	if tod["streak"][1] > 0.0:
		for k in piers:
			var cx := -hx + ROOM.x * (k + 0.5) / piers
			_sun_streak(Vector3(cx + 0.7, 1.2, -0.9), Vector3(0.8, 2.6, 4.8), 16.0, Color(tod["streak"][0]), tod["streak"][1])
	if tod["cast"] > 0.0:
		_glow(Vector3(-1.45, 0.016, -0.05), Vector2(6.2, 5.6), Color("dde9ff"), tod["cast"], true)

	_glow(Vector3(3.5, 0.018, 2.85), Vector2(2.8, 2.2), Color("ffb45a"), tod["lamp"], true)
	_glow(Vector3(hx - 0.04, 1.35, 2.85), Vector2(1.6, 1.6), Color("ffb45a"), tod["lamp"] * 0.7, true, 0.0, true)
	if not tod["people"]:
		_night_desk()

func _night_desk() -> void:
	var h := HERO_DESK
	var dh := OfficeProps.DESK_H
	_put("desk_lamp", h + Vector3(0.53, OfficeProps.TOP, 0.02), -30.0)
	_glow(h + Vector3(0.15, dh + 0.06, 0.05), Vector2(1.6, 1.1), Color("ffc06a"), 0.75, true)
	_glow(h + Vector3(0, 0.02, 0.55), Vector2(2.8, 2.4), Color("ffb060"), 0.5, true)

	_put("phone", h + Vector3(0.22, OfficeProps.TOP, 0.29), -15.0)

	_glow(h + Vector3(0, dh + 0.06, -0.05), Vector2(0.9, 0.6), Color("8fb8ff"), 0.35, true)

func _sun_streak(pos: Vector3, size: Vector3, yaw: float, c: Color, energy: float) -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var d := Decal.new()
	d.size = size
	d.texture_emission = tex
	d.emission_energy = energy
	d.modulate = c
	d.albedo_mix = 0.0
	d.upper_fade = 0.1
	d.normal_fade = 0.6
	d.lower_fade = 0.1
	d.cull_mask = 1
	d.position = pos
	d.rotation.y = deg_to_rad(yaw)
	world.add_child(d)

func _glow(pos: Vector3, size: Vector2, c: Color, alpha: float, radial: bool, yaw := 0.0, wall := false) -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	if radial:
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
	else:
		tex.fill_from = Vector2(0.5, 0.0)
		tex.fill_to = Vector2(0.5, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.albedo_texture = tex
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	q.mesh = pm
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = pos
	if wall:
		q.rotation = Vector3(0, 0, deg_to_rad(90))
	else:
		q.rotation.y = deg_to_rad(yaw)
	world.add_child(q)

func _print_on(file: String, at: Vector3, normal: Vector3, size: Vector2, depth := 0.06) -> void:
	var d := Decal.new()
	d.texture_albedo = load(Lang.path_for("res://props/signs", file))
	d.size = Vector3(size.x, depth, size.y)
	var right := Vector3.UP.cross(normal).normalized()
	d.basis = Basis(right, normal, right.cross(normal))
	d.position = at
	d.upper_fade = 0.0
	d.lower_fade = 0.0
	d.normal_fade = 0.5
	d.cull_mask = 1
	world.add_child(d)

static func seat(row: String, i: int) -> Array:
	if row == "front":
		return [Vector3(DESK_X[i], 0, ROW_FRONT + SEAT_OFF), PI]
	return [Vector3(DESK_X[i], 0, ROW_BACK - SEAT_OFF), 0.0]

const ROOM_CAM := [Vector3(-0.2, 6.8, 9.6), Vector3(-0.2, 0.2, -0.5)]
var cam_mode := "room"
var cam_zoom := 1.0
var cam_side := 0.0

func _unhandled_input(e: InputEvent) -> void:
	if fixed_view:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_V:
		cam_mode = "follow" if cam_mode == "room" else "room"
	if e is InputEventMouseButton and e.pressed and cam_mode == "room":
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_zoom = maxf(0.5, cam_zoom - 0.08)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_zoom = minf(1.0, cam_zoom + 0.08)

func _place_camera(k: float) -> void:
	if fixed_view:
		return
	if cam_mode == "room":
		var follow := lerpf(0.12, 0.9, (1.0 - cam_zoom) / 0.5)
		follow = lerpf(follow, 1.0, clampf(cam_side * 4.0, 0.0, 1.0))
		var drift := (player.global_position - Vector3(ROOM_CAM[1].x, 0, 0.4)) * follow
		drift.y = 0.0
		var look: Vector3 = ROOM_CAM[1] + drift
		var eye: Vector3 = look + (ROOM_CAM[0] - ROOM_CAM[1]) * cam_zoom
		_slide(eye.distance_to(look), k)
		cam.global_position = cam.global_position.lerp(eye, k)
		cam.look_at(cam.global_position + (look - eye), Vector3.UP)
		return
	var target := player.global_position + Vector3(0, 0.6, 0)
	target.x = clampf(target.x, -1.6, 1.6)
	target.z -= 0.8
	var want := target + Vector3(0, 4.3, 7.4)
	_slide(want.distance_to(target), k)
	cam.global_position = cam.global_position.lerp(want, k)
	cam.look_at(target, Vector3.UP)

func _slide(dist: float, k: float) -> void:
	"""Move the view sideways (the camera's h_offset) so the player sits cam_side of the width left of centre."""
	var width := 2.0 * dist * tan(deg_to_rad(cam.fov) * 0.5) * get_viewport().get_visible_rect().size.aspect()
	cam.h_offset = lerpf(cam.h_offset, cam_side * width, k)

func _process(delta: float) -> void:
	t += delta
	_place_camera(1.0 - exp(-delta * 5.0))
	if _marker:
		_marker.position.y = 1.0 + 0.06 * sin(t * 3.0)
		if Story.reached("reflection"):
			_marker.queue_free()
			_marker = null
	if still.size() == 2 and still[0] != "" and t >= still[1]:
		set_process(false)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(still[0])
		get_tree().quit()
