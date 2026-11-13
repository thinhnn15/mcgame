class_name NhaThoDa
extends Node3D

const K := 0.78
const SITE := Vector2(700.0, 640.0)
const POND := Rect2(-47.0, 37.0, 94.0, 38.0)
const KERB_IN := 0.8
const ISLAND := Vector3(0, 0, 56.0)
const PHUONG_DINH := Vector3(0, 0, 17.0)
const CATHEDRAL := Vector3(0, 0, -40.0)
const TOMB := Vector3(0, 0, 0.0)
const CHAPELS := [[-26.0, -48.0, 90.0], [-26.0, -26.0, 90.0], [26.0, -48.0, -90.0], [26.0, -26.0, -90.0]]
const INSIDE_SEEN := 75.0

var water := -1.6

const STONE_CHAPEL := Vector3(-32.0, 0, -72.0)
const HOUSES := [["nha_cu", -41.0, -62.0, 90.0], ["nha_thai", -41.0, -6.0, 90.0], ["nha_thai", 41.0, -62.0, -90.0],
	["nha_cu", 41.0, -6.0, -90.0]]
const BENCHES := [[-14.5, -4.0, 90.0], [-14.5, 6.0, 90.0], [14.5, -4.0, -90.0], [14.5, 6.0, -90.0],
	[-20.0, 35.6, 180.0], [20.0, 35.6, 180.0]]
const POTS := [[-6.0, 24.2], [6.0, 24.2], [-6.0, -14.6], [6.0, -14.6], [-3.0, 33.9], [3.0, 33.9]]
const TREES := [["cay/cay_gao", -30.0, 25.0, 60.0], ["cay/cay_keo", 30.0, 25.0, 15.0], ["cay/cay_keo", -38.0, 12.0, 160.0],
	["cay/cay_gao", 38.0, 12.0, 280.0], ["cay/cay_phuong", -52.0, 33.0, 10.0], ["cay/cay_phuong", 52.0, 33.0, 200.0],
	["cay/cay_keo", -53.0, 79.0, 70.0], ["cay/cay_keo", 53.0, 79.0, 140.0],
	["cay/cay_gao", -21.0, 8.0, 30.0], ["cay/cay_gao", 21.0, 8.0, 250.0],
	["cay/cay_keo", -40.0, -10.0, 300.0], ["cay/cay_keo", 40.0, -10.0, 120.0],
	["cay/cay_keo", -16.0, -80.0, 80.0], ["cay/cay_keo", 16.0, -80.0, 210.0]]

static func add_to_map(world: Node3D) -> NhaThoDa:
	var khu := NhaThoDa.new()
	if OS.get_cmdline_user_args().has("--no-khu"):
		world.add_child(khu)
		khu.set_process(OS.get_cmdline_user_args().has("--khu-measure"))
		return khu
	khu.name = "KhuNhaThoDa"
	var y := 1.6
	var lay = world.get("layout")
	if lay is Dictionary and lay.has("nha_tho_da"):
		var t: Dictionary = lay["nha_tho_da"]
		y = float(t["y"])
		khu.water = float(t["water_y"]) - y
	elif world.has_method("height_at"):
		y = world.height_at(SITE.x, SITE.y)
	khu.position = Vector3(SITE.x, y, SITE.y)
	world.add_child(khu)
	khu.build()
	khu.set_process(OS.get_cmdline_user_args().has("--khu-measure"))
	return khu

var _t := 0.0

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	_t += delta
	if _t > 4.0:
		print("NhaThoDa measure: %.1fk tris, %d draws, fps %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Engine.get_frames_per_second()])
		set_process(false)

func build() -> void:
	var san := HomeKit.place(self, "san_pd", Vector3.ZERO, 0.0)
	_no_shadow(san)
	var pd := HomeKit.place(self, "phuong_dinh", PHUONG_DINH, 0.0, {}, 100.0)
	_phuong_dinh_solid(pd)
	_shadow_proxy(pd, "phuong_dinh", 100.0)
	var nt := HomeKit.place(self, "nha_tho_da", CATHEDRAL, 0.0, {}, 110.0)
	_cathedral_solid(nt)
	_shadow_proxy(nt, "nha_tho_da", 110.0)
	var inside := HomeKit.place(self, "nha_tho_da_trong", CATHEDRAL, 0.0)
	_no_shadow(inside)
	for gi: GeometryInstance3D in inside.find_children("*", "GeometryInstance3D", true, false):
		gi.visibility_range_end = INSIDE_SEEN
	for c: Array in CHAPELS:
		var ch := HomeKit.place(self, "nha_tho_nho", Vector3(c[0], 0, c[1]), c[2], {}, 70.0)
		_chapel_solid(ch)
		_shadow_proxy(ch, "nha_tho_nho", 70.0)
	var sc := HomeKit.place(self, "nha_nguyen_da", STONE_CHAPEL, 0.0, {}, 70.0)
	_shadow_proxy(sc, "nha_nguyen_da", 70.0)
	_stone_chapel_solid(sc)
	var tomb := HomeKit.place(self, "mo_cu_sau", TOMB, 0.0)
	_no_shadow(tomb)
	var b := _body(tomb)
	_box(b, Vector3(3.2, 1.2, 4.2), Vector3(0, 0.6, 0))
	var island := HomeKit.place(self, "dao_pd", ISLAND + Vector3(0, water + 0.6, 0), 0.0)
	_no_shadow(island)
	HomeKit.place(self, "tuong_thanh_tam", ISLAND + Vector3(0, water + 0.6 + 0.14, 0), 0.0)
	_box(_body(island), Vector3(10.0, 1.2, 10.0) / K, Vector3(0, -0.6, 0) / K)
	for k in 7:
		var a := TAU * (k + 0.3) / 7.0
		HomeKit.place_plant(self, "cay/bui_dai_a" if k % 2 else "cay/bui_dai_b",
				ISLAND + Vector3(cos(a) * 3.6, water + 0.6, sin(a) * 3.6), k * 53.0)
	for t: Array in TREES:
		HomeKit.place_plant(self, t[0], Vector3(t[1], 0, t[2]), t[3])
	for hh: Array in HOUSES:
		var house := HomeKit.place(self, hh[0], Vector3(hh[1], 0, hh[2]), hh[3])
		_box(_body(house), Vector3(9.0, 5.0, 7.0), Vector3(0, 2.5, 0))
	for bn: Array in BENCHES:
		HomeKit.place(self, "ghe_da", Vector3(bn[0], 0.06, bn[1]), bn[2])
	for pt: Array in POTS:
		Furniture.place(self, "chau_canh", Vector3(pt[0], 0.5 if pt[1] > 33.0 else 0.06, pt[1]), 0.0, false)
	_light_shafts(inside)
	_grounds_solid()

	for o: Array in [[Vector3(1.0, 7.0, 57.0), Vector3(-9.1, 4.4, -2.0)], [Vector3(1.0, 7.0, 57.0), Vector3(9.1, 4.4, -2.0)],
			[Vector3(18.0, 7.0, 1.0), Vector3(0, 4.4, -30.5)], [Vector3(18.0, 0.3, 57.0), Vector3(0, 8.1, -2.0)],
			[Vector3(22.0, 6.6, 1.4), Vector3(0, 9.2, 27.8)]]:
		_occluder(nt, o[0], o[1])
	for o: Array in [[Vector3(1.0, 5.6, 10.6), Vector3(-9.65, 3.6, 0)], [Vector3(1.0, 5.6, 10.6), Vector3(9.65, 3.6, 0)],
			[Vector3(20.0, 0.4, 13.6), Vector3(0, 6.4, 0)]]:
		_occluder(pd, o[0], o[1])
	for gi: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		if gi.visibility_range_end <= 0.0 and gi.visibility_range_begin <= 0.0 and not san.is_ancestor_of(gi):
			gi.visibility_range_end = 140.0
			gi.visibility_range_end_margin = 8.0

func _phuong_dinh_solid(n: Node3D) -> void:
	var b := _body(n)
	_box(b, Vector3(22.3, 0.6, 15.8), Vector3(0, 0.3, 0))
	for sz in [-1.0, 1.0]:
		_ramp(b, Vector3(0, 0, sz * 8.9), Vector3(0, 0.6, sz * 7.9), 21.0)
		for x0x1: Vector2 in [Vector2(-10.25, -7.0), Vector2(-4.2, -2.1), Vector2(2.1, 4.2), Vector2(7.0, 10.25)]:
			_box(b, Vector3(x0x1.y - x0x1.x, 6.0, 1.5), Vector3((x0x1.x + x0x1.y) / 2.0, 3.6, sz * 6.25))
		_box(b, Vector3(1.2, 6.0, 11.0), Vector3(sz * 9.65, 3.6, 0))
	for x in [-3.85, 3.85]:
		for z in [-2.6, 2.6]:
			_box(b, Vector3(0.7, 6.0, 0.7), Vector3(x, 3.6, z))
	_box(b, Vector3(2.6, 0.75, 1.5), Vector3(0, 0.98, 0))

func _cathedral_solid(n: Node3D) -> void:
	var b := _body(n)
	_box(b, Vector3(21.6, 0.6, 60.6), Vector3(0, 0.3, -1.2))
	_box(b, Vector3(23.8, 0.6, 2.4), Vector3(0, 0.3, 29.8))
	_ramp(b, Vector3(0, 0, 32.4), Vector3(0, 0.6, 31.0), 16.0)
	for sx in [-1.0, 1.0]:
		_box(b, Vector3(1.0, 7.4, 58.0), Vector3(sx * 9.1, 4.3, -2.0))
		_box(b, Vector3(2.1, 12.0, 1.6), Vector3(sx * 10.15, 6.6, 27.8))
		_box(b, Vector3(2.0, 12.0, 1.6), Vector3(sx * 6.0, 6.6, 27.8))
		_box(b, Vector3(1.15, 12.0, 1.6), Vector3(sx * 2.275, 6.6, 27.8))
		_box(b, Vector3(2.0, 12.0, 1.6), Vector3(sx * 3.85, 6.6, 27.8))
		_box(b, Vector3(2.0, 12.0, 1.6), Vector3(sx * 8.1, 6.6, 27.8))
	_box(b, Vector3(19.2, 7.4, 1.0), Vector3(0, 4.3, -30.5))
	for x in [-5.8, -2.9, 2.9, 5.8]:
		for k in 10:
			_cyl(b, 0.4, 0.6, 7.4, x, -20.0 + 5.0 * k)
	for k in 15:
		var z := -18.5 + 2.6 * k
		for j in 10:
			if absf(z - (-20.0 + 5.0 * j)) < 0.75:
				z += 0.9
				break
		for sx in [-1.0, 1.0]:
			_box(b, Vector3(1.85, 1.1, 0.65), Vector3(sx * 1.525, 1.15, z - 0.1))
			_box(b, Vector3(2.0, 1.1, 0.65), Vector3(sx * 4.35, 1.15, z - 0.1))
	_box(b, Vector3(17.2, 1.1, 7.2), Vector3(0, 0.55, -26.4))
	_ramp(b, Vector3(0, 0.6, -22.3), Vector3(0, 1.1, -22.8), 8.0)
	_box(b, Vector3(3.6, 1.8, 1.2), Vector3(0, 2.0, -26.0))

func _chapel_solid(n: Node3D) -> void:
	var b := _body(n)
	_box(b, Vector3(9.6, 7.4, 13.0), Vector3(0, 3.7, -0.3))
	_box(b, Vector3(11.6, 0.5, 15.8), Vector3(0, 0.25, 0.1))

func _stone_chapel_solid(n: Node3D) -> void:
	var b := _body(n)
	_box(b, Vector3(7.8, 4.6, 14.2), Vector3(0, 2.3, -0.2))
	_box(b, Vector3(8.8, 0.5, 15.6), Vector3(0, 0.25, 0.1))

func _grounds_solid() -> void:
	var b := _body(self)
	var s := 1.0 / K
	_box(b, Vector3(20.0, 0.5, 9.0) * s, Vector3(0, 0.25, 28.5) * s)
	for sx in [-1.0, 1.0]:
		_ramp(b, Vector3(sx * 12.0, 0, 28.5) * s, Vector3(sx * 10.0, 0.5, 28.5) * s, 9.0 * s)
	_ramp(b, Vector3(0, 0, 34.5) * s, Vector3(0, 0.5, 33.0) * s, 20.0 * s)
	_ramp(b, Vector3(0, 0, 22.4) * s, Vector3(0, 0.5, 24.0) * s, 20.0 * s)
	var x0 := POND.position.x + KERB_IN - 0.35
	var x1 := POND.end.x - KERB_IN + 0.35
	var z0 := POND.position.y + KERB_IN - 0.35
	var z1 := POND.end.y - KERB_IN + 0.35
	for seg: Array in [[x0, -31.6, z0], [-28.4, 28.4, z0], [31.6, x1, z0], [x0, x1, z1]]:
		_box(b, Vector3(seg[1] - seg[0], 0.6, 0.7) * s, Vector3((seg[0] + seg[1]) / 2.0, 0.3, seg[2]) * s)
	for x in [x0, x1]:
		_box(b, Vector3(0.7, 0.6, z1 - z0) * s, Vector3(x, 0.3, (z0 + z1) / 2.0) * s)

func _shadow_proxy(n: Node3D, model: String, far_at: float) -> void:
	for mi: GeometryInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.visibility_range_begin <= 0.0:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var proxy: Node3D = load(HomeKit.DIR + model + "_far.glb").instantiate()
	proxy.name = "ShadowProxy"
	n.add_child(proxy)
	for mi: GeometryInstance3D in proxy.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		mi.visibility_range_end = far_at

func _light_shafts(inside: Node3D) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0, 0.86, 0.6, 0.09)
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 5.6) * K
	for z in [-15.0, -9.0, -3.0, 3.0, 9.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var top := Vector3(8.4, 4.0, z) * K
		var foot := Vector3(4.6, 0.6, z + 0.8) * K
		var up := (top - foot).normalized()
		var side := Vector3(0, 0, 1)
		var nrm := up.cross(side).normalized()
		mi.transform = Transform3D(Basis(side, up, nrm), (top + foot) / 2.0)
		mi.visibility_range_end = INSIDE_SEEN
		inside.add_child(mi)

func _occluder(n: Node3D, size: Vector3, centre: Vector3) -> void:
	var oc := OccluderInstance3D.new()
	var bo := BoxOccluder3D.new()
	bo.size = size * K
	oc.occluder = bo
	oc.position = centre * K
	n.add_child(oc)

func _no_shadow(n: Node3D) -> void:
	for gi: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _body(n: Node3D) -> StaticBody3D:
	var b := StaticBody3D.new()
	n.add_child(b)
	return b

func _box(b: StaticBody3D, size: Vector3, centre: Vector3) -> void:
	var s := BoxShape3D.new()
	s.size = size * K
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.position = centre * K
	b.add_child(cs)

func _cyl(b: StaticBody3D, r: float, y0: float, h: float, x: float, z: float) -> void:
	var s := CylinderShape3D.new()
	s.radius = r * K
	s.height = h * K
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.position = Vector3(x, y0 + h / 2.0, z) * K
	b.add_child(cs)

func _ramp(b: StaticBody3D, lo: Vector3, hi: Vector3, width: float) -> void:
	var a := lo * K
	var c := hi * K
	var fwd := (c - a).normalized()
	var up := (Vector3.UP - fwd * fwd.dot(Vector3.UP)).normalized()
	var s := BoxShape3D.new()
	s.size = Vector3(width * K, 0.2, (c - a).length() + 0.3)
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.transform = Transform3D(Basis(up.cross(fwd), up, fwd), (a + c) / 2.0 - up * 0.1)
	b.add_child(cs)
