class_name StreetTraffic
extends Node3D

const BUS_SPEED := Vector2(7.0, 9.0)
const RIDE_SPEED := Vector2(5.5, 8.5)
const COATS := [Color("e8443a"), Color("f5c21b"), Color("3faa55"), Color("8b4fd0"), Color("2f8fe0"), Color("ff8a2a"),
	Color("e8443a"), Color("f5c21b")]
const RIDER_SHADER := preload("res://shaders/raincoat_rider.gdshader")

var half := 130.0
var _movers := []
var _riders := []
var _mm: MultiMesh

func setup(street_y: float, lanes: Array, half_len: float, buses := 2, riders := 36) -> void:
	half = half_len
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for i in buses:
		var bus := XeKhach.place(self, Vector3.ZERO, 0.0, false)
		XeKhach.set_lights(bus, true)
		var lane: Array = lanes[i % lanes.size()]
		bus.position = Vector3(r.randf_range(-half, half), street_y, lane[0])
		bus.rotation.y = PI / 2 if lane[1] > 0 else -PI / 2
		_movers.append([bus, lane[1], r.randf_range(BUS_SPEED.x, BUS_SPEED.y)])
	var src: Node3D = load("res://props/furniture/xe_may_ao_mua.glb").instantiate()
	var mi := src.find_child("*", true, false) as MeshInstance3D
	if mi == null:
		mi = src.find_children("*", "MeshInstance3D", true, false)[0]
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = mi.mesh
	_mm.instance_count = riders
	src.free()
	for i in riders:
		var lane: Array = lanes[i % lanes.size()]

		var x := r.randfn(0.0, half * 0.45)
		_riders.append([clampf(x, -half, half), street_y, lane[0] + r.randf_range(-1.6, 1.6), float(lane[1]),
			r.randf_range(RIDE_SPEED.x, RIDE_SPEED.y)])
		_mm.set_instance_custom_data(i, Color(COATS[r.randi_range(0, COATS.size() - 1)], r.randf()))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Riders"
	mmi.multimesh = _mm
	var m := ShaderMaterial.new()
	m.shader = RIDER_SHADER
	m.set_shader_parameter("albedo_tex", load("res://props/furniture/xe_may_ao_mua_alb.png"))
	m.set_shader_parameter("emit_tex", load("res://props/furniture/xe_may_ao_mua_emit.png"))
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_place_riders()

func _place_riders() -> void:
	for i in _riders.size():
		var d: Array = _riders[i]
		var yaw := PI / 2 if d[3] > 0 else -PI / 2
		_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), Vector3(d[0], d[1], d[2])))

func _process(delta: float) -> void:
	for m: Array in _movers:
		var n: Node3D = m[0]
		n.position.x += m[1] * m[2] * delta
		if n.position.x * m[1] > half:
			n.position.x = -m[1] * (half + randf_range(0.0, 40.0))
			n.reset_physics_interpolation()
	for d: Array in _riders:
		d[0] += d[3] * d[4] * delta
		if d[0] * d[3] > half:
			d[0] = -d[3] * (half + randf_range(0.0, 30.0))
	_place_riders()
