class_name SwimFX
extends Node3D

enum {OFF, SURFACE, UNDER}
const DIR := "res://props/farm/fx/"
const RINGS := 24
const RINGS_HQ := 44

var target: Node3D
var size := 1.0
var water_y := 0.0
var mode := SURFACE
var bubble_from: Callable

var _mm: MultiMesh
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _pos := PackedVector3Array()
var _r0 := PackedFloat32Array()
var _grow := PackedFloat32Array()
var _a0 := PackedFloat32Array()
var _next := 0
var _foam: MeshInstance3D
var _shade: MeshInstance3D
var _wake: CPUParticles3D
var _burst: CPUParticles3D
var _bubbles: CPUParticles3D
var _last := Vector3.INF
var _speed := 0.0
var _t_ring := 0.0
var _t_pop := 0.0
var _hq := false
var _n := RINGS
var _stroke: Array[CPUParticles3D] = []
var _t_stroke := 0.0
var _side := 1.0
var _t_breath := 0.6
const DABS := 72
var _dab_mm: MultiMesh
var _dab_age := PackedFloat32Array()
var _dab_pos := PackedVector3Array()
var _dab_vel := PackedVector3Array()
var _dab_yaw := PackedFloat32Array()
var _dab_w := PackedFloat32Array()
var _dab_col := PackedColorArray()
var _dab_next := 0
var _t_dab := 0.0

static var _mats := {}

static func attach(who: Node3D, size_ := 1.0, water := NAN) -> SwimFX:
	var fx := SwimFX.new()
	fx.target = who
	fx.size = size_
	fx.water_y = who.global_position.y if is_nan(water) else water
	who.get_parent().add_child(fx)
	return fx

static func head_of(who: Node3D, bone := "Head") -> Callable:
	var sk := who.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null or sk.find_bone(bone) < 0:
		return Callable()
	var i := sk.find_bone(bone)
	return func() -> Vector3: return sk.global_transform * sk.get_bone_global_pose(i).origin

static func _shade_mat() -> StandardMaterial3D:
	if not _mats.has("shade"):
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.75))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 64
		gt.height = 64
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = gt
		m.albedo_color = Color(0.05, 0.16, 0.24, 0.42)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 1
		_mats["shade"] = m
	return _mats["shade"]

static func _mat(tex: String, color := Color.WHITE, billboard := false) -> StandardMaterial3D:
	var key := tex + str(billboard)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = load(DIR + tex + ".png")
		m.albedo_color = color
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 1
		if billboard:
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_mats[key] = m
	return _mats[key]

func _ready() -> void:

	_hq = Quality.is_high()
	_n = RINGS_HQ if _hq else RINGS
	var quad := PlaneMesh.new()
	quad.size = Vector2(2, 2)
	quad.material = _mat("ring", Color(1, 1, 1, 0.9))
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = quad
	_mm.instance_count = _n
	for i in _n:
		_age.append(9.0)
		_life.append(1.0)
		_pos.append(Vector3.ZERO)
		_r0.append(0.0)
		_grow.append(0.0)
		_a0.append(0.0)
		_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		_mm.set_instance_color(i, Color(1, 1, 1, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	mmi.top_level = true

	_foam = MeshInstance3D.new()
	var fq := PlaneMesh.new()
	fq.size = Vector2(2, 2)
	fq.material = _mat("foam", Color(1, 1, 1, 0.5))
	_foam.mesh = fq
	_foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_foam)
	_foam.top_level = true

	_shade = MeshInstance3D.new()
	var sq := PlaneMesh.new()
	sq.size = Vector2(2, 2)
	sq.material = _shade_mat()
	_shade.mesh = sq
	_shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shade.visible = false
	add_child(_shade)
	_shade.top_level = true
	_wake = _drops(14, 0.55, false)
	_burst = _drops(28, 0.8, true)
	_bubbles = _bubble_emitter()
	if _hq:
		var dq := PlaneMesh.new()
		dq.size = Vector2(1, 1)
		dq.material = _mat("streak", Color(1, 1, 1, 0.85))
		_dab_mm = MultiMesh.new()
		_dab_mm.transform_format = MultiMesh.TRANSFORM_3D
		_dab_mm.use_colors = true
		_dab_mm.mesh = dq
		_dab_mm.instance_count = DABS
		for i in DABS:
			_dab_age.append(9.0)
			_dab_pos.append(Vector3.ZERO)
			_dab_vel.append(Vector3.ZERO)
			_dab_yaw.append(0.0)
			_dab_w.append(1.0)
			_dab_col.append(Color(1, 1, 1, 0))
			_dab_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			_dab_mm.set_instance_color(i, Color(1, 1, 1, 0))
		var dmi := MultiMeshInstance3D.new()
		dmi.multimesh = _dab_mm
		dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dmi)
		dmi.top_level = true
	if _hq:
		for i in 2:
			var e := _drops(16, 0.6, true)
			(e.mesh as QuadMesh).size = Vector2.ONE * 0.11 * size
			e.spread = 30.0
			e.initial_velocity_min = 1.1 * sqrt(size)
			e.initial_velocity_max = 2.0 * sqrt(size)
			e.emission_sphere_radius = 0.08 * size
			_stroke.append(e)

func _drops(n: int, life: float, burst: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.07 * size
	q.material = _mat("drop", Color(0.92, 0.97, 1.0, 0.95), true)
	p.mesh = q
	p.amount = n
	p.lifetime = life
	p.one_shot = burst
	p.explosiveness = 0.92 if burst else 0.0
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 38.0 if burst else 30.0
	p.initial_velocity_min = (1.6 if burst else 0.9) * sqrt(size)
	p.initial_velocity_max = (2.8 if burst else 1.5) * sqrt(size)
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = (0.32 if burst else 0.12) * size
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	add_child(p)
	return p

func _bubble_emitter() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.09 * size
	q.material = _mat("bubble", Color(0.95, 1.0, 1.0, 0.95), true)
	p.mesh = q
	p.amount = 24
	p.lifetime = 1.6
	p.explosiveness = 0.35
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, 0.9, 0)
	p.damping_min = 0.2
	p.damping_max = 0.5
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.06 * size
	if _hq:
		q.size = Vector2.ONE * 0.05 * size
		q.material = _mat("bubble", Color(0.95, 1.0, 1.0, 0.75), true)
		p.amount = 6
		p.one_shot = true
		p.explosiveness = 0.85
		p.spread = 10.0
		p.scale_amount_min = 0.35
		p.scale_amount_max = 1.2
		p.emission_sphere_radius = 0.025 * size
		p.tangential_accel_min = -0.6
		p.tangential_accel_max = 0.6
	add_child(p)
	return p

func ring(at: Vector3, r0: float, grow: float, life: float, alpha := 0.7) -> void:
	var i := _next
	_next = (_next + 1) % _n
	_age[i] = 0.0
	_life[i] = life
	_pos[i] = Vector3(at.x, water_y + 0.012, at.z)
	_r0[i] = r0
	_grow[i] = grow
	_a0[i] = alpha

func splash(strength := 1.0) -> void:
	if target == null:
		return
	var at := target.global_position
	_burst.global_position = Vector3(at.x, water_y + 0.05, at.z)
	_burst.amount = int(clampf(28 * strength, 8, 40))
	_burst.restart()
	ring(at, 0.30 * size, 1.3 * size * strength, 1.3, 0.9)
	ring(at, 0.15 * size, 0.8 * size * strength, 1.0, 0.7)

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	var at := target.global_position
	if _last != Vector3.INF and delta > 0.0:
		var v := Vector2(at.x - _last.x, at.z - _last.z).length() / delta
		_speed = lerpf(_speed, v, clampf(delta * 6.0, 0.0, 1.0))
	_last = at
	var moving := _speed > 0.15

	_t_ring -= delta
	if mode == SURFACE and _t_ring <= 0.0:
		if moving:
			if _hq:
				_t_ring = 0.2
			else:
				ring(at, 0.22 * size, 0.45 * size, 1.3, 0.6)
				_t_ring = 0.2
		else:
			ring(at, 0.30 * size, 0.35 * size, 1.8, 0.55)
			_t_ring = 1.1
	_foam.visible = mode == SURFACE
	if _foam.visible:
		var s := 0.52 * pow(size, 0.7) * (1.0 + 0.04 * sin(Time.get_ticks_msec() * 0.004))
		_foam.global_transform = Transform3D(Basis(Vector3.UP, Time.get_ticks_msec() * 0.0004).scaled(Vector3(s, 1, s)),
			Vector3(at.x, water_y + 0.01 + Swell.lift(at.x, at.z), at.z))
	_shade.visible = mode == UNDER and not _hq
	if _shade.visible:
		var b := target.global_transform.basis
		var yaw := atan2(b.z.x, b.z.z)
		var sw := 1.0 + 0.05 * sin(Time.get_ticks_msec() * 0.005)
		_shade.global_transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(0.32 * size * sw, 1, 0.62 * size)),
			Vector3(at.x, water_y + 0.012, at.z) + b.z.normalized() * 0.1 * size)

	if _hq and mode == SURFACE and moving:
		_t_stroke -= delta
		if _t_stroke <= 0.0:
			var b := target.global_transform.basis
			var p := Vector3(at.x, water_y + 0.03, at.z) + b.x.normalized() * 0.26 * size * _side + b.z.normalized() * 0.22 * size
			var e: CPUParticles3D = _stroke[0 if _side > 0.0 else 1]
			e.global_position = p
			e.restart()
			ring(p, 0.05 * size, randf_range(0.3, 0.5) * size, randf_range(0.6, 0.9), 0.45)
			_side = -_side
			_t_stroke = randf_range(0.36, 0.5)
			e.amount = randi_range(9, 16)
	if _hq:
		_wake_v(at, delta, mode == SURFACE and moving)

	_wake.emitting = mode == SURFACE and moving
	if _wake.emitting:
		var fwd := target.global_transform.basis.z.normalized()
		_wake.global_position = Vector3(at.x, water_y + 0.03, at.z) + fwd * 0.30 * size

	var from: Vector3 = bubble_from.call() if bubble_from.is_valid() else at + Vector3(0, 0.3 * size, 0)
	if _hq:
		var under := mode == UNDER and from.y < water_y - 0.05
		_t_breath -= delta
		if under and _t_breath <= 0.0:
			_t_breath = randf_range(1.5, 2.5)
			_bubbles.global_position = from + target.global_transform.basis.z.normalized() * 0.08 * size
			_bubbles.lifetime = clampf((water_y - from.y) / 0.9, 0.3, 2.5)
			_bubbles.amount = randi_range(3, 6)
			_bubbles.restart()
			_t_pop = _bubbles.lifetime * 0.85
		_t_pop -= delta
		if under and _t_pop <= 0.0 and _t_pop > -0.6:
			ring(Vector3(from.x, water_y, from.z), 0.04 * size, 0.3 * size, 0.9, 0.5)
			_t_pop = -1.0
	if not _hq:
		_bubbles.emitting = mode == UNDER and from.y < water_y - 0.05
	if not _hq and _bubbles.emitting:
		_bubbles.global_position = from
		_bubbles.lifetime = clampf((water_y - from.y) / 0.9, 0.3, 2.5)
		_t_pop -= delta
		if _t_pop <= 0.0:
			ring(Vector3(from.x, water_y, from.z), 0.04 * size, 0.30 * size, 0.9, 0.6)
			_t_pop = randf_range(0.35, 0.8)
	for i in _n:
		if _age[i] >= _life[i]:
			continue
		_age[i] += delta
		var k := clampf(_age[i] / _life[i], 0.0, 1.0)
		var r := _r0[i] + _grow[i] * _life[i] * (1.0 - pow(1.0 - k, 2.0)) * 0.5
		var pp := _pos[i]
		if _hq:
			pp.y = water_y + 0.012 + Swell.lift(pp.x, pp.z)
		var tr := Transform3D(Basis().scaled(Vector3(r, 1, r)), pp)
		if k >= 1.0:
			tr = Transform3D(Basis().scaled(Vector3.ZERO), _pos[i])
		_mm.set_instance_transform(i, tr)
		_mm.set_instance_color(i, Color(1, 1, 1, _a0[i] * pow(1.0 - k, 1.5)))

func _wake_v(at: Vector3, delta: float, on: bool) -> void:
	if on:
		_t_dab -= delta
		if _t_dab <= 0.0:
			_t_dab = 0.07
			var b := target.global_transform.basis
			var fwd := Vector3(b.z.x, 0, b.z.z).normalized()
			var right := Vector3(fwd.z, 0, -fwd.x)
			for sd in [-1.0, 1.0, 0.0]:
				var i := _dab_next
				_dab_next = (_dab_next + 1) % DABS
				var arm := (-fwd).rotated(Vector3.UP, deg_to_rad(32.0) * sd)
				_dab_age[i] = randf_range(0.0, 0.12)
				_dab_pos[i] = Vector3(at.x, water_y + (0.012 if sd != 0.0 else 0.008), at.z) 					+ right * (sd * 0.18 + randf_range(-0.05, 0.05)) * size - fwd * (0.12 if sd != 0.0 else 0.3) * size
				_dab_vel[i] = (right * sd * randf_range(0.5, 0.7) - fwd * 0.05) * size
				_dab_yaw[i] = atan2(arm.x, arm.z) + randf_range(-0.2, 0.2)
				_dab_w[i] = randf_range(0.8, 1.25) * (1.0 if sd != 0.0 else 1.6)

				_dab_col[i] = Color(1, 1, 1, randf_range(0.15, 0.8) if randf() < 0.75 else 0.05) if sd != 0.0 					else Color(0.1, 0.22, 0.2, 0.32)
	for i in DABS:
		if _dab_age[i] >= 1.6:
			continue
		_dab_age[i] += delta
		var k := clampf(_dab_age[i] / 1.6, 0.0, 1.0)
		_dab_pos[i] += _dab_vel[i] * delta * (1.0 - k * 0.6)

		var sc := Vector3((0.32 - 0.14 * k) * _dab_w[i] * size, 1, (0.45 + 0.3 * k) * size)
		var dp := _dab_pos[i]
		dp.y += Swell.lift(dp.x, dp.z)
		var tr := Transform3D(Basis(Vector3.UP, _dab_yaw[i]).scaled(sc), dp)
		if k >= 1.0:
			tr = Transform3D(Basis().scaled(Vector3.ZERO), _dab_pos[i])
		_dab_mm.set_instance_transform(i, tr)
		var c := _dab_col[i]
		_dab_mm.set_instance_color(i, Color(c.r, c.g, c.b, c.a * pow(1.0 - k, 1.3) * smoothstep(0.0, 0.08, k)))
