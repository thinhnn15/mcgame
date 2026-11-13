class_name DesignPick
extends MiniGame

const PALETTE := [Color("ff8c69"), Color("5aa0f2"), Color("6cc08b"), Color("f2c14e"), Color("b07ad0"),
	Color("e86a9a"), Color("4fc3c3"), Color("2f3a4f")]
const SHAPES := ["circle", "square", "rounded", "diamond", "triangle", "hexagon", "octagon", "star5", "star6", "heart", "drop"]

const LOOKALIKE := [["square", "rounded", "diamond"], ["circle", "hexagon", "octagon"], ["star5", "star6"], ["heart", "drop"]]

const LAYOUTS := [
	[["img", 0.04, 0.08, 0.44, 0.84], ["title", 0.54, 0.16, 0.4, 0.12], ["text", 0.54, 0.36, 0.36, 0.14], ["btn", 0.54, 0.66, 0.2, 0.12]],
	[["img", 0.52, 0.08, 0.44, 0.84], ["title", 0.06, 0.16, 0.4, 0.12], ["text", 0.06, 0.36, 0.36, 0.14], ["btn", 0.06, 0.66, 0.2, 0.12]],
	[["img", 0.04, 0.06, 0.92, 0.5], ["title", 0.06, 0.66, 0.5, 0.12], ["btn", 0.74, 0.66, 0.2, 0.12]],
	[["img", 0.0, 0.0, 1.0, 1.0], ["title", 0.25, 0.3, 0.5, 0.12], ["btn", 0.4, 0.6, 0.2, 0.12]],
	[["title", 0.2, 0.2, 0.6, 0.14], ["text", 0.25, 0.44, 0.5, 0.12], ["btn", 0.4, 0.68, 0.2, 0.12]],
	[["img", 0.08, 0.2, 0.3, 0.6], ["title", 0.46, 0.2, 0.46, 0.12], ["btn", 0.46, 0.62, 0.2, 0.12]],
	[["title", 0.06, 0.1, 0.88, 0.12], ["img", 0.06, 0.34, 0.5, 0.58], ["btn", 0.72, 0.7, 0.22, 0.12]],
	[["title", 0.06, 0.1, 0.6, 0.12], ["text", 0.06, 0.28, 0.5, 0.1], ["img", 0.04, 0.48, 0.92, 0.46]],
]
const LAYOUT_LOOKALIKE := [[0, 1, 5], [2, 7, 6], [3, 4]]
const BUTTONS := [Color("f08aa6"), Color("5aa0f2"), Color("6cc08b")]
const SCREEN_BUGS := ["header", "img", "title", "price", "btn_colour", "btn_gone", "swap"]
const OPTIONS := 6
const MISS_SECS := 2.0

var mode := "colour"
var rounds := 3
var _round := 0
var _misses := 0
var _round_misses := 0
var _answer := 0
var _ref: Pic
var _bubble: Label
var _count: Label
var _grid: GridContainer
var _options: Array = []
var _hint := -1.0

class Pic:
	extends Control
	var mode := "colour"
	var sketch := false
	var data = null
	var thing := 0
	var glow := 0.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		match mode:
			"colour":
				if sketch:
					_photo(r)
				else:
					_tile(r, data, "rounded")
			"shape":
				if sketch:
					_scribble(r, data)
				else:
					_tile(r, Color("ff8c69"), data)
			"layout":
				_banner(r, LAYOUTS[data])
			"screen":
				_phone(r, data)
		if glow > 0.0:
			draw_rect(r.grow(-2), Color(1.0, 0.75, 0.3, glow), false, 5.0)

	func _photo(r: Rect2) -> void:
		"""A snapshot the client took: something in the colour they want, on a soft background."""
		draw_rect(r, Color("f4efe8"))
		var c := r.get_center()
		var s := minf(r.size.x, r.size.y) * 0.36
		var col: Color = data
		match thing % 3:
			0:
				var cup := PackedVector2Array([c + Vector2(-s * 0.7, -s * 0.6), c + Vector2(s * 0.7, -s * 0.6),
					c + Vector2(s * 0.5, s), c + Vector2(-s * 0.5, s)])
				draw_colored_polygon(cup, col)
				draw_rect(Rect2(c + Vector2(-s * 0.8, -s * 0.8), Vector2(s * 1.6, s * 0.22)), Color("ffffff"))
				draw_line(c + Vector2(s * 0.15, -s * 0.8), c + Vector2(s * 0.35, -s * 1.3), Color("6b5b55"), 5.0)
			1:
				var leaf := PackedVector2Array()
				for i in 25:
					var t := TAU * i / 24.0
					leaf.append(c + Vector2(cos(t) * s * 0.55, sin(t) * s).rotated(0.6))
				draw_colored_polygon(leaf, col)
				draw_line(c + Vector2(0, s).rotated(0.6), c + Vector2(0, -s).rotated(0.6), col.darkened(0.25), 3.0)
			_:
				draw_line(c + Vector2(0, s * 0.8), c + Vector2(s * 0.2, s * 1.4), Color("8a7d77"), 2.0)
				draw_circle(c + Vector2(0, -s * 0.1), s * 0.85, col, true, -1.0, true)
				draw_circle(c + Vector2(-s * 0.3, -s * 0.45), s * 0.15, Color(1, 1, 1, 0.5), true, -1.0, true)

	func _tile(r: Rect2, col: Color, shape: String) -> void:
		"""A choice: the logo in its shape and colour, a light centre for the shop's mark."""
		draw_rect(r, Color("fffaf2"))
		var c := r.get_center()
		var s := minf(r.size.x, r.size.y) * 0.38
		var pts := DesignPick.outline(shape, c, s)
		draw_colored_polygon(pts, col)
		draw_circle(c + Vector2(0, s * (0.12 if shape in ["triangle", "drop"] else 0.0)), s * 0.28, Color(1, 1, 1, 0.85), true, -1.0, true)

	func _scribble(r: Rect2, shape: String) -> void:
		"""The client's pencil: the shape's outline drawn twice, a little wobbly."""
		draw_rect(r, Color("fdfcf7"))
		var c := r.get_center()
		var s := minf(r.size.x, r.size.y) * 0.36
		for pass_i in 2:
			var pts := DesignPick.outline(shape, c, s * (1.0 + 0.03 * pass_i))
			var wob := PackedVector2Array()
			for i in pts.size():
				var p: Vector2 = pts[i]
				wob.append(p + Vector2(sin(i * 1.7 + pass_i * 2.0), cos(i * 2.3 + pass_i)) * 2.2)
			wob.append(wob[0])
			draw_polyline(wob, Color(0.35, 0.33, 0.36, 0.8 - 0.35 * pass_i), 2.5, true)

	func _phone(r: Rect2, sc: Dictionary) -> void:
		"""An app screen on a phone: a header, a photo, the title, the price, the button."""
		var h := r.size.y * 0.92
		var w := h * 0.56
		var ph := Rect2(r.get_center() - Vector2(w, h) * 0.5, Vector2(w, h))
		draw_rect(ph.grow(3), Color("2e2a33"))
		draw_rect(ph, Color("fffaf6"))
		var y := ph.position.y
		var pad := w * 0.08
		if sc["header"]:
			draw_rect(Rect2(ph.position, Vector2(w, h * 0.1)), Color("5b4a44"))
		y += h * 0.13
		var img := Rect2(Vector2(ph.position.x + pad, 0), Vector2(w - pad * 2, h * 0.34))
		var title := Rect2(Vector2(ph.position.x + pad, 0), Vector2((w - pad * 2) * (1.35 if sc["title"] == "long" else 0.7), h * 0.05))
		if sc["swap"]:
			title.position.y = y
			img.position.y = y + h * 0.1
		else:
			img.position.y = y
			title.position.y = y + h * 0.38
		if sc["img"] == "ok":
			draw_rect(img, Color("9fd0e8"))
			draw_colored_polygon(PackedVector2Array([Vector2(img.position.x, img.end.y), img.position + img.size * Vector2(0.35, 0.5),
				img.position + img.size * Vector2(0.6, 0.75), img.position + img.size * Vector2(0.8, 0.55), img.end]), Color("6cc08b"))
		else:
			draw_rect(img, Color("d7d3d8"))
			draw_line(img.position, img.end, Color("a39ea6"), 2.0)
			draw_line(Vector2(img.position.x, img.end.y), Vector2(img.end.x, img.position.y), Color("a39ea6"), 2.0)
		draw_rect(title, Color("5b4a44"))
		var pw := w * 0.3
		var px := ph.position.x + pad if sc["price"] == "left" else ph.end.x - pad - pw
		var py := maxf(img.end.y, title.end.y) + h * 0.04
		draw_rect(Rect2(px, py, pw, h * 0.06), Color("ff8c69"))
		if sc["btn"] != null:
			draw_rect(Rect2(ph.position.x + pad, ph.end.y - h * 0.14, w - pad * 2, h * 0.08), sc["btn"])

	func _banner(r: Rect2, items: Array) -> void:
		var h := r.size.x * 0.56
		var b := Rect2(r.position + Vector2(0, (r.size.y - h) * 0.5), Vector2(r.size.x, h))
		draw_rect(b, Color("fdfcf7") if sketch else Color("fff4e8"))
		var ink := Color(0.35, 0.33, 0.36, 0.85)
		for it in items:
			var q := Rect2(b.position + Vector2(it[1] * b.size.x, it[2] * b.size.y), Vector2(it[3] * b.size.x, it[4] * b.size.y))
			match it[0]:
				"img":
					if sketch:
						draw_rect(q.grow(-2), ink, false, 2.0)
						draw_line(q.position + Vector2(2, 2), q.end - Vector2(2, 2), ink, 1.5)
						draw_line(Vector2(q.position.x + 2, q.end.y - 2), Vector2(q.end.x - 2, q.position.y + 2), ink, 1.5)
					else:
						draw_rect(q, Color("9fd0e8"))
						var m := PackedVector2Array([Vector2(q.position.x, q.end.y), q.position + q.size * Vector2(0.4, 0.45),
							q.position + q.size * Vector2(0.65, 0.7), q.position + q.size * Vector2(0.8, 0.55), q.end])
						draw_colored_polygon(m, Color("6cc08b"))
						draw_circle(q.position + q.size * Vector2(0.78, 0.25), minf(q.size.x, q.size.y) * 0.1, Color("f2c14e"))
				"title":
					if sketch:
						draw_line(q.position + Vector2(0, q.size.y * 0.5), q.position + Vector2(q.size.x, q.size.y * 0.5), ink, 5.0)
					else:
						draw_rect(q, Color("5b4a44"))
				"text":
					for k in 2:
						var y := q.position.y + q.size.y * (0.25 + 0.5 * k)
						draw_line(Vector2(q.position.x, y), Vector2(q.position.x + q.size.x * (1.0 - 0.3 * k), y),
							ink if sketch else Color("a08a82"), 2.0)
				"btn":
					if sketch:
						draw_rect(q, ink, false, 2.0)
					else:
						draw_rect(q, Color("f08aa6"))
		if sketch:
			draw_rect(b, ink, false, 2.0)

static func outline(shape: String, c: Vector2, s: float) -> PackedVector2Array:
	"""A shape's outline round c, about s from the centre."""
	var pts := PackedVector2Array()
	match shape:
		"circle", "hexagon", "octagon", "triangle":
			var n: int = {"circle": 48, "hexagon": 6, "octagon": 8, "triangle": 3}[shape]
			for i in n:
				var a := -PI / 2.0 + TAU * i / n + (PI / n if shape == "octagon" else 0.0)
				pts.append(c + Vector2(cos(a), sin(a)) * s * (1.1 if shape == "triangle" else 1.0))
		"square":
			for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				pts.append(c + p * s * 0.82)
		"diamond":
			for p in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
				pts.append(c + p * s * 1.1)
		"rounded":
			var k := s * 0.82
			var rr := s * 0.32
			for corner in [[Vector2(k - rr, -k + rr), -PI / 2.0], [Vector2(k - rr, k - rr), 0.0],
					[Vector2(-k + rr, k - rr), PI / 2.0], [Vector2(-k + rr, -k + rr), PI]]:
				for i in 7:
					var a: float = corner[1] + PI / 2.0 * i / 6.0
					pts.append(c + corner[0] + Vector2(cos(a), sin(a)) * rr)
		"star5", "star6":
			var n := 5 if shape == "star5" else 6
			for i in n * 2:
				var a := -PI / 2.0 + PI * i / n
				pts.append(c + Vector2(cos(a), sin(a)) * s * (1.05 if i % 2 == 0 else 0.48))
		"heart":
			for i in 40:
				var t := TAU * i / 40.0
				var x := 16.0 * pow(sin(t), 3)
				var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
				pts.append(c + Vector2(x, -y - 2.0) * s / 16.0)
		"drop":
			for i in 40:
				var t := TAU * i / 40.0
				pts.append(c + Vector2(sin(t) * sin(t / 2.0) * 0.95, -cos(t)) * s * Vector2(1.0, 1.05) + Vector2(0, s * 0.05))
	return pts

func _build(area: Control) -> void:
	rounds = 4 if hard else 3
	duration = {"layout": 46.0, "screen": 50.0}.get(mode, 36.0) * (1.0 - 0.25 * difficulty) * rounds / 3.0
	_left = duration
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	h.size = MiniGame.AREA
	area.add_child(h)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(300, 0)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UiTheme.box(Color("fff4e8"), 16, Color("f0c9a8"), 2, 14))
	_bubble = label(tr("NAME_NGAN" if mode == "screen" else "CHAT_P_HUONG") + ": " + tr({"colour": "MG_ASK_COLOUR",
		"shape": "MG_ASK_SHAPE", "layout": "MG_ASK_LAYOUT", "screen": "MG_ASK_SCREEN"}[mode]), 19, Color("7a4a2a"))
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.custom_minimum_size = Vector2(270, 0)
	bubble.add_child(_bubble)
	left.add_child(bubble)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.box(Color("ffffff"), 14, Color("e8ddd0"), 3, 8))
	_ref = Pic.new()
	_ref.mode = mode
	_ref.sketch = true
	_ref.custom_minimum_size = Vector2(280, 320 if mode == "screen" else 250)
	frame.add_child(_ref)
	left.add_child(frame)
	_count = label("", 18, Color("a08a82"))
	left.add_child(_count)
	h.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	h.add_child(_grid)
	for i in OPTIONS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(168, {"layout": 120, "screen": 200}.get(mode, 150))
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, UiTheme.box(Color.WHITE, 14, {"normal": Color("efe3da"), "hover": UiTheme.PINK,
				"pressed": UiTheme.PINK_DARK, "disabled": Color("efe3da")}[st], 3, 8))
		var p := Pic.new()
		p.mode = mode
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(p)
		b.pressed.connect(_pick.bind(i))
		_grid.add_child(b)
		_options.append(b)
	_next_round()

func _next_round() -> void:
	_round_misses = 0
	_hint = -1.0
	_count.text = Lang.t("MG_TURN", {"n": _round + 1, "all": rounds})
	var want = null
	var others: Array = []
	match mode:
		"colour":
			want = PALETTE[randi() % PALETTE.size()]
			others = _near_colours(want)
		"shape":
			want = SHAPES[randi() % SHAPES.size()]
			others = _other_from(SHAPES, LOOKALIKE, want)
		"layout":
			want = randi() % LAYOUTS.size()
			others = _other_from(range(LAYOUTS.size()), LAYOUT_LOOKALIKE, want)
		"screen":
			want = {"header": true, "img": "ok", "title": "ok", "price": ["left", "right"][randi() % 2],
				"btn": BUTTONS[randi() % BUTTONS.size()], "swap": false}
			others = _buggy_screens(want)
	_answer = randi() % OPTIONS
	_ref.data = want
	_ref.thing = _round + randi() % 3
	_ref.queue_redraw()
	var k := 0
	for i in OPTIONS:
		var b: Button = _options[i]
		b.disabled = false
		b.modulate = Color.WHITE
		var p: Pic = b.get_child(0)
		p.glow = 0.0
		p.data = want if i == _answer else others[k]
		if i != _answer:
			k += 1
		p.queue_redraw()

func _near_colours(want: Color) -> Array:
	"""Five other colours: close to the one wanted (closer when it is urgent or the hero is tired)."""
	var d := 0.035 if hard or difficulty > 0.5 else 0.075
	var out: Array = []
	for step in [[d, 0.0, 0.0], [-d, 0.0, 0.0], [0.0, -0.3, 0.0], [0.0, 0.0, -0.22], [2.2 * d, 0.0, 0.1]]:
		var c := Color.from_hsv(fposmod(want.h + step[0], 1.0), clampf(want.s + step[1], 0.15, 1.0), clampf(want.v + step[2], 0.25, 1.0))
		out.append(c)
	out.shuffle()
	return out

func _buggy_screens(want: Dictionary) -> Array:
	"""Five builds of the screen, each with one bug (subtler ones when it is urgent)."""
	var bugs: Array = SCREEN_BUGS.duplicate()
	bugs.shuffle()
	var out: Array = []
	for bug in bugs.slice(0, OPTIONS - 1):
		var sc := want.duplicate()
		match bug:
			"header":
				sc["header"] = false
			"img":
				sc["img"] = "broken"
			"title":
				sc["title"] = "long"
			"price":
				sc["price"] = "right" if want["price"] == "left" else "left"
			"btn_colour":
				var c: Color = want["btn"]
				sc["btn"] = Color.from_hsv(fposmod(c.h + 0.06, 1.0), c.s, c.v) if hard or difficulty > 0.5 					else BUTTONS[(BUTTONS.find(c) + 1) % BUTTONS.size()]
			"btn_gone":
				sc["btn"] = null
			"swap":
				sc["swap"] = true
		out.append(sc)
	return out

func _other_from(all: Array, alike: Array, want) -> Array:
	"""Five others: when urgent, the look-alikes of the wanted one first."""
	var pool: Array = all.filter(func(x): return x != want)
	pool.shuffle()
	if hard or difficulty > 0.5:
		for g in alike:
			if want in g:
				for x in g:
					if x != want:
						pool.erase(x)
						pool.push_front(x)
	return pool.slice(0, OPTIONS - 1)

func _pick(i: int) -> void:
	if not _running:
		return
	var b: Button = _options[i]
	if i != _answer:
		_misses += 1
		_round_misses += 1
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.35)
		shake(b)
		lose_time(MISS_SECS)
		fumble()
		if _round_misses >= 2:
			_hint = 0.0
		return
	_round += 1
	(b.get_child(0) as Pic).glow = 1.0
	b.get_child(0).queue_redraw()
	if _round >= rounds:
		done(clampf(1.0 - 0.12 * _misses, 0.0, 1.0))
		return
	_running = false
	await get_tree().create_timer(0.45).timeout
	_running = true
	_next_round()

func _tick(delta: float) -> void:
	if _hint >= 0.0:
		_hint += delta
		var p: Pic = (_options[_answer] as Button).get_child(0)
		p.glow = 0.5 + 0.5 * sin(_hint * 7.0)
		p.queue_redraw()

func timeout_score() -> float:
	return clampf(float(_round) / rounds * 0.7 - 0.08 * _misses, 0.0, 1.0)
