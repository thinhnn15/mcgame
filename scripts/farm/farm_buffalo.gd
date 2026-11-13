class_name FarmBuffalo
extends Node3D

const CFG := "res://data/farm/trau.json"
const STALL := Vector3(20.5, 0, -6.6)
const SHED_ZONE := Rect2(17.6, -9.4, 6.4, 5.8)
const SHADE := Vector3(29.4, 0, -10.6)
const NEAR := 1.45
const SEAT := Vector3(0.17, 0.60, -0.04)
const NOSE := Vector3(0.0, 0.74, 0.98)
const HAND := Vector3(-0.2, 0.52, 0.14)
const BODY := Vector3(0.86, 0.9, 1.75)
const BODY_Z := 0.08
const ROPE_COL := Color("8a6a45")
const MOUNT_S := 0.55

var plot: Node3D
var cfg := {}
var slow := {}
var a: FarmAnimal
var state := "chuong"
var spot := Vector3.ZERO
var log := {}
var day := -1
var lying := false
var hero: Player
var _have := false
var _yaw := 0.0
var _speed := 0.0
var _moving := false
var _trail := PackedVector3Array()
var _goal := Vector3.INF
var _wait := 0.0
var _n := 0
var _body: AnimatableBody3D
var _box: CollisionShape3D
var _rope: MeshInstance3D
var _im: ImmediateMesh
var _pace := 1.0
var _chibi_xf := Transform3D()
var _busy_t := 0.0
var _sat := false
var _sit_t := 0.0
var _bob := 0.0
var _said := -1

static func is_here() -> bool:
	return OS.get_cmdline_user_args().has("--trau") or bool(Story.flag("trau_muc_ve", false)) or Clock.chapter() >= 2

static func add(p: Node3D) -> FarmBuffalo:
	var t := FarmBuffalo.new()
	t.name = "FarmBuffalo"
	t.plot = p
	p.add_child(t)
	return t

func _ready() -> void:
	var c = JSON.parse_string(FileAccess.get_file_as_string(CFG))
	cfg = c if c is Dictionary else {}
	slow = cfg.duplicate()
	slow["follow_max"] = float(cfg.get("walk", 0.3))
	slow["start"] = 0.2
	_have = ClassDB.class_exists("Buffalo")
	if not is_here():
		return
	a = FarmAnimal.spawn(self, "trau", _ground(STALL), 0.0)
	_body = AnimatableBody3D.new()
	_body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = BODY
	cs.shape = bx
	cs.position = Vector3(0, BODY.y * 0.5 + 0.1, BODY_Z)
	_body.add_child(cs)
	add_child(_body)
	_im = ImmediateMesh.new()
	_rope = MeshInstance3D.new()
	_rope.mesh = _im
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = ROPE_COL
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rope.material_override = m
	_rope.visible = false
	add_child(_rope)
	TouchControls.add_action(self, _touch, 45)
	_new_day()

func to_dict() -> Dictionary:
	if a == null:
		return {}
	var p := a.global_position
	var st := state if state in ["chuong", "tha"] else "tha"
	return {"state": st, "at": [p.x, p.z, _yaw], "spot": [spot.x, spot.z], "log": log, "day": day}

func from_dict(d: Dictionary) -> void:
	if a == null or d.is_empty():
		return
	log = d.get("log", {})
	if int(d.get("day", -1)) != Clock.day:
		_new_day()
		return
	day = Clock.day
	state = str(d.get("state", "chuong"))
	var at: Array = d.get("at", [STALL.x, STALL.z, 0.0])
	_yaw = float(at[2])
	_place(Vector3(float(at[0]), 0, float(at[1])))
	var s: Array = d.get("spot", [at[0], at[1]])
	spot = _ground(Vector3(float(s[0]), 0, float(s[1])))
	_goal = Vector3.INF
	a.play("Graze" if state == "tha" else "Idle")

func _new_day() -> void:
	day = Clock.day
	if state == "cuoi" and hero:
		_force_off()
	if state == "dat":
		_drop_rope()
	state = "chuong"
	_yaw = 0.0
	_place(STALL)
	_goal = Vector3.INF
	lying = _hour() < float(cfg.get("out_from", 5.0)) or _hour() >= 20.0
	a.play("Lie_Keep" if lying else "Idle")

func _hour() -> float:
	return Clock.minute / 60.0

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, plot.scenery.walk_at(p.x, p.z), p.z)

func _place(p: Vector3) -> void:
	a.global_position = _ground(p)
	a.rotation.y = _yaw
	_body.global_transform = Transform3D(Basis(Vector3.UP, _yaw), a.global_position)

func _xf() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, _yaw), a.global_position)

func _spine_dist(p: Vector3) -> float:
	var x := _xf()
	var r := x * Vector3(0, 0, -0.7)
	var n := x * Vector3(0, 0, 0.85)
	var q := Geometry3D.get_closest_point_to_segment(Vector3(p.x, 0, p.z), Vector3(r.x, 0, r.z), Vector3(n.x, 0, n.z))
	return q.distance_to(Vector3(p.x, 0, p.z))

func _near(p: Player) -> bool:
	return a != null and _have and p.controls and not plot._busy and p.water == 0 and _spine_dist(p.global_position) < NEAR \
		and (p.vehicle == null or p.vehicle == self)

func _on_hill(p: Vector3) -> bool:
	return FarmFields.GRASS_HILL.has_point(Vector2(p.x, p.z))

func _credit(act: String) -> void:
	var pts: int = ClassDB.class_call_static("Buffalo", "credit", log, act, Clock.day, cfg)
	if pts <= 0:
		return
	Progress.friend("trau_muc", pts)
	var xp: String = cfg.get("xp", {}).get(act, "")
	if xp != "":
		plot._xp(xp)
	plot._puff(a.global_position + Vector3(0, 1.3, 0.3), Color("ff8fa3"), 6)

func _play(clip: String, scale := 1.0) -> void:
	if a.anim.current_animation != clip and a._loop != clip:
		a.play(clip)
	a.anim.speed_scale = scale

func _say(key: String, secs := 2.6) -> void:
	plot.hud.toast(tr(key), secs)

func _unhandled_input(e: InputEvent) -> void:
	if a == null or not _have:
		return
	var f: bool = (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_F, KEY_SPACE]) \
		or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_A)
	if not f:
		return
	var p: Player = plot.player
	if state == "cuoi" and hero == p:
		use(p)
		get_viewport().set_input_as_handled()
	elif _near(p) and not (state == "chuong" and lying):
		_rope_key(p)
		get_viewport().set_input_as_handled()

func _rope_key(p: Player) -> void:
	if state == "dat":
		_let_go()
	elif state != "cuoi":
		_take_rope(p)

func _touch() -> Dictionary:
	if a == null or not _have:
		return {}
	var p: Player = plot.player
	if state == "cuoi" and hero == p:
		return {"label": tr("TRAU_TC_OFF"), "run": use.bind(p)}
	if not _near(p) or (state == "chuong" and lying):
		return {}
	return {"label": tr("TRAU_TC_LET_GO" if state == "dat" else "TRAU_TC_LEAD"), "run": _rope_key.bind(p)}

func hint_at(at: Vector3) -> String:
	if a == null or not _have:
		return ""
	var p: Player = plot.player
	if state == "cuoi" and hero == p:
		return "TRAU_HINT_RIDE"
	if state == "dat":
		return "TRAU_HINT_LEAD"
	if _spine_dist(at) >= NEAR:
		return ""
	return "TRAU_HINT_LIE" if lying else "TRAU_HINT"

func _take_rope(p: Player) -> void:
	hero = p
	state = "dat"
	_trail = PackedVector3Array([a.global_position, p.global_position])
	_moving = false
	_pace = p.pace
	if plot.tool_i >= 0:
		plot._stow()
	p.pace = float(cfg.get("lead_pace", 0.55))
	_rope.visible = true
	_goal = Vector3.INF
	if lying:
		lying = false
		a.play("Stand_Up")
	_credit("vuot_ve")
	Sound.play_at("bag.put", a.global_position + Vector3(0, 0.8, 0))

func _drop_rope() -> void:
	if hero:
		hero.pace = _pace
	_rope.visible = false
	_im.clear_surfaces()

func _let_go() -> void:
	_drop_rope()
	var p := a.global_position
	var h := _hour()
	_goal = Vector3.INF
	_wait = 2.0
	var hp: Vector3 = hero.global_position if hero else p
	if SHED_ZONE.has_point(Vector2(p.x, p.z)) or SHED_ZONE.has_point(Vector2(hp.x, hp.z)):
		state = "chuong"
		if h >= 15.0:
			_credit("ve_chuong")
			_say("TRAU_T_HOME")
	else:
		state = "tha"
		spot = p
		if _on_hill(p) and h < 11.0:
			_credit("len_doi")
			_say("TRAU_T_HILL")
	hero = null
	_play("Idle")

func _lead(delta: float) -> void:
	var p := hero
	if p == null or not is_instance_valid(p):
		_let_go()
		return
	var hp := p.global_position
	if _trail.is_empty() or Vector2(hp.x - _trail[-1].x, hp.z - _trail[-1].z).length() > 0.2:
		_trail.append(hp)
		if _trail.size() > 160:
			_trail = _trail.slice(_trail.size() - 120)
	if a.anim.current_animation == "Stand_Up":
		return
	var goal: Vector3 = ClassDB.class_call_static("Buffalo", "rope_point", _trail, float(cfg.get("rope", 1.9)))
	var w := Water.at(goal.x, goal.z)
	var deep := w.y > 0.3
	var r: Dictionary = ClassDB.class_call_static("Buffalo", "seek", a.global_position, _yaw,
		a.global_position if deep else goal, _moving, delta, cfg)
	_step_to(r)

	var d := Vector3(hp.x - a.global_position.x, 0, hp.z - a.global_position.z)
	var most := float(cfg.get("rope_max", 4.2))
	if d.length() > most:
		var to := a.global_position + d.normalized() * most
		p.global_position = Vector3(to.x, hp.y, to.z)

func _step_to(r: Dictionary) -> void:
	_moving = r.moving
	_speed = r.speed
	_yaw = r.yaw
	_place(r.pos)
	if _speed > 0.03:
		_play("Walk", clampf(_speed / float(cfg.get("walk", 0.3)), 0.7, 3.2))
	elif a.anim.current_animation == "Walk":
		_play("Idle")

func _draw_rope() -> void:
	if not _rope.visible or hero == null:
		return
	var from := _xf() * NOSE
	var to := hero.global_transform * HAND
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var span := from.distance_to(to)
	var sag := maxf(0.0, float(cfg.get("rope", 1.9)) * 1.25 - span) * 0.35 + 0.04
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := 12
	for i in n + 1:
		var t := float(i) / n
		var q := from.lerp(to, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var side := (cam.global_position - q).cross(to - from).normalized() * 0.014
		_im.surface_add_vertex(q - side)
		_im.surface_add_vertex(q + side)
	_im.surface_end()

func _out(delta: float) -> void:
	var plan: String = ClassDB.class_call_static("Buffalo", "plan", _hour(), "tha", _on_hill(spot), plot.raining, cfg)
	match plan:
		"home":
			_home_alone()
		"shade":
			if lying:
				_sit_with(delta)
				return
			if _walk_to(SHADE, delta):
				lying = true
				_yaw = lerp_angle(_yaw, deg_to_rad(200.0), 1.0)
				_place(a.global_position)
				a.play("Lie_Start")
		_:
			if lying:
				lying = false
				a.play("Stand_Up")
				_wait = 3.0
				return
			_graze(delta)

func _walk_to(goal: Vector3, delta: float) -> bool:
	var r: Dictionary = ClassDB.class_call_static("Buffalo", "seek", a.global_position, _yaw, _ground(goal), _goal != Vector3.INF, delta, slow)
	_goal = goal if r.moving else Vector3.INF
	_step_to(r)
	return not r.moving

func _graze(delta: float) -> void:
	if a.anim.current_animation in ["Stand_Up", "Lie_Start"]:
		return
	if _goal == Vector3.INF:
		_wait -= delta
		if a.anim.current_animation != "Graze":
			_play("Graze")
		if _wait > 0.0:
			return
		_n += 1
		var g: Vector3 = ClassDB.class_call_static("Buffalo", "graze_spot", spot, float(cfg.get("graze_r", 2.6)), Clock.day * 97 + _n)
		if not _clear(a.global_position, g) or Water.at(g.x, g.z).y > 0.05:
			_wait = 1.0
			return
		_goal = g
	if _walk_to(_goal, delta):
		_goal = Vector3.INF
		var e: Array = cfg.get("graze_every", [6.0, 12.0])
		_wait = randf_range(float(e[0]), float(e[1]))
		_play("Graze")

func _clear(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.6, 0), _ground(to) + Vector3(0, 0.6, 0))
	q.exclude = [_body.get_rid()]
	var tip := (to - from).normalized() * 1.0
	q.to += Vector3(tip.x, 0, tip.z)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _home_alone() -> void:
	plot._puff(a.global_position + Vector3(0, 0.6, 0), Color("efe6d6"), 8)
	state = "chuong"
	lying = false
	_yaw = 0.0
	_place(STALL)
	_goal = Vector3.INF
	_play("Idle")
	if _said != Clock.day and plot.player.global_position.distance_to(STALL) < 30.0:
		_said = Clock.day
		_say("TRAU_T_SELF_HOME")

func _sit_with(delta: float) -> void:
	var p: Player = plot.player
	if p.sitting and _spine_dist(p.global_position) < 2.2:
		_sit_t += delta
		if _sit_t >= float(cfg.get("sit_for", 12.0)):
			_sit_t = -INF
			var first := not Progress.moments().has("ngoi_canh_trau")
			_credit("ngoi_canh")
			Progress.rest("sat_still_or_nap")
			if first:
				Progress.moment("ngoi_canh_trau")
			_say("TRAU_T_SIT", 3.2)
	elif not p.sitting:
		_sit_t = 0.0

func _in_shed(delta: float) -> void:
	if a.global_position.distance_to(_ground(STALL)) > 0.2:
		if _walk_to(STALL, delta):
			_yaw = 0.0
			_play("Idle")
		return
	_yaw = lerp_angle(_yaw, 0.0, 1.0 - exp(-delta * 2.0))
	_place(a.global_position)
	var night := _hour() >= 20.0 or _hour() < float(cfg.get("out_from", 5.0))
	if night and not lying:
		lying = true
		a.play("Lie_Start")
	elif not night and lying and _hour() < 20.0 and _hour() >= 6.0:
		lying = false
		a.play("Stand_Up")

func riding() -> bool:
	return state == "cuoi"

func use(p: Player) -> bool:
	if state != "cuoi":
		return false
	if _busy_t <= 0.0:
		_get_off()
	return true

func _get_on(p: Player) -> void:
	if state == "dat":
		_drop_rope()
	if lying:
		return
	hero = p
	state = "cuoi"
	p.sitting = false
	p.stop_going()
	if plot.tool_i >= 0:
		plot._stow()
	_body.get_child(0).disabled = true
	_speed = 0.0
	_play("Idle")
	var was := p.chibi.global_transform
	_chibi_xf = p.chibi.transform
	_chibi_xf.origin.y = 0.0
	p.vehicle = self
	p.global_position = a.global_position
	p.rotation.y = _yaw
	p.facing = _yaw
	p.velocity = Vector3.ZERO
	_box = CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = BODY - Vector3(0, 0.2, 0)
	_box.shape = bx
	_box.position = Vector3(0, 0.6, BODY_Z)
	p.add_child(_box)
	var from := p.global_transform.affine_inverse() * was
	var seat := Transform3D(Basis(Vector3.UP, PI / 2), SEAT)
	p.chibi.play("Act_SitChair_Idle", 0.3)
	_busy_t = MOUNT_S
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if hero:
			var x := from.interpolate_with(seat, t)
			x.origin.y += sin(t * PI) * 0.35
			hero.chibi.transform = x, 0.0, 1.0, MOUNT_S)
	var first := not Progress.moments().has("cuoi_trau")
	_credit("cuoi")
	if first:
		Progress.moment("cuoi_trau")
		_say("TRAU_T_RIDE_FIRST", 3.2)

func _get_off() -> void:
	var p := hero
	var x := _xf()
	var to := Vector3.INF
	for side: Vector3 in [Vector3(1.0, 0, 0), Vector3(-1.0, 0, 0), Vector3(0, 0, -1.4), Vector3(0, 0, 1.5)]:
		var c := x * side
		if _clear(a.global_position, c - (c - a.global_position).normalized()) and Water.at(c.x, c.z).y <= 0.05:
			to = _ground(c)
			break
	if to == Vector3.INF:
		_say("TRAU_T_NO_ROOM")
		return
	_speed = 0.0
	_busy_t = MOUNT_S
	_play("Idle")
	var from := p.chibi.transform
	var end := Transform3D(Basis(Vector3.UP, PI / 2), p.global_transform.affine_inverse() * to)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var q := from.interpolate_with(end, t)
		q.origin.y += sin(t * PI) * 0.3
		p.chibi.transform = q, 0.0, 1.0, MOUNT_S)
	tw.tween_callback(_landed.bind(p, to))
	p.chibi.play("Base_Wait", 0.35)

func _landed(p: Player, to: Vector3) -> void:
	p.global_position = to
	p.rotation.y = _yaw + PI / 2
	p.facing = p.rotation.y
	_unseat(p)

func _unseat(p: Player) -> void:
	p.chibi.transform = _chibi_xf
	p.vehicle = null
	p.sitting = false
	if _box:
		_box.queue_free()
		_box = null
	_body.get_child(0).disabled = false
	hero = null
	var at := a.global_position
	if SHED_ZONE.has_point(Vector2(at.x, at.z)):
		state = "chuong"
	else:
		state = "tha"
		spot = at
	_goal = Vector3.INF
	_wait = 3.0

func _force_off() -> void:
	var p := hero
	if p == null:
		return
	p.chibi.play("Base_Wait", 0.1)
	p.global_position = _ground(_xf() * Vector3(1.0, 0, 0))
	_unseat(p)

func drive(p: Player, delta: float, inp: Vector2) -> void:
	if _busy_t > 0.0 or not _have:
		p.velocity = Vector3.ZERO
		p.move_and_slide()
		return
	var cb := p.cam.global_transform.basis
	var fwd := Vector3(-cb.z.x, 0, -cb.z.z).normalized()
	var right := Vector3(cb.x.x, 0, cb.x.z).normalized()
	var dir := right * inp.x - fwd * inp.y
	var r: Dictionary = ClassDB.class_call_static("Buffalo", "ride", _yaw, _speed, dir, delta, cfg)
	var v: Vector3 = r.velocity
	var before := p.global_position
	_yaw = r.yaw
	_speed = r.speed
	p.rotation.y = _yaw
	p.facing = _yaw
	p.velocity = Vector3(v.x, 0.0 if p.is_on_floor() else p.velocity.y - 9.8 * delta, v.z)
	p.move_and_slide()
	if p.bounds_box > 0.0:
		p.position.x = clampf(p.position.x, -p.bounds_box, p.bounds_box)
		p.position.z = clampf(p.position.z, -p.bounds_box, p.bounds_box)
	var nose := p.global_position + Vector3(sin(_yaw), 0, cos(_yaw)) * 0.95
	if Water.at(nose.x, nose.z).y > 0.3:
		p.global_position = before
		_speed = 0.0
	elif _speed > 0.2 and p.get_real_velocity().length() < _speed * 0.3:
		_speed *= 0.5

func _ride_step(delta: float) -> void:
	var p := hero
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		state = "tha"
		return
	if not p.controls and _busy_t <= 0.0:
		_force_off()
		return
	if p.sitting and _busy_t <= 0.0:
		p.sitting = false
		_get_off()
	a.global_position = p.global_position
	a.rotation.y = _yaw
	_body.global_transform = _xf()
	if _speed > 0.03:
		_play("Walk", clampf(_speed / float(cfg.get("walk", 0.3)), 0.7, 3.2))
		_bob += delta * _speed * 9.0
	elif a.anim.current_animation == "Walk":
		_play("Idle")
	if _busy_t <= 0.0:
		var seat := Transform3D(Basis(Vector3.UP, PI / 2), SEAT)
		seat.origin.y += absf(sin(_bob)) * 0.025 * minf(1.0, _speed * 3.0)
		p.chibi.transform = seat

func _process(delta: float) -> void:
	if a == null:
		return
	if Clock.day != day:
		_new_day()
	_busy_t -= delta
	var p: Player = plot.player

	var sat := p.sitting
	if sat and not _sat and _have and state in ["tha", "dat"] and not lying and p.vehicle == null \
			and _spine_dist(p.global_position) < NEAR and p.controls and not plot._busy:
		_get_on(p)
	_sat = p.sitting
	if not _have:
		return
	match state:
		"dat": _lead(delta)
		"cuoi": _ride_step(delta)
		"tha": _out(delta)
		"chuong": _in_shed(delta)
	_draw_rope()
