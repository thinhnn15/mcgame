extends Node

const LINES := ["NARR_0_1", "NARR_0_2"]
var _leaving := false
var _skipped := false
var _layer: CanvasLayer

func _ready() -> void:
	Story.load_saved()
	_layer = CanvasLayer.new()
	add_child(_layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(black)
	Narrator.taps = true
	if Story.beat == "bridge":
		await _bridge()
		return
	Story.set_beat("prologue")
	Narrator.skippable = true
	Narrator.skip_requested.connect(_skip_epigraph)
	await get_tree().create_timer(1.0).timeout
	for key in LINES:
		if _skipped:
			break
		await Narrator.say(key)
	Narrator.skip_requested.disconnect(_skip_epigraph)
	await _ask_name()
	Story.set_beat("look")
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file(Story.scene())

func _skip_epigraph() -> void:
	_skipped = true
	Narrator.clear()

func _bridge() -> void:
	Narrator.skippable = true
	Narrator.skip_requested.connect(_next)
	await get_tree().create_timer(0.8).timeout
	if _leaving:
		return
	await Narrator.say("NARR_1_4")
	if _leaving:
		return
	await get_tree().create_timer(0.8).timeout
	_next()

func _ask_name() -> void:
	"""'My name is…' stays up; the name is written on a line under it, Enter (or the arrow) to go on."""
	Narrator.skippable = false
	Narrator.taps = false
	Narrator.say_text(tr("NARR_NAME_ASK"), true)
	await get_tree().create_timer(1.0).timeout
	var k := get_viewport().get_visible_rect().size.y / 1080.0
	var box := VBoxContainer.new()
	box.anchor_left = 0.3
	box.anchor_right = 0.7
	box.anchor_top = 0.83
	box.anchor_bottom = 0.95
	box.add_theme_constant_override("separation", int(10 * k))
	box.modulate.a = 0.0
	_layer.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var field := LineEdit.new()
	field.text = Hero.name
	field.max_length = 16
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_size_override("font_size", int(40 * k))
	field.add_theme_color_override("font_color", NarratorLayer.INK)
	field.add_theme_color_override("caret_color", NarratorLayer.INK)
	var line := StyleBoxFlat.new()
	line.bg_color = Color(0, 0, 0, 0)
	line.border_color = Color(NarratorLayer.INK, 0.5)
	line.border_width_bottom = int(maxf(2.0, 2.0 * k))
	line.content_margin_bottom = 6 * k
	for st in ["normal", "focus", "read_only"]:
		field.add_theme_stylebox_override(st, line)
	row.add_child(field)
	var ok := Button.new()
	ok.text = "→"
	ok.flat = true
	ok.focus_mode = Control.FOCUS_NONE
	ok.add_theme_font_size_override("font_size", int(40 * k))
	ok.add_theme_color_override("font_color", Color(NarratorLayer.INK, 0.7))
	ok.add_theme_color_override("font_hover_color", NarratorLayer.INK)
	row.add_child(ok)
	var hint := Label.new()
	hint.text = tr("NAME_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", int(22 * k))
	hint.add_theme_color_override("font_color", Color(NarratorLayer.INK, 0.45))
	box.add_child(hint)
	create_tween().tween_property(box, "modulate:a", 1.0, 0.6)
	field.grab_focus()
	var done := [false]
	var submit := func():
		if field.text.strip_edges() != "":
			done[0] = true
			return
		var x := row.position.x
		var tw := create_tween()
		for i in 4:
			tw.tween_property(row, "position:x", x + (9.0 if i % 2 == 0 else -9.0) * k, 0.045)
		tw.tween_property(row, "position:x", x, 0.045)
		field.grab_focus()
	field.text_submitted.connect(func(_t: String): submit.call())
	ok.pressed.connect(submit)
	if OS.get_cmdline_user_args().has("--name"):
		get_tree().create_timer(1.5).timeout.connect(func():
			field.text = Stage.arg("--name")
			submit.call())
	while not done[0]:
		await get_tree().process_frame
	Hero.name = field.text.strip_edges().left(16)
	Hero.save()
	Story.save()
	field.editable = false
	var out := create_tween()
	out.tween_property(box, "modulate:a", 0.0, 0.5)
	out.tween_callback(box.queue_free)
	Narrator.taps = true
	Narrator.skippable = true
	await Narrator.say("NARR_NAME_AFTER")

func _next() -> void:
	if _leaving:
		return
	_leaving = true
	Narrator.clear()
	Story.set_beat("night")
	get_tree().change_scene_to_file("res://scenes/office_intro.tscn")
