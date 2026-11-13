class_name PrinterFix
extends MiniGame

const STEPS := ["MG_P1", "MG_P2", "MG_P3", "MG_P4"]

var step := 0
var _parts: Array = []
var _next: Label
var _lid: Panel
var _paper: Panel

func _build(area: Control) -> void:
	duration = 16.0 * (1.0 - 0.25 * difficulty)
	_left = duration
	_next = label("", 26, UiTheme.PINK_DARK)
	_next.position = Vector2(20, 6)
	area.add_child(_next)
	var o := Vector2(250, 90)
	var body := _box(area, Rect2(o + Vector2(0, 90), Vector2(380, 230)), Color("dfe3ea"), 22)
	_lid = _box(area, Rect2(o + Vector2(10, 40), Vector2(360, 60)), Color("c8ced8"), 16)
	_paper = _box(area, Rect2(o + Vector2(110, 70), Vector2(160, 70)), Color("ffffff"), 4)
	_paper.rotation = deg_to_rad(-8)
	_paper.visible = false
	var tray := _box(area, Rect2(o + Vector2(70, 250), Vector2(240, 36)), Color("b7bec9"), 8)
	var btn := _box(area, Rect2(o + Vector2(300, 140), Vector2(46, 46)), Color("5fbf7a"), 23)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parts = [_lid, _paper, _lid, btn]
	for p in [_lid, _paper, btn]:
		(p as Panel).gui_input.connect(_on_click.bind(p))
		(p as Panel).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_show()

func _box(area: Control, r: Rect2, c: Color, radius: int) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.pivot_offset = r.size * 0.5
	p.add_theme_stylebox_override("panel", UiTheme.box(c, radius, Color("a4abb8"), 2, 0))
	area.add_child(p)
	return p

func _on_click(e: InputEvent, part: Panel) -> void:
	if not ((e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)):
		return
	if step >= _parts.size():
		return
	if part != _parts[step]:
		shake(part)
		lose_time(1.0)
		fumble()
		return
	match step:
		0:
			create_tween().tween_property(_lid, "position:y", _lid.position.y - 50, 0.2)
			_paper.visible = true
		1:
			_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tw := create_tween().set_parallel()
			tw.tween_property(_paper, "position:y", _paper.position.y - 120, 0.3)
			tw.tween_property(_paper, "modulate:a", 0.0, 0.3)
			tw.chain().tween_callback(func(): _paper.visible = false)
		2:
			create_tween().tween_property(_lid, "position:y", _lid.position.y + 50, 0.2)
		3:
			pass
	step += 1
	_show()
	if step >= _parts.size():
		done(1.0)

func _show() -> void:
	for p in [_lid, _paper]:
		(p as Panel).modulate = Color.WHITE
	if step < STEPS.size():
		_next.text = Lang.t("MG_NEXT", {"s": tr(STEPS[step])})

func _tick(_delta: float) -> void:
	if step < _parts.size():
		var p: Panel = _parts[step]
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		p.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.85, 0.6), k)

func timeout_score() -> float:
	return float(step) / _parts.size()
