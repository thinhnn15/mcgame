class_name PerfHud
extends CanvasLayer

var _label: Label

static func add(parent: Node) -> PerfHud:
	var h := PerfHud.new()
	h.name = "PerfHud"
	h.layer = 30
	parent.add_child(h)
	return h

func _ready() -> void:
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color("fffaf2"))
	_label.add_theme_color_override("font_outline_color", Color("5b4a44"))
	_label.add_theme_constant_override("outline_size", 6)

	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.offset_left = -300.0
	_label.offset_right = 300.0
	_label.offset_top = 64.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	visible = not OS.get_cmdline_user_args().has("--no-perf")

func _process(_d: float) -> void:
	if not visible or Engine.get_process_frames() % 10 != 0:
		return
	var tris := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var s := str(tris)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	_label.text = "FPS %d   •   tam giác %s   •   lần vẽ %d" % [Engine.get_frames_per_second(), s + out,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F3:
		visible = not visible
