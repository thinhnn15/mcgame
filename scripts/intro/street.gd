extends RefCounted

const CityKit := preload("res://scripts/intro/city_kit.gd")
const TubeHouse := preload("res://scripts/intro/tube_house.gd")

const STREET_Y := -32.0
const CURB_H := 0.15
const WALK_Y := STREET_Y + CURB_H
const NEAR_CURB := -9.5
const FAR_CURB := -19.5
const FAR_FRONT := -24.0
const ROAD_C := -14.5
const LEN := 130.0
const LAMP_COLOR := Color("ffb45e")

var kit: CityKit
var rng := RandomNumberGenerator.new()
var near_front: float
var tower_hx: float
var lamps: Array[Vector3] = []
var ground_mats: Array[ShaderMaterial] = []
var house_tris := 0

var detail_range := Vector2.ZERO
var house_calls := 0

func build(k: CityKit, tower_front_z: float, hx: float) -> void:
	kit = k
	rng.seed = 1035
	near_front = tower_front_z
	tower_hx = hx
	_ground()
	_lamps()
	_trees()
	_houses()
	_poles()
	_scooters()
	_far_city()

func _ground() -> void:
	var shader := preload("res://shaders/intro_ground.gdshader")
	var road := _plane(Vector2(2 * LEN, NEAR_CURB - FAR_CURB), Vector3(0, STREET_Y, ROAD_C), shader)
	road.set_shader_parameter("kind", 0)
	road.set_shader_parameter("lines", Vector4(ROAD_C, NEAR_CURB - 0.35, FAR_CURB + 0.35, 0))
	road.set_shader_parameter("crossing", Vector2(0.0, 2.2))
	for z in [[NEAR_CURB, near_front + 1.3], [FAR_FRONT - 1.0, FAR_CURB]]:
		var a: float = z[0]
		var b: float = z[1]
		var walk := _plane(Vector2(2 * LEN, absf(b - a)), Vector3(0, WALK_Y, (a + b) / 2.0), shader)
		walk.set_shader_parameter("kind", 1)
		walk.set_shader_parameter("base_a", Color("54525e"))
		walk.set_shader_parameter("base_b", Color("6b5f60"))
		walk.set_shader_parameter("puddles", 0.3)

	kit.box(Vector3(2 * LEN, 0.2, 0.25), Color("a9adb8"), Vector3(0, WALK_Y + 0.012 - 0.1, NEAR_CURB + 0.125))
	kit.box(Vector3(2 * LEN, 0.2, 0.25), Color("a9adb8"), Vector3(0, WALK_Y + 0.012 - 0.1, FAR_CURB - 0.125))

	for z in [NEAR_CURB + 0.125, FAR_CURB - 0.125]:
		kit.hit_area(Vector3(10.0, WALK_Y + 0.02, z), Vector2(70.0, 0.2), 260)

	kit.box(Vector3(500, 0.1, 500), Color("1a1b28"), Vector3(0, STREET_Y - 0.08, 0))

func _plane(size: Vector2, pos: Vector3, shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	kit.register(m)
	ground_mats.append(m)
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	kit.root.add_child(mi)
	return m

func _lamps() -> void:
	var near_x := [-52.0, -36.0, -20.0, -6.5, 6.5, 20.0, 36.0, 52.0]
	var far_x := [-44.0, -28.0, -12.0, 3.0, 17.0, 32.0, 48.0]
	for x in near_x:
		_lamp(Vector3(x, WALK_Y, NEAR_CURB + 0.55), 180.0)
	for x in far_x:
		_lamp(Vector3(x, WALK_Y, FAR_CURB - 0.55), 0.0)

func _lamp(pos: Vector3, yaw: float) -> void:
	kit.place("street_lamp", pos, yaw)
	var head := pos + Vector3(0, 7.39, 1.74).rotated(Vector3.UP, deg_to_rad(yaw))
	lamps.append(head)
	kit.add_source(head + Vector3(0, -0.4, 0), 10.0, LAMP_COLOR, 1.7)
	kit.halo(head + Vector3(0, -0.1, 0), 3.2, Color("ffc070"), 0.32)
	kit.halo(head + Vector3(0, -0.12, 0), 0.9, Color("fff0d0"), 0.7)
	_cone(head)

func _cone(head: Vector3) -> void:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/light_cone.gdshader")
	var c := CylinderMesh.new()
	c.top_radius = 0.2
	c.bottom_radius = 2.8
	c.height = 7.1
	c.cap_top = false
	c.cap_bottom = false
	c.radial_segments = 24
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = head + Vector3(0, -3.65, 0)
	kit.root.add_child(mi)

func _trees() -> void:
	var near := [[-44.0, "c"], [-28.0, "a"], [-12.0, "b"], [12.0, "a"], [28.0, "c"], [44.0, "b"]]
	var far := [[-36.0, "b"], [-20.0, "a"], [-4.0, "c"], [25.0, "b"], [40.0, "a"]]
	for t in near:
		_tree(Vector3(t[0], WALK_Y, NEAR_CURB + 1.4), t[1])
	for t in far:
		_tree(Vector3(t[0], WALK_Y, FAR_CURB - 1.5), t[1])

func _tree(pos: Vector3, variant: String) -> void:
	kit.tree(variant, pos, rng.randf_range(0, 360), rng.randf_range(0.82, 0.97))

func _houses() -> void:
	var rows: Array = []

	var row: Array = []
	var x := -LEN
	while x < LEN:
		var w := rng.randf_range(3.6, 5.6)
		if x < 8.0 and x + w > 8.0:
			w = 8.0 - x
			if w < 2.5:
				x += w
				continue
		if absf(x - 8.0) < 0.01:
			row.append({"x0": x, "w": 4.8, "z": FAR_FRONT, "facing": 1, "floors": 3, "kind": "cafe"})
			x += 4.8
			continue
		var low := x > -6.0 and x < 34.0
		row.append({"x0": x, "w": w, "z": FAR_FRONT, "facing": 1, "floors": rng.randi_range(2, 3) if low else rng.randi_range(3, 6), "kind": "shop"})
		x += w
	rows.append(row)

	for side in [-1, 1]:
		row = []
		x = tower_hx + 1.2
		while x < LEN:
			var w := rng.randf_range(3.6, 5.6)
			var kind := "shop"
			if side > 0 and absf(x - (tower_hx + 1.2)) < 0.01:
				w = 6.0
				kind = "mart"
			var x0: float = x if side > 0 else -x - w
			row.append({"x0": x0, "w": w, "z": near_front, "facing": -1, "floors": rng.randi_range(3, 5), "kind": kind})
			x += w
		rows.append(row)
	var th := TubeHouse.new()
	th.setup(kit, rng, WALK_Y)
	th.detail_range = detail_range
	for r: Array in rows:
		r.sort_custom(func(a, b): return a["x0"] < b["x0"])
		for i in r.size():
			var h: Dictionary = r[i]
			var hl := 0.0
			var hr := 0.0
			if i > 0 and absf(r[i - 1]["x0"] + r[i - 1]["w"] - h["x0"]) < 0.05:
				hl = _height(r[i - 1])
			if i < r.size() - 1 and absf(h["x0"] + h["w"] - r[i + 1]["x0"]) < 0.05:
				hr = _height(r[i + 1])

			h["left_h"] = hl if h["facing"] > 0 else hr
			h["right_h"] = hr if h["facing"] > 0 else hl
			th.house(h)
	house_tris = th.b.tris
	house_calls = th.commit()

func _height(h: Dictionary) -> float:
	return TubeHouse.GH + (int(h["floors"]) - 1) * TubeHouse.SH

func _poles() -> void:
	var xs := [-56.0, -38.0, -21.0, -7.5, 9.5, 24.0, 40.0, 58.0]
	var tops: Array = []
	for x in xs:
		var p := Vector3(x, WALK_Y, FAR_CURB - 0.35)
		kit.place("power_pole", p, 0.0)
		tops.append(p)
	for i in tops.size() - 1:
		var a: Vector3 = tops[i]
		var b: Vector3 = tops[i + 1]
		var lines := [[7.75, -0.6, 0.6], [7.75, 0.6, 0.7], [7.15, -0.45, 0.8], [7.15, 0.45, 0.75], [6.8, 0.0, 1.2], [6.6, 0.15, 1.5]]
		for ln in lines:
			_wire(a + Vector3(0, ln[0], ln[1]), b + Vector3(0, ln[0], ln[1]), ln[2] + rng.randf_range(-0.1, 0.2))

func _wire(a: Vector3, b: Vector3, sag: float) -> void:
	var n := 12
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) - Vector3(0, 4.0 * sag * t * (1.0 - t), 0)
		var d := p - prev
		var e := Basis(Quaternion(Vector3.UP, d.normalized())).get_euler()
		kit.part(Props._cyl(0.018, 0.018, d.length() + 0.01), Color("23242c"), (p + prev) / 2.0,
			Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)))
		prev = p

func _scooters() -> void:

	var s := [[Vector3(5.6, WALK_Y, FAR_CURB - 1.3), -12.0, "scooter_red"], [Vector3(6.5, WALK_Y, FAR_CURB - 1.25), -8.0, ""],
		[Vector3(13.6, WALK_Y, FAR_CURB - 1.3), 10.0, "scooter_mint"], [Vector3(14.5, WALK_Y, FAR_CURB - 1.3), 4.0, ""],
		[Vector3(17.8, WALK_Y, NEAR_CURB + 1.6), 172.0, "scooter_mint"], [Vector3(18.7, WALK_Y, NEAR_CURB + 1.5), 185.0, "scooter_red"],
		[Vector3(-16.0, WALK_Y, NEAR_CURB + 1.5), 178.0, ""], [Vector3(-30.5, WALK_Y, FAR_CURB - 1.3), 6.0, "scooter_red"]]
	for it in s:
		kit.place("scooter", it[0], it[1], 1.0, it[2])
		var yaw := deg_to_rad(it[1])
		kit.hit_area(it[0] + Vector3(0, 0.88, -0.3).rotated(Vector3.UP, yaw), Vector2(0.3, 0.6), 14, it[1])
		kit.hit_area(it[0] + Vector3(0, 1.15, 0.53).rotated(Vector3.UP, yaw), Vector2(0.7, 0.12), 6, it[1])

	kit.place("bus_stop", Vector3(-9.6, WALK_Y, NEAR_CURB + 2.0), 180.0)
	kit.hit_area(Vector3(-9.6, WALK_Y + 2.62, NEAR_CURB + 2.0), Vector2(3.4, 1.4), 60)
	kit.drip_edge(Vector3(-11.3, WALK_Y + 2.48, NEAR_CURB + 1.03), Vector3(-7.9, WALK_Y + 2.48, NEAR_CURB + 1.03), 0.15)
	kit.add_source(Vector3(-11.2, WALK_Y + 1.2, NEAR_CURB + 2.0), 3.5, Color("ffd9a8"), 0.7)

func _far_city() -> void:

	var cols := [Color("2c2438"), Color("33283a"), Color("242838"), Color("3a2a3e")]
	var spots: Array = []
	for i in 110:
		var bx := rng.randf_range(-170.0, 170.0)
		var bz := rng.randf_range(-170.0, 140.0)
		if bz > -48.0 and bz < 34.0:
			continue
		if absf(bx) < 16.0 and bz < 60.0:
			continue
		spots.append(Vector2(bx, bz))
	var far = TubeHouse.Batch.new()
	far.cell = 170.0
	for p: Vector2 in spots:
		var bw := rng.randf_range(12.0, 24.0)
		var bd := rng.randf_range(12.0, 22.0)
		var bh := rng.randf_range(18.0, 70.0)

		var ci := rng.randi() % cols.size()
		var c: Color = cols[ci]
		var win: Material = kit.windows({"procedural": true, "lit_rate": 0.13, "seed": float(ci * 7),
			"cell": Vector2(3.0, 3.2), "wall_col": c, "win_size": Vector2(0.55, 0.5), "lit_energy": 0.8,
			"glass_top": c.lightened(0.12), "glass_bottom": c.darkened(0.2)})
		far.box(win, Transform3D(Basis(), Vector3(p.x, STREET_Y + bh / 2.0, p.y)), Vector3(bw, bh, bd),
			TubeHouse.Batch.all_faces(Rect2(0, 0, 1, 1), ["front", "back", "left", "right", "top"]), Color.WHITE)
		if rng.randf() < 0.3:
			var tip := Vector3(p.x, STREET_Y + bh + 1.5, p.y)
			kit.cyl(0.1, 0.06, 3.0, Color("3a3d4a"), tip - Vector3(0, 1.5, 0))
			kit.box(Vector3(0.4, 0.4, 0.4), kit.glow(Color("ff4040"), 2.5), tip)
			kit.halo(tip, 4.0, Color("ff4a4a"), 0.35)
	far.commit(kit.root)
