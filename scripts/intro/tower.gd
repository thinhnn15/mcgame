extends RefCounted

const CityKit := preload("res://scripts/intro/city_kit.gd")

const STOREY := 3.2
const BAY := 1.8
const HX := 13.5
const SIDE_BAYS := 12
const CORNER := 0.45
const LOBBY_K := -10
const TOP_K := 4
const PIER_D := 0.35
const BAND_D := 0.18
const SILL := 0.78
const HEAD := 2.45
const TRANSOM := 2.05

const STONE := Color("c9c2cf")
const STONE_DK := Color("7f7b98")
const LEDGE := Color("e4ddd0")
const FRAME := Color("4a4f63")

const STONE_TILE := {"tile": "tower_stone", "tile_size": Vector2(2.4, 2.4)}
const ACCENT := Color("ffd9a0")

var kit: CityKit
var zf: float
var room_hx: float
var street_y: float
var depth: float
var top_y: float
var red_light: StandardMaterial3D
var red_core: ShaderMaterial
var sign_pos := Vector3.ZERO
var stone: Material
var stone_dk: Material
var ledge: Material

func build(k: CityKit, wall_z: float, our_hx: float) -> void:
	kit = k
	zf = wall_z
	room_hx = our_hx
	street_y = LOBBY_K * STOREY
	depth = CORNER + SIDE_BAYS * BAY
	top_y = (TOP_K + 1) * STOREY
	stone = kit.mat(STONE, STONE_TILE)
	stone_dk = kit.mat(STONE_DK, STONE_TILE)
	ledge = kit.mat(LEDGE, STONE_TILE)

	var win := kit.windows({"lit_rate": 0.1, "cool_rate": 0.25, "seed": 1.0, "cell": Vector2(BAY, STOREY),
		"cell_offset": Vector2(-HX, 0.0), "has_frame": true, "frame_tex": load("res://props/surfaces/tower_window.png")})

	var front := _frame(Vector3(0, 0, zf), 0.0)
	_office_face(front, -HX, int(2 * HX / BAY), win, true)
	var west := _frame(Vector3(-HX, 0, zf), 90.0)
	_office_face(west, -depth, SIDE_BAYS, win, false)
	var east := _frame(Vector3(HX, 0, zf), -90.0)
	_office_face(east, CORNER, SIDE_BAYS, win, false)

	var y0 := (LOBBY_K + 2) * STOREY
	for sx in [-1, 1]:
		kit.box(Vector3(2 * CORNER, top_y - street_y, 2 * CORNER), stone_dk, Vector3(sx * HX, (top_y + street_y) / 2.0, zf))
		kit.box(Vector3(2 * CORNER + 0.12, 0.5, 2 * CORNER + 0.12), ledge, Vector3(sx * HX, y0 - 0.25, zf))
	kit.box(Vector3(2 * HX, top_y - y0, 0.4), stone_dk, Vector3(0, (top_y + y0) / 2.0, zf + depth - 0.2))

	for sx in [-1, 1]:
		kit.box(Vector3(0.07, top_y - y0, 0.07), kit.glow(ACCENT, 1.5), Vector3(sx * (HX + CORNER), (top_y + y0) / 2.0, zf - CORNER))

	kit.wash(Vector3(0, y0 + 7.0, zf - PIER_D - 0.05), Vector2(2 * HX + 1.0, 14.0), Color("ffbf80"), 0.13, 180.0)
	for sx in [-1, 1]:
		kit.wash(Vector3(sx * (HX + PIER_D + 0.05), y0 + 7.0, zf + depth / 2.0), Vector2(depth, 14.0), Color("ffbf80"), 0.1, sx * 90.0)
	_lobby()
	_crown()

func _frame(pos: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = deg_to_rad(yaw)
	kit.root.add_child(n)
	return n

func _office_face(f: Node3D, x0: float, bays: int, win: Material, front: bool) -> void:
	var w := bays * BAY
	var xc := x0 + w / 2.0
	var k0 := LOBBY_K + 2
	var y_lo := k0 * STOREY + SILL
	var y_hi := top_y
	var glass := Vector2(BAY - 0.36, HEAD - SILL)
	for k in range(k0, TOP_K + 1):
		var y0 := k * STOREY

		var b0 := y0 + HEAD
		var b1 := minf(y0 + STOREY + SILL, y_hi)
		kit.box(Vector3(w, b1 - b0, BAND_D), stone, Vector3(xc, (b0 + b1) / 2.0, -BAND_D / 2.0), Vector3.ZERO, f)
		if k < TOP_K:
			kit.box(Vector3(w, 0.07, 0.3), ledge, Vector3(xc, b1 - 0.035, -0.15), Vector3.ZERO, f)

		kit.box(Vector3(w, 0.05, 0.02), stone_dk, Vector3(xc, b0 + 0.18, -BAND_D - 0.008), Vector3.ZERO, f)
		for i in bays:
			var cx := x0 + (i + 0.5) * BAY
			if front and k == 0 and absf(cx) < room_hx:
				continue
			kit.quad(glass, win, Vector3(cx, y0 + (SILL + HEAD) / 2.0, -0.01), Vector3(0, 180, 0), f)

	kit.box(Vector3(w, 0.8, BAND_D), stone, Vector3(xc, y_lo - 0.4, -BAND_D / 2.0), Vector3.ZERO, f)

	for i in bays + 1:
		var px := x0 + i * BAY
		if front and (i == 0 or i == bays):
			continue
		if not front and ((x0 < 0 and i == bays) or (x0 > 0 and i == 0)):
			continue
		kit.box(Vector3(0.36, y_hi - y_lo + 0.8, PIER_D), stone_dk, Vector3(px, (y_hi + y_lo - 0.8) / 2.0, -PIER_D / 2.0), Vector3.ZERO, f)
		kit.box(Vector3(0.08, y_hi - y_lo + 0.8, 0.02), stone, Vector3(px, (y_hi + y_lo - 0.8) / 2.0, -PIER_D - 0.008), Vector3.ZERO, f)

func _lobby() -> void:
	var y0 := street_y + 0.15
	var y1 := (LOBBY_K + 2) * STOREY
	var h := y1 - y0
	var gz := zf + 1.2
	var back := zf + 9.0

	kit.box(Vector3(2 * HX + 0.6, 1.0, 0.7), ledge, Vector3(0, y1 - 0.2, zf - 0.2))
	kit.box(Vector3(2 * HX + 0.6, 0.06, 0.06), kit.glow(ACCENT, 1.4), Vector3(0, y1 - 0.73, zf - 0.5))

	for x in [0.9, 4.5, 8.1, 11.7]:
		for sx in [-1, 1]:
			var cx: float = sx * x

			var cz := zf - 0.04
			kit.cyl(0.3, 0.27, h - 1.4, stone_dk, Vector3(cx, y0 + 0.5 + (h - 1.4) / 2.0, cz))
			kit.box(Vector3(0.8, 0.36, 0.8), stone, Vector3(cx, y0 + 0.18, cz))
			kit.cyl(0.38, 0.35, 0.16, ledge, Vector3(cx, y0 + 0.44, cz))
			kit.cyl(0.3, 0.3, 0.08, stone, Vector3(cx, y0 + 0.56, cz))
			kit.cyl(0.27, 0.36, 0.3, ledge, Vector3(cx, y1 - 1.05, cz))
			kit.box(Vector3(0.8, 0.14, 0.8), ledge, Vector3(cx, y1 - 0.83, cz))

	kit.box(Vector3(2 * HX, 0.2, gz - zf + 0.4), Color("d9cfc2"), Vector3(0, y1 - 0.6, (zf + gz) / 2.0 - 0.2))
	for i in 8:
		var x := -12.6 + i * 3.6
		kit.cyl(0.16, 0.16, 0.03, kit.glow(Color("fff0d0"), 2.2), Vector3(x, y1 - 0.715, zf + 0.5))

	var pane := StandardMaterial3D.new()
	pane.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.albedo_color = Color(0.55, 0.62, 0.85, 0.12)
	pane.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gh := y1 - 0.7 - y0
	var glass := MeshInstance3D.new()
	glass.mesh = kit.quad_mesh(Vector2(2 * HX, gh))
	glass.material_override = pane
	glass.position = Vector3(0, y0 + gh / 2.0, gz)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	kit.root.add_child(glass)
	var x := -HX
	while x <= HX + 0.01:
		kit.box(Vector3(0.08, gh, 0.1), FRAME, Vector3(x, y0 + gh / 2.0, gz))
		x += BAY
	kit.box(Vector3(2 * HX, 0.08, 0.1), FRAME, Vector3(0, y0 + 2.6, gz))
	kit.box(Vector3(2 * HX, 0.12, 0.12), FRAME, Vector3(0, y0 + 0.06, gz))

	var wall := kit.glow(Color("f3e2c8"), 0.55)
	kit.box(Vector3(2 * HX, h, 0.3), wall, Vector3(0, y0 + h / 2.0, back + 0.15))
	for sx in [-1, 1]:
		kit.box(Vector3(0.3, h, back - gz), wall, Vector3(sx * (HX - 0.2), y0 + h / 2.0, (gz + back) / 2.0))
	kit.box(Vector3(2 * HX, 0.1, back - gz), kit.glow(Color("c9a77f"), 0.45), Vector3(0, y0 - 0.04, (gz + back) / 2.0))
	kit.box(Vector3(2 * HX, 0.2, back - gz), kit.glow(Color("efe2cf"), 0.5), Vector3(0, y1 - 0.4, (gz + back) / 2.0))

	kit.box(Vector3(9.0, h - 0.6, 0.2), kit.glow(Color("b98a5e"), 0.45), Vector3(0, y0 + (h - 0.6) / 2.0, back - 0.1))
	for i in 18:
		kit.box(Vector3(0.06, h - 0.6, 0.05), kit.glow(Color("8a6240"), 0.4), Vector3(-4.25 + i * 0.5, y0 + (h - 0.6) / 2.0, back - 0.22))
	_logo(Vector3(0, y0 + 3.4, back - 0.26), 2.6, 1.6)
	kit.box(Vector3(4.2, 1.1, 0.9), kit.glow(Color("e9dccb"), 0.5), Vector3(0, y0 + 0.55, back - 2.6))
	kit.box(Vector3(4.4, 0.08, 1.0), kit.glow(Color("8a6240"), 0.5), Vector3(0, y0 + 1.12, back - 2.6))
	kit.box(Vector3(4.0, 0.05, 0.02), kit.glow(ACCENT, 2.0), Vector3(0, y0 + 0.9, back - 3.06))
	for sx in [-1, 1]:
		kit.place("office_plant", Vector3(sx * 6.0, y0, gz + 2.0), 0.0, 2.0)
		kit.place("office_plant", Vector3(sx * 10.5, y0, back - 1.2), 70.0, 2.4)
		for j in 3:
			var px: float = sx * (2.2 + j * 3.2)
			kit.cyl(0.01, 0.01, 2.0, Color("3a3540"), Vector3(px, y1 - 1.5, gz + 3.5))
			kit.part(Props._sph(0.28), kit.glow(Color("ffe2b0"), 2.0), Vector3(px, y1 - 2.6, gz + 3.5))

	for x2 in [-9.0, -3.0, 3.0, 9.0]:
		kit.add_source(Vector3(x2, y0 + 3.0, gz + 0.5), 7.5, Color("ffc98a"), 0.9)
	_canopy(y0, gz)

func _canopy(y0: float, gz: float) -> void:
	var cy := y0 + 4.3
	var front := zf - 3.2
	var w := 7.6
	var d := gz - front

	kit.box(Vector3(w, 0.3, d), Color("e8e2d8"), Vector3(0, cy, (front + gz) / 2.0))
	kit.box(Vector3(w + 0.1, 0.55, 0.14), ledge, Vector3(0, cy + 0.05, front - 0.05))
	_logo(Vector3(0, cy - 0.05, front - 0.13), 1.1, 2.2)
	for sx in [-1, 1]:
		var a := Vector3(sx * 3.2, cy + 0.1, front + 0.3)
		var b := Vector3(sx * 3.2, cy + 3.0, zf - 0.3)
		var mid := (a + b) / 2.0
		var ln := a.distance_to(b)
		var tilt := rad_to_deg(atan2(b.z - a.z, b.y - a.y))
		kit.cyl(0.035, 0.035, ln, FRAME, mid, Vector3(tilt, 0, 0))
	for i in 3:
		for j in 2:
			kit.cyl(0.13, 0.13, 0.03, kit.glow(Color("fff0d0"), 2.6), Vector3(-2.4 + i * 2.4, cy - 0.165, front + 1.0 + j * 1.6))
	kit.add_source(Vector3(0, cy - 0.8, front + 1.4), 7.0, Color("ffd49a"), 1.4)

	kit.drip_edge(Vector3(-w / 2.0, cy - 0.2, front - 0.13), Vector3(w / 2.0, cy - 0.2, front - 0.13), 0.1)
	for sx in [-1, 1]:
		kit.drip_edge(Vector3(sx * w / 2.0, cy - 0.15, front), Vector3(sx * w / 2.0, cy - 0.15, gz), 0.15)
	kit.hit_area(Vector3(0, cy + 0.16, (front + gz) / 2.0), Vector2(w, d), 80)

	kit.box(Vector3(1.7, 2.5, 0.06), kit.glow(Color("ffe6c0"), 0.35), Vector3(0, y0 + 1.25, gz + 0.06))
	kit.box(Vector3(0.05, 2.5, 0.1), FRAME, Vector3(0, y0 + 1.25, gz))
	kit.box(Vector3(1.8, 0.08, 0.1), FRAME, Vector3(0, y0 + 2.5, gz))

func _logo(pos: Vector3, scale: float, k: float) -> void:
	var n: Node3D = load("res://props/signs/mc_studio.glb").instantiate()
	var cols := {"tile": Color("ff8c69"), "tile_text": Color("fff8ef"), "letters": Color("fff1dc")}
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi.mesh.surface_get_material(0)
		var name := m.resource_name if m else ""
		if not cols.has(name):
			mi.visible = false
			continue
		mi.material_override = kit.glow(cols[name], k * (0.8 if name == "tile" else 1.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.scale = Vector3.ONE * scale
	n.rotation.y = PI
	n.position = Vector3(pos.x, pos.y - 0.09 * scale, pos.z + 0.055 * scale)
	kit.root.add_child(n)

func _crown() -> void:
	var y := top_y

	kit.box(Vector3(2 * HX + 1.2, 0.7, depth + 1.0), stone_dk, Vector3(0, y + 0.35, zf + depth / 2.0 - 0.1))
	kit.box(Vector3(2 * HX + 1.5, 0.16, depth + 1.3), ledge, Vector3(0, y + 0.78, zf + depth / 2.0 - 0.1))
	kit.box(Vector3(2 * HX + 1.2, 0.05, 0.05), kit.glow(ACCENT, 1.3), Vector3(0, y - 0.02, zf - 0.64))
	y += 0.86

	var t1 := _tier(Vector3(0, y, zf + 0.8 + (depth - 1.6) / 2.0), Vector3(2 * (HX - 1.2), 4.4, depth - 1.6), 0.9,
		kit.windows({"lit_rate": 0.35, "cool_rate": 0.0, "seed": 5.0, "cell": Vector2(0.9, 4.4), "lit_energy": 0.75}))
	y += t1

	var t2w := 2 * (HX - 3.6)
	var t2z0 := zf + 1.8
	var t2d := depth - 3.6
	var t2h := 6.6
	kit.box(Vector3(t2w, t2h, t2d), stone, Vector3(0, y + t2h / 2.0, t2z0 + t2d / 2.0))
	kit.box(Vector3(t2w + 0.5, 0.35, t2d + 0.5), ledge, Vector3(0, y + t2h + 0.17, t2z0 + t2d / 2.0))
	for sx in [-1, 1]:
		kit.box(Vector3(0.7, t2h, 0.7), stone_dk, Vector3(sx * (t2w / 2.0 - 0.15), y + t2h / 2.0, t2z0 + 0.15))
	sign_pos = Vector3(0, y + t2h * 0.5, t2z0)
	_logo(sign_pos + Vector3(0, 0, -0.02), 11.0, 1.7)
	for sx in [-1, 1]:
		kit.box(Vector3(0.08, t2h, 0.08), kit.glow(ACCENT, 1.6), Vector3(sx * (t2w / 2.0 + 0.2), y + t2h / 2.0, t2z0 - 0.2))
	kit.wash(Vector3(0, y + t2h / 2.0, t2z0 - 0.05), Vector2(t2w, t2h), Color("ffe1b8"), 0.1, 180.0)
	kit.wash(Vector3(0, y + 1.1, t2z0 - 0.06), Vector2(t2w * 0.9, 2.4), Color("ff9a7a"), 0.12, 180.0)
	for sx in [-1, 1]:
		kit.wash(Vector3(sx * (t2w / 2.0 + 0.04), y + t2h / 2.0, t2z0 + t2d / 2.0), Vector2(t2d, t2h), Color("ffe1b8"), 0.09, sx * 90.0)
	y += t2h + 0.35

	var t3 := Vector3(7.2, 3.4, 7.2)
	kit.box(t3, stone_dk, Vector3(0, y + t3.y / 2.0, zf + depth / 2.0))
	kit.box(Vector3(t3.x + 0.3, 0.2, t3.z + 0.3), ledge, Vector3(0, y + t3.y + 0.1, zf + depth / 2.0))
	y += t3.y + 0.2
	var mz := zf + depth / 2.0
	kit.cyl(0.28, 0.12, 11.0, Color("6a6f80"), Vector3(0, y + 5.5, mz))
	for i in 4:
		var r := 0.9 - i * 0.18
		kit.box(Vector3(r * 2.0, 0.06, 0.06), Color("6a6f80"), Vector3(0, y + 2.0 + i * 2.2, mz))
		kit.box(Vector3(0.06, 0.06, r * 2.0), Color("6a6f80"), Vector3(0, y + 2.0 + i * 2.2, mz))
	var tip := Vector3(0, y + 11.2, mz)
	red_core = kit.glow(Color("ff3b3b"), 3.0)
	var bulb := MeshInstance3D.new()
	bulb.mesh = Props._sph(0.22)
	bulb.material_override = red_core
	bulb.position = tip
	kit.root.add_child(bulb)
	red_light = kit.halo(tip, 3.5, Color("ff4a4a"), 0.6)

func _tier(center: Vector3, size: Vector3, fin: float, win: Material) -> float:
	var y := center.y
	var h := size.y
	kit.box(Vector3(size.x - 0.4, h, size.z - 0.4), stone_dk, Vector3(center.x, y + h / 2.0, center.z))

	var faces := [[Vector3(0, 0, -size.z / 2.0), 180.0, size.x], [Vector3(0, 0, size.z / 2.0), 0.0, size.x],
		[Vector3(-size.x / 2.0, 0, 0), -90.0, size.z], [Vector3(size.x / 2.0, 0, 0), 90.0, size.z]]
	for fc in faces:
		var off: Vector3 = fc[0]
		var yaw: float = fc[1]
		var ln: float = fc[2]
		var n := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
		var along := Vector3(n.z, 0, -n.x)
		var base: Vector3 = Vector3(center.x, y, center.z) + off - n * 0.19
		var count := int(ln / fin)
		for i in count:
			var p: Vector3 = base + along * (-ln / 2.0 + (i + 0.5) * fin) + Vector3(0, h * 0.47, 0)
			kit.quad(Vector2(fin - 0.12, h * 0.8), win, p, Vector3(0, yaw, 0))
		for i in count + 1:
			var p: Vector3 = base + along * (-ln / 2.0 + i * fin) + n * 0.2 + Vector3(0, h / 2.0, 0)
			kit.box(Vector3(0.12, h, 0.12) if absf(n.x) < 0.5 else Vector3(0.12, h, 0.12), stone, p)
	kit.box(Vector3(size.x + 0.5, 0.3, size.z + 0.5), ledge, Vector3(center.x, y + h + 0.15, center.z))
	kit.box(Vector3(size.x + 0.3, 0.05, 0.05), kit.glow(ACCENT, 1.2), Vector3(center.x, y + h - 0.05, center.z - size.z / 2.0 - 0.27))
	return h + 0.3

func update(t: float) -> void:

	var b := clampf(sin(t * TAU / 2.5) * 2.0, 0.0, 1.0)
	if red_light:
		red_light.albedo_color.a = 0.65 * b
	if red_core:
		red_core.set_shader_parameter("emission", Vector3(3.0, 0.35, 0.35) * (0.15 + 0.85 * b))
