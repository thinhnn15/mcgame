extends Node3D

const CityKit := preload("res://scripts/intro/city_kit.gd")
const Tower := preload("res://scripts/intro/tower.gd")
const Street := preload("res://scripts/intro/street.gd")
const TubeHouse := preload("res://scripts/intro/tube_house.gd")
const ROOM := Vector2(9.0, 7.0)
const G := Street.STREET_Y
const STATION_AT := Vector3(0.0, G + 9.6, -15.9)
const RAIL_Y := G + 9.6
const Z0 := -15.9 - SanGa.TRK_OLD
const VIADUCT_END := 430.0
const RIVER := Vector2(436.0, 876.0)
const SPANS := 8
const DIKE := 1.2
const KARST_DIR := "res://props/hometown/karst/"

const SHOTS := [
	{"name": "roi_ga", "secs": 9.0, "look": "rain", "x": 6.15, "v": 0.0, "acc": 1.3, "vmax": 13.0, "wet": 1.0},
	{"name": "kinh_mua", "secs": 9.0, "look": "rain", "x": 95.0, "v": 13.0, "acc": 0.2, "vmax": 15.0, "wet": 1.0},
	{"name": "nhin_lai", "secs": 10.0, "look": "rain", "x": 60.0, "v": 11.0, "acc": 0.5, "vmax": 15.0, "wet": 0.8},
	{"name": "cau_sat", "secs": 14.0, "look": "clearing", "x": 470.0, "v": 15.0, "acc": 0.0, "vmax": 15.0, "wet": 0.5},
	{"name": "dong_lua", "secs": 12.0, "look": "clear", "x": 1260.0, "v": 16.0, "acc": 0.0, "vmax": 16.0, "wet": 0.12},
	{"name": "co_bay", "secs": 10.0, "look": "clear", "x": 1330.0, "v": 11.0, "acc": 0.0, "vmax": 11.0, "wet": 0.0},
	{"name": "con_do", "secs": 10.0, "look": "clear", "x": 1640.0, "v": 16.0, "acc": 0.0, "vmax": 16.0, "wet": 0.0},
	{"name": "thung_lung", "secs": 16.0, "look": "clear", "x": 1880.0, "v": 16.0, "acc": 0.0, "vmax": 16.0, "wet": 0.0},
	{"name": "vao_ham", "secs": 9.0, "look": "clear", "x": 2672.0, "v": 13.0, "acc": 0.0, "vmax": 13.0, "wet": 0.0},
]
const ThuDo := preload("res://scripts/thu_do.gd")
const WET_GLASS := preload("res://shaders/toa_rain_glass.gdshader")

var curve := Curve3D.new()
var route_len := 0.0
var track2d: PackedVector2Array = []
var river2d: PackedVector2Array = []
var kit: CityKit
var tower
var station: Node3D
var lead: Node3D
var tail: Node3D
var hero_sit: Chibi
var hero_stand: Chibi
var film: Camera3D
var sun: DirectionalLight3D
var env: Environment
var rain: Rain
var rain_spot := Node3D.new()
var water_mats: Array[StandardMaterial3D] = []
var sky_rain: ShaderMaterial
var sky_clear: ShaderMaterial
var karst_mat: ShaderMaterial
var vc_mat: StandardMaterial3D
var shot := 0
var shot_t := 0.0
var only := -1
var still_at := -1.0
var png := ""
var s_tunnel := 0.0
var seat_z := -0.8
var glass := {}
var storks: Array[Node3D] = []
var boats: Array[Node3D] = []
var speed := 0.0

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	if "--chain" in OS.get_cmdline_user_args():
		Engine.set_meta("ve_que_chain", true)
	sun = Stage.setup(self)
	env = ($WorldEnvironment as WorldEnvironment).environment
	vc_mat = StandardMaterial3D.new()
	vc_mat.vertex_color_use_as_albedo = true
	vc_mat.roughness = 0.85
	vc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_route()
	_city()
	_river()
	_bridge()
	_country()
	_track()
	_karsts()
	_plants()
	_tunnel()
	_train()
	_wildlife()
	film = Camera3D.new()
	film.far = 6000.0
	add_child(film)
	film.make_current()
	add_child(rain_spot)
	rain = Rain.new()
	rain.follow = rain_spot
	rain.sun = sun
	rain.chibis = func(): return []
	add_child(rain)
	for c in rain.get_children():
		if c is GPUParticlesCollisionBox3D:
			c.size = Vector3(400, 1, 400)
	for gp in rain.find_children("*", "GPUParticles3D", true, false):
		(gp as GPUParticles3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_skies()
	only = int(Stage.arg("--shot", "-1"))
	still_at = float(Stage.arg("--at", "-1"))
	png = Stage.arg("--png")
	_start(maxi(only, 0))
	if still_at >= 0.0:
		shot_t = still_at * float(SHOTS[shot]["secs"])
	print("hanh_trinh: built in %d ms, route %.0f m" % [Time.get_ticks_msec() - t0, route_len])

func _route() -> void:
	var pts := [Vector3(-140, RAIL_Y, Z0), Vector3(VIADUCT_END, RAIL_Y, Z0), Vector3(RIVER.y + 6.0, RAIL_Y, Z0),
		Vector3(1130, G + DIKE, Z0 + 14), Vector3(1430, G + DIKE, Z0 + 70), Vector3(1790, G + DIKE, Z0 + 30),
		Vector3(2130, G + DIKE, Z0 - 50), Vector3(2480, G + DIKE, Z0 - 20), Vector3(2800, G + DIKE, Z0 + 30),
		Vector3(3000, G + DIKE, Z0 + 40)]
	var n := pts.size()
	for i in n:
		var t := Vector3(60, 0, 0)
		if i > 2:
			t = (pts[mini(i + 1, n - 1)] - pts[i - 1]) / 6.0
		curve.add_point(pts[i], -t if i > 0 else Vector3.ZERO, t if i < n - 1 else Vector3.ZERO)
	curve.bake_interval = 0.5
	route_len = curve.get_baked_length()
	var s := 0.0
	while s < route_len:
		var p := curve.sample_baked(s)
		track2d.append(Vector2(p.x, p.z))
		s += 10.0
	s_tunnel = s_at(2790.0)

func s_at(x: float) -> float:
	var best := 0.0
	var bd := INF
	var s := 0.0
	while s < route_len:
		var d := absf(curve.sample_baked(s).x - x)
		if d < bd:
			bd = d
			best = s
		s += 1.0
	return best

func frame_at(s: float) -> Transform3D:
	var a := curve.sample_baked(maxf(s - 2.0, 0.0), true)
	var b := curve.sample_baked(minf(s + 2.0, route_len), true)
	var fwd := (b - a).normalized()
	return Transform3D(Basis.looking_at(-fwd, Vector3.UP), curve.sample_baked(s, true))

static func _dist(p: Vector2, line: PackedVector2Array) -> float:
	var d := INF
	for q in line:
		d = minf(d, p.distance_squared_to(q))
	return sqrt(d)

func _city() -> void:
	station = SanGa.place(self, STATION_AT, 90.0)
	SanGa.viaducts(station, -125.0, VIADUCT_END)
	SanGa.dress(station)
	var city := Node3D.new()
	city.name = "City"
	add_child(city)
	kit = CityKit.new(city)
	var zf := -ROOM.y / 2.0 - 0.2
	tower = Tower.new()
	tower.build(kit, zf, ROOM.x / 2.0)
	for m: ShaderMaterial in kit.window_mats:
		if is_equal_approx(float(m.get_shader_parameter("lit_rate")), 0.1):
			m.set_shader_parameter("lit_rate", 0.012)
	var street = Street.new()
	street.detail_range = Vector2(-45.0, 45.0)
	street.build(kit, zf - Tower.PIER_D, Tower.HX)
	_outskirts()
	_skyline()
	kit.finish()
	_flat(Rect2(-900, -2500, RIVER.x + 900 + 8, 5000), G - 0.06, Color("6e7468"))

func _outskirts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var th = TubeHouse.new()
	th.setup(kit, rng, G)
	for side: int in [1, -1]:
		var x := 172.0
		while x < RIVER.x - 12.0:
			var w := rng.randf_range(4.0, 6.5)
			var floors := rng.randi_range(2, 5) if x < 330.0 else rng.randi_range(1, 3)
			th.house({"x0": x, "w": w, "floors": floors, "facing": -side, "kind": "shop", "left_h": 0.0, "right_h": 0.0,
				"z": Z0 + side * rng.randf_range(15.0, 19.0)})
			x += w + (0.0 if rng.randf() < 0.75 else rng.randf_range(3.0, 9.0))
	th.commit()
	var far = TubeHouse.Batch.new()
	far.cell = 170.0
	var cols := [Color("8a8f9a"), Color("a39a8e"), Color("7f8a86"), Color("9a8e96")]
	for i in 90:
		var p := Vector2(rng.randf_range(175.0, RIVER.x - 20.0), rng.randf_range(-260.0, 260.0))
		if absf(p.y - Z0) < 34.0:
			continue
		var bh := rng.randf_range(10.0, 34.0) * lerpf(1.0, 0.5, (p.x - 175.0) / 260.0)
		var c: Color = cols[rng.randi() % cols.size()]
		var win: Material = kit.windows({"procedural": true, "lit_rate": 0.1, "seed": float(i % 4) * 7.0,
			"cell": Vector2(3.0, 3.2), "wall_col": c, "win_size": Vector2(0.55, 0.5), "lit_energy": 0.8,
			"glass_top": c.lightened(0.12), "glass_bottom": c.darkened(0.25)})
		far.box(win, Transform3D(Basis(), Vector3(p.x, G + bh / 2.0, p.y)),
			Vector3(rng.randf_range(10, 20), bh, rng.randf_range(10, 18)),
			TubeHouse.Batch.all_faces(Rect2(0, 0, 1, 1), ["front", "back", "left", "right", "top"]), Color.WHITE)
	far.commit(kit.root)

func _skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var far = TubeHouse.Batch.new()
	far.cell = 400.0
	var cols := [Color("5a5f78"), Color("666a80"), Color("4e5670"), Color("6c6478"), Color("7a8090")]
	for i in 170:
		var p := Vector2(rng.randf_range(-900.0, 380.0), rng.randf_range(-900.0, 900.0))
		if p.x > -180.0 and p.x < 175.0 and absf(p.y) < 180.0:
			continue
		if p.x > 170.0 and absf(p.y - Z0) < 280.0:
			continue
		var mid := 1.0 - clampf(p.length() / 1100.0, 0.0, 1.0)
		var bh := rng.randf_range(30.0, 70.0) + mid * rng.randf_range(20.0, 110.0)
		var c: Color = cols[rng.randi() % cols.size()]
		var win: Material = kit.windows({"procedural": true, "lit_rate": 0.08, "seed": float(i % 5) * 5.0,
			"cell": Vector2(3.2, 3.4), "wall_col": c, "win_size": Vector2(0.6, 0.55), "lit_energy": 0.7,
			"glass_top": c.lightened(0.15), "glass_bottom": c.darkened(0.2)})
		far.box(win, Transform3D(Basis(), Vector3(p.x, G + bh / 2.0, p.y)),
			Vector3(rng.randf_range(16, 34), bh, rng.randf_range(16, 30)),
			TubeHouse.Batch.all_faces(Rect2(0, 0, 1, 1), ["front", "back", "left", "right", "top"]), Color.WHITE)
	far.commit(kit.root)

func _water_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.05
	m.metallic_specular = 0.6
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 3.0
	nt.width = 512
	nt.height = 512
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	nt.noise = fn
	m.normal_enabled = true
	m.normal_texture = nt
	m.normal_scale = 0.25
	m.uv1_scale = Vector3(0.08, 0.08, 1)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	water_mats.append(m)
	return m

func _river() -> void:
	var w := _water_mat(Color("3d5560"))
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(RIVER.y - RIVER.x + 20, 6000)
	mi.mesh = pm
	mi.material_override = w
	mi.position = Vector3((RIVER.x + RIVER.y) / 2.0, G - 1.6, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: Array in [[RIVER.x, 1.0], [RIVER.y, -1.0]]:
		var x0: float = side[0]
		var dir: float = side[1]
		_quad(st, Vector3(x0 - dir * 4.0, G, -3000), Vector3(x0 - dir * 4.0, G, 3000),
			Vector3(x0 + dir * 6.0, G - 2.2, 3000), Vector3(x0 + dir * 6.0, G - 2.2, -3000), Color("7d7055"))
	st.generate_normals()
	var bank := MeshInstance3D.new()
	bank.mesh = st.commit()
	bank.material_override = vc_mat
	add_child(bank)

func _span_mesh(L: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var iron := Color("5b7a80")
	var dark := Color("3e5357")
	var bw := 3.3
	var n := 8
	var tops := []
	for i in n + 1:
		var x := L * i / n
		var ht := 0.0 if i == 0 or i == n else 5.2 + 2.6 * sin(PI * float(i) / n)
		tops.append(ht)
	for z: float in [-bw, bw]:
		_beam(st, Vector3(0, -0.6, z), Vector3(L, -0.6, z), 0.45, 0.7, iron)
		for i in n:
			var x0 := L * i / n
			var x1 := L * (i + 1) / n
			if i >= 1 and i < n - 1:
				_beam(st, Vector3(x0, tops[i] - 0.6, z), Vector3(x1, tops[i + 1] - 0.6, z), 0.5, 0.55, iron)
			var lo := Vector3(x0 if i % 2 == 0 else x1, -0.6, z)
			var hi_i := i + 1 if i % 2 == 0 else i
			if hi_i > 0 and hi_i < n:
				_beam(st, lo, Vector3(L * hi_i / n, tops[hi_i] - 0.6, z), 0.3, 0.3, iron)
			var hi_j := i if i % 2 == 0 else i + 1
			var lo2 := Vector3(x1 if i % 2 == 0 else x0, -0.6, z)
			if hi_j > 0 and hi_j < n:
				_beam(st, lo2, Vector3(L * hi_j / n, tops[hi_j] - 0.6, z), 0.3, 0.3, iron)
		for i in range(1, n):
			_beam(st, Vector3(L * i / n, -0.6, z), Vector3(L * i / n, tops[i] - 0.6, z), 0.22, 0.22, dark)
	for i in range(1, n):
		var x := L * i / n
		_beam(st, Vector3(x, tops[i] - 0.5, -bw), Vector3(x, tops[i] - 0.5, bw), 0.25, 0.35, dark)
		if i < n - 1:
			_beam(st, Vector3(x, tops[i] - 0.5, -bw), Vector3(L * (i + 1) / n, tops[i + 1] - 0.5, bw), 0.15, 0.15, dark)
	for i in n + 1:
		_beam(st, Vector3(L * i / n, -0.85, -bw), Vector3(L * i / n, -0.85, bw), 0.35, 0.5, dark)
	_beam(st, Vector3(0, -0.35, 0), Vector3(L, -0.35, 0), 3.4, 0.3, Color("6a645c"))
	for z: float in [-2.6, 2.6]:
		_beam(st, Vector3(0, 0.6, z), Vector3(L, 0.6, z), 0.06, 0.06, dark)
	st.generate_normals()
	return st.commit()

func _bridge() -> void:
	var L := (RIVER.y - RIVER.x + 4.0) / SPANS
	var mesh := _span_mesh(L)
	for k in SPANS:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = vc_mat
		mi.position = Vector3(RIVER.x - 2.0 + k * L, RAIL_Y, Z0)
		add_child(mi)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone := Color("a69b8a")
	for k in SPANS + 1:
		var x := RIVER.x - 2.0 + k * L
		var wide := 3.0 if k > 0 and k < SPANS else 5.0
		_beam(st, Vector3(x, G - 4.0, Z0), Vector3(x, RAIL_Y - 1.0, Z0), wide, 8.6, stone)
		_beam(st, Vector3(x, RAIL_Y - 1.4, Z0), Vector3(x, RAIL_Y - 0.9, Z0), wide + 0.6, 9.4, stone.darkened(0.15))
		if k > 0 and k < SPANS:
			for dz: float in [-5.4, 5.4]:
				_beam(st, Vector3(x, G - 4.0, Z0 + dz), Vector3(x, G + 1.5, Z0 + dz * 1.05), 2.0, 2.2, stone.darkened(0.08))
	st.generate_normals()
	var piers := MeshInstance3D.new()
	piers.mesh = st.commit()
	piers.material_override = vc_mat
	add_child(piers)

func _country() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5200, 6000)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	ground.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/paddy_film.gdshader")
	gm.set_shader_parameter("flood_box", Vector4(1280.0, Z0 + 40.0, 1620.0, Z0 + 260.0))
	ground.material_override = gm
	ground.position = Vector3(RIVER.y + 2600 - 8, G, 0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	_embankment()
	var w := _water_mat(Color("2f4a46"))
	w.roughness = 0.25
	w.metallic_specular = 0.3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bank := SurfaceTool.new()
	bank.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := s_at(1500.0)
	var prev := []
	while s < route_len - 60.0:
		var f := frame_at(s)
		var right := f.basis.x
		var off := 75.0 + 25.0 * sin(s / 170.0)
		var mid := f.origin + right * off
		mid.y = G
		river2d.append(Vector2(mid.x, mid.z))
		var hw := 20.0 + 6.0 * sin(s / 90.0)
		var cur := [mid - right * hw, mid + right * hw, mid - right * (hw + 5.0), mid + right * (hw + 5.0)]
		if not prev.is_empty():
			var y := Vector3(0, 0.08, 0)
			_quad(st, prev[0] + y, cur[0] + y, cur[1] + y, prev[1] + y, Color.WHITE)
			var yb := Vector3(0, 0.05, 0)
			_quad(bank, prev[2] + yb, cur[2] + yb, cur[0] + yb, prev[0] + yb, Color("6f8a4a"))
			_quad(bank, prev[1] + yb, cur[1] + yb, cur[3] + yb, prev[3] + yb, Color("6f8a4a"))
		prev = cur
		s += 10.0
	st.generate_normals()
	var rv := MeshInstance3D.new()
	rv.mesh = st.commit()
	rv.material_override = w
	rv.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rv)
	bank.generate_normals()
	var bk := MeshInstance3D.new()
	bk.mesh = bank.commit()
	bk.material_override = vc_mat
	add_child(bk)

func _embankment() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := s_at(RIVER.y + 2.0)
	var prev := []
	var top_w := 2.4
	while s <= route_len:
		var f := frame_at(s)
		var r := f.basis.x
		var p := f.origin - Vector3(0, 0.25, 0)
		var h := p.y - (G - 0.2)
		var foot := top_w + h * 1.6
		var cur := [p - r * foot + Vector3(0, -h, 0), p - r * top_w, p + r * top_w, p + r * foot + Vector3(0, -h, 0)]
		if not prev.is_empty():
			_quad(st, prev[0], cur[0], cur[1], prev[1], Color("6c8c45"))
			_quad(st, prev[1], cur[1], cur[2], prev[2], Color("8a8170"))
			_quad(st, prev[2], cur[2], cur[3], prev[3], Color("6c8c45"))
		prev = cur
		s += 4.0
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = vc_mat
	add_child(mi)

func _track() -> void:
	var g: Node3D = load(HomeKit.DIR + "duong_ray.glb").instantiate()
	var mesh: Mesh = null
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		mesh = mi.mesh
		break
	g.free()
	var mat := HomeKit.material("tiles", load(HomeKit.DIR + "duong_ray_ao.png"))
	var s := s_at(VIADUCT_END + 2.0)
	var chunk: Array[Transform3D] = []
	while s < route_len - 2.0:
		var f := frame_at(s + 2.0)
		f.origin.y -= 0.25
		chunk.append(f)
		s += 4.0
		if chunk.size() >= 50 or s >= route_len - 2.0:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = chunk.size()
			for i in chunk.size():
				mm.set_instance_transform(i, chunk[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = mat
			add_child(mmi)
			chunk.clear()

func _karsts() -> void:
	var meta: Array = JSON.parse_string(FileAccess.get_file_as_string(KARST_DIR + "karst.json"))
	var meshes := []
	for k in meta.size():
		meshes.append(_karst_mesh(k))
	karst_mat = ShaderMaterial.new()
	karst_mat.shader = preload("res://shaders/karst.gdshader")
	karst_mat.set_shader_parameter("mist_top", G + 22.0)
	karst_mat.set_shader_parameter("haze_near", 450.0)
	karst_mat.set_shader_parameter("haze_far", 3200.0)
	karst_mat.set_shader_parameter("haze_max", 0.6)
	karst_mat.set_shader_parameter("mist_max", 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var sites := []
	var massif := FastNoiseLite.new()
	massif.frequency = 0.0035
	massif.seed = 5
	for i in 4000:
		var p := Vector2(rng.randf_range(1050.0, 3400.0), rng.randf_range(-1100.0, 1100.0))
		var valley := smoothstep(1500.0, 1800.0, p.x)
		var r := rng.randf_range(14.0, 42.0) * lerpf(0.8, 1.1, valley)
		var keep := lerpf(45.0, 110.0, valley) + r
		var dt := _dist(p, track2d)
		if dt < keep:
			continue
		if not river2d.is_empty() and _dist(p, river2d) < r + 30.0:
			continue
		var want := lerpf(0.06, 0.4, valley) * (1.0 if dt < 700.0 else 0.6)
		want *= smoothstep(-0.05, 0.35, massif.get_noise_2d(p.x, p.y))
		if dt < 250.0 and valley < 0.5:
			want *= 0.15
		if rng.randf() > want:
			continue
		var clash := false
		for o: Array in sites:
			if p.distance_to(Vector2(o[0], o[1])) < (r + o[2]) * 0.8:
				clash = true
				break
		if clash:
			continue
		sites.append([p.x, p.y, r, r * rng.randf_range(2.3, 3.8)])
	for i in 60:
		var a := rng.randf_range(-0.5, 0.5) * PI + (0.0 if i % 2 == 0 else PI)
		var p := Vector2(2300.0, 0.0) + Vector2(cos(a) * rng.randf_range(1300, 2000), sin(a) * rng.randf_range(1400, 2200))
		if p.x < 1000.0:
			continue
		var r := rng.randf_range(70.0, 140.0)
		sites.append([p.x, p.y, r, r * rng.randf_range(1.7, 2.4)])
	for site: Array in sites:
		var r: float = site[2]
		var h: float = site[3]
		var k := 0
		for j in meta.size():
			if absf(meta[j]["aspect"] - h / r) < absf(meta[k]["aspect"] - h / r):
				k = j
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[k]
		mi.material_override = karst_mat
		mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r, h / meta[k]["aspect"], r)),
			Vector3(site[0], G - 1.0, site[1]))
		add_child(mi)
	print("hanh_trinh: %d karst towers" % sites.size())

var _karsts_green := {}
func _karst_mesh(k: int) -> Mesh:
	if _karsts_green.has(k):
		return _karsts_green[k]
	var src := _first_mesh(KARST_DIR + "karst_%d.glb" % k)
	var arr := src.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var top := 0.0
	for v in vs:
		top = maxf(top, v.y)
	var nz := FastNoiseLite.new()
	nz.frequency = 1.6
	nz.seed = 17 + k
	var green := Color("5e8c4e").srgb_to_linear()
	var green_b := Color("7aa45a").srgb_to_linear()
	var green_d := Color("4a7440").srgb_to_linear()

	var nsum := {}
	for i in vs.size():
		nsum[vs[i]] = nsum.get(vs[i], Vector3.ZERO) + ns[i]
	for i in vs.size():
		var v := vs[i]
		var n: Vector3 = (nsum[v] as Vector3).normalized()
		var patch := nz.get_noise_3d(v.x, v.y * 0.6, v.z)
		var g := smoothstep(0.1, 0.4, n.y) + smoothstep(-0.05, 0.2, patch) + smoothstep(0.82, 0.92, v.y / top)
		g = clampf(g, 0.0, 1.0)
		var leaf := green.lerp(green_b, 0.5 + 0.5 * nz.get_noise_3d(v.x * 3.0, v.y * 3.0, v.z * 3.0))
		leaf = leaf.lerp(green_d, smoothstep(0.0, -0.6, n.y))
		cs[i] = (cs[i] * 0.88).lerp(leaf, g)
		cs[i].a = 1.0
		if g > 0.5:
			ns[i] = n
	arr[Mesh.ARRAY_COLOR] = cs
	arr[Mesh.ARRAY_NORMAL] = ns
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_karsts_green[k] = am
	return am

func _first_mesh(path: String) -> Mesh:
	var g: Node3D = load(path).instantiate()
	var m: Mesh = null
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		m = mi.mesh
		break
	g.free()
	return m

func _plants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var kinds := ["cay/bui_tre", "cay/bui_tre", "cay/cay_keo", "cay/bui_dai_a", "cay/bui_dai_b"]
	var s := s_at(RIVER.y + 30.0)
	while s < s_tunnel - 30.0:
		var f := frame_at(s)
		if rng.randf() < 0.55:
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			for j in rng.randi_range(1, 4):
				var p := f.origin + f.basis.x * side * rng.randf_range(9.0, 22.0) + f.basis.z * rng.randf_range(-8, 8)
				var t := HomeKit.place_plant(self, kinds[rng.randi() % kinds.size()], Vector3(p.x, G, p.z), rng.randf() * 360.0)
				t.scale = Vector3.ONE * rng.randf_range(0.9, 1.4)
		s += rng.randf_range(18.0, 40.0)
	for h in 26:
		var c := Vector2(rng.randf_range(950.0, 2700.0), rng.randf_range(-700.0, 700.0))
		if _dist(c, track2d) < 60.0 or (not river2d.is_empty() and _dist(c, river2d) < 50.0):
			continue
		for j in rng.randi_range(10, 22):
			var a := rng.randf() * TAU
			var p := c + Vector2(cos(a), sin(a)) * rng.randf_range(4.0, 26.0)
			var kind := "cay/bui_tre" if rng.randf() < 0.6 else "cay/cay_keo"
			var t := HomeKit.place_plant(self, kind, Vector3(p.x, G, p.y), rng.randf() * 360.0)
			t.scale = Vector3.ONE * rng.randf_range(1.0, 1.6)

func _tunnel() -> void:
	var f := frame_at(s_tunnel)
	var o := f.origin
	var r := f.basis.x
	var fw := -f.basis.z
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone := Color("9c9384")
	for side: float in [-1.0, 1.0]:
		var c := o + r * side * 3.7 + Vector3(0, 2.3, 0)
		_beam(st, c - Vector3(0, 2.6, 0), c + Vector3(0, 2.6, 0), 1.4, 2.6, stone)
	for k in 9:
		var a0 := PI * k / 9.0
		var a1 := PI * (k + 1) / 9.0
		var p0 := o + Vector3(0, 4.9, 0) + r * cos(a0) * 3.7 + Vector3(0, sin(a0) * 2.6, 0)
		var p1 := o + Vector3(0, 4.9, 0) + r * cos(a1) * 3.7 + Vector3(0, sin(a1) * 2.6, 0)
		_beam(st, p0, p1, 2.6, 1.3, stone.darkened(0.06 * (k % 2)))
	_beam(st, o + Vector3(0, 8.6, 0) - r * 5.6, o + Vector3(0, 8.6, 0) + r * 5.6, 0.8, 2.9, stone.darkened(0.12))
	st.generate_normals()
	var portal := MeshInstance3D.new()
	portal.mesh = st.commit()
	portal.material_override = vc_mat
	add_child(portal)
	var hole := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6.2, 7.4, 40.0)
	hole.mesh = bm
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.03, 0.03, 0.035)
	black.cull_mode = BaseMaterial3D.CULL_DISABLED
	hole.material_override = black
	hole.transform = Transform3D(f.basis, o + Vector3(0, 3.4, 0) - fw * 20.6)
	add_child(hole)
	_cliff(o - fw * 1.0, r, fw)
	var meta: Array = JSON.parse_string(FileAccess.get_file_as_string(KARST_DIR + "karst.json"))
	var tops := [[-40.0, 70.0, 55.0, 190.0, 1], [55.0, 90.0, 60.0, 175.0, 6], [-150.0, 60.0, 50.0, 150.0, 3],
		[160.0, 70.0, 55.0, 160.0, 5], [0.0, 170.0, 80.0, 230.0, 7]]
	for w: Array in tops:
		var p: Vector3 = o + r * float(w[0]) - fw * float(w[1])
		var k: int = w[4]
		var mi := MeshInstance3D.new()
		mi.mesh = _karst_mesh(k)
		mi.material_override = karst_mat
		mi.transform = Transform3D(Basis(Vector3.UP, float(k)).scaled(Vector3(w[2], float(w[3]) / meta[k]["aspect"], w[2])),
			Vector3(p.x, G - 1.0, p.z))
		add_child(mi)

func _cliff(at: Vector3, r: Vector3, fw: Vector3) -> void:
	var nz := FastNoiseLite.new()
	nz.frequency = 0.035
	nz.fractal_octaves = 4
	nz.seed = 3
	var cols := 106
	var rows := 48
	var pts := PackedVector3Array()
	for j in rows + 1:
		var y := -3.0 + 143.0 * pow(float(j) / rows, 1.15)
		for i in cols + 1:
			var u := -210.0 + 420.0 * i / cols
			var hole := Vector2(u / 7.0, maxf(y - 4.0, 0.0) / 7.5).length()
			var crag := nz.get_noise_2d(u, y) * 13.0 + nz.get_noise_2d(u * 0.3, y * 0.3) * 18.0
			crag *= smoothstep(1.0, 2.6, hole)
			var lean := y * 0.22 + pow(absf(u) / 210.0, 2.0) * 90.0
			var top := 143.0 - 30.0 * (0.5 + 0.5 * sin(u / 37.0)) - 20.0 * absf(nz.get_noise_1d(u * 2.0))
			var yy := minf(y, top + 3.0 * float(j) / rows)
			pts.append(at + r * u + Vector3(0, yy + (G - at.y), 0) + fw * (crag * 0.8 - lean - maxf(y - top, 0.0) * 1.5))
	var norms := PackedVector3Array()
	norms.resize(pts.size())
	var colr := PackedColorArray()
	colr.resize(pts.size())
	var rock := Color("bdb6a8").srgb_to_linear()
	var rock_d := Color("8f8a80").srgb_to_linear()
	var green := Color("5e8c4e").srgb_to_linear()
	var green_b := Color("7aa45a").srgb_to_linear()
	for j in rows + 1:
		for i in cols + 1:
			var k := j * (cols + 1) + i
			var a := pts[j * (cols + 1) + mini(i + 1, cols)] - pts[j * (cols + 1) + maxi(i - 1, 0)]
			var b := pts[mini(j + 1, rows) * (cols + 1) + i] - pts[maxi(j - 1, 0) * (cols + 1) + i]
			var n := b.cross(a).normalized()
			if n.dot(fw) < 0.0:
				n = -n
			norms[k] = n
			var ledge := smoothstep(0.25, 0.55, n.y) + smoothstep(0.55, 0.75, nz.get_noise_2d(i * 7.0, j * 9.0) + 0.5) * 0.6
			var p := pts[k]
			var foot := 1.0 - smoothstep(G + 2.0, G + 9.0, p.y)
			var gm := clampf(maxf(ledge, foot) + (1.0 - smoothstep(0.0, 0.25, float(rows - j) / rows)) * 0.8, 0.0, 1.0)
			var rc := rock.lerp(rock_d, 0.5 + 0.5 * nz.get_noise_2d(i * 3.0, j * 0.5))
			colr[k] = rc.lerp(green.lerp(green_b, 0.5 + 0.5 * nz.get_noise_2d(i * 11.0, j * 11.0)), gm)
	var idx := PackedInt32Array()
	for j in rows:
		for i in cols:
			var k := j * (cols + 1) + i
			idx.append_array([k, k + 1, k + cols + 1, k + 1, k + cols + 2, k + cols + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = colr
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	var m := karst_mat.duplicate() as ShaderMaterial
	m.set_shader_parameter("detail", 1.0)
	mi.material_override = m
	add_child(mi)

func _train() -> void:
	lead = ToaTau.place(self, Vector3.ZERO, 0.0, false)
	tail = ToaTau.place(self, Vector3.ZERO, 0.0, false)
	var look := Looks.load_saved()
	hero_sit = _hero(look, lead)
	hero_sit.global_transform = ToaTau.seat_spot(lead, -0.8, -1)
	hero_sit.play("Act_SitChair_Idle", 0.0)
	hero_stand = _hero(look, tail)
	hero_stand.transform = Transform3D(Basis(), Vector3(-0.35, ToaTau.FL, 5.12))
	hero_stand.play("Base_Wait", 0.0)

func _hero(look: Dictionary, car: Node3D) -> Chibi:
	var c := Chibi.new()
	car.add_child(c)
	c.build(look)
	return c

func _train_at(s: float) -> void:
	var f := frame_at(s)
	lead.global_transform = f
	var b := frame_at(s - ToaTau.LENGTH)
	tail.global_transform = Transform3D(b.basis.rotated(Vector3.UP, PI), b.origin)
	hero_sit.global_transform = ToaTau.seat_spot(lead, seat_z, -1)

func _wet(amount: float) -> void:
	for car: Node3D in [lead, tail]:
		if not glass.has(car):
			var panes := []
			for mi: MeshInstance3D in car.find_children("Glass*", "MeshInstance3D", true, false):
				panes.append([mi, mi.material_override])
			var m := ShaderMaterial.new()
			m.shader = WET_GLASS
			m.set_shader_parameter("tint", Color(1.0, 0.86, 0.62, 0.08))
			m.set_shader_parameter("back", -1.0 if car == lead else 1.0)
			glass[car] = [panes, m]
		var wm: ShaderMaterial = glass[car][1]
		wm.set_shader_parameter("wet", amount)
		for pane: Array in glass[car][0]:
			(pane[0] as MeshInstance3D).material_override = wm if amount > 0.0 else pane[1]

func _co() -> Node3D:
	var n := Node3D.new()
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("f7f5ef")
	white.roughness = 0.9
	var bill := StandardMaterial3D.new()
	bill.albedo_color = Color("e8b83a")
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2b2b2e")
	var sph := SphereMesh.new()
	sph.radial_segments = 12
	sph.rings = 6
	_part(n, sph, white, Vector3.ZERO, Vector3(0.2, 0.18, 0.5))
	_part(n, sph, white, Vector3(0, 0.06, 0.32), Vector3(0.13, 0.15, 0.2))
	_part(n, sph, white, Vector3(0, 0.1, 0.45), Vector3(0.1, 0.09, 0.12))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 6
	_part(n, cone, bill, Vector3(0, 0.09, 0.57), Vector3(0.03, 0.16, 0.03), Vector3(PI / 2, 0, 0))
	var stick := CylinderMesh.new()
	stick.top_radius = 0.5
	stick.bottom_radius = 0.5
	stick.height = 1.0
	stick.radial_segments = 4
	for x: float in [-0.035, 0.035]:
		_part(n, stick, dark, Vector3(x, -0.04, -0.46), Vector3(0.016, 0.42, 0.016), Vector3(-PI / 2 + 0.15, 0, 0))
	var wings := []
	var bx := BoxMesh.new()
	for side: float in [-1.0, 1.0]:
		var inner := Node3D.new()
		inner.position = Vector3(side * 0.08, 0.05, 0.04)
		n.add_child(inner)
		_part(inner, bx, white, Vector3(side * 0.2, 0, 0), Vector3(0.4, 0.025, 0.26))
		var outer := Node3D.new()
		outer.position = Vector3(side * 0.4, 0, 0)
		inner.add_child(outer)
		_part(outer, bx, white, Vector3(side * 0.18, 0, -0.03), Vector3(0.36, 0.02, 0.2))
		wings.append([inner, outer, side])
	n.set_meta("wings", wings)
	n.set_meta("phase", randf() * TAU)
	add_child(n)
	return n

func _part(parent: Node3D, m: Mesh, mat: Material, pos: Vector3, scl: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _flap(n: Node3D, t: float, rate: float) -> void:
	var ph: float = t * TAU * rate + float(n.get_meta("phase"))
	for w: Array in n.get_meta("wings"):
		var side: float = w[2]
		(w[0] as Node3D).rotation.z = side * (0.12 + 0.6 * sin(ph))
		(w[1] as Node3D).rotation.z = side * (0.4 * sin(ph - 0.8))

func river_at(s: float) -> Transform3D:
	var f := frame_at(s)
	var mid := f.origin + f.basis.x * (75.0 + 25.0 * sin(s / 170.0))
	var f2 := frame_at(s + 2.0)
	var mid2 := f2.origin + f2.basis.x * (75.0 + 25.0 * sin((s + 2.0) / 170.0))
	mid.y = G + 0.08
	mid2.y = mid.y
	return Transform3D(Basis.looking_at(mid - mid2), mid)

func _wildlife() -> void:
	for i in 5:
		storks.append(_co())
	var rower: Dictionary = Looks.DEFAULT.duplicate(true)
	rower.merge(ThuDo.GRANNY, true)
	rower["hair_color"] = "#3a2a22"
	rower["age"] = 0
	rower["hat"] = ThuDo.HAT
	rower["top"] = ThuDo._baba("#3d4e7a", "#e8d9b5", "")
	for i in 2:
		var boat := Node3D.new()
		add_child(boat)
		var hull := HomeKit.place(boat, "thuyen_nan", Vector3(0, -0.1, 0))
		hull.scale = Vector3(1.15, 1.0, 1.1)
		var c := Chibi.new()
		boat.add_child(c)
		c.build(rower)
		c.position = Vector3(0, 0.25, -2.2)
		c.play("Act_SitFloor", 0.0)
		var oar := Node3D.new()
		oar.position = Vector3(0.45, 0.7, -2.0)
		boat.add_child(oar)
		var stick := CylinderMesh.new()
		stick.top_radius = 0.03
		stick.bottom_radius = 0.03
		stick.height = 2.8
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color("7a5a3a")
		_part(oar, stick, wood, Vector3(0, -0.6, 0.9), Vector3.ONE, Vector3(1.0, 0, 0))
		boat.set_meta("oar", oar)
		boats.append(boat)

func _skies() -> void:
	sky_rain = ShaderMaterial.new()
	sky_rain.shader = preload("res://shaders/shower_sky.gdshader")
	sky_clear = ShaderMaterial.new()
	sky_clear.shader = preload("res://shaders/sky_clouds.gdshader")
	sky_clear.set_shader_parameter("top_color", Color("86c4ea"))
	sky_clear.set_shader_parameter("horizon_color", Color("f3e6cf"))
	sky_clear.set_shader_parameter("ground_color", Color("c9d6a8"))
	sky_clear.set_shader_parameter("cover", 0.42)
	env.ssr_enabled = true
	env.ssr_max_steps = 96
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 1.5
	env.ssr_depth_tolerance = 0.5

func _look(which: String) -> void:
	var toward := Vector3(1.0, 0.22, -0.45).normalized()
	if which == "clear":
		toward = Vector3(-0.25, 0.5, -0.85).normalized()
	sun.global_transform = Transform3D(Basis.looking_at(-toward), Vector3.ZERO)
	rain.set_raining(which == "rain")
	if which == "clear":
		env.sky.sky_material = sky_clear
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("c3cbe0")
		env.ambient_light_energy = 0.62
		sun.light_color = Color("ffe6c0")
		sun.light_energy = 1.1
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = Color("e9e6dc")
		env.fog_density = 0.00028
		env.fog_sky_affect = 0.15
		env.fog_height = G + 10.0
		env.fog_height_density = 0.012
		env.glow_intensity = 0.35
		for m in water_mats:
			m.albedo_color = Color("34524e")
	else:
		env.sky.sky_material = sky_rain
		sky_rain.set_shader_parameter("coverage", 0.72 if which == "rain" else 0.55)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("9aa8bc")
		env.ambient_light_energy = 0.5 if which == "rain" else 0.58
		sun.light_color = Color("ffd9a0")
		sun.light_energy = 1.15 if which == "rain" else 1.3
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = Color("c9c3c0") if which == "rain" else Color("b9b8c0")
		env.fog_density = 0.006 if which == "rain" else 0.0005
		env.fog_sky_affect = 0.0
		env.fog_height = G + 6.0
		env.fog_height_density = 0.04 if which == "rain" else 0.01
		env.glow_intensity = 0.45
		for m in water_mats:
			m.albedo_color = Color("3d5560")

func _start(i: int) -> void:
	shot = i
	shot_t = 0.0
	var sh: Dictionary = SHOTS[i]
	_look(sh["look"])
	hero_sit.visible = sh["name"] in ["kinh_mua", "dong_lua"]
	hero_stand.visible = sh["name"] in ["nhin_lai"]
	seat_z = -2.6 if sh["name"] == "kinh_mua" else -0.8
	sun.directional_shadow_max_distance = 40.0 if sh["name"] in ["kinh_mua", "nhin_lai", "dong_lua", "co_bay"] else 400.0
	ToaTau.set_sway(0.0 if sh["name"] == "roi_ga" else 0.04)
	_wet(sh["wet"])
	for n in storks:
		n.visible = sh["name"] == "co_bay"
	for n in boats:
		n.visible = sh["name"] in ["con_do", "thung_lung"]

func _train_s(sh: Dictionary, t: float) -> float:
	var v0: float = sh["v"]
	var a: float = sh["acc"]
	var vmax: float = sh["vmax"]
	var d := 0.0
	if a <= 0.0:
		d = v0 * t
	else:
		var tm := (vmax - v0) / a
		d = v0 * minf(t, tm) + 0.5 * a * minf(t, tm) ** 2 + vmax * maxf(t - tm, 0.0)
	return s_at_cached(sh) + d

var _s0 := {}
func s_at_cached(sh: Dictionary) -> float:
	var key: String = sh["name"]
	if not _s0.has(key):
		_s0[key] = s_at(sh["x"])
	return _s0[key]

func _process(delta: float) -> void:
	var sh: Dictionary = SHOTS[shot]
	if still_at < 0.0:
		shot_t += delta
	var secs: float = sh["secs"]
	if shot_t > secs:
		if only >= 0 or shot + 1 >= SHOTS.size():
			if only < 0 and Engine.has_meta("ve_que_chain"):
				get_tree().change_scene_to_file("res://scenes/ve_ga.tscn")
				return
			get_tree().quit()
			return
		_start(shot + 1)
		sh = SHOTS[shot]
	var u := clampf(shot_t / secs, 0.0, 1.0)
	var s := _train_s(sh, shot_t)
	speed = (_train_s(sh, shot_t + 0.1) - s) / 0.1
	_train_at(s)
	for car: Node3D in glass:
		(glass[car][1] as ShaderMaterial).set_shader_parameter("run", clampf(speed / 15.0, 0.0, 1.0))
	var lp := lead.global_position
	match sh["name"]:
		"roi_ga":
			film.fov = 42.0
			film.global_position = Vector3(64.0, RAIL_Y + 11.0, Z0 + 16.0).lerp(Vector3(70.0, RAIL_Y + 10.0, Z0 + 18.0), u)
			film.look_at(lp + Vector3(-6, 1.5, 0), Vector3.UP)
		"kinh_mua":
			film.fov = 50.0
			film.global_transform = lead.global_transform * Transform3D(
				Basis.looking_at(Vector3(-1.0, 0.04, -0.42)), Vector3(-0.35, ToaTau.FL + 1.42, -0.9))
		"nhin_lai":
			film.fov = 72.0
			film.global_transform = tail.global_transform * Transform3D(
				Basis.looking_at(Vector3(-0.12, -0.04, 1.0)), Vector3(0.5, ToaTau.FL + 1.15, 4.6))
		"cau_sat":
			film.fov = 19.0
			film.global_position = Vector3(640.0, G + 9.0, Z0 - 300.0).lerp(Vector3(660.0, G + 9.0, Z0 - 296.0), u)
			film.look_at(Vector3(lp.x - 25.0, RAIL_Y + 6.0, Z0), Vector3.UP)
		"dong_lua":
			film.fov = 58.0
			film.global_transform = lead.global_transform * Transform3D(
				Basis.looking_at(Vector3(-1.0, 0.02, 0.15)), Vector3(1.15, ToaTau.FL + 1.25, -1.5))
		"con_do":
			film.fov = 34.0
			var sb := s_at_cached(sh) + 95.0
			var rt := river_at(sb + 0.9 * shot_t)
			boats[0].global_transform = Transform3D(rt.basis, rt.origin - rt.basis.x * 6.0 + Vector3(0, 0.03 * sin(shot_t * 1.7), 0))
			(boats[0].get_meta("oar") as Node3D).rotation.y = 0.35 * sin(shot_t * 1.6)
			boats[1].global_transform = Transform3D(Basis(), Vector3(0, -100, 0))
			var c0 := river_at(sb)
			var away := (c0.origin - frame_at(sb).origin)
			away.y = 0.0
			away = away.normalized()
			film.global_position = c0.origin + away * 13.0 + c0.basis.z * (-8.0 + 1.0 * shot_t) + Vector3(0, 0.9, 0)
			film.look_at(boats[0].global_position - away * 30.0 + Vector3(0, 2.5, 0), Vector3.UP)
		"thung_lung":
			film.fov = 40.0
			var b := frame_at(s_at_cached(sh))
			var fwd := b.basis.z
			film.global_position = b.origin - fwd * 70.0 + b.basis.x * 30.0 + Vector3(0, 14.0 + 120.0 * u * u, 0) + fwd * 140.0 * u
			film.look_at(lp + fwd * lerpf(120.0, 420.0, u) + Vector3(0, lerpf(18.0, 10.0, u), 0), Vector3.UP)
			for k in boats.size():
				var bs := s_at_cached(sh) + (230.0 + 1.6 * shot_t if k == 0 else 470.0 - 1.4 * shot_t)
				var rt := river_at(bs)
				var bt := Transform3D(rt.basis if k == 0 else rt.basis.rotated(Vector3.UP, PI), rt.origin)
				bt.origin += bt.basis.x * (5.0 if k == 0 else -5.0) + Vector3(0, 0.03 * sin(shot_t * 1.7 + k), 0)
				boats[k].global_transform = bt
				(boats[k].get_meta("oar") as Node3D).rotation.y = 0.35 * sin(shot_t * 1.6 + k)
		"co_bay":
			film.fov = 40.0
			var f := frame_at(s - 6.0)
			film.global_position = f.origin + f.basis.x * 27.0 + Vector3(0, G + 3.6 - f.origin.y, 0)
			film.look_at(lp + f.basis.x * 9.0 - f.basis.z * 8.0 + Vector3(0, -0.2, 0), Vector3.UP)
			for k in storks.size():
				var n := storks[k]
				var g := frame_at(s - 13.0 + k * 2.6 + 1.2 * sin(shot_t * 0.7 + k))
				var hy := G + 0.9 + 0.45 * float(k % 2) + 0.2 * sin(shot_t * 1.3 + k)
				n.global_transform = Transform3D(g.basis.scaled(Vector3.ONE * 1.3),
					g.origin + g.basis.x * (17.0 + 1.6 * float(k % 3)) + Vector3(0, hy - g.origin.y, 0))
				_flap(n, shot_t, 2.2)
		"vao_ham":
			film.fov = 44.0
			var f := frame_at(s_tunnel - 150.0)
			film.global_position = f.origin + f.basis.x * 16.0 + Vector3(0, 5.0, 0) + f.basis.z * 35.0 * u
			film.look_at(frame_at(s_tunnel).origin + Vector3(0, lerpf(14.0, 6.0, u), 0), Vector3.UP)
	rain_spot.global_position = film.global_position
	tower.update(Time.get_ticks_msec() / 1000.0)
	for m in water_mats:
		m.uv1_offset += Vector3(0.004, 0.002, 0) * delta
	if png != "" and Engine.get_process_frames() == 8:
		get_viewport().get_texture().get_image().save_png(png)
		get_tree().quit()

func _flat(r: Rect2, y: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = r.size
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	mi.material_override = m
	mi.position = Vector3(r.position.x + r.size.x / 2.0, y, r.position.y + r.size.y / 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		st.set_color(col)
		st.add_vertex(v)

static func _beam(st: SurfaceTool, a: Vector3, b: Vector3, w: float, h: float, col: Color) -> void:
	var z := (b - a).normalized()
	var upv := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := upv.cross(z).normalized() * (w / 2.0)
	var y := z.cross(x).normalized() * (h / 2.0)
	var c := [a - x - y, a + x - y, a + x + y, a - x + y, b - x - y, b + x - y, b + x + y, b - x + y]
	for f: Array in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5]]:
		_quad(st, c[f[0]], c[f[1]], c[f[2]], c[f[3]], col)
