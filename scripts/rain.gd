class_name Rain
extends Node3D

const AREA := Vector3(22.0, 0.5, 22.0)
const HEIGHT := 7.0

const CANOPY_MID := Vector3(-0.53, -0.92, 0.782)
const CANOPY_TOP := Vector3(-0.53, -1.16, 0.782)

var follow: Node3D
var chibis: Callable
var sun: DirectionalLight3D
var drops: GPUParticles3D
var splash: GPUParticles3D
var _umbrellas := {}
var _sun_energy := 1.0
var on := false

func _ready() -> void:
	top_level = true
	splash = GPUParticles3D.new()
	splash.amount = 900
	splash.lifetime = 0.28
	splash.emitting = false
	var sm := ParticleProcessMaterial.new()
	sm.direction = Vector3.UP
	sm.spread = 70.0
	sm.initial_velocity_min = 0.6
	sm.initial_velocity_max = 1.3
	sm.gravity = Vector3(0, -6.0, 0)
	sm.scale_min = 0.6
	sm.scale_max = 1.0
	splash.process_material = sm
	splash.draw_pass_1 = _drop_mesh(Vector3(0.022, 0.022, 0.022), Color(0.85, 0.93, 1.0, 0.8))
	add_child(splash)
	drops = GPUParticles3D.new()
	drops.amount = 2200
	drops.lifetime = 1.0
	drops.preprocess = 1.0
	drops.visibility_aabb = AABB(-AREA / 2 - Vector3(0, HEIGHT + 2, 0), AREA + Vector3(0, HEIGHT + 4, 0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = AREA / 2
	pm.direction = Vector3(0.08, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 8.5
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, -4.0, 0)
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	pm.collision_use_scale = false
	pm.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	pm.sub_emitter_amount_at_collision = 2
	drops.process_material = pm
	drops.collision_base_size = 0.02
	drops.draw_pass_1 = _drop_mesh(Vector3(0.012, 0.34, 0.012), Color(0.78, 0.88, 1.0, 0.55))
	drops.emitting = false
	add_child(drops)
	drops.sub_emitter = drops.get_path_to(splash)

	var ground := GPUParticlesCollisionBox3D.new()
	ground.size = Vector3(60, 1, 60)
	ground.position = Vector3(0, -0.5, 0)
	ground.top_level = true
	add_child(ground)

func _drop_mesh(size: Vector3, c: Color) -> Mesh:
	var m := BoxMesh.new()
	m.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = c
	m.material = mat
	return m

func toggle() -> void:
	set_raining(not on)

func set_raining(v: bool) -> void:
	on = v
	drops.emitting = v
	if sun:
		if _sun_energy == 1.0 and v:
			_sun_energy = sun.light_energy
		var t := create_tween()
		t.tween_property(sun, "light_energy", _sun_energy * (0.5 if v else 1.0), 1.2)

func _process(_d: float) -> void:
	if follow:
		global_position = follow.global_position + Vector3(0, HEIGHT, 0)
	if not chibis.is_valid():
		return
	var seen := {}
	for c in chibis.call():
		var ch := c as Chibi
		if ch == null or not is_instance_valid(ch):
			continue
		var held := ch.tool == "umbrella" and ch.umb_fold < 0.35
		var box: GPUParticlesCollisionBox3D = _umbrellas.get(ch)
		if held and box == null:
			box = GPUParticlesCollisionBox3D.new()
			box.size = Vector3(1.2, 0.16, 1.2)
			box.top_level = true
			add_child(box)
			_umbrellas[ch] = box
		if box:
			if not held:
				box.global_position = Vector3(0, -100, 0)
			else:
				var mid := ch.posed_point("Item", CANOPY_MID)
				var up := (ch.posed_point("Item", CANOPY_TOP) - mid).normalized()
				var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
				box.global_transform = Transform3D(Basis(side, up, side.cross(up)), mid)
		seen[ch] = true
	for ch in _umbrellas.keys():
		if not seen.has(ch):
			_umbrellas[ch].queue_free()
			_umbrellas.erase(ch)
