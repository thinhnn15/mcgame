extends Node

const TOAST_EVENTS := {"f0636b": "pc.alert", "7fcf8a": "pc.done", "f2c14e": "pc.approved", "b38ad0": "pc.chat"}
const EVENING_FROM := 19 * 60
const AUTO_KEYS_AFTER := 1.2
const PC_GAP_MS := 400
const BABBLE_GAP := Vector2(0.07, 0.12)
const BABBLE_PAUSE := 0.12
const SKETCH_NAMES := {"A": "A. Phòng nhỏ yên", "B": "B. Mùa hè ngoài cửa sổ", "C": "C. Đồng nghiệp bập bẹ"}
const BABBLE_LEN := Vector2(0.9, 1.6)
const MOUTH_BELOW := 0.6
const MUSIC_DB := -12.0

const SEASON_MUSIC := true
const SEASON_SCENES := ["hometown", "farm_plot", "village", "nha_trong"]
const SEASON_DB := -6.0

var _pcs := {}
var _mornings := {}
var _scene: Node
var _office: Node
var _sketch := "A"
var _sketch_label: Label
var _bubbles := {}
var _talking := {}
var _ring = null
var _pc_t := -100000
var _key_t := 99.0
var _auto_t := 0.0
var _sat := false
var _season_on := SEASON_MUSIC
var _season_t := 0.0
@onready var _s = get_parent()

func _ready() -> void:
	get_tree().node_added.connect(_added)
	var a := OS.get_cmdline_user_args()
	var i := a.find("--sound-sketch")
	if i >= 0 and i + 1 < a.size():
		_sketch = a[i + 1].to_upper()
	_season_on = (SEASON_MUSIC or a.has("--season-music")) and not a.has("--no-season-music")

func _added(n: Node) -> void:
	if n is Player:
		_s.hero = n
	elif n is Chibi:
		_s.add_walker(n)
	elif n is BaseButton:
		n.pressed.connect(func(): _s.play("ui.click"))
	elif n is MiniGame:
		n.finished.connect(func(score: float): _s.play("mg.good" if score >= 0.6 else "mg.bad"))
		n.grumbled.connect(func(): _s.play("mg.grumble"))
	elif n is PcScreen:
		_pcs[n] = ""
	elif n is Morning:
		_mornings[n] = {"toast": "", "msgs": 0, "req": 0, "list": false}
	elif n is SpeechBubble:
		_bubbles[n] = ""

func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _scene:
		_scene = scene
		_office = scene if scene and "time_name" in scene and "work" in scene else null
	if _bed() == "office_day" and _sketch == "C":
		_chatter(delta)
	for pc in _pcs.keys():
		if not is_instance_valid(pc):
			_pcs.erase(pc)
		else:
			_pc_toast(pc)
	for m in _mornings.keys():
		if not is_instance_valid(m):
			_mornings.erase(m)
		else:
			_morning(m)
	_auto_keys(delta)
	_chair()
	_season_music(delta)

func _season_music(delta: float) -> void:
	"""In the hometown, the theme of the season the world is showing (Season's year phase, so `--lunar m,d` and
	`--season s` pick the music with the colours; the months are the farm's: scripts/farm/farm_plot.gd season()).
	Looked at every two seconds; Sound.music() fades from one theme to the next and loops it with the file's own
	20 s of silence as the gap. In any other scene a season theme still playing is faded out (the city has no
	music: docs/sound_direction.md rule 3)."""
	if not _season_on or _office != null:
		return
	_season_t -= delta
	if _season_t > 0.0:
		return
	_season_t = 2.0
	var scene := get_tree().current_scene
	if scene == null:
		return
	if not (scene.scene_file_path.get_file().get_basename() in SEASON_SCENES):
		if str(_s.get("_song_name")).begins_with("season_"):
			_s.music("", 3.0)
		return
	var m := int(floor(Season._now() * 12.0)) + 1
	var season := "ha" if m >= 4 and m <= 7 else ("thu" if m >= 8 and m <= 10 else ("xuan" if m == 2 or m == 3 else "dong"))
	_s.music("season_" + season, 3.0, SEASON_DB)

func _chair() -> void:
	"""The hero's chair: a creak as they sit into it, a scoot as they get up (from the clip's name)."""
	var hero = _s.hero
	var c = hero.get("chibi") if hero and is_instance_valid(hero) else null
	var sitting: bool = c != null and c.anim != null and c.anim.current_animation.begins_with("Act_SitChair")
	if sitting != _sat and c != null:
		_s.play_at("chair.sit" if sitting else "chair.stand", c.global_position + Vector3(0, 0.4, 0))
	_sat = sitting

func _bed() -> String:
	var bed := ""
	if _office == null:
		return ""
	elif str(_office.get("time_name")) == "night":
		bed = "office_night"
	else:
		var m = _office.get("morning")
		bed = "office_evening" if m and is_instance_valid(m) and float(m.clock) >= EVENING_FROM else "office_day"
	_s.ambience(bed + ("_" + _sketch if bed == "office_day" else ""))
	_s.music("office_quiet" if bed == "office_day" else "", 3.0, MUSIC_DB)
	return bed

func _chatter(delta: float) -> void:
	"""Sketch C: each new line in a coworker's speech bubble comes with a moment of babble - little syllables at
	their own pitch, cute chatter with no words, like ACNH's villagers - instead of real people's murmur. The
	babble lasts about a second whatever the language (docs/sound_spec.md 6.3); thought bubbles stay quiet."""
	for b in _bubbles.keys():
		if not is_instance_valid(b):
			_bubbles.erase(b)
			_talking.erase(b)
			continue
		var label = b.get("_label")
		var who = b.get("_name")
		if label == null or not b.is_visible_in_tree():
			_bubbles[b] = ""
			continue
		if label.text != _bubbles[b]:
			_bubbles[b] = label.text
			if who and who.visible:
				var voice := 0.85 + float(absi(hash(who.text)) % 9) * 0.06
				_talking[b] = [randf_range(BABBLE_LEN.x, BABBLE_LEN.y), 0.0, voice]
	for b in _talking.keys():
		var st: Array = _talking[b]
		st[0] -= delta
		st[1] -= delta
		if st[0] <= 0.0 or not is_instance_valid(b):
			_talking.erase(b)
			continue
		if st[1] <= 0.0:
			_s.play_at("npc.babble", b.global_position + Vector3.DOWN * MOUTH_BELOW, 0.0, st[2] * randf_range(0.94, 1.06))
			st[1] = randf_range(BABBLE_GAP.x, BABBLE_GAP.y) + (randf_range(0.15, 0.35) if randf() < BABBLE_PAUSE else 0.0)

func _working() -> bool:
	var w = _office.get("work") if _office else null
	return w != null and is_instance_valid(w) and bool(w.working)

func _from_desk(event: String) -> void:
	"""A computer sound: in your face while working, else from the hero's desk across the room. Two at the
	same moment (the mail's toast in the room and the chat's on the screen) make one."""
	var now := Time.get_ticks_msec()
	if now - _pc_t < PC_GAP_MS:
		return
	_pc_t = now
	if _office == null or _working():
		_s.play(event)
		return
	var consts: Dictionary = _office.get_script().get_script_constant_map()
	var desk: Vector3 = consts.get("HERO_DESK", Vector3.ZERO)
	_s.play_at(event, desk + Vector3(0, 1.0, 0))

func _pc_toast(pc: PcScreen) -> void:
	var box = pc.get("_toast")
	var label = pc.get("_toast_label")
	if box == null or label == null:
		return
	if box.modulate.a <= 0.01:
		_pcs[pc] = ""
		return
	var text: String = label.text
	if text == _pcs[pc]:
		return
	_pcs[pc] = text
	var sb = box.get_theme_stylebox("panel")
	var edge: String = sb.border_color.to_html(false) if sb is StyleBoxFlat else ""
	_from_desk(TOAST_EVENTS.get(edge, "pc.alert"))

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F9 and OS.is_debug_build():
		_next_sketch()
		return
	if e is InputEventMouseButton and e.pressed and _working() and e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		_key(0.0, "pc.mouse")
		return
	if not (e is InputEventKey and e.pressed and not e.echo) or not _working():
		return
	var k: int = e.physical_keycode
	if (k >= KEY_A and k <= KEY_Z) or (k >= KEY_0 and k <= KEY_9) or k in DeskWork.TYPE_KEYS:
		_key_t = 0.0
		_key(0.0)

func _next_sketch() -> void:
	"""F9 while the sketches are on trial: the next one, its name shown for a moment top centre."""
	_sketch = {"A": "B", "B": "C", "C": "A"}.get(_sketch, "A")
	_talking.clear()
	if _sketch_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_sketch_label = Label.new()
		_sketch_label.add_theme_font_size_override("font_size", 26)
		_sketch_label.add_theme_color_override("font_color", Color.WHITE)
		_sketch_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_sketch_label.add_theme_constant_override("outline_size", 8)
		_sketch_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_sketch_label.position.y = 70
		layer.add_child(_sketch_label)
	_sketch_label.text = SKETCH_NAMES[_sketch] + "   (F9: đổi)"
	_sketch_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_sketch_label, "modulate:a", 0.0, 0.8)

func _auto_keys(delta: float) -> void:
	"""The code writes itself while the hero sits typing: soft keys in little runs, unless the player types."""
	_key_t += delta
	var hero = _s.hero
	var c = hero.get("chibi") if hero and is_instance_valid(hero) else null
	if c == null or c.anim == null or c.anim.current_animation != "Act_SitChair_Type" or _key_t < AUTO_KEYS_AFTER:
		return
	_auto_t -= delta
	if _auto_t <= 0.0:
		_key(-7.0)
		_auto_t = randf_range(0.11, 0.24) + (randf_range(0.5, 1.4) if randf() < 0.1 else 0.0)

func _key(db: float, event := "pc.key") -> void:
	var hero = _s.hero
	if hero and is_instance_valid(hero):
		_s.play_at(event, hero.global_position + Vector3(0, 0.75, 0), db)
	else:
		_s.play(event, db)

func _morning(m: Morning) -> void:
	var st: Dictionary = _mornings[m]
	var list = m.get("_list")
	if not st["list"] and list:
		st["list"] = true
		list.child_entered_tree.connect(func(n: Node):
			if n is Button:
				_s.play("pc.task_new")
				_s.play("office.paper", -4.0))
	var toast = m.get("_toast")
	if toast:
		if toast.modulate.a <= 0.01:
			st["toast"] = ""
		elif toast.text != st["toast"]:
			st["toast"] = toast.text
			_room_toast(toast.text)
	var req = m.get("_req")
	if req is Dictionary:
		if req.size() > st["req"]:
			_s.play("npc.call")
		st["req"] = req.size()
	var msgs = m.get("_phone_msgs")
	if msgs is Array:
		if msgs.size() > st["msgs"] and not msgs.is_empty():
			if msgs[-1] == "call":
				if not _s.is_playing(_ring):
					_ring = _s.play("phone.ring")
			else:
				_s.play("phone.buzz")
				_s.play("phone.text")
		st["msgs"] = msgs.size()
		if not "call" in msgs and _s.is_playing(_ring):
			_s.stop(_ring, 0.3)
			_ring = null

func _room_toast(text: String) -> void:
	if text == tr("MR_MAIL_ARRIVED"):
		_from_desk("pc.mail")
	elif text == tr("MR_KIEN_CHAT"):
		_from_desk("pc.chat")
	elif text == tr("MR_LIGHTS_OFF"):
		_s.play("office.lights_off")
	elif text.begins_with(tr("NAME_KIEN") + ": "):
		_s.play("phone.buzz")
		_s.play("phone.text")
