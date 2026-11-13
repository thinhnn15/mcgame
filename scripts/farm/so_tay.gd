class_name SoTay
extends RefCounted

const FILE := "res://data/farm/so_tay.json"
const INK_ONG := Color("5b3a2a")
const INK_CHAU := Color("2f5d8a")

static var pages: Array = []
static var dry := false
static var _dry_written: Array = []

static func load_pages() -> void:
	if pages.is_empty():
		pages = JSON.parse_string(FileAccess.get_file_as_string(FILE))["pages"]

static func written(id: String) -> bool:
	return id in _dry_written or ("so_tay_" + id) in Progress.moments()

static func write(id: String) -> bool:
	load_pages()
	if written(id):
		return false
	if dry:
		_dry_written.append(id)
	else:
		Progress.moment("so_tay_" + id)
	return true

static func chapter_pages(ch: int) -> Array:
	load_pages()
	return pages.filter(func(p: Dictionary) -> bool: return int(p["chapter"]) <= ch)

static func panel(parent: Node) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.visible = false
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f7ecd4")
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3)
	sb.border_color = Color("c9ab7c")
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 26
	sb.content_margin_bottom = 22
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 10
	box.add_theme_stylebox_override("panel", sb)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(720, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	box.add_child(vb)
	var head := _label(17, Color("8a7358"))
	var ong := _label(24, INK_ONG)
	var hand := FontVariation.new()
	hand.base_font = load("res://fonts/Nunito[wght].ttf")
	hand.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
	hand.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 560}
	ong.add_theme_font_override("font", hand)
	var chau := _label(22, INK_CHAU)
	chau.add_theme_font_override("font", load("res://fonts/MPLUSRounded1c-Medium.ttf"))
	var foot := _label(15, Color("8a7358"))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for c in [head, ong, chau, foot]:
		vb.add_child(c)
	layer.add_child(box)
	parent.add_child(layer)
	layer.set_meta("parts", [head, ong, chau, foot])
	return layer

static func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(640, 0)
	return l

static func show(layer: CanvasLayer, list: Array, i: int) -> void:
	var parts: Array = layer.get_meta("parts")
	var p: Dictionary = list[i]
	var id := str(p["id"]).to_upper()
	parts[0].text = layer.tr("SOTAY_HEAD") % [i + 1, list.size()]
	parts[1].text = layer.tr("SOTAY_%s_ONG" % id)
	parts[2].text = layer.tr("SOTAY_%s_CHAU" % id) if written(p["id"]) else ""
	parts[2].visible = written(p["id"])
	parts[3].text = layer.tr("SOTAY_HINT")
	layer.visible = true
