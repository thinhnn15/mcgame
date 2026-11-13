extends Node3D

const DIR := "res://data/hometown/"
const CHUNK := 32
const KHU := 512.0
const KHU_SHOW := 640.0
const LABEL_END := 220.0
const KARST_DIR := "res://props/hometown/karst/"
const KARST_NEAR := 380.0
const GRASS_END := 60.0
const SIZE_ENDS := [[1.5, 45.0], [4.0, 90.0], [12.0, 250.0]]
const PAL := {0: Color("7ab258"), 1: Color("96c478"), 2: Color("86ad5a"), 3: Color("ceb284"), 4: Color("cfc8b8"),
	5: Color("e2d4a0"), 6: Color("6a8aa8"), 7: Color("c4a882"), 8: Color("609850"), 9: Color("5c8a4a"), 10: Color("8fa872"),
	11: Color("665e58"), 12: Color("514b45"), 13: Color("8a6646"), 14: Color("9c7a64")}

var N := 641
var HALF := 320
var PLAY := 240.0
var VPLAY := 300.0
var terrain: HomeTerrain
var khus := {}
var stats: Label
var fly := []
var measure := false
var house_level := 0
var _tarp: Node3D
var _tarp_flat: Node3D

var heights: PackedFloat32Array
var mats: Image
var layout: Dictionary
var player: Player
var cam: Camera3D
var cam_dist := 11.0
var map_view := false
var fixed_view := false
var still := []
var t := 0.0

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	add_to_group("hometown")
	var clean := OS.get_cmdline_user_args().has("--clean")
	show_names = not clean and not OS.get_cmdline_user_args().has("--no-names")
	var sun := Stage.setup(self)
	Stage.clouds(not OS.get_cmdline_user_args().has("--night"))
	if not OS.get_cmdline_user_args().has("--no-moss"):
		RenderingServer.global_shader_parameter_set("weathering", 1.0)
	if OS.get_cmdline_user_args().has("--night"):
		HomeKit.night_look.call_deferred(self, sun)
	heights = FileAccess.get_file_as_bytes(DIR + "height.f32").to_float32_array()
	mats = Image.load_from_file(ProjectSettings.globalize_path(DIR + "mat.png")) if not TexCache.shipped() \
		else (load(DIR + "mat.png") as Texture2D).get_image()
	layout = JSON.parse_string(FileAccess.get_file_as_string(DIR + "layout.json"))
	var gr: Dictionary = layout.get("grid", {})
	N = int(gr.get("n", 641))
	HALF = int(gr.get("half", 320))
	PLAY = float(gr.get("play", 240.0))
	VPLAY = float(gr.get("village", 300.0))
	house_level = int(Stage.arg("--house-level", str(saved_house_level())))
	if Stage.arg("--rice-stage") != "":
		rice_stage = int(Stage.arg("--rice-stage"))
	_mist()
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 2600.0
	add_child(cam)
	player = Player.new()
	add_child(player)
	_build_terrain()
	_build_water()
	_build_places()
	_vlight_pass()
	NhaThoDa.add_to_map(self)
	_build_karst()
	get_viewport().use_occlusion_culling = _occlude
	_build_boat()
	BoatRow.add(self)
	_build_bus()
	TouchControls.add_action(self, _touch_board, 10)
	_build_forest()
	preload("res://scripts/home/ground_ao.gd").after_build(self)
	var sp: Array = layout["spawn"]
	var at := Stage.arg("--spawn").split_floats(",")
	if at.size() == 2:
		sp = [at[0], at[1]]
	player.position = Vector3(sp[0], height_at(sp[0], sp[1]) + 0.2, sp[1])
	player.bounds_box = PLAY
	player.floor_max_angle = deg_to_rad(32.0)
	player.floor_snap_length = 0.4
	player.setup(Looks.load_saved(), cam)
	_farm_door_setup(at.size() == 2)
	_pave = PaveLift.of(self)
	VillageLife.add(self, walk_at, player)
	DayNight.add(self)
	HomeEvents.add(self, height_at, player)
	Phone.add(self, player)
	MiniMap.add(self, player)
	AmbientLife.make(self, player, height_at)
	WaterLife.make(self, player, height_at)
	if Quality.is_high():
		WaterGrid.make(self, player, _sheet_mat, -0.05)
		Underwater.add(self, cam, player)
	var am := Stage.arg("--auto").split_floats(",")
	if am.size() == 2:
		player.auto_move = Vector2(am[0], am[1])
	var v := Stage.arg("--view").split_floats(",")
	if v.size() == 6:
		fixed_view = true
		cam.position = Vector3(v[0], v[1], v[2])
		cam.look_at(Vector3(v[3], v[4], v[5]), Vector3.UP)
	var hint := Label.new()
	hint.text = "Ở quê (bản khối thô, cả vùng 2 × 2 km)   •   WASD: đi   •   Shift: chạy   •   V: xem bản đồ   •   Lăn chuột: zoom   •   F3: số đo   •   N: tên địa danh"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color("fffaf2"))
	hint.add_theme_color_override("font_outline_color", Color("5b4a44"))
	hint.add_theme_constant_override("outline_size", 8)
	hint.position = Vector2(24, 18)
	var layer := CanvasLayer.new()
	layer.add_child(hint)
	stats = Label.new()
	stats.add_theme_font_size_override("font_size", 20)
	stats.add_theme_color_override("font_color", Color("fffaf2"))
	stats.add_theme_color_override("font_outline_color", Color("5b4a44"))
	stats.add_theme_constant_override("outline_size", 8)
	stats.position = Vector2(24, 56)
	layer.add_child(stats)
	add_child(layer)
	layer.visible = not clean
	_place_camera(1.0)
	still = Stage.still_args()
	if Stage.arg("--fly") != "" or OS.get_cmdline_user_args().has("--fly"):
		if Stage.arg("--fly") == "bus":
			player.global_position = Vector3(-685.5, height_at(-685.5, -3.0) + 0.3, -3.0)
			_bus_film = true
			_bus_board.call_deferred(true)
		elif Stage.arg("--fly") == "boat":
			fly = [Vector3.ZERO]
			player.global_position = Vector3(150, height_at(150, 108) + 0.3, 108)
			boat_speed = BOAT_SPEED * 2.0
			_board.call_deferred(true)
		elif Stage.arg("--fly") == "co_do":
			fly = [Vector3(-520, 14, -150), Vector3(-600, 10, -190), Vector3(-600, 9, -262), Vector3(-600, 10, -330),
				Vector3(-620, 14, -390), Vector3(-600, 22, -440), Vector3(-560, 16, -400), Vector3(-610, 30, -330),
				Vector3(-660, 40, -250), Vector3(-700, 45, -150), Vector3(-720, 45, -110)]
			_fly_dur = 40.0
			_fly_clear_r = 6.0
			_fly_look_ahead = true
			_fly_end_look = Vector3(-800, 40, -200)
			player.set_physics_process(false)
		elif Stage.arg("--fly") == "rung_cho":
			fly = [Vector3(-470, 22, 300), Vector3(-540, 30, 400), Vector3(-600, 38, 470), Vector3(-660, 40, 520),
				Vector3(-690, 42, 480), Vector3(-640, 36, 590), Vector3(-610, 34, 690), Vector3(-585, 30, 745)]
			_fly_dur = 40.0
			_fly_clear_r = 6.0
			_fly_look_ahead = true
			_fly_end_look = Vector3(-562, 30, 790)
			player.set_physics_process(false)
		elif Stage.arg("--fly") == "thung_lang":
			fly = _flight_thung_lang()
		else:
			fly = _flight_nui_rong() if Stage.arg("--fly") == "nui_rong" else _flight()
	measure = OS.get_cmdline_user_args().has("--measure")
	print("hometown: built in %d ms" % (Time.get_ticks_msec() - t0))

func _mist() -> void:
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null:
		return
	var env := we.environment
	var sky := ShaderMaterial.new()
	sky.shader = preload("res://shaders/sky_clouds.gdshader")
	sky.set_shader_parameter("top_color", Stage.SKY_TOP)
	sky.set_shader_parameter("horizon_color", Stage.SKY_HORIZON)
	sky.set_shader_parameter("ground_color", Stage.GROUND)
	env.sky.sky_material = sky
	env.fog_enabled = true
	env.fog_light_color = Color("dfe6ea")
	env.fog_density = 0.0005
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.5

var _pave: PaveLift = null

func walk_at(x: float, z: float) -> float:
	var g := height_at(x, z)
	if _pave == null:
		return g
	var t := _pave.top(Vector3(x, g, z))
	return t if t > g and t - g < 0.3 else g

func height_at(x: float, z: float) -> float:
	var fx := clampf(x + HALF, 0, N - 1.001)
	var fz := clampf(z + HALF, 0, N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var ax := fx - ix
	var az := fz - iz
	var h00 := heights[iz * N + ix]
	var h10 := heights[iz * N + ix + 1]
	var h01 := heights[(iz + 1) * N + ix]
	var h11 := heights[(iz + 1) * N + ix + 1]
	return lerpf(lerpf(h00, h10, ax), lerpf(h01, h11, ax), az)

func _build_terrain() -> void:
	terrain = HomeTerrain.new()
	if FileAccess.file_exists(DIR + "road_sdf.png") or ResourceLoader.exists(DIR + "road_sdf.png"):
		var ri := Image.load_from_file(ProjectSettings.globalize_path(DIR + "road_sdf.png")) if not TexCache.shipped() 			else (load(DIR + "road_sdf.png") as Texture2D).get_image()
		ri.convert(Image.FORMAT_L8)
		terrain.road_sdf = ImageTexture.create_from_image(ri)
		terrain.road_sdf_data = ri.get_data()
	if FileAccess.file_exists(DIR + "rail_sdf.png") or ResourceLoader.exists(DIR + "rail_sdf.png"):
		var ra := Image.load_from_file(ProjectSettings.globalize_path(DIR + "rail_sdf.png")) if not TexCache.shipped() 			else (load(DIR + "rail_sdf.png") as Texture2D).get_image()
		ra.convert(Image.FORMAT_L8)
		terrain.rail_sdf = ImageTexture.create_from_image(ra)
		terrain.rail_sdf_data = ra.get_data()
	add_child(terrain)
	terrain.setup(heights, mats, N, HALF, PAL, player)
	_paint_maps()
	var shr: Dictionary = layout.get("shrine", {})
	if not shr.is_empty():
		terrain.set_all("nr_zone", Vector4(shr["x"], shr["z"], float(shr["r"]) + 12.0, 14.0))
		var stp := PackedVector2Array()
		for q: Array in shr.get("stair_simple", shr["stairs"]):
			stp.append(Vector2(q[0], q[1]))
		while stp.size() < 16:
			stp.append(stp[-1])
		terrain.set_all("nr_stairs", stp)
	var shape := HeightMapShape3D.new()
	shape.map_width = N
	shape.map_depth = N
	shape.map_data = heights
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

var _paint_tex: Texture2D
var _paint_dens: PackedByteArray

func _paint_maps() -> void:
	if OS.get_cmdline_user_args().has("--no-paint"):
		return
	if TexCache.exists(DIR + "grass_col.png"):
		var pi := Image.load_from_file(ProjectSettings.globalize_path(DIR + "grass_col.png")) if not TexCache.shipped() \
			else (load(DIR + "grass_col.png") as Texture2D).get_image()
		if pi.is_compressed():
			pi.decompress()
		pi.convert(Image.FORMAT_RGBA8)
		if pi.get_width() == N and pi.get_height() == N:

			var raw := pi.get_data().slice(1)
			raw.append(0)
			var li := Image.create_from_data(N * 4, N, false, Image.FORMAT_L8, raw)
			li.resize(N, N, Image.INTERPOLATE_NEAREST)
			var d := li.get_data()
			var good := true
			for q: Vector2i in [Vector2i(HALF, HALF), Vector2i(HALF - 91, HALF + 37), Vector2i(800, 1100), Vector2i(1000, 900)]:
				good = good and d[q.y * N + q.x] == pi.get_pixel(q.x, q.y).a8
			if good:
				_paint_dens = d
			else:
				push_warning("hometown: grass_col.png's density did not read back; the carpet keeps grass.png")
			pi.convert(Image.FORMAT_RGB8)
			pi.resize(int((N + 1) / 2.0), int((N + 1) / 2.0), Image.INTERPOLATE_BILINEAR)
			_paint_tex = ImageTexture.create_from_image(pi)
			_paint_mat(null)
	if TexCache.exists(DIR + "road_info.png"):
		var ri := Image.load_from_file(ProjectSettings.globalize_path(DIR + "road_info.png")) if not TexCache.shipped() \
			else (load(DIR + "road_info.png") as Texture2D).get_image()
		if ri.is_compressed():
			ri.decompress()
		ri.convert(Image.FORMAT_RG8)
		terrain.set_all("road_info", ImageTexture.create_from_image(ri))
		terrain.set_all("road_info_on", true)

func _paint_mat(m: ShaderMaterial) -> void:
	"""the painted colour on one grass material (null: the ground's three)"""
	if _paint_tex == null:
		return
	for k: Array in [["paint_tex", _paint_tex], ["paint_on", 1.0], ["paint_grid", Vector2(N, HALF)]]:
		if m == null:
			terrain.set_all(k[0], k[1])
		else:
			m.set_shader_parameter(k[0], k[1])

func _water_mat() -> ShaderMaterial:
	"""(03/11) the river / ponds / lake water: shaders/home_water.gdshader, opaque, its depth from a baked map."""
	var m := ShaderMaterial.new()

	m.shader = preload("res://shaders/home_water_hq.gdshader") if Quality.is_high() else preload("res://shaders/home_water.gdshader")
	m.set_shader_parameter("noise_tex", load("res://props/farm/ground/noise.png"))
	m.set_shader_parameter("grid_n", float(N))
	m.set_shader_parameter("grid_half", float(HALF))
	BoatRow.water2(m, DIR)
	if FileAccess.file_exists(DIR + "water_depth.png") or ResourceLoader.exists(DIR + "water_depth.png"):
		var wi := Image.load_from_file(ProjectSettings.globalize_path(DIR + "water_depth.png")) if not TexCache.shipped() 			else (load(DIR + "water_depth.png") as Texture2D).get_image()
		wi.convert(Image.FORMAT_L8)
		m.set_shader_parameter("depth_map", ImageTexture.create_from_image(wi))
	else:
		m.set_shader_parameter("has_depth", false)
	return m

func _water_sheet() -> Mesh:
	var path := DIR + "water_cells.png"
	if not (FileAccess.file_exists(path) or ResourceLoader.exists(path)):
		var pm := PlaneMesh.new()
		pm.size = Vector2(2 * HALF, 2 * HALF)
		return pm
	var ci := Image.load_from_file(ProjectSettings.globalize_path(path)) if not TexCache.shipped() 		else (load(path) as Texture2D).get_image()
	ci.convert(Image.FORMAT_L8)
	var grown := ci.get_data()
	const C := 4
	var n := ci.get_width()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for cz in n:
		var cx := 0
		while cx < n:
			if grown[cz * n + cx] == 0:
				cx += 1
				continue
			var x0 := cx
			while cx < n and grown[cz * n + cx] > 0:
				cx += 1
			var b := verts.size()
			var xa := float(x0 * C - HALF)
			var xb := float(cx * C - HALF)
			var za := float(cz * C - HALF)
			var zb := float((cz + 1) * C - HALF)
			verts.append_array([Vector3(xa, 0, za), Vector3(xb, 0, za), Vector3(xb, 0, zb), Vector3(xa, 0, zb)])
			norms.append_array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
			idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _water_gameplay(surface: float) -> void:
	for pair in [["water_cells.png", 4.0, float(HALF)], ["paddy_cells.png", 1.0, float(HALF) + 0.5]]:
		var path: String = DIR + pair[0]
		if not (FileAccess.file_exists(path) or ResourceLoader.exists(path)):
			continue
		if pair[0] == "paddy_cells.png" and not (rice_stage <= 2 or not ResourceLoader.exists("res://props/farm/lua_0.glb")):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(path)) if not TexCache.shipped() 			else (load(path) as Texture2D).get_image()
		img.convert(Image.FORMAT_L8)
		Water.add(self, surface if pair[0] == "water_cells.png" else 0.72, height_at, Water.mask_test(img, pair[1], pair[2]))

var _sheet_mat: ShaderMaterial

func _build_water() -> void:
	var wm := _water_mat()
	_sheet_mat = wm
	var river := MeshInstance3D.new()
	river.mesh = _water_sheet()
	river.material_override = wm
	river.position.y = -0.05
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(river)
	_water_gameplay(river.position.y)
	var pw := _water_mat()
	pw.set_shader_parameter("paddy", true)
	pw.set_shader_parameter("has_depth", false)
	pw.set_shader_parameter("shallow_col", Color(0.6, 0.78, 0.74))
	pw.set_shader_parameter("ripple_speed", 0.02)
	if FileAccess.file_exists(DIR + "paddy_cells.png") or ResourceLoader.exists(DIR + "paddy_cells.png"):
		var pci := Image.load_from_file(ProjectSettings.globalize_path(DIR + "paddy_cells.png")) if not TexCache.shipped() 			else (load(DIR + "paddy_cells.png") as Texture2D).get_image()
		pci.convert(Image.FORMAT_L8)
		pw.set_shader_parameter("paddy_mask", ImageTexture.create_from_image(pci))
	for f: Dictionary in [layout["fields"]] + layout.get("paddies", []):
		var paddy := MeshInstance3D.new()
		var pp := PlaneMesh.new()
		pp.size = Vector2(f["x1"] - f["x0"], f["z1"] - f["z0"])
		paddy.mesh = pp
		paddy.material_override = pw
		paddy.position = Vector3((f["x0"] + f["x1"]) / 2.0, 0.72, (f["z0"] + f["z1"]) / 2.0)
		paddy.visibility_range_end = KHU_SHOW
		paddy.visible = rice_stage <= 2 or not ResourceLoader.exists("res://props/farm/lua_0.glb")
		add_child(paddy)
	var sm := _water_mat()
	sm.set_shader_parameter("stream", true)
	sm.set_shader_parameter("has_depth", false)
	sm.set_shader_parameter("shallow_col", Color(0.4, 0.78, 0.72))
	sm.set_shader_parameter("deep_col", Color(0.26, 0.6, 0.62))
	for st: Dictionary in layout.get("streams", []):
		_stream(st, sm)

	for c: Dictionary in layout.get("caves", [layout["cave"]]):
		_vault(Vector3(float(c["from"][0]), 0, float(c["from"][1])), Vector3(float(c["to"][0]), 0, float(c["to"][1])), 13.0, 3.0)
	for tn: Dictionary in layout.get("tunnels", []):
		var a := Vector3(float(tn["from"][0]), 0, float(tn["from"][1]))
		var b := Vector3(float(tn["to"][0]), 0, float(tn["to"][1]))
		var ys: Array = tn.get("y", [height_at(a.x, a.z), height_at(b.x, b.z)])
		var pieces := maxi(1, int(a.distance_to(b) / 12.0))
		for k in pieces:
			var u0 := float(k) / pieces
			var u1 := float(k + 1) / pieces
			var y := lerpf(ys[0], ys[1], (u0 + u1) / 2.0)
			_vault(a.lerp(b, u0), a.lerp(b, u1 + 0.02), float(tn["w"]) * 0.75, y + 1.0)

	var tl: Dictionary = layout["region"]["thung_lang"]
	var jade := MeshInstance3D.new()
	var jm := PlaneMesh.new()
	jm.size = Vector2(float(tl["lake"][0]) * 2.0 + 6.0, float(tl["lake"][1]) * 2.0 + 6.0)
	jade.mesh = jm
	var jw := _water_mat()
	jw.set_shader_parameter("shore_col", Color(0.62, 0.86, 0.72))
	jw.set_shader_parameter("shallow_col", Color(0.36, 0.74, 0.62))
	jw.set_shader_parameter("deep_col", Color(0.16, 0.5, 0.46))
	jade.material_override = jw
	jade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	jade.position = Vector3(tl["x"], -0.03, tl["z"])
	_khu_for(Vector2(tl["x"], tl["z"])).add_child(jade)

static func saved_house_level() -> int:
	var lv := 0
	for id in Story.flag("home_fixes_done", []):
		var s := String(id)
		if s.begins_with("nha_muc_") and s.substr(8).is_valid_int():
			lv = maxi(lv, int(s.substr(8)))
	return lv

var _farm_yard: Node3D
var _farm_house: Node3D
var _farm_house_body: StaticBody3D
const HOUSE_MODELS := ["nha_cu", "nha_cu_1", "nha_cu_2", "nha_cu_2", "nha_cu_4"]
var _farm_extras: Array[Node3D] = []
var _farm_fence: Node3D
var _work_site: WorkSite

func building_level() -> int:
	return int(Stage.arg("--building", str(Story.flag("nha_dang_xay", 0))))

func _place_worksite() -> void:
	if _work_site != null:
		_work_site.queue_free()
		_work_site = null

	var flag := int(Story.flag("nha_dang_xay", 0))
	if flag > 0 and Stage.arg("--building") == "" and Stage.arg("--house-level") == "" and flag <= saved_house_level():
		Story.set_flag("nha_dang_xay", 0)
	var b := building_level()
	if b > house_level and _farm_yard != null:
		_work_site = WorkSite.add(_farm_yard, b)

func _place_farm_house() -> void:
	if _farm_yard == null:
		return
	if _farm_house != null:
		_farm_house.queue_free()
	if _farm_house_body != null:
		_farm_house_body.queue_free()
	for e in _farm_extras:
		e.queue_free()
	_farm_extras.clear()
	var model: String = HOUSE_MODELS[clampi(house_level, 0, HOUSE_MODELS.size() - 1)]
	_farm_house = HomeKit.place(_farm_yard, model, Vector3.ZERO)
	_farm_house_body = StaticBody3D.new()
	var main := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(5.2, 3.0, 2.9)
	main.shape = bs
	main.position = Vector3(0, 1.5, -0.35)
	_farm_house_body.add_child(main)
	if house_level >= 2:
		var side := CollisionShape3D.new()
		var ss := BoxShape3D.new()
		ss.size = Vector3(1.85, 2.4, 2.05)
		side.shape = ss
		side.position = Vector3(3.4, 1.2, -0.35)
		_farm_house_body.add_child(side)
	if house_level >= 3:
		_farm_extras.append(HomeKit.place(_farm_yard, "san_gach_nha_cu", Vector3.ZERO))
		_farm_extras.append(HomeKit.place(_farm_yard, "bep_nha_cu", Vector3(-3.9, 0.0, -2.75)))
		var kb := CollisionShape3D.new()
		var ks := BoxShape3D.new()
		ks.size = Vector3(2.05, 2.2, 1.75)
		kb.shape = ks
		kb.position = Vector3(-3.9, 1.1, -2.75)
		_farm_house_body.add_child(kb)
	_farm_yard.add_child(_farm_house_body)
	for c in _farm_yard.get_children():
		if not c is Node3D:
			continue
		var f := String(c.scene_file_path)
		if f.ends_with("/be_nuoc.glb"):
			(c as Node3D).position = Vector3(5.1, 0.0, 2.0) if house_level >= 2 else Vector3(3.7, 0.0, -1.1)
		elif f.ends_with("/dong_rom.glb"):
			(c as Node3D).position = Vector3(-5.7, 0.0, 3.3) if house_level >= 3 else Vector3(-5.6, 0.0, -2.6)
	_place_worksite()

func _place_farm_fence() -> void:
	if _farm_fence != null:
		_farm_fence.queue_free()
	var kind := "gach" if house_level >= 3 else ("gon" if que_chapter() >= 4 else "xieu")
	_farm_fence = HomeKit.place_layout(_farm_yard, "res://data/hometown/rao_nha_cu_%s.json" % kind, false)
	_farm_fence.name = "Rao"

func set_house_level(n: int) -> void:
	Story.set_flag("home_levels_v", 2)
	house_level = n
	_place_farm_house()
	_place_farm_fence()
	set_roof_mended(n >= 1)

func set_roof_mended(on: bool) -> void:
	if _tarp != null:
		_tarp.visible = not on
	if _tarp_flat != null:
		_tarp_flat.visible = on and house_level < 2

func _vault(a: Vector3, b: Vector3, r: float, y: float) -> void:
	var vault := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 16
	cyl.cap_top = false
	cyl.cap_bottom = false
	vault.mesh = cyl
	vault.material_override = _cave_mat()
	vault.position = (a + b) / 2.0 + Vector3(0, y, 0)
	vault.rotation = Vector3(0, -atan2(b.z - a.z, b.x - a.x), PI / 2)
	vault.scale = Vector3(1, 1, 0.75)
	add_child(vault)

var _cave: StandardMaterial3D

func _cave_mat() -> StandardMaterial3D:
	if _cave == null:
		_cave = StandardMaterial3D.new()
		_cave.albedo_color = Color("5e5a55")
		_cave.roughness = 1.0
		_cave.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _cave

func _stream(st: Dictionary, wm: Material) -> void:
	var pts: Array = st["points"]
	var lens := [0.0]
	for i in range(1, pts.size()):
		lens.append(lens[-1] + Vector2(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]).length())
	var hw: float = float(st["w"]) * 0.5 + 0.7
	var bed: Array = st["bed"]
	var edge := []
	for sb: Array in bed:
		var q := _along(pts, lens, float(sb[0]))
		var side: Vector2 = q[1].orthogonal() * hw
		var y: float = float(sb[1]) + 0.55
		edge.append([Vector3(q[0].x + side.x, y, q[0].y + side.y), Vector3(q[0].x - side.x, y, q[0].y - side.y)])

	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var foot := 0.0
	for i in range(1, bed.size()):
		var run: float = maxf(float(bed[i][0]) - float(bed[i - 1][0]), 0.001)
		var steep := smoothstep(0.1, 0.4, (float(bed[i - 1][1]) - float(bed[i][1])) / run)
		var n := verts.size()
		for j in [i - 1, i]:
			verts.append_array([edge[j][0], edge[j][1]])
			uvs.append_array([Vector2(0.0, bed[j][0]), Vector2(1.0, bed[j][0])])
			var c := Color(steep, foot if j == i - 1 else 0.0, 0.0)
			cols.append_array([c, c])
		idx.append_array([n, n + 2, n + 1, n + 1, n + 2, n + 3])
		foot = 1.0 if steep > 0.5 else 0.0
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(range(verts.size()).map(func(_i): return Vector3.UP))
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = wm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var home := _khu_for(Vector2(pts[0][0], pts[0][1]))
	home.add_child(mi)

	var surf := _stream_surface(pts, lens, bed, hw)
	Water.add_surface(self, surf, func(x: float, z: float) -> float: return maxf(height_at(x, z), surf.call(x, z) - 0.55))
	_stream_ways.append([pts, lens, hw + 7.0])

static func _stream_near(pts: Array, lens: Array, x: float, z: float) -> Vector2:
	var q := Vector2(x, z)
	var best := INF
	var s_ := 0.0
	for i in range(1, pts.size()):
		var a := Vector2(pts[i - 1][0], pts[i - 1][1])
		var ab := Vector2(pts[i][0], pts[i][1]) - a
		var t := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := q.distance_squared_to(a + ab * t)
		if d < best:
			best = d
			s_ = lens[i - 1] + t * (lens[i] - lens[i - 1])
	return Vector2(sqrt(best), s_)

func _stream_surface(pts: Array, lens: Array, bed: Array, hw: float) -> Callable:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for p in pts:
		lo = lo.min(Vector2(p[0], p[1]))
		hi = hi.max(Vector2(p[0], p[1]))
	lo -= Vector2(hw, hw)
	hi += Vector2(hw, hw)
	var bs := PackedFloat32Array(bed.map(func(b): return float(b[0])))
	var by := PackedFloat32Array(bed.map(func(b): return float(b[1]) + 0.55))
	return func(x: float, z: float) -> float:
		if x < lo.x or z < lo.y or x > hi.x or z > hi.y:
			return NAN
		var ds := _stream_near(pts, lens, x, z)
		if ds.x > hw:
			return NAN
		var k := clampi(bs.bsearch(ds.y), 1, bs.size() - 1)
		return lerpf(by[k - 1], by[k], clampf((ds.y - bs[k - 1]) / maxf(bs[k] - bs[k - 1], 0.001), 0.0, 1.0))

func _along(pts: Array, lens: Array, s_: float) -> Array:
	var k := 1
	while k < lens.size() - 1 and lens[k] < s_:
		k += 1
	var p0 := Vector2(pts[k - 1][0], pts[k - 1][1])
	var p1 := Vector2(pts[k][0], pts[k][1])
	var u: float = clampf((s_ - lens[k - 1]) / maxf(lens[k] - lens[k - 1], 0.001), 0.0, 1.0)
	return [p0.lerp(p1, u), (p1 - p0).normalized()]

func _build_nui_rong() -> void:
	if not OS.get_cmdline_user_args().has("--nui-rong-greybox"):
		NuiRong.build(self)
		return
	var s: Dictionary = layout["shrine"]
	if not s.has("stairs"):
		return
	var pts: Array = s["stairs"]
	var y0: float = s["stair_y"][0]
	var y1: float = s["stair_y"][1]
	var total := 0.0
	for i in range(1, pts.size()):
		total += Vector2(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]).length()
	var steps: Array = []
	var walked := 0.0
	var w: float = s["stair_w"]
	for i in range(1, pts.size()):
		var a := Vector2(pts[i - 1][0], pts[i - 1][1])
		var b := Vector2(pts[i][0], pts[i][1])
		var ln := a.distance_to(b)
		var dir := (b - a) / ln
		var yaw := atan2(dir.x, dir.y)
		var d := 0.0
		while d < ln:
			var p := a + dir * d
			var y := y0 + (y1 - y0) * (walked + d) / total
			steps.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y - 0.06, p.y)))
			d += 0.55
		walked += ln
	var slab := BoxMesh.new()
	slab.size = Vector3(w, 0.3, 0.62)
	_multimesh_mat(slab, steps, Props.mat(Color("bdb6a6")))

	var top := Vector3(pts[-1][0], y1, pts[-1][1])
	Props.mesh(self, Props.cyl(7.5, 7.8, 0.6), Color("c9c2b0"), top + Vector3(0, -0.1, 0))
	for k in 3:
		var tw := 3.2 - k * 0.8
		Props.mesh(self, Props.box(Vector3(tw, 2.2, tw)), Color("e2d6bc"), top + Vector3(3.5, 1.1 + k * 2.6, -3.0))
		Props.mesh(self, Props.box(Vector3(tw + 1.0, 0.35, tw + 1.0)), Color("6a4a3a"), top + Vector3(3.5, 2.35 + k * 2.6, -3.0))
	_label("Đỉnh Núi Rồng", top + Vector3(0, 12, 0), 1.2)

	var body: Array = []
	var dp: Array = s["dragon"]
	var u := 0.0
	for i in range(1, dp.size()):
		var a := Vector2(dp[i - 1][0], dp[i - 1][1])
		var b := Vector2(dp[i][0], dp[i][1])
		var ln := a.distance_to(b)
		var d := 0.0
		while d < ln:
			var p := a + (b - a) * d / ln
			var r := lerpf(1.1, 0.35, u / 60.0)
			var y := height_at(p.x, p.y) + r * 0.6 + 0.7 * sin(u * 0.45)
			body.append(Transform3D(Basis().scaled(Vector3(r, r * 0.85, r)), Vector3(p.x, y, p.y)))
			d += 0.9
			u += 0.9
		if u > 60.0:
			break
	var seg := SphereMesh.new()
	seg.radius = 1.0
	seg.height = 2.0
	seg.radial_segments = 10
	seg.rings = 5
	_multimesh_mat(seg, body, Props.mat(Color("a8a294")))
	var head := Vector3(dp[0][0], height_at(dp[0][0], dp[0][1]) + 1.2, dp[0][1])
	Props.mesh(self, Props.box(Vector3(1.6, 1.3, 2.4)), Color("a8a294"), head)
	for sx in [-0.5, 0.5]:
		Props.mesh(self, Props.cyl(0.12, 0.05, 1.2), Color("8e887a"), head + Vector3(sx, 1.1, 0.4), Vector3(-30, 0, sx * 30))

	var lotus: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for lp: Array in layout.get("lotus", []):
		var sc := rng.randf_range(0.85, 1.2)
		lotus.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(lp[0], -0.05, lp[1])))
	if not lotus.is_empty() and ResourceLoader.exists("res://props/farm/sen_3.glb"):
		var lm := ShaderMaterial.new()
		lm.shader = preload("res://shaders/crop_foliage.gdshader")
		lm.set_shader_parameter("atlas", load("res://props/farm/dong_atlas.png"))
		_multimesh_mat(_first_mesh("res://props/farm/sen_3.glb"), lotus, lm, 160.0)

func _multimesh_mat(mesh: Mesh, xforms: Array, m: Material, end := 0.0) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	if end > 0.0:
		var c := Vector3.ZERO
		for x: Transform3D in xforms:
			c += x.origin
		c /= maxf(xforms.size(), 1)
		for i in xforms.size():
			mm.set_instance_transform(i, Transform3D(xforms[i].basis, xforms[i].origin - c))
		mi.position = c
		mi.visibility_range_end = end
	add_child(mi)

var _hip_mesh: CylinderMesh

func _hip(home: Node3D, at: Vector3, w: float, d: float, h: float, yaw: float, c: Color) -> void:
	if _hip_mesh == null:
		_hip_mesh = CylinderMesh.new()
		_hip_mesh.radial_segments = 4
		_hip_mesh.rings = 1
		_hip_mesh.bottom_radius = 0.7071
		_hip_mesh.top_radius = 0.12
		_hip_mesh.height = 1.0
	var mi := Props._part(home, home, _hip_mesh, c, Vector3.ZERO)
	mi.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)) * Basis().scaled(Vector3(w, h, d)) * Basis(Vector3.UP, PI / 4.0),
		at + Vector3(0, h / 2.0, 0))

func _house_block(kind: String, p: Vector3, yaw: float, wall: Color) -> void:
	var r := Basis(Vector3.UP, deg_to_rad(yaw))
	match kind:
		"thai", "nhat":

			_piece(self, Props.box(Vector3(8.4, 0.5, 6.8)), STONE, p + Vector3(0, 0.25, 0), Vector3(0, yaw, 0))
			_piece(self, Props.box(Vector3(7.6, 2.8, 5.2)), wall, p + Vector3(0, 1.9, 0), Vector3(0, yaw, 0))
			for cx in [-2.9, -1.0, 1.0, 2.9]:
				_piece(self, Props.cyl(0.14, 0.14, 2.7), Color("f8f4ec"), p + r * Vector3(cx, 1.85, 3.15))
			if kind == "thai":
				_hip(self, p + Vector3(0, 3.3, 0), 10.0, 8.0, 2.8, yaw, Color("b8483a"))
			else:
				_hip(self, p + Vector3(0, 3.3, 0), 10.6, 8.6, 1.7, yaw, Color("5c6670"))
		"ong":
			_piece(self, Props.box(Vector3(4, 8.4, 10)), wall, p + Vector3(0, 4.2, 0), Vector3(0, yaw, 0))
			for fl in [2.9, 5.7]:
				_piece(self, Props.box(Vector3(4.2, 0.2, 1.1)), Color("d8d2c6"), p + r * Vector3(0, fl, 5.5), Vector3(0, yaw, 0))
				_piece(self, Props.box(Vector3(4.2, 0.7, 0.07)), Color("4a4a4a"), p + r * Vector3(0, fl + 0.45, 6.0), Vector3(0, yaw, 0))
			_piece(self, Props.box(Vector3(3.2, 1.8, 3.2)), Color("7f98a8"), p + r * Vector3(0, 9.3, -2.4), Vector3(0, yaw, 0))
		_:
			Props.house(self, p, yaw, Color("efe4d2"), Color("b46a52"))

const BRICK := Color("b46a4c")
const ROOF := Color("5e4a46")
const STONE := Color("cfc6b2")
const LIME := Color("efe2c4")

func _piece(home: Node3D, m: Mesh, c: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
	Props._part(home, home, m, c, pos, rot, scl)

func _roof(home: Node3D, at: Vector3, w: float, d: float, yaw: float) -> void:
	var r := Basis(Vector3.UP, deg_to_rad(yaw))
	_piece(home, Props.box(Vector3(w + 2.0, 0.5, d + 2.0)), ROOF, at, Vector3(0, yaw, 0))
	_piece(home, Props.box(Vector3(w * 0.8, 1.2, d * 0.55)), ROOF, at + Vector3(0, 0.8, 0), Vector3(0, yaw, 0))
	_piece(home, Props.box(Vector3(w * 0.9, 0.35, 0.5)), Color("8a6a5a"), at + Vector3(0, 1.5, 0), Vector3(0, yaw, 0))
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_piece(home, Props.box(Vector3(0.5, 0.5, 1.2)), ROOF, at + r * Vector3(cx * (w / 2 + 0.9), 0.45, cz * (d / 2 + 0.9)),
				Vector3(-25 * cz, yaw, 0))

func _temple(p: Vector3, yaw: float, home: Node3D) -> void:
	var r := Basis(Vector3.UP, deg_to_rad(yaw))
	_piece(home, Props.box(Vector3(30, 0.3, 50)), STONE, p + r * Vector3(0, 0.05, 4))
	for gx in [-5.0, 0.0, 5.0]:
		var tall := 5.5 if gx == 0.0 else 4.2
		_piece(home, Props.box(Vector3(3.6, tall, 1.6)), LIME, p + r * Vector3(gx, tall / 2, 27))
		_roof(home, p + r * Vector3(gx, tall + 0.3, 27), 3.6, 1.6, yaw)
	_piece(home, Props.box(Vector3(10, 0.7, 4)), STONE, p + r * Vector3(0, 0.35, 14))
	_piece(home, Props.box(Vector3(16, 5.2, 9)), BRICK, p + r * Vector3(0, 2.6, 0))
	_piece(home, Props.box(Vector3(14, 0.2, 1.0)), Color("e8c060"), p + r * Vector3(0, 4.3, 4.55))
	_roof(home, p + r * Vector3(0, 5.5, 0), 16, 9, yaw)
	_piece(home, Props.box(Vector3(11, 4.4, 7)), BRICK, p + r * Vector3(0, 2.2, -13))
	_roof(home, p + r * Vector3(0, 4.7, -13), 11, 7, yaw)
	for side in [[Vector3(-15, 0.7, 4), Vector3(0.6, 1.4, 50)], [Vector3(15, 0.7, 4), Vector3(0.6, 1.4, 50)],
			[Vector3(0, 0.7, -21), Vector3(30, 1.4, 0.6)], [Vector3(-10.5, 0.7, 29), Vector3(9, 1.4, 0.6)],
			[Vector3(10.5, 0.7, 29), Vector3(9, 1.4, 0.6)]]:
		_piece(home, Props.box(side[1]), LIME, p + r * side[0])
	for tz in [8.0, 20.0]:
		for tx in [-11.0, 11.0]:
			Props.tree(home, p + r * Vector3(tx, 0, tz), Color("6faa5a"), 1.4, Color("fff4e0"))

func _citadel_gate(p: Vector3, home: Node3D) -> void:
	for sx in [-1.0, 1.0]:
		_piece(home, Props.box(Vector3(5, 9, 7)), Color("b9ab8e"), p + Vector3(sx * 4.5, 4.5, 0))
		_piece(home, Props.box(Vector3(14, 6, 5)), Color("a99a7e"), p + Vector3(sx * 14, 3, 0))
	_piece(home, Props.box(Vector3(14, 2.4, 7.4)), Color("b9ab8e"), p + Vector3(0, 10.2, 0))
	_piece(home, Props.box(Vector3(8, 3.2, 5)), Color("b85a4a"), p + Vector3(0, 13.0, 0))
	_roof(home, p + Vector3(0, 14.8, 0), 8, 5, 0.0)

func _pagoda_tower(p: Vector3) -> void:
	_piece(self, Props.cyl(16, 17, 1.2), STONE, p + Vector3(0, 0.3, 0))
	var y := 1.0
	for k in 11:
		var r := 5.6 - k * 0.36
		var h := 4.4 - k * 0.12
		_piece(self, Props.cyl(r, r, h), Color("f0d8a0") if k % 2 == 0 else Color("ead09a"), p + Vector3(0, y + h / 2, 0))
		_piece(self, Props.cyl(r + 1.9, r + 0.4, 0.8), ROOF, p + Vector3(0, y + h + 0.25, 0))
		y += h + 0.6
	_piece(self, Props.cyl(1.4, 0.25, 6.0), Color("d9b25a"), p + Vector3(0, y + 3.0, 0))
	var hall := p + Vector3(-22, 0, 8)
	_piece(self, Props.box(Vector3(14, 5, 9)), BRICK, hall + Vector3(0, 2.5, 0))
	_roof(self, hall + Vector3(0, 5.3, 0), 14, 9, 0.0)

const FOREST_CHUNK := 64.0
const FOREST_END := 200.0
const FOREST_NEAR := 70.0

const FOREST_HAND := 190.0
const FOREST_BLOCK := 280.0
const FOREST_THIN := Vector3(400.0, 800.0, 40.0)
const FOREST_GROW := Vector2(0.5, 0.25)
const FOREST_SPREAD := 0.3
var _forest_far: Array = []
var _forest_far_mat: ShaderMaterial
var _forest_far_haze := 0
var _forest_far_fh: Array[String] = []

func _build_forest() -> void:
	var list: Array = layout.get("forest", [])
	if list.is_empty():
		return
	var mat := ShaderMaterial.new()
	var shapes := []

	var cards := ResourceLoader.exists(HomeKit.DIR + "cay/rung_cards.glb") and not OS.get_cmdline_user_args().has("--greybox-forest")
	var near_mat: ShaderMaterial
	var far_new := cards and OS.get_environment("MC_FOREST_OLD") != "1"
	if cards:
		shapes = [_kit_mesh("cay/rung_cards")[0], _kit_mesh("cay/rung_near")[0]]
		mat = HomeKit._plant_material("cay/la_rung").duplicate() as ShaderMaterial
		mat.set_shader_parameter("billboard", true)
		mat.set_shader_parameter("forest_pick", true)
		mat.set_shader_parameter("lod_mode", 2)
		mat.set_shader_parameter("lod_r", FOREST_NEAR)
		if far_new:
			mat.set_shader_parameter("leaf_dissolve", true)
			mat.set_shader_parameter("leaf_mask", _leaf_mask())
		near_mat = mat.duplicate() as ShaderMaterial
		near_mat.set_shader_parameter("billboard", false)
		near_mat.set_shader_parameter("lod_mode", 1)
		if far_new:
			mat.set_shader_parameter("far_cut", FOREST_HAND)
		_lod_mats.append(mat)
		_lod_mats.append(near_mat)
	else:
		mat.shader = preload("res://shaders/karst.gdshader")
		shapes = [_tree_mesh(0), _tree_mesh(1), _tree_mesh(2)]
	var chunks := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 5

	var cam_lanes: Array[PackedVector2Array] = []
	if cards:
		for ln: Array in layout.get("lanes", []):
			var pts := PackedVector2Array()
			for q: Array in ln:
				pts.append(Vector2(q[0], q[1]))
			cam_lanes.append(pts)

	var nbr := PackedInt32Array()
	nbr.resize(list.size())
	if cards:
		var grid := {}
		for ti in list.size():
			var g := Vector2i(floori(list[ti][0] / 15.0), floori(list[ti][1] / 15.0))
			if not grid.has(g):
				grid[g] = []
			grid[g].append(ti)
		for ti in list.size():
			var p := Vector2(list[ti][0], list[ti][1])
			var g := Vector2i(floori(p.x / 15.0), floori(p.y / 15.0))
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					for tj: int in grid.get(g + Vector2i(dx, dz), []):
						if tj != ti and p.distance_squared_to(Vector2(list[tj][0], list[tj][1])) < 225.0:
							nbr[ti] += 1
	for ti in list.size():
		var tr: Array = list[ti]
		var yaw := rng.randf() * TAU
		var k := rng.randf_range(0.85, 1.1)
		var kg := rng.randf_range(0.95, 1.05)
		var in_view := false
		var cq := Vector2(tr[0], tr[1] - 8.8)
		for pts in cam_lanes:
			for i in pts.size() - 1:
				if cq.distance_squared_to(Geometry2D.get_closest_point_to_segment(cq, pts[i], pts[i + 1])) < 4.5 * 4.5:
					in_view = true
					break
			if in_view:
				break
		if in_view:
			continue
		var sc: float = tr[2]
		var size := Vector3(sc, sc, sc)
		if cards:

			var h := (roundi(tr[0] * 4.0) * 83492791) ^ (roundi(tr[1] * 4.0) * 2654435761)
			h = ((h ^ (h >> 15)) * 2246822519) & 0x7fffffff
			var u1 := float(h & 1023) / 1024.0
			var u2 := float((h >> 10) & 1023) / 1024.0
			var u3 := float((h >> 20) & 1023) / 1024.0
			var edge := clampf((nbr[ti] - 4.0) / 7.0, 0.0, 1.0)
			if u3 < (1.0 - edge) * 0.35:
				continue
			var hs := 0.7 + 0.6 * u1
			var ws := pow(hs, 0.6) * (0.92 + 0.16 * u2)
			if edge > 0.6 and u3 > 0.925:
				hs = 1.4 + 0.2 * u2
				ws = 1.12 + 0.1 * u1
			var taper := lerpf(0.72, 1.0, edge)
			size = Vector3(ws, hs, ws) * taper * 1.05
		var cd := Color(int(tr[3]) / 4.0, 0, 0, 0)
		if far_new:
			var h2 := (roundi(tr[0] * 4.0) * 1274126177) ^ (roundi(tr[1] * 4.0) * 3266489917)
			h2 = ((h2 ^ (h2 >> 13)) * 668265263) & 0x7fffffff
			h2 = h2 ^ (h2 >> 16)
			cd = Color(cd.r, float(h2 & 1023) / 1024.0, float((h2 >> 10) & 255) / 256.0, float((h2 >> 18) & 255) / 256.0)
		var key := [floori(tr[0] / FOREST_CHUNK), floori(tr[1] / FOREST_CHUNK), 0 if cards else int(tr[3])]
		if not chunks.has(key):
			chunks[key] = [[], [], [], []]
		chunks[key][0].append(Transform3D(Basis(Vector3.UP, yaw).scaled(size),
			Vector3(tr[0], height_at(tr[0], tr[1]) - 0.2, tr[1])))
		chunks[key][1].append(Color(k, k * kg, k, 1.0))
		chunks[key][2].append(int(tr[3]))
		chunks[key][3].append(cd)
	for key in chunks:
		var xs: Array = chunks[key][0]
		var c := Vector3((key[0] + 0.5) * FOREST_CHUNK, 0, (key[1] + 0.5) * FOREST_CHUNK)
		for row in (2 if cards else 1):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.use_custom_data = cards
			mm.mesh = shapes[row] if cards else shapes[key[2]]
			mm.instance_count = xs.size()
			for i in xs.size():
				mm.set_instance_transform(i, Transform3D(xs[i].basis, xs[i].origin - c))
				mm.set_instance_color(i, chunks[key][1][i])
				if cards:
					mm.set_instance_custom_data(i, chunks[key][3][i])
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.material_override = near_mat if row == 1 else mat
			mi.position = c
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = FOREST_NEAR + FOREST_CHUNK * 0.75 + 8.0 if row == 1 else FOREST_END
			if far_new and row == 0:
				mi.visibility_range_end = FOREST_HAND + FOREST_CHUNK * 0.71 + 6.0
			if cards and row == 0:
				var lo := Vector3(INF, INF, INF)
				var hi := -lo
				for xf: Transform3D in xs:
					lo = lo.min(xf.origin - c)
					hi = hi.max(xf.origin - c)
				mi.custom_aabb = AABB(lo - Vector3(6.5, 0.5, 6.5), hi - lo + Vector3(13.0, 25.0, 13.0))
			add_child(mi)
	if far_new:
		_build_forest_far(chunks, shapes[0], mat)

func _build_forest_far(chunks: Dictionary, card: Mesh, near_cards: ShaderMaterial) -> void:
	var fmat := near_cards.duplicate() as ShaderMaterial
	fmat.set_shader_parameter("lod_mode", 0)
	fmat.set_shader_parameter("far_set", true)
	fmat.set_shader_parameter("far_cut", FOREST_HAND)
	fmat.set_shader_parameter("far_thin", FOREST_THIN)
	fmat.set_shader_parameter("far_grow", FOREST_GROW)
	fmat.set_shader_parameter("far_spread", FOREST_SPREAD)
	var one := _forest_far_card(card)
	if one != null:
		card = one
		fmat.set_shader_parameter("forest_pick", false)
		fmat.set_shader_parameter("far_kinds", true)
	_lod_mats.append(fmat)
	_forest_far_mat = fmat
	var blocks := {}
	var f_lo := Vector2(INF, INF)
	var f_hi := -f_lo
	for key in chunks:
		for xf: Transform3D in chunks[key][0]:
			f_lo = f_lo.min(Vector2(xf.origin.x, xf.origin.z))
			f_hi = f_hi.max(Vector2(xf.origin.x, xf.origin.z))
	var nb := Vector2(ceilf((f_hi.x - f_lo.x + 0.01) / FOREST_BLOCK), ceilf((f_hi.y - f_lo.y + 0.01) / FOREST_BLOCK))
	var bw := (f_hi - f_lo + Vector2(0.01, 0.01)) / nb
	for key in chunks:
		var ch: Array = chunks[key]
		for i in ch[0].size():
			var xf: Transform3D = ch[0][i]
			var bk := Vector2i(floori((xf.origin.x - f_lo.x) / bw.x), floori((xf.origin.z - f_lo.y) / bw.y))
			if not blocks.has(bk):
				blocks[bk] = []
			blocks[bk].append([ch[3][i].g, xf, ch[1][i], ch[3][i]])
	var grow := pow(0.25, -FOREST_GROW.x) * (1.0 + FOREST_SPREAD)
	for bk: Vector2i in blocks:
		var trees: Array = blocks[bk]
		trees.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var c := Vector3(f_lo.x + (bk.x + 0.5) * bw.x, 0, f_lo.y + (bk.y + 0.5) * bw.y)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = card
		mm.instance_count = trees.size()
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		var ranks := PackedFloat32Array()
		for i in trees.size():
			var xf: Transform3D = trees[i][1]
			mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - c))
			mm.set_instance_color(i, trees[i][2])
			mm.set_instance_custom_data(i, trees[i][3])
			ranks.append(trees[i][0])
			lo = lo.min(xf.origin - c)
			hi = hi.max(xf.origin - c)
		var mi := MultiMeshInstance3D.new()
		mi.name = "ForestFar_%d_%d" % [bk.x, bk.y]
		mi.multimesh = mm
		mi.material_override = fmat
		mi.position = c
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := 6.5 * grow
		mi.custom_aabb = AABB(lo - Vector3(m, 0.5, m), hi - lo + Vector3(2.0 * m, 25.0 * pow(0.25, -FOREST_GROW.y), 2.0 * m))
		add_child(mi)
		_forest_far.append([mm, Rect2(lo.x + c.x, lo.z + c.z, hi.x - lo.x, hi.z - lo.z), ranks, -1, Vector2(lo.y, hi.y)])
	if not _forest_far.is_empty():
		get_tree().process_frame.connect(_forest_far_tick)

static func _forest_far_card(src: Mesh) -> ArrayMesh:
	var a := src.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var nr: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	if v.size() != 18 or idx.size() != 36 or uv.size() != 18 or nr.size() != 18:
		return null
	var at := [0, 6, 12]
	at.sort_custom(func(p: int, q: int) -> bool: return uv[p].x < uv[q].x)
	for k in 3:
		for i in 6:
			if absf(uv[at[k] + i].x - uv[at[k]].x) > 0.3:
				return null
	for t in 12:
		if idx[12 + t] - 6 != idx[t] or idx[24 + t] - 12 != idx[t]:
			return null
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var nv := PackedVector3Array()
	var nuv := PackedVector2Array()
	var nn := PackedVector3Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var c2 := PackedFloat32Array()
	for i in 6:
		var i0: int = at[0] + i
		var i1: int = at[1] + i
		var i2: int = at[2] + i
		nv.append(v[i0])
		nuv.append(uv[i0])
		nn.append(nr[i0])
		c0.append_array([v[i1].x, v[i1].y, uv[i1].x, uv[i1].y])
		c1.append_array([v[i2].x, v[i2].y, uv[i2].x, uv[i2].y])
		c2.append_array([nr[i1].x, nr[i1].y, nr[i2].x, nr[i2].y])
	out[Mesh.ARRAY_VERTEX] = nv
	out[Mesh.ARRAY_TEX_UV] = nuv
	out[Mesh.ARRAY_NORMAL] = nn
	for key in [Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
		if a[key] != null:
			out[key] = a[key].slice(at[0], at[0] + 6)
	out[Mesh.ARRAY_CUSTOM0] = c0
	out[Mesh.ARRAY_CUSTOM1] = c1
	out[Mesh.ARRAY_CUSTOM2] = c2

	var tops := [0.0, 0.0, 0.0]
	for k in 3:
		for i in 6:
			tops[k] = maxf(tops[k], v[at[k] + i].y)
	var c3 := PackedFloat32Array()
	for i in 6:
		c3.append_array([tops[0], tops[1], tops[2], 0.0])
	out[Mesh.ARRAY_CUSTOM3] = c3
	out[Mesh.ARRAY_INDEX] = idx.slice(0, 12)
	var m := ArrayMesh.new()
	var fl := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) 			| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) 			| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT) 			| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out, [], {}, fl)
	return m

func _forest_far_tick() -> void:
	if not cam:
		return
	_forest_far_haze -= 1
	if _forest_far_haze <= 0 and _karst_far_mat != null:
		_forest_far_haze = 30

		var ks := _karst_far_mat.shader.get_rid() if _karst_far_mat.shader else RID()
		var kp := func(n_: String) -> Variant:
			var v_: Variant = _karst_far_mat.get_shader_parameter(n_)
			if v_ == null and ks.is_valid():
				v_ = RenderingServer.shader_get_parameter_default(ks, n_)
			return v_
		var hc: Variant = kp.call("haze_color")
		if hc is Color:
			_forest_far_mat.set_shader_parameter("far_haze_color", hc)
		var hn: Variant = kp.call("haze_near")
		var hf: Variant = kp.call("haze_far")
		var hm: Variant = kp.call("haze_max")
		if hn != null and hf != null and hm != null:
			_forest_far_mat.set_shader_parameter("far_hz", Vector3(hn, hf, hm))
		var mc: Variant = kp.call("mist_color")
		if mc is Color:
			_forest_far_mat.set_shader_parameter("far_mist_color", mc)
		var mm_: Variant = kp.call("mist_max")
		var mt: Variant = kp.call("mist_top")
		var mo: Variant = kp.call("mist_morning")
		if mm_ != null and mt != null and mo != null:
			_forest_far_mat.set_shader_parameter("far_mist", Vector3(mm_, mt, mo))
		if _forest_far_fh.is_empty() and _karst_far_mat.shader:
			for u_: Dictionary in _karst_far_mat.shader.get_shader_uniform_list():
				if String(u_["name"]).begins_with("fh_"):
					_forest_far_fh.append(String(u_["name"]))
		for p_: String in _forest_far_fh:
			var v_: Variant = kp.call(p_)
			if v_ != null:
				_forest_far_mat.set_shader_parameter(p_, v_)
	var vp := cam.global_position
	var p := Vector2(vp.x, vp.z)
	for b: Array in _forest_far:
		var r: Rect2 = b[1]
		var q := p.clamp(r.position, r.end)
		var d_min := p.distance_to(q)
		var d_max := 0.0
		for corner in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
			d_max = maxf(d_max, p.distance_to(corner))
		var n := 0
		var dy: float = maxf(absf(vp.y - b[4].x), absf(vp.y - b[4].y))
		if sqrt(d_max * d_max + dy * dy) > FOREST_HAND:
			var g := 0.5 * smoothstep(FOREST_THIN.x - FOREST_THIN.z, FOREST_THIN.x + FOREST_THIN.z, d_min) \
					+ 0.25 * smoothstep(FOREST_THIN.y - FOREST_THIN.z, FOREST_THIN.y + FOREST_THIN.z, d_min)
			var ranks: PackedFloat32Array = b[2]
			n = ranks.size()
			while n > 0 and g >= maxf(1.0 - ranks[n - 1], 0.08) + 0.08:
				n -= 1
		if n != b[3]:
			b[3] = n
			(b[0] as MultiMesh).visible_instance_count = n

static func _leaf_mask() -> ImageTexture:
	const N := 32
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var raw := PackedFloat32Array()
	raw.resize(N * N)
	for i in 29:
		var cx := rng.randf() * N
		var cy := rng.randf() * N
		var ang := rng.randf() * PI
		var a := rng.randf_range(3.5, 6.5)
		var b := a * rng.randf_range(0.38, 0.55)
		var pk := rng.randf_range(0.55, 1.0)
		var ca := cos(ang)
		var sa := sin(ang)
		for y in N:
			for x in N:
				for ox in [-N, 0, N]:
					for oy in [-N, 0, N]:
						var dx: float = x + 0.5 - cx - ox
						var dy: float = y + 0.5 - cy - oy
						var u := dx * ca + dy * sa
						if absf(u) > 2.0 * a:
							continue
						var w := -dx * sa + dy * ca
						var bw := b * (1.0 - 0.35 * u / a if absf(u) < a else 0.65)
						var q := sqrt((u / a) * (u / a) + (w / bw) * (w / bw))
						var v := 0.0
						if q < 1.0:
							v = 0.12 + pk * 0.88 * pow(1.0 - q, 0.55)
						elif q < 2.0:
							v = 0.11 * (2.0 - q)
						raw[y * N + x] = maxf(raw[y * N + x], v)
	var order := []
	for i in N * N:
		order.append([raw[i] + 1e-6 * float((i * 7919) % 1021) / 1021.0, i])
	order.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var img := Image.create(N, N, false, Image.FORMAT_L8)
	for r in N * N:
		var i: int = order[r][1]
		img.set_pixel(i % N, i / N, Color.from_hsv(0, 0, (r + 0.5) / (N * N)))
	return ImageTexture.create_from_image(img)

func _tree_mesh(kind: int) -> ArrayMesh:
	var parts := []
	var trunk := Color("7a6450")
	var leaf: Color = [Color("4f8a46"), Color("5f9a4c"), Color("467f42")][kind]
	match kind:
		0:
			parts = [[Props.cyl(0.35, 0.25, 7.0), Vector3(0, 3.5, 0), Vector3.ONE, trunk],
				[Props.sphere(3.6), Vector3(0, 8.5, 0), Vector3(1.2, 0.75, 1.2), leaf]]
		1:
			parts = [[Props.cyl(0.3, 0.2, 10.0), Vector3(0, 5.0, 0), Vector3.ONE, trunk],
				[Props.sphere(2.4), Vector3(0, 11.0, 0), Vector3(1.0, 1.4, 1.0), leaf]]
		_:
			parts = [[Props.cyl(0.4, 0.25, 12.0), Vector3(0, 6.0, 0), Vector3.ONE, trunk],
				[Props.sphere(3.0), Vector3(0, 8.0, 0), Vector3(1.3, 0.55, 1.3), leaf],
				[Props.sphere(2.6), Vector3(0, 12.5, 0), Vector3(1.2, 0.6, 1.2), leaf.lightened(0.08)]]
	var cparts := []
	for pt in parts:
		cparts.append([pt[0], Transform3D(Basis().scaled(pt[2]), pt[1]), pt[3]])
	return _compound(cparts)

func _giant_tree(p: Vector3, home: Node3D) -> void:
	var bark := Color("b8ab92")
	_piece(home, Props.cyl(2.6, 1.5, 32.0), bark, p + Vector3(0, 16.0, 0))
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		_piece(home, Props.box(Vector3(0.7, 4.5, 4.2)), bark, p + Vector3(sin(a) * 2.6, 2.0, cos(a) * 2.6),
			Vector3(0, rad_to_deg(a), 0))
	for k in 4:
		var a := TAU * k / 4.0
		_piece(home, Props.cyl(0.7, 0.4, 9.0), bark, p + Vector3(sin(a) * 3.0, 34.0, cos(a) * 3.0),
			Vector3(cos(a) * 40.0, 0, -sin(a) * 40.0))
	for c in [[Vector3(0, 41, 0), 8.0], [Vector3(6, 38, 3), 6.0], [Vector3(-6, 39, -2), 6.5], [Vector3(2, 37, -6), 5.5],
			[Vector3(-3, 37.5, 6), 5.5]]:
		_piece(home, Props.sphere(c[1]), Color("4a8a44"), p + c[0], Vector3.ZERO, Vector3(1.2, 0.6, 1.2))
	_piece(home, Props.box(Vector3(1.6, 1.0, 0.15)), Color("8a6a4a"), p + Vector3(0, 0.9, 9.0))

const BOAT_SPEED := 2.6
var boat: Node3D
var boat_route: Array[Vector3] = []
var boat_len := 0.0
var boat_s := 0.0
var boat_dir := 0
var boat_speed := BOAT_SPEED
var boat_hint: Label

func _build_boat() -> void:
	var rv: Array = layout["river"]["points"]
	var from := 0
	for i in rv.size():
		if rv[i][0] >= 150:
			from = i
			break
	for i in range(from, rv.size()):
		if rv[i][0] > 480:
			break
		boat_route.append(Vector3(rv[i][0], 0.12, rv[i][1]))
	boat_route.append(Vector3(478, 0.12, 296))
	for i in range(1, boat_route.size()):
		boat_len += boat_route[i - 1].distance_to(boat_route[i])
	boat = Node3D.new()
	add_child(boat)
	if ResourceLoader.exists("res://props/hometown/thuyen_nan.glb"):
		var hull := HomeKit.place(boat, "thuyen_nan", Vector3(0, -0.1, 0))
		hull.scale = Vector3(1.15, 1.0, 1.1)
	else:
		Props.mesh(boat, Props.box(Vector3(1.5, 0.45, 5.6)), Color("9a6a42"), Vector3(0, 0.2, 0))

	Props.mesh(boat, Props.box(Vector3(0.45, 0.8, 0.3)), Color("3e5a7a"), Vector3(0, 0.9, -2.4))
	Props.mesh(boat, Props.sphere(0.2), Color("e8c4a0"), Vector3(0, 1.45, -2.4))
	Props.mesh(boat, Props.cyl(0.42, 0.02, 0.28), Color("e8d39a"), Vector3(0, 1.62, -2.4))
	Props.mesh(boat, Props.cyl(0.03, 0.03, 2.6), Color("7a5a3a"), Vector3(0.35, 0.7, -2.0), Vector3(55, 0, 0))
	_place_boat(0.0)
	boat_hint = Label.new()
	boat_hint.add_theme_font_size_override("font_size", 26)
	boat_hint.add_theme_color_override("font_color", Color("fffaf2"))
	boat_hint.add_theme_color_override("font_outline_color", Color("5b4a44"))
	boat_hint.add_theme_constant_override("outline_size", 10)
	boat_hint.position = Vector2(24, 820)
	var layer := CanvasLayer.new()
	layer.add_child(boat_hint)
	add_child(layer)

func _route_at(s_: float) -> Array:
	var left := clampf(s_, 0.0, boat_len)
	for i in range(1, boat_route.size()):
		var ln := boat_route[i - 1].distance_to(boat_route[i])
		if left <= ln:
			return [boat_route[i - 1].lerp(boat_route[i], left / ln), (boat_route[i] - boat_route[i - 1]).normalized()]
		left -= ln
	return [boat_route[-1], (boat_route[-1] - boat_route[-2]).normalized()]

func _place_boat(s_: float) -> void:
	var at := _route_at(s_)
	var dir: Vector3 = at[1] * (1.0 if boat_dir >= 0 else -1.0)
	boat.global_position = at[0] + Vector3(0, 0.03 * sin(t * 1.7), 0)
	boat.rotation = Vector3(0.01 * sin(t * 1.3), atan2(dir.x, dir.z), 0.015 * sin(t * 1.1))

func _boat_step(delta: float) -> void:
	if boat == null:
		return
	BoatRow.wake(self, delta)
	if BoatRow.busy(self):
		return
	if boat_dir != 0:
		boat_s += boat_dir * boat_speed * delta
		_place_boat(boat_s)
		player.global_position = boat.global_position + boat.global_basis * Vector3(0, 0.45, 0.8)
		player.facing = boat.rotation.y
		player.rotation.y = player.facing
		if boat_s >= boat_len or boat_s <= 0.0:
			boat_s = clampf(boat_s, 0.0, boat_len)
			boat_dir = 0
			player.set_sitting(false)
			var off := Vector3(498, 0, 312) if boat_s > 0.0 else Vector3(150, 0, 108)
			player.global_position = Vector3(off.x, height_at(off.x, off.z) + 0.3, off.z)
			player.set_physics_process(true)
			if not fly.is_empty():
				get_tree().quit()
		boat_hint.text = ""
		return
	_place_boat(boat_s)
	var near := player.global_position.distance_to(boat.global_position) < 9.0
	boat_hint.text = ("E: lên đò đi Ba Hang" if boat_s == 0.0 else "E: lên đò về bến") if near else ""

func _touch_board() -> Dictionary:
	"""The touch screen's action button by the boat or the bus door (as E)."""
	if boat_dir != 0 or bus_s_dir != 0 or _bus_busy or BoatRow.busy(self):
		return {}
	if bus != null and player.global_position.distance_to(XeKhach.door_spot(bus)) <= 3.2:
		return {"label": tr("TC_BUS"), "run": _bus_board}
	if boat != null and player.global_position.distance_to(boat.global_position) <= 9.0:
		return {"label": tr("TC_BOAT"), "run": _board}
	return {}

func _board(force := false) -> void:
	if boat == null or boat_dir != 0 or bus_s_dir != 0 or _bus_busy or (not force and player.global_position.distance_to(boat.global_position) > 9.0):
		return
	if BoatRow.take(self):
		return
	boat_dir = 1 if boat_s == 0.0 else -1
	player.set_physics_process(false)
	player.set_sitting(true)

const BUS_ROUTE := [Vector2(-682.93, 1.61), Vector2(-668, 1.8), Vector2(-651, -1.2), Vector2(-632, -4.5),
	Vector2(-480, 20), Vector2(-340, 50), Vector2(-300, 48), Vector2(-242.55, 40.93)]
const BUS_LANE := 0.4
const BUS_VMAX := 11.0
const BUS_ACC := 2.2
const BUS_SEE := 0.7
const BUS_CALL := 60.0
const BUS_RUN_IN := 100.0

var bus: Node3D
var bus_len := 0.0
var bus_s := 0.0
var bus_s_dir := 0
var bus_v := 0.0
var _bus_busy := false
var _bus_empty := false
var _bus_film := false
var _bus_fade: ColorRect
var _bus_box: AABB
var _bus_meshes: Array[MeshInstance3D] = []
var _bus_shapes: Array[CollisionShape3D] = []
var _bus_dither := 0.0
var _bus_roll := 0.0
var _bus_specks: Array[Node] = []
var _cam_soft := 1.0

func _build_bus() -> void:
	if not ResourceLoader.exists("res://props/furniture/xe_khach.glb"):
		return
	for i in range(1, BUS_ROUTE.size()):
		bus_len += (BUS_ROUTE[i - 1] as Vector2).distance_to(BUS_ROUTE[i])
	bus = XeKhach.place(self, Vector3.ZERO, 0.0, true)
	var first := true
	for mi: MeshInstance3D in bus.find_children("*", "MeshInstance3D", true, false):
		_bus_meshes.append(mi)
		var b := mi.transform * mi.get_aabb() if mi.get_parent() == bus else bus.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		_bus_box = b if first else _bus_box.merge(b)
		first = false
	for cs: CollisionShape3D in bus.find_children("*", "CollisionShape3D", true, false):
		_bus_shapes.append(cs)

	for mi in _bus_meshes:
		var fm := HomeKit.fade_material(mi.material_override) if mi.material_override is ShaderMaterial else null
		if fm:
			var speck := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.01, 0.01)
			speck.mesh = q
			speck.material_override = fm
			speck.position = Vector3(0, 0.3, 0)
			speck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bus.add_child(speck)
			_bus_specks.append(speck)
	_bus_place(0.0, -1)
	var layer := CanvasLayer.new()
	layer.layer = 5
	_bus_fade = ColorRect.new()
	_bus_fade.color = Color(0.06, 0.05, 0.08, 0.0)
	_bus_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bus_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_bus_fade)
	add_child(layer)

func _bus_route_at(s_: float) -> Array:
	var left := clampf(s_, 0.0, bus_len)
	for i in range(1, BUS_ROUTE.size()):
		var a: Vector2 = BUS_ROUTE[i - 1]
		var b: Vector2 = BUS_ROUTE[i]
		var ln := a.distance_to(b)
		if left <= ln:
			return [a.lerp(b, left / ln), (b - a) / ln]
		left -= ln
	var n := BUS_ROUTE.size()
	return [BUS_ROUTE[n - 1], ((BUS_ROUTE[n - 1] as Vector2) - BUS_ROUTE[n - 2]).normalized()]

func _bus_place(s_: float, heading: int, delta := 0.0) -> void:
	var here: Array = _bus_route_at(s_)
	var ahead: Array = _bus_route_at(s_ + heading * 5.0)
	var dir := ((ahead[0] as Vector2) - (here[0] as Vector2))
	if dir.length() < 0.5:
		dir = (here[1] as Vector2) * heading
	dir = dir.normalized()
	var right := Vector2(-dir.y, dir.x)
	var p: Vector2 = (here[0] as Vector2) + right * BUS_LANE
	var yaw := atan2(dir.x, dir.y)
	var sp := clampf(bus_v / BUS_VMAX, 0.0, 1.0)
	var y := height_at(p.x, p.y) + sp * (0.02 * sin(t * 8.7) + 0.012 * sin(t * 13.3 + 1.0))
	bus.global_position = Vector3(p.x, y, p.y)
	var was := bus.rotation.y
	bus.rotation.y = lerp_angle(was, yaw, 1.0 - exp(-delta * 4.0)) if delta > 0.0 else yaw
	if delta > 0.0:
		var turn := wrapf(bus.rotation.y - was, -PI, PI) / delta
		_bus_roll = lerpf(_bus_roll, clampf(turn * bus_v * 0.012, -0.05, 0.05), 1.0 - exp(-delta * 3.0))
	else:
		_bus_roll = 0.0
	var yb := height_at(p.x - dir.x * 3.0, p.y - dir.y * 3.0)
	var yf := height_at(p.x + dir.x * 3.0, p.y + dir.y * 3.0)
	bus.rotation.x = -atan2(yf - yb, 6.0)
	bus.rotation.z = _bus_roll + 0.012 * sin(t * 2.3) * sp

func _bus_board(force := false) -> void:
	if bus == null or bus_s_dir != 0 or _bus_busy or boat_dir != 0:
		return
	var door := XeKhach.door_spot(bus)
	if not force and player.global_position.distance_to(door) > 3.2:
		return
	_bus_busy = true
	var going := 1 if bus_s < bus_len * 0.5 else -1
	await XeKhach.swing_door(bus, true).finished
	var walked: String = await player.go_to(door, false, 0.25, 6.0)
	if walked == "cancelled":
		await XeKhach.swing_door(bus, false).finished
		_bus_busy = false
		return

	var inside := XeKhach.inside_spot(bus)
	player.set_physics_process(false)
	player.rotation.y = atan2(inside.x - door.x, inside.z - door.z)
	player.facing = player.rotation.y
	player.chibi.play("Move_Walk", 0.15)
	var up := create_tween()
	up.tween_property(player, "global_position", inside, 0.4).set_trans(Tween.TRANS_SINE)
	await up.finished
	player.chibi.play("Base_Wait", 0.2)
	player.visible = false
	for l in _names:
		l.visible = false
	await XeKhach.swing_door(bus, false).finished
	await _bus_fade_to(1.0)
	_bus_place(bus_s, going)
	for cs in _bus_shapes:
		cs.set_deferred("disabled", true)
	bus_v = 0.0
	bus_s_dir = going
	_bus_camera(30.0)
	await get_tree().create_timer(0.25).timeout
	_bus_fade_to(0.0)
	_bus_busy = false

func _bus_fade_to(a: float) -> void:
	var tw := create_tween()
	tw.tween_property(_bus_fade, "color:a", a, 0.55)
	await tw.finished

func _bus_step(delta: float) -> void:
	if bus == null:
		return
	if not _bus_specks.is_empty() and Engine.get_process_frames() > 10:
		for sp in _bus_specks:
			sp.queue_free()
		_bus_specks.clear()
	if bus_s_dir != 0:
		var to_go := (bus_len - bus_s) if bus_s_dir > 0 else bus_s
		var gone := bus_len - to_go
		var v_want := minf(BUS_VMAX, minf(sqrt(2.0 * BUS_ACC * maxf(gone, 0.0)) + 1.2, sqrt(2.0 * BUS_ACC * maxf(to_go, 0.0)) + 0.3))
		if _bus_empty:
			var ahead := bus.global_position + bus.global_basis.z * 4.5
			if Vector2(player.global_position.x - ahead.x, player.global_position.z - ahead.z).length() < 2.6:
				v_want = 0.0
		bus_v = move_toward(bus_v, v_want, BUS_ACC * 2.0 * delta)
		bus_s = clampf(bus_s + bus_s_dir * bus_v * delta, 0.0, bus_len)
		_bus_place(bus_s, bus_s_dir, delta)
		XeKhach.set_lights(bus, HomeKit._night > 0.5)
		if not _bus_empty:
			player.global_position = XeKhach.inside_spot(bus)
			if boat_hint:
				boat_hint.text = ""
		if (bus_s_dir > 0 and bus_s >= bus_len) or (bus_s_dir < 0 and bus_s <= 0.0):
			var came := bus_s_dir
			bus_s_dir = 0
			bus_v = 0.0
			_bus_arrive(came)
		return
	if _bus_busy:
		return
	var pp := Vector2(player.global_position.x, player.global_position.z)

	var at_village := bus_s > bus_len * 0.5
	var other: Vector2 = BUS_ROUTE[0] if at_village else BUS_ROUTE[BUS_ROUTE.size() - 1]
	if player.visible and pp.distance_to(other) < BUS_CALL and pp.distance_to(Vector2(bus.global_position.x, bus.global_position.z)) > 250.0:
		bus_s = BUS_RUN_IN if at_village else bus_len - BUS_RUN_IN
		bus_s_dir = -1 if at_village else 1
		bus_v = BUS_VMAX * 0.8
		_bus_empty = true
		_bus_place(bus_s, bus_s_dir)
		if boat_hint:
			boat_hint.text = "Xe buýt đang tới…"
			get_tree().create_timer(4.0).timeout.connect(func() -> void:
				if boat_hint.text == "Xe buýt đang tới…":
					boat_hint.text = "")
		for cs in _bus_shapes:
			cs.set_deferred("disabled", true)
		return
	if boat_hint and boat_dir == 0:
		var near := player.global_position.distance_to(XeKhach.door_spot(bus)) < 3.2
		if near:
			boat_hint.text = "E: lên xe buýt về làng" if bus_s < bus_len * 0.5 else "E: lên xe buýt ra ga"
		elif boat_hint.text.begins_with("E: lên xe buýt"):
			boat_hint.text = ""

func _bus_arrive(came: int) -> void:
	_bus_busy = true
	_bus_place(bus_s, came)
	if _bus_empty:
		_bus_empty = false
		for cs in _bus_shapes:
			cs.set_deferred("disabled", false)
		await XeKhach.swing_door(bus, true).finished
		await get_tree().create_timer(1.0).timeout
		await XeKhach.swing_door(bus, false).finished
		XeKhach.set_lights(bus, false)
		_bus_busy = false
		return
	_cam_soft = 0.0
	await XeKhach.swing_door(bus, true).finished

	var inside := XeKhach.inside_spot(bus)
	var door := XeKhach.door_spot(bus)
	door.y = height_at(door.x, door.z) + 0.05
	player.global_position = inside
	player.rotation.y = atan2(door.x - inside.x, door.z - inside.z)
	player.facing = player.rotation.y
	player.visible = true
	player.chibi.play("Move_Walk", 0.1)
	var down := create_tween()
	down.tween_property(player, "global_position", door, 0.45).set_trans(Tween.TRANS_SINE)
	await down.finished
	player.chibi.play("Base_Wait", 0.25)
	for cs in _bus_shapes:
		cs.set_deferred("disabled", false)
	player.set_physics_process(true)
	for l in _names:
		l.visible = show_names
	await get_tree().create_timer(1.0).timeout
	await XeKhach.swing_door(bus, false).finished
	XeKhach.set_lights(bus, false)
	_bus_busy = false
	if _bus_film:
		await get_tree().create_timer(2.0).timeout
		get_tree().quit()

func _bus_clear_view(delta: float) -> void:
	if bus == null:
		return
	var block := false
	if bus_s_dir == 0 and not map_view and player.visible \
			and player.global_position.distance_squared_to(bus.global_position) < 900.0:
		var inv := bus.global_transform.affine_inverse()
		var hero := player.global_position + Vector3(0, 0.9, 0)
		var eye := cam.global_position
		var box := _bus_box.grow(0.4 if _bus_dither > 0.0 else 0.0)
		block = box.intersects_segment(inv * eye, inv * (hero + (eye - hero).normalized() * 0.6)) != null
	var f := move_toward(_bus_dither, BUS_SEE if block else 0.0, delta * 4.0)
	if f == _bus_dither:
		return
	var was := _bus_dither
	_bus_dither = f
	for mi in _bus_meshes:
		if not is_instance_valid(mi) or not (mi.material_override is ShaderMaterial):
			continue
		if was == 0.0 and not mi.has_meta("solid"):
			var fm := HomeKit.fade_material(mi.material_override)
			if fm == null:
				continue
			mi.set_meta("solid", mi.material_override)
			mi.material_override = fm
		mi.set_instance_shader_parameter("fade", f)
		if f == 0.0 and mi.has_meta("solid"):
			mi.material_override = mi.get_meta("solid")
			mi.remove_meta("solid")

func _bus_camera(delta: float) -> void:
	var bb := bus.global_basis
	var u := bus_s / bus_len if bus_s_dir > 0 else 1.0 - bus_s / bus_len
	var wide := smoothstep(0.36, 0.44, u) * (1.0 - smoothstep(0.62, 0.7, u))
	var side := lerpf(3.0 * sin(bus_s / 45.0) + 1.0, 13.0, wide)
	var back := lerpf(12.0, 6.0, wide)
	var want := bus.global_position - bb.z * back + bb.x * side + Vector3(0, lerpf(5.2, 3.2, wide), 0)
	want.y = maxf(want.y, height_at(want.x, want.z) + 2.5)
	cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-delta * 2.0))
	cam.look_at(bus.global_position + bb.z * lerpf(10.0, 4.0, wide) + Vector3(0, 1.4, 0), Vector3.UP)

var _karst_far_mat: ShaderMaterial

var _occlude := OS.get_environment("MC_OCCLUDE") == "1"

var _float_fix := OS.get_environment("MC_FLOAT_OLD") == ""

func _build_karst() -> void:
	var meta: Array = JSON.parse_string(FileAccess.get_file_as_string(KARST_DIR + "karst.json"))
	var near_meshes := []
	var far_arrays := []
	for k in meta.size():
		near_meshes.append(_first_mesh(KARST_DIR + "karst_%d.glb" % k))
		far_arrays.append(_first_mesh(KARST_DIR + "karst_%d_far.glb" % k).surface_get_arrays(0))

	const K_MID := 600.0
	const K_CELL := 192.0
	const K_FAR_CELL := 256.0
	var fk := WeatherLook.far_on()
	var mid_arrays := []
	if fk:
		for k in meta.size():
			mid_arrays.append(_first_mesh(KARST_DIR + "karst_%d_mid.glb" % k).surface_get_arrays(0))
	var near_mat := ShaderMaterial.new()

	var k_sh: Shader = preload("res://shaders/karst.gdshader")
	var k_nr: Shader = k_sh
	if OS.get_environment("MC_FILL_KARST_OLD") != "1":
		k_nr = preload("res://scripts/home/shader_copy.gd").with_define(k_sh, "KARST_NO_RING")
	near_mat.shader = k_nr
	near_mat.set_shader_parameter("cov_mode", true)
	_karst_far_mat = ShaderMaterial.new()
	_karst_far_mat.shader = k_nr if fk else k_sh
	_karst_far_mat.set_shader_parameter("cov_mode", true)
	if ResourceLoader.exists("res://props/hometown/karst/rock_tile.png"):
		var rt: Texture2D = load("res://props/hometown/karst/rock_tile.png")
		for m_: ShaderMaterial in [near_mat, _karst_far_mat]:
			m_.set_shader_parameter("rock_tex", rt)
			m_.set_shader_parameter("has_rock", true)
	for m_: ShaderMaterial in [near_mat, _karst_far_mat]:
		m_.set_shader_parameter("cloud_tex", load("res://props/farm/ground/noise.png"))
		m_.set_shader_parameter("has_clouds", true)

	var kv2 := OS.get_environment("MC_KARST_OLD") == ""
	for m_: ShaderMaterial in [near_mat, _karst_far_mat]:
		m_.set_shader_parameter("karst_v2", kv2)
	_karst_far_mat.set_shader_parameter("ring", Vector2(KARST_NEAR - 30.0, 100000.0))
	_karst_skirt()
	var mid_mat: ShaderMaterial = null
	if fk:
		_karst_far_mat.set_shader_parameter("ring", Vector2.ZERO)
		mid_mat = _karst_far_mat.duplicate()
		mid_mat.set_shader_parameter("swap", Vector2(KARST_NEAR, K_MID))
		_karst_far_mat.set_shader_parameter("swap", Vector2(K_MID, 1.0e9))
	var per_mid := {}
	var per_far := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var body := StaticBody3D.new()
	add_child(body)
	var per_khu := {}
	for site: Array in layout.get("karst", []):
		var x: float = site[0]
		var z: float = site[1]
		var r: float = site[2]
		var h: float = site[3]
		var k := 0
		var k2 := -1
		for i in meta.size():
			if absf(meta[i]["aspect"] - h / r) < absf(meta[k]["aspect"] - h / r):
				k = i
		for i in meta.size():
			if i != k and (k2 < 0 or absf(meta[i]["aspect"] - h / r) < absf(meta[k2]["aspect"] - h / r)):
				k2 = i
		if rng.randf() < 0.5:
			k = k2

		var yaw := (-PI * 0.25 + rng.randf_range(-0.4, 0.4)) if rng.randf() < 0.6 else rng.randf() * TAU
		var sc := Vector3(r * rng.randf_range(0.92, 1.0), h / meta[k]["aspect"] * rng.randf_range(0.9, 1.15),
			r * rng.randf_range(0.72, 0.95))
		var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), deg_to_rad(rng.randf_range(0.0, 3.0)))

		var gy := float(site[4])
		var gmin := gy
		for j in 12:
			var aj := TAU * j / 12.0
			gy = minf(gy, height_at(x + cos(aj) * r * 1.05, z + sin(aj) * r * 1.05))
			gmin = minf(gmin, height_at(x + cos(aj + PI / 12.0) * r * 1.3, z + sin(aj + PI / 12.0) * r * 1.3))
		gmin = minf(gmin, gy)
		gy = maxf(gy, float(site[4]) - 0.07 * h)
		var xf := Transform3D(tilt * Basis(Vector3.UP, yaw) * Basis.from_scale(sc), Vector3(x, gy - 1.0, z))

		var foot := Vector3(gy - 1.0, gy - gmin + 0.5, 0.15 * h) if _float_fix and gy - gmin > 1.0 else Vector3.ZERO
		var mi := MeshInstance3D.new()
		mi.mesh = near_meshes[k]
		mi.material_override = near_mat
		mi.transform = xf
		mi.visibility_range_end = KARST_NEAR
		var box: AABB = near_meshes[k].get_aabb()
		if foot.y > 0.0:
			var down := xf.basis.inverse() * Vector3.DOWN
			mi.set_instance_shader_parameter("foot_down", Vector4(down.x, down.y, down.z, foot.y))
			mi.set_instance_shader_parameter("foot_band", Vector2(foot.x, foot.z))
			box = box.merge(AABB(box.position + down * foot.y, box.size))
			mi.custom_aabb = box
		elif kv2:
			mi.set_instance_shader_parameter("foot_band", Vector2(gy - 1.0, 0.15 * h))
		add_child(mi)
		_karst_dress_add(near_meshes[k], k, xf, r)

		var sp: Vector3 = (mi.global_transform * box).get_center() if fk else Vector3.ZERO
		if fk:
			var mk := Vector2i(floori(x / K_CELL), floori(z / K_CELL))
			if not per_mid.has(mk):
				per_mid[mk] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedInt32Array(),
					PackedVector2Array(), PackedVector2Array()]
			_karst_merge(per_mid[mk], mid_arrays[k], xf, sp, foot)
			var fkey := Vector2i(floori(x / K_FAR_CELL), floori(z / K_FAR_CELL))
			if not per_far.has(fkey):
				per_far[fkey] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedInt32Array(),
					PackedVector2Array(), PackedVector2Array()]
			_karst_merge(per_far[fkey], far_arrays[k], xf, sp, foot)
		var fa: Array = far_arrays[k]
		var pts := PackedVector3Array()
		for v: Vector3 in fa[Mesh.ARRAY_VERTEX]:
			pts.append(_karst_foot(xf * v, foot))
		if _occlude:
			var oc := OccluderInstance3D.new()
			var bo := BoxOccluder3D.new()
			bo.size = Vector3(r * 1.15, h * 0.8, r * 1.15)
			oc.occluder = bo
			oc.transform = Transform3D(xf.basis.orthonormalized(), Vector3(x, float(site[4]) + h * 0.4, z))
			add_child(oc)
		var cs := CollisionShape3D.new()
		var hull := ConvexPolygonShape3D.new()
		hull.points = pts
		cs.shape = hull
		body.add_child(cs)
		if fk:
			continue
		var key := Vector2i(floori(x / KHU), floori(z / KHU))
		if not per_khu.has(key):
			per_khu[key] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedInt32Array()]
		var acc: Array = per_khu[key]
		var base: int = acc[0].size()
		acc[0].append_array(pts)
		for nv: Vector3 in fa[Mesh.ARRAY_NORMAL]:
			acc[1].append((xf.basis.inverse().transposed() * nv).normalized())
		acc[2].append_array(fa[Mesh.ARRAY_COLOR])
		for i: int in fa[Mesh.ARRAY_INDEX]:
			acc[3].append(base + i)
	_karst_dress_build()
	if fk:
		_karst_sets(per_far, _karst_far_mat, K_MID, 1.0e9)
		_karst_sets(per_mid, mid_mat, KARST_NEAR, K_MID)
		return
	for key in per_khu:
		var acc: Array = per_khu[key]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = acc[0]
		arr[Mesh.ARRAY_NORMAL] = acc[1]
		arr[Mesh.ARRAY_COLOR] = acc[2]
		arr[Mesh.ARRAY_INDEX] = acc[3]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var far := MeshInstance3D.new()
		far.mesh = m
		far.material_override = _karst_far_mat
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(far)

func _karst_skirt() -> void:
	if not _float_fix or terrain == null or not ResourceLoader.exists(KARST_DIR + "skirt.glb"):
		return
	var m: ShaderMaterial = terrain._mat_far.duplicate()
	m.set_shader_parameter("ring", Vector2.ZERO)
	m.set_shader_parameter("depth_push", 0.0)
	for p_: String in ["road_on", "rail_on", "road_info_on"]:
		m.set_shader_parameter(p_, false)
	m.set_shader_parameter("paint_on", 0.0)
	var hv := Vector3.ZERO
	var ks := _karst_far_mat.shader.get_rid()
	for i_ in 3:
		var n_: String = ["haze_near", "haze_far", "haze_max"][i_]
		var v_: Variant = _karst_far_mat.get_shader_parameter(n_)
		if v_ == null:
			v_ = RenderingServer.shader_get_parameter_default(ks, n_)
		hv[i_] = float(v_) if v_ != null else [110.0, 900.0, 0.72][i_]
	m.set_shader_parameter("skirt_haze", hv)
	if _karst_far_mat.get_shader_parameter("karst_v2"):
		m.set_shader_parameter("skirt_v2", Vector4(1.0, 0.55, 0.55, 0.12))
	var sk := MeshInstance3D.new()
	sk.name = "KarstSkirt"
	sk.mesh = _first_mesh(KARST_DIR + "skirt.glb")
	sk.material_override = m
	sk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sk)

func _karst_foot(p: Vector3, foot: Vector3) -> Vector3:
	if foot.y > 0.0:
		p.y -= foot.y * (1.0 - smoothstep(0.0, foot.z, p.y - foot.x))
	return p

const KD_R := 200.0
const KD_STEP := 40.0
const KD_PER := 44
const KD_KINDS := {"bui_dai_a": 0.45, "bui_dai_b": 0.40, "co_bui": 0.15}
var _kd_cand := {}
var _kd_all := {}
var _kd_mm := {}
var _kd_at := Vector3(1.0e9, 0.0, 1.0e9)
var _kd_rng := RandomNumberGenerator.new()
var _kd_cells := {}
const KD_CELL := 128.0

func _karst_dress_on() -> bool:
	return OS.get_environment("MC_KARST_DRESS_OLD") == ""

func _karst_dress_add(mesh: Mesh, k: int, xf: Transform3D, r: float) -> void:
	if not _karst_dress_on() or mesh == null:
		return
	if _kd_all.is_empty():
		_kd_rng.seed = 23
		for kind: String in KD_KINDS:
			_kd_all[kind] = [PackedVector3Array(), []]
	if not _kd_cand.has(k):
		var a := mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var cs: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var top := 0.0
		for v in vs:
			top = maxf(top, v.y)
		var cand := PackedInt32Array()
		for i in vs.size():

			var rock := cs.is_empty() or cs[i].g - maxf(cs[i].r, cs[i].b) < 0.04
			if ns[i].y > 0.4 and rock and (cs.is_empty() or cs[i].a > 0.45) and vs[i].y > 0.15 * top:
				cand.append(i)
		_kd_cand[k] = [vs, cand, top]
	var e: Array = _kd_cand[k]
	var vs2: PackedVector3Array = e[0]
	var cand2: PackedInt32Array = e[1]
	if cand2.is_empty():
		return
	var placed := PackedVector3Array()
	var size := clampf(r * 0.15, 3.0, 7.0)
	for n in KD_PER:
		var p: Vector3 = xf * vs2[cand2[_kd_rng.randi() % cand2.size()]]
		var ok := true
		for q in placed:
			if q.distance_squared_to(p) < size * size * 0.8:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		var kind := "co_bui"
		var roll := _kd_rng.randf()
		for kk: String in KD_KINDS:
			roll -= float(KD_KINDS[kk])
			if roll <= 0.0:
				kind = kk
				break
		var s := size * _kd_rng.randf_range(0.75, 1.25)
		var entry: Array = _kd_all[kind]
		var origins: PackedVector3Array = entry[0]
		origins.append(p)
		entry[0] = origins
		(entry[1] as Array).append(Transform3D(Basis(Vector3.UP, _kd_rng.randf() * TAU).scaled(Vector3(s, s, s)),
			p - Vector3(0.0, 0.15 * s, 0.0)))

func _karst_dress_build() -> void:
	if not _karst_dress_on():
		return
	for kind: String in _kd_all:
		var km := _kit_mesh("cay/" + kind)
		if km.is_empty():
			continue
		var mat := (HomeKit._plant_material(km[1]) as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter("lod_mode", 1)
		mat.set_shader_parameter("lod_r", KD_R)
		mat.set_shader_parameter("lod_band", 14.0)
		_lod_mats.append(mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = km[0]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_kd_mm[kind] = mm
		var cells := {}
		var os_: PackedVector3Array = _kd_all[kind][0]
		for i in os_.size():
			var ck := Vector2i(floori(os_[i].x / KD_CELL), floori(os_[i].z / KD_CELL))
			if not cells.has(ck):
				cells[ck] = PackedInt32Array()
			var lst: PackedInt32Array = cells[ck]
			lst.append(i)
			cells[ck] = lst
		_kd_cells[kind] = cells
	if OS.get_cmdline_user_args().has("--village-log") or OS.get_environment("MC_KD_LOG") != "":
		for kind: String in _kd_all:
			print("karst dress: %s %d" % [kind, (_kd_all[kind][0] as PackedVector3Array).size()])

func _karst_dress_tick(vp: Vector3) -> void:
	if _kd_mm.is_empty() or Vector2(vp.x - _kd_at.x, vp.z - _kd_at.z).length() < KD_STEP:
		return
	var t0 := Time.get_ticks_usec()
	_kd_at = vp
	var reach := KD_R + KD_STEP + 20.0
	var r2 := reach * reach
	var c0 := Vector2i(floori((vp.x - reach) / KD_CELL), floori((vp.z - reach) / KD_CELL))
	var c1 := Vector2i(floori((vp.x + reach) / KD_CELL), floori((vp.z + reach) / KD_CELL))
	var n_all := 0
	for kind: String in _kd_mm:
		var e: Array = _kd_all[kind]
		var os_: PackedVector3Array = e[0]
		var xs: Array = e[1]
		var cells: Dictionary = _kd_cells[kind]
		var keep := PackedInt32Array()
		for cz in range(c0.y, c1.y + 1):
			for cx in range(c0.x, c1.x + 1):
				var ck := Vector2i(cx, cz)
				if not cells.has(ck):
					continue
				for i: int in cells[ck]:
					var d := Vector2(os_[i].x - vp.x, os_[i].z - vp.z)
					if d.length_squared() < r2:
						keep.append(i)
		var mm: MultiMesh = _kd_mm[kind]
		mm.instance_count = keep.size()
		for j in keep.size():
			mm.set_instance_transform(j, xs[keep[j]])
		n_all += keep.size()
	if OS.get_environment("MC_KD_LOG") != "":
		print("karst dress refill: %d plants, %.2f ms" % [n_all, (Time.get_ticks_usec() - t0) / 1000.0])

func _karst_merge(acc: Array, fa: Array, xf: Transform3D, sp: Vector3, foot := Vector3.ZERO) -> void:
	var base: int = acc[0].size()
	var nb := xf.basis.inverse().transposed()
	for v: Vector3 in fa[Mesh.ARRAY_VERTEX]:
		acc[0].append(_karst_foot(xf * v, foot))
	for nv: Vector3 in fa[Mesh.ARRAY_NORMAL]:
		acc[1].append((nb * nv).normalized())
	acc[2].append_array(fa[Mesh.ARRAY_COLOR])
	for i: int in fa[Mesh.ARRAY_INDEX]:
		acc[3].append(base + i)
	var n: int = (fa[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var uv := PackedVector2Array()
	uv.resize(n)
	uv.fill(Vector2(sp.y, xf.origin.y + 1.0 - foot.y))
	var uv2 := PackedVector2Array()
	uv2.resize(n)
	uv2.fill(Vector2(sp.x, sp.z))
	acc[4].append_array(uv)
	acc[5].append_array(uv2)

func _karst_sets(sets: Dictionary, mat: ShaderMaterial, lo: float, hi: float) -> void:
	for key in sets:
		var acc: Array = sets[key]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = acc[0]
		arr[Mesh.ARRAY_NORMAL] = acc[1]
		arr[Mesh.ARRAY_COLOR] = acc[2]
		arr[Mesh.ARRAY_TEX_UV] = acc[4]
		arr[Mesh.ARRAY_TEX_UV2] = acc[5]
		arr[Mesh.ARRAY_INDEX] = acc[3]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var half := m.get_aabb().size.length() * 0.5 + 5.0
		mi.visibility_range_begin = maxf(lo - half, 0.0)
		if hi < 1.0e8:
			mi.visibility_range_end = hi + half
		add_child(mi)

func _first_mesh(path: String) -> Mesh:
	var sc := (load(path) as PackedScene).instantiate()
	var mi := sc.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var m := mi.mesh
	sc.free()
	return m

func _khu_for(p: Vector2) -> Node3D:
	var key := Vector2i(floori(p.x / KHU), floori(p.y / KHU))
	if not khus.has(key):
		var k := Node3D.new()
		k.name = "Khu_%d_%d" % [key.x, key.y]
		k.set_meta("centre", Vector3((key.x + 0.5) * KHU, 0, (key.y + 0.5) * KHU))
		add_child(k)
		khus[key] = k
	return khus[key]

func _in_village(x: float, z: float) -> bool:
	return absf(x) < VPLAY and absf(z) < VPLAY

func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)

var _names: Array[Label3D] = []
var show_names := true

func _label(text: String, pos: Vector3, size := 1.0, parent: Node3D = null) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.00055 * size
	l.outline_size = 18
	l.modulate = Color("fffaf2")
	l.outline_modulate = Color("5b4a44")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.position = pos
	l.visibility_range_end = LABEL_END * size
	l.visible = show_names
	(parent if parent != null else self).add_child(l)
	_names.append(l)

const KIT_SHADOW := ["luy_tre", "bui_tre", "cay_gao", "cay_phuong", "cay_keo", "cay_da", "cay_bang_lang", "cay_hoa_sua",
	"cay_gao_b", "cay_gao_c", "cay_phuong_b", "cay_phuong_c", "cay_keo_b", "cay_keo_c", "cay_bang_lang_b", "cay_bang_lang_c",
	"cay_hoa_sua_b", "cay_hoa_sua_c"]

func que_chapter() -> int:
	if Stage.arg("--chapter") != "":
		return clampi(int(Stage.arg("--chapter")), 1, 4)
	Story.load_saved()
	var c := String(Story.chapter)
	return clampi(int(c.substr(4)), 1, 4) if c.begins_with("que_") else 1

var _farm_gate: Node3D
var _farm_gate_rest: Transform3D

var _farm_door_ok := false
var _farm_door_pos := Vector3.ZERO
var _farm_door_armed := false
var _farm_door_going := false

func _farm_door_setup(spawn_given: bool) -> void:
	var args := OS.get_cmdline_user_args()
	_farm_door_ok = _farm_gate != null and not spawn_given and not (args.has("--clean") or args.has("--still")
		or args.has("--measure") or args.has("--fly") or Stage.arg("--fly") != "")
	if not _farm_door_ok:
		return
	var yd := _farm_gate.get_parent() as Node3D
	_farm_door_pos = yd.to_global(Vector3(0, 0, 9.0))
	var out := yd.global_transform.basis.z.normalized()
	if String(Story.flag("spawn_at", "")) == "farm_gate":
		Story.set_flag("spawn_at", "")
		var p := _farm_door_pos + out * 2.6
		player.position = Vector3(p.x, height_at(p.x, p.z) + 0.2, p.z)
		player.rotation.y = atan2(out.x, out.z)
		player.facing = player.rotation.y

func _farm_door_step() -> void:
	if not _farm_door_ok or _farm_door_going or player == null or not player.controls or map_view or player.riding():
		return
	var d := player.global_position - _farm_door_pos
	d.y = 0.0
	if d.length() > 3.2:
		_farm_door_armed = true
	elif _farm_door_armed and d.length() < 1.7:
		_farm_door_going = true
		player.controls = false
		Story.set_flag("spawn_at", "farm_lane")
		var layer := CanvasLayer.new()
		layer.layer = 90
		var black := ColorRect.new()
		black.color = Color(0, 0, 0, 0)
		black.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(black)
		add_child(layer)
		var tw := create_tween()
		tw.tween_property(black, "color:a", 1.0, 0.6)
		await tw.finished
		get_tree().change_scene_to_file("res://scenes/farm_plot.tscn")

func set_farm_gate(state: String) -> void:
	if _farm_gate == null:
		return
	var leaf := _farm_gate.find_child("Gate", true, false) as Node3D
	_gate_wire(state == "buoc")
	match state:
		"do":
			_farm_gate.transform = _farm_gate_rest * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(84.0)), Vector3(0, 0.06, 0.05))
			if leaf:
				leaf.rotation.y = 0.0
		"buoc":
			_farm_gate.transform = _farm_gate_rest * Transform3D(Basis(Vector3.BACK, deg_to_rad(3.0)), Vector3.ZERO)
			if leaf:
				leaf.rotation.y = 0.0
		_:
			_farm_gate.transform = _farm_gate_rest * Transform3D(Basis(Vector3.BACK, deg_to_rad(-10.0)) * Basis(Vector3.RIGHT, deg_to_rad(-4.0)), Vector3.ZERO)
			if leaf:
				leaf.rotation.y = deg_to_rad(-28.0)

func _gate_wire(on: bool) -> void:
	var w := _farm_gate.get_node_or_null("Wire") as Node3D
	if w == null:
		if not on:
			return
		w = Node3D.new()
		w.name = "Wire"
		_farm_gate.add_child(w)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("e4ebee")
		mat.metallic = 0.85
		mat.roughness = 0.22
		for k in 3:
			var t := TorusMesh.new()
			t.inner_radius = 0.080
			t.outer_radius = 0.099
			t.rings = 6
			t.ring_segments = 3
			var mi := MeshInstance3D.new()
			mi.mesh = t
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(0.355, 0.5 + k * 0.035 + (0.36 if k == 2 else 0.0), 0.0)
			mi.rotation = Vector3(deg_to_rad(8.0 - k * 7.0), 0.0, deg_to_rad(-6.0 + k * 5.0))
			w.add_child(mi)
		var tail := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.008
		c.bottom_radius = 0.008
		c.height = 0.12
		c.radial_segments = 4
		c.rings = 1
		tail.mesh = c
		tail.material_override = mat
		tail.position = Vector3(0.45, 0.55, 0.06)
		tail.rotation = Vector3(deg_to_rad(70.0), 0.0, deg_to_rad(-40.0))
		w.add_child(tail)
	w.visible = on

func _kit_plants(parent: Node3D, items: Array) -> void:
	var by := {}
	for it: Dictionary in items:
		if not by.has(it["kind"]):
			by[it["kind"]] = []
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(it["yaw"]))).scaled(Vector3.ONE * float(it.get("scale", 1.0))),
			Vector3(it["pos"][0], 0.0, it["pos"][1]))
		by[it["kind"]].append(xf)
		if it.has("solid"):
			var bs := BoxShape3D.new()
			bs.size = Vector3(it["solid"][0], it["solid"][1], it["solid"][2])
			var sb := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			cs.shape = bs
			sb.add_child(cs)
			sb.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(it["yaw"]))), xf.origin + Vector3(0, bs.size.y / 2.0, 0))
			parent.add_child(sb)
	for kind: String in by:
		for part: String in [kind, kind + "_far"]:
			if not ResourceLoader.exists(HomeKit.DIR + part + ".glb"):
				continue
			var g: Node = load(HomeKit.DIR + part + ".glb").instantiate()
			for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
				var src := mi.mesh.surface_get_material(0)
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = mi.mesh
				mm.instance_count = by[kind].size()
				for i in by[kind].size():
					mm.set_instance_transform(i, (by[kind][i] as Transform3D) * mi.transform)
				var mmi := MultiMeshInstance3D.new()
				mmi.name = part.get_file() + "_x%d" % by[kind].size()
				mmi.multimesh = mm
				mmi.material_override = HomeKit._plant_material(kind.get_base_dir() + "/" + (src.resource_name if src else "la_cay"))
				var has_far := ResourceLoader.exists(HomeKit.DIR + kind + "_far.glb")

				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if part.ends_with("_far"):
					mmi.visibility_range_begin = HomeKit.FAR_AT
					if kind.get_file() in KIT_SHADOW:
						var sh := MultiMeshInstance3D.new()
						sh.name = part.get_file() + "_shadow"
						sh.multimesh = mm
						sh.material_override = mmi.material_override
						sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
						sh.visibility_range_end = HomeKit.FAR_AT
						parent.add_child(sh)
				else:
					mmi.visibility_range_end = HomeKit.FAR_AT if has_far else 40.0
				parent.add_child(mmi)
			g.free()

var _no_grass: Array[Vector3] = []
var _no_grass_rects: Array[Rect2] = []

func _model(name: String, pos: Vector3, yaw: float, boxes: Array) -> Node3D:
	var home: Node3D = self if _in_village(pos.x, pos.z) else _khu_for(Vector2(pos.x, pos.z))
	if not ResourceLoader.exists("res://props/hometown/%s.glb" % name):
		return null
	var n := HomeKit.place(home, name, pos, yaw)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", false, false):
		var bb := mi.get_aabb()
		_no_grass.append(Vector3(pos.x, pos.z, 0.5 * minf(bb.size.x, bb.size.z)))
		break
	for b: Array in boxes:
		var bs := BoxShape3D.new()
		bs.size = b[0]
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = bs
		sb.add_child(cs)
		sb.position = (b[1] as Vector3) + Vector3(0, (b[0] as Vector3).y / 2.0, 0)
		if b.size() > 2:
			sb.rotation_degrees = b[2]
		n.add_child(sb)
	return n

func _block(size: Vector3, pos: Vector3, c: Color, yaw := 0.0) -> void:
	var home: Node3D = self if _in_village(pos.x, pos.z) else _khu_for(Vector2(pos.x, pos.z))
	_piece(home, Props.box(size), c, pos + Vector3(0, size.y / 2, 0), Vector3(0, yaw, 0))
	var bs := BoxShape3D.new()
	bs.size = size
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos + Vector3(0, size.y / 2, 0)
	sb.rotation.y = deg_to_rad(yaw)
	add_child(sb)

func _build_places() -> void:
	for pl in layout["places"]:
		var p := _ground(pl["x"], pl["z"])
		var yaw: float = pl.get("yaw", 0.0)
		var far := not _in_village(pl["x"], pl["z"])
		var home: Node3D = _khu_for(Vector2(pl["x"], pl["z"])) if far else self
		match pl["kind"]:
			"station":

				var ga_cols := [[Vector3(7.35, 3.1, 4.7), Vector3(0, 0, 0)],
					[Vector3(28.1, 0.47, 5.7), Vector3(-4.68, 0, -4.88)], [Vector3(9.4, 0.47, 4.9), Vector3(0, 0, 0.27)],
					[Vector3(3.5, 0.1, 1.3), Vector3(0, 0.14, 3.33), Vector3(21.4, 0, 0)],
					[Vector3(1.3, 0.1, 5.5), Vector3(-19.34, 0.14, -4.88), Vector3(0, 0, 21.4)],
					[Vector3(1.3, 0.1, 5.5), Vector3(10.0, 0.14, -4.88), Vector3(0, 0, -21.4)]]
				for x in [-5.85, -1.95, 1.95, 5.85]:
					ga_cols.append([Vector3(0.2, 2.4, 0.2), Vector3(x, 0.47, -5.93)])
				for x in [-17.55, -8.42, 8.42, -7.47, -5.48]:
					ga_cols.append([Vector3(0.18, 2.3, 0.18), Vector3(x, 0.47, -6.71)])
				for x in [-3.74, 3.74]:
					ga_cols.append([Vector3(1.6, 0.7, 0.55), Vector3(x, 0.47, -4.45)])
				_model("nha_ga", p, yaw, ga_cols)
				if not OS.get_cmdline_user_args().has("--no-rails"):
					_rails()
				var to := Vector2(13.0, 7.0).rotated(-deg_to_rad(yaw))
				HomeKit.place_plant(home, "cay/cay_phuong", _ground(pl["x"] + to.x, pl["z"] + to.y), 30.0)
				_town(pl["x"], home)
				_town_life.call_deferred(home)
				_station_edges(home)
			"citadel_gate":
				_citadel_gate(p, home)
			"temple":
				_temple(p, yaw, home)
			"tower":
				ChuaMay.add_to_map(self, p)
			"cave_pagoda":
				var back := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw))) * -6.0
				Props.mesh(home, Props.box(Vector3(12, 9, 6)), Color("2e2c2a"), p + back + Vector3(0, 4.5, 0), Vector3(0, yaw, 0))
				_block(Vector3(6, 3.5, 5), p, Color("c98a5a"), yaw)
				Props.mesh(home, Props.box(Vector3(7.4, 0.6, 6.4)), Color("5a4a4a"), p + Vector3(0, 3.8, 0), Vector3(0, yaw, 0))
			"bench":
				_block(Vector3(1.8, 0.45, 0.55), p, Color("b8b0a0"), yaw)
			"cliff_pagoda":
				var vb: Dictionary = layout["region"]["vach_biec"]
				var c2 := Vector2(vb["x"], vb["z"])
				var out := (Vector2(pl["x"], pl["z"]) - c2).normalized()
				for k in 3:
					var want: float = [0.0, float(vb["h"]) * 0.32, float(vb["h"]) * 0.6][k]
					var q := Vector2(pl["x"], pl["z"])
					if k > 0:
						for step in 120:
							var r := float(vb["r"]) * 1.4 - step * 0.5
							q = c2 + out.rotated([0.0, -0.35, 0.3][k]) * r
							if height_at(q.x, q.y) >= want:
								break
						q += out.rotated([0.0, -0.35, 0.3][k]) * 2.5
					var y := maxf(height_at(q.x, q.y), want) if k > 0 else height_at(q.x, q.y)
					_block(Vector3(8, 0.6, 5), Vector3(q.x, y - 0.6, q.y), Color("b8b0a0"), yaw)
					_block(Vector3(6, 3.4, 4), Vector3(q.x, y, q.y), Color("c98a5a"), yaw)
					Props.mesh(home, Props.box(Vector3(7.4, 0.6, 5.4)), Color("5a4a4a"), Vector3(q.x, y + 3.7, q.y), Vector3(0, yaw, 0))
			"ancient_tree":
				_giant_tree(p, home)
			"cave_mouth":
				var fwd := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
				_piece(home, Props.box(Vector3(9, 7, 6)), Color("262422"), p + Vector3(0, 3.0, 0) - fwd * 2.0, Vector3(0, yaw, 0))
				for sx in [-1.0, 1.0]:
					_piece(home, Props.box(Vector3(2.4, 8, 3)), Color("8e887c"), p + Vector3(0, 4, 0) + fwd.cross(Vector3.UP) * sx * 5.4, Vector3(0, yaw, 0))
			"house_main":
				Props.house(self, p, yaw, Color("f3e9d8"), Color("b85a4a"))
			"house_parents":

				var yd := HomeKit.place_layout(self, "res://data/hometown/yard_nha_bo_me.json")
				yd.position = p
				yd.rotation.y = deg_to_rad(yaw)
				for b: Array in [[Vector3(7.7, 5.2, 4.9), Vector3(0, 0, -0.23)], [Vector3(8.2, 0.39, 6.6), Vector3(0, 0, 0.7)],
						[Vector3(5.65, 1.0, 0.3), Vector3(-4.58, 0, 7.6)], [Vector3(5.65, 1.0, 0.3), Vector3(4.58, 0, 7.6)],
						[Vector3(0.3, 1.0, 10.2), Vector3(-7.4, 0, 2.5)], [Vector3(0.3, 1.0, 10.2), Vector3(7.4, 0, 2.5)]]:
					var bs := BoxShape3D.new()
					bs.size = b[0]
					var sb := StaticBody3D.new()
					var cs := CollisionShape3D.new()
					cs.shape = bs
					sb.add_child(cs)
					sb.position = (b[1] as Vector3) + Vector3(0, (b[0] as Vector3).y / 2.0, 0)
					yd.add_child(sb)

				XeBo.add(yd, Vector3(3.7, 0.05, 5.6), -75.0)

				VespaRide.make(self, yd.global_transform * Vector3(-2.3, 0.03, 4.4), yaw + 36.0)
				_no_grass.append(Vector3(p.x, p.z, 8.6))
			"farm":
				var yard := HomeKit.place_layout(self, "res://data/hometown/yard_nha_cu.json", false, ["rao_tre", "coc_tre", "cong_tre"])
				yard.position = p
				yard.rotation.y = deg_to_rad(yaw)
				_farm_yard = yard
				_place_farm_house()
				if house_level >= 3:
					_no_grass_rects.append(Rect2(p.x - 3.3, p.z + 2.2, 6.6, 4.7))
					_no_grass_rects.append(Rect2(p.x - 5.1, p.z - 3.8, 2.4, 2.1))

				var ch := que_chapter()
				_place_farm_fence()
				_farm_gate = HomeKit.place(yard, "cong_tre", Vector3(0, 0, 9.0))
				_farm_gate_rest = _farm_gate.transform
				set_farm_gate(Stage.arg("--gate") if Stage.arg("--gate") != "" else (String(Story.flag("cong_trang_trai", "xieu")) if ch < 4 else "buoc"))

				var sur := HomeKit.place_layout(self, "res://data/hometown/farm_surround.json", false)
				sur.position = p
				sur.rotation.y = deg_to_rad(yaw)
				var sd: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hometown/farm_surround.json"))
				_kit_plants(sur, (sd["plants"] as Array).filter(func(it: Dictionary) -> bool:
					return not it.has("ch") or (ch >= int(it["ch"][0]) and ch <= int(it["ch"][1]))))
				if ResourceLoader.exists("res://props/furniture/bat_xanh.glb"):
					_tarp = Furniture.place(yard, "bat_xanh", Vector3.ZERO, 0.0, false)
				if ResourceLoader.exists("res://props/furniture/bat_xanh_flat.glb"):
					_tarp_flat = Furniture.place(yard, "bat_xanh_flat", Vector3(2.0, 0.22, 1.75), 15.0, false)
				set_roof_mended(house_level >= 1)
			"gate":
				_model("cong_lang", p, yaw, [[Vector3(1.0, 3.6, 1.0), Vector3(-2.8, 0, 0)], [Vector3(1.0, 3.6, 1.0), Vector3(2.8, 0, 0)]])
				_model("xe_mia", p + Vector3(4.6, 0, 2.2).rotated(Vector3.UP, deg_to_rad(yaw)), yaw + 180.0, [])
			"bus_stop":
				var ts := _model("tram_xe_que", p, yaw, [])
				if ts:
					_occluders.append([ts, AABB(), 0.0, false, [], AABB(), 0.6])
			"kitchen":
				_block(Vector3(4, 2.4, 3.5), p, Color("d9c7ac"), yaw)
			"banyan":
				var da := HomeKit.place_plant(self, "cay/cay_da", p, float(pl.get("yaw", 0.0)))

				_occluders.append([da, AABB(), 0.0, false, [], AABB(p + Vector3(-8.6, 4.3, -8.6), Vector3(17.2, 7.0, 17.2))])
				var tb := CylinderShape3D.new()
				tb.radius = 1.3
				tb.height = 4.0
				var tsb := StaticBody3D.new()
				var tcs := CollisionShape3D.new()
				tcs.shape = tb
				tsb.add_child(tcs)
				tsb.position = p + Vector3(0, 2.0, 0)
				add_child(tsb)
				_no_grass.append(Vector3(p.x, p.z, 2.2))

				var face := deg_to_rad(float(pl.get("face", 0.0)))
				var fwd := Vector3(sin(face), 0, cos(face))
				var side := Vector3(fwd.z, 0, -fwd.x)
				var sp := p + fwd * 2.9
				Furniture.place(self, "am_tho", _ground(sp.x, sp.z), rad_to_deg(face), true)
				var bp := p + fwd * 3.4 - side * 2.4
				_model("ghe_da", _ground(bp.x, bp.z), rad_to_deg(face) - 15.0, [])
			"dinh":

				var dn := _model("dinh_lang", p, yaw, [[Vector3(9.0, 0.5, 5.9), Vector3.ZERO]])
				if dn:
					dn.scale = Vector3.ONE * 1.45
				var ft := []
				for i in 12:
					for j in 9:
						ft.append(Transform3D(Basis(Vector3.UP, PI / 2.0 * ((i * 3 + j) % 4)), Vector3(-161.0 + i * 2.0, 7.01, -145.0 + j * 2.0)))
				_yard_dress("gach_vuon", ft, 110.0, false)
				_no_grass_rects.append(Rect2(-162.5, -146.5, 25.0, 19.0))
			"plaza":
				if String(pl.get("id", "")) == "san_dinh":
					_san_dinh(pl, p)
				elif String(pl.get("id", "")) == "san_bong":
					_san_bong(pl, p)
				elif String(pl.get("id", "")) != "san_ga":
					_piece(self, Props.box(Vector3(pl["w"], 0.12, pl["d"])), Color("d6cdb8"), p + Vector3(0, 0.04, 0))
			"hall":
				_model("nha_van_hoa", p, yaw, [[Vector3(9.4, 2.6, 4.4), Vector3(0, 0, -0.3)]])
			"village_pagoda":
				_model("chua_lang", p, yaw, [[Vector3(5.6, 2.4, 3.8), Vector3(0, 0, -0.3)],
					[Vector3(0.4, 2.26, 0.56), Vector3(-1.76, 0, 9.52)], [Vector3(0.4, 2.26, 0.56), Vector3(1.76, 0, 9.52)],
					[Vector3(0.36, 2.26, 0.56), Vector3(-0.68, 0, 9.52)], [Vector3(0.36, 2.26, 0.56), Vector3(0.68, 0, 9.52)],
					[Vector3(1.56, 0.86, 0.24), Vector3(-2.73, 0, 9.52)], [Vector3(1.56, 0.86, 0.24), Vector3(2.73, 0, 9.52)],
					[Vector3(0.75, 1.1, 0.75), Vector3(0, 0, 5.46)]])
			"well":
				_model("gieng", p, yaw, [[Vector3(1.6, 0.8, 1.6), Vector3.ZERO]])
			"shop":
				_model("quan_nuoc", p, yaw, [])
				_model("ghe_da", p + Vector3(-2.4, 0, 1.4).rotated(Vector3.UP, deg_to_rad(yaw)), yaw + 20.0, [])
			"market":
				_model("cho", p, yaw, [])

				SapGiay.add(self, p + Vector3(7.2, 0, 1.2).rotated(Vector3.UP, deg_to_rad(yaw)), deg_to_rad(yaw))
			"landing":
				pass
			"bridge":
				var ln: float = pl.get("len", 30.0)
				var x: float = pl["x"]
				var zc: float = pl["z"]

				ln += 6.0
				var y0 := height_at(x, zc - ln / 2.0) - 0.14
				var y1 := height_at(x, zc + ln / 2.0) - 0.14
				var pitch := atan2(y1 - y0, ln)
				var c := Vector3(x, (y0 + y1) / 2.0, zc)
				var dl := sqrt(ln * ln + (y1 - y0) * (y1 - y0))
				Props.mesh(self, Props.box(Vector3(2.6, 0.25, dl)), Color("c9a46a"), c, Vector3(-pitch, 0, 0))
				var bs := BoxShape3D.new()
				bs.size = Vector3(2.6, 0.25, dl)
				var sb := StaticBody3D.new()
				var cs := CollisionShape3D.new()
				cs.shape = bs
				sb.add_child(cs)
				sb.position = c
				sb.rotation.x = -pitch
				add_child(sb)
				for k in int(ln / 4.0):
					var zz := zc - ln / 2.0 + k * 4.0 + 2.0
					var yy := lerpf(y0, y1, (zz - (zc - ln / 2.0)) / ln)
					for sx in [-1.2, 1.2]:
						Props.mesh(self, Props.cyl(0.08, 0.08, 1.0), Color("9a7a4a"), Vector3(x + sx, yy + 0.5, zz))
				p.y = (y0 + y1) / 2.0
			"shrine":
				pass
		var lift := {"label": 4.0, "tower": 66.0, "ancient_tree": 52.0, "cave_mouth": 10.0, "citadel_gate": 19.0, "temple": 11.0}.get(pl["kind"], 9.0) as float
		if String(pl["name"]) != "":
			_label(pl["name"], p + Vector3(0, lift, 0), 1.0 if not far else 1.3, home if pl["kind"] != "tower" else null)
	_build_nui_rong()
	for hl in layout.get("hills", []):
		if String(hl["name"]) != "":
			_label(hl["name"], _ground(hl["x"], hl["z"]) + Vector3(0, 6.0, 0), 1.0)
	_build_dressing(layout["dress"])

	var kinds := {"ga": ["ga_trong", "ga_mai", "ga_mai", "ga_con", "ga_mai", "ga_con"], "vit": ["vit"], "trau": ["trau"]}
	var acts := {"ga_trong": ["Idle", "Peck"], "ga_mai": ["Peck", "Idle", "Peck"], "ga_con": ["Peck", "Idle"],
		"vit": ["Preen", "Idle", "Dabble"], "trau": ["Graze", "Graze", "Idle"]}
	var arng := RandomNumberGenerator.new()
	arng.seed = 23
	for an in layout["animals"]:
		var list: Array = kinds.get(an["kind"], [])
		for k in int(an["n"]):
			if list.is_empty():
				break
			var a: float = TAU * k / float(an["n"]) + arng.randf_range(-0.3, 0.3)
			var rr := arng.randf_range(1.5, 3.6) if an["kind"] != "trau" else 4.0
			var x: float = an["x"] + cos(a) * rr
			var z: float = an["z"] + sin(a) * rr
			var kind: String = list[k % list.size()]
			var wet: bool = an["kind"] == "vit" and height_at(x, z) < 0.15
			var fa := FarmAnimal.spawn(self, kind, Vector3(x, 0.0 if wet else height_at(x, z), z), arng.randf() * TAU, "random")
			var clips: Array = ["Swim"] if wet else acts.get(kind, ["Idle"])
			fa.play.call_deferred(clips[arng.randi() % clips.size()])
	Props.bake(self)
	_cull_small.call_deferred()

func _build_dressing(d: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var walls := [Color("f4e3b8"), Color("e9eef0"), Color("f2d7c4"), Color("dfe9d6"), Color("f6efe2")]
	var n_ong := 0
	for i in d["houses"].size():
		var h: Array = d["houses"][i]
		var kind: String = h[3] if h.size() > 3 else "cu"
		var model: String = {"cu": "nha_cu", "thai": THAI_VARIANTS[i % THAI_VARIANTS.size()],
			"nhat": NHAT_VARIANTS[i % NHAT_VARIANTS.size()], "ong": ONG_VARIANTS[n_ong % ONG_VARIANTS.size()]}.get(kind, "")
		if kind == "ong":
			n_ong += 1
		var town := h.size() > 4 and String(h[4]) == "thi_tran"
		if town:
			model = "nha_pho_co_" + kind.substr(3) if kind.begins_with("pc_") else "nha_" + kind
		if model != "" and ResourceLoader.exists("res://props/hometown/%s.glb" % model):

			var hn := HomeKit.place(self, model, _ground(h[0], h[1]), h[2], {}, 22.0 if town else HomeKit.FAR_AT)
			if town and kind.begins_with("pc_") and i % 4 == 1:
				var hw: float = {"a": 1.8, "b": 1.6, "c": 2.2, "d": 1.9, "e": 1.5, "f": 2.4, "g": 1.7, "h": 2.0}[kind.substr(3)]
				var g := HomeKit.place(hn, "hoa_giay", Vector3((hw - 0.15) * 0.78 * (1 if i % 8 == 1 else -1), 0.0, 3.05), 0.0)
				for gi: GeometryInstance3D in g.find_children("*", "GeometryInstance3D", true, false):
					gi.visibility_range_end = 70.0
			if town:
				_occluders.append([hn, AABB(), 0.0, false, []])

				var hx := hn.global_transform
				var bike: bool = model in ["nha_ong", "nha_ong_suaxe", "nha_ong_cao", "nha_ong_thap"] and i % 2 == 0
				for j in (1 if rng.randf() < 0.55 and not bike else 0):
					var pick := rng.randf()
					var sname: String = "via_he_d" if pick < 0.12 else ("via_he_a" if pick < 0.45 else ("via_he_b" if pick < 0.7 else ("via_he_c" if pick < 0.85 else "via_he_e")))
					var lx := (-0.45 if i % 2 == 0 else 0.45) + rng.randf_range(-0.1, 0.1)
					var lz := 2.55 + rng.randf_range(-0.05, 0.1)
					var at := hx * Vector3(lx, 0.0, lz)
					at.y = height_at(at.x, at.z) + 0.1
					var basis := hx.basis * Basis(Vector3.UP, rng.randf_range(-0.35, 0.35))
					if not _town_sets.has(sname):
						_town_sets[sname] = []
					_town_sets[sname].append(Transform3D(basis, at))
					_town_solid(at, Vector3(1.1, 0.7, 0.75), basis)
			var plant := ""
			var at := Vector3.ZERO
			if kind == "thai" and i % 3 != 1:
				plant = "hoa_giay"
				at = HomeKit.THAI_GIAY
			elif kind == "nhat":
				plant = "tung"
				at = HomeKit.NHAT_TUNG
			if plant != "":
				var g := HomeKit.place(hn, plant, at, 0.0)
				for gi: GeometryInstance3D in g.find_children("*", "GeometryInstance3D", true, false):
					gi.visibility_range_end = 90.0
			if kind.begins_with("ong"):
				for pp: Vector3 in ([] if town else HomeKit.ONG_POTS):
					var g2 := HomeKit.place(hn, "chau_cay", pp, float(i * 73 % 360))
					for gi: GeometryInstance3D in g2.find_children("*", "GeometryInstance3D", true, false):
						gi.visibility_range_end = 60.0
				if model in ["nha_ong", "nha_ong_suaxe", "nha_ong_cao", "nha_ong_thap"] and (not town or i % 2 == 0) \
						and ResourceLoader.exists("res://props/furniture/xe_dream.glb"):
					var bike := Furniture.place(hn, "xe_dream", HomeKit.ONG_MOTO, 80.0, false)
					for gi: GeometryInstance3D in bike.find_children("*", "GeometryInstance3D", true, false):
						gi.visibility_range_end = 40.0
		else:
			_house_block(kind, _ground(h[0], h[1]), h[2], walls[i % walls.size()])
	for sname: String in _town_sets:
		_instanced_model(sname, _town_sets[sname], 30.0)
	for f in d["fences"]:
		Props.fence(self, _ground(f[0], f[1]), _ground(f[2], f[3]), Color("c9a46a"))

	var inst := {}

	var kit := {}
	var yard := {}
	var homes := []
	for h in d["houses"]:
		homes.append(Vector2(h[0], h[1]))
	var trunk := {"cay_keo": 0.22, "cay_gao": 0.8, "cay_phuong": 0.4, "bui_tre": 1.5}
	for t in d["trees"]:
		var p := _ground(t[0], t[1])
		var yaw := rng.randf() * TAU
		match t[2]:
			"tree":
				var homey := false
				for hv: Vector2 in homes:
					if hv.distance_squared_to(Vector2(t[0], t[1])) < 45.0 * 45.0:
						homey = true
						break
				var r := rng.randf()
				var kind: String
				if homey:
					kind = "cay_phuong" if r < 0.25 else ("cay_gao" if r < 0.45 else ("cay_keo" if r < 0.65 else "bui_tre"))
				else:
					kind = "cay_keo" if r < 0.6 else ("cay_gao" if r < 0.85 else "bui_tre")
				var sc := rng.randf_range(0.78, 1.02) if kind != "cay_gao" else rng.randf_range(0.72, 0.92)
				if _vl_cut(p): continue
				_add_xf(kit, kind, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc, sc)), p))
				var cap := CylinderShape3D.new()
				cap.radius = float(trunk[kind]) * sc
				cap.height = 2.4
				Props.solid(self, cap, p + Vector3(0, 1.2, 0))
			"cau", "chuoi":
				if _vl_cut(p) and rng.randf() >= 0.0: continue
				_add_xf(yard, "cay_" + String(t[2]), Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.85, 1.1)), p))
	for b in d["bamboo"]:
		var p := _ground(b[0], b[1])
		_add_xf(kit, "bui_tre", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.15)), p))
		var cap := CylinderShape3D.new()
		cap.radius = 1.4
		cap.height = 2.4
		Props.solid(self, cap, p + Vector3(0, 1.2, 0))
	for q in d.get("luy", []):
		var p := _ground(q[0], q[1])
		var bas := Basis(Vector3.UP, deg_to_rad(float(q[2])))
		_add_xf(kit, "luy_tre", Transform3D(bas.scaled(Vector3.ONE * float(q[3])), p))
		var bs := BoxShape3D.new()
		bs.size = Vector3(6.8 * float(q[3]), 3.0, 3.4)
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = bs
		sb.add_child(cs)
		sb.transform = Transform3D(bas, p + Vector3(0, 1.5, 0))
		add_child(sb)
	for b in d["bushes"]:
		_add_xf(kit, "bui_dai_a" if rng.randf() < 0.5 else "bui_dai_b",
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.2)), _ground(b[0], b[1])))
	_hoa_mua(kit)
	for kind: String in kit:
		_kit_dress(kind, kit[kind])
	for nm: String in yard:
		_yard_dress(nm, yard[nm])
	_house_yards()
	_xom_dinh()
	TamCoc.add(self)
	_shore()
	for r in d["rocks"]:
		var sc: float = r[2]
		_add_inst(inst, "rock", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), _ground(r[0], r[1])), Color.WHITE)
	for pl in d["poles"]:
		_add_inst(inst, "pole", Transform3D(Basis(), _ground(pl[0], pl[1])), Color.WHITE)
	for kind in inst:
		_instanced(_dress_mesh(kind), inst[kind], DRESS_END.get(kind, 120.0), kind in ["tree", "bamboo", "cau"])
	_flowers(d["flowers"])
	_grass()
	_wild_bushes()
	_rice()

const THAI_VARIANTS := ["nha_thai", "nha_thai_reu", "nha_thai_lam", "nha_thai_nau"]
const NHAT_VARIANTS := ["nha_nhat", "nha_nhat_do", "nha_nhat_xanh"]
const ONG_VARIANTS := ["nha_ong_taphoa", "nha_ong_suaxe", "nha_ong"]
const DRESS_END := {"tree": 260.0, "bamboo": 200.0, "cau": 180.0, "chuoi": 140.0, "pole": 140.0, "bush": 70.0, "rock": 70.0}
const DRESS_CHUNK := 64.0

func _add_xf(by: Dictionary, kind: String, xf: Transform3D) -> void:
	if not by.has(kind):
		by[kind] = []
	by[kind].append(xf)

func _hoa_mua(kit: Dictionary) -> void:
	if not FileAccess.file_exists(DIR + "hoa_mua.json"):
		return
	var hm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "hoa_mua.json"))
	for kind: String in ["cay_bang_lang", "cay_hoa_sua"]:
		for t: Array in hm.get(kind, []):
			if _vl_cut(Vector3(t[0], 0, t[1])): continue
			var p := _ground(t[0], t[1])
			_add_xf(kit, kind, Transform3D(Basis(Vector3.UP, deg_to_rad(t[2])).scaled(Vector3.ONE * float(t[3])), p))
			var cap := CylinderShape3D.new()
			cap.radius = (0.3 if kind == "cay_bang_lang" else 0.45) * float(t[3])
			cap.height = 2.4
			Props.solid(self, cap, p + Vector3(0, 1.2, 0))

const LOD_R := 45.0
const LOD_CELL := 32.0
const KIT_LOD_R := {"co_lau": 22.0, "bui_dai_b": 22.0, "bui_dai_a": 26.0}

var _lod_mats: Array[ShaderMaterial] = []

const FAR_WIDEN := {"luy_tre": 1.28}

const KIT_VARIANTS := ["cay_keo", "cay_gao", "cay_phuong", "cay_bang_lang", "cay_hoa_sua"]

func _kit_dress(kind: String, xfs: Array, lod_r := -1.0, near_only := false) -> void:
	var all_xfs := xfs
	if kind in KIT_VARIANTS and ResourceLoader.exists(HomeKit.DIR + "cay/" + kind + "_b.glb") \
			and not OS.get_cmdline_user_args().has("--no-tree-variants"):
		var by := [[], [], []]
		for xf: Transform3D in xfs:
			var h := (roundi(xf.origin.x * 4.0) * 73856093) ^ (roundi(xf.origin.z * 4.0) * 19349663)
			h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
			by[(h ^ (h >> 16)) % 3].append(xf)
		for i in [1, 2]:
			if not by[i].is_empty():
				_kit_dress(kind + ["", "_b", "_c"][i], by[i], lod_r, true)
		xfs = by[0]
	var near := _kit_mesh("cay/" + kind)
	if near.is_empty():
		return
	if not xfs.is_empty():
		CanopyShadow.add(kind, xfs)
	var far := _kit_mesh("cay/" + (kind.left(-2) if near_only else kind) + "_far")
	var lr: float = KIT_LOD_R.get(kind, LOD_R) if lod_r <= 0.0 else lod_r
	var cells := {}
	for xf: Transform3D in xfs:
		var key := Vector2i(floori(xf.origin.x / LOD_CELL), floori(xf.origin.z / LOD_CELL))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(xf)
	for key: Vector2i in cells:
		var c := Vector3((key.x + 0.5) * LOD_CELL, 0, (key.y + 0.5) * LOD_CELL)
		var mi := _mmi(near[0], cells[key], c)
		mi.material_override = _lod_mat(near[1], 1 if not far.is_empty() else 0, lr)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = (lr + LOD_CELL * 0.75) if not far.is_empty() else 40.0
		mi.name = kind + "_near"
	if far.is_empty() or near_only:
		return
	if kind in KIT_SHADOW:
		var scells := {}
		for xf: Transform3D in all_xfs:
			var key := Vector2i(floori(xf.origin.x / LOD_CELL), floori(xf.origin.z / LOD_CELL))
			if not scells.has(key):
				scells[key] = []
			scells[key].append(xf)
		for key: Vector2i in scells:
			var sh := _mmi(far[0], scells[key], Vector3((key.x + 0.5) * LOD_CELL, 0, (key.y + 0.5) * LOD_CELL))
			sh.material_override = _lod_mat(far[1], 1, lr)
			sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			sh.visibility_range_end = lr + LOD_CELL * 0.75
			sh.name = kind + "_shadow"
	xfs = all_xfs
	if KIT_LOD_R.has(kind):
		var fc := {}
		for xf: Transform3D in xfs:
			_add_xf(fc, str(Vector2i(floori(xf.origin.x / 64.0), floori(xf.origin.z / 64.0))), xf)
		for key: String in fc:
			var o: Vector3 = (fc[key][0] as Transform3D).origin
			var c := Vector3((floori(o.x / 64.0) + 0.5) * 64.0, 0, (floori(o.z / 64.0) + 0.5) * 64.0)
			var f2 := _mmi(far[0], fc[key], c)
			f2.material_override = _lod_mat(far[1], 2, lr)
			f2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			f2.visibility_range_end = 110.0
			f2.name = kind + "_far"
		return
	var fxs := xfs
	if FAR_WIDEN.has(kind):
		fxs = []
		for xf: Transform3D in xfs:
			fxs.append(Transform3D(xf.basis * Basis.from_scale(Vector3(FAR_WIDEN[kind], 1.0, FAR_WIDEN[kind])), xf.origin))
	var fm := _mmi(far[0], fxs, Vector3.ZERO)
	fm.material_override = _lod_mat(far[1], 2, lr)
	fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fm.name = kind + "_far"

func _temple_foot() -> void:
	var kit := {}
	for t: Array in layout.get("temple_trees", []):
		_add_xf(kit, String(t[2]), Transform3D(Basis(Vector3.UP, deg_to_rad(float(t[3]))).scaled(Vector3.ONE * float(t[4])),
			Vector3(t[0], height_at(t[0], t[1]) - 0.2, t[1])))
	for kind: String in kit:
		_kit_dress(kind, kit[kind], 25.0)
	const DROP := 0.3 * 0.78
	for c: Dictionary in layout.get("crossings", []):
		_model("duong_ngang", Vector3(c["x"], height_at(c["x"], c["z"]) + 0.02 - DROP, c["z"]), float(c["track_yaw"]), [])
		for b: Array in c["barriers"]:
			_model("rao_chan", Vector3(b[0], height_at(b[0], b[1]) - DROP, b[1]), float(b[2]),
				[[Vector3(0.6, 1.6, 0.6), Vector3(0, 0.8, 0)]])
		for g: Array in c["signs"]:
			_model("bien_ngang", Vector3(g[0], height_at(g[0], g[1]) - DROP, g[1]), float(g[2]),
				[[Vector3(0.15, 2.0, 0.15), Vector3(0, 1.0, 0)]])

func _kit_mesh(part: String) -> Array:
	if not ResourceLoader.exists(HomeKit.DIR + part + ".glb"):
		return []
	var g: Node = load(HomeKit.DIR + part + ".glb").instantiate()
	var out := []
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		var src := mi.mesh.surface_get_material(0)
		out = [mi.mesh, part.get_base_dir() + "/" + (src.resource_name if src else "la_cay")]
		break
	g.free()
	return out

func _lod_mat(atlas: String, mode: int, r := LOD_R) -> ShaderMaterial:
	var key := "lod|%s|%d|%d" % [atlas, mode, int(r)]
	if _lod_cache.has(key):
		return _lod_cache[key]
	var m: ShaderMaterial = (HomeKit._plant_material(atlas) as ShaderMaterial).duplicate()
	m.set_shader_parameter("lod_mode", mode)
	m.set_shader_parameter("lod_r", r)
	if mode != 0:
		_lod_mats.append(m)
	_lod_cache[key] = m
	return m

var _lod_cache := {}

func _mmi(mesh: Mesh, xfs: Array, c: Vector3) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		var xf: Transform3D = xfs[i]
		mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - c))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.position = c
	add_child(mi)
	return mi

func _san_dinh(pl: Dictionary, p: Vector3) -> void:
	var w: float = pl["w"]
	var dd: float = pl["d"]
	var tiles := []
	var kerb := []
	for i in int(w / 2.0):
		for j in int(dd / 2.0):
			var x := p.x - w / 2.0 + 1.0 + i * 2.0
			var z := p.z - dd / 2.0 + 1.0 + j * 2.0
			tiles.append(Transform3D(Basis(Vector3.UP, PI / 2.0 * ((i * 7 + j * 3) % 4)), Vector3(x, p.y + 0.01, z)))
	for i in int(w / 2.0):
		for sz in [-1.0, 1.0]:
			kerb.append(Transform3D(Basis(), Vector3(p.x - w / 2.0 + 1.0 + i * 2.0, p.y, p.z + sz * dd / 2.0)))
	for j in int(dd / 2.0):
		for sx in [-1.0, 1.0]:
			kerb.append(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(p.x + sx * w / 2.0, p.y, p.z - dd / 2.0 + 1.0 + j * 2.0)))
	_yard_dress("gach_vuon", tiles, 110.0, false)
	_yard_dress("vien_da", kerb, 90.0, false)

	var fp := Vector3(p.x - 7.0, p.y, p.z + dd / 2.0 - 4.5)
	_model("cot_co", fp + Vector3(0, 0.45, 0), 0.0, [[Vector3(1.6, 9.5, 1.6), Vector3.ZERO]])
	for sx_ in [-1.0, 1.0]:
		_model("vien_da", fp + Vector3(0, 0.0, sx_ * 0.65), 0.0, [])
		_model("vien_da", fp + Vector3(sx_ * 0.65, 0.0, 0), 90.0, [])
	var plinth := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(1.3, 0.45, 1.3)
	plinth.mesh = pb
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color("a39d90")
	pmat.roughness = 1.0
	plinth.material_override = pmat
	plinth.position = fp + Vector3(0, 0.225, 0)
	add_child(plinth)
	_flag(fp + Vector3(0, 9.4, 0), 1.8)
	var da := HomeKit.place_plant(self, "cay/cay_da", _ground(p.x + w / 2.0 - 2.0, p.z + dd / 2.0 - 1.0), 110.0)
	_occluders.append([da, AABB(), 0.0, false, [], AABB(Vector3(p.x + w / 2.0 - 10.6, p.y + 4.3, p.z + dd / 2.0 - 9.6),
		Vector3(17.2, 7.0, 17.2))])
	var tb := CylinderShape3D.new()
	tb.radius = 1.3
	tb.height = 4.0
	Props.solid(self, tb, _ground(p.x + w / 2.0 - 2.0, p.z + dd / 2.0 - 1.0) + Vector3(0, 2.0, 0))
	_no_grass_rects.append(Rect2(p.x - w / 2.0 - 0.6, p.z - dd / 2.0 - 0.6, w + 1.2, dd + 1.2))

	var walls := []
	for k: Array in layout["dress"].get("ke", []):
		var a := deg_to_rad(float(k[2]))
		var f := Vector3(sin(a), 0, cos(a))
		var base := Vector3(k[0], 0, k[1])
		var foot := 1e9
		for dd_: float in [0.3, 1.0, 2.0, 3.0]:
			var q: Vector3 = base + f * dd_
			foot = minf(foot, height_at(q.x, q.z))
		foot -= 0.4
		var b2 := base - f * 1.3
		var top := maxf(height_at(b2.x, b2.z) + 0.15, foot + 1.0)
		var n := maxi(1, int(top - foot))
		for i in n:
			var hgt := 1.0 if i < n - 1 else (top - foot) - (n - 1)
			walls.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3(1.0, hgt, 1.0)), Vector3(k[0], foot + i, k[1])))
	_yard_dress("ke_da", walls, 140.0)
	for b: Array in layout["dress"].get("bac", []):
		var top := Vector3(b[0], 0, b[1])
		var y0 := height_at(top.x, top.z + 3.0)
		_model("bac_da", Vector3(top.x, y0, top.z), float(b[2]), [])
		var rise: float = b[3]
		var ramp := BoxShape3D.new()
		ramp.size = Vector3(3.4, 0.3, sqrt(4.8 * 4.8 + rise * rise))
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = ramp
		sb.add_child(cs)
		sb.transform = Transform3D(Basis(Vector3.RIGHT, atan2(rise, 4.8)), Vector3(top.x, y0 + rise / 2.0 - 0.1, top.z + 2.4))
		add_child(sb)

func _flag(top: Vector3, size: float) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	pm.subdivide_width = 14
	pm.subdivide_depth = 6
	pm.orientation = PlaneMesh.FACE_Z
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/co_hoi.gdshader")
	m.set_shader_parameter("tex", load("res://props/hometown/co_ngu_sac.png"))
	m.set_shader_parameter("width", size)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var wind := Vector3(0.94, 0.0, 0.33).normalized()

	var fly := Vector3(wind.x, 0, wind.z).rotated(Vector3.UP, deg_to_rad(-35.0))

	mi.transform = Transform3D(Basis(fly, Vector3.UP, fly.cross(Vector3.UP)), top + fly * (size / 2.0 + 0.06) - Vector3(0, size / 2.0, 0))
	add_child(mi)

func _pad_low(k: Array) -> float:
	var a := deg_to_rad(float(k[2]))
	return height_at(float(k[0]) + sin(a) * 0.9, float(k[1]) + cos(a) * 0.9)

func _san_bong(pl: Dictionary, p: Vector3) -> void:
	var w: float = pl["w"]
	var dd: float = pl["d"]
	if pl.has("yard"):
		p = _ground(pl["yard"][0], pl["yard"][1])
		w = pl["yard"][2]
		dd = pl["yard"][3]
	var tiles := []
	var lines := []
	for i in int(w / 2.0):
		for j in int(dd / 2.0):
			tiles.append(Transform3D(Basis(Vector3.UP, PI / 2.0 * ((i * 5 + j) % 4)), Vector3(p.x - w / 2.0 + 1.0 + i * 2.0, p.y + 0.01, p.z - dd / 2.0 + 1.0 + j * 2.0)))
	var lw := w - 4.0
	var ld := dd - 4.0
	for i in int(lw / 2.0):
		for sz in [-1.0, 1.0]:
			lines.append(Transform3D(Basis(), Vector3(p.x - lw / 2.0 + 1.0 + i * 2.0, p.y + 0.01, p.z + sz * ld / 2.0)))
	for j in int(ld / 2.0):
		for sx in [-1.0, 0.0, 1.0]:
			lines.append(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(p.x + sx * lw / 2.0, p.y + 0.01, p.z - ld / 2.0 + 1.0 + j * 2.0)))
	_yard_dress("xi_mang", tiles, 110.0, false)
	_yard_dress("vach_san", lines, 70.0, false)
	for sx in [-1.0, 1.0]:
		_model("khung_thanh", Vector3(p.x + sx * lw / 2.0, p.y + 0.05, p.z), 90.0 * sx, [])
	_no_grass_rects.append(Rect2(p.x - w / 2.0 - 0.6, p.z - dd / 2.0 - 0.6, w + 1.2, dd + 1.2))

func _shore() -> void:
	var sd: Dictionary = layout["dress"].get("shore", {})
	if sd.is_empty():
		return
	var kit := {}
	var stones := {}
	for b: Array in sd["bo"]:
		var h := height_at(b[0], b[1])
		var bas := Basis(Vector3.UP, deg_to_rad(float(b[3]))).scaled(Vector3.ONE * float(b[4]))
		if b[2] in ["da_bo_a", "da_bo_b"]:

			var sr := RandomNumberGenerator.new()
			sr.seed = hash(Vector2i(roundi(float(b[0]) * 10.0), roundi(float(b[1]) * 10.0)))
			var sk := float(b[4])
			var tip := Basis(Vector3(sr.randf_range(-1, 1), 0, sr.randf_range(-1, 1)).normalized(), deg_to_rad(sr.randf_range(0.0, 9.0)))
			var sb_ := tip * Basis(Vector3.UP, deg_to_rad(float(b[3]))) * Basis.from_scale(Vector3(
				sk * sr.randf_range(0.8, 1.35), sk * sr.randf_range(0.6, 1.25), sk * sr.randf_range(0.75, 1.3)))
			_add_xf(stones, String(b[2]), Transform3D(sb_, Vector3(b[0], maxf(h, -0.3) - sr.randf_range(0.03, 0.2), b[1])))
		else:
			_add_xf(kit, String(b[2]), Transform3D(bas, Vector3(b[0], maxf(h, -0.4), b[1])))
	for kind: String in kit:
		_kit_dress(kind, kit[kind])
	_temple_foot()
	for nm: String in stones:
		_yard_dress(nm, stones[nm], 50.0, false)
	for b: Array in sd["ben"]:
		var y := maxf(height_at(b[0], b[1]), 0.45) if b[3] == "ben_da" else height_at(b[0], b[1])
		var n := _model(String(b[3]), Vector3(b[0], y, b[1]), float(b[2]), [])
		if n and b[3] == "cau_ben":
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.6, 0.2, 6.0)
			var sb := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			cs.shape = bs
			sb.add_child(cs)
			sb.position = Vector3(0, 0.22, -3.2)
			n.add_child(sb)
	for t: Array in sd["thuyen"]:
		var bp := Vector2(t[0], t[1])
		if height_at(bp.x, bp.y) > -0.2:
			var best := bp
			var lo := height_at(bp.x, bp.y)
			for rr in [1.5, 3.0, 4.5, 6.0, 8.0]:
				for k in 16:
					var q: Vector2 = bp + Vector2.from_angle(TAU * k / 16.0) * float(rr)
					if height_at(q.x, q.y) < lo:
						lo = height_at(q.x, q.y)
						best = q
				if lo < -0.35:
					break
			bp = best
		var bt := _model("thuyen_nan", Vector3(bp.x, -0.05, bp.y), float(t[2]), [])
		if bt:
			_bob.append([bt, bt.position.y, bt.rotation, float(t[0]) * 0.13 + float(t[1]) * 0.07])

var _bob: Array = []

func _bob_step() -> void:
	for b: Array in _bob:
		var n: Node3D = b[0]
		if not is_instance_valid(n):
			continue
		var ph: float = b[3]
		n.position.y = float(b[1]) + sin(t * 1.15 + ph) * 0.035 + sin(t * 0.43 + ph * 2.0) * 0.02
		var r0: Vector3 = b[2]
		n.rotation = Vector3(r0.x + sin(t * 0.9 + ph * 1.7) * 0.02, r0.y + sin(t * 0.17 + ph) * 0.03,
			r0.z + sin(t * 1.3 + ph * 0.6) * 0.035)

func _xom_dinh() -> void:
	if not FileAccess.file_exists(DIR + "xom_dinh.json"):
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "xom_dinh.json"))
	var c: Array = d["centre"]
	for nm: String in d["meshes"]:
		var spec: Dictionary = d["meshes"][nm]
		var n := HomeKit.place(self, nm, Vector3(c[0], c[1], c[2]))
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			mi.visibility_range_end = float(spec["end"])
			if not spec["shadow"]:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for l: Array in d["lamps"]:
		var ln := Node3D.new()
		add_child(ln)
		ln.position = Vector3(l[0], l[1], l[2])
		ln.rotation.y = deg_to_rad(l[3])
		HomeKit._add_pools(ln, HomeKit.LAMPS["cot_dien_den"])
	for b: Array in d["solid"]:
		var bs := BoxShape3D.new()
		bs.size = Vector3(b[4], b[5], b[6])
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = bs
		sb.add_child(cs)
		var roll := deg_to_rad(float(b[7])) if b.size() > 7 else 0.0
		sb.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(b[3])) * Basis(Vector3.BACK, roll), Vector3(b[0], b[1], b[2]))
		add_child(sb)
	for g: Array in d["nograss"]:
		_no_grass.append(Vector3(g[0], g[1], g[2]))
	for nm: String in d.get("yard", {}):
		var xfs := []
		for t: Array in d["yard"][nm]:
			xfs.append(Transform3D(Basis(Vector3.UP, deg_to_rad(t[3])).scaled(Vector3.ONE * float(t[4])), Vector3(t[0], t[1], t[2])))
		_yard_dress(nm, xfs, float(YARD_END.get(nm, 60.0)), nm in ["hoa_giay", "cay_chuoi", "cay_cau", "tung"])
	for nm: String in d.get("kit", {}):
		var kx := []
		for t: Array in d["kit"][nm]:
			kx.append(Transform3D(Basis(Vector3.UP, deg_to_rad(t[3])).scaled(Vector3.ONE * float(t[4])), Vector3(t[0], t[1], t[2])))
		_kit_dress(nm, kx)

const YARD_END := {"rao_tre": 75.0, "tuong_rao": 80.0, "cot_cong": 80.0, "cong_tre": 75.0, "da_buoc": 40.0,
	"chau_cay": 55.0, "luong_cai": 60.0, "luong_hanh": 60.0, "luong_xalach": 60.0, "be_nuoc": 60.0, "chuong_ga": 70.0,
	"day_phoi": 60.0, "hoa_giay": 70.0}

func _house_yards() -> void:
	var path := DIR + "house_yards.json"
	if OS.get_environment("MC_GOCSAN_OLD") != "" and FileAccess.file_exists(DIR + "house_yards_old.json"):
		path = DIR + "house_yards_old.json"
	if not FileAccess.file_exists(path):
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var by := {}
	for it: Array in d["items"]:
		if it[0] in ["cay_cau", "cay_chuoi", "cay_buoi"] and _vl_cut(Vector3(it[1], 0, it[2])): continue
		var pos := _ground(it[1], it[2])
		if String(it[0]).begins_with("goc_"):
			for dv: Vector2 in [Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(-0.8, 0.8), Vector2(0.8, 0.8)]:
				pos.y = minf(pos.y, height_at(it[1] + dv.x, it[2] + dv.y))
		var bas := Basis(Vector3.UP, deg_to_rad(float(it[3]))) * Basis.from_scale(Vector3(float(it[4]), 1.0, 1.0) if it[0] in ["rao_tre", "tuong_rao"] else Vector3.ONE * float(it[4]))
		if it[0] == "xe_dream":
			if ResourceLoader.exists("res://props/furniture/xe_dream.glb"):
				Furniture.place(self, "xe_dream", pos + Vector3(0, 0.05, 0), float(it[3]), true)
			continue
		_add_xf(by, String(it[0]), Transform3D(bas, pos))
		if String(it[0]).begins_with("ngo_gach"):
			_no_grass.append(Vector3(it[1], it[2], 1.45))
	for nm: String in by:
		if nm.begins_with("hang_rao"):
			_kit_dress(nm, by[nm])
			continue
		if nm.begins_with("goc_"):
			_furn_dress(nm, by[nm], GOC_END)
			continue
		_yard_dress(nm, by[nm], float(YARD_END.get(nm, 0.0)), nm in ["cay_chuoi", "cay_buoi", "cay_cau", "hoa_giay"])
	for b: Array in d["solid"]:

		var bas := Basis(Vector3.UP, deg_to_rad(float(b[2])))
		var along := bas.x
		var c := Vector3(b[0], 0, b[1])
		var ln := float(b[3])
		var e0 := c - along * ln / 2.0
		var e1 := c + along * ln / 2.0
		var n := 1 if absf(height_at(e0.x, e0.z) - height_at(e1.x, e1.z)) < 0.25 else maxi(1, ceili(ln / 2.0))
		for i in n:
			var q := e0 + along * ln * (i + 0.5) / n
			var bs := BoxShape3D.new()
			bs.size = Vector3(ln / n + 0.05, 1.0, 0.3)
			var sb := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			cs.shape = bs
			sb.add_child(cs)
			sb.transform = Transform3D(bas, _ground(q.x, q.z) + Vector3(0, 0.5, 0))
			add_child(sb)

const GOC_END := 38.0

func _furn_dress(name_: String, xfs: Array, end_: float) -> void:
	if not ResourceLoader.exists(Furniture.DIR + name_ + ".glb"):
		return
	var tmp: Node3D = load(Furniture.DIR + name_ + ".glb").instantiate()
	var parts := []
	for mi: MeshInstance3D in tmp.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh.duplicate()
		for s_ in mesh.get_surface_count():
			mesh.surface_set_material(s_, Furniture.material(name_))
		parts.append(mesh)
	tmp.free()
	var cells := {}
	for xf: Transform3D in xfs:
		var key := Vector2i(floori(xf.origin.x / 64.0), floori(xf.origin.z / 64.0))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(xf)
	for key: Vector2i in cells:
		var c := Vector3((key.x + 0.5) * 64.0, 0, (key.y + 0.5) * 64.0)
		for mesh: Mesh in parts:
			var mi := _mmi(mesh, cells[key], c)
			mi.visibility_range_end = end_
			mi.name = name_
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _yard_dress(name_: String, xfs: Array, end_ := 0.0, shadow := true) -> void:
	if not ResourceLoader.exists(HomeKit.DIR + name_ + ".glb"):
		return
	var tmp := HomeKit.place(self, name_, Vector3.ZERO)
	var parts := []
	for mi: MeshInstance3D in tmp.find_children("*", "MeshInstance3D", true, false):
		if mi.get_parent().name == &"Far":
			continue
		var mesh: Mesh = mi.mesh.duplicate()
		for s_ in mesh.get_surface_count():
			if mi.get_surface_override_material(s_):
				mesh.surface_set_material(s_, mi.get_surface_override_material(s_))
		parts.append(mesh)
	tmp.free()
	var cells := {}
	for xf: Transform3D in xfs:
		var key := Vector2i(floori(xf.origin.x / 64.0), floori(xf.origin.z / 64.0))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(xf)
	for key: Vector2i in cells:
		var c := Vector3((key.x + 0.5) * 64.0, 0, (key.y + 0.5) * 64.0)
		for mesh: Mesh in parts:
			var mi := _mmi(mesh, cells[key], c)
			mi.visibility_range_end = end_ if end_ > 0.0 else (120.0 if name_ == "cay_cau" else 80.0)
			mi.name = name_
			if not shadow:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _add_inst(inst: Dictionary, kind: String, xf: Transform3D, c: Color) -> void:
	if not inst.has(kind):
		inst[kind] = []
	inst[kind].append([xf, c])

func _instanced(mesh: Mesh, items: Array, end: float, shadow: bool) -> void:
	var chunks := {}
	for it: Array in items:
		var o: Vector3 = (it[0] as Transform3D).origin
		var key := Vector2i(floori(o.x / DRESS_CHUNK), floori(o.z / DRESS_CHUNK))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(it)
	var mat := _vc_mat()
	for key: Vector2i in chunks:
		var list: Array = chunks[key]
		var c := Vector3((key.x + 0.5) * DRESS_CHUNK, 0, (key.y + 0.5) * DRESS_CHUNK)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var xf: Transform3D = list[i][0]
			mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - c))
			mm.set_instance_color(i, list[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.position = c
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = end
		add_child(mi)

var _vc: ShaderMaterial

func _vc_mat() -> ShaderMaterial:
	if _vc == null:
		_vc = ShaderMaterial.new()
		_vc.shader = preload("res://shaders/karst.gdshader")
	return _vc

func _dress_mesh(kind: String) -> ArrayMesh:
	var Y := func(y: float) -> Transform3D: return Transform3D(Basis(), Vector3(0, y, 0))
	var parts := []
	match kind:
		"tree":
			parts = [[Props.cyl(0.16, 0.12, 1.3), Y.call(0.65), Color("a9744f")]]
			for q in [[Vector3(0, 1.75, 0), 0.85], [Vector3(0.45, 1.5, 0.1), 0.6], [Vector3(-0.42, 1.55, -0.1), 0.62],
					[Vector3(0.05, 2.25, 0.05), 0.6]]:
				parts.append([Props.sphere(q[1]), Transform3D(Basis(), q[0]), Color.WHITE])
		"cau":
			parts = [[Props.cyl(0.12, 0.09, 7.0), Y.call(3.5), Color("a89a80")],
				[Props.sphere(1.0), Transform3D(Basis().scaled(Vector3(1.4, 0.6, 1.4)), Vector3(0, 7.2, 0)), Color("6fae4a")]]
		"chuoi":
			parts = [[Props.cyl(0.18, 0.14, 2.0), Y.call(1.0), Color("8fae5a")]]
			for k in 5:
				var a := TAU * k / 5.0
				parts.append([Props.box(Vector3(0.5, 0.05, 1.8)),
					Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.5), Vector3(sin(a) * 0.8, 2.2, cos(a) * 0.8)), Color("7cc05a")])
		"bamboo":
			for k in 5:
				var a := TAU * k / 5.0
				var hgt := 7.0 + 0.6 * k
				parts.append([Props.cyl(0.1, 0.07, hgt),
					Transform3D(Basis(Vector3(cos(a), 0, -sin(a)), 0.08), Vector3(sin(a) * 0.5, hgt / 2.0, cos(a) * 0.5)), Color("86b55a")])
			parts.append([Props.sphere(1.6), Transform3D(Basis().scaled(Vector3(1.2, 1.6, 1.2)), Vector3(0, 7.5, 0)), Color("8cc060")])
		"bush":
			parts = [[Props.sphere(0.6), Transform3D(Basis().scaled(Vector3(1.2, 0.8, 1.0)), Vector3(0, 0.35, 0)), Color("5aa64c")]]
		"rock":
			parts = [[Props.sphere(0.5), Transform3D(Basis().scaled(Vector3(1.2, 0.7, 1.0)), Vector3(0, 0.2, 0)), Color("a9a59c")]]
		"pole":
			parts = [[Props.cyl(0.1, 0.08, 6.5), Y.call(3.25), Color("b8b2a8")]]
	return _compound(parts)

func _compound(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for pt in parts:
		var m: PrimitiveMesh = pt[0]
		if m is SphereMesh:
			(m as SphereMesh).radial_segments = 8
			(m as SphereMesh).rings = 4
		elif m is CylinderMesh:
			(m as CylinderMesh).radial_segments = 6
			(m as CylinderMesh).rings = 1
		var a := m.get_mesh_arrays()
		var xf: Transform3D = pt[1]
		var nb := xf.basis.inverse().transposed()
		var base := verts.size()
		var col: Color = (pt[2] as Color).srgb_to_linear()
		for v: Vector3 in a[Mesh.ARRAY_VERTEX]:
			verts.append(xf * v)
			cols.append(col)
		for nv: Vector3 in a[Mesh.ARRAY_NORMAL]:
			norms.append((nb * nv).normalized())
		for i: int in a[Mesh.ARRAY_INDEX]:
			idx.append(base + i)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out

func _multimesh(mesh: Mesh, xforms: Array, colors := [], end := 0.0) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if end > 0.0:
		var c := Vector3.ZERO
		for x: Transform3D in xforms:
			c += x.origin
		c /= xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, Transform3D(xforms[i].basis, xforms[i].origin - c))
		mi.position = c
		mi.visibility_range_end = end
	add_child(mi)

func _tuft_mesh(h: float, w: float, c: Color) -> ArrayMesh:
	"""A tuft of seven thin blades fanning out from one root (not three wide triangles: those read as paper
	cones), heights and lean varied, two-sided."""
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 7:
		var a := TAU * k / 7.0 + 0.4 * sin(k * 2.3)
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-out.z, 0, out.x) * w * 0.22
		var root := out * w * 0.25
		var hk := h * (0.65 + 0.35 * fmod(k * 0.618, 1.0))
		for v in [root - side, root + side, root + out * w * 0.9 + Vector3(0, hk, 0)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var m := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/grass_tuft.gdshader")
	mat.set_shader_parameter("height", h)
	m.surface_set_material(0, mat)
	return m

const TOWN_ROAD := [Vector2(-776, -9), Vector2(-757, -5.0), Vector2(-738, -1.2), Vector2(-719, 0.6), Vector2(-700, 0),
	Vector2(-684, 1.6), Vector2(-668, 1.8), Vector2(-651, -1.2), Vector2(-632, -4.5)]
const VIA_HE := ["via_he_a", "via_he_b", "via_he_c", "via_he_d", "via_he_e"]
var _town_sets := {}
var _town_body: StaticBody3D

func _town_solid(at: Vector3, size: Vector3, basis := Basis()) -> void:
	if _town_body == null:
		_town_body = StaticBody3D.new()
		_town_body.name = "TownSolids"
		add_child(_town_body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = Transform3D(basis, at + Vector3(0, size.y / 2.0, 0))
	_town_body.add_child(cs)

func _town_road_z(x: float) -> float:
	return (_town_road_at(x)[0] as Vector2).y

func _town_road_at(x: float) -> Array:
	for k in TOWN_ROAD.size() - 1:
		var a: Vector2 = TOWN_ROAD[k]
		var b: Vector2 = TOWN_ROAD[k + 1]
		if x <= b.x or k == TOWN_ROAD.size() - 2:
			var t := clampf((x - a.x) / (b.x - a.x), 0.0, 1.0)
			return [a.lerp(b, t), (b - a).normalized()]
	return [TOWN_ROAD[0], Vector2.RIGHT]

func _instanced_model(name: String, xforms: Array, end: float) -> void:
	if xforms.is_empty() or not ResourceLoader.exists(HomeKit.DIR + name + ".glb"):
		return
	var g: Node3D = load(HomeKit.DIR + name + ".glb").instantiate()
	var mesh: Mesh = null
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		mesh = mi.mesh
		break
	g.free()
	var mat := HomeKit.material("tiles", load(HomeKit.DIR + name + "_ao.png"))
	var patches := {}
	for xf: Transform3D in xforms:
		var key := Vector2i(floori(xf.origin.x / 32.0), floori(xf.origin.z / 32.0))
		if not patches.has(key):
			patches[key] = []
		patches[key].append(xf)
	for key: Vector2i in patches:
		var list: Array = patches[key]
		var c := Vector3((key.x + 0.5) * 32.0, 0, (key.y + 0.5) * 32.0)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var xf: Transform3D = list[i]
			mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - c))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.position = c
		mmi.visibility_range_end = end
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

func _town(gx: float, home: Node3D) -> void:
	var sq := _ground(gx, -21.0) + Vector3(0, 0.1, 0)
	_model("san_ga_pho", sq, 0.0, [[Vector3(4.3, 0.55, 4.3), Vector3(-5.07, 0, 1.56)]])
	var old_tree := HomeKit.place_plant(home, "cay/cay_gao", _ground(gx - 5.07, -21.0 + 1.56) + Vector3(0, 0.55, 0), 35.0)
	old_tree.scale = Vector3.ONE * 1.25
	var tb := _ground(gx - 5.07, -21.0 + 1.56)
	_occluders.append([old_tree, AABB(), 0.0, false, [], AABB(tb + Vector3(-5.5, 4.2, -5.5), Vector3(11.0, 10.0, 11.0))])
	_model("gieng", _ground(gx + 6.5, -27.5), 20.0, [[Vector3(1.6, 0.8, 1.6), Vector3.ZERO]])
	if ResourceLoader.exists("res://props/furniture/xe_dream.glb"):
		for b in [[-9.0, -3.4, 68.0], [-7.6, -2.9, 101.0], [-6.1, -3.6, 84.0],
				[9.4, -31.0, 8.0], [8.8, -29.3, -14.0], [9.6, -26.9, 21.0]]:
			var bike := Furniture.place(home, "xe_dream", _ground(gx + b[0], b[1]) + Vector3(0, 0.15, 0), b[2], false)
			for gi: GeometryInstance3D in bike.find_children("*", "GeometryInstance3D", true, false):
				gi.visibility_range_end = 40.0
	HomeKit.place_plant(home, "cay/cay_phuong", _ground(gx - 5.85, -35.0) + Vector3(0, 0.5, 0), -30.0)
	for l in [[-10.6, -29.5, 70.0], [9.9, -16.0, -95.0], [2.6, -6.5, 160.0]]:
		HomeKit.place(home, "cot_den", _ground(gx + l[0], l[1]) + Vector3(0, 0.1, 0), l[2])
		_town_solid(_ground(gx + l[0], l[1]), Vector3(0.35, 2.4, 0.35))

	var srng := RandomNumberGenerator.new()
	srng.seed = 17
	var clumps := []
	for k in 230:
		var lx := srng.randf_range(-10.6, 10.6)
		var lz := srng.randf_range(-18.8, 18.8)
		var edge := maxf(absf(lx) / 10.6, absf(lz) / 18.8)
		var near_tree := Vector2(lx + 5.07, lz - 1.56).length() < 4.5
		if srng.randf() > edge * edge * 0.9 + (0.35 if near_tree else 0.03) or absf(lx - 0.9) < 1.2:
			continue
		var s := srng.randf_range(0.6, 1.1)
		clumps.append(Transform3D(Basis(Vector3.UP, srng.randf() * TAU).scaled(Vector3(s, s, s)),
			_ground(gx + lx, -21.0 + lz) + Vector3(0, 0.15, 0)))
	if ResourceLoader.exists(HomeKit.DIR + "cay/co_bui.glb"):
		var cb := _first_mesh(HomeKit.DIR + "cay/co_bui.glb")
		_multimesh_mat(cb, clumps, HomeKit._plant_material("cay/la_bui"), 60.0)

	var trng := RandomNumberGenerator.new()
	trng.seed = 41
	var lots: Array = []
	for h: Array in layout["dress"]["houses"]:
		if h.size() > 4 and String(h[4]) == "thi_tran":
			lots.append(h)
	for a: Array in lots:
		for b: Array in lots:
			var pa := Vector2(a[0], a[1])
			var pb := Vector2(b[0], b[1])
			var d := pa.distance_to(pb)
			if pa.x < pb.x and d > 4.6 and d < 7.5 and signf(a[1] - _town_road_z(a[0])) == signf(b[1] - _town_road_z(b[0])):
				var mid := (pa + pb) / 2.0
				var free := true
				for c: Array in lots:
					if Vector2(c[0], c[1]).distance_to(mid) < 1.6:
						free = false
				if free:
					var back := mid + (mid - Vector2(mid.x, _town_road_z(mid.x))).normalized() * 1.2
					var kind: String = ["cay_cau", "cay_chuoi", "cay_cau"][trng.randi() % 3]
					HomeKit.place(home, kind, _ground(back.x, back.y), trng.randf() * 360.0)
					_town_solid(_ground(back.x, back.y), Vector3(0.4, 2.0, 0.4))

	var row: Array = []
	for h: Array in layout["dress"]["houses"]:
		if h.size() > 4 and String(h[4]) == "thi_tran":
			row.append(Vector2(h[0], h[1]))
	for k in [1, 2]:
		var v: Vector2 = TOWN_ROAD[k]
		var best := Vector2.INF
		var best_w := 6.4
		for a: Vector2 in row:
			for b: Vector2 in row:
				var w := a.distance_to(b)
				var mid := (a + b) / 2.0
				if w <= best_w or w > 12.0 or mid.distance_to(v) > 14.0:
					continue
				var clear := true
				for c: Vector2 in row:
					if c != a and c != b and c.distance_to(mid) < 3.6:
						clear = false
						break
				if clear:
					best = mid
					best_w = w
		if best != Vector2.INF:
			var rd: Array = _town_road_at(best.x)
			var face: Vector2 = ((rd[0] as Vector2) - best).normalized()
			var yaw := rad_to_deg(atan2(face.x, face.y))
			var stall := _model("quan_nuoc", _ground(best.x, best.y), yaw, [[Vector3(3.4, 2.0, 2.4), Vector3.ZERO]])
			if stall:
				_occluders.append([stall, AABB(), 0.0, false, []])

	var big := HomeKit.place_plant(home, "cay/cay_phuong", _ground(-777.0, -1.5), 20.0)
	big.scale = Vector3.ONE * 1.35
	HomeKit.place_plant(home, "cay/cay_gao", _ground(-783.0, -10.0), 70.0)
	_town_solid(_ground(-777.0, -1.5), Vector3(1.1, 2.5, 1.1))
	_town_solid(_ground(-783.0, -10.0), Vector3(1.0, 2.5, 1.0))
	_model("cho", _ground(-618.0, 5.5), -100.0, [[Vector3(7.5, 2.4, 4.6), Vector3.ZERO]])

const BACKYARD := ["luong_cai", "be_nuoc", "day_phoi", "cay_chuoi", "luong_hanh", "gian_muop", "luong_xalach"]

func _town_life(home: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var i := 0
	for h: Array in layout["dress"]["houses"]:
		if h.size() < 5 or String(h[4]) != "thi_tran":
			continue
		i += 1
		if rng.randf() > 0.7:
			continue
		var name: String = BACKYARD[(i * 5 + rng.randi() % 3) % BACKYARD.size()]
		var yaw := deg_to_rad(float(h[2]))
		var back := Vector2(sin(yaw), cos(yaw)) * -(4.4 + rng.randf_range(0.0, 1.6))
		var side := Vector2(cos(yaw), -sin(yaw)) * rng.randf_range(-0.6, 0.6)
		var at := Vector2(h[0], h[1]) + back + side
		if not ResourceLoader.exists(HomeKit.DIR + name + ".glb"):
			continue
		var n := HomeKit.place(home, name, _ground(at.x, at.y), float(h[2]) + 180.0 + rng.randf_range(-15.0, 15.0))
		for gi: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
			gi.visibility_range_end = 50.0

	var per := {}
	for pl: Dictionary in layout["places"]:
		if pl["kind"] != "crop_field":
			continue
		var crops: Array = pl["crops"]
		var a := deg_to_rad(float(pl.get("yaw", 0.0)))
		var cx: float = pl["x"]
		var cz: float = pl["z"]
		var hw: float = pl["w"] / 2.0 - 1.0
		var hd: float = pl["d"] / 2.0 - 1.0
		var rows := int(hd * 2.0 / 1.3) + 1
		for r in rows:
			var crop: String = crops[(r + int(cx)) % crops.size()]
			var lz := -hd + r * 1.3
			var lx := -hw + rng.randf_range(0.0, 0.6)
			while lx < hw + 1.1 * sin(lz * 0.45 + cx):
				var bend := 0.35 * sin(lx * 0.18 + r)
				if rng.randf() > 0.12:
					var wx := cx + lx * cos(a) + (lz + bend) * sin(a)
					var wz := cz - lx * sin(a) + (lz + bend) * cos(a)
					if not per.has(crop):
						per[crop] = []
					per[crop].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU),
						_ground(wx + rng.randf_range(-0.1, 0.1), wz + rng.randf_range(-0.1, 0.1))))
				lx += rng.randf_range(0.75, 1.05)
	var cm := ShaderMaterial.new()
	cm.shader = preload("res://shaders/crop_foliage.gdshader")
	cm.set_shader_parameter("atlas", load("res://props/farm/crop_atlas.png"))
	for crop: String in per:
		var path := "res://props/farm/%s.glb" % crop
		if ResourceLoader.exists(path):
			_multimesh_mat(_first_mesh(path), per[crop], cm, 80.0)

	for g in [["trau", -770.0, -25.0, 30.0], ["trau", -766.0, -31.0, 200.0], ["bo_vang", -648.0, -38.0, 120.0]]:
		if ResourceLoader.exists("res://props/farm/animals/%s.glb" % g[0]):
			var a := FarmAnimal.spawn(home, g[0], _ground(g[1], g[2]), deg_to_rad(g[3]))
			a.play("Graze")

func _station_edges(home: Node3D) -> void:
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.36, 0.56, 0.5, 0.82)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.15
	var lotus := []
	var reeds := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for tp: Dictionary in layout.get("town_ponds", []):
		var c := Vector3(tp["x"], tp["y"], tp["z"])
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.02
		cm.radial_segments = 28
		disc.mesh = cm
		disc.scale = Vector3(tp["rx"], 1.0, tp["rz"])
		disc.position = c
		disc.material_override = water
		disc.visibility_range_end = 200.0
		home.add_child(disc)
		for k in 60:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * 0.85
			var p := Vector3(c.x + cos(a) * r * tp["rx"], c.y, c.z + sin(a) * r * tp["rz"])
			if p.x > c.x + tp["rx"] * 0.25 and absf(p.z - c.z) < 2.0:
				continue
			var s := rng.randf_range(0.8, 1.15)
			lotus.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
		for k in 26:
			var a := rng.randf() * TAU
			var p := Vector3(c.x + cos(a) * tp["rx"] * 1.08, 0.0, c.z + sin(a) * tp["rz"] * 1.08)
			if cos(a) > 0.5 and rng.randf() < 0.7:
				continue
			p.y = height_at(p.x, p.z)
			reeds.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
		var jet := Vector3(c.x + tp["rx"] - 0.6, height_at(c.x + tp["rx"] + 0.6, c.z) - 0.05, c.z)
		_model("cau_van", jet, -90.0, [[Vector3(0.95, 0.4, 2.4), Vector3(0, 0, 1.2)]])
	if not lotus.is_empty() and ResourceLoader.exists("res://props/farm/sen_3.glb"):
		var lm := ShaderMaterial.new()
		lm.shader = preload("res://shaders/crop_foliage.gdshader")
		lm.set_shader_parameter("atlas", load("res://props/farm/dong_atlas.png"))
		_multimesh_mat(_first_mesh("res://props/farm/sen_3.glb"), lotus, lm, 90.0)
	if not reeds.is_empty() and ResourceLoader.exists(HomeKit.DIR + "cay/co_lau.glb"):
		_multimesh_mat(_first_mesh(HomeKit.DIR + "cay/co_lau.glb"), reeds, HomeKit._plant_material("cay/la_bui"), 70.0)

	_model("quan_nuoc", _ground(-710.6, -36.5), -60.0, [[Vector3(3.4, 2.0, 2.4), Vector3.ZERO]])

	_model("kho_ga", _ground(-740.0, -43.6), 0.0, [[Vector3(11.4, 3.4, 5.5), Vector3(0, 0, -0.45)],
		[Vector3(11.3, 0.78, 7.3), Vector3(0, 0, 0)]])
	for k in 4:
		HomeKit.place(home, "duong_ray", _ground(-758.0 + k * 4.0, -49.2) + Vector3(0, 0.02, 0), 90.0)
	_model("u_chan", _ground(-760.6, -49.2), 90.0, [[Vector3(2.4, 1.4, 1.6), Vector3(0, 0, -0.9)]])
	_model("toa_hang", _ground(-752.0, -49.2) + Vector3(0, 0.18, 0), 90.0, [[Vector3(6.6, 2.9, 2.3), Vector3.ZERO]])

	var trng := RandomNumberGenerator.new()
	trng.seed = 8
	var x := -684.0
	while x < -641.0:
		var z := -46.5 + trng.randf_range(-1.8, 2.5)
		var kind := "cay/bui_tre" if trng.randf() < 0.45 else "cay/cay_keo"
		var t := HomeKit.place_plant(home, kind, _ground(x, z), trng.randf() * 360.0)
		t.scale = Vector3.ONE * trng.randf_range(0.8, 1.1)
		_town_solid(_ground(x, z), Vector3(0.7, 2.0, 0.7))
		x += trng.randf_range(5.5, 9.5)
	for p in [[-676.0, -39.5], [-668.0, -41.0], [-659.0, -38.8], [-650.0, -40.6]]:
		HomeKit.place_plant(home, "cay/bui_dai_a" if int(p[0]) % 2 == 0 else "cay/bui_dai_b", _ground(p[0], p[1]), trng.randf() * 360.0)
	for p in [[-722.0, -45.0], [-727.0, -39.0], [-759.0, -40.0]]:
		HomeKit.place_plant(home, "cay/cay_keo" if p[0] > -740.0 else "cay/bui_tre", _ground(p[0], p[1]), trng.randf() * 360.0)
		_town_solid(_ground(p[0], p[1]), Vector3(0.7, 2.0, 0.7))

const TRACK_END := 110.0

func _rails() -> void:
	var line: Array = layout["rail"]
	var mesh: Mesh = null
	var g: Node3D = load(HomeKit.DIR + "duong_ray.glb").instantiate()
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		mesh = mi.mesh
		break
	var mat := HomeKit.material("tiles", load(HomeKit.DIR + "duong_ray_ao.png"))
	g.free()
	var runs := {}
	for i in line.size() - 1:
		var a := Vector2(line[i][0], line[i][1])
		var b := Vector2(line[i + 1][0], line[i + 1][1])
		var n := maxi(1, roundi(a.distance_to(b) / 4.0))
		for k in n:
			var p0 := a.lerp(b, float(k) / n)
			var p1 := a.lerp(b, float(k + 1) / n)
			var y0 := height_at(p0.x, p0.y) + 0.02
			var y1 := height_at(p1.x, p1.y) + 0.02
			var f := Vector3(p1.x - p0.x, y1 - y0, p1.y - p0.y)
			var z := f.normalized()
			var x := Vector3.UP.cross(z).normalized()
			var basis := Basis(x, z.cross(x), z * (f.length() / 4.0))
			var mid := Vector3((p0.x + p1.x) / 2, (y0 + y1) / 2, (p0.y + p1.y) / 2)
			var key := Vector2i(floori(mid.x / 64.0), floori(mid.z / 64.0))
			if not runs.has(key):
				runs[key] = []
			runs[key].append(Transform3D(basis, mid))
	for key: Vector2i in runs:
		var list: Array = runs[key]
		var c := Vector3((key.x + 0.5) * 64.0, 0, (key.y + 0.5) * 64.0)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var t: Transform3D = list[i]
			mm.set_instance_transform(i, Transform3D(t.basis, t.origin - c))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.position = c
		mmi.visibility_range_end = TRACK_END
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	var e: Array = line[line.size() - 1]
	var d: Array = line[line.size() - 2]
	var dir := Vector2(e[0] - d[0], e[1] - d[1]).normalized()
	var end := Vector2(e[0], e[1]) - dir * 0.8
	_model("u_chan", Vector3(end.x, height_at(end.x, end.y), end.y), rad_to_deg(atan2(-dir.x, -dir.y)),
		[[Vector3(2.4, 1.4, 1.6), Vector3(0, 0, -0.9)]])

const WILD_END := 70.0
const WILD := {"bui_dai_a": 0.35, "bui_dai_b": 0.3, "co_bui": 0.35}

func _wild_bushes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var per := {}
	var put := func(kind: String, x: float, z: float) -> void:
		var gx := int(round(x)) + HALF
		var gz := int(round(z)) + HALF
		if gx < 0 or gz < 0 or gx >= N or gz >= N or terrain.mats[gz * N + gx] != 0 or _under_model(x, z):
			return
		var key := Vector2i(floori(x / 64.0), floori(z / 64.0))
		if not per.has(kind):
			per[kind] = {}
		if not per[kind].has(key):
			per[kind][key] = []
		var s := rng.randf_range(0.8, 1.2)
		per[kind][key].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
			Vector3(x, height_at(x, z) - 0.02, z)))
	var pick := func() -> String:
		var r := rng.randf()
		for k: String in WILD:
			r -= float(WILD[k])
			if r <= 0.0:
				return k
		return "co_bui"
	var lines: Array = layout["roads"] + layout["dress"]["lanes"]
	for line: Array in lines:
		for i in line.size() - 1:
			var a := Vector2(line[i][0], line[i][1])
			var b := Vector2(line[i + 1][0], line[i + 1][1])
			var ln := a.distance_to(b)
			var u := (b - a) / maxf(ln, 0.01)
			var nrm := Vector2(-u.y, u.x)
			var t := rng.randf_range(0.0, 4.0)
			while t < ln:
				for side in [-1.0, 1.0]:
					if rng.randf() < 0.55:
						var p: Vector2 = a + u * t + nrm * side * rng.randf_range(2.6, 4.2)
						put.call(pick.call(), p.x, p.y)
						if rng.randf() < 0.6:
							var q: Vector2 = p + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
							put.call("co_bui", q.x, q.y)
				t += rng.randf_range(4.0, 7.0)

	for f: Dictionary in [layout["fields"]] + layout["paddies"]:
		var rect := [Vector2(f["x0"], f["z0"]), Vector2(f["x1"], f["z0"]), Vector2(f["x1"], f["z1"]), Vector2(f["x0"], f["z1"])]
		var c: Vector2 = (rect[0] + rect[2]) / 2.0
		for i in 4:
			var a: Vector2 = rect[i]
			var b: Vector2 = rect[(i + 1) % 4]
			var ln := a.distance_to(b)
			var t := rng.randf_range(0.0, 5.0)
			while t < ln:
				var p: Vector2 = a.lerp(b, t / ln)
				p += (p - c).normalized() * rng.randf_range(1.5, 3.0)
				if rng.randf() < 0.5:
					put.call("co_lau" if rng.randf() < 0.5 else "bui_dai_b", p.x, p.y)
				t += rng.randf_range(5.0, 9.0)
	for kind: String in per:
		var path := HomeKit.DIR + "cay/" + kind + ".glb"
		if not ResourceLoader.exists(path):
			continue
		var g: Node3D = load(path).instantiate()
		var mesh: Mesh = null
		var mat: Material = null
		for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
			mesh = mi.mesh
			var src := mesh.surface_get_material(0)
			mat = HomeKit._plant_material("cay/" + (src.resource_name if src else "la_bui"))
			break
		g.free()
		for key: Vector2i in per[kind]:
			var list: Array = per[kind][key]
			var cpos := Vector3((key.x + 0.5) * 64.0, 0, (key.y + 0.5) * 64.0)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = list.size()
			for i in list.size():
				var xf: Transform3D = list[i]
				mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - cpos))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = mat
			mmi.position = cpos
			mmi.visibility_range_end = WILD_END
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)

func _under_model(x: float, z: float) -> bool:
	for r in _no_grass_rects:
		if r.has_point(Vector2(x, z)):
			return true
	for c in _no_grass:
		if absf(x - c.x) < c.z and absf(z - c.y) < c.z and Vector2(x - c.x, z - c.y).length() < c.z:
			return true
	return false

func _grass() -> void:
	"""Grass tufts from the density map (data/hometown/grass.png), the way BotW grows its grass layer."""
	var g := Image.load_from_file(ProjectSettings.globalize_path(DIR + "grass.png")) if not TexCache.shipped() 		else (load(DIR + "grass.png") as Texture2D).get_image()
	var g_paint := g
	if _paint_dens.size() == N * N:
		g_paint = Image.create_from_data(N, N, false, Image.FORMAT_L8, _paint_dens)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var per_chunk := {}
	for z in range(-int(VPLAY), int(VPLAY)):
		for x in range(-int(VPLAY), int(VPLAY)):
			var dens := g_paint.get_pixel(x + HALF, z + HALF).r
			if dens <= 0.02 or rng.randf() > dens * 0.55:
				continue
			var px := x + rng.randf()
			var pz := z + rng.randf()
			if _under_model(px, pz):
				continue
			var key := Vector2i(floori(px / CHUNK), floori(pz / CHUNK))
			if not per_chunk.has(key):
				per_chunk[key] = [[], []]
			var s := rng.randf_range(0.7, 1.3)
			per_chunk[key][0].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
				Vector3(px, height_at(px, pz) - 0.03, pz)))
			per_chunk[key][1].append(Color(0.52, 0.80, 0.30).lerp(Color(0.38, 0.66, 0.24), rng.randf()))
	for z in range(-60, 60):
		for x in range(-790, -620):
			if rng.randf() > 0.2:
				continue
			var gx := x + HALF
			var gz := z + HALF
			if terrain.mats[gz * N + gx] != 0 or _under_model(x + 0.5, z + 0.5):
				continue
			var px := x + rng.randf()
			var pz := z + rng.randf()
			var key := Vector2i(floori(px / CHUNK), floori(pz / CHUNK))
			if not per_chunk.has(key):
				per_chunk[key] = [[], []]
			var s := rng.randf_range(0.7, 1.3)
			per_chunk[key][0].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
				Vector3(px, height_at(px, pz) - 0.03, pz)))
			per_chunk[key][1].append(Color(0.52, 0.80, 0.30).lerp(Color(0.38, 0.66, 0.24), rng.randf()))
	var tuft := _tuft_mesh(0.45, 0.22, Color.WHITE)
	_paint_mat(tuft.surface_get_material(0) as ShaderMaterial)
	for key in per_chunk:
		_multimesh(tuft, per_chunk[key][0], per_chunk[key][1], GRASS_END)
	var gl := g.duplicate() as Image
	gl.convert(Image.FORMAT_L8)
	_grass_dens = gl.get_data()
	if _paint_dens.size() == N * N:
		_grass_dens = _paint_dens
	_lush_setup()
	if _lush_mat:
		_paint_mat(_lush_mat)

const LUSH_CHUNK := 8
const LUSH_R := 29.0
const LUSH_FREE := 44.0
const LUSH_STEP := 0.42
const LUSH_ROAD := Vector2(0.2, 1.3)

var _lush_step := LUSH_STEP
var _lush_road := LUSH_ROAD
var _lush := {}
var _lush_mesh: ArrayMesh
var _lush_mat: ShaderMaterial
var _grass_dens: PackedByteArray
var _lush_noise := FastNoiseLite.new()

func _lush_setup() -> void:
	if OS.get_cmdline_user_args().has("--no-lush"):
		return
	if OS.get_environment("MC_LUSH_OLD") != "":
		_lush_step = 0.42
		_lush_road = Vector2(0.35, 0.9)
	_lush_mesh = _lush_clump(OS.get_environment("MC_LUSH_OLD") != "")
	_lush_mat = ShaderMaterial.new()
	_lush_mat.shader = preload("res://shaders/home_grass.gdshader")
	_lush_mat.set_shader_parameter("noise_tex", load("res://props/farm/ground/noise.png"))
	_lush_noise.frequency = 1.0 / 7.0
	_lush_noise.seed = 21
	_weed_setup()
	_lush_update(1000)

func _lush_clump(old := false) -> ArrayMesh:
	"""(06/11, the Zelda / OoT turf clump: map_study/grass.md) seven blades fanned from a small tuft, each a tapered,
	leaning strip (two triangles at the base, one at the tip): 21 triangles, opaque (no alpha cards: the iPad's
	hidden-surface removal keeps working). Was four thin blades. UV.y = how far up the blade, UV.x = its brightness."""
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var nb := 4 if old else 7
	for b in nb:
		var ang := b * TAU / nb + rng.randf_range(-0.45, 0.45)
		var out := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-out.z, 0, out.x)
		var h := rng.randf_range(0.15, 0.27) if old else rng.randf_range(0.13, 0.28) * (1.15 if b % 3 == 0 else 1.0)
		var w := 0.024 if old else rng.randf_range(0.028, 0.04)
		var lean := rng.randf_range(0.04, 0.12)
		var base := out * (rng.randf_range(0.01, 0.06) if old else rng.randf_range(0.0, 0.07))
		var br := rng.randf()
		var p0 := base - side * w
		var p1 := base + side * w
		var mid := base + out * lean * 0.45 + Vector3(0, h * 0.55, 0)
		var p2 := mid - side * w * 0.7
		var p3 := mid + side * w * 0.7
		var tip := base + out * lean + Vector3(0, h, 0)
		for tri in [[p0, 0.0, p1, 0.0, p3, 0.55], [p0, 0.0, p3, 0.55, p2, 0.55], [p2, 0.55, p3, 0.55, tip, 1.0]]:
			for k in 3:
				st.set_uv(Vector2(br, tri[k * 2 + 1]))
				st.set_normal(Vector3.UP)
				st.add_vertex(tri[k * 2])
	return st.commit()

func _lush_update(budget: int) -> void:
	if _lush_mat == null or cam == null:
		return
	var p := cam.global_position
	_lush_mat.set_shader_parameter("pusher", Vector4(player.global_position.x, player.global_position.y,
		player.global_position.z, 0.7))
	var pc := Vector2i(floori(p.x / LUSH_CHUNK), floori(p.z / LUSH_CHUNK))
	var reach := ceili(LUSH_R / LUSH_CHUNK) + 1
	var built := 0
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := pc + Vector2i(dx, dz)
			if built < budget and not _lush.has(c) and _lush_dist(c, p) < LUSH_R:
				_lush[c] = _lush_chunk(c)
				if _weed_mat:
					_weeds[c] = _weed_chunk(c)
				built += 1
	for c: Vector2i in _lush.keys():
		if _lush_dist(c, p) > LUSH_FREE:
			if _lush[c] != null:
				_lush[c].queue_free()
			_lush.erase(c)
			if _weeds.get(c) != null:
				_weeds[c].queue_free()
			_weeds.erase(c)
	if _weed_mat:
		_weed_mat.set_shader_parameter("pusher", Vector4(player.global_position.x, player.global_position.y,
			player.global_position.z, 0.7))

func _lush_dist(c: Vector2i, p: Vector3) -> float:
	var x0 := c.x * LUSH_CHUNK
	var z0 := c.y * LUSH_CHUNK
	return Vector2(maxf(maxf(x0 - p.x, p.x - (x0 + LUSH_CHUNK)), 0.0), maxf(maxf(z0 - p.z, p.z - (z0 + LUSH_CHUNK)), 0.0)).length()

func _lush_chunk(c: Vector2i) -> MultiMeshInstance3D:
	var area := Rect2(c.x * LUSH_CHUNK, c.y * LUSH_CHUNK, LUSH_CHUNK, LUSH_CHUNK)
	if absf(area.get_center().x) > VPLAY or absf(area.get_center().y) > VPLAY or _grass_dens.size() != N * N:
		return null
	var rects: Array[Rect2] = []
	for r in _no_grass_rects:
		if r.intersects(area):
			rects.append(r)

	if not ClassDB.class_exists("GrassField"):
		return null
	var buf: PackedFloat32Array = ClassDB.class_call_static("GrassField", "lush_chunk", area, N, HALF, terrain.mats,
		_grass_dens, terrain.road_sdf_data, heights, rects, hash(c) + 77, _lush_step, _lush_road.x, _lush_road.y,
		_lush_noise, PAL[0])
	if buf.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _lush_mesh
	mm.instance_count = buf.size() / 16
	mm.buffer = buf
	var centre := Vector3(area.get_center().x, 0.0, area.get_center().y)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _lush_mat
	mi.position = centre
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 26.0 + LUSH_CHUNK * 0.71
	add_child(mi)
	return mi

const WEED_KINDS := ["co_ba_la", "rau_ma", "la_rong", "co_may", "cuc_trang", "hoa_tim"]
const WEED_MAX_V := 36
const WEED_SKIP := Rect2(-200.0, -120.0, 80.0, 60.0)
const WEED_FADE := Vector2(17.0, 23.0)
var _weeds := {}
var _weed_mesh: ArrayMesh
var _weed_mat: ShaderMaterial

func _undergrowth_new() -> bool:
	return OS.get_environment("MC_UNDERGROWTH_OLD") == "" and ClassDB.class_exists("GrassField") \
		and ClassDB.class_has_method("GrassField", "weed_chunk")

func _weed_setup() -> void:
	if not _undergrowth_new():
		return
	var kit := _weed_kit()
	if kit == null:
		return

	var vv := PackedVector3Array()
	var nv := PackedVector3Array()
	var uv := PackedVector2Array()
	for i in WEED_MAX_V:
		vv.append(Vector3.ZERO)
		nv.append(Vector3.UP)
		uv.append(Vector2(i, 0))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vv
	arr[Mesh.ARRAY_NORMAL] = nv
	arr[Mesh.ARRAY_TEX_UV] = uv
	_weed_mesh = ArrayMesh.new()
	_weed_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_weed_mesh.custom_aabb = AABB(Vector3(-0.3, -0.05, -0.3), Vector3(0.6, 0.6, 0.6))
	_weed_mat = ShaderMaterial.new()
	_weed_mat.shader = preload("res://shaders/undergrowth.gdshader")
	_weed_mat.set_shader_parameter("kit_data", kit)
	_weed_mat.set_shader_parameter("atlas", load("res://props/hometown/co_dai/co_dai.png"))
	_weed_mat.set_shader_parameter("ground_green", Vector3(PAL[0].r, PAL[0].g, PAL[0].b))
	_weed_mat.set_shader_parameter("fade_from", WEED_FADE.x)
	_weed_mat.set_shader_parameter("fade_to", WEED_FADE.y)
	_paint_mat(_weed_mat)

func _weed_kit() -> ImageTexture:
	"""The kit's six meshes packed into a float texture, three rows a kind: (position, u), (normal, v), colour."""
	var sc := load("res://props/hometown/co_dai/co_dai.glb") as PackedScene
	if sc == null:
		return null
	var root := sc.instantiate()
	var data := PackedFloat32Array()
	data.resize(WEED_MAX_V * 4 * 3 * WEED_KINDS.size())
	for k in WEED_KINDS.size():
		var mi := root.find_child(WEED_KINDS[k], true, false) as MeshInstance3D
		if mi == null or mi.mesh == null:
			push_warning("undergrowth: no %s in co_dai.glb" % WEED_KINDS[k])
			continue
		var a := mi.mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var us: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var cs: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var cnt := mini(ix.size() if ix.size() > 0 else vs.size(), WEED_MAX_V)
		for i in cnt:
			var v := ix[i] if ix.size() > 0 else i
			var o := (k * 3 * WEED_MAX_V + i) * 4
			var col := cs[v] if v < cs.size() else Color(0.8, 0.8, 0.8, 1.0)
			var nrm := ns[v] if v < ns.size() else Vector3.UP
			for j in 4:
				data[o + j] = [vs[v].x, vs[v].y, vs[v].z, us[v].x][j]
				data[o + WEED_MAX_V * 4 + j] = [nrm.x, nrm.y, nrm.z, us[v].y][j]
				data[o + WEED_MAX_V * 8 + j] = [col.r, col.g, col.b, col.a][j]
	root.free()
	var img := Image.create_from_data(WEED_MAX_V, 3 * WEED_KINDS.size(), false, Image.FORMAT_RGBAF, data.to_byte_array())
	return ImageTexture.create_from_image(img)

func _weed_chunk(c: Vector2i) -> MultiMeshInstance3D:
	var area := Rect2(c.x * LUSH_CHUNK, c.y * LUSH_CHUNK, LUSH_CHUNK, LUSH_CHUNK)
	if absf(area.get_center().x) > VPLAY or absf(area.get_center().y) > VPLAY or _grass_dens.size() != N * N:
		return null
	if area.intersection(WEED_SKIP).get_area() >= area.get_area():
		return null

	var buf: PackedFloat32Array = ClassDB.class_call_static("GrassField", "weed_chunk", area, N, HALF, terrain.mats,
		_grass_dens, terrain.road_sdf_data, heights, _no_grass_rects, _no_grass, WEED_SKIP, 606,
		LUSH_ROAD.x + LUSH_ROAD.y)
	if buf.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _weed_mesh
	mm.instance_count = buf.size() / 16
	mm.buffer = buf
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _weed_mat
	mi.position = Vector3(area.get_center().x, 0.0, area.get_center().y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = WEED_FADE.y + LUSH_CHUNK * 0.71
	add_child(mi)
	return mi

const RICE_CHUNK := 16
const RICE_R := 36.0
const RICE_FREE := 70.0
const RICE_END := 32.0
var rice_stage := 4
var _rice_chunks := {}
var _rice_has := {}
var _rice_mesh: Mesh
var _rice_mat: ShaderMaterial
var _rice_far_mat: ShaderMaterial
var _rice_noise := FastNoiseLite.new()

func _rice() -> void:
	if not ResourceLoader.exists("res://props/farm/lua_%d.glb" % rice_stage):
		return
	_rice_mesh = _first_mesh("res://props/farm/lua_%d.glb" % rice_stage)
	_rice_mat = ShaderMaterial.new()
	_rice_mat.shader = preload("res://shaders/crop_foliage.gdshader")
	_rice_mat.set_shader_parameter("atlas", load("res://props/farm/dong_atlas.png"))
	_rice_noise.frequency = 1.0 / 45.0
	_rice_noise.seed = 9
	var far_pic := "res://props/farm/lua_far_%d.png" % {0: 1, 1: 1, 2: 2, 3: 2, 4: 4}.get(rice_stage, 4)
	_rice_far_mat = ShaderMaterial.new()
	_rice_far_mat.shader = preload("res://shaders/rice_far.gdshader")
	_rice_far_mat.set_shader_parameter("tex", load(far_pic))
	_rice_far_mat.set_shader_parameter("ring", Vector2(RICE_END - 6.0, 100000.0))
	if FileAccess.file_exists(DIR + "paddy_cells.png") or ResourceLoader.exists(DIR + "paddy_cells.png"):
		var ci := Image.load_from_file(ProjectSettings.globalize_path(DIR + "paddy_cells.png")) if not TexCache.shipped() 			else (load(DIR + "paddy_cells.png") as Texture2D).get_image()
		ci.convert(Image.FORMAT_L8)
		_paddy_cells = ci.get_data()
		var cells_tex := ImageTexture.create_from_image(ci)
		_rice_far_mat.set_shader_parameter("cells", cells_tex)
		_rice_far_mat.set_shader_parameter("cells_soft", cells_tex)
		_rice_far_mat.set_shader_parameter("has_cells", true)
		_rice_far_mat.set_shader_parameter("grid_n", float(N))
		_rice_far_mat.set_shader_parameter("grid_half", float(HALF))
	for f: Dictionary in [layout["fields"]] + layout.get("paddies", []):
		var sheet := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(f["x1"] - f["x0"], f["z1"] - f["z0"])
		sheet.mesh = pm
		sheet.material_override = _rice_far_mat
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sheet.position = Vector3((f["x0"] + f["x1"]) / 2.0, 0.6 + (0.25 if rice_stage < 2 else 0.75), (f["z0"] + f["z1"]) / 2.0)
		sheet.visibility_range_end = 900.0
		add_child(sheet)
		for cz in range(floori(f["z0"] / RICE_CHUNK), floori(f["z1"] / RICE_CHUNK) + 1):
			for cx in range(floori(f["x0"] / RICE_CHUNK), floori(f["x1"] / RICE_CHUNK) + 1):
				_rice_has[Vector2i(cx, cz)] = true
	_rice_update(1000)

var _paddy_cells: PackedByteArray

func _rice_update(budget: int) -> void:
	if _rice_mesh == null:
		return
	var p := cam.global_position
	_rice_far_mat.set_shader_parameter("focus", p)
	var built := 0
	for c: Vector2i in _rice_has:
		var d := _chunk_dist(c, p)
		if d < RICE_R and not _rice_chunks.has(c) and built < budget:
			_rice_chunks[c] = _rice_chunk(c)
			built += 1
		elif d > RICE_FREE and _rice_chunks.has(c):
			if _rice_chunks[c] != null:
				_rice_chunks[c].queue_free()
			_rice_chunks.erase(c)

func _chunk_dist(c: Vector2i, p: Vector3) -> float:
	var x0 := c.x * RICE_CHUNK
	var z0 := c.y * RICE_CHUNK
	return Vector2(maxf(maxf(x0 - p.x, p.x - (x0 + RICE_CHUNK)), 0.0), maxf(maxf(z0 - p.z, p.z - (z0 + RICE_CHUNK)), 0.0)).length()

func _rice_chunk(c: Vector2i) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)
	var xs: Array[Transform3D] = []
	var cols: Array[Color] = []
	for z in range(c.y * RICE_CHUNK, (c.y + 1) * RICE_CHUNK):
		for x in range(c.x * RICE_CHUNK, (c.x + 1) * RICE_CHUNK):
			var gx := x + HALF
			var gz := z + HALF
			if gx < 0 or gz < 0 or gx >= N or gz >= N or terrain.mats[gz * N + gx] != 1:
				continue
			var yaw := rng.randi_range(0, 3) * PI * 0.5 + rng.randf_range(-0.05, 0.05)
			var sc := rng.randf_range(0.96, 1.04)

			var edge := 0
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ex := gx + o.x
				var ez := gz + o.y
				if ex >= 0 and ez >= 0 and ex < N and ez < N and terrain.mats[ez * N + ex] != 1:
					edge += 1
			if edge > 0:
				if rng.randf() < 0.18 * edge:
					continue
				sc *= rng.randf_range(0.72, 0.88)
			var pos := Vector3(x + 0.5 + rng.randf_range(-0.02, 0.02), height_at(x + 0.5, z + 0.5), z + 0.5 + rng.randf_range(-0.02, 0.02))
			xs.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc, sc)), pos))
			var k := 0.97 + 0.08 * _rice_noise.get_noise_2d(x, z) + rng.randf_range(-0.02, 0.02)
			var tint := Color(k, k, k * 0.98, 1.0)
			if _paddy_cells.size() == N * N:
				var pv := fmod(float(_paddy_cells[gz * N + gx]) * 0.6180339, 1.0)
				var m := lerpf(0.84, 1.1, pv)
				tint = Color(tint.r * m, tint.g * m, tint.b * m, 1.0)
				var g := clampf((pv - 0.64) / 0.06, 0.0, 1.0)
				tint = tint.lerp(Color(tint.r * 0.62, tint.g * 1.1, tint.b * 0.5, 1.0), g)
				var w := clampf((0.16 - pv) / 0.1, 0.0, 1.0) * 0.8
				tint = tint.lerp(Color(tint.r * 1.1, tint.g * 0.92, tint.b * 0.74, 1.0), w)
			cols.append(tint)
	if xs.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _rice_mesh
	mm.instance_count = xs.size()
	var centre := Vector3((c.x + 0.5) * RICE_CHUNK, 0.6, (c.y + 0.5) * RICE_CHUNK)
	for i in xs.size():
		mm.set_instance_transform(i, Transform3D(xs[i].basis, xs[i].origin - centre))
		mm.set_instance_color(i, cols[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _rice_mat
	mi.position = centre
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = RICE_END + RICE_CHUNK * 0.7
	add_child(mi)
	return mi

func _flowers(list: Array) -> void:

	if _undergrowth_new() and not OS.get_cmdline_user_args().has("--no-lush"):
		return
	var cols := [Color("ff8cbf"), Color("fffaf0"), Color("ffd95a"), Color("bf98ff")]
	var xs: Array = []
	var cs: Array = []
	for fl in list:
		xs.append(Transform3D(Basis(), _ground(fl[0], fl[1]) + Vector3(0, 0.3, 0)))
		cs.append(cols[int(fl[2])])
	var m := SphereMesh.new()
	m.radius = 0.12
	m.height = 0.18
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	m.material = mat
	_multimesh(m, xs, cs)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_V:
		map_view = not map_view
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_E and not (player and player.riding()):
		_board()
		_bus_board()
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F3:
		stats.visible = not stats.visible
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_N:
		show_names = not show_names
		for l in _names:
			l.visible = show_names
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(5.0, cam_dist - 1.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(60.0, cam_dist + 1.0)

var _occluders := []

func _clear_view(delta: float) -> void:
	var eye := cam.global_position
	var hero := player.global_position + Vector3(0, 0.9, 0)
	for o: Array in _occluders:
		var hn: Node3D = o[0]
		var box: AABB = o[1]
		if box.size == Vector3.ZERO:
			var first := true
			var parts := []
			for gi: GeometryInstance3D in hn.find_children("*", "GeometryInstance3D", true, false):
				var mi := gi as MeshInstance3D
				var house := mi != null and mi.material_override == null and mi.get_surface_override_material(0) is ShaderMaterial \
					and String(((mi.get_surface_override_material(0) as ShaderMaterial).shader as Shader).resource_path).begins_with("res://shaders/home_")
				parts.append([gi, house])
				if mi and not house:
					continue
				if mi == null or mi.get_parent().name == &"Far" or mi.visibility_range_begin > 0.0:
					continue
				var b := mi.global_transform * mi.get_aabb()
				box = b if first else box.merge(b)
				first = false
			box = box.grow(-0.15)
			if o.size() > 5 and (o[5] as AABB).size != Vector3.ZERO:
				box = o[5]
			o[1] = box
			o[4] = parts
		var m := 0.6 if o[3] else 0.0

		var dx := maxf(maxf(box.position.x - eye.x, eye.x - box.end.x), 0.0)
		var dz := maxf(maxf(box.position.z - eye.z, eye.z - box.end.z), 0.0)

		var near_hero := hero + (eye - hero).normalized() * 2.5
		var block: bool = not map_view and Vector2(dx, dz).length() < 3.6 + m or not map_view and box.grow(1.2 + m).intersects_segment(eye, near_hero) != null
		o[3] = block
		var f: float = move_toward(o[2], (o[6] if o.size() > 6 else 1.0) if block else 0.0, delta * 5.0)
		if f == o[2]:
			continue
		var was: float = o[2]
		o[2] = f
		hn.visible = f < 0.99
		for pa: Array in o[4]:
			var gi: GeometryInstance3D = pa[0]
			if not pa[1]:
				gi.visible = f < 0.34 if gi.name != &"LampPool" else (f < 0.34 and HomeKit._night > 0.01)
				continue
			var mi := gi as MeshInstance3D
			if was == 0.0:
				for s in mi.mesh.get_surface_count():
					var fm := HomeKit.fade_material(mi.get_surface_override_material(s))
					if fm:
						mi.set_meta("solid_%d" % s, mi.get_surface_override_material(s))
						mi.set_surface_override_material(s, fm)
			mi.set_instance_shader_parameter("fade", f)
			if f == 0.0:
				for s in mi.mesh.get_surface_count():
					if mi.has_meta("solid_%d" % s):
						mi.set_surface_override_material(s, mi.get_meta("solid_%d" % s))

func _place_camera(k: float) -> void:
	if fixed_view:
		return
	var target := player.global_position + Vector3(0, 0.8, 0)
	var want := target + (Vector3(0, 1700, 1.0) if map_view else Vector3(0, cam_dist * 0.62, cam_dist * 0.8))
	if map_view:
		target = Vector3(0, 0, 0)
	cam.global_position = cam.global_position.lerp(want, k)
	cam.look_at(target, Vector3.UP)

var _stream_ways: Array = []

var _dr_held := false

func _dynres_ride() -> void:
	var riding := (bus_s_dir != 0 and not _bus_empty) or boat_dir != 0 or BoatRow.busy(self)
	if riding != _dr_held:
		var dr := get_node_or_null("/root/DynRes")
		if dr:
			dr.hold(riding)
		_dr_held = riding

func _exit_tree() -> void:
	if _dr_held:
		var dr := get_node_or_null("/root/DynRes")
		if dr:
			dr.hold(false)
		_dr_held = false

func _process(delta: float) -> void:
	_farm_door_step()
	_dynres_ride()
	if player and not _stream_ways.is_empty():
		var steep := false
		for w: Array in _stream_ways:
			steep = steep or _stream_near(w[0], w[1], player.position.x, player.position.z).x < w[2]
		player.floor_max_angle = deg_to_rad(55.0 if steep else 32.0)
	if cam and not _lod_mats.is_empty():
		var vp := cam.global_position
		for m in _lod_mats:
			m.set_shader_parameter("view_pos", vp)
		_karst_dress_tick(vp)
	t += delta
	_cam_soft = minf(1.0, _cam_soft + delta * 0.5)
	if bus_s_dir != 0 and not _bus_empty and not map_view:
		_bus_camera(delta)
		if not _occluders.is_empty():
			_clear_view(delta)
	elif fly.is_empty():
		_place_camera(1.0 - exp(-delta * (3.0 if map_view else lerpf(0.8, 5.0, _cam_soft * _cam_soft))))
		if not _occluders.is_empty():
			_clear_view(delta)
		_bus_clear_view(delta)
	elif fly.size() == 1:
		if t > boat_len / boat_speed + 8.0:
			get_tree().quit()
		var bb := boat.global_basis
		var want := boat.global_position - bb.z * 9.0 + Vector3(0, 3.6, 0)
		cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-delta * 3.0)) if t > 0.1 else want
		cam.look_at(boat.global_position + bb.z * 12.0 + Vector3(0, 1.2, 0), Vector3.UP)
	else:
		_fly_camera()
	_show_khus()
	_boat_step(delta)
	_bus_step(delta)
	if not _bob.is_empty() and Engine.get_process_frames() % 2 == 0:
		_bob_step()
	if Engine.get_process_frames() % 6 == 0:
		_rice_update(2)
	if Engine.get_process_frames() % 3 == 0:
		_lush_update(2)
	if _karst_far_mat != null:

		_karst_far_mat.set_shader_parameter("focus", cam.global_position)
	if stats.visible and Engine.get_process_frames() % 10 == 0:
		stats.text = "FPS: %d   •   tam giác: %s   •   lần vẽ: %d   •   ô đất gần: %d" % [Engine.get_frames_per_second(),
			_thousands(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), terrain.near.size()]
	if measure:
		_measure_step()
	if still.size() == 2 and still[0] != "" and t >= still[1]:
		set_process(false)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(still[0])
		get_tree().quit()

func _cull_small() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var n := 0
	for mi: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		if mi is MultiMeshInstance3D or mi.get_parent() == terrain or mi.visibility_range_end > 0.0 or mi is Label3D:
			continue
		var size := (mi as VisualInstance3D).get_aabb().size * (mi as Node3D).global_basis.get_scale()
		var side := maxf(size.x, maxf(size.y, size.z))
		for se: Array in SIZE_ENDS:
			if side < se[0]:
				mi.visibility_range_end = se[1]
				n += 1
				break
	print("hometown: %d small things hidden by distance" % n)
	if OS.get_environment("MC_HIDE") != "":
		var hide := OS.get_environment("MC_HIDE").split(",")
		var n_hidden := {}
		for c in find_children("*", "GeometryInstance3D", true, false):
			var cat := _category(c)
			if hide.has(cat):
				(c as Node3D).visible = false
				n_hidden[cat] = n_hidden.get(cat, 0) + 1
		print("MC_HIDE hid: ", n_hidden)
	if OS.get_environment("MC_ONLY_TERRAIN") == "1":
		for c in get_children():
			if c is GeometryInstance3D and not (c is MeshInstance3D and (c as MeshInstance3D).mesh is PlaneMesh) or c.name.begins_with("Khu"):
				c.visible = false

func _category(c: Node) -> String:
	if c is Label3D:
		return "labels"
	var p := c.get_parent()
	while p != null and p != self:
		if p == terrain:
			return "terrain"
		if p.get_parent() == self and p.scene_file_path != "":
			return "houses"
		p = p.get_parent()
	if c is MultiMeshInstance3D:
		var mm := (c as MultiMeshInstance3D).multimesh
		if mm.mesh == _rice_mesh:
			return "rice"
		if (c as MultiMeshInstance3D).material_override is ShaderMaterial and ((c as MultiMeshInstance3D).material_override as ShaderMaterial).shader in preload("res://scripts/home/shader_copy.gd").family([preload("res://shaders/karst.gdshader")]):
			return "forest"
		if mm.mesh is SphereMesh:
			return "flowers"
		return "grass"
	if c is MeshInstance3D:
		var mi := c as MeshInstance3D
		if mi.mesh is PlaneMesh:
			return "water"
		if mi.material_override is ShaderMaterial and (mi.material_override as ShaderMaterial).shader == preload("res://shaders/karst.gdshader"):
			return "karst"
	return "props"

func _thousands(v: int) -> String:
	var txt := str(v)
	var out := ""
	while txt.length() > 3:
		out = "." + txt.substr(txt.length() - 3) + out
		txt = txt.substr(0, txt.length() - 3)
	return txt + out

func _show_khus() -> void:
	if Engine.get_process_frames() % 15 != 0:
		return
	var p := cam.global_position if not fly.is_empty() else player.global_position
	for k: Node3D in khus.values():
		var c: Vector3 = k.get_meta("centre")
		k.visible = Vector2(c.x - p.x, c.z - p.z).length() < KHU_SHOW + KHU * 0.5

func _flight() -> Array:
	var way := [[-330, 40, 60], [-60, 45, 110], [180, 60, 140], [380, 80, 200], [470, 90, 300], [300, 120, -100],
		[60, 130, -400], [0, 120, -520], [-300, 130, -480], [-560, 120, -360], [-800, 120, -230], [-760, 110, 200],
		[-640, 90, 480], [-420, 70, 300], [-280, 40, 60]]
	var out := []
	for w in way:
		out.append(Vector3(w[0], w[1], w[2]))
	player.set_physics_process(false)
	return out

var _fly_y := 0.0

func _flight_nui_rong() -> Array:
	var s: Dictionary = layout["shrine"]
	var pts: Array = s["stairs"]
	var y0: float = s["stair_y"][0]
	var y1: float = s["stair_y"][1]
	var out := [Vector3(-60, 20, 140)]
	var ys: Array = s.get("stair_ys", [])
	var every := 12 if ys.size() == pts.size() else 1
	for i in range(0, pts.size(), every):
		var y: float = float(ys[i]) if every > 1 else lerpf(y0, y1, float(i) / (pts.size() - 1))
		out.append(Vector3(pts[i][0] + 16.0, y + 9.0, pts[i][1]))
	out.append(Vector3(-150, y1 + 14, 150))
	out.append(Vector3(-160, y1 + 10, 135))
	_fly_dur = 34.0
	_fly_clear_r = 8.0
	_fly_look_ground = false
	player.set_physics_process(false)
	return out

func _flight_thung_lang() -> Array:
	var tn: Dictionary = layout["tunnels"][0]
	var a := Vector3(tn["from"][0], 0, tn["from"][1])
	var b := Vector3(tn["to"][0], 0, tn["to"][1])
	var dir := (b - a).normalized()
	var ys: Array = tn["y"]
	var out := [a - dir * 50.0 + Vector3(0, ys[0] + 5.0, 0), a - dir * 8.0 + Vector3(0, ys[0] + 2.4, 0)]
	for k in 4:
		var u := (k + 1) / 5.0
		out.append(a.lerp(b, u) + Vector3(0, lerpf(ys[0], ys[1], u) + 2.2, 0))
	out.append(b + dir * 10.0 + Vector3(0, ys[1] + 3.0, 0))
	var tl: Dictionary = layout["region"]["thung_lang"]
	for k in 7:
		var an := -PI / 2.0 - 0.5 + k * 0.75
		out.append(Vector3(tl["x"] + cos(an) * 60.0, 9.0, tl["z"] + sin(an) * 36.0))
	out.append(Vector3(-8, 3.0, -444))
	_fly_dur = 48.0
	_fly_clear_r = 3.0
	_fly_look_ground = true
	player.set_physics_process(false)
	return out

var _fly_dur := 70.0
var _fly_clear_r := 60.0
var _fly_look_ground := true
var _fly_look_ahead := false
var _fly_end_look := Vector3.ZERO

func _fly_camera() -> void:
	var dur := _fly_dur
	var pos := _fly_at(t / dur)
	var ahead := _fly_at(t / dur + 0.04)
	var clear := pos.y
	for k in 9:
		var o := Vector2(_fly_clear_r, 0).rotated(TAU * k / 8.0) if k > 0 else Vector2.ZERO
		clear = maxf(clear, height_at(pos.x + o.x, pos.z + o.y) + (35.0 if _fly_clear_r > 20.0 else 4.0))
	for site: Array in layout.get("karst", []):
		if Vector2(site[0] - pos.x, site[1] - pos.z).length() < float(site[2]) + _fly_clear_r:
			clear = maxf(clear, float(site[4]) + float(site[3]) + 30.0)
	_fly_y = clear if _fly_y == 0.0 else lerpf(_fly_y, clear, 0.05)
	cam.global_position = Vector3(pos.x, _fly_y, pos.z)
	if _fly_look_ahead:
		var look := ahead + (ahead - pos).normalized() * 30.0 + Vector3(0, -4.0, 0)
		if _fly_end_look != Vector3.ZERO:
			look = look.lerp(_fly_end_look, smoothstep(0.7, 0.9, t / _fly_dur))
		cam.look_at(look, Vector3.UP)
	elif _fly_look_ground:
		cam.look_at(Vector3(ahead.x, height_at(ahead.x, ahead.z), ahead.z), Vector3.UP)
	else:
		var on := Vector3(ahead.x - 16.0, ahead.y - 7.0, ahead.z) if t < _fly_dur * 0.82 else Vector3(-20, 0, 40)
		cam.look_at(on, Vector3.UP)
	player.global_position = Vector3(pos.x, height_at(pos.x, pos.z), pos.z)
	if t > dur + 1.0:
		get_tree().quit()

func _fly_at(f: float) -> Vector3:
	var x := clampf(f, 0.0, 0.9999) * (fly.size() - 1)
	var i := int(x)
	var u := x - i
	var p0: Vector3 = fly[maxi(i - 1, 0)]
	var p1: Vector3 = fly[i]
	var p2: Vector3 = fly[mini(i + 1, fly.size() - 1)]
	var p3: Vector3 = fly[mini(i + 2, fly.size() - 1)]
	return p1.cubic_interpolate(p2, p0, p3, u)

var _m_i := 0
var _m_t := 0.0
var _m_rows := []
var _m_placed := false
const _M_SPOTS := [[-40, 30, "Giữa ruộng"], [-254, 36, "Ga Yên Khê"], [-128, -60, "Xóm"], [105, -60, "Trang trại"], [-170, 172, "Đỉnh Núi Rồng"],
	[0, -470, "Thung Lặng"], [-600, -420, "Cố đô"], [-640, 520, "Rừng Chò"], [480, 300, "Vách Biếc"]]

func _measure_step() -> void:
	_m_t += get_process_delta_time()
	var only := OS.get_environment("MC_SPOTS")
	while only != "" and _m_i < _M_SPOTS.size() * 4 and not only.split(",").has(String(_M_SPOTS[_m_i / 4][2])):
		_m_i += 1
	if _m_i >= _M_SPOTS.size() * 4:
		_measure_done()
		return
	var spot: Array = _M_SPOTS[_m_i / 4]
	var dir := _m_i % 4
	if not _m_placed:
		_m_placed = true
		_m_t = 0.0
		player.global_position = Vector3(spot[0], height_at(spot[0], spot[1]) + 0.3, spot[1])
		player.velocity = Vector3.ZERO
		fixed_view = true
		var y := height_at(spot[0], spot[1]) + 2.0
		cam.global_position = Vector3(spot[0], y + 5.0, spot[1]) - Vector3(sin(dir * PI / 2), 0, cos(dir * PI / 2)) * 10.0
		cam.look_at(Vector3(spot[0], y, spot[1]) + Vector3(sin(dir * PI / 2), 0, cos(dir * PI / 2)) * 40.0, Vector3.UP)
	if _m_t > 1.2:
		var row := [spot[2], dir, Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]
		_m_rows.append(row)
		print("MEASURE %s dir %d: fps %d, tris %d, draws %d" % row, "  cam ", cam.global_position.snapped(Vector3.ONE), " fwd ", (-cam.global_basis.z).snapped(Vector3(0.1, 0.1, 0.1)))
		_m_t = 0.0
		_m_placed = false
		_m_i += 1
		if _m_i >= _M_SPOTS.size() * 4:
			_measure_done()

func _measure_done() -> void:
	var tris := 0
	var draws := 0
	var worst := [0, 0]
	for r in _m_rows:
		tris += r[3]
		draws += r[4]
		worst = [maxi(worst[0], r[3]), maxi(worst[1], r[4])]
	var n := maxi(_m_rows.size(), 1)
	print("MEASURE average: tris %d, draws %d; worst: tris %d, draws %d" % [tris / n, draws / n, worst[0], worst[1]])
	get_tree().quit()

var _vlight := OS.get_environment("MC_VLIGHT_OLD") != "1"

const VL_CUT := [Vector2(-167.7, -135.9), Vector2(-169.6, -121.2), Vector2(-127.0, -183.0), Vector2(-101.6, -135.5),
	Vector2(-58.4, -207.5), Vector2(-99.3, -135.2), Vector2(-64.5, -158.6), Vector2(-114.3, -176.9),
	Vector2(-143.5, -155.4), Vector2(-139.7, -154.5), Vector2(-91.9, -187.2), Vector2(-93.6, -171.8),
	Vector2(-72.6, -171.8), Vector2(-93.54, -120.23), Vector2(-66.5, -149.91), Vector2(-134.04, -148.67),
	Vector2(-112.67, -187.78), Vector2(-69.35, -181.64), Vector2(-71.92, -184.73), Vector2(-78.01, -180.78),
	Vector2(-73.58, -193.29), Vector2(-89.91, -75.15), Vector2(-95.54, -79.3), Vector2(-101.18, -83.45)]
const VL_STEP := 15.0
const VL_POST_H := 3.2
const VL_ARM := 0.62
const VL_PLACES := [Vector2(-168.5, -121.0), Vector2(-131.5, -121.0), Vector2(-103.0, -116.5), Vector2(-121.5, -127.0)]
const VL_PLACE_FACE := [Vector2(-150, -114), Vector2(-150, -114), Vector2(-112, -122), Vector2(-112, -122)]
const VL_TALL_POLE := Vector2(-142.5, -119.5)
var vl_counts := {}

func _vl_cut(p: Vector3) -> bool:
	if not _vlight:
		return false
	for c: Vector2 in VL_CUT:
		if absf(c.x - p.x) < 0.3 and absf(c.y - p.z) < 0.3:
			return true
	return false

func _vl_win(x: float, z: float) -> bool:
	return x > -182.0 and x < -118.0 and z > -112.0 and z < -68.0

func _vlight_pass() -> void:
	if not _vlight:
		return
	var t0 := Time.get_ticks_msec()
	var acc := {}
	var pole := _vl_src("cot_dien_den")
	var lamp := _vl_src("cot_den")
	var phoi := _vl_src("day_phoi")
	var coco := _vl_src("cot_co")
	if pole.is_empty() or phoi.is_empty():
		return
	var dr: Dictionary = layout["dress"]

	var have: Array[Vector2] = []
	var houses: Array[Vector2] = []
	for h: Array in dr["houses"]:
		houses.append(Vector2(h[0], h[1]))
	var spots := []
	for pl: Array in dr["poles"]:
		var q := Vector2(pl[0], pl[1])
		have.append(q)
		spots.append([_ground(q.x, q.y), _vl_face_road(q)])
	var lines: Array = []
	for i in mini(11, dr["lanes"].size()):
		lines.append(dr["lanes"][i])
	if dr["lanes"].size() > 11:
		lines.append(dr["lanes"][11])
	lines.append(layout["roads"][0])
	var side := 1.0
	for line: Array in lines:
		var pts: Array[Vector2] = []
		for p: Array in line:
			pts.append(Vector2(p[0], p[1]))
		var cum: Array[float] = [0.0]
		for i in range(1, pts.size()):
			cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
		var keys: Array[float] = [0.0]
		for i in range(1, pts.size() - 1):
			var a := (pts[i] - pts[i - 1]).normalized()
			var b := (pts[i + 1] - pts[i]).normalized()
			if absf(a.angle_to(b)) > deg_to_rad(28.0) and cum[i] - keys[keys.size() - 1] > 6.0:
				keys.append(cum[i])
		if cum[cum.size() - 1] - keys[keys.size() - 1] > 6.0:
			keys.append(cum[cum.size() - 1])

		var marks: Array[float] = []
		for k in keys.size():
			if k == 0 or k == keys.size() - 1:
				marks.append(keys[k])
				continue
			var j := 1
			while j < cum.size() - 1 and cum[j] < keys[k]:
				j += 1
			for q: Vector2 in houses:
				if q.distance_squared_to(pts[j]) < 22.0 * 22.0:
					marks.append(keys[k])
					break
		for s_: float in marks:
			var i := 1
			while i < cum.size() - 1 and cum[i] < s_:
				i += 1
			var seg := (pts[i] - pts[i - 1])
			var f := clampf((s_ - cum[i - 1]) / maxf(seg.length(), 0.01), 0.0, 1.0)
			var c := pts[i - 1] + seg * f
			var nrm := Vector2(-seg.y, seg.x).normalized()
			var at := c + nrm * side * 2.9
			side = -side
			if _vl_win(at.x, at.y) or height_at(at.x, at.y) < 0.25:
				continue
			var clash := false
			for q: Vector2 in have:
				if q.distance_squared_to(at) < 10.0 * 10.0:
					clash = true
					break
			for q: Vector2 in houses:
				if clash or q.distance_squared_to(at) < 6.5 * 6.5:
					clash = true
					break
			if clash:
				continue
			have.append(at)
			var to_lane := c - at
			spots.append([_ground(at.x, at.y), atan2(to_lane.x, to_lane.y)])
	for pi_ in VL_PLACES.size():
		var q: Vector2 = VL_PLACES[pi_]
		var cl := false
		for h2: Vector2 in have:
			cl = cl or h2.distance_squared_to(q) < 6.0 * 6.0
		if not cl:
			have.append(q)
			var fc: Vector2 = VL_PLACE_FACE[pi_] - q
			spots.append([_ground(q.x, q.y), atan2(fc.x, fc.y)])
	var ptop: float = pole["aabb"].end.y
	var n_grey: int = dr["poles"].size()

	var stake := _vl_src("coc_tre")
	var bb: AABB = pole.get("den_duong_aabb", AABB())
	var head_crop := AABB(bb.position - Vector3(0.3, 0.06, 0.3), bb.size + Vector3(0.6, 0.4, 0.6))
	var head := Transform3D(Basis(), Vector3(0, VL_POST_H - 0.16, VL_ARM) - Vector3(bb.get_center().x, bb.end.y, bb.get_center().z))
	for k in spots.size():
		var sp: Array = spots[k]
		var xf := Transform3D(Basis(Vector3.UP, sp[1]), sp[0] - Vector3(0, 0.05, 0))
		if k < n_grey or stake.is_empty():
			_vl_put(acc, "tiles", pole["tiles"], xf)
			if pole.has("den_duong"):
				_vl_put(acc, "den_duong", pole["den_duong"], xf)
			_vl_pool(acc, xf * Vector3(0, 0, 1.0), 5.0)
			continue
		var sh: float = stake["aabb"].end.y
		_vl_put(acc, "tiles", stake["tiles"], xf * Transform3D(Basis().scaled(Vector3(1.5, VL_POST_H / sh, 1.5)), Vector3.ZERO))
		_vl_put(acc, "tiles", stake["tiles"], xf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(Vector3(1.2, (VL_ARM + 0.08) / sh, 1.2)),
			Vector3(0, VL_POST_H - 0.12, -0.04)))
		_vl_put(acc, "tiles", pole["tiles"], xf * head, 0.0, -1e9, Color(0, 0, 0, 0), 2, head_crop)
		if pole.has("den_duong"):
			_vl_put(acc, "den_duong", pole["den_duong"], xf * head)
		_vl_pool(acc, xf * Vector3(0, 0, VL_ARM), 6.2)
	vl_counts["lane_posts"] = spots.size() - n_grey
	vl_counts["greybox_poles_lit"] = dr["poles"].size()
	_vl_hide_greybox_poles(dr["poles"])

	var yd: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "house_yards.json")) \
		if FileAccess.file_exists(DIR + "house_yards.json") else {"items": []}
	var pillars := []
	for it: Array in yd["items"]:
		if it[0] == "cot_cong":
			pillars.append(it)
	var used := {}
	var n_lan := 0
	var n_gate := 0
	if not lamp.is_empty() and lamp.has("den_long"):
		var lo: AABB = lamp["den_long_aabb"]
		for a in pillars.size():
			if used.has(a):
				continue
			var mate := -1
			for b in range(a + 1, pillars.size()):
				if not used.has(b) and Vector2(pillars[a][1] - pillars[b][1], pillars[a][2] - pillars[b][2]).length() < 4.5:
					mate = b
					break
			used[a] = true
			if mate >= 0:
				used[mate] = true
			var it: Array = pillars[a]
			if _vl_win(it[1], it[2]):
				continue
			n_gate += 1
			if n_gate % 5 in [2, 4]:
				continue
			var top := _ground(it[1], it[2]) + Vector3(0, 1.79 * float(it[4]), 0)
			var base := Transform3D(Basis(Vector3.UP, deg_to_rad(float(it[3]))), top)

			var lift := Transform3D(Basis().scaled(Vector3.ONE * 0.55), Vector3(0, -0.04, 0)) 				* Transform3D(Basis(), -Vector3(lo.get_center().x, lo.position.y, lo.get_center().z))
			var v0: int = (acc["tiles"]["v"] as PackedVector3Array).size() if acc.has("tiles") else 0
			_vl_put(acc, "tiles", lamp["den_long"], base * lift, 0.0, -1e9, Color(0.78, 0.12, 0.08))
			_vl_lantern_paint(acc["tiles"], v0, lamp["den_long"], lo)
			_vl_put(acc, "den_long", lamp["den_long"], base * lift * Transform3D(Basis().scaled(Vector3.ONE * 1.03),
				Vector3(0, lo.get_center().y * -0.03, 0)))
			_vl_pool(acc, _ground(it[1], it[2]), 3.0)
			n_lan += 1
			if n_lan <= 3:
				vl_counts["lantern_%d" % n_lan] = Vector3(it[1], top.y, it[2]).snapped(Vector3.ONE * 0.1)
	vl_counts["gate_lanterns"] = n_lan

	var n_porch := 0
	var bulb := SphereMesh.new()
	bulb.radius = 0.05
	bulb.height = 0.1
	bulb.radial_segments = 8
	bulb.rings = 4
	var bulb_arr := bulb.get_mesh_arrays()
	var stake2 := _vl_src("coc_tre")
	var n_ong := 0
	for i in dr["houses"].size():
		var h: Array = dr["houses"][i]
		var kind: String = h[3] if h.size() > 3 else "cu"
		var model: String = {"cu": "nha_cu", "thai": THAI_VARIANTS[i % THAI_VARIANTS.size()],
			"nhat": NHAT_VARIANTS[i % NHAT_VARIANTS.size()], "ong": ONG_VARIANTS[n_ong % ONG_VARIANTS.size()]}.get(kind, "")
		if kind == "ong":
			n_ong += 1
		if model == "" or kind == "ong" or (h.size() > 4 and String(h[4]) == "thi_tran") or _vl_win(h[0], h[1]):
			continue
		var door := _vl_door(model)
		if door.is_empty():
			continue
		var hx := Transform3D(Basis(Vector3.UP, deg_to_rad(float(h[2]))), _ground(h[0], h[1]))
		var dp: Vector3 = door["pos"]
		var bp := dp + Vector3(0, 0.42, 0.12)
		_vl_put(acc, "den_duong", {"arrays": bulb_arr}, hx * Transform3D(Basis(), bp))
		if not stake2.is_empty():
			_vl_put(acc, "tiles", stake2["tiles"], hx * Transform3D(Basis().scaled(Vector3(0.3, 0.2 / float(stake2["aabb"].end.y), 0.3)),
				bp + Vector3(0, 0.04, 0)), 0.0, -1e9, Color(0.18, 0.15, 0.12), 5)
		_vl_pool(acc, hx * (bp + Vector3(0, -0.1, -0.09)), 1.7, hx.basis * Vector3.BACK)
		_vl_pool(acc, hx * Vector3(dp.x, float(door["floor"]) + 0.04, dp.z + 1.3), 3.8, hx.basis * Vector3.UP, false)
		n_porch += 1
	vl_counts["porch_lights"] = n_porch

	var lines_at := _vl_take_batches("day_phoi")
	var n_old := lines_at.size()
	for i in range(0, dr["houses"].size(), 2):
		var h: Array = dr["houses"][i]
		if (h.size() > 4 and String(h[4]) == "thi_tran") or h.size() <= 4 or _vl_win(h[0], h[1]):
			continue
		var hp := Vector3(h[0], 0, h[1])
		var near := false
		for xf: Transform3D in lines_at:
			if Vector2(xf.origin.x - hp.x, xf.origin.z - hp.z).length() < 14.0:
				near = true
				break
		if near:
			continue
		var b := Basis(Vector3.UP, deg_to_rad(float(h[2])))
		var at := hp + b * Vector3(-5.2 if i % 4 == 0 else 5.2, 0, -1.0)
		lines_at.append(Transform3D(b * Basis(Vector3.UP, PI / 2.0), _ground(at.x, at.z)))
	for xf: Transform3D in lines_at:
		_vl_put(acc, "tiles", phoi["tiles"], xf, 1.0)
	vl_counts["washing_lines"] = "%d (%d moved from the static batches, %d new)" % [lines_at.size(), n_old, lines_at.size() - n_old]

	var tall := 0.0
	if not coco.is_empty():
		var fp := _ground(VL_TALL_POLE.x, VL_TALL_POLE.y)
		tall = 2.0 * float(coco["aabb"].end.y)
		_vl_put(acc, "tiles", coco["tiles"], Transform3D(Basis().scaled(Vector3(0.9, 2.0, 0.9)), fp - Vector3(0, 0.1, 0)),
			0.0, -1e9, Color(0.86, 0.76, 0.5), 13)
		var foot := BoxMesh.new()
		foot.size = Vector3(1.1, 0.5, 1.1)
		_vl_put(acc, "tiles", {"arrays": foot.get_mesh_arrays()}, Transform3D(Basis(), fp + Vector3(0, 0.2, 0)), 0.0, -1e9,
			Color(0.55, 0.53, 0.5), 6)
		_vl_flag(acc, fp + Vector3(0, tall - 0.15, 0), 2.6)
	var n_ban := 0
	for tg: Vector2 in [Vector2(-150, -136), Vector2(-96, -214)]:
		var near_sp := spots.duplicate()
		near_sp.sort_custom(func(a, b): return Vector2(a[0].x, a[0].z).distance_squared_to(tg) < Vector2(b[0].x, b[0].z).distance_squared_to(tg))
		for k in mini(5, near_sp.size()):
			var sp: Array = near_sp[k]
			if Vector2(sp[0].x, sp[0].z).distance_to(tg) > 70.0:
				break
			var ft := (ptop - 0.9) if spots.find(sp) < n_grey else VL_POST_H - 0.05
			_vl_flag(acc, sp[0] + Vector3(0, ft, 0), 1.1, true)
			n_ban += 1
	vl_counts["banners"] = n_ban
	vl_counts["flagpole_m"] = snappedf(tall, 0.1)
	_vl_build(acc)
	print("vlight: ", vl_counts, " in %d ms" % (Time.get_ticks_msec() - t0))

func _vl_src(name_: String) -> Dictionary:
	if not ResourceLoader.exists(HomeKit.DIR + name_ + ".glb"):
		return {}
	var g: Node = load(HomeKit.DIR + name_ + ".glb").instantiate()
	var out := {}
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		if mi.get_parent().name == &"Far":
			continue
		out["aabb"] = mi.mesh.get_aabb()
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var arr := mi.mesh.surface_get_arrays(s)
			var nm := m.resource_name if m else "tiles"
			out[nm] = {"arrays": arr}
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bb := AABB(vs[0], Vector3.ZERO)
			for v in vs:
				bb = bb.expand(v)
			out[nm + "_aabb"] = bb
		break
	g.free()
	return out

func _vl_put(acc: Dictionary, key: String, src: Dictionary, xf: Transform3D, sway := 0.0, ymin := -1e9,
		tint := Color(0, 0, 0, 0), layer := 2, crop := AABB()) -> void:
	var arr: Array = src["arrays"]
	if not acc.has(key):
		acc[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "t": PackedFloat32Array(), "c": PackedColorArray(),
			"uv": PackedVector2Array(), "uv2": PackedVector2Array(), "i": PackedInt32Array()}
	var a: Dictionary = acc[key]
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ts = arr[Mesh.ARRAY_TANGENT]
	var cs = arr[Mesh.ARRAY_COLOR]
	var uvs = arr[Mesh.ARRAY_TEX_UV]
	var ids = arr[Mesh.ARRAY_INDEX]
	if ids == null or (ids as PackedInt32Array).is_empty():
		ids = PackedInt32Array(range(vs.size()))
	var base: int = (a["v"] as PackedVector3Array).size()
	for j in vs.size():
		var v := vs[j]
		a["v"].append(xf * v)
		a["n"].append((xf.basis * ns[j]).normalized())
		if ts != null and (ts as PackedFloat32Array).size() >= vs.size() * 4:
			var tv := (xf.basis * Vector3(ts[j * 4], ts[j * 4 + 1], ts[j * 4 + 2])).normalized()
			a["t"].append_array([tv.x, tv.y, tv.z, ts[j * 4 + 3]])
		else:
			var tv := (xf.basis * Vector3.RIGHT).normalized()
			a["t"].append_array([tv.x, tv.y, tv.z, 1.0])
		if tint != Color(0, 0, 0, 0):
			a["c"].append(Color(tint.r, tint.g, tint.b, (layer + 0.5) / 64.0))
		elif cs != null and (cs as PackedColorArray).size() == vs.size():
			a["c"].append(cs[j])
		else:
			a["c"].append(Color(1, 1, 1, (layer + 0.5) / 64.0))
		a["uv"].append(uvs[j] if uvs != null and (uvs as PackedVector2Array).size() == vs.size() else Vector2.ZERO)
		var w := 0.0
		if sway > 0.0 and absf(v.x) < 0.9 and v.y < 1.3:
			w = clampf((1.32 - v.y) / 0.75, 0.0, 1.0) * sway
		a["uv2"].append(Vector2(w, 0.0))
	for k in range(0, (ids as PackedInt32Array).size(), 3):
		if ymin > -1e8 and (vs[ids[k]].y < ymin or vs[ids[k + 1]].y < ymin or vs[ids[k + 2]].y < ymin):
			continue
		if crop.size != Vector3.ZERO and not (crop.has_point(vs[ids[k]]) and crop.has_point(vs[ids[k + 1]]) and crop.has_point(vs[ids[k + 2]])):
			continue
		a["i"].append_array([base + ids[k], base + ids[k + 1], base + ids[k + 2]])

func _vl_lantern_paint(a: Dictionary, v0: int, src: Dictionary, lo: AABB) -> void:
	var vs: PackedVector3Array = src["arrays"][Mesh.ARRAY_VERTEX]
	var cs: PackedColorArray = a["c"]
	var paper := Color("f6d9a8").srgb_to_linear()
	var cap := Color("3a1c14").srgb_to_linear()
	var c0 := Vector2(lo.get_center().x, lo.get_center().z)
	for j in vs.size():
		var i := v0 + j
		if i >= cs.size():
			break
		var v := vs[j]
		var t := clampf((v.y - lo.position.y) / maxf(lo.size.y, 0.001), 0.0, 1.0)
		var col := paper
		if t < 0.2 or t > 0.82:
			col = cap
		else:
			var ang := atan2(v.z - c0.y, v.x - c0.x)
			var rib := 0.5 + 0.5 * cos(ang * 4.0)
			col = paper.lerp(paper * Color(0.62, 0.48, 0.34), smoothstep(0.6, 0.95, rib) * 0.8)
		cs[i] = Color(col.r, col.g, col.b, cs[i].a)
	a["c"] = cs

func _vl_pool(acc: Dictionary, c: Vector3, size: float, face := Vector3.UP, on_ground := true) -> void:
	if not acc.has("pool"):
		acc["pool"] = {"v": PackedVector3Array(), "uv": PackedVector2Array(), "i": PackedInt32Array()}
	var a: Dictionary = acc["pool"]
	var base: int = (a["v"] as PackedVector3Array).size()
	var u := Vector3.RIGHT if absf(face.y) > 0.5 else Vector3.UP.cross(face).normalized()
	var w := face.cross(u).normalized() if absf(face.y) > 0.5 else Vector3.UP
	if absf(face.y) > 0.5:
		w = Vector3.BACK
	for j in 5:
		for i in 5:
			var p := c + u * (i / 4.0 - 0.5) * size + w * (j / 4.0 - 0.5) * size
			if absf(face.y) > 0.5 and on_ground:
				p.y = height_at(p.x, p.z) + 0.07
			a["v"].append(p)
			a["uv"].append(Vector2(i / 4.0, j / 4.0))
	for j in 4:
		for i in 4:
			var q := base + j * 5 + i
			a["i"].append_array([q, q + 1, q + 5, q + 1, q + 6, q + 5])

func _vl_flag(acc: Dictionary, top: Vector3, size: float, short := false) -> void:
	if not acc.has("flag"):
		acc["flag"] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "i": PackedInt32Array()}
	var a: Dictionary = acc["flag"]
	var base: int = (a["v"] as PackedVector3Array).size()
	var fly := Vector3(0.94, 0.0, 0.33).normalized()
	var hgt := size * (0.62 if short else 0.75)
	for j in 7:
		for i in 15:
			var p := top + fly * (0.06 + size * i / 14.0) - Vector3(0, hgt * j / 6.0, 0)
			a["v"].append(p)
			a["n"].append(fly.cross(Vector3.UP).normalized() * -1.0)
			a["uv"].append(Vector2(i / 14.0, j / 6.0))
	for j in 6:
		for i in 14:
			var q := base + j * 15 + i
			a["i"].append_array([q, q + 1, q + 15, q + 1, q + 16, q + 15])

func _vl_build(acc: Dictionary) -> void:
	var tris := 0
	if acc.has("tiles"):
		var mi := _vl_mesh(acc["tiles"], _vl_tiles_mat(), "vl_tiles")
		tris += (acc["tiles"]["i"] as PackedInt32Array).size() / 3
		mi.visibility_range_end = 420.0
	for key: String in ["den_duong", "den_long"]:
		if acc.has(key):
			var mi := _vl_mesh(acc[key], HomeKit.material(key, null), "vl_bulbs_" + key)
			mi.visibility_range_end = 320.0
			mi.visible = HomeKit._night > 0.01
			HomeKit._pools.append(mi)
	if acc.has("pool"):
		var tmp := Node3D.new()
		HomeKit._add_pools(tmp, [])
		tmp.free()
		var mi := _vl_mesh(acc["pool"], HomeKit._pool_mat, "vl_pools")
		mi.visibility_range_end = 260.0
		mi.visible = HomeKit._night > 0.01
		HomeKit._pools.append(mi)
	if acc.has("flag"):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/co_hoi.gdshader")
		m.set_shader_parameter("tex", load("res://props/hometown/co_ngu_sac.png"))
		m.set_shader_parameter("width", 1.4)
		m.set_shader_parameter("amp", 0.22)
		var mi := _vl_mesh(acc["flag"], m, "vl_flags")
		mi.visibility_range_end = 300.0
	vl_counts["tiles_tris"] = tris

func _vl_mesh(a: Dictionary, mat: Material, name_: String) -> MeshInstance3D:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = a["v"]
	if a.has("n"):
		arr[Mesh.ARRAY_NORMAL] = a["n"]
	else:
		var ns := PackedVector3Array()
		ns.resize((a["v"] as PackedVector3Array).size())
		ns.fill(Vector3.UP)
		arr[Mesh.ARRAY_NORMAL] = ns
	if a.has("t") and name_ == "vl_tiles":
		arr[Mesh.ARRAY_TANGENT] = a["t"]
		arr[Mesh.ARRAY_COLOR] = a["c"]
		arr[Mesh.ARRAY_TEX_UV2] = a["uv2"]
	arr[Mesh.ARRAY_TEX_UV] = a["uv"]
	arr[Mesh.ARRAY_INDEX] = a["i"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.name = name_
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

var _vl_mat: ShaderMaterial

func _vl_tiles_mat() -> ShaderMaterial:
	if _vl_mat:
		return _vl_mat
	var code := HomeKit.TILES.code
	var inc := "#include \"res://shaders/sky_light.gdshaderinc\""
	code = code.replace(inc, inc + "\n#include \"res://shaders/wind_gust.gdshaderinc\"")
	code = code.replace("void vertex() {", "void vertex() {\n\tif (UV2.x > 0.0) {\n\t\tvec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n" +
		"\t\tfloat g = wg_gust(wp.xz);\n\t\tfloat ph = dot(wp.xz, vec2(0.71, 0.53));\n\t\tvec3 d = wg_dir3();\n" +
		"\t\tVERTEX += d * UV2.x * (0.05 + 0.2 * g) * (0.65 + 0.35 * sin(TIME * 2.1 + ph));\n" +
		"\t\tVERTEX += vec3(-d.z, 0.0, d.x) * UV2.x * 0.035 * sin(TIME * 3.4 + ph * 1.7);\n\t}")
	var sh := Shader.new()
	sh.code = code
	_vl_mat = ShaderMaterial.new()
	_vl_mat.shader = sh
	_vl_mat.set_shader_parameter("albedo_arr", load(HomeKit.DIR + "tiles_array_alb.png"))
	_vl_mat.set_shader_parameter("nrm_arr", load(HomeKit.DIR + "tiles_array_nrm.png"))
	_vl_mat.set_shader_parameter("has_ao", false)
	return _vl_mat

var _vl_doors := {}

func _vl_door(model: String) -> Dictionary:
	if _vl_doors.has(model):
		return _vl_doors[model]
	var out := {}
	var g: Node = load(HomeKit.DIR + model + ".glb").instantiate()
	var front: Array[Vector3] = []
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		if mi.get_parent().name == &"Far":
			continue
		var xf := Transform3D()
		var n: Node = mi
		while n and n != g:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m == null or not String(m.resource_name).begins_with("cua"):
				continue
			var arr := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for j in vs.size():
				if (xf.basis * ns[j]).z > 0.8:
					front.append(xf * vs[j])
	g.free()
	if front.size() >= 4:
		var y0 := 1e9
		for v in front:
			y0 = minf(y0, v.y)
		var low: Array[Vector3] = []
		for v in front:
			if v.y < y0 + 0.25:
				low.append(v)
		var zmax := -1e9
		for v in low:
			zmax = maxf(zmax, v.z)
		var xs := 0.0
		var nn := 0
		for v in low:
			if v.z > zmax - 0.3:
				xs += v.x
				nn += 1
		var dx := xs / maxi(nn, 1)
		var top := y0
		for v in front:
			if absf(v.x - dx) < 0.7 and v.z > zmax - 0.3:
				top = maxf(top, v.y)
		if top - y0 > 1.2:
			out = {"pos": Vector3(dx, top, zmax), "floor": y0}
	_vl_doors[model] = out
	return out

func _vl_face_road(q: Vector2) -> float:
	var best := Vector2.ZERO
	var bd := 1e9
	for r: Array in layout["roads"].slice(0, 4):
		for i in range(1, r.size()):
			var a := Vector2(r[i - 1][0], r[i - 1][1])
			var b := Vector2(r[i][0], r[i][1])
			var c := Geometry2D.get_closest_point_to_segment(q, a, b)
			if c.distance_squared_to(q) < bd:
				bd = c.distance_squared_to(q)
				best = c
	var d := best - q
	return atan2(d.x, d.y) if d.length() > 0.1 else 0.0

func _vl_hide_greybox_poles(poles: Array) -> void:
	for c in get_children():
		var mi := c as MultiMeshInstance3D
		if mi == null or mi.material_override != _vc or mi.multimesh == null or mi.multimesh.instance_count == 0:
			continue
		var o := mi.multimesh.get_instance_transform(0).origin + mi.position
		for pl: Array in poles:
			if absf(o.x - float(pl[0])) < 0.3 and absf(o.z - float(pl[1])) < 0.3:
				mi.queue_free()
				break

func _vl_take_batches(kind: String) -> Array:
	var out := []
	for c in get_children():
		var mi := c as MultiMeshInstance3D
		if mi == null or not String(mi.name).begins_with(kind) or mi.multimesh == null:
			continue
		for i in mi.multimesh.instance_count:
			var xf := mi.multimesh.get_instance_transform(i)
			out.append(Transform3D(xf.basis, xf.origin + mi.position))
		mi.queue_free()
	return out
