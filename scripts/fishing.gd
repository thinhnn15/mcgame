extends Node3D

const ISLAND_R := 6.0
const WATER_Y := -0.35
const CAST := 3.0
const TOOL_CLIPS := "res://data/tool_clips.json"
const FLOAT := "res://characters/tools/rod_float.glb"
const FISH := "res://characters/tools/fish.glb"

const ROD_TIP := Vector3(-0.53, -1.47, 0.782)

const COLORS := {"mFloatRed": Color("ef4f4f"), "mFloatWhite": Color("fbfbf4"), "mFishBody": Color("8fb3c9"),
	"mFishFin": Color("6f93ad"), "mFishEye": Color("2b2a33")}
const FISH_KEYS := ["FISH_ROPHI", "FISH_CARP", "FISH_CRUCIAN", "FISH_SILVER", "FISH_GRASS"]

var player: Player
var cam: Camera3D
var cam_off := Vector3(-3.6, 3.0, 2.8)
var sea_mat: ShaderMaterial
var bob: Node3D
var line: MeshInstance3D
var line_mesh := ImmediateMesh.new()
var bang: Label3D
var say: Label3D
var state := "carry"
var land := Vector3.ZERO
var fly_from := Vector3.ZERO
var fly_t := -1.0
var fly_len := 0.55
var fly_to_tip := false
var t := 0.0
var state_t := 0.0
var bite_at := 0.0
var nibbles: Array = []
var window := 0.9
var release_f := 23
var fish_out_f := 18
var auto := false

func _ready() -> void:
	Stage.setup(self)
	var tc = JSON.parse_string(FileAccess.get_file_as_string(TOOL_CLIPS)) if FileAccess.file_exists(TOOL_CLIPS) else null
	if tc is Dictionary and tc.has("_events"):
		release_f = int(tc["_events"]["Tool_Rod_Swing"]["release"])
		fish_out_f = int(tc["_events"]["Tool_Rod_Catch"]["fish_out"])
	var grass := MeshInstance3D.new()
	grass.mesh = Props.cyl(ISLAND_R, ISLAND_R + 0.3, 1.0)
	grass.material_override = Props.mat(Color("9fdc7c"))
	grass.position.y = -0.5
	add_child(grass)
	Props.solid(self, WorldBoundaryShape3D.new(), Vector3.ZERO)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	pm.subdivide_width = 80
	pm.subdivide_depth = 80
	sea.mesh = pm
	sea_mat = ShaderMaterial.new()
	sea_mat.shader = preload("res://shaders/sea.gdshader")
	sea_mat.set_shader_parameter("shore_r", ISLAND_R + 0.2)
	sea.material_override = sea_mat
	sea.position.y = WATER_Y
	add_child(sea)
	cam = Camera3D.new()
	cam.fov = 44.0
	add_child(cam)
	player = Player.new()
	add_child(player)
	player.position = Vector3(0, 0, ISLAND_R - 0.55)
	player.rotation.y = 0.0
	player.setup(Looks.load_saved(), cam)
	player.chibi.hold("rod")
	player.chibi.set_part("fish", FISH)
	_paint(player.chibi.parts.get("tool", []) + player.chibi.parts.get("fish", []))
	_show_fish(false)
	player.tool_pressed.connect(press)
	bob = load(FLOAT).instantiate()
	add_child(bob)
	_paint(bob.find_children("*", "MeshInstance3D", true, false))
	line = MeshInstance3D.new()
	line.mesh = line_mesh
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1, 1, 1, 0.85)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	line.material_override = lm
	add_child(line)
	bang = _label("!", 150, Color("e8453c"))
	say = _label("", 54, Color("5b4a44"))
	var hint := Label.new()
	hint.text = tr("HINT_FISH")
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color("5b4a44"))
	hint.position = Vector2(24, 18)
	var layer := CanvasLayer.new()
	layer.add_child(hint)
	add_child(layer)
	var co := Stage.arg("--cam")
	if co != "":
		var v := co.split_floats(",")
		cam_off = Vector3(v[0], v[1], v[2])
	_place_camera(1.0)
	if OS.get_cmdline_user_args().has("--auto"):
		auto = true
		_demo()

func _label(text: String, size: int, c: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.outline_size = 18
	l.modulate = c
	l.outline_modulate = Color("fffaf2")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.visible = false
	add_child(l)
	return l

func _paint(meshes: Array) -> void:
	for mi in meshes:
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(s)
			var name := src.resource_name if src else ""
			if not COLORS.has(name):
				continue
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m == null:
				m = ShaderMaterial.new()
				m.shader = Props.TOON
				mi.set_surface_override_material(s, m)
			m.set_shader_parameter("base_color", COLORS[name])

func _show_fish(on: bool) -> void:
	for mi in player.chibi.parts.get("fish", []):
		mi.visible = on
	for mi in player.chibi.parts.get("tool", []):
		mi.visible = not on

func _tip() -> Vector3:
	return player.chibi.posed_point("Z_Pole", ROD_TIP)

func _fwd() -> Vector3:
	return Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))

func _anim() -> AnimationPlayer:
	return player.chibi.anim

func press() -> void:
	match state:
		"carry":
			_cast()
		"wait":
			_strike(false)
		"bite":
			_strike(true)
		"show":
			_bag()

func _cast() -> void:
	state = "cast"
	state_t = 0.0
	player.chibi.play("Tool_Rod_Aim", 0.0)
	_anim().play("Tool_Rod_Swing", 0.1)
	_anim().queue("Tool_Rod_Aim")
	land = player.global_position + _fwd() * CAST
	land.y = WATER_Y
	await get_tree().create_timer(float(release_f) / 30.0).timeout
	_fly(_tip(), land, 0.55, false)
	await get_tree().create_timer(0.55).timeout
	_splash(land, 8)
	state = "wait"
	state_t = 0.0

	bite_at = 2.0 if auto else randf_range(3.0, 6.5)
	nibbles = [bite_at - 1.6, bite_at - 0.8] if auto else [bite_at - randf_range(1.2, 1.8), bite_at - randf_range(0.5, 0.8)]

func _strike(hooked: bool) -> void:
	state = "strike"
	bang.visible = false
	_anim().play("Tool_Rod_Catch" if hooked else "Tool_Rod_Air", 0.08)
	if not hooked:
		_anim().queue("Base_Wait")
		player.chibi.play("Base_Wait", 0.0)
		await get_tree().create_timer(0.23).timeout
		_fly(bob.global_position, Vector3.ZERO, 0.35, true)
		await get_tree().create_timer(0.6).timeout
		state = "carry"
		return
	await get_tree().create_timer(float(fish_out_f) / 30.0).timeout
	_splash(bob.global_position, 14)
	_fly(bob.global_position, Vector3.ZERO, 0.3, true)
	await get_tree().create_timer(1.0 - float(fish_out_f) / 30.0).timeout

	state = "show"
	_show_fish(true)
	bob.visible = false
	_anim().play("Tool_Rod_Get", 0.1)
	_anim().queue("Tool_Rod_GetKeep")
	player.chibi.play("Tool_Rod_GetKeep", 0.0)
	player.chibi.emote("proud")
	say.text = Lang.t("FISH_CAUGHT", {"fish": tr(FISH_KEYS[randi() % FISH_KEYS.size()])})
	say.visible = true

func _bag() -> void:
	state = "bag"
	say.visible = false
	_show_fish(false)
	for mi in player.chibi.parts.get("tool", []):
		mi.visible = false
	_anim().play("Tool_Rod_Putback", 0.12)
	_anim().queue("Base_Wait")
	player.chibi.play("Base_Wait", 0.0)
	await get_tree().create_timer(0.15).timeout
	for mi in player.chibi.parts.get("tool", []):
		mi.visible = true
	bob.visible = true
	await get_tree().create_timer(0.7).timeout
	state = "carry"

func _fly(from: Vector3, to: Vector3, secs: float, to_tip: bool) -> void:
	"""The float on an arc from `from` to `to` (or back to the rod's tip)."""
	fly_from = from
	land = to if not to_tip else land
	fly_len = secs
	fly_t = 0.0
	fly_to_tip = to_tip

func _splash(at: Vector3, n: int) -> void:
	var p := CPUParticles3D.new()
	var s := Props.sphere(0.035)
	s.material = Props.mat(Color("ffffff"))
	p.mesh = s
	p.amount = n
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.6
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -6, 0)
	add_child(p)
	p.global_position = at + Vector3(0, 0.02, 0)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func _demo() -> void:
	"""A cast, two nibbles, the bite struck, the fish shown and bagged; then a cast struck too early; quit."""
	var tm := func(s: float): return get_tree().create_timer(s).timeout
	await tm.call(0.8)
	press()
	while state != "bite":
		await tm.call(0.05)
	await tm.call(0.3)
	press()
	while state != "show":
		await tm.call(0.05)
	await tm.call(2.4)
	press()
	await tm.call(1.6)
	press()
	while state != "wait":
		await tm.call(0.05)
	await tm.call(0.9)
	press()
	await tm.call(1.8)
	get_tree().quit()

func _process(delta: float) -> void:
	t += delta
	state_t += delta
	sea_mat.set_shader_parameter("t", t)
	_place_camera(1.0 - exp(-delta * 5.0))
	var tip := _tip()
	var surface := WATER_Y + 0.02 * sin(t * 2.1)
	var slack := 1.0
	if fly_t >= 0.0:
		fly_t += delta
		var k := minf(1.0, fly_t / fly_len)
		var to := tip + Vector3(0, -0.22, 0) if fly_to_tip else land
		var p := fly_from.lerp(to, k)
		p.y += sin(k * PI) * (1.1 if not fly_to_tip else 0.5)
		bob.global_position = p
		slack = 0.4
		if k >= 1.0:
			fly_t = -1.0
	elif state in ["wait", "bite"]:
		var y := surface
		for n in nibbles:
			var a: float = state_t - n
			if a > 0.0 and a < 0.3:
				y -= 0.045 * sin(a / 0.3 * PI)
				if a < delta * 1.5:
					_splash(land, 3)
		if state == "wait" and state_t >= bite_at:
			state = "bite"
			_splash(land, 12)
			bang.visible = true
		if state == "bite":
			var a := state_t - bite_at
			y = surface - 0.13 * minf(1.0, a / 0.12)
			if a > window:
				state = "wait"
				bang.visible = false
				state_t = 0.0
				bite_at = 2.5 if auto else randf_range(3.0, 6.0)
				nibbles = [bite_at - 0.8]
		bob.global_position = Vector3(land.x, y, land.z)
		slack = 0.5
	elif state == "strike":
		slack = 0.05
	else:
		var sway := Vector3(sin(t * 1.7), 0, cos(t * 1.3)) * 0.015
		bob.global_position = bob.global_position.lerp(tip + Vector3(0, -0.22, 0) + sway, 1.0 - exp(-delta * 12.0))
		slack = 0.1
	bang.global_position = player.global_position + Vector3(0, 1.85, 0)
	say.global_position = player.global_position + Vector3(0, 1.95, 0)
	_draw_line(tip, bob.global_position + Vector3(0, 0.1, 0), slack)

func _draw_line(a: Vector3, b: Vector3, slack: float) -> void:
	"""The fishing line: a thin ribbon facing the camera, sagging by `slack` between the tip and the float."""
	line_mesh.clear_surfaces()
	if not bob.visible:
		return
	var sag := Vector3(0, -a.distance_to(b) * 0.18 * slack, 0)
	var ctrl := (a + b) * 0.5 + sag
	line_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := 16
	for i in n + 1:
		var k := float(i) / n
		var p := a.lerp(ctrl, k).lerp(ctrl.lerp(b, k), k)
		var nxt := a.lerp(ctrl, minf(1.0, k + 0.05)).lerp(ctrl.lerp(b, minf(1.0, k + 0.05)), minf(1.0, k + 0.05))
		var dir := (nxt - p).normalized() if k < 1.0 else (b - ctrl).normalized()
		var side := dir.cross(cam.global_position - p).normalized() * 0.004
		line_mesh.surface_add_vertex(p - side)
		line_mesh.surface_add_vertex(p + side)
	line_mesh.surface_end()

func _place_camera(k: float) -> void:
	var target := player.global_position + Vector3(0, 0.45, 0) + _fwd() * 1.7
	var want := player.global_position + Basis(Vector3.UP, player.rotation.y) * cam_off
	cam.global_position = cam.global_position.lerp(want, k)
	cam.look_at(target, Vector3.UP)
