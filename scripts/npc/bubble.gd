class_name SpeechBubble
extends Node3D

const PX := 0.0008
const MAX_W := 300

var _vp: SubViewport
var _panel: PanelContainer
var _label: Label
var _tail: Polygon2D
var _name: Label
var name_color := Color("f08aa6")
var _sprite: Sprite3D
var _hide_at := 0.0
var _now := 0.0
var _tween: Tween

func _ready() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var root := Control.new()
	root.theme = UiTheme.make()
	_vp.add_child(root)
	_panel = PanelContainer.new()
	root.add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", UiTheme.INK)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_panel.add_child(_label)
	_tail = Polygon2D.new()
	root.add_child(_tail)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 17)
	_name.add_theme_color_override("font_color", Color.WHITE)
	root.add_child(_name)
	_sprite = Sprite3D.new()
	_sprite.texture = _vp.get_texture()
	_sprite.pixel_size = PX
	_sprite.fixed_size = true
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.no_depth_test = true
	_sprite.render_priority = 10
	_sprite.centered = true
	_sprite.offset.y = 0.0
	_sprite.visible = false
	add_child(_sprite)

func show_text(text: String, secs: float, thought := false, who := "") -> void:
	_label.text = text
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var w := _label.get_minimum_size().x
	if w > MAX_W:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size.x = MAX_W
	else:
		_label.custom_minimum_size.x = 0
	var r := 30 if thought else 22
	_panel.add_theme_stylebox_override("panel", UiTheme.box(Color("fffaf2"), r, Color("f2d8cc"), 3, 16))
	_sprite.visible = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame
	var top := 4.0
	_name.visible = who != "" and not thought
	if _name.visible:
		_name.text = who
		_name.add_theme_stylebox_override("normal", UiTheme.box(name_color, 12, Color(0, 0, 0, 0), 0, 10))
		_name.reset_size()
		top = 4.0 + _name.get_combined_minimum_size().y * 0.55
	_panel.reset_size()
	var size := _panel.get_combined_minimum_size()
	if _name.visible:
		size.x = maxf(size.x, _name.get_combined_minimum_size().x + 28)
	_panel.size = size
	_panel.position = Vector2(4, top)
	_name.position = Vector2(14, 4)
	_name.move_to_front()
	var cx := 4 + size.x * 0.5
	var by := top + size.y
	if thought:
		_tail.polygon = _circle(Vector2(cx - 18, by + 8), 7)
		_tail.color = Color("fffaf2")
	else:
		_tail.polygon = PackedVector2Array([Vector2(cx - 10, by - 3), Vector2(cx + 10, by - 3), Vector2(cx - 2, by + 14)])
		_tail.color = Color("fffaf2")
	_vp.size = Vector2i(int(size.x) + 8, int(by) + 18)
	await get_tree().process_frame
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_sprite.offset.y = _vp.size.y * 0.5
	_sprite.visible = true
	_hide_at = _now + secs
	if _tween:
		_tween.kill()
	_sprite.scale = Vector3.ONE * 0.2
	_sprite.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_property(_sprite, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func showing() -> bool:
	"""A line is up (or still fading)."""
	return _sprite.visible

func hide_now() -> void:
	_hide_at = 0.0

func _process(_delta: float) -> void:
	_now += _delta
	if _sprite.visible:
		_keep_on_screen()
	if _sprite.visible and _now > _hide_at:
		_sprite.visible = false if _sprite.modulate.a <= 0.05 else _sprite.visible
		_sprite.modulate.a = move_toward(_sprite.modulate.a, 0.0, _delta * 5.0)
		if _sprite.modulate.a <= 0.0:
			_sprite.visible = false

func _keep_on_screen() -> void:
	"""Someone at the back of the room speaks near the top of the screen: slide the bubble down so it
	stays whole (a fixed_size sprite: one bubble pixel is k screen pixels wherever it is). Near a side
	edge (the view slides the player left while the computer's screen is up) it slides in sideways."""
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(global_position):
		return
	var vh := float(get_viewport().get_visible_rect().size.y)
	var k := PX / (2.0 * tan(deg_to_rad(cam.fov) * 0.5)) * vh
	var anchor_y := cam.unproject_position(global_position).y
	var top := anchor_y - _vp.size.y * k
	var margin := 0.03 * vh
	_sprite.offset.y = _vp.size.y * 0.5 - maxf(0.0, (margin - top) / k)
	var vw := float(get_viewport().get_visible_rect().size.x)
	var ax := cam.unproject_position(global_position).x
	var half := _vp.size.x * 0.5 * k
	_sprite.offset.x = (maxf(0.0, margin - (ax - half)) - maxf(0.0, ax + half - (vw - margin))) / k

static func _circle(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
