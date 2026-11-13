class_name ChuaMayBac
extends RefCounted

const TOP_Z := 31.0
const STEPS := 40
const TREAD := 0.4
const RUN := STEPS * TREAD
const REST := 8.0
const W := 5.0
const REST_W := 13.0
const WALL := 0.35
const WALL_H := 0.85

static func flight_z(i: int) -> float:
	return TOP_Z + i * (RUN + REST)

static func foot_z() -> float:
	return flight_z(3) - REST

static func height_at(z: float, drop: float) -> float:
	var rise := drop / 3.0
	for i in 3:
		var z0 := flight_z(i)
		if z < z0:
			return -rise * i
		if z <= z0 + RUN:
			return -rise * i - rise * ceilf((z - z0) / TREAD - 0.001) / STEPS
	return -drop

static func build(chua: ChuaMay, drop: float) -> void:
	var rise := drop / 3.0 / STEPS
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b := StaticBody3D.new()
	b.name = "StairSolid"
	chua.add_child(b)
	for i in 3:
		var z0 := flight_z(i)
		var y0 := -drop / 3.0 * i
		for k in STEPS:
			var top := y0 - rise * (k + 1)
			_box(st, Vector3(W, rise + 0.3, TREAD + 0.02), Vector3(0, top - (rise + 0.3) / 2.0, z0 + TREAD * (k + 0.5)))
		var y1 := y0 - drop / 3.0
		var mid := Vector3(0, (y0 + y1) / 2.0, z0 + RUN / 2.0)
		var slope := atan2(y0 - y1, RUN)
		var length := sqrt(RUN * RUN + (y0 - y1) * (y0 - y1))
		for sx in [-1.0, 1.0]:
			var c := mid + Vector3(sx * (W + WALL) / 2.0, WALL_H / 2.0 - 0.35, 0)
			_box(st, Vector3(WALL, WALL_H + 0.7, length), c, Basis(Vector3.RIGHT, slope))
			_box(st, Vector3(WALL + 0.1, 0.1, length), c + Vector3(0, (WALL_H + 0.7) / 2.0 + 0.04, 0), Basis(Vector3.RIGHT, slope))
			for p in 5:
				var pz := z0 + RUN * p / 4.0
				_post(st, Vector3(sx * (W + WALL) / 2.0, height_at(pz - 0.01, drop) if p > 0 else y0, pz))
			_solid_box(b, Vector3(WALL, 1.6, length), c + Vector3(0, 0.3, 0), Basis(Vector3.RIGHT, slope))
		_box(st, Vector3(W + 2 * WALL, 0.6, length), mid - Vector3(0, 0.62, 0), Basis(Vector3.RIGHT, slope))
		_ramp(b, Vector3(0, y0, z0), Vector3(0, y1, z0 + RUN))
		var rz := z0 + RUN
		var rl := REST if i < 2 else 3.0
		_box(st, Vector3(REST_W, 0.8, rl), Vector3(0, y1 - 0.4, rz + rl / 2.0))
		_solid_box(b, Vector3(REST_W, 0.8, rl), Vector3(0, y1 - 0.4, rz + rl / 2.0))
		if i < 2:
			for sx in [-1.0, 1.0]:
				_box(st, Vector3(WALL, WALL_H, rl), Vector3(sx * (REST_W - WALL) / 2.0, y1 + WALL_H / 2.0, rz + rl / 2.0))
				_solid_box(b, Vector3(WALL, 1.4, rl), Vector3(sx * (REST_W - WALL) / 2.0, y1 + 0.7, rz + rl / 2.0))
				for pz in [rz, rz + rl]:
					_post(st, Vector3(sx * (REST_W - WALL) / 2.0, y1, pz))
				HomeKit.place(chua, "ghe_da", Vector3(sx * 3.4, y1, rz + rl * 0.55), -90.0 * sx)
				var t := HomeKit.place_plant(chua, "chua/cay_dai", Vector3(sx * 5.0, y1, rz + rl * 0.3), 60.0 * sx)
				for mi: MeshInstance3D in t.find_children("*", "MeshInstance3D", true, false):
					mi.visibility_range_end = ChuaMayCanh.TREE_END
	var mi := MeshInstance3D.new()
	mi.name = "Stair"
	mi.mesh = st.commit()
	mi.material_override = ChuaMayCanh.stone()
	chua.add_child(mi)
	for sx in [-1.0, 1.0]:
		Furniture.place(chua, "den_da_chua", Vector3(sx * 4.2, -drop, foot_z() + 1.5), 0.0, true)

static func _box(st: SurfaceTool, size: Vector3, at: Vector3, basis := Basis()) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	st.append_from(bm, 0, Transform3D(basis, at))

static func _post(st: SurfaceTool, at: Vector3) -> void:
	_box(st, Vector3(0.5, 1.25, 0.5), at + Vector3(0, 0.62 - 0.05, 0))
	var s := SphereMesh.new()
	s.radius = 0.2
	s.height = 0.5
	s.radial_segments = 8
	s.rings = 4
	st.append_from(s, 0, Transform3D(Basis(), at + Vector3(0, 1.38, 0)))

static func _solid_box(b: StaticBody3D, size: Vector3, at: Vector3, basis := Basis()) -> void:
	var s := BoxShape3D.new()
	s.size = size
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.transform = Transform3D(basis, at)
	b.add_child(cs)

static func _ramp(b: StaticBody3D, hi: Vector3, lo: Vector3) -> void:
	var fwd := (hi - lo).normalized()
	var up := (Vector3.UP - fwd * fwd.dot(Vector3.UP)).normalized()
	var s := BoxShape3D.new()
	s.size = Vector3(W, 0.2, (hi - lo).length() + 0.3)
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.transform = Transform3D(Basis(up.cross(fwd), up, fwd), (hi + lo) / 2.0 - up * 0.1)
	b.add_child(cs)
