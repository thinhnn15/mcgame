class_name FarmTouch
extends Node

const TAME := 3
const HAND := Vector2(0.25, 0.35)
const REACH_F := 19
const STROKE := [12, 19]
const STROKE_SECS := 0.32
const PAT_R := 0.42
var vang_lie := 3

var plot
var hen_days := 0
var _hen_day := -1

static func add(p) -> FarmTouch:
	var t := FarmTouch.new()
	t.name = "FarmTouch"
	t.plot = p
	p.add_child(t)
	return t

func hen(x: Dictionary) -> String:
	var a: FarmAnimal = x.a
	if _hen_day != Clock.day:
		_hen_day = Clock.day
		hen_days += 1
	var tame := hen_days > TAME
	x.wait = 6.0
	x.eat = 0.0
	x.goal = a.position
	_face(a, plot.player.global_position)
	a.play("Idle", 0.2)
	if not tame:
		_crouch(a, 0, _shy_hop.bind(x))
		return "FARM_T_PAT_HEN_SHY"
	if a.kind == "ga_trong":
		_crouch(a, 2, _puff_at.bind(a, 0.55), _crow.bind(a))
		return "FARM_T_PAT_HEN"
	_crouch(a, 2, _squat.bind(a), _get_up.bind(x))
	return "FARM_T_PAT_HEN"

func _crow(a: FarmAnimal) -> void:
	if is_instance_valid(a) and a.anim.current_animation == "Idle":
		a.play("Crow")
		Sound.play_at("animal.rooster_crow", a.global_position + Vector3(0, 0.45, 0), -6.0)

func _squat(a: FarmAnimal) -> void:
	if not is_instance_valid(a):
		return
	a.play("Sit_Start", 0.15)
	_puff_at(a, 0.4)
	_after(0.5, func() -> void:
		if is_instance_valid(a):
			Sound.play_at("animal.hen_cluck", a.global_position + Vector3(0, 0.25, 0), -6.0, 0.9))

func _get_up(x: Dictionary) -> void:
	await get_tree().create_timer(0.6).timeout
	var a: FarmAnimal = x.a
	if is_instance_valid(a) and a.anim.current_animation in ["Sit_Keep", "Sit_Start"]:
		a.play("Sit_End", 0.15)
		x.wait = 1.5

func vang(a: FarmAnimal) -> float:
	var me: Vector3 = plot.player.global_position
	var side := atan2(me.x - a.global_position.x, me.z - a.global_position.z) + PI / 2.0
	a.rotation.y = side
	var lie := Progress.hearts("cho_vang") >= vang_lie
	a.play("Wag")
	plot.pets.pat_r = PAT_R
	_crouch(a, 2, _vang_reach.bind(a, lie))
	_after(4.0, _vang_done)
	return 5.5 if lie else 4.0

func _vang_done() -> void:
	plot.pets.pat_r = FarmPets.HERO_R

func _vang_reach(a: FarmAnimal, lie: bool) -> void:
	if not is_instance_valid(a):
		return
	Sound.play_at("animal.dog_huff", a.global_position + Vector3(0, 0.4, 0), -4.0)
	_puff_at(a, 0.6)
	if lie:
		a.play("Lie", 0.2)

func muop(a: FarmAnimal) -> String:
	var hearts := Progress.hearts("meo_muop")
	var snub := randf() < (0.35 if hearts < 2 else (0.15 if hearts < 5 else 0.05))
	var me: Vector3 = plot.player.global_position
	var yaw := atan2(a.global_position.x - me.x, a.global_position.z - me.z)
	plot.player.facing = yaw
	plot.player.rotation.y = yaw
	if snub:
		a.play("Groom", 0.2)
		_after(2.6, func() -> void:
			if is_instance_valid(a) and a._loop == "Groom":
				a.play("Loaf", 0.3))
		return "FARM_T_PAT_MUOP_SNUB"
	a.play("Rub", 0.2)
	Sound.play_at("animal.cat_purr", a.global_position + Vector3(0, 0.2, 0), -6.0)
	_after(2.4, func() -> void:
		if is_instance_valid(a) and a._loop == "Rub":
			a.play("Loaf", 0.3))
	_puff_at(a, 0.35)
	return "FARM_T_PAT_MUOP"

func _crouch(a: FarmAnimal, strokes: int, on_reach := Callable(), on_done := Callable(), reach := 0.0) -> void:
	var p: Player = plot.player
	var ch := p.chibi
	if ch == null or not ch.anim.has_animation("Tool_Egg_Pick"):
		if on_reach.is_valid():
			on_reach.call()
		return
	var spot := _spot(_target(a, reach), p.global_position)
	if Vector2(spot.x - p.global_position.x, spot.z - p.global_position.z).length() > 0.05:
		var how: String = await p.go_to(spot, false, 0.04, 1.5)
		if how == "cancelled" or not is_instance_valid(a):
			return
	var at := _target(a, reach)
	var me := p.global_position
	var yaw := atan2(at.x - me.x, at.z - me.z) - atan2(HAND.x, HAND.y)
	p.facing = yaw
	p.rotation.y = yaw
	var held := ch.tool
	if held != "":
		ch.hold("")
	var name := "Tool_Egg_Pick"
	ch.use_tool(name)
	var waited := 0.0
	while ch.anim.current_animation == name and ch.anim.current_animation_position < REACH_F / 30.0 and waited < 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if on_reach.is_valid():
		on_reach.call()

	var t := 0.0
	while t < strokes * STROKE_SECS * 2.0 and ch.anim.current_animation == name:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := 0.5 - 0.5 * cos(t / STROKE_SECS * PI)
		ch.anim.seek(lerpf(STROKE[1], STROKE[0], k) / 30.0 - get_process_delta_time(), true)
	if ch.anim.current_animation == name:
		ch.anim.play(ch._base_clip, 0.35)
	if held != "" and ch.tool == "":
		ch.hold(held)
	if on_done.is_valid():
		on_done.call()

func _target(a: FarmAnimal, reach: float) -> Vector3:
	var me: Vector3 = plot.player.global_position
	var at := a.global_position
	var d := Vector3(me.x - at.x, 0, me.z - at.z)
	return at + d.normalized() * reach if d.length() > 1e-3 else at

func _spot(at: Vector3, me: Vector3) -> Vector3:
	var yaw := atan2(at.x - me.x, at.z - me.z) - atan2(HAND.x, HAND.y)
	var off := Vector3(HAND.x * cos(yaw) + HAND.y * sin(yaw), 0, -HAND.x * sin(yaw) + HAND.y * cos(yaw))
	return Vector3(at.x - off.x, me.y, at.z - off.z)

func _shy_hop(x: Dictionary) -> void:
	var a: FarmAnimal = x.a
	if not is_instance_valid(a):
		return
	var me: Vector3 = plot.player.global_position
	var away := Vector3(a.position.x - me.x, 0, a.position.z - me.z)
	away = away.normalized() if away.length() > 1e-3 else Vector3(1, 0, 0)
	var to := a.position + away * 0.55
	var y: Rect2 = plot.YARD
	to.x = clampf(to.x, y.position.x + 0.2, y.end.x - 0.2)
	to.z = clampf(to.z, y.position.y + 0.2, y.end.y - 0.2)
	a.play("Flap", 0.08)
	Sound.play_at("animal.wing_flaps", a.global_position + Vector3(0, 0.3, 0), -8.0)
	Sound.play_at("animal.hen_alarm", a.global_position + Vector3(0, 0.3, 0), -14.0, 1.1)
	a.rotation.y = atan2(away.x, away.z)
	var tw := create_tween()
	tw.tween_property(a, "position", to, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	x.goal = to
	x.wait = 1.6
	await tw.finished
	if is_instance_valid(a) and a._loop == "Flap":
		a.play("Idle", 0.2)

func _face(a: FarmAnimal, to: Vector3) -> void:
	a.rotation.y = atan2(to.x - a.global_position.x, to.z - a.global_position.z)

func _puff_at(a: FarmAnimal, h: float) -> void:
	_after(0.7, func() -> void:
		if is_instance_valid(a):
			plot._puff(a.global_position + Vector3(0, h, 0), Color("ffb3c1"), 6))

func _after(secs: float, f: Callable) -> void:
	get_tree().create_timer(secs).timeout.connect(f)

func to_dict() -> Dictionary:
	return {"hen_days": hen_days, "hen_day": _hen_day}

func from_dict(d: Dictionary) -> void:
	hen_days = int(d.get("hen_days", 0))
	_hen_day = int(d.get("hen_day", -1))
