class_name DogScene
extends FarmCutscene

const DOOR := Vector3(5.15, 0, -2.0)
const HEN_AT := Vector3(5.02, 0, -2.35)
const HERO_AT := Vector3(3.95, 0, -3.05)
const LANTERN_POLE := Vector3(4.9, 0, -1.3)
const LOST := Vector3(3.35, 0, 5.35)
const TRAIL := [Vector3(4.15, 0, -1.25), Vector3(3.6, 0, 0.4), Vector3(3.8, 0, 2.2), Vector3(3.6, 0, 4.0), LOST]
const N := 8
const SLOW := 0.5
const HEAD_Y := 0.57

var hen: FarmAnimal
var dog: FarmAnimal
var hero: Player
var chicks: Array[FarmAnimal] = []
var lost: FarmAnimal
var _count: Label3D
var _carry := false
var _dskel: Skeleton3D
var _tool := ""
var _pace := 1.0
var _sc: FarmScenery
var _walk_tw: Tween = null

func play(p: Node3D) -> void:
	drives_hens = true
	own_light = true
	_begin(p)
	_dusk()
	hero = p.player
	hero.visible = true
	_tool = hero.chibi.tool
	_pace = hero.pace
	_sc = p.scenery
	_cast()

	_fix(Vector3(2.2, 1.25, 1.6), Vector3(2.45, 1.1, 1.2), Vector3(4.9, 0.45, -1.8), Vector3(4.95, 0.4, -1.9), 3.0, 44.0)
	for i in N - 1:
		_file_in(chicks[i], 1.2 + 0.95 * i)
	await _until(3.0)

	_fix(Vector3(3.75, 0.5, -1.05), Vector3(3.8, 0.49, -1.12), DOOR + Vector3(-0.1, 0.32, -0.1), DOOR + Vector3(-0.1, 0.34, -0.1), 5.8, 40.0)
	await _until(8.8)
	_hero("Emo_Think")
	hen.rotation.y = atan2(3.4 - HEN_AT.x, -0.6 - HEN_AT.z)
	_fix(HEN_AT + Vector3(-0.8, 0.3, 0.02), HEN_AT + Vector3(-0.74, 0.3, 0.02), HEN_AT + Vector3(0, 0.26, 0),
		HEN_AT + Vector3(0, 0.26, 0), 2.2, 38.0)
	await _until(9.4)
	hen.play("Idle")
	Sound.play_at("animal.hen_alarm", hen.global_position, -2.0, 0.95)
	await _until(11.0)
	_count.visible = false
	hero.rotation.y = atan2(-0.8, 1.0)
	hero.facing = hero.rotation.y
	_fix(HERO_AT + Vector3(-1.7, 1.3, 2.2), HERO_AT + Vector3(-1.6, 1.25, 2.05), HERO_AT + Vector3(0, 1.0, 0),
		HERO_AT + Vector3(0, 1.0, 0), 2.0, 48.0)
	_hero("Emo_Nervous")

	await _until(13.0)
	dog.play("Run", 0.1)
	dog.anim.speed_scale = 0.55
	var sit := HERO_AT + Vector3(-0.35, 0, 0.8)
	_move(dog, [dog.position, sit], 1.1, true, Tween.TRANS_SINE, Tween.EASE_OUT).finished.connect(_dog_sits)
	_fix(HERO_AT + Vector3(-2.6, 1.0, 0.55), HERO_AT + Vector3(-2.45, 0.98, 0.55), HERO_AT + Vector3(-0.2, 0.72, 0.4),
		HERO_AT + Vector3(-0.2, 0.72, 0.4), 3.0, 46.0)
	await _until(15.2)
	hero.rotation.y = atan2(TRAIL[1].x - hero.position.x, TRAIL[1].z - hero.position.z)
	hero.facing = hero.rotation.y
	_hero("Act_Point")

	await _until(16.0)
	var t0: Vector3 = _on_ground(TRAIL[0])
	var along: Vector3 = (_on_ground(TRAIL[1]) - t0).normalized()
	dog.position = t0 - along * 0.35
	dog.rotation.y = atan2(along.x, along.z)
	dog.anim.speed_scale = 1.0
	dog.play("Sniff", 0.2)
	Sound.play_at("animal.dog_sniff", dog.global_position)
	var side := Vector3(-along.z, 0, along.x)
	if side.x > 0.0:
		side = -side

	_fix(t0 + along * 2.3 + side * 0.3 + Vector3(0, 0.28, 0), t0 + along * 2.2 + side * 0.28 + Vector3(0, 0.26, 0),
		t0 + along * 0.2 + Vector3(0, 0.14, 0), t0 + along * 0.8 + Vector3(0, 0.14, 0), 2.5, 36.0)
	await _until(16.7)
	dog.anim.speed_scale = 2.0
	dog.play("Track", 0.25)
	var way: Array = [dog.position] + TRAIL.slice(1, 4)
	way.append(LOST + Vector3(0.25, 0, -0.75))
	for i in way.size():
		way[i] = _on_ground(way[i])
	_move(dog, way, 8.3, true, Tween.TRANS_LINEAR).finished.connect(_dog_stops)
	hero.pace = 0.5
	hero.go_to(Vector3(3.15, 0, 1.6))
	await _until(17.8)
	Sound.play_at("animal.dog_sniff", dog.global_position, -2.0, 1.05)
	await _until(18.5)
	_fix(Vector3(1.2, 2.4, 4.4), Vector3(1.35, 2.2, 4.6), Vector3(3.5, 0.2, 0.6), Vector3(3.5, 0.2, 2.4), 6.5, 44.0)
	await _until(22.5)
	Sound.play_at("animal.dog_sniff", dog.global_position, -4.0)

	await _until(25.0)
	var lp := lost.global_position
	lost.rotation.y = atan2(0.26, -0.3)
	_fix(lp + Vector3(0.26, 0.24, -0.3), lp + Vector3(0.23, 0.23, -0.27), lp + Vector3(0, 0.1, 0), lp + Vector3(0, 0.11, 0), 3.5, 34.0)
	await _until(25.6)
	Sound.play_at("animal.chick_peeps", lp, -14.0, 0.82)
	await _until(27.3)
	Sound.play_at("animal.chick_peeps", lp, -16.0, 0.78)

	await _until(28.5)
	dog.play("Listen", 0.15)
	var dh := dog.position + Vector3(0, HEAD_Y + 0.08, 0)
	var fwd := Vector3(sin(dog.rotation.y), 0, cos(dog.rotation.y))
	var sd := Vector3(fwd.z, 0, -fwd.x)
	if sd.x > 0.0:
		sd = -sd
	_fix(dh + sd * 1.4 + fwd * 0.45 + Vector3(0, -0.04, 0), dh + sd * 1.3 + fwd * 0.42 + Vector3(0, -0.04, 0), dh, dh, 1.1, 36.0)

	await _until(29.6)
	dog.play("Sniff", 0.25)
	var nose_to := _on_ground(LOST + Vector3(0.08, 0, -0.5))
	dog.rotation.y = atan2(LOST.x - nose_to.x, LOST.z - nose_to.z)
	_move(dog, [dog.position, nose_to], 1.0, false)
	lost.rotation.y = atan2(nose_to.x - lp.x, nose_to.z - lp.z)
	var mid := lp + (nose_to - lp) * 0.45 + Vector3(0, 0.25, 0)
	_fix(mid + Vector3(-1.35, 0.04, 0.14), mid + Vector3(-1.22, 0.04, 0.12), mid, mid, 4.0, 36.0)
	await _until(31.2)
	lost.play("Idle", 0.3)
	await _until(31.9)
	Sound.play_at("animal.dog_huff", dog.global_position)
	await _until(32.7)
	Sound.play_at("animal.chick_peeps", lp, -10.0, 1.0)

	await _until(33.6)
	_carry = true
	dog.play("Carry", 0.25)
	hero.stop_going()
	hero.position = Vector3(1.5, 0, 0.1)
	var home := _on_ground(Vector3(4.05, 0, 2.2))
	var dirh := (home - dog.position).normalized()
	dog.rotation.y = atan2(dirh.x, dirh.z)
	_walk_tw = _move(dog, [dog.position, home], 5.6, true, Tween.TRANS_LINEAR)
	_slow(SLOW)
	var front := dog.position + dirh * 3.0 + Vector3(0, 0.42, 0)
	_follow(front, front + Vector3(0, 0.02, 0), dog, Vector3(0, 0.4, 0), 3.0, 34.0, 34.0)
	await _until(36.6)
	_slow(1.0)
	var lamp := LANTERN_POLE + Vector3(0.27, 1.2, 0)
	var back := dog.position - dirh * 1.5 + Vector3(0.25, 0.78, 0)
	_follow(back, back + dirh * 1.2, dog, Vector3(0, 0.3, 0), 2.4, 40.0, 40.0, 0.62, lamp)
	await _until(39.0)

	var at := HEN_AT + Vector3(-0.85, 0, 0.6)
	if _walk_tw:
		_walk_tw.kill()
	dog.position = at
	dog.rotation.y = atan2(HEN_AT.x - at.x, HEN_AT.z - at.z)
	dog.play("Put_Down", 0.15)
	hen.rotation.y = atan2(at.x - HEN_AT.x, at.z - HEN_AT.z)
	hero.stop_going()
	hero.position = HERO_AT
	hero.rotation.y = atan2(at.x - HERO_AT.x, at.z - HERO_AT.z)
	hero.facing = hero.rotation.y
	_fix(at + Vector3(-0.6, 0.62, 2.6), at + Vector3(-0.55, 0.6, 2.45), at + Vector3(0.35, 0.36, -0.45), at + Vector3(0.35, 0.36, -0.45), 5.0, 46.0)
	await _until(39.8)
	_carry = false
	var down := dog.position + Vector3(sin(dog.rotation.y), 0, cos(dog.rotation.y)) * 0.35
	lost.position = _on_ground(down)
	lost.play("Run", 0.1)
	lost.anim.speed_scale = 1.2
	_move(lost, [lost.position, HEN_AT + Vector3(-0.06, 0, 0.12)], 1.2, true, Tween.TRANS_LINEAR).finished.connect(_tucked)
	await _until(41.2)
	hen.play("Sit_Start", 0.25)
	await _until(41.6)
	_count.visible = true
	_pop("8!", Color("6fd36a"))
	Sound.play_at("animal.duckling_peep", DOOR, 0.0, 1.2)
	await _until(42.0)
	_hero("Emo_Happy")
	Sound.play_at("animal.hen_alarm", hen.global_position, -9.0, 1.1)

	await _until(44.0)
	_count.visible = false
	dog.rotation.y = atan2(-0.4, -1.0)
	dog.play("Wag", 0.2)
	hero.position = at + Vector3(-0.25, 0, -0.62)
	hero.rotation.y = atan2(at.x - hero.position.x, at.z - hero.position.z)
	hero.facing = hero.rotation.y
	_fix(at + Vector3(-2.4, 1.2, 1.4), at + Vector3(-2.25, 1.15, 1.3), at + Vector3(-0.1, 0.55, -0.3),
		at + Vector3(-0.1, 0.55, -0.3), 5.0, 45.0)
	_hero("Emo_Love")
	await _until(45.8)
	dog.play("Shake_Dry", 0.1)
	Sound.play_at("animal.dog_shake", dog.global_position)
	_spray(dog.global_position + Vector3(0, 0.38, 0))
	await _until(46.1)
	_hero("Emo_Shocked")
	await _until(47.3)
	_hero("Emo_Laugh")

	await _until(49.0)
	dog.position = HEN_AT + Vector3(-0.95, 0, 0.8)
	dog.rotation.y = atan2(DOOR.x - dog.position.x, DOOR.z - dog.position.z) - 0.6
	dog.play("Lie", 0.3)
	hero.position = HERO_AT
	hero.rotation.y = atan2(dog.position.x - HERO_AT.x, dog.position.z - HERO_AT.z)
	hero.facing = hero.rotation.y
	_fix(Vector3(2.9, 0.6, 0.35), Vector3(2.5, 0.95, 0.9), Vector3(4.5, 0.55, -1.6), Vector3(4.6, 0.65, -1.7), 5.0, 42.0)
	await _until(53.5)
	_letterbox(false)
	await _until(54.0)
	hero.pace = _pace
	hero.chibi.hold(_tool)
	_count.queue_free()
	_end()

func _dusk() -> void:
	var sun: DirectionalLight3D = plot.sun
	sun.rotation = Vector3(deg_to_rad(-14.0), deg_to_rad(-60.0), 0.0)
	sun.light_energy = 0.12
	sun.light_color = Color(0.58, 0.64, 0.84)
	var env: Environment = plot.env
	if env:
		env.ambient_light_energy = 0.3
		env.background_energy_multiplier = 0.24
		env.fog_density = 0.014
		env.fog_light_color = Color(0.3, 0.34, 0.44)

func _cast() -> void:
	var kind := "ga_con"
	var hs: Array = plot.hens
	hen = hs[0].a
	hen.visible = true
	hen.position = HEN_AT
	hen.rotation.y = -PI / 2 + 0.25
	hen.play("Idle")
	for i in range(1, hs.size()):
		(hs[i].a as FarmAnimal).visible = false
	for i in N:
		var at := Vector3(3.55 - 0.32 * (i % 4), 0, -1.1 + 0.42 * (i / 4) + 0.12 * (i % 2))
		var c := FarmAnimal.spawn(plot, kind, at, PI / 2 - 0.4)
		c.play("Idle")
		chicks.append(c)
	lost = chicks[N - 1]
	lost.position = _on_ground(LOST)
	lost.rotation.y = -0.6
	lost.play("Shiver")
	Crops.draw(plot, [{"model": "khoai_mon_4", "pos": _on_ground(LOST + Vector3(0.05, 0, 0.1)), "yaw": 0.7},
		{"model": "khoai_mon_3", "pos": _on_ground(LOST + Vector3(0.55, 0, 0.35)), "yaw": 2.1}])
	dog = FarmAnimal.spawn(plot, "cho_vang", Vector3(1.9, 0, -0.6), PI / 2)
	dog.play("Lie_Keep")
	_dskel = dog.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	hero.stop_going()
	hero.position = HERO_AT
	hero.rotation.y = atan2(DOOR.x - HERO_AT.x, DOOR.z - HERO_AT.z)
	hero.facing = hero.rotation.y
	hero.chibi.open_umbrella()
	_lantern()
	_footprints()
	_count = Label3D.new()
	_count.font_size = 96
	_count.pixel_size = 0.0028
	_count.outline_size = 22
	_count.modulate = Color("fff3d6")
	_count.outline_modulate = Color("5b4636")
	_count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_count.no_depth_test = true
	_count.position = DOOR + Vector3(-0.08, 0.62, 0.0)
	_count.text = ""
	plot.add_child(_count)

func _lantern() -> void:
	var pole := Props.at(plot, LANTERN_POLE, 0.0)
	Props._part(pole, pole, Props._cyl(0.025, 0.03, 1.45), Color("c2a46a"), Vector3(0, 0.725, 0))
	Props._part(pole, pole, Props._box(Vector3(0.32, 0.03, 0.03)), Color("b39257"), Vector3(0.14, 1.42, 0))
	Furniture.place(plot, "den_bao", LANTERN_POLE + Vector3(0.27, 1.4, 0), 0.0, false)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.4)
	l.light_energy = 2.0
	l.omni_range = 2.8
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(0.75, 0.75)
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.disable_fog = true
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	gr.colors = PackedColorArray([Color(1.0, 0.8, 0.45), Color(0.55, 0.36, 0.16), Color(0, 0, 0)])
	g.gradient = gr
	hm.albedo_texture = g
	hq.material = hm
	halo.mesh = hq
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plot.add_child(halo)
	halo.global_position = LANTERN_POLE + Vector3(0.27, 1.2, 0)
	l.shadow_enabled = false
	plot.add_child(l)
	l.global_position = LANTERN_POLE + Vector3(0.27, 1.25, 0)

func _footprints() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(0.075, 0.075)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = load("res://props/farm/fx/foot_chick.png")
	m.roughness = 0.12
	m.albedo_color = Color(0.7, 0.62, 0.58)
	q.material = m
	var xs: Array[Transform3D] = []
	var pts: Array = TRAIL.duplicate()
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d := b - a
		var steps := int(d.length() / 0.1)
		var yaw := atan2(d.x, d.z) + PI
		for k in steps:
			var side := Vector3(d.z, 0, -d.x).normalized() * (0.018 if k % 2 else -0.018)
			var at := _on_ground(a + d * (float(k) / steps) + side) + Vector3(0, 0.006, 0)
			xs.append(Transform3D(Basis(Vector3.UP, yaw + randf_range(-0.2, 0.2)), at))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plot.add_child(mmi)

func _on_ground(v: Vector3) -> Vector3:
	return Vector3(v.x, _sc.walk_at(v.x, v.z), v.z)

func _file_in(c: FarmAnimal, t: float) -> void:
	await _until(t)
	c.play("Walk", 0.15)
	c.anim.speed_scale = 1.6
	await _move(c, [c.position, DOOR + Vector3(-0.35, 0, 0.18), DOOR], 1.2, true, Tween.TRANS_LINEAR).finished
	c.visible = false
	var n := chicks.find(c) + 1
	_pop(str(n), Color("fff3d6"))
	Sound.play_at("animal.duckling_peep", DOOR, -10.0, 1.15 + 0.02 * n)

func _pop(text: String, col: Color) -> void:
	_count.text = text
	_count.modulate = col
	_count.scale = Vector3.ONE * 0.4
	var tw := create_tween()
	tw.tween_property(_count, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_count, "scale", Vector3.ONE, 0.12)

func _dog_sits() -> void:
	dog.anim.speed_scale = 1.0
	dog.rotation.y = atan2(HERO_AT.x - dog.position.x, HERO_AT.z - dog.position.z)
	dog.play("Sit", 0.2)
	await _until(_t + 0.8)
	dog.play("Wag", 0.2)

func _dog_stops() -> void:
	dog.anim.speed_scale = 1.0
	dog.play("Idle", 0.2)

func _tucked() -> void:
	lost.anim.speed_scale = 1.0
	lost.rotation.y = hen.rotation.y
	lost.play("Hide", 0.2)

func _hero(clip: String) -> void:
	var an := hero.chibi.anim
	if an == null or not an.has_animation(clip):
		return
	an.play(clip, 0.2)
	an.queue("Base_Wait")

func _spray(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	var s := SphereMesh.new()
	s.radius = 0.018
	s.height = 0.036
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 0.93, 1.0, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s.material = m
	p.mesh = s
	p.amount = 180
	p.lifetime = 1.0
	p.explosiveness = 0.35
	p.one_shot = true
	p.direction = Vector3.UP
	p.spread = 100.0
	p.initial_velocity_min = 1.4
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, -8.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.local_coords = false
	plot.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)

func _jaw() -> Transform3D:
	var i := _dskel.find_bone("Jaw")
	var xf := _dskel.global_transform * _dskel.get_bone_global_pose(i) * _dskel.get_bone_global_rest(i).affine_inverse()
	return xf * Transform3D(Basis(), Vector3(0, 0.448, 0.498))

func _tick(_delta: float) -> void:
	if _carry and _dskel:
		var m := _jaw()
		var ahead := Vector3(sin(dog.rotation.y), 0, cos(dog.rotation.y))

		lost.global_position = m.origin + ahead * 0.055 + Vector3(0, -0.06, 0)
		lost.rotation.y = dog.rotation.y + PI / 2
