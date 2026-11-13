class_name Player
extends CharacterBody3D

const WALK := 1.7
const RUN := 3.4
const WALK_CLIP_SPEED := 0.78
const RUN_CLIP_SPEED := 1.65

const SMALL_AT := 10.0
const BIG_AT := 30.0
const SMALL_GESTURES := ["Act_LookAround", "Act_Stretch", "Wait_ScratchHead", "Wait_Nails", "Wait_BrushOff",
	"Wait_Hum", "emote:sigh", "emote:sneeze"]
const TOOL_GESTURES := ["Act_LookAround", "emote:sigh"]
const CLIP_FX := {"Wait_Hum": ["note", 14], "Emo_Sleepy": ["z", 36]}
const DOZE_Z := 4.0

const WADE_IN := 0.06
const SWIM_IN := 0.62
const SWIM_OUT := 0.5
const SWIM := 1.1
const SWIM_CLIP_SPEED := 0.55

const DIVE_IN := 1.5
const DIVE_OUT := 1.3
const DIVE_MAX := 8.0
const UNDER := 0.9

var chibi: Chibi
var cam: Camera3D
var sitting := false
var facing := 0.0
var auto_move := Vector2.ZERO
var pace := 1.0
var steer := Vector3.ZERO
var steer_run := false
var _go := 0
var gestures := true
var _idle := 0.0
var _smalls := 0
var _last_small := ""
var _mine := ""
var _big := ""
var _z := 0.0
var controls := true
var emote_keys := true
var remote := false
var bounds_box := 0.0
var peer_id := 0
var _clip := ""
var _tag: Label3D
var vehicle = null

var water := 0

var _pave = null
var water_y := NAN
var water_d := 0.0
var _wfx: SwimFX
var dive := ""
var _dive_t := 0.0
var _was_at := Vector3.INF
static var _swim_ev := {}

signal tool_pressed

func _ready() -> void:
	if not remote:
		add_to_group(&"hero")
		TouchControls.add_action(self, _touch_tool, 40)
		TouchControls.add_action(self, _touch_dive, 30)

func _touch_tool() -> Dictionary:
	"""The touch screen's action button: the tool in hand, as F / pad A."""
	if not controls or chibi == null or chibi.tool == "" or busy():
		return {}
	return {"label": tr("TC_USE"), "run": tool_pressed.emit}

func _touch_dive() -> Dictionary:
	"""The action button while swimming in deep water: dive, and up again."""
	if not controls or chibi == null or water != 2:
		return {}
	if dive == "" and water_d > DIVE_IN:
		return {"label": tr("TC_DIVE"), "run": toggle_dive}
	if dive == "Swim_Under":
		return {"label": tr("TC_SURFACE"), "run": toggle_dive}
	return {}

func setup(look: Dictionary, camera: Camera3D) -> void:
	cam = camera
	var shape := CapsuleShape3D.new()
	shape.radius = 0.26
	shape.height = 1.3
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.65
	add_child(cs)
	chibi = Chibi.new()
	add_child(chibi)
	chibi.build(look)
	Net.acted.connect(_on_acted)

func owner_id() -> int:
	return peer_id if remote else Net.my_id()

func set_name_tag(text: String) -> void:
	"""The name over the head, shown while online."""
	if _tag == null:
		_tag = Label3D.new()
		_tag.font_size = 48
		_tag.pixel_size = 0.004
		_tag.outline_size = 14
		_tag.modulate = Color("5b4a44")
		_tag.outline_modulate = Color("fffaf2")
		_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_tag.position.y = 1.62
		add_child(_tag)
	_tag.text = text
	_tag.visible = text != ""

func _on_acted(id: int, kind: String, arg: String) -> void:
	if id != owner_id():
		return
	match kind:
		"emote":
			if remote or not busy():
				chibi.emote(arg)
		"clip":
			var parts := arg.split(">")
			if (remote or not busy()) and chibi.anim.has_animation(parts[0]):
				if parts.size() > 1:
					chibi._base_clip = parts[1]
				chibi.anim.speed_scale = 1.0
				chibi.anim.play(parts[0], 0.3)
				chibi.anim.queue(chibi._base_clip)
				if CLIP_FX.has(parts[0]):
					EmoteFx.play(chibi, CLIP_FX[parts[0]][0], CLIP_FX[parts[0]][1] / 30.0)
		"fx":
			EmoteFx.play(chibi, arg)

func _input_dir() -> Vector2:
	if not controls or Agent.quiet:
		return auto_move
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A): v.x -= 1
	if Input.is_physical_key_pressed(KEY_D): v.x += 1
	if Input.is_physical_key_pressed(KEY_W): v.y -= 1
	if Input.is_physical_key_pressed(KEY_S): v.y += 1
	v += TouchControls.move
	if auto_move != Vector2.ZERO:
		v = auto_move
	return v.limit_length(1.0)

func _unhandled_input(e: InputEvent) -> void:
	if remote or not controls:
		return
	if (e is InputEventKey or e is InputEventJoypadButton) and e.pressed:
		_poke()
	if e is InputEventKey and e.pressed and not e.echo:
		if vehicle != null and vehicle.riding() and e.physical_keycode in [KEY_E, KEY_Q, KEY_C]:
			return
		match e.physical_keycode:
			KEY_E:
				if emote_keys:
					Net.act("emote", "wave")
			KEY_Q:
				if emote_keys:
					Net.act("emote", "happy")
			KEY_C: toggle_sit()
			KEY_F, KEY_SPACE:
				if vehicle != null and vehicle.use(self):
					return
				if water == 2:
					toggle_dive()
				elif chibi.tool != "" and not busy():
					tool_pressed.emit()
	if e is InputEventJoypadButton and e.pressed:
		match e.button_index:
			JOY_BUTTON_A:
				if vehicle != null and vehicle.use(self):
					return
				if water == 2:
					toggle_dive()
				elif chibi.tool != "" and not busy():
					tool_pressed.emit()
			JOY_BUTTON_X: Net.act("emote", "wave")
			JOY_BUTTON_Y: Net.act("emote", "happy")
			JOY_BUTTON_B: toggle_sit()

func go_to(goal: Vector3, run := false, arrive := 0.15, timeout := 20.0) -> String:
	"""Walk somewhere by itself (a click, the AI), along the navigation mesh when the scene has one.
	Returns "arrived", "stuck", "timeout" or "cancelled" (a move key, stop_going(), or another go_to)."""
	_go += 1
	var me := _go
	goal.y = global_position.y
	var path := PackedVector3Array([goal])
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_regions(map).size() > 0:
		var nav := NavigationServer3D.map_get_path(map, global_position, goal, true)
		if nav.size() > 1:
			path = nav.slice(1)
	steer_run = run
	var t := 0.0
	var check_t := 0.0
	var check_pos := global_position
	var i := 0
	var result := "arrived"
	while i < path.size():
		var to := path[i] - global_position
		to.y = 0
		if to.length() < (arrive if i == path.size() - 1 else 0.4):
			i += 1
			continue
		steer = to.normalized() * clampf(to.length() / 0.5, 0.35, 1.0)
		await get_tree().physics_frame
		if me != _go or not is_inside_tree():
			return "cancelled"
		var dt := get_physics_process_delta_time() * Engine.time_scale
		t += dt
		check_t += dt
		if check_t > 1.0:
			if global_position.distance_to(check_pos) < 0.1:
				result = "stuck"
				break
			check_t = 0.0
			check_pos = global_position
		if t > timeout:
			result = "timeout"
			break
	steer = Vector3.ZERO
	return result

func stop_going() -> void:
	_go += 1
	steer = Vector3.ZERO

func set_sitting(on: bool) -> void:
	"""Sit on the ground (or stand up)."""
	sitting = on
	chibi.play("Act_SitFloor" if sitting else "Base_Wait", 0.3)

func toggle_sit() -> void:
	"""C / pad B: down onto the ground and up again, animated (Wait_SitDown / Wait_SitUp)."""
	if water != 0 and not sitting:
		return
	if sitting:
		stand_up()
	elif chibi.anim.has_animation("Wait_SitDown"):
		sitting = true
		Net.act("clip", "Wait_SitDown>Act_SitFloor")
	else:
		set_sitting(true)

func stand_up() -> void:
	"""Up off the ground; the walk waits for the clip (busy). Other seats (a chair, a bed) just blend."""
	_big = ""
	if chibi._base_clip == "Act_SitFloor" and chibi.anim.has_animation("Wait_SitUp"):
		sitting = false
		Net.act("clip", "Wait_SitUp>Base_Wait")
	else:
		set_sitting(false)

func riding() -> bool:
	return vehicle != null and vehicle.riding()

func _pave_feet(delta: float) -> void:
	if _pave == null:
		var map := get_tree().get_first_node_in_group("hometown")
		_pave = PaveLift.of(map) if map and OS.get_environment("MC_PAVE_OFF") == "" else false
	if not _pave or chibi == null or riding():
		return
	var want := 0.0
	if water == 0 and not sitting:
		var t: float = _pave.top(global_position)
		if t > global_position.y:
			want = minf(t - global_position.y, 0.3)
	var y := chibi.position.y
	if absf(want - y) > 0.25:
		y = want
	else:
		y = lerpf(y, want, 1.0 - exp(-delta * 18.0))
	chibi.position.y = y

func busy() -> bool:
	"""Swinging a tool or getting up off the ground: no walking until the clip is over. (The rod's two holds,
	waiting for a bite and showing the catch, are loops the player strikes / walks out of: not busy.)"""
	var c: String = chibi.anim.current_animation if chibi.anim != null else ""
	return (c.begins_with("Tool_") and c not in ["Tool_Rod_Aim", "Tool_Rod_GetKeep"]) or c == "Wait_SitUp"

func _physics_process(delta: float) -> void:
	_pave_feet(delta)
	if remote:
		_follow_state(delta)
		return
	Net.send_state(position, facing, chibi._base_clip, chibi.anim.speed_scale if chibi.anim else 1.0, delta)
	if vehicle != null and vehicle.riding():
		vehicle.drive(self, delta, _input_dir())
		return
	if busy():
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var inp := _input_dir()
	if steer != Vector3.ZERO and inp.length() > 0.1 and auto_move == Vector2.ZERO:
		stop_going()
	if inp.length() > 0.1 or steer != Vector3.ZERO:
		if _big == "doze":
			_poke()
		if sitting:
			stand_up()
			if busy():
				velocity = Vector3.ZERO
				move_and_slide()
				return
	var running := Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER) \
		or TouchControls.run
	var speed := (RUN if running else WALK) * inp.length() * pace

	var fwd := -cam.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var dir := (right * inp.x - fwd * inp.y)
	if steer != Vector3.ZERO:
		dir = steer
		running = steer_run
		speed = (RUN if running else WALK) * steer.length() * pace
		sitting = false
	_water_check(Vector2(velocity.x, velocity.z).length())
	if dive != "":
		_dive_step(delta)
	if water == 2 and dive == "Swim_Under":
		speed = (UNDER * (1.45 if running else 1.0)) * minf(maxf(inp.length(), steer.length()), 1.0) * pace
	elif water == 2 and dive != "":
		speed = 0.0
	elif water == 2:
		speed = (SWIM * (1.55 if running else 1.0)) * minf(maxf(inp.length(), steer.length()), 1.0) * pace
	elif water == 1:
		speed *= lerpf(1.0, 0.5, smoothstep(WADE_IN, SWIM_IN, water_d))
	if dir.length() > 0.01:
		dir = dir.normalized()
		facing = lerp_angle(facing, atan2(dir.x, dir.z), 1.0 - exp(-delta * 12.0))
		rotation.y = facing
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	if water == 2:

		velocity.y = (water_y + Swell.lift(position.x, position.z, water_d) - position.y) * 8.0
	move_and_slide()

	if bounds_box > 0.0:
		position.x = clampf(position.x, -bounds_box, bounds_box)
		position.z = clampf(position.z, -bounds_box, bounds_box)
	else:
		var flat := Vector2(position.x, position.z)
		if flat.length() > 18.6:
			flat = flat.normalized() * 18.6
			position.x = flat.x
			position.z = flat.y
	if water == 2 and chibi.anim:
		if dive == "":
			chibi.play("Move_Swim" if speed > 0.1 else "Swim_Idle", 0.25)
			_loop_clip(chibi.anim.current_animation)
			chibi.anim.speed_scale = speed / SWIM_CLIP_SPEED * 0.55 if speed > 0.1 else 1.0
		elif dive == "Swim_Under":
			chibi.anim.speed_scale = maxf(speed / UNDER, 0.45)
	elif not sitting and chibi.anim:
		if chibi.anim.current_animation in ["Move_Swim", "Swim_Idle"] and speed <= 0.1:
			chibi.play("Base_Wait", 0.25)
			chibi.anim.speed_scale = 1.0
		if speed > 0.1:
			var clip := "Move_Run" if running else "Move_Walk"
			chibi.play(clip, 0.15)
			chibi.anim.speed_scale = speed / (RUN_CLIP_SPEED if running else WALK_CLIP_SPEED) * 0.55
		elif chibi.anim.current_animation in ["Move_Walk", "Move_Run"]:
			chibi.play("Base_Wait", 0.2)
			chibi.anim.speed_scale = 1.0
	_gestures(delta, speed)

func _poke() -> void:
	"""Any input: the idle count starts over and a dozing hero wakes with a start (sitting stays until a
	move or C)."""
	_idle = 0.0
	_smalls = 0
	if _big == "doze":
		_big = ""
		chibi.play("Base_Wait", 0.3)
		Net.act("emote", "surprised")

func _gestures(delta: float, speed: float) -> void:
	"""Idle gestures (SMALL_AT, BIG_AT): count the seconds standing in plain Base_Wait or in a gesture of our
	own; walking, sitting by choice, a menu, a tool swing or any other clip starts the count over."""
	if (_big == "sit" and not sitting) or (_big == "doze" and chibi._base_clip != "Wait_Doze"):
		_big = ""
	if _big == "doze":
		_z -= delta
		if _z <= 0.0:
			_z = DOZE_Z
			Net.act("fx", "z")
	if _big != "":
		return
	var now: String = chibi.anim.current_animation if chibi.anim else ""
	if not gestures or water != 0 or speed > 0.1 or sitting or not controls or busy() or (now != "Base_Wait" and now != _mine):
		_idle = 0.0
		_smalls = 0
		return
	_idle += delta
	if now != "Base_Wait":
		return
	if _idle >= BIG_AT:
		_big_gesture()
	elif _idle >= SMALL_AT * (_smalls + 1):
		_smalls += 1
		_small_gesture()

func _small_gesture() -> void:
	var pool: Array = (TOOL_GESTURES if chibi.tool != "" else SMALL_GESTURES).filter(func(g): return g != _last_small)
	var g: String = pool.pick_random()
	_last_small = g
	if g.begins_with("emote:"):
		_mine = str(Chibi.emotes.get(g.trim_prefix("emote:"), {}).get("clip", ""))
		Net.act("emote", g.trim_prefix("emote:"))
	elif chibi.anim.has_animation(g):
		_mine = g
		Net.act("clip", g)

func _big_gesture() -> void:
	"""Sit down on the ground for a while, or nod off standing up (always that with a tool in hand)."""
	if chibi.tool == "" and randf() < 0.6 and chibi.anim.has_animation("Wait_SitDown"):
		_big = "sit"
		toggle_sit()
	elif chibi.anim.has_animation("Wait_Doze"):
		_big = "doze"
		_z = 2.5
		Net.act("clip", "Emo_Sleepy>Wait_Doze")

func _water_check(moving: float) -> void:
	var w := Water.at(global_position.x, global_position.z)
	water_y = w.x
	water_d = w.y
	var was := water
	if water_d > SWIM_IN or (water == 2 and water_d > SWIM_OUT):
		water = 2
	elif water_d > WADE_IN:
		water = 1
	else:
		water = 0
	if water == 2 and sitting:
		sitting = false
	if water != 2 and dive != "":
		dive = ""
	if water != 0 and _wfx == null:
		_wfx = SwimFX.attach(self, 1.0, water_y)
		_wfx.bubble_from = SwimFX.head_of(self)
	if _wfx == null:
		return
	_wfx.mode = SwimFX.OFF if water == 0 else (SwimFX.UNDER if _under() else SwimFX.SURFACE)
	if water != 0:
		_wfx.water_y = water_y
		_wfx.size = 1.0 if water == 2 else lerpf(0.4, 0.8, smoothstep(WADE_IN, SWIM_IN, water_d))
	var fast := moving > 2.4
	if water == 2 and was != 2:
		_wfx.splash(0.8 if fast else 0.45)
	elif water == 1 and was == 0 and fast:
		_wfx.splash(0.35)

func toggle_dive() -> void:
	if dive == "" and water == 2 and water_d > DIVE_IN:
		_dive_to("Swim_Dive")
	elif dive == "Swim_Under":
		_dive_to("Swim_Surface")

func _dive_to(stage: String) -> void:
	dive = stage
	_dive_t = 0.0
	chibi.play(stage, 0.1 if stage == "Swim_Under" else 0.2)
	chibi.anim.speed_scale = 1.0
	_loop_clip("Swim_Under")

func _dive_step(delta: float) -> void:
	_dive_fx(delta)
	var n := chibi.anim.get_animation(dive).length if chibi.anim.has_animation(dive) else 1.0
	if dive == "Swim_Dive" and _dive_t >= n:
		_dive_to("Swim_Under")
	elif dive == "Swim_Under" and (_dive_t >= DIVE_MAX or water_d < DIVE_OUT):
		_dive_to("Swim_Surface")
	elif dive == "Swim_Surface" and _dive_t >= n:
		dive = ""

func _dive_fx(delta: float) -> void:
	var t0 := _dive_t
	_dive_t += delta
	if _wfx == null:
		return
	for e: Array in [["Swim_Dive", "under", 1.0], ["Swim_Dive", "feet_out", 0.5], ["Swim_Surface", "out", 0.9]]:
		var at := _swim_at(e[0], e[1])
		if dive == e[0] and t0 < at and _dive_t >= at:
			_wfx.splash(e[2])

func _under() -> bool:
	match dive:
		"Swim_Dive":
			return _dive_t >= _swim_at("Swim_Dive", "under")
		"Swim_Under":
			return true
		"Swim_Surface":
			return _dive_t < _swim_at("Swim_Surface", "out")
	return false

static func _swim_at(clip: String, key: String) -> float:
	if _swim_ev.is_empty():
		var ev: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tool_clips.json")).get("_events", {})
		for c in ["Swim_Dive", "Swim_Surface"]:
			for k in ev.get(c, {}):
				var v = ev[c][k]
				_swim_ev[c + "/" + k] = float(v[0] if v is Array else v) / 30.0
	return _swim_ev.get(clip + "/" + key, 0.0)

func _loop_clip(n: String) -> void:
	if n != "" and chibi.anim.has_animation(n) and chibi.anim.get_animation(n).loop_mode == Animation.LOOP_NONE:
		chibi.anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR

func _follow_state(delta: float) -> void:
	"""A remote avatar glides to its owner's latest packet (15 a second) and plays the same base clip."""
	var st: Dictionary = Net.states.get(peer_id, {})
	if st.is_empty():
		return
	var to: Vector3 = st["pos"]
	if position.distance_to(to) > 3.0:
		position = to
	position = position.lerp(to, 1.0 - exp(-delta * 12.0))
	facing = lerp_angle(facing, st["yaw"], 1.0 - exp(-delta * 12.0))
	rotation.y = facing
	if st["clip"] != _clip:
		_clip = st["clip"]
		if chibi.anim.get_queue().has(_clip):
			chibi._base_clip = _clip
		else:
			chibi.play(_clip, 0.2)
			chibi.anim.speed_scale = 1.0
			if _clip in ["Move_Swim", "Swim_Idle", "Swim_Under"]:
				_loop_clip(_clip)
		if _clip in ["Swim_Dive", "Swim_Under", "Swim_Surface"]:
			if _clip != dive:
				dive = _clip
				_dive_t = 0.0
		else:
			dive = ""
	if _clip in ["Move_Walk", "Move_Run", "Move_Swim", "Swim_Under"]:
		chibi.anim.speed_scale = st["speed"]

	var moved := 0.0
	if _was_at != Vector3.INF and delta > 0.0:
		moved = Vector2(position.x - _was_at.x, position.z - _was_at.z).length() / delta
	_was_at = position
	_water_check(moved)
	if dive != "":
		_dive_fx(delta)
