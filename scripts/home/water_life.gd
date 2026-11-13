class_name WaterLife
extends Node

const CELL := 48.0
const STEP := 6.0
const MIN_DEPTH := 0.8
const APART := 24.0
const R := 5.5
const NEAR_ON := 40.0
const NEAR_OFF := 56.0

const LAKE := [["ca_chep", 3], ["ca_me", 4], ["ca_ro_phi", 4], ["ca_tram", 2], ["ca_diec", 3]]
const RIVER := [["ca_chep", 2], ["ca_me", 4], ["ca_muong", 5], ["ca_nganh", 2], ["ca_that_lat", 1]]

var who: Node3D
var bed: Callable
var max_live := 4
var dense := 1.0
var _cells := {}
var _live := {}
var _t := 0.0

static func make(parent: Node, who_: Node3D, bed_: Callable) -> WaterLife:
	var w := WaterLife.new()
	w.name = "WaterLife"
	w.who = who_
	w.bed = bed_
	w.max_live = 4 if Quality.is_high() else 2
	w.dense = 1.0 if Quality.is_high() else 0.6
	parent.add_child(w)
	return w

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or who == null or not is_instance_valid(who):
		return
	_t = 0.5
	var p := Vector2(who.global_position.x, who.global_position.z)
	var c0 := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var near: Array = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := c0 + Vector2i(dx, dz)
			if not _cells.has(c):
				_cells[c] = _find(c)
			var sp: Array = _cells[c]
			for i in sp.size():
				near.append([p.distance_to(sp[i].c), "%d,%d,%d" % [c.x, c.y, i], sp[i]])
	near.sort_custom(func(a, b): return a[0] < b[0])
	var want := {}
	for e in near:
		if e[0] < NEAR_ON and want.size() < max_live:
			want[e[1]] = e[2]
	for k in _live.keys():
		var keep := want.has(k)
		if not keep:
			for e in near:
				if e[1] == k and e[0] < NEAR_OFF and _live.size() <= max_live:
					keep = true
		if not keep:
			(_live[k] as Node).queue_free()
			_live.erase(k)
	for k in want:
		if not _live.has(k) and _live.size() < max_live:
			_live[k] = _school(want[k])

func _school(s: Dictionary) -> FishSchool:
	var rng := RandomNumberGenerator.new()
	rng.seed = s.seed
	var pool: Array = RIVER if s.river else LAKE
	var kinds := []
	for row in pool:
		if rng.randf() < 0.7:
			kinds.append([row[0], maxi(1, roundi(row[1] * dense * rng.randf_range(0.7, 1.2)))])
	if kinds.is_empty():
		kinds.append(pool[0])
	var w := Water.at(s.c.x, s.c.y)
	var f := FishSchool.make(get_parent(), s.c, s.r, w.x, bed, [])
	f.scarer = who
	f.shallow = 0.2
	for k in kinds:
		f.add_kind(k[0], k[1])
	if Quality.is_high():
		_dress(f, s, w.x, rng)
	return f

static var _meshes := {}
static var _mats := {}

static func _mesh(path: String) -> Mesh:
	if not _meshes.has(path):
		var sc := (load(path) as PackedScene).instantiate()
		_meshes[path] = (sc.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
		sc.free()
	return _meshes[path]

static func _mat(key: String) -> Material:
	if not _mats.has(key):
		if key == "stone":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.45, 0.43, 0.38)
			m.roughness = 1.0
			_mats[key] = m
		elif key == "stem":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.36, 0.52, 0.30)
			m.roughness = 1.0
			_mats[key] = m
		else:
			var m := ShaderMaterial.new()
			m.shader = preload("res://shaders/crop_foliage.gdshader")
			m.set_shader_parameter("atlas", load("res://props/farm/dong_atlas.png"))
			_mats[key] = m
	return _mats[key]

func _dress(f: FishSchool, s: Dictionary, wy: float, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "Bed"
	root.top_level = true
	f.add_child(root)
	var c: Vector2 = s.c
	var r: float = (s.r as Vector2).x
	var bed_at := func(x: float, z: float) -> float: return bed.call(x, z)
	var stones := []
	for i in rng.randi_range(4, 7):
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * r * sqrt(rng.randf()) * 1.1
		var sc := rng.randf_range(0.22, 0.5)
		stones.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.6, 1.0), sc)),
			Vector3(p.x, bed_at.call(p.x, p.y) - 0.03, p.y)))
	_mm(root, _mesh("res://props/hometown/da_bo_a.glb"), _mat("stone"), stones)
	var weed := []
	for i in rng.randi_range(6, 10):
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * r * sqrt(rng.randf()) * 1.15
		var sc := rng.randf_range(1.0, 1.7)
		weed.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(1.0, 1.6), sc)),
			Vector3(p.x, bed_at.call(p.x, p.y) - 0.02, p.y)))
	_mm(root, _mesh("res://props/hometown/cay/co_bui.glb"), HomeKit._plant_material("cay/la_bui"), weed)
	var a0 := rng.randf() * TAU
	var lc := c + Vector2(cos(a0), sin(a0)) * r * 0.7
	var leaves := []
	var flowers := []
	var stems := []
	for i in (rng.randi_range(3, 5) if s.river else rng.randi_range(6, 9)):
		var a := rng.randf() * TAU
		var p := lc + Vector2(cos(a), sin(a)) * 1.6 * sqrt(rng.randf())
		var b: float = bed_at.call(p.x, p.y)
		if wy - b < 0.3:
			continue
		var fl := i < 2
		var sc := rng.randf_range(0.85, 1.15)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(p.x, wy - 0.03, p.y))
		(flowers if fl else leaves).append(t)
		var h := wy - b
		var lean := Vector3(rng.randf_range(-0.15, 0.15), 1.0, rng.randf_range(-0.15, 0.15)).normalized()
		var basis := Basis(Vector3.UP.cross(lean).normalized(), Vector3.UP.angle_to(lean)) if lean != Vector3.UP else Basis()
		stems.append(Transform3D(basis.scaled(Vector3(1.0, h, 1.0)), Vector3(p.x, b + h * 0.5, p.y)))
	_mm(root, _mesh("res://props/farm/sen_0.glb"), _mat("plant"), leaves)
	_mm(root, _mesh("res://props/farm/sen_3.glb"), _mat("plant"), flowers)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.009
	cyl.bottom_radius = 0.013
	cyl.height = 1.0
	cyl.radial_segments = 5
	cyl.rings = 1
	_mm(root, cyl, _mat("stem"), stems)

static func _mm(root: Node3D, mesh: Mesh, mat: Material, xf: Array) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 45.0
	root.add_child(mi)

func _find(c: Vector2i) -> Array:
	var out: Array = []
	var x0 := c.x * CELL
	var z0 := c.y * CELL
	var x := x0 + STEP * 0.5
	while x < x0 + CELL:
		var z := z0 + STEP * 0.5
		while z < z0 + CELL:
			var w := Water.at(x, z)
			if w.y >= MIN_DEPTH and _far_enough(out, Vector2(x, z)):
				var r := _fit(x, z)
				if r > 0.0:
					var wet := 0
					for k in 16:
						var a := k * TAU / 16.0
						if Water.at(x + cos(a) * 12.0, z + sin(a) * 12.0).y > 0.3:
							wet += 1
					out.append({"c": Vector2(x, z), "r": Vector2(r, r), "river": wet < 9,
						"seed": hash(Vector2i(roundi(x), roundi(z)))})
			z += STEP
		x += STEP
	return out

func _far_enough(out: Array, p: Vector2) -> bool:
	for s in out:
		if (s.c as Vector2).distance_to(p) < APART:
			return false
	for c in _cells.values():
		for s in c:
			if (s.c as Vector2).distance_to(p) < APART:
				return false
	return true

func _fit(x: float, z: float) -> float:
	for r in [R, R * 0.6, 2.5]:
		var ok := true
		for k in 8:
			var a := k * TAU / 8.0
			if Water.at(x + cos(a) * r, z + sin(a) * r).y < 0.35:
				ok = false
				break
		if ok:
			return r
	return 0.0
