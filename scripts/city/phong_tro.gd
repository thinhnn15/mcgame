class_name PhongTro
extends Node3D

const W := 5.4
const D := 3.3
const H := 2.9
const GAP := 1.0
const WIN_X := -1.5
const WIN := Vector2(1.0, 1.15)
const WIN_Y := 1.55
const TILES := "res://props/hometown/tiles/"
const SURFACE_SHADER := preload("res://shaders/toon_surface.gdshader")
const CAP := Color("4a3a32")
const CAM_POS := Vector3(0.10, 4.45, 6.35)
const CAM_AT := Vector3(-0.05, 0.85, -0.40)
const HERO_R := 0.25

const SPOTS := {"door": Vector2(2.1, 0.8), "bed_side": Vector2(-1.5, -0.3), "desk": Vector2(0.05, -0.3),
	"kitchen": Vector2(1.2, -0.95), "fridge": Vector2(2.08, -0.75), "drawers": Vector2(-1.95, 0.05),
	"cushion": Vector2(-0.25, 0.37)}

var cam: Camera3D
var env: Environment
var hero: Chibi
var player: Player
var time := ""
var _sun: DirectionalLight3D
var _patch: SpotLight3D
var _night_lights: Array[Light3D] = []
var _morning_only: Array[Node3D] = []
var _night_only: Array[Node3D] = []
var _tile_sizes := {}
var _neighbour_pane: StandardMaterial3D
var _neighbour_wall: StandardMaterial3D
var _hero_fill: OmniLight3D
var _drift: Tween
var _vignette: CanvasLayer
var _standalone := false
var _swapped := {}
var _boxes: Array = []
var gender := "m"
var _laptop: Node3D
var _voice_ui: CanvasLayer
var _bubble: PanelContainer
var _voice_label: Label
var _tail: Polygon2D
var _rings: Control
var _voice_on := false
var _voice_k := 0
var _voice_t := 0.0
var _clock_hands: Array[Node3D] = []
var _clock_min := 0.0

func _ready() -> void:
	if get_parent() == get_tree().root:
		_standalone = true
		build()
		var we := WorldEnvironment.new()
		we.environment = env
		add_child(we)
		cam.current = true
		_vignette = _make_vignette()
		add_child(_vignette)
		set_time(Stage.arg("--time", "night"))
		var c := Stage.arg("--cam").split_floats(",")
		if c.size() == 6:
			cam.position = Vector3(c[0], c[1], c[2])
			cam.look_at(Vector3(c[3], c[4], c[5]), Vector3.UP)
		var args := OS.get_cmdline_user_args()
		if "--play" in args:
			_play()
		if "--walk-test" in args:
			_walk_test.call_deferred()
		if "--walk-real" in args:
			_play()
			_walk_real.call_deferred()
		var st := Stage.still_args()
		if st[0] != "":
			_still(st[0], maxf(float(st[1]), 1.0))

func _still(path: String, at: float) -> void:
	await get_tree().create_timer(at).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("phong_tro: %s  draws %d  tris %d" % [path,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()

func build() -> void:
	if cam:
		return
	_tile_sizes = JSON.parse_string(FileAccess.get_file_as_string(TILES + "tiles.json"))
	gender = _gender()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_hdr_threshold = 0.9
	for lv in [1, 2, 3]:
		env.set_glow_level(lv, 1.0)
	env.adjustment_enabled = true
	_shell()
	_outside()
	_furnish()
	_lights()
	cam = Camera3D.new()
	cam.fov = 33.0
	add_child(cam)
	cam.position = CAM_POS
	cam.look_at(global_position + CAM_AT, Vector3.UP)
	hero = Chibi.new()
	add_child(hero)
	hero.build(Looks.load_saved())
	for g: GeometryInstance3D in hero.find_children("*", "GeometryInstance3D", true, false):
		g.layers = 2

static func _gender() -> String:
	var g := Stage.arg("--gender")
	if g in ["m", "f"]:
		return g
	Hero.load_saved()
	if Hero.gender in ["m", "f"]:
		return Hero.gender
	var l := Looks.load_saved()
	var bottom = l.get("bottom", {})
	if bottom is Dictionary and String(bottom.get("shape", "")) in ["skirt", "dress", "longskirt", "pleated"]:
		return "f"
	return "f" if String(l.get("hair", "")) in ["bob", "buns", "pigtails", "layered", "long", "ponytail", "twin", "braid"] \
		else "m"

func _surface(tile: String, tint := Color.WHITE, origin := Vector2.ZERO, clamp := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE_SHADER
	m.set_shader_parameter("tile_alb", load(TILES + tile + "_alb.png"))
	m.set_shader_parameter("tile_nrm", load(TILES + tile + "_nrm.png"))
	m.set_shader_parameter("has_nrm", true)
	var s = _tile_sizes.get(tile, 1.0)
	m.set_shader_parameter("tile_size", Vector2(s[0], s[1]) if s is Array else Vector2(s, s))
	m.set_shader_parameter("tile_origin", origin)
	m.set_shader_parameter("clamp_tile", clamp)
	m.set_shader_parameter("base_color", tint)
	m.set_shader_parameter("shadow_tint", Color(0.78, 0.78, 0.88))
	return m

func _box(root: Node3D, size: Vector3, c: Variant, pos: Vector3, shadow := false) -> void:
	Props._part(root, root, Props._box(size), c, pos, Vector3.ZERO, Vector3.ONE, shadow)

func _raw(size: Vector3, m: Material, pos: Vector3, cast: GeometryInstance3D.ShadowCastingSetting) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = cast
	add_child(mi)
	return mi

func _flat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

func _put(name: String, pos: Vector3, yaw := 0.0, s := 1.0) -> Node3D:
	var n := Furniture.place(self, name, pos, yaw, false)
	n.scale = Vector3.ONE * s

	var cast := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if pos.x < 0.6 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = cast
	return n

func _solid(x0: float, x1: float, z0: float, z1: float, h := 1.0) -> void:
	var size := Vector3(x1 - x0, h, z1 - z0)
	var at := Vector3((x0 + x1) / 2, h / 2, (z0 + z1) / 2)
	var b := BoxShape3D.new()
	b.size = size
	Props.solid(self, b, at)
	_boxes.append([at, size])

func _shell() -> void:
	var x0 := -W / 2
	var x1 := W / 2
	var z0 := -D / 2
	var shell := Node3D.new()
	add_child(shell)
	var wall := _surface("tuong_tro")
	var wall_side := _surface("tuong_tro", Color(0.97, 0.97, 0.99))
	_box(shell, Vector3(W + 0.5, 0.3, D + 0.4), Color("2e2724"), Vector3(0, -0.16, 0))
	_box(shell, Vector3(W, 0.02, D), _surface("gach_bong"), Vector3(0, -0.01, 0))

	var wl := WIN_X - WIN.x / 2
	var wr := WIN_X + WIN.x / 2
	var wb := WIN_Y - WIN.y / 2
	var wt := WIN_Y + WIN.y / 2
	_box(shell, Vector3(wl - x0 + 0.2, H, 0.2), wall, Vector3((x0 - 0.2 + wl) / 2, H / 2, z0 - 0.1), true)
	_box(shell, Vector3(x1 + 0.2 - wr, H, 0.2), wall, Vector3((wr + x1 + 0.2) / 2, H / 2, z0 - 0.1), true)
	_box(shell, Vector3(WIN.x, wb, 0.2), wall, Vector3(WIN_X, wb / 2, z0 - 0.1), true)
	_box(shell, Vector3(WIN.x, H - wt, 0.2), wall, Vector3(WIN_X, (wt + H) / 2, z0 - 0.1), true)
	_box(shell, Vector3(0.2, H, D + 0.2), wall_side, Vector3(x0 - 0.1, H / 2, -0.1), true)
	_box(shell, Vector3(0.2, H, D + 0.2), wall_side, Vector3(x1 + 0.1, H / 2, -0.1), true)
	var so := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var black := _flat(Color.BLACK)
	_raw(Vector3(W + 1.0, 0.1, D + 0.6), black, Vector3(0, H + 0.12, 0.3), so)
	_raw(Vector3(W + 1.0, 2.5, 0.2), black, Vector3(0, H + 1.25, z0 - 0.1), so)
	_raw(Vector3(0.2, 2.5, D + 0.6), black, Vector3(x0 - 0.1, H + 1.25, 0.1), so)
	_raw(Vector3(0.2, 2.5, D + 0.6), black, Vector3(x1 + 0.1, H + 1.25, 0.1), so)

	_box(shell, Vector3(W + 0.44, 0.08, 0.24), CAP, Vector3(0, H + 0.04, z0 - 0.1))
	_box(shell, Vector3(0.24, 0.08, D + 0.24), CAP, Vector3(x0 - 0.1, H + 0.04, -0.1))
	_box(shell, Vector3(0.24, 0.08, D + 0.24), CAP, Vector3(x1 + 0.1, H + 0.04, -0.1))
	_box(shell, Vector3(0.22, H + 0.08, 0.02), CAP, Vector3(x0 - 0.1, (H + 0.08) / 2, D / 2 + 0.01))
	_box(shell, Vector3(0.22, H + 0.08, 0.02), CAP, Vector3(x1 + 0.1, (H + 0.08) / 2, D / 2 + 0.01))

	var lip := Color("8a5a44")
	_box(shell, Vector3(W, 0.12, 0.015), lip, Vector3(0, 0.06, z0 + 0.008))
	_box(shell, Vector3(0.015, 0.12, D), lip, Vector3(x0 + 0.008, 0.06, 0))
	_box(shell, Vector3(0.015, 0.12, D), lip, Vector3(x1 - 0.008, 0.06, 0))
	_box(shell, Vector3(W, 0.03, 0.04), Color("6f5a48"), Vector3(0, 0.0, D / 2 - 0.02))

	_put("cua_so_nhom", Vector3(WIN_X, WIN_Y, z0))
	_put("rem_cua", Vector3(WIN_X, wt + 0.14, z0))
	_put("cua_phong_tro", Vector3(x1, 0, 0.8), -90.0)
	_put("cay_trau_ba", Vector3(WIN_X - 0.05, wb + 0.01, z0 + 0.06), 20.0)

	var fl := BoxShape3D.new()
	fl.size = Vector3(W + 1.0, 0.2, D + 1.0)
	Props.solid(self, fl, Vector3(0, -0.1, 0))
	_solid(x0 - 0.2, x1 + 0.2, z0 - 0.2, z0, 2.0)
	_solid(x0 - 0.2, x0, z0, D / 2, 2.0)
	_solid(x1, x1 + 0.2, z0, D / 2, 2.0)
	_solid(x0, x1, 1.6, 1.8, 2.0)

func _outside() -> void:
	var z := -D / 2 - 0.2 - GAP
	var o := Node3D.new()
	add_child(o)
	_neighbour_wall = _flat(Color("4d5058"))
	_raw(Vector3(W + 3.0, H + 3.0, 0.3), _neighbour_wall, Vector3(0, (H + 3.0) / 2 - 0.5, z - 0.15),
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_neighbour_pane = _flat(Color("ffd79a"), 1.0)
	_box(o, Vector3(0.9, 1.0, 0.02), _neighbour_pane, Vector3(WIN_X + 0.3, WIN_Y + 0.15, z + 0.02))

func _furnish() -> void:
	var x0 := -W / 2
	var x1 := W / 2
	var z0 := -D / 2

	_put("giuong_sat_don" + ("_nu" if gender == "f" else ""), Vector3(-1.7, 0, -1.1))
	_solid(-2.68, -0.72, -1.6, -0.6, 0.5)
	var phone := _put("phone", Vector3(-2.05, 0.5, -0.78), 80.0)
	_morning_only.append(phone)
	_put("day_den_nhay", Vector3(-2.62, 2.2, z0))
	_put("anh_gia_dinh", Vector3(-2.3, 1.35, z0))
	_put("tranh_que", Vector3(x0, 1.75, -1.0), 90.0)

	var dx := -0.15
	var dz := z0 + 0.27
	_put("ban_hoc_gap", Vector3(dx, 0, dz))
	_solid(-0.65, 0.35, -1.63, -1.13, 0.78)
	_laptop_voice(_put("laptop_mo", Vector3(dx + 0.05, 0.74, dz + 0.03), -14.0))
	_put("desk_lamp", Vector3(dx - 0.38, 0.74, dz - 0.1), 160.0)
	_put("noodle_cup", Vector3(dx + 0.36, 0.74, dz + 0.1), 20.0, 1.5)
	if gender == "f":
		_put("small_cactus", Vector3(dx + 0.42, 0.74, dz - 0.08), 0.0, 1.3)
	else:
		_put("energy_can", Vector3(dx + 0.42, 0.74, dz - 0.08), 0.0, 1.3)
	_put("paper_stack_low", Vector3(dx - 0.22, 0.74, dz + 0.12), 10.0)
	_put("plastic_stool_blue", Vector3(0.05, 0, -0.83), 15.0)
	_solid(-0.11, 0.21, -0.99, -0.67, 0.45)
	_put("lich_ghi_chu", Vector3(-0.1, 1.5, z0))
	_put("may_lanh_treo", Vector3(0.95, 2.38, z0))

	var sx := 1.2
	_put("ke_bep_tro", Vector3(sx, 0, z0 + 0.19))
	_solid(0.75, 1.65, -1.65, -1.28, 1.0)
	_put("thung_mi", Vector3(sx - 0.18, 0.055, z0 + 0.2), 4.0, 0.75)
	_put("dai_cu", Vector3(sx + 0.2, 0.776, z0 + 0.18), 0.0, 0.8)
	_put("ke_treo_bep", Vector3(sx, 1.55, z0))
	_clock(Vector3(sx, 2.0, z0 + 0.06))
	_put("thung_rac_tro", Vector3(1.86, 0, z0 + 0.25), 25.0)
	_solid(1.71, 2.01, -1.55, -1.25, 0.4)
	_put("tu_lanh_mini", Vector3(x1 - 0.36, 0, z0 + 0.32))
	_solid(2.08, 2.6, -1.62, -1.05, 1.0)
	_put("am_sieu_toc", Vector3(x1 - 0.44, 0.86, z0 + 0.28), 30.0, 0.8)
	_put("mug", Vector3(x1 - 0.22, 0.86, z0 + 0.42), -20.0)
	_put("balo_laptop", Vector3(0.56, 0, -1.2), -20.0)

	_put("ke_dep_tro", Vector3(x1 - 0.18, 0, -0.42), -90.0)
	_solid(2.36, 2.7, -0.75, -0.1, 0.5)
	_put("mu_bao_hiem", Vector3(x1 - 0.18, 0.45, -0.47), -110.0)
	_put("quat_treo_tuong", Vector3(x1, 2.1, -0.42), -90.0)
	var mat_at := Vector3(x1 - 0.48, 0.005, 0.8)
	_box(self, Vector3(0.42, 0.01, 0.66), _surface("tham_cua", Color.WHITE, Vector2(mat_at.x - 0.21, mat_at.z - 0.33), true),
		mat_at)
	_put("dep_le", Vector3(x1 - 0.5, 0.01, 0.62), -20.0)

	var wx := x0 + 0.23
	_put("tu_nhua_4_ngan", Vector3(wx, 0, 0.05), 90.0)
	_solid(-2.7, -2.24, -0.2, 0.3, 0.9)
	if gender == "f":
		_put("guong_ban", Vector3(wx + 0.02, 0.88, -0.1), 70.0)
		_put("strawberry_plush", Vector3(wx, 0.88, 0.14), 75.0)
	else:
		_put("mug", Vector3(wx + 0.05, 0.88, -0.07), 30.0)
		_put("headphones", Vector3(wx, 0.88, 0.15), 70.0)
	_put("moc_ao_tuong" + ("_nu" if gender == "f" else ""), Vector3(x0, 1.72, 0.1), 90.0)
	_put("chau_cay_nho", Vector3(x0 + 0.32, 0, 1.28))
	_solid(-2.56, -2.2, 1.1, 1.46, 0.6)

	var mx := -0.3
	var mz := 0.75
	_box(self, Vector3(1.8, 0.008, 1.2), _surface("chieu", Color.WHITE, Vector2(mx - 0.9, mz - 0.6), true),
		Vector3(mx, 0.006, mz))
	var tx := mx + 0.05
	var tz := mz + 0.12
	_put("ban_xep_thap", Vector3(tx, 0, tz))
	_solid(-0.61, 0.11, 0.64, 1.1, 0.34)
	_put("noodle_cup", Vector3(tx - 0.15, 0.32, tz + 0.02), 40.0, 1.5)
	_put("dem_ngoi", Vector3(tx, 0.008, tz - 0.48))

const VOICE := {
	"m": ["Game như này cho chó chơi à?!", "F5 đi anh em!", "Con game này chỉ dành cho trẻ con…", "Hế hế hế hê!",
		"Tất cả là tại con Linh!"],
	"f": ["Lá la la… a bộ PC…", "Sợ quá, sợ quá, phải ban nó thôi!", "Vui vẻ không quạu nha!",
		"Chúng tôi không làm gì sai cả!"],
}
const VOICE_CYCLE := 4.6

func _laptop_voice(laptop: Node3D) -> void:
	_laptop = laptop
	_voice_ui = CanvasLayer.new()
	_voice_ui.layer = 4
	add_child(_voice_ui)
	_rings = Control.new()
	_rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rings.draw.connect(_draw_rings)
	_voice_ui.add_child(_rings)
	_tail = Polygon2D.new()
	_tail.color = Color("fff8e7")
	_voice_ui.add_child(_tail)
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fff8e7")
	sb.border_color = Color("e2c99e")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0.1, 0.06, 0.04, 0.28)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	_bubble.add_theme_stylebox_override("panel", sb)
	_voice_label = Label.new()
	var fv := FontVariation.new()
	fv.base_font = load("res://fonts/Nunito[wght].ttf")
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	_voice_label.add_theme_font_override("font", fv)
	_voice_label.add_theme_font_size_override("font_size", 24)
	_voice_label.add_theme_color_override("font_color", Color("6b4a35"))
	_voice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.add_child(_voice_label)
	_voice_ui.add_child(_bubble)
	_voice_ui.visible = false

func _laptop_px() -> Vector2:
	return cam.unproject_position(_laptop.to_global(Vector3(0, 0.2, -0.12)))

func _draw_rings() -> void:
	if not _voice_on:
		return
	var p := _laptop_px()
	var vp := get_viewport().get_visible_rect().size
	var k := vp.y / 720.0
	for i in 3:
		var f := fmod(_voice_t * 1.1 + i / 3.0, 1.0)
		var r := (14.0 + f * 46.0) * k
		var a := (1.0 - f) * 0.55 * _bubble.modulate.a
		_rings.draw_arc(p, r, deg_to_rad(200), deg_to_rad(340), 24, Color(1.0, 0.95, 0.82, a), 3.0 * k, true)

func _voice_step(delta: float) -> void:
	if not _voice_on:
		return
	if Stage.still_args()[0] == "":
		_voice_t += delta
	if _voice_t >= VOICE_CYCLE:
		_voice_t -= VOICE_CYCLE
		_voice_k = (_voice_k + 1) % VOICE[gender].size()
	var t := _voice_t
	_voice_label.text = VOICE[gender][_voice_k]
	_voice_label.visible_ratio = clampf((t - 0.15) / 1.1, 0.0, 1.0)
	var a := clampf(t / 0.25, 0.0, 1.0) * clampf((3.9 - t) / 0.45, 0.0, 1.0)
	_bubble.modulate.a = a
	_tail.modulate.a = a
	var pop := 0.86 + 0.14 * (1.0 - pow(1.0 - clampf(t / 0.3, 0.0, 1.0), 3.0)) + 0.04 * sin(clampf(t / 0.3, 0.0, 1.0) * PI)
	var vp := get_viewport().get_visible_rect().size
	var k := vp.y / 720.0
	_bubble.scale = Vector2.ONE * pop * k
	var p := _laptop_px()
	var size := _bubble.get_combined_minimum_size() * _bubble.scale
	var top := p + Vector2(-size.x / 2.0 + 30.0 * k, -size.y - 70.0 * k)
	top.x = clampf(top.x, 12.0, vp.x - size.x - 12.0)
	_bubble.position = top
	_bubble.pivot_offset = _bubble.size / 2.0
	var bx := clampf(p.x, top.x + 26.0 * k, top.x + size.x - 26.0 * k)
	var by := top.y + size.y - 4.0 * k
	_tail.polygon = PackedVector2Array([Vector2(bx - 12.0 * k, by), Vector2(bx + 12.0 * k, by),
		p + Vector2(0, -26.0 * k)])
	_rings.queue_redraw()

func _clock(at: Vector3) -> void:
	var piv := Node3D.new()
	piv.position = at
	add_child(piv)
	var ink := _flat(Color("4a3a32"))
	var red := _flat(Color("d9534f"))
	for spec in [[0.018, 0.085, 0.004, ink], [0.013, 0.12, 0.008, ink], [0.005, 0.13, 0.012, red]]:
		var arm := Node3D.new()
		arm.position.z = spec[2]
		piv.add_child(arm)
		var b := BoxMesh.new()
		b.size = Vector3(spec[0], spec[1], 0.004)
		var mi := MeshInstance3D.new()
		mi.mesh = b
		mi.material_override = spec[3]
		mi.position.y = spec[1] / 2 - 0.015
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arm.add_child(mi)
		_clock_hands.append(arm)

func _process(delta: float) -> void:
	if _clock_hands.size() == 3:
		_clock_min += delta / 60.0
		var h := fmod(_clock_min / 60.0, 12.0)
		_clock_hands[0].rotation.z = -h / 12.0 * TAU
		_clock_hands[1].rotation.z = -fmod(_clock_min, 60.0) / 60.0 * TAU
		_clock_hands[2].rotation.z = -floorf(fmod(_clock_min * 60.0, 60.0)) / 60.0 * TAU
	_voice_step(delta)

func _lights() -> void:
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.5
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 14.0
	_sun.light_cull_mask = 1
	add_child(_sun)
	_sun.look_at_from_position(Vector3(WIN_X + 1.2, WIN_Y + 2.4, -D / 2 - 1.6), Vector3(WIN_X - 0.6, 0.4, -D / 2 + 0.9),
		Vector3.UP)
	var lamp := SpotLight3D.new()
	lamp.light_color = Color("ffc47e")
	lamp.light_energy = 1.4
	lamp.spot_range = 2.6
	lamp.spot_angle = 62.0
	lamp.spot_angle_attenuation = 1.3
	add_child(lamp)
	lamp.look_at_from_position(Vector3(-0.5, 1.15, -1.45), Vector3(-0.3, 0.35, -0.9), Vector3.UP)
	var fill := OmniLight3D.new()
	fill.light_color = Color("ffbe80")
	fill.light_energy = 0.3
	fill.omni_range = 3.0
	fill.omni_attenuation = 1.2
	fill.position = Vector3(-0.6, 1.4, -0.5)
	add_child(fill)
	var screen := OmniLight3D.new()
	screen.light_color = Color("9fbcff")
	screen.light_energy = 0.7
	screen.omni_range = 1.0
	screen.position = Vector3(-0.55, 0.95, -0.85)
	add_child(screen)
	var fairy := OmniLight3D.new()
	fairy.light_color = Color("ffc98a")
	fairy.light_energy = 0.7
	fairy.omni_range = 2.0
	fairy.position = Vector3(-1.6, 1.95, -1.25)
	add_child(fairy)
	_night_lights = [lamp, fill, screen, fairy]
	_hero_fill = OmniLight3D.new()
	_hero_fill.light_color = Color("ffe2bf")
	_hero_fill.light_energy = 0.6
	_hero_fill.omni_range = 1.2
	_hero_fill.light_cull_mask = 2
	_hero_fill.position = Vector3(-1.75, 1.05, -0.75)
	add_child(_hero_fill)
	_patch = SpotLight3D.new()
	_patch.light_color = Color("ffdcaa")
	_patch.light_energy = 1.3
	_patch.spot_range = 3.4
	_patch.spot_angle = 26.0
	_patch.spot_angle_attenuation = 0.7
	_patch.light_cull_mask = 1
	add_child(_patch)
	_patch.look_at_from_position(Vector3(WIN_X + 0.15, WIN_Y + 0.4, -D / 2 + 0.2), Vector3(WIN_X - 0.25, 0.3, -D / 2 + 1.25),
		Vector3.UP)

	var bars := _bars_texture()
	for q in [[Vector3(WIN_X - 0.1, 0.56, -1.05), Vector2(0.9, 0.75)], [Vector3(WIN_X - 0.35, 0.012, -0.2), Vector2(1.1, 0.8)]]:
		var m := StandardMaterial3D.new()
		m.albedo_texture = bars
		m.albedo_color = Color(1.0, 0.86, 0.62, 0.2)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		var pm := PlaneMesh.new()
		pm.size = q[1]
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = m
		mi.position = q[0]
		mi.rotation_degrees = Vector3(0, -12, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_morning_only.append(mi)

func _shaft() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.7, 0.07))
	g.add_point(0.6, Color(1.0, 0.9, 0.7, 0.03))
	g.set_color(1, Color(1.0, 0.9, 0.7, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_texture = gt
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var top := Vector3(WIN_X + 0.1, WIN_Y + 0.2, -D / 2 + 0.05)
	var foot := Vector3(WIN_X - 0.1, 0.4, -D / 2 + 1.0)
	var q := QuadMesh.new()
	q.size = Vector2(1.0, top.distance_to(foot) + 0.4)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = (top + foot) / 2.0
	mi.look_at(position + mi.position + (foot - top).cross(Vector3.RIGHT).normalized(), (top - foot).normalized())
	_morning_only.append(mi)

func _bars_texture() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := float(x) / n
			var v := float(y) / n
			var edge := smoothstep(0.0, 0.12, u) * smoothstep(1.0, 0.88, u) * smoothstep(0.0, 0.12, v) * smoothstep(1.0, 0.88, v)
			var bar := 1.0 - 0.75 * (1.0 - smoothstep(0.02, 0.05, absf(fposmod(u * 6.0, 1.0) - 0.5) - 0.42))
			var rail := 1.0 - 0.7 * (1.0 - smoothstep(0.015, 0.04, absf(v - 0.5)))
			var a := clampf(edge * bar * rail, 0.0, 1.0)
			img.set_pixel(x, y, Color(a, a, a, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _make_vignette() -> CanvasLayer:
	var cl := CanvasLayer.new()
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float strength = 0.55;
void fragment() {
	vec2 d = (UV - vec2(0.5, 0.47)) * vec2(1.0, 1.25);
	COLOR = vec4(0.03, 0.025, 0.05, smoothstep(0.32, 0.78, length(d)) * strength);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	cl.add_child(r)
	return cl

func set_time(t: String) -> void:
	time = t
	var night := t == "night"
	for l in _night_lights:
		l.visible = night
	_sun.visible = not night
	_patch.visible = not night
	for n in _morning_only:
		n.visible = not night
	Furniture.material("laptop_mo").set_shader_parameter("emit_strength", 0.9 if night else 0.0)
	Furniture.material("day_den_nhay").set_shader_parameter("emit_strength", 1.4 if night else 0.0)
	_clock_min = (22.0 * 60.0 + 40.0) if night else (9.0 * 60.0 + 40.0)
	if Stage.arg("--hour") != "":
		_clock_min = float(Stage.arg("--hour")) * 60.0
	if _voice_ui:
		_voice_on = night
		_voice_ui.visible = night
		if Stage.still_args()[0] != "":
			_voice_t = 2.0
	_neighbour_pane.emission_energy_multiplier = 1.2 if night else 0.0
	_neighbour_pane.albedo_color = Color("ffd79a") if night else Color("8f9aa0")
	_neighbour_wall.albedo_color = Color("4d5058") if night else Color("d7dcd8")
	_neighbour_wall.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if night \
		else BaseMaterial3D.SHADING_MODE_UNSHADED
	_hero_fill.visible = not night
	if night:
		env.background_color = Color("0f0e14")
		env.ambient_light_color = Color("6a77aa")
		env.ambient_light_energy = 0.33
		env.tonemap_exposure = 1.0
		env.adjustment_saturation = 1.0
	else:
		env.background_color = Color("1b1a20")
		env.ambient_light_color = Color("e6e4e4")
		env.ambient_light_energy = 0.52
		env.tonemap_exposure = 0.86
		env.adjustment_saturation = 1.04
		_sun.light_color = Color("fff0d8")
		_sun.light_energy = 1.5
	if not player:
		_pose(night)

func _pose(night: bool) -> void:
	"""Night: on the bed's foot, the phone in his hands, the laptop and lamp at his shoulder. Morning: lying, his
	head on the pillow, the phone beside it."""
	hero.rotation = Vector3.ZERO
	if night:
		hero.position = Vector3(-1.0, 0.065, -0.8)
		hero.play("Act_SitChair_Phone", 0.0)
		hero.hold("phone")
	else:
		hero.hold("")
		hero.position = Vector3(-1.62, 0.45, -1.15)
		hero.rotation.y = deg_to_rad(90.0)
		hero.play("Act_FaintLie", 0.0)

func _play() -> void:
	hero.visible = false
	player = Player.new()
	add_child(player)
	player.position = Vector3(SPOTS["door"].x, 0, SPOTS["door"].y)
	player.bounds_box = 10.0
	player.setup(Looks.load_saved(), cam)

func _walk_test() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = HERO_R
	cap.height = 1.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	var path_z := -0.15
	var bad := 0
	for id in SPOTS:
		var s: Vector2 = SPOTS[id]
		var pts := [SPOTS["door"], Vector2(SPOTS["door"].x, path_z), Vector2(s.x, path_z), s]
		var hit := ""
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var n := maxi(1, int(a.distance_to(b) / 0.05))
			for i in n + 1:
				var p := a.lerp(b, float(i) / n)
				q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, 0.55, p.y))
				if not space.intersect_shape(q, 1).is_empty():
					hit = "snag at (%.2f, %.2f)" % [p.x, p.y]
					break
			if hit != "":
				break
		print("walk %-9s %s" % [id, "OK" if hit == "" else hit])
		bad += int(hit != "")
	print("walk-test: %d of %d spots reachable" % [SPOTS.size() - bad, SPOTS.size()])
	if Stage.still_args()[0] == "":
		get_tree().quit()

func _walk_real() -> void:
	await get_tree().create_timer(0.5).timeout
	var path_z := -0.15
	var bad := 0
	for id in SPOTS:
		if id == "door":
			continue
		var s: Vector2 = SPOTS[id]
		var legs := [Vector3(SPOTS["door"].x, 0, path_z), Vector3(s.x, 0, path_z), Vector3(s.x, 0, s.y),
			Vector3(s.x, 0, path_z), Vector3(SPOTS["door"].x, 0, path_z), Vector3(SPOTS["door"].x, 0, SPOTS["door"].y)]
		var res := "arrived"
		for g in legs:
			res = await player.go_to(g, false, 0.12, 12.0)
			if res != "arrived":
				res = "%s near (%.2f, %.2f)" % [res, player.position.x, player.position.z]
				break
		print("walk-real %-9s %s" % [id, "OK" if res == "arrived" else res])
		bad += int(res != "arrived")
	print("walk-real: %d of %d spots walked to and back" % [SPOTS.size() - 1 - bad, SPOTS.size() - 1])
	get_tree().quit()

func show_in(we: WorldEnvironment, hide: Array) -> void:
	build()
	_swapped = {"env": we.environment, "hidden": []}
	we.environment = env
	for n in hide:
		if n is Node3D and n.visible:
			n.visible = false
			_swapped["hidden"].append(n)
	cam.current = true
	_vignette = _make_vignette()
	add_child(_vignette)
	_drift = create_tween().set_loops()
	_drift.tween_property(cam, "position:x", CAM_POS.x + 0.35, 14.0).set_trans(Tween.TRANS_SINE)
	_drift.tween_property(cam, "position:x", CAM_POS.x - 0.35, 14.0).set_trans(Tween.TRANS_SINE)

func hide_from(we: WorldEnvironment) -> void:
	if _drift:
		_drift.kill()
	if _vignette:
		_vignette.queue_free()
		_vignette = null
	if _swapped.has("env"):
		we.environment = _swapped["env"]
		for n in _swapped["hidden"]:
			n.visible = true
	_swapped = {}
	cam.current = false
