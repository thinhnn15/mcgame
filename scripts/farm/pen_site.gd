class_name PenSite
extends Node3D

const START_H := 7.0
const END_H := 17.0
const WOOD := Color("c79f6a")
const WOOD_D := Color("8a6a44")
const ROPE := Color("d8c8a0")
const THATCH := Color("a8925a")
const BRICK := Color("b86a4a")
const SAND := Color("d9c49a")

var rect := Rect2()
var stage := 0
var days := 1
var _worker: Chibi
var _on := false
var _alive := true

static func add(parent: Node3D, p_rect: Rect2, y: float, p_stage: int, p_days: int, brick: bool) -> PenSite:
	var s := PenSite.new()
	s.name = "PenSite"
	s.rect = p_rect
	s.stage = p_stage
	s.days = maxi(1, p_days)
	s.position = Vector3(p_rect.get_center().x, y, p_rect.get_center().y)
	parent.add_child(s)
	s._build(brick)
	return s

func _exit_tree() -> void:
	_alive = false

func _build(brick: bool) -> void:
	var w := rect.size.x
	var d := rect.size.y
	var hx := w / 2.0
	var hz := d / 2.0

	var xf := []
	var n_x := maxi(1, roundi(w / 1.5))
	var n_z := maxi(1, roundi(d / 1.5))
	for i in n_x + 1:
		for sz in [-1.0, 1.0]:
			xf.append(Transform3D(Basis(), Vector3(-hx + w * i / n_x, 0, sz * hz)))
	for j in range(1, n_z):
		for sx in [-1.0, 1.0]:
			xf.append(Transform3D(Basis(), Vector3(sx * hx, 0, -hz + d * j / n_z)))
	HomeKit._batch(self, "coc_tre", xf)
	for sz in [-1.0, 1.0]:
		_part(Vector3(w, 0.03, 0.03), ROPE, Vector3(0, 0.55, sz * hz))
	for sx in [-1.0, 1.0]:
		_part(Vector3(0.03, 0.03, d), ROPE, Vector3(sx * hx, 0.55, 0))

	_part(Vector3(0.36, 0.26, 0.03), WOOD, Vector3(-hx + 0.3, 0.95, hz + 0.02))
	_part(Vector3(0.04, 1.1, 0.04), WOOD_D, Vector3(-hx + 0.3, 0.55, hz))
	if stage <= 0:
		return

	HomeKit.place(self, "dong_cat", Vector3(hx + 0.9, 0, -hz + 0.6), -20.0)
	if brick:
		HomeKit.place(self, "dong_gach", Vector3(hx + 0.8, 0, -hz + 1.7), 10.0)
	else:
		for k in 5:
			Props._part(self, self, Props._cyl(0.04, 0.04, d * 0.8), Color("d8b878"),
				Vector3(hx + 0.6 + 0.09 * k, 0.04 + 0.03 * (k % 2), -hz + 1.6), Vector3(90, 0, 0))

	var s1 := 1
	var s2 := 2 if days >= 2 else 1
	var s3 := days
	var px := hx - 0.25
	var pz := hz - 0.25
	if stage >= s1:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_part(Vector3(0.12, 1.8, 0.12), WOOD, Vector3(sx * px, 0.9, sz * pz))
		_part(Vector3(w - 0.3, 0.1, 0.1), WOOD, Vector3(0, 1.85, -pz))
		_part(Vector3(w - 0.3, 0.1, 0.1), WOOD, Vector3(0, 1.85, pz))
		_part(Vector3(0.1, 0.1, d - 0.3), WOOD, Vector3(-px, 1.85, 0))
		_part(Vector3(0.1, 0.1, d - 0.3), WOOD, Vector3(px, 1.85, 0))
	if stage >= s2 and days >= 2:
		var c := BRICK if brick else Color("d8b878")
		_part(Vector3(w - 0.4, 0.8, 0.08), c, Vector3(0, 0.4, -pz))
		_part(Vector3(0.08, 0.8, d - 0.4), c, Vector3(-px, 0.4, 0))
		_part(Vector3(0.08, 0.8, d - 0.4), c, Vector3(px, 0.4, 0))
	if stage >= s3 and days >= 3:
		Props._part(self, self, Props._box(Vector3(w + 0.3, 0.1, d / 2.0 + 0.3)), THATCH,
			Vector3(0, 2.05, -d / 4.0), Vector3(-10, 0, 0))

	_worker = Chibi.new()
	_worker.name = "ThoChuong"
	add_child(_worker)
	var look := Looks.DEFAULT.duplicate(true)
	var l: Dictionary = WorkSite.BUILDER["tho_ca"]
	for key in l:
		look[key] = l[key].duplicate(true) if l[key] is Dictionary else l[key]
	_worker.build(look)
	if not OS.get_cmdline_user_args().has("--no-merge"):
		ChibiMerge.merge(_worker)
	_worker.position = Vector3(px - 0.55, 0, pz + 0.5)
	_worker.rotation.y = PI * 0.75
	_set_on(_working())
	_hammer()

func _part(size: Vector3, c: Color, pos: Vector3) -> void:
	Props._part(self, self, Props._box(size), c, pos, Vector3.ZERO)

func _working() -> bool:
	var h := Clock.hour()
	return h >= START_H and h < END_H and not Clock.raining()

func _set_on(on: bool) -> void:
	_on = on
	if _worker:
		_worker.visible = on
		_worker.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED

func _process(_d: float) -> void:
	if _worker == null:
		return
	var on := _working()
	if on != _on:
		_set_on(on)

func _hammer() -> void:
	_worker.hold("bua")
	while _alive:
		if not _on:
			await get_tree().create_timer(1.0).timeout
			continue
		for i in randi_range(3, 5):
			var impact: float = _worker.use_tool("Tool_Axe_Hit")
			if impact < 0.0:
				break
			await get_tree().create_timer(impact).timeout
			if not _alive:
				return
			if _on and _worker.is_inside_tree():
				Sound.play_at("step.wood", _worker.global_position + Vector3(0, 0.6, -0.4), 2.0, randf_range(1.35, 1.6))
			await get_tree().create_timer(0.55).timeout
		if not _alive:
			return
		await get_tree().create_timer(randf_range(1.5, 3.5)).timeout
