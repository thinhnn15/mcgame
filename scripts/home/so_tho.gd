class_name SoTho
extends CanvasLayer

signal closed
signal worked(id: String)

const INK := Color("5b4a44")
const PAPER := Color("fbf3e2")
const PAPER_D := Color("f1e4c8")
const LINE := Color("dcc9a4")
const TICK := Color("5e9a5a")
const MISS := Color("8a7a68")
const WARN := Color("b5652e")
const PICK := Color("ffd98a")
const SKETCH := "res://props/furniture/rooms/so_tho/"

var _list: VBoxContainer
var _page: VBoxContainer
var _sel := ""
var _pages: Array = []
var _pen := {}

static func ready_() -> bool:
	return ClassDB.class_exists("HomeWork")

static func hw(method: String, arg = null):
	if not ready_():
		return null
	return ClassDB.class_call_static("HomeWork", method) if arg == null else ClassDB.class_call_static("HomeWork", method, arg)

func _ready() -> void:
	layer = 20
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.05, 0.3)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)
	var book := PanelContainer.new()
	book.add_theme_stylebox_override("panel", UiTheme.box(PAPER, 22, Color("b98a5e"), 4, 18))
	book.anchor_left = 0.5
	book.anchor_right = 0.5
	book.anchor_top = 0.5
	book.anchor_bottom = 0.5
	book.offset_left = -640
	book.offset_right = 640
	book.offset_top = -380
	book.offset_bottom = 380
	add_child(book)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	book.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := _label(30)
	title.text = tr("SO_THO_TITLE")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var shut := _button(tr("SO_THO_CLOSE"))
	shut.pressed.connect(close)
	head.add_child(shut)
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 18)
	spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spread)

	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UiTheme.box(PAPER_D, 14, LINE, 2, 10))
	left.custom_minimum_size.x = 380
	spread.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UiTheme.box(PAPER, 14, LINE, 2, 16))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spread.add_child(right)
	var rscroll := ScrollContainer.new()
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rscroll)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 10)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.add_child(_page)

func open(page := "") -> void:
	visible = true
	_pages = hw("pages") if ready_() else []
	_sel = page
	if _sel == "" and not _pages.is_empty():
		_sel = String(_first_to_do())
	_fill()
	Sound.play("ui.click", -4.0)

func open_pen(req: Dictionary) -> void:
	visible = true
	_pen = req
	_pages = []
	_sel = ""
	_fill()
	Sound.play("ui.click", -4.0)

static func pen_busy() -> bool:
	return ClassDB.class_exists("PenWork") and not (ClassDB.class_call_static("PenWork", "booked") as Dictionary).is_empty()

func close() -> void:
	if not visible:
		return
	visible = false
	_pen = {}
	closed.emit()

func _unhandled_input(e: InputEvent) -> void:
	if visible and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_ESCAPE, KEY_N]:
		close()
		get_viewport().set_input_as_handled()

func _first_to_do() -> String:
	for p in _pages:
		if not p["done"]:
			return p["id"]
	return _pages[0]["id"]

func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	for c in _page.get_children():
		c.queue_free()
	if not _pen.is_empty():
		_fill_pen()
		return
	if not ready_():
		var l := _label(20)
		l.text = tr("SO_THO_NOT_YET")
		_page.add_child(l)
		return
	var booked: Dictionary = hw("booked")
	for p in _pages:
		var b := _button("")
		var st: Dictionary = hw("check", p["id"])
		b.text = tr("UPG_" + String(p["id"]).to_upper())
		if p["done"]:
			b.text += "  · " + tr("SO_THO_DONE_MARK")
		elif st.get("ok", false):
			b.text += "  · " + tr("SO_THO_READY_MARK")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(340, 46)
		var on: bool = p["id"] == _sel
		b.add_theme_stylebox_override("normal", UiTheme.box(PICK if on else (Color("eaf2e2") if p["done"] else Color.WHITE),
			10, Color("e3b96a") if on else LINE, 3 if on else 2, 8))
		b.add_theme_color_override("font_color", Color(INK, 0.55) if p["done"] else INK)
		if booked.get("id", "") == p["id"]:
			b.text += "  " + tr("SO_THO_BOOKED_MARK")
		b.pressed.connect(func() -> void:
			_sel = p["id"]
			_fill())
		_list.add_child(b)
	if _sel != "":
		_fill_page(_sel, booked)

func _fill_page(id: String, booked: Dictionary) -> void:
	var st: Dictionary = hw("check", id)
	if st.get("ok", false) and pen_busy():
		st["ok"] = false
		st["reason"] = "busy"
	var t := _label(26)
	t.text = tr("UPG_" + id.to_upper())
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(t)
	var gives := _label(20)
	gives.text = tr("UPG_" + id.to_upper() + "_GIVES")
	gives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gives.modulate = Color(1, 1, 1, 0.85)
	_page.add_child(gives)

	var before := SKETCH + id + "_truoc.png"
	var after := SKETCH + id + "_sau.png"
	if ResourceLoader.exists(before) and ResourceLoader.exists(after):
		var pics := HBoxContainer.new()
		pics.add_theme_constant_override("separation", 12)
		for pair in [[before, "SO_THO_BEFORE"], [after, "SO_THO_AFTER"]]:
			var c := VBoxContainer.new()
			var tr_ := TextureRect.new()
			tr_.texture = load(pair[0])
			tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr_.custom_minimum_size = Vector2(320, 180)
			c.add_child(tr_)
			var cap := _label(15)
			cap.text = tr(pair[1])
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			c.add_child(cap)
			pics.add_child(c)
		_page.add_child(pics)
	if st.get("reason", "") == "done":
		var d := _label(20)
		d.text = tr("SO_THO_DONE")
		d.add_theme_color_override("font_color", TICK)
		_page.add_child(d)
		return

	var needs: Dictionary = st.get("needs", {})
	if not needs.is_empty():
		_page.add_child(_head(tr("SO_THO_NEEDS")))
		for m in needs:
			var have := int(needs[m][0])
			var need := int(needs[m][1])
			var l := _label(20)
			var ok := have >= need
			var mat := tr("MAT_" + String(m).to_upper())
			l.text = "%s  %d / %d" % [mat.left(1).to_upper() + mat.substr(1), mini(have, need), need]
			if not ok:
				l.text += "   — " + tr("MAT_SRC_" + String(m).to_upper())
			l.add_theme_color_override("font_color", TICK if ok else MISS)
			_page.add_child(l)
	if int(st.get("fee", 0)) > 0:
		var f := _label(20)
		f.text = tr("SO_THO_FEE") % [int(st["fee"]), int(st.get("money", 0))]
		f.add_theme_color_override("font_color", TICK if st.get("money_ok", false) else MISS)
		_page.add_child(f)

	var helpers: Array = st.get("helpers", [])
	if not helpers.is_empty():
		_page.add_child(_head(tr("SO_THO_HELPERS")))
		var names := []
		for h in helpers:
			var who := tr("CAST_" + String(h["who"]).to_upper())
			names.append(who if h.get("comes", true) else "%s (%s)" % [who, tr("SO_THO_NOT_YET_FRIEND")])
		var hl := _label(20)
		hl.text = ", ".join(names)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_page.add_child(hl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	_page.add_child(row)
	if booked.get("id", "") == id:
		var bl := _label(18)
		bl.text = tr("SO_THO_BOOKED")
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bl)
		var cancel := _button(tr("SO_THO_CANCEL"))
		cancel.pressed.connect(func() -> void:
			hw("cancel")
			_fill())
		row.add_child(cancel)
		return
	var reason := String(st.get("reason", ""))
	if reason != "":
		var why := _label(19)
		why.text = tr("SO_THO_WHY_" + reason.to_upper())
		if reason == "needs":
			why.text = tr("SO_THO_WHY_NEEDS_N") % tr("UPG_NHA_MUC_%d" % (int(hw("level")) + 1))
		why.add_theme_color_override("font_color", WARN)
		why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(why)
	var go := _button(tr("SO_THO_BOOK") if st.get("with_tho", false) else tr("SO_THO_DO_NOW"))
	go.custom_minimum_size = Vector2(200, 54)
	go.disabled = not st.get("ok", false)
	go.add_theme_stylebox_override("normal", UiTheme.box(PICK, 14, Color("e3b96a"), 3, 10))
	go.add_theme_stylebox_override("disabled", UiTheme.box(Color("e9e1d3"), 14, Color("cbbda6"), 2, 10))
	go.add_theme_color_override("font_disabled_color", Color(INK, 0.45))
	var alone: bool = not st.get("with_tho", false)
	go.pressed.connect(func() -> void:
		if hw("book", id):
			Sound.play("mg.good", -6.0)
			if alone:
				worked.emit(id)
		_pages = hw("pages")
		_fill())
	row.add_child(go)

func _fill_pen() -> void:
	var kind := String(_pen["kind"])
	var kd: Dictionary = FarmPens.KINDS.get(kind, {})
	var t := _label(26)
	t.text = tr(String(kd.get("name", "UPG_PEN")))
	_page.add_child(t)
	if _pen.has("upgrade_from"):
		var up := _label(19)
		up.text = tr("SO_THO_PEN_UPGRADE") % tr(String(FarmPens.KINDS[_pen["upgrade_from"]]["name"]))
		up.modulate = Color(1, 1, 1, 0.85)
		_page.add_child(up)
	var gives := _label(19)
	gives.text = tr("SO_THO_PEN_GIVES")
	gives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gives.modulate = Color(1, 1, 1, 0.85)
	_page.add_child(gives)
	if not ClassDB.class_exists("PenWork"):
		var l := _label(20)
		l.text = tr("SO_THO_NOT_YET")
		_page.add_child(l)
		return
	var st: Dictionary = ClassDB.class_call_static("PenWork", "check", kind)
	var d := _label(20)
	d.text = tr("SO_THO_PEN_DAYS") % int(st.get("days", 1))
	_page.add_child(d)
	var needs: Dictionary = st.get("needs", {})
	if not needs.is_empty():
		_page.add_child(_head(tr("SO_THO_NEEDS")))
		for m in needs:
			var have := int(needs[m][0])
			var need := int(needs[m][1])
			var l := _label(20)
			var ok := have >= need
			var mat := tr("MAT_" + String(m).to_upper())
			l.text = "%s  %d / %d" % [mat.left(1).to_upper() + mat.substr(1), mini(have, need), need]
			if not ok:
				l.text += "   — " + tr("MAT_SRC_" + String(m).to_upper())
			l.add_theme_color_override("font_color", TICK if ok else MISS)
			_page.add_child(l)
	if int(st.get("fee", 0)) > 0:
		var f := _label(20)
		f.text = tr("SO_THO_FEE") % [int(st["fee"]), int(st.get("money", 0))]
		f.add_theme_color_override("font_color", TICK if st.get("money_ok", false) else MISS)
		_page.add_child(f)
	var hl := _label(20)
	hl.text = tr("SO_THO_HELPERS") + " " + tr("CAST_CHU_TAM")
	_page.add_child(hl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	_page.add_child(row)
	var booked: Dictionary = ClassDB.class_call_static("PenWork", "booked")
	if not booked.is_empty() and int(booked.get("pen", -2)) == int(_pen.get("pen", -1)):
		var bl := _label(18)
		bl.text = tr("SO_THO_BOOKED")
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bl)
		var cancel := _button(tr("SO_THO_CANCEL"))
		cancel.pressed.connect(func() -> void:
			ClassDB.class_call_static("PenWork", "cancel")
			_fill())
		row.add_child(cancel)
		return
	var reason := String(st.get("reason", ""))
	if reason != "":
		var why := _label(19)
		why.text = tr("SO_THO_WHY_" + reason.to_upper())
		why.add_theme_color_override("font_color", WARN)
		why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(why)
	var go := _button(tr("SO_THO_BOOK"))
	go.custom_minimum_size = Vector2(200, 54)
	go.disabled = not st.get("ok", false)
	go.add_theme_stylebox_override("normal", UiTheme.box(PICK, 14, Color("e3b96a"), 3, 10))
	go.add_theme_stylebox_override("disabled", UiTheme.box(Color("e9e1d3"), 14, Color("cbbda6"), 2, 10))
	go.add_theme_color_override("font_disabled_color", Color(INK, 0.45))
	go.pressed.connect(func() -> void:
		if ClassDB.class_call_static("PenWork", "book", kind, _pen["cell"], int(_pen["rot"]), int(_pen["pen"])):
			Sound.play("mg.good", -6.0)
		_fill())
	row.add_child(go)

func _head(text: String) -> Label:
	var l := _label(19)
	l.text = text
	l.add_theme_color_override("font_color", Color("8b5a3a"))
	return l

func _label(px: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", INK)
	return l

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, INK)
	b.add_theme_stylebox_override("normal", UiTheme.box(Color.WHITE, 10, LINE, 2, 8))
	b.add_theme_stylebox_override("hover", UiTheme.box(Color("fff0d6"), 10, Color("e3b96a"), 3, 8))
	b.add_theme_stylebox_override("pressed", UiTheme.box(PICK, 10, Color("e3b96a"), 3, 8))
	b.add_theme_stylebox_override("disabled", UiTheme.box(Color("efe8dc"), 10, LINE, 2, 8))
	return b
