class_name Props
extends RefCounted

const TOON := preload("res://shaders/toon.gdshader")
const CELL := 10.0
const PART := "prop_part"

static var _mats := {}
static var _shared := {}
static var _arrays := {}
static var _pending := {}

static func mat(c: Color) -> ShaderMaterial:
	var key := c.to_html()
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = TOON
		m.set_shader_parameter("base_color", c)
		_mats[key] = m
	return _mats[key]

static func mat_glow(c: Color, e: Vector3) -> ShaderMaterial:
	var key := "%s:%s" % [c.to_html(), e]
	if not _mats.has(key):
		var m := mat(c).duplicate() as ShaderMaterial
		m.set_shader_parameter("emission", e)
		_mats[key] = m
	return _mats[key]

static func mesh(parent: Node3D, m: Mesh, c: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 32
	s.rings = 16
	return s

static func cyl(r0: float, r1: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = r0
	c.top_radius = r1
	c.height = h
	c.radial_segments = 24
	return c

static func box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b

static func solid(parent: Node3D, shape: Shape3D, pos: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	sb.add_child(cs)
	sb.position = pos
	parent.add_child(sb)

static func at(root: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = deg_to_rad(yaw)
	root.add_child(n)
	return n

static func _sph(r: float) -> Mesh:
	var key := "s:%.4f" % r
	if not _shared.has(key):
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2
		s.radial_segments = clampi(int(8.0 + r * 28.0), 8, 28)
		s.rings = maxi(4, s.radial_segments / 2)
		_shared[key] = s
	return _shared[key]

static func _cyl(r0: float, r1: float, h: float) -> Mesh:
	var key := "c:%.4f:%.4f:%.4f" % [r0, r1, h]
	if not _shared.has(key):
		var c := CylinderMesh.new()
		c.bottom_radius = r0
		c.top_radius = r1
		c.height = h
		c.radial_segments = clampi(int(8.0 + maxf(r0, r1) * 40.0), 8, 24)
		c.rings = 1
		_shared[key] = c
	return _shared[key]

static func _box(s: Vector3) -> Mesh:
	var key := "b:%s" % s
	if not _shared.has(key):
		_shared[key] = box(s)
	return _shared[key]

static func _part(root: Node3D, parent: Node3D, m: Mesh, c: Variant, pos: Vector3, rot := Vector3.ZERO,
		scl := Vector3.ONE, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = c if c is Material else mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta(PART, true)
	parent.add_child(mi)
	if _pending.is_empty():
		Props._flush.call_deferred()
	_pending[root.get_instance_id()] = true
	return mi

static func _flush() -> void:
	for id in _pending:
		var root := instance_from_id(id) as Node3D
		if root != null:
			bake(root)
	_pending.clear()

static func bake(root: Node3D) -> void:
	var groups := {}
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not mi.has_meta(PART) or mi.is_queued_for_deletion():
			continue
		var xf := mi.transform
		var p := mi.get_parent()
		while p != root and p != null:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var cell := Vector2i(floori(xf.origin.x / CELL), floori(xf.origin.z / CELL))
		var key := [mi.material_override.get_instance_id(), mi.cast_shadow, cell]
		if not groups.has(key):
			groups[key] = {"mat": mi.material_override, "shadow": mi.cast_shadow, "parts": []}
		groups[key]["parts"].append([mi.mesh, xf])
		mi.queue_free()
	for g in groups.values():
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		for part in g["parts"]:
			var m: Mesh = part[0]
			var xf: Transform3D = part[1]
			var a: Array = _arrays.get(m.get_instance_id(), [])
			if a.is_empty():
				a = m.surface_get_arrays(0)
				_arrays[m.get_instance_id()] = a
			var nb := xf.basis.inverse().transposed()
			var base := verts.size()
			for v: Vector3 in a[Mesh.ARRAY_VERTEX]:
				verts.append(xf * v)
			for n: Vector3 in a[Mesh.ARRAY_NORMAL]:
				norms.append((nb * n).normalized())
			uvs.append_array(a[Mesh.ARRAY_TEX_UV])
			for i: int in a[Mesh.ARRAY_INDEX]:
				idx.append(base + i)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var out := MeshInstance3D.new()
		out.name = "Merged"
		out.mesh = am
		out.material_override = g["mat"]
		out.cast_shadow = g["shadow"]
		root.add_child(out)

static func tree(root: Node3D, pos: Vector3, leaf := Color("6fcf6a"), size := 1.0, fruit := Color(0, 0, 0, 0)) -> Node3D:
	var n := at(root, pos, randf() * 360.0)
	n.scale = Vector3.ONE * size
	_part(root, n, _cyl(0.16, 0.12, 1.3), Color("a9744f"), Vector3(0, 0.65, 0))
	for p in [[Vector3(0, 1.75, 0), 0.85], [Vector3(0.45, 1.5, 0.1), 0.6], [Vector3(-0.42, 1.55, -0.1), 0.62],
			[Vector3(0.05, 2.25, 0.05), 0.6]]:
		_part(root, n, _sph(p[1]), leaf, p[0])
	if fruit.a > 0:
		for i in 5:
			var a := i * TAU / 5.0
			_part(root, n, _sph(0.1), fruit, Vector3(cos(a) * 0.7, 1.45 + 0.25 * sin(a * 2.0), sin(a) * 0.7))
	var cap := CylinderShape3D.new()
	cap.radius = 0.25 * size
	cap.height = 2.0
	solid(root, cap, pos + Vector3(0, 1, 0))
	return n

static func flower(root: Node3D, pos: Vector3, petal: Color) -> Node3D:
	var n := at(root, pos, randf() * 360.0)
	_part(root, n, _cyl(0.015, 0.015, 0.28), Color("5fb85a"), Vector3(0, 0.14, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 5:
		var a := i * TAU / 5.0
		_part(root, n, _sph(0.055), petal, Vector3(cos(a) * 0.06, 0.3, sin(a) * 0.06), Vector3.ZERO, Vector3(1, 0.6, 1), false)
	_part(root, n, _sph(0.04), Color("ffe17a"), Vector3(0, 0.31, 0), Vector3.ZERO, Vector3.ONE, false)
	return n

static func bush(root: Node3D, pos: Vector3, c := Color("5cc46b"), bloom := Color(0, 0, 0, 0)) -> Node3D:
	var n := at(root, pos, randf() * 360.0)
	for p in [[Vector3(0, 0.3, 0), 0.42], [Vector3(0.3, 0.25, 0.1), 0.3], [Vector3(-0.3, 0.25, -0.05), 0.32]]:
		_part(root, n, _sph(p[1]), c, p[0])
	if bloom.a > 0:
		for i in 7:
			var a := i * TAU / 7.0
			_part(root, n, _sph(0.07), bloom, Vector3(cos(a) * 0.36, 0.4 + 0.12 * sin(a * 3.0), sin(a) * 0.32))
	var s := SphereShape3D.new()
	s.radius = 0.45
	solid(root, s, pos + Vector3(0, 0.3, 0))
	return n

static func rock(root: Node3D, pos: Vector3, s := 1.0) -> Node3D:
	var n := at(root, pos, randf() * 360.0)
	_part(root, n, _sph(0.35 * s), Color("b9b4c4"), Vector3(0, 0.12 * s, 0), Vector3.ZERO, Vector3(1.2, 0.65, 1.0))
	return n

static func fence(root: Node3D, a: Vector3, b: Vector3, c := Color("fff3e3")) -> void:
	var d := b - a
	var n := int(d.length() / 0.5)
	for i in n + 1:
		var p := a + d * (float(i) / float(maxi(n, 1)))
		_part(root, root, _box(Vector3(0.1, 0.55, 0.08)), c, p + Vector3(0, 0.27, 0))
		_part(root, root, _sph(0.06), c, p + Vector3(0, 0.56, 0))
	for h in [0.2, 0.42]:
		var rail := _part(root, root, _box(Vector3(d.length(), 0.06, 0.04)), c, (a + b) / 2.0 + Vector3(0, h, 0))
		rail.rotation.y = -atan2(d.z, d.x)
	var bs := BoxShape3D.new()
	bs.size = Vector3(d.length(), 0.6, 0.2)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = bs
	sb.add_child(cs)
	sb.position = (a + b) / 2.0 + Vector3(0, 0.3, 0)
	sb.rotation.y = -atan2(d.z, d.x)
	root.add_child(sb)

static func lamp(root: Node3D, pos: Vector3) -> Node3D:
	var n := at(root, pos)
	_part(root, n, _cyl(0.06, 0.05, 1.9), Color("6a7fa8"), Vector3(0, 0.95, 0))
	_part(root, n, _sph(0.16), mat_glow(Color("fff3c4"), Vector3(1.0, 0.85, 0.5) * 0.6), Vector3(0, 2.0, 0))
	_part(root, n, _cyl(0.2, 0.05, 0.12), Color("6a7fa8"), Vector3(0, 2.18, 0))
	var c := CylinderShape3D.new()
	c.radius = 0.1
	c.height = 2.0
	solid(root, c, pos + Vector3(0, 1, 0))
	return n

static func bench(root: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := at(root, pos, yaw)
	var wood := Color("d99a6c")
	_part(root, n, _box(Vector3(1.3, 0.08, 0.42)), wood, Vector3(0, 0.42, 0))
	_part(root, n, _box(Vector3(1.3, 0.32, 0.07)), wood, Vector3(0, 0.66, 0.2), Vector3(-10, 0, 0))
	for x in [-0.55, 0.55]:
		_part(root, n, _box(Vector3(0.08, 0.42, 0.38)), Color("8a6a5a"), Vector3(x, 0.21, 0))
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.3, 0.8, 0.5)
	solid(root, bs, pos + Vector3(0, 0.4, 0))
	return n

static func house(root: Node3D, pos: Vector3, yaw: float, wall: Color, roof_c: Color) -> Node3D:
	var n := at(root, pos, yaw)
	_part(root, n, _box(Vector3(3.2, 2.2, 2.8)), wall, Vector3(0, 1.1, 0))
	if not _shared.has("roof"):
		var roof := PrismMesh.new()
		roof.size = Vector3(3.8, 1.3, 3.3)
		_shared["roof"] = roof
	_part(root, n, _shared["roof"], roof_c, Vector3(0, 2.85, 0))
	_part(root, n, _box(Vector3(0.8, 1.35, 0.1)), Color("a8704e"), Vector3(0, 0.68, 1.42))
	_part(root, n, _sph(0.05), Color("ffe17a"), Vector3(0.25, 0.7, 1.49))
	for x in [-1.0, 1.0]:
		_part(root, n, _box(Vector3(0.62, 0.62, 0.08)), mat_glow(Color("cfeeff"), Vector3(0.3, 0.35, 0.4)), Vector3(x, 1.35, 1.41))
		_part(root, n, _box(Vector3(0.74, 0.1, 0.14)), Color("ffffff"), Vector3(x, 1.0, 1.44))
	_part(root, n, _cyl(0.18, 0.18, 0.7), Color("c96a5a"), Vector3(0.9, 3.4, -0.5))
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.3, 2.4, 2.9)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos + Vector3(0, 1.2, 0)
	sb.rotation.y = deg_to_rad(yaw)
	root.add_child(sb)
	return n

static func pier(root: Node3D, pos: Vector3, yaw: float, length := 5.0) -> Node3D:
	var n := at(root, pos, yaw)
	for i in int(length / 0.45):
		_part(root, n, _box(Vector3(1.4, 0.08, 0.4)), Color("d9a77c") if i % 2 == 0 else Color("cf9b70"), Vector3(0, 0.05, -i * 0.45))
	for i in range(0, int(length / 0.45), 3):
		for x in [-0.65, 0.65]:
			_part(root, n, _cyl(0.07, 0.07, 1.2), Color("9a6a4c"), Vector3(x, -0.4, -i * 0.45))
	return n
