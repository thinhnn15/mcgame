extends Node3D

const ThuDo := preload("res://scripts/thu_do.gd")
const STOP_X := -693.6
const RIDE := 0.27

const SHOT_LIST := [
	{"name": "trong_ham", "secs": 7.0, "x0": -1000.0, "v": 12.0},
	{"name": "ra_ham", "secs": 12.0, "x0": -905.0, "v": 12.0},
	{"name": "toi_ga", "secs": 20.0, "x0": -735.0, "v": 8.0},
]

var shots: Array = SHOT_LIST.duplicate(true)
var home: Node3D
var curve := Curve3D.new()
var route_len := 0.0
var lead: Node3D
var tail: Node3D
var hero: Chibi
var bo: Chibi
var cam: Camera3D
var shot := 0
var shot_t := 0.0
var only := -1
var still_at := -1.0
var png := ""
var _waved := false
var _sun_energy := 0.0

func _ready() -> void:
	home = load("res://scenes/hometown.tscn").instantiate()
	add_child(home)
	home.fixed_view = true
	cam = home.cam
	_sun_energy = (home.get_node("Sun") as DirectionalLight3D).light_energy
	home.player.visible = false
	home.player.set_physics_process(false)
	var line: Array = home.layout["rail"]
	for i in line.size() - 1:
		var a := Vector2(line[i][0], line[i][1])
		var b := Vector2(line[i + 1][0], line[i + 1][1])
		var n := maxi(1, roundi(a.distance_to(b) / 4.0))
		for k in n:
			var p := a.lerp(b, float(k) / n)
			curve.add_point(Vector3(p.x, home.height_at(p.x, p.y) + 0.02 + RIDE, p.y))
	var e := Vector2(line[-1][0], line[-1][1])
	curve.add_point(Vector3(e.x, home.height_at(e.x, e.y) + 0.02 + RIDE, e.y))
	curve.bake_interval = 0.5
	route_len = curve.get_baked_length()
	lead = ToaTau.place(home, Vector3.ZERO, 0.0, false)
	tail = ToaTau.place(home, Vector3.ZERO, 0.0, false)
	for car: Node3D in [lead, tail]:
		for z: float in [-3.5, 0.0, 3.5]:
			var l := OmniLight3D.new()
			l.light_color = Color("ffd9a0")
			l.light_energy = 1.6
			l.omni_range = 6.5
			l.position = Vector3(0, ToaTau.FL + 2.0, z)
			car.add_child(l)
	var head := SpotLight3D.new()
	head.light_color = Color("fff0d0")
	head.light_energy = 6.0
	head.spot_range = 60.0
	head.spot_angle = 22.0
	head.position = Vector3(0, ToaTau.FL + 0.6, ToaTau.LENGTH / 2.0 + 0.2)
	head.rotation = Vector3(-0.04, PI, 0)
	lead.add_child(head)
	hero = Chibi.new()
	home.add_child(hero)
	hero.build(Looks.load_saved())
	hero.visible = false
	var dad: Dictionary = Looks.DEFAULT.duplicate(true)
	dad.merge(ThuDo.DAD, true)
	dad["eye_style"] = "calm"
	bo = Chibi.new()
	home.add_child(bo)
	bo.build(dad)
	var plat := _platform_y()
	bo.global_transform = Transform3D(Basis.looking_at(Vector3(-0.6, 0, -1.0)), Vector3(-692.0, plat, -47.6))
	bo.play("Base_Wait", 0.0)
	var xe := Furniture.place(home, "scooter", Vector3(-690.6, plat, -46.2), -80.0, false)
	xe.name = "XeBo"
	only = int(Stage.arg("--shot", "-1"))
	still_at = float(Stage.arg("--at", "-1"))
	png = Stage.arg("--png")
	_start(maxi(only, 0))
	if still_at >= 0.0:
		shot_t = still_at * float(shots[shot]["secs"])

func _platform_y() -> float:
	return home.height_at(-700.0, -44.0) + 0.47

func _s_for_x(x: float) -> float:
	var best := 0.0
	var bd := INF
	var s := 0.0
	while s < route_len:
		var d := absf(curve.sample_baked(s).x - x)
		if d < bd:
			bd = d
			best = s
		s += 0.5
	return best

func frame_at(s: float) -> Transform3D:
	var a := curve.sample_baked(maxf(s - 2.0, 0.0), true)
	var b := curve.sample_baked(minf(s + 2.0, route_len), true)
	var fwd := (b - a).normalized()
	return Transform3D(Basis.looking_at(-fwd, Vector3.UP), curve.sample_baked(s, true))

func _train_at(s: float) -> void:
	lead.global_transform = frame_at(s)
	var b := frame_at(s - ToaTau.LENGTH)
	tail.global_transform = Transform3D(b.basis.rotated(Vector3.UP, PI), b.origin)

func _start(i: int) -> void:
	shot = i
	shot_t = 0.0
	_waved = false
	var sh: Dictionary = shots[i]
	var s0 := _s_for_x(sh["x0"])
	sh["s0"] = s0
	if sh["name"] == "toi_ga":
		var d := _s_for_x(STOP_X) - s0
		sh["acc"] = -float(sh["v"]) * float(sh["v"]) / (2.0 * d)
	home.get_node("Sun").light_energy = 0.0 if sh["name"] == "trong_ham" else _sun_energy
	ToaTau.set_doors(lead, 0.0, -1)
	ToaTau.set_doors(lead, 0.0, 1)
	hero.visible = false

func _train_s(sh: Dictionary, t: float) -> float:
	var v0: float = sh["v"]
	var a: float = sh.get("acc", 0.0)
	if a < 0.0:
		var tm := -v0 / a
		var tt := minf(t, tm)
		return float(sh["s0"]) + v0 * tt + 0.5 * a * tt * tt
	return float(sh["s0"]) + v0 * t

func _process(delta: float) -> void:
	var sh: Dictionary = shots[shot]
	if still_at < 0.0:
		shot_t += delta
	var secs: float = sh["secs"]
	if shot_t > secs:
		if only >= 0 or shot + 1 >= shots.size():
			if only < 0 and Engine.has_meta("ve_que_chain"):
				Engine.remove_meta("ve_que_chain")
				get_tree().change_scene_to_file("res://scenes/farm_plot.tscn")
				return
			get_tree().quit()
			return
		_start(shot + 1)
		sh = shots[shot]
	var u := clampf(shot_t / secs, 0.0, 1.0)
	var s := _train_s(sh, shot_t)
	_train_at(s)
	var v := (_train_s(sh, shot_t + 0.1) - s) / 0.1
	ToaTau.set_sway(0.04 * clampf(v / 10.0, 0.0, 1.0))
	var lp := lead.global_position
	match sh["name"]:
		"trong_ham":
			cam.fov = 50.0
			var f := frame_at(_s_for_x(-935.0))
			cam.global_position = f.origin + f.basis.x * 3.4 + Vector3(0, 1.3, 0)
			cam.look_at(f.origin - f.basis.z * 30.0 + Vector3(0, 1.6, 0), Vector3.UP)
		"ra_ham":
			cam.fov = 46.0

			var f := frame_at(s - 31.0)
			var k := smoothstep(0.35, 1.0, u)
			cam.global_position = f.origin + Vector3(0, 2.9 + 52.0 * k * k, 0) - f.basis.x * 22.0 * k - f.basis.z * 10.0 * k
			var look_far := Vector3(-560.0, home.height_at(-560.0, -20.0) + 4.0, -20.0)
			cam.look_at((lp + Vector3(0, 2.2, 0) + f.basis.z * 20.0).lerp(look_far, smoothstep(0.3, 1.0, u)), Vector3.UP)
		"toi_ga":
			cam.fov = 40.0
			var plat := _platform_y()
			cam.global_position = Vector3(-684.5, plat + 1.7, -45.0)
			cam.look_at(Vector3(-702.0, plat + 1.2, -50.5), Vector3.UP)
			var stop_t := -float(sh["v"]) / float(sh["acc"])
			if shot_t > stop_t + 0.8:
				ToaTau.set_doors(lead, clampf((shot_t - stop_t - 0.8) / 0.9, 0.0, 1.0), -1)
			_hero_steps(shot_t - stop_t - 1.9, plat)
			if shot_t > stop_t + 2.4 and not _waved:
				_waved = true
				bo.play("Emo_Wave", 0.2)
			if _waved:
				var to_hero := hero.global_position - bo.global_position
				to_hero.y = 0.0
				if to_hero.length() > 0.5:
					bo.global_basis = bo.global_basis.slerp(Basis.looking_at(-to_hero.normalized()), minf(1.0, delta * 3.0))
	home.player.global_position = _anchor()
	if png != "" and Engine.get_process_frames() == 12:
		get_viewport().get_texture().get_image().save_png(png)
		get_tree().quit()

func _anchor() -> Vector3:
	var p := cam.global_position - cam.global_basis.z * 20.0
	return Vector3(p.x, home.height_at(p.x, p.z) - 3.0, p.z)

func _hero_steps(t: float, plat: float) -> void:
	if t < 0.0:
		hero.visible = false
		return
	hero.visible = true
	var door: float = ToaTau.DOORS[0]
	var inside := lead.to_global(Vector3(-0.5, ToaTau.FL, door))
	var sill := lead.to_global(Vector3(-ToaTau.W / 2.0 + 0.1, ToaTau.FL, door))
	var down := lead.to_global(Vector3(-ToaTau.W / 2.0 - 0.9, 0, door))
	down.y = plat
	var toward := Vector3(-693.2, plat, -50.0)
	var out_dir := (down - inside)
	out_dir.y = 0.0
	var pos: Vector3
	var face := out_dir.normalized()
	if t < 0.9:
		pos = inside.lerp(sill, t / 0.9)
		hero.play("Move_Walk", 0.15)
	elif t < 1.4:
		var k := (t - 0.9) / 0.5
		pos = sill.lerp(down, k)
		pos.y += sin(k * PI) * 0.18
	elif t < 2.4:
		pos = down
		hero.play("Base_Wait", 0.2)
	else:
		var walk := toward - down
		var d := minf((t - 2.4) * 1.1, walk.length())
		pos = down + walk.normalized() * d
		face = walk.normalized()
		hero.play("Move_Walk" if d < walk.length() else "Base_Wait", 0.2)
	hero.global_transform = Transform3D(Basis.looking_at(-face), pos)
