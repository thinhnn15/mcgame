class_name DuckHouse
extends Node3D

const ROOST := 18.2
const WAKE := 6.0
const RAMP := [Vector3(0, 0, 1.55), Vector3(0, -0.075, 1.27), Vector3(0, 0.135, 0.52), Vector3(0, 0.135, 0.24)]
const GAP := 0.7
const KINDS := ["vit", "vit_con", "vit_con", "vit_con"]
const EGGS_MAX := 4
const EGG_AT := Vector3(0.1, 0.14, 0.42)

var water_y := 0.0
var pond_c := Vector2.ZERO
var pond_r := Vector2.ONE
var path: Curve3D
var ducks := []
var _free_at := 0.0
var _last_h := -1.0
var core = null
var _clips := []
var _fed := false
var _eggs := 0
var fed: bool:
	get: return core.is_fed() if core else _fed
	set(v): _fed = v
var eggs: int:
	get: return core.eggs() if core else _eggs
	set(v): _eggs = v
var _feed_at := Vector3.INF
var _feed_t := 0.0
var _talk_t := 4.0
var _egg_nodes := []
var _house := Transform3D()

static func add(parent: Node3D, house_pos: Vector3, yaw_deg: float, water_y_: float, pond_c_: Vector2,
		pond_r_: Vector2) -> DuckHouse:
	var d := DuckHouse.new()
	d.name = "DuckHouse"
	d.water_y = water_y_
	d.pond_c = pond_c_
	d.pond_r = pond_r_
	parent.add_child(d)
	var b := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	d._house = Transform3D(b, house_pos)
	d.path = Curve3D.new()
	d.path.bake_interval = 0.04
	for i in RAMP.size():
		var q: Vector3 = house_pos + b * RAMP[i]
		if i == 0:
			q.y = water_y_
		d.path.add_point(q)
	for i in KINDS.size():
		var at := d._on_pond(randf(), randf())
		var a := FarmAnimal.spawn(d, KINDS[i], at, randf() * TAU)
		a.play.call_deferred("Swim")
		d.ducks.append({"a": a, "kind": KINDS[i], "state": "swim", "goal": at, "s": 0.0, "late": 0.03 * i, "hop": 0.0})
		d._clips.append("")
	if ClassDB.class_exists(&"DuckFlock") and OS.get_environment("MC_FARM_GD") == "":
		d.core = ClassDB.instantiate(&"DuckFlock")
		var pts := PackedVector3Array()
		for i in d.path.point_count:
			pts.append(d.path.get_point_position(i))
		var swim := PackedFloat32Array()
		var walk := PackedFloat32Array()
		var hops := PackedStringArray()
		for k: String in KINDS:
			var sp: Dictionary = FarmAnimal.SPEED.get(k, FarmAnimal.SPEED["vit"])
			swim.append(float(sp["Swim"]))
			walk.append(float(sp["Walk"]))
			hops.append("Flap" if k == "vit" else "Hop")
		d.core.setup(pts, pond_c_, pond_r_, water_y_, swim, walk, hops, ROOST, WAKE, GAP)
		d.core.snap(Clock.hour())
		d._apply(0.0)
	else:
		d._snap()
	return d

func _apply(delta: float) -> void:
	for i in ducks.size():
		var a: FarmAnimal = ducks[i]["a"]
		a.position = core.pos(i)
		a.rotation.y = core.yaw(i)
		a.visible = core.shown(i)
		var cl: String = core.clip(i)
		if cl != _clips[i] or delta == 0.0:
			_clips[i] = cl
			a.play(cl, 0.1 if cl in ["Flap", "Hop"] else 0.25)

func _on_pond(u: float, v: float) -> Vector3:
	var ang := u * TAU
	var r := sqrt(v) * 0.55
	return Vector3(pond_c.x + cos(ang) * pond_r.x * r, water_y, pond_c.y + sin(ang) * pond_r.y * r)

func _process(delta: float) -> void:
	if core == null:
		_process_gd(delta)
		return
	core.step(delta, Clock.hour(), Time.get_ticks_msec() / 1000.0)
	_apply(delta)
	_talk_t -= delta
	var mum: FarmAnimal = ducks[0]["a"]
	if _talk_t <= 0.0 and mum.visible:
		_talk_t = randf_range(5.0, 11.0)
		Sound.play_at("animal.duck_quack", mum.global_position + Vector3(0, 0.2, 0))
		if randf() < 0.6 and ducks[1]["a"].visible:
			Sound.play_at("animal.duckling_peep", ducks[1]["a"].global_position + Vector3(0, 0.1, 0), -3.0)

func _process_gd(delta: float) -> void:
	var h := Clock.hour()
	if _last_h >= 0.0 and absf(h - _last_h) > 0.2:
		_snap()
	_last_h = h
	var now := Time.get_ticks_msec() / 1000.0
	var length := path.get_baked_length()
	var mum: FarmAnimal = ducks[0]["a"]
	_feed_t -= delta
	_talk_t -= delta
	if _talk_t <= 0.0 and mum.visible:
		_talk_t = randf_range(5.0, 11.0)
		Sound.play_at("animal.duck_quack", mum.global_position + Vector3(0, 0.2, 0))
		if randf() < 0.6 and ducks[1]["a"].visible:
			Sound.play_at("animal.duckling_peep", ducks[1]["a"].global_position + Vector3(0, 0.1, 0), -3.0)
	for i in ducks.size():
		var d: Dictionary = ducks[i]
		var a: FarmAnimal = d["a"]
		var night: bool = h >= ROOST + float(d["late"]) or h < WAKE
		match d["state"]:
			"swim":
				if night:
					d["state"] = "home"
					continue
				if i == 0:
					if _feed_t > 0.0:
						d["goal"] = _feed_at
					elif Vector2(a.position.x - d["goal"].x, a.position.z - d["goal"].z).length() < 0.15:
						d["goal"] = _on_pond(randf(), randf())
				else:
					var back := Basis(Vector3.UP, mum.rotation.y) * Vector3(0, 0, -0.32 * i)
					d["goal"] = mum.position + back
				_swim_to(a, d["goal"], delta, (1.0 if i == 0 else 1.25) * (2.0 if _feed_t > 0.0 else 1.0))
			"home":
				if not night:
					d["state"] = "swim"
					continue
				var foot := path.sample_baked(0.0)
				var queue := _queue_spot(i, foot)
				if _swim_to(a, queue, delta, 1.3) < 0.08 and _first_waiting(i) and now >= _free_at:
					d["state"] = "ramp_in"
					d["s"] = 0.0
					_free_at = now + GAP
					_hop(d)
			"ramp_in", "ramp_out":
				var dir := 1.0 if d["state"] == "ramp_in" else -1.0
				var sp: float = FarmAnimal.SPEED.get(d["kind"], FarmAnimal.SPEED["vit"])["Walk"]
				d["s"] = clampf(float(d["s"]) + dir * sp * delta, 0.0, length)
				var p := path.sample_baked(d["s"])
				var ahead := path.sample_baked(clampf(float(d["s"]) + dir * 0.06, 0.0, length))
				var dv := ahead - p
				if Vector2(dv.x, dv.z).length() > 0.004:
					a.rotation.y = lerp_angle(a.rotation.y, atan2(dv.x, dv.z), 1.0 - exp(-delta * 10.0))
				a.position = p
				d["hop"] = float(d["hop"]) - delta
				if d["hop"] <= 0.0:
					a.play("Walk" if d["s"] > 0.05 else "Swim")
				if dir > 0.0 and d["s"] >= length:
					d["state"] = "in"
					a.visible = false
				elif dir < 0.0 and d["s"] <= 0.0:
					d["state"] = "swim"
					d["goal"] = _on_pond(randf(), randf())
					a.play("Swim")
			"in":
				if not night and now >= _free_at:
					if i == 0 or ducks[i - 1]["state"] != "in":
						d["state"] = "ramp_out"
						d["s"] = length
						_free_at = now + GAP
						a.position = path.sample_baked(length)
						a.visible = true

func feed(at: Vector3) -> String:
	if core:
		var r: String = core.feed(at)
		if r != "asleep":
			Sound.play_at("animal.duck_quack", ducks[0]["a"].global_position + Vector3(0, 0.2, 0))
		return r
	if ducks.all(func(d: Dictionary) -> bool: return d["state"] == "in" or d["state"] == "home"):
		return "asleep"
	var q := at - Vector3(pond_c.x, 0, pond_c.y)
	var e := sqrt(pow(q.x / pond_r.x, 2) + pow(q.z / pond_r.y, 2))
	if e > 0.8:
		q *= 0.8 / e
	_feed_at = Vector3(pond_c.x + q.x, water_y, pond_c.y + q.z)
	_feed_t = 9.0
	Sound.play_at("animal.duck_quack", ducks[0]["a"].global_position + Vector3(0, 0.2, 0))
	var first := not fed
	fed = true
	return "first" if first else "again"

func night() -> void:
	if core:
		core.night()
		_show_eggs()
		return
	if fed:
		eggs = mini(eggs + 1, EGGS_MAX)
	fed = false
	_show_eggs()

func take_egg() -> void:
	if core:
		core.take_egg()
		_show_eggs()
		return
	eggs = maxi(eggs - 1, 0)
	_show_eggs()

func _show_eggs() -> void:
	for n in _egg_nodes:
		n.queue_free()
	_egg_nodes.clear()
	for i in eggs:
		var p := _house * (EGG_AT + Vector3(-0.07 * i, 0, 0.03 * (i % 2)))
		_egg_nodes.append(Props.mesh(get_parent(), Props.sphere(0.05), Color("dfe9e4"), p, Vector3.ZERO, Vector3(1, 1.25, 1)))

func to_dict() -> Dictionary:
	if core:
		return core.to_dict()
	return {"fed": fed, "eggs": eggs}

func from_dict(d: Dictionary) -> void:
	if core:
		core.from_dict(d)
		_show_eggs()
		return
	fed = bool(d.get("fed", false))
	eggs = clampi(int(d.get("eggs", 0)), 0, EGGS_MAX)
	_show_eggs()

func _swim_to(a: FarmAnimal, to: Vector3, delta: float, k := 1.0) -> float:
	var v := to - a.position
	v.y = 0.0
	var dist := v.length()
	if dist > 0.05:
		var sp: float = FarmAnimal.SPEED.get(a.kind, FarmAnimal.SPEED["vit"])["Swim"] * k
		var p := a.position + v.normalized() * minf(sp * delta, dist)
		a.position = Vector3(p.x, water_y, p.z)
		a.rotation.y = lerp_angle(a.rotation.y, atan2(v.x, v.z), 1.0 - exp(-delta * 6.0))
	a.play("Swim")
	return dist

func _queue_spot(i: int, foot: Vector3) -> Vector3:
	var n := 0
	for j in i:
		if ducks[j]["state"] == "home":
			n += 1
	var out := Vector3(foot.x - path.sample_baked(0.3).x, 0, foot.z - path.sample_baked(0.3).z).normalized()
	return foot + out * (0.3 * n)

func _first_waiting(i: int) -> bool:
	for j in i:
		if ducks[j]["state"] == "home":
			return false
	return true

func _hop(d: Dictionary) -> void:
	var a: FarmAnimal = d["a"]
	var clip := "Flap" if d["kind"] == "vit" else "Hop"
	if a.anim.has_animation(clip):
		a.play(clip, 0.1)
		d["hop"] = 0.5

func _snap() -> void:
	var h := Clock.hour()
	_free_at = 0.0
	for d: Dictionary in ducks:
		var a: FarmAnimal = d["a"]
		if h >= ROOST + d["late"] or h < WAKE:
			d["state"] = "in"
			a.visible = false
		else:
			d["state"] = "swim"
			a.visible = true
			a.position = _on_pond(randf(), randf())
			d["goal"] = a.position
			a.play("Swim")
	_last_h = h
