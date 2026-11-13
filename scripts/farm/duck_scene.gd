class_name DuckScene
extends FarmCutscene

const WALK := 0.30
const GAP := 0.15
const N := 5

var duck: FarmAnimal
var kids: Array[FarmAnimal] = []
var _fx := {}
var _path: Array[Vector3] = []
var _cum: Array[float] = []
var _walk := {}
var _trail: Array[Vector3] = []
var _line := false
var _flies: Array[FarmAnimal] = []
var _kims: Array[Dictionary] = []
var _lap = null
var _sky_mat: Material = null
var _sky_keep := {}
var _env_keep := Color.WHITE
var _pond: ShaderMaterial = null
var _pond_keep := {}
var W := FarmScenery.WATER_Y
var top := 0.0
var edge := Vector3.ZERO

func play(p: Node3D) -> void:
	own_light = true
	_begin(p)
	_golden()
	_cast()

	_fix(Vector3(11.2, 0.75, 4.7), Vector3(10.95, 0.5, 4.2), Vector3(11.9, -0.1, 1.4), Vector3(10.4, 0.0, 1.5), 4.0, 42.0, 39.0)
	await _until(2.6)
	for a in [duck] + kids:
		_walk[a][1] = _goal(a)
	await _until(4.0)
	_follow(Vector3(8.25, 0.24, 2.3), Vector3(8.3, 0.22, 2.15), duck, Vector3(0, 0.24, 0), 4.0, 40.0, 38.0,
		0.3, Vector3(7.3, 0.1, 1.0))
	await _until(4.7)
	Sound.play_at("animal.duck_quack", duck.global_position)
	await _until(8.0)
	var last := kids[N - 1]
	_follow(last.position + Vector3(0.36, 0.17, -0.4), last.position + Vector3(0.5, 0.16, -0.22), last,
		Vector3(0, 0.05, 0), 2.6, 34.0, 34.0)
	await _until(8.5)
	Sound.play_at("animal.duckling_peep", last.global_position)
	await _until(9.1)
	last.anim.speed_scale = 1.5
	await _until(10.6)
	last.anim.speed_scale = 1.4

	_fix(Vector3(9.65, 0.02, 3.3), Vector3(9.7, 0.02, 3.15), Vector3(9.5, 0.16, 1.6), Vector3(9.6, 0.1, 1.6), 5.4, 38.0)
	await _until(12.7)
	_duck_in()
	await _until(14.0)
	kids[0].play("Peer", 0.3)
	await _until(15.1)
	duck.play("Call_Swim", 0.2)
	Sound.play_at("animal.duck_quack", duck.global_position)

	for i in N - 1:
		await _until(16.0 + 1.4 * i)
		if i == 0:
			_fix(Vector3(9.2, 0.55, 2.3), Vector3(9.15, 0.5, 2.2), Vector3(9.75, -0.05, 1.6), Vector3(9.75, -0.08, 1.62), 2.6, 40.0)
		elif i == 2:
			_fix(Vector3(10.6, -0.12, 1.3), Vector3(10.55, -0.12, 1.35), Vector3(9.5, 0.08, 1.6), Vector3(9.55, 0.06, 1.6), 2.8, 36.0)
		_hop(kids[i], 0.0)

	await _until(21.4)
	last.play("Peer", 0.3)
	_fix(Vector3(9.84, top - 0.04, 1.72), Vector3(9.77, top - 0.03, 1.68), edge + Vector3(-0.03, 0.06, 0),
		edge + Vector3(-0.03, 0.06, 0), 3.6, 34.0)
	await _until(22.0)
	Sound.play_at("animal.duckling_peep", last.global_position, -4.0, 0.9)
	await _until(23.6)
	Sound.play_at("animal.duckling_peep", last.global_position, -6.0, 0.85)
	await _until(25.0)
	_fix(edge + Vector3(-0.3, 0.2, -0.26), edge + Vector3(-0.26, 0.17, -0.24), Vector3(10.45, W, 1.85),
		Vector3(10.45, W, 1.85), 2.6, 40.0)
	await _until(25.3)
	duck.play("Call_Swim", 0.2)
	Sound.play_at("animal.duck_quack", duck.global_position)
	await _until(25.8)
	Sound.play_at("animal.duckling_peep", kids[1].global_position)
	await _until(27.6)
	_fix(Vector3(9.52, top + 0.07, 2.02), Vector3(9.5, top + 0.07, 1.94), edge + Vector3(-0.1, 0.05, 0),
		edge + Vector3(-0.1, 0.05, 0), 2.6, 30.0)
	await _until(27.8)
	last.anim.speed_scale = -1.2
	last.play("Walk", 0.15)
	_move(last, [edge, edge + Vector3(-0.2, 0, 0)], 0.75, false, Tween.TRANS_SINE, Tween.EASE_OUT)
	await _until(28.6)
	last.anim.speed_scale = 1.0
	last.play("Idle", 0.2)
	last.set_mood(true)
	await _until(29.6)
	last.anim.speed_scale = 1.8
	last.play("Run", 0.1)
	_move(last, [edge + Vector3(-0.2, 0, 0), edge], 0.5, false, Tween.TRANS_QUAD, Tween.EASE_IN)

	await _until(30.1)
	last.anim.speed_scale = 1.0
	_slow(0.25)
	var mid := edge + Vector3(0.25, 0.02, 0.02)
	var sun_way := Vector3(-0.6, 0, 0.8)
	_follow(mid - sun_way * 0.9 + Vector3(0, -0.06, 0), mid - sun_way * 0.82 + Vector3(0, -0.06, 0), last,
		Vector3(0, 0.04, 0), 1.2, 30.0, 30.0, 0.35, mid + Vector3(0, -0.06, 0))
	_hop(last, 1.0)
	await _until(31.1)
	_slow(1.0)

	await _until(31.2)
	var pop := Vector3(edge.x + 0.6, W, edge.z)
	_fix(pop + Vector3(-0.72, 0.1, 0.42), pop + Vector3(-0.66, 0.1, 0.38), pop + Vector3(0.08, 0.02, 0.0),
		pop + Vector3(0.1, 0.03, 0.0), 2.6, 36.0)
	await _until(32.9)
	last.set_mood(false)
	Sound.play_at("animal.duckling_peep", kids[0].global_position, 0.0, 1.05)
	await _until(33.1)
	Sound.play_at("animal.duck_quack", duck.global_position, -2.0)

	await _until(33.8)
	last.play("Swim", 0.2)
	var by := duck.position + Vector3(-0.2, 0, 0.26)
	_move(last, [last.position, by], 1.2)
	_fix(by + Vector3(-0.15, 0.1, 0.85), by + Vector3(-0.12, 0.1, 0.78), by + Vector3(0.12, 0.05, -0.12),
		by + Vector3(0.12, 0.05, -0.12), 2.8, 36.0)
	await _until(35.0)
	var tw := create_tween()
	tw.tween_property(duck, "rotation:y", atan2(by.x - duck.position.x, by.z - duck.position.z), 0.5)
	duck.play("Call_Swim", 0.25)
	await _until(35.6)
	last.play("Shake", 0.15)
	Sound.play_at("animal.duckling_peep", last.global_position, 1.0, 1.12)

	await _until(36.6)
	var m := duck.position
	for i in 12:
		_trail.append(m + Vector3(-1.2 + 0.1 * i, 0, 0))
	_line = true
	duck.anim.speed_scale = 1.25
	duck.play("Swim", 0.3)
	_move(duck, [m, Vector3(11.6, W, 2.7), Vector3(12.8, W, 2.6), Vector3(13.3, W, 1.8)], 11.5, true,
		Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_fix(Vector3(13.4, 2.3, 0.1), Vector3(13.0, 1.8, 0.4), Vector3(11.4, -0.2, 2.5), Vector3(11.9, -0.2, 2.6), 5.4, 42.0)
	await _until(42.0)
	_fix(Vector3(11.3, 0.25, 3.7), Vector3(11.35, 0.22, 3.6), Vector3(12.2, -0.08, 2.1), Vector3(12.5, -0.08, 2.0), 5.5, 38.0)
	await _until(47.5)
	_letterbox(false)
	await _until(48.0)
	_unlight()
	Sound.stop(_lap, 1.0)
	_end()

func _golden() -> void:
	var sun: DirectionalLight3D = plot.sun
	sun.rotation = Vector3(deg_to_rad(-13.0), deg_to_rad(-37.0), 0.0)
	sun.light_energy = 1.05
	sun.light_color = Color(1.0, 0.7, 0.45)
	var w := (plot.scenery as Node).get_node_or_null("Pond") as MeshInstance3D
	if w:
		_pond = w.material_override
		for k in ["sky", "shallow"]:
			_pond_keep[k] = _pond.get_shader_parameter(k)
		_pond.set_shader_parameter("sky", Color(0.99, 0.8, 0.62))
		_pond.set_shader_parameter("shallow", Color(0.56, 0.6, 0.42))
	var env: Environment = plot.env
	if env:
		env.fog_light_color = Color(0.98, 0.8, 0.64)
		env.ambient_light_energy = 0.72
		env.background_energy_multiplier = 0.95
		_env_keep = env.ambient_light_color
		env.ambient_light_color = Color(1.0, 0.86, 0.72)
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			_sky_mat = env.sky.sky_material
			for k in ["sky_horizon_color", "ground_horizon_color", "sky_top_color"]:
				_sky_keep[k] = _sky_mat.get(k)
			_sky_mat.set("sky_horizon_color", Color(0.98, 0.78, 0.6))
			_sky_mat.set("ground_horizon_color", Color(0.9, 0.72, 0.58))
			_sky_mat.set("sky_top_color", Color(0.46, 0.6, 0.82))

func _unlight() -> void:
	for k in _sky_keep:
		_sky_mat.set(k, _sky_keep[k])
	if plot.env:
		plot.env.ambient_light_color = _env_keep
	for k in _pond_keep:
		_pond.set_shader_parameter(k, _pond_keep[k])

func _cast() -> void:
	var sc: FarmScenery = plot.scenery
	top = sc.jetty_top()
	var j := FarmScenery.JETTY
	edge = Vector3(j.x + FarmScenery.JETTY_LEN - 0.07, top, j.z)
	for v in [Vector2(6.9, 0.55), Vector2(7.55, 1.25)]:
		_path.append(Vector3(v.x, sc.height_at(v.x, v.y), v.y))
	_path.append(Vector3(j.x, top, j.z))
	_path.append(edge)
	_cum.append(0.0)
	for i in range(1, _path.size()):
		_cum.append(_cum[i - 1] + _path[i].distance_to(_path[i - 1]))
	duck = FarmAnimal.spawn(plot, "vit", _at(0.6), 0.0)
	_walk[duck] = [0.6, 0.6]
	for i in N:
		var s := 0.6 - 0.32 - GAP * i
		var k := FarmAnimal.spawn(plot, "vit_con_hd", _at(s), 0.0)
		if i == N - 1:
			k.scale = Vector3.ONE * 0.75
		_walk[k] = [s, s]
		kids.append(k)
	for a in [duck] + kids:
		a.anim.speed_scale = 1.4
		a.play("Idle")
		a.rotation.y = _yaw(_walk[a][0])
	var frog := FarmAnimal.spawn(plot, "ech", Vector3(12.6, W + 0.06, 2.6), -2.4)
	frog.play("Idle")
	for i in 2:
		var f := FarmAnimal.spawn(plot, "chuon_chuon", Vector3(11.5, W + 0.4, 1.5), 0.0, ["", "ngo"][i])
		f.play("Fly")
		_flies.append(f)

	var jk := FarmAnimal.spawn(plot, "chuon_kim", Vector3(j.x + 1.08, top, j.z + 0.24), PI / 2, "")
	jk.play("Idle")
	_kims.append({"f": jk, "c": Vector3(j.x + 0.8, top + 0.12, j.z - 0.6), "r": Vector3(0.4, 0.04, 0.25), "seed": 1.3,
		"perch": jk.position, "go": 12.8, "off": -1.0})
	var rc := Vector3(11.45, W + 0.4, 3.02)

	var rr := Vector3(0.2, 0.03, 0.1)
	var rk := FarmAnimal.spawn(plot, "chuon_kim", _kim_pt(rc, rr, 4.1, 0.0), 0.0, "do")
	rk.play("Hover")
	_kims.append({"f": rk, "c": rc, "r": rr, "seed": 4.1, "perch": rk.position, "go": 0.0, "off": 0.0})
	_lap = Sound.play_at("water.pond_lap", Vector3(FarmScenery.POND_C.x, W, FarmScenery.POND_C.y))

func _at(s: float) -> Vector3:
	s = clampf(s, 0.0, _cum[-1])
	for i in range(1, _path.size()):
		if s <= _cum[i]:
			return _path[i - 1].lerp(_path[i], (s - _cum[i - 1]) / maxf(_cum[i] - _cum[i - 1], 0.001))
	return _path[-1]

func _yaw(s: float) -> float:
	var d := _at(s + 0.05) - _at(s - 0.05)
	return atan2(d.x, d.z)

func _goal(a: FarmAnimal) -> float:
	var L: float = _cum[-1]
	if a == duck:
		return L
	var rank := 0
	for k in kids:
		if k == a:
			break
		if _walk.has(k):
			rank += 1
	return L - (0.3 if _walk.has(duck) else 0.0) - GAP * rank

func _requeue() -> void:
	for k in kids:
		if _walk.has(k):
			_walk[k][1] = _goal(k)

func _duck_in() -> void:
	_walk.erase(duck)
	_requeue()
	duck.anim.speed_scale = 1.0
	duck.play("Flap", 0.15)
	var land := Vector3(edge.x + 0.45, W, edge.z + 0.05)
	await _move(duck, [edge, (edge + land) / 2 + Vector3(0, 0.16, 0), land], 0.55, false, Tween.TRANS_LINEAR).finished
	Sound.play_at("water.splash", land, -4.0, 1.15)
	_swim(duck, 0.8, 0.8)
	_move(duck, [land, Vector3(10.35, W, 1.75), Vector3(10.55, W, 1.95)], 1.5)
	await _until(_t + 1.5)
	var tw := create_tween()
	tw.tween_property(duck, "rotation:y", -PI / 2 - 0.35, 0.6)

func _hop(k: FarmAnimal, big: float) -> void:
	_walk.erase(k)
	_requeue()
	k.anim.speed_scale = 1.0
	k.rotation.y = PI / 2
	k.play("Hop", 0.08)
	await _until(_t + 0.17)
	var from := k.position
	var land := Vector3(edge.x + 0.3 + 0.2 * big + randf_range(0.0, 0.08), W, edge.z + randf_range(-0.12, 0.12) * (1.0 - big))
	var up := 0.07 + 0.09 * big
	await _move(k, [from, (from + land) / 2 + Vector3(0, up + (top - W) * 0.5, 0), land], 0.36 + 0.2 * big, false,
		Tween.TRANS_LINEAR).finished
	if big > 0.0:
		Sound.play_at("water.splash", land, -2.0, 1.35)
		var fx := _swim(k, 0.45, 1.0)
		fx.mode = SwimFX.UNDER
		await _move(k, [land, land + Vector3(0.06, -0.13, 0.0)], 0.3, false, Tween.TRANS_SINE, Tween.EASE_OUT).finished
		await _move(k, [k.position, land + Vector3(0.1, 0, 0)], 0.32, false, Tween.TRANS_SINE, Tween.EASE_IN).finished
		fx.mode = SwimFX.SURFACE
		fx.splash(0.35)
		Sound.play_at("water.plop", k.global_position, -6.0, 1.2)
		k.play("Shake", 0.1)
		return
	Sound.play_at("water.plop", land)
	_swim(k, 0.4, 0.45)
	k.play("Swim", 0.1)
	var i := kids.find(k)
	var slot := duck.position + Vector3(0.18 + 0.1 * (i % 2), 0, -0.36 + 0.22 * i)
	_move(k, [land, slot], 1.4)

func _swim(a: FarmAnimal, size: float, splash: float) -> SwimFX:
	var fx := SwimFX.attach(a, size, W)
	fx.splash(splash)
	_fx[a] = fx
	return fx

func _tick(delta: float) -> void:
	for a in _walk:
		var w: Array = _walk[a]
		if w[0] < w[1] - 0.001:
			w[0] = minf(w[1], w[0] + WALK * delta)
			a.position = _at(w[0])
			a.rotation.y = lerp_angle(a.rotation.y, _yaw(w[0]), 1.0 - exp(-delta * 8.0))
			if a.anim.current_animation != "Walk" and a.anim.current_animation != "Run" and a.anim.speed_scale > 0.0:
				a.play("Walk", 0.2)
		elif a.anim.current_animation == "Walk" and a.anim.speed_scale > 0.0:
			a.play("Idle", 0.25)
	if _line:
		if _trail.is_empty() or _trail[-1].distance_to(duck.position) > 0.02:
			_trail.append(duck.position)
		for i in kids.size():
			var to := _behind(0.26 + 0.17 * i)
			var k := kids[i]
			var d := to - k.position
			d.y = 0.0
			k.position += d * (1.0 - exp(-delta * 2.2))
			if d.length() > 0.02:
				k.rotation.y = lerp_angle(k.rotation.y, atan2(d.x, d.z), 1.0 - exp(-delta * 5.0))
	for i in _flies.size():
		var f := _flies[i]
		var u := _t * (0.35 + 0.1 * i) + i * 2.0
		var c := Vector3(11.2 + 1.4 * i, W + 0.35 + 0.08 * sin(u * 3.1), 1.4 + 0.8 * i)
		var at := c + Vector3(cos(u) * 0.9, 0, sin(u * 2.0) * 0.5)
		var d := at - f.position
		f.position = at
		if d.length() > 0.001:
			f.rotation.y = atan2(d.x, d.z)
	for q in _kims:
		var f: FarmAnimal = q.f
		if q.off < 0.0:
			if _t < q.go:
				continue
			q.off = _t
		var w := _kim_at(q.c, q.r, q.seed, _t - q.off)
		var p: Vector3 = w[0]
		var lift := smoothstep(0.0, 0.5, _t - q.off)
		f.position = (q.perch as Vector3).lerp(p, lift)
		var want := "Fly" if w[2] or lift < 1.0 else "Hover"
		if f.anim.current_animation != want:
			f.play(want, 0.1)
		var d: Vector3 = w[1] if lift >= 1.0 else p - (q.perch as Vector3)
		if Vector2(d.x, d.z).length() > 0.01:
			f.rotation.y = lerp_angle(f.rotation.y, atan2(d.x, d.z), 1.0 - exp(-delta * 10.0))

func _kim_at(c: Vector3, r: Vector3, seed_: float, t: float) -> Array:
	var per := 2.0
	var k := floorf(t / per)
	var ph := (t - k * per) / per
	var a := _kim_pt(c, r, seed_, k)
	var b := _kim_pt(c, r, seed_, k + 1.0)
	var p := a.lerp(b, smoothstep(0.0, 0.3, ph)) + Vector3(0, 0.005 * sin(t * 9.0 + seed_), 0)
	return [p, b - a, ph < 0.3]

func _kim_pt(c: Vector3, r: Vector3, seed_: float, k: float) -> Vector3:
	return c + Vector3(sin(k * 1.7 + seed_) * r.x, sin(k * 2.3 + seed_) * r.y, cos(k * 2.9 + seed_ * 1.3) * r.z)

func _behind(dist: float) -> Vector3:
	var left := dist
	var p := duck.position
	for i in range(_trail.size() - 1, -1, -1):
		var seg := p.distance_to(_trail[i])
		if seg >= left:
			return p.lerp(_trail[i], left / maxf(seg, 0.001))
		left -= seg
		p = _trail[i]
	return p
