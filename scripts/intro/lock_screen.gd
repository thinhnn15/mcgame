class_name PhoneLockScreen
extends Control

const SIZE := Vector2(430, 880)
const INK := Color(1, 1, 1, 0.96)

var k := 1.0
var _phone: Control
var _screen: Panel
var _dark: ColorRect
var _cards: Array = []
var _stop := false

class Home:
	extends Control

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 26:
			var p := Vector2(rng.randf() * w, rng.randf() * h * 0.45)
			draw_circle(p, rng.randf_range(0.8, 2.2), Color(1, 1, 1, rng.randf_range(0.35, 0.9)))

		var layers := [[0.64, Color("4d4580"), 11, 0.2], [0.72, Color("312b5c"), 7, 0.27], [0.80, Color("1c1937"), 5, 0.34]]
		for l in layers:
			var base: float = h * l[0]
			var n: int = l[2]
			var span := w / n
			draw_rect(Rect2(0, base - h * 0.03, w, h - base + h * 0.03), l[1])
			for i in int(n * 1.2):
				var cx := rng.randf_range(-span * 0.3, w + span * 0.3)
				var r := span * rng.randf_range(0.2, 0.38)
				var top: float = base - h * l[3] * rng.randf_range(0.45, 1.0)
				draw_rect(Rect2(cx - r, top + r, r * 2.0, base - top - r + 2.0), l[1])
				draw_circle(Vector2(cx, top + r), r, l[1], true, -1.0, true)
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				draw_circle(Vector2(cx + side * r * 0.7, top + r * 2.6), r * 0.6, l[1], true, -1.0, true)
			draw_rect(Rect2(0, base - 3.0, w, h * 0.012 + 5.0), Color(0.85, 0.75, 0.85, 0.1))
		draw_rect(Rect2(0, h * 0.84, w, h * 0.16), Color("2d3b2a"))
		for i in 6:
			var y := h * (0.86 + 0.025 * i)
			draw_line(Vector2(0, y), Vector2(w, y + 6), Color("3f5a37"), 2.0)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	k = get_viewport_rect().size.y / 1080.0
	_phone = Control.new()
	_phone.size = SIZE * k
	_phone.pivot_offset = _phone.size * 0.5
	add_child(_phone)
	var body := Panel.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("0c0e13")
	bs.set_corner_radius_all(int(68 * k))
	bs.border_color = Color("4a505c")
	bs.set_border_width_all(maxi(2, int(3 * k)))
	bs.shadow_color = Color(0, 0, 0, 0.5)
	bs.shadow_size = int(34 * k)
	bs.shadow_offset = Vector2(0, 12 * k)
	body.add_theme_stylebox_override("panel", bs)
	body.size = _phone.size
	_phone.add_child(body)
	_screen = Panel.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color.BLACK
	ss.set_corner_radius_all(int(56 * k))
	_screen.add_theme_stylebox_override("panel", ss)
	_screen.position = Vector2(14, 14) * k
	_screen.size = _phone.size - Vector2(28, 28) * k
	_screen.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_phone.add_child(_screen)
	var sky := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([Color("141631"), Color("3a3168"), Color("b5677a"), Color("e9a27e")])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	sky.texture = gt
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.size = _screen.size
	_screen.add_child(sky)
	var home := Home.new()
	home.size = _screen.size
	_screen.add_child(home)
	var shade := TextureRect.new()
	var sg := Gradient.new()
	sg.colors = PackedColorArray([Color(0, 0, 0, 0.35), Color(0, 0, 0, 0)])
	var st := GradientTexture2D.new()
	st.gradient = sg
	st.fill_from = Vector2(0.5, 0)
	st.fill_to = Vector2(0.5, 0.5)
	shade.texture = st
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.size = _screen.size
	_screen.add_child(shade)
	_build_face()
	_dark = ColorRect.new()
	_dark.color = Color(0, 0, 0, 0)
	_dark.size = _screen.size
	_screen.add_child(_dark)
	for c in find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone.position = Vector2((get_viewport_rect().size.x - _phone.size.x) * 0.5, get_viewport_rect().size.y + 40 * k)

func _txt(text: String, size: int, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(size * k))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l

func _round(c: Color, sz: Vector2, r: float) -> Panel:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(int(r * k))
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = sz * k
	p.size = sz * k
	return p

func _build_face() -> void:
	var w := _screen.size.x
	var island := _round(Color.BLACK, Vector2(120, 34), 17)
	island.position = Vector2((w - island.size.x) * 0.5, 16 * k)
	_screen.add_child(island)
	var status := HBoxContainer.new()
	status.position = Vector2(34, 20) * k
	status.size = Vector2(w - 68 * k, 30 * k)
	var carrier := _txt("mc mobile", 17, Color(1, 1, 1, 0.85))
	carrier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(carrier)
	status.add_child(_txt("12%  ", 17, Color(1, 1, 1, 0.85)))
	var batt := _round(Color(1, 1, 1, 0), Vector2(30, 15), 4)
	var bstyle := batt.get_theme_stylebox("panel") as StyleBoxFlat
	bstyle.border_color = Color(1, 1, 1, 0.8)
	bstyle.set_border_width_all(maxi(1, int(2 * k)))
	batt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var level := _round(Color("ff5a52"), Vector2(5, 9), 2)
	level.position = Vector2(3, 3) * k
	batt.add_child(level)
	status.add_child(batt)
	_screen.add_child(status)
	var date := _txt(tr("PHONE_DATE"), 22, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	date.position = Vector2(0, 92 * k)
	date.size = Vector2(w, 30 * k)
	_screen.add_child(date)
	var clock := _txt("01:35", 112, INK, HORIZONTAL_ALIGNMENT_CENTER)
	clock.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	clock.add_theme_constant_override("shadow_offset_y", int(3 * k))
	clock.position = Vector2(0, 118 * k)
	clock.size = Vector2(w, 140 * k)
	_screen.add_child(clock)
	var y := 300.0
	for n in [[tr("NAME_KIEN"), tr("INTRO_PHONE_MSG"), "01:35", false],
			[tr("PHONE_MOM_NAME"), tr("PHONE_MOM_MSG"), tr("PHONE_WEEKS"), true]]:
		var card := _card(n[0], n[1], n[2], n[3], w - 40 * k)
		card.position = Vector2(20 * k, y * k)
		card.modulate.a = 0.0
		_screen.add_child(card)
		_cards.append(card)
		y += 132.0
	var bottom_y := _screen.size.y - 112 * k
	for side in [0, 1]:
		var b := _round(Color(1, 1, 1, 0.16), Vector2(62, 62), 31)
		b.position = Vector2(44 * k if side == 0 else w - 106 * k, bottom_y)
		var icon := _round(Color(1, 1, 1, 0.85), Vector2(14, 22) if side == 0 else Vector2(26, 18), 4)
		icon.position = (b.size - icon.size) * 0.5
		b.add_child(icon)
		_screen.add_child(b)
	var bar := _round(Color(1, 1, 1, 0.85), Vector2(150, 6), 3)
	bar.position = Vector2((w - bar.size.x) * 0.5, _screen.size.y - 22 * k)
	_screen.add_child(bar)

func _card(who: String, text: String, when: String, unread: bool, width: float) -> Control:
	"""A notification: frosted glass, the Messages icon, the app's name and the time, the sender, the text."""
	var card := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.93, 0.92, 0.98, 0.22)
	s.border_color = Color(1, 1, 1, 0.16)
	s.set_border_width_all(1)
	s.set_corner_radius_all(int(28 * k))
	s.content_margin_left = 16 * k
	s.content_margin_right = 18 * k
	s.content_margin_top = 14 * k
	s.content_margin_bottom = 16 * k
	card.add_theme_stylebox_override("panel", s)
	card.custom_minimum_size = Vector2(width, 0)
	card.size = Vector2(width, 116 * k)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(14 * k))
	card.add_child(row)
	var icon := _round(Color("34c759"), Vector2(46, 46), 12)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var bubble := _round(Color.WHITE, Vector2(28, 22), 11)
	bubble.position = Vector2(9, 11) * k
	icon.add_child(bubble)
	row.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", int(2 * k))
	var head := HBoxContainer.new()
	var app := _txt(tr("PHONE_APP").to_upper(), 15, Color(1, 1, 1, 0.7))
	app.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(app)
	head.add_child(_txt(when, 15, Color(1, 1, 1, 0.7)))
	v.add_child(head)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", int(8 * k))
	if unread:
		var dot := _round(Color("4aa3ff"), Vector2(11, 11), 6)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_row.add_child(dot)
	name_row.add_child(_txt(who, 22, INK))
	v.add_child(name_row)
	var msg := _txt(text, 22, Color(1, 1, 1, 0.92))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	row.add_child(v)
	return card

func stop() -> void:
	"""Skipped: let play() fall through."""
	_stop = true

func play() -> void:
	var vs := get_viewport_rect().size
	var up := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_phone.rotation = deg_to_rad(-4.0)
	up.tween_property(_phone, "position:y", (vs.y - _phone.size.y) * 0.45, 0.7)
	up.tween_property(_phone, "rotation", 0.0, 0.7)
	await up.finished
	var buzz := create_tween()
	var x0 := _phone.position.x
	for i in 6:
		buzz.tween_property(_phone, "position:x", x0 + (5.0 if i % 2 == 0 else -5.0) * k, 0.04)
	buzz.tween_property(_phone, "position:x", x0, 0.04)
	for card in _cards:
		await _wait(0.45)
		if _stop:
			return
		var c: Control = card
		var y0 := c.position.y
		c.position.y = y0 - 18 * k
		var t := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(c, "modulate:a", 1.0, 0.3)
		t.tween_property(c, "position:y", y0, 0.35)
	await _wait(2.6)
	if _stop:
		return
	await _swipe(_cards[0])
	await _wait(0.7)
	if _stop:
		return
	var mom: Control = _cards[1]
	var mx := mom.position.x
	var hold := create_tween().set_trans(Tween.TRANS_SINE)
	hold.tween_property(mom, "position:x", mx - 70 * k, 0.35)
	hold.tween_interval(0.5)
	hold.tween_property(mom, "position:x", mx, 0.3)
	await hold.finished
	await _wait(0.9)
	if _stop:
		return
	await _swipe(mom)
	await _wait(0.5)
	var off := create_tween()
	off.tween_property(_dark, "color:a", 1.0, 0.35)
	off.tween_interval(0.3)
	off.tween_property(_phone, "position:y", vs.y + 40 * k, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await off.finished

func _swipe(c: Control) -> void:
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(c, "position:x", c.position.x - 560 * k, 0.32)
	t.tween_property(c, "rotation", deg_to_rad(-6.0), 0.32)
	t.tween_property(c, "modulate:a", 0.0, 0.32)
	await t.finished

func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout
