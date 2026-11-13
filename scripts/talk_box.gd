class_name TalkBox
extends Control

signal _next
signal _picked(i: int)

static var auto_secs := 0.0
static var auto_picks: Array = []

const CPS := 40.0
const PORTRAIT_LAYER := 1 << 19
const PORTRAIT_PX := 384
const CARD := Vector2(256, 256)

const CAM_AT := Vector3(0.0, -0.05, 1.1)
const CAM_FROM := Vector3(-0.42, -2.05, 1.22)
const MOUTH_STEP := 0.085

const FACES := {
	"smile": {"eye": 0, "brow": 0, "mouth": 0, "talk": [8, 0, 1, 8, 2]},
	"happy": {"eye": 3, "brow": 3, "mouth": 1, "talk": [1, 8, 1, 2]},
	"excited": {"eye": 4, "brow": 3, "mouth": 1, "talk": [1, 7, 8, 1]},
	"calm": {"eye": 0, "brow": 0, "mouth": 4, "talk": [2, 4, 8, 4]},
	"sleepy": {"eye": 1, "brow": 1, "mouth": 4, "talk": [2, 4, 7, 4]},
	"sad": {"eye": 6, "brow": 1, "mouth": 5, "talk": [9, 5, 2, 5]},
	"lonely": {"eye": 15, "brow": 1, "mouth": 5, "talk": [9, 5, 2, 5]},
	"bored": {"eye": 1, "brow": 0, "mouth": 6, "talk": [2, 6, 4, 6]},
	"worried": {"eye": 6, "brow": 1, "mouth": 6, "talk": [2, 6, 9, 6]},
	"annoyed": {"eye": 5, "brow": 2, "mouth": 4, "talk": [12, 4, 2, 4]},
	"shocked": {"eye": 4, "brow": 3, "mouth": 7, "talk": [7, 2, 7, 9]},
	"sly": {"eye": 12, "brow": 5, "mouth": 13, "talk": [8, 13, 1, 13]},
}

var _panel: PanelContainer
var _card: PanelContainer
var _frame: PanelContainer
var _backdrop: GradientTexture2D
var _gap: Control
var _tag: PanelContainer
var _name: Label
var _text: Label
var _arrow: Label
var _choices: VBoxContainer
var _typing := false
var _waiting := false
var _shown := 0.0
var _t := 0.0

var _vp: SubViewport
var _cam: Camera3D
var _speaker: Chibi
var _saved_face := Vector3i.ZERO
var _face := {}
var _mouth_t := 0.0
var _mouth_i := 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.make()
	visible = false
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.box(Color("fffaf0"), 46, Color("f3dfc8"), 4, 26))
	_panel.position = Vector2(360, 790)
	_panel.custom_minimum_size = Vector2(1200, 240)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_gap = Control.new()
	_gap.custom_minimum_size = Vector2(CARD.x + 26, 0)
	_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_gap)

	_card = PanelContainer.new()
	_card.position = Vector2(_panel.position.x + 22, _panel.position.y - 78)
	_card.custom_minimum_size = CARD
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", UiTheme.box(Color.WHITE, 40, Color(0, 0, 0, 0), 0, 0))
	_frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_frame)
	_backdrop = GradientTexture2D.new()
	_backdrop.fill = GradientTexture2D.FILL_RADIAL
	_backdrop.fill_from = Vector2(0.5, 0.42)
	_backdrop.fill_to = Vector2(0.5, 1.12)
	_backdrop.gradient = Gradient.new()
	var back := TextureRect.new()
	back.texture = _backdrop
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(back)
	_vp = SubViewport.new()
	_vp.size = Vector2i(PORTRAIT_PX, PORTRAIT_PX)
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.cull_mask = PORTRAIT_LAYER
	_cam.fov = 31.0
	_cam.near = 0.3
	_vp.add_child(_cam)
	var face := TextureRect.new()
	face.texture = _vp.get_texture()
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(face)
	add_child(_card)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 32)
	_text.add_theme_constant_override("line_spacing", 8)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_text)
	_tag = PanelContainer.new()
	_tag.position = Vector2(_panel.position.x + CARD.x + 48, _panel.position.y - 26)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 26)
	_name.add_theme_color_override("font_color", Color.WHITE)
	_tag.add_child(_name)
	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.add_theme_font_size_override("font_size", 26)
	_arrow.add_theme_color_override("font_color", UiTheme.PINK_DARK)
	_arrow.position = Vector2(1508, 985)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 12)
	_choices.position = Vector2(1520, 500)
	add_child(_choices)

func set_speaker(c: Chibi, color := UiTheme.PINK) -> void:
	"""Whose face the portrait shows (null: no portrait). Their expression is theirs again on close()."""
	_release_speaker()
	_speaker = c
	_card.visible = c != null
	_gap.visible = c != null
	_tag.position.x = _panel.position.x + (CARD.x + 48 if c else 40)
	if c == null:
		return
	_saved_face = Vector3i(c.base_eye, c.base_mouth, c.base_brow)
	for v in c.find_children("*", "VisualInstance3D", true, false):
		(v as VisualInstance3D).layers |= PORTRAIT_LAYER

	var env: Environment = get_viewport().find_world_3d().environment
	env = env.duplicate() if env else Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.fog_enabled = false
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff3e6")
	env.ambient_light_energy = 0.75
	_cam.environment = env
	var ring := UiTheme.box(Color.WHITE, 48, color, 5, 8)
	ring.shadow_size = 10
	ring.shadow_offset = Vector2(0, 5)
	ring.shadow_color = Color(0.35, 0.22, 0.2, 0.2)
	_card.add_theme_stylebox_override("panel", ring)
	_backdrop.gradient.colors = PackedColorArray([color.lerp(Color.WHITE, 0.9), color.lerp(Color.WHITE, 0.55)])
	c.skel.skeleton_updated.connect(_aim)
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE

func _release_speaker() -> void:
	if _speaker == null or not is_instance_valid(_speaker):
		_speaker = null
		return
	if _speaker.skel.skeleton_updated.is_connected(_aim):
		_speaker.skel.skeleton_updated.disconnect(_aim)
	for v in _speaker.find_children("*", "VisualInstance3D", true, false):
		(v as VisualInstance3D).layers &= ~PORTRAIT_LAYER
	_speaker.base_eye = _saved_face.x
	_speaker.base_mouth = _saved_face.y
	_speaker.base_brow = _saved_face.z
	_speaker = null
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _aim() -> void:
	"""Ride the Head bone as posed after the modifiers (the head turned to the listener included)."""
	var skel := _speaker.skel
	var bi := skel.find_bone("Head")
	if bi < 0:
		return
	var d := skel.get_bone_global_pose(bi) * skel.get_bone_global_rest(bi).affine_inverse()
	var at := skel.global_transform * (d * Vector3(CAM_AT.x, CAM_AT.z, -CAM_AT.y))
	var from := skel.global_transform * (d * Vector3(CAM_FROM.x, CAM_FROM.z, -CAM_FROM.y))
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)

func say(who: String, text: String, color := UiTheme.PINK_DARK, face := {}) -> void:
	"""Show a line (with the speaker's expression for it) and wait until the player reads on."""
	visible = true
	_name.text = who
	_tag.add_theme_stylebox_override("panel", UiTheme.box(color, 20, Color.WHITE, 3, 18))
	_tag.visible = who != ""
	_text.text = text
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
	_waiting = true
	_arrow.visible = false
	_face = face if not face.is_empty() else FACES["smile"]
	_mouth_i = 0
	_mouth_t = 0.0
	if _speaker:
		_speaker.base_eye = _face["eye"]
		_speaker.base_brow = _face["brow"]
	if auto_secs > 0.0:
		get_tree().create_timer(auto_secs).timeout.connect(func(): _typing = false; _next.emit(), CONNECT_ONE_SHOT)
	await _next

func ask(options: Array) -> int:
	"""A column of choices; returns the index picked (keyboard: arrows + Enter, or 1-9)."""
	visible = true
	_arrow.visible = false
	for c in _choices.get_children():
		c.queue_free()
	var wide := 340.0
	for o in options:
		wide = maxf(wide, minf(560.0, 60.0 + str(o).length() * 13.0))
	_choices.position = Vector2(1880 - wide, 500 - maxf(0.0, options.size() - 4) * 74.0)
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.custom_minimum_size = Vector2(wide, 62)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 24 if wide > 340.0 else 26)
		b.pressed.connect(func(): _picked.emit(i))
		_choices.add_child(b)
	(_choices.get_child(0) as Button).grab_focus.call_deferred()
	if auto_secs > 0.0:
		var want: int = clampi(int(auto_picks.pop_front()) if not auto_picks.is_empty() else 0, 0, options.size() - 1)
		get_tree().create_timer(auto_secs).timeout.connect(func(): _picked.emit(want), CONNECT_ONE_SHOT)
	var i: int = await _picked
	for c in _choices.get_children():
		c.queue_free()
	return i

func close() -> void:
	visible = false
	_typing = false
	_waiting = false
	_release_speaker()

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _typing:
		_shown += CPS * delta
		_text.visible_characters = int(_shown)
		if _shown >= _text.get_total_character_count():
			_typing = false
			_text.visible_characters = -1
	_arrow.visible = _waiting and not _typing
	_arrow.position.y = 985 + sin(_t * 6.0) * 5.0
	if _speaker and not _face.is_empty():
		if _typing:
			_mouth_t -= delta
			if _mouth_t <= 0.0:
				_mouth_t = MOUTH_STEP * randf_range(0.8, 1.3)
				var shapes: Array = _face["talk"]
				_mouth_i = (_mouth_i + 1) % shapes.size()
				_speaker.base_mouth = shapes[_mouth_i]
		else:
			_speaker.base_mouth = _face["mouth"]

func _advance() -> void:
	if _typing:
		_typing = false
		_text.visible_characters = -1
	elif _waiting:
		_waiting = false
		_next.emit()

func _on_panel_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()

func _input(e: InputEvent) -> void:
	if not visible:
		return
	if _choices.get_child_count() > 0:
		if e is InputEventKey and e.pressed and not e.echo and e.keycode >= KEY_1 and e.keycode <= KEY_9:
			var i: int = e.keycode - KEY_1
			if i < _choices.get_child_count():
				get_viewport().set_input_as_handled()
				_picked.emit(i)
		return
	if not _waiting:
		return
	var go := false
	if e is InputEventKey and e.pressed and not e.echo:
		go = e.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_F, KEY_E]
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		go = true
	if go:
		get_viewport().set_input_as_handled()
		_advance()

func _exit_tree() -> void:
	_release_speaker()
