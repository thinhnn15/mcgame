class_name ChuaSuKien
extends RefCounted

const BA := "ba_noi"
const PACE := 0.7
const ROUND_R := 6.3
const TIER := 2.4 * ChuaMay.K

static var _f_was := false

static func register() -> void:
	HomeEvents.minigames["chua_len_doc"] = len_doc
	HomeEvents.minigames["chua_cua_ben"] = cua_ben
	HomeEvents.minigames["chua_thinh_chuong"] = thinh_chuong
	HomeEvents.minigames["chua_ngoi_khan"] = ngoi_khan
	HomeEvents.minigames["chua_ba_vong"] = ba_vong
	HomeEvents.minigames["chua_ban_cong"] = ban_cong
	HomeEvents.minigames["chua_tha_ca"] = tha_ca
	HomeEvents.minigames["chua_xe_ve"] = xe_ve
	HomeEvents.minigames["ba_ru_dong_y"] = dong_y
	HomeEvents.minigames["ba_ru_hien"] = hien
	HomeEvents.minigames["ba_ru_don"] = don

static func _chua(ev: HomeEvents) -> ChuaMay:
	return ev.map.get_node_or_null("ChuaThapMay") as ChuaMay if ev.map else null

static func _g(ev: HomeEvents, chua: ChuaMay, x: float, z: float) -> Vector3:
	var p := chua.to_global(Vector3(x, 0, z))
	p.y = ev.ground.call(p.x, p.z)
	return p

static func _frame(ev: HomeEvents) -> float:
	await ev.get_tree().process_frame
	return ev.get_process_delta_time()

static func _f() -> bool:
	var down := Input.is_physical_key_pressed(KEY_F) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	var hit := down and not _f_was
	_f_was = down
	return hit

static func _moving() -> bool:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		if Input.is_physical_key_pressed(k):
			return true
	return Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)).length() > 0.4

static func _toward(c: Chibi, to: Vector3, speed: float, dt: float, clip := "Move_Walk") -> bool:
	var d := to - c.global_position
	var flat := Vector2(d.x, d.z)
	if flat.length() < 0.05:
		c.global_position = to
		return true
	var step := minf(flat.length(), speed * dt)
	var k := step / flat.length()
	c.global_position += Vector3(d.x * k, d.y * k, d.z * k)
	c.rotation.y = lerp_angle(c.rotation.y, atan2(d.x, d.z), 1.0 - exp(-dt * 8.0))
	if c.anim and c.anim.current_animation != clip:
		c.play(clip, 0.2)
	return false

static func _idle(c: Chibi) -> void:
	if c.anim and c.anim.current_animation != "Base_Wait":
		c.play("Base_Wait", 0.25)

static func _hero_near(ev: HomeEvents, c: Chibi, r: float) -> bool:
	var d := ev.player.global_position - c.global_position
	return Vector2(d.x, d.z).length() < r

static func len_doc(ev: HomeEvents, _s: Dictionary) -> void:
	var chua := _chua(ev)
	var ba := ev._chibi(BA)
	if chua == null or ba == null:
		return
	ba.hold("cane")

	var way := [[0.9, 96.0, ""], [0.9, 79.0, ""], [0.9, 75.0, "rest"], [0.9, 55.0, ""], [-2.9, 51.4, "bench"],
		[0.9, 47.0, ""], [0.9, 27.0, ""]]
	var st := {"held": false, "held_m": 0.0, "all_m": 0.0, "waved": false}
	ev._hero_controls(true)
	ev._hint_text("EV_HINT_HAND")
	_f()
	for w: Array in way:
		var to := _g(ev, chua, w[0], w[1])
		while true:
			var dt: float = await _frame(ev)
			var before := ba.global_position
			var there := _toward(ba, to, PACE, dt, "Tool_Cane_Walk")
			var moved := before.distance_to(ba.global_position)
			st["all_m"] += moved
			_hand(ev, ba, st, moved)
			if not st["waved"] and chua.to_local(ev.player.global_position).z < 31.0 and chua.to_local(ba.global_position).z > 60.0:
				st["waved"] = true
				ba.emote("wave")
				ev.toast(ev._line("EV_DC_BA_6", BA), 4.0)
			if there:
				break
		match w[2]:
			"rest":
				_idle(ba)
				var t := 0.0
				while t < 3.5:
					t += await _frame(ev)
					_hand(ev, ba, st, 0.0)
			"bench":
				await _bench(ev, chua, ba, st)
	_idle(ba)
	if st["held_m"] >= 0.6 * maxf(st["all_m"], 1.0):
		ev._reward({"moment": "dat_tay_ba_len_doc"})
	if st["held"]:
		_let_go(ev)
	ev._hint_text("")
	ev._hero_controls(false)

static func _hand(ev: HomeEvents, ba: Chibi, st: Dictionary, moved: float) -> void:
	if _f():
		if st["held"]:
			st["held"] = false
			_let_go(ev)
		elif _hero_near(ev, ba, 1.8):
			st["held"] = true
			ev.player.controls = false
			ev.player.stop_going()
	if ev.auto and not st["held"]:
		st["held"] = true
		ev.player.controls = false
	if st["held"]:
		var side := ba.global_basis * Vector3(-0.72, 0, 0)
		ev.player.global_position = ba.global_position + side + Vector3(0, 0.05, 0)
		ev.player.velocity = Vector3.ZERO
		ev.player.rotation.y = ba.rotation.y
		ev.player.facing = ba.rotation.y
		var clip := "Move_Walk" if moved > 0.0005 else "Base_Wait"
		if ev.player.chibi.anim and ev.player.chibi.anim.current_animation != clip:
			ev.player.chibi.play(clip, 0.2)
		st["held_m"] += moved

static func _let_go(ev: HomeEvents) -> void:
	ev.player.controls = true
	ev.player.chibi.play("Base_Wait", 0.2)

static func _bench(ev: HomeEvents, chua: ChuaMay, ba: Chibi, st: Dictionary) -> void:
	if st["held"]:
		st["held"] = false
		_let_go(ev)
	var face := chua.global_rotation.y + PI / 2.0
	var tw := ba.create_tween()
	tw.tween_property(ba, "rotation:y", ba.rotation.y + wrapf(face - ba.rotation.y, -PI, PI), 0.4)
	await tw.finished
	ba.play("Act_SitChair_Idle", 0.3)
	ev._hint_text("EV_HINT_SIT")
	var t := 0.0
	var sat := 0.0
	var cleared := false
	while true:
		var dt: float = await _frame(ev)
		t += dt
		if ev.auto and t > 1.0 and not ev.player.sitting:
			ev._put_hero(ba.global_position + chua.global_basis * Vector3(0, 0, 1.0), ba.rotation.y)
			ev.player.set_sitting(true)
		if ev.player.sitting and _hero_near(ev, ba, 3.0):
			sat += dt
		if sat > 5.0 and not cleared:
			cleared = true
			_clear_mist(chua)
		if sat > 9.0:
			ev._hero_controls(false)
			await ev._say(BA, "EV_DC_BA_7", "calm")
			ev.box.close()
			ev._reward({"moment": "suong_tan_chieu_nghi"})
			ev._hero_controls(true)
			break
		if t > 25.0 and sat < 0.5:
			break
	ev._hint_text("EV_HINT_HAND")
	if ev.player.sitting:
		ev.player.set_sitting(false)
	ba.play("Base_Wait", 0.3)

static func _clear_mist(chua: ChuaMay) -> void:
	var mist := chua.get_node_or_null("Mist")
	if mist == null or mist.get_child_count() == 0:
		return
	var m := (mist.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
	if m:
		var tw := mist.create_tween()
		tw.tween_property(m, "albedo_color:a", 0.0, 6.0).set_trans(Tween.TRANS_SINE)

static func cua_ben(ev: HomeEvents, _s: Dictionary) -> void:
	var chua := _chua(ev)
	if chua == null:
		return
	if ev.actors.has(BA):
		ev._followers.append(BA)
	ev._point_at(ev._where("thap_may", {"off": [0.0, -3.0]}), "EV_HINT_GATE")
	ev._hero_controls(true)
	var prev := chua.to_local(ev.player.global_position)
	var side := false
	while true:
		await _frame(ev)
		if ev.auto:
			ev._put_hero(chua.to_global(Vector3(4.6, 0.1, -1.0)), ev.player.rotation.y)
		var p := chua.to_local(ev.player.global_position)
		if prev.z >= 0.0 and p.z < 0.0:
			side = absf(p.x) > 2.4
			break
		prev = p
	ev._hero_controls(false)
	ev._clear_markers()
	ev._followers.clear()
	HomeEvents.choices["di_chua_voi_ba.cua"] = "ben" if side else "giua"
	var ba := ev._chibi(BA)
	if ba and side:
		ba.emote("agree")
	await ev._wait(0.8)

static func thinh_chuong(ev: HomeEvents, _s: Dictionary) -> void:
	var chua := _chua(ev)
	if chua == null:
		return
	var st := {"n": 0, "soon": false}
	var on_rang := func():
		st["n"] += 1
		for sx in [-1.0, 1.0]:
			_ripple(chua, Vector3(sx * (ChuaMayCanh.POND.x + 2.2), ChuaMayCanh.POND_WATER + 0.03, ChuaMayCanh.POND.z))
	var on_soon := func(): st["soon"] = true
	chua.rang.connect(on_rang)
	chua.rang_too_soon.connect(on_soon)
	chua.bell_rest = 6.0
	ev._hint_text("EV_HINT_BELL")
	ev._hero_controls(true)
	var auto_t := 0.0
	while st["n"] < 3:
		var dt: float = await _frame(ev)
		if ev.auto:
			auto_t += dt
			if auto_t > 9.0:
				auto_t = 0.0
				chua.ring_bell()
		if st["soon"]:
			st["soon"] = false
			ev._hero_controls(false)
			await ev._say("su_thay", "EV_DC_THAY_3", "smile")
			ev.box.close()
			ev._hero_controls(true)
	ev._hint_text("")
	ev._hero_controls(false)
	chua.rang.disconnect(on_rang)
	chua.rang_too_soon.disconnect(on_soon)
	chua.bell_rest = 0.0
	await ev._wait(5.0)

static func _ripple(chua: ChuaMay, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 4
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.45)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	mi.scale = Vector3(0.3, 0.02, 0.3)
	chua.add_child(mi)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(4.2, 0.02, 4.2), 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 6.0)
	tw.chain().tween_callback(mi.queue_free)

static func ngoi_khan(ev: HomeEvents, _s: Dictionary) -> void:
	var chua := _chua(ev)
	var ba := ev._chibi(BA)
	if chua == null or ba == null:
		return
	ba.hold("")
	ba.global_position = chua.to_global(ChuaMay.HALL + Vector3(0, 1.2, 1.4) * ChuaMay.K)
	ba.rotation.y = chua.global_rotation.y + PI
	ba.play("Act_SitFloor", 0.3)
	ev._hint_text("EV_HINT_SIT")
	ev._hero_controls(true)
	var sat := 0.0
	var t := 0.0
	var shown := 0
	while t < 16.0:
		var dt: float = await _frame(ev)
		t += dt
		if ev.auto and t > 1.0 and not ev.player.sitting:
			ev._put_hero(ba.global_position + chua.global_basis * Vector3(1.0, 0, 0.2), ba.rotation.y)
			ev.player.set_sitting(true)
		if ev.player.sitting and _hero_near(ev, ba, 2.5):
			sat += dt
		if shown < 3 and t > 2.0 + shown * 4.5:
			ev.toast(TranslationServer.translate("EV_DC_KHAN_%d" % (shown + 1)), 4.0)
			shown += 1
	ev._hint_text("")
	ev._hero_controls(false)
	if sat > 8.0:
		await ev._say(BA, "EV_DC_BA_11", "calm")
		ev.box.close()
		await ev._narr("EV_DC_NARR_2")
	if ev.player.sitting:
		ev.player.set_sitting(false)
	ba.play("Base_Wait", 0.3)
	ba.hold("cane")

static func ba_vong(ev: HomeEvents, _s: Dictionary) -> void:
	var chua := _chua(ev)
	var ba := ev._chibi(BA)
	if chua == null or ba == null:
		return
	var c := Vector3(ChuaMay.TOWER.x, 0, ChuaMay.TOWER.z)
	var tier_y := ChuaMay.L2 + TIER
	ev._hint_text("EV_HINT_ROUND")
	ev._hero_controls(true)

	for p: Vector3 in [Vector3(c.x, ChuaMay.L2, c.z + 11.5), Vector3(c.x, tier_y, c.z + ROUND_R)]:
		var to := chua.to_global(p)
		while true:
			var dt: float = await _frame(ev)
			if _toward(ba, to, PACE, dt, "Tool_Cane_Walk"):
				break
	var theta := 0.0
	var near := 0.0
	var all := 0.0
	var said := [false, false, false]
	while theta < TAU * 3.0:
		var dt: float = await _frame(ev)
		theta += PACE * dt / ROUND_R
		var p := c + Vector3(-ROUND_R * sin(theta), tier_y, ROUND_R * cos(theta))
		var to := chua.to_global(p)
		_toward(ba, to, PACE * 1.5, dt, "Tool_Cane_Walk")
		if ev.auto:
			ev._put_hero(chua.to_global(c + Vector3(-(ROUND_R + 1.0) * sin(theta - 0.12), tier_y, (ROUND_R + 1.0) * cos(theta - 0.12))), ba.rotation.y)
		all += dt
		if _hero_near(ev, ba, 3.5):
			near += dt
		var lap := int(theta / TAU)
		var in_lap := fmod(theta, TAU)
		if lap == 0 and not said[0] and in_lap > deg_to_rad(205.0):
			said[0] = true
			ev.toast(ev._line("EV_DC_VONG_1", BA), 9.0)
		elif lap == 1 and not said[1] and in_lap > deg_to_rad(290.0):
			said[1] = true
			ev.toast(ev._line("EV_DC_VONG_2", BA), 8.0)
		elif lap == 2 and not said[2] and in_lap > deg_to_rad(90.0):
			said[2] = true
			ev._hero_controls(false)
			ba.rotation.y = chua.global_rotation.y - PI / 2.0
			ba.play("Act_Point", 0.2)
			await ev._wait(1.0)
			await ev._say(BA, "EV_DC_VONG_3", "calm")
			ev.box.close()
			await ev._say(BA, "EV_DC_VONG_4", "worried")
			await ev._wait(3.0)
			await ev._say(BA, "EV_DC_VONG_5", "smile")
			ev.box.close()
			ev._hero_controls(true)
	_idle(ba)
	ev._hint_text("")
	ev._hero_controls(false)
	if near >= 0.7 * all:
		ev._reward({"moment": "ba_vong_quanh_thap"})

static func ban_cong(ev: HomeEvents, _s: Dictionary) -> void:
	var chua := _chua(ev)
	var ba := ev._chibi(BA)
	if chua == null or ba == null:
		return
	ba.global_position = chua.to_global(ChuaMayCanh.BENCH + Vector3(0.15, 0, 0))
	ba.rotation.y = chua.global_rotation.y + PI / 2.0
	ba.play("Act_SitChair_Idle", 0.3)
	ev._hint_text("EV_HINT_TOWER")
	ev._point_at(ev._where("thap_may", {"off": [0.0, ChuaMay.TOWER.z + 8.0]}), "")
	ev._hero_controls(true)
	var up_y := chua.to_global(ChuaMay.TOWER + Vector3(0, (ChuaMay.BALCONY - 1.5) * ChuaMay.K, 0)).y
	var t := 0.0
	while ev.player.global_position.y < up_y:
		t += await _frame(ev)
		if ev.auto and t > 1.0:
			t = -100.0
			chua._through_door(true)
	ev._clear_markers()
	ev._hint_text("")
	await ev._wait(1.2)
	ba.play("Base_Wait", 0.3)
	var d := ev.player.global_position - ba.global_position
	ba.rotation.y = atan2(d.x, d.z)
	var w := 0.0
	while w < 9.0:
		ba.emote("wave")
		await ev._wait(2.2)
		w += 2.2
	ev._reward({"moment": "ba_vay_goc_bo_de"})
	ev._hint_text("EV_HINT_DOWN")
	t = 0.0
	while not _hero_near(ev, ba, 3.5) or ev.player.global_position.y > up_y - 10.0:
		t += await _frame(ev)
		if ev.auto and t > 2.0:
			t = -100.0
			chua._through_door(false)
			await ev._wait(1.5)
			ev._put_hero(ba.global_position + chua.global_basis * Vector3(1.2, 0, 1.2), ba.rotation.y)
	ev._hint_text("")
	ev._hero_controls(false)

static func tha_ca(ev: HomeEvents, _s: Dictionary) -> void:
	var fwd := ev.player.global_basis.z.normalized()
	var c := ev.player.global_position + Vector3(fwd.x, 0, fwd.z) * 4.8
	c.y = 0.03
	var fish := []
	for i in 3:
		var f: Node3D = (load("res://characters/tools/fish.glb") as PackedScene).instantiate()
		var m := StandardMaterial3D.new()
		m.albedo_color = [Color("e2552e"), Color("f08a2a"), Color("d8402a")][i]
		m.roughness = 0.5
		for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = m
		f.scale = Vector3.ONE * 1.4
		ev.map.add_child(f)
		f.global_position = c
		fish.append(f)
	var t := 0.0
	while t < 7.0:
		var dt: float = await _frame(ev)
		t += dt
		for i in 3:
			var a := t * 0.9 + i * TAU / 3.0
			var r := 0.6 + t * 0.25
			var f: Node3D = fish[i]
			var sink := maxf(0.0, t - 5.0) * 0.5
			f.global_position = c + Vector3(cos(a) * r, -sink, sin(a) * r)
			f.rotation = Vector3(0, -a, 0)
	for f: Node3D in fish:
		f.queue_free()

static func xe_ve(ev: HomeEvents, _s: Dictionary) -> void:
	await ev._fade(1.0, 1.2)
	ev.toast(TranslationServer.translate("EV_DC_XE_0"), 5.0)
	var still := 0.0
	var t := 0.0
	while still < 12.0 and t < 40.0:
		var dt: float = await _frame(ev)
		t += dt
		if _moving() and not ev.auto:
			if still > 1.0:
				ev.toast(TranslationServer.translate("EV_DC_XE_1"), 3.0)
			still = 0.0
		else:
			still += dt
	await ev._narr("EV_DC_NARR_3")
	if still >= 12.0:
		ev._reward({"moment": "ba_ngu_tren_vai"})

static func dong_y(ev: HomeEvents, _s: Dictionary) -> void:
	var ba := ev._chibi(BA)
	if ba == null:
		return
	ev._hint_text("EV_HINT_NOD")
	ev._hero_controls(true)
	_f()
	var t := 0.0
	var sat := 0.0
	while true:
		var dt: float = await _frame(ev)
		t += dt
		if (ev.auto and t > 1.0) or (_f() and _hero_near(ev, ba, 3.0)):
			ev._hero_controls(false)
			ev.player.chibi.emote("agree")
			await ev._wait(1.2)
			break
		if ev.player.sitting and _hero_near(ev, ba, 2.5):
			sat += dt
			if sat > 1.2:
				break
	ev._hint_text("")
	ev._hero_controls(false)

const PORCH := 0.39
const CEILING := 2.7

static func _house(ev: HomeEvents, x: float, z: float, up: float) -> Array:
	var at := ev._where("nha_bo_me", {"off": [x, z]})
	if at.is_empty():
		return []
	return [at[0] + Vector3(0, up, 0), at[1]]

static func hien(ev: HomeEvents, _s: Dictionary) -> void:
	var ba := ev._chibi(BA)
	if ba == null or ev.map == null:
		return
	var porch := Node3D.new()
	porch.name = "BaRuHien"
	ev.map.add_child(porch)
	var a := _house(ev, 3.0, 3.8, PORCH)
	if a.is_empty():
		return
	var yaw_deg := rad_to_deg(float(a[1]))
	Furniture.place(porch, "chong_tre", a[0], yaw_deg, true)
	var t := _house(ev, 3.5, 3.7, PORCH + 0.42)
	Furniture.place(porch, "coi_trau", t[0], yaw_deg + 20.0, false)
	var l := _house(ev, 2.0, 4.05, CEILING)
	Furniture.place(porch, "den_hien", l[0], yaw_deg, false)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffcf8a")
	lamp.light_energy = 0.9
	lamp.omni_range = 6.5
	lamp.omni_attenuation = 1.4
	porch.add_child(lamp)
	lamp.global_position = l[0] + Vector3(0, -0.6, 0)
	var seat := _house(ev, 2.7, 3.85, PORCH)
	ba.global_position = seat[0]
	ba.rotation.y = float(seat[1])
	ba.hold("")
	ba.play("Act_SitChair_Idle", 0.2)
	if ba.skel and ba.skel.find_bone("Wrist_R") >= 0:
		var bone := BoneAttachment3D.new()
		bone.bone_name = "Wrist_R"
		ba.skel.add_child(bone)
		bone.name = "QuatNan"
		var fan := Furniture.place(bone, "quat_nan", Vector3.ZERO, 0.0, false)
		fan.rotation_degrees = Vector3(0, 90, 0)
		var tw := fan.create_tween().set_loops()
		tw.tween_property(fan, "rotation_degrees:x", 28.0, 0.55).set_trans(Tween.TRANS_SINE)
		tw.tween_property(fan, "rotation_degrees:x", -8.0, 0.55).set_trans(Tween.TRANS_SINE)

static func don(ev: HomeEvents, _s: Dictionary) -> void:
	var porch := ev.map.get_node_or_null("BaRuHien") if ev.map else null
	if porch:
		porch.queue_free()
	var ba := ev._chibi(BA)
	if ba and ba.skel and ba.skel.has_node("QuatNan"):
		ba.skel.get_node("QuatNan").queue_free()
