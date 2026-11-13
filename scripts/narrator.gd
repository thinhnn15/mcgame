class_name NarratorLayer
extends CanvasLayer

signal skip_requested
signal _line_over

const CPS := 32.0
const HOLD := 1.4
const HOLD_PER := 0.045
const FADE := 0.5
const GAP := 0.4
const SKIP_HOLD := 1.0
const INK := Color("fff8ef")
const VOICES := "res://data/audio/voice.json"
const VOICE_DUCK := -6.0
const VOICE_TAIL := 0.6

var skippable := false
var taps := true
var _label: Label
var _ring: Control
var _skip_btn: Button
var _state := ""
var _shown := 0.0
var _left := 0.0
var _pause := 0.0
var _esc := 0.0
var _btn_held := false
var _btn_timer := 0.0
var _stay := false
var _voice: AudioStreamPlayer
var _voiced := {}
var _voiced_keys := {}
var _say_key := ""
var _voiced_lang := ""
var _voice_tw: Tween

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.anchor_left = 0.2
	_label.anchor_right = 0.8
	_label.anchor_top = 0.5
	_label.anchor_bottom = 0.8
	_label.add_theme_color_override("font_color", INK)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.add_theme_constant_override("shadow_outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0.18, 0.13, 0.13, 0.45))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_constant_override("line_spacing", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	add_child(_label)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	_voice.finished.connect(_voice_done)
	add_child(_voice)
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.anchor_left = 1.0
	_ring.anchor_right = 1.0
	_ring.anchor_top = 1.0
	_ring.anchor_bottom = 1.0
	_ring.offset_left = -84
	_ring.offset_top = -84
	_ring.offset_right = -36
	_ring.offset_bottom = -36
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_skip_btn = Button.new()
	_skip_btn.text = tr("SKIP_HOLD")
	_skip_btn.theme = UiTheme.make()
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.anchor_left = 1.0
	_skip_btn.anchor_right = 1.0
	_skip_btn.anchor_top = 1.0
	_skip_btn.anchor_bottom = 1.0
	_skip_btn.offset_left = -260
	_skip_btn.offset_top = -100
	_skip_btn.offset_right = -100
	_skip_btn.offset_bottom = -40
	_skip_btn.visible = false
	_skip_btn.button_down.connect(func(): _btn_held = true)
	_skip_btn.button_up.connect(func(): _btn_held = false)
	add_child(_skip_btn)
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var h := get_viewport().get_visible_rect().size.y
	_label.add_theme_font_size_override("font_size", int(round(h * 0.031)))

func say(key: String, args := {}) -> void:
	"""Write one line (a data/i18n/strings.csv key) and wait until it has faded."""
	_say_key = key
	await say_text(Lang.t(key, args))

func say_text(text: String, stay := false) -> void:
	"""Write one line already in the player's language. `stay`: it holds until the next line or clear()
	(don't await it: "My job was…" waits there while the player picks)."""
	if _state != "":
		_line_over.emit()
	_stay = stay
	_label.text = text
	_label.visible_characters = 0
	_label.modulate.a = 1.0
	_label.visible = true
	_shown = 0.0
	_pause = 0.0
	_state = "write"
	_speak(text)
	await _line_over

func place(left := 0.2, right := 0.8) -> void:
	"""Where across the view the lines go (fractions of its width): the middle by default; the left part
	while the computer's screen is up on the right."""
	_label.anchor_left = left
	_label.anchor_right = right

func clear() -> void:
	if _state == "":
		return
	_state = ""
	_label.visible = false
	_hush(0.15)
	_line_over.emit()

func busy() -> bool:
	return _state != ""

func _cjk() -> bool:
	return Lang.current in ["ja", "ko", "zh_CN"]

func _process(delta: float) -> void:
	_skip_input(delta)
	match _state:
		"write":
			if _pause > 0.0:
				_pause -= delta
				return
			var before := int(_shown)
			_shown += delta * (CPS * (0.5 if _cjk() else 1.0))
			var total := _label.get_total_character_count()
			var now := mini(int(_shown), total)
			_label.visible_characters = now
			if now > before and now <= _label.text.length():
				var c := _label.text[now - 1]
				_pause = 0.15 if c in [",", "，", "、"] else (0.35 if c in [".", "…", "?", "!", "。", "？", "！"] else 0.0)
			if now >= total:
				_hold()
		"hold":
			_left -= delta
			if _left <= 0.0:
				_fade()
		"fade":
			_left -= delta
			_label.modulate.a = clampf((_left - GAP) / FADE, 0.0, 1.0)
			if _left <= 0.0:
				_state = ""
				_label.visible = false
				_line_over.emit()

func _hold() -> void:
	_label.visible_characters = -1
	_state = "hold"
	_left = 1e9 if _stay else HOLD + HOLD_PER * _label.text.length()
	if _voice.playing and not _stay:
		_left = maxf(_left, _voice.stream.get_length() - _voice.get_playback_position() + VOICE_TAIL)

func _fade() -> void:
	_state = "fade"
	_left = FADE + GAP
	_hush(FADE)

func _speak(text: String) -> void:
	"""Read the line aloud if it has a recording in the player's language."""
	if _voiced_lang != Lang.current:
		_voiced_lang = Lang.current
		_voiced.clear()
		_voiced_keys.clear()
		var keys: Array = (JSON.parse_string(FileAccess.get_file_as_string(VOICES)) as Dictionary).get(Lang.current, [])
		for k in keys:
			_voiced_keys[k] = "res://audio/voice/%s/%s.ogg" % [Lang.current, k]
			_voiced[tr(k)] = _voiced_keys[k]
	if _voice_tw:
		_voice_tw.kill()
	_voice.stop()
	var path: String = _voiced_keys.get(_say_key, _voiced.get(text, ""))
	_say_key = ""
	if path == "":
		_voice_done()
		return
	_voice.stream = load(path)
	_voice.volume_db = 0.0
	_voice.play()
	Sound.duck("narrator", VOICE_DUCK, 0.4)

func _hush(secs: float) -> void:
	if not _voice.playing:
		return
	if _voice_tw:
		_voice_tw.kill()
	_voice_tw = create_tween()
	_voice_tw.tween_property(_voice, "volume_db", -40.0, secs)
	_voice_tw.tween_callback(func(): _voice.stop(); _voice_done())

func _voice_done() -> void:
	Sound.unduck("narrator", 0.8)

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch and e.pressed and skippable:
		_skip_btn.visible = true
		_btn_timer = 3.0
	if not taps or _state == "" or _state == "fade" or (_stay and _state == "hold"):
		return
	var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
		or (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER])
	if not tap:
		return
	if _state == "write":
		_hold()
	else:
		_fade()
	get_viewport().set_input_as_handled()

func _skip_input(delta: float) -> void:
	if _btn_timer > 0.0 and not _btn_held:
		_btn_timer -= delta
		if _btn_timer <= 0.0:
			_skip_btn.visible = false
	var held := skippable and (Input.is_physical_key_pressed(KEY_ESCAPE) or _btn_held)
	var was := _esc
	_esc = minf(_esc + delta, SKIP_HOLD) if held else 0.0
	if _esc >= SKIP_HOLD and was < SKIP_HOLD:
		skip_requested.emit()
	if _esc != was:
		_ring.queue_redraw()

func _draw_ring() -> void:
	if _esc <= 0.0 or _esc >= SKIP_HOLD:
		return
	var c := _ring.size * 0.5
	_ring.draw_arc(c, 20.0, 0.0, TAU, 48, Color(INK, 0.25), 4.0, true)
	_ring.draw_arc(c, 20.0, -PI * 0.5, -PI * 0.5 + TAU * _esc / SKIP_HOLD, 48, INK, 4.0, true)
