class_name FarmFields
extends RefCounted

const THUA := [Rect2(17.0, -3.0, 5.4, 8.6), Rect2(23.0, -3.0, 5.4, 8.6), Rect2(29.0, -3.0, 5.4, 8.6)]
const FIELD := Rect2(16.2, -3.8, 19.0, 10.2)
const SINK := 0.22
const WATER_UP := 0.12
const SHED := Vector3(20.5, 0, -7.2)
const TROUGH := Vector3(23.4, 0, -6.4)
const ALMOND := Vector3(31.0, 0, -12.0)
const TEA_ROWS := [-10.6, -12.1, -13.6, -15.1]
const TEA_X0 := 9.5
const TEA_X1 := 23.5
const GRASS_HILL := Rect2(26.0, -17.0, 10.0, 11.0)

const CALENDAR := [[606, "co"], [700, "ma"], [800, "lua"], [810, "chin"], [9999, "gocra"]]

static func prepare(s: FarmScenery) -> void:
	s.pads.append([FIELD, 3.0])
	for r: Rect2 in THUA:
		s.sinks.append([r, SINK])
		s.no_grass.append(r.grow(-0.1))
		s.worn_rects.append([r, 0.9])
	s.pads.append([Rect2(SHED.x - 2.6, SHED.z - 2.2, 5.6, 4.6), 2.0])
	s.earth_rects.append([Rect2(SHED.x - 2.2, SHED.z - 1.8, 4.4, 4.2)])
	s.no_grass.append(Rect2(SHED.x - 2.0, SHED.z - 1.7, 4.0, 3.6))

	s.paths.append([[Vector2(5.6, 1.4), Vector2(7.9, -2.8), Vector2(11.2, -3.9), Vector2(15.4, -3.9), Vector2(18.2, -4.9),
		Vector2(20.5, -5.0)], 0.9])
	s.paths.append([[Vector2(15.4, -3.9), Vector2(16.6, -6.5), Vector2(16.4, -9.6), Vector2(16.9, -16.0)], 0.75])
	for z: float in TEA_ROWS:
		s.worn_rects.append([Rect2(TEA_X0, z + 0.55, TEA_X1 - TEA_X0, 0.6), 0.55])

static func stage_today(lunar: Array) -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--ruong")
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	var md := int(lunar[0]) * 100 + int(lunar[1])
	for row: Array in CALENDAR:
		if md < int(row[0]):
			return row[1]
	return "gocra"

static func build(farm: Node3D, s: FarmScenery) -> Node3D:
	var root := Node3D.new()
	root.name = "FarmFields"
	farm.add_child(root)
	var demo := OS.get_cmdline_user_args().has("--ruong-demo")
	var today := stage_today(Clock.lunar_now)
	var acc := {"water": [], "rice": {}, "sheaves": []}
	for i in THUA.size():
		_paddy(acc, s, THUA[i], (["ma", "lua", "chin"][i] if demo else today), i)
	_draw_paddies(root, acc)

	var sh := SHED
	sh.y = s.height_at(sh.x, sh.z)
	Furniture.place(root, "chuong_trau", sh, 0.0, true)
	var tr_ := TROUGH
	tr_.y = s.height_at(tr_.x, tr_.z)
	for g: GeometryInstance3D in Furniture.place(root, "mang_trau", tr_, -12.0, true).find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if demo:
		var at := SHED + Vector3(0.6, 0, 2.6)
		at.y = s.height_at(at.x, at.z)
		FarmAnimal.spawn(farm, "trau", at, deg_to_rad(200.0))
	var hay := Vector3(17.6, 0, -8.0)
	hay.y = s.height_at(hay.x, hay.z)
	HomeKit.place(root, "dong_rom", hay, 30.0)
	var hay_box := BoxShape3D.new()
	hay_box.size = Vector3(1.2, 1.6, 1.2)
	Props.solid(root, hay_box, hay + Vector3(0, 0.8, 0))

	s.batch_into(root, "cay/cay_bang", [Transform3D(Basis(Vector3.UP, 0.6), Vector3(ALMOND.x, s.height_at(ALMOND.x, ALMOND.z), ALMOND.z))])
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.5
	trunk.height = 3.0
	Props.solid(root, trunk, Vector3(ALMOND.x, s.height_at(ALMOND.x, ALMOND.z) + 1.5, ALMOND.z))
	return root

static func _paddy(acc: Dictionary, s: FarmScenery, r: Rect2, stage: String, i: int) -> void:
	var floor_y := s.height_at(r.get_center().x, r.get_center().y)
	var flooded := stage in ["nuoc", "ma", "lua"]
	if flooded:
		acc.water.append([r.grow(-0.05), floor_y + WATER_UP])
	var model: String = {"ma": "lua_0", "lua": "lua_2", "chin": "lua_4", "gocra": "lua_gocra"}.get(stage, "")
	if model == "":
		return

	if not acc.rice.has(model):
		acc.rice[model] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 50 + i
	var noise := FastNoiseLite.new()
	noise.frequency = 1.0 / 9.0
	noise.seed = 9 + i
	var nx := int(r.size.x)
	var nz := int(r.size.y)
	for a in nx:
		for b in nz:
			var edge := int(a == 0 or a == nx - 1) + int(b == 0 or b == nz - 1)
			if edge > 0 and rng.randf() < 0.15 * edge:
				continue
			var sc := rng.randf_range(0.96, 1.04) * (rng.randf_range(0.74, 0.88) if edge > 0 else 1.0)
			var x := r.position.x + (a + 0.5) * r.size.x / nx + rng.randf_range(-0.02, 0.02)
			var z := r.position.y + (b + 0.5) * r.size.y / nz + rng.randf_range(-0.02, 0.02)
			var yaw := rng.randi_range(0, 3) * PI * 0.5 + rng.randf_range(-0.05, 0.05)
			var k := 0.97 + 0.08 * noise.get_noise_2d(x, z) + rng.randf_range(-0.02, 0.02)
			acc.rice[model].append([Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc, sc)),
				Vector3(x, floor_y + 0.01, z)), Color(k, k, k * 0.98, 1.0)])
	if stage == "chin":
		for k in 3:
			acc.sheaves.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU),
				Vector3(r.position.x + 0.5 + k * 0.6, floor_y + SINK, r.end.y + 0.3)))

static func _draw_paddies(root: Node3D, acc: Dictionary) -> void:
	if not acc.water.is_empty():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for w: Array in acc.water:
			var r: Rect2 = w[0]
			var y: float = w[1]
			var c := [Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y, r.position.y),
				Vector3(r.end.x, y, r.end.y), Vector3(r.position.x, y, r.end.y)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(c[k])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.52, 0.62, 0.55, 0.72)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.06
		m.metallic_specular = 0.7
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "PaddyWater"
		root.add_child(mi)
	if _rice_mat == null:
		_rice_mat = ShaderMaterial.new()
		_rice_mat.shader = preload("res://shaders/crop_foliage.gdshader")
		_rice_mat.set_shader_parameter("atlas", load("res://props/farm/dong_atlas.png"))
	for model: String in acc.rice:
		var mesh := _first_mesh("res://props/farm/%s.glb" % model)
		var list: Array = acc.rice[model]
		if mesh == null or list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = list.size()
		for n in list.size():
			mm.set_instance_transform(n, list[n][0])
			mm.set_instance_color(n, list[n][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = _rice_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "Rice_" + model
		root.add_child(mi)
	var bo := _first_mesh("res://props/farm/lua_bo.glb")
	if bo and not acc.sheaves.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = bo
		mm.instance_count = acc.sheaves.size()
		for n in acc.sheaves.size():
			mm.set_instance_transform(n, acc.sheaves[n])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = _rice_mat
		mi.name = "Sheaves"
		root.add_child(mi)

static var _rice_mat: ShaderMaterial

static func _first_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var sc := (load(path) as PackedScene).instantiate()
	var found := sc.find_children("*", "MeshInstance3D", true, false)
	var m: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	sc.free()
	return m

static func tea_bushes(s: FarmScenery) -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for ri in TEA_ROWS.size():
		var z: float = TEA_ROWS[ri]
		var n := int((TEA_X1 - TEA_X0) / 0.92)
		for k in n:
			var x := TEA_X0 + (k + 0.5) * (TEA_X1 - TEA_X0) / n + rng.randf_range(-0.05, 0.05)
			var zz := z + rng.randf_range(-0.06, 0.06)
			out.append({"pos": Vector3(x, s.height_at(x, zz) - 0.03, zz), "row": ri, "k": k,
				"yaw": rng.randf_range(-0.12, 0.12) + (PI if k % 2 else 0.0)})
	return out

static func blockers() -> Array:
	var out := [[FIELD, "PEN_BAD_THING"], [Rect2(SHED.x - 2.2, SHED.z - 1.8, 4.4, 3.8), "PEN_BAD_THING"]]
	return out
