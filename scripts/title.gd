extends Node3D

var chibi: Chibi
var ui: Control
var t := 0.0
var still := []
var press: Label
var _slots_ui: Control
var _cards: HBoxContainer
var _ask: Control
var _busy := false
var _heads: Array = []
const BLUR := """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.32, 0.18, 0.2, 0.38);
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 3.2).rgb;
	COLOR = vec4(mix(c, tint.rgb, tint.a), 1.0);
}"""

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--new-story"):
		Story.new_story()
	Story.load_saved()
	var used := SlotKeeper.slots().filter(func(c): return not c["empty"])
	var only_this := used.size() == 1 and int(used[0]["slot"]) == SlotKeeper.active()
	if used.is_empty() or (only_this and not Story.opening_done):
		get_tree().change_scene_to_file.call_deferred(Story.scene())
		set_process(false)
		return
	var sun := Stage.setup(self, 0.6)
	sun.light_color = Color("ffc896")
	sun.rotation_degrees = Vector3(-22, -35, 0)
	var we := find_child("WorldEnvironment", false, false) as WorldEnvironment
	var sky := (we.environment.sky.sky_material as ProceduralSkyMaterial)
	sky.sky_top_color = Color("8fb4e8")
	sky.sky_horizon_color = Color("ffd2b0")
	sky.ground_horizon_color = Color("ffd2b0")
	_build_set()
	Hero.load_saved()
	chibi = Chibi.new()
	add_child(chibi)
	chibi.build(Looks.load_saved() if Hero.exists() else Hero.start_look())
	chibi.position = Vector3(0.7, 0, 0.2)
	chibi.rotation.y = deg_to_rad(-20)
	get_tree().create_timer(1.2).timeout.connect(func(): chibi.emote("wave"))
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(-0.2, 1.35, 4.6)
	cam.look_at(Vector3(0.2, 0.95, 0), Vector3.UP)
	cam.fov = 34.0
	_build_ui()
	still = Stage.still_args()
	if OS.get_cmdline_user_args().has("--slots"):
		_open_slots.call_deferred()

func _build_set() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/toon.gdshader")
	gm.set_shader_parameter("base_color", Color("b8dfa0"))
	ground.material_override = gm
	add_child(ground)
	var path := MeshInstance3D.new()
	var pp := PlaneMesh.new()
	pp.size = Vector2(1.2, 14.0)
	path.mesh = pp
	var pmat := ShaderMaterial.new()
	pmat.shader = preload("res://shaders/toon.gdshader")
	pmat.set_shader_parameter("base_color", Color("e8cfa4"))
	path.material_override = pmat
	path.position = Vector3(0.9, 0.005, -4.0)
	path.rotation_degrees.y = 8.0
	add_child(path)
	for at in [Vector3(-5.2, 0, -7.5), Vector3(3.1, 0, -4.2), Vector3(-3.6, 0, -6.5), Vector3(1.0, 0, -9.0)]:
		var tree := ChopTree.new()
		tree.position = at
		tree.rotation.y = randf() * TAU
		add_child(tree)
	Furniture.place(self, "plastic_stool", Vector3(1.55, 0, 0.1), 15.0, false)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiTheme.make()
	layer.add_child(ui)
	var title := Label.new()
	title.text = tr("GAME_TITLE")
	title.add_theme_font_size_override("font_size", 120)
	title.add_theme_color_override("font_color", Color("fff8ef"))
	title.add_theme_color_override("font_outline_color", Color("c9746a"))
	title.add_theme_constant_override("outline_size", 22)
	title.position = Vector2(110, 150)
	ui.add_child(title)
	_heads.append(title)
	var sub := Label.new()
	sub.text = tr("GAME_SUBTITLE")
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color("fff8ef"))
	sub.add_theme_color_override("font_outline_color", Color("b8685e"))
	sub.add_theme_constant_override("outline_size", 10)
	sub.position = Vector2(118, 320)
	ui.add_child(sub)
	_heads.append(sub)
	press = Label.new()
	press.text = tr("PRESS_ANY_KEY")
	press.add_theme_font_size_override("font_size", 34)
	press.add_theme_color_override("font_color", Color("fff8ef"))
	press.add_theme_color_override("font_outline_color", Color("b8685e"))
	press.add_theme_constant_override("outline_size", 10)
	press.position = Vector2(118, 520)
	ui.add_child(press)
	var langs := HBoxContainer.new()
	langs.add_theme_constant_override("separation", 8)
	ui.add_child(langs)
	for lang in Lang.LANGS:
		var lb := Button.new()
		lb.text = Lang.NAMES[lang]
		lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lb.toggle_mode = true
		lb.button_pressed = Lang.current == lang
		lb.custom_minimum_size = Vector2(0, 46)
		lb.pressed.connect(func(): if lang != Lang.current: Lang.set_language(lang))
		langs.add_child(lb)
	langs.reset_size()
	langs.position = Vector2(1870 - langs.size.x, 30)
	var credits := Button.new()
	credits.text = tr("CR_BUTTON")
	credits.custom_minimum_size = Vector2(0, 46)
	credits.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/credits.tscn"))
	ui.add_child(credits)
	credits.reset_size()
	credits.position = Vector2(1870 - credits.size.x, 1080 - 30 - credits.size.y)

func _unhandled_input(e: InputEvent) -> void:
	"""Any key, click or touch goes on (the language buttons take their own clicks first)."""
	var go: bool = (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed) 		or (e is InputEventScreenTouch and e.pressed)
	if _slots_ui:
		if e.is_action_pressed("ui_cancel") or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_B):
			get_viewport().set_input_as_handled()
			if _ask:
				_close_ask()
			else:
				_close_slots()
		return
	if go and t > 0.6:
		get_viewport().set_input_as_handled()
		_open_slots()

func _continue() -> void:

	Story.load_saved()
	if String(Story.chapter).begins_with("que_"):
		get_tree().change_scene_to_file("res://scenes/farm_plot.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/office.tscn")

func _process(delta: float) -> void:
	t += delta
	if press:
		press.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 2.4))
	if still.size() == 2 and still[0] != "" and t >= still[1]:
		set_process(false)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(still[0])
		get_tree().quit()

func _open_slots() -> void:
	if _slots_ui or _busy:
		return
	press.visible = false
	_slots_ui = Control.new()
	_slots_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_slots_ui)
	var dim := ColorRect.new()
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = BLUR
	dim.material = sm
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slots_ui.add_child(dim)
	for h in _heads:
		(h as Control).visible = false
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 30)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slots_ui.add_child(col)
	var head := Label.new()
	head.text = tr("SLOT_TITLE")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 52)
	head.add_theme_color_override("font_color", UiTheme.CREAM)
	head.add_theme_color_override("font_outline_color", Color("b8685e"))
	head.add_theme_constant_override("outline_size", 14)
	col.add_child(head)
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 30)
	col.add_child(_cards)
	var back := Button.new()
	back.text = tr("SLOT_BACK")
	back.custom_minimum_size = Vector2(220, 60)
	back.add_theme_font_size_override("font_size", 26)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_slots)
	col.add_child(back)
	_fill_cards()
	_slots_ui.modulate.a = 0.0
	create_tween().tween_property(_slots_ui, "modulate:a", 1.0, 0.25)

func _close_slots() -> void:
	if not _slots_ui or _busy:
		return
	_slots_ui.queue_free()
	_slots_ui = null
	_cards = null
	press.visible = true
	for h in _heads:
		(h as Control).visible = true
	t = 0.0

func _fill_cards() -> void:
	for c in _cards.get_children():
		c.queue_free()
	var slots := SlotKeeper.slots()
	var latest := -1
	var latest_at := -1
	for info in slots:
		if not info["empty"] and int(info.get("saved_at", 0)) >= latest_at:
			latest_at = int(info.get("saved_at", 0))
			latest = int(info["slot"])
	var focus: Control = null
	for info in slots:
		var card := _card(info)
		_cards.add_child(card)
		if focus == null or int(info["slot"]) == latest:
			focus = card
	if focus:
		focus.grab_focus.call_deferred()

func _card(info: Dictionary) -> Button:
	var n := int(info["slot"])
	var empty: bool = info["empty"]
	var card := Button.new()
	card.custom_minimum_size = Vector2(440, 430)
	card.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CREAM, 28, Color("f3d9d0"), 3, 18))
	card.add_theme_stylebox_override("hover", UiTheme.box(Color("fff3f0"), 28, UiTheme.PINK, 4, 18))
	card.add_theme_stylebox_override("focus", UiTheme.box(Color("fffaf3"), 28, UiTheme.PINK_DARK, 5, 18))
	card.add_theme_stylebox_override("pressed", UiTheme.box(Color("ffe6ec"), 28, UiTheme.PINK_DARK, 4, 18))
	card.pressed.connect(func(): _pick(n, empty))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 20
	box.offset_right = -20
	box.offset_top = 20
	box.offset_bottom = -18
	card.add_child(box)
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(400, 225)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	frame.add_theme_stylebox_override("panel", UiTheme.box(Color("f6e3d8") if empty else Color("e9d6cc"), 20))
	box.add_child(frame)
	var tex := _thumb(info) if not empty else null
	if tex:
		var pic := TextureRect.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.add_child(pic)
	else:
		var mark := Label.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.text = "+" if empty else str(n)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		mark.add_theme_font_size_override("font_size", 96)
		mark.add_theme_color_override("font_color", Color(UiTheme.PINK_DARK, 0.75))
		frame.add_child(mark)
	var name_l := _line(box, 32, UiTheme.INK)
	var line2 := _line(box, 23, Color("8a6e64"))
	var line3 := _line(box, 21, Color("a8918a"))
	if empty:
		name_l.text = tr("SLOT_NEW")
		line2.text = tr("SLOT_EMPTY")
		return card
	name_l.text = str(info.get("name", "")) if str(info.get("name", "")) != "" else tr("SLOT_NO_NAME")
	name_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if not info.get("opening_done", false):
		line2.text = tr("SLOT_OPENING")
	elif str(info.get("chapter", "")).begins_with("que_"):
		line2.text = tr("SLOT_HOME") % int(info.get("day", 1))
	else:
		line2.text = tr("SLOT_CITY") % int(info.get("day", 1))
	var mins := int(float(info.get("playtime", 0.0)) / 60.0)
	line3.text = tr("SLOT_TIME") % [mins / 60, mins % 60]
	var del := Button.new()
	del.text = tr("SLOT_DELETE")
	del.focus_mode = Control.FOCUS_NONE
	del.custom_minimum_size = Vector2(92, 44)
	del.add_theme_font_size_override("font_size", 19)
	del.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 1, 1, 0.88), 14, Color("f3d9d0"), 2))
	del.anchor_left = 1.0
	del.anchor_right = 1.0
	del.offset_left = -92 - 32
	del.offset_right = -32
	del.offset_top = 32
	del.offset_bottom = 32 + 44
	del.pressed.connect(func(): _ask_delete(n, name_l.text))
	card.add_child(del)
	return card

func _line(box: VBoxContainer, size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = 400
	box.add_child(l)
	return l

func _thumb(info: Dictionary) -> Texture2D:
	var p := str(info.get("thumb", ""))
	if p == "" or not FileAccess.file_exists(p):
		return null
	var img := Image.load_from_file(p)
	return ImageTexture.create_from_image(img) if img and not img.is_empty() else null

func _ask_delete(n: int, who: String, sure := false) -> void:
	"""Asked twice (docs/opening_spec.md 9: a story is not lost by one tap)."""
	_close_ask()
	_ask = Control.new()
	_ask.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slots_ui.add_child(_ask)
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.1, 0.12, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ask.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ask.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)
	var q := Label.new()
	q.text = tr("SLOT_DEL_SURE") if sure else tr("SLOT_DEL_ASK") % who
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.add_theme_font_size_override("font_size", 32)
	q.custom_minimum_size = Vector2(620, 0)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(q)
	if not sure:
		var note := Label.new()
		note.text = tr("SLOT_DEL_NOTE")
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.add_theme_font_size_override("font_size", 23)
		note.add_theme_color_override("font_color", Color("8a6e64"))
		col.add_child(note)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	var keep := Button.new()
	keep.text = tr("SLOT_KEEP")
	keep.custom_minimum_size = Vector2(220, 64)
	keep.add_theme_font_size_override("font_size", 26)
	keep.pressed.connect(_close_ask)
	row.add_child(keep)
	var go := Button.new()
	go.text = tr("SLOT_DELETE")
	go.custom_minimum_size = Vector2(220, 64)
	go.add_theme_font_size_override("font_size", 26)
	if sure:
		go.add_theme_stylebox_override("normal", UiTheme.box(Color("e57a86"), 16, Color("d0606e"), 3))
		go.add_theme_color_override("font_color", Color.WHITE)
	go.pressed.connect(func():
		if sure:
			_close_ask()
			SlotKeeper.erase_slot(n)
			_fill_cards()
		else:
			_ask_delete(n, who, true))
	row.add_child(go)
	keep.grab_focus.call_deferred()

func _close_ask() -> void:
	if _ask:
		_ask.queue_free()
		_ask = null
		if _cards and _cards.get_child_count() > 0:
			(_cards.get_child(0) as Control).grab_focus.call_deferred()

func _pick(n: int, empty: bool) -> void:
	if _busy or _ask:
		return
	_busy = true
	if not SlotKeeper.use_slot(n):
		_busy = false
		return
	if empty:
		Story.new_story()
		get_tree().change_scene_to_file(Story.scene())
		return
	Story.load_saved()
	Hero.load_saved()
	if not Story.opening_done:
		get_tree().change_scene_to_file(Story.scene())
		return
	_continue()
