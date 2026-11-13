class_name FarmPens
extends Node3D

const CELL := 0.5
const DOOR := 1.0
const SLOPE := 0.4
const CATALOG := "res://data/farm/chuong.json"

static var KINDS: Dictionary = _load_kinds()
static var ORDER: Array = KINDS.keys()

static func _load_kinds() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var out := {}
	if not d is Dictionary:
		return out
	for id in d.get("kinds", {}):
		var k: Dictionary = (d["kinds"][id] as Dictionary).duplicate()
		var sz: Array = k.get("size", [2, 2])
		k["size"] = Vector2i(int(sz[0]), int(sz[1]))
		if not k.has("animals"):
			k["animals"] = []
		out[id] = k
	if ClassDB.class_exists("PenRules"):
		ClassDB.class_call_static("PenRules", "setup", d.get("kinds", {}))
	return out

static func next_kind(kind: String) -> String:
	for id in KINDS:
		if String(KINDS[id].get("prev", "")) == kind:
			return id
	return ""

static func can_build_any() -> bool:
	if not ClassDB.class_exists("PenWork"):
		return false
	for id in KINDS:
		if int(KINDS[id].get("days", 0)) > 0 and not KINDS[id].has("prev") \
				and String(ClassDB.class_call_static("PenWork", "check", id).get("reason", "")) != "locked":
			return true
	return false

const REST := {"lon_i": ["Idle", "Root", "Root", "Lie"], "lon_con": ["Idle", "Idle", "Lie"], "bo_vang": ["Idle", "Graze", "Graze", "Lie"]}
const WOOD := Color("c79f6a")
const BAMBOO := Color("d8b878")
const THATCH := Color("a8925a")
const STONE := Color("bdb4a2")

class Pen:
	var kind := ""
	var cell := Vector2i.ZERO
	var rot := 0
	var node: Node3D
	var animals := []
	var held := false
	var state := "xong"
	var data := {}

var scenery: FarmScenery
var bounds := Rect2()
var blockers := []
var paths := []
var hero: Node3D
var pens: Array = []

func setup(the_scenery: FarmScenery, the_bounds: Rect2, the_blockers: Array, the_paths: Array, the_hero: Node3D) -> void:
	scenery = the_scenery
	bounds = the_bounds
	blockers = the_blockers
	paths = the_paths
	hero = the_hero

static func size_of(kind: String, rot: int) -> Vector2i:
	var s: Vector2i = KINDS[kind]["size"]
	return Vector2i(s.y, s.x) if rot % 2 else s

static func rect_of(kind: String, cell: Vector2i, rot: int) -> Rect2:
	return Rect2(Vector2(cell) * CELL, Vector2(size_of(kind, rot)) * CELL)

static func door_rect(kind: String, cell: Vector2i, rot: int) -> Rect2:
	if not KINDS[kind]["door"]:
		return Rect2()
	var r := rect_of(kind, cell, rot)
	match rot % 4:
		0: return Rect2(r.position.x, r.end.y, r.size.x, DOOR)
		1: return Rect2(r.end.x, r.position.y, DOOR, r.size.y)
		2: return Rect2(r.position.x, r.position.y - DOOR, r.size.x, DOOR)
		_: return Rect2(r.position.x - DOOR, r.position.y, DOOR, r.size.y)

static func cell_for(kind: String, rot: int, p: Vector2) -> Vector2i:
	var s := size_of(kind, rot)
	return Vector2i(roundi(p.x / CELL - s.x / 2.0), roundi(p.y / CELL - s.y / 2.0))

func check(kind: String, cell: Vector2i, rot: int, ignore: Pen = null) -> String:
	if ClassDB.class_exists("PenRules"):
		var others := []
		for p: Pen in pens:
			if p != ignore:
				others.append([p.kind, p.cell, p.rot])
		var ctx := {"bounds": bounds, "blockers": blockers, "pens": others, "height": scenery.height_at,
			"terrain": _terrain}
		if hero:
			ctx["hero"] = Vector2(hero.global_position.x, hero.global_position.z)
		var why := String(ClassDB.class_call_static("PenRules", "check", kind, cell, rot, ctx))
		if why == "" and String(KINDS[kind].get("ground", "any")) == "pond":
			var r0 := rect_of(kind, cell, rot)
			var near := INF
			for sx in [0.0, 0.5, 1.0]:
				for sz in [0.0, 0.5, 1.0]:
					near = minf(near, FarmScenery.pond_e(r0.position.x + r0.size.x * sx, r0.position.y + r0.size.y * sz))
			if near > 2.4:
				why = "PEN_BAD_GROUND_POND"
		return why
	var r := rect_of(kind, cell, rot).grow(-0.01)
	var d := door_rect(kind, cell, rot).grow(-0.01)
	if not bounds.encloses(r) or (d.has_area() and not bounds.encloses(d)):
		return "PEN_BAD_OUT"
	for b in blockers:
		if r.intersects(b[0]) or (d.has_area() and d.intersects(b[0])):
			return b[1]
	for p: Pen in pens:
		if p == ignore:
			continue
		var pr := rect_of(p.kind, p.cell, p.rot)
		var pd := door_rect(p.kind, p.cell, p.rot)
		if r.intersects(pr) or (pd.has_area() and r.intersects(pd)) or (d.has_area() and d.intersects(pr)):
			return "PEN_BAD_PEN"
	var lo := INF
	var hi := -INF
	var x := r.position.x
	while x <= r.end.x + 0.01:
		var z := r.position.y
		while z <= r.end.y + 0.01:
			if FarmScenery.pond_e(x, z) < 1.7 or absf(z - FarmScenery.DITCH_Z) < 1.2:
				return "PEN_BAD_WATER"
			var h := scenery.height_at(x, z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
			for path in paths:
				if _on_path(Vector2(x, z), path):
					return "PEN_BAD_PATH"
			z += CELL
		x += CELL
	if hi - lo > SLOPE:
		return "PEN_BAD_SLOPE"
	if hero and r.grow(0.3).has_point(Vector2(hero.global_position.x, hero.global_position.z)):
		return "PEN_BAD_HERO"
	return ""

func _terrain(x: float, z: float, ground: String) -> String:
	var pe := FarmScenery.pond_e(x, z)
	if ground == "pond":
		if pe < 0.6:
			return "PEN_BAD_WATER"
	elif pe < 1.7 or absf(z - FarmScenery.DITCH_Z) < 1.2:
		return "PEN_BAD_WATER"
	for path in paths:
		if _on_path(Vector2(x, z), path):
			return "PEN_BAD_PATH"
	return ""

func _on_path(q: Vector2, path: Array) -> bool:
	var pts: Array = path[0]
	var half: float = path[1] / 2.0 + 0.15
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var t := clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if q.distance_to(a + (b - a) * t) < half:
			return true
	return false

func pen_at(p: Vector2) -> Pen:
	for pen: Pen in pens:
		if rect_of(pen.kind, pen.cell, pen.rot).has_point(p):
			return pen
	return null

func add(kind: String, cell: Vector2i, rot: int, stock := true, state := "xong") -> Pen:
	var p := Pen.new()
	p.kind = kind
	p.cell = cell
	p.rot = rot
	p.state = state
	pens.append(p)
	_remake(p)
	place(p, cell, rot)
	if stock and state == "xong":
		stock(p)
	return p

func _remake(p: Pen) -> void:
	if p.node:
		p.node.queue_free()
	match p.state:
		"xong":
			p.node = _build(p.kind)
			add_child(p.node)
		_:
			var r := rect_of(p.kind, p.cell, p.rot)
			var stage := 0
			var days := maxi(1, int(KINDS[p.kind].get("days", 1)))
			if p.state == "dang_xay":
				stage = maxi(1, int(Story.flag("chuong_xay_ngay", 1)))
			var brick: bool = (KINDS[p.kind].get("needs", {}) as Dictionary).has("gach")
			p.node = PenSite.add(self, r, scenery.height_at(r.get_center().x, r.get_center().y), stage, days, brick)
	place(p, p.cell, p.rot)

func set_state(p: Pen, state: String) -> void:
	if p.state == state and p.node:
		return
	p.state = state
	_remake(p)

func finish_build(row: Dictionary) -> void:
	var idx := int(row.get("pen", -1))
	var cl: Array = row.get("cell", [0, 0])
	var cell := Vector2i(int(cl[0]), int(cl[1]))
	var kind := String(row.get("kind", ""))
	if not KINDS.has(kind):
		return
	if idx >= 0 and idx < pens.size():
		var p: Pen = pens[idx]
		p.kind = kind
		p.cell = cell
		p.rot = int(row.get("rot", p.rot))
		set_state(p, "xong")
		settle(p)
		return
	add(kind, cell, int(row.get("rot", 0)), false)

func refresh_sites() -> void:
	if not ClassDB.class_exists("PenWork"):
		return
	var b: Dictionary = ClassDB.class_call_static("PenWork", "booked")
	var idx := int(b.get("pen", -1)) if not b.is_empty() else -1
	var day := int(Story.flag("chuong_xay_ngay", 0))
	for i in pens.size():
		var p: Pen = pens[i]
		if i == idx and day > 0:
			if p.state == "xong":
				p.kind = String(b.get("kind", p.kind))
			set_state(p, "dang_xay")
		elif i == idx and p.state == "dang_xay":
			set_state(p, "nen")
		elif i != idx and p.state == "dang_xay":
			set_state(p, "xong")

func demolish(p: Pen) -> bool:
	if not p.animals.is_empty():
		return false
	if p.state == "xong" and ClassDB.class_exists("PenRules") and ClassDB.class_exists("Stock"):
		var back: Dictionary = ClassDB.class_call_static("PenRules", "refund", p.kind)
		for m in back:
			Stock.add(m, int(back[m]))
	remove(p)
	return true

func stock(p: Pen) -> void:
	if p.state != "xong":
		return
	for what in KINDS[p.kind]["animals"]:
		_spawn(p, what)

func _spawn(p: Pen, what: String) -> void:
	var at := _inside(p)
	var a := FarmAnimal.spawn(self, what, _world(p, at), randf() * TAU)
	p.animals.append({"a": a, "goal": at, "wait": randf_range(0.5, 4.0), "lie": false})

func place(p: Pen, cell: Vector2i, rot: int, lift := 0.0) -> void:
	p.cell = cell
	p.rot = rot
	var r := rect_of(p.kind, cell, rot)
	var c := r.get_center()
	p.node.position = Vector3(c.x, scenery.height_at(c.x, c.y) + lift, c.y)
	p.node.rotation.y = rot * PI / 2

func settle(p: Pen) -> void:
	for d in p.animals:
		d.goal = _inside(p)
		d.wait = 0.0
		if d.lie:
			d.lie = false
			(d.a as FarmAnimal).play("Stand_Up")

func remove(p: Pen) -> void:
	for d in p.animals:
		(d.a as Node).queue_free()
	p.node.queue_free()
	pens.erase(p)

func step(delta: float) -> void:
	for p: Pen in pens:
		if p.held:
			continue
		for d in p.animals:
			_animal(p, d, delta)

func _animal(p: Pen, d: Dictionary, delta: float) -> void:
	var a: FarmAnimal = d.a
	var want := _world(p, d.goal)
	var to := Vector3(want.x - a.position.x, 0, want.z - a.position.z)
	if to.length() > 0.12:
		var far := to.length() > 2.5
		var clip := "Run" if far and a.speed("Run") > 0.0 else "Walk"
		if a.anim.current_animation != clip:
			a.play(clip)
		var v := to.normalized() * a.speed(clip)
		a.position += v * delta if v.length() * delta < to.length() else to
		a.position.y = scenery.height_at(a.position.x, a.position.z)
		a.rotation.y = lerp_angle(a.rotation.y, atan2(to.x, to.z), 1.0 - exp(-delta * 6.0))
		return
	if a.anim.current_animation in ["Walk", "Run"]:
		a.play("Idle")
	d.wait -= delta
	if d.wait > 0.0:
		return
	if d.lie:
		d.lie = false
		a.play("Stand_Up")
		d.wait = 1.5
		return
	var acts: Array = REST.get(a.kind, ["Idle"])
	var act: String = acts[randi() % acts.size()]
	if act == "Lie":
		d.lie = true
		a.play("Lie_Start")
		d.wait = randf_range(12.0, 25.0)
	elif randf() < 0.5:
		d.goal = _inside(p)
	else:
		a.play(act)
		d.wait = randf_range(3.0, 8.0)

func _inside(p: Pen) -> Vector2:
	var s := Vector2(KINDS[p.kind]["size"]) * CELL
	return Vector2(randf_range(-s.x / 2 + 0.55, s.x / 2 - 0.55), randf_range(-s.y / 2 + 0.75, s.y / 2 - 0.55))

func _world(p: Pen, local: Vector2) -> Vector3:
	var w := p.node.position + Basis(Vector3.UP, p.rot * PI / 2) * Vector3(local.x, 0, local.y)
	return Vector3(w.x, scenery.height_at(w.x, w.z), w.z)

func to_dict() -> Array:
	var out := []
	for p: Pen in pens:
		out.append({"kind": p.kind, "x": p.cell.x, "z": p.cell.y, "rot": p.rot, "data": p.data, "state": p.state,
			"animals": p.animals.map(func(d: Dictionary) -> String: return (d.a as FarmAnimal).kind)})
	return out

func from_dict(rows: Array) -> void:
	for p in pens.duplicate():
		remove(p)
	for row in rows:
		if not KINDS.has(row.get("kind", "")):
			continue
		var p := add(row["kind"], Vector2i(int(row["x"]), int(row["z"])), int(row["rot"]), false, String(row.get("state", "xong")))
		p.data = row.get("data", {})
		for what in row.get("animals", []):
			_spawn(p, what)

func _build(kind: String) -> Node3D:
	var root := Node3D.new()
	var s := Vector2(KINDS[kind]["size"]) * CELL
	var body := StaticBody3D.new()
	root.add_child(body)
	var model := String(KINDS[kind].get("model", ""))
	if model != "" and kind != "to_ong" and ResourceLoader.exists(Furniture.DIR + model + ".glb"):
		Furniture.place(root, model, Vector3.ZERO, 0.0, false)
		if KINDS[kind]["door"]:
			_walls_solid(body, s, 1.0, 1.0)
		else:
			_box(body, Vector3(s.x * 0.6, 0.9, s.y * 0.6), Vector3(0, 0.45, 0))
		return root
	match kind:
		"chuong_lon":
			_part(root, Vector3(s.x, 0.06, s.y), STONE, Vector3(0, 0.03, 0))
			_walls(root, body, s, 0.75, 1.0, BAMBOO)
			for x in [-s.x / 2 + 0.08, s.x / 2 - 0.08]:
				for z in [-s.y / 2 + 0.08, 0.0]:
					_part(root, Vector3(0.1, 1.6, 0.1), WOOD, Vector3(x, 0.8, z))
			_part(root, Vector3(s.x + 0.3, 0.1, s.y / 2 + 0.4), THATCH, Vector3(0, 1.62, -s.y / 4), Vector3(-8, 0, 0))
			_part(root, Vector3(1.2, 0.25, 0.35), Color("a8a39a"), Vector3(0, 0.15, s.y / 2 - 0.45))
			_part(root, Vector3(0.9, 0.18, 0.8), Color("e8cf7a"), Vector3(-s.x / 2 + 0.6, 0.1, -s.y / 2 + 0.55))
		"chuong_bo":
			_walls(root, body, s, 1.1, 1.4, WOOD)
			for x in [-s.x / 2 + 0.1, s.x / 2 - 0.1]:
				for z in [-s.y / 2 + 0.1, s.y / 2 - 0.1]:
					_part(root, Vector3(0.14, 2.3, 0.14), WOOD, Vector3(x, 1.15, z))
			_part(root, Vector3(s.x + 0.5, 0.14, s.y + 0.5), THATCH, Vector3(0, 2.35, 0), Vector3(-6, 0, 0))
			_part(root, Vector3(1.6, 0.35, 0.45), WOOD, Vector3(0, 0.25, -s.y / 2 + 0.4))
			_part(root, Vector3(1.4, 0.2, 0.35), Color("e8cf7a"), Vector3(0, 0.45, -s.y / 2 + 0.4))
		"to_ong":
			Furniture.place(root, "to_ong", Vector3.ZERO, 0.0, false)
			_box(body, Vector3(0.48, 0.6, 0.48), Vector3(0, 0.3, 0))
		"coc_bo":
			_part(root, Vector3(0.1, 0.9, 0.1), BAMBOO, Vector3(0, 0.45, 0))
			_part(root, Vector3(0.18, 0.06, 0.18), Color("8a6a44"), Vector3(0, 0.7, 0))
			_box(body, Vector3(0.2, 0.9, 0.2), Vector3(0, 0.45, 0))
		_:
			var h := 0.9 if s.x < 2.5 else 1.1
			_part(root, Vector3(s.x, 0.06, s.y), STONE, Vector3(0, 0.03, 0))
			if KINDS[kind]["door"]:
				_walls(root, body, s, h, minf(1.0, s.x * 0.4), BAMBOO)
			else:
				_walls(root, body, s, h, 0.0, BAMBOO)
			for x in [-s.x / 2 + 0.08, s.x / 2 - 0.08]:
				for z in [-s.y / 2 + 0.08, s.y / 2 - 0.08]:
					_part(root, Vector3(0.1, h + 0.8, 0.1), WOOD, Vector3(x, (h + 0.8) / 2, z))
			if KINDS[kind].get("ground", "any") != "grass":
				_part(root, Vector3(s.x + 0.3, 0.1, s.y + 0.3), THATCH, Vector3(0, h + 0.82, 0), Vector3(-6, 0, 0))
	return root

func _walls_solid(body: StaticBody3D, s: Vector2, h: float, gap: float) -> void:
	var t := 0.16
	_box(body, Vector3(s.x, h, t), Vector3(0, h / 2, -s.y / 2 + t / 2))
	for x in [-1, 1]:
		_box(body, Vector3(t, h, s.y), Vector3(x * (s.x / 2 - t / 2), h / 2, 0))
		var w := (s.x - gap) / 2
		_box(body, Vector3(w, h, t), Vector3(x * (gap / 2 + w / 2), h / 2, s.y / 2 - t / 2))

func _walls(root: Node3D, body: StaticBody3D, s: Vector2, h: float, gap: float, c: Color) -> void:
	var t := 0.08
	_part(root, Vector3(s.x, h, t), c, Vector3(0, h / 2, -s.y / 2 + t / 2))
	_box(body, Vector3(s.x, h, t * 2), Vector3(0, h / 2, -s.y / 2 + t / 2))
	for x in [-1, 1]:
		_part(root, Vector3(t, h, s.y), c, Vector3(x * (s.x / 2 - t / 2), h / 2, 0))
		_box(body, Vector3(t * 2, h, s.y), Vector3(x * (s.x / 2 - t / 2), h / 2, 0))
		var w := (s.x - gap) / 2
		_part(root, Vector3(w, h, t), c, Vector3(x * (gap / 2 + w / 2), h / 2, s.y / 2 - t / 2))
		_box(body, Vector3(w, h, t * 2), Vector3(x * (gap / 2 + w / 2), h / 2, s.y / 2 - t / 2))

func _part(root: Node3D, size: Vector3, c: Color, pos: Vector3, rot := Vector3.ZERO) -> void:
	Props._part(root, root, Props._box(size), c, pos, rot)

func _box(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	body.add_child(cs)
