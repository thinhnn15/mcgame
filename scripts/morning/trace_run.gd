class_name TraceRun
extends MiniGame

const CASES := [
	{"ask": "MG_T1_ASK", "cart": "MG_T1_CART", "want": 70000, "bug": 4, "fixed": "sum += item.price * item.qty;",
		"steps": [["MG_T_START", "int Cart::total() const {", -1], ["MG_T_ZERO", "int sum = 0;", 0],
			["MG_T1_ITEM", "for (const auto& item : items_) {", 0], ["MG_T1_SKIP", "if (item.qty <= 0) continue;", 0],
			["MG_T1_ADD", "sum += item.price;", 35000], ["MG_T_LOOP_END", "}", 35000], ["MG_T_RETURN", "return sum;", 35000]],
		"fixes": [["MG_T1_F1", true], ["MG_T1_F2", false], ["MG_T1_F3", false]]},
	{"ask": "MG_T2_ASK", "cart": "MG_T2_CART", "want": 120000, "bug": 3, "fixed": "if (sum < 100000) sum += 20000;",
		"steps": [["MG_T_START", "int Cart::total() const {", -1], ["MG_T_ZERO", "int sum = 0;", 0],
			["MG_T2_ITEMS", "for (const auto& item : items_) sum += item.price * item.qty;", 120000],
			["MG_T2_SHIP", "if (sum > 100000) sum += 20000;", 140000], ["MG_T_RETURN", "return sum;", 140000]],
		"fixes": [["MG_T2_F1", true], ["MG_T2_F2", false], ["MG_T2_F3", false]]},
	{"ask": "MG_T3_ASK", "cart": "MG_T3_CART", "want": 180000, "bug": 3, "fixed": "sum -= sum * 10 / 100;",
		"steps": [["MG_T_START", "int Cart::total() const {", -1], ["MG_T_ZERO", "int sum = 0;", 0],
			["MG_T3_ITEMS", "for (const auto& item : items_) sum += item.price * item.qty;", 200000],
			["MG_T3_CODE", "if (coupon_ == \"GIAM10\") sum -= 10;", 199990], ["MG_T_RETURN", "return sum;", 199990]],
		"fixes": [["MG_T3_F1", true], ["MG_T3_F2", false], ["MG_T3_F3", false]]},
]
const STEP_SECS := 0.65

static var _last_case := -1

var case := {}
var _stage := "ready"
var _misses := 0
var _wrong_fix := 0
var _fixed := false
var _lines: Array = []
var _sum: Label
var _sum_box: PanelContainer
var _verdict_l: Label
var _fixes: VBoxContainer
var _run: Button
var _checks: Array = []
var _hint := -1.0
var _hint_on := false
var _mono: SystemFont

static func money(n: int) -> String:
	"""Dong, written the way the player's language writes it."""
	var lang := TranslationServer.get_locale().left(2)
	var digits := str(absi(n))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "." if lang == "vi" else ","
		out += digits[i]
	match lang:
		"vi":
			return out + "đ"
		"ja":
			return out + "ドン"
		"ko":
			return out + "동"
		"zh":
			return out + "越南盾"
	return "₫" + out

func _args() -> Dictionary:
	return {"p": money(35000), "q": money(100000), "s": money(20000), "x": money(20000), "d": money(10),
		"a": money(120000), "b": money(200000)}

func _build(area: Control) -> void:
	var pick := randi() % CASES.size()
	if pick == _last_case:
		pick = (pick + 1) % CASES.size()
	_last_case = pick
	case = CASES[pick]
	duration = 60.0 * (1.0 - 0.25 * difficulty) * (0.85 if hard else 1.0)
	_left = duration
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Menlo", "monospace"])
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	h.size = MiniGame.AREA
	area.add_child(h)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	main.custom_minimum_size = Vector2(560, 0)
	h.add_child(main)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_box(tr("MG_T_TRY"), Lang.t(case["cart"], _args())))
	row.add_child(_box(tr("MG_T_WANT"), money(case["want"])))
	_sum_box = _box(tr("MG_T_NOW"), "—")
	_sum = _sum_box.get_child(0).get_child(1)
	row.add_child(_sum_box)
	main.add_child(row)
	for i in (case["steps"] as Array).size():
		var st: Array = case["steps"][i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 44)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
		v.offset_left = 12
		v.add_theme_constant_override("separation", -2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var words := label(Lang.t(st[0], _args()), 17, UiTheme.INK)
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(words)
		var code := label(st[1], 13, Color("a08a82"))
		code.add_theme_font_override("font", _mono)
		code.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(code)
		b.add_child(v)
		b.pressed.connect(_on_line.bind(i))
		main.add_child(b)
		_lines.append(b)
		_paint(i, "")
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(side)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UiTheme.box(Color("fff4e8"), 16, Color("f0c9a8"), 2, 12))
	var ask := label(tr("CHAT_P_BAO") + ": " + Lang.t(case["ask"], _args()), 17, Color("7a4a2a"))
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.custom_minimum_size = Vector2(270, 0)
	bubble.add_child(ask)
	side.add_child(bubble)
	for k in ["MG_T_S1", "MG_T_S2", "MG_T_S3", "MG_T_S4"]:
		var c := label("○  " + tr(k), 17, Color("a08a82"))
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.custom_minimum_size = Vector2(270, 0)
		side.add_child(c)
		_checks.append(c)
	_verdict_l = label("", 17, Color("d9363e"))
	_verdict_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_verdict_l.custom_minimum_size = Vector2(270, 0)
	side.add_child(_verdict_l)
	_fixes = VBoxContainer.new()
	_fixes.add_theme_constant_override("separation", 6)
	_fixes.visible = false
	side.add_child(_fixes)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(gap)
	_run = button(tr("MG_T_RUN"), 22)
	_run.custom_minimum_size = Vector2(0, 56)
	_run.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PINK_DARK, 16))
	_run.add_theme_color_override("font_color", Color.WHITE)
	_run.pressed.connect(_on_run)
	side.add_child(_run)

func _box(head: String, value: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(Color.WHITE, 10, Color("e4dcea"), 2, 10))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(label(head, 14, Color("a08a82")))
	var l := label(value, 18, UiTheme.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	p.add_child(v)
	return p

func _paint(i: int, how: String) -> void:
	"""A line's look: "" plain, now (being run), no (ruled out), hint, hit (the bug), fixed."""
	var b: Button = _lines[i]
	var c: Array = {"": [Color.WHITE, Color("e4dcea")], "now": [Color("eef5ff"), Color("5aa0f2")], "no": [Color("f6f3f1"), Color("e4dcea")],
		"hint": [Color("fff6e0"), Color("f2b84e")], "hit": [Color("fff1f1"), Color("e0565e")], "fixed": [Color("eefaf2"), Color("4aa56a")]}[how]
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, UiTheme.box(c[0], 10, UiTheme.PINK if st == "hover" and how in ["", "hint"] else c[1], 2, 8))
	b.modulate.a = 0.55 if how == "no" else 1.0

func _tick_check(k: int) -> void:
	(_checks[k] as Label).text = "✓  " + tr(["MG_T_S1", "MG_T_S2", "MG_T_S3", "MG_T_S4"][k])
	(_checks[k] as Label).add_theme_color_override("font_color", Color("4aa56a"))

func _play(then: Callable) -> void:
	"""Run the lines one at a time, the total changing as it goes (fixed: right from the bug on)."""
	var steps: Array = case["steps"]
	for i in steps.size():
		if not is_inside_tree():
			return
		for k in steps.size():
			if (_lines[k] as Button).modulate.a > 0.6 or k == i:
				_paint(k, "now" if k == i else ("fixed" if _fixed and k == case["bug"] else ""))
		var v: int = case["want"] if _fixed and i >= int(case["bug"]) else int(steps[i][2])
		_sum.text = "—" if v < 0 else money(v)
		var wrong: bool = not _fixed and i >= int(case["bug"])
		_sum_box.add_theme_stylebox_override("panel", UiTheme.box(Color("fff1f1") if wrong else Color.WHITE, 10,
			Color("e0565e") if wrong else Color("e4dcea"), 2, 10))
		await get_tree().create_timer(STEP_SECS).timeout
	for k in steps.size():
		_paint(k, "fixed" if _fixed and k == case["bug"] else "")
	then.call()

func _on_run() -> void:
	if _stage != "ready":
		return
	_stage = "running"
	_run.visible = false
	_play(func():
		_tick_check(0)
		_stage = "pick"
		var steps: Array = case["steps"]
		_verdict_l.text = Lang.t("MG_T_WRONG", {"a": money(int(steps[-1][2])), "b": money(case["want"])}))

func _on_line(i: int) -> void:
	if _stage != "pick" or not _running:
		return
	var bug: int = case["bug"]
	if i != bug:
		_misses += 1
		_paint(i, "no")
		_verdict_l.text = tr("MG_T_TOO_EARLY") if i < bug else tr("MG_T_TOO_LATE")
		shake(_lines[i])
		fumble()
		if _misses >= 2:
			_hint = 0.0
		return
	_hint = -1.0
	_stage = "fix"
	_paint(bug, "hit")
	_tick_check(1)
	_verdict_l.add_theme_color_override("font_color", UiTheme.INK)
	_verdict_l.text = tr("MG_T_HOW")
	_fixes.visible = true
	var order: Array = range((case["fixes"] as Array).size())
	order.shuffle()
	for k in order:
		var f: Array = case["fixes"][k]
		var b := button(Lang.t(f[0], _args()), 16)
		b.custom_minimum_size = Vector2(270, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_fix.bind(b, bool(f[1])))
		_fixes.add_child(b)

func _on_fix(b: Button, right: bool) -> void:
	if _stage != "fix" or not _running:
		return
	if not right:
		_wrong_fix += 1
		b.disabled = true
		b.modulate.a = 0.4
		shake(b)
		fumble()
		return
	_stage = "rerun"
	_fixed = true
	_tick_check(2)
	_fixes.visible = false
	var bug: int = case["bug"]
	var code: Label = (_lines[bug] as Button).get_child(0).get_child(1)
	code.text = case["fixed"]
	_paint(bug, "fixed")
	_verdict_l.text = tr("MG_T_RERUN")
	_play(func():
		_tick_check(3)
		_stage = "done"
		_sum_box.add_theme_stylebox_override("panel", UiTheme.box(Color("eefaf2"), 10, Color("4aa56a"), 2, 10))
		_verdict_l.add_theme_color_override("font_color", Color("4aa56a"))
		_verdict_l.text = Lang.t("MG_T_DONE", {"b": money(case["want"])})
		await get_tree().create_timer(0.9).timeout
		done(clampf(1.0 - 0.15 * _misses - 0.25 * _wrong_fix, 0.0, 1.0)))

func _tick(delta: float) -> void:
	if _hint >= 0.0 and _stage == "pick":
		_hint += delta
		var on := fmod(_hint, 0.8) < 0.5
		if on != _hint_on:
			_hint_on = on
			_paint(case["bug"], "hint" if on else "")

func timeout_score() -> float:
	return {"ready": 0.0, "running": 0.0, "pick": 0.15, "fix": 0.3, "rerun": 0.45, "done": 0.6}[_stage]
