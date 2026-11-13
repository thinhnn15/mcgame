class_name JobPick
extends PcScreen

signal picked(job: String)
signal woke

const WINDOWS := [
	["report", "PICK_REPORT", "", Rect2(12, 10, 360, 220), 4, ""],
	["mail", "PICK_MAIL", "mail", Rect2(780, 8, 360, 220), 99, ""],
	["chat", "PICK_CHAT", "", Rect2(400, 6, 340, 150), 23, ""],
	["cal", "PICK_CAL", "", Rect2(10, 330, 300, 220), 6, ""],
	["board", "SCR_BOARD", "board", Rect2(842, 340, 300, 210), 12, ""],
	["code", "render_queue.cpp — engine — Code", "code", Rect2(96, 92, 470, 290), 3, "dev"],
	["design", "logo_final_v7_FINAL_thatsu.png — Design", "design", Rect2(586, 92, 470, 290), 17, "design"],
]
const CARD_H := 86
const CHORE_TINT := Color(0.62, 0.64, 0.72)
const FULL := Rect2(10, 10, 1132, 584)

var _wins := {}
var _done := false
var asleep := true
var _sleep: Control

func _build_desktop() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	move_child(dim, 0)
	var root := Control.new()
	root.size = DESIGN
	root.theme = UiTheme.make()
	_vp.add_child(root)
	var wall := TextureRect.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("2b3550"), Color("4a3a5c")])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 1)
	wall.texture = gt
	wall.size = DESIGN
	wall.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(wall)
	for w in WINDOWS:
		root.add_child(_job_window(w))
	var bar := _panel(Color("1d2129", 0.95), Vector2(DESIGN.x, 44))
	bar.position = Vector2(0, DESIGN.y - 44)
	bar.size = Vector2(DESIGN.x, 44)
	var h := HBoxContainer.new()
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 16)
	m.add_child(h)
	bar.add_child(m)
	var logo := _panel(Color("ff8c69"), Vector2(32, 32), 8)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ll := _label("mc", Color("fff8ef"), 14)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_child(ll)
	h.add_child(logo)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(gap)
	var bell := _label("● 99+", Color("ff8a8a"), 15)
	bell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(bell)
	var clock := _label("   " + clock_text, Color("e3e7ee"), 15)
	clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(clock)
	root.add_child(bar)
	_sleep = ColorRect.new()
	(_sleep as ColorRect).color = Color("07080b")
	_sleep.size = DESIGN
	_sleep.mouse_filter = Control.MOUSE_FILTER_STOP
	_sleep.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			wake())
	var hint := _label(tr("PC_WAKE_HINT"), Color(0.85, 0.88, 0.95, 0.55), 22)
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sleep.add_child(hint)
	root.add_child(_sleep)
	var tw := hint.create_tween().set_loops()
	tw.tween_property(hint, "modulate:a", 0.45, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(hint, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)

func wake() -> void:
	if not asleep:
		return
	asleep = false
	var tw := create_tween()
	tw.tween_property(_sleep, "modulate:a", 0.0, 0.45)
	tw.tween_callback(_sleep.queue_free)
	woke.emit()

func _unhandled_input(e: InputEvent) -> void:
	if asleep and shown and e is InputEventKey and e.pressed and not e.echo:
		get_viewport().set_input_as_handled()
		wake()

func _begin() -> void:
	pass

func _process(_delta: float) -> void:
	pass

func _job_window(w: Array) -> Control:
	var title: String = tr(w[1]) if (w[1] as String).is_valid_identifier() else w[1]
	var job: String = w[5]
	var holder := Control.new()
	holder.position = w[3].position
	holder.size = w[3].size + (Vector2(0, CARD_H) if job != "" else Vector2.ZERO)
	var glow: Panel = null
	if job != "":
		glow = Panel.new()
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color(0, 0, 0, 0)
		gs.border_color = UiTheme.PINK
		gs.set_border_width_all(5)
		gs.set_corner_radius_all(16)
		glow.add_theme_stylebox_override("panel", gs)
		glow.position = Vector2(-7, -7)
		glow.size = w[3].size + Vector2(14, 14)
		holder.add_child(glow)
		var gt := glow.create_tween().set_loops()
		gt.tween_property(glow, "modulate:a", 0.25, 0.9).set_trans(Tween.TRANS_SINE)
		gt.tween_property(glow, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	var made: Array = _window(Rect2(Vector2.ZERO, w[3].size), Color("eef0f4") if w[2] != "code" else C["title"],
		Color("5b6270") if w[2] != "code" else C["muted"])
	var win: PanelContainer = made[0]
	holder.add_child(win)
	(made[1] as Label).text = title
	var card: PanelContainer = null
	if job != "":
		card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 0.98, 0.95, 0.97), 16, UiTheme.PINK, 3, 16))
		card.position = Vector2(0, w[3].size.y + 14)
		card.size = Vector2(w[3].size.x, CARD_H - 18)
		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 2)
		var name_l := _label(tr("JOB_" + job.to_upper()), UiTheme.INK, 24)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(name_l)
		var note := _label(tr("JOB_" + job.to_upper() + "_NOTE"), Color("8a7a74"), 16)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(note)
		card.add_child(cv)
		holder.add_child(card)
	else:
		holder.modulate = CHORE_TINT
	var body: VBoxContainer = made[2]
	if w[2] != "":
		var pic := TextureRect.new()
		pic.texture = load(Lang.path_for(OfficeProps.SCREEN_DIR, w[2] + ".png"))
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(pic)
	else:
		body.add_child(_chore_page(w[0]))
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiTheme.box(Color("e5484d"), 14, Color.WHITE, 2, 8))
	var bl := _label(str(w[4]) if w[4] < 99 else "99+", Color.WHITE, 14)
	badge.add_child(bl)
	badge.position = Vector2(w[3].size.x - 70, -12)
	holder.add_child(badge)
	for c in holder.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.pivot_offset = w[3].size * 0.5
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_entered.connect(_hover.bind(w[0], true))
	holder.mouse_exited.connect(_hover.bind(w[0], false))
	holder.gui_input.connect(_on_input.bind(w[0]))
	if job != "":
		holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_wins[w[0]] = {"win": holder, "inner": win, "glow": glow, "card": card, "badge": bl, "count": w[4], "job": job,
		"rect": w[3]}
	return holder

func _chore_page(id: String) -> Control:
	"""A plain picture of a chore: grey text lines, chat bubbles, meeting blocks."""
	var page := _panel(Color("fbfbfc"))
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	m.add_child(v)
	page.add_child(m)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for i in 7:
		var row := HBoxContainer.new()
		match id:
			"chat":
				var dot := _panel(Color.from_hsv(rng.randf(), 0.35, 0.95), Vector2(18, 18), 9)
				row.add_child(dot)
				row.add_child(_panel(Color("e9ecf1"), Vector2(rng.randi_range(90, 260), 18), 9))
			"cal":
				row.add_child(_label("%02d:00" % (9 + i), Color("7a8292"), 13))
				var blk := _panel(Color.from_hsv(0.58 + rng.randf() * 0.3, 0.3, 0.97), Vector2(rng.randi_range(120, 230), 16), 5)
				row.add_child(blk)
			_:
				row.add_child(_panel(Color("dfe3ea"), Vector2(rng.randi_range(160, 420), 10), 5))
		v.add_child(row)
	return page

func _hover(id: String, on: bool) -> void:
	"""A job's window under the mouse lifts a little and the other job dims; the chores never come forward."""
	if _done or asleep or _wins[id]["job"] == "":
		return
	for k in _wins:
		if _wins[k]["job"] == "":
			continue
		var w: Control = _wins[k]["win"]
		var lit: bool = k == id or not on
		create_tween().tween_property(w, "modulate", Color.WHITE if lit else Color(0.8, 0.8, 0.86), 0.12)
		create_tween().tween_property(w, "scale", Vector2.ONE * (1.04 if on and k == id else 1.0), 0.12)

func _on_input(e: InputEvent, id: String) -> void:
	if _done or asleep or not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var w: Dictionary = _wins[id]
	if w["job"] == "":
		w["count"] += 1
		(w["badge"] as Label).text = str(w["count"]) if w["count"] < 99 else "99+"
		var win: Control = w["win"]
		var x0: float = w["rect"].position.x
		var tw := create_tween()
		for k in 4:
			tw.tween_property(win, "position:x", x0 + (7.0 if k % 2 == 0 else -7.0), 0.04)
		tw.tween_property(win, "position:x", x0, 0.04)
		return
	_choose(id)

func pick(job: String) -> void:
	"""Choose without a click (tests, the AI control)."""
	for k in _wins:
		if _wins[k]["job"] == job:
			_choose(k)

func _choose(id: String) -> void:
	_done = true
	var keep: Control = _wins[id]["win"]
	keep.move_to_front()
	for part in [(_wins[id]["badge"] as Label).get_parent(), _wins[id]["card"], _wins[id]["glow"]]:
		if part:
			create_tween().tween_property(part, "modulate:a", 0.0, 0.15)
	keep.size = _wins[id]["rect"].size
	(_wins[id]["inner"] as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var delay := 0.0
	for k in _wins:
		if k == id:
			continue
		var w: Control = _wins[k]["win"]
		var tw := create_tween().set_parallel()
		tw.tween_property(w, "scale", Vector2.ONE * 0.85, 0.18).set_delay(delay)
		tw.tween_property(w, "modulate:a", 0.0, 0.18).set_delay(delay)
		delay += 0.12
	var grow := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	grow.tween_property(keep, "position", FULL.position, 0.4).set_delay(delay)
	grow.tween_property(keep, "size", FULL.size, 0.4).set_delay(delay)
	grow.tween_property(keep, "scale", Vector2.ONE, 0.4).set_delay(delay)
	grow.tween_property(keep, "modulate", Color.WHITE, 0.2).set_delay(delay)
	await grow.finished
	picked.emit(_wins[id]["job"])
