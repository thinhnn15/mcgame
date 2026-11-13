class_name FarmPets
extends Node

const GATE := Vector3(-4.6, 0, 5.0)
const SHY := Vector3(-8.2, 0, 7.9)
const BOWL := Vector3(-4.0, 0, 4.5)
const DISH := Vector3(-4.6, 0, -0.4)
const FEEDS := 3
const DISH_NIGHTS := 2
const GIFT := 25
const PAT := 10

const HERO_R := 0.75
const ROUND := 1.6

var plot
var dry := false
var vang: FarmAnimal
var muop: FarmAnimal
var vang_stays := false
var muop_stays := false
var feeds := 0
var fed_today := false
var bowl_full := false
var patted := -1
var muop_patted := -1
var stolen := false
var dish_nights := 0
var dish_full := false
var _bowl: Node3D
var _rice: Node3D
var _dish: Node3D
var _fish: Node3D
var _prints: Array = []
var _vang_goal := Vector3.ZERO
var _vang_wait := 0.0
var _shy_to := Vector3.INF
var _shy_age := 0.0
var _hero_was := Vector3.INF
var _hero_vel := Vector3.ZERO
var pat_r := HERO_R
var _greet := false

func setup(p, is_dry: bool) -> void:
	plot = p
	dry = is_dry
	vang_stays = Progress.is_open("cho_vang")
	muop_stays = Progress.is_open("meo_muop")
	vang = FarmAnimal.spawn(plot, "cho_vang", SHY, 0.0)
	muop = FarmAnimal.spawn(plot, "meo_muop", plot.CHONG + Vector3(0.3, 0.47, 0), PI / 2)
	_bowl = Props.at(plot, ground(BOWL))
	Props._part(_bowl, _bowl, Props._cyl(0.11, 0.08, 0.07), Color("e9e2d2"), Vector3(0, 0.035, 0))
	_rice = Props.mesh(_bowl, Props.sphere(0.085), Color("fbf8f0"), Vector3(0, 0.07, 0), Vector3.ZERO, Vector3(1, 0.45, 1))
	_dish = Props.at(plot, ground(DISH))

	Props._part(_dish, _dish, Props._cyl(0.22, 0.25, 0.3), Color("7a5a3c"), Vector3(0, 0.15, 0))
	Props._part(_dish, _dish, Props._cyl(0.2, 0.2, 0.02), Color("d6b27c"), Vector3(0, 0.305, 0))
	Props._part(_dish, _dish, Props._cyl(0.12, 0.12, 0.022), Color("c49c64"), Vector3(0, 0.307, 0))
	Props._part(_dish, _dish, Props._cyl(0.15, 0.12, 0.03), Color("e9e2d2"), Vector3(0, 0.335, 0))
	_fish = Props.mesh(_dish, Props.sphere(0.06), Color("b8b2a2"), Vector3(0, 0.37, 0), Vector3.ZERO, Vector3(2.0, 0.6, 0.8))
	for root in [_bowl, _dish]:
		for g in root.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bowl_show()
	_dish_show()
	_place_for_hour()

func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, plot.scenery.walk_at(p.x, p.z), p.z)

func morning() -> String:
	fed_today = false
	bowl_full = false
	_bowl_show()
	var key := ""
	if dish_full:
		dish_full = false
		dish_nights += 1
		_paw_prints(DISH + Vector3(0.2, 0, 0.5), 5)
		_friend("meo_muop", GIFT)
		key = "FARM_T_DISH_EMPTY"
	_dish_show()
	if not vang_stays and feeds >= FEEDS:
		vang_stays = true
		if not dry:
			Progress.moment("vang_o_lai")
		vang.position = ground(GATE)
		_vang_goal = plot.player.global_position + Vector3(0.8, 0, 0.6)
		key = "FARM_T_VANG_STAYS"
	_place_for_hour()
	if vang_stays and key == "" and plot.player.global_position.distance_to(plot.CHONG) > 3.0:
		vang.position = ground(plot.CHONG + Vector3(1.0, 0, 0.9))
		_vang_goal = Vector3.ZERO
		_greet = true
	return key

func evening(fish_in_hand: int) -> String:
	var h := Clock.hour()
	if not muop_stays and not stolen and fish_in_hand > 0 and h >= 17.0:
		stolen = true
		plot.fish_used += 1
		_paw_prints(plot.CHONG + Vector3(1.4, 0, 1.4), 7)
		return "FARM_T_FISH_STOLEN"
	if not muop_stays and dish_nights >= DISH_NIGHTS and h >= 18.5:
		muop_stays = true
		if not dry:
			Progress.moment("muop_o_lai")
		muop.visible = true
		muop.play("Loaf")
		return "FARM_T_MUOP_STAYS"
	return ""

func use(at: Vector3) -> bool:
	if _near(at, BOWL, 1.3) and not vang_stays and not fed_today and not bowl_full and Clock.hour() < 11.0:
		bowl_full = true
		_bowl_show()
		plot.hud.toast(tr("FARM_T_BOWL"), 2.5)
		return true
	if _near(at, DISH, 1.1) and not muop_stays and not dish_full and Clock.hour() >= 16.0:
		if plot.fish_in_hand() <= 0:
			plot.hud.toast(tr("FARM_T_DISH_NO_FISH"), 2.5)
		else:
			plot.fish_used += 1
			dish_full = true
			_dish_show()
			plot.hud.toast(tr("FARM_T_DISH"), 2.5)
		return true
	if vang_stays and vang.visible and _near(at, vang.position, 1.2) and patted != Clock.day:
		patted = Clock.day
		_vang_wait = plot.touch.vang(vang)
		_friend("cho_vang", PAT)
		plot._xp("vuot_ve")
		plot.hud.toast(tr("FARM_T_PAT"), 2.0)
		return true
	if muop_stays and muop.visible and _near(at, muop.position, 1.0) and muop_patted != Clock.day:
		muop_patted = Clock.day
		var said: String = plot.touch.muop(muop)
		_friend("meo_muop", PAT)
		plot._xp("vuot_ve")
		plot.hud.toast(tr(said), 2.2)
		return true
	return false

func step(delta: float, hidden: bool) -> void:
	muop.visible = muop_stays and not hidden
	vang.visible = not hidden and (vang_stays or (Clock.hour() >= 6.0 and Clock.hour() < 11.0) or bowl_full)
	if hidden or not vang.visible:
		return
	var hero: Vector3 = plot.player.global_position
	if _hero_was != Vector3.INF and delta > 0.0:
		_hero_vel = _hero_vel.lerp(_flat(hero - _hero_was) / delta, 1.0 - exp(-delta * 6.0))
	_hero_was = hero
	var goal: Vector3
	var clip := "Sit_Keep"
	if vang_stays:
		var night: bool = Clock.hour() >= 21.0 or Clock.hour() < 6.0
		if night:
			goal = plot.CHONG + Vector3(1.0, 0, 0.9)
			clip = "Lie_Keep"
		else:
			if hero.distance_to(_vang_goal) > 2.6 or _vang_goal == Vector3.ZERO:
				var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 1.2
				_vang_goal = hero + side
			goal = _vang_goal
			clip = "Idle"
	elif bowl_full and hero.distance_to(BOWL) > 5.0:
		goal = BOWL + Vector3(-0.45, 0, 0.3)
		clip = "Sniff"
	elif hero.distance_to(GATE) < 2.6 or hero.distance_to(vang.position) < 2.2:
		goal = SHY

		_shy_age += delta
		var keep := _shy_to != Vector3.INF and _shy_age < 1.2 and _flat(hero).distance_to(_flat(_shy_to)) > 1.6
		if keep:
			goal = _shy_to
		elif _flat(vang.position).distance_to(_flat(SHY)) < 0.5 or _route_blocked(vang.position, SHY, hero):
			_shy_to = _shy_spot(hero)
			_shy_age = 0.0
			goal = _shy_to
	else:
		goal = GATE
	if goal != _shy_to:
		_shy_to = Vector3.INF

	goal = _bank(goal, vang.position)
	if _flat(goal).distance_to(_flat(hero)) < HERO_R + 0.1:
		goal = _bank(hero + _away(vang.position, hero) * (HERO_R + 0.15), vang.position)
	var to := FarmScenery.way(vang.position, goal) - vang.position
	to.y = 0
	if _vang_wait > 0.0:
		_vang_wait -= delta
		_keep_out(hero)
		return
	if to.length() > 0.2:

		var near_h := _flat(vang.position).distance_to(_flat(hero))
		var run := to.length() > 3.0 or near_h < ROUND
		var gait := "Run" if near_h < HERO_R + 0.35 and _hero_vel.length() > 1.5 else ("Follow" if run else "Walk")
		if _greet and to.length() > 1.2:
			gait = "Run"
		var sp: float = FarmAnimal.SPEED["cho_vang"][gait]
		var dir := _round_hero(to.normalized(), hero)
		var next := vang.position + dir * minf(sp * delta, to.length())
		if _wet(next) and not _wet(vang.position):
			dir = to.normalized()
			next = vang.position + dir * minf(sp * delta, to.length())
			if _flat(next).distance_to(_flat(hero)) < HERO_R:
				next = vang.position
		vang.position = next
		_keep_out(hero)
		vang.rotation.y = lerp_angle(vang.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-delta * 7.0))
		vang.play(gait)
		return
	_keep_out(hero)
	if _greet and clip == "Idle":
		_greet = false
		vang.rotation.y = atan2(hero.x - vang.position.x, hero.z - vang.position.z)
		vang.play("Wag")
		Sound.play_at("animal.dog_huff", vang.global_position + Vector3(0, 0.4, 0), -4.0)
		_vang_wait = 2.0
		return
	if clip == "Sniff":
		vang.rotation.y = lerp_angle(vang.rotation.y, atan2(BOWL.x - vang.position.x, BOWL.z - vang.position.z), 0.2)
		vang.play("Sniff")
		_vang_wait = 3.0
		bowl_full = false
		fed_today = true
		feeds += 1
		_friend("cho_vang", GIFT)
		_bowl_show()
		return
	if clip == "Idle":
		vang.rotation.y = lerp_angle(vang.rotation.y, atan2(hero.x - vang.position.x, hero.z - vang.position.z), 1.0 - exp(-delta * 4.0))
		clip = "Sit_Keep" if randf() < 0.002 or vang._loop == "Sit_Keep" else "Idle"
	elif clip == "Sit_Keep" and not vang_stays:
		vang.rotation.y = lerp_angle(vang.rotation.y, atan2(hero.x - vang.position.x, hero.z - vang.position.z), 1.0 - exp(-delta * 3.0))
	if vang._loop != clip:
		vang.play(clip)

func _place_for_hour() -> void:
	if vang_stays:
		vang.position = ground(plot.CHONG + Vector3(1.0, 0, 0.9)) if Clock.hour() >= 21.0 else ground(plot.player.global_position + Vector3(1.0, 0, 0.8))
	else:
		vang.position = ground(GATE)
	if muop_stays:
		muop.play("Loaf")

func _round_hero(d: Vector3, hero: Vector3) -> Vector3:
	var off := _flat(vang.position) - _flat(hero)
	var dist := off.length()
	if dist > ROUND or dist < 1e-4:
		return d
	var n := off / dist
	if d.dot(-n) <= 0.0:
		return d
	var t := Vector3(-n.z, 0, n.x)
	if t.dot(d) < 0.0 or (absf(t.dot(d)) < 1e-3 and t.dot(_flat(GATE) - _flat(hero)) < 0.0):
		t = -t
	var w := clampf((ROUND - dist) / (ROUND - HERO_R), 0.0, 1.0)
	var out := d.lerp(t, w)
	if dist < HERO_R:
		out += n * 1.5
	return out.normalized() if out.length() > 1e-4 else t

func _keep_out(hero: Vector3) -> void:
	var off := _flat(vang.position) - _flat(hero)
	if off.length() < pat_r:
		var n := off.normalized() if off.length() > 1e-4 else Vector3(sin(vang.rotation.y), 0, cos(vang.rotation.y))
		var p := _flat(hero) + n * pat_r
		if not _wet(p) and _clear(vang.position, p):
			vang.position.x = p.x
			vang.position.z = p.z
	vang.position.y = plot.scenery.walk_at(vang.position.x, vang.position.z)

func _route_blocked(from: Vector3, to: Vector3, hero: Vector3) -> bool:
	var p := from
	for i in 3:
		var n := FarmScenery.way(p, to)
		if _in_way(p, n, hero):
			return true
		if _flat(n).distance_to(_flat(to)) < 0.05:
			break
		p = n
	return false

func _in_way(a: Vector3, b: Vector3, hero: Vector3) -> bool:
	var ab := _flat(b) - _flat(a)
	var ah := _flat(hero) - _flat(a)
	var l := ab.length()
	if l < 1e-3:
		return false
	var s := ah.dot(ab) / l
	return s > 0.0 and s < l + HERO_R and (ah - ab / l * s).length() < HERO_R + 0.3

func _shy_spot(hero: Vector3) -> Vector3:
	var from := vang.position
	var away := _away(from, hero)
	var walk := _hero_vel.normalized() if _hero_vel.length() > 0.3 else Vector3.ZERO
	var best := from
	var best_score := -1.0
	for turn in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 2.0, -2.0]:
		var p := _bank(from + away.rotated(Vector3.UP, turn) * 2.4, from)
		if not _clear(from, p):
			continue
		var rel := _flat(p) - _flat(hero)
		var off_line := 2.0
		if walk != Vector3.ZERO and rel.dot(walk) > 0.0:
			off_line = minf((rel - walk * rel.dot(walk)).length(), 2.0)
		var score := minf(rel.length(), 3.0) + 1.5 * off_line
		if score > best_score:
			best_score = score
			best = p
	return best

func _away(from: Vector3, hero: Vector3) -> Vector3:
	var a := _flat(from) - _flat(hero)
	return a.normalized() if a.length() > 1e-3 else Vector3(sin(vang.rotation.y), 0, cos(vang.rotation.y))

func _wet(p: Vector3) -> bool:
	return absf(p.z - FarmScenery.DITCH_Z) < 0.95 and not FarmScenery.on_deck(p.x, p.z)

func _bank(p: Vector3, side: Vector3) -> Vector3:
	if _wet(p):
		p.z = FarmScenery.DITCH_Z + (1.15 if side.z > FarmScenery.DITCH_Z else -1.15)
	return p

func _clear(a: Vector3, b: Vector3) -> bool:
	var ya: float = plot.scenery.walk_at(a.x, a.z) + 0.35
	var yb: float = plot.scenery.walk_at(b.x, b.z) + 0.35
	var q := PhysicsRayQueryParameters3D.create(Vector3(a.x, ya, a.z), Vector3(b.x, yb, b.z))
	if plot.player is CollisionObject3D:
		q.exclude = [(plot.player as CollisionObject3D).get_rid()]
	return plot.player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0, p.z)

func _near(a: Vector3, b: Vector3, r: float) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() < r

func _friend(who: String, pts: int) -> void:
	if not dry:
		Progress.friend(who, pts)

func _bowl_show() -> void:
	_bowl.visible = not vang_stays
	_rice.visible = bowl_full

func _dish_show() -> void:
	_dish.visible = not muop_stays or dish_full
	_fish.visible = dish_full

func _paw_prints(at: Vector3, n: int) -> void:
	for p in _prints:
		p.queue_free()
	_prints.clear()
	for i in n:
		var q := at + Vector3(-0.5 + i * 0.22, 0, sin(i * 1.7) * 0.12)
		var m := Props.mesh(plot, Props._cyl(0.025, 0.025, 0.004), Color("6b5444"), ground(q) + Vector3(0, 0.012, 0))
		_prints.append(m)

func to_dict() -> Dictionary:
	return {"feeds": feeds, "patted": patted, "muop_patted": muop_patted, "stolen": stolen, "dish_nights": dish_nights, "dish_full": dish_full,
		"vang": vang_stays, "muop": muop_stays}

func from_dict(d: Dictionary) -> void:
	feeds = int(d.get("feeds", 0))
	patted = int(d.get("patted", -1))
	muop_patted = int(d.get("muop_patted", -1))
	stolen = bool(d.get("stolen", false))
	dish_nights = int(d.get("dish_nights", 0))
	dish_full = bool(d.get("dish_full", false))
	vang_stays = vang_stays or bool(d.get("vang", false))
	muop_stays = muop_stays or bool(d.get("muop", false))
	_bowl_show()
	_dish_show()
	_place_for_hour()
