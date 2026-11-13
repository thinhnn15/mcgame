class_name BoatRow
extends Node

const VMAX := 3.2
const PUSH := 1.5
const DRAG := 0.35
const STROKE := 1.4
const STEER := 2.0
const LANE := 4.6
const LANE_CAVE := 6.0
const CAVE_PAD := 8.0
const WEAVE := 3.0
const DOT_STEP := 2.5

const DOT_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 boat_pos;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float a = clamp(1.0 - dot(d, d), 0.0, 1.0);
	float k = smoothstep(2.8, 3.8, distance(wp.xz, boat_pos.xz));
	ALBEDO = vec3(1.0, 0.86, 0.55) * a * a * k * (0.75 + 0.25 * sin(TIME * 2.0 + wp.x * 0.7));
}"""

var home: Node3D
var active := false
var dir := 1
var s := 0.0
var v := 0.0
var lat := 0.0
var vlat := 0.0
var stroke := 0.0
var caves: Array = []
var _say: Label
var _keys: Label
var _arrow: Polygon2D
var _ui: CanvasLayer
var _oar: Node3D
var _dots: MultiMeshInstance3D
var _dot_mat: ShaderMaterial
var _moved: Array = []
var _tip := 0
var _tip_t := 0.0
var _call := ""
var _call_t := 0.0
var _bump_t := 0.0
var _bump_say := -99.0
var _said_listen := false
var _clock := 0.0
var _auto := ""
var _shot_s := 0.0
var _cave_k := 0.0
var _cam_on := false
var _cam_at := Vector3.ZERO

static func add(home_: Node3D) -> void:
	if not OS.get_cmdline_user_args().has("--row") or home_.get("boat") == null:
		return
	var n := BoatRow.new()
	n.name = "BoatRow"
	n.home = home_
	home_.add_child(n)
	n._setup()
	if Stage.arg("--row-auto") != "":
		n._auto = Stage.arg("--row-auto")
		Engine.time_scale = 2.0
		home_.player.global_position = Vector3(150, home_.height_at(150, 108) + 0.3, 108)
		n.start.call_deferred()

static var _flow_tex: Texture2D
static var _flow_rect := Vector4.ZERO
static var _wake_at := Vector2.INF
static var _wake_on := false

static func water2(m: ShaderMaterial, dir_: String) -> void:
	if OS.get_environment("MC_WATER2_OLD") == "1":
		return
	if _flow_tex == null:
		var png := dir_ + "water_flow.png"
		if not (FileAccess.file_exists(png) or ResourceLoader.exists(png)) or not FileAccess.file_exists(dir_ + "water_flow.json"):
			return
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir_ + "water_flow.json"))
		_flow_rect = Vector4(j["x0"], j["z0"], 1.0 / (float(j["w"]) * float(j["px"])), 1.0 / (float(j["h"]) * float(j["px"])))
		_flow_tex = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(png))) 			if not TexCache.shipped() else load(png) as Texture2D
	m.set_shader_parameter("water2", true)
	m.set_shader_parameter("flow_tex", _flow_tex)
	m.set_shader_parameter("flow_rect", _flow_rect)

static func wake(home_: Node3D, delta: float) -> void:
	var test := OS.get_environment("MC_WAKE")
	if test != "":
		var f := test.replace("/", ",").split_floats(",")
		if f.size() == 4 and not _wake_on:
			RenderingServer.global_shader_parameter_set("boat_wake", Vector4(f[0], f[1], deg_to_rad(f[2]), f[3]))
			_wake_on = true
		return
	var b: Node3D = home_.get("boat")
	var p := Vector2(b.global_position.x, b.global_position.z)
	var v := 0.0 if _wake_at == Vector2.INF or delta <= 0.0 else p.distance_to(_wake_at) / delta
	_wake_at = p
	if v > 0.15 and v < 20.0:
		RenderingServer.global_shader_parameter_set("boat_wake", Vector4(p.x, p.y, b.rotation.y, v))
		_wake_on = true
	elif _wake_on:
		RenderingServer.global_shader_parameter_set("boat_wake", Vector4.ZERO)
		_wake_on = false

static func busy(home_: Node3D) -> bool:
	var n := home_.get_node_or_null("BoatRow") as BoatRow
	return n != null and n.active

static func take(home_: Node3D) -> bool:
	var n := home_.get_node_or_null("BoatRow") as BoatRow
	if n == null:
		return false
	n.start()
	return true

func _setup() -> void:
	var len_: float = home.boat_len
	for c: Dictionary in home.layout.get("caves", []):
		var a := _s_near(Vector2(c["from"][0], c["from"][1]), len_)
		var b := _s_near(Vector2(c["to"][0], c["to"][1]), len_)
		caves.append([minf(a, b), maxf(a, b), 1.0 if caves.size() % 2 == 0 else -1.0])

	var xs: Array[Transform3D] = []
	for c: Array in caves:
		var d: float = c[0] - 2.0
		while d <= c[1] + 2.0:
			var at: Array = home._route_at(d)
			var dv: Vector3 = at[1]
			xs.append(Transform3D(Basis(), (at[0] as Vector3) + Vector3(-dv.z, 0, dv.x) * _guide(d) + Vector3(0, -0.02, 0)))
			d += DOT_STEP
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	q.orientation = PlaneMesh.FACE_Y
	mm.mesh = q
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	_dot_mat = ShaderMaterial.new()
	_dot_mat.shader = Shader.new()
	_dot_mat.shader.code = DOT_SHADER
	_dots = MultiMeshInstance3D.new()
	_dots.multimesh = mm
	_dots.material_override = _dot_mat
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dots.visible = false
	home.add_child(_dots)

	_oar = Node3D.new()
	Props.mesh(_oar, Props.cyl(0.035, 0.035, 2.6), Color("7a5a3a"), Vector3(0, -0.9, 0))
	Props.mesh(_oar, Props.box(Vector3(0.05, 0.6, 0.22)), Color("8a6a48"), Vector3(0, -2.1, 0))
	_oar.position = Vector3(-0.5, 0.75, -1.45)
	_oar.visible = false
	home.boat.add_child(_oar)

	_ui = CanvasLayer.new()
	_ui.layer = 5
	_ui.visible = false
	home.add_child(_ui)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.position.y -= 70
	box.alignment = BoxContainer.ALIGNMENT_END
	_ui.add_child(box)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(80, 70)
	box.add_child(holder)
	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([Vector2(0, -26), Vector2(22, 16), Vector2(-22, 16)])
	_arrow.color = Color(1.0, 0.93, 0.75, 0.95)
	_arrow.position = Vector2(40, 35)
	_arrow.visible = false
	holder.add_child(_arrow)
	_say = _label(30)
	box.add_child(_say)
	_keys = _label(22)
	_keys.modulate = Color(1, 1, 1, 0.8)
	box.add_child(_keys)

func _label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("fffaf2"))
	l.add_theme_color_override("font_outline_color", Color("5b4a44"))
	l.add_theme_constant_override("outline_size", 10)
	return l

func _s_near(p: Vector2, len_: float) -> float:
	var best := 0.0
	var bd := INF
	var d := 0.0
	while d <= len_:
		var at: Vector3 = home._route_at(d)[0]
		var dd := Vector2(at.x, at.z).distance_squared_to(p)
		if dd < bd:
			bd = dd
			best = d
		d += 1.0
	return best

func _guide(d: float) -> float:
	for c: Array in caves:
		if d > c[0] - CAVE_PAD and d < c[1] + CAVE_PAD:
			var u: float = (d - (c[0] - CAVE_PAD)) / (c[1] - c[0] + 2.0 * CAVE_PAD)
			return WEAVE * float(c[2]) * sin(u * TAU)
	return 0.0

func _cave_at(d: float) -> int:
	for i in caves.size():
		if d > caves[i][0] - CAVE_PAD and d < caves[i][1] + CAVE_PAD:
			return i
	return -1

func start() -> void:
	if active:
		return
	active = true
	s = home.boat_s
	dir = 1 if s < home.boat_len * 0.5 else -1
	v = 0.0
	lat = 0.0
	vlat = 0.0
	stroke = 0.0
	_tip = 0
	_tip_t = 0.0
	_call = ""
	_said_listen = false
	_cam_on = false
	home.boat_hint.text = ""
	home.player.set_physics_process(false)
	home.player.set_sitting(true)

	_moved.clear()
	for c in home.boat.get_children():
		if c != _oar and c is Node3D and (c as Node3D).position.z < -1.5:
			_moved.append([c, (c as Node3D).position])
			if c is MeshInstance3D and (c as MeshInstance3D).rotation_degrees.x > 30.0:
				(c as Node3D).visible = false
			else:
				(c as Node3D).position = Vector3(0, (c as Node3D).position.y - 0.45, 2.1)
	_oar.visible = true
	_dots.visible = true
	_ui.visible = true
	_keys.text = tr("CHEO_KEYS")
	_show(tr("CHEO_TIP_PUSH"))

func _dock() -> void:
	active = false
	s = clampf(s, 0.0, home.boat_len)
	home.boat_s = 0.0 if s < home.boat_len * 0.5 else home.boat_len
	home.boat_dir = 0
	for e: Array in _moved:
		(e[0] as Node3D).position = e[1]
		(e[0] as Node3D).visible = true
	_moved.clear()
	_oar.visible = false
	_dots.visible = false
	_ui.visible = false
	var p: Player = home.player
	p.set_sitting(false)
	var off := Vector3(498, 0, 312) if home.boat_s > 0.0 else Vector3(150, 0, 108)
	p.global_position = Vector3(off.x, home.height_at(off.x, off.z) + 0.3, off.z)
	p.set_physics_process(true)
	if _auto != "":
		get_tree().quit()

func _show(text: String) -> void:
	_say.text = tr("CAST_CHU_TU") + ": " + text if text != "" else ""

func _process(delta: float) -> void:
	if not active:
		return
	_clock += delta
	var iv := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if _auto != "":
		iv = Vector2(clampf((_guide(s + 6.0 * dir) - lat) * dir * 0.6 + 0.6 * sin(_clock * 0.7), -1.0, 1.0), -1.0)
		if s >= _shot_s:
			_shot_s += 25.0
			get_viewport().get_texture().get_image().save_png("%s/row_%03d.png" % [_auto, int(s)])
	var fwd := -iv.y
	var side := iv.x

	if fwd > 0.1:
		var before := stroke
		stroke += delta / STROKE
		v += PUSH * fwd * (0.4 + 1.2 * maxf(0.0, sin(stroke * TAU))) * delta
		if floorf(stroke) != floorf(before) and has_node("/root/Sound"):
			get_node("/root/Sound").play_at("water.plop", home.boat.global_position, -12.0, randf_range(0.9, 1.1))
	elif fwd < -0.1:
		v -= 1.6 * delta
	v -= v * DRAG * delta
	v = clampf(v, -0.6, VMAX)
	s += dir * v * delta
	if (dir == 1 and s >= home.boat_len) or (dir == -1 and s <= 0.0):
		_dock()
		return
	if s < 0.0 or s > home.boat_len:
		s = clampf(s, 0.0, home.boat_len)
		v = 0.0

	var want := side * STEER * dir * (0.45 + 0.55 * clampf(absf(v) / 1.5, 0.0, 1.0))
	vlat = lerpf(vlat, want, clampf(3.0 * delta, 0.0, 1.0))
	lat += vlat * delta
	var cave := _cave_at(s)
	var lane := LANE_CAVE if cave >= 0 else LANE
	_bump_t -= delta
	if absf(lat) > lane:
		lat = signf(lat) * lane
		if absf(vlat) > 0.5 and _bump_t <= 0.0:
			_bump_t = 1.0
			v *= 0.6
			if has_node("/root/Sound"):
				get_node("/root/Sound").play_at("nature.creak", home.boat.global_position, -4.0)
			if _clock - _bump_say > 25.0:
				_bump_say = _clock
				_show(tr("CHEO_BUMP"))
				_call_t = 2.5
		vlat = -vlat * 0.4

	var at: Array = home._route_at(s)
	var d: Vector3 = at[1]
	var right := Vector3(-d.z, 0, d.x)
	var head := d * float(dir)
	var tt: float = home.t
	home.boat.global_position = (at[0] as Vector3) + right * lat + Vector3(0, 0.03 * sin(tt * 1.7), 0)
	var yaw := atan2(head.x, head.z) - vlat * dir * 0.09
	var sw := sin(stroke * TAU)
	home.boat.rotation = Vector3(0.01 * sin(tt * 1.3), yaw, 0.015 * sin(tt * 1.1) + 0.012 * sw * clampf(fwd, 0.0, 1.0))

	_oar.rotation = Vector3(deg_to_rad(63.0 - 8.0 * sw), deg_to_rad(12.0 * cos(stroke * TAU)), 0)
	var p: Player = home.player
	p.global_position = home.boat.global_position + home.boat.global_basis * Vector3(0, 0.45, -1.6)
	p.facing = yaw
	p.rotation.y = yaw
	_dot_mat.set_shader_parameter("boat_pos", home.boat.global_position)
	_camera(delta, cave >= 0, head)
	_talk(delta, cave)

func _camera(delta: float, in_cave: bool, head: Vector3) -> void:
	_cave_k = move_toward(_cave_k, 1.0 if in_cave else 0.0, delta * 0.6)
	var back := lerpf(7.0, 5.5, _cave_k)
	var up := lerpf(2.8, 2.0, _cave_k)
	var bp: Vector3 = home.boat.global_position
	var want := bp - head * back + Vector3(0, up, 0)
	var cam: Camera3D = home.cam

	_cam_at = _cam_at.lerp(want, 1.0 - exp(-delta * 3.0)) if _cam_on else want
	_cam_on = true
	cam.global_position = _cam_at
	cam.look_at(bp + head * 5.0 + Vector3(0, 0.8, 0), Vector3.UP)

func _talk(delta: float, cave: int) -> void:
	_call_t -= delta
	var iv := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if _tip == 0:
		_tip_t += delta if iv.y < -0.1 else 0.0
		if _tip_t > 2.0:
			_tip = 1
			_tip_t = 0.0
			_show(tr("CHEO_TIP_STEER"))
	elif _tip == 1:
		_tip_t += delta if absf(iv.x) > 0.1 else 0.0
		if _tip_t > 1.0:
			_tip = 2
			_show("")
	if cave < 0:
		_arrow.visible = false
		if _call != "" and _call_t <= 0.0:
			_call = ""
			_show("")
		return
	if not _said_listen:
		_said_listen = true
		_tip = 2
		_show(tr("CHEO_TIP_LISTEN"))
		_call_t = 3.0
		return
	var err := (_guide(s) - lat) * dir
	var want := "CHEO_STRAIGHT" if absf(err) < 1.2 else ("CHEO_RIGHT" if err > 0.0 else "CHEO_LEFT")
	if want != _call and _call_t <= 0.0:
		_call = want
		_call_t = 1.4
		_show(tr(want))
	_arrow.visible = true
	_arrow.rotation = 0.0 if _call == "CHEO_STRAIGHT" else (PI / 2.0 if _call == "CHEO_RIGHT" else -PI / 2.0)
