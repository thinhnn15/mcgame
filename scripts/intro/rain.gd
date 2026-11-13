extends RefCounted

const CityKit := preload("res://scripts/intro/city_kit.gd")

const WIND := Vector3(3.0, -14.5, 1.05)

var kit: CityKit
var near: GPUParticles3D
var mid: GPUParticles3D
var far: GPUParticles3D
var splash: GPUParticles3D
var hits: GPUParticles3D
var drips: GPUParticles3D
var mist: GPUParticles3D
var veils: Array[MeshInstance3D] = []
var mats: Array[ShaderMaterial] = []
var street_y := 0.0

func build(k: CityKit, parent: Node3D, ground_y: float) -> void:
	kit = k
	street_y = ground_y
	near = _streaks(parent, 2400, Vector3(6.0, 5.0, 6.0), 0.004, 0.5, 0.3, 0.8)
	mid = _streaks(parent, 9000, Vector3(24.0, 14.0, 24.0), 0.009, 0.75, 0.3, 1.2)
	far = _streaks(parent, 14000, Vector3(70.0, 35.0, 70.0), 0.02, 1.3, 0.16, 6.0)
	splash = _splashes(parent)
	hits = _hits(parent)
	drips = _drips(parent)
	mist = _mist(parent)
	for r in [42.0, 80.0]:
		veils.append(_veil(parent, r))

func _streaks(parent: Node3D, n: int, ext: Vector3, width: float, length: float, alpha: float, near_fade: float) -> GPUParticles3D:
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
	q.size = Vector2(1, 1)
	var m := _streak_mat(width, length, alpha, near_fade, maxf(ext.x, ext.z) * 1.4)
	q.material = m
	p.draw_pass_1 = q
	p.amount = n
	p.lifetime = ext.y * 2.0 / WIND.length()
	p.preprocess = p.lifetime
	p.local_coords = false
	p.fixed_fps = 0
	p.visibility_aabb = AABB(-ext - Vector3(10, 20, 10), (ext + Vector3(10, 20, 10)) * 2.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

func _streak_mat(width: float, length: float, alpha: float, near_fade: float, far_fade: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/rain_streak.gdshader")
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("length", length)
	m.set_shader_parameter("alpha", alpha)
	m.set_shader_parameter("near_fade", near_fade)
	m.set_shader_parameter("far_fade", far_fade)
	kit.register(m)
	mats.append(m)
	return m

func _splash_mat(size: Vector2, alpha: float, far_fade: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/rain_splash.gdshader")
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("alpha", alpha)
	m.set_shader_parameter("far_fade", far_fade)
	kit.register(m)
	mats.append(m)
	return m

func _splashes(parent: Node3D) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14.0, 0.0, 14.0)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _splash_mat(Vector2(0.15, 0.1), 0.3, 15.0)
	p.draw_pass_1 = q
	p.amount = 1500
	p.lifetime = 0.34
	p.preprocess = 0.34
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-20, -1, -20), Vector3(40, 3, 40))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

func _points(pm: ParticleProcessMaterial, pts: PackedVector3Array) -> void:
	var w := 256
	var h := maxi(1, ceili(float(pts.size()) / w))
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBF)
	for i in pts.size():
		img.set_pixel(i % w, i / w, Color(pts[i].x, pts[i].y, pts[i].z))
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	pm.emission_point_texture = ImageTexture.create_from_image(img)
	pm.emission_point_count = pts.size()

func _bounds(pts: PackedVector3Array, pad: float) -> AABB:
	var b := AABB(pts[0], Vector3.ZERO)
	for v in pts:
		b = b.expand(v)
	return b.grow(pad)

func _hits(parent: Node3D) -> GPUParticles3D:
	if kit.hit_pts.is_empty():
		return null
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	_points(pm, kit.hit_pts)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _splash_mat(Vector2(0.1, 0.075), 0.26, 20.0)
	p.draw_pass_1 = q
	p.amount = mini(2400, kit.hit_pts.size() * 2)
	p.lifetime = 0.3
	p.preprocess = 0.3
	p.local_coords = false
	p.visibility_aabb = _bounds(kit.hit_pts, 1.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

func _drips(parent: Node3D) -> GPUParticles3D:
	if kit.drip_pts.is_empty():
		return null
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	_points(pm, kit.drip_pts)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(WIND.x * 0.05, -9.8, WIND.z * 0.05)
	pm.particle_flag_align_y = true
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := _streak_mat(0.012, 0.22, 0.55, 0.8, 40.0)
	m.set_shader_parameter("gust_lean", 0.0)
	q.material = m
	p.draw_pass_1 = q
	p.amount = mini(1400, kit.drip_pts.size())
	p.lifetime = 0.85
	p.preprocess = 0.85
	p.randomness = 0.6
	p.local_coords = false
	p.visibility_aabb = _bounds(kit.drip_pts, 5.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

func _mist(parent: Node3D) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28.0, 0.15, 28.0)
	pm.direction = Vector3(WIND.x, 0.0, WIND.z).normalized()
	pm.spread = 15.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.7
	pm.scale_max = 1.5
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/rain_mist.gdshader")
	kit.register(m)
	mats.append(m)
	q.material = m
	p.draw_pass_1 = q
	p.amount = 90
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -1, -40), Vector3(80, 6, 80))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

func _veil(parent: Node3D, r: float) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 110.0
	c.cap_top = false
	c.cap_bottom = false
	c.radial_segments = 48
	c.rings = 1
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/rain_veil.gdshader")
	m.set_shader_parameter("circumference", TAU * r)
	m.set_shader_parameter("y_fade_lo", street_y - 1.0)
	m.set_shader_parameter("alpha", 0.5 if r < 60.0 else 0.4)
	m.set_shader_parameter("haze_alpha", 0.1 if r < 60.0 else 0.16)
	kit.register(m)
	mats.append(m)
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, street_y + 54.0, 0)
	parent.add_child(mi)
	return mi

func follow(cam: Vector3, inside: bool, wall_z: float) -> void:
	if inside:
		near.emitting = false
		mid.position = Vector3(cam.x, cam.y, wall_z - 26.0)
		far.position = Vector3(cam.x, cam.y - 10.0, wall_z - 60.0)
	else:
		near.emitting = true
		near.position = cam + Vector3(-1.0, 3.5, 0.0)
		mid.position = cam + Vector3(-4.0, 6.0, 0.0)

		far.position = Vector3(cam.x * 0.5, maxf(cam.y, street_y + 25.0), minf(cam.z, wall_z) - 30.0)
	for v in veils:
		v.position = Vector3(cam.x, street_y + 54.0, cam.z)

	var low := cam.y < street_y + 12.0 and not inside
	splash.emitting = low
	splash.position = Vector3(cam.x - 6.0, street_y + 0.02, cam.z)
	mist.emitting = cam.y < street_y + 20.0 and not inside
	mist.position = Vector3(cam.x - 10.0, street_y + 0.05, cam.z)
	if hits:
		hits.emitting = cam.y < street_y + 16.0 and not inside
	if drips:
		drips.emitting = not inside

func set_flash(e: float) -> void:
	for m in mats:
		m.set_shader_parameter("flash", e)
