class_name VespaRide
extends Node3D

const SEAT_ANCHOR := Vector3(0.0, 0.0, -0.18)

const SIDE := Vector3(0.58, 0.0, -0.18)
const NEAR := 1.4
const WHEEL_R := {"wheel_f": 0.146, "wheel_r": 0.133}
const WHEEL_Z := 0.415
const STEER_MAX := 0.16
const MOUNT_S := 1.0
const DISMOUNT_S := 1.0
const MODEL := "vespa_tripo"
const SKINS := [""]
const ROOMS := {"dinh": 8.0, "village_pagoda": 7.0, "temple": 7.0, "cave_pagoda": 9.0, "cliff_pagoda": 7.0, "landing": 6.0}
const DEEP := 0.2
const SLOW := Rect2(-200.0, -120.0, 80.0, 76.0)
const SLOW_MS := 3.0
const XOM_R := {"bac_xom": 1.2, "ke_da_goc": 1.2, "cong_ngo": 1.2, "bac_xom_chieu_nghi": 1.6}

var skin := ""
var hero: Player = null
var state := "parked"
var motion = null
var _model: Node3D
var _wheels := []
var _steer: Node3D = null
var _steer_rest := Basis()
var _steer_a := 0.0
var _body: StaticBody3D
var _t := 0.0
var _lean := 0.0
var _prompt: Label3D
var _chibi_xf := Transform3D()
var _engine: AudioStreamPlayer3D = null
var _home := Transform3D()
var _zones := []
var _say_t := 0.0

var _pave: PaveLift = null
var _bike_y := 0.0
var _lift := 0.0

var _last_ok := Vector3.INF
var _escape := false

static func unlocked() -> bool:
	return Progress.is_open("xe_vespa") or bool(Story.flag("co_vespa", false)) or OS.get_environment("MC_VESPA") != "" \
		or OS.get_cmdline_user_args().has("--vespa")

static func make(parent: Node, pos: Vector3, yaw_deg: float, skin_ := "") -> VespaRide:
	var v := VespaRide.new()
	v.skin = skin_ if skin_ in SKINS else ""
	v.name = "Vespa"
	parent.add_child(v)
	v.global_position = pos
	v.rotation.y = deg_to_rad(yaw_deg)
	v._home = v.global_transform

	if "_no_grass_rects" in parent and "_no_grass" in parent:
		parent._no_grass_rects.append(Rect2(pos.x - 1.0, pos.z - 1.0, 2.0, 2.0))
		parent._no_grass.append(Vector3(pos.x, pos.z, 1.0))
	v._restore()
	return v

func _ready() -> void:
	if ClassDB.class_exists("MotoRide"):
		motion = ClassDB.instantiate("MotoRide")
	set_process(false)
	if not ResourceLoader.exists(Furniture.DIR + MODEL + ".glb"):
		return
	if not unlocked():

		var t := Timer.new()
		t.wait_time = 0.5
		t.autostart = true
		add_child(t)
		t.timeout.connect(func() -> void:
			if unlocked():
				t.queue_free()
				_setup())
		return
	_setup()

func _setup() -> void:
	set_process(true)
	if _zones.is_empty():
		_build_zones()
	_test.call_deferred()
	_model = Furniture.place(self, MODEL, Vector3.ZERO, 0.0, false, skin)
	for n in ["wheel_f", "wheel_r"]:
		var w := _model.find_child(n, true, false) as Node3D
		if w:
			_wheels.append(w)
	_steer = _model.find_child("steer", true, false) as Node3D
	if _steer:
		_steer_rest = _steer.basis

		for mi: MeshInstance3D in _steer.find_children("*", "MeshInstance3D", true, false) + ([_steer] if _steer is MeshInstance3D else []):
			if not mi.name.begins_with("wheel"):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.55, 1.05, 1.22)
	cs.shape = bs
	cs.position = Vector3(0, 0.5, 0)
	_body.add_child(cs)
	add_child(_body)
	_prompt = Label3D.new()
	_prompt.text = tr("MOTO_HINT_ON")

	_prompt.font_size = 48
	_prompt.pixel_size = 0.0005
	_prompt.fixed_size = true
	_prompt.no_depth_test = true
	_prompt.render_priority = 2
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color("5b4a44")
	_prompt.outline_modulate = Color("fff6e6")
	_prompt.outline_size = 14
	_prompt.position = Vector3(0, 1.35, 0)
	_prompt.visible = false
	add_child(_prompt)

var _test_max := 0.0
var _test_n := 0
var _test_sum := 0.0

func _test() -> void:
	var mode := OS.get_environment("MC_VESPA_TEST")
	if mode == "" and OS.get_cmdline_user_args().has("--vespa-near"):
		mode = "near"
	if mode == "":
		return
	await get_tree().create_timer(1.5).timeout
	var p := _local_hero()
	if p == null:
		return
	if mode == "near":
		p.global_position = global_transform * (SIDE + Vector3(0.5, 0.0, 0.0))
		return
	if mode == "pave" or mode == "zone":
		_pave = PaveLift.of(get_parent())
		var hk := get_parent()
		var best := [-1.0, Vector3.ZERO]
		if mode == "pave":
			for mmi: MultiMeshInstance3D in hk.get_children().filter(func(n: Node) -> bool:
					return n is MultiMeshInstance3D and PaveLift.KINDS.any(func(k: String) -> bool: return String(n.name).begins_with(k))):
				for i in mmi.multimesh.instance_count:
					var o: Vector3 = (mmi.global_transform * mmi.multimesh.get_instance_transform(i)).origin
					var d := _pave.top(o) - float(hk.height_at(o.x, o.z))
					if d > best[0] and Vector2(o.x, o.z).length() < 400.0:
						best = [d, o]
			global_position = Vector3(best[1].x, hk.height_at(best[1].x, best[1].z), best[1].z)
			print("vespa_test: %d pave squares; highest over the ground %.3f m at %s" % [_pave.count, best[0], best[1]])
		else:
			var st: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/hometown/layout.json")) as Dictionary)["shrine"]["stairs"]
			var a0 := Vector2(st[0][0], st[0][1])
			var a1 := Vector2(st[1][0], st[1][1])
			var back := a0 - (a1 - a0).normalized() * 6.0
			global_position = Vector3(back.x, hk.height_at(back.x, back.y), back.y)
			rotation.y = atan2(a0.x - back.x, a0.y - back.y)
			print("vespa_test: below Núi Rồng's stair at %s" % global_position)
		p.global_position = global_transform * SIDE
		await get_tree().create_timer(0.3).timeout
		use(p)
		await get_tree().create_timer(MOUNT_S + 0.3).timeout
		p.auto_move = Vector2(sin(global_rotation.y), cos(global_rotation.y)) * (0.35 if mode == "pave" else 0.6)
		for i in 16:
			await get_tree().create_timer(0.3).timeout
			print("vespa_test: t %.1f state %s lift %.3f escape %s bike %s" % [i * 0.3, state, _lift, _escape, global_position])
			if mode == "zone" and state == "parked" and i > 2:
				p.auto_move = Vector2.ZERO
				await get_tree().create_timer(0.4).timeout
				print("vespa_test: in a zone %s; F again" % no_ride(global_position))
				p.global_position = global_transform * SIDE
				use(p)
				await get_tree().create_timer(MOUNT_S + 0.5).timeout
				p.auto_move = -Vector2(sin(global_rotation.y), cos(global_rotation.y)) * 0.6
				await get_tree().create_timer(2.0).timeout
				print("vespa_test: after F + back: state %s bike %s zone %s" % [state, global_position, no_ride(global_position)])
				break
		return
	p.global_position = global_transform * SIDE
	use(p)
	await get_tree().create_timer(MOUNT_S + 0.3).timeout
	var h := global_rotation.y
	var dir := Vector2(sin(h), cos(h))
	if OS.get_environment("MC_VESPA_DIR") != "":
		var f := OS.get_environment("MC_VESPA_DIR").split_floats(",")
		dir = Vector2(f[0], f[1])
	print("vespa_test: bike at %s yaw %.1f" % [global_position, rad_to_deg(h)])
	p.auto_move = dir
	if mode == "run":
		var secs := float(OS.get_environment("MC_VESPA_SECS")) if OS.get_environment("MC_VESPA_SECS") != "" else 20.0
		var slow := 0
		var t := 0.0

		var L: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hometown/layout.json"))
		var road: Array = L["roads"][0]
		var k := 0
		var best := INF
		for i in road.size():
			var dd := Vector2(road[i][0] - p.global_position.x, road[i][1] - p.global_position.z).length()
			if dd < best:
				best = dd
				k = i
		_test_max = 0.0
		var step := -1 if OS.get_environment("MC_VESPA_REV") != "" else 1
		var idle := OS.get_environment("MC_VESPA_IDLE") != ""
		while t < secs and is_instance_valid(p):
			await get_tree().process_frame
			if idle:
				p.auto_move = Vector2.ZERO
			elif k >= 0 and k < road.size():
				var to := Vector2(road[k][0] - p.global_position.x, road[k][1] - p.global_position.z)
				if to.length() < 3.0:
					k += step
				p.auto_move = to.normalized()
			var d := get_process_delta_time()
			t += d
			_test_max = maxf(_test_max, d)
			_test_sum += d
			_test_n += 1
			slow += 1 if d > 0.025 else 0
		print("vespa_run: %.1f s, %d frames, avg %.2f ms, max %.2f ms, >25ms %d, at %s, state %s" % [t, _test_n,
			_test_sum / maxi(_test_n, 1) * 1000.0, _test_max * 1000.0, slow, p.global_position, state])
		p.auto_move = Vector2.ZERO

func riding() -> bool:
	return state != "parked"

func _process(delta: float) -> void:
	if motion == null or _model == null:
		return
	if state == "parked":
		var p := _local_hero()
		if p:
			var near := (p.global_position - global_position) * Vector3(1, 0, 1)
			var close := near.length() < NEAR and p.water == 0 and not p.sitting and p.controls
			_prompt.visible = close
			if close and p.vehicle == null:
				p.vehicle = self
			elif not close and p.vehicle == self:
				p.vehicle = null
		return
	_prompt.visible = false
	_t += delta
	_say_t -= delta
	if hero and (not hero.controls or not hero.is_inside_tree()):
		_force_off("")
		return
	if state == "ride":
		if not no_ride(_nose()):
			_last_ok = hero.global_position
			_escape = false
		elif not _escape:
			if _last_ok != Vector3.INF:
				hero.global_position = _last_ok
				_follow(hero, 0.0)
			_force_off("MOTO_T_NO_RIDE")
			return
	if state == "mount" and _t >= MOUNT_S:
		state = "ride"
		hero.chibi.play("Ride_Sit", 0.15)
	elif state == "dismount" and _t >= DISMOUNT_S:
		_park()

func _local_hero() -> Player:
	var par := get_parent()
	if par and "player" in par and par.player is Player and not par.player.remote:
		return par.player
	return null

func use(p: Player) -> bool:
	if motion == null or _model == null:
		return false
	if state == "parked":
		_get_on(p)
		return true
	if state == "ride" and motion.get_speed() < 1.2:
		_get_off()
		return true
	return state != "parked"

func _get_on(p: Player) -> void:
	hero = p
	state = "mount"
	_t = 0.0
	p.vehicle = self
	p.stop_going()
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	_body.get_child(0).disabled = true

	var yaw := global_rotation.y
	p.global_position = global_transform * SIDE
	p.facing = yaw
	p.rotation.y = yaw
	motion.reset(yaw)
	_escape = no_ride(global_position) or no_ride(_nose())
	_last_ok = Vector3.INF
	_bike_y = global_position.y
	_lift = 0.0
	if _pave == null:
		_pave = PaveLift.of(get_parent())
	_chibi_xf = p.chibi.transform
	_chibi_xf.origin.y = 0.0
	for c in ["Ride_Sit", "Ride_Drive"]:
		if p.chibi.anim.has_animation(c):
			p.chibi.anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR
	p.chibi.play("Ride_Mount", 0.1)
	var tw := create_tween()
	tw.tween_property(p, "global_position", global_transform * SEAT_ANCHOR, MOUNT_S * 0.6).set_delay(MOUNT_S * 0.25)
	_prompt.text = tr("MOTO_HINT_OFF")
	if get_node_or_null("/root/DynRes"):
		DynRes.hold(true)

func _get_off() -> void:
	state = "dismount"
	_t = 0.0
	motion.stop()
	hero.chibi.play("Ride_Dismount", 0.1)
	var tw := create_tween()
	tw.tween_property(hero, "global_position", global_transform * SIDE, DISMOUNT_S * 0.6).set_delay(DISMOUNT_S * 0.2)

func _park() -> void:
	state = "parked"
	_body.process_mode = Node.PROCESS_MODE_INHERIT
	_body.get_child(0).disabled = false
	hero.chibi.transform = _chibi_xf
	_lift = 0.0
	hero.chibi.play("Base_Wait", 0.2)
	hero.chibi.anim.speed_scale = 1.0
	hero.vehicle = null
	hero = null
	_prompt.text = tr("MOTO_HINT_ON")
	_set_lean(0.0)
	if get_node_or_null("/root/DynRes"):
		DynRes.hold(false)
	_save()

func drive(p: Player, delta: float, inp: Vector2) -> void:
	if state != "ride":
		p.velocity = Vector3.ZERO
		p.move_and_slide()
		_follow(p, delta)
		return
	var fwd := -p.cam.global_transform.basis.z
	var boost := OS.get_environment("MC_VESPA_TEST") == "run" or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER) \
		or TouchControls.run
	motion.set_cap(SLOW_MS if _escape or SLOW.has_point(Vector2(p.global_position.x, p.global_position.z)) else 0.0)
	var r: Dictionary = motion.step(delta, inp, fwd, boost)
	var v: Vector3 = r["velocity"]
	p.velocity.x = v.x
	p.velocity.z = v.z
	p.velocity.y = 0.0 if p.is_on_floor() else p.velocity.y - 9.8 * delta
	p.facing = float(r["heading"])
	p.rotation.y = p.facing
	p.move_and_slide()
	if p.bounds_box > 0.0:
		p.position.x = clampf(p.position.x, -p.bounds_box, p.bounds_box)
		p.position.z = clampf(p.position.z, -p.bounds_box, p.bounds_box)
	var spd := float(r["speed"])
	if p.get_real_velocity().length() < spd * 0.3 and spd > 2.0:
		motion.stop()
	var clip := "Ride_Drive" if spd > 0.3 else "Ride_Sit"
	if p.chibi.anim.current_animation != clip and p.chibi.anim.has_animation(clip):
		p.chibi.play(clip, 0.25)
	for w: Node3D in _wheels:
		w.rotate_object_local(Vector3.RIGHT, float(r["speed"]) * delta / float(WHEEL_R.get(w.name, 0.125)))
	if _steer:
		_steer_a = lerpf(_steer_a, clampf(float(r["lean"]) * -0.6, -STEER_MAX, STEER_MAX), 1.0 - exp(-delta * 8.0))
		_steer.basis = _steer_rest * Basis(Vector3.UP, _steer_a)
	_follow(p, delta)
	_set_lean(float(r["lean"]))

func _follow(p: Player, delta: float) -> void:
	var b := Basis(Vector3.UP, p.rotation.y)
	var at := p.global_position - b * SEAT_ANCHOR
	var want := at.y
	if state == "ride":
		for zw in [WHEEL_Z, -WHEEL_Z]:
			want = maxf(want, _pave.top(at + b * Vector3(0, 0, zw)) if _pave else -INF)
	if delta <= 0.0 or absf(want - _bike_y) > 0.4:
		_bike_y = want
	else:
		_bike_y = lerpf(_bike_y, want, 1.0 - exp(-delta * 18.0))
	_bike_y = maxf(_bike_y, at.y)
	global_position = Vector3(at.x, _bike_y, at.z)
	rotation.y = p.rotation.y
	_lift = _bike_y - at.y

func _nose() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, WHEEL_Z + 0.15)

func _set_lean(a: float) -> void:
	_lean = a
	if _model:
		_model.rotation.z = a
	if hero and hero.chibi:
		hero.chibi.transform = Transform3D(_chibi_xf.basis * Basis(Vector3(0, 0, 1), a), _chibi_xf.origin + Vector3(0, _lift, 0))

func _force_off(say: String) -> void:
	if hero == null:
		return
	motion.stop()
	var h := hero
	h.global_position = global_transform * SIDE
	_park()
	if say != "" and _say_t <= 0.0:
		_say_t = 3.0
		if h.chibi:
			h.chibi.emote("surprised")
		_prompt.text = tr(say)
		_prompt.visible = true
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
			if is_instance_valid(_prompt):
				_prompt.text = tr("MOTO_HINT_ON"))

func no_ride(p: Vector3) -> bool:
	var w := Water.at(p.x, p.z)
	if not is_nan(w.x) and w.y > DEEP:
		return true
	var q := Vector2(p.x, p.z)
	for z: Array in _zones:
		match z[0]:
			"seg":
				var a: Vector2 = z[1]
				var b: Vector2 = z[2]
				var t := clampf((q - a).dot(b - a) / maxf((b - a).length_squared(), 1e-6), 0.0, 1.0)
				if q.distance_to(a + (b - a) * t) < float(z[3]):
					return true
			"rect":
				if (z[1] as Rect2).has_point(q):
					return true
			"disc":
				if q.distance_to(z[1]) < float(z[2]):
					return true
	return _paddy(p.x, p.z)

func _paddy(x: float, z: float) -> bool:
	var hk := get_parent()
	if hk == null or not "terrain" in hk or hk.terrain == null or not "N" in hk:
		return false
	var n: int = hk.N
	var half: int = hk.HALF
	var gx := int(round(x)) + half
	var gz := int(round(z)) + half
	if gx < 0 or gz < 0 or gx >= n or gz >= n:
		return false
	var m: PackedByteArray = hk.terrain.mats
	var i := gz * n + gx
	return i < m.size() and m[i] == 1

func _build_zones() -> void:
	_zones.clear()
	var path := "res://data/hometown/layout.json"
	if not FileAccess.file_exists(path):
		return
	var L: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for pl: Dictionary in L.get("places", []):
		if ROOMS.has(pl.get("kind", "")):
			_zones.append(["disc", Vector2(pl["x"], pl["z"]), ROOMS[pl["kind"]]])
		if pl.get("kind", "") == "station":
			_zones.append(["rect", Rect2(float(pl["x"]) - 19.0, float(pl["z"]) - 7.8, 28.5, 10.6)])
	var sh: Dictionary = L.get("shrine", {})
	var st: Array = sh.get("stairs", [])
	for i in st.size() - 1:
		_zones.append(["seg", Vector2(st[i][0], st[i][1]), Vector2(st[i + 1][0], st[i + 1][1]), float(sh.get("stair_w", 3.2)) / 2.0 + 0.6])
	var tp: Dictionary = L.get("temple", {})
	if tp.has("stair"):
		var zs: Array = tp["stair"].map(func(r: Array) -> float: return float(r[0]))
		var hw := float(tp.get("land_hw", 5.5)) + 0.5
		_zones.append(["rect", Rect2(float(tp["stair_x"]) - hw, zs.min() - 1.0, 2.0 * hw, zs.max() - zs.min() + 2.0)])

	var xp := "res://data/hometown/xom_dinh.json"
	if FileAccess.file_exists(xp):
		var X = JSON.parse_string(FileAccess.get_file_as_string(xp))
		if X is Dictionary:
			for r: Array in X.get("noride", []):
				_zones.append(["disc", Vector2(r[1], r[2]), float(XOM_R.get(r[0], 1.2))])

	var site := NhaThoDa.SITE
	_zones.append(["disc", site + Vector2(NhaThoDa.CATHEDRAL.x, NhaThoDa.CATHEDRAL.z), 15.0])
	for c: Array in NhaThoDa.CHAPELS:
		_zones.append(["disc", site + Vector2(c[0], c[1]), 5.0])
	_zones.append(["disc", site + Vector2(NhaThoDa.STONE_CHAPEL.x, NhaThoDa.STONE_CHAPEL.z), 6.0])

func _save() -> void:
	var t := global_transform
	Story.set_flag("vespa_at", [snappedf(t.origin.x, 0.01), snappedf(t.origin.y, 0.01), snappedf(t.origin.z, 0.01),
		snappedf(rotation.y, 0.001)])

func _restore() -> void:
	var at = Story.flag("vespa_at", null)
	if not (at is Array) or (at as Array).size() < 4:
		return
	var p := Vector3(float(at[0]), float(at[1]), float(at[2]))
	var hk := get_parent()
	var box: float = hk.player.bounds_box if hk and "player" in hk and hk.player else 0.0
	if box > 0.0 and (absf(p.x) > box or absf(p.z) > box):
		return
	if _zones.is_empty():
		_build_zones()
	if no_ride(p):
		return
	global_position = p
	rotation.y = float(at[3])
