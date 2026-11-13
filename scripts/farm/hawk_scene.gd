class_name HawkScene
extends FarmCutscene

const H0 := Vector3(5.8, 0, 0.3)
const R0 := Vector3(7.6, 0, 1.1)
const SKY_C := Vector3(5.8, 6.5, -1.0)
const SKY_R := 4.5

const FLARE := Vector3(5.75, 0.35, -0.05)
const COOP := Vector3(5.15, 0, -2.0)
const SWOOP_SLOW := 0.4
const DIVE := 1.86
const FACE_EST := Vector3(5.75, 0.95, 0.1)
const LEAP := 0.44
const SLOW := 0.22

const HIDE := [Vector3(0.15, 0, 0.03), Vector3(-0.15, 0, 0.03), Vector3(0.13, 0, -0.1), Vector3(-0.13, 0, -0.1),
	Vector3(0.07, 0, 0.15), Vector3(-0.07, 0, 0.15)]

var hen: FarmAnimal
var rooster: FarmAnimal
var hawk: FarmAnimal
var chicks: Array[FarmAnimal] = []
var _others: Array[FarmAnimal] = []
var _circling := true
var _ang := 2.4
var _skel: Skeleton3D = null

func play(p: Node3D) -> void:
	drives_hens = true
	_begin(p)
	_cast()

	_fix(Vector3(6.6, 0.75, 3.0), Vector3(6.4, 0.7, 2.7), Vector3(5.7, 0.3, 0.1), Vector3(5.75, 0.3, 0.1), 3.8, 38.0)
	await _until(2.6)
	Sound.play_at("animal.hawk_cry", hawk.global_position, -6.0)

	await _until(3.8)
	_follow(Vector3(5.1, 0.25, 1.6), Vector3(5.15, 0.25, 1.55), hawk, Vector3.ZERO, 3.4, 34.0, 24.0)
	await _until(5.0)
	Sound.play_at("animal.hawk_cry", hawk.global_position)
	await _until(7.2)
	_rig("beside", 3.0, 38.0)
	await _until(8.6)
	Sound.play_at("animal.hawk_cry", hawk.global_position, 2.0)
	await _until(10.2)
	_rig("face", 2.0, 40.0)
	await _until(11.0)
	hawk.set_mood(true)

	await _until(12.2)
	hawk.set_mood(false)
	_fix(Vector3(5.25, 0.2, 1.25), Vector3(5.45, 0.19, 1.1), Vector3(5.8, 0.14, 0.35), Vector3(5.8, 0.16, 0.3), 3.2, 30.0)
	await _until(13.6)
	hen.play("Idle")
	await _until(13.7)
	Sound.play_at("animal.hen_alarm", hen.global_position)
	await _until(13.9)
	_chicks_hide()
	await _until(14.0)
	Sound.play_at("animal.chick_peeps", H0)
	await _until(15.0)
	for o in _others:
		o.anim.speed_scale = 1.5
		o.play("Run")
		var to := COOP + Vector3(randf_range(-0.9, -0.5), 0, randf_range(-0.3, 0.5))
		_move(o, [o.position, to], o.position.distance_to(to) / 1.1).finished.connect(o.play.bind("Flap"))
	await _until(15.3)
	hen.play("Shield")
	await _until(15.4)
	_fix(Vector3(5.72, 0.36, 1.3), Vector3(5.74, 0.34, 1.15), Vector3(5.8, 0.26, 0.3), Vector3(5.8, 0.26, 0.3), 1.4, 34.0)
	await _until(15.8)
	Sound.play_at("animal.chick_peeps", H0, -2.0)

	await _until(16.8)
	_stoop()
	_follow(Vector3(5.2, 0.3, 1.7), Vector3.INF, hawk, Vector3(0, 0.4, 0), 1.1, 40.0, 40.0)
	await _until(17.9)
	_follow(Vector3(5.86, 0.13, 0.95), Vector3(5.87, 0.12, 0.88), hawk, Vector3(0, 0.45, 0), 0.76, 44.0, 44.0)
	await _until(18.4)
	_charge()
	await _until(18.66)
	_fix(Vector3(4.9, 0.7, 2.9), Vector3(4.97, 0.67, 2.78), Vector3(5.8, 0.62, 0.25), Vector3(5.85, 0.6, 0.25), 1.0, 46.0)

	await _until(19.0)
	_turn_on_rooster()
	await _until(19.12)
	_slow(SLOW)
	await _until(19.18)
	_counter()
	await _until(19.69)
	_strike()
	await _until(20.3)
	_slow(1.0)

	await _until(20.35)
	_follow(Vector3(5.4, 0.3, 1.6), Vector3(5.35, 0.3, 1.65), hawk, Vector3(0, 0.4, 0), 0.8, 40.0, 40.0)
	await _until(21.15)
	_rig("chase", 2.6, 42.0)
	await _until(21.25)
	hawk.play("Look_Back", 0.2)
	await _until(22.08)
	Sound.play_at("animal.hawk_cry", hawk.global_position, 3.0, 0.92)
	await _until(23.25)
	_shot.hold = true

	await _until(24.15)
	_follow(rooster.position + Vector3(0.35, 0.28, 1.0), rooster.position + Vector3(0.3, 0.3, 0.85), rooster,
		Vector3(0, 0.33, 0), 3.4, 36.0, 34.0)
	await _until(24.35)
	rooster.play("Crow")
	await _until(24.7)
	Sound.play_at("animal.rooster_crow", rooster.global_position)
	await _until(26.45)
	rooster.set_mood(false)
	await _until(27.55)
	_fix(Vector3(5.7, 0.4, 1.4), Vector3(5.65, 0.38, 1.25), Vector3(5.8, 0.2, 0.3), Vector3(5.8, 0.2, 0.3), 2.6, 36.0)
	await _until(27.65)
	hen.play("Shield_End")
	await _until(27.95)
	_chicks_out()
	await _until(30.15)
	_fix(Vector3(6.6, 0.9, 3.1), Vector3(6.9, 1.2, 3.6), Vector3(5.9, 0.3, 0.2), Vector3(5.9, 0.3, 0.2), 3.0, 40.0)
	await _until(31.95)
	_letterbox(false)
	await _until(32.45)
	_end()

func _cast() -> void:
	var hs: Array = plot.hens
	hen = hs[0].a
	hen.visible = true
	hen.position = H0
	hen.rotation.y = atan2(4.9 - H0.x, 2.9 - H0.z)
	hen.play("Peck")
	for i in range(1, hs.size()):
		var o: FarmAnimal = hs[i].a
		o.visible = true
		o.position = Vector3(4.7 + 0.45 * i, 0, -0.6 - 0.35 * i)
		o.play("Peck")
		_others.append(o)
	rooster = FarmAnimal.spawn(plot, "ga_trong", R0, -2.2)
	rooster.play("Peck")
	for i in 6:
		var a := lerpf(0.2 * PI, 0.95 * PI, i / 5.0) + randf_range(-0.12, 0.12)
		var at := H0 + Vector3(cos(a), 0, sin(a)) * randf_range(0.35, 0.7)
		var c := FarmAnimal.spawn(plot, "ga_con", at, randf() * TAU)
		c.play("Peck" if i % 2 == 0 else "Idle")
		chicks.append(c)
	hawk = FarmAnimal.spawn(plot, "dieu_hau", _sky(_ang))
	hawk.full_rate = true
	rooster.full_rate = true
	hawk.play("Soar")
	_skel = hawk.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

func _sky(a: float) -> Vector3:
	return SKY_C + Vector3(cos(a) * SKY_R, 0.5 * sin(a * 2.0), sin(a) * SKY_R)

func _head() -> Vector3:
	return _skel.to_global(_skel.get_bone_global_pose(_skel.find_bone("Head")).origin)

func _chicks_hide() -> void:
	var b := Basis(Vector3.UP, hen.rotation.y)
	for i in chicks.size():
		var c := chicks[i]
		var to: Vector3 = H0 + b * (HIDE[i] as Vector3)
		var dur := maxf(c.position.distance_to(to) / 0.75, 0.3)
		c.anim.speed_scale = 1.6
		c.play("Run")
		var tw := _move(c, [c.position, to], dur, true, Tween.TRANS_LINEAR)
		tw.finished.connect(_hidden.bind(c, hen.rotation.y + randf_range(-0.5, 0.5)))

func _hidden(c: FarmAnimal, yaw: float) -> void:
	c.anim.speed_scale = 1.0
	c.rotation.y = yaw
	c.play("Hide")

func _chicks_out() -> void:
	for i in chicks.size():
		var c := chicks[i]
		await get_tree().create_timer(0.12 * i).timeout
		var out := c.position + (c.position - H0).normalized() * randf_range(0.2, 0.35)
		c.play("Walk")
		var tw := _move(c, [c.position, out], 1.1)
		tw.finished.connect(c.play.bind("Peck" if i % 2 == 0 else "Idle"))

func _stoop() -> void:
	_circling = false
	var from := hawk.position
	hawk.anim.speed_scale = SWOOP_SLOW
	hawk.play("Swoop", 0.15)
	var ctrl := FLARE + Vector3(0, 2.6, -2.6) + (from - FLARE) * 0.2
	_move(hawk, [from, ctrl, FLARE], DIVE, true, Tween.TRANS_SINE, Tween.EASE_IN)
	await _until(_t + DIVE)

	hawk.anim.speed_scale = 1.0
	hawk.play("Hover", 0.12)
	Sound.play_at("animal.wing_flaps", FLARE, 0.0, 0.85)
	_move(hawk, [FLARE, FLARE + Vector3(0.0, -0.06, 0.05)], 0.4, false)

func _turn_on_rooster() -> void:
	var to := rooster.global_position - hawk.global_position
	var a0 := hawk.rotation.y
	var a1 := atan2(to.x, to.z)
	create_tween().tween_method(func(v: float) -> void: hawk.rotation.y = lerp_angle(a0, a1, v), 0.0, 1.0, 0.3) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hawk.set_mood(true)

func _counter() -> void:
	hawk.play("Clash", 0.1)
	Sound.play_at("animal.hawk_cry", hawk.global_position, 2.0, 0.7)
	var to := rooster.global_position - hawk.global_position
	to.y = 0.0
	var h := hawk.position
	_move(hawk, [h, h + to.normalized() * 0.14 + Vector3(0, 0.04, 0)], 0.45, false, Tween.TRANS_SINE, Tween.EASE_OUT)

func _charge() -> void:
	rooster.set_mood(true)
	rooster.anim.speed_scale = 2.0
	rooster.play("Run")
	var j := FACE_EST + Vector3(0.55, -FACE_EST.y, 0.6)
	await _move(rooster, [rooster.position, j], 0.85, true, Tween.TRANS_LINEAR).finished

	var face := _face()
	var to := Vector3(face.x - j.x, 0, face.z - j.z).normalized()
	rooster.rotation.y = atan2(to.x, to.z)
	rooster.anim.speed_scale = 1.0
	rooster.play("Kick", 0.08)
	Sound.play_at("animal.wing_flaps", j, 0.0, 0.7)
	var tw := create_tween()
	tw.tween_method(_leap.bind(j), 0.0, 1.0, LEAP).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var side := Vector3(-to.z, 0, to.x)
	if side.z < 0.0:
		side = -side

	var body := hawk.global_position + Vector3(0, 0.3, 0)
	var mid := face.lerp(body, 0.4) - to * 0.12 + Vector3(0, 0.04, 0)
	_fix(mid + side * 2.0 + Vector3(0, -0.22, 0), mid + side * 1.6 + Vector3(0, -0.16, 0), mid, mid, 0.9, 40.0)

func _leap(s: float, j: Vector3) -> void:
	var feet := _feet() - rooster.global_position
	var k := _face() - feet
	rooster.position = _bez([j, (j + k) / 2 + Vector3(0, 0.25, 0), k], s)

func _face() -> Vector3:
	var hb := _skel.global_transform.basis * _skel.get_bone_global_pose(_skel.find_bone("Head")).basis
	return _head() + hb.y.normalized() * 0.05 + hawk.global_basis.z * 0.13

func _feet() -> Vector3:
	var sk := rooster.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var at := Vector3.ZERO
	for b in ["Toe_L", "Toe_R"]:
		at += sk.to_global(sk.get_bone_global_pose(sk.find_bone(b)).origin)
	return at / 2.0

func _strike() -> void:
	var at := _face()
	_feathers(at)
	_shake = 0.05
	Engine.time_scale = 0.05
	_speed = 0.05
	get_tree().create_timer(0.6, true, false, true).timeout.connect(func() -> void: _speed = SLOW)
	Sound.play_at("animal.feather_hit", at, 2.0, 0.65)
	Sound.play_at("animal.wing_flaps", at, -2.0, 0.6)
	hawk.anim.speed_scale = 1.0
	hawk.set_mood(false)
	hawk.play("Recoil", 0.05)
	var h := hawk.position
	var back := hawk.global_position - rooster.global_position
	back.y = 0.0
	var k := h + back.normalized() * 0.35 + Vector3(0, 0.12, 0)
	_move(hawk, [h, k], 0.6, false, Tween.TRANS_QUAD, Tween.EASE_OUT).finished.connect(func() -> void:
		_move(hawk, [k, k + Vector3(-0.4, 1.8, -0.6), k + Vector3(-6.0, 6.5, -10.0)], 5.0, true, Tween.TRANS_SINE,
			Tween.EASE_IN_OUT))

	await _until(_t + 0.15)
	rooster.play("Flap", 0.2)
	var r := rooster.position
	var land := Vector3(r.x + 0.3, 0, r.z + 0.3)
	await _move(rooster, [r, r + Vector3(0.12, 0.1, 0.12), land], 0.5, false, Tween.TRANS_QUAD, Tween.EASE_IN).finished
	rooster.rotation.y = atan2(1.0, 3.0)
	rooster.play("Idle")

func _feathers(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.055, 0.02)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	p.amount = 22
	p.one_shot = true
	p.explosiveness = 0.92
	p.lifetime = 2.6
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, -0.8, 0)
	p.damping_min = 1.2
	p.damping_max = 2.4
	p.angular_velocity_min = -420.0
	p.angular_velocity_max = 420.0
	p.angle_max = 360.0
	p.particle_flag_rotate_y = true
	var g := Gradient.new()
	g.set_color(0, Color("6b4429"))
	g.set_color(1, Color("d9b48a"))
	g.add_point(0.6, Color("a8532a"))
	p.color_initial_ramp = g
	p.local_coords = false
	plot.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)

func _tick(delta: float) -> void:
	if hawk and _circling:
		_ang += delta * 5.0 / SKY_R
		hawk.position = _sky(_ang)
		hawk.rotation.y = atan2(-sin(_ang), cos(_ang))

func _rig_pose(kind: String, s: float, delta: float) -> Array:
	var b := hawk.global_basis
	match kind:
		"beside":
			var a := _ang - 0.42
			return [SKY_C + Vector3(cos(a), 0, sin(a)) * (SKY_R + 2.3) + Vector3(0, 0.9 - 0.3 * s, 0),
				hawk.global_position, 1.0 - exp(-delta * 9.0)]
		"face":
			var hd := _head()
			return [hd + b.z * (0.62 - 0.1 * s) - b.x * 0.28 + Vector3(0, -0.04, 0), hd + b.z * 0.06,
				1.0 - exp(-delta * 20.0)]
		"chase":
			var hd := _head()
			var pos: Vector3 = _pos if _shot.get("hold", false) else hd - b.z * 1.05 + b.x * 0.52 + Vector3(0, 0.26, 0)

			return [pos, hd, 1.0 - exp(-delta * 15.0)]
	return [_pos, _look, 1.0]
