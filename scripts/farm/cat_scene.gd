class_name CatScene
extends FarmCutscene

const STOVE := Vector3(-2.75, 0, -1.6)
const SEAT := Vector3(-2.75, 0, -0.78)
const BASKET := Vector3(-3.15, 0, -1.2)
const BED := Vector3(-4.3, 0, -2.4)
const BED_TOP := 0.425
const HIDE := Vector3(-3.38, 0, -3.2)
const SPRING := Vector3(-2.25, 0, -2.35)
const REFUGE := Vector3(-3.95, 0, -3.25)
const DOG := Vector3(-1.35, 0, -3.55)
const DOG_BED := Vector3(-3.9, 0, -1.38)
const DOG_LIE := Vector3(-5.06, 0, -1.55)
const HERO_BED := Vector3(-4.0, 0, -1.7)
const HERO_SEAT := Vector3(0, 0.0, -0.36)
const CAT_BED := Vector3(-3.64, BED_TOP, -2.3)
const GRILL_Y := 0.262
const MOUTH := Vector3(0, 0.166, 0.206)
const SLOW := 0.3
const POUNCE_Y := 0.33

const SEATED := {"Emo_Content": [3, -1, "flower", 14, 2.0], "Emo_Laugh": [3, 1, "note", 8, 1.8]}

var cat: FarmAnimal
var dog: FarmAnimal
var hero: Player
var _fish: Array[Node3D] = []
var _held: Node3D = null
var _dropped: Node3D = null
var _cskel: Skeleton3D
var _sizzle = null
var _purr = null
var _hens: Array[FarmAnimal] = []
var _tool := ""
var _sky_mat: Material = null
var _sky_keep := {}
var _env_keep := []
var _glow_light: OmniLight3D

func play(p: Node3D) -> void:
	drives_hens = true
	own_light = true
	_begin(p)
	hero = p.player
	hero.visible = true
	_tool = hero.chibi.tool
	hero.chibi.hold("")
	_dusk()
	_cast()
	_sit_ground()

	_fix(Vector3(-1.0, 1.0, -2.45), Vector3(-1.15, 0.95, -2.4), Vector3(-3.0, 0.6, -1.15), Vector3(-2.95, 0.58, -1.15), 4.5, 44.0)
	await _until(2.2)
	_hero("Emo_Content")

	await _until(4.5)
	_fix(Vector3(-2.5, 0.52, -1.22), Vector3(-2.56, 0.47, -1.3), STOVE + Vector3(0, GRILL_Y, 0), STOVE + Vector3(0, GRILL_Y, 0), 3.5, 34.0)

	await _until(8.0)
	var eye := (STOVE - HIDE).normalized()
	var side := Vector3(eye.z, 0, -eye.x)
	var back := HIDE - eye * 0.78 + side * 0.4
	_fix(back + Vector3(0, 0.44, 0), back + eye * 0.08 + Vector3(0, 0.43, 0), STOVE + Vector3(0, 0.36, 0), STOVE + Vector3(0, 0.36, 0), 1.8, 42.0)
	await _until(9.4)
	Sound.play_at("animal.cat_meow", cat.global_position, -14.0, 1.15)
	await _until(9.8)
	var face := HIDE + Vector3(0, 0.17, 0)
	_fix(face + eye * 1.0 + side * 0.22 + Vector3(0, 0.05, 0), face + eye * 0.9 + side * 0.2 + Vector3(0, 0.05, 0), face, face, 1.7, 30.0)

	await _until(11.5)
	_fix(Vector3(-0.9, 1.2, 1.25), Vector3(-1.0, 1.15, 1.1), Vector3(-3.1, 0.66, -1.3), Vector3(-3.3, 0.62, -1.4), 3.5, 44.0)
	_stand()
	await _until(12.2)
	hero.go_to(Vector3(-4.0, 0, 2.8))

	await _until(15.0)
	cat.play("Sneak", 0.4)
	var tw := _way(cat, [HIDE, Vector3(-2.85, 0, -3.1), Vector3(-2.4, 0, -2.85), SPRING], 7.0)
	var low := Vector3(-2.12, 0.22, -1.0)
	_follow(low, low + Vector3(0.05, -0.02, -0.08), cat, Vector3(0, 0.17, 0), 3.3, 38.0, 38.0, 0.2, STOVE + Vector3(0, 0.2, 0))

	await _until(18.3)
	tw.pause()
	cat.anim.speed_scale = 0.0
	dog.play("Sit", 0.2)
	var fwd := Vector3(sin(dog.rotation.y), 0, cos(dog.rotation.y))
	var dh := dog.position + fwd * 0.12 + Vector3(0, 0.56, 0)
	_fix(dh + fwd * 1.5 + Vector3(0.2, -0.12, 0.25), dh + fwd * 1.38 + Vector3(0.18, -0.12, 0.23), dh, dh, 1.2, 34.0)
	await _until(19.5)
	var ch := cat.position + Vector3(0, 0.18, 0)
	_fix(ch + Vector3(0.58, 0.06, 0.82), ch + Vector3(0.54, 0.06, 0.76), ch, ch, 1.2, 32.0)
	await _until(20.5)
	dog.play("Lie", 0.3)
	await _until(20.7)
	_follow(low + Vector3(0.05, -0.02, -0.08), low + Vector3(0.1, -0.02, -0.14), cat, Vector3(0, 0.17, 0), 3.8, 38.0, 38.0,
		0.2, STOVE + Vector3(0, 0.2, 0))
	cat.anim.speed_scale = 1.0
	tw.play()

	await _until(24.5)
	cat.play("Wiggle", 0.25)
	var aim := Vector3(STOVE.x - cat.position.x, 0, STOVE.z - cat.position.z).normalized()
	cat.rotation.y = atan2(aim.x, aim.z)
	var rear := cat.position - aim * 0.95 + Vector3(aim.z, 0, -aim.x) * 0.32
	_fix(rear + Vector3(0, 0.5, 0), rear + aim * 0.08 + Vector3(0, 0.48, 0), cat.position + aim * 0.3 + Vector3(0, 0.1, 0),
		cat.position + aim * 0.3 + Vector3(0, 0.1, 0), 2.0, 42.0)
	await _until(26.5)
	await _pounce()

	var cp := cat.position
	var to_cam := Vector3(0.75, 0, 0.8)
	cat.rotation.y = atan2(to_cam.x, to_cam.z)
	_fix(cp + to_cam * 1.05 + Vector3(0, 0.24, 0), cp + to_cam * 0.98 + Vector3(0, 0.24, 0), cp + Vector3(0, 0.19, 0), cp + Vector3(0, 0.19, 0), 0.9, 36.0)
	await _until(_t + 0.9)
	hero.stop_going()
	hero.position = Vector3(-3.45, 0, -0.6)
	hero.rotation.y = atan2(cp.x - hero.position.x, cp.z - hero.position.z)
	hero.facing = hero.rotation.y
	var hh := hero.position + Vector3(0, 1.08, 0)
	_fix(Vector3(-1.8, 1.02, -1.02), Vector3(-1.9, 1.02, -1.0), hh, hh, 1.5, 40.0)
	_hero("Emo_Shocked")
	Sound.play_at("animal.cat_meow", cat.global_position, -6.0, 1.3)
	await _until(_t + 1.5)

	var t0 := _t
	_chase()
	_follow(Vector3(0.6, 0.38, -0.05), Vector3(0.55, 0.36, 0.05), cat, Vector3(0, 0.15, 0), 3.0, 44.0, 44.0)
	await _until(t0 + 3.0)
	_fix(Vector3(-1.4, 4.4, 5.6), Vector3(-1.6, 4.2, 5.3), Vector3(-2.2, 0.0, -0.2), Vector3(-2.6, 0.0, -0.4), 3.9, 46.0)
	await _until(t0 + 6.9)

	_fix(Vector3(-3.55, 0.2, -4.08), Vector3(-3.6, 0.2, -4.0), REFUGE + Vector3(0.05, 0.15, 0.2), REFUGE + Vector3(0.05, 0.15, 0.2), 3.5, 48.0)
	await _until(t0 + 10.4)
	_fix(REFUGE + Vector3(0.5, 0.2, -0.85), REFUGE + Vector3(0.46, 0.2, -0.78), REFUGE + Vector3(0, 0.15, 0), REFUGE + Vector3(0, 0.15, 0), 3.8, 36.0)
	await _until(t0 + 12.6)
	cat.play("Groom", 0.3)
	_drop_fish(true)

	await _until(t0 + 14.2)
	_fix(Vector3(-2.1, 1.05, 0.5), Vector3(-2.2, 1.0, 0.4), Vector3(-4.2, 0.55, -1.9), Vector3(-4.2, 0.55, -1.9), 4.0, 40.0)
	dog.anim.speed_scale = 1.0
	dog.play("Walk", 0.3)
	_way(dog, [dog.position, Vector3(-4.6, 0, -1.2), DOG_LIE], 2.0).finished.connect(_dog_down)
	hero.go_to(HERO_BED)
	await _until(t0 + 16.8)
	_sit_bed()
	await _until(t0 + 17.4)
	_hero("Emo_Laugh")

	await _until(t0 + 18.2)
	cat.anim.speed_scale = 1.0
	cat.play("Walk", 0.3)
	var foot := Vector3(CAT_BED.x + 0.05, 0, -3.2)
	await _way(cat, [cat.position, Vector3(-3.78, 0, -3.32), foot], 0.8).finished
	cat.rotation.y = 0.0
	cat.play("Pounce", 0.1)
	await _until(_t + 0.12)
	var on := Vector3(CAT_BED.x + 0.03, BED_TOP, -2.62)
	await _move(cat, [foot, (foot + on) / 2 + Vector3(0, 0.42, 0), on], 0.42, false, Tween.TRANS_LINEAR).finished
	cat.play("Walk", 0.2)
	await _move(cat, [on, CAT_BED], 0.7, false, Tween.TRANS_SINE).finished
	cat.play("Rub", 0.25)
	Sound.play_at("animal.cat_meow", cat.global_position, -6.0, 1.05)

	await _until(t0 + 22.2)
	_fix(Vector3(-2.9, 0.92, 0.1), Vector3(-2.7, 1.05, 0.5), Vector3(-3.85, 0.58, -2.0), Vector3(-3.9, 0.55, -2.0), 5.5, 40.0)
	cat.play("Sleep", 0.5)
	_purr = Sound.play_at("animal.cat_purr", cat.global_position)
	_fireflies()
	_nightfall(5.0)
	await _until(t0 + 27.2)
	_letterbox(false)
	_stand()
	create_tween().tween_property(hero.chibi, "position", Vector3.ZERO, 0.4)
	await _until(t0 + 27.7)
	Sound.stop(_purr, 1.0)
	Sound.stop(_sizzle, 1.0)
	hero.chibi.hold(_tool)
	_undusk()
	_end()

func _dusk() -> void:
	var sun: DirectionalLight3D = plot.sun
	sun.rotation = Vector3(deg_to_rad(-6.0), deg_to_rad(-48.0), 0.0)
	sun.light_energy = 0.8
	sun.light_color = Color(1.0, 0.55, 0.35)
	var env: Environment = plot.env
	if env:
		_env_keep = [env.ambient_light_color, env.ambient_light_energy]
		env.ambient_light_color = Color(0.62, 0.62, 0.8)
		env.ambient_light_energy = 0.55
		env.background_energy_multiplier = 0.8
		env.fog_light_color = Color(0.86, 0.62, 0.55)
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			_sky_mat = env.sky.sky_material
			for k in ["sky_horizon_color", "ground_horizon_color", "sky_top_color"]:
				_sky_keep[k] = _sky_mat.get(k)
			_sky_mat.set("sky_horizon_color", Color(0.98, 0.62, 0.45))
			_sky_mat.set("ground_horizon_color", Color(0.82, 0.58, 0.5))
			_sky_mat.set("sky_top_color", Color(0.36, 0.42, 0.66))

func _nightfall(secs: float) -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(plot.sun, "light_energy", 0.3, secs)
	tw.tween_property(plot.sun, "light_color", Color(0.75, 0.6, 0.85), secs)
	tw.tween_property(_glow_light, "light_energy", 3.4, secs)
	if plot.env:
		tw.tween_property(plot.env, "ambient_light_energy", 0.4, secs)

func _undusk() -> void:
	for k in _sky_keep:
		_sky_mat.set(k, _sky_keep[k])
	if plot.env and not _env_keep.is_empty():
		plot.env.ambient_light_color = _env_keep[0]
		plot.env.ambient_light_energy = _env_keep[1]

func _cast() -> void:
	Furniture.place(plot, "bep_lo", STOVE, 0.0)
	for k in 3:
		var f := Furniture.place(plot, "ca_nuong", STOVE + Vector3(0, GRILL_Y, -0.085 + 0.085 * k), 0.0, false)
		_fish.append(f)
	Furniture.place(plot, "gio_ca", BASKET, 20.0, false)
	_glow()
	_smoke()
	_sizzle = Sound.play_at("cook.grill_sizzle", STOVE + Vector3(0, 0.3, 0))
	cat = FarmAnimal.spawn(plot, "meo_muop", HIDE, atan2(STOVE.x - HIDE.x, STOVE.z - HIDE.z))
	cat.play("Loaf")
	_cskel = cat.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	dog = FarmAnimal.spawn(plot, "cho_vang", DOG, -PI / 2 + 0.5)
	dog.play("Lie_Keep")
	var hs: Array = plot.hens
	for i in hs.size():
		var h: FarmAnimal = hs[i].a
		h.visible = true
		if i < 2:
			h.position = Vector3(-0.9 + 0.6 * i, 0, 1.0 + 0.3 * i)
			_hens.append(h)
		h.play("Peck")

func _glow() -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.25)
	l.light_energy = 2.5
	l.omni_range = 3.0
	_glow_light = l
	l.shadow_enabled = false
	plot.add_child(l)
	l.global_position = STOVE + Vector3(0, 0.36, 0)

func _smoke() -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.28, 0.28)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 0.55))
	gr.set_color(1, Color(1, 1, 1, 0.0))
	g.gradient = gr
	m.albedo_texture = g
	q.material = m
	p.mesh = q
	p.amount = 16
	p.lifetime = 4.0
	p.preprocess = 3.0
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.12
	p.initial_velocity_max = 0.22
	p.gravity = Vector3(0.05, 0.1, 0.02)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = sc
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	ramp.colors = PackedColorArray([Color(0.95, 0.93, 0.9, 0.0), Color(0.95, 0.93, 0.9, 0.55), Color(0.85, 0.87, 0.9, 0.0)])
	p.color_ramp = ramp
	plot.add_child(p)
	p.global_position = STOVE + Vector3(0, 0.36, 0)
	p.emitting = true

func _fireflies() -> void:
	for i in 9:
		var f := FarmAnimal.spawn(plot, "dom_dom", BED + Vector3(randf_range(-1.6, 2.2), randf_range(0.5, 1.4), randf_range(0.4, 2.0)),
			randf() * TAU)
		f.scale = Vector3.ONE * 1.8
		f.play("Fly")

func _sit_ground() -> void:
	hero.stop_going()
	hero.position = SEAT
	hero.rotation.y = PI
	hero.facing = PI
	hero.sitting = true
	hero.chibi.play("Act_SitFloor", 0.0)

func _stand() -> void:
	hero.sitting = false
	hero.chibi.play("Base_Wait", 0.3)

func _sit_bed() -> void:
	hero.stop_going()
	hero.position = HERO_BED
	hero.rotation.y = 0.0
	hero.facing = 0.0
	hero.sitting = true
	hero.chibi.play("Act_SitChair_Idle", 0.35)
	create_tween().tween_property(hero.chibi, "position", HERO_SEAT, 0.35)

func _hero(clip: String) -> void:
	var an := hero.chibi.anim
	if hero.sitting:
		var f: Array = SEATED.get(clip, [])
		if not f.is_empty():
			hero.chibi._override = Vector2i(f[0], f[1])
			hero.chibi._override_until = hero.chibi._time + float(f[4])
			EmoteFx.play(hero.chibi, f[2], float(f[3]) / 30.0)
		return
	if an == null or not an.has_animation(clip):
		return
	var back: String = an.current_animation if hero.sitting else "Base_Wait"
	an.play(clip, 0.2)
	an.queue(back)

func _pounce() -> void:
	_slow(SLOW)
	var from := cat.position
	var fish := _fish[1]
	var flat := Vector3(STOVE.x - from.x, 0, STOVE.z - from.z).normalized()
	var top := Vector3(STOVE.x, 0, STOVE.z) - flat * 0.24 + Vector3(0, POUNCE_Y, 0)
	var land := Vector3(STOVE.x + 0.05, 0, STOVE.z + 0.64)
	var mid := (from + land) / 2 + Vector3(0, 0.3, 0)
	_fix(from + Vector3(1.0, 0.36, 1.05), from + Vector3(0.93, 0.37, 0.99), mid, mid + Vector3(0, -0.03, 0), 1.9, 42.0)
	cat.play("Pounce", 0.08)
	await _until(_t + 0.12)
	var tilt := create_tween()
	tilt.tween_property(cat, "rotation:x", -0.22, 0.1)
	tilt.tween_property(cat, "rotation:x", 0.42, 0.18)
	tilt.tween_property(cat, "rotation:x", 0.3, 0.14)
	tilt.tween_property(cat, "rotation:x", 0.0, 0.16)
	await _move(cat, [from, (from + top) / 2 + Vector3(0, 0.2, 0), top], 0.28, false, Tween.TRANS_LINEAR).finished
	_held = fish
	Sound.play_at("animal.cat_meow", cat.global_position, -12.0, 1.4)
	var over := Vector3(STOVE.x, POUNCE_Y + 0.04, STOVE.z + 0.12)
	await _move(cat, [top, over, land], 0.3, true, Tween.TRANS_LINEAR).finished
	cat.rotation.x = 0.0
	cat.play("Idle", 0.2)
	await _until(_t + 0.12)
	_slow(1.0)

func _chase() -> void:

	var loop := [cat.position, Vector3(-1.5, 0, -0.7), Vector3(-0.6, 0, 0.6), Vector3(-1.5, 0, 1.6), Vector3(-3.3, 0, 0.8),
		Vector3(-4.05, 0, -0.6), Vector3(-5.0, 0, -1.45), Vector3(-5.68, 0, -2.2), Vector3(-5.4, 0, -3.1), REFUGE]
	cat.anim.speed_scale = 0.85
	cat.play("Run", 0.1)
	_way(cat, loop, 6.9).finished.connect(_hidden)
	get_tree().create_timer(0.3, false).timeout.connect(_bark)
	await _until(_t + 0.7)
	dog.anim.speed_scale = 0.7
	dog.play("Run", 0.15)
	var dog_way := [dog.position, Vector3(-1.7, 0, -1.0), Vector3(-0.7, 0, 0.5), Vector3(-1.5, 0, 1.5), Vector3(-3.2, 0, 0.75),
		Vector3(-3.75, 0, -0.75), DOG_BED]
	_way(dog, dog_way, 6.5).finished.connect(_dog_at_bed)
	hero.go_to(Vector3(-4.3, 0, 0.6), true)
	await _until(_t + 1.1)
	for h in _hens:
		h.play("Flap", 0.1)
		var away := h.position + Vector3(randf_range(0.5, 1.3), 0, randf_range(0.9, 1.6))
		_move(h, [h.position, away], 1.0)
	Sound.play_at("animal.hen_alarm", _hens[0].global_position, -4.0, 1.1)
	await _until(_t + 1.6)
	hero.stop_going()
	_hero("Emo_Dizzy")
	await _until(_t + 1.0)
	Sound.play_at("animal.dog_bark", dog.global_position, -2.0, 1.05)

func _bark() -> void:
	dog.play("Bark", 0.1)
	Sound.play_at("animal.dog_bark", dog.global_position)

func _hidden() -> void:
	cat.anim.speed_scale = 1.0
	cat.rotation.y = atan2(0.42, -1.0)
	cat.play("Eat", 0.3)
	_drop_fish(false)

func _dog_at_bed() -> void:
	dog.anim.speed_scale = 1.0
	dog.rotation.y = atan2(REFUGE.x - dog.position.x, REFUGE.z - dog.position.z)
	dog.play("Bark", 0.2)
	Sound.play_at("animal.dog_bark", dog.global_position, -3.0)

func _dog_down() -> void:
	dog.rotation.y = PI / 2 - 0.5
	dog.play("Lie", 0.3)

func _drop_fish(eaten: bool) -> void:
	if eaten:
		if _dropped:
			_dropped.visible = false
		return
	if _held == null:
		return
	var m := _mouth()
	_dropped = _held
	_held = null
	_dropped.global_transform = Transform3D(Basis(Vector3.UP, cat.rotation.y + PI / 2),
		Vector3(m.origin.x, 0.005, m.origin.z) + cat.global_basis.z * 0.02)

func _mouth() -> Transform3D:
	var i := _cskel.find_bone("Head")
	var xf := _cskel.global_transform * _cskel.get_bone_global_pose(i) * _cskel.get_bone_global_rest(i).affine_inverse()
	return xf * Transform3D(Basis(), MOUTH)

func _tick(_delta: float) -> void:
	if _held and _cskel:
		var m := _mouth()
		_held.global_transform = Transform3D(m.basis * Basis.from_euler(Vector3(PI / 2, 0, 0)),
			m.origin + m.basis * Vector3(0, -0.03, -0.03))

func _way(n: Node3D, pts: Array, dur: float, trans := Tween.TRANS_LINEAR, ease_ := Tween.EASE_IN_OUT) -> Tween:
	var c := Curve3D.new()
	c.bake_interval = 0.02
	for i in pts.size():
		var h: Vector3 = ((pts[mini(i + 1, pts.size() - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)) / 6.0
		c.add_point(pts[i], -h, h)
	var tw := create_tween()
	tw.tween_method(_way_step.bind(n, c), 0.0, 1.0, dur).set_trans(trans).set_ease(ease_)
	return tw

func _way_step(k: float, n: Node3D, c: Curve3D) -> void:
	var len := c.get_baked_length()
	n.position = c.sample_baked(k * len, true)
	var d := c.sample_baked(minf(k * len + 0.04, len), true) - c.sample_baked(maxf(k * len - 0.04, 0.0), true)
	d.y = 0.0
	if d.length() > 0.0005:
		n.rotation.y = lerp_angle(n.rotation.y, atan2(d.x, d.z), 1.0 - exp(-get_process_delta_time() * 9.0))
