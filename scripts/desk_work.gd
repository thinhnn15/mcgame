class_name DeskWork
extends Node

const SIT_BACK := Npc.SIT_BACK
const REACH := 0.75
const WORK_SECS := 90.0
const SIDE := 0.25
const TYPE_KEYS := [KEY_SPACE, KEY_ENTER, KEY_BACKSPACE, KEY_SEMICOLON, KEY_COMMA, KEY_PERIOD, KEY_SLASH,
	KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_MINUS, KEY_EQUAL, KEY_APOSTROPHE]

var office
var seats := []
var working := false
var progress := 0.0
var work_chars := PcScreen.AUTO_CPS * WORK_SECS
var _seat := {}
var _busy := false
var _hint: Label
var _panel: PanelContainer
var _bar: ProgressBar
var _bubble: SpeechBubble
var _zoom_before := 1.0
var pc: PcScreen
var _layer: CanvasLayer
var _keys_rate := 0.0
var _desk_bar: HBoxContainer
var _leave: PanelContainer
var _hide: PanelContainer
var _zoom: PanelContainer
var _app_hint: Label
var _sits := 0
var _tip: Control
const CFG := "user://settings.cfg"
const HINT_SITS := 3

class BarIcon:
	extends Control
	var kind := "door"
	var up := false

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, size.x * 0.5, UiTheme.PINK_DARK, true, -1.0, true)
		var w := Color.WHITE
		if kind == "door":
			draw_rect(Rect2(c + Vector2(-2, -9), Vector2(10, 18)), w, false, 2.5)
			draw_line(c + Vector2(2, 0), c + Vector2(-9, 0), w, 2.5, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 0), c + Vector2(-6, -5), c + Vector2(-6, 5)]), w)
		elif kind == "zoom":
			var m := c - Vector2(2, 2)
			draw_arc(m, 7.0, 0.0, TAU, 24, w, 2.5, true)
			draw_line(m + Vector2(5, 5), m + Vector2(10, 10), w, 3.0, true)
			draw_line(m - Vector2(3.5, 0), m + Vector2(3.5, 0), w, 2.0, true)
			if not up:
				draw_line(m - Vector2(0, 3.5), m + Vector2(0, 3.5), w, 2.0, true)
		else:
			draw_rect(Rect2(c + Vector2(-9, -8), Vector2(18, 12)), w, false, 2.5)
			draw_line(c + Vector2(0, 4), c + Vector2(0, 7), w, 2.5)
			var d := -1.0 if up else 1.0
			draw_polyline(PackedVector2Array([c + Vector2(-4, -3 * d - 2), c + Vector2(0, d - 2), c + Vector2(4, -3 * d - 2)]), w, 2.5, true)

func setup(p_office, layer: CanvasLayer, free_seats: Array) -> void:
	TouchControls.add_action(self, func() -> Dictionary:
		if working or _busy or not office.player.controls or (office.morning and office.morning.busy):
			return {}
		var s := _nearest()
		return {} if s.is_empty() else {"label": tr("SIT_HOVER"), "run": sit_down.bind(s)}, 20)
	office = p_office
	_layer = layer
	for s in free_seats:
		var st: Array = office.seat(s[0], int(s[1]))
		seats.append({"pos": st[0], "yaw": st[1], "chair": _chair_at(st[0])})
	if office.pick:
		for s in seats:
			office.pick.add(func(): return s["pos"] + Vector3(0, 0.6, 0),
				func(): return tr("STAND_HOVER") if working else tr("SIT_HOVER"),
				_clicked.bind(s),
				func(): return not _busy and (s == _seat if working else office.player.controls))
	pc = PcScreen.new()
	Hero.load_saved()
	pc.job = Hero.job
	pc.clock_text = OfficeProps.screen_time
	layer.add_child(pc)
	pc.typed.connect(func(n: int): progress = minf(1.0, progress + n / work_chars))
	pc.task_done.connect(func(text: String):
		_bubble.show_text(text, 2.2)
		EmoteFx.play(office.player.chibi, "sparkle" if randf() < 0.6 else "bulb", 0.0))
	pc.hide_pressed.connect(_show_screen.bind(false))
	pc.stand_pressed.connect(func():
		if working and not _busy:
			stand_up())
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", UiTheme.INK)
	_hint.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.98, 0.95, 0.92), 18, Color("f6dccf"), 2, 16))
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 0.86
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.visible = false
	layer.add_child(_hint)
	_panel = PanelContainer.new()
	_panel.theme = UiTheme.make()
	_panel.position = Vector2(24, 60)
	_panel.visible = false
	var v := VBoxContainer.new()
	_panel.add_child(v)
	var title := Label.new()
	title.text = tr("WORK_TITLE")
	title.add_theme_font_size_override("font_size", 20)
	v.add_child(title)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(260, 22)
	_bar.max_value = 100.0
	_bar.add_theme_stylebox_override("background", UiTheme.box(Color("f3e6dc"), 11, Color(0, 0, 0, 0), 0, 0))
	_bar.add_theme_stylebox_override("fill", UiTheme.box(Color("8fd3a8"), 11, Color(0, 0, 0, 0), 0, 0))
	_bar.add_theme_color_override("font_color", UiTheme.INK)
	v.add_child(_bar)
	layer.add_child(_panel)
	_build_desk_bar(layer)
	_bubble = SpeechBubble.new()
	_bubble.position.y = 1.72
	office.player.add_child(_bubble)
	var t := Stage.arg("--work").split_floats(",")
	if t.size() == 2:
		get_tree().create_timer(t[0]).timeout.connect(func():
			office.player.global_position = _spot(seats[0])
			sit_down(seats[0]))
		get_tree().create_timer(t[1]).timeout.connect(stand_up)

func _chair_at(p: Vector3) -> Node3D:
	for c in office.world.get_children():
		if c is Node3D and str(c.scene_file_path).ends_with("office_chair.glb") \
				and Vector2(c.position.x - p.x, c.position.z - p.z).length() < 0.05:
			return c
	return null

func _spot(s: Dictionary) -> Vector3:
	return s["pos"] - Vector3(sin(s["yaw"]), 0, cos(s["yaw"])) * SIT_BACK

func _pill(kind: String, text: String, key: String, act: Callable) -> PanelContainer:
	"""One of the bar's buttons: a cream card with a picture, the words and the key."""
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var calm := UiTheme.box(Color("fff8ef"), 28, Color("f6dccf"), 2, 14)
	var lit := UiTheme.box(Color("ffe9ef"), 28, UiTheme.PINK, 3, 14)
	p.add_theme_stylebox_override("panel", calm)
	p.mouse_entered.connect(func(): p.add_theme_stylebox_override("panel", lit))
	p.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", calm))
	p.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			p.accept_event()
			p.pivot_offset = p.size * 0.5
			p.scale = Vector2(0.96, 0.96)
			p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.12)
			act.call())
	var h := HBoxContainer.new()
	h.name = "HBoxContainer"
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := BarIcon.new()
	icon.name = "Icon"
	icon.kind = kind
	icon.custom_minimum_size = Vector2(36, 36)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon)
	var l := Label.new()
	l.name = "Text"
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", UiTheme.INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	var k := Label.new()
	k.name = "Key"
	k.text = key
	k.add_theme_font_size_override("font_size", 15)
	k.add_theme_color_override("font_color", UiTheme.INK)
	k.add_theme_stylebox_override("normal", UiTheme.box(Color(0.36, 0.29, 0.27, 0.12), 6, Color(0, 0, 0, 0), 0, 7))
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(k)
	p.add_child(h)
	return p

func _build_desk_bar(layer: CanvasLayer) -> void:
	_desk_bar = HBoxContainer.new()
	_desk_bar.add_theme_constant_override("separation", 12)
	_desk_bar.visible = false
	_leave = _pill("door", tr("DESK_LEAVE"), "Esc", func():
		if working and not _busy and not (office.morning and office.morning.busy):
			stand_up())
	_hide = _pill("screen", tr("DESK_HIDE"), "Tab", func():
		if working and not _busy and not (office.morning and office.morning.busy):
			_show_screen(not pc.shown))
	_zoom = _pill("zoom", tr("OS_ZOOM"), "Esc", func():
		if working and pc.shown and not _busy and not (office.morning and office.morning.busy):
			pc.set_zoom(not pc.zoomed))
	_desk_bar.add_child(_leave)
	_desk_bar.add_child(_hide)
	_desk_bar.add_child(_zoom)
	layer.add_child(_desk_bar)
	_app_hint = Label.new()
	_app_hint.add_theme_font_size_override("font_size", 20)
	_app_hint.add_theme_color_override("font_color", UiTheme.INK)
	_app_hint.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.98, 0.95, 0.92), 16, Color("f6dccf"), 2, 14))
	_app_hint.visible = false
	layer.add_child(_app_hint)

func _app_hint_text() -> String:
	match pc.app:
		"riu":
			return tr("PC_HINT_RIU")
		"board":
			return tr("PC_HINT_BOARD")
		"desk":
			return tr("PC_HINT_DESK")
	return tr("PC_HINT_DESIGN") if pc.job == "design" else tr("PC_HINT_CODE")

func _place_bar() -> void:
	"""Bottom left, sized to the view (never too small to hit)."""
	var vs := get_viewport().get_visible_rect().size
	var k := clampf(minf(vs.x / 1600.0, vs.y / 900.0), 0.82, 1.4)
	_desk_bar.scale = Vector2(k, k)
	_desk_bar.reset_size()
	_desk_bar.position = Vector2(24.0 * k, vs.y - (_desk_bar.size.y + 24.0) * k)
	(_hide.get_node("HBoxContainer/Text") as Label).text = tr("DESK_HIDE") if pc.shown else tr("DESK_SHOW")
	var hi: BarIcon = _hide.get_node("HBoxContainer/Icon")
	if hi.up == pc.shown:
		hi.up = not pc.shown
		hi.queue_redraw()
	_leave.get_node("HBoxContainer/Key").visible = not (pc.zoomed and pc.shown)
	_zoom.visible = pc.shown
	_zoom.get_node("HBoxContainer/Key").visible = pc.zoomed
	(_zoom.get_node("HBoxContainer/Text") as Label).text = tr("OS_UNZOOM") if pc.zoomed else tr("OS_ZOOM")
	var zi: BarIcon = _zoom.get_node("HBoxContainer/Icon")
	if zi.up != pc.zoomed:
		zi.up = pc.zoomed
		zi.queue_redraw()
	_app_hint.visible = pc.shown and not pc.zoomed and _sits <= HINT_SITS
	if _app_hint.visible:
		var t := _app_hint_text()
		if _app_hint.text != t:
			_app_hint.text = t
			_app_hint.reset_size()
		_app_hint.scale = Vector2(k, k)
		_app_hint.position = Vector2(24.0 * k, _desk_bar.position.y - (_app_hint.size.y + 10.0) * k)

func _first_sit_tip() -> void:
	"""The very first sit: a tag over "Leave desk" and three pulses; any click or key (or 7 s) and it goes."""
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	if bool(cfg.get_value("tips", "desk_leave", false)):
		return
	cfg.set_value("tips", "desk_leave", true)
	cfg.save(CFG)
	await get_tree().create_timer(0.6).timeout
	if not working:
		return
	_tip = Label.new()
	(_tip as Label).text = tr("DESK_TIP_LEAVE")
	_tip.add_theme_font_size_override("font_size", 22)
	_tip.add_theme_color_override("font_color", UiTheme.INK)
	_tip.add_theme_stylebox_override("normal", UiTheme.box(Color("fff8ef"), 18, UiTheme.PINK_DARK, 3, 16))
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_tip)
	(_tip as Label).reset_size()
	var k := _desk_bar.scale.x
	_tip.scale = Vector2(k, k)
	_tip.position = Vector2(_desk_bar.position.x, _desk_bar.position.y - (_tip.size.y + 64.0) * k)
	for i in 3:
		_leave.pivot_offset = _leave.size * 0.5
		var tw := _leave.create_tween()
		tw.tween_property(_leave, "scale", Vector2(1.1, 1.1), 0.25).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_leave, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)
		await tw.finished
		if _tip == null:
			return
	var t := 0.0
	while _tip and t < 5.5:
		await get_tree().process_frame
		t += get_process_delta_time()
	_drop_tip()

func _drop_tip() -> void:
	if _tip:
		_tip.queue_free()
		_tip = null

func _input(e: InputEvent) -> void:
	if _tip and ((e is InputEventMouseButton and e.pressed) or (e is InputEventKey and e.pressed)):
		_drop_tip()

func _count_sit() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	_sits = int(cfg.get_value("tips", "desk_sits", 0)) + 1
	cfg.set_value("tips", "desk_sits", _sits)
	cfg.save(CFG)

func _nearest() -> Dictionary:
	var pp: Vector3 = office.player.global_position
	for s in seats:
		if Vector2(pp.x - _spot(s).x, pp.z - _spot(s).z).length() < REACH:
			return s
	return {}

func _process(delta: float) -> void:
	var seated_ui: bool = working and not _busy and not (office.morning and office.morning.busy)
	_desk_bar.visible = seated_ui
	if seated_ui:
		_place_bar()
	else:
		_app_hint.visible = false
	if _busy or (office.morning and office.morning.busy):
		_hint.visible = false
		return
	if working:
		_hint.visible = false
		_bar.value = progress * 100.0
		_keys_rate = maxf(0.0, _keys_rate - delta * maxf(2.0, _keys_rate))
		var a: AnimationPlayer = office.player.chibi.anim
		a.speed_scale = lerpf(a.speed_scale, 1.0 + clampf(_keys_rate / 8.0, 0.0, 0.8), 1.0 - exp(-delta * 6.0))
		return
	var s := _nearest()
	_hint_at(tr("WORK_SIT"), 0.5)
	_hint.visible = not s.is_empty() and office.player.controls

func _hint_at(text: String, x: float) -> void:
	"""The hint centred at x (of the view's width), kept whole on screen."""
	_hint.text = text
	_hint.reset_size()
	var vw := get_viewport().get_visible_rect().size.x
	var w := _hint.size.x
	var at := clampf(x * vw, w * 0.5 + 16.0, maxf(w * 0.5 + 16.0, vw - w * 0.5 - 16.0)) / vw
	_hint.anchor_left = at
	_hint.anchor_right = at
	_hint.reset_size()

func _unhandled_input(e: InputEvent) -> void:
	if _busy or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if office.morning and office.morning.busy:
		return
	var k: int = e.physical_keycode
	if working and k == KEY_ESCAPE and pc.zoomed and pc.shown:
		get_viewport().set_input_as_handled()
		pc.set_zoom(false)
	elif working and k == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		stand_up()
	elif working and k == KEY_TAB:
		get_viewport().set_input_as_handled()
		_show_screen(not pc.shown)
	elif working and pc.shown:
		if (k >= KEY_A and k <= KEY_Z) or (k >= KEY_0 and k <= KEY_9) or k in TYPE_KEYS:
			get_viewport().set_input_as_handled()
			pc.type_keys(1)
			_keys_rate += 1.0
	elif working and k in [KEY_F, KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		stand_up()
	elif not working and k == KEY_F:
		var s := _nearest()
		if not s.is_empty() and office.player.controls:
			get_viewport().set_input_as_handled()
			sit_down(s)

func _clicked(s: Dictionary) -> void:
	if working:
		stand_up()
		return
	var p: Player = office.player
	var at := _spot(s)
	if Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() >= REACH:
		await p.go_to(at, false, 0.2)
		if Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() >= REACH:
			return
	if not _busy and not working and p.controls:
		sit_down(s)

func sit_down(s: Dictionary) -> void:
	_busy = true
	_seat = s
	var p: Player = office.player
	p.controls = false
	p.set_physics_process(false)
	p.sitting = false
	var chair: Node3D = s["chair"]
	var home := chair.transform if chair else Transform3D()
	if chair:
		s["home"] = home
		var fwd := Vector3(sin(s["yaw"]), 0, cos(s["yaw"]))
		var out := Transform3D(home.basis.rotated(Vector3.UP, deg_to_rad(-25.0)), home.origin + fwd.cross(Vector3.UP) * 0.48 - fwd * 0.2)
		create_tween().tween_property(chair, "transform", out, 0.25)
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "global_position", _spot(s), 0.3)
	tw.tween_property(p, "rotation:y", p.rotation.y + angle_difference(p.rotation.y, s["yaw"]), 0.3)
	p.chibi.play("Move_Walk", 0.1)
	await tw.finished
	p.global_position = s["pos"]
	p.rotation.y = s["yaw"]
	p.facing = s["yaw"]
	if chair:
		create_tween().tween_property(chair, "transform", home, 0.6).set_trans(Tween.TRANS_SINE)
	await _clip("Act_SitChair_Down")
	if not Story.opening_done:
		Story.set_beat("done")
	p.chibi.play("Act_SitChair_Type", 0.2)
	working = true
	_count_sit()
	_first_sit_tip()
	_panel.visible = office.morning == null or office.morning.show_bar
	_zoom_before = office.cam_zoom
	_light_monitor(s)
	pc.working = true
	_show_screen(Stage.arg("--pc") != "away")
	_busy = false

func _show_screen(on: bool) -> void:
	"""The computer's screen up on the right (the view widens a little and slides the hero left), or put
	away (the camera leans in to the desk)."""
	if on:
		pc.open()
	else:
		pc.close()
	office.cam_side = SIDE if on else 0.0
	office.cam_zoom = minf(_zoom_before, 0.86 if on else 0.72)

func _light_monitor(s: Dictionary) -> void:
	"""From now on the desk's own monitor shows the screen live (its taskbar clock is the screen's own)."""
	if s.has("monitor"):
		return
	var desk: Vector3 = s["pos"] + Vector3(sin(s["yaw"]), 0, cos(s["yaw"])) * office.SEAT_OFF + Vector3(0, 0.93, 0)
	var best: MeshInstance3D = null
	var best_d := 0.8
	for mi: MeshInstance3D in office.world.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is QuadMesh and mi.material_override is ShaderMaterial and mi.global_position.distance_to(desk) < best_d:
			best = mi
			best_d = mi.global_position.distance_to(desk)
	if best == null:
		return
	s["monitor"] = best
	best.material_override = pc.live_material(best.material_override)
	for l in best.get_parent().get_children():
		if l is Label3D and (l as Label3D).position.distance_to(best.position) < 0.4:
			(l as Label3D).visible = false

func stand_up() -> void:
	_drop_tip()
	_busy = true
	working = false
	pc.working = false
	pc.close()
	office.cam_side = 0.0
	var p: Player = office.player
	p.chibi.anim.speed_scale = 1.0
	var s := _seat
	var chair: Node3D = s.get("chair")
	if chair:
		var home: Transform3D = s["home"]
		var fwd := Vector3(sin(s["yaw"]), 0, cos(s["yaw"]))
		var out := Transform3D(home.basis.rotated(Vector3.UP, deg_to_rad(-25.0)), home.origin + fwd.cross(Vector3.UP) * 0.48 - fwd * 0.2)
		create_tween().tween_property(chair, "transform", out, 0.35).set_trans(Tween.TRANS_SINE)
	await _clip("Act_SitChair_Up")
	p.global_position = _spot(s)
	p.chibi.play("Base_Wait", 0.0)
	if chair:
		create_tween().tween_property(chair, "transform", s["home"], 0.5).set_delay(0.3).set_trans(Tween.TRANS_SINE)
	office.cam_zoom = _zoom_before
	_panel.visible = progress > 0.0 and (office.morning == null or office.morning.show_bar)
	p.set_physics_process(true)
	p.controls = true
	_busy = false

func _clip(name: String) -> void:
	var a: AnimationPlayer = office.player.chibi.anim
	if not a.has_animation(name):
		return
	a.speed_scale = 1.0
	a.play(name, 0.12)
	await get_tree().create_timer(a.get_animation(name).length).timeout
