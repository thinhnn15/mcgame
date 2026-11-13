class_name FarmScenery
extends Node3D

const SIZE := 72.0
const GRID := 0.75
const SPLAT_PX := 288
const CHUNK := 8.0
const GRASS_STEP := 0.33
const FLOWERS := [Color(0.97, 0.96, 0.90), Color(0.98, 0.84, 0.30), Color(0.82, 0.72, 0.96), Color(0.98, 0.70, 0.62)]
const DITCH_Z := 6.6
const WATER_Y := -0.20

const POND_C := Vector2(11.6, 1.6)
const POND_R := Vector2(3.0, 2.2)
const JETTY := Vector3(8.15, 0.0, 1.6)
const JETTY_LEN := 1.45

const BRIDGE := Vector3(-6.0, 0.0, DITCH_Z)
const BRIDGE_YAW := -18.0
const BRIDGE_HALF := Vector2(0.525, 1.21)

const BRIDGE_TOP := 0.075
const DIR := "res://props/farm/ground/"

var paths := [
	[[Vector2(-36, 11.2), Vector2(-24, 9.8), Vector2(-13, 8.4), Vector2(-6.0, DITCH_Z), Vector2(-3.4, 4.3), Vector2(0, 3.2),
		Vector2(3.6, 2.6), Vector2(5.4, 1.7)], 1.0],
	[[Vector2(-3.4, 4.3), Vector2(-4.7, 0.6), Vector2(-4.3, -1.3)], 0.75],
]
var worn_circles := [[Vector2(-4.3, -2.4), 1.9, 0.9], [Vector2(4.2, -2.2), 0.9, 1.0], [Vector2(4.4, 0.6), 1.0, 1.0]]
var worn_rects := [[Rect2(-3.0, -2.2, 6.0, 4.0), 1.0], [Rect2(3.3, -2.9, 4.0, 4.4), 0.55]]
var no_grass := [Rect2(-2.8, -2.0, 5.6, 3.6), Rect2(-8.6, -1.9, 3.8, 3.4), Rect2(5.1, -3.0, 2.0, 2.0),
	Rect2(-5.5, -3.0, 2.4, 1.3)]
var flat := Rect2(-10.0, -5.0, 19.5, 10.0)

var pads := []

var earth_rects := []

var sinks := []

var ground: MeshInstance3D
var grass_mat: ShaderMaterial
var flower_mat: ShaderMaterial
var ground_mat: ShaderMaterial
var _noise := FastNoiseLite.new()
var _splat: Image

var decks: Array = []
var _hc: RefCounted

func build(env: Environment = null) -> void:
	var t0 := Time.get_ticks_msec()
	_noise.seed = 7
	_noise.frequency = 0.045
	if ClassDB.class_exists("FarmHeight"):
		_hc = ClassDB.instantiate("FarmHeight")
		_hc.configure({"flat": flat, "pads": pads, "sinks": sinks, "ditch_z": DITCH_Z, "pond_c": POND_C, "pond_r": POND_R,
			"seed": _noise.seed, "frequency": _noise.frequency})
		if OS.has_environment("MC_FARM_TIME"):
			var worst := 0.0
			var rng := RandomNumberGenerator.new()
			for k in 400:
				var x := rng.randf_range(-SIZE / 2, SIZE / 2)
				var z := rng.randf_range(-SIZE / 2, SIZE / 2)
				worst = maxf(worst, absf(_hc.height(x, z) - _height_gd(x, z)))
			print("  height C++ vs GDScript: worst %.6f m" % worst)
	_splat = _paint_splat()
	if OS.has_environment("MC_FARM_TIME"): print("  splat %d" % (Time.get_ticks_msec() - t0))
	var tex := ImageTexture.create_from_image(_splat)
	var noise: Texture2D = load(DIR + "noise.png")
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = preload("res://shaders/farm_ground.gdshader")
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = preload("res://shaders/farm_grass.gdshader")
	for m in [ground_mat, grass_mat]:
		m.set_shader_parameter("noise_tex", noise)
		m.set_shader_parameter("splat_tex", tex)
		m.set_shader_parameter("splat_rect", Vector4(-SIZE / 2, -SIZE / 2, SIZE, SIZE))
	flower_mat = grass_mat.duplicate()
	flower_mat.set_shader_parameter("flowers", true)
	ground_mat.set_shader_parameter("grass_tex", load(DIR + "grass_detail.png"))
	ground_mat.set_shader_parameter("dirt_tex", load(DIR + "dirt_alb.png"))
	_build_ground()
	if OS.has_environment("MC_FARM_TIME"): print("  %s %d" % ["_build_ground()", Time.get_ticks_msec() - t0])
	_build_far()
	if OS.has_environment("MC_FARM_TIME"): print("  %s %d" % ["_build_far()", Time.get_ticks_msec() - t0])
	_build_grass()
	if OS.has_environment("MC_FARM_TIME"): print("  %s %d" % ["_build_grass()", Time.get_ticks_msec() - t0])
	_build_water()
	if OS.has_environment("MC_FARM_TIME"): print("  %s %d" % ["_build_water()", Time.get_ticks_msec() - t0])
	_build_pond()
	if OS.has_environment("MC_FARM_TIME"): print("  %s %d" % ["_build_pond()", Time.get_ticks_msec() - t0])
	_build_plants()
	if OS.has_environment("MC_FARM_TIME"): print("  %s %d" % ["_build_plants()", Time.get_ticks_msec() - t0])
	print("farm_scenery: built in %d ms" % (Time.get_ticks_msec() - t0))
	if env:
		env.fog_enabled = true
		env.fog_light_color = Color(0.86, 0.90, 0.93)
		env.fog_density = 0.0022
		env.fog_aerial_perspective = 0.2
		env.fog_sun_scatter = 0.15

func height_at(x: float, z: float) -> float:
	if _hc:
		return _hc.height(x, z)
	return _height_gd(x, z)

func _height_gd(x: float, z: float) -> float:
	var dx := maxf(maxf(flat.position.x - x, x - flat.end.x), 0.0)
	var dz := maxf(maxf(flat.position.y - z, z - flat.end.y), 0.0)
	var out := smoothstep(0.0, 3.0, sqrt(dx * dx + dz * dz))
	var h := (_noise.get_noise_2d(x, z) * 0.9 + 0.35) * out
	h += smoothstep(-7.0, -15.0, z) * 2.4
	for pd: Array in pads:
		var r: Rect2 = pd[0]
		var ex := maxf(maxf(r.position.x - x, x - r.end.x), 0.0)
		var ez := maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
		h *= smoothstep(0.0, pd[1], sqrt(ex * ex + ez * ez))
	h *= 1.0 - exp(-pow((z - DITCH_Z) / 1.3, 2.0))
	for sk: Array in sinks:
		var r: Rect2 = sk[0]
		var e := maxf(maxf(r.position.x - x, x - r.end.x), maxf(r.position.y - z, z - r.end.y))
		h -= float(sk[1]) * (1.0 - smoothstep(-0.25, 0.0, e))
	h -= 0.62 * exp(-pow((z - DITCH_Z) / 0.75, 2.0))
	return lerpf(h, -0.62, 1.0 - smoothstep(0.6, 1.25, pond_e(x, z)))

static func pond_e(x: float, z: float) -> float:
	var q := (Vector2(x, z) - POND_C) / POND_R
	return q.dot(q)

func jetty_top() -> float:
	return maxf(height_at(JETTY.x, JETTY.z), 0.0) + 0.07

func set_wet(w: float) -> void:
	ground_mat.set_shader_parameter("wet", w)
	for m in [grass_mat, flower_mat]:
		m.set_shader_parameter("wet", w)
		m.set_shader_parameter("gust", lerpf(0.12, 0.2, w))
		m.set_shader_parameter("cloud_depth", lerpf(0.8, 1.0, w))
	ground_mat.set_shader_parameter("cloud_depth", lerpf(0.8, 1.0, w))
	Stage.clouds(true, lerpf(0.8, 1.0, w))

func set_pusher(p: Vector3) -> void:
	for m in [grass_mat, flower_mat]:
		m.set_shader_parameter("pusher", Vector4(p.x, p.y, p.z, 0.7))

func _paint_splat() -> Image:
	if ClassDB.class_exists("FarmSplat"):
		var data: PackedByteArray = ClassDB.class_call_static("FarmSplat", "paint", SIZE, SPLAT_PX, paths, earth_rects,
			worn_circles, worn_rects, DITCH_Z, POND_C, POND_R)
		return Image.create_from_data(SPLAT_PX, SPLAT_PX, false, Image.FORMAT_RGBA8, data)
	var img := Image.create(SPLAT_PX, SPLAT_PX, false, Image.FORMAT_RGBA8)
	var px := SIZE / SPLAT_PX
	for j in SPLAT_PX:
		for i in SPLAT_PX:
			var p := Vector2(-SIZE / 2 + (i + 0.5) * px, -SIZE / 2 + (j + 0.5) * px)
			var r := 0.0
			for pa in paths:
				var pts: Array = pa[0]
				var half: float = pa[1] * 0.5
				for k in pts.size() - 1:
					var d := _seg_dist(p, pts[k], pts[k + 1])

					var track := 1.0 - smoothstep(half - 0.15, half + 0.3, d)
					if half > 0.4:
						track *= 0.55 + 0.45 * smoothstep(0.08, 0.26, d)
					r = maxf(r, track)
			for er: Array in earth_rects:
				var rr: Rect2 = er[0]
				var e := maxf(maxf(rr.position.x - p.x, p.x - rr.end.x), maxf(rr.position.y - p.y, p.y - rr.end.y))
				r = maxf(r, 1.0 - smoothstep(-0.45, 0.2, e))
			var g := 0.0
			for c in worn_circles:
				g = maxf(g, (1.0 - smoothstep(c[1] * 0.55, c[1], p.distance_to(c[0]))) * c[2])
			for wr in worn_rects:
				var rr: Rect2 = wr[0]
				var e := maxf(maxf(rr.position.x - p.x, p.x - rr.end.x), maxf(rr.position.y - p.y, p.y - rr.end.y))
				g = maxf(g, (1.0 - smoothstep(-0.3, 0.6, e)) * wr[1])
			var b := exp(-pow((p.y - DITCH_Z) / 1.8, 2.0))
			var pe := pond_e(p.x, p.y)
			b = maxf(b, exp(-pow((pe - 1.0) / 0.5, 2.0)))
			g = maxf(g, exp(-pow((pe - 1.02) / 0.09, 2.0)) * 0.7)
			img.set_pixel(i, j, Color(r, g, b, 1.0))
	return img

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _splat_at(x: float, z: float) -> Color:
	var i := clampi(int((x + SIZE / 2) / SIZE * SPLAT_PX), 0, SPLAT_PX - 1)
	var j := clampi(int((z + SIZE / 2) / SIZE * SPLAT_PX), 0, SPLAT_PX - 1)
	return _splat.get_pixel(i, j)

func _build_ground() -> void:
	var n := int(SIZE / GRID)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	var hg: PackedFloat32Array = _hc.grid(-SIZE / 2, -SIZE / 2, GRID, n + 1, n + 1) if _hc else PackedFloat32Array()
	for j in n + 1:
		for i in n + 1:
			var x := -SIZE / 2 + i * GRID
			var z := -SIZE / 2 + j * GRID
			pts.append(Vector3(x, hg[j * (n + 1) + i] if _hc else height_at(x, z), z))
	for j in n + 1:
		for i in n + 1:
			var p: Vector3 = pts[j * (n + 1) + i]

			var xl: Vector3 = pts[j * (n + 1) + maxi(i - 1, 0)]
			var xr: Vector3 = pts[j * (n + 1) + mini(i + 1, n)]
			var zu: Vector3 = pts[maxi(j - 1, 0) * (n + 1) + i]
			var zd: Vector3 = pts[mini(j + 1, n) * (n + 1) + i]
			var nrm := Vector3((xl.y - xr.y) / maxf(xr.x - xl.x, 0.01), 1.0, (zu.y - zd.y) / maxf(zd.z - zu.z, 0.01)).normalized()
			st.set_normal(nrm)
			st.add_vertex(p)
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + n + 1)
			st.add_index(a + 1)
			st.add_index(a + n + 2)
			st.add_index(a + n + 1)
	var mesh := st.commit()
	ground = MeshInstance3D.new()
	ground.mesh = mesh
	ground.material_override = ground_mat
	ground.name = "Ground"

	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)

func _build_far() -> void:
	"""The ground on out to 200 m (4 m grid, the same material; its inner edge tucked 8 cm under the near ground
	so no crack shows), and a few of Ninh Bình's limestone towers standing in the haze, the way BotW layers its
	far hills."""
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 4.0
	var far := 200.0
	var n := int(far * 2 / step)
	var inner := SIZE / 2 - 2.0
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			var cx := -far + i * step
			var cz := -far + j * step
			var inside := absf(cx) <= SIZE / 2 and absf(cz) <= SIZE / 2
			hs[j * (n + 1) + i] = _far_height(cx, cz) - (0.08 if inside else 0.0)
	for j in n:
		for i in n:
			var x0 := -far + i * step
			var z0 := -far + j * step
			if x0 >= -inner and x0 + step <= inner and z0 >= -inner and z0 + step <= inner:
				continue
			var q := [Vector2(x0, z0), Vector2(x0 + step, z0), Vector2(x0 + step, z0 + step), Vector2(x0, z0 + step)]
			var qi := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			var v := []
			for ci in 4:
				var c: Vector2 = q[ci]
				var g: Vector2i = qi[ci]
				v.append(Vector3(c.x, hs[g.y * (n + 1) + g.x], c.y))
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = ground_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "FarGround"
	add_child(mi)
	var rock := Props.mat(Color("6f8a6a"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for t in [[Vector2(-70, -150), 34.0, 70.0], [Vector2(-25, -175), 26.0, 85.0], [Vector2(30, -160), 30.0, 62.0],
			[Vector2(85, -130), 24.0, 78.0], [Vector2(130, -60), 28.0, 55.0], [Vector2(-130, -80), 30.0, 66.0],
			[Vector2(-150, 20), 22.0, 50.0], [Vector2(150, 40), 26.0, 58.0]]:
		var sm := SphereMesh.new()
		sm.radial_segments = 10
		sm.rings = 6
		var tower := MeshInstance3D.new()
		tower.mesh = sm
		tower.material_override = rock
		tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var c: Vector2 = t[0]
		tower.position = Vector3(c.x, t[2] * 0.42, c.y)
		tower.scale = Vector3(t[1], t[2], t[1] * rng.randf_range(0.8, 1.1))
		tower.rotation.y = rng.randf() * TAU
		add_child(tower)

func _far_height(x: float, z: float) -> float:
	if absf(x) <= SIZE / 2 and absf(z) <= SIZE / 2:
		return height_at(x, z)
	var d := maxf(absf(x), absf(z)) - SIZE / 2
	var edge := height_at(clampf(x, -SIZE / 2, SIZE / 2), clampf(z, -SIZE / 2, SIZE / 2))
	var wild := (_noise.get_noise_2d(x * 0.3, z * 0.3) * 1.8 + 0.6) + smoothstep(-20.0, -60.0, z) * 5.0
	return lerpf(edge, wild, smoothstep(0.0, 20.0, d))

func _clump() -> ArrayMesh:
	"""Five thin blades fanned round the centre: each a tapered strip (two-triangle base, a tip triangle), leaning
	out a little; COLOR.a = height up the blade, COLOR.r = the blade's brightness. 15 triangles."""
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for b in 5:
		var ang := b * TAU / 5.0 + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-out.z, 0, out.x)
		var h := rng.randf_range(0.11, 0.20)
		var w := 0.017
		var lean := rng.randf_range(0.04, 0.09)
		var base := out * rng.randf_range(0.01, 0.05)
		var br := rng.randf()
		var p0 := base - side * w
		var p1 := base + side * w
		var mid := base + out * lean * 0.45 + Vector3(0, h * 0.55, 0)
		var p2 := mid - side * w * 0.7
		var p3 := mid + side * w * 0.7
		var tip := base + out * lean + Vector3(0, h, 0)
		for tri in [[p0, 0.0, p1, 0.0, p3, 0.55], [p0, 0.0, p3, 0.55, p2, 0.55], [p2, 0.55, p3, 0.55, tip, 1.0]]:
			for k in 3:
				st.set_color(Color(br, 0, 0, tri[k * 2 + 1]))
				st.set_normal(Vector3.UP)
				st.add_vertex(tri[k * 2])
	return st.commit()

func _flower() -> ArrayMesh:
	"""A tiny wild flower: a thin stem and a five-petal star on top facing up (8 triangles); COLOR.a as the grass."""
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.15
	for tri in [[Vector3(-0.006, 0, 0), 0.0, Vector3(0.006, 0, 0), 0.0, Vector3(0, h, 0), 0.9]]:
		for k in 3:
			st.set_color(Color(1, 0, 0, tri[k * 2 + 1]))
			st.add_vertex(tri[k * 2])
	var c := Vector3(0, h, 0)
	for i in 5:
		var a := i * TAU / 5.0
		var b := a + TAU / 10.0
		var p := c + Vector3(cos(a), 0.15, sin(a)) * 0.05
		var q := c + Vector3(cos(b), 0.0, sin(b)) * 0.018
		var r := c + Vector3(cos(a - TAU / 10.0), 0.0, sin(a - TAU / 10.0)) * 0.018
		for v in [c, q, p, c, p, r]:
			st.set_color(Color(1, 0, 0, 1.0))
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func _build_grass() -> void:
	var clump := _clump()
	var flower := _flower()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var nc := int(SIZE / CHUNK)
	var total := 0
	for cj in nc:
		for ci in nc:
			var c0 := Vector2(-SIZE / 2 + ci * CHUNK, -SIZE / 2 + cj * CHUNK)
			var centre := c0 + Vector2(CHUNK, CHUNK) * 0.5
			var xfs := []
			var fl := []
			var steps := int(CHUNK / GRASS_STEP)
			for j in steps:
				for i in steps:
					var x := c0.x + (i + rng.randf()) * GRASS_STEP
					var z := c0.y + (j + rng.randf()) * GRASS_STEP
					if not _grass_here(x, z, rng):
						continue
					var y := height_at(x, z)
					var s := rng.randf_range(0.75, 1.3)
					var bas := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
					xfs.append(Transform3D(bas, Vector3(x - centre.x, y, z - centre.y)))

					var meadow := _noise.get_noise_2d(x * 1.7 - 60.0, z * 1.7) * 0.5 + 0.5
					if rng.randf() < 0.22 * smoothstep(0.45, 0.75, meadow):
						fl.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)),
							Vector3(x - centre.x + 0.08, y, z - centre.y)), FLOWERS[rng.randi() % FLOWERS.size()]])
			if xfs.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = clump
			mm.instance_count = xfs.size()
			for k in xfs.size():
				mm.set_instance_transform(k, xfs[k])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = grass_mat
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.position = Vector3(centre.x, 0, centre.y)
			mmi.visibility_range_end = 22.0
			mmi.name = "Grass_%d_%d" % [ci, cj]
			add_child(mmi)
			total += xfs.size()
			if not fl.is_empty():
				var fm := MultiMesh.new()
				fm.transform_format = MultiMesh.TRANSFORM_3D
				fm.use_custom_data = true
				fm.mesh = flower
				fm.instance_count = fl.size()
				for k in fl.size():
					fm.set_instance_transform(k, fl[k][0])
					fm.set_instance_custom_data(k, fl[k][1])
				var fmi := MultiMeshInstance3D.new()
				fmi.multimesh = fm
				fmi.material_override = flower_mat
				fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				fmi.position = mmi.position
				fmi.visibility_range_end = 22.0
				add_child(fmi)
	print("farm_scenery: %d grass clumps (%d triangles)" % [total, total * 15])

func _grass_here(x: float, z: float, rng: RandomNumberGenerator) -> bool:
	for r in no_grass:
		if (r as Rect2).has_point(Vector2(x, z)):
			return false
	var y := height_at(x, z)
	if y < WATER_Y + 0.05 or absf(x) > SIZE / 2 - 0.5 or absf(z) > SIZE / 2 - 0.5:
		return false
	var sp := _splat_at(x, z)
	if sp.r > 0.3:
		return false

	var keep := (1.0 - sp.g * 0.9) * (0.55 + 0.45 * (_noise.get_noise_2d(x * 2.1 + 40.0, z * 2.1) * 0.5 + 0.5)) + sp.b * 0.3
	return rng.randf() < keep

func _build_water() -> void:
	var w := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE, 1.6)
	w.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.40, 0.60, 0.58, 0.78)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic_specular = 0.6
	w.material_override = m
	w.position = Vector3(0, WATER_Y, DITCH_Z)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.name = "Ditch"
	add_child(w)

	var root := Props.at(self, BRIDGE, BRIDGE_YAW)
	for k in 11:
		Props._part(root, root, Props._box(Vector3(1.05, 0.05, 0.2)), Color("c9a473") if k % 2 else Color("bb9666"),
			Vector3(0, 0.05, -1.1 + k * 0.22))
	for x in [-0.44, 0.44]:
		Props._part(root, root, Props._box(Vector3(0.10, 0.10, 2.6)), Color("8a6a46"), Vector3(x, -0.02, 0))
	var bw := BRIDGE_HALF.x
	var bl := BRIDGE_HALF.y
	add_deck(root.transform, Vector2.ZERO, BRIDGE_HALF, BRIDGE_TOP, 0.42)
	_deck(root, [Vector3(-bw, BRIDGE_TOP, -bl), Vector3(bw, BRIDGE_TOP, -bl), Vector3(-bw, BRIDGE_TOP, bl), Vector3(bw, BRIDGE_TOP, bl),
		Vector3(-bw, -0.2, -bl - 0.42), Vector3(bw, -0.2, -bl - 0.42), Vector3(-bw, -0.2, bl + 0.42), Vector3(bw, -0.2, bl + 0.42),
		Vector3(-bw, -0.7, -bl - 0.42), Vector3(bw, -0.7, -bl - 0.42), Vector3(-bw, -0.7, bl + 0.42), Vector3(bw, -0.7, bl + 0.42)])

func add_deck(xf: Transform3D, c: Vector2, h: Vector2, top: float, run: float) -> void:
	decks.append({"inv": xf.affine_inverse(), "c": c, "h": h, "top": top, "run": run})

func walk_at(x: float, z: float) -> float:
	var g := height_at(x, z)
	for d: Dictionary in decks:
		var q: Vector3 = d.inv * Vector3(x, 0.0, z)
		var e := maxf(absf(q.x - d.c.x) - d.h.x, absf(q.z - d.c.y) - d.h.y)
		if e <= 0.0:
			g = maxf(g, d.top)
		elif e < d.run and d.top > g:
			g = lerpf(d.top, g, e / d.run)
	return g

static func way(from: Vector3, to: Vector3) -> Vector3:
	var a := deg_to_rad(BRIDGE_YAW)
	var along := Vector3(sin(a), 0.0, cos(a))
	var q := Vector2(from.x - BRIDGE.x, from.z - BRIDGE.z).rotated(a)
	var on := absf(q.x) < 0.3 and absf(q.y) < BRIDGE_HALF.y + 1.0
	var south := to.z > DITCH_Z
	var end_to: Vector3 = BRIDGE + along * (BRIDGE_HALF.y + 0.7) * (1.0 if south else -1.0)
	end_to.y = to.y
	if (from.z > DITCH_Z) == south:
		return end_to if on and absf(q.y) < BRIDGE_HALF.y else to
	if on:
		return end_to
	var end_from: Vector3 = BRIDGE - along * (BRIDGE_HALF.y + 0.7) * (1.0 if south else -1.0)
	end_from.y = to.y
	return end_from

func _deck(root: Node3D, pts: Array) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = PackedVector3Array(pts)
	cs.shape = hull
	sb.add_child(cs)
	root.add_child(sb)

static func on_deck(x: float, z: float) -> bool:
	var q := Vector2(x - BRIDGE.x, z - BRIDGE.z).rotated(deg_to_rad(BRIDGE_YAW))
	if absf(q.x) < BRIDGE_HALF.x + 0.05 and absf(q.y) < BRIDGE_HALF.y + 0.4:
		return true
	return x > JETTY.x - 0.3 and x < JETTY.x + JETTY_LEN + 0.05 and absf(z - JETTY.z) < 0.36

func _build_pond() -> void:
	var w := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = POND_R * 2.0 * 1.2
	w.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/farm_pond.gdshader")
	m.set_shader_parameter("noise_tex", load(DIR + "noise.png"))
	m.set_shader_parameter("centre", POND_C)
	m.set_shader_parameter("radii", POND_R)
	w.material_override = m
	w.position = Vector3(POND_C.x, WATER_Y, POND_C.y)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.name = "Pond"
	add_child(w)

	var top := jetty_top()
	var root := Props.at(self, Vector3(JETTY.x, 0.0, JETTY.z), 0.0)
	var n := 8
	for k in n:
		var x := 0.09 + k * (JETTY_LEN - 0.18) / (n - 1)
		Props._part(root, root, Props._box(Vector3(0.16, 0.035, 0.56 + 0.04 * (k % 2))),
			Color("c7a46c") if k % 2 else Color("b8955f"), Vector3(x, top - 0.018, 0.01 * (k % 3 - 1)))
	for zz in [-0.22, 0.22]:
		Props._part(root, root, Props._box(Vector3(JETTY_LEN, 0.045, 0.06)), Color("8d6c44"),
			Vector3(JETTY_LEN / 2, top - 0.06, zz))
		for x in [0.55, JETTY_LEN - 0.08]:
			Props._part(root, root, Props._cyl(0.03, 0.03, 0.75), Color("7c6040"), Vector3(x, top - 0.42, zz))
	add_deck(root.transform, Vector2(JETTY_LEN / 2, 0.0), Vector2(JETTY_LEN / 2, 0.3), top, 0.3)
	_deck(root, [Vector3(0.0, top, -0.3), Vector3(0.0, top, 0.3), Vector3(JETTY_LEN, top, -0.3), Vector3(JETTY_LEN, top, 0.3),
		Vector3(-0.3, top - 0.16, -0.3), Vector3(-0.3, top - 0.16, 0.3), Vector3(-0.3, top - 0.8, -0.3), Vector3(-0.3, top - 0.8, 0.3),
		Vector3(JETTY_LEN, top - 0.8, -0.3), Vector3(JETTY_LEN, top - 0.8, 0.3)])

	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var plants := []
	var bud := RandomNumberGenerator.new()
	bud.seed = 12
	for k in 7:
		plants.append({"model": Season.lotus(bud), "yaw": rng.randf() * TAU,
			"pos": Vector3(13.0 + rng.randf_range(-0.9, 0.9), WATER_Y, 0.4 + rng.randf_range(-0.6, 0.6))})
	for p in [Vector2(10.4, 2.9), Vector2(11.2, 3.1), Vector2(12.6, 2.6), Vector2(10.0, 0.4), Vector2(12.0, 0.9), Vector2(13.6, 2.2)]:
		plants.append({"model": "sung_3", "yaw": rng.randf() * TAU, "pos": Vector3(p.x, WATER_Y, p.y)})
	for p in [Vector2(9.0, 3.0), Vector2(14.2, 1.2), Vector2(12.9, 3.5), Vector2(9.3, 0.0)]:
		plants.append({"model": "beo_tay_3", "yaw": rng.randf() * TAU, "pos": Vector3(p.x, WATER_Y, p.y)})
	Crops.draw(self, plants)
	var reeds := []
	for k in 9:
		var a := lerpf(-1.9, 1.3, k / 8.0) + rng.randf_range(-0.12, 0.12)
		var at := POND_C + Vector2(cos(a) * POND_R.x, sin(a) * POND_R.y) * 1.02
		reeds.append(_at(at.x, at.y, rng.randf() * 360.0, WATER_Y + 0.08))
	_batch("cay/co_lau", reeds)

func _build_plants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var luy := []
	for k in 11:
		var x := -35.0 + k * 7.0
		luy.append(_at(x, -16.6 if x > 8.0 and x < 25.0 else -15.5, 0.0))
	_batch("cay/luy_tre", luy)
	_batch("cay/bui_tre", [_at(-15.0, -7.5, 20.0), _at(7.2, -9.9, -40.0), _at(-18.5, 3.5, 70.0)])
	_batch("cay/cay_gao", [_at(13.0, 10.5, 30.0)])
	var lau := []
	for k in 14:
		var x := -22.0 + k * 3.3 + rng.randf_range(-0.8, 0.8)
		if absf(x + 6.0) < 1.6:
			continue
		lau.append(_at(x, DITCH_Z + (0.9 if k % 2 else -0.95), rng.randf() * 360.0, WATER_Y + 0.1))
	_batch("cay/co_lau", lau)
	var lao := []
	for p in [Vector2(-11.5, 7.0), Vector2(-9.0, 9.5), Vector2(8.6, 5.4), Vector2(11.0, -3.0), Vector2(-12.0, -2.5), Vector2(8.0, -6.0)]:
		lao.append(_at(p.x, p.y, rng.randf() * 360.0))
	_batch("cay/bui_dai_b", lao)
	var tufts := []
	for p in [Vector2(-3.4, -3.2), Vector2(-5.9, -1.4), Vector2(3.1, -3.4), Vector2(7.6, -1.0), Vector2(7.4, 1.6),
			Vector2(-2.6, 2.6), Vector2(2.9, 2.2), Vector2(-9.0, 2.2), Vector2(-4.2, 3.0), Vector2(1.8, 4.6)]:
		tufts.append(_at(p.x, p.y, rng.randf() * 360.0))
	_batch("cay/co_bui", tufts)

func _at(x: float, z: float, yaw_deg: float, y := NAN) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), Vector3(x, height_at(x, z) if is_nan(y) else y, z))

func _batch(name: String, xforms: Array) -> void:
	"""Every copy of one kit plant as one MultiMesh per mesh (its near version; this place is small)."""
	batch_into(self, name, xforms)

func batch_into(parent: Node3D, name: String, xforms: Array) -> void:
	var tmp := HomeKit.place_plant(self, name, Vector3.ZERO)
	for mi: MeshInstance3D in tmp.find_children("*", "MeshInstance3D", true, false):
		if mi.visibility_range_begin > 0.0:
			continue
		var mesh: Mesh = mi.mesh.duplicate()
		for s in mesh.get_surface_count():
			var mat := mi.get_surface_override_material(s)
			if mat:
				mesh.surface_set_material(s, mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		var local := tmp.global_transform.affine_inverse() * mi.global_transform
		for k in xforms.size():
			mm.set_instance_transform(k, (xforms[k] as Transform3D) * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = name.get_file()
		parent.add_child(mmi)
	tmp.queue_free()
