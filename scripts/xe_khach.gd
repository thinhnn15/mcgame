class_name XeKhach
extends RefCounted

const OPEN := {"DoorA": -90.0, "DoorB": 90.0}
const W := 2.3
const DOOR_Z := 2.57

const GLASS := preload("res://shaders/vehicle_glass.gdshader")
static var _glass: ShaderMaterial

static func place(parent: Node3D, pos: Vector3, yaw_deg := 0.0, solid := true) -> Node3D:
	var bus := Furniture.place(parent, "xe_khach", pos, yaw_deg, solid)
	if _glass == null:
		_glass = ShaderMaterial.new()
		_glass.shader = GLASS
	for mi: MeshInstance3D in bus.find_children("Glass*", "MeshInstance3D", true, false):
		mi.material_override = _glass
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return bus

static func set_door(bus: Node3D, t: float) -> void:
	for leaf: String in OPEN:
		var n := bus.find_child(leaf, true, false) as Node3D
		if n:
			n.rotation.y = deg_to_rad(OPEN[leaf] * t)

static func swing_door(bus: Node3D, open: bool, secs := 0.7) -> Tween:
	var tw := bus.create_tween().set_parallel().set_trans(Tween.TRANS_BACK if open else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for leaf: String in OPEN:
		var n := bus.find_child(leaf, true, false) as Node3D
		if n:
			tw.tween_property(n, "rotation:y", deg_to_rad(OPEN[leaf] if open else 0.0), secs)
	return tw

static func door_spot(bus: Node3D) -> Vector3:
	return bus.to_global(Vector3(-W / 2 - 0.75, 0.0, DOOR_Z))

static func inside_spot(bus: Node3D) -> Vector3:
	return bus.to_global(Vector3(-W / 2 + 0.38, 0.78, DOOR_Z))

const LAMP_FRONT := [Vector3(-0.66, 0.92, 3.335), Vector3(0.66, 0.92, 3.335)]
const LAMP_BACK := [Vector3(-0.82, 0.86, -3.345), Vector3(0.82, 0.86, -3.345)]
const BEAM := Color(1.0, 0.93, 0.76)
const CONE := preload("res://shaders/light_cone.gdshader")
const NOSE := 3.34
const PEOPLE := 2

static func set_lights(bus: Node3D, on: bool) -> void:
	var rig := bus.get_node_or_null("Lights") as Node3D
	if rig == null:
		if not on:
			return
		rig = _make_lights(bus)
	rig.visible = on

static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

static func _soft(stops: Array, radial: bool, from: Vector2, to: Vector2, w := 128, h := 128) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL if radial else GradientTexture2D.FILL_LINEAR
	tex.fill_from = from
	tex.fill_to = to
	tex.width = w
	tex.height = h
	return tex

static func _decal(tex: Texture2D, size: Vector3, energy: float) -> Decal:
	var d := Decal.new()
	d.size = size
	d.texture_emission = tex
	d.emission_energy = energy
	d.modulate = BEAM
	d.albedo_mix = 0.0
	d.normal_fade = 0.45
	d.cull_mask = 0xFFFFF & ~PEOPLE
	return d

static func _make_lights(bus: Node3D) -> Node3D:
	var rig := Node3D.new()
	rig.name = "Lights"
	bus.add_child(rig)
	var fwd := Vector3(0, -0.04, 1).normalized()
	var halo_tex := _soft([[0.0, Color(1, 1, 1, 0.9)], [0.35, Color(1, 1, 1, 0.35)], [1.0, Color(1, 1, 1, 0.0)]], true,
		Vector2(0.5, 0.5), Vector2(0.5, 0.0), 64, 64)
	for p: Vector3 in LAMP_FRONT:
		var face := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.12
		disc.bottom_radius = 0.12
		disc.height = 0.012
		disc.radial_segments = 16
		face.mesh = disc
		face.material_override = _glow(Color(1.0, 0.97, 0.88), 4.0)
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		face.position = p + Vector3(0, 0, 0.004)
		face.rotation.x = PI / 2
		rig.add_child(face)
		var halo := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.9)
		halo.mesh = q
		var hm := StandardMaterial3D.new()
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		hm.no_depth_test = false
		hm.albedo_texture = halo_tex
		hm.albedo_color = Color(BEAM.r, BEAM.g, BEAM.b, 0.8)
		halo.material_override = hm
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.position = p + Vector3(0, 0, 0.08)
		rig.add_child(halo)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.1
		cm.bottom_radius = 0.9
		cm.height = 7.0
		cm.cap_top = false
		cm.cap_bottom = false
		cone.mesh = cm
		var sm := ShaderMaterial.new()
		sm.shader = CONE
		sm.set_shader_parameter("color", BEAM)
		sm.set_shader_parameter("strength", 0.08)
		cone.material_override = sm
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var yv := -fwd
		var zv := Vector3.RIGHT.cross(yv).normalized()
		cone.basis = Basis(yv.cross(zv).normalized(), yv, zv)
		cone.position = p + fwd * 3.6
		rig.add_child(cone)

	var pool_tex := _soft([[0.0, Color(1, 1, 1)], [0.4, Color(0.55, 0.55, 0.55)], [1.0, Color(0, 0, 0)]], true,
		Vector2(0.5, 0.02), Vector2(0.5, 1.0), 128, 256)
	var pool := _decal(pool_tex, Vector3(4.0, 2.0, 10.0), 1.1)
	pool.position = Vector3(0, 0.5, NOSE + 5.0)
	rig.add_child(pool)

	var wall_tex := _soft([[0.0, Color(1, 1, 1)], [0.5, Color(0.45, 0.45, 0.45)], [1.0, Color(0, 0, 0)]], true,
		Vector2(0.5, 0.62), Vector2(0.5, 0.0), 128, 128)
	var front := _decal(wall_tex, Vector3(4.2, 10.0, 3.0), 0.9)
	front.rotation.x = -PI / 2
	front.position = Vector3(0, 1.1, NOSE + 5.2)
	front.upper_fade = 0.05
	front.lower_fade = 0.7
	rig.add_child(front)
	var spot := SpotLight3D.new()
	spot.light_color = BEAM
	spot.light_energy = 1.4
	spot.spot_range = 10.0
	spot.spot_angle = 30.0
	spot.light_cull_mask = PEOPLE
	spot.position = Vector3(0, 1.0, NOSE + 0.05)
	spot.basis = Basis.looking_at(fwd)
	rig.add_child(spot)
	for p: Vector3 in LAMP_BACK:
		var tail := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.13, 0.36, 0.012)
		tail.mesh = bm
		tail.material_override = _glow(Color(1.0, 0.25, 0.2), 3.0)
		tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tail.position = p
		rig.add_child(tail)
	return rig
