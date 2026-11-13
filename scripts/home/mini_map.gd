class_name MiniMap
extends Control

const TEX := "res://data/hometown/mini_map.png"
const FILE := "user://save/mini_map.json"
const RADII := [60.0, 150.0]
const WORLD := 2048.0
const HOMES := ["nha_bo_me", "trang_trai"]
const ARROW := Color("f08a4b")
const MARK := Color("f6c142")
const HOME := Color("c8664f")
const INK := Color("5b4a44")
const PAPER := Color("fffaf2")

var map: Node3D
var player: Player
var mode := 0
var homes: Array[Vector2] = []

var tex := TEX
var world := WORLD
var radii: Array = RADII
var top := 18.0
var _own_homes := false
var _mat: ShaderMaterial
var _win: ColorRect
var _last := []
var _v := PackedVector2Array()
var _c := PackedColorArray()
var _i := PackedInt32Array()

static func add(parent: Node3D, hero: Player, opts := {}) -> MiniMap:
	if OS.get_cmdline_user_args().has("--no-minimap") or not ResourceLoader.exists(str(opts.get("tex", TEX))):
		return null
	var layer := CanvasLayer.new()
	layer.layer = 4
	layer.name = "MiniMap"
	var m := MiniMap.new()
	m.map = parent
	m.player = hero
	m.tex = str(opts.get("tex", TEX))
	m.world = float(opts.get("world", WORLD))
	m.radii = opts.get("radii", RADII)
	m.top = float(opts.get("top", 18.0))
	if opts.has("homes"):
		m._own_homes = true
		for h: Vector2 in opts["homes"]:
			m.homes.append(h)
	layer.add_child(m)
	parent.add_child(layer)
	return m

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if FileAccess.file_exists(FILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if d is Dictionary:
			mode = clampi(int(d.get("mode", 0)), 0, 2)
	if OS.get_cmdline_user_args().has("--clean"):
		mode = 2
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/mini_map.gdshader")
	_mat.set_shader_parameter("map_tex", load(tex))
	_mat.set_shader_parameter("world", world)
	_win = ColorRect.new()
	_win.material = _mat
	_win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win.show_behind_parent = true
	add_child(_win)
	var lay = JSON.parse_string(FileAccess.get_file_as_string("res://data/hometown/layout.json"))
	for p in lay.get("places", []) if lay is Dictionary and not _own_homes else []:
		if p["id"] in HOMES:
			homes.append(Vector2(p["x"], p["z"]))
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var vp := get_viewport_rect().size
	var d: float = clampf(minf(vp.x, vp.y) * 0.3, 170.0, 300.0)
	size = Vector2(d, d)
	position = Vector2(vp.x - d - 18.0, top)
	_win.size = size
	_last = []

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_M:
		_cycle()
	elif e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_BACK:
		_cycle()

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		if (e.position - size / 2.0).length() <= size.x / 2.0:
			_cycle()
			accept_event()

func _cycle() -> void:
	mode = (mode + 1) % 3
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"mode": mode}))
	_last = []

func _process(_delta: float) -> void:
	var ev := get_tree().get_first_node_in_group("home_events")
	var overview: bool = map.get("fixed_view") and not map.get("measure")
	visible = mode < 2 and player != null and not overview and not (ev and ev.cinematic())
	if not visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var f := -cam.global_basis.z
	var fwd := Vector2(f.x, f.z)
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector2(0, -1)
	var at := Vector2(player.global_position.x, player.global_position.z)
	var marks: Array = ev.map_marks() if ev else []
	var now := [at.snapped(Vector2(0.25, 0.25)), fwd.snapped(Vector2(0.01, 0.01)), snappedf(player.facing, 0.02), marks.size(), mode]
	if now == _last:
		return
	_last = now
	_mat.set_shader_parameter("center", at)
	_mat.set_shader_parameter("fwd", fwd)
	_mat.set_shader_parameter("radius_m", radii[mode])
	queue_redraw()

func _screen(w: Vector2, at: Vector2, fwd: Vector2, clamp_r := 0.8) -> Array:
	"""A world point (x z) on the window: [position, on the rim?]."""
	var o: Vector2 = (w - at) / float(radii[mode])
	var right := Vector2(-fwd.y, fwd.x)
	var d := Vector2(o.dot(right), -o.dot(fwd))
	var rim := d.length() > clamp_r
	if rim:
		d = d.normalized() * clamp_r
	return [size / 2.0 + d * size.x / 2.0, rim]

func _draw() -> void:
	"""Every shape on the window as one triangle list: one draw call (the letter N too: three bars)."""
	if _last.is_empty():
		return
	_v.clear()
	_c.clear()
	_i.clear()
	var at: Vector2 = _last[0]
	var fwd: Vector2 = _mat.get_shader_parameter("fwd")
	var u := size.x / 200.0

	var n: Vector2 = _screen(at + Vector2(0, -1e5), at, fwd, 0.905)[0]
	_disc(n, 8.5 * u, INK)
	var a := 3.0 * u
	var b := 4.2 * u
	var t := 1.1 * u
	_quad([n + Vector2(-a - t, b), n + Vector2(-a - t, -b), n + Vector2(-a + t, -b), n + Vector2(-a + t, b)], PAPER)
	_quad([n + Vector2(a - t, b), n + Vector2(a - t, -b), n + Vector2(a + t, -b), n + Vector2(a + t, b)], PAPER)
	_quad([n + Vector2(-a - t, -b), n + Vector2(-a + t * 1.2, -b), n + Vector2(a + t, b), n + Vector2(a - t * 1.2, b)], PAPER)

	for h in homes:
		var p: Vector2 = _screen(h, at, fwd)[0]
		for e in [[1.6 * u, PAPER], [0.0, HOME]]:
			var k: float = 5.5 * u + e[0]
			_tri(p + Vector2(-k, 0), p + Vector2(0, -k * 1.05), p + Vector2(k, 0), e[1])
			_quad([p + Vector2(-k * 0.75, -0.1 * k), p + Vector2(k * 0.75, -0.1 * k), p + Vector2(k * 0.75, k * 0.8), p + Vector2(-k * 0.75, k * 0.8)], e[1])

	var ev := get_tree().get_first_node_in_group("home_events")
	for m in (ev.map_marks() if ev else []):
		var s: Array = _screen(Vector2(m.x, m.z), at, fwd)
		var p: Vector2 = s[0]
		var k := 6.0 * u
		if s[1]:
			var dir: Vector2 = (p - size / 2.0).normalized()
			_tri(p + dir * (k + 6.0 * u), p + dir.orthogonal() * k * 0.8, p - dir.orthogonal() * k * 0.8, INK)
		_disc(p, k + 1.6 * u, INK)
		_disc(p, k, MARK)

	var face := Vector2(sin(player.facing), cos(player.facing))
	var right := Vector2(-fwd.y, fwd.x)
	var d := Vector2(face.dot(right), -face.dot(fwd)).normalized()
	var c := size / 2.0
	for e in [[2.2 * u, PAPER], [0.0, ARROW]]:
		var k: float = 9.0 * u + e[0]
		var tip := c + d * k
		var notch: Vector2 = c - d * (9.0 * u * 0.25 - e[0] * 0.3)
		_tri(tip, c - d * k * 0.6 + d.orthogonal() * k * 0.7, notch, e[1])
		_tri(tip, notch, c - d * k * 0.6 - d.orthogonal() * k * 0.7, e[1])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _i, _v, _c)

func _tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var o := _v.size()
	_v.append_array([a, b, c])
	_c.append_array([col, col, col])
	_i.append_array([o, o + 1, o + 2])

func _quad(p: Array, col: Color) -> void:
	_tri(p[0], p[1], p[2], col)
	_tri(p[0], p[2], p[3], col)

func _disc(p: Vector2, r: float, col: Color) -> void:
	var o := _v.size()
	_v.append(p)
	_c.append(col)
	for j in 18:
		_v.append(p + Vector2.from_angle(TAU * j / 18.0) * r)
		_c.append(col)
		_i.append_array([o, o + 1 + j, o + 1 + (j + 1) % 18])
