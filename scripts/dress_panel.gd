class_name DressPanel
extends Control

signal closed()

const SHEET := 0.46
const TILE := Vector2(132, 160)
const DOT := 72.0
const OPEN_DEAF := 300

static func categories() -> Array:
	"""[title key, [[row label, kind, look key, options], ...]] - the parts a player may change in game."""
	var socks: Array = Looks.shapes("socks").filter(func(n: String) -> bool: return not n.ends_with("_in"))
	return [
		["TAB_HAIR", [["ROW_HAIR_STYLE", "shape", "hair", Looks.shapes("hair")],
			["ROW_HAIR_COLOR", "color", "hair_color", Looks.HAIR_COLORS]]],
		["TAB_TOP", [["ROW_STYLE", "shape", "top.shape", Looks.shapes("tops")],
			["ROW_DESIGN", "shape", "top.design", Looks.TOP_DESIGNS],
			["ROW_COLOR_MAIN", "color", "top.color", Looks.CLOTH_COLORS],
			["ROW_PATTERN", "shape", "top.pattern", Looks.PATTERNS],
			["ROW_COLOR_SECOND", "color", "top.color_b", Looks.CLOTH_COLORS]]],
		["TAB_BOTTOM", [["ROW_STYLE", "shape", "bottom.shape", ["none"] + Looks.shapes("bottoms")],
			["ROW_DESIGN", "shape", "bottom.design", Looks.BOTTOM_DESIGNS],
			["ROW_COLOR_MAIN", "color", "bottom.color", Looks.CLOTH_COLORS],
			["ROW_PATTERN", "shape", "bottom.pattern", Looks.PATTERNS],
			["ROW_COLOR_SECOND", "color", "bottom.color_b", Looks.CLOTH_COLORS]]],
		["TAB_SHOES", [["ROW_STYLE", "shape", "shoes.shape", Looks.shapes("shoes")],
			["ROW_COLOR_MAIN", "color", "shoes.color", Looks.CLOTH_COLORS],
			["ROW_TRIM", "color", "shoes.trim", Looks.CLOTH_COLORS],
			["ROW_SOCKS", "shape", "socks.shape", ["none"] + socks]]],
		["TAB_HAT", [["ROW_STYLE", "shape", "hat.shape", ["none"] + Looks.shapes("hats")],
			["ROW_COLOR_MAIN", "color", "hat.color", Looks.CLOTH_COLORS],
			["ROW_TRIM", "color", "hat.trim", Looks.CLOTH_COLORS]]],
		["TAB_ACC", [["ROW_STYLE", "shape", "acc.shape", ["none"] + Looks.shapes("accessories")],
			["ROW_COLOR_MAIN", "color", "acc.color", Looks.CLOTH_COLORS + ["#e8434d", "#ffd36e"]],
			["ROW_COLOR_SECOND", "color", "acc.trim", Looks.CLOTH_COLORS + ["#58a85a", "#ffb84d"]]]],
		["TAB_FACE", [["ROW_EYE_STYLE", "shape", "eye_style", Looks.EYE_STYLES],
			["ROW_EYE_COLOR", "color", "eye_color", Looks.EYE_COLORS],
			["ROW_SKIN", "color", "skin", Looks.SKINS]]],
	]

var look: Dictionary
var _chibi: Chibi
var _thumbs: LookThumbs
var _body: VBoxContainer
var _cat := 0
var _cat_buttons: Array = []
var _tiles: Array = []
var _options: Array = []
var _opened_at := 0
var _cats: Array = []

func setup(chibi: Chibi) -> void:
	"""Before the panel is added to the tree: _ready builds the tiles from this look."""
	_chibi = chibi
	look = Looks.load_saved()
	_opened_at = Time.get_ticks_msec()

func open(chibi: Chibi) -> void:
	"""Opened again, in this scene (the hero is a new one after a scene change)."""
	_chibi = chibi
	look = Looks.load_saved()
	_opened_at = Time.get_ticks_msec()
	show()
	if _body != null:
		_fit()
		_show_cat(_cat)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.make()
	TouchControls.claim(self)
	_cats = categories()
	_thumbs = LookThumbs.new()
	add_child(_thumbs)
	var dim := ColorRect.new()
	dim.color = Color(0.25, 0.2, 0.25, 0.2)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var sheet := PanelContainer.new()
	sheet.anchor_left = 1.0 - SHEET
	sheet.anchor_right = 1.0
	sheet.anchor_bottom = 1.0
	sheet.offset_left = 20
	sheet.offset_right = -20
	sheet.offset_top = 20
	sheet.offset_bottom = -20
	add_child(sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	sheet.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var title := Label.new()
	title.text = tr("TC_DRESS")
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var done := Button.new()
	done.text = tr("TC_DONE")
	done.custom_minimum_size = Vector2(150, 64)
	done.add_theme_font_size_override("font_size", 26)
	done.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PINK_DARK, 18))
	done.add_theme_color_override("font_color", Color.WHITE)
	done.pressed.connect(close)
	head.add_child(done)

	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	col.add_child(tabs)
	for i in _cats.size():
		var b := Button.new()
		b.text = tr(_cats[i][0])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 56)
		var at := i
		b.pressed.connect(func() -> void: _show_cat(at))
		tabs.add_child(b)
		_cat_buttons.append(b)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_show_cat(0)

func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size

func _process(_delta: float) -> void:
	if visible:
		_fit()

func _show_cat(i: int) -> void:
	_cat = i
	for b in _cat_buttons.size():
		var on := b == i
		_cat_buttons[b].add_theme_stylebox_override("normal",
			UiTheme.box(UiTheme.PINK if on else Color.WHITE, 16, UiTheme.PINK_DARK if on else Color("f3d9d0"), 2))
	_tiles.clear()
	_options.clear()
	for c in _body.get_children():
		c.queue_free()
	for row in _cats[i][1]:
		var lab := Label.new()
		lab.text = tr(row[0])
		lab.add_theme_font_size_override("font_size", 24)
		_body.add_child(lab)
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		_body.add_child(grid)
		for opt in row[3]:
			grid.add_child(_option(str(row[1]), str(row[2]), opt))
	_mark_worn()
	_refresh_thumbs()

func _mark_worn() -> void:
	for o in _options:
		var b: Button = o["button"]
		if not is_instance_valid(b):
			continue
		var on: bool = str(_worn(str(o["key"]))) == str(o["value"])
		if o["kind"] == "color":
			b.add_theme_stylebox_override("normal", UiTheme.box(Color(o["value"]), int(DOT / 2),
				UiTheme.PINK_DARK if on else Color("ffffff"), 6 if on else 4))
		else:
			b.add_theme_stylebox_override("normal", UiTheme.box(Color("fff0f3") if on else Color.WHITE, 16,
				UiTheme.PINK_DARK if on else Color("f3d9d0"), 4 if on else 2))

func _worn(key: String):
	var path := key.split(".")
	if path.size() == 2:
		return (look.get(path[0], {}) as Dictionary).get(path[1], "")
	return look.get(key, "")

func _option(kind: String, key: String, value) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: _pick(key, value))
	_options.append({"button": b, "key": key, "value": value, "kind": kind})
	if kind == "color":
		b.custom_minimum_size = Vector2(DOT, DOT)
		b.add_theme_stylebox_override("normal", UiTheme.box(Color(value), int(DOT / 2), Color("ffffff"), 4))
		b.add_theme_stylebox_override("pressed", UiTheme.box(Color(value), int(DOT / 2), UiTheme.PINK_DARK, 6))
		return b
	b.text = Looks.option_name(str(value))
	b.custom_minimum_size = TILE
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_constant_override("icon_max_width", 112)
	b.clip_text = true
	_tiles.append({"button": b, "key": key, "value": value, "frame": _frame_for(key)})
	return b

func _frame_for(key: String) -> String:
	if key in ["hair", "eye_style"] or key.begins_with("hat.") or key.begins_with("acc."):
		return "head"
	return "feet" if key.begins_with("shoes.") or key.begins_with("socks.") else "body"

func _pick(key: String, value) -> void:

	if Time.get_ticks_msec() - _opened_at < OPEN_DEAF:
		return
	look = Looks.with_value(look, key, value)
	if _chibi != null and is_instance_valid(_chibi):
		_chibi.apply_look(look)
	_mark_worn()
	_refresh_thumbs()

func _refresh_thumbs() -> void:
	_thumbs.clear()
	for t in _tiles:
		var b: Button = t["button"]
		_thumbs.request(Looks.with_value(look, t["key"], t["value"]), t["frame"], func(tex: Texture2D) -> void:
			if is_instance_valid(b):
				b.icon = tex)

func close() -> void:
	Looks.save(look)
	Net.set_look(look)
	hide()
	closed.emit()

func _unhandled_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo \
			and (e as InputEventKey).physical_keycode in [KEY_ESCAPE, KEY_Q]:
		close()
		get_viewport().set_input_as_handled()
