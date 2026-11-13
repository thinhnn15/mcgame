class_name FarmRain
extends Node3D

const WIND := Vector3(1.8, -12.5, 0.8)
const DAY_AMBIENT := Color(0.78, 0.81, 0.88)

var layers: Array[GPUParticles3D] = []
var splash: GPUParticles3D
var mist: GPUParticles3D
var veil: MeshInstance3D
var on := false
var storm := false
var cam: Camera3D
var env: Environment
var flash_light: DirectionalLight3D
var bolt: Node3D
var _flash_mats: Array[ShaderMaterial] = []
var _next := 4.0
var _first := true
var _flash_t := -1.0
var _flash_k := 0.0
var _claps := []

signal thunder(near: bool)

func build(env_: Environment = null) -> void:
	env = env_
	layers.append(_streaks(1400, Vector3(6.0, 5.0, 6.0), 0.005, 0.55, 0.32, 0.8))
	layers.append(_streaks(5000, Vector3(22.0, 12.0, 22.0), 0.010, 0.8, 0.30, 1.2))
	layers.append(_streaks(6000, Vector3(60.0, 30.0, 60.0), 0.022, 1.4, 0.15, 6.0))
	splash = _splashes()
	mist = _mist()
	veil = _veil(58.0)
	_lightning_rig()
	set_on(false)

func set_on(v: bool) -> void:
	on = v
	for p in layers + [splash, mist]:
		p.emitting = v
		p.visible = v
	veil.visible = v

func follow(cam: Vector3, ground_y := 0.0) -> void:
	for p in layers:
		p.global_position = Vector3(cam.x, cam.y + 2.0, cam.z)
	splash.global_position = Vector3(cam.x, ground_y + 0.01, cam.z - 4.0)
	mist.global_position = Vector3(cam.x, ground_y + 0.1, cam.z - 4.0)
	veil.global_position = Vector3(cam.x, ground_y + 50.0, cam.z)

func _mat(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("ambient", DAY_AMBIENT)
	for u in shader.get_shader_uniform_list():
		if u.name == "flash":
			_flash_mats.append(m)
	return m

func _lightning_rig() -> void:
	flash_light = DirectionalLight3D.new()
	flash_light.light_color = Color("dfe6ff")
	flash_light.light_energy = 0.0
	flash_light.shadow_enabled = false
	add_child(flash_light)
	flash_light.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(20.0), 0.0)

	bolt = Node3D.new()
	add_child(bolt)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.7, 1.75, 2.1)
	m.disable_fog = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var trunk := _jag(m, rng, Vector3.ZERO, 62.0, 1.3)
	for k in [3, 6, 9]:
		if k < trunk.size():
			_jag(m, rng, trunk[k], 16.0, 0.6)
	bolt.visible = false

func _jag(m: Material, rng: RandomNumberGenerator, from: Vector3, drop: float, w: float) -> Array:
	var pts := [from]
	var p := from
	while p.y > from.y - drop:
		var q := p + Vector3(rng.randf_range(-4.5, 4.5), -rng.randf_range(4.5, 8.0), rng.randf_range(-1.0, 1.0))
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, w, (q - p).length())
		seg.mesh = bm
		seg.material_override = m
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bolt.add_child(seg)
		seg.look_at_from_position((p + q) / 2.0, q, Vector3.FORWARD)
		p = q
		pts.append(p)
		w = maxf(0.35, w * 0.9)
	return pts

func strike(near: bool) -> void:
	_flash_t = 0.0
	_flash_k = 1.0 if near else 0.45
	bolt.visible = false

	flash_light.shadow_enabled = near
	if near and cam:
		var b := cam.global_transform.basis
		var fwd := -b.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var at := cam.global_position + fwd * randf_range(85.0, 120.0) + b.x * randf_range(-45.0, 45.0)
		bolt.global_position = Vector3(at.x, 66.0, at.z)
		bolt.rotation.y = randf() * TAU
	_claps.append([randf_range(0.6, 1.5) if near else randf_range(2.5, 5.0), near])

func _process(delta: float) -> void:
	if on and storm:
		_next -= delta
		if _next <= 0.0:
			strike(_first or randf() < 0.4)
			_first = false
			_next = randf_range(14.0, 40.0)
	for c in _claps:
		c[0] -= delta
	while not _claps.is_empty() and _claps[0][0] <= 0.0:
		var near: bool = _claps.pop_front()[1]
		Sound.play("weather.thunder_near" if near else "weather.thunder_far")
		thunder.emit(near)
	if _flash_t < 0.0:
		return
	_flash_t += delta

	var e := 0.0
	if _flash_t < 0.06:
		e = _flash_t / 0.06
	elif _flash_t < 0.12:
		e = 0.35
	elif _flash_t < 0.18:
		e = 1.0
	else:
		e = maxf(0.0, 1.0 - (_flash_t - 0.18) / 0.5)
	e *= _flash_k
	flash_light.light_energy = 1.6 * e
	bolt.visible = _flash_k > 0.9 and _flash_t < 0.26
	for m in _flash_mats:
		m.set_shader_parameter("flash", e)
	if env:
		env.ambient_light_energy += 0.5 * e
		env.background_energy_multiplier += 0.6 * e
	if _flash_t > 0.7:
		_flash_t = -1.0
		flash_light.light_energy = 0.0
		flash_light.shadow_enabled = false
		for m in _flash_mats:
			m.set_shader_parameter("flash", 0.0)

func _streaks(n: int, ext: Vector3, width: float, length: float, alpha: float, near_fade: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = ext
	pm.direction = WIND.normalized()
	pm.spread = 3.0
	pm.initial_velocity_min = WIND.length() * 0.9
	pm.initial_velocity_max = WIND.length() * 1.15
	pm.gravity = Vector3.ZERO
	pm.particle_flag_align_y = true
	p.process_material = pm
	var q := QuadMesh.new()
	var m := _mat(preload("res://shaders/rain_streak.gdshader"))
	m.set_shader_parameter("tint", Color(0.86, 0.89, 0.94))
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("length", length)
	m.set_shader_parameter("alpha", alpha)
	m.set_shader_parameter("near_fade", near_fade)
	m.set_shader_parameter("far_fade", maxf(ext.x, ext.z) * 1.4)
	q.material = m
	p.draw_pass_1 = q
	p.amount = n
	p.lifetime = ext.y * 2.0 / WIND.length()
	p.preprocess = p.lifetime
	p.local_coords = false
	p.visibility_aabb = AABB(-ext - Vector3(10, 20, 10), (ext + Vector3(10, 20, 10)) * 2.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _splashes() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(11.0, 0.0, 9.0)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	p.process_material = pm
	var q := QuadMesh.new()
	var m := _mat(preload("res://shaders/rain_splash.gdshader"))
	m.set_shader_parameter("tint", Color(0.88, 0.92, 0.96))
	m.set_shader_parameter("size", Vector2(0.16, 0.11))
	m.set_shader_parameter("alpha", 0.45)
	m.set_shader_parameter("far_fade", 16.0)
	q.material = m
	p.draw_pass_1 = q
	p.amount = 900
	p.lifetime = 0.34
	p.preprocess = 0.34
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-16, -2, -14), Vector3(32, 5, 28))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _mist() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24.0, 0.15, 20.0)
	pm.direction = Vector3(WIND.x, 0.0, WIND.z).normalized()
	pm.spread = 15.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.7
	pm.scale_max = 1.5
	p.process_material = pm
	var q := QuadMesh.new()
	var m := _mat(preload("res://shaders/rain_mist.gdshader"))
	m.set_shader_parameter("tint", Color(0.80, 0.83, 0.87))
	m.set_shader_parameter("alpha", 0.12)
	q.material = m
	p.draw_pass_1 = q
	p.amount = 60
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-36, -2, -32), Vector3(72, 8, 64))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _veil(r: float) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 110.0
	c.cap_top = false
	c.cap_bottom = false
	c.radial_segments = 40
	c.rings = 1
	var m := _mat(preload("res://shaders/rain_veil.gdshader"))
	m.set_shader_parameter("tint", Color(0.84, 0.87, 0.92))
	m.set_shader_parameter("haze", Color(0.66, 0.70, 0.74))
	m.set_shader_parameter("circumference", TAU * r)
	m.set_shader_parameter("y_fade_lo", -2.0)
	m.set_shader_parameter("alpha", 0.45)
	m.set_shader_parameter("haze_alpha", 0.22)
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
