class_name OfficeProps
extends RefCounted

const DESK_H := 0.56
const WOOD := Color("e6c9a0")
const WOOD_DARK := Color("b98e62")
const METAL := Color("c9ced8")
const DARK := Color("4a4f5c")
const SCREEN := Color("bfe6ff")
const WOOD_DEEP := Color("7a5236")

static var _rboxes := {}

static func _rbox(size: Vector3, r: float) -> Mesh:
	var key := "%s:%.3f" % [size, r]
	if _rboxes.has(key):
		return _rboxes[key]
	var h := size / 2.0
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.95)
	var inner := h - Vector3.ONE * r
	var cs := [_axis(inner.x, h.x, r), _axis(inner.y, h.y, r), _axis(inner.z, h.z, r)]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()

	for f in [[0, 1, 2, 1], [0, -1, 1, 2], [1, 1, 0, 2], [1, -1, 2, 0], [2, 1, 1, 0], [2, -1, 0, 1]]:
		var ax: int = f[0]
		var sg: float = f[1]
		var ua: int = f[2]
		var va: int = f[3]
		var us: Array = cs[ua]
		var vs: Array = cs[va]
		var base := verts.size()
		for j in vs.size():
			for i in us.size():
				var p := Vector3.ZERO
				p[ax] = sg * h[ax]
				p[ua] = us[i]
				p[va] = vs[j]
				var q := Vector3(clampf(p.x, -inner.x, inner.x), clampf(p.y, -inner.y, inner.y), clampf(p.z, -inner.z, inner.z))
				var d := p - q
				var n := Vector3.ZERO
				if d.length() > 1e-6:
					n = d.normalized()
				else:
					n[ax] = sg
				verts.append(q + n * r)
				norms.append(n)
				uvs.append(Vector2(float(i) / (us.size() - 1), float(j) / (vs.size() - 1)))
		var w := us.size()
		for j in vs.size() - 1:
			for i in w - 1:
				var a0 := base + j * w + i
				for tri in [[a0, a0 + w, a0 + 1], [a0 + 1, a0 + w, a0 + w + 1]]:

					var v0: Vector3 = verts[tri[0]]
					var cr := (verts[tri[1]] - v0).cross(verts[tri[2]] - v0)
					var out := norms[tri[0]] + norms[tri[1]] + norms[tri[2]]
					if cr.dot(out) > 0.0:
						idx.append_array([tri[0], tri[2], tri[1]])
					else:
						idx.append_array(tri)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_rboxes[key] = am
	return am

static func _axis(i: float, o: float, r: float) -> Array:
	return [-o, -(i + r * 0.71), -i, i, i + r * 0.71, o]

static func _solid_box(root: Node3D, size: Vector3, pos: Vector3, yaw := 0.0) -> void:
	var bs := BoxShape3D.new()
	bs.size = size
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = deg_to_rad(yaw)
	root.add_child(sb)

static func desk(root: Node3D, pos: Vector3, yaw := 0.0, mug := Color("ffffff"), kind := "code", panel := 2,
		top := WOOD) -> Node3D:
	var n := Furniture.place(root, "office_desk", pos, yaw, false, "office_desk_boss" if top == WOOD_DEEP else "")
	if panel >= 2:
		Furniture.place(n, "desk_panel_back", Vector3.ZERO, 0.0, false)
	if panel >= 1:
		Furniture.place(n, "desk_panel_side", Vector3.ZERO, 0.0, false)
	Furniture.place(n, "desktop_pc", PC, 0.0, false)
	_screen(root, n, kind, PC + Vector3(0, 0.3375, 0.021))
	var mug_skin: String = {Color("ffd6a0"): "mug_peach", Color("8c2f39"): "mug_red"}.get(mug, "")
	Furniture.place(n, "mug", Vector3(-0.43, TOP, -0.08), 0.0, false, mug_skin)
	Furniture.place(n, "paper_stack_low", Vector3(-0.26, TOP, -0.13), 8.0, false)
	_solid_box(root, Vector3(1.2, 0.9, 0.7), pos + Vector3(0, 0.45, 0), yaw)
	return n

const FELT := Color("aab4c2")
const SHELL := Color("3b4050")
const TOP := 0.59
const PC := Vector3(0, TOP, -0.18)

const GLASS := Vector2(0.56, 0.315)
const SCREEN_DIR := "res://props/screens"
const SCREEN_DARK := ["code"]
static var screen_time := "10:10"
static var _screen_mats := {}
static var _screen_lang := ""
static var _carets := {}

const LOGO_COLORS := {"panel": Color("34404f"), "cap": Color("c9ced8"), "tile": Color("ff8c69"),
	"tile_text": Color("fff8ef"), "letters": Color("fff1dc")}
const LOGO_FACE := 0.055
const LOGO_LINE_Y := -0.2

static func company_logo(root: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var n: Node3D = load("res://props/signs/mc_studio.glb").instantiate()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			(mi as MeshInstance3D).set_surface_override_material(i, Props.mat(LOGO_COLORS.get(m.resource_name if m else "", Color.WHITE)))
	n.position = pos
	n.rotation.y = deg_to_rad(yaw)
	root.add_child(n)
	return n

static func _screen(root: Node3D, n: Node3D, kind: String, at: Vector3) -> void:
	if _carets.is_empty():
		_carets = JSON.parse_string(FileAccess.get_file_as_string(SCREEN_DIR + "/carets.json"))
	if not _screen_mats.has(kind) or _screen_lang != Lang.current:
		if _screen_lang != Lang.current:
			_screen_mats.clear()
			_screen_lang = Lang.current
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/screen.gdshader")
		m.set_shader_parameter("on", kind != "off")
		if kind != "off":
			m.set_shader_parameter("screen_tex", load(Lang.path_for(SCREEN_DIR, kind + ".png")))
			m.set_shader_parameter("brightness", 1.0 if kind in SCREEN_DARK else 0.9)
			var c: Array = _carets.get(Lang.current, _carets["en"]).get(kind, [0, 0, 0, 0])
			m.set_shader_parameter("caret", Vector4(c[0], c[1], c[2], c[3]))
			m.set_shader_parameter("caret_color", Vector3(0.9, 0.92, 0.96) if kind in SCREEN_DARK else Vector3(0.15, 0.17, 0.22))
		_screen_mats[kind] = m
	var q := QuadMesh.new()
	q.size = GLASS
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _screen_mats[kind]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	n.add_child(mi)
	if kind == "off":
		return
	var clock := Label3D.new()
	clock.text = screen_time
	clock.font_size = 32
	clock.pixel_size = 0.00024
	clock.outline_size = 0
	clock.modulate = Color("e3e7ee") if kind in SCREEN_DARK else Color("2a2f38")
	clock.position = at + Vector3((0.945 - 0.5) * GLASS.x, (0.5 - 0.974) * GLASS.y, 0.001)
	n.add_child(clock)

const SEAT_H := 0.32

static func chair(root: Node3D, pos: Vector3, yaw := 0.0, boss := false) -> Node3D:
	return Furniture.place(root, "office_chair", pos, yaw, false, "office_chair_boss" if boss else "")

static func plant(root: Node3D, pos: Vector3, s := 1.0) -> Node3D:
	var n := Furniture.place(root, "office_plant", pos, randf() * 360.0, false)
	n.scale = Vector3.ONE * s
	Props.solid(root, _cylinder(0.2, 1.0), pos + Vector3(0, 0.5, 0))
	return n

static func _cylinder(r: float, h: float) -> CylinderShape3D:
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	return c

static func bookshelf(root: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Furniture.place(root, "office_bookshelf", pos, yaw, false)
	_solid_box(root, Vector3(1.08, 1.56, 0.4), pos + Vector3(0, 0.78, 0), yaw)
	return n

static func printer(root: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Furniture.place(root, "office_printer", pos, yaw, false)
	_solid_box(root, Vector3(0.62, 0.72, 0.55), pos + Vector3(0, 0.36, 0), yaw)
	return n

static func cabinet(root: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Furniture.place(root, "office_cabinet", pos, yaw, false)
	_solid_box(root, Vector3(0.6, 0.97, 0.63), pos + Vector3(0, 0.485, 0), yaw)
	return n

static func water_cooler(root: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Furniture.place(root, "office_water_cooler", pos, yaw, false)
	Props.solid(root, _cylinder(0.22, 1.3), pos + Vector3(0, 0.65, 0))
	return n

static func coffee_corner(root: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Furniture.place(root, "office_coffee_corner", pos, yaw, false)
	_solid_box(root, Vector3(1.68, 1.0, 0.66), pos + Vector3(0, 0.5, 0), yaw)
	return n

static func whiteboard(root: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	return Furniture.place(root, "office_whiteboard", pos, yaw, false)

static func clock(root: Node3D, pos: Vector3, yaw := 0.0, hour := 9, minute := 5) -> Node3D:
	var n := Furniture.place(root, "office_clock", pos, yaw, false)
	var ah := TAU * (float(hour % 12) + minute / 60.0) / 12.0
	var am := TAU * minute / 60.0
	Props._part(root, n, Props._box(Vector3(0.022, 0.09, 0.008)), DARK, Vector3(sin(ah) * 0.045, cos(ah) * 0.045, 0.047),
		Vector3(0, 0, -rad_to_deg(ah)))
	Props._part(root, n, Props._box(Vector3(0.014, 0.13, 0.008)), DARK, Vector3(sin(am) * 0.065, cos(am) * 0.065, 0.052),
		Vector3(0, 0, -rad_to_deg(am)))
	return n

static func glass_wall(root: Node3D, a: Vector3, b: Vector3, h := 1.9) -> void:
	var d := b - a
	var mid := (a + b) / 2.0
	var yaw := -rad_to_deg(atan2(d.z, d.x))
	var n := Props.at(root, mid, yaw)
	var L := d.length()
	Props._part(root, n, Props._box(Vector3(L, 0.9, 0.06)), Color("e8f1f7"), Vector3(0, 0.45, 0))
	for y in [0.9, h]:
		Props._part(root, n, Props._box(Vector3(L, 0.05, 0.08)), METAL, Vector3(0, y, 0))
	var k := 1
	for i in k + 1:
		Props._part(root, n, Props._box(Vector3(0.05, h, 0.08)), METAL, Vector3(-L / 2 + L * i / k, h / 2, 0))
	var glass := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(L, h - 0.9, 0.02)
	glass.mesh = bm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.96, 0.98, 1.0, 0.1)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.1
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.material_override = gm
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.position = Vector3(0, 0.9 + (h - 0.9) / 2, 0)
	n.add_child(glass)
	_solid_box(root, Vector3(L, h, 0.1), mid + Vector3(0, h / 2, 0), yaw)

static func sofa(root: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Furniture.place(root, "office_sofa", pos, yaw, false)
	_solid_box(root, Vector3(1.7, 0.8, 0.76), pos + Vector3(0, 0.4, 0), yaw)
	return n

static func low_table(root: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := Furniture.place(root, "office_low_table", pos, yaw, false)
	_solid_box(root, Vector3(0.92, 0.42, 0.52), pos + Vector3(0, 0.21, 0), yaw)
	return n

static func floor_lamp(root: Node3D, pos: Vector3) -> Node3D:
	var n := Furniture.place(root, "office_floor_lamp", pos, 0.0, false)
	Props.solid(root, _cylinder(0.18, 1.6), pos + Vector3(0, 0.8, 0))
	return n

static func blinds(root: Node3D, a: Vector3, b: Vector3, top := 1.88, bottom := 1.35) -> void:
	var d := b - a
	var n := Props.at(root, (a + b) / 2.0, -rad_to_deg(atan2(d.z, d.x)))
	var y := top
	while y > bottom:
		Props._part(root, n, Props._box(Vector3(d.length() - 0.08, 0.026, 0.012)), Color("e8e4dc"), Vector3(0, y, 0.06),
			Vector3(-25, 0, 0), Vector3.ONE, false)
		y -= 0.045
	Props._part(root, n, Props._box(Vector3(d.length() - 0.06, 0.05, 0.05)), Color("d9d2c6"), Vector3(0, top + 0.03, 0.06))

static func kpi_chart(root: Node3D, pos: Vector3, yaw := 0.0) -> void:
	Furniture.place(root, "office_kpi_chart", pos, yaw, false)
