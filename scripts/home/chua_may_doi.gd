class_name ChuaMayDoi
extends RefCounted

const STEP := 3.0
const X0 := -150.0
const X1 := 150.0
const Z0 := -210.0
const Z1 := 140.0
const LAKE := Vector3(0, 0, -150.0)
const LAKE_R := Vector2(40.0, 24.0)
const KARST := [[-170.0, -80.0, 55.0, 24.0], [-140.0, -215.0, 68.0, 28.0], [160.0, -190.0, 62.0, 26.0],
	[185.0, -40.0, 48.0, 22.0], [-200.0, 70.0, 44.0, 20.0], [40.0, -260.0, 58.0, 30.0]]

static func build(world: Node3D, chua: ChuaMay) -> void:
	var drop := chua.stair_drop
	var nx := int((X1 - X0) / STEP) + 1
	var nz := int((Z1 - Z0) / STEP) + 1
	var h := PackedFloat32Array()
	h.resize(nx * nz)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bumps := FastNoiseLite.new()
	bumps.frequency = 0.03
	for j in nz:
		for i in nx:
			h[j * nx + i] = _height(X0 + i * STEP, Z0 + j * STEP, drop, bumps)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz:
		for i in nx:
			var p := Vector3(X0 + i * STEP, h[j * nx + i], Z0 + j * STEP)
			var dx := h[j * nx + mini(i + 1, nx - 1)] - h[j * nx + maxi(i - 1, 0)]
			var dz := h[mini(j + 1, nz - 1) * nx + i] - h[maxi(j - 1, 0) * nx + i]
			var n := Vector3(-dx, 2.0 * STEP, -dz).normalized()
			var steep := 1.0 - n.y
			var c := Color("86ad64").lerp(Color("5f8a4a"), clampf(steep * 4.0, 0, 1))
			if steep > 0.3:
				c = c.lerp(Color("8f8c82"), clampf((steep - 0.3) * 4.0, 0, 1))
			st.set_color(c)
			st.set_normal(n)
			st.add_vertex(p)
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + nx)
			st.add_index(a + 1)
			st.add_index(a + nx + 1)
			st.add_index(a + nx)
	var mi := MeshInstance3D.new()
	mi.name = "Doi"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	chua.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = nx
	hs.map_depth = nz
	hs.map_data = h
	cs.shape = hs
	cs.scale = Vector3(STEP, 1, STEP)
	cs.position = Vector3((X0 + X1) / 2.0, 0, (Z0 + Z1) / 2.0)
	body.add_child(cs)
	chua.add_child(body)
	_plain(chua, drop)
	_lake(chua, drop)
	_woods(chua, h, nx, nz, drop)
	for k: Array in KARST:
		_karst(chua, Vector3(k[0], -drop - 2.0, k[1]), k[2], k[3], rng)

static func _height(x: float, z: float, drop: float, n: FastNoiseLite) -> float:
	var best := -drop + 0.6 * n.get_noise_2d(x, z)

	for f: Array in [[-24.0, 24.0, -14.0, 31.0, -1.2], [-22.0, 22.0, -48.0, -14.0, 1.8],
			[-15.0, 15.0, -79.0, -49.0, 5.3], [-10.0, 10.0, ChuaMayBac.foot_z(), ChuaMayBac.foot_z() + 14.0, -drop]]:
		var d := maxf(maxf(f[0] - x, x - f[1]), maxf(f[2] - z, z - f[3]))
		best = maxf(best, f[4] - _fall(maxf(d, 0.0), n, x, z))
	if absf(x) < 9.0 and z > ChuaMayBac.TOP_Z and z < ChuaMayBac.foot_z():
		var s := ChuaMayBac.height_at(z, drop) - 1.0
		best = s if absf(x) < 6.6 else maxf(minf(best, s + (absf(x) - 6.6) * 2.0), s - 1.0)
	else:
		var d := maxf(absf(x) - 6.6, 0.0)
		if z > ChuaMayBac.TOP_Z and z < ChuaMayBac.foot_z():
			best = maxf(best, ChuaMayBac.height_at(z, drop) - 1.0 - _fall(d, n, x, z))
	for f: Array in [[-24.0, 24.0, -14.0, 31.0, 0.0], [-22.0, 22.0, -48.0, -14.0, 3.0], [-15.0, 15.0, -79.0, -49.0, 6.5]]:
		if x > f[0] and x < f[1] and z > f[2] and z < f[3]:
			best = minf(best, f[4] - 1.2)
	var q := Vector2((x - LAKE.x) / LAKE_R.x, (z - LAKE.z) / LAKE_R.y).length()
	if q < 1.4:
		best = lerpf(minf(best, -drop - 2.5), best, smoothstep(0.85, 1.4, q))
	return best

static func _fall(d: float, n: FastNoiseLite, x: float, z: float) -> float:
	return 34.0 * (1.0 - exp(-d / (14.0 + 4.0 * n.get_noise_2d(x * 2.0, z * 2.0))))

static func _plain(chua: ChuaMay, drop: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("86ad64")
	m.roughness = 1.0
	mi.material_override = m
	mi.position = Vector3(0, -drop - 0.8, 0)
	chua.add_child(mi)

static func _lake(chua: ChuaMay, drop: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.02
	cm.radial_segments = 40
	cm.rings = 1
	mi.mesh = cm
	mi.scale = Vector3(LAKE_R.x * 1.12, 1, LAKE_R.y * 1.12)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/home_water.gdshader")
	m.set_shader_parameter("noise_tex", load("res://props/farm/ground/noise.png"))
	m.set_shader_parameter("has_depth", false)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = LAKE + Vector3(0, -drop - 0.9, 0)
	chua.add_child(mi)

static func _karst(chua: ChuaMay, base: Vector3, height: float, r0: float, rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 16
	var rings := 12
	var ph := rng.randf() * TAU
	for k in rings + 1:
		var t := float(k) / rings
		for s in sides + 1:
			var a := TAU * s / sides
			var wob := 1.0 + 0.16 * sin(a * 3.0 + ph + t * 4.0) + 0.08 * sin(a * 5.0 - ph * 2.0 + t * 7.0)
			var r := r0 * (1.0 - 0.6 * pow(t, 1.8)) * wob * (1.0 - 0.65 * pow(t, 8.0))
			var y := height * (t + 0.04 * sin(a * 2.0 + ph))
			var green := t > 0.82 or (sin(a * 4.0 + ph + t * 9.0) > 0.55 and t > 0.25)
			st.set_color(Color("6f8f52") if green else Color("9a978c").darkened(0.12 * sin(a * 7.0 + t * 5.0)))
			st.add_vertex(base + Vector3(cos(a) * r, y, sin(a) * r))
	for k in rings:
		for s in sides:
			var a := k * (sides + 1) + s
			for v in [a, a + 1, a + sides + 1, a + 1, a + sides + 2, a + sides + 1]:
				st.add_index(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	chua.add_child(mi)

static func _woods(chua: ChuaMay, h: PackedFloat32Array, nx: int, nz: int, drop: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var kinds := [["cay/cay_keo", "cay/la_cay", []], ["chua/thong_co", "chua/la_chua", []], ["chua/thong_co2", "chua/la_chua", []]]
	for n in 6000:
		if (kinds[0][2].size() + kinds[1][2].size() + kinds[2][2].size()) >= 150:
			break
		var x := rng.randf_range(X0 + 6, X1 - 6)
		var z := rng.randf_range(Z0 + 6, Z1 - 6)
		var i := int((x - X0) / STEP)
		var j := int((z - Z0) / STEP)
		var y := h[j * nx + i]
		var dy := absf(h[j * nx + mini(i + 1, nx - 1)] - y) + absf(h[mini(j + 1, nz - 1) * nx + i] - y)
		if y < -drop + 1.0 or y > -1.5 or dy < 0.6 or dy > 7.0:
			continue
		if absf(x) < 12.0 and z > -10.0:
			continue
		var k := 0 if rng.randf() < 0.55 else 1 + rng.randi() % 2
		var sc := rng.randf_range(0.85, 1.2)
		kinds[k][2].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(x, y - 0.3, z)))
	for kd: Array in kinds:
		var sc := (load("res://props/hometown/%s.glb" % kd[0]) as PackedScene).instantiate()
		var mesh := (sc.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
		sc.free()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = kd[2].size()
		for t in kd[2].size():
			mm.set_instance_transform(t, kd[2][t])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = HomeKit._plant_material(kd[1])
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chua.add_child(mmi)
