class_name PhoneApp
extends Control

signal chosen(id: String)

const SIZE := Vector2(430, 880)
const BODY := Color("15171d")
const GLASS := Color("f6f1ec")
const MOM := Color("ffffff")
const ME := Color("5aa0f2")
const MUTE := Color("8a8f99")
const INK := Color("2a2730")

var _phone: Control
var _screen: Control
var _time := "08:30"
var _battery := 80
var _status_time: Label
var _status_batt: Label
var _choosing := false
var _batt: Battery
var _last_page := {}

class Battery:
	extends Control
	var pct := 80

	func _draw() -> void:
		var r := Rect2(Vector2(0, 2), Vector2(size.x - 4, size.y - 4))
		draw_rect(r, Color(1, 1, 1, 0.9), false, 2.0)
		draw_rect(Rect2(Vector2(r.end.x, r.position.y + r.size.y * 0.3), Vector2(3, r.size.y * 0.4)), Color(1, 1, 1, 0.9))
		var f := r.grow(-3.0)
		f.size.x *= clampf(pct / 100.0, 0.05, 1.0)
		draw_rect(f, Color("f0636b") if pct <= 20 else Color(1, 1, 1, 0.9))

class Soup:
	extends Control
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("f3e3cf"))
		var c := Vector2(size.x * 0.5, size.y * 0.62)
		var w := size.x * 0.34
		draw_circle(c + Vector2(0, 6), w * 1.05, Color("d9c2a6"), true, -1.0, true)
		var bowl := PackedVector2Array()
		for i in 17:
			var a := PI * i / 16.0
			bowl.append(c + Vector2(cos(a) * w, sin(a) * w * 0.8))
		draw_colored_polygon(bowl, Color("ffffff"))
		draw_arc(c, w, PI, TAU, 24, Color("ffffff"), 1.0)
		draw_rect(Rect2(c - Vector2(w, 4), Vector2(w * 2, 8)), Color("c9733c"))
		for k in 5:
			draw_circle(c + Vector2(-w * 0.6 + k * w * 0.3, -1), 4.0, Color("6cc08b"))
		for k in 3:
			var x := c.x - w * 0.4 + k * w * 0.4
			var pts := PackedVector2Array()
			for j in 8:
				pts.append(Vector2(x + sin(t * 2.0 + j * 0.9 + k) * 4.0, c.y - 14 - j * 7))
			draw_polyline(pts, Color(1, 1, 1, 0.8), 2.5, true)

class Rings:
	extends Control
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		for k in 3:
			var u := fmod(t * 0.6 + k / 3.0, 1.0)
			draw_arc(c, 60.0 + u * 80.0, 0.0, TAU, 48, Color(1, 1, 1, 0.5 * (1.0 - u)), 3.0, true)
		draw_circle(c, 56.0, Color("f7c6a3"), true, -1.0, true)
		draw_circle(c + Vector2(-17, -6), 5.0, Color("5b4a44"), true, -1.0, true)
		draw_circle(c + Vector2(17, -6), 5.0, Color("5b4a44"), true, -1.0, true)
		draw_arc(c + Vector2(0, 8), 18.0, 0.4, PI - 0.4, 12, Color("5b4a44"), 3.0, true)
		draw_arc(c + Vector2(0, -30), 50.0, PI + 0.5, TAU - 0.5, 16, Color("6b5a52"), 12.0, true)

class NoteIcon:
	extends Control
	var ring := -1.0
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var shake := sin(t * 40.0) * 2.0 if fmod(t, 1.4) < 0.4 else 0.0
		var body := Rect2(c + Vector2(-10 + shake, -16), Vector2(20, 32))
		draw_rect(body, Color("2a2730"))
		draw_rect(body.grow(-3.0), Color("9fd0e8"))
		if ring >= 0.0:
			draw_arc(c, 24.0, -PI / 2.0, -PI / 2.0 + TAU * ring, 40, Color("f08aa6"), 4.0, true)
			draw_arc(c, 24.0, -PI / 2.0 + TAU * ring, -PI / 2.0 + TAU, 40, Color(0, 0, 0, 0.12), 4.0, true)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.08, 0.18)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_phone = Control.new()
	_phone.size = SIZE
	_phone.theme = UiTheme.make()
	_phone.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_phone)
	var body := Panel.new()
	var bs := UiTheme.box(BODY, 58, Color("2c303a"), 5, 0)
	bs.shadow_color = Color(0, 0, 0, 0.35)
	bs.shadow_size = 24
	body.add_theme_stylebox_override("panel", bs)
	body.size = SIZE
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone.add_child(body)
	var glass := Panel.new()
	glass.position = Vector2(14, 14)
	glass.size = SIZE - Vector2(28, 28)
	glass.add_theme_stylebox_override("panel", UiTheme.box(GLASS, 46, Color(0, 0, 0, 0), 0, 0))
	glass.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_phone.add_child(glass)
	_screen = Control.new()
	_screen.size = glass.size
	glass.add_child(_screen)
	var bar := HBoxContainer.new()
	bar.position = Vector2(34, 18)
	bar.size = Vector2(SIZE.x - 68, 30)
	_status_time = _label("", 20, Color.WHITE)
	_status_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_status_time)
	_status_batt = _label("", 18, Color.WHITE)
	bar.add_child(_status_batt)
	_batt = Battery.new()
	_batt.custom_minimum_size = Vector2(34, 18)
	_batt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_batt)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone.add_child(bar)
	get_viewport().size_changed.connect(_place)
	_place()

func setup(time_text: String, battery: int) -> void:
	_time = time_text
	_battery = battery
	_status_time.text = time_text
	_status_batt.text = "%d%%  " % battery
	_batt.pct = battery
	_batt.queue_redraw()

func _place() -> void:
	"""On the right of the view, sized to it (the hero is framed on the left)."""
	var vs := get_viewport_rect().size
	var k := vs.y * 0.86 / SIZE.y
	_phone.scale = Vector2(k, k)
	_phone.position = Vector2(vs.x * 0.7 - SIZE.x * k * 0.5, (vs.y - SIZE.y * k) * 0.5)

func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _bar_dark(on: bool) -> void:
	"""The status bar's colour: white over a picture, dark over the light pages."""
	var c := Color.WHITE if on else INK
	_status_time.add_theme_color_override("font_color", c)
	_status_batt.add_theme_color_override("font_color", c)

func _page() -> Control:
	for ch in _screen.get_children():
		ch.queue_free()
	var p := Control.new()
	p.size = _screen.size
	_screen.add_child(p)
	return p

func slide_in() -> void:
	var to := _phone.position
	_phone.position.y = get_viewport_rect().size.y + 20.0
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_phone, "position:y", to.y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	await tw.finished

func slide_out() -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(_phone, "position:y", get_viewport_rect().size.y + 20.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	queue_free()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _choosing:
		accept_event()
		chosen.emit("later")

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE and _choosing:
		get_viewport().set_input_as_handled()
		chosen.emit("later")

func lock(notes: Array, day_text := "") -> void:
	"""The lock screen for a moment (the first look of the day): the wallpaper, the time, what is waiting.
	day_text: the day under the clock (Monday unless told otherwise - the Saturday of Bố's message)."""
	var p := _page()
	_bar_dark(true)
	var bg := ColorRect.new()
	bg.color = Color("1c1937")
	bg.size = p.size
	p.add_child(bg)
	var home := PhoneLockScreen.Home.new()
	home.size = p.size
	p.add_child(home)
	var clock := _label(_time, 92, Color.WHITE)
	clock.position = Vector2(0, 90)
	clock.size = Vector2(p.size.x, 110)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(clock)
	var day := _label(day_text if day_text != "" else tr("PHONE_DAY_MON"), 22, Color(1, 1, 1, 0.85))
	day.position = Vector2(0, 205)
	day.size = Vector2(p.size.x, 30)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(day)
	var v := VBoxContainer.new()
	v.position = Vector2(22, 270)
	v.size = Vector2(p.size.x - 44, 0)
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	for n in notes:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.82), 22, Color(0, 0, 0, 0), 0, 16))
		var l := _label(n, 19, INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(l)
		v.add_child(card)
		card.modulate.a = 0.0
		create_tween().tween_property(card, "modulate:a", 1.0, 0.2).set_delay(0.08 * v.get_child_count())
	await get_tree().create_timer(0.6).timeout
	var tw := create_tween()
	tw.tween_property(p, "position:y", -p.size.y, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished

func thread(entries: Array, choices: Array, typing := false, who_name := "") -> String:
	"""The thread with Mum: entries [{"who": mom|me|log, "text", "when"?, "photo"?, "photo_tex"?}]; the newest of
	Mum's comes after "typing..." if `typing`. choices [[label, id], ...] -> the id picked ("later": put away).
	who_name: the name at the top when it is not Mum (Bố's thread, the Saturday after the week)."""
	var p := _page()
	_bar_dark(false)
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", UiTheme.box(Color("ffffff"), 0, Color(0, 0, 0, 0), 0, 12))
	head.position = Vector2(0, 0)
	head.size = Vector2(p.size.x, 112)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 12)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(10, 0)
	hh.add_child(pad)
	hh.add_child(_label("‹", 34, ME))
	var av := Panel.new()
	av.custom_minimum_size = Vector2(44, 44)
	av.size_flags_vertical = Control.SIZE_SHRINK_END
	av.add_theme_stylebox_override("panel", UiTheme.box(Color("f7c6a3"), 22, Color(0, 0, 0, 0), 0, 0))
	hh.add_child(av)
	var name_l := _label(who_name if who_name != "" else tr("PHONE_MOM_NAME"), 24, INK)
	name_l.size_flags_vertical = Control.SIZE_SHRINK_END
	hh.add_child(name_l)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 54)
	m.add_child(hh)
	head.add_child(m)
	p.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 112)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lm := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		lm.add_theme_constant_override("margin_" + side, 14)
	lm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lm.add_child(list)
	scroll.add_child(lm)
	p.add_child(scroll)
	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	var chips := VBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	foot.add_child(chips)
	var input := PanelContainer.new()
	input.add_theme_stylebox_override("panel", UiTheme.box(Color("ffffff"), 22, Color("e1dbd5"), 2, 16))
	var input_l := _label(tr("PHONE_INPUT"), 19, MUTE)
	input.add_child(input_l)
	foot.add_child(input)
	var fm := MarginContainer.new()
	for side in ["left", "right"]:
		fm.add_theme_constant_override("margin_" + side, 14)
	fm.add_theme_constant_override("margin_bottom", 22)
	fm.add_child(foot)
	p.add_child(fm)
	var last_mom := -1
	for i in entries.size():
		if entries[i]["who"] == "mom":
			last_mom = i
	for i in entries.size():
		if typing and i == last_mom:
			continue
		list.add_child(_entry(entries[i]))
	var lay := func():
		fm.size = Vector2(p.size.x, 0)
		fm.reset_size()
		fm.size.x = p.size.x
		fm.position = Vector2(0, p.size.y - fm.size.y)
		scroll.size = Vector2(p.size.x, fm.position.y - 112)
		await get_tree().process_frame
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await lay.call()
	if typing and last_mom >= 0:
		var dots := _bubble("•  •  •", "mom")
		list.add_child(dots)
		await lay.call()
		await get_tree().create_timer(0.8).timeout
		dots.queue_free()
		list.add_child(_entry(entries[last_mom]))
		await lay.call()
	for c in choices:
		var b := Button.new()
		b.text = c[0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 58)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 20)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func(): chosen.emit(c[1]))
		chips.add_child(b)
	await lay.call()
	_choosing = true
	var id: String = await chosen
	_choosing = false
	for b in chips.get_children():
		b.queue_free()
	_last_page = {"list": list, "input": input_l, "lay": lay}
	return id

func reply(text: String) -> void:
	"""The hero's answer types itself into the box (a click finishes it), goes, and is seen a moment later."""
	var input: Label = _last_page["input"]
	var list: VBoxContainer = _last_page["list"]
	input.add_theme_color_override("font_color", INK)
	var dur := minf(0.6, 0.03 * text.length())
	var t := 0.0
	var skip := [false]
	var hurry := func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			skip[0] = true
	gui_input.connect(hurry)
	while t < dur and not skip[0]:
		input.text = text.left(int(text.length() * t / dur))
		await get_tree().process_frame
		t += get_process_delta_time()
	gui_input.disconnect(hurry)
	input.text = tr("PHONE_INPUT")
	input.add_theme_color_override("font_color", MUTE)
	list.add_child(_bubble(text, "me"))
	await (_last_page["lay"] as Callable).call()
	await get_tree().create_timer(1.0).timeout
	var seen := _label(tr("PHONE_SEEN"), 15, MUTE)
	seen.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	list.add_child(seen)
	await (_last_page["lay"] as Callable).call()
	await get_tree().create_timer(0.5).timeout

func _entry(e: Dictionary) -> Control:
	if e["who"] == "log":
		var l := _label(e["text"], 16, MUTE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return l
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	if e.has("when"):
		var w := _label(e["when"], 15, MUTE)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(w)
	if e.get("photo_tex") != null:
		var holder := HBoxContainer.new()
		var pic := TextureRect.new()
		pic.texture = e["photo_tex"]
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(230, 160)
		holder.add_child(pic)
		v.add_child(holder)
	elif e.get("photo", false):
		var holder := HBoxContainer.new()
		var soup := Soup.new()
		soup.custom_minimum_size = Vector2(230, 160)
		holder.add_child(soup)
		v.add_child(holder)
	v.add_child(_bubble(e["text"], e["who"]))
	return v

func _bubble(text: String, who: String) -> Control:
	var h := HBoxContainer.new()
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := PanelContainer.new()
	b.add_theme_stylebox_override("panel", UiTheme.box(MOM if who == "mom" else ME, 22, Color("ebe4dd") if who == "mom" else Color(0, 0, 0, 0),
		2 if who == "mom" else 0, 14))
	var l := _label(text, 20, INK if who == "mom" else Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(0, 0)
	var font := l.get_theme_font("font")
	b.custom_minimum_size = Vector2(minf(300.0, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 34.0), 0)
	b.add_child(l)
	if who == "me":
		h.add_child(gap)
		h.add_child(b)
	else:
		h.add_child(b)
		h.add_child(gap)
	return h

func ringing() -> String:
	"""Mum is calling: her picture, rings, Answer / Decline -> "answer" | "decline" | "later" (let it ring)."""
	var p := _page()
	_bar_dark(true)
	var bg := ColorRect.new()
	bg.color = Color("3b3350")
	bg.size = p.size
	p.add_child(bg)
	var who := _label(tr("PHONE_MOM_NAME"), 40, Color.WHITE)
	who.position = Vector2(0, 110)
	who.size = Vector2(p.size.x, 50)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(who)
	var sub := _label(tr("PHONE_INCOMING"), 20, Color(1, 1, 1, 0.75))
	sub.position = Vector2(0, 165)
	sub.size = Vector2(p.size.x, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(sub)
	var rings := Rings.new()
	rings.position = Vector2(p.size.x * 0.5 - 150, 230)
	rings.size = Vector2(300, 300)
	rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(rings)
	var row := HBoxContainer.new()
	row.position = Vector2(30, p.size.y - 190)
	row.size = Vector2(p.size.x - 60, 120)
	row.add_theme_constant_override("separation", 30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for o in [["MR_P_DECLINE", "decline", Color("f0636b")], ["MR_P_ANSWER", "answer", Color("5fbf7a")]]:
		var b := Button.new()
		b.text = tr(o[0])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(160, 78)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 21)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, UiTheme.box((o[2] as Color).darkened(0.1 if st != "normal" else 0.0), 39, Color(0, 0, 0, 0), 0, 10))
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, Color.WHITE)
		b.pressed.connect(func(): chosen.emit(o[1]))
		row.add_child(b)
	p.add_child(row)
	_choosing = true
	var id: String = await chosen
	_choosing = false
	return id

func talk(lines: Array, bye: String) -> void:
	"""On the phone with Mum: a call timer, her lines as subtitles one after another (a click hurries them),
	then the hero's goodbye."""
	var p := _page()
	_bar_dark(true)
	var bg := ColorRect.new()
	bg.color = Color("3b3350")
	bg.size = p.size
	p.add_child(bg)
	var rings := Rings.new()
	rings.position = Vector2(p.size.x * 0.5 - 150, 90)
	rings.size = Vector2(300, 300)
	rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(rings)
	var timer := _label("00:00", 24, Color(1, 1, 1, 0.8))
	timer.position = Vector2(0, 390)
	timer.size = Vector2(p.size.x, 30)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(timer)
	var sub := _label("", 23, Color.WHITE)
	sub.position = Vector2(30, 450)
	sub.size = Vector2(p.size.x - 60, 200)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(sub)
	var secs := [0.0]
	var tick := func():
		while is_instance_valid(timer):
			secs[0] += 7.0
			timer.text = "%02d:%02d" % [int(secs[0]) / 60, int(secs[0]) % 60]
			await get_tree().create_timer(0.25).timeout
	tick.call()
	for line in lines:
		sub.text = tr("PHONE_MOM_NAME") + ": " + line
		sub.modulate.a = 0.0
		create_tween().tween_property(sub, "modulate:a", 1.0, 0.2)
		var waited := 0.0
		_choosing = false
		var skip := [false]
		var hurry := func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				skip[0] = true
		gui_input.connect(hurry)
		_phone.gui_input.connect(hurry)
		while waited < 1.8 and not skip[0]:
			await get_tree().process_frame
			waited += get_process_delta_time()
		gui_input.disconnect(hurry)
		_phone.gui_input.disconnect(hurry)
	var b := Button.new()
	b.text = bye
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(40, p.size.y - 160)
	b.size = Vector2(p.size.x - 80, 70)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 21)
	b.pressed.connect(func(): chosen.emit("bye"))
	p.add_child(b)
	_choosing = true
	await chosen
	_choosing = false
