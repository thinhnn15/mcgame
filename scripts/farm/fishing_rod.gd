class_name FishingRod
extends Node3D

const CAST := 3.0
const SEE := 2.5
const SPOOK := 0.6
const TOOL_CLIPS := "res://data/tool_clips.json"
const FLOAT := "res://characters/tools/rod_float.glb"
const ROD_TIP := Vector3(-0.53, -1.47, 0.782)
const GRIP := Vector3(-0.53, 0.03, 0.782)

const COLORS := {"mFloatRed": Color("ef4f4f"), "mFloatWhite": Color("fbfbf4")}

var player: Player
var school: FishSchool
var ctx_fn: Callable
var state := "carry"
var bob: Node3D
var line: MeshInstance3D
var line_mesh := ImmediateMesh.new()
var bang: Label3D
var say: Label3D
var book: CanvasLayer
var land := Vector3.ZERO
var water_y := 0.0
var cast_from := Vector3.ZERO
var lured = null
var row := {}
var held: FarmAnimal
var held_len := 0.4
var t := 0.0
var state_t := 0.0
var look_t := 0.0
var nib_left := 0
var nib_t := 0.0
var dips: Array = []
var window := 0.9
var release_f := 22
var fish_out_f := 18
var fly_from := Vector3.ZERO
var fly_t := -1.0
var fly_len := 0.55
var fly_to_tip := false
var auto := false
var _yaw_back := 0.0
var _dfly: FarmAnimal
var _dfly_core = null
var _dfly_clip := ""
var _float_t := 0.0

static func attach(parent: Node, player_: Player, school_: FishSchool, ctx: Callable) -> FishingRod:
	var r := FishingRod.new()
	r.name = "FishingRod"
	r.player = player_
	r.school = school_
	r.ctx_fn = ctx
	parent.add_child(r)
	return r

func _ready() -> void:
	top_level = true
	AnimPacks.need("fishing")
	FishTable.load_table()
	var tc = JSON.parse_string(FileAccess.get_file_as_string(TOOL_CLIPS)) if FileAccess.file_exists(TOOL_CLIPS) else null
	if tc is Dictionary and tc.has("_events"):
		release_f = int(tc["_events"]["Tool_Rod_Swing"]["release"])
		fish_out_f = int(tc["_events"]["Tool_Rod_Catch"]["fish_out"])
	bob = load(FLOAT).instantiate()
	add_child(bob)
	_paint(bob.find_children("*", "MeshInstance3D", true, false))
	bob.visible = false
	line = MeshInstance3D.new()
	line.mesh = line_mesh
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1, 1, 1, 0.85)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	line.material_override = lm
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	bang = _label("!", 150, Color("e8453c"))
	say = _label("", 46, Color("5b4a44"))
	book = FishLog.panel(self)
	add_child(book)
	player.tool_pressed.connect(press)

func _label(text: String, size: int, c: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.outline_size = 18
	l.modulate = c
	l.outline_modulate = Color("fffaf2")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.visible = false
	add_child(l)
	return l

func _paint(meshes: Array) -> void:
	for mi in meshes:
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(s)
			var nm := src.resource_name if src else ""
			if not COLORS.has(nm):
				continue
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m == null:
				m = ShaderMaterial.new()
				m.shader = Props.TOON
				mi.set_surface_override_material(s, m)
			m.set_shader_parameter("base_color", COLORS[nm])

func _unhandled_input(e: InputEvent) -> void:
	if (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_L) or \
			(e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_BACK):
		FishLog.toggle(book)

func _holding() -> bool:
	return player.chibi != null and player.chibi.tool == "rod"

func _anim() -> AnimationPlayer:
	return player.chibi.anim

func _tip() -> Vector3:
	return player.chibi.posed_point("Z_Pole", ROD_TIP)

func _fwd() -> Vector3:
	return Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))

func press() -> void:
	if not _holding() and state != "show":
		return
	match state:
		"carry":
			_cast()
		"wait":
			_strike(false)
		"bite":
			_strike(true)
		"show":
			_bag()

func _landing() -> Vector3:
	var p := player.global_position
	var d := CAST + 0.5
	while d >= 1.0:
		var q := p + _fwd() * d
		var w := Water.at(q.x, q.z)
		if not is_nan(w.x) and w.y > 0.12:
			return Vector3(q.x, w.x, q.z)
		d -= 0.25
	return Vector3.INF

func _cast() -> void:
	var at := _landing()
	state = "cast"
	state_t = 0.0
	cast_from = player.global_position
	_hide_hint()
	player.chibi.play("Tool_Rod_Aim", 0.0)
	_anim().play("Tool_Rod_Swing", 0.1)
	_anim().queue("Tool_Rod_Aim")
	await get_tree().create_timer(float(release_f) / 30.0).timeout
	if at == Vector3.INF:
		_say(tr("FISH_NO_WATER"), 1.6)
		_end_cast()
		return
	land = at
	water_y = at.y
	bob.visible = true
	_fly(_tip(), land, 0.55, false)
	await get_tree().create_timer(0.55).timeout
	if state != "cast":
		return
	_splash(land, 8)
	school.scare(land, SPOOK)
	state = "wait"
	state_t = 0.0
	look_t = randf_range(0.8, 2.0)
	lured = null
	dips.clear()

func _end_cast() -> void:
	"""The float reeled straight back in, nothing on."""
	state = "strike"
	_anim().play("Tool_Rod_Air", 0.08)
	_anim().queue("Base_Wait")
	player.chibi.play("Base_Wait", 0.0)
	await get_tree().create_timer(0.23).timeout
	if bob.visible:
		_fly(bob.global_position, Vector3.ZERO, 0.35, true)
	await get_tree().create_timer(0.6).timeout
	bob.visible = false
	state = "carry"
	state_t = 0.0

func _strike(hooked: bool) -> void:
	bang.visible = false
	if not hooked:
		if lured != null:
			school.let_go(lured)
			lured = null
		_end_cast()
		return
	state = "strike"
	var f: Dictionary = lured
	lured = null
	var cm := school.cm_of(f)
	school.take(f)
	_anim().play("Tool_Rod_Catch", 0.08)
	await get_tree().create_timer(float(fish_out_f) / 30.0).timeout
	_splash(bob.global_position, 14)
	_fly(bob.global_position, Vector3.ZERO, 0.3, true)
	await get_tree().create_timer(1.0 - float(fish_out_f) / 30.0).timeout

	state = "show"
	state_t = 0.0
	cast_from = player.global_position
	bob.visible = false
	_yaw_back = player.rotation.y
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var d := cam.global_position - player.global_position
		player.rotation.y = atan2(d.x, d.z)
		player.facing = player.rotation.y
	for mi in player.chibi.parts.get("tool", []):
		mi.visible = false
	var kind: String = f.kind
	held = FarmAnimal.spawn(self, kind.get_slice(":", 0), Vector3.ZERO, 0.0, kind.get_slice(":", 1) if kind.contains(":") else "")
	held.top_level = true
	held_len = clampf(cm / 100.0 * 0.9, 0.26, 0.62)
	if held.anim and held.anim.has_animation("Held"):
		held.play("Held", 0.0)
	_anim().play("Tool_Rod_Get", 0.1)
	_anim().queue("Tool_Rod_GetKeep")
	player.chibi.play("Tool_Rod_GetKeep", 0.0)
	player.chibi.emote("proud")
	FishLog.dry = auto
	var news := FishLog.add(kind, cm)
	Progress.load_saved()
	var bonus := 0 if auto else int(Progress.skills().get("skills", {}).get("cau_ca", {}).get("rarity_bonus", {}).get(row.get("rarity", ""), 0))
	if not auto:
		Progress.act("cau_duoc")
	if bonus > 0:
		Progress.story({"cau_ca": bonus})
	var txt := Lang.t("FISH_CAUGHT", {"fish": tr(row.get("name", "FISH_CARP"))}) + "\n" + Lang.t("FISH_CM", {"cm": "%.0f" % cm})
	if news == "new":
		txt += " · " + tr("FISH_NEW")
	elif news == "best":
		txt += " · " + tr("FISH_BEST")
	if row.get("release", false):
		txt += "\n" + tr("FISH_LET_GO")
	say.text = txt
	say.visible = true

func _bag() -> void:
	state = "bag"
	say.visible = false
	if row.get("release", false) and held != null:
		_splash(player.global_position + _fwd() * 0.9 + Vector3(0, -0.2, 0), 10)
	if held != null:
		held.queue_free()
		held = null
	if not auto or Vector2(player.global_position.x - cast_from.x, player.global_position.z - cast_from.z).length() < 0.3:
		player.rotation.y = _yaw_back
		player.facing = _yaw_back
	_anim().play("Tool_Rod_Putback", 0.12)
	_anim().queue("Base_Wait")
	player.chibi.play("Base_Wait", 0.0)
	await get_tree().create_timer(0.15).timeout
	for mi in player.chibi.parts.get("tool", []):
		mi.visible = true
	await get_tree().create_timer(0.7).timeout
	state = "carry"
	state_t = 0.0

func _say(text: String, secs: float) -> void:
	say.text = text
	say.visible = true
	get_tree().create_timer(secs).timeout.connect(func(): if state != "show": say.visible = false)

func _hide_hint() -> void:
	if state != "show":
		say.visible = false

func _fly(from: Vector3, to: Vector3, secs: float, to_tip: bool) -> void:
	fly_from = from
	if not to_tip:
		land = to
	fly_len = secs
	fly_t = 0.0
	fly_to_tip = to_tip

func _splash(at: Vector3, n: int) -> void:
	var p := CPUParticles3D.new()
	var s := Props.sphere(0.035)
	s.material = Props.mat(Color("ffffff"))
	p.mesh = s
	p.amount = n
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.6
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -6, 0)
	add_child(p)
	p.global_position = at + Vector3(0, 0.02, 0)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func _look() -> void:
	"""A hungry fish near the float that is about now and open to the hero turns and comes to it."""
	var ctx: Dictionary = ctx_fn.call() if ctx_fn.is_valid() else {}
	for f in school.near(land, SEE):
		var r := FishTable.row(f.kind)
		if not FishTable.biting(r, ctx):
			continue
		if randf() < float(r.get("wary", 0.3)) * 0.6:
			continue
		row = r
		lured = f
		school.lure(f, land)
		nib_left = randi_range(int(r["nibbles"][0]), int(r["nibbles"][1]))
		nib_t = randf_range(0.6, 1.2)
		window = float(r.get("window", 0.9))
		return
	look_t = randf_range(1.5, 3.0)

func _wait_step(delta: float) -> void:
	if lured != null and (lured.state != "bait" or not lured in school.fish):
		lured = null
		look_t = randf_range(2.0, 4.0)
	if lured == null:
		look_t -= delta
		if look_t <= 0.0:
			_look()
		return
	if not lured.get("there", false):
		return
	nib_t -= delta
	if nib_t > 0.0:
		return
	if nib_left > 0:
		nib_left -= 1
		lured.gap = 0.0
		dips.append(state_t)
		school._fx.ring(land, 0.02, 0.18, 1.2, 0.5)
		get_tree().create_timer(0.18).timeout.connect(func(): if lured != null: lured.gap = 0.14)
		nib_t = randf_range(0.7, 1.4)
		return
	state = "bite"
	state_t = 0.0
	lured.gap = 0.0
	_splash(land, 12)
	bang.visible = true

func _process(delta: float) -> void:
	t += delta
	state_t += delta
	var moved := Vector2(player.global_position.x - cast_from.x, player.global_position.z - cast_from.z).length()
	if state in ["wait", "bite"] and moved > 0.3:
		bang.visible = false
		if lured != null:
			school.let_go(lured)
			lured = null
		state = "carry"
		state_t = 0.0
		bob.visible = false
	elif state == "show" and moved > 0.3:
		_bag()
	elif state == "carry":
		bob.visible = _holding()
	if state == "wait":
		_wait_step(delta)
	elif state == "bite" and state_t > window:
		bang.visible = false
		if lured != null:
			school.let_go(lured)
			lured = null
		state = "wait"
		state_t = 0.0
		look_t = randf_range(2.5, 4.5)
	if auto:
		_auto_step()
	_float_step(delta)
	if held != null:
		_hold_step()
	_visitor_step(delta)
	bang.global_position = player.global_position + Vector3(0, 1.85, 0)
	say.global_position = player.global_position + Vector3(0, 2.0, 0)

func _visitor_step(delta: float) -> void:
	if _dfly_core == null:
		if not ClassDB.class_exists("FarmCritters"):
			return
		_dfly_core = ClassDB.instantiate("FarmCritters")
		_dfly_core.add_visitor()
		var kind := "chuon_kim" if randf() < 0.45 else "chuon_chuon"
		_dfly = FarmAnimal.spawn(self, kind, Vector3.ZERO, 0.0, FarmAnimal.COATS[kind].pick_random())
		_dfly.top_level = true
		_dfly.visible = false
	var h := Clock.hour()
	_float_t = _float_t + delta if state in ["wait", "bite"] else 0.0
	var want := state == "wait" and _float_t > 2.0 and h >= 7.0 and h < 17.5 and not Clock.raining() and _holding()
	var tip := _tip()
	_dfly_core.set_perch(0, tip + Vector3(0, 0.006, 0), want)
	_dfly_core.step(delta, Vector3(1e4, 0, 1e4), 0.0)
	_dfly.visible = _dfly_core.shown(0)
	if not _dfly.visible:
		return
	_dfly.global_position = _dfly_core.pos(0)
	if _dfly_core.state_name(0) in ["settled", "land"]:
		var d := tip - player.chibi.posed_point("Z_Pole", ROD_TIP + Vector3(0, 0.15, 0))
		var dn := d.normalized() if d.length() > 1e-4 else _fwd()
		_dfly.rotation = Vector3(clampf(-asin(dn.y), -0.45, 0.45), atan2(dn.x, dn.z), 0.0)
	else:
		_dfly.rotation = Vector3(0.0, _dfly_core.yaw(0), 0.0)
	var cl: String = _dfly_core.clip(0)
	if cl != _dfly_clip:
		_dfly_clip = cl
		_dfly.play(cl, 0.1)

func _auto_step() -> void:
	if (state == "carry" and _holding() and state_t > 1.2) or (state == "bite" and state_t > 0.22) or 			(state == "show" and state_t > 2.8):
		press()
	if state == "carry" and state_t > 1.2:
		state_t = 0.0

func _float_step(delta: float) -> void:
	if not bob.visible:
		line_mesh.clear_surfaces()
		return
	var tip := _tip()
	var slack := 1.0
	if fly_t >= 0.0:
		fly_t += delta
		var k := minf(1.0, fly_t / fly_len)
		var to := tip + Vector3(0, -0.22, 0) if fly_to_tip else land
		var p := fly_from.lerp(to, k)
		p.y += sin(k * PI) * (1.1 if not fly_to_tip else 0.5)
		bob.global_position = p
		slack = 0.4
		if k >= 1.0:
			fly_t = -1.0
			if fly_to_tip and state in ["show", "carry", "bag"]:
				bob.visible = false
	elif state in ["wait", "bite"]:
		var y := water_y + 0.012 * sin(t * 2.1)
		for d in dips:
			var a: float = state_t - d
			if a > 0.0 and a < 0.3:
				y -= 0.045 * sin(a / 0.3 * PI)
		if state == "bite":
			y = water_y - 0.13 * minf(1.0, state_t / 0.12)
		bob.global_position = Vector3(land.x, y, land.z)
		slack = 0.5
	elif state == "strike":
		slack = 0.05
	else:
		var sway := Vector3(sin(t * 1.7), 0, cos(t * 1.3)) * 0.015
		bob.global_position = bob.global_position.lerp(tip + Vector3(0, -0.22, 0) + sway, 1.0 - exp(-delta * 12.0))
		slack = 0.1
	_draw_line(tip, bob.global_position + Vector3(0, 0.1, 0), slack)

func _hold_step() -> void:
	"""The catch lies between the hands as the Get clips hold it: along the Item bone's +y, its back up."""
	var ch := player.chibi
	var tail := ch.posed_point("Item", GRIP + Vector3(0, -0.13, 0))
	var head := ch.posed_point("Item", GRIP + Vector3(0, 0.31, 0))
	var up := ch.posed_point("Item", GRIP + Vector3(0, 0.09, 0.1)) - ch.posed_point("Item", GRIP + Vector3(0, 0.09, 0))
	var z := (head - tail).normalized()
	var x := up.cross(z).normalized()
	var b := Basis(x, z.cross(x), z)
	var box := AABB()
	for mi: MeshInstance3D in held.find_children("*", "MeshInstance3D", true, false):
		box = mi.get_aabb()
		break
	var k := held_len / maxf(box.size.z, 0.01)
	held.global_transform = Transform3D(b.scaled(Vector3.ONE * k), (tail + head) * 0.5)

func _draw_line(a: Vector3, b: Vector3, slack: float) -> void:
	"""(fishing.gd) The line: a thin ribbon facing the camera, sagging by `slack` between the tip and the float."""
	line_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var sag := Vector3(0, -a.distance_to(b) * 0.18 * slack, 0)
	var ctrl := (a + b) * 0.5 + sag
	line_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := 16
	for i in n + 1:
		var k := float(i) / n
		var p := a.lerp(ctrl, k).lerp(ctrl.lerp(b, k), k)
		var k2 := minf(1.0, k + 0.05)
		var nxt := a.lerp(ctrl, k2).lerp(ctrl.lerp(b, k2), k2)
		var dir := (nxt - p).normalized() if k < 1.0 else (b - ctrl).normalized()
		var side := dir.cross(cam.global_position - p).normalized() * 0.004
		line_mesh.surface_add_vertex(p - side)
		line_mesh.surface_add_vertex(p + side)
	line_mesh.surface_end()
