extends Node3D

var chibi: Chibi
var look: Dictionary
var still := []
var spin := 0.0
var ui: Control

var yaw := 0.0
var shown_yaw := 0.0
var idle := 99.0
var dragging := false
var cam: Camera3D
var thumbs: LookThumbs
var _tiles: Array = []
var _tab_now := ""
var _gender_box: Control
var _gender_hint: Label

const HAIR_GROUPS := [["HAIR_SHORT", ["buzz", "spiky", "short", "messy", "bowl", "quiff", "sidepart", "slick", "mullet", "twoblock", "crop", "permwave", "bobcurl", "thin", "bald"]],
	["HAIR_MEDIUM", []], ["HAIR_LONG", ["hippie", "wolfcut"]], ["HAIR_TIED", ["ponytail", "pigtails", "tripo_buns", "lowbun", "braids", "topbun", "spacebuns"]]]
const CLOSE_TABS := ["TAB_HAIR", "TAB_FACE", "TAB_HAT", "TAB_ACC"]

const CAM_FULL := [Vector3(0.0, 1.15, 4.0), Vector3(0.0, 0.84, 0.0)]
const CAM_FACE := [Vector3(0.16, 1.12, 2.9), Vector3(0.16, 0.95, 0.0)]
var _cam_to := CAM_FULL
var _cam_look: Vector3 = CAM_FULL[1]

func _ready() -> void:
	Stage.setup(self)
	_build_stage()
	look = Looks.load_saved()
	if OS.get_cmdline_user_args().has("--new-game"):
		Hero.new_game = true
	if Hero.new_game:
		Hero.load_saved()
		look = Hero.start_look(Hero.gender)
	var lj := Stage.arg("--look")
	if lj != "":
		look.merge(JSON.parse_string(lj), true)
	chibi = Chibi.new()
	add_child(chibi)
	chibi.build(look)
	chibi.position = Vector3(0.62, 0, 0)
	cam = Camera3D.new()
	add_child(cam)
	cam.position = CAM_FULL[0]
	cam.look_at(CAM_FULL[1], Vector3.UP)
	cam.fov = 32.0
	thumbs = LookThumbs.new()
	add_child(thumbs)
	_build_ui()
	still = Stage.still_args()
	if OS.get_cmdline_user_args().has("--turn-demo"):
		for i in 8:
			get_tree().create_timer(0.6 + 0.55 * i).timeout.connect(func(): _turn(PI / 4.0))
	var tab := Stage.arg("--tab")
	if tab != "":
		(ui.find_child("Tabs", true, false) as TabContainer).current_tab = int(tab)

func _build_stage() -> void:
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.75
	cm.bottom_radius = 0.8
	cm.height = 0.12
	disc.mesh = cm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/toon.gdshader")
	m.set_shader_parameter("base_color", Color("ffe3ea"))
	disc.material_override = m
	disc.position = Vector3(0.62, -0.06, 0)
	add_child(disc)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/toon.gdshader")
	gm.set_shader_parameter("base_color", Color("cdeeb4"))
	ground.material_override = gm
	ground.position.y = -0.12
	add_child(ground)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiTheme.make()
	layer.add_child(ui)

	var title := Label.new()
	title.text = tr("CREATOR_TITLE")
	title.add_theme_font_size_override("font_size", 44)
	title.position = Vector2(60, 36)
	ui.add_child(title)
	Hero.load_saved()
	if not Hero.new_game and (_in_opening() or Hero.gender == ""):
		_gender_pick(title)

	var panel := PanelContainer.new()
	panel.position = Vector2(50, 120)
	panel.custom_minimum_size = Vector2(760, 820)
	ui.add_child(panel)
	var tabs := TabContainer.new()
	tabs.name = "Tabs"
	panel.add_child(tabs)
	if Hero.new_game:
		_profile_tab(tabs)
	_tab(tabs, "TAB_HAIR", [["ROW_HAIR_STYLE", "shape", "hair", Looks.shapes("hair")], ["ROW_HAIR_COLOR", "color", "hair_color", Looks.HAIR_COLORS]])
	_tab(tabs, "TAB_FACE", [["ROW_EYE_STYLE", "shape", "eye_style", Looks.EYE_STYLES], ["ROW_EYE_COLOR", "color", "eye_color", Looks.EYE_COLORS],
		["ROW_BLUSH", "blush", "blush", [0.0, 0.35, 0.6, 0.9]],
		["ROW_FACE_SHAPE", "shape", "face", ["normal"] + Chibi.FACES]])
	_tab(tabs, "TAB_SKIN", [["ROW_SKIN", "color", "skin", Looks.SKINS]])
	for slot in [["TAB_TOP", "top", "tops"], ["TAB_BOTTOM", "bottom", "bottoms"], ["TAB_SHOES", "shoes", "shoes"]]:
		var opts: Array = Looks.shapes(slot[2])
		if slot[1] == "bottom":
			opts = ["none"] + opts
		var rows := [["ROW_STYLE", "part", slot[1] + ".shape", opts]]
		if slot[1] != "shoes":
			rows.append(["ROW_DESIGN", "shape", slot[1] + ".design", Looks.TOP_DESIGNS if slot[1] == "top" else Looks.BOTTOM_DESIGNS])
		rows += [["ROW_COLOR_MAIN", "color", slot[1] + ".color", Looks.CLOTH_COLORS],
			["ROW_PATTERN", "shape", slot[1] + ".pattern", Looks.PATTERNS], ["ROW_COLOR_SECOND", "color", slot[1] + ".color_b", Looks.CLOTH_COLORS]]
		if slot[1] != "shoes":
			rows.append(["ROW_COLOR_THIRD", "color", slot[1] + ".color_c", Looks.CLOTH_COLORS])
		rows.append(["ROW_TRIM", "color", slot[1] + ".trim", Looks.CLOTH_COLORS])
		if slot[1] == "shoes":
			rows += [["ROW_SOCKS", "part", "socks.shape", ["none"] + Looks.shapes("socks").filter(func(n: String) -> bool: return not n.ends_with("_in"))],
				["ROW_SOCKS_COLOR", "color", "socks.color", Looks.CLOTH_COLORS], ["ROW_SOCKS_TRIM", "color", "socks.trim", Looks.CLOTH_COLORS]]
		_tab(tabs, slot[0], rows)
	_tab(tabs, "TAB_HAT", [["ROW_STYLE", "part", "hat.shape", ["none"] + Looks.shapes("hats")],
		["ROW_COLOR_MAIN", "color", "hat.color", Looks.CLOTH_COLORS], ["ROW_TRIM", "color", "hat.trim", Looks.CLOTH_COLORS],
		["ROW_EAR_INNER", "color", "hat.color_c", ["#ffb6c8", "#ffd6e0", "#f2d2b0", "#ffffff", "#c4a3ff", "#7fd3e6"]]])
	_tab(tabs, "TAB_ACC", [["ROW_STYLE", "part", "acc.shape", ["none"] + Looks.shapes("accessories")],
		["ROW_COLOR_MAIN", "color", "acc.color", Looks.CLOTH_COLORS + ["#e8434d", "#ffd36e"]],
		["ROW_COLOR_SECOND", "color", "acc.trim", Looks.CLOTH_COLORS + ["#58a85a", "#ffb84d"]]])
	_emote_tab(tabs)
	tabs.tab_changed.connect(func(i: int): _on_tab(tabs.get_tab_control(i).name))
	_on_tab.call_deferred(tabs.get_tab_control(tabs.current_tab).name)

	for t in [["◀", -1.0, Vector2(990, 520)], ["▶", 1.0, Vector2(1470, 520)]]:
		var tb := Button.new()
		tb.text = t[0]
		tb.custom_minimum_size = Vector2(72, 72)
		tb.position = t[2]
		tb.add_theme_font_size_override("font_size", 30)
		var step: float = t[1]
		tb.pressed.connect(func(): _turn(step * PI / 4.0))
		ui.add_child(tb)
	var turn_hint := Label.new()
	turn_hint.text = tr("HINT_TURN")
	turn_hint.add_theme_font_size_override("font_size", 20)
	turn_hint.add_theme_color_override("font_color", Color("8a7a74"))
	turn_hint.position = Vector2(1180, 1028)
	turn_hint.custom_minimum_size = Vector2(300, 0)
	turn_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(turn_hint)

	var bar := HBoxContainer.new()
	bar.position = Vector2(980, 950)
	bar.add_theme_constant_override("separation", 16)
	ui.add_child(bar)
	for b in [["BTN_RANDOM", _randomize], ["BTN_WAVE", func(): chibi.emote("wave")],
			["BTN_HAPPY", func(): chibi.emote("happy")], ["BTN_BEGIN" if Hero.new_game or _in_opening() else "BTN_START", _start]]:
		var btn := Button.new()
		btn.text = tr(b[0])
		btn.custom_minimum_size = Vector2(170, 64)
		btn.pressed.connect(b[1])
		bar.add_child(btn)
	var go: Button = bar.get_child(3)
	go.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PINK_DARK, 18))
	go.add_theme_color_override("font_color", Color.WHITE)
	go.add_theme_font_size_override("font_size", 26)
	_quality_menu()
	_language_menu()

func _quality_menu() -> void:
	var box := PanelContainer.new()
	box.name = "Quality"
	box.position = Vector2(50, 956)
	ui.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var head := Label.new()
	head.text = tr("GRAPHICS")
	row.add_child(head)
	var group := ButtonGroup.new()
	var auto_btn: Button
	for level in ["auto", "low", "medium", "high"]:
		var b := Button.new()
		b.text = Quality.label(level)
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(110, 48)
		b.button_pressed = Quality.saved() == level
		b.pressed.connect(func():
			Quality.set_level(level, self)
			auto_btn.text = Quality.label("auto") + (" (%s)" % Quality.label(Quality.chosen()) if level == "auto" else ""))
		row.add_child(b)
		if level == "auto":
			auto_btn = b
	if Quality.saved() == "auto":
		auto_btn.text += " (%s)" % Quality.label(Quality.chosen())

func _language_menu() -> void:
	var box := PanelContainer.new()
	box.name = "Language"
	ui.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var head := Label.new()
	head.text = tr("LANGUAGE")
	row.add_child(head)
	var group := ButtonGroup.new()
	for lang in Lang.LANGS:
		var b := Button.new()
		b.text = Lang.NAMES[lang]
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 48)
		b.button_pressed = Lang.current == lang
		b.pressed.connect(func():
			if lang != Lang.current:
				Looks.save(look)
				Lang.set_language(lang))
		row.add_child(b)
	box.reset_size()
	box.position = Vector2(1870 - box.size.x, 30)

func _option_name(value: String) -> String:
	return Looks.option_name(value)

func _tab(tabs: TabContainer, title: String, rows: Array) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, tr(title))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)
	for r in rows:
		var lab := Label.new()
		lab.text = tr(r[0])
		lab.add_theme_font_size_override("font_size", 24)
		v.add_child(lab)
		var groups := [["", r[3]]]
		if r[2] == "hair":
			groups = []
			var rest: Array = r[3].filter(func(h): return not HAIR_GROUPS.any(func(g): return h in g[1]))
			for g in HAIR_GROUPS:
				var members: Array = rest if g[0] == "HAIR_MEDIUM" else r[3].filter(func(h): return h in g[1])
				if not members.is_empty():
					groups.append([g[0], members])
		for g in groups:
			if g[0] != "":
				var sub := Label.new()
				sub.text = tr(g[0])
				sub.add_theme_font_size_override("font_size", 19)
				sub.add_theme_color_override("font_color", Color("a08a82"))
				v.add_child(sub)
			var grid := HFlowContainer.new()
			grid.add_theme_constant_override("h_separation", 10)
			grid.add_theme_constant_override("v_separation", 10)
			v.add_child(grid)
			for opt in g[1]:
				grid.add_child(_option(r[1], r[2], opt, title))

func _frame_for(key: String) -> String:
	"""Which picture a style gets: the head for hair, eyes, hats and accessories; the feet for shoes."""
	if key in ["hair", "eye_style", "face"] or key.begins_with("hat.") or key.begins_with("acc."):
		return "head"
	return "feet" if key.begins_with("shoes.") else "body"

func _option(kind: String, key: String, value, tab := "") -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_entered.connect(func(): chibi.apply_look(_with_value(look, key, value)))
	b.mouse_exited.connect(func(): chibi.apply_look(look))
	if kind in ["shape", "part"] and not key.ends_with("color"):
		b.text = _option_name(str(value))
		b.custom_minimum_size = Vector2(132, 160)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_constant_override("icon_max_width", 112)
		b.clip_text = true
		_tiles.append({"button": b, "key": key, "value": value, "frame": _frame_for(key), "tab": tab})
		b.pressed.connect(func(): _set_value(key, value))
		return b
	if kind == "color":
		b.custom_minimum_size = Vector2(58, 58)
		b.add_theme_stylebox_override("normal", UiTheme.box(Color(value), 29, Color("ffffff"), 4))
		b.add_theme_stylebox_override("hover", UiTheme.box(Color(value), 29, UiTheme.PINK, 5))
		b.add_theme_stylebox_override("pressed", UiTheme.box(Color(value), 29, UiTheme.PINK_DARK, 6))
	elif kind == "blush":
		b.text = tr(["BLUSH_NONE", "BLUSH_LIGHT", "BLUSH_MEDIUM", "BLUSH_STRONG"][[0.0, 0.35, 0.6, 0.9].find(value)])
		b.custom_minimum_size = Vector2(120, 52)
	else:
		b.text = _option_name(str(value))
		b.custom_minimum_size = Vector2(150, 52)
	b.pressed.connect(func(): _set_value(key, value))
	return b

func _on_tab(tab_name: String) -> void:
	_tab_now = tab_name
	_cam_to = CAM_FACE if tab_name in CLOSE_TABS else CAM_FULL
	_refresh_thumbs()

func _refresh_thumbs() -> void:
	"""Re-take the pictures of the tab in view (the look has changed: their colours and the rest with it)."""
	thumbs.clear()
	for t in _tiles:
		if t["tab"] != _tab_now:
			continue
		var b: Button = t["button"]
		thumbs.request(_with_value(look, t["key"], t["value"]), t["frame"], func(tex: Texture2D):
			if is_instance_valid(b):
				b.icon = tex)

func _set_value(key: String, value) -> void:
	look = _with_value(look, key, value)
	chibi.apply_look(look)
	if key.ends_with("shape") or key.ends_with("design") or key == "hair":
		chibi.emote("happy" if randf() < 0.5 else "wave")
	_refresh_thumbs()

func _with_value(base: Dictionary, key: String, value) -> Dictionary:
	return Looks.with_value(base, key, value)

func _randomize() -> void:
	look["hair"] = Looks.shapes("hair").pick_random()
	look["hair_color"] = Looks.HAIR_COLORS.pick_random()
	look["eye_style"] = Looks.EYE_STYLES.pick_random()
	look["eye_color"] = Looks.EYE_COLORS.pick_random()
	look["skin"] = Looks.SKINS.pick_random()
	for slot in [["top", "tops"], ["bottom", "bottoms"], ["shoes", "shoes"]]:
		var shp: String = Looks.shapes(slot[1]).pick_random()
		if slot[0] == "top" and shp == "dress":
			look["bottom"] = {"shape": "none"}
		look[slot[0]] = {"shape": shp, "color": Looks.CLOTH_COLORS.pick_random(), "color_b": Looks.CLOTH_COLORS.pick_random(),
			"pattern": Looks.PATTERNS.pick_random() if randf() < 0.6 else "plain", "trim": Looks.CLOTH_COLORS.pick_random()}
	if look["top"]["shape"] != "dress" and look["bottom"].get("shape", "none") == "none":
		look["bottom"]["shape"] = "shorts"
	chibi.apply_look(look)
	chibi.emote("happy")
	_refresh_thumbs()

func _gender_pick(title: Label) -> void:
	_gender_box = PanelContainer.new()
	_gender_box.name = "Gender"
	ui.add_child(_gender_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_gender_box.add_child(row)
	var head := Label.new()
	head.text = tr("ROW_GENDER")
	head.add_theme_font_size_override("font_size", 26)
	row.add_child(head)
	var group := ButtonGroup.new()
	for g in [["m", "GENDER_M"], ["f", "GENDER_F"]]:
		var b := Button.new()
		b.text = tr(g[1])
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = Hero.gender == g[0]
		b.custom_minimum_size = Vector2(150, 56)
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.PINK, 16, UiTheme.PINK_DARK, 3))
		b.pressed.connect(func():
			Hero.gender = g[0]
			Hero.save()
			_gender_hint.visible = false
			chibi.emote("wave"))
		row.add_child(b)
	_gender_hint = Label.new()
	_gender_hint.text = tr("GENDER_PICK_HINT")
	_gender_hint.add_theme_font_size_override("font_size", 22)
	_gender_hint.add_theme_color_override("font_color", UiTheme.PINK_DARK)
	_gender_hint.visible = false
	ui.add_child(_gender_hint)
	_place_gender.call_deferred(title)

func _place_gender(title: Label) -> void:
	_gender_box.position = Vector2(title.position.x + title.size.x + 36, 30)
	_gender_hint.position = _gender_box.position + Vector2(10, _gender_box.size.y + 4)

func _gender_missing() -> bool:
	"""True (and the box nods at the player) while the gender is still to pick."""
	if _gender_box == null or Hero.gender in ["m", "f"]:
		return false
	_gender_hint.visible = true
	var x := _gender_box.position.x
	var tw := create_tween()
	for d in [14.0, -12.0, 8.0, -4.0, 0.0]:
		tw.tween_property(_gender_box, "position:x", x + d, 0.06)
	return true

func _in_opening() -> bool:
	"""Opened by the story's opening, after the name (scripts/opening.gd, docs/opening_spec.md)."""
	Story.load_saved()
	return not Story.opening_done and Story.beat == "look"

func _start() -> void:
	if _gender_missing():
		return
	Looks.save(look)
	if _in_opening():
		Story.set_beat("bridge")
		get_tree().change_scene_to_file("res://scenes/opening.tscn")
		return
	if Hero.new_game:
		Hero.new_game = false
		if Hero.name.strip_edges() == "":
			Hero.name = Hero.DEFAULT_NAMES[Hero.gender]
		Hero.save()
		Net.set_my_name(Hero.name)
		get_tree().change_scene_to_file("res://scenes/office_intro.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/village.tscn")

func _profile_tab(tabs: TabContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "TAB_PROFILE"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, tr("TAB_PROFILE"))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	scroll.add_child(v)
	var head := func(key: String):
		var lab := Label.new()
		lab.text = tr(key)
		lab.add_theme_font_size_override("font_size", 24)
		v.add_child(lab)
	head.call("ROW_NAME")
	var name_edit := LineEdit.new()
	name_edit.text = Hero.name
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(420, 56)
	name_edit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_edit.add_theme_font_size_override("font_size", 26)
	name_edit.add_theme_stylebox_override("normal", UiTheme.box(Color.WHITE, 16, Color("f3d9d0"), 2, 14))
	name_edit.add_theme_stylebox_override("focus", UiTheme.box(Color.WHITE, 16, UiTheme.PINK, 3, 14))
	name_edit.add_theme_color_override("font_color", UiTheme.INK)
	name_edit.text_changed.connect(func(s): Hero.name = s.strip_edges())
	name_edit.text_submitted.connect(func(_s): name_edit.release_focus())
	v.add_child(name_edit)
	head.call("ROW_GENDER")
	var gender_row := HFlowContainer.new()
	gender_row.add_theme_constant_override("h_separation", 10)
	v.add_child(gender_row)
	var gg := ButtonGroup.new()
	for g in [["m", "GENDER_M"], ["f", "GENDER_F"]]:
		var b := Button.new()
		b.text = tr(g[1])
		b.toggle_mode = true
		b.button_group = gg
		b.button_pressed = Hero.gender == g[0]
		b.custom_minimum_size = Vector2(180, 56)
		b.pressed.connect(func():
			if Hero.gender == g[0]:
				return
			var was_default: bool = Hero.name == "" or Hero.name == Hero.DEFAULT_NAMES[Hero.gender]
			Hero.gender = g[0]
			if was_default:
				Hero.name = Hero.DEFAULT_NAMES[g[0]]
				name_edit.text = Hero.name
			look = Hero.start_look(g[0])
			chibi.apply_look(look)
			chibi.emote("wave"))
		gender_row.add_child(b)
	head.call("ROW_JOB")
	var jg := ButtonGroup.new()
	for j in [["dev", "JOB_DEV", "JOB_DEV_NOTE"], ["design", "JOB_DESIGN", "JOB_DESIGN_NOTE"]]:
		var b := Button.new()
		b.text = "%s\n%s" % [tr(j[1]), tr(j[2])]
		b.toggle_mode = true
		b.button_group = jg
		b.button_pressed = Hero.job == j[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(560, 84)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(func():
			Hero.job = j[0]
			chibi.emote("idea" if Chibi.emotes.has("idea") else "happy"))
		v.add_child(b)

func _turn(by: float) -> void:
	yaw += by
	idle = 0.0

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		dragging = e.pressed
	elif e is InputEventScreenTouch:
		dragging = e.pressed
	elif (e is InputEventMouseMotion or e is InputEventScreenDrag) and dragging:
		yaw += e.relative.x * 0.012
		idle = 0.0
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode in [KEY_A, KEY_LEFT]:
			_turn(-PI / 4.0)
		elif e.physical_keycode in [KEY_D, KEY_RIGHT]:
			_turn(PI / 4.0)

func _process(delta: float) -> void:
	spin += delta
	idle += delta
	var k := 1.0 - exp(-delta * 6.0)
	cam.position = cam.position.lerp(_cam_to[0], k)
	_cam_look = _cam_look.lerp(_cam_to[1], k)
	cam.look_at(_cam_look, Vector3.UP)
	shown_yaw = lerp_angle(shown_yaw, yaw, 1.0 - exp(-delta * 10.0))

	var sway := sin(spin * 0.5) * deg_to_rad(28.0) * smoothstep(4.0, 6.0, idle)
	chibi.rotation.y = deg_to_rad(-18.0) + shown_yaw + sway
	if still.size() == 2 and still[0] != "" and chibi._time >= still[1]:
		set_process(false)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(still[0])
		get_tree().quit()

func _emote_tab(tabs: TabContainer) -> void:
	"""Every reaction (data/emotes.json) as a button: body clip + face + effect, like ACNH's reactions."""
	var scroll := ScrollContainer.new()
	scroll.name = "TAB_REACTIONS"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, tr("TAB_REACTIONS"))
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for k in Chibi.load_emotes():
		var b := EmoteWheel.emote_button(k, Chibi.emotes[k])
		b.pressed.connect(func(): chibi.emote(k))
		grid.add_child(b)
