class_name DecorRoom
extends Node3D

class Entry:
	extends RefCounted
	var id := ""
	var layer := ""
	var rect := Rect2i()
	var rot := 0
	var wall := ""
	var host: Entry = null
	var kids: Array = []
	var node: Node3D
	var held := false

const CELL := 0.5
const WALL_CELL := 0.25
const WALL_K := 2
const ART := "res://props/furniture/art/"
const KHUNG := "res://props/furniture/khung/"
const CATALOG := "res://data/home/decor.json"
const ART_DATA := "res://data/home/art.json"
const FINISH := "res://data/home/finish.json"
const RUG_H := 0.016
const SLACK := 0.25
const WALLS := ["back", "left", "right"]
const WALL_YAW := {"back": 0.0, "left": PI / 2, "right": -PI / 2}
const HERO_R := 0.22
const KHO_BASE := 40
const UPGRADES := "res://data/home/upgrades.json"
const VERSION := 3
const KHO_ROOM := "nha_cu"

signal received(id: String)
signal surfaces_changed
signal face_glow(face: int)

static var _cat := {}
static var _data := {}
static var _art := {}
static var _rooms := {}
static var _boxes := {}
static var _live := {}
static var _upg := {}
static var _pics := {}
static var _frame_mats := {}
static var _shot_tall := {}
static var _looks := {}
static var _mains := {}
static var _finish := {}
static var _rug_meshes := {}
static var try_all := false
static var render_story := true

var room := ""
var origin := Vector2.ZERO
var size := Vector2i(14, 10)
var wall_h := 2.7
var door := Rect2i()
var keep_clear: Array = []
var wall_fixed := {}
var entries: Array = []
var kho := {}
var got: Array = []
var san := {}
var basket := {}
var news: Array = []
var hero: Node3D
var grid := DecorGrid.new()
var loose := false
var _load_ver := VERSION
var surfaces := {}
var rs: Object = null

static var _be := {}

static func catalog() -> Dictionary:
	if _cat.is_empty():
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
		_data = d
		for row in d["items"]:
			_cat[row["id"]] = row

		_art = JSON.parse_string(FileAccess.get_file_as_string(ART_DATA)) if FileAccess.file_exists(ART_DATA) else {}
		var by_group: Dictionary = d.get("frame_by_group", {})
		for a in _art.get("paintings", []) + _art.get("story_photos", []):
			var cells_: Array = a.get("cells", [])
			if cells_.is_empty():
				cells_ = _art["photo"]["sizes"][a.get("size", "vua")]["cells"]
			var row := {"id": a["id"], "kind": "wall", "art": a["id"], "cells": cells_,
				"name": "DECOR_" + String(a["id"]).to_upper(),
				"frame": a.get("frame", by_group.get(a.get("group", "photo"), "khung_go_moc"))}
			if a.get("keep", false):
				row["keep"] = "ong_ba" if a["id"] in ["anh_ca_nha"] else "qua"
			if a.get("group", "") == "lich":
				row["calendar"] = true
			_cat[a["id"]] = row

		var models: Dictionary = d.get("heirloom_models", {})
		for h in finish().get("repair", {}).get("items", []):
			var hr := {"id": h["id"], "kind": h["kind"], "model": models.get(h["id"], h["id"]),
				"name": "DECOR_" + String(h["id"]).to_upper(), "keep": "ong_ba", "repair": h}
			if h.get("fixed", {}).get("top", false):
				hr["top"] = true
			_cat[h["id"]] = hr

		for o in finish().get("outdoor", {}).get("items", []):
			if ResourceLoader.exists(Furniture.DIR + String(o["id"]) + ".glb"):
				_cat[o["id"]] = {"id": o["id"], "kind": "outdoor", "model": o["id"], "name": "DECOR_" + String(o["id"]).to_upper()}

		for g in finish().get("rugs", {}).get("items", []):
			var rr := {"id": g["id"], "kind": "rug", "model": "rugs/" + String(g["id"]), "cells": g["cells"],
				"name": "DECOR_" + String(g["id"]).to_upper(), "round": String(g["id"]).ends_with("_tron")}
			if g.has("variants"):
				rr["skins"] = g["variants"]
				rr["skin"] = "rugs/%s_%s" % [g["id"], g["variants"][0]]
			_cat[g["id"]] = rr
		_rooms = d["rooms"]
	return _cat

static func item(id: String) -> Dictionary:
	if id.begins_with("anh:"):
		return _photo_row(id)
	if "@" in id:
		var row: Dictionary = catalog()[id.get_slice("@", 0)].duplicate()
		row["base"] = row["id"]
		row["id"] = id
		var v := id.get_slice("@", 1)
		if v in row.get("skins", []):
			row["skin"] = "rugs/%s_%s" % [row["base"], v]
		else:
			row["variant"] = v
		return row
	return catalog()[id]

static func base_id(id: String) -> String:
	return id.get_slice("@", 0)

static func known(id: String) -> bool:
	if id.begins_with("anh:"):
		var p := id.split(":")
		return p.size() == 5 and FileAccess.file_exists(PhotoPrint.shot_path(p[1])) 			and art()["photo"]["sizes"].has(p[2])
	if "@" in id:
		var b := base_id(id)
		return catalog().has(b) and (id.get_slice("@", 1) in catalog()[b].get("skins", []) 				or not variant_row(b, id.get_slice("@", 1)).is_empty())
	return catalog().has(id)

static func forget() -> void:
	_pics.clear()
	_shot_tall.clear()
	_boxes.clear()

static func catalog_data() -> Dictionary:
	catalog()
	return _data

static func art() -> Dictionary:
	catalog()
	return _art

static func _photo_row(id: String) -> Dictionary:
	var p := id.split(":")
	var sz: Dictionary = art()["photo"]["sizes"].get(p[2], art()["photo"]["sizes"]["vua"])
	if not _shot_tall.has(p[1]):
		var img := Image.load_from_file(PhotoPrint.shot_path(p[1]))
		_shot_tall[p[1]] = img != null and img.get_height() > img.get_width()
	var c: Array = sz["cells"]
	var cells_ := [c[1], c[0]] if _shot_tall[p[1]] else [c[0], c[1]]
	return {"id": id, "kind": "small" if p[4] == "ban" else "wall", "frame": p[3], "cells": cells_,
		"photo": p[1], "px": int(sz["tex"]), "size": p[2], "stand": p[4] == "ban", "name": "DECOR_ANH_" + p[2].to_upper()}

static func pic_size(row: Dictionary) -> Vector2:
	var look := frame_look(row["frame"])
	if row.has("photo"):
		var long_m := float(catalog_data().get("photo_long", {}).get(row.get("size", "vua"), 0.32))
		var tall: bool = row["cells"][1] > row["cells"][0]
		var p := Vector2(long_m * 2.0 / 3.0, long_m) if tall else Vector2(long_m, long_m * 2.0 / 3.0)
		return p * (0.8 if row.get("stand", false) else 1.0)
	var g := float(art().get("wall_grid", WALL_CELL))
	var outer := Vector2(float(row["cells"][0]), float(row["cells"][1])) * g - Vector2(0.03, 0.03)
	if row.get("stand", false):
		outer *= 0.8
	return (outer - Vector2.ONE * 2.0 * float(look["border"])).max(Vector2(0.05, 0.05))

static func frame_look(frame: String) -> Dictionary:
	var looks: Dictionary = catalog_data()["frame_looks"]
	if looks.has(frame):
		return looks[frame]
	var base := frame.rsplit("_", true, 1)
	if base.size() == 2 and looks.has(base[0]):
		var l: Dictionary = looks[base[0]].duplicate()
		l["tint"] = l.get("variants", {}).get(base[1], l.get("tint", "ffffff"))
		return l
	return looks["khung_go_moc"]

static func box(id: String) -> AABB:
	var row := item(id)
	if row.get("kind", "") == "rug":
		var c: Array = row["cells"]
		var sz := Vector3(c[0] * CELL - 0.04, RUG_H, c[1] * CELL - 0.04)
		return AABB(Vector3(-sz.x / 2.0, 0.0, -sz.z / 2.0), sz)
	if row.has("frame"):
		var key := "%s|%s|%s" % [row["frame"], row["cells"], row.get("stand", false)]
		if not _boxes.has(key):
			_boxes[key] = _frame_mesh(row).get_aabb()
		return _boxes[key]
	var model: String = row["model"]
	if not _boxes.has(model):
		var n: Node3D = load(Furniture.DIR + model + ".glb").instantiate()
		var b := AABB()
		var first := true
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			var one := mi.transform * mi.get_aabb()
			b = one if first else b.merge(one)
			first = false
		n.free()
		_boxes[model] = b
	return _boxes[model]

static func cells(metres: float) -> int:
	return maxi(1, ceili(metres / CELL - SLACK))

static func wall_cells(metres: float) -> int:
	return maxi(1, ceili(metres / WALL_CELL - SLACK))

static func size_of(id: String, rot := 0) -> Vector2i:
	var b := box(id)
	if item(id)["kind"] == "wall":
		return Vector2i(wall_cells(b.size.x), wall_cells(b.size.y))
	var s := Vector2i(cells(b.size.x), cells(b.size.z))
	return Vector2i(s.y, s.x) if rot % 2 == 1 else s

static func is_top(e: Entry) -> bool:
	return e.layer == "floor" and item(e.id).get("top", false)

static func top_height(e: Entry) -> float:
	return float(item(e.id).get("top_h", box(e.id).size.y))

func setup(room_id: String, corner: Vector2) -> void:
	catalog()
	room = room_id
	origin = corner
	var r: Dictionary = _rooms[room]
	size = Vector2i(r["size"][0], r["size"][1])
	wall_h = float(r["wall_h"])
	door = _rect(r["door"])
	keep_clear = r.get("keep_clear", []).map(_rect)
	for wall in r.get("wall_fixed", {}):
		wall_fixed[wall] = r["wall_fixed"][wall].map(func(a: Array) -> Rect2i:
			return Rect2i(a[0] * WALL_K, a[1] * WALL_K, a[2] * WALL_K, a[3] * WALL_K))
	var fixed := []
	for wall in WALLS:
		fixed.append(wall_fixed.get(wall, []))
	grid.setup(size, PackedInt32Array([wall_len("back"), wall_len("left"), wall_len("right")]), wall_rows(), CELL, door,
		keep_clear, fixed)
	grid.set_wall_cell(WALL_CELL)
	if not is_instance_valid(_live.get(room)):
		_live[room] = self

func _exit_tree() -> void:
	if _live.get(room) == self:
		_live.erase(room)

static func _rect(a: Array) -> Rect2i:
	return Rect2i(a[0], a[1], a[2], a[3])

func save_path() -> String:
	return "user://save/decor_%s.json" % room

func wall_len(wall: String) -> int:
	return (size.x if wall == "back" else size.y) * WALL_K

func wall_rows() -> int:
	return int(wall_h / WALL_CELL)

func floor_point(cell: Vector2) -> Vector3:
	return Vector3(origin.x + cell.x * CELL, 0, origin.y + cell.y * CELL)

func wall_point(wall: String, along: float, up: float) -> Vector3:
	match wall:
		"back":
			return Vector3(origin.x + along, up, origin.y)
		"left":
			return Vector3(origin.x, up, origin.y + along)
		_:
			return Vector3(origin.x + size.x * CELL, up, origin.y + along)

func wall_plane(wall: String) -> Plane:
	match wall:
		"back":
			return Plane(Vector3.BACK, origin.y)
		"left":
			return Plane(Vector3.RIGHT, origin.x)
		_:
			return Plane(Vector3.LEFT, -(origin.x + size.x * CELL))

func pose(e: Entry, lift := 0.0) -> void:
	var n: Node3D = e.node
	var b := box(e.id)
	var r: Rect2i = e.rect
	var mid := Vector2(r.position) + Vector2(r.size) / 2.0
	if e.layer == "wall":
		var yaw: float = WALL_YAW[e.wall]
		n.rotation = Vector3(0, yaw, 0)
		var spot := wall_point(e.wall, mid.x * WALL_CELL, mid.y * WALL_CELL) + Basis(Vector3.UP, yaw) * Vector3(0, 0, lift)
		n.position = spot - Basis(Vector3.UP, yaw) * Vector3(b.get_center().x, b.get_center().y, b.position.z - 0.005)
	else:
		var yaw: float = e.rot * PI / 2
		n.rotation = Vector3(0, yaw, 0)
		var y := (top_height(e.host) if e.layer == "top" else 0.0) + lift
		var spot := floor_point(mid) + Vector3(0, y, 0)
		n.position = spot - Basis(Vector3.UP, yaw) * Vector3(b.get_center().x, b.position.y, b.get_center().z)
	for k in e.kids:
		pose(k, lift)

func candidate(e: Entry, from: Vector3, dir: Vector3) -> Dictionary:
	var kind: String = item(e.id)["kind"]
	if kind == "wall":
		return _wall_candidate(e, from, dir)
	var sz := size_of(e.id, e.rot)
	if kind == "small":
		var best := {}
		var best_t := INF
		for h in entries:
			if h == e or not is_top(h) or h.held:
				continue
			var p = Plane(Vector3.UP, top_height(h)).intersects_ray(from, dir)
			if p == null:
				continue
			var hr: Rect2i = h.rect
			if not hr.has_point(_cell_of(p)) or sz.x > hr.size.x or sz.y > hr.size.y:
				continue
			var t := from.distance_to(p)
			if t < best_t:
				best_t = t
				best = {"layer": "top", "rect": _clamp(Rect2i(_origin_cell(p, sz), sz), hr), "host": h}
		if not best.is_empty():
			return best
	var p = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	if p == null:
		return {}
	return {"layer": "rug" if kind == "rug" else "floor", "rect": _clamp(Rect2i(_origin_cell(p, sz), sz), Rect2i(Vector2i.ZERO, size))}

func _wall_candidate(e: Entry, from: Vector3, dir: Vector3) -> Dictionary:
	var sz := size_of(e.id)
	var best := {}
	var best_t := INF
	for wall in WALLS:
		var p = wall_plane(wall).intersects_ray(from, dir)
		if p == null or p.y < 0.0 or p.y > wall_h:
			continue
		var along: float = (p.x - origin.x) if wall == "back" else (p.z - origin.y)
		if along < 0.0 or along > wall_len(wall) * WALL_CELL:
			continue
		var t := from.distance_to(p)
		if t < best_t:
			best_t = t
			var at := Vector2i(roundi(along / WALL_CELL - sz.x / 2.0), roundi(p.y / WALL_CELL - sz.y / 2.0))
			best = {"layer": "wall", "wall": wall,
				"rect": _clamp(Rect2i(at, sz), Rect2i(0, WALL_K, wall_len(wall), wall_rows() - WALL_K))}
	return best

func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / CELL), floori((p.z - origin.y) / CELL))

func _origin_cell(p: Vector3, sz: Vector2i) -> Vector2i:
	return Vector2i(roundi((p.x - origin.x) / CELL - sz.x / 2.0), roundi((p.z - origin.y) / CELL - sz.y / 2.0))

static func _clamp(r: Rect2i, inside: Rect2i) -> Rect2i:
	r.position.x = clampi(r.position.x, inside.position.x, maxi(inside.position.x, inside.end.x - r.size.x))
	r.position.y = clampi(r.position.y, inside.position.y, maxi(inside.position.y, inside.end.y - r.size.y))
	return r

func is_yard() -> bool:
	return bool(_rooms[room].get("yard", false))

func allowed_here(id: String) -> bool:
	var row := item(id)
	if row["kind"] in ["wall", "small"]:
		return true
	if is_yard():
		return row["kind"] == "outdoor" or base_id(id) in finish().get("outdoor", {}).get("also", [])
	return row["kind"] != "outdoor"

func can_place(e: Entry, spot: Dictionary) -> bool:
	if spot.is_empty() or not allowed_here(e.id):
		return false
	var r: Rect2i = spot["rect"]
	match spot["layer"]:
		"floor":
			return grid.fits_floor(r, box(e.id).size.y, hero_cells(), _floors(e), _walls(e))
		"top":
			var host: Entry = spot["host"]
			var sib := PackedInt32Array()
			for k in host.kids:
				if k != e:
					sib.append_array([k.rect.position.x, k.rect.position.y, k.rect.size.x, k.rect.size.y])
			return grid.fits_top(host.rect, r, sib)
		"wall":
			return grid.fits_wall(WALLS.find(spot["wall"]), r, _floors(e), _walls(e), loose)
		"rug":
			if not Rect2i(Vector2i.ZERO, size).encloses(r):
				return false
			for o in entries:
				if o != e and not o.held and o.layer == "rug" and o.rect.intersects(r):
					return false
			return true
	return false

func _floors(e: Entry) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for o in entries:
		if o != e and not o.held and o.layer == "floor":
			a.append_array([o.rect.position.x, o.rect.position.y, o.rect.size.x, o.rect.size.y, box(o.id).size.y])
	return a

func _walls(e: Entry) -> PackedInt32Array:
	var a := PackedInt32Array()
	for o in entries:
		if o != e and not o.held and o.layer == "wall":
			a.append_array([WALLS.find(o.wall), o.rect.position.x, o.rect.position.y, o.rect.size.x, o.rect.size.y])
	return a

func hero_cells() -> Rect2i:
	if hero == null:
		return Rect2i()
	var p := hero.global_position
	var a := _cell_of(p - Vector3(HERO_R, 0, HERO_R))
	var b := _cell_of(p + Vector3(HERO_R, 0, HERO_R))
	return Rect2i(a, b - a + Vector2i.ONE)

func make(id: String, rot := 0) -> Entry:
	var row := item(id)
	var e := Entry.new()
	e.id = id
	e.rot = rot
	e.rect = Rect2i(Vector2i.ZERO, size_of(id, rot))
	if row.has("frame"):
		e.node = framed(self, row)
	elif row["kind"] == "rug":
		e.node = rug(self, row)
	elif row.has("repair") and not mended(id):
		e.node = Furniture.place(self, String(row["model"]) + "_hong", Vector3.ZERO, 0.0, row["kind"] in ["floor", "outdoor"])
	else:
		e.node = Furniture.place(self, row["model"], Vector3.ZERO, 0.0, row["kind"] in ["floor", "outdoor"], row.get("skin", ""))
		if row.has("variant"):
			_coat(e.node, row)
	return e

static func mended(id: String) -> bool:
	var row := item(id)
	return not row.has("repair") or String(row["repair"]["fix"]) in Story.flag("home_fixes_done", [])

static func broken(id: String) -> bool:
	return item(id).has("repair") and not mended(id)

static func repair_state(id: String) -> Dictionary:
	var r: Dictionary = item(id)["repair"]
	var have := {}
	for m in r["needs"]:
		have[m] = Stock.count(m)
	var level_ok := try_all or Progress.is_open(String(r["fix"]))
	var level := 0
	for u in Progress.unlocks().get("items", []):
		if u["id"] == r["fix"]:
			level = int(u.get("unlock", {}).get("level", 0))
	return {"needs": r["needs"], "have": have, "level_ok": level_ok, "level": level,
		"ok": level_ok and (try_all or Stock.has(r["needs"]))}

func repair(e: Entry) -> String:
	if not broken(e.id):
		return "done"
	var st := repair_state(e.id)
	if not st["level_ok"]:
		return "level"
	if not try_all and not Stock.take(st["needs"]):
		return "need"
	var row := item(e.id)
	var done: Array = Story.flag("home_fixes_done", [])
	done.append(String(row["repair"]["fix"]))
	Story.set_flag("home_fixes_done", done)
	var pages: Array = Story.flag("so_tay_pages", [])
	if row["repair"].has("page") and row["repair"]["page"] not in pages:
		pages.append(row["repair"]["page"])
		Story.set_flag("so_tay_pages", pages)
	if not try_all:
		Progress.story(finish()["repair"].get("xp", {}))
	var old := e.node
	e.node = Furniture.place(self, String(row["model"]), Vector3.ZERO, 0.0, row["kind"] in ["floor", "outdoor"])
	pose(e)
	old.queue_free()
	return "ok"

static func rug(parent: Node3D, row: Dictionary) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var c: Array = row["cells"]
	mi.mesh = rug_mesh(c[0] * CELL - 0.04, c[1] * CELL - 0.04, row.get("round", false))
	mi.material_override = Furniture.material(String(row.get("skin", row["model"])))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	parent.add_child(n)
	if row.has("variant"):
		_coat(n, row)
	return n

static func rug_mesh(w: float, d: float, round: bool) -> ArrayMesh:
	var key := "%s|%s|%s" % [w, d, round]
	if _rug_meshes.has(key):
		return _rug_meshes[key]
	var v := PackedVector3Array()
	var nm := PackedVector3Array()
	var uv := PackedVector2Array()
	var ix := PackedInt32Array()
	var ring: Array = []
	if round:
		for k in 48:
			var a := TAU * k / 48.0
			ring.append(Vector2(cos(a) * w / 2.0, sin(a) * d / 2.0))
	else:
		ring = [Vector2(-w / 2, -d / 2), Vector2(w / 2, -d / 2), Vector2(w / 2, d / 2), Vector2(-w / 2, d / 2)]

	v.append(Vector3(0, RUG_H, 0))
	nm.append(Vector3.UP)
	uv.append(Vector2(0.5, 0.5))
	for p: Vector2 in ring:
		v.append(Vector3(p.x, RUG_H, p.y))
		nm.append(Vector3.UP)
		uv.append(Vector2(p.x / w + 0.5, p.y / d + 0.5))
	for k in ring.size():
		ix.append_array([0, 1 + k, 1 + (k + 1) % ring.size()])

	for k in ring.size():
		var a: Vector2 = ring[k]
		var b: Vector2 = ring[(k + 1) % ring.size()]
		var out := Vector3(b.y - a.y, 0, a.x - b.x).normalized() * -1.0
		var s := v.size()
		var ua := Vector2(a.x / w + 0.5, a.y / d + 0.5)
		var ub := Vector2(b.x / w + 0.5, b.y / d + 0.5)
		for q in [[a, RUG_H, ua], [b, RUG_H, ub], [b, 0.0, ub], [a, 0.0, ua]]:
			v.append(Vector3(q[0].x, q[1], q[0].y))
			nm.append(out)
			uv.append(q[2])
		ix.append_array([s, s + 1, s + 2, s, s + 2, s + 3, s, s + 2, s + 1, s, s + 3, s + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = ix
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_rug_meshes[key] = m
	return m

static func finish() -> Dictionary:
	if _finish.is_empty() and FileAccess.file_exists(FINISH):
		_finish = JSON.parse_string(FileAccess.get_file_as_string(FINISH))
	return _finish

static func palette(id: String) -> String:
	var b := base_id(id)
	if b.begins_with("anh:") or not catalog().has(b) or catalog()[b].has("keep"):
		return ""
	return String(finish().get("paint", {}).get("items", {}).get(b, ""))

static func variants(id: String, all := false) -> Array:
	var pal := palette(id)
	if pal == "":
		return []
	var paint: Dictionary = finish()["paint"]
	var out := []
	for c in paint["palettes"][pal]["colors"]:
		var look := variant_row(id, c)
		if all or variant_open(look):
			out.append(look)
	return out

static func variant_open(v: Dictionary) -> bool:
	return v.has("unlock") and (try_all or Progress.is_open(String(v["unlock"])))

static func variant_row(id: String, v: String) -> Dictionary:
	var colors: Dictionary = finish().get("paint", {}).get("colors", {})
	if not colors.has(v) or not catalog().has(base_id(id)):
		return {}
	var row: Dictionary = catalog()[base_id(id)]
	var col := Color(String(colors[v]["hex"]))
	var look := {"id": v, "unlock": colors[v]["unlock"], "hex": colors[v]["hex"]}
	var m := _main_colour(String(row.get("skin", row.get("model", ""))))
	if float(m.get("colourful", 0.0)) > 0.3 and float(m.get("share", 0.0)) > 0.45:
		look.merge({"mode": "hue", "from": int(m["hue"]), "tol": 28, "to": roundi(col.h * 360.0),
			"sat": snappedf(clampf(col.s / maxf(float(m["sat"]), 0.05), 0.3, 1.6), 0.01),
			"val": snappedf(clampf(col.v / maxf(float(m["val"]), 0.05), 0.25, 1.4), 0.01)})
	else:
		look.merge({"mode": "paint", "color": colors[v]["hex"]})
	return look

static func _main_colour(atlas: String) -> Dictionary:
	if not _mains.has(atlas):
		var path := Furniture.DIR + atlas + "_alb.png"
		_mains[atlas] = Recolor.main_hue((load(path) as Texture2D).get_image()) if ResourceLoader.exists(path) else {}
	return _mains[atlas]

static func paint_cost(id: String) -> Dictionary:
	var pal := palette(id)
	if pal == "":
		return {}
	var what = finish()["paint"]["palettes"][pal].get("cost")
	return {} if what == null else {String(what): 1}

static func paint_pay(id: String) -> bool:
	var cost := paint_cost(id)
	if cost.is_empty() or try_all:
		return true
	if not Stock.use(String(cost.keys()[0])):
		return false
	Progress.story(finish()["paint"].get("xp", {}))
	return true

static func brush_open() -> bool:
	var tool := String(finish().get("paint", {}).get("tool", ""))
	return try_all or tool == "" or Progress.is_open(tool)

static func swatch(v: Dictionary) -> Color:
	return Color(String(v["hex"])) if v.has("hex") else Color.WHITE

static func _coat(node: Node3D, row: Dictionary) -> void:
	var look := variant_row(row["base"], row["variant"])
	var atlas := String(row.get("skin", row["model"]))
	var mat := look_material(atlas, look) if not look.is_empty() else Furniture.material(atlas)
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat

static func look_material(atlas: String, look: Dictionary) -> ShaderMaterial:
	var key := atlas + "|" + JSON.stringify(look)
	if _looks.has(key):
		return _looks[key]
	var base := Furniture.material(atlas)
	var m := base.duplicate() as ShaderMaterial
	var src: Texture2D = base.get_shader_parameter("albedo_tex")
	var params := look.duplicate()
	if params.get("color") is String:
		params["color"] = Color(params["color"])
	m.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(Recolor.apply(src.get_image(), params)))
	_looks[key] = m
	return m

func paint(e: Entry, v: String) -> void:
	var b := base_id(e.id)
	e.id = b + "@" + v if v != "" and not variant_row(b, v).is_empty() else b
	var row := item(e.id)
	if row.has("variant"):
		_coat(e.node, row)
	else:
		var atlas := String(row.get("skin", row["model"]))
		for mi: MeshInstance3D in e.node.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = Furniture.material(atlas)

static func variant_of(id: String) -> String:
	return id.get_slice("@", 1) if "@" in id else ""

static func choice_open(choice: String) -> bool:
	if try_all:
		return true
	if _upg.is_empty():
		_upg = JSON.parse_string(FileAccess.get_file_as_string(UPGRADES)) if FileAccess.file_exists(UPGRADES) else {}
	var done: Array = Story.flag("home_fixes_done", [])
	for row in _upg.get("levels", []) + _upg.get("fixes", []):
		if choice in row.get("gives", {}).get("choices", []) and row["id"] in done:
			return true
	return false

const SURFACE_CHOICE := {"wall": "mau_voi", "dado": "mau_voi", "floor": "gach_nen"}
const FACE := {"back": 0, "left": 1, "right": 2, "front": 3}

func surface_options(kind: String) -> Array:
	var out := []
	var priced: Dictionary = _surface_prices()
	for o in finish().get("surfaces", {}).get(kind, {}).get("options", []):
		var row: Dictionary = o.duplicate()
		row["open"] = try_all or Progress.is_open(String(o["unlock"]))
		if not try_all and priced.has(o["id"]) and ClassDB.class_exists("PatternShop") \
				and not ClassDB.class_call_static("PatternShop", "owned", String(o["id"])):
			row["open"] = false
			row["at_stall"] = true
		out.append(row)
	return out

static var _sprices := {}

static func _surface_prices() -> Dictionary:
	if _sprices.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/home/prices.json"))
		_sprices = d.get("surfaces", {}) if d is Dictionary else {}
		_sprices.erase("_doc")
		if _sprices.is_empty():
			_sprices = {"_none": 0}
	return _sprices

func surface(kind: String, face := -1) -> Dictionary:
	if rs != null:
		var id := String(rs.current(kind, face))
		for o in surface_options(kind):
			if o["id"] == id:
				return o
		return {}
	var want := String(surfaces.get(kind, ""))
	var def := String(finish().get("surfaces", {}).get(kind, {}).get("default", ""))
	for o in surface_options(kind):
		if o["id"] == (want if want != "" else def):
			return o
	return {}

func set_surface(kind: String, id: String, face := -1) -> String:
	if rs != null:
		if rs.is_previewing():
			rs.cancel()
		var why := _surface_check(kind, id, face)
		if why != "":
			return why
		rs.preview(kind, id, face)
		var c: Dictionary = rs.cost()
		if not try_all and not c.is_empty() and not Stock.take(c):
			rs.cancel()
			return "need"
		rs.commit()
		surfaces = rs.state()
		save()
		surfaces_changed.emit()
		return "ok"
	var row := {}
	for o in surface_options(kind):
		if o["id"] == id:
			row = o
	if row.is_empty() or not row["open"] or not choice_open(SURFACE_CHOICE[kind]):
		return "closed"
	if surface(kind).get("id", "") == id:
		return "same"
	var had: Array = surfaces.get(kind + "s_had", [])
	var cost: Dictionary = finish()["surfaces"][kind].get("cost", {})
	var def := String(finish()["surfaces"][kind].get("default", ""))
	if not try_all and not cost.is_empty() and id not in had and id != def:
		if not Stock.take(cost):
			return "need"
	if id not in had:
		had.append(id)
	surfaces[kind + "s_had"] = had
	surfaces[kind] = id
	save()
	surfaces_changed.emit()
	return "ok"

func _rs_load() -> void:
	if not ClassDB.class_exists("RoomSurfaces") or is_yard():
		return
	if rs == null:
		rs = ClassDB.instantiate("RoomSurfaces")
		rs.setup(finish().get("surfaces", {}), be_mat())
	rs.load(surfaces)

static func tile_path(tile: String) -> String:
	return "res://" + String(be_mat().get("paths", {}).get(tile, "props/hometown/tiles/%s_alb.png" % tile))

func themes() -> Array:
	var out := []
	for t in finish().get("surfaces", {}).get("themes", {}).get("list", []):
		var row: Dictionary = t.duplicate()
		row["open"] = _part_open("wall", t["wall"]) and (t["dado"] == "" or _part_open("dado", t["dado"])) \
			and _part_open("floor", t["floor"])
		out.append(row)
	return out

func _part_open(kind: String, id: String) -> bool:
	if not choice_open(SURFACE_CHOICE[kind]):
		return false
	for o in surface_options(kind):
		if o["id"] == id:
			return o["open"]
	return false

func preview_theme(id: String) -> String:
	if rs == null:
		return "closed"
	for t in themes():
		if t["id"] == id:
			if not t["open"]:
				return "closed"
			rs.preview("wall", t["wall"], -1)
			rs.preview("dado", t["dado"], -1)
			rs.preview("floor", t["floor"], -1)
			surfaces_changed.emit()
			return "ok"
	return "closed"

func theme_now() -> String:
	if rs == null or rs.has_faces("wall") or rs.has_faces("dado"):
		return ""
	for t in finish().get("surfaces", {}).get("themes", {}).get("list", []):
		if String(rs.current("wall", -1)) == t["wall"] and String(rs.current("dado", -1)) == t["dado"] \
				and String(rs.current("floor", -1)) == t["floor"]:
			return t["id"]
	return ""

static func be_mat() -> Dictionary:
	if _be.is_empty():
		_be = JSON.parse_string(FileAccess.get_file_as_string("res://data/home/be_mat.json"))
	return _be

func _surface_check(kind: String, id: String, face: int) -> String:
	if not choice_open(SURFACE_CHOICE.get(kind, "")):
		return "closed"
	if id != "":
		var row := {}
		for o in surface_options(kind):
			if o["id"] == id:
				row = o
		if row.is_empty() or not row["open"]:
			return "closed"
	if String(rs.current(kind, face)) == id and (face >= 0 or not rs.has_faces(kind)):
		return "same"
	return ""

func preview_surface(kind: String, id: String, face := -1) -> String:
	if rs == null:
		return set_surface(kind, id)
	var why := _surface_check(kind, id, face)
	if why != "":
		return why
	rs.preview(kind, id, face)
	surfaces_changed.emit()
	return "ok"

func surfaces_previewing() -> bool:
	return rs != null and rs.is_previewing()

func surface_cost() -> Dictionary:
	return rs.cost() if surfaces_previewing() else {}

func commit_surfaces(before := "") -> String:
	if not surfaces_previewing():
		return "ok"
	var c: Dictionary = rs.cost()
	if not try_all and not c.is_empty() and not Stock.take(c):
		return "need"
	remember(before)
	rs.commit()
	surfaces = rs.state()
	save()
	surfaces_changed.emit()
	return "ok"

func cancel_surfaces() -> void:
	if surfaces_previewing():
		rs.cancel()
		surfaces_changed.emit()

func face_at(from: Vector3, dir: Vector3) -> int:
	var best := -1
	var best_t := INF
	for wall in WALLS:
		var p = wall_plane(wall).intersects_ray(from, dir)
		if p == null or p.y < 0.0 or p.y > wall_h:
			continue
		var along: float = (p.x - origin.x) if wall == "back" else (p.z - origin.y)
		if along < 0.0 or along > wall_len(wall) * WALL_CELL:
			continue
		var t := from.distance_to(p)
		if t < best_t:
			best_t = t
			best = FACE[wall]
	return best

static func _frame_mesh(row: Dictionary) -> ArrayMesh:
	var look := frame_look(row["frame"])
	var pic := pic_size(row)
	return PhotoPrint.frame_mesh(pic.x, pic.y, float(look["border"]), float(look["depth"]), row.get("stand", false))

static func framed(parent: Node3D, row: Dictionary) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var mi := MeshInstance3D.new()
	mi.mesh = _frame_mesh(row)
	mi.set_surface_override_material(0, frame_material(row["frame"]))
	var pm := ShaderMaterial.new()
	pm.shader = Furniture.TOON
	pm.set_shader_parameter("base_color", Color.WHITE)
	pm.set_shader_parameter("has_albedo", true)
	pm.set_shader_parameter("albedo_tex", picture(row))
	pm.set_shader_parameter("shade_soft", 0.5)
	pm.set_shader_parameter("rim", 0.0)
	mi.set_surface_override_material(1, pm)
	if not row.get("stand", false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return n

static func frame_material(style: String) -> ShaderMaterial:
	if not _frame_mats.has(style):
		var st := frame_look(style)
		var m := ShaderMaterial.new()
		m.shader = Furniture.TOON
		m.set_shader_parameter("base_color", Color(st.get("tint", "ffffff")))
		var tex_path: String = KHUNG + String(st.get("tex", style)) + "_alb.png"
		m.set_shader_parameter("has_albedo", ResourceLoader.exists(tex_path))
		if ResourceLoader.exists(tex_path):
			m.set_shader_parameter("albedo_tex", load(tex_path))
		m.set_shader_parameter("shade_soft", 0.35)
		m.set_shader_parameter("rim", 0.12)
		_frame_mats[style] = m
	return _frame_mats[style]

static func picture(row: Dictionary) -> Texture2D:
	if row.get("calendar", false):
		return calendar_page()
	var path := ""
	if row.has("photo"):
		path = PhotoPrint.make_print(row["photo"], int(row["px"]))
	elif row.has("art"):
		path = ART + String(row["art"]) + ".png"
		if FileAccess.file_exists(story_shot(row["art"])):
			path = story_shot(row["art"])
	var want := pic_size(row) if row.has("cells") else Vector2.ONE
	var key := "%s|%.3f" % [path, want.x / want.y]
	if _pics.has(key):
		return _pics[key]
	var img: Image = null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		img = (load(path) as Texture2D).get_image()
	elif path != "" and FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img == null or img.is_empty():
		img = Image.create(8, 12, false, Image.FORMAT_RGB8)
		img.fill(Color("efe3c8"))
		return ImageTexture.create_from_image(img)
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var a := want.x / want.y
	if absf(float(w) / h - a) > 0.02:
		var cw := mini(w, roundi(h * a))
		var ch := mini(h, roundi(w / a))
		img = img.get_region(Rect2i((w - cw) / 2, (h - ch) / 2, cw, ch))
	img.generate_mipmaps()
	_pics[key] = ImageTexture.create_from_image(img)
	return _pics[key]

static func story_shot(id: String) -> String:
	return "user://photos/story/%s.png" % id

func render_story_photos() -> void:
	if not render_story:
		return
	for a in art().get("story_photos", []):
		var id: String = a["id"]
		var scene := "res://scenes/story_photos/%s.tscn" % id
		if FileAccess.file_exists(story_shot(id)) or not ResourceLoader.exists(scene):
			continue
		var have := kho.has(id) or san.has(id) or entries.any(func(e): return e.id == id)
		if not (have or Progress.is_open(a.get("unlock", id))):
			continue
		await _render_story(id, scene)

func _render_story(id: String, scene: String) -> void:
	var px := Vector2i(768, 512)
	var vp := SubViewport.new()
	vp.size = px * 2
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var set_: Node = load(scene).instantiate()
	vp.add_child(set_)
	set_.call("put_hero", Looks.load_saved())
	(set_.get_node("Cam") as Camera3D).make_current()
	await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(px.x, px.y, Image.INTERPOLATE_LANCZOS)
	img = PhotoPrint.finish(img, set_.get_meta("finish", {}))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(story_shot(id).get_base_dir()))
	img.save_png(story_shot(id))
	vp.queue_free()
	for k in _pics.keys():
		if String(k).begins_with(ART + id + "."):
			_pics.erase(k)
	for e in entries:
		if e.id == id:
			var mi := e.node.get_child(0) as MeshInstance3D
			if mi:
				(mi.get_surface_override_material(1) as ShaderMaterial).set_shader_parameter("albedo_tex", picture(item(id)))

static func calendar_page() -> Texture2D:
	Clock.load_saved()
	var d := clampi(int(Clock.lunar()[1]), 1, 30)
	var key := "lich:%d" % d
	if _pics.has(key):
		return _pics[key]
	var atlas := ART + "lich_bloc.png"
	if not ResourceLoader.exists(atlas):
		return picture({})
	var img: Image = (load(atlas) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var w := img.get_width() / 6
	var h := img.get_height() / 5
	var page := img.get_region(Rect2i(((d - 1) % 6) * w, ((d - 1) / 6) * h, w, h))
	page.generate_mipmaps()
	if _pics.size() > 64:
		_pics.clear()
	_pics[key] = ImageTexture.create_from_image(page)
	return _pics[key]

func collect_prints() -> int:
	Clock.load_saved()
	var n := 0
	for o in PhotoPrint.due(Clock.day):
		var id := "anh:%s:%s:%s:%s" % [o["photo"], o["size"], o["frame"], o["mount"]]
		if known(id):
			_receive_now(id)
			n += 1
	return n

func put(e: Entry, spot: Dictionary) -> void:
	if e.host:
		e.host.kids.erase(e)
	var shift: Vector2i = (spot["rect"] as Rect2i).position - e.rect.position
	for k in e.kids:
		k.rect = Rect2i(k.rect.position + shift, k.rect.size)
	e.layer = spot["layer"]
	e.rect = spot["rect"]
	e.wall = spot.get("wall", "")
	e.host = spot.get("host")
	if e.layer == "top":
		e.host.kids.append(e)
	if e not in entries:
		entries.append(e)
	_on_floor_kids(e)
	pose(e)

func _on_floor_kids(e: Entry) -> void:
	for k in e.kids:
		if k not in entries:
			entries.append(k)

func store(e: Entry) -> int:
	var to_san := 0
	for k in e.kids.duplicate():
		to_san += store(k)
	_off(e)
	return to_san + (0 if _add_kho(e.id) else 1)

func discard(e: Entry) -> bool:
	if keeps(e.id) != "":
		return false
	for k in e.kids.duplicate():
		store(k)
	_off(e)
	return true

func give(e: Entry) -> bool:
	if keeps(e.id) != "":
		return false
	for k in e.kids.duplicate():
		store(k)
	_off(e)
	basket[e.id] = int(basket.get(e.id, 0)) + 1
	return true

static func keeps(id: String) -> String:
	return String(item(id).get("keep", ""))

func _off(e: Entry) -> void:
	if e.host:
		e.host.kids.erase(e)
	e.host = null
	e.kids.clear()
	entries.erase(e)
	e.node.queue_free()

func kho_cap() -> int:
	if _upg.is_empty():
		_upg = JSON.parse_string(FileAccess.get_file_as_string(UPGRADES)) if FileAccess.file_exists(UPGRADES) else {}
	var cap := int(_upg.get("storage", {}).get("base", KHO_BASE))
	var done: Array = Story.flag("home_fixes_done", [])
	for f in _upg.get("fixes", []):
		if f.get("id", "") in done:
			cap += int(f.get("gives", {}).get("storage", 0))
	return cap

func kho_count() -> int:
	var n := 0
	for id in kho:
		n += int(kho[id])
	return n

func _add_kho(id: String) -> bool:
	if kho_count() < kho_cap():
		kho[id] = int(kho.get(id, 0)) + 1
		return true
	san[id] = int(san.get(id, 0)) + 1
	return false

func tidy_san() -> int:
	var moved := 0
	for id in san.keys():
		while int(san[id]) > 0 and kho_count() < kho_cap():
			san[id] = int(san[id]) - 1
			kho[id] = int(kho.get(id, 0)) + 1
			moved += 1
		if int(san[id]) <= 0:
			san.erase(id)
	return moved

func take(id: String, from_san := false) -> Entry:
	var d := san if from_san else kho
	if int(d.get(id, 0)) <= 0:
		return null
	d[id] = int(d[id]) - 1
	if d[id] == 0:
		d.erase(id)
	news.erase(id)
	return make(id)

static func receive(room_id: String, id: String) -> void:
	if not known(id):
		push_warning("DecorRoom.receive: %s is not in decor.json" % id)
		return
	for r in _live:
		if is_instance_valid(_live[r]):
			(_live[r] as DecorRoom)._receive_now(id)
			return
	var path := "user://save/decor_%s.json" % KHO_ROOM
	var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not d is Dictionary:
		d = {}
	var pend: Array = d.get("pending", [])
	pend.append(id)
	d["pending"] = pend
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(d, "\t"))

func _receive_now(id: String) -> void:
	_add_kho(id)
	if id not in news:
		news.append(id)
	received.emit(id)

func snapshot() -> String:
	var placed := []
	for e in entries:
		if e.layer != "top" and not e.held:
			placed.append(_row(e))
	return JSON.stringify({"placed": placed, "kho": kho, "san": san, "basket": basket,
		"surfaces": rs.state() if rs != null else surfaces})

func remember(state := "") -> void:
	grid.remember(state if state != "" else snapshot())

func undo() -> bool:
	var st := grid.undo()
	if st == "":
		return false
	restore(st)
	return true

func restore(state: String) -> void:
	var d: Dictionary = JSON.parse_string(state)
	for e in entries:
		e.node.queue_free()
	entries.clear()
	kho = _counts(d["kho"])
	san = _counts(d.get("san", {}))
	basket = _counts(d.get("basket", {}))
	for row in d["placed"]:
		_load_row(row, null)
	if d.has("surfaces"):
		surfaces = d["surfaces"]
		if rs != null:
			rs.load(surfaces)
		surfaces_changed.emit()

static func _counts(src: Dictionary) -> Dictionary:
	var out := {}
	for id in src:
		if int(src[id]) > 0:
			out[id] = int(src[id])
	return out

func entry_at(from: Vector3, dir: Vector3) -> Entry:
	var best: Entry = null
	var best_t := INF
	for e in entries:
		if e.held:
			continue
		var n: Node3D = e.node
		var hit = (n.global_transform * box(e.id)).intersects_ray(from, dir)
		if hit != null:
			var t := from.distance_to(hit)
			if e.layer == "top":
				t -= 0.05
			elif e.layer == "rug":
				t += 0.05
			if t < best_t:
				best_t = t
				best = e
	return best

func save() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path().get_base_dir()))
	var placed := []
	for e in entries:
		if e.layer != "top":
			placed.append(_row(e))
	var house := {"kho": kho, "got": got, "san": san, "basket": basket, "news": news}
	if rs != null:
		surfaces = rs.state()
	var mine := {"version": VERSION, "placed": placed, "surfaces": surfaces}
	if room == KHO_ROOM:
		mine.merge(house)
	else:
		var kp := "user://save/decor_%s.json" % KHO_ROOM
		var k = JSON.parse_string(FileAccess.get_file_as_string(kp)) if FileAccess.file_exists(kp) else null
		if not k is Dictionary:
			k = {}
		k.merge(house, true)
		k.erase("pending")
		FileAccess.open(kp, FileAccess.WRITE).store_string(JSON.stringify(k, "\t"))
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(mine, "\t"))

func _row(e: Entry) -> Dictionary:
	var r: Rect2i = e.rect
	if e.layer == "wall":
		return {"id": e.id, "wall": e.wall, "u": r.position.x, "v": r.position.y}
	var row := {"id": e.id, "x": r.position.x, "z": r.position.y, "rot": e.rot}
	if not e.kids.is_empty():
		row["kids"] = e.kids.map(_row)
	return row

func load_saved(fresh := false, all := false) -> void:
	Progress.load_saved()
	Clock.load_saved()
	var d = null
	if not fresh and FileAccess.file_exists(save_path()):
		d = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	var r: Dictionary = _rooms[room]
	var pending: Array = d.get("pending", []) if d is Dictionary else []
	if d is Dictionary and not d.has("placed"):
		d = null
	var placed: Array = d["placed"] if d is Dictionary else r["start"]
	_load_ver = int(d.get("version", 1)) if d is Dictionary else 2
	surfaces = d.get("surfaces", {}) if d is Dictionary else {}
	_rs_load()
	var k = d
	var kr: Dictionary = r
	if room != KHO_ROOM:
		var kp := "user://save/decor_%s.json" % KHO_ROOM
		k = JSON.parse_string(FileAccess.get_file_as_string(kp)) if FileAccess.file_exists(kp) else null
		if k is Dictionary and not k.has("kho"):
			k = null
		kr = _rooms[KHO_ROOM]
		if k is Dictionary:
			pending.append_array(k.get("pending", []))
	kho = _counts(k["kho"] if k is Dictionary else kr["kho"])
	san = _counts(k.get("san", {})) if k is Dictionary else {}
	basket = _counts(k.get("basket", {})) if k is Dictionary else {}
	news = Array(k.get("news", [])) if k is Dictionary else []
	got = Array(k.get("got", [])) if k is Dictionary else []
	for row in placed:
		_load_row(row, null)
	_load_ver = VERSION
	if d == null and room == KHO_ROOM:
		for e in entries:
			if e.id not in got:
				got.append(e.id)
		for id in kho:
			if id not in got:
				got.append(id)
	_unlocked(all)
	for id in pending:
		if known(id):
			_receive_now(id)
	collect_prints()
	grid.forget()
	render_story_photos.call_deferred()

func _load_row(row: Dictionary, host: Entry) -> void:
	if not known(row["id"]):
		return
	var e := make(row["id"], int(row.get("rot", 0)))
	var spot: Dictionary
	if row.has("wall"):
		var k := WALL_K if _load_ver < 3 else 1
		spot = {"layer": "wall", "wall": row["wall"], "rect": Rect2i(Vector2i(row["u"], row["v"]) * k, size_of(row["id"]))}
	else:
		var lay := "top" if host != null else ("rug" if item(row["id"])["kind"] == "rug" else "floor")
		spot = {"layer": lay, "host": host, "rect": Rect2i(Vector2i(row["x"], row["z"]), e.rect.size)}
	e.rect = spot["rect"]
	if not can_place(e, spot):
		push_warning("DecorRoom: %s does not fit at %s (kept there anyway)" % [row["id"], spot["rect"]])
	put(e, spot)
	for k in row.get("kids", []):
		_load_row(k, e)

func _unlocked(all: bool) -> void:
	for id in catalog():
		if id in got:
			continue
		if all or Progress.is_open(id):
			got.append(id)
			if all:
				kho[id] = int(kho.get(id, 0)) + 1
			else:
				_receive_now(id)
