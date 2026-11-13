class_name OrbitCam
extends Camera3D

const PITCH_MIN := deg_to_rad(3.0)
const PITCH_MAX := deg_to_rad(72.0)
const DIST_MIN := 2.5
const DIST_MAX := 40.0
const NEAR_OK := 2.6
const MOUSE_TURN := 0.0055
const STICK_TURN := 2.2
const KEY_TURN := 1.7
const TOUCH_TURN := 0.008
const WHEEL_TILT := deg_to_rad(4.0)
const RADIUS := 0.2

var target: Node3D
var yaw := 0.0
var pitch := deg_to_rad(21.0)
var dist := 7.0
var height := 1.0
var collision_mask := 1
var pad := 0
var turn_keys := [KEY_Q, KEY_E]
var _home := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _dist := 0.0
var _lift := 0.0
var _reach := 0.0
var _buttons := 0
var _look := Vector3.ZERO

func follow(node: Node3D, start_yaw := 0.0) -> void:
	target = node
	yaw = start_yaw
	_home = Vector3(yaw, pitch, dist)
	_yaw = yaw
	_pitch = pitch
	_dist = dist
	_reach = dist
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	make_current()
	_place(0.0)

func reset_view() -> void:
	yaw = _home.x
	pitch = _home.y
	dist = _home.z

func touch_turn(d: Vector2) -> void:
	yaw -= d.x * TOUCH_TURN
	pitch = clampf(pitch + d.y * TOUCH_TURN * 0.7, PITCH_MIN, PITCH_MAX)

func look_point() -> Vector3:
	return _look

func _set_drag(button: int, down: bool) -> void:
	if down:
		_buttons |= 1 << button
	else:
		_buttons &= ~(1 << button)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _buttons else Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT] and _buttons:
		_buttons = 0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(e: InputEvent) -> void:

	if e is InputEventKey and e.physical_keycode in turn_keys:
		get_viewport().set_input_as_handled()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_set_drag(e.button_index, e.pressed)
		elif e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var up: bool = e.button_index == MOUSE_BUTTON_WHEEL_UP
			if e.ctrl_pressed:
				dist = maxf(DIST_MIN, dist * 0.9) if up else minf(DIST_MAX, dist / 0.9)
			else:
				pitch = clampf(pitch + (WHEEL_TILT if up else -WHEEL_TILT), PITCH_MIN, PITCH_MAX)
	elif e is InputEventMouseMotion and _buttons:
		var m: Vector2 = e.screen_relative if e.screen_relative != Vector2.ZERO else e.relative
		yaw -= m.x * MOUSE_TURN
		pitch = clampf(pitch + m.y * MOUSE_TURN * 0.7, PITCH_MIN, PITCH_MAX)
	elif e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_R:
		reset_view()
	elif e is InputEventJoypadButton and e.device == pad and e.pressed and e.button_index == JOY_BUTTON_RIGHT_STICK:
		reset_view()

func _process(delta: float) -> void:
	if target == null:
		return
	var sx := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X)
	var sy := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)
	if absf(sx) > 0.2:
		yaw -= sx * STICK_TURN * delta
	if absf(sy) > 0.2:
		pitch = clampf(pitch + sy * STICK_TURN * 0.6 * delta, PITCH_MIN, PITCH_MAX)
	if turn_keys.size() == 2 and not (get_viewport().gui_get_focus_owner() is LineEdit):
		if Input.is_physical_key_pressed(turn_keys[0]):
			yaw += KEY_TURN * delta
		if Input.is_physical_key_pressed(turn_keys[1]):
			yaw -= KEY_TURN * delta
	var k := 1.0 - exp(-delta * 10.0)
	_yaw = lerp_angle(_yaw, yaw, k)
	_pitch = lerpf(_pitch, pitch, k)
	_dist = lerpf(_dist, dist, k)
	_place(delta)

func _spot() -> Vector3:
	if target.is_physics_interpolated_and_enabled():
		return target.get_global_transform_interpolated().origin
	return target.global_position

func _offset(p: float, d: float) -> Vector3:
	return Vector3(sin(_yaw) * cos(p), sin(p), cos(_yaw) * cos(p)) * d

func _clear(look: Vector3, dir: Vector3, d: float) -> float:
	if not is_inside_tree() or d <= 0.0:
		return d
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = RADIUS
	q.shape = sph
	q.transform = Transform3D(Basis(), look)
	q.motion = dir * d
	q.collision_mask = collision_mask
	if target is CollisionObject3D:
		q.exclude = [(target as CollisionObject3D).get_rid()]
	var r := get_world_3d().direct_space_state.cast_motion(q)
	return d * r[0]

func _place(delta: float) -> void:
	var feet := _spot()
	var look0 := feet + Vector3(0, height, 0)

	var want_lift := 0.0
	var reach := _dist
	var p := _pitch
	while true:
		var c := _clear(look0, _offset(p, 1.0), _dist)
		if c >= minf(_dist, NEAR_OK) or p >= PITCH_MAX:
			want_lift = p - _pitch
			reach = c
			break
		p = minf(PITCH_MAX, p + deg_to_rad(6.0))
	var kl := 1.0 - exp(-delta * 8.0) if delta > 0.0 else 1.0
	_lift = lerpf(_lift, want_lift, kl)
	var pe := minf(PITCH_MAX, _pitch + _lift)
	reach = minf(reach, _clear(look0, _offset(pe, 1.0), _dist))
	if delta <= 0.0:
		_reach = reach
	else:
		_reach = lerpf(_reach, reach, 1.0 - exp(-delta * (14.0 if reach < _reach else 2.5)))

	var low := (1.0 - clampf((pe - PITCH_MIN) / deg_to_rad(25.0), 0.0, 1.0)) * clampf((_reach - 1.5) / 3.0, 0.0, 1.0)
	_look = look0 + Vector3(0, low * 0.5, 0)
	global_position = _look + _offset(pe, _reach * (1.0 - low * 0.25))
	look_at(_look + Vector3(0, low * 0.8, 0), Vector3.UP)
