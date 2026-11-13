extends CanvasLayer

const STICK_R := 62.0
const KNOB_R := 27.0
const DEAD := 0.12
const RUN_AT := 0.85
const RUN_HOLD := 0.25
const LEFT_SHARE := 0.4
const TAP_SLOP := 10.0
const DOUBLE_TAP := 0.3
const TURN := 0.008
const PINCH_STEP := 1.08
const ACT_W := 168.0
const ACT_H := 64.0
const SMALL := 56.0
const MARGIN := 18.0
const POLL := 0.1

var active := false
var move := Vector2.ZERO
var run := false

var _pt := 1.0
var _safe := Rect2()
var _root: Control
var _act: PanelContainer
var _act_label: Label
var _emote: PanelContainer
var _sit: PanelContainer
var _sit_label: Label
var _dress: PanelContainer
var _wheel: EmoteWheel
var _dress_panel: DressPanel
var _hero: Player
var _actions: Array = []
var _claimed: Array = []
var _offer := {}
var _poll := 0.0
var _fingers := {}
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _run_t := 0.0
var _pinch := 0.0
var _last_tap := -1.0
var _shown := false

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var forced := "--touch" in OS.get_cmdline_user_args() or "--touch" in OS.get_cmdline_args()
	if forced:
		Input.emulate_touch_from_mouse = true
	active = forced or OS.has_feature("mobile")
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_stick)
	add_child(_root)
	_act = _panel(UiTheme.PINK, 26)
	_act_label = _label(_act, true)
	_emote = _panel(Color("f6dccf"), 99)
	_label(_emote, false).text = tr("TC_EMOTE")
	_sit = _panel(Color("f6dccf"), 99)
	_sit_label = _label(_sit, false)
	_dress = _panel(Color("f6dccf"), 99)
	_label(_dress, false).text = tr("TC_DRESS")
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show(false)

func add_action(owner: Object, fn: Callable, priority := 0) -> void:
	_actions.append([weakref(owner), fn, priority])
	_actions.sort_custom(func(a, b): return a[2] > b[2])

func claim(c: Control) -> void:
	_claimed.append(weakref(c))

func tap_slop() -> float:
	return TAP_SLOP * _pt

func _panel(border: Color, radius: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 0.98, 0.95, 0.93), radius, border, 3, 10))
	_root.add_child(p)
	return p

func _label(p: PanelContainer, wrap: bool) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", UiTheme.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return l

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var per_px := vs.y / maxf(win.y, 1.0)
	_pt = per_px * maxf(DisplayServer.screen_get_scale(), 1.0)
	_safe = Rect2(Vector2.ZERO, vs)
	if OS.has_feature("mobile"):
		var s := DisplayServer.get_display_safe_area()
		if s.size.x > 0:
			_safe = Rect2(Vector2(s.position) * per_px, Vector2(s.size) * per_px)
	_root.size = vs
	var m := MARGIN * _pt
	var br := _safe.end - Vector2(m, m)
	for l: Label in [_act_label, _sit_label, _emote.get_child(0), _dress.get_child(0)]:
		l.add_theme_font_size_override("font_size", int((15.0 if l == _act_label else 11.0) * _pt))
	_act_label.custom_minimum_size.x = ACT_W * _pt - 22.0
	_act.custom_minimum_size = Vector2(ACT_W, ACT_H) * _pt
	_act.size = _act.custom_minimum_size
	_act.position = br - _act.size
	for b: PanelContainer in [_sit, _emote, _dress]:
		(b.get_child(0) as Label).custom_minimum_size.x = SMALL * _pt - 22.0
		b.custom_minimum_size = Vector2(SMALL, SMALL) * _pt
		b.size = b.custom_minimum_size
	_sit.position = _act.position + Vector2(_act.size.x - _sit.size.x, -_sit.size.y - 12.0 * _pt)
	_emote.position = _sit.position - Vector2(_emote.size.x + 12.0 * _pt, 0)
	_dress.position = _emote.position - Vector2(_dress.size.x + 12.0 * _pt, 0)
	_root.queue_redraw()

func _process(delta: float) -> void:
	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group(&"hero") as Player
	var want: bool = active and _hero != null and _hero.controls and _hero.is_physics_processing() \
		and not Agent.quiet and not get_tree().paused and not (_wheel and _wheel.visible) \
		and not (_dress_panel and _dress_panel.visible)
	if want != _shown:
		_show(want)
	if not _shown:
		return
	if _fingers.is_empty() or not _has_role("stick"):
		_run_t = 0.0
	elif _knob.length() >= RUN_AT * STICK_R * _pt:
		_run_t += delta
	else:
		_run_t = 0.0
	run = _run_t >= RUN_HOLD
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL
		_refresh()

func _show(on: bool) -> void:
	_shown = on
	_root.visible = on
	if not on:
		_fingers.clear()
		move = Vector2.ZERO
		run = false
		_knob = Vector2.ZERO
	_root.queue_redraw()

func _refresh() -> void:
	"""Ask the scene what the action button would do now, and the sit button's word."""
	var best := {}
	var i := _actions.size() - 1
	while i >= 0:
		if _actions[i][0].get_ref() == null or not (_actions[i][1] as Callable).is_valid():
			_actions.remove_at(i)
		i -= 1
	for a in _actions:
		var o: Dictionary = a[1].call()
		if not o.is_empty():
			best = o
			break
	_offer = best
	var text: String = best.get("label", "")
	if _act_label.text != text:
		_act_label.text = text
	_act.visible = text != ""
	var sit_text := tr("TC_STAND") if _hero.sitting else tr("TC_SIT")
	if _sit_label.text != sit_text:
		_sit_label.text = sit_text

func _input(e: InputEvent) -> void:
	if e is InputEventKey or e is InputEventJoypadButton \
			or (e is InputEventJoypadMotion and absf((e as InputEventJoypadMotion).axis_value) > 0.5):
		if active and not (e is InputEventKey and get_viewport().gui_get_focus_owner() is LineEdit):
			active = false
		return
	if e is InputEventScreenTouch:
		active = true
		if not _shown:
			return
		var t := e as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index, t.position)
	elif e is InputEventScreenDrag and _shown and _fingers.has((e as InputEventScreenDrag).index):
		var d := e as InputEventScreenDrag
		_touch_move(d.index, d.position)

func _touch_down(i: int, p: Vector2) -> void:
	var f := {"role": "", "start": p, "pos": p, "t": Time.get_ticks_msec() / 1000.0}
	for b: PanelContainer in [_act, _sit, _emote, _dress]:
		if b.visible and b.get_global_rect().grow(6.0 * _pt).has_point(p):
			f["role"] = "button"
			_press(b)
			_fingers[i] = f
			return
	if _on_claimed(p):
		f["role"] = "ui"
		_fingers[i] = f
		return
	if p.x < _safe.position.x + _safe.size.x * LEFT_SHARE and not _has_role("stick"):
		f["role"] = "stick"
		var r := STICK_R * _pt
		_center = p.clamp(_safe.position + Vector2(r, r), _safe.end - Vector2(r, r))
		_knob = p - _center
		_stick_out()
		if _hero:
			_hero._poke()
	else:
		f["role"] = "cam"
		if _count_role("cam") == 1:
			_pinch = p.distance_to(_other_cam(i)["pos"])
	_fingers[i] = f

func _touch_move(i: int, p: Vector2) -> void:
	var f: Dictionary = _fingers[i]
	var last: Vector2 = f["pos"]
	f["pos"] = p
	match f["role"]:
		"stick":
			_knob = p - _center
			var r := STICK_R * _pt
			if _knob.length() > r:
				_center += _knob - _knob.limit_length(r)
				_knob = _knob.limit_length(r)
			_stick_out()
		"cam":
			if _count_role("cam") >= 2:
				_pinch_move(i)
			elif p.distance_to(f["start"]) > tap_slop():
				var cam := get_viewport().get_camera_3d()
				if cam and cam.has_method("touch_turn"):
					cam.touch_turn((p - last) / _pt)

func _touch_up(i: int, p: Vector2) -> void:
	if not _fingers.has(i):
		return
	var f: Dictionary = _fingers[i]
	_fingers.erase(i)
	match f["role"]:
		"stick":
			_knob = Vector2.ZERO
			move = Vector2.ZERO
			_root.queue_redraw()
		"cam":
			var now := Time.get_ticks_msec() / 1000.0
			if p.distance_to(f["start"]) <= tap_slop() and now - float(f["t"]) < 0.25 and _fingers.is_empty():
				if now - _last_tap < DOUBLE_TAP:
					var cam := get_viewport().get_camera_3d()
					if cam and cam.has_method("reset_view"):
						cam.reset_view()
					_last_tap = -1.0
				else:
					_last_tap = now

func _stick_out() -> void:
	var r := STICK_R * _pt
	var v := _knob / r
	move = Vector2.ZERO if v.length() < DEAD else v * ((v.length() - DEAD) / (1.0 - DEAD)) / v.length()
	_root.queue_redraw()

func _pinch_move(i: int) -> void:
	var d: float = (_fingers[i]["pos"] as Vector2).distance_to(_other_cam(i)["pos"])
	if _pinch <= 0.0:
		_pinch = d
		return
	var ratio := d / _pinch
	if ratio > PINCH_STEP or ratio < 1.0 / PINCH_STEP:
		_pinch = d
		_wheel_notch(ratio > 1.0, (_fingers[i]["pos"] + _other_cam(i)["pos"]) * 0.5)

func _wheel_notch(closer: bool, at: Vector2) -> void:
	"""One mouse-wheel notch: up = closer in every scene (ctrl for OrbitCam, where the plain wheel tilts)."""
	var win := get_viewport().get_final_transform() * at
	for down in [true, false]:
		var w := InputEventMouseButton.new()
		w.button_index = MOUSE_BUTTON_WHEEL_UP if closer else MOUSE_BUTTON_WHEEL_DOWN
		w.pressed = down
		w.ctrl_pressed = true
		w.factor = 1.0
		w.position = win
		w.global_position = win
		Input.parse_input_event.call_deferred(w)

func _other_cam(i: int) -> Dictionary:
	for k in _fingers:
		if k != i and _fingers[k]["role"] == "cam":
			return _fingers[k]
	return {"pos": Vector2.ZERO}

func _on_claimed(p: Vector2) -> bool:
	var i := _claimed.size() - 1
	var hit := false
	while i >= 0:
		var c := _claimed[i].get_ref() as Control
		if c == null or not c.is_inside_tree():
			_claimed.remove_at(i)
		elif c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			hit = true
		i -= 1
	return hit

func _has_role(role: String) -> bool:
	return _count_role(role) > 0

func _count_role(role: String) -> int:
	var n := 0
	for k in _fingers:
		if _fingers[k]["role"] == role:
			n += 1
	return n

func _press(b: PanelContainer) -> void:
	var tw := create_tween()
	b.scale = Vector2.ONE * 0.92
	b.pivot_offset = b.size / 2
	tw.tween_property(b, "scale", Vector2.ONE, 0.12)
	if _hero:
		_hero._poke()
	if b == _act:
		_refresh()
		if not _offer.is_empty():
			Input.vibrate_handheld(15)
			(_offer["run"] as Callable).call()
	elif b == _sit:
		if not _hero.busy():
			_hero.toggle_sit()
	elif b == _emote:
		if _wheel == null:
			_wheel = EmoteWheel.new()
			add_child(_wheel)
			_wheel.picked.connect(func(k: String): Net.act("emote", k))
		_wheel.toggle()
	elif b == _dress:
		if _dress_panel == null:
			_dress_panel = DressPanel.new()
			_dress_panel.setup(_hero.chibi)
			add_child(_dress_panel)
		else:
			_dress_panel.open(_hero.chibi)

func _draw_stick() -> void:
	if not _shown:
		return
	var r := STICK_R * _pt
	var held := _has_role("stick")
	var c := _center if held else _safe.position + Vector2(MARGIN * _pt + r, _safe.size.y - MARGIN * _pt - r)
	var a := 0.85 if held else 0.35
	_root.draw_circle(c, r, Color(1, 0.98, 0.95, 0.35 * a))
	_root.draw_arc(c, r, 0, TAU, 48, Color(UiTheme.INK, 0.5 * a), 3.0 * _pt, true)
	var knob := Color(UiTheme.PINK, a) if not run else Color(UiTheme.PINK_DARK, a)
	_root.draw_circle(c + _knob, KNOB_R * _pt, knob)
