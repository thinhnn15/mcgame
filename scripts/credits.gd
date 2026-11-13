class_name Credits
extends Control

const DATA := "res://data/credits.json"
const AUDIO := "res://data/audio/credits.json"
const LOGO := preload("res://brand/mcstudio_logo.png")
const SPEED := 70.0
const FAST := 5.0
const END_HOLD := 4.0
const HEAD := Color("e0849c")

static var then := "res://scenes/title.tscn"

var roll: VBoxContainer
var last: Control
var licenses: PanelContainer
var held := false
var ended := 0.0
var _gone := false

func _ready() -> void:
	theme = UiTheme.make()
	var bg := ColorRect.new()
	bg.color = UiTheme.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var data: Dictionary = d if d is Dictionary else {}
	_build_roll(data)
	_build_corner()
	licenses = _build_licenses(data)
	if OS.get_cmdline_user_args().has("--licenses"):
		_show_licenses(true)

func _build_roll(data: Dictionary) -> void:
	roll = VBoxContainer.new()
	roll.alignment = BoxContainer.ALIGNMENT_BEGIN
	roll.add_theme_constant_override("separation", 6)
	roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(roll)
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(520, 520.0 * LOGO.get_height() / LOGO.get_width())
	roll.add_child(logo)
	_gap(30)
	_line(tr("CR_A_GAME_BY"), 26, HEAD)
	_line(str(data.get("studio", "")), 44)
	_gap(40)
	_line(tr("GAME_TITLE"), 96, Color("f08aa6"), Color.WHITE, 14)
	_gap(120)
	for role in data.get("roles", []):
		_line(tr(role[0]), 26, HEAD)
		for who in role[1]:
			_line(who, 40)
		_gap(56)
	_gap(80)
	_line(tr("CR_THANKS_TO"), 34, HEAD)
	_gap(40)
	var audio := _audio()
	if not audio.sounds.is_empty():
		_line(tr("CR_SOUNDS_FROM"), 26, HEAD)
		_line(" · ".join(audio.sounds), 30)
		_gap(48)
	for who in audio.instruments:
		_line(tr("CR_INSTRUMENTS"), 26, HEAD)
		_line(who, 30)
		_gap(48)
	_line(tr("CR_FONTS"), 26, HEAD)
	for f in data.get("fonts", []):
		_line(f[0], 30)
	_line(str(data.get("font_license", "")), 22)
	_gap(48)
	var engine: Array = data.get("engine", ["Godot Engine"])
	_line(tr("CR_MADE_WITH"), 26, HEAD)
	_line(" · ".join([engine[0]] + Array(data.get("tools", []))), 30)
	_gap(260)
	_line(tr("CR_THANK_YOU"), 52)
	_gap(30)
	last = _line(Lang.t("CR_RIGHTS", {"year": int(data.get("year", 2026)), "studio": data.get("studio", "")}), 24)
	roll.reset_size()
	roll.size.x = size.x
	roll.position = Vector2(0, size.y)

func _line(text: String, px: int, color := UiTheme.INK, outline := Color(0, 0, 0, 0), ow := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if text.length() > 60:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = minf(size.x - 160.0, 1200.0)
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	if ow > 0:
		l.add_theme_color_override("font_outline_color", outline)
		l.add_theme_constant_override("outline_size", ow)
	roll.add_child(l)
	return l

func _gap(px: int) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = px
	roll.add_child(c)

func _audio() -> Dictionary:
	"""Who made the sounds, from data/audio/credits.json: CC0 contributors, instrument libraries, the voice."""
	var out := {"sounds": [], "instruments": [], "voices": []}
	var d = JSON.parse_string(FileAccess.get_file_as_string(AUDIO)) if FileAccess.file_exists(AUDIO) else null
	if not (d is Dictionary):
		return out
	for key in d:
		var row = d[key]
		if not (row is Dictionary):
			continue
		var by := str(row.get("by", ""))
		var lic := str(row.get("license", ""))
		if by == "" or by == "mcgame":
			continue
		if lic.begins_with("Apache"):
			_add(out.voices, "%s · Apache License 2.0" % by)
		elif "VSCO" in str(row.get("source", "")):
			_add(out.instruments, "VSCO 2 Community Edition · %s" % by)
		else:
			for who in by.split(", "):
				_add(out.sounds, who)
	out.sounds.sort_custom(func(a, b): return a.to_lower() < b.to_lower())
	return out

func _add(list: Array, what: String) -> void:
	if not what in list:
		list.append(what)

func _build_corner() -> void:
	var hint := Label.new()
	hint.text = tr("CR_HINT")
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(UiTheme.INK, 0.55))
	hint.position = Vector2(40, size.y - 56)
	add_child(hint)
	var b := Button.new()
	b.text = tr("CR_LICENSES")
	b.custom_minimum_size = Vector2(0, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_show_licenses.bind(true))
	add_child(b)
	b.reset_size()
	b.position = Vector2(size.x - b.size.x - 40, 30)

func _build_licenses(data: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	p.visible = false
	p.position = Vector2(size.x * 0.1, size.y * 0.08)
	p.size = Vector2(size.x * 0.8, size.y * 0.84)
	add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	p.add_child(box)
	var title := Label.new()
	title.text = tr("CR_LICENSES")
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	var intro := Label.new()
	intro.text = tr("CR_LICENSE_INTRO")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	var text := RichTextLabel.new()
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.selection_enabled = true
	text.add_theme_color_override("default_color", UiTheme.INK)
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_font_size_override("bold_font_size", 20)
	box.add_child(text)
	_fill_licenses(text, data)
	var back := Button.new()
	back.text = tr("CR_BACK")
	back.custom_minimum_size = Vector2(160, 46)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(_show_licenses.bind(false))
	box.add_child(back)
	return p

func _fill_licenses(t: RichTextLabel, data: Dictionary) -> void:
	"""Plain add_text all the way (no BBCode), so the brackets in the licence texts stay as they are."""
	var used := {}
	var studio := str(data.get("studio", ""))
	_head(t, Lang.t("CR_RIGHTS", {"year": int(data.get("year", 2026)), "studio": studio}))
	t.add_text(Lang.t("CR_RIGHTS_TEXT", {"game": tr("GAME_TITLE"), "studio": studio}) + "\n\n")
	_head(t, "Godot Engine")
	t.add_text(Engine.get_license_text() + "\n\n")
	_head(t, "Godot Engine: third-party components")
	for c in Engine.get_copyright_info():
		for part in c.parts:
			t.add_text("%s\n    © %s\n    License: %s\n" % [c.name, "\n    © ".join(part.copyright), part.license])
			for lic in str(part.license).split(" or "):
				for name in lic.split(" and "):
					used[name.strip_edges().trim_prefix("(").trim_suffix(")")] = true
	t.add_text("\n")
	_head(t, "Fonts")
	for f in data.get("fonts", []):
		t.add_text("%s: %s\n" % [f[0], f[1]])
	var ofl := str(data.get("font_license_file", ""))
	if ofl != "" and FileAccess.file_exists(ofl):
		t.add_text("\n" + FileAccess.get_file_as_string(ofl) + "\n")
	var audio := _audio()
	_head(t, "Sounds")
	t.add_text("Sound recordings from freesound.org by %s, dedicated to the public domain under CC0 1.0.\n"
		% ", ".join(audio.sounds))
	for who in audio.instruments:
		t.add_text("%s, dedicated to the public domain under CC0 1.0.\n" % who)
	for who in audio.voices:
		t.add_text("Narration voice: VieNeu-TTS (https://huggingface.co/pnnbao-ump/VieNeu-TTS-v3-Turbo) by %s. "
			% who.get_slice(" · ", 0) + "Licensed under the Apache License, Version 2.0.\n")
		used["Apache-2.0"] = true
	t.add_text("\n")
	var texts := Engine.get_license_info()
	for name in used:
		if texts.has(name):
			_head(t, "License: " + name)
			t.add_text(texts[name] + "\n\n")

func _head(t: RichTextLabel, text: String) -> void:
	t.push_bold()
	t.push_color(HEAD)
	t.add_text(text + "\n")
	t.pop()
	t.pop()

func _show_licenses(on: bool) -> void:
	licenses.visible = on

func _process(delta: float) -> void:
	if licenses.visible or _gone:
		return
	var end_y := size.y * 0.5 - (last.position.y + last.size.y)
	if roll.position.y > end_y:
		roll.position.y = maxf(roll.position.y - SPEED * (FAST if held else 1.0) * delta, end_y)
	else:
		ended += delta
		if ended >= END_HOLD:
			_leave()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_B):
		get_viewport().set_input_as_handled()
		if licenses.visible:
			_show_licenses(false)
		else:
			_leave()
		return
	if e is InputEventKey or e is InputEventMouseButton or e is InputEventScreenTouch or e is InputEventJoypadButton:
		held = e.is_pressed()

func _leave() -> void:
	if _gone:
		return
	_gone = true
	var to := then
	then = "res://scenes/title.tscn"
	get_tree().change_scene_to_file(to)
