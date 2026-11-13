class_name FarmLand
extends Node3D

const CELL := 0.4
const TOP := 0.12
const WEED_NIGHTS := 3

var beds := []
var soil := {}
var crops := {}
var fallow := {}
var _mesh: MeshInstance3D
var _sparks: MultiMeshInstance3D
var _rings: MultiMeshInstance3D
var core = null

func _init() -> void:
	if ClassDB.class_exists(&"FarmSoil") and OS.get_environment("MC_FARM_GD") == "":
		core = ClassDB.instantiate(&"FarmSoil")
		core.set_crop_table(Crops.table())

func _sync() -> void:
	soil = core.soil_dict()
	crops = core.crops_dict()
	fallow = core.fallow_dict()

func setup(defs: Array, state := "co") -> void:
	beds.clear()
	soil.clear()
	crops.clear()
	for d in defs:
		beds.append({"i": d[0], "j0": d[1], "n": d[2]})
	if core:
		core.setup(defs, state)
		_sync()
		redraw()
		return
	for b in beds.size():
		for k in beds[b].n:
			soil[Vector2i(b, k)] = state
	redraw()

func cell_at(p: Vector3) -> Vector2i:
	var q := to_local(p)
	return Vector2i(roundi(q.x / CELL), roundi(q.z / CELL))

func cell_pos(c: Vector2i, y := 0.0) -> Vector3:
	return to_global(Vector3(c.x * CELL, y, c.y * CELL))

func owner(c: Vector2i) -> Vector2i:
	return core.resolve(c) if core else c

func piece_of(c: Vector2i) -> Vector2i:
	if core:
		return core.piece_of(c)
	for b in beds.size():
		var d: Dictionary = beds[b]
		if (c.x == d.i or c.x == d.i + 1) and c.y >= d.j0 and c.y < d.j0 + d.n:
			return Vector2i(b, c.y - d.j0)
	return Vector2i(-1, -1)

func state_at(c: Vector2i) -> String:
	if core:
		return core.state_at(c)
	var pc := piece_of(c)
	return soil.get(pc, "")

func ripe(c: Vector2i) -> bool:
	if core:
		return core.ripe(c)
	if not crops.has(c):
		return false
	var cr: Dictionary = crops[c]
	return cr.stage >= (Crops.table()[cr.crop]["models"] as Array).size() - 1

func hoe(c: Vector2i, draw := true) -> bool:
	if core:
		return _did(core.hoe(c), draw)
	var pc := piece_of(c)
	if pc.x < 0 or crops.has(c) or crops.has(_twin(c)):
		return false
	soil[pc] = "xoi"
	if draw:
		redraw()
	return true

func dig(c: Vector2i) -> String:
	if core:
		var id: String = core.dig(c)
		_did(id != "", true)
		return id
	var cc := c if crops.has(c) else _twin(c)
	if not crops.has(cc):
		return ""
	var id: String = crops[cc].crop
	crops.erase(cc)
	soil[piece_of(cc)] = "xoi"
	fallow.erase(piece_of(cc))
	redraw()
	return id

func sow(c: Vector2i, crop: String) -> bool:
	if core:
		return _did(core.sow(c, crop), true)
	var st := state_at(c)
	if st == "" or st == "co" or crops.has(c):
		return false
	crops[c] = {"crop": crop, "stage": 0, "grown": 0}
	redraw()
	return true

func water(c: Vector2i, draw := true) -> bool:
	if core:
		return _did(core.water(c), draw)
	var pc := piece_of(c)
	if pc.x < 0 or soil[pc] == "co" or soil[pc] == "uot":
		return false
	soil[pc] = "uot"
	if draw:
		redraw()
	return true

func row_of(c: Vector2i, n: int, dir: int) -> Array:
	if core:
		return core.row_of(c, n, dir)
	var pc := piece_of(c)
	if pc.x < 0:
		return [c]
	var b: Dictionary = beds[pc.x]
	var out := []
	for m in n:
		var k: int = pc.y + m * dir
		if k >= 0 and k < b.n:
			out.append(Vector2i(b.i, b.j0 + k))
	var m2 := 1
	while out.size() < mini(n, b.n):
		var k: int = pc.y - m2 * dir
		m2 += 1
		if k >= 0 and k < b.n:
			out.append(Vector2i(b.i, b.j0 + k))
		elif k < -n or k > b.n + n:
			break
	return out

func harvest(c: Vector2i) -> Dictionary:
	if core:
		var got: Dictionary = core.harvest(c)
		_did(not got.is_empty(), true)
		return got
	if not ripe(c):
		return {}
	var cr: Dictionary = crops[c]
	var row: Dictionary = Crops.table()[cr.crop]
	var h: Array = row["harvest"]
	var got := {"crop": cr.crop, "n": randi_range(int(h[0]), int(h[1]))}
	if row["regrow_to"] != null:
		cr.stage = int(row["regrow_to"])
		cr.grown = 0
	else:
		crops.erase(c)
	redraw()
	return got

func rain() -> void:
	if core:
		core.rain()
		_did(true, true)
		return
	for pc in soil:
		if soil[pc] != "co":
			soil[pc] = "uot"
	redraw()

func next_day() -> void:
	if core:
		core.next_day()
		_did(true, true)
		return
	for c in crops:
		var cr: Dictionary = crops[c]
		if soil.get(piece_of(c), "") != "uot":
			continue
		var days: Array = Crops.table()[cr.crop]["days"]
		if cr.stage >= days.size():
			continue
		cr.grown += 1
		if cr.grown >= int(days[cr.stage]):
			cr.stage += 1
			cr.grown = 0
	for pc in soil:
		if soil[pc] == "co":
			fallow.erase(pc)
			continue
		var b: Dictionary = beds[pc.x]
		var row: int = b.j0 + pc.y
		var empty := not crops.has(Vector2i(b.i, row)) and not crops.has(Vector2i(b.i + 1, row))
		if not empty or soil[pc] == "xoi":
			fallow.erase(pc)
			continue
		fallow[pc] = int(fallow.get(pc, 0)) + 1
		if fallow[pc] >= WEED_NIGHTS:
			soil[pc] = "co"
			fallow.erase(pc)
	for pc in soil:
		if soil[pc] == "uot" or soil[pc] == "xoi":
			soil[pc] = "kho"
	redraw()

func plant(c: Vector2i, crop: String, stage: int) -> void:
	if core:
		core.plant(c, crop, stage)
		_did(true, true)
		return
	crops[c] = {"crop": crop, "stage": stage, "grown": 0}
	redraw()

func _did(changed: bool, draw: bool) -> bool:
	if changed:
		_sync()
		if draw:
			redraw()
	return changed

func _twin(c: Vector2i) -> Vector2i:
	"""The other cell of the same bed piece."""
	if core:
		return core.twin(c)
	var pc := piece_of(c)
	if pc.x < 0:
		return c
	var i: int = beds[pc.x].i
	return Vector2i(i + 1 if c.x == i else i, c.y)

func redraw() -> void:
	var items := []
	var covered := {}
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for b in beds.size():
		var d: Dictionary = beds[b]
		for k in d.n:
			var part := "dau" if k == 0 else ("cuoi" if k == d.n - 1 else "giua")
			var st: String = soil[Vector2i(b, k)]
			if st == "co" and part == "giua" and k % 2 == 1:
				st = "co2"
			items.append({"model": "luong2_%s_%s" % [part, st], "pos": Vector3((d.i + 0.5) * CELL, 0, (d.j0 + k) * CELL)})
			for ci in [d.i, d.i + 1]:
				covered[Vector2i(ci, d.j0 + k)] = true
		lo = Vector2i(mini(lo.x, d.i - 1), mini(lo.y, d.j0 - 1))
		hi = Vector2i(maxi(hi.x, d.i + 2), maxi(hi.y, d.j0 + d.n))

	for i in range(lo.x, hi.x + 1):
		for j in range(lo.y, hi.y + 1):
			var c := Vector2i(i, j)
			if covered.has(c):
				continue
			var ex := 1 if i == hi.x else (-1 if i == lo.x else 0)
			var ez := 1 if j == hi.y else (-1 if j == lo.y else 0)
			var model := "ranh"
			var yaw := 0.0
			if ex != 0 and ez != 0:
				model = "ranh_goc"
				yaw = {Vector2i(1, 1): 0.0, Vector2i(-1, 1): -PI / 2, Vector2i(-1, -1): PI, Vector2i(1, -1): PI / 2}[Vector2i(ex, ez)]
			elif ex != 0 or ez != 0:
				model = "ranh_bien"
				yaw = 0.0 if ex == 1 else (PI if ex == -1 else (-PI / 2 if ez == 1 else PI / 2))
			items.append({"model": model, "pos": Vector3(i * CELL, 0, j * CELL), "yaw": yaw})
	for c in crops:
		var cr: Dictionary = crops[c]
		var h := absi(c.x * 73856093 ^ c.y * 19349663)
		var fp: Array = Crops.table()[cr.crop].get("footprint", [1, 1])
		var mid := Vector3(CELL * 0.5, 0, CELL * 0.5) if core and (int(fp[0]) >= 2 or int(fp[1]) >= 2) else Vector3.ZERO
		items.append({"model": Crops.model(cr.crop, cr.stage), "pos": Vector3(c.x * CELL, TOP, c.y * CELL) + mid,
			"yaw": float(h % 628) / 100.0})
	if _mesh:
		_mesh.queue_free()
	_mesh = Crops.draw(self, items, true, true)[0]
	_draw_sparks()

func _draw_sparks() -> void:
	if _sparks == null:
		_sparks = _spark_layer("res://shaders/ripe_sparkle.gdshader", Vector2(0.46, 0.46), false)
		_rings = _spark_layer("res://shaders/ripe_ring.gdshader", Vector2(0.44, 0.44), true)
	var at := []
	for c in crops:
		if not ripe(c):
			continue
		var cr: Dictionary = crops[c]
		var fp: Array = Crops.table()[cr.crop].get("footprint", [1, 1])
		var big := core != null and (int(fp[0]) >= 2 or int(fp[1]) >= 2)
		var mid := Vector3(CELL * 0.5, 0, CELL * 0.5) if big else Vector3.ZERO
		var top := Crops.mesh(Crops.model(cr.crop, cr.stage)).get_aabb().end.y
		var pos := Vector3(c.x * CELL, TOP, c.y * CELL) + mid
		at.append([pos, top, 2.0 if big else 1.0, float(absi(c.x * 7919 + c.y * 104729) % 97) / 97.0])
	for layer in [_sparks, _rings]:
		var mm: MultiMesh = layer.multimesh
		mm.instance_count = at.size()
		for k in at.size():
			var e: Array = at[k]
			var xf := Transform3D(Basis.from_scale(Vector3.ONE * float(e[2])), e[0] + Vector3(0, 0.015, 0)) if layer == _rings 				else Transform3D(Basis(), e[0] + Vector3(0, float(e[1]) + 0.18, 0))
			mm.set_instance_transform(k, xf)
			mm.set_instance_custom_data(k, Color(float(e[3]), 0, 0, 0))
		layer.visible = at.size() > 0

func _spark_layer(shader: String, size: Vector2, flat: bool) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q: PrimitiveMesh
	if flat:
		q = PlaneMesh.new()
		(q as PlaneMesh).size = size
	else:
		q = QuadMesh.new()
		(q as QuadMesh).size = size
	var m := ShaderMaterial.new()
	m.shader = load(shader)
	q.material = m
	mm.mesh = q
	mi.multimesh = mm
	mi.custom_aabb = AABB(Vector3(-50, -5, -50), Vector3(100, 20, 100))
	add_child(mi)
	return mi

func to_dict() -> Dictionary:
	if core:
		return core.to_dict()
	var s := {}
	for pc in soil:
		s["%d,%d" % [pc.x, pc.y]] = soil[pc]
	var c := {}
	for cell in crops:
		c["%d,%d" % [cell.x, cell.y]] = crops[cell]
	var f := {}
	for pc in fallow:
		f["%d,%d" % [pc.x, pc.y]] = fallow[pc]
	return {"soil": s, "crops": c, "fallow": f}

func from_dict(d: Dictionary) -> void:
	if core:
		core.from_dict(d)
		_sync()
		redraw()
		return
	for key in d.get("soil", {}):
		var v: PackedStringArray = key.split(",")
		soil[Vector2i(int(v[0]), int(v[1]))] = d.soil[key]
	fallow.clear()
	for key in d.get("fallow", {}):
		var v: PackedStringArray = key.split(",")
		fallow[Vector2i(int(v[0]), int(v[1]))] = int(d.fallow[key])
	crops.clear()
	for key in d.get("crops", {}):
		var v: PackedStringArray = key.split(",")
		var cr: Dictionary = d.crops[key]
		crops[Vector2i(int(v[0]), int(v[1]))] = {"crop": cr.crop, "stage": int(cr.stage), "grown": int(cr.grown)}
	redraw()
