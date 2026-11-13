class_name MiniGame
extends Control

signal finished(score: float)
signal grumbled

const AREA := Vector2(880, 470)
const GRUMBLES := 6

var title := ""
var duration := 30.0
var difficulty := 0.0
var job := "design"
var hard := false
var _left := 0.0
var _bar: ProgressBar
var _secs: Label
var _area: Control
var _running := true
var _verdict: Label
var _card: PanelContainer
var grumble_after := 3
var _fumbles := 0
var _last_grumble := -1
var _grumble: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.12, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_card = PanelContainer.new()
	_card.theme = UiTheme.make()
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.custom_minimum_size = AREA + Vector2(40, 130)
	add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_card.add_child(v)
	var head := HBoxContainer.new()
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 30)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_secs = Label.new()
	_secs.add_theme_font_size_override("font_size", 24)
	_secs.add_theme_color_override("font_color", Color("a08a82"))
	head.add_child(_secs)
	v.add_child(head)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", UiTheme.box(Color("f3e6dc"), 7, Color(0, 0, 0, 0), 0, 0))
	_bar.add_theme_stylebox_override("fill", UiTheme.box(Color("8fd3a8"), 7, Color(0, 0, 0, 0), 0, 0))
	v.add_child(_bar)
	_area = Control.new()
	_area.custom_minimum_size = AREA
	_area.clip_contents = true
	v.add_child(_area)
	_verdict = Label.new()
	_verdict.set_anchors_preset(Control.PRESET_FULL_RECT)
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_verdict.add_theme_font_size_override("font_size", 64)
	_verdict.add_theme_color_override("font_color", Color.WHITE)
	_verdict.add_theme_color_override("font_outline_color", UiTheme.PINK_DARK)
	_verdict.add_theme_constant_override("outline_size", 18)
	_verdict.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_verdict.visible = false
	add_child(_verdict)
	_left = duration
	_build(_area)
	_card.reset_size.call_deferred()
	_center.call_deferred()
	_card.scale = Vector2(0.9, 0.9)
	_card.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.25)
	tw.tween_property(_card, "modulate:a", 1.0, 0.15)

func _center() -> void:
	var vs := get_viewport_rect().size
	_card.position = (vs - _card.size) * 0.5
	_card.pivot_offset = _card.size * 0.5

func _process(delta: float) -> void:
	if not _running:
		return
	_left -= delta
	_bar.value = 100.0 * maxf(_left, 0.0) / duration
	_secs.text = "%d″" % ceili(maxf(_left, 0.0))
	var low := _left < duration * 0.25
	_bar.add_theme_stylebox_override("fill", UiTheme.box(Color("f08a74") if low else Color("8fd3a8"), 7, Color(0, 0, 0, 0), 0, 0))
	_tick(delta)
	if _left <= 0.0:
		done(timeout_score())

func lose_time(secs: float) -> void:
	_left -= secs

func done(score: float) -> void:
	"""The game is over: a verdict for a moment, then finished(score)."""
	if not _running:
		return
	_running = false
	_verdict.text = tr("MG_GREAT") if score >= 0.85 else (tr("MG_OK") if score >= 0.5 else tr("MG_FAIL"))
	_verdict.position = Vector2.ZERO
	_verdict.size = get_viewport_rect().size
	_verdict.visible = true
	_verdict.scale = Vector2(0.6, 0.6)
	_verdict.pivot_offset = _verdict.size * 0.5
	create_tween().tween_property(_verdict, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	await get_tree().create_timer(1.1).timeout
	finished.emit(clampf(score, 0.0, 1.0))
	queue_free()

func fumble() -> void:
	"""A wrong move. The third (grumble_after) gets a grumpy line, and every second one after it."""
	_fumbles += 1
	var past := _fumbles - grumble_after
	if past >= 0 and past % 2 == 0:
		_say_grumpy()

func _say_grumpy() -> void:
	var i := randi() % GRUMBLES
	if i == _last_grumble:
		i = (i + 1) % GRUMBLES
	_last_grumble = i
	if _grumble == null:
		_grumble = Label.new()
		_grumble.add_theme_font_size_override("font_size", 24)
		_grumble.add_theme_color_override("font_color", Color("8a2f3a"))
		_grumble.add_theme_stylebox_override("normal", UiTheme.box(Color("fff0f0"), 18, Color("f08a74"), 3, 16))
		_grumble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_grumble)
	var who := Hero.name if Hero.name != "" else tr("HERO_CALLED")
	_grumble.text = "%s:  %s" % [who, tr("MG_GRUMBLE_%d" % (i + 1))]
	_grumble.reset_size()
	_grumble.position = _card.position + Vector2(24, _card.size.y - 18)
	_grumble.pivot_offset = Vector2(0, _grumble.size.y)
	_grumble.scale = Vector2(0.7, 0.7)
	_grumble.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_grumble, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(2.4)
	tw.tween_property(_grumble, "modulate:a", 0.0, 0.4)
	shake(_card)
	grumbled.emit()

func shake(c: Control) -> void:
	var x0 := c.position.x
	var tw := create_tween()
	for i in 4:
		tw.tween_property(c, "position:x", x0 + (8.0 if i % 2 == 0 else -8.0), 0.04)
	tw.tween_property(c, "position:x", x0, 0.04)

func label(text: String, size := 22, color := UiTheme.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func button(text: String, size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	return b

func _build(_area_: Control) -> void:
	pass

func _tick(_delta: float) -> void:
	pass

func timeout_score() -> float:
	return 0.0
