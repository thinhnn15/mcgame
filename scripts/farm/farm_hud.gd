class_name FarmHud
extends CanvasLayer

signal tool_tapped(i: int)
signal shop_tapped(i: int)
signal shop_closed()

const INK := Color("5b4a44")
const PAPER := Color("fff6e6")
const PICK := Color("ffd98a")
const SLOT := 96.0
const WATER := Color("62a8e2")
const GAP := 12.0
const BAR_W := 6 * SLOT + 5 * GAP
const UI := "res://ui/icons/ui/"
const CELL := 160
const PAD := 4

var _clock: Label
var _bag: Label
var _bar: Control
var _slots := []
static var _packed: ImageTexture
static var _cells := {}
static var _cell_paths: Array = []
var _pick := -1
var _picked_name := ""
var _keys := true
var _tag: PanelContainer
var _tag_text: Label
var _tag_tw: Tween
var _toast: Label
var _toast_tw: Tween
var _hint: Label
var _black: ColorRect
var _shop: PanelContainer
var _shop_text: Label
var _shop_done: PanelContainer
var _shop_n := 0
var _skills: VBoxContainer
var _skill_rows := {}

func _ready() -> void:
	_clock = _label(26)
	_panel(_clock, Vector2(20, 16))
	_skills = VBoxContainer.new()
	_skills.add_theme_constant_override("separation", 4)
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", _style(Color(PAPER, 0.85), 2))
	sp.position = Vector2(20, 74)
	sp.add_child(_skills)
	add_child(sp)
	_bag = _label(20)
	var bp := _panel(_bag, Vector2(0, 16))
	bp.anchor_left = 1.0
	bp.anchor_right = 1.0
	bp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bp.offset_left = -20
	bp.offset_right = -20
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(BAR_W, SLOT + 24)
	_bar.size = _bar.custom_minimum_size
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = -BAR_W / 2
	_bar.offset_right = BAR_W / 2
	_bar.offset_top = -54 - SLOT - 24
	_bar.offset_bottom = -54
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.gui_input.connect(_bar_input)
	TouchControls.claim(_bar)
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	for i in 6:
		_slots.append({"icon": null, "count": -1, "badge": null, "water": Vector2i.ZERO, "dim": false, "lift": 0.0})
	_tag_text = _label(19)
	_tag = PanelContainer.new()
	var ts := _style(Color(PAPER, 0.95), 2)
	ts.content_margin_top = 4
	ts.content_margin_bottom = 4
	_tag.add_theme_stylebox_override("panel", ts)
	_tag.add_child(_tag_text)
	_tag.visible = false
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_pack(["slot", "slot_pick", "chip", "key", "drop", "drop_empty"].map(func(n: String) -> String: return UI + n + ".svg"))
	add_child(_tag)
	_keys = not OS.has_feature("mobile")
	_hint = _label(16)
	_hint.modulate.a = 0.75
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.offset_top = -40
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_toast = _label(24)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 0.68
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", PAPER)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.modulate.a = 0.0
	add_child(_toast)
	_black = ColorRect.new()
	_black.color = Color(0.08, 0.07, 0.10, 0.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)

func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	return l

func _style(fill: Color, border: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(14)
	s.set_border_width_all(border)
	s.border_color = Color("e3cfae")
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _panel(l: Label, at: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(PAPER, 0.92), 2))
	p.position = at
	p.add_child(l)
	add_child(p)
	return p

func set_clock(day: int, minutes: float) -> void:
	var m := int(minutes) % (24 * 60)
	_clock.text = "%s   %02d:%02d" % [tr("FARM_DAY") % day, m / 60, (m % 60) / 10 * 10]

func set_bag(bag: Dictionary) -> void:
	var parts := []
	for k in bag:
		if bag[k] > 0:
			parts.append("%s × %d" % [tr(k), bag[k]])
	_bag.text = "\n".join(parts) if parts else tr("FARM_BAG_EMPTY")

func set_tools(rows: Array, pick: int) -> void:
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var r: Dictionary = rows[i]
		s.icon = r.get("icon")
		s.count = int(r.get("count", -1))
		s.badge = r.get("badge")
		s.water = r.get("water", Vector2i.ZERO)
		s.dim = r.get("dim", false)
		if i == pick and (pick != _pick or r.get("name", "") != _picked_name):
			_lift(i, 1.0)
			_say(str(r.get("name", "")), i)
			_picked_name = r.get("name", "")
		elif i != pick and i == _pick:
			_lift(i, 0.0)
	_pick = pick
	_bar.queue_redraw()

func _bar_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var i := int(floor(mb.position.x / (SLOT + GAP)))
	if i >= 0 and i < _slots.size() and mb.position.x - i * (SLOT + GAP) <= SLOT and mb.position.y >= 24:
		tool_tapped.emit(i)
		_bar.accept_event()

func _draw_bar() -> void:
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var lift: float = s.lift
		var k := 1.0 + 0.08 * lift
		var r := Rect2(Vector2(SLOT / 2 + i * (SLOT + GAP), 24 + SLOT / 2 - 6 * lift) - Vector2(SLOT, SLOT) * k / 2,
			Vector2(SLOT, SLOT) * k)
		_part(UI + ("slot_pick" if i == _pick else "slot") + ".svg", r)
		if s.icon:
			_part(s.icon.resource_path, Rect2(r.position + Vector2(8, 6) * k, Vector2(80, 80) * k),
				Color(1, 1, 1, 0.45) if s.dim else Color.WHITE)
		if s.badge:
			_part(UI + "chip.svg", Rect2(r.end - Vector2(46, 48), Vector2(44, 44)))
			_part(s.badge.resource_path, Rect2(r.end - Vector2(43, 45), Vector2(38, 38)))
		var w: Vector2i = s.water
		if w.y > 0 and w.y <= 5:
			var x0 := r.get_center().x - 15.0 * (w.y - 1) / 2
			for d in w.y:
				_part(UI + ("drop" if d < w.x else "drop_empty") + ".svg", Rect2(Vector2(x0 + d * 15.0 - 6, r.end.y - 16), Vector2(12, 12)))
		if _keys:
			_part(UI + "key.svg", Rect2(r.position - Vector2(7, 7), Vector2(26, 26)))
	var font := _bar.get_theme_default_font()
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var lift: float = s.lift
		var k := 1.0 + 0.08 * lift
		var r := Rect2(Vector2(SLOT / 2 + i * (SLOT + GAP), 24 + SLOT / 2 - 6 * lift) - Vector2(SLOT, SLOT) * k / 2,
			Vector2(SLOT, SLOT) * k)
		var w: Vector2i = s.water
		if w.y > 5:
			var b := Rect2(r.position + Vector2(14, r.size.y - 15), Vector2(r.size.x - 28, 11))
			_bar.draw_rect(b, Color("fffaf0"))
			_bar.draw_rect(Rect2(b.position, Vector2(b.size.x * w.x / w.y, b.size.y)), WATER)
			_bar.draw_rect(b, Color("3c78b4"), false, 1.5)
		if _keys:
			_bar.draw_string(font, r.position + Vector2(-7, 12), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 26, 16, PAPER)
		if s.count >= 0:
			var at := r.position + Vector2(8, r.size.y - 10)
			_bar.draw_string_outline(font, at, str(s.count), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 7, Color("4b3a32"))
			_bar.draw_string(font, at, str(s.count), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

func _part(path: String, at: Rect2, tint := Color.WHITE) -> void:
	if not _cells.has(path):
		_pack([path])
	if _cells.has(path):
		_bar.draw_texture_rect_region(_packed, at, _cells[path], tint)

static func _pack(more: Array) -> void:
	for p in more:
		if p not in _cell_paths and ResourceLoader.exists(p):
			_cell_paths.append(p)
	var cols := 6
	var stride := CELL + 2 * PAD
	var img := Image.create(cols * stride, ceili(_cell_paths.size() / float(cols)) * stride, false, Image.FORMAT_RGBA8)
	_cells.clear()
	for n in _cell_paths.size():
		var src := (load(_cell_paths[n]) as Texture2D).get_image()
		if src.is_compressed():
			src.decompress()
		src.clear_mipmaps()
		src.convert(Image.FORMAT_RGBA8)
		src.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
		var at := Vector2i(n % cols, n / cols) * stride + Vector2i(PAD, PAD)
		img.blit_rect(src, Rect2i(0, 0, CELL, CELL), at)
		_cells[_cell_paths[n]] = Rect2(at, Vector2(CELL, CELL))
	img.generate_mipmaps()
	_packed = ImageTexture.create_from_image(img)

func _lift(i: int, to: float) -> void:
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_method(
		_set_lift.bind(i), float(_slots[i].lift), to, 0.12)

func _set_lift(v: float, i: int) -> void:
	_slots[i].lift = v
	_bar.queue_redraw()

func _say(text: String, i: int) -> void:
	if text == "":
		return
	_tag_text.text = text
	if _tag_tw:
		_tag_tw.kill()
	_tag.visible = true
	_tag.modulate.a = 1.0
	_place_tag.call_deferred(i)
	_tag_tw = create_tween()
	_tag_tw.tween_interval(1.5)
	_tag_tw.tween_property(_tag, "modulate:a", 0.0, 0.3)
	_tag_tw.tween_callback(_tag.hide)

func _place_tag(i: int) -> void:
	_tag.reset_size()
	var x := _bar.global_position.x + SLOT / 2 + i * (SLOT + GAP)
	_tag.position = Vector2(x - _tag.size.x / 2, _bar.global_position.y + 24 - _tag.size.y - 16)

func _input(e: InputEvent) -> void:
	var keys := _keys
	if e is InputEventKey:
		keys = true
	elif e is InputEventJoypadButton or e is InputEventScreenTouch \
			or (e is InputEventJoypadMotion and absf((e as InputEventJoypadMotion).axis_value) > 0.4):
		keys = false
	if keys != _keys:
		_keys = keys
		_bar.queue_redraw()

func shop(title: String, rows: Array, pick: int, hint: String) -> void:
	if _shop == null:
		_shop_text = _label(20)
		_shop = PanelContainer.new()
		_shop.add_theme_stylebox_override("panel", _style(Color(PAPER, 0.96), 3))
		_shop.anchor_left = 0.5
		_shop.anchor_right = 0.5
		_shop.anchor_top = 0.3
		_shop.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_shop.mouse_filter = Control.MOUSE_FILTER_STOP
		_shop.gui_input.connect(_shop_tap)
		TouchControls.claim(_shop)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		box.add_child(_shop_text)
		_shop_done = PanelContainer.new()
		_shop_done.add_theme_stylebox_override("panel", _style(PICK, 2))
		_shop_done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_shop_done.mouse_filter = Control.MOUSE_FILTER_STOP
		_shop_done.gui_input.connect(func(e: InputEvent) -> void:
			var mb := e as InputEventMouseButton
			if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				shop_closed.emit()
				_shop_done.accept_event())
		var done := _label(20)
		done.text = tr("FARM_SHOP_CLOSE")
		done.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shop_done.add_child(done)
		box.add_child(_shop_done)
		_shop.add_child(box)
		add_child(_shop)
	_shop_n = rows.size()
	var lines := [title, ""]
	for i in rows.size():
		lines.append(("▶ " if i == pick else "    ") + str(rows[i]))
	lines += ["", hint]
	_shop_text.text = "
".join(lines)
	_shop_done.visible = TouchControls.active
	_shop.visible = true

func _shop_tap(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or _shop_n <= 0:
		return
	var y: float = _shop.global_position.y + mb.position.y - _shop_text.global_position.y
	var row := int(floor(y / maxf(_shop_text.get_line_height(), 1.0))) - 2
	if row >= 0 and row < _shop_n:
		shop_tapped.emit(row)
	_shop.accept_event()

func close_shop() -> void:
	if _shop:
		_shop.visible = false

func set_skills(rows: Array) -> void:
	for r in rows:
		var name: String = r[0]
		if not _skill_rows.has(name):
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 10)
			var l := _label(16)
			l.custom_minimum_size = Vector2(132, 0)
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(96, 9)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.max_value = 1.0
			var bg := StyleBoxFlat.new()
			bg.bg_color = Color("ead9bb")
			bg.set_corner_radius_all(5)
			var fg := StyleBoxFlat.new()
			fg.bg_color = Color("9cc46a")
			fg.set_corner_radius_all(5)
			bar.add_theme_stylebox_override("background", bg)
			bar.add_theme_stylebox_override("fill", fg)
			hb.add_child(l)
			hb.add_child(bar)
			_skills.add_child(hb)
			_skill_rows[name] = [l, bar]
		(_skill_rows[name][0] as Label).text = "%s  %d" % [name, int(r[1])]
		(_skill_rows[name][1] as ProgressBar).value = float(r[2])

func set_hint(text: String) -> void:
	_hint.text = text

func toast(text: String, secs := 2.2) -> void:
	_toast.text = text
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.18)
	_toast_tw.tween_interval(secs)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.5)

func fade(to: float, secs: float) -> void:
	await create_tween().tween_property(_black, "color:a", to, secs).finished
