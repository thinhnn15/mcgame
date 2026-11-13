extends RefCounted

var cell := 20.0

var groups := {}
var regions := {}
var tris := 0

func load_atlas(json_path: String) -> Dictionary:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	for set_name in d["regions"]:
		var r := {}
		for k in d["regions"][set_name]:
			var a: Array = d["regions"][set_name][k]
			r[k] = Rect2(a[0], a[1], a[2] - a[0], a[3] - a[1])
		regions[set_name] = r
	return d

func uv(set_name: String, name: String, s := Rect2(0, 0, 1, 1)) -> Rect2:
	var r: Rect2 = regions[set_name][name]
	return Rect2(r.position + s.position * r.size, s.size * r.size)

func _group(mat: Material, at: Vector3) -> Dictionary:
	var key := "%d|%d|%d" % [mat.get_instance_id(), floori(at.x / cell), floori(at.z / cell)]
	if not groups.has(key):
		groups[key] = {"mat": mat, "v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(),
			"c": PackedColorArray(), "i": PackedInt32Array()}
	return groups[key]

static func vcol(c: Color, glow := 0.0) -> Color:
	var l := c.srgb_to_linear()
	return Color(l.r, l.g, l.b, 1.0 - glow)

func quad4(mat: Material, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, r: Rect2, col: Color, glow := 0.0,
		two_sided := false, cell_at = null) -> void:
	var g := _group(mat, cell_at if cell_at != null else (p0 + p2) * 0.5)
	var n := (p1 - p0).cross(p3 - p0).normalized()
	var vc := vcol(col, glow)
	var u0 := r.position.x
	var v0 := r.position.y
	var u1 := r.end.x
	var v1 := r.end.y
	var sides := [1, -1] if two_sided else [1]
	for s in sides:
		var b: int = g["v"].size()
		g["v"].append_array(PackedVector3Array([p0, p1, p2, p3]))
		for k in 4:
			g["n"].append(n * s)
			g["c"].append(vc)
		g["uv"].append_array(PackedVector2Array([Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0), Vector2(u0, v0)]))
		if s > 0:
			g["i"].append_array(PackedInt32Array([b, b + 3, b + 2, b, b + 2, b + 1]))
		else:
			g["i"].append_array(PackedInt32Array([b, b + 2, b + 3, b, b + 1, b + 2]))
		tris += 2

func quad(mat: Material, xf: Transform3D, size: Vector2, r: Rect2, col: Color, glow := 0.0, two_sided := false, cell_at = null) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	quad4(mat, xf * Vector3(-hx, -hy, 0), xf * Vector3(hx, -hy, 0), xf * Vector3(hx, hy, 0), xf * Vector3(-hx, hy, 0),
		r, col, glow, two_sided, cell_at)

func box(mat: Material, xf: Transform3D, size: Vector3, faces: Dictionary, col: Color, glow := 0.0, cell_at = null) -> void:
	var h := size * 0.5
	var at = cell_at if cell_at != null else xf.origin
	var c := func(x: float, y: float, z: float) -> Vector3: return xf * Vector3(x * h.x, y * h.y, z * h.z)
	if faces.has("front"):
		quad4(mat, c.call(-1, -1, 1), c.call(1, -1, 1), c.call(1, 1, 1), c.call(-1, 1, 1), faces["front"], col, glow, false, at)
	if faces.has("back"):
		quad4(mat, c.call(1, -1, -1), c.call(-1, -1, -1), c.call(-1, 1, -1), c.call(1, 1, -1), faces["back"], col, glow, false, at)
	if faces.has("left"):
		quad4(mat, c.call(-1, -1, -1), c.call(-1, -1, 1), c.call(-1, 1, 1), c.call(-1, 1, -1), faces["left"], col, glow, false, at)
	if faces.has("right"):
		quad4(mat, c.call(1, -1, 1), c.call(1, -1, -1), c.call(1, 1, -1), c.call(1, 1, 1), faces["right"], col, glow, false, at)
	if faces.has("top"):
		quad4(mat, c.call(-1, 1, 1), c.call(1, 1, 1), c.call(1, 1, -1), c.call(-1, 1, -1), faces["top"], col, glow, false, at)
	if faces.has("bottom"):
		quad4(mat, c.call(-1, -1, -1), c.call(1, -1, -1), c.call(1, -1, 1), c.call(-1, -1, 1), faces["bottom"], col, glow, false, at)

static func all_faces(r: Rect2, names := ["front", "back", "left", "right", "top", "bottom"]) -> Dictionary:
	var d := {}
	for n in names:
		d[n] = r
	return d

func cyl(mat: Material, xf: Transform3D, r: float, h: float, segs: int, side: Rect2, cap: Rect2, col: Color, caps := true) -> void:
	var g := _group(mat, xf.origin)
	var vc := vcol(col)
	var b: int = g["v"].size()
	for i in segs + 1:
		var a := TAU * i / segs
		var d := Vector3(sin(a), 0, cos(a))
		var nrm := (xf.basis * d).normalized()
		for y in [-0.5, 0.5]:
			g["v"].append(xf * (d * r + Vector3(0, y * h, 0)))
			g["n"].append(nrm)
			g["c"].append(vc)
			g["uv"].append(Vector2(side.position.x + side.size.x * float(i) / segs, side.end.y if y < 0 else side.position.y))
	for i in segs:
		var k := b + i * 2
		g["i"].append_array(PackedInt32Array([k, k + 1, k + 3, k, k + 3, k + 2]))
		tris += 2
	if caps:
		for y in [-0.5, 0.5]:
			var nrm := (xf.basis * Vector3(0, y * 2, 0)).normalized()
			var c0: int = g["v"].size()
			g["v"].append(xf * Vector3(0, y * h, 0))
			g["n"].append(nrm)
			g["c"].append(vc)
			g["uv"].append(cap.get_center())
			for i in segs:
				var a := TAU * i / segs
				g["v"].append(xf * Vector3(sin(a) * r, y * h, cos(a) * r))
				g["n"].append(nrm)
				g["c"].append(vc)
				g["uv"].append(cap.get_center() + Vector2(sin(a), cos(a)) * cap.size * 0.5)
			for i in segs:
				var p := c0 + 1 + i
				var q := c0 + 1 + (i + 1) % segs
				if y > 0:
					g["i"].append_array(PackedInt32Array([c0, q, p]))
				else:
					g["i"].append_array(PackedInt32Array([c0, p, q]))
				tris += 1

func commit(parent: Node3D) -> int:
	var n := 0
	for g in groups.values():
		if (g["i"] as PackedInt32Array).is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g["v"]
		arr[Mesh.ARRAY_NORMAL] = g["n"]
		arr[Mesh.ARRAY_TEX_UV] = g["uv"]
		arr[Mesh.ARRAY_COLOR] = g["c"]
		arr[Mesh.ARRAY_INDEX] = g["i"]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.name = "Batch"
		mi.mesh = am
		mi.material_override = g["mat"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		n += 1
	groups.clear()
	return n
