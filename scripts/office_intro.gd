extends "res://scripts/office.gd"

const CityKit := preload("res://scripts/intro/city_kit.gd")
const Tower := preload("res://scripts/intro/tower.gd")
const Street := preload("res://scripts/intro/street.gd")
const Rain := preload("res://scripts/intro/rain.gd")
const CITY_LAYER := 4
const LENGTH := 15.0

const PATH := [
	[0.0, Vector3(30.0, -30.75, -13.4), Vector3(0.0, -27.8, -12.6), 46.0],
	[2.8, Vector3(23.5, -29.6, -14.6), Vector3(0.0, -24.5, -8.0), 47.0],
	[4.6, Vector3(19.0, -21.0, -19.0), Vector3(-1.0, -4.0, -4.0), 52.0],
	[6.4, Vector3(15.0, -11.0, -36.0), Vector3(-0.5, 12.0, -1.0), 56.0],
	[7.7, Vector3(11.0, -7.0, -34.0), Vector3(-1.0, 11.0, -1.5), 54.0],
	[9.8, Vector3(-1.95, 1.4, -7.2), Vector3(-2.0, 1.2, -3.6), 42.0],
	[10.6, Vector3(-2.3, 1.0, -4.9), Vector3(-2.5, 0.95, -2.0), 45.0],
	[11.1, Vector3(-2.45, 0.93, -3.55), Vector3(-3.3, 0.95, -1.5), 48.0],
	[11.8, Vector3(-3.0, 0.98, -2.6), Vector3(-4.2, 1.0, -0.9), 50.0],
	[12.5, Vector3(-3.95, 1.2, -2.0), Vector3(-3.95, 1.0, 0.8), 50.0],
	[13.4, Vector3(-4.2, 1.42, -0.6), Vector3(-2.6, 0.95, -0.3), 44.0],
	[15.0, Vector3(-3.9, 1.55, 1.75), Vector3(-2.3, 0.92, -0.5), 36.0],
]

const FLASHES := [[3.0, 1.0, true], [7.0, 0.5, false], [13.0, 0.3, false]]
const HAZE := Color("2a2c4e")

var kit
var tower
var street
var rain
var city: Node3D
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial
var flash_light: DirectionalLight3D
var flash_t := -1.0
var flash_k := 0.0
var bolt: Node3D
var glass_mats: Array = []
var glow_quads: Array = []
var far_glow: StandardMaterial3D
var white: ColorRect
var bars: Array = []
var stamp: Label
var shot_t := 0.0
var fired := {}
var env: Environment
var amb0 := 0.0
var hold_cam: PackedFloat64Array
var _street_hidden := false
var in_room := 0.0
var still_mode := false
var frames_dir := ""
var frame_n := 0
var asleep := true
var cam_override: Array = []
var ending: IntroEnding
var ending_done := false
var story := false

func _init() -> void:
	forced_time = "night"
	forced_sit = "Act_SitChair_Slump"

func _ready() -> void:
	super._ready()
	fixed_view = true
	_snore()
	ending = IntroEnding.new()
	add_child(ending)
	env = (find_child("WorldEnvironment", false, false) as WorldEnvironment).environment

	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/night_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_enabled = true
	env.fog_light_color = HAZE
	env.fog_density = 0.011
	env.fog_sky_affect = 0.0
	env.fog_height = Street.STREET_Y + 6.0
	env.fog_height_density = 0.04
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	amb0 = env.ambient_light_energy
	_build_outside()
	_dark_screens()
	_lightning_rig()
	_interior_mood()
	_overlay()
	hold_cam = Stage.arg("--cam").split_floats(",")
	still_mode = still.size() == 2 and still[0] != ""
	frames_dir = Stage.arg("--frames")
	if frames_dir != "":
		DirAccess.make_dir_recursive_absolute(frames_dir)
		RenderingServer.frame_post_draw.connect(_save_frame)
	Story.load_saved()
	story = not Story.opening_done and Story.beat in ["night", "job", "work"] and frames_dir == "" \
		and not OS.get_cmdline_user_args().has("--auto") and hold_cam.size() < 6
	if story:
		Narrator.taps = true
		Narrator.skippable = Story.beat == "night"
		Narrator.skip_requested.connect(_on_skip)
		if Story.beat in ["job", "work"]:
			_skip_shot()
	_camera_at(0.0)

func _build_window_view() -> void:
	pass

func _build_outside() -> void:
	var hx := ROOM.x / 2.0
	var hz := ROOM.y / 2.0
	var zf := -hz - 0.2

	Props._part(world, world, Props._box(Vector3(ROOM.x + 0.4, 0.4, ROOM.y)), Color("e9e2d6"), Vector3(0, 3.0, 0))
	Props._part(world, world, Props._box(Vector3(ROOM.x + 0.4, 2.8, 0.2)), surface("wall"), Vector3(0, 1.4, hz + 0.1))

	var piers := 5
	for i in piers:
		var cx := -hx + ROOM.x * (i + 0.5) / piers
		_glass(Vector3(cx, 1.6, zf + 0.06), Vector2(ROOM.x / piers - 0.3, 1.7), 1.0 if i == 1 else 0.3)
	_window_glow(Vector3(-1.8, 1.55, zf + 0.25), Vector2(1.6, 1.8), Color("ffbf6a"), 0.6)
	_window_glow(Vector3(-0.0, 1.55, zf + 0.25), Vector2(1.6, 1.8), Color("ffbf6a"), 0.16)

	far_glow = _window_glow(Vector3(-1.8, 1.6, zf - 0.42), Vector2(2.8, 2.8), Color("ffb860"), 0.0, Vector2(0.5, 0.5))

	city = Node3D.new()
	city.name = "City"
	add_child(city)
	kit = CityKit.new(city)
	tower = Tower.new()
	tower.build(kit, zf, hx)
	street = Street.new()
	street.build(kit, zf - Tower.PIER_D, Tower.HX)
	kit.add_source(Vector3(-1.8, 1.4, zf - 0.6), 3.5, Color("ffbf6a"), 0.8)
	rain = Rain.new()
	rain.build(kit, self, Street.STREET_Y)
	kit.finish()
	_to_city_layer.call_deferred()
	moon = DirectionalLight3D.new()
	moon.light_color = Color("aab4ff")
	moon.light_energy = 0.2
	moon.light_cull_mask = CITY_LAYER
	moon.shadow_enabled = false
	add_child(moon)
	moon.look_at_from_position(Vector3(-30, 40, -50), Vector3.ZERO, Vector3.UP)

func _to_city_layer() -> void:
	for v in city.find_children("*", "VisualInstance3D", true, false):
		(v as VisualInstance3D).layers = CITY_LAYER

func _window_glow(pos: Vector3, size: Vector2, c: Color, alpha: float, centre := Vector2(0.45, 0.65)) -> StandardMaterial3D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = centre
	tex.fill_to = Vector2(centre.x, centre.y - 0.65)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	q.mesh = qm
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = pos
	world.add_child(q)
	if alpha > 0.0:
		glow_quads.append([q, alpha])
	m.disable_fog = true
	return m

func _glass(pos: Vector3, size: Vector2, glow: float) -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	q.mesh = qm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/intro_glass.gdshader")
	m.set_shader_parameter("pane", size)
	m.set_shader_parameter("glow", glow)
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = pos
	world.add_child(q)
	glass_mats.append(m)

func _dark_screens() -> void:
	var off: Material = OfficeProps._screen_mats.get("off")
	if off == null:
		return
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/intro_screen_off.gdshader")
	for n in world.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.material_override == off:
			mi.material_override = m

func _interior_mood() -> void:
	var h := HERO_DESK
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffb867")
	lamp.light_energy = 0.55
	lamp.omni_range = 2.3
	lamp.light_cull_mask = 2
	lamp.position = h + Vector3(0.38, OfficeProps.TOP + 0.45, 0.12)
	add_child(lamp)
	var city_fill := DirectionalLight3D.new()
	city_fill.light_color = Color("8ea0ff")
	city_fill.light_energy = 0.22
	city_fill.light_cull_mask = 2
	add_child(city_fill)
	city_fill.look_at_from_position(Vector3(-1.5, 3.0, -4.0), Vector3(-2.0, 0.5, 0.5), Vector3.UP)
	_glow(h + Vector3(0.2, OfficeProps.TOP + 0.01, 0.1), Vector2(2.2, 1.6), Color("ffc06a"), 0.35, true)
	_glow(h + Vector3(0.1, 0.025, 0.7), Vector2(4.0, 3.4), Color("ffa850"), 0.28, true)
	for i in 5:
		var cx := -ROOM.x / 2.0 + ROOM.x * (i + 0.5) / 5.0
		_glow(Vector3(cx, 0.02, -2.6), Vector2(1.5, 1.8), Color("7f8cff"), 0.12, false)

func _lightning_rig() -> void:
	flash_light = DirectionalLight3D.new()
	flash_light.light_color = Color("c4ccff")
	flash_light.light_energy = 0.0
	flash_light.shadow_enabled = false
	add_child(flash_light)
	flash_light.look_at_from_position(Vector3(-20, 30, -45), Vector3(0, 0, 0), Vector3.UP)

	bolt = Node3D.new()
	add_child(bolt)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.6, 1.65, 2.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var p := Vector3.ZERO
	var w := 0.5
	while p.y > -40.0:
		var q := p + Vector3(rng.randf_range(-4.0, 4.0), -rng.randf_range(4.0, 7.0), rng.randf_range(-1.0, 1.0))
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, w, (q - p).length())
		seg.mesh = bm
		seg.material_override = m
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bolt.add_child(seg)
		seg.look_at_from_position((p + q) / 2.0, q, Vector3.FORWARD)
		p = q
		w = maxf(0.22, w * 0.9)
	bolt.visible = false

func _flash(k: float, show_bolt: bool) -> void:
	flash_t = 0.0
	flash_k = k
	bolt.visible = show_bolt
	if show_bolt:
		var b := cam.global_transform.basis
		var at := cam.global_position - b.z * 150.0 - b.x * 40.0
		bolt.global_position = Vector3(at.x, cam.global_position.y + 38.0, at.z)
		var d := at - cam.global_position
		sky_mat.set_shader_parameter("flash_dir", Vector2(d.x, d.z).normalized())

func _update_flash(delta: float) -> void:
	if flash_t < 0.0:
		return
	flash_t += delta

	var e := 0.0
	if flash_t < 0.06:
		e = flash_t / 0.06
	elif flash_t < 0.12:
		e = 0.35
	elif flash_t < 0.18:
		e = 1.0
	else:
		e = maxf(0.0, 1.0 - (flash_t - 0.18) / 0.5)
	e *= flash_k
	flash_light.light_energy = 0.55 * e
	sky_mat.set_shader_parameter("flash", e)
	env.ambient_light_energy = amb0 + 0.12 * e + 0.1 * in_room
	white.color.a = 0.04 * e
	kit.set_flash(e)
	rain.set_flash(e)
	for m in street.ground_mats:
		m.set_shader_parameter("flash", e)
	for m in glass_mats:
		m.set_shader_parameter("flash", e)
	if flash_t > 0.2:
		bolt.visible = false
	if flash_t > 0.8:
		flash_t = -1.0

func _overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	white = ColorRect.new()
	white.color = Color(0.85, 0.88, 1.0, 0)
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(white)
	for top in [true, false]:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.anchor_left = 0.0
		b.anchor_right = 1.0
		b.anchor_top = 0.0 if top else 0.885
		b.anchor_bottom = 0.115 if top else 1.0
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(b)
		bars.append(b)
	stamp = Label.new()
	stamp.text = tr("INTRO_STAMP")
	stamp.add_theme_font_size_override("font_size", 34)
	stamp.add_theme_color_override("font_color", Color("e9e4f5"))
	stamp.anchor_left = 0.06
	stamp.anchor_top = 0.905
	stamp.modulate.a = 0.0
	layer.add_child(stamp)
	ending.setup(self, layer)
	ending.finished.connect(_on_ending_finished)

func _key_at(time: float) -> float:
	var n := PATH.size()
	var ts: Array[float] = []
	for k in PATH:
		ts.append(k[0])
	time = clampf(time, ts[0], ts[n - 1])
	var slopes: Array[float] = []
	for i in n:
		if i == n - 1:
			slopes.append(0.0)
		elif i == 0:
			slopes.append(1.0 / (ts[1] - ts[0]))
		else:
			var a := ts[i] - ts[i - 1]
			var b := ts[i + 1] - ts[i]
			slopes.append(2.0 / (a + b))
	var i := 0
	while i < n - 2 and time > ts[i + 1]:
		i += 1
	var h := ts[i + 1] - ts[i]
	var s := (time - ts[i]) / h
	var h00 := 2 * s * s * s - 3 * s * s + 1
	var h10 := s * s * s - 2 * s * s + s
	var h01 := -2 * s * s * s + 3 * s * s
	var h11 := s * s * s - s * s
	return h00 * i + h10 * h * slopes[i] + h01 * (i + 1) + h11 * h * slopes[i + 1]

func _camera_at(time: float) -> void:
	var pos: Vector3
	var look: Vector3
	var fov: float
	if cam_override.size() == 3:
		pos = cam_override[0]
		look = cam_override[1]
		fov = cam_override[2]
	elif hold_cam.size() >= 6:
		pos = Vector3(hold_cam[0], hold_cam[1], hold_cam[2])
		look = Vector3(hold_cam[3], hold_cam[4], hold_cam[5])
		fov = hold_cam[6] if hold_cam.size() > 6 else 46.0
	else:
		var u := _key_at(time)
		var k := mini(int(u), PATH.size() - 2)
		var f := u - k
		var p0: Array = PATH[maxi(k - 1, 0)]
		var a: Array = PATH[k]
		var b: Array = PATH[k + 1]
		var p3: Array = PATH[mini(k + 2, PATH.size() - 1)]
		pos = _cr(p0[1], a[1], b[1], p3[1], f)
		look = _cr(p0[2], a[2], b[2], p3[2], f)
		fov = lerpf(a[3], b[3], smoothstep(0.0, 1.0, f))
	cam.position = pos
	cam.look_at(look, Vector3.UP)
	cam.fov = fov
	for gq in glow_quads:
		var mi: MeshInstance3D = gq[0]
		var m := mi.material_override as StandardMaterial3D
		m.albedo_color.a = gq[1] * smoothstep(2.0, 5.5, pos.distance_to(mi.position))
	if far_glow:
		far_glow.albedo_color.a = 0.75 * smoothstep(5.0, 22.0, pos.distance_to(Vector3(-1.8, 1.6, -3.7)))
	if rain:
		var inside := pos.z > -3.64 and absf(pos.x) < ROOM.x / 2.0 and pos.y > -0.3 and pos.y < 3.0
		in_room = lerpf(in_room, 1.0 if inside else 0.0, 0.08) if not still_mode else (1.0 if inside else 0.0)
		rain.follow(pos, inside, -ROOM.y / 2.0 - 0.2)
		if inside and not _street_hidden and shot_t > 11.0:
			_hide_low_city()

func _save_frame() -> void:
	if shot_t <= 0.0:
		return
	get_viewport().get_texture().get_image().save_png(frames_dir.path_join("f_%04d.png" % frame_n))
	frame_n += 1
	if ending_done:
		get_tree().quit()

func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u: float) -> Vector3:
	var d01 := maxf(p0.distance_to(p1), 1e-4)
	var d12 := maxf(p1.distance_to(p2), 1e-4)
	var d23 := maxf(p2.distance_to(p3), 1e-4)
	var m1: Vector3 = (p2 - p0) * d12 / (d01 + d12) if p0 != p1 else p2 - p1
	var m2: Vector3 = (p3 - p1) * d12 / (d12 + d23) if p2 != p3 else p2 - p1
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * p1 + (u3 - 2.0 * u2 + u) * m1 + (-2.0 * u3 + 3.0 * u2) * p2 + (u3 - u2) * m2

func _process(delta: float) -> void:
	shot_t += delta
	_camera_at(shot_t)
	for f in FLASHES:
		if shot_t >= f[0] and not fired.has(f[0]):
			fired[f[0]] = true
			_flash(f[1], f[2])
	_update_flash(delta)
	if flash_t < 0.0:
		env.ambient_light_energy = amb0 + 0.1 * in_room
	tower.update(shot_t)
	stamp.modulate.a = smoothstep(0.5, 2.0, shot_t) * (1.0 - smoothstep(LENGTH - 2.5, LENGTH - 1.0, shot_t))
	if still.size() == 2 and still[0] != "" and shot_t >= still[1]:
		set_process(false)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(still[0])
		get_tree().quit()
	if shot_t >= LENGTH and not fired.has("ending") and hold_cam.size() < 6:
		fired["ending"] = true
		ending.run()

func _on_skip() -> void:
	if Story.beat == "night":
		_skip_shot()
		ending.skip_night()
	elif Story.beat == "work":
		ending.skip_work()
	elif Story.beat == "monday":
		Narrator.clear()
		Narrator.skippable = false
		_on_ending_finished()

func _skip_shot() -> void:
	"""Jump to the end of the fly-in (its flashes spent), the ending already under way."""
	shot_t = maxf(shot_t, LENGTH)
	for f in FLASHES:
		fired[f[0]] = true
	fired["ending"] = true
	if Story.beat in ["job", "work"]:
		ending.run.call_deferred()

func _on_ending_finished() -> void:
	if ending_done:
		return
	ending_done = true
	if frames_dir != "" or OS.get_cmdline_user_args().has("--auto"):
		await get_tree().process_frame
		get_tree().quit()
		return
	get_tree().change_scene_to_file("res://scenes/office.tscn")

func _snore() -> void:
	while is_inside_tree() and asleep:
		await get_tree().create_timer(2.4).timeout
		if player and player.chibi and asleep:
			EmoteFx.play(player.chibi, "z", 0.0)

func _hide_low_city() -> void:
	_street_hidden = true
	var limit := -4.0
	for n in city.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		var box := g.global_transform * g.get_aabb()
		if box.end.y < limit:
			g.visible = false
