class_name EmoteWheel
extends Control

signal picked(kind: String)

const RADIUS := 372.0
const BTN := Vector2(150, 132)
var _keys: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.25, 0.2, 0.25, 0.25)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var title := Label.new()
	title.text = tr("TAB_REACTIONS")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("5b4a44"))
	title.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.98, 0.95, 0.95), 24, Color("f6dccf"), 3, 18))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(180, 64)
	title.set_meta("off", Vector2(-90, -32))
	add_child(title)
	_keys = Chibi.load_emotes().keys()
	var n := _keys.size()

	var outer := n if n <= 16 else int(ceil(n * 0.56))
	for i in n:
		var k: String = _keys[i]
		var b := emote_button(k, Chibi.emotes[k], i)
		var ring := 0 if i < outer else 1
		var count := outer if ring == 0 else n - outer
		var j := i if ring == 0 else i - outer
		var a := -PI / 2 + TAU * (j + 0.5 * ring) / count
		var r := RADIUS * (1.0 if n <= 16 else (1.12 if ring == 0 else 0.62))
		b.set_meta("off", Vector2(cos(a) * r * 1.5, sin(a) * r) - b.size / 2)
		b.pressed.connect(func(): _pick(k))
		add_child(b)
	_layout.call_deferred()

static func emote_button(_kind: String, e: Dictionary, i := -1) -> Button:
	var b := Button.new()
	var small := Chibi.emotes.size() > 16
	b.custom_minimum_size = BTN * (0.82 if small else 1.0)
	b.size = b.custom_minimum_size
	b.text = (("%d. " % (i + 1)) if i >= 0 and i < 9 else "") + TranslationServer.translate("EMOTE_" + _kind.to_upper())
	b.icon = load("res://characters/fx/%s.png" % e.get("icon", "sparkle"))
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_constant_override("icon_max_width", 64)
	b.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.98, 0.95, 0.95), 22, Color("f6dccf"), 3, 8))
	b.add_theme_stylebox_override("hover", UiTheme.box(Color(1, 0.95, 0.9, 1.0), 22, UiTheme.PINK, 4, 8))
	b.add_theme_stylebox_override("pressed", UiTheme.box(Color(1, 0.92, 0.88, 1.0), 22, UiTheme.PINK_DARK, 5, 8))
	b.add_theme_color_override("font_color", Color("5b4a44"))
	return b

func toggle() -> void:
	visible = not visible
	_layout()

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vs
	for c in get_children():
		if c.has_meta("off"):
			c.position = vs / 2 + c.get_meta("off")
		elif c is ColorRect:
			c.size = vs

func _pick(k: String) -> void:
	visible = false
	picked.emit(k)

func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_ESCAPE:
			visible = false
			get_viewport().set_input_as_handled()
		elif e.physical_keycode >= KEY_1 and e.physical_keycode <= KEY_9:
			var i: int = e.physical_keycode - KEY_1
			if i < _keys.size():
				_pick(_keys[i])
				get_viewport().set_input_as_handled()
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		visible = false
