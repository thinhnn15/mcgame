class_name ChuaMayCanh
extends RefCounted

const POND := Vector3(3.0, 0.0, 15.0)
const POND_R := 4.563
const POND_WATER := 0.234
const POND_IN := 0.429

const TREES := [
	["thong_co", Vector3(-11.0, 0.0, 7.0), 200.0, 1.0], ["thong_co", Vector3(11.0, 0.0, 7.0), -20.0, 1.0],
	["thong_co2", Vector3(-12.0, 0.0, 22.0), 160.0, 1.05], ["thong_co2", Vector3(12.0, 0.0, 22.0), 20.0, 1.05],
	["thong_co2", Vector3(-19.5, ChuaMay.L1, -16.0), 150.0, 1.0], ["thong_co2", Vector3(19.5, ChuaMay.L1, -16.0), 30.0, 1.0],
	["thong_co", Vector3(-19.5, ChuaMay.L1, -45.0), 220.0, 1.1], ["thong_co", Vector3(19.5, ChuaMay.L1, -45.0), -40.0, 1.1],
	["cay_dai", Vector3(-11.5, ChuaMay.L1, -29.0), 0.0, 1.0], ["cay_dai", Vector3(11.5, ChuaMay.L1, -29.0), 140.0, 1.0],
	["bo_de", Vector3(-10.5, ChuaMay.L2, -53.5), 0.0, 1.0],
	["thong_co", Vector3(13.6, ChuaMay.L2, -78.0), -60.0, 1.15],
]
const LANTERNS := [Vector3(3.6, 0.0, 8.6), Vector3(3.6, 0.0, 22.5), Vector3(4.6, ChuaMay.L1, -15.6),
	Vector3(4.4, ChuaMay.L1, -42.4)]
const POTS := [Vector3(5.6, ChuaMay.L1, -25.6)]
const BENCH := Vector3(-7.6, ChuaMay.L2, -51.2)

const PAVED := [[Vector3(0, 0, 6.0), Vector2(23.0, 6.0)], [Vector3(0, 0, 20.0), Vector2(6.0, 22.0)],
	[Vector3(0, ChuaMay.L1, -31.0), Vector2(44.0, 34.0)], [Vector3(0, ChuaMay.L2, -64.0), Vector2(30.0, 30.0)]]
const TREE_END := 260.0

static var _stone: ShaderMaterial

static func stone() -> ShaderMaterial:
	if _stone == null:
		_stone = ShaderMaterial.new()
		_stone.shader = preload("res://shaders/toon_surface.gdshader")
		_stone.set_shader_parameter("tile_alb", load("res://props/surfaces/chua_da_xanh_alb.png"))
		_stone.set_shader_parameter("tile_nrm", load("res://props/surfaces/chua_da_xanh_nrm.png"))
		_stone.set_shader_parameter("has_nrm", true)
		_stone.set_shader_parameter("tile_size", Vector2(3.2, 3.2))
		_stone.set_shader_parameter("shade_soft", 0.35)
		_stone.set_shader_parameter("rim", 0.1)
	return _stone

static func dress(chua: ChuaMay) -> void:
	_paving(chua)
	for sx in [-1.0, 1.0]:
		_pond(chua, sx)
		for p: Vector3 in LANTERNS:
			Furniture.place(chua, "den_da_chua", Vector3(p.x * sx, p.y, p.z), 0.0, true)
		for p: Vector3 in POTS:
			Furniture.place(chua, "chau_canh", Vector3(p.x * sx, p.y, p.z), 0.0, true)
			var bonsai := HomeKit.place_plant(chua, "chua/thong_co", Vector3(p.x * sx, p.y + 0.93, p.z), 90.0 - 90.0 * sx)
			bonsai.scale = Vector3.ONE * 0.24
	for t: Array in TREES:
		var n := HomeKit.place_plant(chua, "chua/" + t[0], t[1], t[2])
		n.scale = Vector3.ONE * float(t[3])
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			mi.visibility_range_end = TREE_END
		if t[0] == "bo_de":
			chua._see_setup(n)
	_boards(chua)
	HomeKit.place(chua, "ghe_da", BENCH, 90.0)
	_leaves(chua, TREES[10][1] + Vector3(0, 7.0, 0))
	_mist(chua)
	_sounds(chua)

static func _boards(chua: ChuaMay) -> void:
	var K := ChuaMay.K
	var hall := ChuaMay.HALL
	for b: Array in [["chu_tam_quan", Vector3(0, 5.45, 2.885) * K, Vector2(2.6, 0.7) * K, true],
			["chu_tam_quan", Vector3(0, 5.45, -2.885) * K, Vector2(2.6, 0.7) * K, false],
			["chu_chinh_dien", hall + Vector3(0, 5.85, 6.56) * K, Vector2(3.4, 0.85) * K, true],
			["chu_doi_tren", hall + Vector3(1.8, 3.4, 6.49) * K, Vector2(0.42, 3.6) * K, true],
			["chu_doi_duoi", hall + Vector3(-1.8, 3.4, 6.49) * K, Vector2(0.42, 3.6) * K, true]]:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = b[2]
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://props/hometown/chua/%s.png" % b[0])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.roughness = 0.55
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = b[1]
		mi.rotation.y = 0.0 if b[3] else PI
		mi.visibility_range_end = 70.0
		chua.add_child(mi)

static func _paving(chua: ChuaMay) -> void:
	for a: Array in PAVED:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = a[1]
		mi.mesh = pm
		mi.material_override = stone()
		mi.position = a[0] + Vector3(0, 0.02, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chua.add_child(mi)

static func _pond(chua: ChuaMay, sx: float) -> void:
	var pond := HomeKit.place(chua, "ho_ban_nguyet", Vector3(POND.x * sx, 0, POND.z), 0.0 if sx > 0 else 180.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	for i in n:
		var a0 := PI * i / n
		var a1 := PI * (i + 1) / n
		for v: Vector3 in [Vector3(POND_IN, 0, 0), Vector3(maxf(POND_R * sin(a0), POND_IN), 0, -POND_R * cos(a0)),
				Vector3(maxf(POND_R * sin(a1), POND_IN), 0, -POND_R * cos(a1))]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var water := MeshInstance3D.new()
	water.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/home_water.gdshader")
	m.set_shader_parameter("noise_tex", load("res://props/farm/ground/noise.png"))
	m.set_shader_parameter("has_depth", false)
	m.set_shader_parameter("shallow_col", Color("6f9c86"))
	m.set_shader_parameter("deep_col", Color("35605a"))
	m.set_shader_parameter("shore_col", Color("8fb8a2"))
	water.material_override = m
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position.y = POND_WATER
	pond.add_child(water)
	var bed := MeshInstance3D.new()
	bed.mesh = water.mesh
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("2c3b33")
	bm.roughness = 1.0
	bed.material_override = bm
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bed.position.y = 0.04
	pond.add_child(bed)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if sx > 0 else 8
	var lm := ShaderMaterial.new()
	lm.shader = preload("res://shaders/crop_foliage.gdshader")
	lm.set_shader_parameter("atlas", load("res://props/farm/dong_atlas.png"))

	var pick := RandomNumberGenerator.new()
	pick.seed = 70 + (1 if sx > 0 else 2)
	var by_model := {}
	for kind: Array in [["sen_0", 16], ["sen_1", 6], ["sen_3", 5], ["sen_2", 3]]:
		for i in int(kind[1]):
			var a := rng.randf_range(0.2, PI - 0.2)
			var r := POND_R * sqrt(rng.randf_range(0.25, 0.85))
			var s := rng.randf_range(0.8, 1.15)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s),
				Vector3(maxf(r * sin(a), POND_IN + 0.6), POND_WATER - 0.03, -r * cos(a)))
			var model: String = kind[0] if kind[0] in ["sen_0", "sen_1"] else Season.lotus(pick)
			if not by_model.has(model):
				by_model[model] = []
			by_model[model].append(xf)
	for model: String in by_model:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _first_mesh("res://props/farm/%s.glb" % model)
		mm.instance_count = by_model[model].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, by_model[model][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = lm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pond.add_child(mmi)
	var b := StaticBody3D.new()
	pond.add_child(b)
	for i in 12:
		var t := PI * (i + 0.5) / 12
		var c := Vector3(4.78 * sin(t), 0.5, -4.78 * cos(t))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.5, 1.0, 2.0 * 4.9 * sin(PI / 24) + 0.2)
		cs.shape = bs
		cs.position = c
		cs.rotation.y = -t
		b.add_child(cs)
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(0.45, 1.0, 10.0)
	cs2.shape = bs2
	cs2.position = Vector3(0.22, 0.5, 0)
	b.add_child(cs2)

static func _first_mesh(path: String) -> Mesh:
	var sc := (load(path) as PackedScene).instantiate()
	var m := (sc.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	sc.free()
	return m

static func _leaves(chua: ChuaMay, at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 6
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = at
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(5.0, 1.5, 5.0)
	pm.direction = Vector3(0.6, -1, 0.2)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0.12, -0.35, 0.05)
	pm.damping_min = 0.3
	pm.damping_max = 0.5
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.18
	pm.scale_max = 0.24
	p.process_material = pm
	var q := QuadMesh.new()
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.albedo_texture = load("res://props/hometown/chua/la_chua.png")
	var r: Array = JSON.parse_string(FileAccess.get_file_as_string("res://props/hometown/chua/la_chua.json"))["la_roi"]
	sm.uv1_scale = Vector3(r[2], r[3], 1)
	sm.uv1_offset = Vector3(r[0], r[1], 0)
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.billboard_keep_scale = true
	q.material = sm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-8, -10, -8), Vector3(16, 12, 16))
	chua.add_child(p)

static var _puff: Texture2D

static func _mist(chua: ChuaMay) -> void:
	if _puff == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.5, Color(1, 1, 1, 0.45))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 128
		gt.height = 64
		_puff = gt
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _puff
	m.albedo_color = Color(0.93, 0.95, 0.97, 0.32)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 3.0
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 6.0
	m.distance_fade_max_distance = 22.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var drift := Node3D.new()
	drift.name = "Mist"
	chua.add_child(drift)
	for i in 16:
		var a := TAU * (i + rng.randf_range(-0.3, 0.3)) / 16
		var r := rng.randf_range(70.0, 110.0)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(rng.randf_range(40.0, 60.0), rng.randf_range(7.0, 11.0))
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(r * cos(a), rng.randf_range(1.0, 4.0) - chua.stair_drop, -30.0 + r * sin(a))
		drift.add_child(mi)
		var tw := mi.create_tween().set_loops()
		var span := rng.randf_range(3.0, 6.0)
		var dur := rng.randf_range(14.0, 24.0)
		var side := Vector3(-sin(a), 0, cos(a)) * span
		tw.tween_property(mi, "position", mi.position + side, dur).set_trans(Tween.TRANS_SINE)
		tw.tween_property(mi, "position", mi.position - side, dur * 2.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(mi, "position", mi.position, dur).set_trans(Tween.TRANS_SINE)

static func _sounds(chua: ChuaMay) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var chimes := Timer.new()
	chimes.one_shot = true
	chua.add_child(chimes)
	var ring := func():
		var a := TAU * (rng.randi() % 8 + 0.5) / 8.0
		var y := rng.randf_range(4.0, 22.0)
		Sound.play_at("temple.chime", chua.to_global(ChuaMay.TOWER + Vector3(cos(a) * 5.6, y, sin(a) * 5.6)))
		chimes.start(rng.randf_range(7.0, 16.0))
	chimes.timeout.connect(ring)
	chimes.start(rng.randf_range(2.0, 5.0))
	var prayer := Timer.new()
	prayer.one_shot = true
	chua.add_child(prayer)
	var pray := func():
		var at := chua.to_global(ChuaMay.HALL + Vector3(0, 2.0, -1.0))
		var tw := chua.create_tween()
		tw.tween_callback(func(): Sound.play_at("temple.bowl", at))
		tw.tween_interval(4.0)
		for i in 24:
			tw.tween_callback(func(): Sound.play_at("temple.mo", at, rng.randf_range(-1.5, 0.0)))
			tw.tween_interval(0.85 + rng.randf_range(-0.03, 0.03))
		tw.tween_interval(1.0)
		tw.tween_callback(func(): Sound.play_at("temple.bowl", at))
		prayer.start(120.0)
	prayer.timeout.connect(pray)
	prayer.start(20.0)
