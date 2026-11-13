class_name HomeKit
extends RefCounted

const DIR := "res://props/hometown/"
const SHADER := preload("res://shaders/home_tile.gdshader")
const FOLIAGE := preload("res://shaders/home_foliage.gdshader")
const TILES := preload("res://shaders/home_tiles.gdshader")
const LAMP := preload("res://shaders/home_lamp.gdshader")
const POOL := preload("res://shaders/home_lamp_pool.gdshader")

const LAMPS := {
	"tram_xe_que": [[Vector3(0, 0.15, 0.12), Vector3.UP, 2.7], [Vector3(0, 1.25, -0.64), Vector3.BACK, 2.6],
		[Vector3(0, 1.85, 0.75), Vector3.DOWN, 1.4]],
	"den_duong": [[Vector3(0, 0.06, 1.25), Vector3.UP, 5.0]],
	"cot_den": [[Vector3(0, 0.06, 0.55), Vector3.UP, 3.6]],
	"cot_dien_den": [[Vector3(0, 0.06, 1.0), Vector3.UP, 5.0]],
	"quan_nuoc": [[Vector3(0.5, 0.12, 0.5), Vector3.UP, 3.4]],
	"nha_ong_cafe": [[Vector3(0, 0.14, 3.45), Vector3.UP, 3.8], [Vector3(0, 1.4, 2.6), Vector3.BACK, 3.6]],
	"nha_ong_pho": [[Vector3(0, 0.14, 3.3), Vector3.UP, 3.4], [Vector3(0, 1.1, 2.6), Vector3.BACK, 3.0]],
	"nha_ong_taphoa": [[Vector3(0, 0.14, 3.3), Vector3.UP, 3.4], [Vector3(0, 1.1, 2.6), Vector3.BACK, 3.0]],
	"nha_ong_thuoc": [[Vector3(0, 1.1, 2.6), Vector3.BACK, 3.0], [Vector3(1.48, 1.95, 3.3), Vector3.BACK, 1.4]],
	"nha_ga": [[Vector3(-8.42, 0.48, -5.7), Vector3.UP, 2.8], [Vector3(8.42, 0.48, -5.7), Vector3.UP, 2.8],
		[Vector3(-3.74, 0.48, -3.6), Vector3.UP, 3.2], [Vector3(3.74, 0.48, -3.6), Vector3.UP, 3.2],
		[Vector3(0, 1.5, -2.2), Vector3.FORWARD, 4.2], [Vector3(0, 0.48, 2.85), Vector3.UP, 2.8],
		[Vector3(0, 1.7, 2.2), Vector3.BACK, 3.2],

		[Vector3(-2.1, 1.6, 2.21), Vector3.BACK, 1.5], [Vector3(2.1, 1.65, 2.21), Vector3.BACK, 1.5],
		[Vector3(-2.1, 1.65, -2.21), Vector3.FORWARD, 1.5], [Vector3(2.1, 1.65, -2.21), Vector3.FORWARD, 1.5],
		[Vector3(-3.53, 1.65, 0), Vector3.LEFT, 1.5], [Vector3(3.53, 1.65, 0), Vector3.RIGHT, 1.5],

		[Vector3(-6.47, 2.05, -6.77), Vector3.FORWARD, 1.9], [Vector3(-6.47, 2.05, -6.65), Vector3.BACK, 1.9],
		[Vector3(-17.55, 0.48, -5.7), Vector3.UP, 2.8]],
}
static var _lamp_mats := {}
static var _pool_mat: ShaderMaterial
static var _night := 0.0
static var _pools: Array[Node3D] = []

const FAR_AT := 45.0
const HIDE_AT := {"tiny": 28.0, "small": 55.0, "plant": 90.0}
const SIZE_CLASS := {"da_buoc": "tiny", "san_gach": "tiny", "coc_tre": "tiny", "day_phoi": "tiny",
	"luong_cai": "small", "luong_hanh": "small", "luong_co": "small", "luong_xalach": "small", "rao_tre": "small",
	"cong_tre": "small", "cong_tre_lon": "small", "chuong_ga": "small", "be_nuoc": "small", "dong_rom": "small", "gian_muop": "small",
	"cay_chuoi": "plant", "cay_cau": "plant", "cay_buoi": "plant", "decal_san": "plant"}
const MARGIN := 3.0

const NO_SHADOW := ["da_buoc", "san_gach", "luong_cai", "luong_hanh", "luong_co", "luong_xalach", "coc_tre", "day_phoi",
	"den_duong"]

const THAI_GIAY := Vector3(1.56, 0.33, 3.39)
const NHAT_TUNG := Vector3(1.17, 0.33, 4.21)
const ONG_POTS := [Vector3(0.585, 2.465, 3.29), Vector3(1.326, 2.465, 3.29)]
const ONG_MOTO := Vector3(0.95, 0.0, 3.95)
const TEX_OF := {"voi_trang": "voi", "ngoi_bo": "ngoi", "hoa_hong": "voi", "hoa_vang": "voi",
	"hoa_trang": "voi", "la": "voi", "dat_nung": "voi", "vua": "voi", "go_dam": "go", "hoa_do": "voi",
	"sat": "voi", "ngoi_go_bo": "ngoi_go", "voi_cu": "voi", "go_cu": "go", "cui": "go",
	"ngoi_cu_bo": "ngoi_cu", "tre_cu": "tre", "la_rau": "voi", "la_hanh": "voi", "co": "voi", "muop": "voi",
	"ton": "xi_mang", "quan_ao_do": "voi", "quan_ao_xanh": "voi", "day": "voi", "dat_luong": "dat",
	"gach_san_cu": "gach_san", "ngoi_thai": "ngoi_men", "ngoi_thai_bo": "ngoi_men", "voi_kem": "voi", "da_op": "da_voi",
	"cot_trang": "voi", "voi_xanh": "voi", "gach_am": "gach", "ngoi_thai_reu": "ngoi_men", "ngoi_thai_bo_reu": "ngoi_men",
	"ngoi_thai_lam": "ngoi_men", "ngoi_thai_bo_lam": "ngoi_men", "ngoi_thai_nau": "ngoi_men", "ngoi_thai_bo_nau": "ngoi_men",
	"voi_ghi": "voi", "ngoi_nhat": "ngoi_phang", "ngoi_nhat_bo": "ngoi_phang", "ngoi_nhat_do": "ngoi_phang",
	"ngoi_nhat_bo_do": "ngoi_phang", "ngoi_nhat_xanh": "ngoi_phang", "ngoi_nhat_bo_xanh": "ngoi_phang",
	"son_hong": "voi", "son_xanh": "voi", "son_vang": "voi", "son_lam": "voi", "inox": "xi_mang", "ton_do": "xi_mang",
	"bat_do": "voi", "lop": "xi_mang", "xi_mang_ong": "xi_mang", "sat_xanh": "voi", "bien_xanh": "voi", "quan_ao_vang": "voi",
	"go_do": "go", "voi_chua": "voi", "dong": "xi_mang", "nhua_do": "voi", "du_xanh": "voi", "du_vang": "voi", "da_den": "da_voi", "nuoc_gieng": "voi", "ngoi_dinh": "ngoi_men", "ngoi_dinh_bo": "ngoi_men", "nuoc_chau": "voi",
	"ton_xam": "xi_mang", "ton_gi": "xi_mang", "voi_ga": "voi", "da_phat_diem": "da_voi", "son_gi": "xi_mang",
	"ngoi_co_1": "ngoi_cu", "ngoi_co_2": "ngoi_cu", "ngoi_co_3": "ngoi_cu"}
const TINTS := {
	"ngoi_thai": Color("dd6e4c"),
	"ngoi_thai_bo": Color("b8503a"),
	"voi_kem": Color("f6e7c2"),
	"da_op": Color("d8c8a8"),
	"voi_xanh": Color("e8efe4"),
	"gach_am": Color("e0a58a"),
	"ngoi_thai_reu": Color("6f9a5a"), "ngoi_thai_bo_reu": Color("557a46"),
	"ngoi_thai_lam": Color("5f7fa8"), "ngoi_thai_bo_lam": Color("4a6488"),
	"ngoi_thai_nau": Color("8a5a44"), "ngoi_thai_bo_nau": Color("6c4434"),
	"voi_ghi": Color("ebe8e1"),
	"ngoi_nhat": Color("6d8399"), "ngoi_nhat_bo": Color("566a80"),
	"ngoi_nhat_do": Color("9a4a3a"), "ngoi_nhat_bo_do": Color("7a3a2e"),
	"ngoi_nhat_xanh": Color("4a8a8c"), "ngoi_nhat_bo_xanh": Color("386c6e"),
	"son_hong": Color("f4c9c4"), "son_xanh": Color("cde8dc"), "son_vang": Color("f7e2a2"), "son_lam": Color("c8dcef"),
	"inox": Color("eef1f4"),
	"xi_mang_ong": Color("f2e2c6"),
	"sat_xanh": Color("4f7f62"),
	"bien_xanh": Color("3f74b8"),
	"quan_ao_vang": Color("f2c94c"),
	"go_do": Color("b85a42"),
	"voi_chua": Color("eab65a"),
	"dong": Color("b48d4c"),
	"nhua_do": Color("e04a3a"),
	"du_xanh": Color("4a86c8"), "du_vang": Color("f2c14c"),
	"da_den": Color("8a8580"),
	"nuoc_gieng": Color("3e5f6a"),
	"ton_do": Color("c8604a"),
	"bat_do": Color("e05a4e"),
	"lop": Color("5a585a"),
	"cot_trang": Color("fbf7ee"),
	"voi": Color("fff0bb"),
	"voi_trang": Color("fbf6ec"),
	"go": Color("ffffff"),
	"go_son": Color("86d9c5"),
	"ngoi": Color("ffffff"),
	"ngoi_bo": Color("e8c2b4"),
	"xi_mang": Color("f3ead8"),
	"hoa_hong": Color("ff9db4"),
	"hoa_vang": Color("ffd766"),
	"hoa_trang": Color("ffffff"),
	"la": Color("7fc46a"),
	"dat_nung": Color("e3926a"),
	"vua": Color("f8edd6"),
	"go_dam": Color("8a7468"),
	"ngoi_go_bo": Color("b39684"),
	"hoa_do": Color("ff4d4d"),
	"sat": Color("4a4645"),
	"voi_cu": Color("f2dda4"),
	"go_cu": Color("c2b4a4"),
	"bat": Color("5d9de0"),
	"cui": Color("d8c09c"),
	"ngoi_cu_bo": Color("d9b8a6"),
	"tre_cu": Color("d2c8b0"),
	"la_rau": Color("8ccf6a"),
	"la_hanh": Color("6fbf5a"),
	"co": Color("a6c25e"),
	"muop": Color("7fb85a"),
	"ton": Color("a9b7c4"),
	"quan_ao_do": Color("f27a7a"),
	"quan_ao_xanh": Color("6f95d6"),
	"day": Color("6a5a48"),
	"dat_luong": Color("a88a6a"),
	"gach_san_cu": Color("e2cbbb"),
}

const DAMP := {"voi": [0.55, 0.5, 0.7], "voi_trang": [0.4, 0.5, 0.6], "da_voi": [0.5, 0.0, 0.4],
	"vua": [0.45, 0.4, 0.6], "voi_cu": [0.7, 0.25, 0.9]}

static var _cache := {}

static func material(mat: String, ao: Texture2D, tints := {}) -> ShaderMaterial:
	var key := mat + "|" + str(ao.get_rid() if ao else 0) + "|" + str(tints.get(mat, ""))
	if _cache.has(key):
		return _cache[key]
	if mat.begins_with("den_"):
		if not _lamp_mats.has(mat):
			var lm := ShaderMaterial.new()
			lm.shader = LAMP
			lm.set_shader_parameter("night", _night)
			if mat == "den_do":
				lm.set_shader_parameter("day_color", Color("c8463c"))
				lm.set_shader_parameter("glow_color", Color("ff4a3a"))
			elif mat == "den_xanh":
				lm.set_shader_parameter("day_color", Color("3fae6a"))
				lm.set_shader_parameter("glow_color", Color("4cff8a"))
			elif mat == "den_long":
				lm.set_shader_parameter("day_color", Color("d8463a"))
				lm.set_shader_parameter("glow_color", Color("ff7a4a"))
				lm.set_shader_parameter("glow_energy", 1.8)
			elif mat == "den_long_xanh":
				lm.set_shader_parameter("day_color", Color("3f9a8a"))
				lm.set_shader_parameter("glow_color", Color("6ff0d0"))
				lm.set_shader_parameter("glow_energy", 1.6)
			_lamp_mats[mat] = lm
		return _lamp_mats[mat]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	if mat == "tiles":
		m.shader = TILES
		m.set_shader_parameter("albedo_arr", load(DIR + "tiles_array_alb.png"))
		m.set_shader_parameter("nrm_arr", load(DIR + "tiles_array_nrm.png"))
		if ao:
			m.set_shader_parameter("has_ao", true)
			m.set_shader_parameter("ao_tex", ao)
		_cache[key] = m
		return m
	if mat == "la_atlas":
		m.shader = FOLIAGE
		m.set_shader_parameter("atlas", load(DIR + "la_atlas.png"))
		_cache[key] = m
		return m
	if mat.begins_with("cua") or mat.begins_with("decal_"):
		m.set_shader_parameter("albedo_tex", load(DIR + mat + "_alb.png"))
		m.set_shader_parameter("nrm_tex", load(DIR + mat + "_nrm.png"))
		m.set_shader_parameter("cutout", true)
	else:
		var tex: String = TEX_OF.get(mat, mat)
		m.set_shader_parameter("albedo_tex", load(DIR + "tiles/" + tex + "_alb.png"))
		m.set_shader_parameter("nrm_tex", load(DIR + "tiles/" + tex + "_nrm.png"))
	m.set_shader_parameter("tint", tints.get(mat, TINTS.get(mat, Color.WHITE)))
	if ao:
		m.set_shader_parameter("has_ao", true)
		m.set_shader_parameter("ao_tex", ao)
	if DAMP.has(mat):
		var d: Array = DAMP[mat]
		m.set_shader_parameter("damp", d[0])
		m.set_shader_parameter("damp_y0", d[1])
		m.set_shader_parameter("damp_h", d[2])
	_cache[key] = m
	return m

static func place(parent: Node3D, name: String, pos: Vector3, yaw_deg := 0.0, tints := {}, far_at := FAR_AT) -> Node3D:
	var n: Node3D = load(DIR + name + ".glb").instantiate()
	n.position = pos
	n.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(n)
	var ao: Texture2D = load(DIR + name + "_ao.png") if ResourceLoader.exists(DIR + name + "_ao.png") else null
	var has_far := ResourceLoader.exists(DIR + name + "_far.glb")
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var own_ao := null if DOOR_SWING.has(String(mi.name)) or mi.name == &"Decals" else ao
		if mi.name == &"Decals" or NO_SHADOW.has(name):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var mat_name := src.resource_name if src else ""
			mi.set_surface_override_material(s, material(mat_name, own_ao, tints))
		if has_far:
			mi.visibility_range_end = far_at

	if has_far:
		var far: Node3D = load(DIR + name + "_far.glb").instantiate()
		far.name = "Far"
		n.add_child(far)
		for mi: MeshInstance3D in far.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = _far_material(name)
			mi.visibility_range_begin = far_at
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if LAMPS.has(name):
		_add_pools(n, LAMPS[name])
	return n

static func place_plant(parent: Node3D, name: String, pos: Vector3, yaw_deg := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(n)
	var sub := name.get_base_dir()
	for part in [name, name + "_far"]:
		if not ResourceLoader.exists(DIR + part + ".glb"):
			continue
		var g: Node3D = load(DIR + part + ".glb").instantiate()
		n.add_child(g)
		for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(s)
				var mn := src.resource_name if src else ""
				if mn.begins_with("la_"):
					mi.set_surface_override_material(s, _plant_material(sub + "/" + mn))
			if part.ends_with("_far"):
				mi.visibility_range_begin = FAR_AT
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				mi.visibility_range_end = FAR_AT
	return n

static func _plant_material(atlas: String) -> ShaderMaterial:
	if not _cache.has("plant|" + atlas):
		var m := ShaderMaterial.new()
		m.shader = FOLIAGE
		m.set_shader_parameter("atlas", load(DIR + atlas + ".png"))
		if ResourceLoader.exists(DIR + atlas + "_bloom.png"):
			m.set_shader_parameter("bloom_mask", load(DIR + atlas + "_bloom.png"))
		if ResourceLoader.exists(DIR + atlas + "_species.png"):
			m.set_shader_parameter("species_map", load(DIR + atlas + "_species.png"))
		_cache["plant|" + atlas] = m
	return _cache["plant|" + atlas]

static var _fade_shaders := {}

static func fade_material(m: Material) -> Material:
	if not (m is ShaderMaterial) or (m as ShaderMaterial).shader == null:
		return null
	var sh: Shader = (m as ShaderMaterial).shader
	if not _fade_shaders.has(sh):
		var code := sh.code
		for _k in 4:
			var a := code.find("#include \"")
			if a < 0:
				break
			var b := code.find("\"", a + 10)
			var inc := load(code.substr(a + 10, b - a - 10)) as ShaderInclude
			code = code.substr(0, a) + (inc.code if inc else "") + code.substr(b + 1)
		var i := code.find("void fragment() {")
		if i < 0:
			_fade_shaders[sh] = null
		else:
			var head := "instance uniform float fade = 0.0;\nconst float BAYER[16] = float[](0.03, 0.53, 0.16, 0.66, 0.78, " \
				+ "0.28, 0.91, 0.41, 0.22, 0.72, 0.09, 0.59, 0.97, 0.47, 0.84, 0.34);\n"
			var cut := "\n\tif (fade > 0.0 && BAYER[(int(FRAGCOORD.x) % 4) + (int(FRAGCOORD.y) % 4) * 4] < fade) {\n\t\tdiscard;\n\t}"
			var j := i + "void fragment() {".length()
			var f := Shader.new()
			f.code = code.substr(0, i) + head + code.substr(i, j - i) + cut + code.substr(j)
			_fade_shaders[sh] = f
	var fs: Shader = _fade_shaders[sh]
	if fs == null:
		return null
	if not _cache.has(m):
		var d := (m as ShaderMaterial).duplicate() as ShaderMaterial
		d.shader = fs
		_cache[m] = d
		if m in _lamp_mats.values():
			_lamp_mats["fade|" + str(m.get_instance_id())] = d
	return _cache[m]

static func set_night(t: float) -> void:
	_night = clampf(t, 0.0, 1.0)
	for lm: ShaderMaterial in _lamp_mats.values():
		lm.set_shader_parameter("night", _night)
	_pools = _pools.filter(func(q): return is_instance_valid(q))
	for q in _pools:
		q.visible = _night > 0.01
	if _pool_mat:
		_pool_mat.set_shader_parameter("night", _night)

static func night_look(root: Node3D, sun: DirectionalLight3D) -> void:
	sun.light_energy = 0.12
	sun.light_color = Color("8fa3d6")
	var we := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		var env := we.environment
		if env.sky.sky_material is ProceduralSkyMaterial:
			var sm := env.sky.sky_material as ProceduralSkyMaterial
			sm.sky_top_color = Color("1b2448")
			sm.sky_horizon_color = Color("3a4470")
			sm.ground_horizon_color = Color("3a4470")
			sm.ground_bottom_color = Color("1d2a2a")
		elif env.sky.sky_material is ShaderMaterial:
			var cm := env.sky.sky_material as ShaderMaterial
			cm.set_shader_parameter("top_color", Color("1b2448"))
			cm.set_shader_parameter("horizon_color", Color("3a4470"))
			cm.set_shader_parameter("ground_color", Color("1d2a2a"))
			cm.set_shader_parameter("night", 1.0)
		env.ambient_light_color = Color("5a6aa0")
		env.ambient_light_energy = 0.35
		if env.fog_enabled:
			env.fog_light_color = Color("2a3358")

		for mat in _night_haze_mats(root):
			mat.set_shader_parameter("haze_color", Color("2a3358"))
			if mat.shader in preload("res://scripts/home/shader_copy.gd").family([preload("res://shaders/karst.gdshader")]):
				mat.set_shader_parameter("mist_color", Color("3a4470"))
				mat.set_shader_parameter("mist_max", 0.2)
	set_night(1.0)

static func _night_haze_mats(root: Node) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	var hz := preload("res://scripts/home/shader_copy.gd").family([preload("res://shaders/karst.gdshader"),
		preload("res://shaders/greybox_terrain.gdshader")])
	for gi: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		var m := gi.material_override as ShaderMaterial
		if m and m.shader in hz and not m in out:
			out.append(m)
	return out

static func _add_pools(n: Node3D, pools: Array) -> void:
	if _pool_mat == null:
		_pool_mat = ShaderMaterial.new()
		_pool_mat.shader = POOL
		_pool_mat.set_shader_parameter("night", _night)
	for p: Array in pools:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(p[2], p[2])
		q.mesh = qm
		q.material_override = _pool_mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.visibility_range_end = FAR_AT
		q.name = "LampPool"
		q.visible = _night > 0.01
		_pools.append(q)
		n.add_child(q)
		var f: Vector3 = p[1]
		q.position = p[0]
		if absf(f.y) > 0.5:
			q.rotation.x = -PI / 2 * signf(f.y)
		elif absf(f.x) > 0.5:
			q.rotation.y = PI / 2 * signf(f.x)
		elif f.z < 0:
			q.rotation.y = PI

static func _far_material(name: String) -> ShaderMaterial:
	var key := name + "|far"
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo_tex", load(DIR + name + "_far_alb.png"))
	m.set_shader_parameter("has_nrm", false)
	_cache[key] = m
	return m

static func _hide_far(node: Node, piece: String) -> void:
	if not SIZE_CLASS.has(piece):
		return
	var end: float = HIDE_AT[SIZE_CLASS[piece]]
	var geoms: Array = node.find_children("*", "GeometryInstance3D", true, false)
	if node is GeometryInstance3D:
		geoms.append(node)
	for g: GeometryInstance3D in geoms:
		g.visibility_range_end = end
		g.visibility_range_end_margin = MARGIN

static func place_layout(parent: Node3D, path: String, with_house := true, skip: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = path.get_file().get_basename()
	parent.add_child(root)
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if with_house and d.has("house"):
		place(root, d["house"], Vector3.ZERO)

	var count := {}
	var items: Array = d["items"].filter(func(it: Dictionary) -> bool: return not (it["name"] in skip))
	for it: Dictionary in items:
		count[it["name"]] = count.get(it["name"], 0) + 1
	var batches := {}
	for it: Dictionary in items:
		var p: Array = it["pos"]
		var nm: String = it["name"]
		if nm.begins_with("decal_"):
			var q := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(it["size"][0], it["size"][1])
			q.mesh = pm
			q.material_override = material(nm, null)
			q.position = Vector3(p[0], p[1], p[2])
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(q)
			_hide_far(q, nm)
			continue
		var r: Array = it.get("rot", [0, 0, 0])
		var sc: Array = it.get("scale", [1, 1, 1])
		var xf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(r[0]), deg_to_rad(r[1]), deg_to_rad(r[2])), EULER_ORDER_YXZ)
			.scaled_local(Vector3(sc[0], sc[1], sc[2])), Vector3(p[0], p[1], p[2]))
		if count[nm] > 1 and not _has_moving_parts(nm):
			if not batches.has(nm):
				batches[nm] = []
			batches[nm].append(xf)
			continue
		var n := place(root, nm, Vector3.ZERO)
		n.transform = xf
		if nm in NO_SHADOW:
			for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hide_far(n, nm)
	for nm: String in batches:
		_batch(root, nm, batches[nm])
	return root

static func _has_moving_parts(name: String) -> bool:
	var n: Node = load(DIR + name + ".glb").instantiate()
	var moving := false
	for leaf_name: String in DOOR_SWING:
		if n.find_child(leaf_name, true, false):
			moving = true
	n.free()
	return moving

static func _batch(parent: Node3D, name: String, xforms: Array) -> void:
	var tmp := place(parent, name, Vector3.ZERO)
	var ao: Texture2D = load(DIR + name + "_ao.png") if ResourceLoader.exists(DIR + name + "_ao.png") else null
	for mi: MeshInstance3D in tmp.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh.duplicate()
		for s in mesh.get_surface_count():
			mesh.surface_set_material(s, mi.get_surface_override_material(s))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		var local := tmp.global_transform.affine_inverse() * mi.global_transform
		for i in xforms.size():
			mm.set_instance_transform(i, (xforms[i] as Transform3D) * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = name + "_x%d" % xforms.size()
		mmi.multimesh = mm
		if name in NO_SHADOW:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
		_hide_far(mmi, name)
	tmp.free()

const DOOR_SWING := {"Gate": -95.0, "Gate_R": 95.0, "DoorF_L": -105.0, "DoorF_R": 105.0, "DoorF_L1": -170.0, "DoorF_L2": 170.0, "DoorF_R1": 170.0, "DoorF_R2": -170.0, "DoorB": -100.0}

static func set_door(house: Node3D, which: String, t: float) -> void:
	var e := t * t * (3.0 - 2.0 * t)
	for leaf_name: String in DOOR_SWING:
		if leaf_name.begins_with(which):
			var leaf := house.find_child(leaf_name, true, false) as Node3D
			if leaf:
				leaf.rotation.y = deg_to_rad(DOOR_SWING[leaf_name] * e)
	house.set_meta(which, t)

static func swing_door(house: Node3D, which: String, open: bool, secs := 0.9) -> Tween:
	var from: float = house.get_meta(which, 0.0)
	var tw := house.create_tween()
	tw.tween_method(func(t: float) -> void: set_door(house, which, t), from, 1.0 if open else 0.0, secs * absf((1.0 if open else 0.0) - from))
	return tw
