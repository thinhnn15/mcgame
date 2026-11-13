class_name PcScreen
extends Control

signal typed(chars: int)
signal task_done(text: String)
signal hide_pressed
signal stand_pressed
signal design_done(task)

const DESIGN := Vector2i(1152, 648)

const ICONS := {"riu": preload("res://brand/app_riu.png"), "design": preload("res://brand/app_pencil.png"),
	"code": preload("res://brand/app_code.png"), "board": preload("res://brand/app_board.png")}
const MC_TILE := preload("res://brand/mcstudio_mark.png")
const WIDTH := 0.56
const ZOOM_WIDTH := 0.86
const ZOOM_HEIGHT := 0.80
const AUTO_CPS := 6.0
const PER_KEY := 3
const CODE_SIZE := 18
const LINE_H := 25
const CODE_LINES := 11

const C := {"bg": Color("1e222a"), "title": Color("181b21"), "activity": Color("1a1d23"), "side": Color("20242c"),
	"tabbar": Color("191c22"), "tab": Color("1e222a"), "panel": Color("1a1d23"), "border": Color("2c313b"),
	"fg": Color("e3e7ee"), "side_fg": Color("b5bcc8"), "muted": Color("7d8594"), "gutter": Color("5a6170"),
	"accent": Color("5aa0f2"), "status": Color("3a6ea8"), "folder": Color("d8b25a"), "cpp": Color("6c9ef8"),
	"comment": Color("6f9a6a"), "string": Color("e6a26f"), "number": Color("b5cea8"), "keyword": Color("d78ee0"),
	"type": Color("5ec4b6"), "func": Color("e8d58a"), "ident": Color("a8c8f0"), "punct": Color("c3c9d4"),
	"ok": Color("7fcf8a"), "err": Color("f0636b"), "dim": Color("7d8594"), "plain": Color("c3c9d4")}
const KW := ["void", "if", "return", "for", "auto", "const", "continue", "struct", "class", "nullptr", "static",
	"true", "false", "while", "break", "int", "float", "bool", "emit", "std", "include"]

const TASKS := [
	{"card": "SCR_T1", "dir": "render", "file": "render_queue.cpp", "comment": "PC_C1", "pop": "WORK_POP_2",
		"pre": "void RenderQueue::flush(FrameContext& ctx)\n{\n    std::lock_guard<std::mutex> lock(mutex_);\n    if (items_.empty())\n        return;\n\n    for (auto& item : items_) {\n        auto* shader = cache_.find(item.shaderId);\n",
		"code": "        {C}\n        if (!shader || !item.mesh) {\n            LOG_WARN(\"skip draw %u\", item.shaderId);\n            continue;\n        }\n        ctx.bind(*shader);\n        ctx.draw(item.mesh, item.instanceCount);\n    }\n    items_.clear();\n}\n",
		"term": [["$ cmake --build build -j8", "dim"], ["[100%] Built target engine", "plain"], ["✓ build passed, 0 errors", "ok"]]},
	{"card": "SCR_T3", "dir": "assets", "file": "image_loader.cpp", "comment": "PC_C2", "pop": "WORK_POP_5",
		"pre": "#include \"image_loader.h\"\n#include <future>\n\nstd::vector<Image> ImageLoader::loadAll(const std::vector<Path>& files)\n{\n",
		"code": "    {C}\n    std::vector<std::future<Image>> jobs;\n    for (const auto& f : files)\n        jobs.push_back(pool_.run([f] { return decode(f); }));\n\n    std::vector<Image> out;\n    for (auto& j : jobs)\n        out.push_back(j.get());\n    return out;\n}\n",
		"term": [["$ ./bench images", "dim"], ["load 120 images: 2.41s -> 0.68s", "plain"], ["✓ 3.5x faster", "ok"]]},
	{"card": "SCR_T4", "dir": "tests", "file": "cart_test.cpp", "comment": "PC_C3", "pop": "WORK_POP_3",
		"pre": "#include \"cart.h\"\n#include <gtest/gtest.h>\n\n",
		"code": "{C}\nTEST(Cart, AddsUpTotal)\n{\n    Cart cart;\n    cart.add({\"milk_tea\", 35000}, 2);\n    cart.add({\"banh_mi\", 25000}, 1);\n    EXPECT_EQ(cart.total(), 95000);\n}\n\nTEST(Cart, EmptyIsZero)\n{\n    EXPECT_EQ(Cart{}.total(), 0);\n}\n",
		"term": [["$ ctest --output-on-failure", "dim"], ["[  PASSED  ] 14 tests.", "plain"], ["✓ all tests passed", "ok"]]},
	{"card": "SCR_T6", "dir": "sync", "file": "order_sync.cpp", "comment": "PC_C4", "pop": "WORK_POP_1",
		"pre": "#include \"order_sync.h\"\n\nvoid OrderSync::onServerUpdate(const Order& remote)\n{\n    auto& local = orders_[remote.id];\n",
		"code": "    {C}\n    if (remote.updatedAt <= local.updatedAt)\n        return;\n    local = remote;\n    emit changed(remote.id);\n}\n",
		"term": [["$ git commit -am \"fix: order sync keeps the newest\"", "dim"], ["[fix/order-sync 3f2c1a9] 1 file changed, 5 insertions(+)", "plain"], ["✓ pushed to origin", "ok"]]},
]

const BOARD := {"SCR_TODO": ["SCR_T3", "SCR_T4", "SCR_T6", "SCR_T8"], "SCR_DOING": ["SCR_T1"],
	"SCR_REVIEW": ["SCR_T2", "SCR_T5"], "SCR_DONE": ["SCR_T9", "SCR_T7"]}
const COLUMNS := ["SCR_TODO", "SCR_DOING", "SCR_REVIEW", "SCR_DONE"]
const TAGS := {"SCR_TODO": Color("9aa3b0"), "SCR_DOING": Color("5aa0f2"), "SCR_REVIEW": Color("e8b04a"), "SCR_DONE": Color("5fbf7a")}

var shown := false
var job := "dev"
var night := false
var fatigue := 0.0
var _design: DesignApp
var _box: SubViewportContainer
var _vig: TextureRect
var _dim: ColorRect
var centred := false
var working := false
var app := "code"
var clock_text := "10:10"
var minute := 610.0
var zoomed := false
var _riu: RiuApp
var _riu_app: Control
var _desk_icons: Control
var _riu_badge: Label
var _vp: SubViewport
var _frame: PanelContainer
var _stand_neck: Panel
var _stand_foot: Panel
var _led: ColorRect
var _mono: Font
var _task := 0
var _typed := 0
var _owed := 0.0
var _pause := 0.0
var _code_text := ""
var _board := {}
var _term_lines: Array = []
var _code_view: RichTextLabel
var _term_view: RichTextLabel
var _status_pos: Label
var _title: Label
var _tabs: HBoxContainer
var _explorer: VBoxContainer
var _code_app: Control
var _board_app: Control
var _board_cols: HBoxContainer
var _app_buttons := {}
var _clock: Label
var _toast: PanelContainer
var _toast_label: Label
var _blink := 0.0
var _caret_on := true

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_mono = SystemFont.new()
	(_mono as SystemFont).font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Menlo", "DejaVu Sans Mono", "monospace"])
	if Lang.font:
		var fb: Array[Font] = [Lang.font]
		_mono.fallbacks = fb
	for col in BOARD:
		_board[col] = (BOARD[col] as Array).duplicate()
	_build_monitor()
	_build_desktop()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_begin()

func _begin() -> void:
	"""The desktop is built: start the work. (Other screens on the same monitor - scripts/job_pick.gd,
	scripts/mirror_screen.gd - extend this class and replace _build_desktop, _begin and _process.)"""
	if _design:
		_design.start()
	else:
		_start_task(0)
	if Stage.arg("--pc") in ["board", "riu", "desk"]:
		_show_app(Stage.arg("--pc"))
	if Stage.arg("--pc-zoom") != "":
		set_zoom(true)

func _build_monitor() -> void:
	_stand_neck = Panel.new()
	_stand_neck.add_theme_stylebox_override("panel", UiTheme.box(Color("3a3f4b"), 6, Color(0, 0, 0, 0), 0, 0))
	add_child(_stand_neck)
	_stand_foot = Panel.new()
	_stand_foot.add_theme_stylebox_override("panel", UiTheme.box(Color("444a57"), 14, Color(0, 0, 0, 0), 0, 0))
	add_child(_stand_foot)
	_frame = PanelContainer.new()
	var bezel := UiTheme.box(Color("2b2f38"), 26, Color("4a5060"), 2, 0)
	bezel.content_margin_left = 14
	bezel.content_margin_right = 14
	bezel.content_margin_top = 14
	bezel.content_margin_bottom = 26
	bezel.shadow_color = Color(0, 0, 0, 0.35)
	bezel.shadow_size = 18
	bezel.shadow_offset = Vector2(0, 6)
	_frame.add_theme_stylebox_override("panel", bezel)
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_frame)
	var box := SubViewportContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var tired := ShaderMaterial.new()
	tired.shader = preload("res://shaders/pc_tired.gdshader")
	box.material = tired
	_frame.add_child(box)
	_box = box
	_vp = SubViewport.new()
	_vp.disable_3d = true
	_vp.size_2d_override = DESIGN
	_vp.size_2d_override_stretch = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.gui_embed_subwindows = true
	box.add_child(_vp)
	_led = ColorRect.new()
	_led.color = Color("8fd3a8")
	_led.size = Vector2(6, 6)
	_led.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_led)

func _layout() -> void:
	var view := get_viewport_rect().size
	var w := view.x * WIDTH
	if zoomed:
		w = minf(view.x * ZOOM_WIDTH, (view.y * ZOOM_HEIGHT - 40.0) * DESIGN.x / DESIGN.y + 28.0)
	var screen_h := (w - 28.0) * DESIGN.y / DESIGN.x
	var h := screen_h + 40.0
	var mid := centred or zoomed
	var at := Vector2((view.x - w) * 0.5 if mid else view.x - w - view.x * 0.025, (view.y - h) * (0.36 if centred else 0.42))

	_vp.size = Vector2i(maxi(1, int(w - 28.0)), maxi(1, int(screen_h)))
	_box.size = Vector2(_vp.size)
	_frame.position = at
	_frame.size = Vector2(w, h)
	pivot_offset = at + Vector2(w * 0.5, h * 0.5)
	_stand_neck.size = Vector2(w * 0.08, view.y * 0.045)
	_stand_neck.position = Vector2(at.x + (w - _stand_neck.size.x) * 0.5, at.y + h - 8.0)
	_stand_foot.size = Vector2(w * 0.26, 16)
	_stand_foot.position = Vector2(at.x + (w - _stand_foot.size.x) * 0.5, _stand_neck.position.y + _stand_neck.size.y - 4.0)
	_led.position = Vector2(at.x + w * 0.5 - 3.0, at.y + h - 16.0)
	_stand_neck.visible = not mid
	_stand_foot.visible = not mid

func use_design_tasks() -> void:
	"""The designer's logo jobs come from the task list (scripts/morning/morning.gd): see DesignApp."""
	if _design:
		_design.use_tasks()

func design_assign(task) -> void:
	if _design:
		_design.assign(task)

func chat() -> RiuApp:
	"""The office chat (scripts/riu_app.gd): the morning posts to it and hears the answers."""
	return _riu

func set_zoom(on: bool) -> void:
	"""The screen big in the middle of the view (reading the chat), or back on the right."""
	if on == zoomed:
		return
	zoomed = on
	_layout()
	scale = Vector2(0.97, 0.97)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(self, "scale", Vector2.ONE, 0.22)

func open() -> void:
	if shown:
		return
	shown = true
	visible = true
	scale = Vector2(0.94, 0.94)
	modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.28)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)

func close() -> void:
	if not shown:
		return
	shown = false
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2(0.96, 0.96), 0.15)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(func(): visible = shown)

func live_material(base: ShaderMaterial) -> ShaderMaterial:
	"""The desk monitor's own screen material, showing this desktop live."""
	var m := base.duplicate() as ShaderMaterial
	m.set_shader_parameter("on", true)
	m.set_shader_parameter("screen_tex", _vp.get_texture())
	m.set_shader_parameter("brightness", 1.0)
	m.set_shader_parameter("caret", Vector4.ZERO)
	return m

func _build_desktop() -> void:
	var root := Control.new()
	root.size = DESIGN
	root.theme = UiTheme.make()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	root.theme.default_font_size = 15
	_vp.add_child(root)
	var wall := TextureRect.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("ffd9c7"), Color("c9dcf5")])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 1)
	wall.texture = gt
	wall.size = DESIGN
	wall.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(wall)
	var brand := TextureRect.new()
	brand.texture = preload("res://brand/mcstudio_logo.png")
	brand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	brand.size = Vector2(320, 100)
	brand.position = Vector2(DESIGN.x - 350, DESIGN.y - 44 - 130)
	brand.modulate.a = 0.22
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(brand)
	minute = _minutes(clock_text)
	_desk_icons = _build_icons()
	root.add_child(_desk_icons)
	var window_rect := Rect2(10, 10, DESIGN.x - 20, DESIGN.y - 44 - 20)
	if job == "design":
		_design = DesignApp.new(self)
		_code_app = _design.build(window_rect)
	else:
		_code_app = _build_code_app(window_rect)
	root.add_child(_code_app)
	_board_app = _build_board_app(window_rect)
	root.add_child(_board_app)
	_riu = RiuApp.new(self)
	_riu_app = _riu.build(window_rect)
	root.add_child(_riu_app)
	root.add_child(_build_taskbar())
	_riu.unread_changed.connect(func(n: int):
		_riu_badge.text = str(n)
		_riu_badge.visible = n > 0)
	_riu.tick()
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UiTheme.box(Color("2a2f3a", 0.96), 12, Color("7fcf8a"), 2, 16))
	_toast_label = Label.new()
	_toast_label.add_theme_color_override("font_color", Color("e9f7ec"))
	_toast_label.add_theme_font_size_override("font_size", 17)
	_toast.add_child(_toast_label)
	_toast.modulate.a = 0.0
	root.add_child(_toast)
	_vig = TextureRect.new()
	var vg := Gradient.new()
	vg.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	vg.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.25), Color(0, 0, 0, 1)])
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.05, 1.05)
	_vig.texture = vt
	_vig.size = DESIGN
	_vig.stretch_mode = TextureRect.STRETCH_SCALE
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig.modulate.a = 0.0
	root.add_child(_vig)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0)
	_dim.size = DESIGN
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dim)
	_show_app("code")

func _rect(c: Color, radius := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	return s

func _label(text: String, color: Color, size := 15, mono := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	if mono:
		l.add_theme_font_override("font", _mono)
	return l

func _panel(c: Color, min_size := Vector2.ZERO, radius := 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _rect(c, radius))
	p.custom_minimum_size = min_size
	return p

func _window(rect: Rect2, bar: Color, title_color: Color) -> Array:
	"""A window with rounded corners and a title bar (title, - [] x on the right). -> [window, title, body]"""
	var win := PanelContainer.new()
	var st := _rect(bar, 10)
	st.shadow_color = Color(0, 0, 0, 0.25)
	st.shadow_size = 10
	win.add_theme_stylebox_override("panel", st)
	win.position = rect.position
	win.size = rect.size
	win.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	win.add_child(v)
	var head := HBoxContainer.new()
	head.custom_minimum_size = Vector2(0, 34)
	var title := _label("", title_color, 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(110, 0)
	head.add_child(pad)
	head.add_child(title)
	for k in ["—", "□", "✕"]:
		var b := Button.new()
		b.text = k
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(36, 34)
		b.add_theme_color_override("font_color", title_color)
		b.add_theme_color_override("font_hover_color", Color.WHITE if k == "✕" else title_color)
		b.add_theme_font_size_override("font_size", 14)
		var hov := _rect(Color("e0565e") if k == "✕" else Color(1, 1, 1, 0.12), 6)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", hov)
		if k != "□":
			b.pressed.connect(_window_closed)
		else:
			b.pressed.connect(func():
				if _desk_icons and not night:
					set_zoom(not zoomed))
		head.add_child(b)
	v.add_child(head)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	return [win, title, body]

func _build_code_app(rect: Rect2) -> Control:
	var w: Array = _window(rect, C["title"], C["muted"])
	_title = w[1]
	var body: VBoxContainer = w[2]
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 0)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(main)
	var act := _panel(C["activity"], Vector2(46, 0))
	var icons := VBoxContainer.new()
	icons.add_theme_constant_override("separation", 18)
	for k in ["▤", "⌕", "⑂"]:
		var l := _label(k, C["accent"] if k == "▤" else C["muted"], 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icons.add_child(l)
	act.add_child(icons)
	main.add_child(act)
	var side := _panel(C["side"], Vector2(200, 0))
	_explorer = VBoxContainer.new()
	_explorer.add_theme_constant_override("separation", 3)
	side.add_child(_explorer)
	main.add_child(side)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	var tabbar := _panel(C["tabbar"], Vector2(0, 34))
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 1)
	tabbar.add_child(_tabs)
	right.add_child(tabbar)
	var ed := _panel(C["bg"])
	ed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ed.gui_input.connect(_tap)
	(ed.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 8
	(ed.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_top = 8
	_code_view = _rich(CODE_SIZE)
	ed.add_child(_code_view)
	right.add_child(ed)
	var term := _panel(C["panel"], Vector2(0, 128))
	(term.get_theme_stylebox("panel") as StyleBoxFlat).border_color = C["border"]
	(term.get_theme_stylebox("panel") as StyleBoxFlat).border_width_top = 1
	var tv := VBoxContainer.new()
	var heads := HBoxContainer.new()
	heads.add_theme_constant_override("separation", 22)
	for k in ["SCR_PROBLEMS", "SCR_OUTPUT", "SCR_TERMINAL"]:
		heads.add_child(_label(tr(k), C["fg"] if k == "SCR_TERMINAL" else C["muted"], 13))
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 12)
	hm.add_theme_constant_override("margin_top", 6)
	hm.add_child(heads)
	tv.add_child(hm)
	var tm := MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 12)
	tm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_term_view = _rich(16)
	tm.add_child(_term_view)
	tv.add_child(tm)
	term.add_child(tv)
	right.add_child(term)
	var status := _panel(C["status"], Vector2(0, 24))
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 18)
	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_left", 10)
	sm.add_theme_constant_override("margin_right", 14)
	sm.add_child(sh)
	sh.add_child(_label("⑂ fix/render-crash", Color.WHITE, 13))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(gap)
	_status_pos = _label("", Color.WHITE, 13)
	sh.add_child(_status_pos)
	sh.add_child(_label("UTF-8   C++", Color.WHITE, 13))
	status.add_child(sm)
	body.add_child(status)
	return w[0]

func _rich(size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", _mono)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", C["plain"])
	r.add_theme_constant_override("line_separation", LINE_H - size - 4 if size == CODE_SIZE else 3)
	return r

func _build_board_app(rect: Rect2) -> Control:
	var w: Array = _window(rect, Color("eef0f4"), Color("5b6270"))
	(w[1] as Label).text = tr("SCR_BOARD")
	var body: VBoxContainer = w[2]
	var page := _panel(Color("f7f8fa"))
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 18)
	page.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(_label(tr("SCR_BOARD"), Color("20242c"), 24))
	var due := _label("  " + tr("SCR_DAYS_LEFT"), Color("d9363e"), 15)
	due.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(due)
	v.add_child(head)
	_board_cols = HBoxContainer.new()
	_board_cols.add_theme_constant_override("separation", 14)
	_board_cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_board_cols)
	body.add_child(page)
	_fill_board()
	return w[0]

func _fill_board() -> void:
	for c in _board_cols.get_children():
		c.queue_free()
	for col in COLUMNS:
		var p := _panel(Color("eceef2"), Vector2.ZERO, 10)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var m := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + side, 10)
		p.add_child(m)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		m.add_child(v)
		var cards: Array = _board[col]
		v.add_child(_label("%s  %d" % [tr(col), cards.size()], Color("5b6270"), 13))
		for key in cards:
			var card := _panel(Color.WHITE, Vector2(0, 58), 8)
			var cs := card.get_theme_stylebox("panel") as StyleBoxFlat
			cs.border_color = TAGS[col]
			cs.border_width_left = 4
			cs.content_margin_left = 12
			cs.content_margin_top = 8
			cs.shadow_color = Color(0, 0, 0, 0.06)
			cs.shadow_size = 3
			var l := _label(tr(key), Color("20242c"), 15)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.add_child(l)
			v.add_child(card)
		_board_cols.add_child(p)

func _build_taskbar() -> Control:
	var bar := _panel(Color("1d2129", 0.92), Vector2(DESIGN.x, 44))
	bar.position = Vector2(0, DESIGN.y - 44)
	bar.size = Vector2(DESIGN.x, 44)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 14)
	m.add_child(h)
	bar.add_child(m)
	var logo := Button.new()
	logo.icon = MC_TILE
	logo.expand_icon = true
	logo.tooltip_text = tr("OS_DESKTOP")
	logo.focus_mode = Control.FOCUS_NONE
	logo.custom_minimum_size = Vector2(36, 36)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for s in ["normal", "hover", "pressed"]:
		var st := _rect(Color(1, 1, 1, {"normal": 0.0, "hover": 0.12, "pressed": 0.2}[s]), 8)
		st.set_content_margin_all(1)
		logo.add_theme_stylebox_override(s, st)
	logo.pressed.connect(_show_app.bind("desk"))
	h.add_child(logo)
	h.add_child(Control.new())
	for a in [["riu", tr("OS_RIU")], ["code", tr("OS_DESIGN") if job == "design" else tr("OS_CODE")],
			["board", tr("SCR_BOARD")]]:
		var b := _bar_button(a[1])
		b.icon = ICONS[_icon_of(a[0])]
		b.add_theme_constant_override("icon_max_width", 22)
		b.add_theme_constant_override("h_separation", 8)
		b.pressed.connect(_show_app.bind(a[0]))
		_app_buttons[a[0]] = b
		h.add_child(b)
		if a[0] == "riu":
			_riu_badge = _label("", Color.WHITE, 12)
			var bs := _rect(Color("e0565e"), 8)
			bs.content_margin_left = 5
			bs.content_margin_right = 5
			_riu_badge.add_theme_stylebox_override("normal", bs)
			_riu_badge.position = Vector2(4, 1)
			_riu_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_riu_badge.visible = false
			b.add_child(_riu_badge)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(gap)
	_clock = _label(clock_text, Color("e3e7ee"), 15)
	_clock.custom_minimum_size = Vector2(64, 0)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_clock)
	return bar

func _bar_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color("e3e7ee"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	for s in ["normal", "hover", "pressed"]:
		var st := _rect(Color(1, 1, 1, {"normal": 0.0, "hover": 0.1, "pressed": 0.16}[s]), 6)
		st.content_margin_left = 12
		st.content_margin_right = 12
		b.add_theme_stylebox_override(s, st)
	return b

func _build_icons() -> Control:
	"""The desktop's icons, down the left of the wallpaper (one click opens: no double clicks to learn)."""
	var col := VBoxContainer.new()
	col.position = Vector2(26, 22)
	col.add_theme_constant_override("separation", 14)
	for a in [["riu", "", null, tr("OS_RIU")], ["code", "", null, tr("OS_DESIGN") if job == "design" else tr("OS_CODE")],
			["board", "", null, tr("SCR_BOARD")]]:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(112, 112)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for s in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(s, _rect(Color(1, 1, 1, {"normal": 0.0, "hover": 0.28, "pressed": 0.4}[s]), 12))
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 6)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tile := TextureRect.new()
		tile.texture = ICONS[_icon_of(a[0])]
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile.custom_minimum_size = Vector2(68, 68)
		tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tile)
		var l := _label(a[3], Color("2e3440"), 16)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.7))
		v.add_child(l)
		b.add_child(v)
		b.pressed.connect(_show_app.bind(a[0]))
		col.add_child(b)
	return col

func _icon_of(app_id: String) -> String:
	return "design" if app_id == "code" and job == "design" else app_id

func _window_closed() -> void:
	"""A window's - or x: back to the desktop (screens with no desktop put themselves away)."""
	if _desk_icons:
		_show_app("desk")
	else:
		hide_pressed.emit()

static func _minutes(text: String) -> float:
	var p := text.strip_edges().split(":")
	return float(p[0].to_int() * 60 + p[1].to_int()) if p.size() == 2 else 610.0

func _show_app(name: String) -> void:
	app = name
	_code_app.visible = name == "code"
	_board_app.visible = name == "board"
	if _riu_app:
		_riu_app.visible = name == "riu"
		if name == "riu":
			_riu.shown_now()
	for k in _app_buttons:
		var b: Button = _app_buttons[k]
		var st := _rect(Color(1, 1, 1, 0.16 if k == name else 0.0), 6)
		st.content_margin_left = 12
		st.content_margin_right = 12
		st.border_color = C["accent"]
		st.border_width_bottom = 2 if k == name else 0
		b.add_theme_stylebox_override("normal", st)

func _start_task(i: int) -> void:
	_task = i % TASKS.size()
	var t: Dictionary = TASKS[_task]
	_typed = 0
	_code_text = (t["code"] as String).replace("{C}", "// " + tr(t["comment"]))
	_move_card(t["card"], "SCR_DOING")
	_term_lines.append(["$ ", "dim"])
	_title.text = "%s — engine — Code" % t["file"]
	for c in _tabs.get_children():
		c.queue_free()
	for k in TASKS.size():
		var f: Dictionary = TASKS[(_task + k) % TASKS.size()]
		if k > 2:
			break
		var tab := _panel(C["tab"] if k == 0 else C["tabbar"], Vector2(0, 34))
		var ts := tab.get_theme_stylebox("panel") as StyleBoxFlat
		ts.content_margin_left = 14
		ts.content_margin_right = 14
		ts.border_color = C["accent"]
		ts.border_width_top = 2 if k == 0 else 0
		var l := _label(f["file"], C["fg"] if k == 0 else C["muted"], 15)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tab.add_child(l)
		_tabs.add_child(tab)
	for c in _explorer.get_children():
		c.queue_free()
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_top", 8)
	m.add_child(_label(tr("SCR_EXPLORER"), C["muted"], 13))
	_explorer.add_child(m)
	var tree := [[0, "▾ engine", "dir"], [1, "▾ src", "dir"]]
	for f in TASKS:
		tree.append([2, "▸ " + f["dir"] if f != t else "▾ " + f["dir"], "dir"])
		if f == t:
			tree.append([3, f["file"], "sel"])
			tree.append([3, (f["file"] as String).get_basename() + ".h", "f"])
	tree.append([1, "CMakeLists.txt", "f"])
	for row in tree:
		var line := _panel(C["border"] if row[2] == "sel" else Color(0, 0, 0, 0), Vector2(0, 22))
		(line.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 12 + row[0] * 14
		var col: Color = C["folder"] if row[2] == "dir" else (C["fg"] if row[2] == "sel" else C["side_fg"])
		line.add_child(_label(row[1], col, 15))
		_explorer.add_child(line)
	_render_code()
	_render_term()

func type_keys(n: int) -> void:
	"""The player's key presses: each one writes a few more characters (fewer, and some not at all, as the
	night wears on)."""
	if app != "code" and _desk_icons:
		_show_app("code")
	if fatigue > 0.35 and randf() < (fatigue - 0.35) * 1.3:
		return
	_write(maxi(1, int(round(n * PER_KEY * (1.0 - 0.7 * fatigue)))))

func _tap(e: InputEvent) -> void:
	"""A tap (or a click) on the editor or the canvas types, for screens without a keyboard."""
	if not working:
		return
	if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		type_keys(1)

func set_clock(text: String) -> void:
	clock_text = text
	if _clock:
		_clock.text = text
	var m := _minutes(text)
	if m != minute:
		minute = m
		if _riu:
			_riu.tick()

func notify(text: String) -> void:
	"""A message dropping in (the boss, the team chat, the calendar)."""
	_toast_show(text, Color("f0636b"))

func set_fatigue(f: float) -> void:
	fatigue = clampf(f, 0.0, 1.0)
	_vig.modulate.a = smoothstep(0.0, 0.7, fatigue)
	_dim.color.a = smoothstep(0.55, 1.0, fatigue)
	(_box.material as ShaderMaterial).set_shader_parameter("blur", smoothstep(0.25, 0.9, fatigue))

func _write(n: int) -> void:
	if _design:
		_design.write(n)
		return
	if _pause > 0.0 or n <= 0:
		return
	var before := _typed
	_typed = mini(_code_text.length(), _typed + n)

	while _typed < _code_text.length() and _code_text[_typed] == " " and _code_text[_typed - 1] in [" ", "\n"]:
		_typed += 1
	typed.emit(_typed - before)
	_render_code()
	if _typed >= _code_text.length():
		_finish_task()

func _finish_task() -> void:
	var t: Dictionary = TASKS[_task]
	_pause = 0.4 * (t["term"] as Array).size() + 1.6
	if not _term_lines.is_empty() and _term_lines[-1][0] == "$ ":
		_term_lines.pop_back()
	for k in (t["term"] as Array).size():
		get_tree().create_timer(0.4 * k + 0.2).timeout.connect(func():
			_term_lines.append(t["term"][k])
			_render_term())
	get_tree().create_timer(0.4 * (t["term"] as Array).size() + 0.2).timeout.connect(func():
		_move_card(t["card"], "SCR_DONE")
		_toast_show("✓  " + tr(t["pop"]))
		task_done.emit(tr(t["pop"])))

func _move_card(card: String, to: String) -> void:
	for col in _board:
		(_board[col] as Array).erase(card)
	(_board[to] as Array).push_front(card)
	if _board_cols:
		_fill_board()

func _toast_show(text: String, edge := Color("7fcf8a")) -> void:
	_toast.add_theme_stylebox_override("panel", UiTheme.box(Color("2a2f3a", 0.96), 12, edge, 2, 16))
	_toast_label.text = text
	_toast.reset_size()

	_toast.position = Vector2(76, DESIGN.y - 44 - _toast.size.y - 24) if _design and app == "code" \
		else Vector2((DESIGN.x - _toast.size.x) * 0.5, 50)
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)

func _process(delta: float) -> void:
	_blink += delta
	if _design:
		_design.process(delta)
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			if _design:
				_design.next()
			else:
				_start_task(_task + 1)
	if not working:
		return
	_owed += delta * AUTO_CPS * (1.0 - fatigue)
	if _owed >= 1.0:
		var n := int(_owed)
		_owed -= n
		_write(n)
	elif not _design and (fmod(_blink, 1.1) < 0.65) != _caret_on:
		_render_code()

func _render_code() -> void:
	var t: Dictionary = TASKS[_task]
	var text: String = t["pre"] + _code_text.substr(0, _typed)
	var lines := text.split("\n")
	var first := maxi(0, lines.size() - CODE_LINES)
	var out := ""
	for i in range(first, lines.size()):
		out += "[color=#%s]%3d[/color]   " % [C["gutter"].to_html(false), i + 1]
		out += _highlight(lines[i])
		_caret_on = fmod(_blink, 1.1) < 0.65
		if i == lines.size() - 1 and _caret_on:
			out += "[bgcolor=#%s] [/bgcolor]" % C["accent"].to_html(false)
		out += "\n"
	_code_view.text = out
	var last: String = lines[lines.size() - 1]
	_status_pos.text = tr("SCR_LNCOL").format({"l": lines.size(), "c": last.length() + 1})

func _render_term() -> void:
	var out := ""
	_term_lines = _term_lines.slice(-4)
	for l in _term_lines:
		out += "[color=#%s]%s[/color]\n" % [C[l[1]].to_html(false), (l[0] as String).replace("[", "[lb]")]
	_term_view.text = out

static var _tok: RegEx

func _highlight(line: String) -> String:
	"""One line of C++ in the editor's colours (the same rules as make_screens.py)."""
	if _tok == null:
		_tok = RegEx.create_from_string("//.*|#\\w+|\"[^\"]*\"?|\\b\\d+\\.?\\d*[uf]?\\b|[A-Za-z_]\\w*|\\s+|.")
	var ms := _tok.search_all(line)
	var out := ""
	for i in ms.size():
		var s := ms[i].get_string()
		var col := ""
		if s.begins_with("//"):
			col = "comment"
		elif s.begins_with("#"):
			col = "keyword"
		elif s.begins_with("\""):
			col = "string"
		elif s[0] >= "0" and s[0] <= "9":
			col = "number"
		elif s[0] == "_" or s[0].to_lower() != s[0].to_upper():
			if s in KW:
				col = "keyword"
			elif i + 1 < ms.size() and ms[i + 1].get_string() == "(":
				col = "func"
			elif s[0] == s[0].to_upper() and s[0] != "_":
				col = "type"
			else:
				col = "ident"
		elif s.strip_edges() != "":
			col = "punct"
		var esc := s.replace("[", "[lb]")
		out += esc if col == "" else "[color=#%s]%s[/color]" % [C[col].to_html(false), esc]
	return out
