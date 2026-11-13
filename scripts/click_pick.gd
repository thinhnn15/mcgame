class_name ClickPick
extends Node

const RADIUS := 0.06

var cam: Camera3D
var targets: Array = []
var enabled := true
var _hover := {}
var _mouse := Vector2(-1e6, -1e6)
var _label: Label
var _down := Vector2.ZERO

func setup(camera: Camera3D, layer: CanvasLayer) -> void:
	cam = camera
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", UiTheme.INK)
	_label.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.98, 0.95, 0.95), 14, UiTheme.PINK, 2, 12))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	layer.add_child(_label)

func add(point: Callable, label: Callable, run: Callable, ok := Callable()) -> void:
	targets.append({"point": point, "label": label, "run": run, "ok": ok})

func _input(e: InputEvent) -> void:
	if e is InputEventMouse:
		_mouse = e.position

func _target_at(mouse: Vector2) -> Dictionary:
	var vp := get_viewport()
	var best := {}
	var best_d := RADIUS * vp.get_visible_rect().size.y
	if not enabled or cam == null or vp.gui_get_hovered_control() != null:
		return best
	for t in targets:
		if t["ok"].is_valid() and not t["ok"].call():
			continue
		var p: Vector3 = t["point"].call()
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p).distance_to(mouse)
		if d < best_d:
			best = t
			best_d = d
	return best

func _process(_delta: float) -> void:
	var best := _target_at(_mouse)
	var mouse := _mouse
	_hover = best
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if not best.is_empty() else Input.CURSOR_ARROW)
	_label.visible = not best.is_empty()
	if _label.visible:
		_label.text = best["label"].call()
		_label.reset_size()
		_label.position = mouse + Vector2(22, 18)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if TouchControls.active:
			if e.pressed:
				_down = e.position
				return
			if e.position.distance_to(_down) > TouchControls.tap_slop():
				return
		elif not e.pressed:
			return
		var t := _target_at(e.position)
		if not t.is_empty():
			get_viewport().set_input_as_handled()
			_hover = {}
			t["run"].call()

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
