class_name CallHud
extends Control

signal answer_pressed
signal later_pressed
signal hide_toggled(id: String)

const CREAM := Color(1, 0.98, 0.95, 0.95)
const INK := Color("5b4a44")
const MUTE := Color("9a8a84")
const LINE_MIN := 2.2
const LINE_PER_CHAR := 0.05
const LINE_MAX := 6.5

var auto := false
var _card: PanelContainer
var _avatar: Avatar
var _name: Label
var _sub: Label
var _buttons: HBoxContainer
var _subtitle: PanelContainer
var _text: RichTextLabel
var _chips: VBoxContainer
var _toast: Label
var _toast_t := 0.0
var _contacts: PanelContainer
var _list: VBoxContainer
var _skip := false
var _picked := -1
var _choosing := 0

class Avatar:
	extends Control
	var color := Color("e08a8a")
	var letter := ""
	var face: Texture2D
	var ringing := false
	var _t := 0.0

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _process(delta: float) -> void:
		if ringing:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		if ringing:
			var f := fmod(_t * 1.6, 1.0)
			draw_circle(c, r * (1.0 + f * 0.35), Color(color, 0.35 * (1.0 - f)))
		if face != null:
			draw_circle(c, r, color.lerp(Color.WHITE, 0.6))
			draw_texture_rect(face, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
			draw_arc(c, r - 1.5, 0.0, TAU, 48, color, 3.0, true)
			return
		draw_circle(c, r, color)
		var font := get_theme_default_font()
		var fs := int(r * 1.05)
		var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(c.x - w * 0.5, c.y + fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(1, 1, 1, 0.97))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_card()
	_build_subtitle()
	_build_contacts()
	_toast = _label(24, INK)
	_toast.position = Vector2(28, 200)
	_toast.add_theme_color_override("font_outline_color", Color("fffaf2"))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.visible = false
	add_child(_toast)

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)
		if _toast_t <= 0.0:
			_toast.visible = false

func _input(e: InputEvent) -> void:
	"""While the chips are up the number keys are theirs (not the tools')."""
	if _choosing == 0 or not (e is InputEventKey and e.pressed and not e.echo):
		return
	var i: int = e.physical_keycode - KEY_1
	if i >= 0 and i < _choosing:
		_picked = i
		get_viewport().set_input_as_handled()

func show_ring(who: String, color: Color, face: Texture2D = null) -> void:
	_avatar.color = color
	_avatar.letter = who.substr(0, 1)
	_avatar.face = face
	_avatar.ringing = true
	_avatar.queue_redraw()
	_name.text = who
	_sub.text = tr("PHONE_INCOMING")
	_buttons.visible = true
	_card.visible = true

func show_call() -> void:
	_avatar.ringing = false
	_avatar.queue_redraw()
	_buttons.visible = false
	set_timer(0.0)

func set_timer(secs: float) -> void:
	_sub.text = "%02d:%02d" % [int(secs / 60.0), int(fmod(secs, 60.0))]

func hide_call() -> void:
	_card.visible = false
	_subtitle.visible = false
	_clear_chips()

func toast(text: String, secs := 3.5) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_t = secs

func line(who: String, color: Color, text: String) -> void:
	"""A subtitle: who (in their colour) and the line, as long as it takes to read (T skips on)."""
	_text.text = ("[color=#%s]%s[/color]   %s" % [color.to_html(false), who, text]) if who != "" else "[i]%s[/i]" % text
	_subtitle.visible = true
	_skip = false
	var secs := clampf(LINE_MIN * 0.6 + text.length() * LINE_PER_CHAR, LINE_MIN, LINE_MAX)
	if auto:
		secs = minf(secs, 1.6)
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < end and not _skip and is_inside_tree():
		await get_tree().process_frame

func skip() -> void:
	_skip = true

func choose(texts: Array, default_i: int, secs: float) -> int:
	"""The hero's answers as chips over the subtitle; the picked one's index (default_i if none in secs)."""
	_clear_chips()
	for i in texts.size():
		var b := Button.new()
		b.text = "%d   %s" % [i + 1, texts[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", INK)
		b.add_theme_stylebox_override("normal", UiTheme.box(CREAM, 22, UiTheme.PINK, 3, 18))
		b.add_theme_stylebox_override("hover", UiTheme.box(Color("fff1f4"), 22, UiTheme.PINK_DARK, 3, 18))
		b.add_theme_stylebox_override("pressed", UiTheme.box(Color("ffe3ea"), 22, UiTheme.PINK_DARK, 3, 18))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.custom_minimum_size = Vector2(0, 64)
		b.pressed.connect(func() -> void: _picked = i)
		_chips.add_child(b)
	_chips.visible = true
	_choosing = texts.size()
	_picked = -1
	var end := Time.get_ticks_msec() + int((1.4 if auto else secs) * 1000.0)
	while _picked < 0 and Time.get_ticks_msec() < end and is_inside_tree():
		await get_tree().process_frame
	var got := _picked if _picked >= 0 else default_i
	_clear_chips()
	return got

func _clear_chips() -> void:
	_choosing = 0
	_chips.visible = false
	for c in _chips.get_children():
		c.queue_free()

func contacts_open() -> bool:
	return _contacts.visible

func show_contacts(rows: Array) -> void:
	"""rows: [{id, name, rel, color, note, missed, hideable, hidden, none}] in the book's order."""
	for c in _list.get_children():
		c.queue_free()
	for r in rows:
		_list.add_child(_row(r))
	_contacts.visible = true

func hide_contacts() -> void:
	_contacts.visible = false

func _row(r: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.75), 16, Color(0, 0, 0, 0), 0, 12))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)
	var av := Avatar.new()
	av.custom_minimum_size = Vector2(58, 58)
	av.color = Color(str(r["color"]))
	av.letter = str(r["name"]).substr(0, 1)
	av.face = r.get("face")
	if r.get("none", false) or r.get("hidden", false):
		av.modulate = Color(1, 1, 1, 0.5)
	h.add_child(av)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var n := _label(26, INK)
	n.text = str(r["name"])
	v.add_child(n)
	var sub := _label(19, MUTE)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if r.get("none", false):
		sub.text = str(r.get("note", ""))
	elif r.get("hidden", false):
		sub.text = tr("PHONE_HIDDEN")
	elif int(r.get("missed", 0)) > 0:
		sub.text = Lang.t("PHONE_MISSED_N", {"n": r["missed"]})
		sub.add_theme_color_override("font_color", UiTheme.PINK_DARK)
	else:
		sub.text = str(r["rel"])
	v.add_child(sub)
	if r.get("hideable", false):
		var b := Button.new()
		b.text = tr("PHONE_SHOW") if r.get("hidden", false) else tr("PHONE_HIDE")
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", INK)
		b.add_theme_stylebox_override("normal", UiTheme.box(Color("f3ece6"), 14, Color(0, 0, 0, 0), 0, 10))
		b.add_theme_stylebox_override("hover", UiTheme.box(Color("ebe1d9"), 14, Color(0, 0, 0, 0), 0, 10))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var id := str(r["id"])
		b.pressed.connect(func() -> void: hide_toggled.emit(id))
		h.add_child(b)
	return row

func _label(size_: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String, bg: Color, border: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_stylebox_override("normal", UiTheme.box(bg, 18, border, 3, 14))
	b.add_theme_stylebox_override("hover", UiTheme.box(bg.lightened(0.25), 18, border, 3, 14))
	b.add_theme_stylebox_override("pressed", UiTheme.box(bg.darkened(0.05), 18, border, 3, 14))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(128, 56)
	return b

func _build_card() -> void:
	_card = PanelContainer.new()
	_card.position = Vector2(24, 76)
	_card.add_theme_stylebox_override("panel", UiTheme.box(CREAM, 26, UiTheme.PINK, 3, 16))
	_card.visible = false
	add_child(_card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	_card.add_child(h)
	_avatar = Avatar.new()
	_avatar.custom_minimum_size = Vector2(76, 76)
	h.add_child(_avatar)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.custom_minimum_size = Vector2(150, 0)
	h.add_child(v)
	_name = _label(30, INK)
	v.add_child(_name)
	_sub = _label(20, MUTE)
	v.add_child(_sub)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	_buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_buttons)
	var yes := _button(tr("PHONE_ANSWER") + "  (T)", UiTheme.MINT, Color("8fd6bd"))
	yes.pressed.connect(answer_pressed.emit)
	_buttons.add_child(yes)
	var no := _button(tr("PHONE_LATER") + "  (X)", Color("fde3ea"), UiTheme.PINK)
	no.pressed.connect(later_pressed.emit)
	_buttons.add_child(no)

func _build_subtitle() -> void:
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = -480
	bottom.offset_right = 480
	bottom.offset_bottom = -150
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 12)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	_chips = VBoxContainer.new()
	_chips.add_theme_constant_override("separation", 10)
	_chips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_chips.custom_minimum_size = Vector2(620, 0)
	_chips.visible = false
	bottom.add_child(_chips)
	_subtitle = PanelContainer.new()
	_subtitle.add_theme_stylebox_override("panel", UiTheme.box(Color(0.2, 0.16, 0.17, 0.72), 22, Color(0, 0, 0, 0), 0, 22))
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.visible = false
	bottom.add_child(_subtitle)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("normal_font_size", 30)
	_text.add_theme_color_override("default_color", Color("fffaf2"))
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.add_child(_text)

func _build_contacts() -> void:
	_contacts = PanelContainer.new()
	_contacts.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_contacts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_contacts.grow_vertical = Control.GROW_DIRECTION_BOTH
	_contacts.offset_left = -470
	_contacts.offset_right = -40
	_contacts.offset_top = -230
	_contacts.offset_bottom = 460
	_contacts.add_theme_stylebox_override("panel", UiTheme.box(Color("15171d"), 46, Color(0, 0, 0, 0), 0, 14))
	_contacts.visible = false
	add_child(_contacts)
	var glass := PanelContainer.new()
	glass.add_theme_stylebox_override("panel", UiTheme.box(Color("f6f1ec"), 36, Color(0, 0, 0, 0), 0, 18))
	_contacts.add_child(glass)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	glass.add_child(v)
	var title := _label(34, INK)
	title.text = tr("PHONE_CONTACTS")
	v.add_child(title)
	var hint := _label(18, MUTE)
	hint.text = tr("PHONE_CONTACTS_HINT")
	v.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
