extends Node3D

const CELL := 0.55
const PLOT := Vector3(3.3, 0.02, 4.4)
const EARTH := Color("c9a274")
const SOIL := Color("8d5c3e")
const SOIL_DARK := Color("6e4630")
const DUST := Color("e8d6bc")

var player: Player
var cam: Camera3D
var tilled := {}
var shake := 0.0
var cam_off := Vector3(3.2, 1.3, -0.6)
var _step_from := Vector3.ZERO
var _step_dir := Vector3.ZERO
var _stepping := false

func _ready() -> void:
	Stage.setup(self)
	var grass := MeshInstance3D.new()
	grass.mesh = Props.cyl(14.0, 14.0, 1.0)
	grass.material_override = Props.mat(Color("9fdc7c"))
	grass.position.y = -0.5
	add_child(grass)
	Props.solid(self, WorldBoundaryShape3D.new(), Vector3.ZERO)
	Props.mesh(self, Props.box(PLOT), EARTH, Vector3(0, 0.0, 0))
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	player = Player.new()
	add_child(player)
	player.position = Vector3(0, 0, 1.4)
	player.rotation.y = PI
	player.facing = player.rotation.y
	player.setup(Looks.load_saved(), cam)
	player.chibi.hold("hoe")
	player.tool_pressed.connect(stroke)
	var hint := Label.new()
	hint.text = tr("HINT_HOE")
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
		_demo()

func stroke() -> void:
	var c := player.chibi
	var impact := c.use_tool("Tool_Hoe_Hit")
	if impact < 0.0:
		return

	while c.anim.current_animation != "Tool_Hoe_Hit" or c.anim.current_animation_position < impact - 0.001:
		await get_tree().process_frame
		if c.anim.current_animation != "Tool_Hoe_Hit" and c.anim.current_animation_position > 0.5:
			return
	c.hit_stop(0.06)
	shake = 0.05
	var at := c.posed_point("Item", Chibi.HOE_EDGE)
	at.y = 0.02
	var back := player.global_position - at
	back.y = 0.0
	back = back.normalized()
	_clods(at, back)
	_till(at)

func step_back() -> void:
	"""Shuffle back one cell, still bent over the hoe. Chains straight on from the end of a stroke."""
	var c := player.chibi
	var a := c.anim.current_animation
	if _stepping or (a.begins_with("Tool_") and not (a == "Tool_Hoe_Hit" and c.anim.current_animation_position > 0.8)):
		return
	_step_from = player.position
	_step_dir = -Vector3(sin(player.rotation.y), 0.0, cos(player.rotation.y))
	_stepping = true
	c.use_tool("Tool_Hoe_Step")

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_R:
		step_back()
	elif e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_RIGHT_SHOULDER:
		step_back()

func _till(at: Vector3) -> void:
	var k := Vector2i(roundi(at.x / CELL), roundi(at.z / CELL))
	if tilled.has(k):
		return
	var n := Node3D.new()
	add_child(n)
	n.position = Vector3(k.x * CELL, 0.0, k.y * CELL)
	n.rotation.y = player.rotation.y

	Props.mesh(n, Props.sphere(CELL * 0.62), SOIL, Vector3(0, -0.005, 0), Vector3.ZERO, Vector3(1.0, 0.11, 0.95))
	for i in 3:
		var z := (i - 1) * CELL * 0.29 + randf_range(-0.015, 0.015)
		Props.mesh(n, Props.sphere(0.1), SOIL_DARK, Vector3(randf_range(-0.03, 0.03), 0.035, z),
			Vector3(0, randf_range(-6.0, 6.0), 0), Vector3(CELL * 3.6 * randf_range(0.9, 1.0), 0.42, 0.9))
	tilled[k] = n
	n.scale = Vector3(1, 0.05, 1)
	create_tween().tween_property(n, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _clods(at: Vector3, back: Vector3) -> void:
	"""Soil thrown back towards the player and up, then a slow puff of dust."""
	var b := _burst(at, SOIL, Props.sphere(0.03), 14, (back + Vector3(0, 1.6, 0)).normalized(), 2.4, 9.8, 0.55)
	b.spread = 40.0
	var d := _burst(at + Vector3(0, 0.05, 0), DUST, Props.sphere(0.06), 7, Vector3.UP, 0.6, -0.4, 0.8)
	d.spread = 80.0

func _burst(at: Vector3, c: Color, m: Mesh, n: int, dir: Vector3, speed: float, gravity: float, life: float) -> CPUParticles3D:
	"""A one-shot spray of small toon pieces (as scripts/chop_tree.gd)."""
	var p := CPUParticles3D.new()
	p.emitting = false
	(m as PrimitiveMesh).material = Props.mat(c)
	p.mesh = m
	p.amount = n
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = life
	p.direction = dir
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -gravity, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.7, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)
	return p

func _demo() -> void:
	"""A row of four strokes along the field, stepping back after each; quit."""
	var tm := func(s: float): return get_tree().create_timer(s).timeout
	await tm.call(0.8)
	var c := player.chibi
	for i in 4:
		stroke()
		if i < 3:
			await get_tree().process_frame
			while c.anim.current_animation == "Tool_Hoe_Hit" and c.anim.current_animation_position < 0.82:
				await get_tree().process_frame
			step_back()
			await tm.call(0.85)
		else:
			await tm.call(1.0)
	await tm.call(1.2)
	get_tree().quit()

func _place_camera(k: float) -> void:
	var target := player.global_position + Vector3(0, 0.6, -0.3)
	var want := target + cam_off
	cam.global_position = cam.global_position.lerp(want, k)
	cam.look_at(target, Vector3.UP)
	if shake > 0.0:
		cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.25

func _process(delta: float) -> void:
	shake = maxf(0.0, shake - delta)
	if _stepping:

		var a := player.chibi.anim
		var u := 1.0
		if a.current_animation == "Tool_Hoe_Step":
			u = clampf((a.current_animation_position * 30.0 - 1.0) / 24.0, 0.0, 1.0)
		player.position = _step_from + _step_dir * CELL * u
		if a.current_animation != "Tool_Hoe_Step":
			_stepping = false
	_place_camera(1.0 - exp(-delta * 5.0))
