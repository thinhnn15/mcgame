class_name FarmPlace
extends CanvasLayer

signal toggled(on: bool)

const LIFT := 0.25
const HAND_SPEED := 900.0
const OK := Color(0.45, 0.9, 0.55, 0.5)
const BAD := Color(1.0, 0.4, 0.4, 0.55)
const HOVER := Color(1.0, 0.9, 0.55, 0.45)
const DOOR := Color(1.0, 1.0, 0.9, 0.35)
const INK := Color("5b4a44")
const PAPER := Color("fff6e6")
const PICK := Color("ffd98a")
const VIEW := Vector3(0, 16.0, 12.0)
const GRID_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float cell = 0.5;
uniform vec4 line : source_color = vec4(1.0, 0.98, 0.9, 0.5);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = wp.xz / cell;
	vec2 d = abs(fract(g + 0.5) - 0.5) / fwidth(g);
	ALBEDO = line.rgb;
	ALPHA = (1.0 - min(min(d.x, d.y), 1.0)) * line.a;
}
"""

var pens: FarmPens
var cam: Camera3D
var player: Player
var active := false
var kho := {}
var held: FarmPens.Pen = null
var _new := false
var _back_cell := Vector2i.ZERO
var _back_rot := 0
var _rot := 0
var _ok := false
var _hover: FarmPens.Pen = null
var _pointer := Vector2(960, 540)
var _hand := false
var _sel := 0
var _ids: Array = []
var _grid: MeshInstance3D
var _mark: MeshInstance3D
var _door: MeshInstance3D
var _mark_mat: StandardMaterial3D
var _button: Button
var _turn_button: Button
var _help: PanelContainer
var _hint: Label
var _why: Label
var _bar: PanelContainer
var _cards: HBoxContainer
var _toast: Label
var _toast_tw: Tween
var _hand_icon: Control
var book: SoTho
var _acts: PanelContainer
var _acts_for: FarmPens.Pen = null
var _new_nen := false

func setup(the_pens: FarmPens, camera: Camera3D, hero: Player) -> void:
	pens = the_pens
	cam = camera
	player = hero
	_grid = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = pens.bounds.size
	_grid.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = Shader.new()
	gm.shader.code = GRID_SHADER
	_grid.material_override = gm
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var c := pens.bounds.get_center()
	_grid.position = Vector3(c.x, 0.03, c.y)
	_grid.visible = false
	pens.add_child(_grid)
	_mark_mat = StandardMaterial3D.new()
	_mark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mark_mat.render_priority = 1
	_mark_mat.no_depth_test = true
	_mark = _flat_box(_mark_mat)
	var dm := _mark_mat.duplicate() as StandardMaterial3D
	dm.albedo_color = DOOR
	_door = _flat_box(dm)
	_build_ui()
	book = SoTho.new()
	add_child(book)
	book.closed.connect(func() -> void:
		if active:
			_fill_kho()
			_show_acts(_hover, true))

func _flat_box(m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	pens.add_child(mi)
	return mi

func view() -> Array:
	var c := pens.bounds.get_center()
	return [Vector3(c.x, 0, c.y - 1.5) + VIEW, Vector3(c.x, 0, c.y - 1.5)]

func open() -> void:
	if active:
		return
	active = true
	player.controls = false
	player.stop_going()
	_grid.visible = true
	_help.visible = true
	_bar.visible = true
	_button.text = tr("PLACE_DONE")
	_fill_kho()
	_refresh_hint()
	toggled.emit(true)

func close() -> void:
	if not active:
		return
	if held:
		_put_back()
	active = false
	player.controls = true
	_grid.visible = false
	_mark.visible = false
	_door.visible = false
	_help.visible = false
	_bar.visible = false
	_hand_icon.visible = false
	_button.text = tr("PLACE_OPEN")
	_hover = null
	toggled.emit(false)

func _unhandled_input(e: InputEvent) -> void:
	if book and book.visible:
		return
	if not active:
		if (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_B) \
				or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_BACK):
			if player.controls:
				open()
				get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseMotion or e is InputEventScreenDrag:
		_pointer = e.position
		_hand = false
	elif e is InputEventMouseButton and e.pressed:
		_pointer = e.position
		_hand = false
		match e.button_index:
			MOUSE_BUTTON_LEFT: _primary(false)
			MOUSE_BUTTON_RIGHT: _put_back()
			MOUSE_BUTTON_WHEEL_UP: _turn()
			MOUSE_BUTTON_WHEEL_DOWN: _turn()
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_B: close()
			KEY_ESCAPE: _back_or_close()
			KEY_F, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: _primary(true)
			KEY_R: _turn()
			KEY_Q: _pick_card(_sel - 1)
			KEY_E: _pick_card(_sel + 1)
	elif e is InputEventJoypadButton and e.pressed:
		match e.button_index:
			JOY_BUTTON_BACK: close()
			JOY_BUTTON_A: _primary(true)
			JOY_BUTTON_B: _back_or_close()
			JOY_BUTTON_X: _turn()
			JOY_BUTTON_LEFT_SHOULDER: _pick_card(_sel - 1)
			JOY_BUTTON_RIGHT_SHOULDER: _pick_card(_sel + 1)
	else:
		return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active:
		return
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A): v.x -= 1
	if Input.is_physical_key_pressed(KEY_D): v.x += 1
	if Input.is_physical_key_pressed(KEY_W): v.y -= 1
	if Input.is_physical_key_pressed(KEY_S): v.y += 1
	if v.length() > 0.15:
		_hand = true
		var vp := get_viewport().get_visible_rect().size
		_pointer = (_pointer + v.limit_length(1.0) * HAND_SPEED * delta).clamp(Vector2.ZERO, vp)
	_hand_icon.visible = _hand
	_hand_icon.position = _pointer - Vector2(18, 18)
	if book and book.visible:
		return
	var at := _ground()
	if held:
		var cell := FarmPens.cell_for(held.kind, _rot, at)
		pens.place(held, cell, _rot, LIFT)
		var why := pens.check(held.kind, cell, _rot, held)
		_ok = why == ""
		_why.text = "" if _ok else tr(why)
		_show_mark(held.kind, cell, _rot, OK if _ok else BAD)
	else:
		var was := _hover
		_hover = pens.pen_at(at)
		if _hover:
			_show_mark(_hover.kind, _hover.cell, _hover.rot, HOVER)
		else:
			_mark.visible = false
			_door.visible = false
		if _hover != was:
			_show_acts(_hover, false)

func _ground() -> Vector2:
	var from := cam.project_ray_origin(_pointer)
	var dir := cam.project_ray_normal(_pointer)
	if dir.y > -0.01:
		return Vector2(from.x, from.z)
	var p := from + dir * (-from.y / dir.y)
	return Vector2(p.x, p.z)

func _primary(by_hand: bool) -> void:
	if held:
		if _ok:
			_drop()
		else:
			Sound.play("mg.bad", -8.0)
			_say(_why.text)
		return
	var p := pens.pen_at(_ground())
	if p:
		if p.state == "dang_xay" or _booked_index() == pens.pens.find(p):
			Sound.play("mg.bad", -8.0)
			_say(tr("PEN_BAD_BUILDING"))
			return
		_pick_up(p)
	elif by_hand and _sel < _ids.size():
		_take(_ids[_sel])

func _pick_up(p: FarmPens.Pen) -> void:
	held = p
	held.held = true
	_new = false
	_back_cell = p.cell
	_back_rot = p.rot
	_rot = p.rot
	Sound.play("ui.click", -6.0)
	_refresh_hint()

func _take(kind: String) -> void:
	if held:
		_put_back()
	_rot = 0
	if kind.begins_with("+"):
		var k := kind.substr(1)
		held = pens.add(k, FarmPens.cell_for(k, 0, _ground()), 0, false, "nen")
		held.held = true
		_new = true
		_new_nen = true
		_show_acts(null, false)
		Sound.play("ui.click", -6.0)
		_refresh_hint()
		return
	if int(kho.get(kind, 0)) <= 0:
		return
	kho[kind] = int(kho[kind]) - 1
	held = pens.add(kind, FarmPens.cell_for(kind, 0, _ground()), 0, false)
	held.held = true
	_new = true
	_new_nen = false
	_fill_kho()
	Sound.play("ui.click", -6.0)
	_refresh_hint()

func _drop() -> void:
	pens.place(held, held.cell, _rot)
	held.held = false
	var staked := _new_nen
	if _new and _new_nen:
		_say(tr("PLACE_STAKED"))
	elif _new:
		pens.stock(held)
		_say(tr("PLACE_PUT") % tr(FarmPens.KINDS[held.kind]["name"]))
	else:
		pens.settle(held)
	var n := held.node
	n.scale = Vector3.ONE * 1.04
	n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sound.play("ui.click", -2.0)
	var dropped := held
	held = null
	_new_nen = false
	_why.text = ""
	_mark.visible = false
	_door.visible = false
	_refresh_hint()
	if staked:
		_open_book_for(dropped, dropped.kind)

func _put_back() -> void:
	if held == null:
		return
	if _new and _new_nen:
		pens.remove(held)
	elif _new:
		kho[held.kind] = int(kho.get(held.kind, 0)) + 1
		pens.remove(held)
		_fill_kho()
	else:
		pens.place(held, _back_cell, _back_rot)
		held.held = false
	held = null
	_new_nen = false
	_why.text = ""
	_mark.visible = false
	_door.visible = false
	_refresh_hint()

func _back_or_close() -> void:
	if held:
		_put_back()
	else:
		close()

func _turn() -> void:
	if held == null:
		return
	_rot = (_rot + 1) % 4
	Sound.play("ui.click", -10.0)

func _booked_index() -> int:
	if not ClassDB.class_exists("PenWork"):
		return -1
	var b: Dictionary = ClassDB.class_call_static("PenWork", "booked")
	return int(b.get("pen", -1)) if not b.is_empty() else -1

func _show_acts(p: FarmPens.Pen, force: bool) -> void:
	if p == _acts_for and not force:
		return
	_acts_for = p
	for c in _acts.get_child(0).get_children():
		c.queue_free()
	_acts.visible = false
	if p == null or held != null:
		return
	var idx := pens.pens.find(p)
	var kd: Dictionary = FarmPens.KINDS[p.kind]
	var booked := _booked_index() == idx
	if p.state == "nen":
		_acts.get_child(0).add_child(_act_button(tr("SO_THO_BOOKED") if booked else tr("PLACE_BOOK"),
			func() -> void: _open_book_for(p, p.kind)))
		if not booked:
			_acts.get_child(0).add_child(_act_button(tr("PLACE_UNSTAKED"), func() -> void:
				pens.remove(p)
				_show_acts(null, true)
				Sound.play("ui.click", -6.0)))
	elif p.state == "xong" and not booked:
		var nxt := FarmPens.next_kind(p.kind)
		if nxt != "" and ClassDB.class_exists("PenWork"):
			_acts.get_child(0).add_child(_act_button(tr("PLACE_UPGRADE") + ": " + tr(FarmPens.KINDS[nxt]["name"]), func() -> void:
				var why := pens.check(nxt, p.cell, p.rot, p)
				if why != "":
					Sound.play("mg.bad", -8.0)
					_say(tr("PEN_BAD_UPGRADE_ROOM") if why == "PEN_BAD_PEN" or why == "PEN_BAD_OUT" else tr(why))
					return
				_open_book_for(p, nxt)))
		if int(kd.get("days", 0)) > 0:
			_acts.get_child(0).add_child(_act_button(tr("PLACE_DEMOLISH"), func() -> void:
				if pens.demolish(p):
					Sound.play("ui.click", -4.0)
					_say(tr("PLACE_DEMOLISHED"))
					_show_acts(null, true)
				else:
					Sound.play("mg.bad", -8.0)
					_say(tr("PLACE_NOT_EMPTY"))))
	elif p.state == "xong" and booked:
		_acts.get_child(0).add_child(_act_button(tr("SO_THO_BOOKED"), func() -> void: _open_book_for(p, p.kind)))
	_acts.visible = _acts.get_child(0).get_child_count() > 0

func _open_book_for(p: FarmPens.Pen, kind: String) -> void:
	var idx := pens.pens.find(p)
	var req := {"kind": kind, "cell": p.cell, "rot": p.rot, "pen": idx}
	if kind != p.kind:
		req["upgrade_from"] = p.kind
	book.open_pen(req)

func _act_button(text: String, on_press: Callable) -> Button:
	var b := _chip(text, 18)
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(on_press)
	TouchControls.claim(b)
	return b

func _show_mark(kind: String, cell: Vector2i, rot: int, col: Color) -> void:
	var r := FarmPens.rect_of(kind, cell, rot)
	(_mark.mesh as BoxMesh).size = Vector3(r.size.x - 0.04, 0.01, r.size.y - 0.04)
	_mark.position = Vector3(r.get_center().x, 0.05, r.get_center().y)
	_mark_mat.albedo_color = col
	_mark.visible = true
	var d := FarmPens.door_rect(kind, cell, rot)
	_door.visible = d.has_area()
	if d.has_area():
		(_door.mesh as BoxMesh).size = Vector3(d.size.x - 0.04, 0.01, d.size.y - 0.04)
		_door.position = Vector3(d.get_center().x, 0.05, d.get_center().y)

func _say(text: String) -> void:
	if text == "":
		return
	_toast.text = text
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tw.tween_interval(1.8)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.4)

func _refresh_hint() -> void:
	var touch: bool = TouchControls.active
	_hint.text = tr(("PLACE_HINT_HELD" if held else "PLACE_HINT") + ("_TOUCH" if touch else ""))
	_turn_button.visible = held != null and touch

func _build_ui() -> void:
	_button = _chip(tr("PLACE_OPEN"), 22)
	_button.anchor_left = 0.5
	_button.anchor_right = 0.5
	_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_button.offset_top = 16
	_button.pressed.connect(_on_button)
	add_child(_button)
	_turn_button = _chip(tr("PLACE_TURN"), 24)
	_turn_button.anchor_left = 1.0
	_turn_button.anchor_right = 1.0
	_turn_button.anchor_top = 0.5
	_turn_button.anchor_bottom = 0.5
	_turn_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_turn_button.offset_right = -24
	_turn_button.custom_minimum_size = Vector2(120, 72)
	_turn_button.pressed.connect(_turn)
	_turn_button.visible = false
	add_child(_turn_button)
	_help = PanelContainer.new()
	_help.add_theme_stylebox_override("panel", UiTheme.box(Color(PAPER, 0.92), 14, Color("e3cfae"), 2, 14))
	_help.position = Vector2(20, 16)
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_child(col)
	var title := _label(26)
	title.text = tr("PLACE_TITLE")
	col.add_child(title)
	_hint = _label(17)
	col.add_child(_hint)
	_why = _label(20)
	_why.add_theme_color_override("font_color", Color("c0504a"))
	col.add_child(_why)
	_help.visible = false
	add_child(_help)
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", UiTheme.box(Color(PAPER, 0.94), 18, Color("e3cfae"), 2, 12))
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.offset_top = -136
	_bar.offset_bottom = -16
	var bar_col := VBoxContainer.new()
	_bar.add_child(bar_col)
	var kho_title := _label(17)
	kho_title.text = tr("PLACE_KHO")
	bar_col.add_child(kho_title)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	bar_col.add_child(_cards)
	_bar.visible = false
	add_child(_bar)
	_toast = _label(24)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 0.62
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", PAPER)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.modulate.a = 0.0
	add_child(_toast)
	_acts = PanelContainer.new()
	_acts.add_theme_stylebox_override("panel", UiTheme.box(Color(PAPER, 0.94), 14, Color("e3cfae"), 2, 10))
	_acts.anchor_left = 1.0
	_acts.anchor_right = 1.0
	_acts.anchor_top = 0.5
	_acts.anchor_bottom = 0.5
	_acts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_acts.grow_vertical = Control.GROW_DIRECTION_BOTH
	_acts.offset_right = -24
	_acts.offset_top = 60
	var acol := VBoxContainer.new()
	acol.add_theme_constant_override("separation", 8)
	_acts.add_child(acol)
	_acts.visible = false
	add_child(_acts)
	_hand_icon = Control.new()
	_hand_icon.size = Vector2(36, 36)
	_hand_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_icon.draw.connect(_draw_hand)
	_hand_icon.visible = false
	add_child(_hand_icon)
	TouchControls.claim(_button)
	TouchControls.claim(_turn_button)
	TouchControls.claim(_bar)

func _chip(text: String, px: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", px)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, INK)
	b.add_theme_stylebox_override("normal", UiTheme.box(Color(PAPER, 0.94), 16, Color("e3cfae"), 2, 14))
	b.add_theme_stylebox_override("hover", UiTheme.box(PICK, 16, Color("e3b96a"), 2, 14))
	b.add_theme_stylebox_override("pressed", UiTheme.box(PICK, 16, Color("e3b96a"), 3, 14))
	return b

func _on_button() -> void:
	if active:
		close()
	elif player.controls:
		open()

func _draw_hand() -> void:
	_hand_icon.draw_circle(Vector2(18, 18), 13.0, Color(PAPER, 0.9))
	_hand_icon.draw_arc(Vector2(18, 18), 13.0, 0.0, TAU, 32, INK, 3.0, true)
	_hand_icon.draw_circle(Vector2(18, 18), 3.5, INK)

func _label(px: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _fill_kho() -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	_ids = []
	for k in FarmPens.ORDER:
		if int(kho.get(k, 0)) > 0:
			_ids.append(k)
	var kho_n := _ids.size()
	if ClassDB.class_exists("PenWork"):
		for k in FarmPens.ORDER:
			var kd: Dictionary = FarmPens.KINDS[k]
			if int(kd.get("days", 0)) <= 0 or kd.has("prev"):
				continue
			if String(ClassDB.class_call_static("PenWork", "check", k).get("reason", "")) == "locked":
				continue
			_ids.append("+" + k)
	_sel = clampi(_sel, 0, maxi(0, _ids.size() - 1))
	if _ids.is_empty():
		var l := _label(18)
		l.text = tr("PLACE_KHO_EMPTY")
		_cards.add_child(l)
		return
	for i in _ids.size():
		var k: String = _ids[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		if k.begins_with("+"):
			b.text = "%s\n%s" % [tr("PLACE_BUILD_NEW"), tr(FarmPens.KINDS[k.substr(1)]["name"])]
		else:
			b.text = "%s\n×%d" % [tr(FarmPens.KINDS[k]["name"]), int(kho[k])]
		if i == kho_n and kho_n > 0:
			var sep := _label(17)
			sep.text = " · "
			_cards.add_child(sep)
		b.custom_minimum_size = Vector2(150, 66)
		b.add_theme_font_size_override("font_size", 17)
		for key in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(key, INK)
		var on := i == _sel and _hand
		b.add_theme_stylebox_override("normal", UiTheme.box(PICK if on else Color.WHITE, 12, Color("e3cfae"), 3 if on else 2, 10))
		b.add_theme_stylebox_override("hover", UiTheme.box(Color("fff0d6"), 12, Color("e3b96a"), 3, 10))
		b.add_theme_stylebox_override("pressed", UiTheme.box(PICK, 12, Color("e3b96a"), 3, 10))
		b.pressed.connect(_on_card.bind(i, k))
		_cards.add_child(b)

func _on_card(i: int, k: String) -> void:
	_sel = i
	_take(k)

func _pick_card(i: int) -> void:
	if _ids.is_empty():
		return
	_sel = posmod(i, _ids.size())
	_hand = true
	_fill_kho()
