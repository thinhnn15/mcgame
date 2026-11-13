class_name Morning
extends Node

const START := 510.0
const LUNCH_AT := 720.0
const STAY_AT := 1050.0
const LEAVES := [[1065.0, "khoa", "MR_KHOA_BYE"], [1085.0, "ngan", "MR_NGAN_BYE"], [1110.0, "kien", "MR_KIEN_BYE"],
	[1140.0, "tung", "MR_TUNG_BYE"]]
const MOM2_AT := 1155.0
const LIGHTS_AT := 1170.0
const LATE_AT := 1290.0
const PACE_DAY := 1.0
const PACE_EVE := 0.7
const WAIT_SECS := 45.0
const FAST_PACE := 8.0
const DOOR_AT := Vector3(-3.95, 0, 2.8)
const COFFEE_AT := Vector3(-2.95, 0, 1.65)
const WINDOW_AT := Vector3(-1.9, 0, -3.0)

var office
var clock := START
var busy := false
var show_bar := true
var ended := false
var dusk: Dusk
var lunch := ""
var mom := "none"
var stayed_answer := ""
var jobs_done := 0
var _hold := false
var _fired := {}
var _req := {}
var _t := 0.0
var _sat_at := -1.0
var _lunched := false
var _lights := false
var _can_go := false
var _fast_to := 0.0
var _auto := false
var _pace_mul := 1.0
var _hud: CanvasLayer
var _game_layer: CanvasLayer
var _clock_l: Label
var _toast: Label
var _phone_note: PanelContainer
var _phone_msgs: Array = []
var _thread: Array = []
var _phone_looked := false

func setup(p_office) -> void:
	office = p_office
	Hero.load_saved()
	office.morning = self
	_auto = OS.get_cmdline_user_args().has("--md-auto")
	_pace_mul = float(Stage.arg("--md-pace", "1"))
	_thread = [{"who": "mom", "text": tr("PHONE_MOM_MSG"), "when": tr("PHONE_WEEKS")},
		{"who": "log", "text": tr("OS_TODAY")}]
	if office.work and Hero.job == "design":
		office.work.work_chars = 3.0 * DesignApp.REV_CHARS
	_build_hud()
	dusk = Dusk.new()
	add_child(dusk)
	dusk.setup(office)
	if office.pick:
		office.pick.add(func(): return DOOR_AT + Vector3(-0.3, 1.0, 0.0), func(): return tr("MR_GO_HOME"),
			_go_home, func(): return not busy and not ended and office.player.controls)
		office.pick.add(func(): return COFFEE_AT + Vector3(-0.4, 1.0, 0.0), func(): return tr("MD_COFFEE"),
			_rest.bind("coffee"), func(): return not busy and office.player.controls and not ended)
		office.pick.add(func(): return WINDOW_AT + Vector3(0, 1.3, -0.3), func(): return tr("MD_WINDOW"),
			_rest.bind("window"), func(): return not busy and office.player.controls and not ended)
	if OS.get_cmdline_user_args().has("--md-ending"):
		_test_ending.call_deferred()
	elif _auto:
		_autoplay.call_deferred()

func _test_ending() -> void:
	if _auto:
		TalkBox.auto_secs = 2.0
	await get_tree().create_timer(1.0).timeout
	_end()

func _process(delta: float) -> void:
	_t += delta
	if ended:
		return
	if not _hold:
		var pace := PACE_EVE if _fired.has("stay") else PACE_DAY
		if clock < _fast_to and not busy and _req.is_empty():
			pace = FAST_PACE
		clock += delta * pace * _pace_mul
	dusk.set_time(clock)
	_update_hud()
	if busy:
		return
	var w = office.work
	var seated: bool = w != null and w.working
	var progress: float = w.progress if w else 0.0
	if seated and _sat_at < 0.0:
		_sat_at = _t

	if not _fired.has("boss") and _sat_at >= 0.0 and _t - _sat_at > 3.0:
		_moment("boss", _summon.bind("kien", "boss_job"))
	if not _fired.has("mom") and _fired.has("boss") and _req.is_empty() and clock >= 570.0 and progress > 0.12:
		_moment("mom", _phone_in.bind("text"))
	if not _fired.has("cake") and _fired.has("boss") and _req.is_empty() and clock >= 600.0 \
			and ((not seated and progress > 0.2) or office.player.global_position.distance_to(COFFEE_AT) < 1.4):
		_moment("cake", _summon.bind("ngan", "ngan_cake"))
	if not _fired.has("lunch") and _req.is_empty() and ((progress >= 0.5 and clock >= 690.0) or clock >= LUNCH_AT):
		_moment("lunch", _summon.bind("khoa", "khoa_lunch"))
	if _fired.has("lunch") and not _lunched and not _req.has("khoa"):
		_lunch()
		return

	if _lunched and jobs_done == 0 and progress >= 1.0:
		jobs_done = 1
		_fast_to = STAY_AT
		Narrator.say("MD_N_DONE", {"t": fmt(clock)})
	if not _fired.has("stay") and _lunched and _req.is_empty() and (jobs_done >= 1 or clock >= STAY_AT):
		clock = maxf(clock, STAY_AT)
		_moment("stay", _summon.bind("kien", "boss_stay"))

	if _fired.has("stay") and not _req.has("kien"):
		for l in LEAVES:
			if clock >= l[0] and not _fired.has("leave_" + l[1]):
				_fired["leave_" + l[1]] = true
				_leave(l[1], l[2])
		if clock >= MOM2_AT and not _fired.has("mom2"):
			_moment("mom2", _phone_in.bind("text2"))
		if clock >= LIGHTS_AT and not _lights:
			_lights = true
			dusk.lights_off()
			_say_toast(tr("MR_LIGHTS_OFF"))
			Narrator.say("MD_N_LAMPS")
		if jobs_done == 1 and progress >= 1.0:
			if not _lights:
				_fast_to = LIGHTS_AT
			else:
				jobs_done = 2
				_can_go = true
				Narrator.say("MD_N_HOME", {"t": fmt(clock)})
		elif clock >= LATE_AT and not _can_go:
			_can_go = true
			Narrator.say("MD_N_LATE", {"t": fmt(clock)})

func _moment(name: String, what: Callable) -> void:
	_fired[name] = true
	if _auto:
		print("MD moment %s at %s" % [name, fmt(clock)])
	what.call()

func fmt(m: float) -> String:
	return "%02d:%02d" % [(int(m) / 60) % 24, int(m) % 60]

func _build_hud() -> void:
	_game_layer = CanvasLayer.new()
	_game_layer.layer = 40
	add_child(_game_layer)
	_hud = CanvasLayer.new()
	_hud.layer = 60
	add_child(_hud)
	_clock_l = Label.new()
	_clock_l.anchor_left = 1.0
	_clock_l.anchor_right = 1.0
	_clock_l.offset_left = -260
	_clock_l.offset_right = -24
	_clock_l.offset_top = 22
	_clock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_l.add_theme_font_size_override("font_size", 26)
	_clock_l.add_theme_color_override("font_color", Color("fff8ef"))
	_clock_l.add_theme_color_override("font_outline_color", Color("8a5a48"))
	_clock_l.add_theme_constant_override("outline_size", 8)
	_clock_l.modulate.a = 0.85
	_hud.add_child(_clock_l)
	_toast = Label.new()
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_top = 130
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.add_theme_font_size_override("font_size", 24)
	_toast.add_theme_color_override("font_color", UiTheme.INK)
	_toast.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.98, 0.95, 0.95), 16, Color("f6dccf"), 2, 16))
	_toast.modulate.a = 0.0
	_hud.add_child(_toast)
	_phone_note = PanelContainer.new()
	_phone_note.theme = UiTheme.make()
	_phone_note.anchor_left = 1.0
	_phone_note.anchor_right = 1.0
	_phone_note.anchor_top = 1.0
	_phone_note.anchor_bottom = 1.0
	_phone_note.offset_left = -400
	_phone_note.offset_right = -24
	_phone_note.offset_top = -120
	_phone_note.offset_bottom = -30
	_phone_note.mouse_filter = Control.MOUSE_FILTER_STOP
	_phone_note.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_phone_note.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_open_phone())
	var nh := HBoxContainer.new()
	nh.name = "H"
	nh.add_theme_constant_override("separation", 12)
	nh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := PhoneApp.NoteIcon.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(54, 54)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.ring = -1.0
	nh.add_child(icon)
	var nl := Label.new()
	nl.name = "Text"
	nl.add_theme_font_size_override("font_size", 18)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nh.add_child(nl)
	_phone_note.add_child(nh)
	_phone_note.visible = false
	_hud.add_child(_phone_note)

func _update_hud() -> void:
	var text := tr("MR_MONDAY") + " · " + fmt(clock)
	if _clock_l.text != text:
		_clock_l.text = text
		if office.work and office.work.pc:
			office.work.pc.set_clock(fmt(clock))
	if _phone_note.visible and not busy:
		_phone_settle()

func _say_toast(text: String) -> void:
	_toast.text = text
	_toast.reset_size()
	var tw := create_tween()
	_toast.modulate.a = 0.0
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)

func minutes_left(_id: String) -> int:
	return -1

func has_request(id: String) -> bool:
	return _req.has(id) and _req[id]["state"] == "waiting"

func _summon(id: String, kind: String) -> void:
	var b: NpcBrain = office.life.people.get(id) if office.life else null
	if b == null or not b.npc.visible:
		return
	var r := {"kind": kind, "state": "coming", "until": INF}
	_req[id] = r
	while not b.react(_come.bind(b, r), 9, "request"):
		await get_tree().create_timer(1.0).timeout
		if ended:
			return

func _come(b: NpcBrain, r: Dictionary) -> void:
	"""They walk over, stand by the hero with a quiet "!", and wait a while; then leave it on the desk."""
	var p: Player = office.player
	var to := b.npc.global_position - p.global_position
	to.y = 0.0
	var spot := p.global_position + (to.normalized() if to.length() > 0.05 else Vector3.BACK) * 1.0
	var w = office.work
	if w and w.working and not w._seat.is_empty():

		var fwd := Vector3(sin(w._seat["yaw"]), 0, cos(w._seat["yaw"]))
		var side := fwd.cross(Vector3.UP)
		spot = p.global_position - fwd * 0.95 + side * (0.45 if to.dot(side) >= 0.0 else -0.45)
	get_tree().create_timer(12.0).timeout.connect(func():
		if r["state"] == "coming":
			b.npc.interrupt())
	await b.npc.walk_to(spot)
	b.engaged = true
	await b.npc.face_point(p.global_position)
	b.npc.look_at_node = p
	r["state"] = "waiting"
	r["until"] = _t + WAIT_SECS
	var icon := Label3D.new()
	icon.text = "!"
	icon.font_size = 64
	icon.pixel_size = 0.004
	icon.modulate = Color("ff8c69")
	icon.outline_modulate = Color("fff8ef")
	icon.outline_size = 16
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.no_depth_test = true
	icon.position = Vector3(0, 1.85, 0)
	b.npc.add_child(icon)
	r["icon"] = icon
	while r["state"] in ["waiting", "talking"] and not ended:
		await get_tree().process_frame
		icon.position.y = 1.85 + 0.05 * sin(_t * 4.0)
		icon.visible = r["state"] == "waiting" and not office.life.prompting(b)
		if r["state"] == "waiting" and _t > r["until"] and not busy:
			r["state"] = "missed"
			await _missed(b, r)
	icon.queue_free()
	b.npc.look_at_node = null
	_req.erase(b.npc.id)

func request_talk(b: NpcBrain) -> void:
	"""The hero turned to someone who came over (scripts/npc/office_life.gd talk_to)."""
	var r: Dictionary = _req[b.npc.id]
	r["state"] = "talking"
	busy = true
	_hold = true
	var p: Player = office.player
	var free := p.controls
	p.controls = false
	p.stop_going()
	var box: TalkBox = office.life.box
	box.set_speaker(b.npc.chibi, Npc.TAG_COLORS.get(b.npc.id, UiTheme.PINK))
	Narrator.clear()
	var screen := _pc_aside()
	match str(r["kind"]):
		"boss_job":
			await _talk_boss_job(b, box)
		"ngan_cake":
			await _talk_ngan_cake(b, box)
		"khoa_lunch":
			await _talk_khoa_lunch(b, box)
		"boss_stay":
			await _talk_boss_stay(b, box)
	box.close()
	_pc_back(screen)
	if free:
		p.controls = true
	r["state"] = "done"
	_hold = false
	busy = false

func _missed(b: NpcBrain, r: Dictionary) -> void:
	"""Never turned round: they leave it on the desk, no hard feelings, and go back to their day."""
	match str(r["kind"]):
		"boss_job":
			b.npc.say("MR_KIEN_NOTE")
			_new_job(false)
		"ngan_cake":
			b.npc.say("MR_NGAN_OK")
		"khoa_lunch":
			lunch = "no"
			b.npc.say("MR_KHOA_NO")
		"boss_stay":
			b.npc.say("MR_KIEN_NOTE")
			stayed_answer = "stay"
			_new_job(true)
	await b.npc.wait(1.5)

func _pc_aside() -> bool:
	if office.work and office.work.working and office.work.pc.shown:
		office.work._show_screen(false)
		return true
	return false

func _pc_back(was_shown: bool) -> void:
	if was_shown and office.work.working and not office.work.pc.shown:
		office.work._show_screen(true)

func _say(b: NpcBrain, box: TalkBox, key: String, face := "smile") -> void:
	await box.say(tr("NAME_" + b.npc.id.to_upper()), tr(key), Npc.TAG_COLORS.get(b.npc.id, UiTheme.PINK_DARK),
		TalkBox.FACES.get(face, TalkBox.FACES["smile"]))

func _talk_boss_job(b: NpcBrain, box: TalkBox) -> void:
	await _say(b, box, "MD_KIEN_JOB_" + Hero.job.to_upper(), "calm")
	var i: int = await box.ask([tr("MR_OK_BOSS"), tr("MR_BUSY_BOSS")])
	if i == 1:
		await _say(b, box, "MR_KIEN_BUSY_REPLY", "calm")
	box.close()
	_new_job(false)
	Narrator.say("MD_N_WORK")

func _new_job(night: bool) -> void:
	"""The job is the typing: the desk's bar starts over, and a line says what it is."""
	if office.work:
		office.work.progress = 0.0
	var key := ("MR_T_NIGHT_" if night else "MR_T_JOB_") + Hero.job.to_upper()
	_say_toast(Lang.t("MD_NEW_WORK", {"w": tr(key)}))

func _talk_ngan_cake(b: NpcBrain, box: TalkBox) -> void:
	await _say(b, box, "MR_NGAN_CAKE", "happy")
	var i: int = await box.ask([tr("MD_CAKE_YES"), tr("MR_CAKE_NO")])
	if i == 0:
		Bonds.add("ngan", 3)
		EmoteFx.play(b.npc.chibi, "heart", 0.0)
		await _say(b, box, "MR_NGAN_HAPPY", "happy")
	else:
		await _say(b, box, "MR_NGAN_OK", "smile")

func _talk_khoa_lunch(b: NpcBrain, box: TalkBox) -> void:
	await _say(b, box, "MR_KHOA_LUNCH", "calm")
	var i: int = await box.ask([tr("MR_LUNCH_YES"), tr("MR_LUNCH_NO")])
	lunch = "yes" if i == 0 else "no"
	await _say(b, box, "MR_KHOA_YES" if i == 0 else "MR_KHOA_NO", "happy" if i == 0 else "calm")
	if i == 0:
		Bonds.add("khoa", 3)
		await _say(b, box, "MD_KHOA_HOUSE", "calm")
		Narrator.say("MD_N_HOUSE")

func _lunch() -> void:
	"""Midday: a black card for a moment - bún chả with Duy, or noodles at the desk - and it is 13:00."""
	_lunched = true
	busy = true
	_hold = true
	var card := _black_card(tr("MR_LUNCH_WITH") if lunch == "yes" else tr("MR_LUNCH_DESK"))
	await _beat(card, 3.4)
	clock = 780.0
	await _fade_out(card)
	_hold = false
	busy = false

func _talk_boss_stay(b: NpcBrain, box: TalkBox) -> void:
	await _say(b, box, "MR_KIEN_STAY", "calm")
	var i: int = await box.ask([tr("MR_STAY_OK"), tr("MR_STAY_ASK")])
	stayed_answer = "stay" if i == 0 else "asked"
	if i == 1:
		await _say(b, box, "MR_KIEN_STAY_REPLY", "calm")
		Narrator.say("MR_N_ASKED")
	box.close()
	_new_job(true)

func _leave(id: String, line_key: String) -> void:
	"""Someone goes home: a word over their shoulder, out of the door, gone for the day."""
	var b: NpcBrain = office.life.people.get(id) if office.life else null
	if b == null:
		return
	_req.erase(id)
	while not b.react(_walk_out.bind(b, line_key), 30, "leave"):
		await get_tree().create_timer(1.0).timeout
		if ended:
			return

func _walk_out(b: NpcBrain, line_key: String) -> void:
	b.engaged = true
	b.npc.say(line_key)
	EmoteFx.play(b.npc.chibi, "note", 0.0)
	await b.npc.walk_to(DOOR_AT, false, true)
	b._alive = false
	get_tree().create_timer(0.2).timeout.connect(func(): b.engaged = true)
	b.npc.visible = false
	b.npc.process_mode = Node.PROCESS_MODE_DISABLED
	b.npc.global_position = Vector3(-6.0, 0, 2.8)

func _rest(kind: String) -> void:
	var p: Player = office.player
	var at: Vector3 = COFFEE_AT if kind == "coffee" else WINDOW_AT
	await p.go_to(at, false, 0.3)
	if p.global_position.distance_to(at) > 0.8 or busy:
		return
	busy = true
	p.controls = false
	p.facing = -PI / 2 if kind == "coffee" else PI
	p.rotation.y = p.facing
	if kind == "coffee":
		p.chibi.hold("cup")
		EmoteFx.play(p.chibi, "note", 0.0)
	else:
		EmoteFx.play(p.chibi, "sparkle", 0.0)
	await get_tree().create_timer(1.8).timeout
	clock += 5.0
	if kind == "coffee":
		p.chibi.hold("")
	else:
		Narrator.say("MR_WINDOW_DONE")
	p.controls = true
	busy = false

func _phone_in(kind: String) -> void:
	_phone_msgs.append(kind)
	_thread.append({"who": "mom", "text": tr("MR_MOM_TEXT2" if kind == "text2" else "MR_MOM_TEXT"), "new": true})
	_phone_settle()
	var x0 := _phone_note.position.x
	var tw := create_tween()
	for i in 6:
		tw.tween_property(_phone_note, "position:x", x0 + (6.0 if i % 2 == 0 else -6.0), 0.04)
	tw.tween_property(_phone_note, "position:x", x0, 0.04)

func _phone_settle() -> void:
	_phone_note.visible = not _phone_msgs.is_empty()
	if not _phone_note.visible:
		return
	var l: Label = _phone_note.get_node("H/Text")
	var text := "%s · %s\n%s" % [tr("PHONE_MOM_NAME"), tr("PHONE_NEW"),
		tr("MR_PHONE_HINT_CLICK") if _typing_at_desk() else tr("MR_PHONE_HINT")]
	if l.text != text:
		l.text = text

func _typing_at_desk() -> bool:
	return office.work != null and office.work.working and office.work.pc.shown

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_P and _phone_note.visible \
			and not _typing_at_desk():
		get_viewport().set_input_as_handled()
		_open_phone()

func _open_phone() -> void:
	if busy or ended or _phone_msgs.is_empty():
		return
	busy = true
	_hold = true
	var kind: String = _phone_msgs[-1]
	_phone_note.visible = false
	var screen := _pc_aside()
	var p: Player = office.player
	var free := p.controls
	var seated: bool = office.work != null and office.work.working
	p.controls = false
	p.stop_going()
	if not seated:
		var cam := get_viewport().get_camera_3d()
		var to := cam.global_position - p.global_position
		var yaw := atan2(to.x, to.z)
		create_tween().tween_property(p, "rotation:y", p.rotation.y + angle_difference(p.rotation.y, yaw), 0.2)
		p.facing = yaw
	_phone_out(p.chibi, seated)
	var side_was: float = office.cam_side
	var zoom_was: float = office.cam_zoom
	office.cam_side = 0.25
	office.cam_zoom = minf(zoom_was, 0.7)
	var app := PhoneApp.new()
	_game_layer.add_child(app)
	app.setup(fmt(clock), _battery())
	await app.slide_in()
	if not _phone_looked:
		_phone_looked = true
		await app.lock([tr("PHONE_MOM_NAME") + " · " + tr("PHONE_NEW"), tr("PHONE_CAL")])
	var said := ""
	var choices := [[tr("MR_P_CALL"), "call"], [tr("PHONE_REPLY_LIE2" if kind == "text2" else "PHONE_REPLY_LIE"), "lie"],
		[tr("MR_P_LATER"), "later"]]
	var typing := _thread.any(func(en): return en.get("new", false))
	var id: String = await app.thread(_thread, choices, typing)
	for en in _thread:
		en.erase("new")
	match id:
		"call":
			_phone_msgs.clear()
			await app.talk([tr("PHONE_CALL_1"), tr("PHONE_CALL_2"), tr("PHONE_CALL_3")], tr("PHONE_BYE"))
			mom = "called"
			_thread.append({"who": "log", "text": tr("PHONE_LOG_CALL")})
			clock += 10.0
			said = "MR_MOM_CALLED"
		"lie":
			_phone_msgs.clear()
			var t := tr("PHONE_REPLY_LIE2" if kind == "text2" else "PHONE_REPLY_LIE")
			_thread.append({"who": "me", "text": t})
			await app.reply(t)
			if mom != "called":
				mom = "lied"
			said = "MR_MOM_LIED2" if kind == "text2" else "MR_MOM_LIED"
	app.slide_out()
	office.cam_side = side_was
	office.cam_zoom = zoom_was
	await _phone_away(p.chibi, seated)
	if free:
		p.controls = true
	_hold = false
	_pc_back(screen)
	if said != "":
		Narrator.say(said)
	busy = false
	_phone_settle()

func _phone_out(c: Chibi, seated: bool) -> void:
	var a := c.anim
	var ph := HandPhone.on(c)
	if seated and a.has_animation("Act_SitChair_Phone"):
		a.get_animation("Act_SitChair_Phone").loop_mode = Animation.LOOP_LINEAR
		c.play("Act_SitChair_Phone", 0.3)
		get_tree().create_timer(0.15).timeout.connect(func(): ph.shown = true)
	elif a.has_animation("Act_PhoneOut"):
		c.play("Act_PhoneOut", 0.12)
		a.queue("Act_PhoneLook")
		get_tree().create_timer(0.3).timeout.connect(func(): ph.shown = true)
	else:
		c.play("Act_SitChair_Idle" if seated else "Act_PhoneLook", 0.2)
		ph.shown = not seated

func _phone_away(c: Chibi, seated: bool) -> void:
	var a := c.anim
	var ph := HandPhone.on(c)
	if seated or not a.has_animation("Act_PhoneAway"):
		ph.shown = false
		c.play("Act_SitChair_Type" if seated else "Base_Wait", 0.25)
		return
	c.play("Act_PhoneAway", 0.1)
	a.queue("Base_Wait")
	await get_tree().create_timer(0.37).timeout
	ph.shown = false
	await get_tree().create_timer(0.17).timeout

func _battery() -> int:
	"""82% in the morning, down to 12% late at night (the 01:35 lock screen's)."""
	return int(round(lerpf(82.0, 12.0, clampf((clock - START) / (1440.0 - START), 0.0, 1.0))))

func _go_home() -> void:
	"""The door. While the boss is still in, a word on why not; after that, home - with the work or without."""
	if busy or ended:
		return
	var p: Player = office.player
	if not _fired.has("leave_kien"):
		Narrator.say("MR_DOOR_EARLY", {"t": fmt(clock)})
		return
	await p.go_to(DOOR_AT + Vector3(0.4, 0, 0), false, 0.3)
	if busy or ended:
		return
	_end()

func _end() -> void:
	"""Black. The night in the rented room, a line at a time (the rent going up, the flat twenty years away);
	Tuesday the same; Friday (played already); Saturday, Bố's message and the two words back; the resignation
	letter with the name; and home - the farm plot (docs/cot_truyen_thanh_pho.md, approved 06/11)."""
	ended = true
	busy = true
	_hold = true
	var done := _can_go
	var black := _black_card(tr("MR_HOME_EARLY" if done else "MR_HOME_CARRY"))
	await _beat(black, 3.6)
	(black.get_child(0) as Control).visible = false
	_hud.visible = false
	var home := clock + 40.0
	var lines := [Lang.t("MD_NIGHT_ROOM", {"t": fmt(fmod(home, 1440.0))})]
	if done:
		lines.append(Lang.t("MD_NIGHT_NOODLES", {"t": fmt(fmod(home + 15.0, 1440.0))}))
	var rent := home + 12.0 + (20.0 if done else 0.0)
	var app_at := rent + 13.0
	var boss_at := maxf(app_at + 20.0, 1410.0)
	lines.append_array([Lang.t("MD_NIGHT_RENT", {"t": fmt(fmod(rent, 1440.0))}),
		Lang.t("MD_NIGHT_APP", {"t": fmt(fmod(app_at, 1440.0))}),
		Lang.t("MR_NIGHT_BOSS", {"t": fmt(fmod(boss_at, 1440.0))}),
		Lang.t("MD_NIGHT_BED", {"t": fmt(fmod(boss_at + 20.0, 1440.0))})])
	_room_open("night")
	create_tween().tween_property(black, "color:a", 0.42, 1.4)
	await _night(black, lines)
	Narrator.taps = true
	Narrator.skippable = false
	await Narrator.say("MR_N_TOMORROW")
	await Narrator.say("MD_N_FRIDAY")
	await _beat(black, 1.2)
	if _room:
		_room.set_time("morning")
		create_tween().tween_property(black, "color:a", 0.18, 1.2)
	await _saturday(black)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 0.96, 0.8)
	await tw.finished
	_room_close()
	await _resign(black)
	await _beat(black, 1.0)
	if _auto:
		print("MD END mom=%s lunch=%s stayed=%s jobs=%d" % [mom, lunch, stayed_answer, jobs_done])
		get_tree().quit()
		return
	Story.chapter = "que_1"
	Story.day = 1
	Story.set_beat("done")

	Engine.set_meta("ve_que_chain", true)
	get_tree().change_scene_to_file("res://scenes/hanh_trinh.tscn")

var _reading := false
var _room: PhongTro

func _room_open(t: String) -> void:
	"""The rented room (scripts/city/phong_tro.gd) built far from the office floor, its camera and light swapped in;
	the office's lights hidden meanwhile. The cards stay over it, dimmed instead of black."""
	_room = PhongTro.new()
	_room.position = Vector3(400, 0, 0)
	office.add_child(_room)
	_room.build()
	_room.set_time(t)
	var lights: Array = office.find_children("*", "Light3D", true, false).filter(func(n): return not _room.is_ancestor_of(n))
	_room.show_in(office.get_node("WorldEnvironment"), lights)

func _room_close() -> void:
	if _room:
		_room.hide_from(office.get_node("WorldEnvironment"))
		_room.queue_free()
		_room = null

func _read_lines(keys: Array) -> void:
	"""Narration read on while something else waits (the phone's chip): _reading is true till the last line."""
	_reading = true
	for k in keys:
		await Narrator.say(k)
	_reading = false

func _saturday(black: Control) -> void:
	"""Saturday, 09:40 (cot_truyen_thanh_pho nhịp D): the first morning of the week without the alarm. The lock
	screen: Bố, 06:12, with his photo of the land; under it Mum's message, three weeks unanswered. His words,
	read; the land, twenty years away here and already there at home; and the two words typed back: "Con về."."""
	await Narrator.say("MD_SAT_1")
	var app := PhoneApp.new()
	_game_layer.add_child(app)
	app.setup("09:40", 71)
	await app.slide_in()
	await app.lock([tr("PHONE_DAD_NAME") + " · 06:12 · " + tr("PHONE_NEW"),
		tr("PHONE_MOM_NAME") + " · " + tr("MD_SAT_OLD")], tr("PHONE_DAY_SAT"))
	var photo := "res://ui/photos/dat_bo.png"
	var entries := [{"who": "mom", "when": tr("MD_DAD_WHEN"), "text": tr("MD_DAD_1"),
			"photo_tex": load(photo) if ResourceLoader.exists(photo) else null},
		{"who": "mom", "text": tr("MD_DAD_2")}]
	if _auto:
		_auto_press(app)
	_read_lines(["MD_SAT_2", "MD_SAT_3", "MD_SAT_4"])
	await app.thread(entries, [[tr("MD_REPLY_HOME"), "home"]], true, tr("PHONE_DAD_NAME"))
	while _reading:
		await get_tree().process_frame
	await app.reply(tr("MD_REPLY_HOME"))
	await Narrator.say("MD_SAT_5")
	await app.slide_out()
	await _beat(black, 0.8)

func _auto_press(app: PhoneApp) -> void:
	"""--md-auto: the thread's chip, pressed a moment after it appears (a signal sent earlier would be lost)."""
	while is_instance_valid(app) and not app._choosing:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(app):
		app.chosen.emit("home")

func _resign(black: Control) -> void:
	"""Monday, 08:00 (nhịp E), at his own desk in the office (07/11 Màn chơi, the user's ask): the morning light back on
	the floor, the hero sat down; the resignation letter on the screen as a sheet of paper, "Họ tên:" - and the name,
	written slowly; then Kiên, Dung and Duy come by one at a time, stand behind the chair, say their word (by their
	hearts) and go back. Nobody is in the way: staying late was normal here, and so is leaving."""
	await Narrator.say("MD_RES_0")
	await _office_morning()
	var tw := create_tween()
	tw.tween_property(black, "color:a", 0.0, 1.2)
	await tw.finished
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffdf6")
	sb.border_color = Color("d9cdb8")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 10
	for side in ["left", "right"]:
		sb.set("content_margin_" + side, 48)
	sb.content_margin_top = 34
	sb.content_margin_bottom = 40
	paper.add_theme_stylebox_override("panel", sb)
	paper.set_anchors_preset(Control.PRESET_CENTER)
	paper.grow_horizontal = Control.GROW_DIRECTION_BOTH
	paper.grow_vertical = Control.GROW_DIRECTION_BOTH
	paper.custom_minimum_size = Vector2(620, 300)
	paper.modulate.a = 0.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 26)
	paper.add_child(v)
	var head := Label.new()
	head.text = tr("MD_RES_FORM")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 34)
	head.add_theme_color_override("font_color", Color("3a3540"))
	v.add_child(head)
	var line := Label.new()
	line.add_theme_font_size_override("font_size", 30)
	line.add_theme_color_override("font_color", Color("3a3540"))
	v.add_child(line)
	_game_layer.add_child(paper)
	line.text = tr("MD_RES_NAME")
	var t2 := create_tween()
	t2.tween_property(paper, "modulate:a", 1.0, 0.5)
	await _beat(black, 1.0)
	await Narrator.say("MD_RES_1")
	var name := Hero.name if Hero.name != "" else tr("HERO_CALLED")
	for k in name.length():
		line.text = tr("MD_RES_NAME") + " " + name.left(k + 1)
		await _beat(black, 0.28)
	await Narrator.say("MD_RES_2")
	await _beat(black, 0.8)
	var t3 := create_tween()
	t3.tween_property(paper, "modulate:a", 0.0, 0.5)
	await t3.finished
	paper.queue_free()

	for who in [["kien", "MD_BYE_KIEN", "MD_BYE_KIEN"], ["ngan", "MD_BYE_NGAN", "MD_BYE_NGAN_0"],
			["khoa", "MD_BYE_KHOA", "MD_BYE_KHOA_0"]]:
		var key: String = who[1] if (who[0] == "kien" or Bonds.hearts(who[0]) > 0) else who[2]
		await _goodbye(who[0], key)
	await Narrator.say("MD_RES_END")
	var t4 := create_tween()
	t4.tween_property(black, "color:a", 0.96, 1.0)
	await t4.finished

func _office_morning() -> void:
	"""The office as it is at 08:00 the next Monday: day light (the dusk undone, the strip lights on), the hero sat at
	his desk with the screen put away, the three who will say goodbye at their places."""
	clock = 480.0
	if dusk._off_tw:
		dusk._off_tw.kill()
	dusk._off = 0.0
	dusk.set_time(clock)
	var w = office.work
	show_bar = false
	if w and w._panel:
		w._panel.visible = false
	if w and not w.working and not w.seats.is_empty():
		office.player.global_position = w._spot(w.seats[0])
		w.sit_down(w.seats[0])
		var waited := 0.0
		while waited < 4.0 and not (w.pc and w.pc.shown):
			await get_tree().process_frame
			waited += get_process_delta_time()
	if w and w.pc and w.pc.shown:
		w._show_screen(false)
	if office.life:
		for b in office.life.people.values():
			(b as NpcBrain).engaged = true
	for id in ["kien", "ngan", "khoa"]:
		var b: NpcBrain = office.life.people.get(id) if office.life else null
		if b == null:
			continue
		b._alive = false
		b.engaged = true
		b.npc.process_mode = Node.PROCESS_MODE_INHERIT
		b.npc.visible = true
		b.npc.global_position = DOOR_AT + Vector3(0.6 + ["kien", "ngan", "khoa"].find(id) * 0.5, 0, -0.4)

func _goodbye(id: String, key: String) -> void:
	"""One of them walks up behind the hero's chair, faces him, says the word, and walks off to the door."""
	var b: NpcBrain = office.life.people.get(id) if office.life else null
	if b == null:
		return
	var p: Player = office.player
	var spot := p.global_position + Vector3(0.0, 0.0, 0.95)
	var w = office.work
	if w and not w._seat.is_empty():
		var fwd := Vector3(sin(w._seat["yaw"]), 0, cos(w._seat["yaw"]))
		var side := fwd.cross(Vector3.UP)
		spot = p.global_position - fwd * 0.95 + side * 0.45
	await b.npc.walk_to(spot, false, true)
	b.npc.face_point(p.global_position)
	var box: TalkBox = office.life.box
	box.set_speaker(b.npc.chibi, Npc.TAG_COLORS.get(b.npc.id, UiTheme.PINK))
	await _say(b, box, key, "smile")
	box.close()
	b.npc.walk_to(DOOR_AT, false, true)
	await get_tree().create_timer(0.6).timeout

func _black_card(text: String) -> ColorRect:
	var black := ColorRect.new()
	black.color = Color(0.03, 0.02, 0.05, 0.0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	var l := Label.new()
	l.text = text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 36)
	l.add_theme_color_override("font_color", Color("fff8ef"))
	l.modulate.a = 0.0
	black.add_child(l)
	_game_layer.add_child(black)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 0.96, 0.6)
	tw.tween_property(l, "modulate:a", 1.0, 0.5)
	return black

func _fade_out(card: ColorRect) -> void:
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 0.0, 0.6)
	await tw.finished
	card.queue_free()

func _night(black: Control, lines: Array) -> void:
	"""The night after the door, a line at a time, the earlier ones fading back."""
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 160
	v.offset_right = -160
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 22)
	black.add_child(v)
	for i in lines.size():
		for old in v.get_children():
			create_tween().tween_property(old, "modulate:a", 0.35, 0.4)
		var l := Label.new()
		l.text = lines[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", Color("fff8ef"))
		l.modulate.a = 0.0
		v.add_child(l)
		create_tween().tween_property(l, "modulate:a", 1.0, 0.5)
		await _beat(black, 2.8)
	await _beat(black, 0.8)
	var tw := create_tween()
	tw.tween_property(v, "modulate:a", 0.0, 0.5)
	await tw.finished
	v.queue_free()

func _beat(black: Control, seconds: float) -> void:
	"""A while on a black card; a click moves it on."""
	var skip := [false]
	var f := func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			skip[0] = true
	black.gui_input.connect(f)
	var until := _t + seconds / (_pace_mul if _auto else 1.0)
	while _t < until and not skip[0]:
		await get_tree().process_frame
	black.gui_input.disconnect(f)

func _autoplay() -> void:
	"""--md-auto: sit, type, answer everyone's first option, stand up once for the cake, go home at the end."""
	TalkBox.auto_secs = 0.8
	TalkBox.auto_picks = [0]
	await get_tree().create_timer(2.0).timeout
	var w = office.work
	await w.sit_down(w.seats[0])
	var stood := false
	while not ended and is_inside_tree():
		await get_tree().create_timer(0.4).timeout
		if busy:
			continue
		if w.working and w.pc:
			if Hero.job == "design":
				w.progress = minf(1.0, w.progress + 0.03 * _pace_mul)
			else:
				w.pc.type_keys(int(14 * _pace_mul))
		for id in _req.keys():
			if has_request(id) and not office.life.talking:
				office.life.talk_to(office.life.people[id])
				break
		if not stood and _fired.has("mom") and w.working and w.progress > 0.25 and _req.is_empty():
			stood = true
			await w.stand_up()
			await get_tree().create_timer(1.5).timeout
			await office.player.go_to(COFFEE_AT, false, 0.4)
			await get_tree().create_timer(6.0).timeout
		if stood and not w.working and _req.is_empty() and not office.life.talking and not _can_go:
			await w.sit_down(w.seats[0])
		if _can_go and w.working:
			await w.stand_up()
			_go_home()
