class_name Npc
extends Node3D

static var clock := 0.0

const WALK := 1.15
const RUN := 2.6
const WALK_CLIP_SPEED := 0.78
const RUN_CLIP_SPEED := 1.65
const TURN := 7.0
const SIT_BACK := 0.28
const LOOK_NEAR := 2.2
const SPACE := 0.8
const TAG_COLORS := {"tung": Color("6fa8dc"), "ngan": Color("f08aa6"), "khoa": Color("8d6e5a"), "kien": Color("4a5568")}

var id := ""
var chibi: Chibi
var nav_map: RID
var seat := Vector3.ZERO
var seat_yaw := 0.0
var sitting := false
var seated_clip := "Act_SitChair_Type"
var chair: Node3D = null
var _chair_home := Transform3D()
var _chair_out := false
var _chair_tw: Tween
var token := 0
var bubble: SpeechBubble
var look_at_node: Node3D = null
var _look_target: Marker3D
var _look: LookAtModifier3D
var _body: AnimatableBody3D
var _shape: CollisionShape3D
var _heading := 0.0
var _stall := 0.0
var _squeeze := 0.0
var _yield := 1.0
const SQUEEZE_AFTER := 0.8
const CLEAR := 0.55
static var everyone: Array[Node3D] = []

func setup(person_id: String, look: Dictionary, map: RID) -> void:
	id = person_id
	nav_map = map
	chibi = Chibi.new()
	add_child(chibi)
	chibi.build(look)
	Beard.add(chibi, look)
	Glasses.add(chibi, look)
	FaceMask.add(chibi, look)
	Scarf.add(chibi, look)
	_heading = rotation.y
	bubble = SpeechBubble.new()
	bubble.name_color = TAG_COLORS.get(person_id, bubble.name_color)
	var k := chibi.size()
	bubble.position.y = 1.72 * (0.74 if k < 0.99 else 1.0)
	add_child(bubble)
	_body = AnimatableBody3D.new()
	_body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	_shape = cs
	var cap := CapsuleShape3D.new()
	cap.radius = 0.24 * k
	cap.height = 1.3 * k
	cs.shape = cap
	cs.position.y = 0.65 * k
	_body.add_child(cs)
	add_child(_body)
	_setup_look()
	everyone.append(self)
	tree_exiting.connect(func(): everyone.erase(self))

func _setup_look() -> void:
	if chibi.skel == null or chibi.skel.find_bone("Head") < 0:
		return
	_look_target = Marker3D.new()
	add_child(_look_target)
	_look = LookAtModifier3D.new()
	_look.bone_name = "Head"
	_look.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
	_look.primary_rotation_axis = Vector3.AXIS_Y
	_look.use_secondary_rotation = true
	_look.duration = 0.25
	_look.transition_type = Tween.TRANS_SINE
	_look.ease_type = Tween.EASE_IN_OUT
	_look.use_angle_limitation = true
	_look.symmetry_limitation = true
	_look.primary_limit_angle = deg_to_rad(140.0)
	_look.primary_damp_threshold = 0.8
	_look.secondary_limit_angle = deg_to_rad(60.0)
	_look.secondary_damp_threshold = 0.8
	_look.influence = 0.0
	chibi.skel.add_child(_look)
	_look.target_node = _look.get_path_to(_look_target)

func _process(delta: float) -> void:
	if everyone.size() > 0 and everyone[0] == self:
		clock += delta
	if _look == null:
		return
	var want := 0.0
	if look_at_node != null and is_instance_valid(look_at_node):
		var p := look_at_node.global_position + Vector3(0, 1.0, 0)
		var to := p - global_position
		to.y = 0.0
		var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
		if to.length() > 0.05 and fwd.dot(to.normalized()) > -0.3:
			_look_target.global_position = p
			want = 1.0
	_look.influence = move_toward(_look.influence, want, delta * 3.0)

func interrupt() -> void:
	token += 1

func wait(secs: float) -> bool:
	var tok := token
	var left := secs
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		if tok != token:
			return false
	return true

func walk_to(target: Vector3, run := false, exact := false) -> bool:
	"""Walk (or run) to target, then stop there. False if interrupted.
	The path is asked from the navigation mesh at once (map_get_path) and followed corner by corner,
	bending round people on the way (_steer) without ever stopping for them: the aisles take two.
	Progress is measured along the path, so a path that first leads away from the target is not "stuck".
	Unless exact (its own seat), a spot someone already stands on is moved aside on the way in.
	The player standing in the way: it slows and bends round; held up for SQUEEZE_AFTER it shows a drop of
	sweat and squeezes past side on, the body turned to them (sorry, coming through). It never stops on the
	player: arriving on them, it steps aside first."""
	if sitting and not await stand_up():
		return false
	if not exact:
		target = _free_spot(target)
	var tok := token
	var speed := RUN if run else WALK
	var clip := "Move_Run" if run else "Move_Walk"
	var clip_speed := RUN_CLIP_SPEED if run else WALK_CLIP_SPEED
	if chibi.tool == "cane":
		speed = Chibi.CANE_WALK_SPEED
		clip_speed = Chibi.CANE_WALK_SPEED
	if chibi.size() < 0.99:
		speed *= chibi.size() * Chibi.KID_CADENCE
		clip_speed *= chibi.size()
	_shape.set_deferred("disabled", true)
	var path := _path_to(target)
	var idx := 0
	var vel := Vector3.ZERO
	var moving := false
	var repicked := exact
	var best := INF
	var since_best := 0.0
	var stuck_total := 0.0
	var ghost := 0.0
	var walked := 0.0
	var held := 0.0
	var asides := 0
	_squeeze = 0.0
	while true:
		await get_tree().physics_frame
		if tok != token:
			_end_walk()
			return false
		var dt := get_physics_process_delta_time()
		walked += dt
		var flat := Vector3(global_position.x, 0, global_position.z)
		var to := target - flat
		if to.length() < 0.08:
			if asides < 2 and _on_player(target):
				asides += 1
				target = _aside(target)
				path = _path_to(target)
				idx = 0
				continue
			break
		if not repicked and to.length() < 1.2:
			repicked = true
			var t2 := _free_spot(target)
			if t2.distance_to(target) > 0.05:
				target = t2
				path = _path_to(target)
				idx = 0
			continue
		while idx < path.size() - 1 and flat.distance_to(path[idx]) < 0.25:
			idx += 1
		var aim: Vector3 = path[idx] - flat
		var last := idx == path.size() - 1
		var want := aim.normalized() * (minf(speed, aim.length() * 4.0 + 0.3) if last else speed)
		var safe := want
		if ghost > 0.0 or (last and aim.length() < 0.5):
			ghost = maxf(0.0, ghost - dt)
			_yield = 1.0
		else:
			safe = _steer(want)
		if _squeeze > 0.0:
			_squeeze -= dt
		elif _yield < 0.55:
			held += dt
			if held > SQUEEZE_AFTER:
				held = 0.0
				_squeeze = 1.4
				EmoteFx.play(chibi, "sweat", 0.0)
		else:
			held = maxf(0.0, held - dt)
		vel = vel.lerp(safe, 1.0 - exp(-dt * 10.0))
		global_position += vel * dt
		if not (last and aim.length() < 0.6):
			var on := NavigationServer3D.map_get_closest_point(nav_map, global_position)
			if Vector2(on.x - global_position.x, on.z - global_position.z).length() > 0.01:
				global_position = Vector3(on.x, 0.0, on.z)
		var sp := vel.length()
		if sp > 0.15:
			var yaw := atan2(vel.x, vel.z)
			var p := _player()
			if _squeeze > 0.0 and p:
				var tp: Vector3 = p.global_position - global_position
				yaw += PI * 0.5 * (1.0 if vel.cross(Vector3.UP).dot(tp) < 0.0 else -1.0)
			rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-dt * TURN))
		var go := sp > (0.12 if moving else 0.25)
		if go != moving:
			moving = go
			chibi.play(clip if go else "Base_Wait", 0.2)
		chibi.anim.speed_scale = (clampf(sp / clip_speed, 0.6, 2.0) if moving else 1.0) * (0.7 if _squeeze > 0.0 else 1.0)
		var left := _path_left(path, idx, flat)
		if left < best - 0.03:
			best = left
			since_best = 0.0
			stuck_total = 0.0
		else:
			since_best += dt
			stuck_total += dt
			if since_best > 1.5:
				if to.length() < 0.9 and not _on_player(flat):
					break
				path = _path_to(target)
				idx = 0
				if OS.has_environment("MC_LIFE_DEBUG"):
					print("REPATH %.1fs %s at %s to %s: %s" % [clock, id, flat, target, path])
				best = INF
				since_best = 0.0
			if stuck_total > 2.5:
				ghost = 1.5
				stuck_total = 0.0
		if OS.has_environment("MC_LIFE_DEBUG"):
			if sp < 0.1 and to.length() > 0.5:
				_stall += dt
				if fmod(_stall, 1.0) < dt and _stall > 2.0:
					print("  STUCKDBG %s pos=%s aim=%s idx=%d/%d want=%s ghost=%.1f" % [id, flat, path[idx], idx, path.size(), want, ghost])
			elif _stall > 0.5:
				print("STALL %.1fs %s %.1fs at %s to %s" % [clock, id, _stall, global_position, target])
				_stall = 0.0
			else:
				_stall = 0.0
			if walked > 20.0 and walked - dt <= 20.0:
				print("LONGWALK %.1fs %s at %s to %s" % [clock, id, global_position, target])
	_end_walk()
	return true

func _path_to(target: Vector3) -> PackedVector3Array:
	"""Corners from here to target on the floor (flattened); the target itself last, even off the mesh
	(the spot behind a chair)."""
	var raw := NavigationServer3D.map_get_path(nav_map, global_position, target, true)
	var out := PackedVector3Array()
	for p in raw:
		var q := Vector3(p.x, 0, p.z)
		if out.is_empty() or out[out.size() - 1].distance_to(q) > 0.05:
			out.append(q)
	if out.size() > 1 and out[0].distance_to(Vector3(global_position.x, 0, global_position.z)) < 0.05:
		out.remove_at(0)
	var gap := out[out.size() - 1].distance_to(target) if not out.is_empty() else INF
	if gap > 0.7:
		if OS.has_environment("MC_LIFE_DEBUG"):
			print("UNREACHABLE %.1fs %s from %s to %s" % [clock, id, global_position, target])
	elif gap > 0.05:
		out.append(Vector3(target.x, 0, target.z))
	if out.is_empty():
		out.append(Vector3(global_position.x, 0, global_position.z))
	return out

static func _path_left(path: PackedVector3Array, idx: int, from: Vector3) -> float:
	var d := from.distance_to(path[idx])
	for i in range(idx, path.size() - 1):
		d += path[i].distance_to(path[i + 1])
	return d

func _steer(want: Vector3) -> Vector3:
	"""Keep walking, just bend round people: someone ahead within a metre gets passed on the side they are
	not on (more the closer they are), and anyone overlapping is eased away from. It never stops and never
	turns back: the aisles are wide enough for two (office.gd), so a bend is always enough."""
	var speed := want.length()
	if speed < 0.01:
		return want
	var dir := want / speed
	var side := dir.cross(Vector3.UP)
	var bend := Vector3.ZERO
	for o in everyone:
		if o == self or not is_instance_valid(o):
			continue
		var to := o.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > 1.0 or d < 0.001:
			continue
		if to.dot(dir) > 0.0:
			bend -= side * (1.0 if side.dot(to) > 0.0 else -1.0) * (1.0 - d) * 1.3
		if d < 0.55:
			var apart := -to / d * (0.55 - d) * 2.0
			bend += apart - dir * apart.dot(dir)
	var p := _player()
	if _squeeze > 0.0 and p:
		var tp: Vector3 = p.global_position - global_position
		tp.y = 0.0
		if tp.length() < 1.1:
			bend -= side * (1.0 if side.dot(tp) > 0.0 else -1.0) * 1.2
	var v := dir + bend
	if v.dot(dir) < 0.35:
		v += dir * (0.35 - v.dot(dir))
	_yield = _yield_to_player(dir)
	return v.normalized() * speed * (0.6 if _squeeze > 0.0 else _yield)

func _yield_to_player(dir: Vector3) -> float:
	"""The player standing right in the way: slow down and let the bend carry it round, rather than barge
	through them (an NPC is never solid while it walks)."""
	for o in everyone:
		if o is Npc or not is_instance_valid(o):
			continue
		var to: Vector3 = o.global_position - global_position
		to.y = 0.0
		var ahead := to.dot(dir)
		var lateral := (to - dir * ahead).length()
		if ahead > 0.0 and lateral < 0.45:
			return clampf((to.length() - 0.5) / 0.4, 0.15, 1.0)
	return 1.0

func _player() -> Node3D:
	for o in everyone:
		if not (o is Npc) and is_instance_valid(o):
			return o
	return null

func _on_player(at: Vector3) -> bool:
	var p := _player()
	if p == null:
		return false
	return Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < CLEAR

func _aside(at: Vector3) -> Vector3:
	"""A spot next to the player instead of on them, on the floor, on this side of them."""
	var p := _player()
	var away := at - p.global_position
	away.y = 0.0
	if away.length() < 0.05:
		away = global_position - p.global_position
		away.y = 0.0
	if away.length() < 0.05:
		away = Vector3.RIGHT
	var t: Vector3 = p.global_position + away.normalized() * (CLEAR + 0.3)
	t = NavigationServer3D.map_get_closest_point(nav_map, t)
	return Vector3(t.x, 0, t.z)

func _end_walk() -> void:
	_shape.set_deferred("disabled", false)
	_stop()

func _free_spot(t: Vector3) -> Vector3:
	for i in 6:
		var moved := false
		for o in everyone:
			if o == self or not is_instance_valid(o):
				continue
			var away := t - o.global_position
			away.y = 0.0
			if away.length() < SPACE:
				var dir := away.normalized() if away.length() > 0.01 else (t - global_position).normalized()
				t = o.global_position + dir * SPACE
				t.y = 0.0
				moved = true
		if not moved:
			break
	return t

func _stop() -> void:
	chibi.anim.speed_scale = 1.0
	chibi.play("Base_Wait", 0.2)

func face_dir(yaw: float) -> bool:
	var tok := token
	while absf(angle_difference(rotation.y, yaw)) > 0.03:
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-get_process_delta_time() * TURN))
		await get_tree().process_frame
		if tok != token:
			return false
	rotation.y = yaw
	return true

func face_point(p: Vector3) -> bool:
	var to := p - global_position
	return await face_dir(atan2(to.x, to.z))

func act(clip: String, back := "") -> bool:
	"""Play a one-shot clip (Act_*, Tool_*, or a reaction Emo_*) and wait for it; then the base clip."""
	if not chibi.anim.has_animation(clip):
		return await wait(0.6)
	var tok := token
	if back != "":
		chibi._base_clip = back
	chibi.anim.speed_scale = 1.0
	chibi.anim.play(clip, 0.15)
	chibi.anim.queue(chibi._base_clip)
	var ok := await wait(chibi.anim.get_animation(clip).length - 0.1)
	return ok and tok == token

func emote(kind: String) -> bool:
	"""A reaction (data/emotes.json): body clip, face and the effect over the head."""
	var clip := str(Chibi.emotes.get(kind, {}).get("clip", ""))
	chibi.emote(kind)
	if clip == "" or not chibi.anim.has_animation(clip):
		return await wait(1.2)
	return await wait(chibi.anim.get_animation(clip).length - 0.1)

func say(key: String, args := {}, secs := 0.0) -> void:
	"""A speech bubble (data/i18n/strings.csv key), long enough to read."""
	var text := Lang.t(key, args)
	bubble.show_text(text, secs if secs > 0.0 else clampf(1.6 + text.length() * 0.06, 2.2, 5.0), false,
		tr("NAME_" + id.to_upper()))

func think(icon_text: String, secs := 2.0) -> void:
	"""A small thought bubble ("...", "?", "♪") without words to translate."""
	bubble.show_text(icon_text, secs, true)

func hold(t: String) -> void:
	chibi.hold(t)

func sit_down() -> bool:
	"""From the spot behind its chair: scoot back into the seat and settle to work. The chair waits rolled
	out to the side (where it was left) and slides in under it as it sits."""
	if sitting:
		return true
	var back := -Vector3(sin(seat_yaw), 0, cos(seat_yaw))
	if not _chair_out and global_position.distance_to(seat_spot()) > 0.5:
		if not await walk_to(seat_spot() + back * 0.35):
			return false
		roll_chair(true, 0.3)
		if not await wait(0.3):
			return false
	if not await walk_to(seat_spot(), false, true):
		return false
	if not await face_dir(seat_yaw):
		return false
	global_position = seat
	rotation.y = seat_yaw
	sitting = true
	roll_chair(false, 0.6)
	if chibi.size() < 0.99:
		create_tween().tween_property(chibi, "position:y", chibi.seat_lift(), 0.5).set_trans(Tween.TRANS_SINE)
	await act("Act_SitChair_Down", seated_clip)
	chibi.play(seated_clip, 0.2)
	return true

func stand_up() -> bool:
	if not sitting:
		return true
	sitting = false
	chibi.play("Base_Wait", 0.0)
	chibi._base_clip = "Base_Wait"
	if chibi.position.y != 0.0:
		create_tween().tween_property(chibi, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	roll_chair(true, 0.35)
	if chibi.anim.has_animation("Act_SitChair_Up"):
		chibi.anim.play("Act_SitChair_Up", 0.12)
		chibi.anim.queue("Base_Wait")
		await get_tree().create_timer(chibi.anim.get_animation("Act_SitChair_Up").length).timeout
	global_position = seat_spot()
	chibi.anim.play("Base_Wait", 0.0)
	return true

func set_chair(c: Node3D) -> void:
	chair = c
	_chair_home = c.transform

func roll_chair(out: bool, secs: float) -> void:
	"""Roll the chair half a metre to the sitter's right and a little back, turned askew (out), or home."""
	if chair == null or out == _chair_out:
		return
	_chair_out = out
	var t := _chair_home
	if out:
		var fwd := Vector3(sin(seat_yaw), 0, cos(seat_yaw))
		t = Transform3D(_chair_home.basis.rotated(Vector3.UP, deg_to_rad(-25.0)),
			_chair_home.origin + fwd.cross(Vector3.UP) * 0.48 - fwd * 0.2)
	if _chair_tw:
		_chair_tw.kill()
	_chair_tw = create_tween()
	_chair_tw.tween_property(chair, "transform", t, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func seat_spot() -> Vector3:
	return seat - Vector3(sin(seat_yaw), 0, cos(seat_yaw)) * SIT_BACK

func set_seated(clip: String) -> void:
	"""Change what it does in the chair (type, idle, nap) without getting up."""
	seated_clip = clip
	if sitting:
		chibi.play(clip, 0.4)

func place_seated() -> void:
	"""Start the scene already at work in its chair."""
	global_position = seat
	rotation.y = seat_yaw
	_heading = seat_yaw
	sitting = true
	chibi.position.y = chibi.seat_lift()
	chibi.play(seated_clip, 0.0)
	chibi.anim.seek(randf() * 1.5, true)
