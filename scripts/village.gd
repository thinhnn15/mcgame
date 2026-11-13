extends Node3D

const FRIENDS := [
	{"id": "MOCHI", "pos": Vector3(-5.5, 0, 1.5),
		"look": {"hair": "buns", "hair_color": "#f2a6c0", "eye_style": "sparkle", "eye_color": "#b05aa8", "skin": "#ffe8d6",
			"top": {"shape": "dress", "color": "#fff3a8", "color_b": "#ffffff", "pattern": "dots"}, "bottom": {"shape": "none"},
			"shoes": {"shape": "boots", "color": "#ffb7c8", "trim": "#ffffff"}}},
	{"id": "BO", "pos": Vector3(5.0, 0, 3.5),
		"look": {"hair": "buns", "hair_color": "#a8693c", "eye_style": "calm", "eye_color": "#4aa56a", "skin": "#f2c29a",
			"top": {"shape": "hoodie", "color": "#a8e6a1", "pattern": "plain", "trim": "#ffffff"},
			"bottom": {"shape": "pants", "color": "#7fb4ff", "pattern": "plain"}, "shoes": {"shape": "sneakers", "color": "#ffffff", "trim": "#7fd3e6"}}},
	{"id": "KEM", "pos": Vector3(1.0, 0, -7.0),
		"look": {"hair": "buns", "hair_color": "#e8c27a", "eye_style": "round", "eye_color": "#4f86c6", "skin": "#ffd6c4",
			"top": {"shape": "tee", "color": "#c4a3ff", "color_b": "#ffffff", "pattern": "stripes"},
			"bottom": {"shape": "skirt", "color": "#ffffff", "color_b": "#ff9fb8", "pattern": "flowers"},
			"shoes": {"shape": "sneakers", "color": "#ff9fb8", "trim": "#ffffff"}}},
]
const HOME_SPOT := Vector3(0, 0, 4)
const PIER_SPOT := Vector3(0, 0, 15.5)

var player: Player
var avatars := {}
var cam: Camera3D
var cam_dist := 7.5
var friends: Array = []
var sea_mat: ShaderMaterial
var world_root: Node3D
var built_seed := -1
var last_mode := -1
var players_root: Node3D
var still := []
var t := 0.0
var hint: Label
var badge: Label
var toast: Label
var toast_t := 0.0
var panel: PanelContainer
var name_edit: LineEdit
var addr_edit: LineEdit
var host_btn: Button
var join_btn: Button
var leave_btn: Button
var host_info: Label
var roster: Label
var panel_wait := 0.0
var emote_at := -1.0
var rain: Rain

func _ready() -> void:
	var sun := Stage.setup(self)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	Net.set_look(Looks.load_saved())
	if Net.mode != Net.Mode.CLIENT:
		Net.world = own_world()
	_build_world()
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	_build_hud()
	_respawn_all()
	Net.session_changed.connect(_on_session_changed)
	Net.player_joined.connect(_spawn)
	Net.player_left.connect(_despawn)
	Net.player_changed.connect(_on_player_changed)
	Net.notice.connect(_show_toast)
	_place_camera(1.0)
	still = Stage.still_args()
	rain = Rain.new()
	rain.follow = player
	rain.sun = sun
	rain.chibis = func(): return avatars.values().map(func(p): return p.chibi)
	add_child(rain)
	if OS.get_cmdline_user_args().has("--rain"):
		rain.set_raining(true)
	if OS.get_cmdline_user_args().has("--umbrella"):
		player.chibi.open_umbrella()
	var am := Stage.arg("--auto")
	if am != "":
		var v := am.split_floats(",")
		player.auto_move = Vector2(v[0], v[1])
	if Stage.arg("--emote") != "":
		emote_at = 3.0

func own_world() -> Dictionary:
	"""My village as data. A visitor builds the host's village from this (more fields as the game grows:
	the season, what has been chopped or planted, the houses...)."""
	return {"seed": 7, "owner": Net.my_name}

func _world_seed() -> int:
	return int(Net.world.get("seed", 7))

func _build_world() -> void:
	if world_root:
		world_root.free()
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	built_seed = _world_seed()
	friends.clear()
	_build_island()
	_build_village(built_seed)
	for f in FRIENDS:
		var c := Chibi.new()
		world_root.add_child(c)
		var l := Looks.DEFAULT.duplicate(true)
		l.merge(f["look"], true)
		c.build(l)
		c.position = f["pos"]
		c.rotation.y = randf() * TAU
		var bubble := Label3D.new()
		bubble.text = tr("SAY_" + f["id"])
		bubble.font_size = 64
		bubble.pixel_size = 0.004
		bubble.outline_size = 18
		bubble.modulate = Color("5b4a44")
		bubble.outline_modulate = Color("fffaf2")
		bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bubble.no_depth_test = true
		bubble.position = f["pos"] + Vector3(0, 1.95, 0)
		bubble.visible = false
		world_root.add_child(bubble)
		friends.append({"chibi": c, "bubble": bubble, "near": false, "home_yaw": c.rotation.y})

func _build_island() -> void:
	var grass := MeshInstance3D.new()
	grass.mesh = Props.cyl(19.0, 19.0, 1.0)
	grass.material_override = Props.mat(Color("9fdc7c"))
	grass.position.y = -0.5
	world_root.add_child(grass)
	var sand := MeshInstance3D.new()
	sand.mesh = Props.cyl(21.5, 22.5, 1.0)
	sand.material_override = Props.mat(Color("ffe6b0"))
	sand.position.y = -0.62
	world_root.add_child(sand)
	var floor_ := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(60, 1, 60)
	cs.shape = bs
	floor_.add_child(cs)
	floor_.position.y = -0.5
	world_root.add_child(floor_)
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(240, 240)
	pm.subdivide_width = 120
	pm.subdivide_depth = 120
	sea.mesh = pm
	sea_mat = ShaderMaterial.new()
	sea_mat.shader = preload("res://shaders/sea.gdshader")
	sea.material_override = sea_mat
	sea.position.y = -0.35
	world_root.add_child(sea)

	for i in 14:
		var p := MeshInstance3D.new()
		p.mesh = Props.cyl(0.9, 0.9, 0.02)
		p.material_override = Props.mat(Color("f3d9a6"))
		p.position = Vector3(0.0 + sin(i * 0.5) * 0.8, 0.005, 17.0 - i * 1.25)
		world_root.add_child(p)
	var plaza := MeshInstance3D.new()
	plaza.mesh = Props.cyl(3.2, 3.2, 0.02)
	plaza.material_override = Props.mat(Color("f3d9a6"))
	plaza.position = Vector3(0, 0.006, -0.5)
	world_root.add_child(plaza)

func _build_village(world_seed: int) -> void:
	var w := world_root
	seed(world_seed)
	Props.house(w, Vector3(-7, 0, -6), 35, Color("fff1e0"), Color("ff8f8f"))
	Props.house(w, Vector3(7.5, 0, -5.5), -30, Color("eaf6ff"), Color("7fb4ff"))
	Props.house(w, Vector3(-1, 0, -12), 0, Color("fff8d6"), Color("8fd18b"))
	for p in [Vector3(-12, 0, 2), Vector3(-11, 0, -9), Vector3(11, 0, 4), Vector3(12, 0, -10), Vector3(-4, 0, 10),
			Vector3(6, 0, 11), Vector3(-15, 0, -3), Vector3(15, 0, -2), Vector3(4, 0, -14)]:
		Props.tree(w, p, [Color("6fcf6a"), Color("8fdc6a"), Color("ffb3c8")].pick_random(), randf_range(0.9, 1.25),
			Color("ff7a6a") if randf() < 0.4 else Color(0, 0, 0, 0))
	for i in 60:
		var a := randf() * TAU
		var r := randf_range(4.5, 16.5)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if abs(p.x) < 1.8 and p.z > 3:
			continue
		Props.flower(w, p, [Color("ff8fb1"), Color("ffffff"), Color("ffd36e"), Color("b59cff"), Color("ff9a6e")].pick_random())
	for p in [Vector3(-3.5, 0, -3.0), Vector3(3.2, 0, -3.4), Vector3(-9, 0, 6), Vector3(9.5, 0, 8)]:
		Props.bush(w, p, Color("5cc46b"), [Color("ff9fc0"), Color("ffffff"), Color("b59cff")].pick_random())
	for p in [Vector3(-13, 0, 8), Vector3(14, 0, 7), Vector3(-6, 0, -15)]:
		Props.rock(w, p, randf_range(0.8, 1.4))
	Props.fence(w, Vector3(-9.5, 0, -2.5), Vector3(-4.5, 0, -2.5))
	Props.fence(w, Vector3(4.5, 0, -2.0), Vector3(10, 0, -1.0))
	Props.lamp(w, Vector3(-2.6, 0, 1.6))
	Props.lamp(w, Vector3(2.6, 0, 1.6))
	Props.bench(w, Vector3(0, 0, -3.2), 0)
	Props.pier(w, Vector3(0, -0.1, 19.0), 180, 6.0)

func _respawn_all() -> void:
	var keep := HOME_SPOT
	if player and Net.mode != Net.Mode.CLIENT and last_mode != Net.Mode.CLIENT:
		keep = player.position
	for id in avatars.keys():
		_despawn(id)
	for id in Net.players:
		_spawn(id)
	if Net.mode != Net.Mode.CLIENT:
		player.position = keep
	last_mode = Net.mode

func _spawn(id: int) -> void:
	if avatars.has(id) or not Net.players.has(id):
		return
	var info: Dictionary = Net.players[id]
	var p := Player.new()
	p.name = "P%d" % id
	p.remote = id != Net.my_id()
	p.peer_id = id
	p.controls = not panel.visible
	players_root.add_child(p)
	p.position = PIER_SPOT + Vector3((avatars.size() - 1.5) * 0.9, 0, 0)
	p.setup(Looks.from(info.get("look", {})), cam)
	p.set_name_tag(info["name"] if Net.online() else "")
	avatars[id] = p
	if not p.remote:
		player = p
	_refresh_ui()

func _despawn(id: int) -> void:
	if avatars.has(id):
		avatars[id].free()
		avatars.erase(id)
	_refresh_ui()

func _on_player_changed(id: int) -> void:
	"""A new look or name: rebuild that avatar where it stands."""
	if not avatars.has(id):
		return
	var old: Player = avatars[id]
	var at := old.position
	var yaw := old.facing
	var auto := old.auto_move
	_despawn(id)
	_spawn(id)
	var p: Player = avatars[id]
	p.position = at
	p.facing = yaw
	p.rotation.y = yaw
	p.auto_move = auto

func _on_session_changed() -> void:
	if Net.mode != Net.Mode.CLIENT:
		Net.world = own_world()
	var auto := player.auto_move if player else Vector2.ZERO
	var rebuild := built_seed != _world_seed()
	_respawn_all()
	if rebuild:
		_build_world()
	player.auto_move = auto
	_place_camera(1.0)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiTheme.make()
	layer.add_child(ui)
	var sb := UiTheme.box(Color(1, 0.98, 0.95, 0.85), 18, Color("f6dccf"), 2, 16)
	hint = Label.new()
	hint.text = tr("HINT_VILLAGE")
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_stylebox_override("normal", sb)
	hint.position = Vector2(30, 1010)
	ui.add_child(hint)
	badge = Label.new()
	badge.add_theme_font_size_override("font_size", 22)
	badge.add_theme_stylebox_override("normal", sb)
	badge.position = Vector2(30, 28)
	ui.add_child(badge)
	toast = Label.new()
	toast.add_theme_font_size_override("font_size", 26)
	toast.add_theme_stylebox_override("normal", UiTheme.box(Color(UiTheme.PINK, 0.95), 20, Color.WHITE, 3, 20))
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.position.y = 90
	toast.visible = false
	ui.add_child(toast)

	panel = PanelContainer.new()
	panel.position = Vector2(1300, 110)
	panel.custom_minimum_size = Vector2(580, 0)
	panel.visible = false
	ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := Label.new()
	title.text = tr("NET_TITLE")
	title.add_theme_font_size_override("font_size", 32)
	v.add_child(title)
	v.add_child(_small(tr("NET_YOUR_NAME")))
	name_edit = LineEdit.new()
	name_edit.text = Net.my_name
	name_edit.max_length = 16
	name_edit.text_submitted.connect(func(s): Net.set_my_name(s); name_edit.release_focus())
	name_edit.focus_exited.connect(func(): Net.set_my_name(name_edit.text))
	v.add_child(name_edit)
	v.add_child(HSeparator.new())
	host_btn = Button.new()
	host_btn.text = tr("NET_HOST_BTN")
	host_btn.custom_minimum_size.y = 56
	host_btn.pressed.connect(func(): Net.host())
	v.add_child(host_btn)
	host_info = _small("")
	host_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(host_info)
	v.add_child(_small(tr("NET_VISIT_HELP")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	addr_edit = LineEdit.new()
	addr_edit.placeholder_text = tr("NET_ADDR_EXAMPLE")
	addr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	addr_edit.text_submitted.connect(func(_s): _join())
	row.add_child(addr_edit)
	join_btn = Button.new()
	join_btn.text = tr("NET_VISIT_BTN")
	join_btn.custom_minimum_size = Vector2(130, 52)
	join_btn.pressed.connect(_join)
	row.add_child(join_btn)
	leave_btn = Button.new()
	leave_btn.custom_minimum_size.y = 52
	leave_btn.pressed.connect(func(): Net.leave())
	v.add_child(leave_btn)
	v.add_child(HSeparator.new())
	roster = _small("")
	v.add_child(roster)
	v.add_child(_small(tr("NET_CLOSE_HELP")))
	_refresh_ui()

func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	return l

func _join() -> void:
	if addr_edit.text.strip_edges() != "":
		Net.join(addr_edit.text)
		addr_edit.release_focus()

func _refresh_ui() -> void:
	if badge == null:
		return
	var n := Net.players.size()
	match Net.mode:
		Net.Mode.OFFLINE:
			badge.text = tr("NET_BADGE_SOLO")
		Net.Mode.HOST:
			badge.text = Lang.t("NET_BADGE_HOST", {"n": n, "max": Net.MAX_VISITORS + 1})
		Net.Mode.CLIENT:
			badge.text = Lang.t("NET_BADGE_VISIT", {"host": Net.host_name(), "n": n})
	host_btn.disabled = Net.mode == Net.Mode.HOST
	join_btn.disabled = Net.mode == Net.Mode.CLIENT
	leave_btn.visible = Net.online()
	leave_btn.text = tr("NET_CLOSE_GATE") if Net.mode == Net.Mode.HOST else tr("NET_GO_HOME")
	if Net.mode == Net.Mode.HOST:
		var lan: Array = Net.lan_addresses()
		host_info.text = Lang.t("NET_LAN", {"addr": ", ".join(lan) if not lan.is_empty() else tr("NET_NOT_FOUND")}) + "\n" + Net.upnp_note
	else:
		host_info.text = ""
	host_info.visible = host_info.text != ""
	var names := []
	for id in Net.players:
		var tag := tr("NET_HOST_TAG") if Net.online() and id == 1 else ""
		names.append("• " + str(Net.players[id]["name"]) + tag + (tr("NET_YOU_TAG") if id == Net.my_id() else ""))
	roster.text = tr("NET_ROSTER") + "\n" + "\n".join(names)

func _show_toast(text: String) -> void:
	toast.text = text
	toast.visible = true
	toast.modulate.a = 1.0
	toast_t = 3.5
	_refresh_ui()

func _toggle_panel(open: bool) -> void:
	panel.visible = open
	player.controls = not open
	if open:
		name_edit.text = Net.my_name
		_refresh_ui()
	else:
		name_edit.release_focus()
		addr_edit.release_focus()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_TAB:
				get_tree().change_scene_to_file("res://scenes/creator.tscn")
			KEY_M:
				_toggle_panel(not panel.visible)
			KEY_N:
				rain.toggle()
			KEY_U:
				if player.chibi.tool == "umbrella":
					player.chibi.close_umbrella()
				else:
					player.chibi.open_umbrella()
					player.chibi.emote("happy")
			KEY_ESCAPE:
				if panel.visible:
					_toggle_panel(false)
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(4.0, cam_dist - 0.5)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(12.0, cam_dist + 0.5)

func _place_camera(k: float) -> void:
	var target := player.global_position + Vector3(0, 0.7, 0)
	var want := target + Vector3(0, cam_dist * 0.62, cam_dist * 0.8)
	cam.global_position = cam.global_position.lerp(want, k)
	cam.look_at(target, Vector3.UP)

func _process(delta: float) -> void:
	t += delta
	sea_mat.set_shader_parameter("t", t)
	_place_camera(1.0 - exp(-delta * 5.0))
	for f in friends:
		var c: Chibi = f["chibi"]
		var to := Vector3(1e6, 0, 0)
		for id in avatars:
			var d: Vector3 = avatars[id].global_position - c.global_position
			if d.length() < to.length():
				to = d
		var near := to.length() < 2.4
		if near and not f["near"]:
			c.emote("wave")
		f["near"] = near
		var want: float = atan2(to.x, to.z) if near else f["home_yaw"]
		c.rotation.y = lerp_angle(c.rotation.y, want, 1.0 - exp(-delta * 6.0))
		(f["bubble"] as Label3D).visible = near
	if toast_t > 0.0:
		toast_t -= delta
		toast.modulate.a = clampf(toast_t / 0.6, 0.0, 1.0)
		toast.visible = toast_t > 0.0
	if panel.visible:
		panel_wait -= delta
		if panel_wait <= 0.0:
			panel_wait = 0.5
			_refresh_ui()
	if emote_at >= 0.0 and t >= emote_at:
		emote_at = -1.0
		Net.act("emote", Stage.arg("--emote"))
	if still.size() == 2 and still[0] != "" and t >= still[1]:
		set_process(false)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(still[0])
		get_tree().quit()
