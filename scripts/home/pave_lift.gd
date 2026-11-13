class_name PaveLift
extends RefCounted

const KINDS := ["ngo_gach", "ngo_vien", "da_lat"]
const YARDS := "res://data/hometown/house_yards.json"
const XOM := "res://data/hometown/xom_dinh.json"
const PROPS := "res://props/hometown/%s.glb"

var grid = null
var _cells := {}
var count := 0

static func of(map: Node) -> PaveLift:
	if map == null:
		return null
	if map.has_meta(&"pave_lift"):
		return map.get_meta(&"pave_lift")
	var t0 := Time.get_ticks_usec()
	var pl := PaveLift.new()
	if ClassDB.class_exists(&"PaveGrid"):
		pl.grid = ClassDB.instantiate(&"PaveGrid")
	pl._add_house_yards(map)
	pl._add_xom_dinh()
	map.set_meta(&"pave_lift", pl)
	print("pave_lift: %d squares (%s) in %.1f ms" % [pl.count, "C++" if pl.grid else "gd", (Time.get_ticks_usec() - t0) / 1000.0])
	return pl

func add(xf: Transform3D, box: AABB) -> void:
	count += 1
	if grid:
		grid.add(xf, box)
		return
	var e := [xf.affine_inverse(), xf, box.position.x, box.end.x, box.position.z, box.end.z, box.end.y * 0.8]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c: Vector3 in [Vector3(box.position.x, 0, box.position.z), Vector3(box.end.x, 0, box.position.z),
			Vector3(box.position.x, 0, box.end.z), Vector3(box.end.x, 0, box.end.z)]:
		var w := xf * c
		lo = Vector2(minf(lo.x, w.x), minf(lo.y, w.z))
		hi = Vector2(maxf(hi.x, w.x), maxf(hi.y, w.z))
	for cx in range(floori(lo.x / 2.0), floori(hi.x / 2.0) + 1):
		for cz in range(floori(lo.y / 2.0), floori(hi.y / 2.0) + 1):
			var k := Vector2i(cx, cz)
			if not _cells.has(k):
				_cells[k] = []
			_cells[k].append(e)

func top(q: Vector3) -> float:
	if grid:
		return grid.top(q.x, q.y, q.z)
	var best := -INF
	for e: Array in _cells.get(Vector2i(floori(q.x / 2.0), floori(q.z / 2.0)), []):
		var l: Vector3 = (e[0] as Transform3D) * q
		if l.x >= e[2] and l.x <= e[3] and l.z >= e[4] and l.z <= e[5]:
			best = maxf(best, ((e[1] as Transform3D) * Vector3(l.x, e[6], l.z)).y)
	return best

func _add_house_yards(map: Node) -> void:
	var path := YARDS
	if OS.get_environment("MC_GOCSAN_OLD") != "" and FileAccess.file_exists(path.replace(".json", "_old.json")):
		path = path.replace(".json", "_old.json")
	if not FileAccess.file_exists(path) or not map.has_method("height_at"):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		return
	var boxes := {}
	for it: Array in d.get("items", []):
		var kind := str(it[0])
		if not KINDS.any(func(k: String) -> bool: return kind.begins_with(k)):
			continue
		if not boxes.has(kind):
			boxes[kind] = _mesh_box(kind)
		var box: AABB = boxes[kind]
		if box.size == Vector3.ZERO:
			continue
		var x := float(it[1])
		var z := float(it[2])
		var b := Basis(Vector3.UP, deg_to_rad(float(it[3]))) * Basis.from_scale(Vector3.ONE * float(it[4]))
		add(Transform3D(b, Vector3(x, float(map.height_at(x, z)), z)), box)

func _add_xom_dinh() -> void:
	if not FileAccess.file_exists(XOM):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(XOM))
	if not d is Dictionary or not d.has("pave"):
		return
	var boxes := {}
	for it: Array in d["pave"]:
		var kind := str(it[0])
		if not boxes.has(kind):
			boxes[kind] = _mesh_box(kind)
		var box: AABB = boxes[kind]
		if box.size == Vector3.ZERO:
			continue

		var up := Vector3(it[5], it[6], it[7]).normalized()
		var f := Basis(Vector3.UP, deg_to_rad(float(it[4]))).z
		var zf := (f - up * f.dot(up)).normalized()
		var b := Basis(up.cross(zf), up, zf).scaled_local(Vector3(float(it[8]), 1.0, float(it[9])))
		add(Transform3D(b, Vector3(it[1], it[2], it[3])), box)

static func _mesh_box(kind: String) -> AABB:
	var path := PROPS % kind
	if not ResourceLoader.exists(path):
		return AABB()
	var root := (load(path) as PackedScene).instantiate() as Node3D
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var n: Node = mi
		while n != root and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b := xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	root.free()
	return box
