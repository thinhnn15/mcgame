extends Node3D

const ROOMS := {
	"nha_cu": {"corner": Vector2(-3.5, -2.5), "window": 5.5, "inner": "right", "front_door": true,
		"doors": [{"to": "buong_ben", "side": "right", "along": 2.0, "level": 2},
			{"to": "san_truoc", "side": "front", "along": 3.5, "level": 3},
			{"to": "farm", "side": "front", "along": 3.5, "level": 0, "max_level": 2}]},
	"buong_ben": {"corner": Vector2(-2.0, -2.5), "window": 2.0, "inner": "left", "front_door": false,
		"doors": [{"to": "nha_cu", "side": "left", "along": 2.0, "level": 0}]},
	"san_truoc": {"corner": Vector2(-3.5, -2.0), "yard": true,
		"doors": [{"to": "nha_cu", "side": "back", "along": 3.5, "level": 0},
			{"to": "farm", "side": "front", "along": 3.5, "level": 0}]},
}
const INNER_DOOR_Z := 2.0
const SURFACE_SHADER := preload("res://shaders/toon_surface.gdshader")
const TILES := "res://props/hometown/tiles/"
const LIME := Color("f2dda4")
const WOOD := Color("8a5b3c")
const WOOD_DARK := Color("6b4430")
const PLAY_CAM := Vector3(0, 6.0, 7.6)
const DECOR_CAM := [Vector3(0, 10.6, 7.4), Vector3(0, 0.2, 0.1)]

var room: DecorRoom
var room_id := "nha_cu"
var _corner := Vector2(-3.5, -2.5)
var _leaving := false
var _relook := false
var so_tho: SoTho
var decor: DecorMode
var player: Player
var cam: Camera3D
var _x1 := 0.0
var _z1 := 0.0
var _fixed := false
var _still := []
var _t := 0.0
var _frames := 0
var _tile_sizes := {}
var _mats := {}
var _wall_mat: ShaderMaterial
var _floor_mat: ShaderMaterial
var _room_mat: ShaderMaterial
var _lamp: OmniLight3D
var _done: Array = []
var _level := 0

func _ready() -> void:
	var sun := Stage.setup(self)
	var env := (get_node("WorldEnvironment") as WorldEnvironment).environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b2420")
	var room_peek := String(Engine.get_meta("nha_trong_room", Stage.arg("--room")))
	if ROOMS.get(room_peek, {}).get("yard", false):
		env.background_color = Color("cfe3ea")
	var args := OS.get_cmdline_user_args()
	if "--still" in args or "--stats" in args or "--fresh" in args:
		DecorRoom.render_story = false
	room_id = String(Engine.get_meta("nha_trong_room", ""))
	if room_id == "":
		room_id = Stage.arg("--room") if ROOMS.has(Stage.arg("--room")) else "nha_cu"
	var came_from := String(Engine.get_meta("nha_trong_from", ""))
	Engine.remove_meta("nha_trong_room")
	Engine.remove_meta("nha_trong_from")
	_corner = ROOMS[room_id]["corner"]
	room = DecorRoom.new()
	add_child(room)
	room.setup(room_id, _corner)
	_x1 = _corner.x + room.size.x * DecorRoom.CELL
	_z1 = _corner.y + room.size.y * DecorRoom.CELL
	_tile_sizes = JSON.parse_string(FileAccess.get_file_as_string(TILES + "tiles.json"))
	if ROOMS[room_id].get("yard", false):
		_shell_yard()
	else:
		_shell()
	_house_look()
	cam = Camera3D.new()
	cam.fov = 34.0
	add_child(cam)
	player = Player.new()
	add_child(player)
	player.position = Vector3(0, 0, _z1 - 1.0)
	if came_from == "" and Stage.arg("--walk-door") != "":
		for dr in ROOMS[room_id]["doors"]:
			if dr["to"] == Stage.arg("--walk-door"):
				player.position = _door_point(dr) + _door_in(dr) * 0.3
	if came_from != "":
		for dr in ROOMS[room_id]["doors"]:
			if dr["to"] == came_from:
				player.position = _door_point(dr) + _door_in(dr) * 0.9
	player.bounds_box = 10.0
	player.setup(Looks.load_saved(), cam)
	Sound.hero = player
	room.hero = player
	DecorRoom.try_all = "--all" in args
	room.load_saved("--fresh" in args, "--all" in args)
	if SoTho.ready_() and not ("--still" in args or "--stats" in args or "--fresh" in args):
		SoTho.hw("sync")
	room.surfaces_changed.connect(_repaint)
	room.face_glow.connect(func(face: int) -> void:
		if _room_mat != null:
			_room_mat.set_shader_parameter("glow_face", face))
	if Stage.arg("--surfaces") != "":
		var ids := Stage.arg("--surfaces").split(",")
		room.surfaces["wall"] = ids[0]
		if ids.size() > 1:
			room.surfaces["floor"] = ids[1]
		if ids.size() > 2:
			room.surfaces["dado"] = ids[2]
		if room.rs != null:
			room.rs.load(room.surfaces)
	_repaint()
	decor = DecorMode.new()
	add_child(decor)
	decor.setup(room, cam, player)
	if "--no-ui" not in args:
		PerfHud.add(self)

	decor.toggled.connect(func(on: bool) -> void: sun.shadow_enabled = not on)
	var c := Stage.arg("--cam").split_floats(",")
	if c.size() == 6:
		_fixed = true
		cam.position = Vector3(c[0], c[1], c[2])
		cam.look_at(Vector3(c[3], c[4], c[5]), Vector3.UP)
	else:
		_place_camera(1.0)
	var pt := Stage.arg("--point").split_floats(",")
	if pt.size() == 2:
		decor._pointer = Vector2(pt[0], pt[1])
		decor.set_process_unhandled_input(false)
	if "--decor" in args:
		decor.open()
		if not _fixed:
			_place_camera(1.0)
		if Stage.arg("--hold") != "":
			room.kho[Stage.arg("--hold")] = int(room.kho.get(Stage.arg("--hold"), 0)) + 1
			decor._take(Stage.arg("--hold"))
			if Stage.arg("--paint") != "":
				decor._paint_open()
				decor._paint_pick(int(Stage.arg("--paint")))
			if "--fix" in args:
				decor._fix_open()
		if Stage.arg("--tab") != "":
			decor._on_tab(Stage.arg("--tab"))
		if Stage.arg("--try") != "":
			for one in Stage.arg("--try").split(","):
				var kid := one.split(":")
				var at := kid[1].split("@")
				var face := int(at[1]) if at.size() > 1 else -1
				if face >= 0:
					decor._nen_one = true
					decor._nen_face = face
					room.face_glow.emit(face)
				if kid[0] == "theme":
					room.preview_theme(at[0])
				else:
					room.preview_surface(kid[0], "" if at[0] == "none" else at[0], face)
			decor._nen_show_bar()
			decor._fill_kho()
	_still = Stage.still_args()
	decor.shop.ready_today = "--photo-now" in args
	if "--no-ui" in args:
		decor.visible = false
		player.visible = false
	so_tho = SoTho.new()
	add_child(so_tho)
	so_tho.closed.connect(func() -> void:
		player.controls = true
		if _relook and not _leaving:
			_leaving = true
			Engine.set_meta("nha_trong_room", room_id)
			get_tree().reload_current_scene())
	so_tho.worked.connect(func(_id: String) -> void: _relook = true)
	if Stage.arg("--so-tho") != "" or "--so-tho" in args:
		_open_so_tho(Stage.arg("--so-tho") if not Stage.arg("--so-tho").begins_with("--") else "")
	if "--shop" in args:
		decor._open_shop()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_C and not decor.shop._panel.visible:
		snap()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_N and not decor.active 			and not so_tho.visible:
		_open_so_tho("")
		get_viewport().set_input_as_handled()

func _open_so_tho(page: String) -> void:
	player.controls = false
	player.stop_going()
	so_tho.open(page)

func snap() -> String:
	decor.visible = false
	decor.shop.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var id := PhotoPrint.save_shot(get_viewport().get_texture().get_image())
	decor.visible = true
	decor.shop.visible = true
	decor._say(tr("PHOTO_TAKEN"))
	Sound.play("ui.click", 0.0)
	if decor.active:
		decor._print_btn.visible = true
	return id

func _process(delta: float) -> void:
	_t += delta
	_frames += 1
	if not _fixed:
		_place_camera(delta)
	_door_check()
	if "--stats" in OS.get_cmdline_user_args() and _t > 3.0:
		print("nha_trong stats: %d items, draw calls %d, objects %d, primitives %d, %.2f ms/frame" % [
			room.entries.size(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			1000.0 * _t / _frames])
		get_tree().quit()
	if _still[0] != "" and _t >= _still[1]:
		get_viewport().get_texture().get_image().save_png(_still[0])
		get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and decor and decor.active:
		decor.close()

func _place_camera(delta: float) -> void:
	var pos: Vector3
	var look: Vector3
	if decor and decor.active:
		pos = DECOR_CAM[0]
		look = DECOR_CAM[1]
	else:
		var p := player.global_position
		var follow := Vector3(clampf(p.x, -1.6, 1.6) * 0.6, 0, clampf(p.z, -1.5, 1.5) * 0.35)
		pos = PLAY_CAM + follow
		look = Vector3(follow.x, 0.7, follow.z - 0.4)
	var k := 1.0 - exp(-delta * 4.0)
	var basis_now := cam.global_transform.basis
	cam.position = cam.position.lerp(pos, k)
	var goal := Transform3D.IDENTITY.translated(cam.position).looking_at(look, Vector3.UP).basis
	cam.basis = basis_now.slerp(goal, k).orthonormalized() if delta < 1.0 else goal

func _surface(tile: String, tint := Color.WHITE) -> ShaderMaterial:
	var key := "%s:%s" % [tile, tint.to_html()]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = SURFACE_SHADER
		m.set_shader_parameter("tile_alb", load(TILES + tile + "_alb.png"))
		m.set_shader_parameter("tile_nrm", load(TILES + tile + "_nrm.png"))
		m.set_shader_parameter("has_nrm", true)
		var s := float(_tile_sizes.get(tile, 1.0))
		m.set_shader_parameter("tile_size", Vector2(s, s))
		m.set_shader_parameter("base_color", tint)
		_mats[key] = m
	return _mats[key]

func _box(root: Node3D, size: Vector3, c: Variant, pos: Vector3, shadow := false) -> void:
	Props._part(root, root, Props._box(size), c, pos, Vector3.ZERO, Vector3.ONE, shadow)

func _repaint() -> void:
	if ROOMS[room_id].get("yard", false):
		return
	var w := room.surface("wall")
	var f := room.surface("floor")
	if _room_mat != null:
		if room.rs != null:
			var params: Dictionary = room.rs.shader_params(LIME)
			for k in params:
				_room_mat.set_shader_parameter(k, params[k])
		else:
			_repaint_shell(w, f)
		return
	_wall_mat.set_shader_parameter("base_color", Color(String(w["hex"])) if w.has("hex") else LIME)
	var tile := String(f.get("tile", "gach_san"))
	if f.get("id", "") == String(DecorRoom.finish().get("surfaces", {}).get("floor", {}).get("default", "")):
		tile = "gach_san"
	if not ResourceLoader.exists(TILES + tile + "_alb.png"):
		return
	var src := _surface(tile)
	for k in ["tile_alb", "tile_nrm", "has_nrm", "tile_size"]:
		_floor_mat.set_shader_parameter(k, src.get_shader_parameter(k))

const BE_MAT := "res://props/furniture/rooms/be_mat_"
const FACES := 12

static func be_mat() -> Dictionary:
	return DecorRoom.be_mat()

func _room_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/toon_surface_room.gdshader")
	m.set_shader_parameter("layers_alb", load(BE_MAT + "alb.png"))
	m.set_shader_parameter("layers_nrm", load(BE_MAT + "nrm.png"))
	return m

func _slice(tile: String) -> Array:
	var i := (be_mat()["layers"] as Array).find(tile)
	if i < 0:
		i = 0
	return [i, float(be_mat()["metres"][i])]

func _repaint_shell(w: Dictionary, f: Dictionary) -> void:
	var wall := _slice(String(w.get("tile", "voi")))
	var tint := Color(String(w["hex"])) if w.has("hex") else LIME
	var tile := String(f.get("tile", "gach_san"))
	if f.get("id", "") == String(DecorRoom.finish().get("surfaces", {}).get("floor", {}).get("default", "")):
		tile = "gach_san"
	var flo := _slice(tile)
	var lime := _slice("voi")
	var layer := PackedInt32Array()
	var tints := PackedColorArray()
	var metres := PackedFloat32Array()
	var dado := PackedInt32Array()
	for i in FACES:
		var s: Array = flo if i == 8 else (wall if i < 8 else lime)
		layer.append(int(s[0]))
		metres.append(float(s[1]))
		tints.append(Color.WHITE if i == 8 else (tint if (i < 8 or w.has("hex")) else LIME))
		dado.append(-1)
	_room_mat.set_shader_parameter("face_layer", layer)
	_room_mat.set_shader_parameter("face_tint", tints)
	_room_mat.set_shader_parameter("face_m", metres)
	_room_mat.set_shader_parameter("dado_layer", dado)
	_room_mat.set_shader_parameter("dado_tint", tints)
	_room_mat.set_shader_parameter("dado_m", metres)

func _solid(at: Vector3, size: Vector3) -> void:
	var b := BoxShape3D.new()
	b.size = size
	Props.solid(self, b, at)

func _shell() -> void:
	var x0 := _corner.x
	var z0 := _corner.y
	var w := _x1 - x0
	var d := _z1 - z0
	var h := room.wall_h
	var cx := (x0 + _x1) / 2.0
	var cz := (z0 + _z1) / 2.0
	var shell := Node3D.new()
	add_child(shell)

	_box(shell, Vector3(w + 0.6, 0.34, d + 0.5), Color("7d5f4c"), Vector3(cx, -0.17 - 0.012, cz - 0.05))
	if ClassDB.class_exists("RoomShell"):

		var inner := String(ROOMS[room_id]["inner"])
		var mi := MeshInstance3D.new()
		mi.name = "Shell"
		mi.mesh = ClassDB.class_call_static("RoomShell", "build", {"x0": x0, "z0": z0, "x1": _x1, "z1": _z1, "h": h,
			"t": 0.2, "walls": PackedStringArray(["back", "left", "right"]), "holes": [
				{"face": "back", "along": float(ROOMS[room_id]["window"]), "y": 1.0, "w": 1.0, "h": 1.0},
				{"face": inner, "along": INNER_DOOR_Z, "y": 0.0, "w": 0.86, "h": 1.95}]})
		_room_mat = _room_material()
		mi.material_override = _room_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.add_child(mi)
	else:
		_floor_mat = _surface("gach_san").duplicate()
		_wall_mat = _surface("voi", LIME).duplicate()
		_box(shell, Vector3(w, 0.02, d), _floor_mat, Vector3(cx, -0.01, cz))
		_box(shell, Vector3(w + 0.4, h, 0.2), _wall_mat, Vector3(cx, h / 2, z0 - 0.1))
		_box(shell, Vector3(0.2, h, d + 0.2), _wall_mat, Vector3(x0 - 0.1, h / 2, cz - 0.1))
		_box(shell, Vector3(0.2, h, d + 0.2), _wall_mat, Vector3(_x1 + 0.1, h / 2, cz - 0.1))

	_box(shell, Vector3(w, 0.16, 0.03), Color("9a6b4c"), Vector3(cx, 0.08, z0 + 0.015))
	_box(shell, Vector3(0.03, 0.16, d), Color("9a6b4c"), Vector3(x0 + 0.015, 0.08, cz))
	_box(shell, Vector3(0.03, 0.16, d), Color("9a6b4c"), Vector3(_x1 - 0.015, 0.08, cz))
	_box(shell, Vector3(w + 0.4, 0.2, 0.26), WOOD, Vector3(cx, h + 0.06, z0 - 0.05))
	_box(shell, Vector3(0.26, 0.2, d + 0.3), WOOD, Vector3(x0 - 0.05, h + 0.06, cz))
	_box(shell, Vector3(0.26, 0.2, d + 0.3), WOOD, Vector3(_x1 + 0.05, h + 0.06, cz))
	for p in [Vector2(x0, z0), Vector2(_x1, z0), Vector2(x0, _z1), Vector2(_x1, _z1)]:
		Props._part(shell, shell, Props._cyl(0.11, 0.11, h + 0.1), WOOD, Vector3(p.x, h / 2 + 0.05, p.y), Vector3.ZERO,
			Vector3.ONE, false)
	_window(shell, Vector3(x0 + float(ROOMS[room_id]["window"]), 1.5, z0))
	if ROOMS[room_id]["inner"] == "left":
		_inner_door(shell, Vector3(x0, 0, z0 + INNER_DOOR_Z), 1.0)
	else:
		_inner_door(shell, Vector3(_x1, 0, z0 + INNER_DOOR_Z), -1.0)
	if ROOMS[room_id]["front_door"]:

		var dr := room.door
		var door_mid := Vector3(x0 + (dr.position.x + dr.size.x / 2.0) * DecorRoom.CELL, 0, _z1)
		_box(shell, Vector3(dr.size.x * DecorRoom.CELL + 0.2, 0.06, 0.2), WOOD, door_mid + Vector3(0, 0.02, 0.02))
		_box(shell, Vector3(0.9, 0.012, 0.42), Color("d8bf86"), door_mid + Vector3(0, 0.006, -0.3))

	_solid(Vector3(cx, -0.1, cz), Vector3(w + 1.0, 0.2, d + 1.0))
	_solid(Vector3(cx, 1.0, z0 - 0.1), Vector3(w + 0.4, 2.0, 0.2))
	_solid(Vector3(x0 - 0.1, 1.0, cz), Vector3(0.2, 2.0, d + 0.4))
	_solid(Vector3(_x1 + 0.1, 1.0, cz), Vector3(0.2, 2.0, d + 0.4))
	_solid(Vector3(cx, 1.0, _z1 + 0.15), Vector3(w + 0.4, 2.0, 0.2))

	_lamp = OmniLight3D.new()
	_lamp.light_color = Color("ffd9a8")
	_lamp.light_energy = 0.45
	_lamp.omni_range = 6.5
	_lamp.position = Vector3(cx, 2.4, cz)
	add_child(_lamp)

const ROOMS_TEX := "res://props/furniture/rooms/"

func _house_look() -> void:
	var args := OS.get_cmdline_user_args()
	_done = Stage.arg("--fixes").split(",", false) if Stage.arg("--fixes") != "" else Story.flag("home_fixes_done", [])
	for id in _done:
		if String(id).begins_with("nha_muc_"):
			_level = maxi(_level, int(String(id).trim_prefix("nha_muc_")))
	if ROOMS[room_id].get("yard", false):
		return
	var x0 := _corner.x
	var z0 := _corner.y
	var h := room.wall_h
	var hour := float(Stage.arg("--hour")) if Stage.arg("--hour") != "" else Clock.hour()

	if _level < 1 and room_id == "nha_cu":
		var q := []
		for x in [0.9, 3.2, 6.4]:
			q.append([Vector3(x0 + x, h - 0.75, z0 + 0.004), Vector3.RIGHT, Vector3.UP, Vector2(0.75, 1.5)])
		q.append([Vector3(_x1 - 0.004, h - 0.8, z0 + 2.6), Vector3.BACK, Vector3.UP, Vector2(0.7, 1.4)])
		q.append([Vector3(x0 + 0.004, h - 0.7, z0 + 3.8), Vector3.FORWARD, Vector3.UP, Vector2(0.6, 1.3)])
		_quads(q, _decal(ROOMS_TEX + "vet_doc.png", BaseMaterial3D.BLEND_MODE_MUL))

	var clean := "lau_don" in _done
	if not clean:
		var webs := [[Vector3(x0 + 0.5, h - 0.5, z0 + 0.005), Vector3.RIGHT, Vector3.DOWN, Vector2(1.0, 1.0)],
			[Vector3(_x1 - 0.5, h - 0.5, z0 + 0.005), Vector3.LEFT, Vector3.DOWN, Vector2(1.0, 1.0)],
			[Vector3(x0 + 0.005, h - 0.45, z0 + 4.5), Vector3.FORWARD, Vector3.DOWN, Vector2(0.9, 0.9)]]
		_quads(webs, _decal(ROOMS_TEX + "mang_nhen.png", BaseMaterial3D.BLEND_MODE_MIX))
	_lamp.light_energy = 0.45 if clean else 0.3
	_lamp.light_color = Color("ffd9a8") if clean else Color("e8d8c0")

	var win := Vector3(x0 + float(ROOMS[room_id]["window"]), 1.5, z0)
	if "va_cua_so" not in _done:
		for k in [-1, 1]:
			Props._part(self, self, Props._box(Vector3(1.25, 0.12, 0.03)), WOOD_DARK, win + Vector3(0, k * 0.18, 0.13),
				Vector3(0, 0, k * 14.0), Vector3.ONE, true)
		Props._part(self, self, Props._box(Vector3(0.12, 1.05, 0.03)), WOOD, win + Vector3(0.2, 0, 0.12), Vector3.ZERO,
			Vector3.ONE, true)
	elif hour >= 7.0 and hour < 16.5:
		_quads([[Vector3(win.x + 0.25, 0.004, z0 + 0.95), Vector3.RIGHT, Vector3.BACK, Vector2(1.3, 1.6)]],
			_decal(ROOMS_TEX + "nang_cua.png", BaseMaterial3D.BLEND_MODE_ADD))
	if room_id != "nha_cu":
		return
	var bulb_at := Vector3(x0 + (_x1 - x0) * 0.63, h - 0.55, z0 + 2.6)
	Props._part(self, self, Props._cyl(0.006, 0.006, 0.5), Color("3a302a"), bulb_at + Vector3(0, 0.3, 0), Vector3.ZERO, Vector3.ONE, false)
	var lit := "thay_bong_den" in _done
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("fff2c8") if lit else Color("8d8a80")
	if lit:
		glass.emission_enabled = true
		glass.emission = Color("ffd38a")
		glass.emission_energy_multiplier = 2.2 if (hour >= 17.5 or hour < 6.0) else 0.4
	var b := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.1
	b.mesh = sm
	b.material_override = glass
	b.position = bulb_at
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(b)
	if lit and (hour >= 17.5 or hour < 6.0):
		var warm := OmniLight3D.new()
		warm.light_color = Color("ffc979")
		warm.light_energy = 0.9
		warm.omni_range = 5.0
		warm.position = bulb_at + Vector3(0, -0.1, 0)
		add_child(warm)

func _quads(q: Array, mat: Material) -> void:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var ix := PackedInt32Array()
	for one in q:
		var c: Vector3 = one[0]
		var u: Vector3 = one[1] * one[3].x / 2.0
		var d: Vector3 = one[2] * one[3].y / 2.0
		var k := v.size()
		v.append_array([c - u - d, c + u - d, c + u + d, c - u + d])
		uv.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		ix.append_array([k, k + 1, k + 2, k, k + 2, k + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = ix
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _decal(tex: String, blend: BaseMaterial3D.BlendMode) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(tex)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.blend_mode = blend
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if blend != BaseMaterial3D.BLEND_MODE_MUL else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m

func _window(root: Node3D, at: Vector3) -> void:
	var w := 1.0
	var h := 1.0
	_box(root, Vector3(w, h, 0.02), Color("cfe6c4"), at + Vector3(0, 0, 0.01))
	_box(root, Vector3(w, h * 0.35, 0.021), Color("e6f2dc"), at + Vector3(0, h * 0.32, 0.011))
	for y in [-1, 1]:
		_box(root, Vector3(w + 0.16, 0.08, 0.1), WOOD, at + Vector3(0, y * (h / 2 + 0.04), 0.05), true)
	for x in [-1, 1]:
		_box(root, Vector3(0.08, h + 0.16, 0.1), WOOD, at + Vector3(x * (w / 2 + 0.04), 0, 0.05), true)
	_box(root, Vector3(w + 0.3, 0.05, 0.16), WOOD, at + Vector3(0, -h / 2 - 0.1, 0.08))
	for i in 5:
		var x := -w / 2 + (i + 1) * w / 6.0
		Props._part(root, root, Props._cyl(0.022, 0.022, h), WOOD_DARK, at + Vector3(x, 0, 0.05), Vector3.ZERO,
			Vector3.ONE, true)

func _inner_door(root: Node3D, at: Vector3, s := 1.0) -> void:
	_box(root, Vector3(0.03, 1.95, 0.86), Color("7a5038"), at + Vector3(0.02 * s, 0.975, 0))
	for z in [-0.215, 0.215]:
		_box(root, Vector3(0.035, 1.9, 0.02), Color("5f3d2a"), at + Vector3(0.025 * s, 0.975, z))
	_box(root, Vector3(0.08, 0.1, 1.06), WOOD, at + Vector3(0.04 * s, 2.0, 0), true)
	for z in [-0.48, 0.48]:
		_box(root, Vector3(0.08, 2.05, 0.1), WOOD, at + Vector3(0.04 * s, 1.0, z), true)
	_box(root, Vector3(0.05, 0.05, 0.05), Color("c9a24a"), at + Vector3(0.05 * s, 1.0, 0.3))

func _door_check() -> void:
	if _leaving or decor.active or not player.controls:
		return
	var p := player.global_position
	for dr in ROOMS[room_id]["doors"]:
		if _level < int(dr["level"]) or _level > int(dr.get("max_level", 99)):
			continue
		var d := _door_point(dr)
		if Vector2(p.x - d.x, p.z - d.z).length() < 0.55:
			_leaving = true
			if _still[0] == "":
				room.save()
			Sound.play("ui.click", -6.0)
			if dr["to"] == "farm":
				Story.set_flag("spawn_at", "farm_house")
				get_tree().change_scene_to_file("res://scenes/farm_plot.tscn")
				return
			Engine.set_meta("nha_trong_room", dr["to"])
			Engine.set_meta("nha_trong_from", room_id)
			get_tree().reload_current_scene()
			return

func _door_point(dr: Dictionary) -> Vector3:
	var a := float(dr["along"])
	match dr["side"]:
		"left": return Vector3(_corner.x, 0, _corner.y + a)
		"right": return Vector3(_x1, 0, _corner.y + a)
		"front": return Vector3(_corner.x + a, 0, _z1)
	return Vector3(_corner.x + a, 0, _corner.y)

func _door_in(dr: Dictionary) -> Vector3:
	return {"left": Vector3.RIGHT, "right": Vector3.LEFT, "front": Vector3.FORWARD, "back": Vector3.BACK}[dr["side"]]

func _shell_yard() -> void:
	var x0 := _corner.x
	var z0 := _corner.y
	var w := _x1 - x0
	var d := _z1 - z0
	var h := room.wall_h
	var cx := (x0 + _x1) / 2.0
	var cz := (z0 + _z1) / 2.0
	var shell := Node3D.new()
	add_child(shell)
	_box(shell, Vector3(w + 16.0, 0.02, d + 12.0), Color("8fb36a"), Vector3(cx, -0.03, cz + 2.0))
	_box(shell, Vector3(w + 1.6, 0.02, d + 1.2), _surface("dat"), Vector3(cx, -0.018, cz + 0.4))
	_floor_mat = _surface("gach_lat").duplicate()
	_wall_mat = _surface("voi", LIME).duplicate()
	_box(shell, Vector3(w, 0.03, d), _floor_mat, Vector3(cx, -0.005, cz))

	_box(shell, Vector3(w + 0.4, h, 0.2), _wall_mat, Vector3(cx, h / 2, z0 - 0.1))

	Props._part(shell, shell, Props._box(Vector3(w + 1.2, 0.08, 2.6)), _surface("ngoi"), Vector3(cx, h + 0.55, z0 - 0.7),
		Vector3(-22.0, 0, 0), Vector3.ONE, true)
	_box(shell, Vector3(w + 1.25, 0.07, 0.12), Color("7d4630"), Vector3(cx, h + 0.06, z0 + 0.48), true)
	_box(shell, Vector3(w + 1.3, 0.12, 0.14), Color("6e3c2a"), Vector3(cx, h + 1.05, z0 - 1.9), true)
	var door_x := x0 + 3.5
	_box(shell, Vector3(1.0, 2.05, 0.03), Color("3a2a22"), Vector3(door_x, 1.025, z0 + 0.01))
	for sx in [-1, 1]:
		_box(shell, Vector3(0.1, 2.15, 0.12), WOOD, Vector3(door_x + sx * 0.55, 1.075, z0 + 0.04), true)
	_box(shell, Vector3(1.2, 0.12, 0.12), WOOD, Vector3(door_x, 2.15, z0 + 0.04), true)
	_box(shell, Vector3(1.3, 0.1, 0.5), Color("b39a7a"), Vector3(door_x, 0.05, z0 + 0.25))
	_box(shell, Vector3(1.5, 0.08, 0.2), WOOD_DARK, Vector3(door_x, 2.3, z0 + 0.05), true)
	_box(shell, Vector3(0.1, 0.16, 0.1), Color("3a302a"), Vector3(door_x + 0.75, 2.05, z0 + 0.08))
	var lamp_glass := StandardMaterial3D.new()
	lamp_glass.albedo_color = Color("fff0c8")
	Props._part(shell, shell, Props._cyl(0.05, 0.05, 0.1), lamp_glass, Vector3(door_x + 0.75, 1.93, z0 + 0.1), Vector3.ZERO, Vector3.ONE, false)
	for wx in [x0 + 1.5, x0 + 5.5]:
		_window(shell, Vector3(wx, 1.45, z0))
		_box(shell, Vector3(0.9, 0.18, 0.22), _surface("gach"), Vector3(wx, 0.62, z0 + 0.11))
		_box(shell, Vector3(0.84, 0.06, 0.18), Color("6f8f4f"), Vector3(wx, 0.73, z0 + 0.11))

	for side_x in [x0 - 0.08, _x1 + 0.08]:
		_box(shell, Vector3(0.14, 0.6, d), _surface("gach"), Vector3(side_x, 0.3, cz))
		_box(shell, Vector3(0.2, 0.04, d + 0.06), Color("a99a86"), Vector3(side_x, 0.62, cz))
		for k in 3:
			_box(shell, Vector3(0.2, 0.72, 0.2), _surface("gach"), Vector3(side_x, 0.36, z0 + 0.4 + k * (d - 0.4) / 2.0))
	for seg in [[x0, door_x - 0.75], [door_x + 0.75, _x1]]:
		var ln: float = seg[1] - seg[0]
		_box(shell, Vector3(ln, 0.45, 0.14), _surface("gach"), Vector3(seg[0] + ln / 2.0, 0.225, _z1 + 0.08))
		_box(shell, Vector3(ln + 0.06, 0.04, 0.2), Color("a99a86"), Vector3(seg[0] + ln / 2.0, 0.47, _z1 + 0.08))
	for gx in [door_x - 0.85, door_x + 0.85]:
		_box(shell, Vector3(0.22, 0.85, 0.22), _surface("gach"), Vector3(gx, 0.425, _z1 + 0.08))

	for pl in [["cay_chuoi", Vector3(x0 - 1.4, 0, z0 + 0.6)], ["cay_chuoi", Vector3(x0 - 1.0, 0, z0 + 2.4)],
			["cay_cau", Vector3(_x1 + 1.3, 0, z0 + 0.4)], ["cay_buoi", Vector3(_x1 + 1.8, 0, z0 + 2.8)]]:
		if ResourceLoader.exists(HomeKit.DIR + String(pl[0]) + ".glb"):
			HomeKit.place(shell, pl[0], pl[1])

	_solid(Vector3(cx, 1.0, z0 - 0.1), Vector3(w + 0.4, 2.0, 0.2))
	_solid(Vector3(x0 - 0.1, 1.0, cz), Vector3(0.2, 2.0, d + 0.4))
	_solid(Vector3(_x1 + 0.1, 1.0, cz), Vector3(0.2, 2.0, d + 0.4))
	_solid(Vector3(cx, 1.0, _z1 + 0.15), Vector3(w + 0.4, 2.0, 0.2))
	_solid(Vector3(cx, -0.1, cz), Vector3(w + 1.0, 0.2, d + 1.0))
