class_name XeBo
extends Node3D

const MODEL := "cub_tripo"
const AWAY_FROM := 7.0
const AWAY_UNTIL := 17.5

var _bike: Node3D
var _home := true
var _t := 0.0
var _always := false

static func add(parent: Node3D, at: Vector3, yaw_deg := 0.0) -> XeBo:
	var x := XeBo.new()
	x.name = "XeBo"
	x.position = at
	x.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(x)
	return x

static func bo_home() -> bool:
	var h := Clock.hour()
	return h < AWAY_FROM or h >= AWAY_UNTIL or Clock.raining()

func _ready() -> void:
	_always = "--xe-bo" in OS.get_cmdline_user_args()
	if _always:
		(func() -> void: print("XeBo at ", global_position)).call_deferred()
	if not ResourceLoader.exists(Furniture.DIR + MODEL + ".glb"):
		push_warning("XeBo: no %s.glb (blender -b -P tools/furniture/cub_tripo.py)" % MODEL)
		return
	_bike = Furniture.place(self, MODEL, Vector3.ZERO, 0.0, true)
	_show(_always or bo_home())

func _show(home: bool) -> void:
	_home = home
	if _bike == null:
		return
	_bike.visible = home
	for sb: StaticBody3D in _bike.find_children("*", "StaticBody3D", true, false):
		for cs: CollisionShape3D in sb.find_children("*", "CollisionShape3D", true, false):
			cs.disabled = not home

func _process(delta: float) -> void:
	_t += delta
	if _t < 2.0:
		return
	_t = 0.0
	var h := _always or bo_home()
	if h != _home:
		_show(h)
