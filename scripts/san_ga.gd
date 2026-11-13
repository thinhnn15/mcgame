class_name SanGa
extends RefCounted

const TRK_METRO := -5.2
const TRK_OLD := 5.2
const PX := 3.6
const FL := 1.0
const PZ := 15.0
const STREET := -9.6
const HOLE := [-0.9, 0.9, -4.5, 2.0]
const STAIR_BOT := -2.4
const STAIR_TOP := Vector3(0, 1.0, 2.3)
const BENCHES := [-9.75, 9.75]
const CONC_L := 15.0
const BRICK_L := 7.5
const YELLOW := 0.9
const WALK_RULES := 2
const SHOW_AFTER := 0.4
const ROOF := [-3.95, 2.5, 4.5, 5.7]

const GLASS := preload("res://shaders/vehicle_glass.gdshader")
const SURFACE := preload("res://shaders/station_tile.gdshader")
const FLOOR_SHADER := preload("res://shaders/station_surface.gdshader")

const SURFACES := {
	"Tactile": ["st_tactile", 0.3, Color.WHITE],
	"Concrete": ["st_concrete", 2.0, Color(0.92, 0.9, 0.87)],
	"Tiles": ["st_wall_tile", 0.6, Color.WHITE],
	"Brick": ["st_brick", 0.6, Color.WHITE],
}
const SPAN_TILE := {"cau_can_bt": ["st_concrete", 2.0, Color(0.92, 0.9, 0.87)], "cau_can_gach": ["st_brick", 0.6, Color.WHITE]}
const NEAR_SPANS := 40.0
const STONE := ["st_stone", 0.5, Color(0.95, 0.93, 0.9)]
const RING := ["st_brick", 0.6, Color(0.78, 0.7, 0.68)]
static var _glass: ShaderMaterial

static func place(parent: Node3D, pos: Vector3, yaw_deg := 0.0) -> Node3D:
	var st := Furniture.place(parent, "san_ga", pos, yaw_deg, false)
	if _glass == null:
		_glass = ShaderMaterial.new()
		_glass.shader = GLASS
		_glass.set_shader_parameter("tint", Color(0.74, 0.84, 0.9, 0.12))
		_glass.set_shader_parameter("glint", 0.25)
	var g := st.find_child("Glass", true, false) as MeshInstance3D
	if g:
		g.material_override = _glass
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surfaces(st)
	var sb := StaticBody3D.new()
	st.add_child(sb)
	var x0: float = HOLE[0]
	var x1: float = HOLE[1]
	var z0: float = HOLE[2]
	var z1: float = HOLE[3]
	_box(sb, Vector3(-PX, 0.6, -PZ), Vector3(PX, FL, z0))
	_box(sb, Vector3(-PX, 0.6, z1), Vector3(PX, FL, PZ))
	_box(sb, Vector3(-PX, 0.6, z0), Vector3(x0, FL, z1))
	_box(sb, Vector3(x1, 0.6, z0), Vector3(PX, FL, z1))
	_box(sb, Vector3(x0 - 0.15, FL, z0 - 0.15), Vector3(x0, FL + 1.0, z1))
	_box(sb, Vector3(x1, FL, z0 - 0.15), Vector3(x1 + 0.15, FL + 1.0, z1))
	_box(sb, Vector3(x0, FL, z0 - 0.15), Vector3(x1, FL + 1.0, z0))
	_box(sb, Vector3(x0, STAIR_BOT - 0.4, z0), Vector3(x1, STAIR_BOT, z0 + 0.5))
	var ramp := CollisionShape3D.new()
	var rs := BoxShape3D.new()
	var run := z1 - (z0 + 0.5)
	var rise := FL - STAIR_BOT
	rs.size = Vector3(x1 - x0, 0.2, sqrt(run * run + rise * rise))
	ramp.shape = rs
	ramp.position = Vector3(0, (FL + STAIR_BOT) / 2 - 0.1, (z0 + 0.5 + z1) / 2)
	ramp.rotation.x = -atan2(rise, run)
	sb.add_child(ramp)
	for z in [-PZ + 0.1, PZ - 0.1]:
		_box(sb, Vector3(-PX, FL, z - 0.05), Vector3(PX, FL + 1.25, z + 0.05))
		for s in [-1.0, 1.0]:
			var ze := 12.6 if z > 0 else -12.6
			_box(sb, Vector3(s * (PX - 0.08) - 0.05, FL, minf(z, ze)), Vector3(s * (PX - 0.08) + 0.05, FL + 1.25, maxf(z, ze)))
	for z in [-12.0, -7.0, 6.5, 12.0]:
		var col := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.19
		cy.height = 3.0
		col.shape = cy
		col.position = Vector3(0, FL + 1.5, z)
		sb.add_child(col)
	for z: float in BENCHES:
		_box(sb, Vector3(-0.95, FL, z - 0.9), Vector3(0.95, FL + 0.42, z + 0.9))
	var line := StaticBody3D.new()
	line.collision_layer = WALK_RULES
	line.collision_mask = 0
	st.add_child(line)
	for s in [-1.0, 1.0]:
		_box(line, Vector3(s * (PX - YELLOW) - 0.05, FL, -PZ), Vector3(s * (PX - YELLOW) + 0.05, FL + 2.0, PZ))
	_box(line, Vector3(x0, FL, z1 - 0.1), Vector3(x1, FL + 2.0, z1))
	return st

static func _surfaces(st: Node3D) -> void:
	var corner := st.to_global(Vector3(PX - 0.3, FL, -PZ))
	var origin := Vector2(corner.x, corner.z)
	var floor_mi := st.find_child("Floor", true, false) as MeshInstance3D
	if floor_mi:
		var m := ShaderMaterial.new()
		m.shader = FLOOR_SHADER
		m.set_shader_parameter("tile_alb", load("res://props/surfaces/st_pavers_alb.png"))
		m.set_shader_parameter("tile_nrm", load("res://props/surfaces/st_pavers_nrm.png"))
		m.set_shader_parameter("tile_size", Vector2(1.2, 1.2))
		m.set_shader_parameter("tile_origin", origin)
		m.set_shader_parameter("overlay", load(Furniture.local_path("san_ga_floor_ov.png")))
		m.set_shader_parameter("overlay_emit", load("res://props/furniture/san_ga_floor_ov_emit.png"))
		m.set_shader_parameter("shade_soft", 0.35)
		floor_mi.material_override = m
	for n: String in SURFACES:
		var mi := st.find_child(n, true, false) as MeshInstance3D
		if mi:
			mi.material_override = _tile(SURFACES[n], origin)

static func _tile(spec: Array, origin: Vector2, ground_y := -1000.0, span := 7.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	m.set_shader_parameter("tile_alb", load("res://props/surfaces/%s_alb.png" % spec[0]))
	m.set_shader_parameter("tile_nrm", load("res://props/surfaces/%s_nrm.png" % spec[0]))
	m.set_shader_parameter("has_nrm", true)
	m.set_shader_parameter("tile_size", Vector2(spec[1], spec[1]))
	m.set_shader_parameter("tile_origin", origin)
	m.set_shader_parameter("base_color", spec[2])
	m.set_shader_parameter("shade_soft", 0.35)
	m.set_shader_parameter("rim", 0.12)
	m.set_shader_parameter("ground_y", ground_y)
	m.set_shader_parameter("span_len", span)
	return m

static func _box(sb: StaticBody3D, lo: Vector3, hi: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = hi - lo
	cs.shape = bs
	cs.position = (lo + hi) / 2
	sb.add_child(cs)

static func viaducts(st: Node3D, z_from: float, z_to: float) -> void:
	var mat := Furniture.material("san_ga")
	for line: Array in [["cau_can_bt", TRK_METRO, CONC_L], ["cau_can_gach", TRK_OLD, BRICK_L]]:
		var l: float = line[2]
		var ground := st.to_global(Vector3(0, STREET, 0)).y
		var tile := _tile(SPAN_TILE[line[0]], Vector2.ZERO, ground, l)
		var stone := _tile(STONE, Vector2.ZERO, ground, l)
		var ringm := _tile(RING, Vector2.ZERO, ground, l)
		var src: Node3D = load(Furniture.DIR + line[0] + ".glb").instantiate()
		var decks: Array[Transform3D] = []
		var tops: Array[Transform3D] = []
		var z := -PZ + l / 2 + floorf((z_from + PZ) / l) * l
		while z - l / 2 < z_to:
			var xf := Transform3D(Basis(), Vector3(line[1], 0, z))
			decks.append(xf)
			if absf(z) >= PZ:
				tops.append(xf)
			z += l
		var parts := []
		for pn: String in ["Deck", "Trim", "Ring", "Top", "Wall", "Cope"]:
			var all_: Array = decks if pn in ["Deck", "Trim", "Ring"] else tops
			parts.append([pn, all_.filter(func(x: Transform3D): return absf(x.origin.z) <= NEAR_SPANS), true])
			parts.append([pn, all_.filter(func(x: Transform3D): return absf(x.origin.z) > NEAR_SPANS), false])
		for part: Array in parts:
			var mi := src.find_child(part[0], true, false) as MeshInstance3D
			if mi == null or part[1].is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mi.mesh
			mm.instance_count = part[1].size()
			for k in part[1].size():
				mm.set_instance_transform(k, part[1][k] * mi.transform)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%s%s" % [line[0], part[0], "" if part[2] else "_far"]
			if not part[2]:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.multimesh = mm
			match part[0]:
				"Deck", "Wall":
					mmi.material_override = tile
				"Ring":
					mmi.material_override = ringm
				"Trim", "Cope":
					mmi.material_override = stone if line[0] == "cau_can_gach" else mat
				_:
					mmi.material_override = mat
			st.add_child(mmi)
		src.free()

static func roof_y(x: float) -> float:
	var half: float = ROOF[0] if x < 0.0 else ROOF[1]
	return ROOF[2] + (ROOF[3] - ROOF[2]) * cos(PI / 2 * clampf(x / half, 0.0, 1.0))

static func cutaway(st: Node3D, cam_pos: Vector3, look_pos: Vector3, delta: float) -> void:
	var a := st.to_local(cam_pos)
	var b := st.to_local(look_pos)
	var roof := false
	for i in 25:
		var p := a.lerp(b, i / 24.0)
		if p.x > ROOF[0] - 0.4 and p.x < ROOF[1] + 0.4 and absf(p.z) < PZ + 0.4 and p.y > roof_y(p.x) - 0.3:
			roof = true
			break
	var board := roof
	for bx: AABB in [AABB(Vector3(-1.45, 2.75, 4.45), Vector3(2.9, 2.8, 0.7)), AABB(Vector3(-3.45, 3.1, 10.15), Vector3(2.5, 2.4, 0.7))]:
		if bx.intersects_segment(a, b):
			board = true
	var hold: Dictionary = st.get_meta("cutaway", {})
	for n: String in ["Roof", "Glass", "Board"]:
		var block := board if n == "Board" else roof
		var clear: float = 0.0 if block else hold.get(n, SHOW_AFTER) + delta
		hold[n] = clear
		var node := st.find_child(n, true, false) as Node3D
		if node:
			node.visible = clear >= SHOW_AFTER
	st.set_meta("cutaway", hold)

static func dress(st: Node3D) -> void:
	var stand := [
		["ga_may_nuoc", Vector3(-0.75, FL, -13.6), -90.0, true],
		["ga_thung_rac", Vector3(-0.55, FL, -12.75), -90.0, true],
		["ga_bang_doi", Vector3(0.0, FL, -5.8), -90.0, true],
		["ga_chau_hoa_giay", Vector3(0.8, FL, 13.6), 0.0, true],
		["ga_chau_hoa_giay", Vector3(1.7, FL, 3.6), 40.0, true],
		["ga_chau_hoa_giay", Vector3(0.8, FL, -13.6), 120.0, true],
		["ga_bien_uot", Vector3(1.05, FL, 7.75), 70.0, false],
		["ga_binh_cuu_hoa", Vector3(-0.17, FL + 0.75, -7.0), -60.0, false],
	]
	for s: Array in stand:
		Furniture.place(st, s[0], s[1], s[2], s[3], "ga_do")
	var broom := Furniture.place(st, "ga_choi", Vector3(0.7, FL, 7.75), 0.0, false, "ga_do")
	broom.rotation.z = deg_to_rad(-17.0)
	var board := st.find_child("Board", true, false) as Node3D
	for h: Array in [["ga_bien_xanh", -1.9, -9.5], ["ga_bien_xanh", -1.9, 8.0], ["ga_bien_go", 1.25, -9.5],
			["ga_bien_go", 1.25, 8.0], ["ga_dong_ho", 0.0, 11.0]]:
		var x: float = h[1]
		var top := roof_y(x) - (0.28 if x == 0.0 else 0.02)
		Furniture.place(board, h[0], Vector3(x, top, h[2]), 0.0, false, "ga_do")

static func set_door_light(st: Node3D, side: String, amount: float) -> void:
	var mi := st.find_child("Floor", true, false) as MeshInstance3D
	if mi and mi.material_override:
		(mi.material_override as ShaderMaterial).set_shader_parameter("metro_light" if side == "metro" else "old_light", amount)

static func seat_spot(st: Node3D, bench := 1, side := 1, along := 0.0) -> Transform3D:
	var p := st.to_global(Vector3(side * 0.72, FL, BENCHES[bench] + along))
	var face := st.global_basis * Vector3(side, 0, 0)
	return Transform3D(Basis.looking_at(-face), p)
