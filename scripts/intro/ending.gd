class_name IntroEnding
extends Node

signal finished

const BEATS := {"buzz": 1.2, "wake": 3.0}
const CAM_POS := Vector3(-3.35, 1.8, -1.3)
const CAM_LOOK := Vector3(-2.2, 0.85, -0.2)
const CAM_FOV := 42.0
const COLLAPSE_SPEED := 1.15
const SLUMP_BACK := 0.22
const WORK_POS := Vector3(-1.1, 1.95, 1.75)
const WORK_LOOK := Vector3(-2.3, 0.72, -0.55)
const WORK_FOV := 42.0
const WORK_SIDE := 0.25

const WORK_EVENTS := [[3.0, "say", "NARR_3_2"], [5.5, "yawn", ""], [8.0, "boss", "NIGHT_MSG_FEEDBACK"], [16.0, "say", "NARR_2_1"],
	[22.0, "note", "NIGHT_CHAT"], [30.0, "boss", "NIGHT_MSG_DEMO"], [38.0, "say", "NARR_2_2"],
	[44.0, "note", "NIGHT_CAL"], [52.0, "boss", "INTRO_PHONE_MSG"]]
const DROWSY_FROM := 24.0
const TIRED_FROM := 46.0
const WORK_END := 72.0

var intro
var blur: ColorRect
var black: ColorRect
var card: Label
var _blur_mat: ShaderMaterial
var _layer: CanvasLayer
var _gen := 0
var _cam_tw: Tween
var _phone: PhoneLockScreen
var _title: Label
var _pc: PcScreen
var _working := false
var _skip_work := false
var _blur_k := 0.0
var cam_pos := CAM_POS
var cam_look := CAM_LOOK
var cam_fov := CAM_FOV

func setup(p_intro, layer: CanvasLayer) -> void:
	intro = p_intro
	_layer = layer
	var c := Stage.arg("--end-cam").split_floats(",")
	if c.size() >= 6:
		cam_pos = Vector3(c[0], c[1], c[2])
		cam_look = Vector3(c[3], c[4], c[5])
		cam_fov = c[6] if c.size() > 6 else CAM_FOV
	blur = ColorRect.new()
	blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur_mat = ShaderMaterial.new()
	_blur_mat.shader = preload("res://shaders/faint_blur.gdshader")
	blur.material = _blur_mat
	blur.visible = false
	layer.add_child(blur)
	layer.move_child(blur, 0)
	black = ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	card = Label.new()
	card.text = tr("INTRO_FLASHBACK")
	card.add_theme_font_size_override("font_size", 46)
	card.add_theme_color_override("font_color", Color("e9e4f5"))
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.modulate.a = 0.0
	layer.add_child(card)

func run() -> void:
	if intro.story:
		await _story()
		return
	var hero: Player = intro.player
	await _wait(BEATS["buzz"])
	_buzz()
	await _wait(BEATS["wake"] - BEATS["buzz"])
	intro.asleep = false
	_ease_camera(2.5)
	await _clip("Act_SlumpWake")
	await _yawn()
	_to_keyboard()
	hero.chibi.play("Act_SitChair_Type", 0.3)
	await _wait(2.4)
	await _type_yawn()
	await _wait(1.6)
	hero.chibi.play("Act_SitChair_TypeDrowsy", 0.4)
	blur.visible = true
	create_tween().tween_method(_set_blur, 0.0, 0.1, 5.0)
	await _wait(5.0)
	await _collapse()

func _story() -> void:
	if Story.beat == "night":
		var g := _gen
		await _night(g)
		if g != _gen:
			return
	else:
		_settle_awake()
	await _after_night()

func _after_night() -> void:
	if Story.beat != "work":
		await _pick()
	await _work()
	await _collapse()

func _night(g: int) -> void:
	"""Beat 2 after the fly-in: a moment of the hero asleep, the phone, the title."""
	await _wait(2.0)
	if g != _gen:
		return
	_buzz(false)
	await _wait(1.6)
	if g != _gen:
		return
	intro.asleep = false
	_ease_camera(2.5)
	await _clip("Act_SlumpWake")
	if g != _gen:
		return
	await _yawn()
	if g != _gen:
		return
	await _lock_screen()
	if g != _gen:
		return
	await Narrator.say("NARR_2_4")
	if g != _gen:
		return
	await _show_title()

func skip_night() -> void:
	"""Held Esc during beat 2: straight to the pick, the hero awake at the desk."""
	if Story.beat != "night":
		return
	_gen += 1
	Narrator.clear()
	if _phone:
		_phone.stop()
		_phone.visible = false
	if _title:
		_title.queue_free()
	_title = null
	_settle_awake()
	_after_night()

func skip_work() -> void:
	"""Held Esc while working: straight on to the black."""
	_skip_work = true

func _settle_awake() -> void:
	intro.asleep = false
	if _cam_tw:
		_cam_tw.kill()
	intro.cam_override = [cam_pos, cam_look, cam_fov]
	intro.player.chibi.play("Act_SitChair_Idle", 0.1)

func _pick() -> void:
	"""Beat 3: the monitor is asleep - the player wakes it; "My job was…", the crowded windows, the job's
	line."""
	Story.set_beat("job")
	Narrator.taps = false
	Narrator.skippable = false
	var pick := JobPick.new()
	pick.centred = true
	pick.clock_text = "01:35"
	_layer.add_child(pick)
	pick.open()
	var auto := Stage.arg("--pick")
	if auto != "":
		get_tree().create_timer(2.0).timeout.connect(pick.wake)
		get_tree().create_timer(4.5).timeout.connect(pick.pick.bind(auto))
	await pick.woke
	Narrator.say_text(tr("NARR_3_1"), true)
	var job: String = await pick.picked
	Hero.job = job
	Hero.save()
	Story.set_beat("work")
	var sep := "" if Lang.current in ["ja", "ko", "zh_CN"] else " "
	await Narrator.say_text(tr("NARR_3_1") + sep + tr("JOB_LINE_" + job.to_upper()))
	pick.close()
	get_tree().create_timer(0.4).timeout.connect(pick.queue_free)

func _work() -> void:
	"""Beat 3, played: back to work at 01:35 on the job's screen. The player types (or taps); the clock runs,
	messages drop in, the narrator's thoughts come between; from TIRED_FROM the dark closes in - the screen
	and the room swim, the keys go heavy - and at WORK_END it is black. Then the room again, from the side."""
	var hero: Player = intro.player
	Story.set_beat("work")
	_to_keyboard()
	_drowsy_face()
	hero.chibi.play("Act_SitChair_Type", 0.3)
	if _cam_tw:
		_cam_tw.kill()
	intro.cam_override = [WORK_POS, WORK_LOOK, WORK_FOV]
	var vp_size: Vector2 = intro.get_viewport().get_visible_rect().size
	var width := 2.0 * WORK_POS.distance_to(WORK_LOOK) * tan(deg_to_rad(WORK_FOV) * 0.5) * vp_size.aspect()
	create_tween().tween_property(intro.cam, "h_offset", WORK_SIDE * width, 0.8).set_trans(Tween.TRANS_SINE)
	_pc = PcScreen.new()
	_pc.job = Hero.job
	_pc.night = true
	_pc.clock_text = "01:35"
	_layer.add_child(_pc)
	_pc.working = true
	_pc.open()
	Narrator.place(0.02, 0.4)
	Narrator.taps = false
	Narrator.skippable = true
	blur.visible = true
	_skip_work = false
	_working = true
	var t := 0.0
	var done := {}
	while t < WORK_END and not _skip_work:
		await get_tree().process_frame
		t += get_process_delta_time()
		for ev in WORK_EVENTS:
			if t >= ev[0] and not done.has(ev[0]):
				done[ev[0]] = true
				match ev[1]:
					"say":
						Narrator.say(ev[2])
					"yawn":
						_type_yawn()
					"boss":
						_pc.notify(tr("NAME_KIEN") + ": " + tr(ev[2]))
					_:
						_pc.notify(tr(ev[2]))
		if t >= DROWSY_FROM and hero.chibi.anim.current_animation == "Act_SitChair_Type":
			hero.chibi.play("Act_SitChair_TypeDrowsy", 0.5)
		var minutes := 95 + int(t * 1.05)
		_pc.set_clock("%02d:%02d" % [minutes / 60, minutes % 60])
		var f := smoothstep(TIRED_FROM, WORK_END, t)
		_pc.set_fatigue(f)
		_set_blur(0.3 * f)
		hero.chibi.anim.speed_scale = 1.0 - 0.6 * f
	_working = false
	Story.set_beat("monday")
	_pc.set_fatigue(1.0)
	Narrator.clear()
	_layer.move_child(black, -1)
	_layer.move_child(card, -1)
	var dark := create_tween()
	dark.tween_property(black, "color:a", 1.0, 1.0)
	await dark.finished
	_pc.queue_free()
	_pc = null
	Narrator.place()
	await Narrator.say("NARR_2_3")
	intro.cam.h_offset = 0.0
	intro.cam_override = [cam_pos, cam_look, cam_fov]
	hero.chibi.anim.speed_scale = 0.5
	_set_blur(0.08)
	var back := create_tween()
	back.tween_property(black, "color:a", 0.0, 1.2)
	await back.finished
	Narrator.skippable = true

func _drowsy_face() -> void:
	"""Still half asleep: heavy lids, a flat mouth, tired brows (clips without face keys show these)."""
	var c: Chibi = intro.player.chibi
	c.base_eye = 1
	c.base_mouth = 4
	c.base_brow = 1

func _yawn() -> void:
	"""Woken but not awake: a moment slack in the chair, a big yawn-stretch (tears after it), lids heavy."""
	_drowsy_face()
	intro.player.chibi.play("Act_SitChair_Idle", 0.1)
	await _wait(0.5)
	await _clip("Act_SitChair_Yawn")
	intro.player.chibi.play("Act_SitChair_Idle", 0.1)
	await _wait(0.6)

func _type_yawn() -> void:
	"""The second yawn, smaller, at the keyboard: hands still on the keys, the head tipped back."""
	var c: Chibi = intro.player.chibi
	await _clip("Act_SitChair_TypeYawn")
	if c.anim.current_animation == "Act_SitChair_TypeYawn" or c.anim.current_animation == "":
		c.anim.play("Act_SitChair_Type", 0.25)

func _to_keyboard() -> void:
	"""Out of the slump: the chair and the hero roll back in to the desk (the slump sat them back from it)."""
	var back: float = intro.hero_back
	if back <= 0.0:
		return
	var hero: Player = intro.player
	var chair := _hero_chair()
	var fwd := Vector3(sin(hero.rotation.y), 0, cos(hero.rotation.y))
	create_tween().tween_property(hero, "position", hero.position + fwd * back, 0.6).set_trans(Tween.TRANS_SINE)
	if chair:
		create_tween().tween_property(chair, "position", chair.position + fwd * back, 0.6).set_trans(Tween.TRANS_SINE)
	intro.hero_back = 0.0

func _unhandled_input(e: InputEvent) -> void:
	"""While working: the keys type."""
	if not _working or _pc == null or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k: int = e.physical_keycode
	if (k >= KEY_A and k <= KEY_Z) or (k >= KEY_0 and k <= KEY_9) or k in DeskWork.TYPE_KEYS:
		get_viewport().set_input_as_handled()
		_pc.type_keys(1)

func _lock_screen() -> void:
	"""The phone's lock screen, close up (scripts/intro/lock_screen.gd): the boss's message and, under it,
	the mother's - unread for three weeks - swiped away, the mother's after a moment's hesitation."""
	var p := PhoneLockScreen.new()
	_phone = p
	_layer.add_child(p)
	await p.play()
	p.queue_free()
	_phone = null

func _show_title() -> void:
	"""The game's name on the rain-streaked glass, where the mother's "về nhà" just was; it runs down and
	melts away."""
	var k: float = intro.get_viewport().get_visible_rect().size.y / 1080.0
	_title = Label.new()
	_title.text = tr("GAME_TITLE")
	_title.add_theme_font_size_override("font_size", int(150 * k))
	_title.add_theme_color_override("font_color", Color(1.0, 0.97, 0.94, 0.9))
	_title.add_theme_color_override("font_outline_color", Color(0.79, 0.45, 0.42, 0.55))
	_title.add_theme_constant_override("outline_size", int(18 * k))
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.modulate.a = 0.0
	_layer.add_child(_title)
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(2.2)
	tw.tween_property(_title, "modulate:a", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_title, "position:y", 26 * k, 1.6)
	await tw.finished
	if _title:
		_title.queue_free()
		_title = null

func _collapse() -> void:
	"""At the keyboard: the typing slows to a stop, the hands slip off the keys, the head droops - and the hero
	goes down face first on the desk (Act_SlumpWake played backwards), the chair rolling back under the fall.
	The picture swims and closes in; black, "Five days earlier..."."""
	var hero: Player = intro.player
	var a: AnimationPlayer = hero.chibi.anim
	blur.visible = true
	var tw := create_tween()
	tw.tween_property(a, "speed_scale", 0.25, 1.8).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_method(_set_blur, _blur_k, 0.15, 1.8)
	await tw.finished
	a.speed_scale = 1.0
	hero.chibi.play("Act_SitChair_Idle", 0.6)
	await _wait(0.9)
	if a.has_animation("Act_SlumpWake"):
		a.play("Act_SlumpWake", 0.25, -COLLAPSE_SPEED, true)
		var secs := a.get_animation("Act_SlumpWake").length / COLLAPSE_SPEED
		var fwd := Vector3(sin(hero.rotation.y), 0, cos(hero.rotation.y))
		var chair := _hero_chair()
		var roll := create_tween().set_parallel()
		roll.tween_property(hero, "position", hero.position - fwd * SLUMP_BACK, secs * 0.7).set_delay(secs * 0.25).set_trans(Tween.TRANS_SINE)
		if chair:
			roll.tween_property(chair, "position", chair.position - fwd * SLUMP_BACK, secs * 0.7).set_delay(secs * 0.25).set_trans(Tween.TRANS_SINE)
		intro.hero_back = SLUMP_BACK
		await _wait(secs)
	hero.chibi.play("Act_SitChair_Slump", 0.12)
	var tw2 := create_tween()
	tw2.tween_method(_set_blur, 0.15, 1.0, 2.2).set_trans(Tween.TRANS_SINE)
	await _wait(1.6)
	var fade := create_tween()
	fade.tween_property(black, "color:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	await fade.finished
	await _wait(0.6)
	var t2 := create_tween()
	t2.tween_property(card, "modulate:a", 1.0, 1.0)
	t2.tween_interval(2.0)
	t2.tween_property(card, "modulate:a", 0.0, 0.8)
	await t2.finished
	await _wait(0.4)
	Narrator.skippable = false
	finished.emit()

func _set_blur(k: float) -> void:
	_blur_k = k
	_blur_mat.set_shader_parameter("strength", k)
	_blur_mat.set_shader_parameter("dark", 0.35 * k)

func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout

func _clip(name: String) -> void:
	var a: AnimationPlayer = intro.player.chibi.anim
	if not a.has_animation(name):
		await _wait(1.0)
		return
	a.speed_scale = 1.0
	a.play(name, 0.15)
	await _wait(a.get_animation(name).length)

func _ease_camera(secs: float) -> void:
	var from: Array = [intro.cam.position, intro.cam.position - intro.cam.global_transform.basis.z * 3.0, intro.cam.fov]
	var tw := create_tween()
	_cam_tw = tw
	tw.tween_method(func(k: float):
		var p: Vector3 = (from[0] as Vector3).lerp(cam_pos, k) + Vector3(0, sin(k * PI) * 0.7, 0)
		var l: Vector3 = (from[1] as Vector3).lerp(cam_look, k)
		intro.cam_override = [p, l, lerpf(from[2], cam_fov, k)], 0.0, 1.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _hero_chair() -> Node3D:
	var p: Vector3 = intro.player.position
	for c in intro.world.get_children():
		if c is Node3D and str(c.scene_file_path).ends_with("office_chair.glb") \
				and Vector2(c.position.x - p.x, c.position.z - p.z).length() < 0.1:
			return c
	return null

func _buzz(bubble := true) -> void:
	var phone: Node3D = null
	for c in intro.world.get_children():
		if c is Node3D and str(c.scene_file_path).ends_with("phone.glb"):
			phone = c
	if phone == null:
		return
	var base := phone.rotation
	var tw := create_tween()
	for i in 2:
		for k in 6:
			tw.tween_property(phone, "rotation:y", base.y + (0.12 if k % 2 == 0 else -0.12), 0.05)
		tw.tween_property(phone, "rotation", base, 0.05)
		tw.tween_interval(0.45)
	if not bubble:
		return
	var b := SpeechBubble.new()
	b.name_color = Color("4a5568")
	b.position = phone.position + Vector3(0, 0.22, 0)
	intro.world.add_child(b)
	b.show_text(tr("INTRO_PHONE_MSG"), 3.4, false, tr("SCR_BOSS_FULL"))
