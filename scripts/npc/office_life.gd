class_name OfficeLife
extends Node3D

const DATA := "res://data/office_life.json"
const BOSS_SEAT := [Vector3(3.0, 0, -2.7), 0.0]
const BOSS_DOOR := Vector3(2.8, 0, -0.35)

var SPOTS := {
	"coffee": [Vector3(-3.42, 0, 1.65), -PI / 2], "coffee_wait": [Vector3(-2.9, 0, 2.6), -2.2],
	"cooler": [Vector3(-3.72, 0, 0.75), -PI / 2], "cooler_b": [Vector3(-2.9, 0, 0.95), -1.81],
	"printer": [Vector3(3.45, 0, 1.3), PI / 2], "printer_aside": [Vector3(2.6, 0, 1.5), 1.45],
	"window_1": [Vector3(-3.3, 0, -3.1), PI], "window_2": [Vector3(-1.9, 0, -3.1), PI],
	"window_3": [Vector3(-0.6, 0, -3.1), PI], "basil": [Vector3(0.9, 0, -3.08), PI],
	"whiteboard": [Vector3(-3.95, 0, -2.5), -PI / 2],
}
const CAUGHT := ["window", "phone", "stretch", "chat", "cooler", "whiteboard", "basil"]

var office
var life_speed := 1.0
var people := {}
var boss: NpcBrain
var nav_map: RID
var _near := {}
var _desk_cups := {}
var _claims := {}
var box: TalkBox
var talking := false
var _told := {}
var _prompt: Button
var _prompt_for: NpcBrain

func setup(p_office) -> void:
	office = p_office
	life_speed = maxf(0.1, float(Stage.arg("--life-speed", "1")))
	if Stage.arg("--seed") != "":
		seed(int(Stage.arg("--seed")))
	_bake_nav()
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var chars = JSON.parse_string(FileAccess.get_file_as_string(office.CHARS))
	for id in data["people"]:
		var p: Dictionary = data["people"][id]
		var npc := Npc.new()
		add_child(npc)
		var l := Looks.DEFAULT.duplicate(true)
		l.merge(chars[id]["look"], true)
		npc.setup(id, l, nav_map)
		if str(p["seat"]) == "boss":
			npc.seat = BOSS_SEAT[0]
			npc.seat_yaw = BOSS_SEAT[1]
		else:
			var st: Array = office.seat(p["seat"][0], int(p["seat"][1]))
			npc.seat = st[0]
			npc.seat_yaw = st[1]
		for c in office.world.get_children():
			if c is Node3D and str(c.scene_file_path).ends_with("office_chair.glb") 					and Vector2(c.position.x - npc.seat.x, c.position.z - npc.seat.z).length() < 0.05:
				npc.set_chair(c)
		npc.place_seated()
		var b := NpcBrain.new()
		npc.add_child(b)
		b.setup(npc, self, p["traits"])
		b.set_meta("boss", p.get("boss", false))
		people[id] = b
		if p.get("boss", false):
			boss = b
			b.rest("patrol", 22.0)
	for id in people:
		if id != "kien":
			people[id].rest("coffee_round", 12.0)
	Npc.everyone.append(office.player)
	Npc.clock = 0.0
	Net.acted.connect(_on_acted)
	if OS.has_environment("MC_LIFE_DEBUG"):
		_check_reach.call_deferred()

func _check_reach() -> void:
	"""Debug: can everyone get everywhere? Every spot, seat and door from the middle of the room."""
	for i in 30:
		await get_tree().physics_frame
	var targets := {}
	for k in SPOTS:
		targets[k] = SPOTS[k][0]
	for b in people.values():
		targets["seat_" + b.npc.id] = b.npc.seat_spot()
	targets["boss_door"] = BOSS_DOOR
	var bad := 0
	for from in [Vector3(-1.0, 0, 1.5), BOSS_SEAT[0] + Vector3(0, 0, -0.28)]:
		for k in targets:
			var path := NavigationServer3D.map_get_path(nav_map, from, targets[k], true)
			var gap: float = INF if path.is_empty() else Vector3(path[path.size() - 1].x, 0, path[path.size() - 1].z).distance_to(targets[k])
			if gap > 0.7:
				bad += 1
				print("REACH FAIL from %s to %s %s (gap %.2f)" % [from, k, targets[k], gap])
	print("REACH checked %d targets, %d unreachable" % [targets.size() * 2, bad])

func chibis() -> Array:
	return people.values().map(func(b): return b.npc.chibi)

func _bake_nav() -> void:
	nav_map = get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(nav_map, 0.05)
	NavigationServer3D.map_set_cell_height(nav_map, 0.05)
	var nm := NavigationMesh.new()
	nm.cell_size = 0.05
	nm.cell_height = 0.05
	nm.agent_radius = 0.24
	nm.agent_height = 1.2
	nm.agent_max_climb = 0.05
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.filter_baking_aabb = AABB(Vector3(-5, -0.5, -4), Vector3(10, 3, 8))
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, office.world)
	var hx: float = office.ROOM.x / 2.0
	var hz: float = office.ROOM.y / 2.0
	src.add_faces(PackedVector3Array([Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz),
		Vector3(-hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]), Transform3D.IDENTITY)
	var chairs := []
	for x in office.DESK_X:
		chairs.append(Vector3(x, 0, office.ROW_FRONT + office.SEAT_OFF))
		chairs.append(Vector3(x, 0, office.ROW_BACK - office.SEAT_OFF))
	for c in chairs:
		var r := 0.22
		src.add_projected_obstruction(PackedVector3Array([c + Vector3(-r, 0, -r), c + Vector3(r, 0, -r),
			c + Vector3(r, 0, r), c + Vector3(-r, 0, r)]), 0.0, 1.0, false)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nm
	add_child(region)

func home(b: NpcBrain) -> bool:
	"""Back to its own chair; true once seated."""
	if b.npc.sitting:
		return true
	if not await b.npc.sit_down():
		return false
	b.npc.hold("")
	_cup_on_desk(b)
	return true

func activities_for(b: NpcBrain) -> Array:
	var n := b.needs
	var tr_ := func(k: String) -> float: return b.trait_of(k, 0.3)
	var list := []
	if b == boss:
		list.append({"name": "patrol", "score": 0.9, "run": _patrol.bind(b)})
		list.append({"name": "phone_call", "score": 0.35 + (1.0 - n["fun"]) * 0.3, "run": _phone_call.bind(b)})
		list.append({"name": "coffee", "score": (1.0 - n["thirst"]) * 0.9, "run": _coffee.bind(b)})
		return list
	var boss_near := boss != null and boss.npc.global_position.distance_to(b.npc.global_position) < 3.5
	var k := 0.15 if boss_near else 1.0
	list.append({"name": "coffee", "score": k * ((1.0 - n["thirst"]) * (0.45 + tr_.call("coffee") * 0.6) + (1.0 - n["energy"]) * 0.25), "run": _coffee.bind(b)})
	list.append({"name": "stretch", "score": k * ((1.0 - n["fun"]) * 0.45 + (1.0 - n["energy"]) * 0.25), "run": _stretch.bind(b)})
	list.append({"name": "window", "score": k * (1.0 - n["fun"]) * (0.3 + tr_.call("restless") * 0.5), "run": _window.bind(b)})
	list.append({"name": "phone", "score": k * (1.0 - n["fun"]) * 0.45, "run": _phone.bind(b)})
	list.append({"name": "printer", "score": k * 0.5, "run": _printer.bind(b)})
	list.append({"name": "whiteboard", "score": k * 0.3 + (1.0 - n["fun"]) * 0.15, "run": _whiteboard.bind(b)})
	list.append({"name": "cooler", "score": k * ((1.0 - n["thirst"]) * 0.35 + (1.0 - n["social"]) * 0.35), "run": _cooler.bind(b)})
	var friend := _free_partner(b)
	if friend:
		list.append({"name": "chat", "score": k * (1.0 - n["social"]) * (0.3 + tr_.call("social") * 0.6), "run": _visit.bind(b, friend)})
	if tr_.call("plants") > 0.5:
		list.append({"name": "basil", "score": k * (0.25 + (1.0 - n["fun"]) * 0.5) * tr_.call("plants"), "run": _basil.bind(b)})
	if tr_.call("barista") > 0.5:
		var tired := _most_tired(b)
		if tired:
			list.append({"name": "coffee_round", "score": k * (1.0 - tired.needs["energy"]) * 1.1, "run": _coffee_round.bind(b, tired)})
	if n["energy"] < 0.25:
		list.append({"name": "nap", "score": (0.25 - n["energy"]) * 4.0 * (0.4 + tr_.call("sleepy")), "run": _nap.bind(b)})
	return list

func _free_partner(b: NpcBrain) -> NpcBrain:
	var free := people.values().filter(func(o): return o != b and o != boss and not o.engaged and o.doing == "work")
	return free.pick_random() if not free.is_empty() else null

func _most_tired(b: NpcBrain) -> NpcBrain:
	var best: NpcBrain = null
	for o in people.values():
		if o != b and o != boss and not o.engaged and o.doing == "work" and (best == null or o.needs["energy"] < best.needs["energy"]):
			best = o
	return best if best and best.needs["energy"] < 0.55 else null

func line(id: String, topic: String) -> String:
	"""A random existing L_<ID>_<TOPIC>_<n> key (or L_ANY_...), "" if there is none."""
	var keys := []
	for who in [id.to_upper(), "ANY"]:
		for i in range(1, 6):
			var key := "L_%s_%s_%d" % [who, topic, i]
			if tr(key) != key:
				keys.append(key)
		if not keys.is_empty():
			break
	return keys.pick_random() if not keys.is_empty() else ""

func _say(b: NpcBrain, topic: String, chance := 1.0) -> void:
	var key := line(b.npc.id, topic)
	if key != "" and randf() <= chance:
		b.npc.say(key)

func _spot(name: String) -> Vector3:
	return SPOTS[name][0]

func _go(b: NpcBrain, spot: String) -> bool:
	_claims[spot] = b
	if not await b.npc.walk_to(SPOTS[spot][0]):
		return false
	return await b.npc.face_dir(SPOTS[spot][1])

func release(b: NpcBrain) -> void:
	"""Its activity is over: the spots it held are free again (NpcBrain calls this)."""
	for s in _claims.keys():
		if _claims[s] == b:
			_claims.erase(s)

func _taken(spot: String, me: NpcBrain) -> bool:
	if _claims.has(spot) and _claims[spot] != me:
		return true
	for o in people.values():
		if o != me and o.npc.global_position.distance_to(SPOTS[spot][0]) < 0.45:
			return true
	return false

func _cup_on_desk(b: NpcBrain) -> void:
	if not b.has_meta("cup") or b == boss:
		return
	b.remove_meta("cup")
	if _desk_cups.has(b.npc.id) and is_instance_valid(_desk_cups[b.npc.id]):
		_desk_cups[b.npc.id].queue_free()
	var fwd := Vector3(sin(b.npc.seat_yaw), 0, cos(b.npc.seat_yaw))
	var right := fwd.cross(Vector3.UP)
	var at: Vector3 = b.npc.seat + fwd * 0.4 + right * -0.32
	at.y = OfficeProps.TOP
	_desk_cups[b.npc.id] = Furniture.place(office.world, "coffee_cup", at, randf() * 360.0, false)

func _coffee(b: NpcBrain) -> void:
	b.rest("coffee", 70.0)
	if _taken("coffee", b):
		if not await _go(b, "coffee_wait"):
			return
		b.npc.think("...", 2.0)
		for i in 20:
			if not _taken("coffee", b):
				break
			if not await b.npc.wait(0.6):
				return
	if not await _go(b, "coffee"):
		return
	if not await b.npc.act("Act_Press"):
		return
	b.npc.think("♨", 2.4)
	if not await b.npc.wait(2.4):
		return
	b.npc.hold("cup")
	b.set_meta("cup", true)
	_say(b, "COFFEE", 0.6)
	await b.npc.act("Tool_Cup_Drink")
	b.fill("thirst", 0.8)
	b.fill("energy", 0.35)

func _coffee_round(b: NpcBrain, to: NpcBrain) -> void:
	"""Khoa makes phin coffee and brings it to whoever is most tired."""
	b.rest("coffee_round", 140.0)
	to.engaged = true
	if not await _go(b, "coffee"):
		to.engaged = false
		return
	await b.npc.act("Act_Press")
	b.npc.think("♨", 2.4)
	await b.npc.wait(2.4)
	b.npc.hold("cup")
	var fwd := Vector3(sin(to.npc.seat_yaw), 0, cos(to.npc.seat_yaw))
	var side := to.npc.seat + fwd.cross(Vector3.UP) * 0.62 - fwd * 0.05
	if not await b.npc.walk_to(side):
		to.engaged = false
		return
	await b.npc.face_point(to.npc.global_position)
	b.npc.look_at_node = to.npc
	to.npc.look_at_node = b.npc
	b.npc.say("L_KHOA_OFFER_1")
	await b.npc.wait(2.2)
	b.npc.hold("")
	to.npc.say(line(to.npc.id, "THANKS"))
	EmoteFx.play(to.npc.chibi, "heart", 0.0)
	to.fill("energy", 0.5)
	to.fill("social", 0.3)
	to.set_meta("cup", true)
	_cup_on_desk(to)
	await b.npc.emote("happy")
	b.npc.look_at_node = null
	to.npc.look_at_node = null
	to.engaged = false
	b.fill("social", 0.4)

func _stretch(b: NpcBrain) -> void:
	b.rest("stretch", 60.0)
	if not await b.npc.stand_up():
		return
	await b.npc.face_dir(b.npc.seat_yaw + PI)
	_say(b, "STRETCH", 0.7)
	if b.npc.chibi.anim.has_animation("Act_Stretch"):
		await b.npc.act("Act_Stretch")
	else:
		await b.npc.emote("sleepy")
	b.fill("fun", 0.3)
	b.fill("energy", 0.1)

func _window(b: NpcBrain) -> void:
	b.rest("window", 80.0)
	var free := ["window_1", "window_2", "window_3"].filter(func(s): return not _taken(s, b))
	if free.is_empty():
		return
	if not await _go(b, free.pick_random()):
		return
	b.npc.think("...", 2.5)
	if not await b.npc.wait(3.0):
		return
	_say(b, "WINDOW")
	if not await b.npc.wait(2.5):
		return
	await b.npc.emote("think" if randf() < 0.5 else "sleepy" if b.trait_of("sleepy") > 0.6 else "happy")
	b.fill("fun", 0.5)

func _phone(b: NpcBrain) -> void:
	b.rest("phone", 90.0)
	if not await b.npc.stand_up():
		return
	await b.npc.face_dir(b.npc.seat_yaw + PI * 0.5)
	b.npc.chibi.play("Act_PhoneLook" if b.npc.chibi.anim.has_animation("Act_PhoneLook") else "Base_Wait")
	if not await b.npc.wait(3.5):
		return
	_say(b, "PHONE")
	if not await b.npc.wait(2.5):
		return
	b.npc.chibi.play("Base_Wait")
	await b.npc.emote("laugh" if randf() < 0.5 else "love")
	b.fill("fun", 0.5)

func _whiteboard(b: NpcBrain) -> void:
	b.rest("whiteboard", 150.0)
	if _taken("whiteboard", b) or not await _go(b, "whiteboard"):
		return
	await b.npc.emote("think")
	await b.npc.emote("idea")
	_say(b, "IDEA")
	await b.npc.wait(1.5)
	b.fill("fun", 0.2)

func _printer(b: NpcBrain) -> void:
	"""Printing something; on the clumsy it jams, and someone helpful comes to sort it out."""
	b.rest("printer", 110.0)
	if _taken("printer", b) or not await _go(b, "printer"):
		return
	await b.npc.act("Act_Press")
	if not await b.npc.wait(1.5):
		return
	if randf() > 0.2 + b.trait_of("clumsy") * 0.6:
		await b.npc.emote("happy")
		return
	b.engaged = true
	_say(b, "JAM")
	await b.npc.emote("confused")
	await b.npc.act("Act_Bang")
	var helper := _helper_for(b, _spot("printer"))
	if helper == null:
		await b.npc.act("Act_Bang")
		await b.npc.emote("surprised")
		await b.npc.emote("happy")
		return
	await b.npc.emote("sad")
	if helper.react(_help_printer.bind(helper, b), 3, "help"):

		await b.npc.walk_to(_spot("printer_aside"), false, true)
		await b.npc.face_point(_spot("printer") + Vector3(0.6, 0, 0))
		for i in 40:
			if not helper.engaged and i > 3:
				break
			b.npc.look_at_node = helper.npc
			if not await b.npc.wait(0.5):
				break
	b.npc.look_at_node = null
	b.engaged = false

func _help_printer(h: NpcBrain, who: NpcBrain) -> void:
	h.engaged = true
	for i in 12:
		if who.npc.global_position.distance_to(_spot("printer")) > 0.5:
			break
		await h.npc.wait(0.25)
	if await _go(h, "printer"):
		h.npc.look_at_node = who.npc
		_say(h, "HELP")
		await h.npc.wait(1.2)
		h.npc.look_at_node = null
		await h.npc.face_dir(PI / 2)
		await h.npc.act("Act_Press")
		await h.npc.act("Act_Bang")
		await h.npc.emote("idea")
		_say(h, "FIXED")
		EmoteFx.play(who.npc.chibi, "sparkle", 0.0)
		who.npc.say(line(who.npc.id, "THANKS"))
		h.fill("social", 0.3)
		await h.npc.emote("clap")
	h.npc.look_at_node = null
	h.engaged = false

func _helper_for(b: NpcBrain, near: Vector3) -> NpcBrain:
	var best: NpcBrain = null
	var best_d := 99.0
	for o in people.values():
		if o == b or o == boss or o.engaged or o.busy_with_priority() > 1 or o.trait_of("helpful") < 0.5:
			continue
		var d: float = o.npc.global_position.distance_to(near)
		if d < best_d:
			best = o
			best_d = d
	return best

func _basil(b: NpcBrain) -> void:
	"""Ngân fills a cup at the water cooler and waters her basil on the windowsill."""
	b.rest("basil", 120.0)
	if not _taken("cooler", b):
		if await _go(b, "cooler"):
			await b.npc.act("Act_Press")
			b.npc.hold("cup")
	if not await _go(b, "basil"):
		return
	await b.npc.act("Tool_Cup_Pour" if b.npc.chibi.anim.has_animation("Tool_Cup_Pour") else "Act_Press")
	EmoteFx.play(b.npc.chibi, "flower", 0.0)
	_say(b, "BASIL")
	await b.npc.wait(1.0)
	await b.npc.emote("happy")
	b.npc.hold("")
	b.fill("fun", 0.6)

func _cooler(b: NpcBrain) -> void:
	"""A cup of water - and if someone else is there, a little chat."""
	b.rest("cooler", 80.0)
	var other: NpcBrain = null
	for o in people.values():
		if o != b and o != boss and o.doing == "cooler" and not o.engaged:
			other = o
	var spot := "cooler_b" if _taken("cooler", b) else "cooler"
	if not await _go(b, spot):
		return
	if spot == "cooler":
		await b.npc.act("Act_Press")
		b.npc.hold("cup")
		await b.npc.act("Tool_Cup_Drink")
	if other and other.npc.global_position.distance_to(b.npc.global_position) < 1.5:
		other.engaged = true
		await converse(b, other)
		other.engaged = false
	else:
		await b.npc.wait(1.5)
	b.npc.hold("")
	b.fill("thirst", 0.5)

func _visit(b: NpcBrain, to: NpcBrain) -> void:
	"""Over to a coworker's desk for a chat (they swivel round and chat from the chair)."""
	b.rest("chat", 90.0)
	if to.engaged or to.doing != "work":
		return
	to.engaged = true
	var fwd := Vector3(sin(to.npc.seat_yaw), 0, cos(to.npc.seat_yaw))
	var side := to.npc.seat - fwd.cross(Vector3.UP) * 0.62 - fwd * 0.1
	if await b.npc.walk_to(side):
		await b.npc.face_point(to.npc.global_position)
		await converse(b, to)
	to.engaged = false

func converse(a: NpcBrain, b: NpcBrain) -> bool:
	"""A three-line chat (CONVO_<n>_A/B/C): A opens, B answers, A closes, and someone laughs."""
	var n := randi_range(1, 6)
	a.npc.look_at_node = b.npc
	b.npc.look_at_node = a.npc
	var b_seated := b.npc.sitting
	if b_seated:
		b.npc.set_seated("Act_SitChair_Idle" if b.npc.chibi.anim.has_animation("Act_SitChair_Idle") else b.npc.seated_clip)
	a.npc.chibi.play("Act_Talk" if a.npc.chibi.anim.has_animation("Act_Talk") else "Base_Wait")
	a.npc.say("CONVO_%d_A" % n)
	var ok := await a.npc.wait(2.6)
	if ok:
		a.npc.chibi.play("Act_Listen" if a.npc.chibi.anim.has_animation("Act_Listen") else "Base_Wait")
		if not b_seated:
			b.npc.chibi.play("Act_Talk" if b.npc.chibi.anim.has_animation("Act_Talk") else "Base_Wait")
		b.npc.say("CONVO_%d_B" % n)
		ok = await a.npc.wait(2.6)
	if ok:
		a.npc.chibi.play("Base_Wait")
		if not b_seated:
			b.npc.chibi.play("Base_Wait")
		a.npc.say("CONVO_%d_C" % n)
		EmoteFx.play(b.npc.chibi, "note", 0.2)
		ok = await a.npc.emote("laugh")
	if b_seated:
		b.npc.set_seated("Act_SitChair_Type")
	a.npc.look_at_node = null
	b.npc.look_at_node = null
	a.fill("social", 0.6)
	b.fill("social", 0.5)
	return ok

func _nap(b: NpcBrain) -> void:
	"""Too tired: a nap on the desk (with little z's) until rested, or until someone notices."""
	b.rest("nap", 120.0)
	var fwd := Vector3(sin(b.npc.seat_yaw), 0, cos(b.npc.seat_yaw))
	b.npc.global_position = b.npc.seat - fwd * 0.22
	b.npc.set_seated("Act_SitChair_Slump")
	while b.needs["energy"] < 0.7:
		EmoteFx.play(b.npc.chibi, "z", 0.0)
		if not await b.npc.wait(2.6):
			break
		b.fill("energy", 0.05)
	b.npc.set_seated("Act_SitChair_Type")
	b.npc.global_position = b.npc.seat

func _patrol(k: NpcBrain) -> void:
	"""Kiên's rounds: along the front aisle, round the end, along the back aisle, and home. He stops
	behind each person; a napper gets an 'Ahem!', the others a word about the deadline."""
	k.rest("patrol", randf_range(70.0, 110.0))

	var route := [[BOSS_DOOR, null], [Vector3(1.35, 0, 0.7), null], [Vector3(-2.65, 0, 0.62), "tung"], [Vector3(-1.6, 0, 0.62), "player"],
		[Vector3(1.35, 0, 0.7), null], [Vector3(1.4, 0, -2.85), null], [Vector3(-0.3, 0, -2.85), "ngan"],
		[Vector3(-2.9, 0, -2.85), "khoa"], [Vector3(1.4, 0, -2.85), null], [Vector3(1.35, 0, 0.7), null],
		[BOSS_DOOR, null]]
	for leg in route:
		if not await k.npc.walk_to(leg[0]):
			return
		if leg[1] != null and people.has(leg[1]):
			await _check_on(k, people[leg[1]])
		elif leg[1] == "player":
			await _check_on_player(k)
	k.fill("fun", 0.4)

func _check_on_player(k: NpcBrain) -> void:
	"""Behind a player who is working at a desk: a word of praise (and the player gets a little boost)."""
	var w = office.work
	if w == null or not w.working:
		return
	var player: Node3D = office.player
	if player.global_position.distance_to(k.npc.global_position) > 1.6:
		return
	await k.npc.face_point(player.global_position)
	k.npc.look_at_node = player
	_say(k, "GOODJOB")
	EmoteFx.play(player.chibi, "sparkle", 0.3)
	w.progress = minf(1.0, w.progress + 0.05)
	await k.npc.wait(2.2)
	k.npc.look_at_node = null

func _check_on(k: NpcBrain, p: NpcBrain) -> void:
	if not p.npc.sitting or p.engaged:
		return
	await k.npc.face_point(p.npc.global_position)
	k.npc.look_at_node = p.npc
	if p.doing == "nap":
		k.npc.say("L_KIEN_WAKE_1")
		await k.npc.wait(0.6)
		p.react(_woken.bind(p, k), 7, "woken")
		await k.npc.wait(2.6)
		await k.npc.emote("angry")
		k.npc.say("L_KIEN_HMM_1")
		await k.npc.wait(1.6)
	elif randf() < 0.6:
		_say(k, "PATROL")
		await k.npc.wait(1.6)
		p.npc.look_at_node = k.npc
		p.npc.say("L_ANY_REPLY_1")
		EmoteFx.play(p.npc.chibi, "sweat", 0.2)
		await k.npc.wait(1.8)
		p.npc.look_at_node = null
	else:
		k.npc.think("...", 1.6)
		await k.npc.wait(1.8)
	k.npc.look_at_node = null

func _woken(p: NpcBrain, k: NpcBrain) -> void:
	p.npc.set_seated("Act_SitChair_Type")
	p.npc.global_position = p.npc.seat
	EmoteFx.play(p.npc.chibi, "exclaim", 0.0)
	p.npc.look_at_node = k.npc
	await p.npc.wait(0.5)
	p.npc.say("L_ANY_WAKE_1")
	await p.npc.wait(3.0)
	EmoteFx.play(p.npc.chibi, "sweat", 0.0)
	p.npc.look_at_node = null
	p.fill("energy", 0.3)

func _phone_call(k: NpcBrain) -> void:
	"""On the phone in his office: the client, then (quietly) his little girl."""
	k.rest("phone_call", 100.0)
	if not await k.npc.stand_up():
		return
	await k.npc.face_dir(PI * 0.75)
	k.npc.chibi.play("Act_Talk" if k.npc.chibi.anim.has_animation("Act_Talk") else "Base_Wait")
	k.npc.say("L_KIEN_PHONE_1")
	if not await k.npc.wait(3.2):
		return
	if randf() < 0.5:
		await k.npc.emote("nervous")
	else:
		k.npc.chibi.play("Act_PhoneLook" if k.npc.chibi.anim.has_animation("Act_PhoneLook") else "Base_Wait")
		k.npc.say("L_KIEN_PHONE_2")
		if not await k.npc.wait(3.0):
			return
		EmoteFx.play(k.npc.chibi, "heart", 0.0)
		await k.npc.wait(1.5)
	k.npc.chibi.play("Base_Wait")
	k.fill("fun", 0.4)

func _panic(p: NpcBrain) -> void:
	"""Caught away from the desk by the boss: a jump, an excuse, and a run back to the chair."""
	p.npc.hold("")
	EmoteFx.play(p.npc.chibi, "exclaim", 0.0)
	if boss:
		p.npc.look_at_node = boss.npc
	await p.npc.wait(0.4)
	_say(p, "PANIC")
	if p.npc.chibi.anim.has_animation("Act_LookAround"):
		await p.npc.act("Act_LookAround")
	else:
		await p.npc.emote("nervous")
	p.npc.look_at_node = null
	if await p.npc.walk_to(p.npc.seat_spot(), true, true):
		await p.npc.sit_down()
		EmoteFx.play(p.npc.chibi, "sweat", 0.0)
		if boss and randf() < 0.5:
			boss.npc.say("L_KIEN_HMM_1")

var _dbg_t := 0.0

func _process(_delta: float) -> void:
	_update_prompt()
	if OS.has_environment("MC_LIFE_DEBUG"):
		_dbg_t += _delta
		if _dbg_t > 1.0:
			_dbg_t = 0.0
			if int(Npc.clock) % 5 == 0:
				for b in people.values():
					print("POS %.0fs %s %s %s seated=%s" % [Npc.clock, b.npc.id, b.doing, b.npc.global_position, b.npc.sitting])
				print("PLAYERPOS %.0fs %s" % [Npc.clock, office.player.global_position])
			var ps := people.values()
			for i in ps.size():
				for j in range(i + 1, ps.size()):
					var d: float = ps[i].npc.global_position.distance_to(ps[j].npc.global_position)
					if d < 0.65:
						print("CLOSE %.1fs %s(%s %s) %s(%s %s) d=%.2f" % [Npc.clock, ps[i].npc.id, ps[i].doing,
							ps[i].npc.global_position, ps[j].npc.id, ps[j].doing, ps[j].npc.global_position, d])
	if boss:
		var bp := boss.npc.global_position
		for p in people.values():
			if p == boss or not p.doing in CAUGHT or not p.ready_for("panic"):
				continue
			if p.npc.global_position.distance_to(bp) < 3.0 and boss.doing in ["patrol", "coffee"]:
				p.rest("panic", 25.0)
				p.react(_panic.bind(p), 6, "panic")
	var player: Node3D = office.player
	for b in people.values():
		var d: float = b.npc.global_position.distance_to(player.global_position)
		var engaged_look: bool = b.npc.look_at_node != null and b.npc.look_at_node != player
		if not engaged_look:
			b.npc.look_at_node = player if d < Npc.LOOK_NEAR else null
		var near := d < 1.6
		if near and not talking and not _near.get(b.npc.id, false) and b.ready_for("greet") and b.busy_with_priority() <= 1 and not b.engaged:
			b.rest("greet", 35.0)
			_say(b, "HI")
		_near[b.npc.id] = near

func _on_acted(id: int, kind: String, arg: String) -> void:
	"""The player waved or cheered: the nearest person answers in kind."""
	if id != Net.my_id() or kind != "emote":
		return
	var player: Node3D = office.player
	var best: NpcBrain = null
	var best_d := 3.2
	for b in people.values():
		var d: float = b.npc.global_position.distance_to(player.global_position)
		if d < best_d and not b.engaged:
			best = b
			best_d = d
	if best:
		best.react(_answer.bind(best, arg), 4, "answer")

func _answer(b: NpcBrain, kind: String) -> void:
	var player: Node3D = office.player
	b.npc.look_at_node = player
	if b.npc.sitting:
		EmoteFx.play(b.npc.chibi, "hand" if kind == "wave" else "note", 0.0)
		_say(b, "HI" if kind == "wave" else "YAY")
		await b.npc.wait(2.2)
	else:
		await b.npc.face_point(player.global_position)
		_say(b, "HI" if kind == "wave" else "YAY")
		await b.npc.emote("wave" if kind == "wave" else "clap")
	b.fill("social", 0.3)

const TALK_NEAR := 1.9
const TALK_SHOW := 1.7
const TALK_REACH := 2.5

const TOPIC_FACES := {"HI": "smile", "CHAT": "happy", "MOOD_TIRED": "sleepy", "MOOD_THIRSTY": "worried",
	"MOOD_BORED": "bored", "MOOD_LONELY": "lonely", "MOOD_GOOD": "happy", "BYE": "smile"}
const LINE_FACES := {"L_TUNG_CHAT_1": "shocked", "L_TUNG_CHAT_2": "worried", "L_TUNG_CHAT_3": "sly",
	"L_NGAN_CHAT_1": "excited", "L_NGAN_CHAT_3": "smile", "L_KIEN_CHAT_2": "annoyed", "L_KIEN_CHAT_3": "sad",
	"L_KIEN_MOOD_GOOD_1": "calm", "L_TUNG_HI_2": "bored"}
const PERSON_FACES := {"khoa": "calm", "kien": "calm"}

func setup_talk(layer: CanvasLayer, pick: ClickPick) -> void:
	box = TalkBox.new()
	TouchControls.add_action(self, func() -> Dictionary:
		if _prompt_for == null or talking:
			return {}
		return {"label": Lang.t("TC_TALK", {"name": tr("NAME_" + _prompt_for.npc.id.to_upper())}),
			"run": talk_to.bind(_prompt_for)}, 30)
	layer.add_child(box)
	Bonds.ensure()
	_story_hints()
	var who := Stage.arg("--talk")
	if who != "" and people.has(who):
		var h := int(Stage.arg("--hearts", "-1"))
		if h >= 0:
			Bonds.points[who] = Bonds.HEART_AT[h]
			Bonds.told.clear()
			for s in Bonds.data.get("people", {}).get(who, {}).get("stories", []):
				if int(s.get("hearts", 0)) < h:
					Bonds.told[s["id"]] = true
		TalkBox.auto_secs = float(Stage.arg("--talk-secs", "2.2"))
		TalkBox.auto_picks = Array(Stage.arg("--talk-picks", "0").split(",")).map(func(v): return int(v))
		get_tree().create_timer(2.0).timeout.connect(func(): talk_to(people[who]))
	for b in people.values():
		pick.add(func(): return b.npc.global_position + Vector3(0, 0.62 if b.npc.sitting else 0.8, 0),
			func(): return Lang.t("TALK_HOVER", {"name": tr("NAME_" + b.npc.id.to_upper())}),
			talk_to.bind(b),
			func(): return not talking and office.player.controls and _near_enough(b))
	_prompt = Button.new()
	_prompt.theme = UiTheme.make()
	_prompt.focus_mode = Control.FOCUS_NONE
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.98, 0.95, 0.95), 18, UiTheme.PINK, 3, 14))
	_prompt.visible = false
	_prompt.pressed.connect(func():
		if _prompt_for:
			talk_to(_prompt_for))
	layer.add_child(_prompt)

func prompting(b: NpcBrain) -> bool:
	"""The talk button is up over b (scripts/morning/morning.gd hides b's own "!" meanwhile)."""
	return _prompt != null and _prompt.visible and _prompt_for == b

func _near_enough(b: NpcBrain) -> bool:
	var to: Vector3 = b.npc.global_position - office.player.global_position
	to.y = 0.0
	return to.length() < TALK_SHOW

func _update_prompt() -> void:
	"""The talk button over the nearest coworker in reach (not while talking, working or busy)."""
	if _prompt == null:
		return
	var best: NpcBrain = null
	var best_d := TALK_SHOW
	var free: bool = not talking and office.player.controls and not (office.work and office.work.working)
	var mo = office.morning
	if mo and mo.busy:
		free = false
	for b in people.values():
		if not b.npc.visible:
			continue

		var asks: bool = mo != null and not talking and not mo.busy and mo.has_request(b.npc.id)
		if not (free or asks):
			continue
		var to: Vector3 = b.npc.global_position - office.player.global_position
		to.y = 0.0
		if to.length() < (TALK_SHOW + 0.6 if asks else best_d) and (asks or not b.engaged):
			best = b
			best_d = to.length()
			if asks:
				break
	_prompt_for = best

	_prompt.visible = best != null and not best.npc.bubble.showing()
	if not _prompt.visible:
		return
	var head := best.npc.global_position + Vector3(0, 1.0 if best.npc.sitting else 1.45, 0)
	if office.cam.is_position_behind(head):
		_prompt.visible = false
		return
	_prompt.text = Lang.t("TALK_HOVER", {"name": tr("NAME_" + best.npc.id.to_upper())}) + "  (T)"
	var wait: int = office.morning.minutes_left(best.npc.id) if office.morning else -1
	if wait >= 0:
		_prompt.text = "! %d′   " % wait + _prompt.text
	_prompt.reset_size()
	_prompt.position = office.cam.unproject_position(head) - Vector2(_prompt.size.x * 0.5, _prompt.size.y)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_T and _prompt_for \
			and _prompt and not talking:
		get_viewport().set_input_as_handled()
		talk_to(_prompt_for)

func _story_hints() -> void:
	while is_inside_tree():
		await get_tree().create_timer(5.0).timeout
		var p: Node3D = office.player
		for b in people.values():
			if not talking and not b.engaged and p.global_position.distance_to(b.npc.global_position) < 5.0 \
					and not Bonds.next_story(b.npc.id).is_empty():
				EmoteFx.play(b.npc.chibi, "exclaim", 0.0)

func talk_to(b: NpcBrain) -> void:
	"""The player clicked someone: walk over, and if they can put down what they are doing, talk."""
	if talking:
		return
	if office.morning and office.morning.has_request(b.npc.id):
		talking = true
		await office.morning.request_talk(b)
		talking = false
		return
	talking = true
	b.rest("greet", 35.0)
	var p: Player = office.player
	var to := p.global_position - b.npc.global_position
	to.y = 0.0
	if to.length() > TALK_NEAR:

		p.go_to(b.npc.global_position + to.normalized() * 0.95, false, 0.3)
		while p.steer != Vector3.ZERO and p.global_position.distance_to(b.npc.global_position) > TALK_NEAR:
			await get_tree().physics_frame
		p.stop_going()
	if p.global_position.distance_to(b.npc.global_position) > TALK_REACH or b.engaged 			or not b.react(_talk.bind(b), 8, "talk"):
		b.npc.think("…", 1.5)
		talking = false

func _talk(b: NpcBrain) -> void:
	var p: Player = office.player
	var npc := b.npc
	var id := npc.id
	b.engaged = true
	p.stop_going()
	p.controls = false
	p.set_physics_process(false)
	npc.look_at_node = p
	var seated := npc.sitting
	if seated:
		npc.set_seated("Act_SitChair_Idle" if npc.chibi.anim.has_animation("Act_SitChair_Idle") else npc.seated_clip)
	else:
		await npc.face_point(p.global_position)
	var to := npc.global_position - p.global_position
	p.facing = atan2(to.x, to.z)
	create_tween().tween_property(p, "rotation:y", p.rotation.y + angle_difference(p.rotation.y, p.facing), 0.25)
	var zoom: float = office.cam_zoom
	office.cam_zoom = minf(zoom, 0.78)
	if not seated:
		npc.chibi.play("Base_Wait", 0.3)
	box.set_speaker(npc.chibi, Npc.TAG_COLORS.get(id, UiTheme.PINK))
	Narrator.clear()
	var memory := Bonds.remembered_line(id)
	if not memory.is_empty() and randf() < 0.5:
		await box.say(_who(id), Bonds.text(memory["line"], id), Npc.TAG_COLORS.get(id, UiTheme.PINK_DARK),
			TalkBox.FACES.get(str(memory.get("face", "smile")), TalkBox.FACES["smile"]))
	else:
		await _line(b, line(id, "HI"), "HI")
	while true:
		var story := Bonds.next_story(id)
		var opts := [tr("TALK_OPT_CHAT"), tr("TALK_OPT_HOW"), tr("TALK_OPT_BYE")]
		if not story.is_empty():
			opts.push_front(Lang.t("TALK_OPT_STORY_NEW", {"title": Bonds.text(story["title"], id)}))
		var pick: int = await box.ask(opts)
		if not story.is_empty():
			if pick == 0:
				await _story(b, story)
				continue
			pick -= 1
		if pick == 0:
			if Bonds.add(id, 1 if _chatted.has(id) else 3):
				await _bond_up(b)
			_chatted[id] = true
			await _line(b, _fresh_chat(id), "CHAT")
			EmoteFx.play(npc.chibi, "note", 0.0)
			b.fill("social", 0.25)
			b.fill("fun", 0.15)
		elif pick == 1:
			var mood := _mood(b)
			await _line(b, line(id, mood), mood)
			if not _asked.has(id) and Bonds.add(id, 2):
				await _bond_up(b)
			_asked[id] = true
			b.fill("social", 0.3)
		else:
			await _line(b, line(id, "BYE"), "BYE")
			box.close()
			if not seated:
				await npc.emote("wave")
			break
	if seated:
		npc.set_seated("Act_SitChair_Type")
	npc.look_at_node = null
	office.cam_zoom = zoom
	p.set_physics_process(true)
	p.controls = true
	talking = false

func _line(b: NpcBrain, key: String, topic: String) -> void:
	"""One line in the dialogue box, said with its face (the portrait's mouth moves while it types)."""
	if key == "":
		return
	var id := b.npc.id
	var face: String = LINE_FACES.get(key, TOPIC_FACES.get(topic, "smile"))
	if not LINE_FACES.has(key) and topic in ["HI", "CHAT", "BYE"] and PERSON_FACES.has(id):
		face = PERSON_FACES[id]
	await box.say(_who(id), tr(key), Npc.TAG_COLORS.get(id, UiTheme.PINK_DARK), TalkBox.FACES[face])

func _who(id: String) -> String:
	"""The name on the tag."""
	return tr("NAME_" + id.to_upper())

var _chatted := {}
var _asked := {}

func _story(b: NpcBrain, story: Dictionary) -> void:
	"""One of their stories: their lines, the player's replies (which they remember), then closer."""
	var id := b.npc.id
	Bonds.heard_today[id] = true
	await _steps(b, story.get("steps", []))
	Bonds.told[story["id"]] = true
	var up := Bonds.add(id, int(story.get("points", 8)))
	EmoteFx.play(b.npc.chibi, "heart", 0.0)
	if up:
		await _bond_up(b)

func _steps(b: NpcBrain, steps: Array) -> void:
	var id := b.npc.id
	var color: Color = Npc.TAG_COLORS.get(id, UiTheme.PINK_DARK)
	for st in steps:
		if st.has("say"):
			await box.say(_who(id), Bonds.text(st["say"], id), color,
				TalkBox.FACES.get(str(st.get("face", "smile")), TalkBox.FACES["smile"]))
		elif st.has("emote"):
			var fx := str(Chibi.emotes.get(st["emote"], {}).get("fx", ""))
			if fx != "":
				EmoteFx.play(b.npc.chibi, fx, 0.0)
		elif st.has("choice"):
			var options: Array = st["choice"]
			var i: int = await box.ask(options.map(func(o): return Bonds.text(o["text"], id)))
			var o: Dictionary = options[i]
			Bonds.add(id, int(o.get("points", 0)))
			if o.has("flag"):
				Bonds.flags[o["flag"]] = true
				Bonds.save()
			await _steps(b, o.get("then", []))
		elif st.has("if"):
			await _steps(b, st.get("then", []) if Bonds.flags.has(st["if"]) else st.get("else", []))

func _bond_up(b: NpcBrain) -> void:
	var id := b.npc.id
	EmoteFx.play(b.npc.chibi, "heart", 0.0)
	await box.say(tr("NAME_" + id.to_upper()), Lang.t("BOND_UP", {"name": tr("NAME_" + id.to_upper())}),
		Npc.TAG_COLORS.get(id, UiTheme.PINK_DARK), TalkBox.FACES["happy"])

func _fresh_chat(id: String) -> String:
	"""A CHAT line not told yet today (they come round again once all are told)."""
	var keys := []
	for i in range(1, 6):
		var key := "L_%s_CHAT_%d" % [id.to_upper(), i]
		if tr(key) != key:
			keys.append(key)
	if keys.is_empty():
		return line(id, "MOOD_GOOD")
	var told: Array = _told.get(id, [])
	var left := keys.filter(func(k): return not told.has(k))
	if left.is_empty():
		told.clear()
		left = keys
	var key: String = left.pick_random()
	told.append(key)
	_told[id] = told
	return key

func _mood(b: NpcBrain) -> String:
	"""How they really are (the brain's lowest need) as a MOOD_<...> topic."""
	var low := "good"
	var lowest := 0.4
	for k in ["energy", "thirst", "fun", "social"]:
		if b.need(k) < lowest:
			lowest = b.need(k)
			low = k
	return {"energy": "MOOD_TIRED", "thirst": "MOOD_THIRSTY", "fun": "MOOD_BORED", "social": "MOOD_LONELY",
		"good": "MOOD_GOOD"}[low]
