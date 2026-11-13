class_name FarmDays
extends Node3D

const CAY := "res://data/farm/cay_qua.json"
const BEP := "res://data/farm/bep.json"
const KITCHEN_AT := Vector3(-4.45, 0, -8.6)
const NAP := [11.0, 15.0]
const BA := [6.0, 11.0]
const ME := [18.0, 19.5]
const BA_LOVES := ["FARM_CAU", "DISH_TRA_XANH", "DISH_CHE_BUOI", "FARM_CHE_THOM"]
const BA_LINES := 8
const FRUIT_LOOK := {
	"buoi": [Color("d2d564"), 0.12, 5], "chuoi": [Color("b8c84a"), 0.05, 6], "cau": [Color("e3933c"), 0.05, 9]}

var plot: Node3D
var kinds := {}
var recipes := {}
var bep := {}
var trees := []
var last := {}
var nap_day := -1
var dinner_day := -1
var ba_word_day := -1
var ba_gift_day := -1
var me_day := -1
var _have_fruit := false
var _have_cook := false
var _fruit_nodes: Array[Node] = []
var _menu: Array = []
var _menu_i := 0
var _menu_who := ""
var _pot: Array = []
var ba: Chibi
var me: Chibi
var _ba_props: Array[Node3D] = []
var _me_props: Array[Node3D] = []

static func add(p: Node3D) -> FarmDays:
	var d := FarmDays.new()
	d.name = "FarmDays"
	d.plot = p
	p.add_child(d)
	return d

func _ready() -> void:
	_have_fruit = ClassDB.class_exists("FruitTrees")
	_have_cook = ClassDB.class_exists("Cooking")
	var c = JSON.parse_string(FileAccess.get_file_as_string(CAY))
	kinds = c.get("kinds", {}) if c is Dictionary else {}
	var b = JSON.parse_string(FileAccess.get_file_as_string(BEP))
	bep = b if b is Dictionary else {}
	recipes = bep.get("recipes", {})
	trees = FarmYard.fruit_trees()
	for t: Dictionary in trees:
		var tp: Vector3 = t.pos
		tp.y = plot.scenery.height_at(tp.x, tp.z)
		t.pos = tp
	plot.hud.shop_tapped.connect(_tap)
	plot.hud.shop_closed.connect(_close)
	redraw()

func to_dict() -> Dictionary:
	return {"last": last, "nap": nap_day, "dinner": dinner_day, "ba_word": ba_word_day, "ba_gift": ba_gift_day,
		"me": me_day}

func from_dict(d: Dictionary) -> void:
	last = {}
	for k in d.get("last", {}):
		last[k] = int(d["last"][k])
	nap_day = int(d.get("nap", -1))
	dinner_day = int(d.get("dinner", -1))
	ba_word_day = int(d.get("ba_word", -1))
	ba_gift_day = int(d.get("ba_gift", -1))
	me_day = int(d.get("me", -1))
	redraw()

func _last_of(t: Dictionary) -> int:
	if not last.has(t.id):
		last[t.id] = int(ClassDB.class_call_static("FruitTrees", "start", kinds[t.kind], int(t.seed), Clock.day)) \
			if _have_fruit else -999
	return int(last[t.id])

func ripe(t: Dictionary) -> bool:
	if not _have_fruit:
		return true
	return bool(ClassDB.class_call_static("FruitTrees", "ripe", kinds[t.kind], _last_of(t), Clock.day, plot.month()))

func redraw() -> void:
	for n in _fruit_nodes:
		n.queue_free()
	_fruit_nodes.clear()
	var lists := {}
	var crop_trees := []
	for t: Dictionary in trees:
		var r := ripe(t)
		if t.model != "":
			crop_trees.append({"model": t.model + ("_4" if r else "_3"), "yaw": deg_to_rad(t.yaw), "pos": t.pos})
			continue
		if not r or not FRUIT_LOOK.has(t.kind):
			continue
		if not lists.has(t.kind):
			lists[t.kind] = []
		lists[t.kind] += _fruit_spots(t)
	for kind in lists:
		var look: Array = FRUIT_LOOK[kind]
		var sm := SphereMesh.new()
		sm.radius = look[1]
		sm.height = look[1] * 2.0
		sm.radial_segments = 8
		sm.rings = 4
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = sm
		mm.instance_count = lists[kind].size()
		for i in lists[kind].size():
			mm.set_instance_transform(i, lists[kind][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Props.mat(look[0])
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.name = "Fruit_" + kind
		add_child(mmi)
		_fruit_nodes.append(mmi)
	if not crop_trees.is_empty():
		for mmi: MultiMeshInstance3D in Crops.draw(self, crop_trees, true):
			mmi.visibility_range_end = 0.0
			_fruit_nodes.append(mmi)

func _fruit_spots(t: Dictionary) -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t.seed) * 31 + 7
	var look: Array = FRUIT_LOOK[t.kind]
	var p: Vector3 = t.pos
	match t.kind:
		"buoi":
			for i in int(look[2]):
				var a := lerpf(-0.3, PI + 0.3, (i + rng.randf() * 0.6) / float(look[2]))
				var r := rng.randf_range(1.05, 1.4)
				out.append(Transform3D(Basis.IDENTITY, p + Vector3(cos(a) * r, rng.randf_range(1.55, 2.3), sin(a) * r * 0.8)))
		"chuoi":
			var c := p + Vector3(0.18, 1.2, 0.28)
			for i in int(look[2]):
				var a := i * TAU / float(look[2])
				var b := Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.35).scaled(Vector3(1, 2.6, 1))
				out.append(Transform3D(b, c + Vector3(cos(a) * 0.07, (i % 2) * 0.06, sin(a) * 0.07)))
		"cau":
			var c := p + Vector3(0.16, 4.45, 0.2)
			for i in int(look[2]):
				out.append(Transform3D(Basis.IDENTITY, c + Vector3(rng.randf_range(-0.09, 0.09), -i * 0.035,
					rng.randf_range(-0.09, 0.09))))
	return out

func _near(p: Vector3, at: Vector3, r: float) -> bool:
	var d := at - p
	d.y = 0
	return d.length() < r

func _tree_at(at: Vector3) -> Dictionary:
	var best := {}
	var bd := 1e9
	for t: Dictionary in trees:
		var d := Vector2(at.x - t.pos.x, at.z - t.pos.z).length()
		if d < float(t.r) and d < bd:
			best = t
			bd = d
	return best

func hint_at(at: Vector3) -> String:
	if _menu_open():
		return ""
	if ba and ba.visible and _near(ba.global_position, at, 1.2):
		return "FARM_HINT_BA"
	if me and me.visible and _near(me.global_position, at, 1.3):
		return "FARM_HINT_ME"
	if (_have_cook or plot.tea.can_roast()) and _near(KITCHEN_AT, at, 1.1):
		return "FARM_HINT_BEP"
	if _near(FarmYard.HAMMOCK, at, 1.3) and _noon():
		return "FARM_HINT_VONG"
	var t := _tree_at(at)
	if not t.is_empty() and ripe(t) and _have_fruit:
		return "FARM_HINT_TREE"
	return ""

func use(at: Vector3) -> bool:
	if ba and ba.visible and _near(ba.global_position, at, 1.2):
		_open_ba()
		return true
	if me and me.visible and _near(me.global_position, at, 1.3):
		_dinner_with_me()
		return true
	if (_have_cook or plot.tea.can_roast()) and _near(KITCHEN_AT, at, 1.1):
		_open_bep()
		return true
	var t := _tree_at(at)
	var fruit := not t.is_empty() and _have_fruit and ripe(t)
	if _near(FarmYard.HAMMOCK, at, 1.3) and (_noon() or not fruit):
		_nap()
		return true
	if t.is_empty() or not _have_fruit:
		return false
	if not ripe(t):
		if _near(plot.CHONG, at, 1.6):
			return false
		var left := int(ClassDB.class_call_static("FruitTrees", "days_left", kinds[t.kind], _last_of(t), Clock.day, plot.month()))
		plot.hud.toast(tr("FRUIT_T_OFF") if left < 0 else tr("FRUIT_T_WAIT") % left, 2.0)
		return true
	_pick(t)
	return true

func _pick(t: Dictionary) -> void:
	plot._busy = true
	var face: Vector3 = t.pos - plot.player.global_position
	face.y = 0
	if face.length() > 0.01:
		plot._face(face)
	if await plot._clip("Tool_Egg_Pick", 19, 46):
		var k: Dictionary = kinds[t.kind]
		var n := int(ClassDB.class_call_static("FruitTrees", "amount", k, int(t.seed), Clock.day))
		last[t.id] = Clock.day
		Sound.play_at("harvest.pick", t.pos + Vector3(0, 1.4, 0))
		plot._gain(str(k["key"]), n)
		plot._xp("hai_qua_cay")
		redraw()
	plot._busy = false

func price_of(key: String) -> int:
	for k in kinds:
		if str(kinds[k]["key"]) == key and kinds[k].has("price"):
			return int(kinds[k]["price"])
	for id in recipes:
		if str(recipes[id]["dish"]) == key:
			return int(recipes[id].get("price", 0))
	for g in bep.get("pot", {}).get("generic", []):
		if str(g["dish"]) == key:
			return int(g.get("price", 0))
	return 0

func _noon() -> bool:
	return Clock.hour() >= NAP[0] and Clock.hour() < NAP[1]

func _nap() -> void:
	if not _noon():
		plot.hud.toast(tr("VONG_T_NOT_NOON"), 2.2)
		return
	if nap_day == Clock.day:
		plot.hud.toast(tr("VONG_T_NAPPED"), 2.0)
		return
	plot._busy = true
	plot.player.controls = false
	await plot.hud.fade(1.0, 0.8)
	Clock.minute = minf(Clock.minute + 120.0, NAP[1] * 60.0)
	nap_day = Clock.day
	if not plot.dry:
		Progress.rest("sat_still_or_nap")
	plot._light()
	await get_tree().create_timer(0.5).timeout
	await plot.hud.fade(0.0, 0.8)
	plot.hud.toast(tr("VONG_T_NAP"), 3.0)
	plot.player.controls = true
	plot._busy = false

func _open_ids() -> Array:
	var out := []
	for row in Progress.unlocks().get("items", []):
		if row["type"] == "recipe" and recipes.has(row["id"]) and Progress.met(row["unlock"]):
			out.append(row["id"])
	return out

func _have() -> Dictionary:
	var h: Dictionary = plot.bag.duplicate()
	h["fish"] = plot.fish_in_hand()
	return h

func _open_bep() -> void:
	_pot = []
	_menu_who = "bep"
	_bep_rows()
	if _menu.size() <= 1 and not plot.tea.can_roast():
		_menu = []
		_menu_who = ""
		plot.hud.toast(tr("BEP_T_NOTHING"), 3.0)
		return
	_menu_i = 0
	for i in _menu.size():
		if _menu[i].kind == "add":
			_menu_i = i
			break
	plot.player.controls = false
	_draw()

func _pot_left(key: String) -> int:
	var n: int = plot.fish_in_hand() if key == "fish" else int(plot.bag.get(key, 0))
	return n - _pot.count(key)

func _is_dish(key: String) -> bool:
	if key.begins_with("DISH_"):
		return true
	return false

func _bep_rows() -> void:
	_menu = []
	if plot.tea.can_roast():
		_menu.append({"kind": "roast"})
	_menu.append({"kind": "pot"})
	if _have_cook:
		var keys := []
		for k in plot.bag:
			if not _is_dish(str(k)) and int(plot.bag[k]) > 0:
				keys.append(str(k))
		keys.sort_custom(func(a: String, b: String) -> bool: return tr(a) < tr(b))
		if plot.fish_in_hand() > 0:
			keys.push_front("fish")
		for k: String in keys:
			if _pot_left(k) > 0:
				_menu.append({"kind": "add", "key": k})
		if not _pot.is_empty():
			_menu.append({"kind": "cook"})
	for k in plot.bag:
		if _is_dish(str(k)) and int(plot.bag[k]) > 0:
			_menu.append({"kind": "eat", "key": str(k)})

func _known_dishes() -> int:
	var n := 0
	for m in Progress.moments():
		if str(m).begins_with("mon_"):
			n += 1
	return n

func _draw() -> void:
	var rows := []
	var title := ""
	var hint := ""
	if _menu_who == "bep":
		title = tr("BEP_TITLE_POT") % _known_dishes()
		hint = tr("BEP_HINT_POT_TOUCH" if TouchControls.active else "BEP_HINT_POT")
		var pot_max := int(bep.get("pot", {}).get("max", 5))
		for m: Dictionary in _menu:
			match m.kind:
				"roast": rows.append(tr("BEP_ROW_ROAST") % [int(plot.tea.cfg["roast"]["needs"]), int(plot.bag.get("CROP_CHE", 0))])
				"pot":
					if _pot.is_empty():
						rows.append(tr("BEP_ROW_POT_EMPTY") % pot_max)
					else:
						rows.append(tr("BEP_ROW_POT") % [", ".join(_pot.map(func(k: String) -> String: return _name(k))), _pot.size(), pot_max])
				"add": rows.append(tr("BEP_ROW_ADD") % [_name(m.key), _pot_left(m.key)])
				"cook": rows.append(tr("BEP_ROW_COOK_POT") % _pot.size())
				"eat": rows.append(tr("BEP_ROW_EAT") % [tr(m.key), int(plot.bag.get(m.key, 0))])
	else:
		title = tr("BA_TITLE")
		hint = tr("BA_HINT_TOUCH" if TouchControls.active else "BA_HINT")
		for m: Dictionary in _menu:
			match m.kind:
				"talk": rows.append(tr("BA_ROW_TALK"))
				"gift": rows.append(tr("BA_ROW_GIFT") % [tr(m.key), int(plot.bag.get(m.key, 0))])
	plot.hud.shop(title, rows, _menu_i, hint)

func _menu_open() -> bool:
	return not _menu.is_empty()

func menu_input(e: InputEvent) -> bool:
	if not _menu_open():
		return false
	var up := false
	var down := false
	var ok := false
	var close := false
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		up = k in [KEY_W, KEY_UP]
		down = k in [KEY_S, KEY_DOWN]
		ok = k in [KEY_F, KEY_SPACE, KEY_ENTER]
		close = k in [KEY_ESCAPE, KEY_Q]
		if k in [KEY_X, KEY_BACKSPACE] and _menu_who == "bep":
			_take_out()
			get_viewport().set_input_as_handled()
			return true
		if k == KEY_C and _menu_who == "bep" and not _pot.is_empty():
			_cook_pot()
			get_viewport().set_input_as_handled()
			return true
	elif e is InputEventJoypadButton and e.pressed:
		up = e.button_index == JOY_BUTTON_DPAD_UP
		down = e.button_index == JOY_BUTTON_DPAD_DOWN
		ok = e.button_index == JOY_BUTTON_A
		close = e.button_index == JOY_BUTTON_B
	if up or down:
		_menu_i = posmod(_menu_i + (1 if down else -1), _menu.size())
		_draw()
	elif ok:
		_choose()
	elif close:
		_close()
	get_viewport().set_input_as_handled()
	return true

func _tap(i: int) -> void:
	if not _menu_open():
		return
	if i == _menu_i:
		_choose()
	else:
		_menu_i = clampi(i, 0, _menu.size() - 1)
		_draw()

func _close() -> void:
	if not _menu_open():
		return
	_menu = []
	_menu_who = ""
	plot.hud.close_shop()
	plot.player.controls = true

func _choose() -> void:
	var m: Dictionary = _menu[_menu_i]
	match m.kind:
		"roast":
			_close()
			plot.tea.start_roast()
		"pot": _take_out()
		"add": _put_in(m.key)
		"cook": _cook_pot()
		"eat": _eat(m.key)
		"talk": _ba_talk()
		"gift": _ba_gift(m.key)

func _name(key: String) -> String:
	return tr("BEP_FISH" if key == "fish" else key)

func _put_in(key: String) -> void:
	if _pot.size() >= int(bep.get("pot", {}).get("max", 5)):
		plot.hud.toast(tr("BEP_T_POT_FULL"), 1.6)
		return
	if _pot_left(key) <= 0:
		return
	_pot.append(key)
	Sound.play("bag.put")
	var at := _menu_i
	_bep_rows()
	_menu_i = clampi(at + (1 if _pot.size() == 1 else 0), 0, _menu.size() - 1)
	if _pot_left(key) <= 0:
		_menu_i = clampi(at, 0, _menu.size() - 1)
	_draw()

func _take_out() -> void:
	if _pot.is_empty():
		return
	_pot.pop_back()
	_bep_rows()
	_menu_i = clampi(_menu_i, 0, _menu.size() - 1)
	_draw()

func _cook_pot() -> void:
	if _pot.is_empty():
		plot.hud.toast(tr("BEP_T_POT_EMPTY"), 1.6)
		return
	var got: Dictionary = ClassDB.class_call_static("Cooking", "cook", bep.get("pot", {}), recipes, _open_ids(), _pot)
	var dish := str(got.get("dish", ""))
	if dish == "":
		return
	var pot := _pot.duplicate()
	_close()
	for k: String in pot:
		if k == "fish":
			plot.fish_used += 1
			continue
		plot.bag[k] = int(plot.bag.get(k, 0)) - 1
		if int(plot.bag[k]) <= 0:
			plot.bag.erase(k)
	plot._update_bag()
	plot._busy = true
	plot.player.controls = false
	var k := FarmYard.KITCHEN
	plot._puff(Vector3(k.x, plot.scenery.height_at(k.x, k.z), k.z) + FarmYard.CHIMNEY, Color(0.92, 0.92, 0.93), 8)
	var scene := PotScene.new()
	scene.items = pot.map(func(x: String) -> Color: return _colour_of(x))
	plot.add_child(scene)
	await scene.done
	scene.queue_free()
	var n := int(got.get("portions", 1))
	plot.bag[dish] = int(plot.bag.get(dish, 0)) + n
	plot._update_bag()
	plot._xp("nau_mon")
	var first := not Progress.moments().has("mon_" + dish)
	if not plot.dry:
		Progress.moment("mon_" + dish)
	Sound.play_at("harvest.pick", plot.player.global_position + Vector3(0, 0.8, 0))
	plot.hud.toast((tr("BEP_T_NEW") if first else tr("BEP_T_GOT_DISH")) % [tr(dish), n], 3.0)
	plot.player.controls = true
	plot._busy = false

func _colour_of(key: String) -> Color:
	var tags: Array = bep.get("pot", {}).get("tags", {}).get(key, [])
	var t := str(tags[0]) if not tags.is_empty() else ""
	return {"rau": Color("6fae4a"), "cu": Color("e2b04a"), "qua": Color("f0c540"), "dau": Color("7a4a3a"),
		"gia_vi": Color("e8743a"), "hoa": Color("f2a0c0"), "che": Color("4e7a34"), "trung": Color("fbf3e2"),
		"ca": Color("9fb3c4"), "ngot": Color("e9a83a")}.get(t, Color("c8b89a"))

func _eat(key: String) -> void:
	plot.bag[key] = int(plot.bag.get(key, 0)) - 1
	if int(plot.bag[key]) <= 0:
		plot.bag.erase(key)
	plot._update_bag()
	var h := Clock.hour()
	if h >= float(bep.get("dinner_from", 17.0)) and h < float(bep.get("dinner_to", 21.0)) and dinner_day != Clock.day:
		dinner_day = Clock.day
		if not plot.dry:
			Progress.rest("dinner")
		plot.hud.toast(tr("BEP_T_DINNER"), 3.2)
	else:
		plot.hud.toast(tr("BEP_T_ATE"), 1.8)
	_close()

func step(_delta: float) -> void:
	if Engine.get_process_frames() % 20 != 0:
		return
	var h := Clock.hour()
	var ba_here := h >= BA[0] and h < BA[1] and Clock.weather == "" and plot.cutscene == null
	var at_tea: bool = plot.tea.ba_here(h)
	if ba_here and ba == null:
		ba = _person("ba_noi", plot.CHONG + Vector3(0.4, 0, 0.78), 0.0)
		ba.play("Act_SitChair_Idle", 0.0)
		var y: float = plot.scenery.height_at(plot.CHONG.x, plot.CHONG.z)
		_ba_props.append(_no_shadow(Furniture.place(plot, "coi_trau", Vector3(plot.CHONG.x - 0.3, y + 0.435, plot.CHONG.z + 0.1), 20.0, false)))
	if ba:
		ba.visible = ba_here
		var spot: Vector3 = plot.tea.ba_spot() if at_tea else plot.CHONG + Vector3(0.4, 0, 0.78)
		spot.y = plot.scenery.height_at(spot.x, spot.z)
		if ba.position.distance_to(spot) > 0.05:
			ba.position = spot
			ba.rotation.y = PI if at_tea else 0.0
		var clip := "Base_Wait" if at_tea else "Act_SitChair_Idle"
		if ba_here and ba.anim and ba.anim.current_animation != clip:
			ba.play(clip, 0.2)
		for p in _ba_props:
			p.visible = ba_here and not at_tea
	var me_here := h >= ME[0] and h < ME[1] and me_day != Clock.day and plot.cutscene == null and _lives_here()
	if me_here and me == null:
		me = _person("me", plot.CHONG + Vector3(1.25, 0, 0.75), -PI / 2.0)
		me.play("Base_Wait", 0.0)
		var y: float = plot.scenery.height_at(plot.CHONG.x, plot.CHONG.z)
		_me_props.append(_no_shadow(Furniture.place(plot, "mam_com", Vector3(plot.CHONG.x + 0.45, y + 0.435, plot.CHONG.z), 0.0, false)))
		plot.hud.toast(tr("ME_T_ARRIVE"), 3.0)
	if me:
		me.visible = me_here
		for p in _me_props:
			p.visible = me_here

func _no_shadow(n: Node3D) -> Node3D:
	for g: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

func _lives_here() -> bool:
	return FarmHouse.saved_level() >= 1 and not plot._rebuilding()

func _person(id: String, at: Vector3, yaw: float) -> Chibi:
	var cast: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hometown/cast.json"))
	var who: Dictionary = cast["people"].get(id, {})
	var look := Looks.DEFAULT.duplicate(true)
	for src in [cast["bases"].get(str(who.get("look", {}).get("base", "")), {}), who.get("look", {})]:
		for k in src:
			if k != "base":
				look[k] = src[k].duplicate(true) if src[k] is Dictionary else src[k]
	var c := Chibi.new()
	c.name = id
	add_child(c)
	c.build(look)
	if not OS.get_cmdline_user_args().has("--no-merge"):
		ChibiMerge.merge(c)

	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if mi.visible and not (n.begins_with("Merged") or n.begins_with("Hair_") or n.begins_with("Body")):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	at.y = plot.scenery.height_at(at.x, at.z)
	c.position = at
	c.rotation.y = yaw
	return c

func _open_ba() -> void:
	_menu = [{"kind": "talk"}]
	for k in plot.bag:
		if int(plot.bag[k]) > 0:
			_menu.append({"kind": "gift", "key": k})
	_menu_who = "ba"
	_menu_i = 0
	plot.player.controls = false
	_draw()

func _ba_talk() -> void:
	var line := "BA_LINE_%d" % (posmod(Clock.day, BA_LINES) + 1)
	if ba_word_day != Clock.day:
		ba_word_day = Clock.day
		if not plot.dry:
			Progress.friend("ba_noi", 1)
	_close()
	plot.hud.toast(tr(line), 4.5)

func _ba_gift(key: String) -> void:
	if ba_gift_day == Clock.day:
		plot.hud.toast(tr("BA_T_GIFTED"), 2.0)
		return
	plot.bag[key] = int(plot.bag.get(key, 0)) - 1
	if int(plot.bag[key]) <= 0:
		plot.bag.erase(key)
	plot._update_bag()
	ba_gift_day = Clock.day
	var love := key in BA_LOVES
	if not plot.dry:
		Progress.friend("ba_noi", 6 if love else 3)
	_close()
	plot.hud.toast(tr("BA_T_GIFT_LOVE" if love else "BA_T_GIFT"), 3.0)

func _dinner_with_me() -> void:
	plot._busy = true
	plot.player.controls = false
	await plot.hud.fade(1.0, 0.7)
	Clock.minute += 40.0
	me_day = Clock.day
	dinner_day = Clock.day
	if not plot.dry:
		Progress.rest("dinner")
		Progress.friend("me", 2)
	if me:
		me.visible = false
	for p in _me_props:
		p.visible = false
	plot._light()
	await get_tree().create_timer(0.4).timeout
	await plot.hud.fade(0.0, 0.7)
	plot.hud.toast(tr("ME_T_DINNER"), 3.2)
	plot.player.controls = true
	plot._busy = false

class PotScene extends CanvasLayer:
	signal done
	var items: Array = []
	var _t := 0.0
	var _draw: Control
	const LONG := 2.6

	func _ready() -> void:
		layer = 40
		var dim := ColorRect.new()
		dim.color = Color(0.1, 0.07, 0.05, 0.35)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		_draw = Control.new()
		_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
		_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_draw.draw.connect(_paint)
		add_child(_draw)

	func _process(d: float) -> void:
		_t += d
		_draw.queue_redraw()
		if _t >= LONG:
			set_process(false)
			done.emit()

	func _input(e: InputEvent) -> void:
		var hit: bool = (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_F, KEY_SPACE, KEY_ENTER]) \
			or (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed) \
			or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_A)
		if hit and _t > 0.4:
			_t = maxf(_t, LONG - 0.2)
		get_viewport().set_input_as_handled()

	func _paint() -> void:
		var sz := _draw.size
		var c := Vector2(sz.x * 0.5, sz.y * 0.5)
		var r := minf(sz.x, sz.y) * 0.17
		for i in 7:
			var a := float(i) / 6.0 - 0.5
			var f := 0.75 + 0.25 * sin(_t * 9.0 + i * 1.7)
			_draw.draw_circle(c + Vector2(a * r * 1.6, r * 1.05), r * 0.22 * f, Color(1.0, 0.55 + 0.2 * f, 0.2, 0.85))
		_draw.draw_circle(c + Vector2(0, r * 0.12), r * 1.12, Color("2b2421"))
		_draw.draw_circle(c, r, Color("6b4e3a"))
		var boil := clampf((_t - 0.4) / 1.2, 0.0, 1.0)
		_draw.draw_circle(c, r * 0.86, Color("8a6a4a").lerp(Color("c9a46a"), boil))
		var drop := 0.9 / maxf(1.0, items.size())
		for i in items.size():
			var k := clampf((_t - i * drop) / 0.35, 0.0, 1.0)
			var a := i * TAU / maxf(1.0, items.size()) + _t * 0.8 * boil
			var at := c + Vector2(cos(a), sin(a)) * r * 0.45 * k + Vector2(0, -r * 1.6 * (1.0 - k))
			_draw.draw_circle(at, r * 0.16, items[i])
		for i in 9:
			var ph := fmod(_t * 1.3 + i * 0.37, 1.0)
			var bx := c + Vector2(sin(i * 2.3) * r * 0.6, cos(i * 1.7) * r * 0.5)
			if boil > 0.3:
				_draw.draw_arc(bx, r * 0.06 * ph, 0, TAU, 12, Color(1, 1, 1, 0.5 * (1.0 - ph)), 2.0)
			var sy := c + Vector2(sin(i * 1.9 + _t) * r * 0.5, -r * (0.9 + ph * 1.4))
			_draw.draw_circle(sy, r * (0.12 + 0.18 * ph), Color(1, 1, 1, 0.22 * boil * (1.0 - ph)))
		if _t > LONG - 0.5:
			var f := (_t - (LONG - 0.5)) / 0.5
			_draw.draw_circle(c, r * (1.0 + f * 0.6), Color(1.0, 0.9, 0.6, 0.35 * (1.0 - f)))
