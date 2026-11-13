extends RefCounted

const TOON := preload("res://shaders/intro_toon.gdshader")
const WINDOW := preload("res://shaders/intro_window.gdshader")
const MAX_SRC := 40
const FURN := "res://props/furniture/"

var root: Node3D
var src_pos: Array[Vector4] = []
var src_col: Array[Vector4] = []
var lit_mats: Array[ShaderMaterial] = []
var window_mats: Array[ShaderMaterial] = []
var foliage_mats: Array[ShaderMaterial] = []
var drip_pts := PackedVector3Array()
var hit_pts := PackedVector3Array()
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _quads := {}
var _halo_tex: GradientTexture2D

func _init(r: Node3D) -> void:
	root = r

func add_source(pos: Vector3, radius: float, c: Color, strength: float) -> void:
	if src_pos.size() >= MAX_SRC:
		push_warning("city_kit: more than %d light sources" % MAX_SRC)
		return
	src_pos.append(Vector4(pos.x, pos.y, pos.z, radius))
	src_col.append(Vector4(c.r, c.g, c.b, strength))

func register(m: ShaderMaterial) -> ShaderMaterial:
	lit_mats.append(m)
	return m

func finish() -> void:
	var p := PackedVector4Array()
	var c := PackedVector4Array()
	for i in MAX_SRC:
		p.append(src_pos[i] if i < src_pos.size() else Vector4(0, -999, 0, 0.001))
		c.append(src_col[i] if i < src_col.size() else Vector4.ZERO)
	for m in lit_mats:
		m.set_shader_parameter("src_pos", p)
		m.set_shader_parameter("src_col", c)
		m.set_shader_parameter("src_n", src_pos.size())

func set_flash(e: float) -> void:
	for m in window_mats:
		m.set_shader_parameter("flash", e)

func drip_edge(a: Vector3, b: Vector3, spacing := 0.3) -> void:
	var n := maxi(1, int(a.distance_to(b) / spacing))
	for i in n:
		drip_pts.append(a.lerp(b, (i + _rng.randf()) / n) + Vector3(0, -0.02, 0))

func hit_area(centre: Vector3, size: Vector2, n: int, yaw := 0.0) -> void:
	for i in n:
		var o := Vector3(_rng.randf_range(-0.5, 0.5) * size.x, 0.0, _rng.randf_range(-0.5, 0.5) * size.y)
		hit_pts.append(centre + o.rotated(Vector3.UP, deg_to_rad(yaw)))

func hit_dome(centre: Vector3, radii: Vector3, n: int) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 0.92
		var y := sqrt(maxf(0.0, 1.0 - r * r))
		hit_pts.append(centre + Vector3(cos(a) * r * radii.x, y * radii.y, sin(a) * r * radii.z))

func mat(c: Color, opts := {}) -> ShaderMaterial:
	var key := "%s|%s" % [c.to_html(), opts]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("base_color", c)
	if opts.has("emission"):
		var e: Color = opts["emission"]
		m.set_shader_parameter("emission", Vector3(e.r, e.g, e.b))
	m.set_shader_parameter("stripes", opts.get("stripes", 0.0))
	m.set_shader_parameter("lamp_gain", opts.get("lamp", 1.0))
	m.set_shader_parameter("wet", opts.get("wet", 0.3))
	if opts.has("tile"):
		m.set_shader_parameter("has_tile", true)
		m.set_shader_parameter("tile_alb", load("res://props/surfaces/%s_alb.png" % opts["tile"]))
		m.set_shader_parameter("tile_nrm", load("res://props/surfaces/%s_nrm.png" % opts["tile"]))
		m.set_shader_parameter("tile_size", opts.get("tile_size", Vector2.ONE))
	_mats[key] = register(m)
	return m

func glow(c: Color, k := 1.0) -> ShaderMaterial:
	return mat(c.darkened(0.6), {"emission": Color(c.r * k, c.g * k, c.b * k), "lamp": 0.0})

func windows(opts := {}) -> ShaderMaterial:
	var key := "win|%s" % [opts]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = WINDOW
	for k in opts:
		m.set_shader_parameter(k, opts[k])
	window_mats.append(m)
	_mats[key] = m
	return m

func prop_mat(name: String) -> ShaderMaterial:
	var key := "prop|" + name
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("base_color", Color.WHITE)
	m.set_shader_parameter("has_albedo", true)
	m.set_shader_parameter("albedo_tex", load(FURN + name + "_alb.png"))
	if ResourceLoader.exists(FURN + name + "_nrm.png"):
		m.set_shader_parameter("has_prop_nrm", true)
		m.set_shader_parameter("prop_nrm", load(FURN + name + "_nrm.png"))
	if ResourceLoader.exists(FURN + name + "_emit.png"):
		m.set_shader_parameter("has_prop_emit", true)
		m.set_shader_parameter("prop_emit", load(FURN + name + "_emit.png"))
		m.set_shader_parameter("emit_strength", 3.0)
	m.set_shader_parameter("wet", 0.3)
	_mats[key] = register(m)
	return m

func part(m: Mesh, c: Variant, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mt: Material = c if c is Material else mat(c)
	return Props._part(root, parent if parent else root, m, mt, pos, rot, scl, false)

func box(size: Vector3, c: Variant, pos: Vector3, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	return part(Props._box(size), c, pos, rot, Vector3.ONE, parent)

func cyl(r0: float, r1: float, h: float, c: Variant, pos: Vector3, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	return part(Props._cyl(r0, r1, h), c, pos, rot, Vector3.ONE, parent)

func quad_mesh(size: Vector2) -> QuadMesh:
	var key := "%s" % size
	if not _quads.has(key):
		var q := QuadMesh.new()
		q.size = size
		_quads[key] = q
	return _quads[key]

func quad(size: Vector2, c: Variant, pos: Vector3, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	return part(quad_mesh(size), c, pos, rot, Vector3.ONE, parent)

func place(name: String, pos: Vector3, yaw := 0.0, scl := 1.0, skin := "", parent: Node3D = null) -> Node3D:

	var glb := FURN + (skin if skin != "" and ResourceLoader.exists(FURN + skin + ".glb") else name) + ".glb"
	var n: Node3D = load(glb).instantiate()
	n.position = pos
	n.rotation.y = deg_to_rad(yaw)
	n.scale = Vector3.ONE * scl
	(parent if parent else root).add_child(n)
	var m := prop_mat(skin if skin != "" else name)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

func tree(variant: String, pos: Vector3, yaw := 0.0, scl := 1.0, parent: Node3D = null) -> Node3D:
	var n: Node3D = load(FURN + "street_tree_%s.glb" % variant).instantiate()
	n.position = pos
	n.rotation.y = deg_to_rad(yaw)
	n.scale = Vector3.ONE * scl
	(parent if parent else root).add_child(n)
	if not _mats.has("foliage"):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/intro_foliage.gdshader")
		m.set_shader_parameter("atlas", load(FURN + "street_tree_atlas.png"))
		_mats["foliage"] = register(m)
		foliage_mats.append(m)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _mats["foliage"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 0.6
	var dome: Array = {"a": [Vector3(0, 5.6, 0), Vector3(2.6, 1.6, 2.6)], "b": [Vector3(0, 4.0, 0), Vector3(2.7, 2.2, 2.6)],
		"c": [Vector3(0, 6.8, 0), Vector3(1.8, 2.0, 1.8)]}[variant]
	hit_dome(pos + (dome[0] as Vector3) * scl, (dome[1] as Vector3) * scl, 70)
	return n

func _halo_texture() -> GradientTexture2D:
	if _halo_tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		_halo_tex = GradientTexture2D.new()
		_halo_tex.gradient = g
		_halo_tex.fill = GradientTexture2D.FILL_RADIAL
		_halo_tex.fill_from = Vector2(0.5, 0.5)
		_halo_tex.fill_to = Vector2(0.5, 0.0)
		_halo_tex.width = 128
		_halo_tex.height = 128
	return _halo_tex

func halo(pos: Vector3, size: float, c: Color, alpha: float, parent: Node3D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.albedo_texture = _halo_texture()
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.disable_fog = true
	var q := MeshInstance3D.new()
	q.mesh = quad_mesh(Vector2(size, size))
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = pos
	(parent if parent else root).add_child(q)
	return m

func wash(pos: Vector3, size: Vector2, c: Color, alpha: float, yaw := 0.0, radial := false, pitch := 0.0) -> StandardMaterial3D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	if radial:
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
	else:
		tex.fill_from = Vector2(0.5, 1.0)
		tex.fill_to = Vector2(0.5, 0.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.albedo_texture = tex
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.disable_fog = true
	var q := MeshInstance3D.new()
	q.mesh = quad_mesh(size)
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = pos
	q.rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0)
	root.add_child(q)
	return m
