class_name ToaTau
extends RefCounted

const W := 3.1
const FL := 1.0
const DOORS := [-4.9, 3.3]
const SLIDE := 0.52
const LENGTH := 12.3

const GLASS := preload("res://shaders/vehicle_glass.gdshader")
const STRAP := preload("res://shaders/toa_strap.gdshader")
static var _glass: ShaderMaterial
static var _glass_warm: ShaderMaterial
static var _straps: ShaderMaterial

static func place(parent: Node3D, pos: Vector3, yaw_deg := 0.0, solid := true, skin := "") -> Node3D:
	var car := Furniture.place(parent, "toa_tau", pos, yaw_deg, solid, skin)
	if _glass == null:
		_glass = ShaderMaterial.new()
		_glass.shader = GLASS
		_glass.set_shader_parameter("tint", Color(0.7, 0.86, 0.9, 0.05))
		_glass.set_shader_parameter("glint", 0.18)
	if _glass_warm == null:
		_glass_warm = _glass.duplicate()
		_glass_warm.set_shader_parameter("tint", Color(1.0, 0.86, 0.62, 0.08))
	for mi: MeshInstance3D in car.find_children("Glass*", "MeshInstance3D", true, false):
		mi.material_override = _glass_warm if skin == "" else _glass
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _straps == null:
		_straps = ShaderMaterial.new()
		_straps.shader = STRAP
		_straps.set_shader_parameter("tex", load("res://props/furniture/toa_tau_strap.png"))
	var st := car.find_child("Straps", true, false) as MeshInstance3D
	if st:
		st.material_override = _straps
		st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return car

static func set_sway(metres: float) -> void:
	if _straps:
		_straps.set_shader_parameter("sway", metres)

static func _leaves(car: Node3D, side: int) -> Array:
	var out := []
	var tag := "L" if side > 0 else "R"
	for i in DOORS.size():
		for half: String in ["A", "B"]:
			var n := car.find_child("Door%s%d%s" % [tag, i, half], true, false) as Node3D
			if n:
				if not n.has_meta("shut_z"):
					n.set_meta("shut_z", n.position.z)
				out.append([n, -1.0 if half == "A" else 1.0])
	return out

static func set_doors(car: Node3D, t: float, side := -1) -> void:
	for l: Array in _leaves(car, side):
		l[0].position.z = l[0].get_meta("shut_z") + l[1] * SLIDE * t

static func slide_doors(car: Node3D, open: bool, side := -1, secs := 0.9) -> Tween:
	var tw := car.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for l: Array in _leaves(car, side):
		tw.tween_property(l[0], "position:z", l[0].get_meta("shut_z") + (l[1] * SLIDE if open else 0.0), secs)
	return tw

static func door_spot(car: Node3D, door := 0, side := -1) -> Vector3:
	return car.to_global(Vector3(side * (W / 2 + 0.6), FL, DOORS[door]))

static func seat_spot(car: Node3D, z: float, side := -1) -> Transform3D:
	var p := car.to_global(Vector3(side * (W / 2 - 0.05 - 0.6), FL, z))
	var face := car.global_basis * Vector3(-side, 0, 0)
	return Transform3D(Basis.looking_at(-face), p)
