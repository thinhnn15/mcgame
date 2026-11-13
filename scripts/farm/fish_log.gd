class_name FishLog
extends RefCounted

const FILE := "user://save/fish_log.json"

static var caught := {}
static var _loaded := false
static var dry := false

static func forget() -> void:
	caught = {}
	_loaded = false

static func load_saved() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(FILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if d is Dictionary:
			caught = d.get("caught", {})

static func save() -> void:
	if dry:
		return
	DirAccess.make_dir_recursive_absolute("user://save")
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": 1, "caught": caught}, "\t"))

static func add(kind: String, cm: float) -> String:
	load_saved()
	var e: Dictionary = caught.get(kind, {})
	var what := "new" if e.is_empty() else ("best" if cm > float(e.get("best", 0.0)) + 0.05 else "")
	e["n"] = int(e.get("n", 0)) + 1
	e["best"] = maxf(float(e.get("best", 0.0)), snappedf(cm, 0.1))
	if not e.has("day"):
		e["day"] = Clock.day
	caught[kind] = e
	save()
	return what

static func panel(parent: Node) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.visible = false
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fff6e6f0")
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	box.add_theme_stylebox_override("panel", sb)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(box)
	var col := VBoxContainer.new()
	box.add_child(col)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("5b4a44"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	layer.set_meta("fill", func():
		load_saved()
		FishTable.load_table()
		for c in grid.get_children():
			c.queue_free()
		var got := 0
		for r in FishTable.rows:
			var e: Dictionary = caught.get(r["kind"], {})
			got += int(not e.is_empty())
			var l := Label.new()
			l.add_theme_font_size_override("font_size", 22)
			l.add_theme_color_override("font_color", Color("5b4a44") if not e.is_empty() else Color("b3a79a"))
			l.text = "%s   %s" % [cap(TranslationServer.translate(r["name"])) if not e.is_empty() else "???",
				Lang.t("FISH_LOG_ROW", {"n": e["n"], "cm": "%.1f" % float(e["best"])}) if not e.is_empty() else ""]
			grid.add_child(l)
		title.text = Lang.t("FISH_LOG_TITLE", {"got": got, "all": FishTable.rows.size()}))
	return layer

static func cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)

static func toggle(layer: CanvasLayer) -> void:
	if not layer.visible:
		layer.get_meta("fill").call()
	layer.visible = not layer.visible
