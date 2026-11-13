class_name DecorMode
extends CanvasLayer

signal toggled(on: bool)

const LIFT := 0.12
const HAND_SPEED := 900.0
const OK := Color(0.45, 0.9, 0.55, 0.5)
const BAD := Color(1.0, 0.4, 0.4, 0.55)
const HOVER := Color(1.0, 0.9, 0.55, 0.45)
const INK := Color("5b4a44")
const PAPER := Color("fff6e6")
const PICK := Color("ffd98a")
const THROW_HOLD := 0.9
const THUMBS := "res://props/furniture/thumbs/"
const TABS := ["all", "floor", "rug", "small", "wall", "nen", "san"]
const GRID_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float cell = 0.5;
uniform vec4 line : source_color = vec4(1.0, 0.98, 0.9, 0.55);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = wp.xz / cell;
	vec2 d = abs(fract(g + 0.5) - 0.5) / fwidth(g);
	ALBEDO = line.rgb;
	ALPHA = (1.0 - min(min(d.x, d.y), 1.0)) * line.a;
}
"""

var room: DecorRoom
var cam: Camera3D
var player: Player
var active := false
var held: DecorRoom.Entry = null
var _back := {}
var _back_rot := 0
var _spot := {}
var _hover: DecorRoom.Entry = null
var _pointer := Vector2(960, 540)
var _hand := false
var _sel := 0
var _ids: Array = []
var _grid: MeshInstance3D
var _mark: MeshInstance3D
var _mark_mat: StandardMaterial3D
var _button: Button
var _help: PanelContainer
var _hint: Label
var _bar: PanelContainer
var _cards: HBoxContainer
var _toast: Label
var _toast_tw: Tween
var _hand_icon: Control
var _pending := ""
var _tab := "all"
var _query := ""
var _hold_t := -1.0
var _acts: HBoxContainer
var _act := {}
var _count: Label
var _tab_btns := {}
var _search: LineEdit
var _ask: PanelContainer
var _ask_label: Label
var _ask_id := ""
var _thumbs := {}
var shop: PhotoShop
var _print_btn: Button
var _paint: PanelContainer
var _paint_row: HBoxContainer
var _paint_cost: Label
var _paint_opts: Array = []
var _paint_from := ""
var _paint_sel := 0
var _fix: PanelContainer
var _fix_text: Label
var _fix_btn: Button
var _fix_of: DecorRoom.Entry = null
var _hammer: Texture2D
var _nen_one := false
var _nen_face := -1
var _nen_before := ""
var _nen_bar: PanelContainer
var _nen_cost: Label

func setup(the_room: DecorRoom, camera: Camera3D, hero: Player) -> void:
	room = the_room
	cam = camera
	player = hero
	_grid = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(room.size) * DecorRoom.CELL
	_grid.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = Shader.new()
	gm.shader.code = GRID_SHADER
	_grid.material_override = gm
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid.position = room.floor_point(Vector2(room.size) / 2.0) + Vector3(0, 0.004, 0)
	_grid.visible = false
	room.add_child(_grid)
	_mark = MeshInstance3D.new()
	_mark.mesh = BoxMesh.new()
	_mark_mat = StandardMaterial3D.new()
	_mark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mark_mat.render_priority = 1
	_mark.material_override = _mark_mat
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.visible = false
	room.add_child(_mark)
	_build_ui()
	room.received.connect(_on_received)
	_offer_news.call_deferred()

func open() -> void:
	if active:
		return
	active = true
	player.controls = false
	player.stop_going()
	_grid.visible = true
	_help.visible = true
	_bar.visible = true
	_acts.visible = true
	_ask.visible = false
	_print_btn.visible = not PhotoPrint.album().is_empty()
	_button.text = tr("DECOR_DONE")
	var moved := room.tidy_san()
	if _tab == "san" and room.san.is_empty():
		_tab = "all"
	_fill_kho()
	_refresh_hint()
	if moved > 0:
		_say(tr("DECOR_SAN_TIDY") % moved)
	_badges(true)
	toggled.emit(true)

func close() -> void:
	_paint_cancel()
	_nen_end()
	if not active:
		return
	if held:
		_put_back()
	active = false
	player.controls = true
	_grid.visible = false
	_mark.visible = false
	_help.visible = false
	_bar.visible = false
	_acts.visible = false
	_print_btn.visible = false
	room.loose = false
	_hand_icon.visible = false
	_hold_t = -1.0
	_search.release_focus()
	_button.text = tr("DECOR_OPEN")
	_set_hover(null)
	room.grid.forget()
	_badges(false)
	_fix.visible = false
	room.save()
	toggled.emit(false)
	_offer_news()

func _unhandled_input(e: InputEvent) -> void:
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
			MOUSE_BUTTON_WHEEL_UP: _turn(1)
			MOUSE_BUTTON_WHEEL_DOWN: _turn(-1)
	elif e is InputEventScreenTouch and e.pressed:
		_pointer = e.position
		_hand = false
		_primary(false)
	elif e is InputEventKey and not e.pressed and e.physical_keycode == KEY_K:
		_hold_stop()
	elif e is InputEventJoypadButton and not e.pressed and e.button_index == JOY_BUTTON_DPAD_DOWN:
		_hold_stop()
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_B: close()
			KEY_ESCAPE: _back_or_close()
			KEY_F, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: _primary(true)
			KEY_R: _turn(1)
			KEY_X, KEY_DELETE, KEY_BACKSPACE: _to_kho()
			KEY_G: _give()
			KEY_K: _hold_start()
			KEY_Z: _undo()
			KEY_L: _toggle_loose()
			KEY_P: _open_shop()
			KEY_V: _paint_ok() if _paint.visible else _paint_open()
			KEY_Q: _paint_pick(_paint_sel - 1) if _paint.visible else _pick_card(_sel - 1)
			KEY_E: _paint_pick(_paint_sel + 1) if _paint.visible else _pick_card(_sel + 1)
	elif e is InputEventJoypadButton and e.pressed:
		match e.button_index:
			JOY_BUTTON_BACK: close()
			JOY_BUTTON_A: _primary(true)
			JOY_BUTTON_B: _back_or_close()
			JOY_BUTTON_X: _turn(1)
			JOY_BUTTON_Y: _to_kho()
			JOY_BUTTON_DPAD_UP: _give()
			JOY_BUTTON_DPAD_DOWN: _hold_start()
			JOY_BUTTON_LEFT_STICK: _undo()
			JOY_BUTTON_RIGHT_STICK: _paint_ok() if _paint.visible else _paint_open()
			JOY_BUTTON_LEFT_SHOULDER: _paint_pick(_paint_sel - 1) if _paint.visible else _pick_card(_sel - 1)
			JOY_BUTTON_RIGHT_SHOULDER: _paint_pick(_paint_sel + 1) if _paint.visible else _pick_card(_sel + 1)
	else:
		return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active:
		return
	if _hold_t >= 0.0:
		_hold_t += delta
		_act["throw"].modulate = Color(1, 1, 1).lerp(Color(1.0, 0.55, 0.5), clampf(_hold_t / THROW_HOLD, 0.0, 1.0))
		if _hold_t >= THROW_HOLD:
			_hold_t = -1.0
			_act["throw"].modulate = Color.WHITE
			_throw()
	var target := held if held else _hover
	for k in ["turn", "kho", "give", "throw"]:
		_act[k].disabled = target == null
	_act["undo"].disabled = not room.grid.can_undo()
	_act["loose"].visible = held != null and DecorRoom.item(held.id)["kind"] == "wall"
	_act["paint"].visible = held != null and DecorRoom.palette(held.id) != ""
	_act["fix"].visible = target != null and DecorRoom.broken(target.id)
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
	var from := cam.project_ray_origin(_pointer)
	var dir := cam.project_ray_normal(_pointer)
	if _tab == "nen" and _nen_one and held == null:
		var face := room.face_at(from, dir)
		if face >= 0:
			_nen_face = face
			room.face_glow.emit(face)
			Sound.play("ui.click", -6.0)
			_fill_kho()
			return
	if held:
		var s := room.candidate(held, from, dir)
		if not s.is_empty():
			_spot = s
		if not _spot.is_empty():
			_apply(held, _spot)
			room.pose(held, LIFT)
			_show_mark(_spot, OK if room.can_place(held, _spot) else BAD)
	else:
		_set_hover(room.entry_at(from, dir))

func _primary(by_hand: bool) -> void:
	_search.release_focus()
	if _paint.visible:
		_paint_ok()
		return
	var from := cam.project_ray_origin(_pointer)
	var dir := cam.project_ray_normal(_pointer)
	if held:
		var s := room.candidate(held, from, dir)
		if not s.is_empty():
			_spot = s
		if room.can_place(held, _spot):
			_drop()
		else:
			Sound.play("mg.bad", -8.0)
			_say(tr("DECOR_NO_ROOM"))
		return
	var e := room.entry_at(from, dir)
	if e:
		_pick_up(e)
	elif by_hand and _sel < _ids.size():
		_take(_ids[_sel], _tab == "san")

func _pick_up(e: DecorRoom.Entry) -> void:
	_pending = room.snapshot()
	held = e
	held.held = true
	_back = {"layer": e.layer, "rect": e.rect, "wall": e.wall, "host": e.host}
	_back_rot = e.rot
	_spot = _back.duplicate()
	if e.host:
		e.host.kids.erase(e)
	_set_hover(null)
	room.pose(held, LIFT)
	Sound.play("ui.click", -6.0)
	_refresh_hint()

func _take(id: String, from_san := false) -> void:
	if held:
		_put_back()
	_pending = room.snapshot()
	var e := room.take(id, from_san)
	if e == null:
		return
	held = e
	held.held = true
	_back = {}
	_spot = room.candidate(held, cam.project_ray_origin(_pointer), cam.project_ray_normal(_pointer))
	if _spot.is_empty():
		_spot = room.candidate(held, room.floor_point(Vector2(room.size) / 2.0) + Vector3(0, 5, 0), Vector3.DOWN)
	_apply(held, _spot)
	room.pose(held, LIFT)
	_badges(true)
	_fill_kho()
	Sound.play("ui.click", -6.0)
	_refresh_hint()

func _drop() -> void:
	held.held = false
	room.put(held, _spot)
	room.remember(_pending)
	_pending = ""
	var n := held.node
	n.scale = Vector3.ONE * 1.06
	n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sound.play("ui.click", -2.0)
	held = null
	_mark.visible = false
	_refresh_hint()

func _put_back() -> void:
	if held == null:
		return
	if _paint.visible:
		_paint_cancel()
		return
	held.held = false
	if _back.is_empty():
		room.store(held)
		_fill_kho()
	else:
		held.rot = _back_rot
		_apply(held, _back)
		room.put(held, _back)
	held = null
	_pending = ""
	_mark.visible = false
	_refresh_hint()

func _back_or_close() -> void:
	if held:
		_put_back()
	else:
		close()

func _turn(step: int) -> void:
	if held == null or DecorRoom.item(held.id)["kind"] == "wall":
		return
	if not held.kids.is_empty():
		_say(tr("DECOR_TURN_KIDS"))
		return
	held.rot = posmod(held.rot + step, 4)
	var sz := DecorRoom.size_of(held.id, held.rot)
	held.rect.size = sz
	if not _spot.is_empty():
		_spot["rect"] = Rect2i(_spot["rect"].position, sz)
	Sound.play("ui.click", -10.0)

func _to_kho() -> void:
	_paint_cancel()
	var e := _let_go()
	if e == null:
		return
	var n := e.kids.size()
	var to_san := room.store(e)
	_fill_kho()
	Sound.play("ui.click", -4.0)
	var name_: String = tr(DecorRoom.item(e.id)["name"])
	if to_san > 0:
		_say(tr("DECOR_TO_SAN") % name_)
	else:
		_say(tr("DECOR_STORED") % name_ + ("" if n == 0 else " (+%d)" % n))
	_refresh_hint()

func _give() -> void:
	_paint_cancel()
	var e := _keepsake_check()
	if e == null:
		return
	e = _let_go()
	room.give(e)
	_fill_kho()
	Sound.play("ui.click", -4.0)
	_say(tr("DECOR_GIVEN") % tr(DecorRoom.item(e.id)["name"]))
	_refresh_hint()

func _throw() -> void:
	var e := _keepsake_check()
	if e == null:
		return
	e = _let_go()
	room.discard(e)
	_fill_kho()
	Sound.play("ui.click", -2.0)
	_say(tr("DECOR_THROWN") % tr(DecorRoom.item(e.id)["name"]))
	_refresh_hint()

func _hold_start() -> void:
	_paint_cancel()
	if _keepsake_check() == null:
		return
	_hold_t = 0.0
	_say(tr("DECOR_HOLD_THROW"))

func _hold_stop() -> void:
	_hold_t = -1.0
	_act["throw"].modulate = Color.WHITE

func _keepsake_check() -> DecorRoom.Entry:
	var e := held if held else _hover
	if e == null:
		_say(tr("DECOR_PICK_FIRST"))
		return null
	var k := DecorRoom.keeps(e.id)
	if k != "":
		Sound.play("mg.bad", -8.0)
		_say(tr("DECOR_KEEP_ONG_BA") if k == "ong_ba" else tr("DECOR_KEEP_QUA"))
		return null
	return e

func _let_go() -> DecorRoom.Entry:
	var e := held if held else _hover
	if e == null:
		return null
	room.remember(_pending if held and _pending != "" else room.snapshot())
	_pending = ""
	held = null
	_mark.visible = false
	_set_hover(null)
	e.held = false
	return e

func _undo() -> void:
	if room.surfaces_previewing():
		_nen_drop()
	if held:
		_put_back()
	_set_hover(null)
	if room.undo():
		_fill_kho()
		_badges(true)
		Sound.play("ui.click", -6.0)
		_say(tr("DECOR_UNDONE"))
	else:
		_say(tr("DECOR_NO_UNDO"))
	_refresh_hint()

func _apply(e: DecorRoom.Entry, s: Dictionary) -> void:
	if s.is_empty():
		return
	var shift: Vector2i = (s["rect"] as Rect2i).position - e.rect.position
	e.layer = s["layer"]
	e.rect = s["rect"]
	e.wall = s.get("wall", "")
	e.host = s.get("host")
	for k in e.kids:
		k.rect = Rect2i(k.rect.position + shift, k.rect.size)

func _set_hover(e: DecorRoom.Entry) -> void:
	_hover = e
	if e == null:
		if held == null:
			_mark.visible = false
		return
	_show_mark({"layer": e.layer, "rect": e.rect, "wall": e.wall, "host": e.host}, HOVER)

func _show_mark(s: Dictionary, col: Color) -> void:
	var r: Rect2i = s["rect"]
	var c := DecorRoom.CELL
	var mid := Vector2(r.position) + Vector2(r.size) / 2.0
	var bm := _mark.mesh as BoxMesh
	if s["layer"] == "wall":
		var w := DecorRoom.WALL_CELL
		bm.size = Vector3(r.size.x * w - 0.03, r.size.y * w - 0.03, 0.01)
		var yaw: float = DecorRoom.WALL_YAW[s["wall"]]
		_mark.rotation = Vector3(0, yaw, 0)
		_mark.position = room.wall_point(s["wall"], mid.x * w, mid.y * w) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.008)
	else:
		bm.size = Vector3(r.size.x * c - 0.04, 0.01, r.size.y * c - 0.04)
		_mark.rotation = Vector3.ZERO
		var y := DecorRoom.top_height(s["host"]) if s["layer"] == "top" else 0.0
		_mark.position = room.floor_point(mid) + Vector3(0, y + 0.01, 0)
	_mark_mat.albedo_color = col
	_mark.visible = true

func _say(text: String) -> void:
	_toast.text = text
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tw.tween_interval(1.8)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.4)

func _refresh_hint() -> void:
	_hint.text = tr("DECOR_HINT_HELD") if held else tr("DECOR_HINT")

func _build_ui() -> void:
	_button = Button.new()
	_button.text = tr("DECOR_OPEN")
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_size_override("font_size", 22)
	_button.add_theme_color_override("font_color", INK)
	_button.add_theme_color_override("font_hover_color", INK)
	_button.add_theme_color_override("font_pressed_color", INK)
	_button.add_theme_stylebox_override("normal", UiTheme.box(Color(PAPER, 0.94), 16, Color("e3cfae"), 2, 14))
	_button.add_theme_stylebox_override("hover", UiTheme.box(PICK, 16, Color("e3b96a"), 2, 14))
	_button.add_theme_stylebox_override("pressed", UiTheme.box(PICK, 16, Color("e3b96a"), 3, 14))
	_button.anchor_left = 1.0
	_button.anchor_right = 1.0
	_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_button.offset_left = -20
	_button.offset_right = -20
	_button.offset_top = 16
	_button.pressed.connect(_on_button)
	add_child(_button)
	_print_btn = _small_button(tr("DECOR_PRINT"))
	_print_btn.anchor_left = 1.0
	_print_btn.anchor_right = 1.0
	_print_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_print_btn.offset_right = -20
	_print_btn.offset_top = 70
	_print_btn.pressed.connect(_open_shop)
	_print_btn.visible = false
	add_child(_print_btn)
	shop = PhotoShop.new()
	add_child(shop)
	shop.closed.connect(func() -> void:
		_acts.visible = active
		_offer_news()
		if room.collect_prints() > 0:
			_fill_kho())
	_help = PanelContainer.new()
	_help.add_theme_stylebox_override("panel", UiTheme.box(Color(PAPER, 0.92), 14, Color("e3cfae"), 2, 14))
	_help.position = Vector2(20, 16)
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_child(col)
	var title := _label(26)
	title.text = tr("DECOR_TITLE")
	col.add_child(title)
	_hint = _label(17)
	col.add_child(_hint)
	_help.visible = false
	add_child(_help)
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", UiTheme.box(Color(PAPER, 0.94), 18, Color("e3cfae"), 2, 12))
	_bar.anchor_right = 1.0
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = 20
	_bar.offset_right = -20
	_bar.offset_top = -196
	_bar.offset_bottom = -16
	var bar_col := VBoxContainer.new()
	_bar.add_child(bar_col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	bar_col.add_child(top)
	_count = _label(18)
	_count.custom_minimum_size.x = 120
	top.add_child(_count)
	for t in TABS:
		var b := _small_button("")
		b.pressed.connect(_on_tab.bind(t))
		_tab_btns[t] = b
		top.add_child(b)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_search = LineEdit.new()
	_search.placeholder_text = tr("DECOR_SEARCH")
	_search.custom_minimum_size = Vector2(200, 0)
	_search.add_theme_font_size_override("font_size", 17)
	_search.add_theme_color_override("font_color", INK)
	_search.add_theme_color_override("font_placeholder_color", Color(INK, 0.5))
	_search.add_theme_stylebox_override("normal", UiTheme.box(Color.WHITE, 10, Color("e3cfae"), 2, 8))
	_search.add_theme_stylebox_override("focus", UiTheme.box(Color.WHITE, 10, Color("e3b96a"), 2, 8))
	_search.text_changed.connect(func(t: String) -> void:
		_query = t.strip_edges().to_lower()
		_fill_kho())
	_search.text_submitted.connect(func(_t: String) -> void: _search.release_focus())
	top.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar_col.add_child(scroll)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	scroll.add_child(_cards)
	_bar.visible = false
	add_child(_bar)

	_acts = HBoxContainer.new()
	_acts.add_theme_constant_override("separation", 8)
	_acts.anchor_left = 1.0
	_acts.anchor_right = 1.0
	_acts.anchor_top = 1.0
	_acts.anchor_bottom = 1.0
	_acts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_acts.offset_right = -20
	_acts.offset_top = -258
	_acts.offset_bottom = -206
	for a in [["loose", "DECOR_LOOSE_OFF"], ["fix", "DECOR_FIX"], ["paint", "DECOR_PAINT"], ["undo", "DECOR_UNDO"], ["turn", "DECOR_TURN"],
			["kho", "DECOR_PUT_AWAY"], ["give", "DECOR_GIVE"], ["throw", "DECOR_THROW"]]:
		var b := _small_button(tr(a[1]))
		b.custom_minimum_size = Vector2(0, 52)
		_act[a[0]] = b
		_acts.add_child(b)
	_act["undo"].pressed.connect(_undo)
	_act["fix"].pressed.connect(_fix_open)
	_act["paint"].pressed.connect(func() -> void: _paint_ok() if _paint.visible else _paint_open())
	_act["loose"].pressed.connect(_toggle_loose)
	_act["turn"].pressed.connect(func() -> void: _turn(1))
	_act["kho"].pressed.connect(_to_kho)
	_act["give"].pressed.connect(_give)
	_act["throw"].button_down.connect(_hold_start)
	_act["throw"].button_up.connect(_hold_stop)
	_acts.visible = false
	add_child(_acts)

	_paint = PanelContainer.new()
	_paint.add_theme_stylebox_override("panel", UiTheme.box(Color(PAPER, 0.96), 16, Color("e3b96a"), 3, 12))
	_paint.anchor_left = 1.0
	_paint.anchor_right = 1.0
	_paint.anchor_top = 1.0
	_paint.anchor_bottom = 1.0
	_paint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_paint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_paint.offset_right = -20
	_paint.offset_bottom = -290
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 8)
	_paint.add_child(pcol)
	_paint_row = HBoxContainer.new()
	_paint_row.add_theme_constant_override("separation", 10)
	pcol.add_child(_paint_row)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	pcol.add_child(prow)
	_paint_cost = _label(17)
	_paint_cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prow.add_child(_paint_cost)
	var cancel := _small_button(tr("DECOR_PAINT_CANCEL"))
	cancel.pressed.connect(_paint_cancel)
	prow.add_child(cancel)
	var done := _small_button(tr("DECOR_PAINT_OK"))
	done.pressed.connect(_paint_ok)
	prow.add_child(done)
	_paint.visible = false
	add_child(_paint)

	_fix = PanelContainer.new()
	_fix.add_theme_stylebox_override("panel", UiTheme.box(Color(PAPER, 0.96), 16, Color("e3b96a"), 3, 14))
	_fix.anchor_left = 1.0
	_fix.anchor_right = 1.0
	_fix.anchor_top = 1.0
	_fix.anchor_bottom = 1.0
	_fix.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fix.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_fix.offset_right = -20
	_fix.offset_bottom = -290
	var fcol := VBoxContainer.new()
	fcol.add_theme_constant_override("separation", 10)
	_fix.add_child(fcol)
	_fix_text = _label(20)
	fcol.add_child(_fix_text)
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 10)
	frow.alignment = BoxContainer.ALIGNMENT_END
	fcol.add_child(frow)
	var fno := _small_button(tr("DECOR_PAINT_CANCEL"))
	fno.pressed.connect(func() -> void: _fix.visible = false)
	frow.add_child(fno)
	_fix_btn = _small_button(tr("DECOR_FIX_GO"))
	_fix_btn.pressed.connect(_fix_go)
	frow.add_child(_fix_btn)
	_fix.visible = false
	add_child(_fix)

	_nen_bar = PanelContainer.new()
	_nen_bar.add_theme_stylebox_override("panel", UiTheme.box(Color(PAPER, 0.96), 16, Color("e3b96a"), 3, 12))
	_nen_bar.anchor_left = 1.0
	_nen_bar.anchor_right = 1.0
	_nen_bar.anchor_top = 1.0
	_nen_bar.anchor_bottom = 1.0
	_nen_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_nen_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_nen_bar.offset_right = -20
	_nen_bar.offset_bottom = -290
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 10)
	_nen_bar.add_child(nrow)
	_nen_cost = _label(18)
	_nen_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nrow.add_child(_nen_cost)
	var ndrop := _small_button(tr("DECOR_NEN_DROP"))
	ndrop.pressed.connect(_nen_drop)
	nrow.add_child(ndrop)
	var nkeep := _small_button(tr("DECOR_NEN_KEEP"))
	nkeep.pressed.connect(_nen_keep)
	nrow.add_child(nkeep)
	_nen_bar.visible = false
	add_child(_nen_bar)

	_ask = PanelContainer.new()
	_ask.add_theme_stylebox_override("panel", UiTheme.box(Color(PAPER, 0.96), 16, Color("e3b96a"), 3, 14))
	_ask.anchor_left = 0.5
	_ask.anchor_right = 0.5
	_ask.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ask.offset_top = 80
	var ask_row := HBoxContainer.new()
	ask_row.add_theme_constant_override("separation", 12)
	_ask.add_child(ask_row)
	_ask_label = _label(20)
	_ask_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ask_row.add_child(_ask_label)
	var yes := _small_button(tr("DECOR_PLACE_NOW"))
	yes.pressed.connect(_ask_yes)
	ask_row.add_child(yes)
	var later := _small_button(tr("DECOR_LATER"))
	later.pressed.connect(_ask_later)
	ask_row.add_child(later)
	_ask.visible = false
	add_child(_ask)
	_toast = _label(24)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 0.62
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", PAPER)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	add_child(_toast)
	_hand_icon = Control.new()
	_hand_icon.size = Vector2(36, 36)
	_hand_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_icon.draw.connect(_draw_hand)
	_hand_icon.visible = false
	add_child(_hand_icon)

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

func _small_button(text: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.add_theme_font_size_override("font_size", 17)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, INK if c != "font_disabled_color" else Color(INK, 0.35))
	b.add_theme_stylebox_override("normal", UiTheme.box(Color.WHITE, 12, Color("e3cfae"), 2, 10))
	b.add_theme_stylebox_override("hover", UiTheme.box(Color("fff0d6"), 12, Color("e3b96a"), 2, 10))
	b.add_theme_stylebox_override("pressed", UiTheme.box(PICK, 12, Color("e3b96a"), 3, 10))
	b.add_theme_stylebox_override("disabled", UiTheme.box(Color(1, 1, 1, 0.6), 12, Color("eee2cc"), 2, 10))
	return b

func _thumb(id: String) -> Texture2D:
	if not _thumbs.has(id) and "@" in id:
		var base := _thumb(DecorRoom.base_id(id))
		var look := DecorRoom.variant_row(DecorRoom.base_id(id), DecorRoom.variant_of(id)).duplicate()
		if look.get("color") is String:
			look["color"] = Color(look["color"])
		_thumbs[id] = ImageTexture.create_from_image(Recolor.apply(base.get_image(), look)) if base else null
	if not _thumbs.has(id):
		var path := THUMBS + id + ".png"
		if ResourceLoader.exists(path):
			_thumbs[id] = load(path)
		elif DecorRoom.item(id).has("frame"):
			_thumbs[id] = DecorRoom.picture(DecorRoom.item(id))
		elif DecorRoom.item(id)["kind"] == "rug":
			var row := DecorRoom.item(id)
			_thumbs[id] = load(Furniture.DIR + String(row.get("skin", row["model"])) + "_alb.png")
		else:
			_thumbs[id] = null
	return _thumbs[id]

func _paint_open() -> void:
	if held == null or DecorRoom.palette(held.id) == "":
		return
	if not DecorRoom.brush_open():
		_say(tr("DECOR_PAINT_NO_BRUSH"))
		return
	_paint_from = DecorRoom.variant_of(held.id)
	_paint_opts = [""]
	for v in DecorRoom.variants(held.id):
		_paint_opts.append(v["id"])
	for c in _paint_row.get_children():
		c.queue_free()
	for i in _paint_opts.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 52)
		var col := Color("fff6e6")
		var open := true
		if i == 0:
			b.icon = _thumb(DecorRoom.base_id(held.id))
			b.expand_icon = true
			b.tooltip_text = tr("DECOR_PAINT_OWN")
		else:
			var v := DecorRoom.variant_row(held.id, _paint_opts[i])
			col = DecorRoom.swatch(v)
			open = DecorRoom.variant_open(v)
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, UiTheme.box(col if open else col.lerp(Color("bdb3a6"), 0.7), 26, INK, 2, 4))
		if not open:
			b.tooltip_text = tr("DECOR_PAINT_LOCKED")
		b.pressed.connect(_paint_pick.bind(i))
		_paint_row.add_child(b)
	var cost := DecorRoom.paint_cost(held.id)
	_paint_cost.text = tr("DECOR_PAINT_FREE") if cost.is_empty() else tr("DECOR_PAINT_COST") % tr("MAT_" + String(cost.keys()[0]).to_upper())
	_paint.visible = true
	_paint_sel = _paint_opts.find(_paint_from)
	_paint_mark()
	Sound.play("ui.click", -6.0)

func _paint_pick(i: int) -> void:
	if not _paint.visible or _paint_opts.is_empty():
		return
	i = wrapi(i, 0, _paint_opts.size())
	if i > 0 and not DecorRoom.variant_open(DecorRoom.variant_row(held.id, _paint_opts[i])):
		_say(tr("DECOR_PAINT_LOCKED"))
		Sound.play("mg.bad", -10.0)
		return
	_paint_sel = i
	room.paint(held, _paint_opts[i])
	room.pose(held, LIFT)
	_paint_mark()
	Sound.play("ui.click", -8.0)

func _paint_mark() -> void:
	for i in _paint_row.get_child_count():
		var b: Button = _paint_row.get_child(i)
		b.scale = Vector2.ONE * (1.15 if i == _paint_sel else 1.0)
		b.pivot_offset = b.custom_minimum_size / 2.0
		b.modulate = Color.WHITE if i == _paint_sel else Color(1, 1, 1, 0.85)
		var st := b.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if st:
			st.border_color = Color("e39a3a") if i == _paint_sel else INK
			st.set_border_width_all(5 if i == _paint_sel else 2)
			b.add_theme_stylebox_override("normal", st)
			b.add_theme_stylebox_override("hover", st)

func _paint_ok() -> void:
	if not _paint.visible:
		return
	_paint.visible = false
	var now := DecorRoom.variant_of(held.id)
	if now == _paint_from:
		return
	var cost := DecorRoom.paint_cost(held.id)
	if now != "" and not DecorRoom.paint_pay(held.id):
		room.paint(held, _paint_from)
		_say(tr("DECOR_PAINT_NEED") % tr("MAT_" + String(cost.keys()[0]).to_upper()))
		Sound.play("mg.bad", -8.0)
		return
	Sound.play("mg.good", -8.0)
	_say(tr("DECOR_PAINTED"))

func _paint_cancel() -> void:
	if not _paint.visible:
		return
	_paint.visible = false
	room.paint(held, _paint_from)

func _fix_open() -> void:
	var e := held if held else _hover
	if e == null or not DecorRoom.broken(e.id):
		return
	_paint_cancel()
	_fix_of = e
	var st := DecorRoom.repair_state(e.id)
	var lines := [tr(DecorRoom.item(e.id)["name"])]
	for m in st["needs"]:
		lines.append(tr("DECOR_FIX_LINE") % [int(st["needs"][m]), tr("MAT_" + String(m).to_upper()), int(st["have"][m])])
	if not st["level_ok"]:
		lines.append(tr("DECOR_FIX_LEVEL_N") % int(st["level"]))
	_fix_text.text = "\n".join(lines)
	_fix_btn.disabled = not st["ok"]
	_fix.visible = true

func _fix_go() -> void:
	_fix.visible = false
	if _fix_of == null:
		return
	var nm := tr(DecorRoom.item(_fix_of.id)["name"])
	match room.repair(_fix_of):
		"ok":
			Sound.play("mg.good", -4.0)
			var key := String(DecorRoom.item(_fix_of.id)["repair"].get("story", ""))
			_say(tr(key) if key != "" and tr(key) != key else tr("DECOR_MENDED") % nm)
			if _fix_of.held:
				room.pose(_fix_of, LIFT)
			_badges(true)
		"level":
			_say(tr("DECOR_FIX_LEVEL"))
		"need":
			Sound.play("mg.bad", -8.0)
			_say(tr("DECOR_FIX_NEED"))
	_fix_of = null

func _badges(show: bool) -> void:
	if _hammer == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var tilt := Transform2D(deg_to_rad(-38.0), Vector2.ZERO)
		for y in 64:
			for x in 64:
				var q := Vector2(x - 31.5, y - 31.5)
				var d := q.length()
				if d >= 30.0:
					continue
				var c := Color("5b4a44") if d > 26.5 else Color("fff6e6")
				var l := tilt * q
				if absf(l.x) < 3.2 and l.y > -8.0 and l.y < 19.0:
					c = Color("9b6a44") if l.x < 1.0 else Color("7d5235")
				if l.y > -16.0 and l.y < -6.0 and l.x > -12.0 and l.x < 9.0:
					c = Color("aeb8bf") if l.y < -13.0 else Color("6f7a82")
				if l.y > -14.0 and l.y < -8.0 and l.x >= 9.0 and l.x < 14.0 + (l.y + 14.0) * 0.6:
					c = Color("6f7a82")
				img.set_pixel(x, y, c)
		_hammer = ImageTexture.create_from_image(img)
	for e in room.entries:
		var b: Sprite3D = e.node.get_node_or_null("Hammer")
		var want := show and DecorRoom.broken(e.id)
		if want and b == null:
			b = Sprite3D.new()
			b.name = "Hammer"
			b.texture = _hammer
			b.pixel_size = 0.0055
			b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			b.no_depth_test = true
			b.render_priority = 10
			var bx := DecorRoom.box(e.id)
			b.position = Vector3(bx.get_center().x, bx.end.y + 0.18, bx.get_center().z + 0.1)
			e.node.add_child(b)
			var tw := b.create_tween().set_loops()
			tw.tween_property(b, "scale", Vector3.ONE * 1.18, 0.6).set_trans(Tween.TRANS_SINE)
			tw.tween_property(b, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_SINE)
		elif not want and b != null:
			b.queue_free()

func _toggle_loose() -> void:
	room.loose = not room.loose
	_act["loose"].text = tr("DECOR_LOOSE_ON" if room.loose else "DECOR_LOOSE_OFF")
	_say(tr("DECOR_LOOSE_ON" if room.loose else "DECOR_LOOSE_OFF"))

func _open_shop() -> void:
	if PhotoPrint.album().is_empty():
		_say(tr("PHOTO_ALBUM_EMPTY"))
		return
	if held:
		_put_back()
	_acts.visible = false
	_ask.visible = false
	shop.open()

func _on_tab(t: String) -> void:
	if t != "nen":
		_nen_end()
	_tab = t
	_sel = 0
	_fill_kho()

func _fill_kho() -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	_count.text = tr("DECOR_KHO_COUNT") % [room.kho_count(), room.kho_cap()]
	var san_n := 0
	for id in room.san:
		san_n += int(room.san[id])
	if _tab == "san" and san_n == 0:
		_tab = "all"
	for t in TABS:
		var b: Button = _tab_btns[t]
		b.text = tr("DECOR_TAB_SAN") % san_n if t == "san" else tr("DECOR_TAB_" + String(t).to_upper())
		b.visible = (t != "san" or san_n > 0) and (t != "nen" or _nen_open())
		b.add_theme_stylebox_override("normal", UiTheme.box(PICK if t == _tab else Color.WHITE, 12, Color("e3cfae"), 2, 10))
	if _tab == "nen":
		_ids = []
		_fill_nen()
		return
	var src: Dictionary = room.san if _tab == "san" else room.kho
	_ids = []
	var order: Array = DecorRoom.catalog().keys()
	for id in src:
		if id not in order:
			order.append(id)
	for id in order:
		if int(src.get(id, 0)) <= 0 or not DecorRoom.known(id):
			continue
		var kind: String = DecorRoom.item(id)["kind"]
		if not room.allowed_here(id):
			continue
		if _tab in ["floor", "rug", "small", "wall"] and kind != _tab and not (_tab == "floor" and kind == "outdoor"):
			continue
		if _query != "" and not (tr(DecorRoom.item(id)["name"]).to_lower().contains(_query) or id.contains(_query)):
			continue
		_ids.append(id)
	_sel = clampi(_sel, 0, maxi(0, _ids.size() - 1))
	if _ids.is_empty():
		var l := _label(18)
		l.text = tr("DECOR_KHO_EMPTY") if room.kho.is_empty() and _query == "" else tr("DECOR_NONE_FOUND")
		_cards.add_child(l)
		return
	for i in _ids.size():
		var id: String = _ids[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		var n := int(src[id])
		b.text = tr(DecorRoom.item(id)["name"]) + ("" if n == 1 else " ×%d" % n)
		b.icon = _thumb(id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 64)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = tr(DecorRoom.item(id)["name"])
		b.custom_minimum_size = Vector2(140, 104 if b.icon else 66)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", INK)
		var on := i == _sel and _hand
		var fresh := id in room.news
		b.add_theme_stylebox_override("normal", UiTheme.box(PICK if on else (Color("fff7e0") if fresh else Color.WHITE), 12,
			Color("e39a3a") if fresh else Color("e3cfae"), 3 if on or fresh else 2, 8))
		b.add_theme_stylebox_override("hover", UiTheme.box(Color("fff0d6"), 12, Color("e3b96a"), 3, 8))
		b.add_theme_stylebox_override("pressed", UiTheme.box(PICK, 12, Color("e3b96a"), 3, 8))
		b.pressed.connect(_on_card.bind(i, id))
		_cards.add_child(b)

func _nen_open() -> bool:
	return not room.is_yard() and (DecorRoom.choice_open("mau_voi") or DecorRoom.choice_open("gach_nen"))

func _fill_nen() -> void:
	var one := _small_button(tr("DECOR_NEN_ONE_FACE"))
	one.toggle_mode = true
	one.button_pressed = _nen_one
	one.add_theme_stylebox_override("pressed", UiTheme.box(PICK, 12, Color("e39a3a"), 3, 8))
	one.toggled.connect(_nen_one_toggle)
	one.visible = room.rs != null
	_cards.add_child(one)
	if _nen_one:
		var which := _label(15)
		which.text = tr("DECOR_NEN_PICK_FACE") if _nen_face < 0 else tr("DECOR_NEN_FACE_" + ["BACK", "LEFT", "RIGHT", "FRONT"][_nen_face])
		which.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cards.add_child(which)
	if room.rs != null:
		var th := _label(16)
		th.text = tr("DECOR_NEN_THEME")
		th.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cards.add_child(th)
		var now_t := room.theme_now()
		for t in room.themes():
			_theme_card(t, t["id"] == now_t)
	for kind in (["wall", "dado", "floor"] if room.rs != null else ["wall", "floor"]):
		var head := _label(16)
		head.text = tr("DECOR_NEN_" + kind.to_upper())
		head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cards.add_child(head)
		if not DecorRoom.choice_open(DecorRoom.SURFACE_CHOICE[kind]):
			var later := _label(15)
			later.text = tr("DECOR_NEN_LATER_" + ("WALL" if kind == "dado" else kind.to_upper()))
			later.modulate.a = 0.7
			later.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_cards.add_child(later)
			continue
		var face := _nen_face if (_nen_one and kind != "floor") else -1
		var now := String(room.surface(kind, face).get("id", ""))
		if kind == "dado":
			_nen_card(kind, {"id": "", "open": true}, now == "")
		for o in room.surface_options(kind):
			_nen_card(kind, o, o["id"] == now)

func _nen_card(kind: String, o: Dictionary, on: bool) -> void:
	var id := String(o["id"])
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(92, 110)
	b.text = tr("DECOR_NEN_NONE") if id == "" else tr("DECOR_" + id.to_upper())
	b.tooltip_text = b.text
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", INK)
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 68)
	if o.has("tile"):
		var path := DecorRoom.tile_path(String(o["tile"]))
		b.icon = load(path) if ResourceLoader.exists(path) else null
		if o.has("hex"):
			for st in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_disabled_color"]:
				b.add_theme_color_override(st, Color(String(o["hex"])))
	elif o.has("hex"):
		var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
		img.fill(Color(String(o["hex"])))
		b.icon = ImageTexture.create_from_image(img)
	b.disabled = not o["open"]
	b.add_theme_stylebox_override("normal", UiTheme.box(PICK if on else Color.WHITE, 12, Color("e39a3a") if on else Color("e3cfae"), 3 if on else 2, 6))
	b.add_theme_stylebox_override("hover", UiTheme.box(Color("fff0d6"), 12, Color("e3b96a"), 3, 6))
	b.add_theme_stylebox_override("disabled", UiTheme.box(Color("ece6dc"), 12, Color("e3cfae"), 2, 6))
	if not o["open"]:
		b.modulate = Color(1, 1, 1, 0.45)
		if o.get("at_stall", false):
			b.tooltip_text = b.text + "\n" + tr("DECOR_NEN_AT_STALL")
	b.pressed.connect(_on_nen.bind(kind, id))
	_cards.add_child(b)

func _theme_card(t: Dictionary, on: bool) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(104, 124)
	b.text = tr("DECOR_" + String(t["id"]).to_upper())
	b.tooltip_text = b.text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", INK)
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 72)
	var path := "res://props/furniture/rooms/bo_mau/%s.png" % String(t["id"])
	b.icon = load(path) if ResourceLoader.exists(path) else null
	b.disabled = not t["open"]
	b.add_theme_stylebox_override("normal", UiTheme.box(PICK if on else Color("fffaf0"), 12, Color("e39a3a") if on else Color("e3cfae"), 3 if on else 2, 6))
	b.add_theme_stylebox_override("hover", UiTheme.box(Color("fff0d6"), 12, Color("e3b96a"), 3, 6))
	b.add_theme_stylebox_override("disabled", UiTheme.box(Color("ece6dc"), 12, Color("e3cfae"), 2, 6))
	if not t["open"]:
		b.modulate = Color(1, 1, 1, 0.45)
	b.pressed.connect(_on_theme.bind(String(t["id"])))
	_cards.add_child(b)

func _on_theme(id: String) -> void:
	if not room.surfaces_previewing():
		_nen_before = room.snapshot()
	if room.preview_theme(id) == "closed":
		Sound.play("mg.bad", -8.0)
		_say(tr("DECOR_PAINT_LOCKED"))
	else:
		Sound.play("ui.click", -8.0)
	_nen_show_bar()
	_fill_kho()

func _nen_one_toggle(on: bool) -> void:
	_nen_one = on
	if not on:
		_nen_face = -1
	room.face_glow.emit(_nen_face if on else -1)
	_fill_kho()
	if on and _nen_face < 0:
		_say(tr("DECOR_NEN_PICK_FACE"))

func _on_nen(kind: String, id: String) -> void:
	var face := -1
	if kind != "floor" and _nen_one:
		if _nen_face < 0:
			Sound.play("mg.bad", -10.0)
			_say(tr("DECOR_NEN_PICK_FACE"))
			return
		face = _nen_face
	if room.rs == null:
		_nen_result(room.set_surface(kind, id))
		_fill_kho()
		return
	if not room.surfaces_previewing():
		_nen_before = room.snapshot()
	var r := room.preview_surface(kind, id, face)
	if r == "closed":
		Sound.play("mg.bad", -8.0)
		_say(tr("DECOR_PAINT_LOCKED"))
	elif r == "ok":
		Sound.play("ui.click", -8.0)
	_nen_show_bar()
	_fill_kho()

func _nen_result(r: String) -> void:
	match r:
		"ok":
			Sound.play("mg.good", -10.0)
		"need":
			Sound.play("mg.bad", -8.0)
			_say(tr("DECOR_NEN_NEED"))
		"closed":
			Sound.play("mg.bad", -8.0)
			_say(tr("DECOR_PAINT_LOCKED"))

func _nen_show_bar() -> void:
	_nen_bar.visible = active and room.surfaces_previewing()
	if _nen_bar.visible:
		var c := room.surface_cost()
		_nen_cost.text = tr("DECOR_NEN_COST") % int(c["hop_voi"]) if c.has("hop_voi") else tr("DECOR_NEN_FREE")

func _nen_keep() -> void:
	var r := room.commit_surfaces(_nen_before)
	_nen_result(r)
	if r == "ok":
		_say(tr("DECOR_PAINTED"))
	_nen_show_bar()
	_fill_kho()

func _nen_drop() -> void:
	room.cancel_surfaces()
	_nen_show_bar()
	if active and _tab == "nen":
		_fill_kho()

func _nen_end() -> void:
	if room == null:
		return
	room.cancel_surfaces()
	if _nen_bar:
		_nen_bar.visible = false
	_nen_one = false
	_nen_face = -1
	room.face_glow.emit(-1)

func _on_received(_id: String) -> void:
	if active:
		_fill_kho()
	else:
		_offer_news()

func _offer_news() -> void:
	if active or room.news.is_empty() or not is_instance_valid(player) or not player.controls:
		_ask.visible = false
		return
	_ask_id = room.news[-1]
	_ask_label.text = tr("DECOR_NEW_ASK") % tr(DecorRoom.item(_ask_id)["name"])
	_ask.visible = true

func _ask_yes() -> void:
	var id := _ask_id
	_ask.visible = false
	open()
	if int(room.kho.get(id, 0)) > 0:
		_take(id)
	elif int(room.san.get(id, 0)) > 0:
		_take(id, true)

func _ask_later() -> void:
	room.news.erase(_ask_id)
	room.save()
	_offer_news()

func _on_card(i: int, id: String) -> void:
	_sel = i
	_take(id, _tab == "san")

func _pick_card(i: int) -> void:
	if _ids.is_empty():
		return
	_sel = posmod(i, _ids.size())
	_hand = true
	_fill_kho()
	(_cards.get_parent() as ScrollContainer).ensure_control_visible.call_deferred(_cards.get_child(_sel))
