class_name Footprints
extends Node3D

const POOL := 96
const LIFE := 9.0
const NEAR := 22.0
const SOFT := {2: Color(0.36, 0.28, 0.19), 3: Color(0.55, 0.43, 0.29), 5: Color(0.58, 0.47, 0.31),
	7: Color(0.45, 0.35, 0.24), 13: Color(0.27, 0.19, 0.13)}
const ALPHA := 0.55
const PLANT := 0.07
const RUN := 2.6

var ground: Callable
var kind_at: Callable
var centre: Node3D
var _mm: MultiMesh
var _born := PackedFloat32Array()
var _col := PackedColorArray()
var _next := 0
var _now := 0.0
var _feet := []

func _ready() -> void:
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.21)
	q.orientation = PlaneMesh.FACE_Y
	_mm.mesh = q
	_mm.instance_count = POOL
	_born.resize(POOL)
	_col.resize(POOL)
	for i in POOL:
		_born[i] = -1e9
		_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -1000, 0)))
		_mm.set_instance_color(i, Color(0, 0, 0, 0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _print_tex()
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-5000, -500, -5000), Vector3(10000, 1000, 10000))
	add_child(mi)

func track(c: Chibi) -> void:
	"""Watch this character's feet."""
	if c == null or c.skel == null:
		return
	for side in ["L", "R"]:
		var b := c.skel.find_bone("Ankle_" + side)
		if b < 0:
			continue
		_feet.append({"c": c, "side": side, "bone": b, "base": -1.0, "last": Vector3.INF,
			"prev_root": c.global_position, "speed": 0.0})

func _process(delta: float) -> void:
	_now += delta
	for i in POOL:
		var age := _now - _born[i]
		if age < LIFE + 0.1:
			var col := _col[i]
			col.a = ALPHA * clampf(1.0 - (age - LIFE * 0.5) / (LIFE * 0.5), 0.0, 1.0)
			_mm.set_instance_color(i, col)
	for f: Dictionary in _feet:
		var c: Chibi = f["c"]
		if not is_instance_valid(c) or not c.is_visible_in_tree():
			continue
		if centre != null and c.global_position.distance_to(centre.global_position) > NEAR:
			continue
		var mv: Vector3 = c.global_position - f["prev_root"]
		mv.y = 0.0
		f["prev_root"] = c.global_position
		if delta > 0.0:
			f["speed"] = lerpf(f["speed"], mv.length() / delta, 0.1)
		var ankle := c.skel.global_transform * c.skel.get_bone_global_pose(f["bone"]).origin
		var h := ankle.y - c.global_position.y
		if f["base"] < 0.0:
			f["base"] = (c.skel.global_transform * c.skel.get_bone_global_rest(f["bone"]).origin).y - c.global_position.y

		var prev: float = f.get("prev_h", h)
		if h < prev - 0.0005:
			f["falling"] = true
		elif f.get("falling", false) and h >= prev:
			f["falling"] = false
			if prev < f["base"] + PLANT and f["speed"] > 0.3:
				_step(c, f, f.get("prev_ankle", ankle))
		f["prev_h"] = h
		f["prev_ankle"] = ankle

func _step(c: Chibi, f: Dictionary, ankle: Vector3) -> void:
	var kind: int = kind_at.call(ankle.x, ankle.z) if kind_at.is_valid() else -1
	if not SOFT.has(kind):
		return
	var yaw := c.global_rotation.y
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var at := ankle + fwd * 0.03
	at.y = (ground.call(at.x, at.z) if ground.is_valid() else c.global_position.y) + 0.012
	if f["last"] != Vector3.INF and (f["last"] as Vector3).distance_to(at) < 0.12:
		return
	f["last"] = at
	var i := _next
	_next = (_next + 1) % POOL
	var col: Color = SOFT[kind]
	_col[i] = Color(col.r, col.g, col.b, ALPHA)
	_born[i] = _now
	_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), at))
	_mm.set_instance_color(i, _col[i])
	if f["speed"] > RUN:
		Chores._dust(c, at, col.lerp(Color.WHITE, 0.45))

static var _tex: Texture2D

static func _print_tex() -> Texture2D:
	"""A soft sole print: the ball of the foot and the heel, white with alpha (the colour comes per print)."""
	if _tex != null:
		return _tex
	var w := 32
	var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := (y + 0.5) / h
			var ball := Vector2(u / 0.85, (v - 0.32) / 0.27).length()
			var heel := Vector2(u / 0.62, (v - 0.78) / 0.19).length()
			var waist := Vector2(u / 0.55, (v - 0.56) / 0.2).length()
			var d := minf(minf(ball, heel), waist * 1.15)
			var a := clampf((1.0 - d) / 0.35, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex
