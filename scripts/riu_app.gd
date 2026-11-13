class_name RiuApp
extends RefCounted

const DATA := "res://data/chat/monday.json"
const DAYS := ["wed", "thu", "fri", "sun", "mon"]
const DAY_KEYS := {"wed": "OS_DAY_WED", "thu": "OS_DAY_THU", "fri": "OS_DAY_FRI", "sun": "OS_DAY_SUN", "mon": "OS_TODAY"}
const C := {"side": Color("3f2a52"), "side_fg": Color("d9cfe3"), "side_mute": Color("a596b5"), "pick": Color("1164a3"),
	"page": Color("ffffff"), "ink": Color("1d1c1d"), "mute": Color("6b6a70"), "line": Color("e3e1e6"),
	"badge": Color("e0565e"), "online": Color("2bac76"), "me": Color("ff8c69"), "mention": Color("fff4d6")}
const TEXT := 20
const GROUP_MINS := 5

signal unread_changed(n: int)
signal answered(x: String, i: int)
signal task_pressed(x: String)

var pc
var channels: Array = []
var people := {}
var current := "chung"
var _read := {}
var _older := {}
var _seen := {}
var _names := {}
var _posted := {}
var _answered := {}
var _closed := {}
var _extra := {}
var _task_open := {}
var _side: VBoxContainer
var _head_name: Label
var _head_topic: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _composer: Label
var _items := {}

func _init(p_pc) -> void:
	pc = p_pc
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	people = data["people"]
	var job := "DESIGN" if pc.job == "design" else "DEV"
	for c in data["channels"]:
		var ch: Dictionary = c.duplicate(true)
		for k in ["name", "topic"]:
			if ch.has(k):
				ch[k] = str(ch[k]).replace("{job}", job)
		for m in ch["msgs"]:
			m["x"] = str(m["x"]).replace("{job}", job)
			if m["w"] == "client":
				m["w"] = "huong" if pc.job == "design" else "bao"
		channels.append(ch)
	_names = {"me": Hero.name if Hero.name != "" else tr("HERO_CALLED"), "kien": tr("NAME_KIEN"), "tung": tr("NAME_TUNG"),
		"ngan": tr("NAME_NGAN"), "khoa": tr("NAME_KHOA")}

func build(rect: Rect2) -> Control:
	var w: Array = pc._window(rect, C["side"], C["side_fg"])
	(w[1] as Label).text = tr("OS_RIU") + " · mcStudio"
	var body: VBoxContainer = w[2]
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 0)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(main)
	var side: PanelContainer = pc._panel(C["side"], Vector2(260, 0))
	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_left", 10)
	sm.add_theme_constant_override("margin_right", 10)
	sm.add_theme_constant_override("margin_top", 6)
	side.add_child(sm)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 2)
	sm.add_child(_side)
	main.add_child(side)
	var page: PanelContainer = pc._panel(C["page"])
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(page)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	page.add_child(v)
	var head: PanelContainer = pc._panel(C["page"], Vector2(0, 58))
	var hs := head.get_theme_stylebox("panel") as StyleBoxFlat
	hs.border_color = C["line"]
	hs.border_width_bottom = 1
	hs.content_margin_left = 20
	var hv := HBoxContainer.new()
	hv.add_theme_constant_override("separation", 14)
	_head_name = pc._label("", C["ink"], 22)
	_head_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_head_topic = pc._label("", C["mute"], 16)
	_head_topic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hv.add_child(_head_name)
	hv.add_child(_head_topic)
	head.add_child(hv)
	v.add_child(head)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lm := MarginContainer.new()
	lm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["left", "right", "top", "bottom"]:
		lm.add_theme_constant_override("margin_" + k, 16 if k != "left" else 20)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lm.add_child(_list)
	_scroll.add_child(lm)
	v.add_child(_scroll)
	var cm := MarginContainer.new()
	for k in ["left", "right", "bottom"]:
		cm.add_theme_constant_override("margin_" + k, 16)
	cm.add_theme_constant_override("margin_top", 4)
	var comp: PanelContainer = pc._panel(C["page"], Vector2(0, 46), 10)
	var cs := comp.get_theme_stylebox("panel") as StyleBoxFlat
	cs.border_color = Color("c9c6cf")
	cs.set_border_width_all(1)
	cs.content_margin_left = 14
	_composer = pc._label("", Color("9a98a0"), 17)
	_composer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	comp.add_child(_composer)
	cm.add_child(comp)
	v.add_child(cm)
	for ch in channels:
		_seen[ch["id"]] = _shown_today(ch).size()
		_read[ch["id"]] = 0.0
	_fill_side()
	open_channel(current)
	return w[0]

func _ch(id: String) -> Dictionary:
	for ch in channels:
		if ch["id"] == id:
			return ch
	return {}

func _title(ch: Dictionary) -> String:
	return tr(people[ch["dm"]]["name"]) if ch.has("dm") else tr(ch["name"])

func _when(m: Dictionary) -> float:
	"""The minute a message came (a "cond" one: when it was posted, never if it wasn't)."""
	return float(_posted.get(m["x"], INF)) if m.get("cond", false) else float(m["t"])

func _visible(m: Dictionary) -> bool:
	return m["d"] != "mon" or _when(m) <= pc.minute

func _all(ch: Dictionary) -> Array:
	"""The channel's messages and today's additions, in order."""
	var out: Array = (ch["msgs"] as Array) + (_extra.get(ch["id"], []) as Array)
	out.sort_custom(func(a, b):
		var da := DAYS.find(a["d"])
		var db := DAYS.find(b["d"])
		return da < db if da != db else _when(a) < _when(b))
	return out

func _shown_today(ch: Dictionary) -> Array:
	return _all(ch).filter(func(m): return m["d"] == "mon" and _visible(m))

func _unread(ch: Dictionary) -> int:
	return _shown_today(ch).filter(func(m): return m["w"] != "me" and _when(m) > float(_read.get(ch["id"], -1))).size()

func unread_total() -> int:
	var n := 0
	for ch in channels:
		n += _unread(ch)
	return n

func _fill_side() -> void:
	for c in _side.get_children():
		c.queue_free()
	_items.clear()
	var ws := HBoxContainer.new()
	ws.add_theme_constant_override("separation", 10)
	var mark := TextureRect.new()
	mark.texture = pc.MC_TILE
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(32, 32)
	ws.add_child(mark)
	var wl: Label = pc._label("mcStudio", Color.WHITE, 20)
	wl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ws.add_child(wl)
	_side.add_child(ws)
	var group := ""
	for ch in channels:
		if ch["group"] != group:
			group = ch["group"]
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 8)
			_side.add_child(gap)
			_side.add_child(pc._label(tr(group), C["side_mute"], 15))
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 32)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 17)
		for s in ["normal", "hover", "pressed"]:
			var st: StyleBoxFlat = pc._rect(Color(1, 1, 1, {"normal": 0.0, "hover": 0.08, "pressed": 0.12}[s]), 6)
			st.content_margin_left = 10
			st.content_margin_right = 10
			b.add_theme_stylebox_override(s, st)
		var badge: Label = pc._label("", Color.WHITE, 14)
		var bs: StyleBoxFlat = pc._rect(C["badge"], 9)
		bs.content_margin_left = 7
		bs.content_margin_right = 7
		badge.add_theme_stylebox_override("normal", bs)
		badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
		var dot: Label = null
		if ch.has("dm"):
			dot = pc._label("●", C["online"], 13)
			dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 12)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(dot)
		b.pressed.connect(open_channel.bind(ch["id"]))
		_items[ch["id"]] = [b, badge, dot]
		_side.add_child(b)
	_paint_side()

func _paint_side() -> void:
	for id in _items:
		var ch := _ch(id)
		var b: Button = _items[id][0]
		var badge: Label = _items[id][1]
		var n := _unread(ch)
		var dot: Label = _items[id][2]
		if dot:
			var here: bool = pc.minute < float(people[ch["dm"]]["off"])
			dot.text = "●" if here else "○"
			dot.add_theme_color_override("font_color", C["online"] if here else C["side_mute"])
		b.text = ("     " if dot else "") + _title(ch)
		var on: bool = id == current
		var col: Color = Color.WHITE if on or n > 0 else C["side_fg"]
		b.add_theme_color_override("font_color", col)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		var st: StyleBoxFlat = pc._rect(C["pick"] if on else Color(1, 1, 1, 0.0), 6)
		st.content_margin_left = 10
		st.content_margin_right = 10
		b.add_theme_stylebox_override("normal", st)
		badge.text = str(n)
		badge.visible = n > 0 and not on
	unread_changed.emit(unread_total())

func open_channel(id: String) -> void:
	current = id
	var ch := _ch(id)
	_read[id] = pc.minute
	_head_name.text = _title(ch)
	var topic := tr(ch["topic"])
	if ch.get("client", false):
		topic = topic.format({"who": tr(people["huong" if pc.job == "design" else "bao"]["name"])})
	elif ch.has("members"):
		topic = "%s  ·  %s" % [tr("OS_MEMBERS").format({"n": int(ch["members"])}), topic.format(_names)]
	_head_topic.text = topic
	_composer.text = tr("OS_WRITE").format({"to": _title(ch)})
	_fill_list()
	_paint_side()

func _fill_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var ch := _ch(current)
	var msgs: Array = _all(ch).filter(func(m): return _visible(m) and (m["d"] == "mon" or _older.get(current, false)))
	if not _older.get(current, false) and (ch["msgs"] as Array).any(func(m): return m["d"] != "mon"):
		var more := Button.new()
		more.text = tr("OS_OLDER")
		more.focus_mode = Control.FOCUS_NONE
		more.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		more.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		more.add_theme_font_size_override("font_size", 16)
		more.add_theme_color_override("font_color", C["pick"])
		more.add_theme_color_override("font_hover_color", C["pick"])
		for s in ["normal", "hover", "pressed"]:
			var st: StyleBoxFlat = pc._rect(Color(C["pick"], {"normal": 0.08, "hover": 0.16, "pressed": 0.24}[s]), 14)
			st.content_margin_left = 16
			st.content_margin_right = 16
			st.content_margin_top = 4
			st.content_margin_bottom = 4
			more.add_theme_stylebox_override(s, st)
		more.pressed.connect(func():
			_older[current] = true
			_fill_list())
		_list.add_child(more)
	var day := ""
	var last := {}
	for m in msgs:
		if m["d"] != day:
			day = m["d"]
			last = {}
			_list.add_child(_day_line(tr(DAY_KEYS[day])))
		var same: bool = not last.is_empty() and last["w"] == m["w"] and _when(m) - _when(last) <= GROUP_MINS
		_list.add_child(_message(m, same))
		last = m
	if msgs.is_empty():
		var none: Label = pc._label(tr("OS_NOTHING"), C["mute"], 17)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(none)
	_to_bottom.call_deferred()

func _to_bottom() -> void:
	await pc.get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _day_line(text: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	for i in 3:
		if i == 1:
			var l: Label = pc._label(text, C["ink"], 15)
			var st: StyleBoxFlat = pc._rect(C["page"], 12)
			st.border_color = C["line"]
			st.set_border_width_all(1)
			st.content_margin_left = 12
			st.content_margin_right = 12
			l.add_theme_stylebox_override("normal", st)
			h.add_child(l)
		else:
			var line := ColorRect.new()
			line.color = C["line"]
			line.custom_minimum_size = Vector2(0, 1)
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(line)
	return h

func _message(m: Dictionary, same: bool) -> Control:
	var me: bool = m["w"] == "me"
	var who: String = _names["me"] if me else tr(people[m["w"]]["name"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var av: PanelContainer = pc._panel(C["me"] if me else Color(people[m["w"]]["color"]), Vector2(40, 40 if not same else 0), 10)
	if same:
		av.self_modulate.a = 0.0
	else:
		var i: Label = pc._label(who.left(1).to_upper(), Color.WHITE, 19)
		i.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		i.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		av.add_child(i)
	av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(av)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not same:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var n: Label = pc._label(who, C["ink"], 18)
		n.add_theme_constant_override("outline_size", 1)
		n.add_theme_color_override("font_outline_color", C["ink"])
		h.add_child(n)
		var t: Label = pc._label(_clock(_when(m)), C["mute"], 14)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(t)
		v.add_child(h)
	var text := tr(m["x"]).format(_names)
	var body: Label = pc._label(text, C["ink"], TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if text.contains("@" + _names["me"]):
		var st: StyleBoxFlat = pc._rect(C["mention"], 6)
		st.content_margin_left = 6
		st.content_margin_right = 6
		body.add_theme_stylebox_override("normal", st)
	v.add_child(body)
	if m.has("task") and m["d"] == "mon" and not _closed.has(m["x"]) and _task_open.has(m["x"]):
		var rb := Button.new()
		rb.text = tr("CHAT_REPLY_MAIL") + "  ➤"
		rb.focus_mode = Control.FOCUS_NONE
		rb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		rb.add_theme_font_size_override("font_size", 18)
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			rb.add_theme_color_override(k, Color.WHITE)
		for st in ["normal", "hover", "pressed"]:
			var sb: StyleBoxFlat = pc._rect(Color("f08aa6") if st == "normal" else Color("e8738f"), 8)
			sb.content_margin_left = 16
			sb.content_margin_right = 16
			sb.content_margin_top = 5
			sb.content_margin_bottom = 5
			rb.add_theme_stylebox_override(st, sb)
		rb.pressed.connect(func(): task_pressed.emit(m["x"]))
		var rpad := MarginContainer.new()
		rpad.add_theme_constant_override("margin_top", 6)
		rpad.add_child(rb)
		v.add_child(rpad)
	if m.has("ask") and m["d"] == "mon" and not _answered.has(m["x"]) and not _closed.has(m["x"]):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		for i in (m["ask"] as Array).size():
			var b := Button.new()
			b.text = tr(m["ask"][i][0])
			b.focus_mode = Control.FOCUS_NONE
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.add_theme_font_size_override("font_size", 17)
			for k in ["font_color", "font_hover_color", "font_pressed_color"]:
				b.add_theme_color_override(k, C["pick"] if k == "font_color" else Color.WHITE)
			for st in ["normal", "hover", "pressed"]:
				var sb: StyleBoxFlat = pc._rect(Color.WHITE if st == "normal" else C["pick"], 8)
				sb.border_color = C["pick"]
				sb.set_border_width_all(2)
				sb.content_margin_left = 14
				sb.content_margin_right = 14
				sb.content_margin_top = 4
				sb.content_margin_bottom = 4
				b.add_theme_stylebox_override(st, sb)
			b.pressed.connect(_answer.bind(m, i))
			h.add_child(b)
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_top", 6)
		pad.add_child(h)
		v.add_child(pad)
	row.add_child(v)
	return row

func _channel_of(x: String) -> Dictionary:
	for ch in channels:
		for m in ch["msgs"]:
			if m["x"] == x:
				return ch
	return {}

func post(x: String) -> void:
	"""A "cond" message comes now (the morning decided it does)."""
	if _posted.has(x) or _channel_of(x).is_empty():
		return
	_posted[x] = pc.minute
	tick()

func open_task(x: String) -> void:
	"""The task that message stands for is on the list: show its Reply button."""
	_task_open[x] = true
	if not _channel_of(x).is_empty() and _channel_of(x)["id"] == current:
		_fill_list()

func close_ask(x: String) -> void:
	"""No more buttons under that message (it was answered some other way)."""
	_closed[x] = true
	if not _channel_of(x).is_empty() and _channel_of(x)["id"] == current:
		_fill_list()

func _answer(m: Dictionary, i: int) -> void:
	if _answered.has(m["x"]) or _closed.has(m["x"]):
		return
	_answered[m["x"]] = i
	var ch := _channel_of(m["x"])
	var more: Array = _extra.get(ch["id"], [])
	more.append({"d": "mon", "t": pc.minute, "w": "me", "x": m["ask"][i][0]})
	more.append({"d": "mon", "t": pc.minute + 1.0, "w": m["w"], "x": m["ask"][i][1]})
	_extra[ch["id"]] = more
	_seen[ch["id"]] = _shown_today(ch).size()
	_read[ch["id"]] = pc.minute
	_fill_list()
	answered.emit(m["x"], i)

static func _clock(m: float) -> String:
	return "%02d:%02d" % [int(m / 60.0) % 24, int(m) % 60]

func tick() -> void:
	"""The clock moved on (pc.minute): new messages, badges, toasts; the green dots go out at leave time."""
	var changed := false
	for ch in channels:
		var today := _shown_today(ch)
		if today.size() == _seen[ch["id"]]:
			continue
		changed = true
		for k in range(_seen[ch["id"]], today.size()):
			var m: Dictionary = today[k]
			if m["w"] != "me" and not (pc.app == "riu" and current == ch["id"] and pc.shown):
				var text := tr(m["x"]).format(_names)
				pc._toast_show("%s · %s\n%s" % [tr(people[m["w"]]["name"]), _title(ch), text.left(60) + ("…" if text.length() > 60 else "")], Color("b38ad0"))
		_seen[ch["id"]] = today.size()
		if ch["id"] == current and pc.app == "riu":
			_read[current] = pc.minute
			_fill_list()
	if changed or _items.is_empty():
		_paint_side()
	else:
		for id in _items:
			var ch := _ch(id)
			if _items[id][2] and ((_items[id][2] as Label).text == "●") != (pc.minute < float(people[ch["dm"]]["off"])):
				_paint_side()
				break

func shown_now() -> void:
	"""Ríu came to the front: the open channel counts as read."""
	_read[current] = pc.minute
	_paint_side()
