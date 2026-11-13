class_name FarmHouse
extends Node3D

signal entered

const MODELS := ["nha_cu", "nha_cu_1", "nha_cu_2", "nha_cu_2", "nha_cu_4"]
const DOOR := Vector3(0, 0, 1.4)
const DOOR_R := 0.5
const AWAY := 1.0

const PORCH_H := 0.22
const PORCH_X := 2.72
const PORCH_Z := 2.41
const PORCH_RUN := 0.28

var level := 0
var building := 0
var hero: Node3D
var _armed := false

static func add(parent: Node3D, at: Vector3, yaw := 0.0) -> FarmHouse:
	var h := FarmHouse.new()
	h.name = "FarmHouse"
	h.position = at
	h.rotation.y = yaw
	parent.add_child(h)
	return h

static func saved_level() -> int:
	var lv := 0
	for id in Story.flag("home_fixes_done", []):
		var s := String(id)
		if s.begins_with("nha_muc_") and s.substr(8).is_valid_int():
			lv = maxi(lv, int(s.substr(8)))
	return lv

func _ready() -> void:
	level = saved_level()
	building = int(Story.flag("nha_dang_xay", 0))
	if building <= level:
		building = 0
	HomeKit.place(self, MODELS[clampi(level, 0, MODELS.size() - 1)], Vector3.ZERO)
	var body := StaticBody3D.new()
	add_child(body)
	_box(body, Vector3(5.2, 3.0, 2.9), Vector3(0, 1.5, -0.35))
	_porch(body)
	if level >= 2:
		_box(body, Vector3(1.85, 2.4, 2.05), Vector3(3.4, 1.2, -0.35))
	if level >= 3:
		HomeKit.place(self, "san_gach_nha_cu", Vector3.ZERO)
		HomeKit.place(self, "bep_nha_cu", Vector3(-3.9, 0.0, -2.75))
		_box(body, Vector3(2.05, 2.2, 1.75), Vector3(-3.9, 1.1, -2.75))
	if building > 0:
		WorkSite.add(self, building)

func _box(body: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)

func _porch(body: StaticBody3D) -> void:
	var x := PORCH_X
	var r := PORCH_RUN
	_hull(body, [Vector3(-x, PORCH_H, 0.9), Vector3(x, PORCH_H, 0.9), Vector3(-x, PORCH_H, PORCH_Z), Vector3(x, PORCH_H, PORCH_Z),
		Vector3(-x - r, 0, 0.9), Vector3(x + r, 0, 0.9), Vector3(-x - r, 0, PORCH_Z + r), Vector3(x + r, 0, PORCH_Z + r)])
	var pts := []
	for sx: float in [-0.7, 0.7]:
		pts += [Vector3(sx, 0, PORCH_Z - 0.1), Vector3(sx, PORCH_H, PORCH_Z - 0.1), Vector3(sx, PORCH_H, PORCH_Z),
			Vector3(sx, 0.11, 2.72), Vector3(sx, 0, 2.88)]
	_hull(body, pts)

func _hull(body: StaticBody3D, pts: Array) -> void:
	var cs := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = PackedVector3Array(pts)
	cs.shape = hull
	body.add_child(cs)

func door_out() -> Vector3:
	return to_global(DOOR + Vector3(0, PORCH_H, 0.9))

func footprint() -> Rect2:
	var c := global_position
	return Rect2(c.x - 5.4, c.z - 3.8, 10.4, 3.8 + (6.8 if level >= 3 else 3.0))

func _physics_process(_d: float) -> void:
	if hero == null or building > 0 or not is_instance_valid(hero):
		return
	var p := to_local(hero.global_position)
	var dist := Vector2(p.x - DOOR.x, p.z - DOOR.z).length()
	if dist > AWAY:
		_armed = true
	elif _armed and dist < DOOR_R:
		_armed = false
		entered.emit()
