class_name DesignApp
extends RefCounted

const REV_CHARS := 70.0
const RINGS := [Color("ffb26b"), Color("ff8c69"), Color("5aa0f2"), Color("2f3a4f"), Color("6cc08b")]
const INNERS := [Color("fff1d6"), Color("cfe4ff"), Color("d8b25a")]
const R_RANGE := Vector2(0.45, 0.9)
const H_RANGE := Vector2(0.12, 0.5)
const SNAP := 0.04
const STEP := 0.04
const PEN := Color("e0565e")
const BLUE := Color("5aa0f2")
const GREEN := Color("4aa56a")
const PINK := Color("f08aa6")
const INK := Color("20242c")
const KNOB_ANG := {"r": -0.61, "h": 2.53}
const IDLE_NUDGE := 8.0

const PROJECTS := [
	{"file": "logo_final_v%d_FINAL_thatsu.png", "first": 7,
		"rounds": [["DESIGN_FB_1", {"r": 0.8}], ["DESIGN_FB_2", {"ring": 2, "inner": 1}], ["DESIGN_FB_3", {"ring": 3, "inner": 2}]]},
	{"file": "logo_final_v%d_FINAL_thatsu.png", "first": 10,
		"rounds": [["DESIGN_FB_5", {"r": 0.7, "h": 0.24}], ["DESIGN_FB_6", {"h": 0.36}], ["DESIGN_FB_4", {"ring": 0, "inner": 0}]]},
]
const FIRST := {"ring": 0, "inner": 0, "r": 0.62, "h": 0.28}

const CFG := "user://settings.cfg"

static var _taught := false

var pc
var rev := 7
var progress := 0.0
var cur := FIRST.duplicate()
var approved := 0
var _project := 0
var _step := 0
var _base := FIRST.duplicate()
var _signed := false
var _from := FIRST
var _logo: LogoView
var _title: Label
var _comments: VBoxContainer
var _bar: ProgressBar
var _bar_label: Label
var _size: Label
var _bubble: PanelContainer
var _bubble_label: Label
var _dots: HBoxContainer
var _round_label: Label
var _cards: VBoxContainer
var _rows := {}
var _was_ok := {}
var _send: Button
var _hint: Label
var _drag := ""
var _idle := 0.0
var _typing := false
var _mean: Label
var _resting := false
var tasked := false
var job = null
var _queued = null
var _t := 0.0

class LogoView:
	extends Control
	var look := {}
	var want := {}
	var active: Array = []
	var done := {}
	var hover := ""
	var ghost := -1.0
	var editing := false
	var hand := -1.0
	var stamp := ""
	var stamp_t := 1.0
	var t := 0.0

	func radius() -> float:
		return minf(size.x, size.y) * 0.5

	func knob(p: String) -> Vector2:
		return size * 0.5 + Vector2.from_angle(KNOB_ANG[p]) * radius() * float(look[p])

	func _draw() -> void:
		if look.is_empty():
			return
		var c := size * 0.5
		var big := radius()
		draw_circle(c, big * look["r"], look["ring"], true, -1.0, true)
		draw_circle(c, big * look["h"], look["inner"], true, -1.0, true)
		if not editing and want.is_empty():
			var r: float = big * look["r"]
			var bar := Rect2(c + Vector2(-r * 0.7, r + 16), Vector2(r * 1.4, 10))
			if bar.end.y < size.y:
				draw_rect(bar, Color(look["ring"], 0.55))
		if editing:
			for p in active:
				var rr: float = big * float(look[p])
				if hover == p:
					draw_arc(c, rr, 0.0, TAU, 96, Color(BLUE, 0.3), 8.0, true)
				draw_arc(c, rr, 0.0, TAU, 96, Color(BLUE, 1.0 if hover == p else 0.55), 2.0, true)
			if hover != "" and ghost > 0.0:
				_dashed(c, big * ghost, Color(BLUE, 0.7), 1.5)
		for p in want:
			var wr: float = big * float(want[p])
			if done.has(p):
				var k: float = done[p]
				var a := 1.0 - clampf((k - 0.35) / 0.6, 0.0, 1.0)
				if a > 0.0:
					draw_arc(c, wr, 0.0, TAU, 96, Color(GREEN, a), 3.0 + 4.0 * sin(clampf(k / 0.35, 0.0, 1.0) * PI), true)
			else:
				_dashed(c, wr, PEN, 3.0)
				if editing:
					var dir := Vector2.from_angle(KNOB_ANG[p])
					var now: float = big * float(look[p])
					var sgn := signf(wr - now)
					if absf(wr - now) > 22.0:
						var tip := c + dir * (now + sgn * 30.0)
						var side := dir.orthogonal() * 8.0
						draw_polyline(PackedVector2Array([tip - dir * sgn * 9.0 + side, tip, tip - dir * sgn * 9.0 - side]), PEN, 3.0, true)
		if editing:
			for p in active:
				if done.has(p):
					continue
				var at := knob(p)
				var kr := 20.0 if hover == p else 16.0
				draw_circle(at, kr + 2.0, Color(0, 0, 0, 0.12), true, -1.0, true)
				draw_circle(at, kr, Color.WHITE, true, -1.0, true)
				draw_arc(at, kr, 0.0, TAU, 32, BLUE, 3.0, true)
				var d := Vector2.from_angle(KNOB_ANG[p])
				for s in [-1.0, 1.0]:
					var tip2: Vector2 = at + d * s * kr * 0.55
					var back: Vector2 = at + d * s * kr * 0.15
					draw_colored_polygon(PackedVector2Array([tip2, back + d.orthogonal() * 4.0, back - d.orthogonal() * 4.0]), BLUE)
		if hand >= 0.0 and editing and not active.is_empty():
			for p in active:
				if want.has(p) and not done.has(p):
					var u := ease(clampf(fmod(hand, 2.2) / 1.2, 0.0, 1.0), -2.0)
					var from := knob(p)
					var to := c + Vector2.from_angle(KNOB_ANG[p]) * big * float(want[p])
					var n := maxi(1, int(from.distance_to(to) / 8.0))
					for i in n:
						draw_circle(from.lerp(to, (i + 0.5) / n), 2.0, Color(PINK, 0.8), true, -1.0, true)
					var at2 := from.lerp(to, u)
					draw_circle(at2, 18.0, Color(PINK, 0.7), true, -1.0, true)
					draw_arc(at2, 18.0, 0.0, TAU, 32, Color.WHITE, 3.0, true)
					break
		if stamp != "":
			var font := get_theme_font("font", "Label")
			var fs := 34
			var w := font.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0
			var e := ease(clampf(stamp_t / 0.22, 0.0, 1.0), -2.0)
			draw_set_transform(c, deg_to_rad(-12.0), Vector2.ONE * lerpf(1.8, 1.0, e))
			var box := Rect2(Vector2(-w * 0.5, -30), Vector2(w, 60))
			draw_rect(box, Color(1, 1, 1, 0.75 * e))
			draw_rect(box, Color(Color("d9363e"), e), false, 4.0)
			draw_string(font, Vector2(-w * 0.5 + 14, 12), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Color("d9363e"), e))
			draw_set_transform(Vector2.ZERO)

	func _dashed(c: Vector2, r: float, col: Color, width := 2.5) -> void:
		var n := maxi(16, int(r * 0.35)) * 2
		for i in range(0, n, 2):
			draw_arc(c, r, TAU * i / n, TAU * (i + 1) / n, 6, col, width, true)

class Avatar:
	extends Control
	var tint := Color("f7c6a3")

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, tint, true, -1.0, true)
		draw_circle(c + Vector2(-r * 0.32, -r * 0.08), r * 0.1, Color("5b4a44"), true, -1.0, true)
		draw_circle(c + Vector2(r * 0.32, -r * 0.08), r * 0.1, Color("5b4a44"), true, -1.0, true)
		draw_arc(c + Vector2(0, r * 0.12), r * 0.3, 0.3, PI - 0.3, 12, Color("5b4a44"), 2.5, true)

class MiniIcon:
	extends Control
	var part := "r"
	var up := true
	var ring := Color("ffb26b")
	var inner := Color("fff1d6")

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		draw_circle(c, r, ring, true, -1.0, true)
		draw_circle(c, r * 0.45, inner, true, -1.0, true)
		var e := r if part == "r" else r * 0.45
		draw_arc(c, e, 0.0, TAU, 32, PEN, 2.5, true)
		var d := Vector2.from_angle(-0.61)
		var from := c + d * e
		var to := from + d * (9.0 if up else -9.0)
		draw_line(from, to, PEN, 2.5, true)
		draw_colored_polygon(PackedVector2Array([to + d * (4.0 if up else -4.0), to + d.orthogonal() * 4.0, to - d.orthogonal() * 4.0]), PEN)

class PenRing:
	extends Control
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size).grow(5.0)
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for i in 4:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := int(a.distance_to(b) / 6.0)
			for k in range(0, n, 2):
				draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), PEN, 2.5)

func _init(p_pc) -> void:
	pc = p_pc

func build(rect: Rect2) -> Control:
	var w: Array = pc._window(rect, Color("eef0f4"), Color("5b6270"))
	_title = w[1]
	var body: VBoxContainer = w[2]
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 0)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(main)
	main.add_child(_rail())
	var canvas: PanelContainer = pc._panel(Color("e9ecf1"))
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if pc.night:
		canvas.gui_input.connect(pc._tap)
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 10)
	canvas.add_child(cv)
	var board: PanelContainer = pc._panel(Color("fffaf2"), Vector2(460, 460) if not pc.night else Vector2(380, 380), 12)
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo = LogoView.new()
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(_logo)
	cv.add_child(board)
	if pc.night:
		var bv := VBoxContainer.new()
		bv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bv.custom_minimum_size = Vector2(380, 0)
		_bar_label = pc._label("", Color("5b6270"), 15)
		bv.add_child(_bar_label)
		_bar = ProgressBar.new()
		_bar.custom_minimum_size = Vector2(380, 10)
		_bar.show_percentage = false
		_bar.max_value = REV_CHARS
		_bar.add_theme_stylebox_override("background", pc._rect(Color("d3d8e0"), 5))
		_bar.add_theme_stylebox_override("fill", pc._rect(BLUE, 5))
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(_bar)
		cv.add_child(bv)
	else:
		_logo.mouse_filter = Control.MOUSE_FILTER_STOP
		_logo.gui_input.connect(_on_logo)
		_logo.mouse_exited.connect(func():
			_logo.hover = ""
			_logo.ghost = -1.0)
		_hint = pc._label("", Color("6b3f22"), 20)
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var hs: StyleBoxFlat = pc._rect(Color.WHITE, 18)
		hs.border_color = PEN
		hs.set_border_width_all(2)
		hs.content_margin_left = 18
		hs.content_margin_right = 18
		hs.content_margin_top = 5
		hs.content_margin_bottom = 5
		_hint.add_theme_stylebox_override("normal", hs)
		cv.add_child(_hint)
	main.add_child(canvas)
	main.add_child(_panel_side())
	return w[0]

func _rail() -> Control:
	"""A slim tool rail (for the look of a design tool): pen, circle (in use), text."""
	var rail: PanelContainer = pc._panel(Color.WHITE, Vector2(56, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_child(v)
	rail.add_child(m)
	for k in ["✎", "◯", "T"]:
		var tile: PanelContainer = pc._panel(Color("ffe3ea") if k == "◯" else Color("f4f5f8"), Vector2(40, 40), 10)
		var l: Label = pc._label(k, PINK if k == "◯" else Color("8a919c"), 22)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tile.add_child(l)
		v.add_child(tile)
	return rail

func _panel_side() -> Control:
	"""The client: who, what they said, what they mean (a card a change), and Send."""
	var insp: PanelContainer = pc._panel(Color.WHITE, Vector2(492 if not pc.night else 300, 0))
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 10)
	var im := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		im.add_theme_constant_override("margin_" + side, 20 if side != "top" else 16)
	im.add_child(iv)
	insp.add_child(im)
	var head := HBoxContainer.new()
	head.add_child(pc._label(tr("DESIGN_COMMENTS"), INK, 18))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 5)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(_dots)
	_round_label = pc._label("", Color("4a5160"), 16)
	head.add_child(_round_label)
	iv.add_child(head)
	_comments = VBoxContainer.new()
	_comments.add_theme_constant_override("separation", 6)
	iv.add_child(_comments)
	if pc.night:
		_size = pc._label("", Color("4a5160"), 14)
		iv.add_child(_size)
		return insp
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 12)
	var av := Avatar.new()
	av.custom_minimum_size = Vector2(52, 52)
	av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	who.add_child(av)
	_bubble = pc._panel(Color("fff4e8"), Vector2.ZERO, 16)
	var bs := _bubble.get_theme_stylebox("panel") as StyleBoxFlat
	bs.border_color = Color("f2cfae")
	bs.set_border_width_all(2)
	bs.content_margin_left = 14
	bs.content_margin_right = 14
	bs.content_margin_top = 10
	bs.content_margin_bottom = 10
	_bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bubble_label = pc._label("", Color("6b3f22"), 22)
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.add_child(_bubble_label)
	who.add_child(_bubble)
	iv.add_child(who)
	_mean = pc._label("✎  " + tr("DESIGN_MEAN"), PEN, 17)
	iv.add_child(_mean)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	iv.add_child(_cards)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	iv.add_child(fill)
	_send = Button.new()
	_send.focus_mode = Control.FOCUS_NONE
	_send.custom_minimum_size = Vector2(0, 64)
	_send.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_send.add_theme_font_size_override("font_size", 22)
	_send.pressed.connect(_on_send)
	iv.add_child(_send)
	return insp

func start() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG) == OK and bool(cfg.get_value("tips", "design_drag", false)):
		_taught = true
	rev = PROJECTS[0]["first"]
	_open_round()

func _learned() -> void:
	"""The player has moved an edge: no more showing them how (this run, and the next)."""
	_logo.hand = -1.0
	if _taught:
		return
	_taught = true
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("tips", "design_drag", true)
	cfg.save(CFG)

func _rounds() -> Array:
	return PROJECTS[_project]["rounds"]

func _target() -> Dictionary:
	"""The logo this comment asks for: the last one sent, with what the comment changes."""
	var t: Dictionary = _base.duplicate()
	t.merge(_rounds()[_step][1], true)
	return t

func _todo() -> Array:
	"""What this comment changes (one or two parts), in the order the cards show them."""
	var t := _target()
	return ["r", "h", "ring", "inner"].filter(func(p):
		return int(t[p]) != int(_base[p]) if p in ["ring", "inner"] else absf(float(t[p]) - float(_base[p])) > 0.001)

func _open_round() -> void:
	"""A comment comes in: the bubble, the red pen, a card per change."""
	_say(tr(_rounds()[_step][0]))
	_was_ok = {}
	if not pc.night:
		_mean.visible = true
		_build_cards()
		if not _taught:
			_logo.hand = 0.0
	_idle = 0.0
	_show()

func _say(text: String) -> void:
	"""The client's words (by day without their "Client:" - the face says who)."""
	if pc.night:
		_night_comment(text)
		return
	var prefix: String = tr("MG_CLIENT")
	if text.begins_with(prefix):
		text = text.substr(prefix.length()).lstrip(":： ")
	_bubble_label.text = text
	_bubble.pivot_offset = _bubble.size * 0.5
	_bubble.scale = Vector2(0.92, 0.92)
	_bubble.create_tween().tween_property(_bubble, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

func _build_cards() -> void:
	for c in _cards.get_children():
		c.queue_free()
	_rows.clear()
	var todo := _todo()
	_logo.active = todo.filter(func(p): return p in ["r", "h"])
	_logo.done = {}
	for p in todo:
		_cards.add_child(_size_card(p) if p in ["r", "h"] else _colour_card(p))

func _card_shell() -> PanelContainer:
	var card: PanelContainer = pc._panel(Color("fbf7f2"), Vector2.ZERO, 14)
	var st := card.get_theme_stylebox("panel") as StyleBoxFlat
	st.border_color = Color("efe2d3")
	st.set_border_width_all(2)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	return card

func _disc() -> Label:
	var d: Label = pc._label("", Color.WHITE, 18)
	d.custom_minimum_size = Vector2(30, 30)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return d

func _size_card(p: String) -> Control:
	var card := _card_shell()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var disc := _disc()
	h.add_child(disc)
	var up: bool = float(_target()[p]) > float(_base[p])
	var icon := MiniIcon.new()
	icon.part = p
	icon.up = up
	icon.ring = RINGS[cur["ring"]]
	icon.custom_minimum_size = Vector2(44, 44)
	h.add_child(icon)
	var key := ("DESIGN_DO_R_" if p == "r" else "DESIGN_DO_H_") + ("UP" if up else "DOWN")
	var l: Label = pc._label(tr(key), INK, 21)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	var minus := _round_button("−", p, -1)
	var plus := _round_button("+", p, 1)
	h.add_child(minus)
	h.add_child(plus)
	card.mouse_entered.connect(_hover.bind(p, -1.0))
	card.mouse_exited.connect(_hover.bind("", -1.0))
	_rows[p] = {"card": card, "disc": disc, "minus": minus, "plus": plus, "icon": icon}
	return card

func _round_button(text: String, p: String, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(44, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(func():
		if pc._pause > 0.0:
			return
		_learned()
		_set_part(p, float(cur[p]) + STEP * dir)
		_changed())
	return b

func _colour_card(p: String) -> Control:
	var card := _card_shell()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var disc := _disc()
	h.add_child(disc)
	var l: Label = pc._label(tr("DESIGN_RING" if p == "ring" else "DESIGN_INNER"), INK, 21)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	h.add_child(pc._label("→", Color("a07a5a"), 19))
	var colours: Array = RINGS if p == "ring" else INNERS
	var want: int = _target()[p]
	var chip: PanelContainer = pc._panel(colours[want], Vector2(28, 28), 7)
	(chip.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color("c9ced8")
	(chip.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(2)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(chip)
	v.add_child(h)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 40)
	pad.add_child(row)
	v.add_child(pad)
	var swatches: Array = []
	for i in colours.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(40, 40)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var tick: Label = pc._label("✓", Color.WHITE, 18)
		tick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tick.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tick.add_theme_constant_override("outline_size", 5)
		tick.add_theme_color_override("font_outline_color", INK)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tick)
		if i == want:
			var ring := PenRing.new()
			ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(ring)
		b.pressed.connect(func():
			if pc._pause > 0.0:
				return
			cur[p] = i
			_changed())
		row.add_child(b)
		swatches.append(b)
	_rows[p] = {"card": card, "disc": disc, "swatches": swatches, "colours": colours}
	return card

func _snap(what: String, v: float) -> float:
	var want: float = _target()[what]
	return want if absf(v - want) < SNAP else v

func _matched(what: String) -> bool:
	if what in ["ring", "inner"]:
		return int(cur[what]) == int(_target()[what])
	return absf(float(cur[what]) - float(_target()[what])) < 0.001

func _left() -> int:
	return _todo().filter(func(p): return not _matched(p)).size()

func _look() -> Dictionary:
	if pc.night:
		var k := ease(progress / REV_CHARS, -1.8)
		var a: Dictionary = _from
		var b := _target()
		return {"ring": (RINGS[a["ring"]] as Color).lerp(RINGS[b["ring"]], k),
			"inner": (INNERS[a["inner"]] as Color).lerp(INNERS[b["inner"]], k),
			"r": lerpf(a["r"], b["r"], k), "h": lerpf(a["h"], b["h"], k)}
	return {"ring": RINGS[cur["ring"]], "inner": INNERS[cur["inner"]], "r": cur["r"], "h": cur["h"]}

func _set_part(what: String, v: float) -> void:
	"""A new size or hole (snapping onto the red circle when close); the hole stays inside the ring."""
	if what == "r":
		cur["r"] = _snap("r", clampf(v, R_RANGE.x, R_RANGE.y))
		cur["h"] = minf(float(cur["h"]), float(cur["r"]) - 0.1)
	else:
		cur["h"] = _snap("h", clampf(v, H_RANGE.x, minf(H_RANGE.y, float(cur["r"]) - 0.1)))

func _changed() -> void:
	var was := _left()
	_show()
	if _left() < was:
		_idle = 0.0
	if was > 0 and _left() == 0:
		_send.pivot_offset = _send.size * 0.5
		_send.scale = Vector2(1.1, 1.1)
		_send.create_tween().tween_property(_send, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)

func _show() -> void:
	_title.text = (PROJECTS[_project]["file"] as String) % rev + " — " + tr("OS_DESIGN")
	if _resting:
		_logo.editing = false
		_logo.want = {}
		_logo.queue_redraw()
		_paint_dots()
		_dots.visible = _logo.stamp != ""
		_round_label.visible = _dots.visible
		_send.visible = not tasked
		_send_look(Color("eef5ff"), Color("3a6ea8"), tr("DESIGN_NEW_JOB"))
		_send.disabled = false
		_hint.visible = true
		_hint.text = tr("DESIGN_HINT_REST")
		return
	_send.visible = true
	_dots.visible = true
	_round_label.visible = true
	_logo.look = _look()
	_logo.editing = pc._pause <= 0.0 and not pc.night
	_logo.queue_redraw()
	_paint_dots()
	if pc.night:
		_bar.value = progress
		_bar_label.text = tr("DESIGN_EDITING").format({"v": rev + 1}) + "   %d%%" % int(100.0 * progress / REV_CHARS)
		_size.text = "W %d   H %d" % [int(_logo.look["r"] * 400), int(_logo.look["r"] * 400)]
		return
	_logo.want = {}
	if pc._pause <= 0.0:
		for p in _logo.active:
			_logo.want[p] = _target()[p]
	for p in _rows:
		var row: Dictionary = _rows[p]
		var ok := _matched(p)
		var st := (row["card"] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		st.bg_color = Color("eaf7ee") if ok else Color("fbf7f2")
		st.border_color = _card_border(p, ok)
		var disc: Label = row["disc"]
		disc.text = "✓" if ok else ""
		var ds: StyleBoxFlat = pc._rect(GREEN if ok else Color.WHITE, 15)
		ds.border_color = GREEN if ok else Color("c9a98a")
		ds.set_border_width_all(2)
		disc.add_theme_stylebox_override("normal", ds)
		if ok and not _was_ok.get(p, false):
			disc.pivot_offset = Vector2(15, 15)
			disc.scale = Vector2.ZERO
			disc.create_tween().tween_property(disc, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
			if p in ["r", "h"]:
				_logo.done[p] = 0.0
		elif not ok and _was_ok.get(p, false):
			_logo.done.erase(p)
		_was_ok[p] = ok
		if row.has("swatches"):
			for i in (row["swatches"] as Array).size():
				var b: Button = row["swatches"][i]
				var picked: bool = i == int(cur[p])
				for s in ["normal", "hover", "pressed"]:
					var sb: StyleBoxFlat = pc._rect(row["colours"][i], 10)
					sb.border_color = INK if picked else (Color("8a919c") if s != "normal" else Color("c9ced8"))
					sb.set_border_width_all(3 if picked else 2)
					b.add_theme_stylebox_override(s, sb)
				(b.get_child(0) as Label).visible = picked
		else:
			var icon: MiniIcon = row["icon"]
			icon.ring = RINGS[cur["ring"]]
			icon.inner = INNERS[cur["inner"]]
			icon.queue_redraw()
			var dir := signf(float(_target()[p]) - float(cur[p]))
			for k in [["minus", -1.0], ["plus", 1.0]]:
				var b: Button = row[k[0]]
				var lead: bool = not ok and dir == k[1]
				for s in ["normal", "hover", "pressed"]:
					var sb: StyleBoxFlat = pc._rect(PINK if lead else Color("f1f3f6"), 22)
					if s != "normal":
						sb.bg_color = sb.bg_color.darkened(0.08)
					b.add_theme_stylebox_override(s, sb)
				for c in ["font_color", "font_hover_color", "font_pressed_color"]:
					b.add_theme_color_override(c, Color.WHITE if lead else Color("4a5160"))
	var left := _left()
	if pc._pause > 0.0:
		_send_look(Color("7fcf8a"), Color.WHITE, tr("DESIGN_SENT_BTN").format({"v": rev + 1}))
		_send.disabled = true
	elif left > 0:
		_send_look(Color("eef0f4"), Color("8a919c"), tr("DESIGN_LEFT").format({"n": left}))
		_send.disabled = true
	else:
		_send_look(PINK, Color.WHITE, tr("MG_SEND") + "  ➤")
		_send.disabled = false
	_hint.visible = pc._pause <= 0.0
	if left == 0:
		_hint.text = tr("DESIGN_HINT_SEND")
	elif _logo.active.any(func(p): return not _matched(p)):
		_hint.text = tr("DESIGN_HINT_DRAG")
	else:
		_hint.text = tr("DESIGN_HINT_SWATCH")

func _card_border(p: String, ok: bool) -> Color:
	return Color("9fd8ae") if ok else (BLUE if _logo.hover == p else Color("efe2d3"))

func _hover(p: String, ghost: float) -> void:
	"""The pointer over an edge (or its card): light it up - only what changes, nothing rebuilt."""
	if p == _logo.hover and is_equal_approx(ghost, _logo.ghost):
		return
	var was := _logo.hover
	_logo.hover = p
	_logo.ghost = ghost
	_logo.mouse_default_cursor_shape = Control.CURSOR_DRAG if p != "" else Control.CURSOR_ARROW
	if was != p:
		for k in [was, p]:
			if _rows.has(k):
				((_rows[k]["card"] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat).border_color = _card_border(k, _matched(k))
	_logo.queue_redraw()

func _nudge() -> void:
	"""A press away from the edges: point at what to do (the ghost knob slides once, the hint pill pops)."""
	_logo.hand = 0.0
	_idle = 0.0
	_hint.pivot_offset = _hint.size * 0.5
	_hint.scale = Vector2(1.08, 1.08)
	_hint.create_tween().tween_property(_hint, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)

func _send_look(bg: Color, fg: Color, text: String) -> void:
	_send.text = text
	for s in ["normal", "hover", "pressed", "disabled"]:
		_send.add_theme_stylebox_override(s, pc._rect(bg.darkened(0.06) if s in ["hover", "pressed"] else bg, 18))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		_send.add_theme_color_override(c, fg)

func _paint_dots() -> void:
	var n: int = _rounds().size()
	if _dots.get_child_count() != n:
		for c in _dots.get_children():
			c.queue_free()
		for i in n:
			var d := Panel.new()
			d.custom_minimum_size = Vector2(12, 12)
			d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_dots.add_child(d)
	for i in mini(n, _dots.get_child_count()):
		var done: bool = i < _step or (i == _step and (_signed or pc._pause > 0.0))
		var sb: StyleBoxFlat = pc._rect(PINK if done else (Color("f9cdd9") if i == _step else Color("e3e6eb")), 6)
		if i == _step and not done:
			sb.border_color = PINK
			sb.set_border_width_all(2)
		(_dots.get_child(i) as Panel).add_theme_stylebox_override("panel", sb)
	_round_label.text = "  %d/%d" % [mini(_step + 1, n), n]

func _on_logo(e: InputEvent) -> void:
	"""On the logo: the pointer lights the nearest edge that may move (and shows where it would go); a press
	right on the red circle puts it there, else it grabs that edge and drags it."""
	if pc._pause > 0.0 or _logo.active.is_empty() or not (e is InputEventMouse):
		return
	var d: float = (e.position - _logo.size * 0.5).length() / _logo.radius()
	var near := ""
	var best := INF
	for p in _logo.active:
		var gap := absf(d - float(cur[p]))
		if gap < best:
			best = gap
			near = p
	var on := best * _logo.radius() < 28.0
	for p in _logo.active:
		if (e.position as Vector2).distance_to(_logo.knob(p)) < 28.0:
			on = true
			near = p
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			for p in _logo.active:
				if not _matched(p) and absf(d - float(_target()[p])) * _logo.radius() < 16.0:
					_learned()
					_set_part(p, float(_target()[p]))
					_drag = p
					_changed()
					return
			if not on:
				_nudge()
				return
			_learned()
			_drag = near
			_drag_to(e.position)
		else:
			_drag = ""
	elif e is InputEventMouseMotion:
		if _drag != "":
			_drag_to(e.position)
		else:
			_hover(near if on else "", d if on else -1.0)

func _drag_to(at: Vector2) -> void:
	_set_part(_drag, (at - _logo.size * 0.5).length() / _logo.radius())
	_logo.hover = _drag
	_logo.ghost = -1.0
	_changed()

func _on_send() -> void:
	if _send.disabled:
		return
	if _resting:
		if pc._pause <= 0.0 and not tasked:
			_new_file()
		return
	pc.typed.emit(int(REV_CHARS))
	_finish()

func write(n: int) -> void:
	"""The keys: at night they push the logo along; by day the work is done with the mouse."""
	if not pc.night or pc._pause > 0.0 or n <= 0:
		return
	var before := progress
	progress = minf(REV_CHARS, progress + n)
	pc.typed.emit(int(progress - before))
	_show()
	if progress >= REV_CHARS:
		_finish()

func _finish() -> void:
	"""Off to the client: they are typing... then their next comment (next()) - or, the third time, their OK
	and the stamp."""
	_signed = _step == _rounds().size() - 1
	pc._pause = 4.5 if _signed else 1.6
	_drag = ""
	_logo.hover = ""
	_show()
	var sent: String = tr("DESIGN_SENT").format({"v": rev + 1})
	if pc.night:
		pc._toast_show("✓  " + sent)
	else:
		_typing = true
	if _signed:
		approved += 1
		pc.get_tree().create_timer(1.0).timeout.connect(func():
			_typing = false
			_say(tr("DESIGN_OK"))
			if _mean:
				_mean.visible = false
			_logo.stamp = tr("DESIGN_STAMP")
			_logo.stamp_t = 0.0
			if not pc.night:
				_rest()
			pc.task_done.emit(tr("DESIGN_APPROVED")))
	else:
		pc.task_done.emit(sent)

func next() -> void:
	"""The next version: from the logo just sent, towards what the client now wants (a new file once they
	signed the last one off)."""
	_typing = false
	_base = _target()
	_from = _base
	cur = _base.duplicate()
	if _signed:
		_signed = false
		if pc.night:
			_new_file()
		elif _queued != null:
			job = _queued
			_queued = null
			_new_file()
		return
	_step += 1
	rev += 1
	progress = 0.0
	_open_round()

func _rest(signed := true) -> void:
	"""Nothing to do: just signed off (the task is done, the next one may come up) - or nothing given yet."""
	_resting = true
	for c in _cards.get_children():
		c.queue_free()
	_rows.clear()
	_logo.active = []
	var card := _card_shell()
	if signed:
		(card.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("eaf7ee")
		(card.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color("9fd8ae")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if signed:
		v.add_child(pc._label("★  " + tr("DESIGN_APPROVED"), Color("2f7a4a"), 20))
	var l: Label = pc._label(tr("DESIGN_REST" if signed else "DESIGN_NO_JOB"), Color("4a5160"), 18)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	card.add_child(v)
	_cards.add_child(card)
	_show()
	if signed and tasked and job != null:
		var done = job
		job = null
		pc.design_done.emit(done)

func use_tasks() -> void:
	"""From now on the jobs come from the task list: none yet, nothing to do."""
	tasked = true
	if job == null and not pc.night:
		_say(tr("DESIGN_NO_JOB_SAY"))
		if _mean:
			_mean.visible = false
		_rest(false)

func assign(task) -> void:
	"""A logo task from the list: its file opens (after the stamp, if one is still coming down)."""
	if pc.night:
		return
	if pc._pause > 0.0 or _signed:
		_queued = task
		return
	job = task
	_new_file()

func _new_file() -> void:
	_resting = false
	if approved > 0:
		_project = (_project + 1) % PROJECTS.size()
		rev = maxi(rev + 1, PROJECTS[_project]["first"])
	_step = 0
	_logo.stamp = ""
	progress = 0.0
	_open_round()

func _night_comment(text: String) -> void:
	var b: PanelContainer = pc._panel(Color("fff4e8"), Vector2(0, 0), 8)
	(b.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 8
	(b.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_top = 5
	(b.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_bottom = 5
	var l: Label = pc._label(text, Color("7a4a2a"), 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(250, 0)
	b.add_child(l)
	_comments.add_child(b)
	_comments.move_child(b, 0)
	while _comments.get_child_count() > 4:
		var old := _comments.get_child(_comments.get_child_count() - 1)
		_comments.remove_child(old)
		old.queue_free()

func process(delta: float) -> void:
	_t += delta
	_logo.t += delta
	var redraw := _logo.editing
	for p in _logo.done:
		_logo.done[p] += delta
		redraw = true
	if _logo.stamp != "" and _logo.stamp_t < 0.3:
		_logo.stamp_t += delta
		redraw = true
	if pc.night:
		if redraw:
			_logo.queue_redraw()
		return
	if _logo.editing and pc.shown and not _resting:
		_idle += delta
		if _idle > IDLE_NUDGE and _left() > 0:
			_idle = 0.0
			_logo.hand = 0.0
	if _logo.hand >= 0.0:
		_logo.hand += delta
		if _logo.hand > (6.6 if not _taught else 2.2):
			_logo.hand = -1.0
		redraw = true
	if _typing:
		_bubble_label.text = ["•", "•  •", "•  •  •"][int(_t * 3.0) % 3]
	if not _send.disabled and not _resting:
		_send.pivot_offset = _send.size * 0.5
		_send.scale = Vector2.ONE * (1.0 + 0.03 * sin(_t * 7.5))
	else:
		_send.scale = Vector2.ONE
	if redraw:
		_logo.queue_redraw()
