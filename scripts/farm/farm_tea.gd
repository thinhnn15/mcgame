class_name FarmTea
extends Node3D

const CFG := "res://data/farm/che.json"
const REACH := 1.25

var plot: Node3D
var cfg := {}
var patches := []
var last := {}
var ba_pick_day := -1
var _have := false
var _nodes: Array[Node] = []
var _roast: RoastPan

static func add(p: Node3D) -> FarmTea:
	var t := FarmTea.new()
	t.name = "FarmTea"
	t.plot = p
	p.add_child(t)
	return t

func _ready() -> void:
	_have = ClassDB.class_exists("TeaRows")
	var c = JSON.parse_string(FileAccess.get_file_as_string(CFG))
	cfg = c if c is Dictionary else {}
	var per := int(cfg.get("patch_bushes", 4))
	var groups := {}
	for b: Dictionary in FarmFields.tea_bushes(plot.scenery):
		var id := "r%d_p%d" % [b.row, int(b.k) / per]
		if not groups.has(id):
			groups[id] = {"id": id, "row": b.row, "bushes": [], "seed": groups.size() + 1}
		groups[id].bushes.append(b)
	for id in groups:
		var g: Dictionary = groups[id]
		var lo := Vector3(1e9, 0, 0)
		var hi := Vector3(-1e9, 0, 0)
		var sum := Vector3.ZERO
		for b: Dictionary in g.bushes:
			sum += b.pos
			lo.x = minf(lo.x, b.pos.x)
			hi.x = maxf(hi.x, b.pos.x)
		g["centre"] = sum / g.bushes.size()
		g["half"] = (hi.x - lo.x) * 0.5 + 0.45
		patches.append(g)
	redraw()

func to_dict() -> Dictionary:
	return {"last": last, "ba": ba_pick_day}

func from_dict(d: Dictionary) -> void:
	last = {}
	for k in d.get("last", {}):
		last[k] = int(d["last"][k])
	ba_pick_day = int(d.get("ba", -1))
	redraw()

func is_open() -> bool:
	return OS.get_cmdline_user_args().has("--che") or Clock.chapter() >= 3 or bool(Story.flag("doi_che_mo", false))

func _last_of(p: Dictionary) -> int:
	if not last.has(p.id):
		last[p.id] = Clock.day - int(cfg.get("every", 2))
	return int(last[p.id])

func ready_at(p: Dictionary) -> bool:
	return _have and bool(ClassDB.class_call_static("TeaRows", "ready", cfg, _last_of(p), Clock.day))

func redraw() -> void:
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	var plants := []
	for p: Dictionary in patches:
		var buds := not _have or ready_at(p)
		for b: Dictionary in p.bushes:
			plants.append({"model": "che_3" if buds else "che_2", "yaw": b.yaw, "pos": b.pos})
	for mmi: MultiMeshInstance3D in Crops.draw(self, plants, false):
		mmi.visibility_range_end = 0.0
		_nodes.append(mmi)

func _patch_at(at: Vector3) -> Dictionary:
	var best := {}
	var bd := 1e9
	for p: Dictionary in patches:
		var c: Vector3 = p.centre
		var dx := maxf(absf(at.x - c.x) - float(p.half), 0.0)
		var dz := absf(at.z - c.z)
		if dx < 0.3 and dz < REACH and dz + dx < bd:
			best = p
			bd = dz + dx
	return best

func hint_at(at: Vector3) -> String:
	if not _have or _roast != null:
		return ""
	var p := _patch_at(at)
	if p.is_empty():
		return ""
	return "FARM_HINT_CHE" if is_open() else "FARM_HINT_CHE_SHUT"

func use(at: Vector3) -> bool:
	if not _have:
		return false
	var p := _patch_at(at)
	if p.is_empty():
		return false
	if not is_open():
		plot.hud.toast(tr("CHE_T_SHUT"), 2.6)
		return true
	if not ready_at(p):
		plot.hud.toast(tr("CHE_T_WAIT"), 2.2)
		return true
	_pick(p)
	return true

func ba_near(at: Vector3) -> bool:
	var d: FarmDays = plot.days
	return d != null and d.ba != null and d.ba.visible and Vector2(d.ba.global_position.x - at.x, d.ba.global_position.z - at.z).length() < 5.0

func _pick(p: Dictionary) -> void:
	plot._busy = true
	var face: Vector3 = p.centre - plot.player.global_position
	face.y = 0
	if face.length() > 0.01:
		plot._face(face)
	if await plot._clip("Tool_Egg_Pick", 19, 46):
		var with_ba := ba_near(plot.player.global_position)
		var got: Dictionary = ClassDB.class_call_static("TeaRows", "pick", cfg, int(p.seed), Clock.day, Clock.hour(),
			Clock.weather != "", with_ba)
		last[p.id] = Clock.day
		Sound.play_at("harvest.pick", p.centre + Vector3(0, 0.5, 0))
		plot._gain(str(cfg["keys"]["fresh"]), int(got.n))
		plot._xp("hai")
		redraw()
		if with_ba and ba_pick_day != Clock.day:
			ba_pick_day = Clock.day
			if not plot.dry:
				Progress.friend("ba_noi", 1)
			await get_tree().create_timer(1.5).timeout
			plot.hud.toast(tr("CHE_T_BA"), 3.5)
		elif bool(got.dew):
			await get_tree().create_timer(1.5).timeout
			plot.hud.toast(tr("CHE_T_DEW"), 2.4)
	plot._busy = false

func ba_spot() -> Vector3:
	for p: Dictionary in patches:
		if ready_at(p):
			return p.centre + Vector3(float(p.half) + 0.9, 0, 0.75)
	return (patches[0].centre if not patches.is_empty() else Vector3.ZERO) + Vector3(0, 0, 0.75)

func ba_here(h: float) -> bool:
	var b: Dictionary = cfg.get("ba", {})
	return _have and is_open() and h >= float(b.get("from", 6.0)) and h < float(b.get("to", 8.5))

func price_of(key: String) -> int:
	return int(cfg.get("price", {}).get(key, 0))

func can_roast() -> bool:
	return _have and int(plot.bag.get(str(cfg.get("keys", {}).get("fresh", "CROP_CHE")), 0)) >= int(cfg["roast"]["needs"])

func start_roast() -> void:
	if not can_roast():
		plot.hud.toast(tr("CHE_T_FEW") % int(cfg["roast"]["needs"]), 2.4)
		return
	plot._busy = true
	plot.player.controls = false
	_roast = RoastPan.new()
	_roast.beat = float(cfg["roast"]["beat"])
	_roast.window = float(cfg["roast"]["window"])
	plot.add_child(_roast)
	var offsets: PackedFloat32Array = await _roast.done
	_roast.queue_free()
	_roast = null
	var res: Dictionary = ClassDB.class_call_static("TeaRows", "roast", cfg, offsets)
	var fresh := str(cfg["keys"]["fresh"])
	plot.bag[fresh] = int(plot.bag[fresh]) - int(cfg["roast"]["needs"])
	if int(plot.bag[fresh]) <= 0:
		plot.bag.erase(fresh)
	var key := str(cfg["keys"]["fine" if res.fine else "dry"])
	plot._gain(key, 1)
	plot._xp("sao_che")
	plot.hud.toast(tr("CHE_T_FINE" if res.fine else "CHE_T_DRY"), 3.0)
	plot.player.controls = true
	plot._busy = false

class RoastPan extends CanvasLayer:
	signal done(offsets: PackedFloat32Array)
	const TURNS := 3
	var beat := 1.6
	var window := 0.18
	var _t := 0.0
	var _turn := 0
	var _offsets := PackedFloat32Array()
	var _pressed := false
	var _flash := 0.0
	var _good := false
	var _draw: Control
	var _label: Label

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
		_label = Label.new()
		_label.add_theme_font_size_override("font_size", 24)
		_label.add_theme_color_override("font_color", Color("fff6e6"))
		_label.add_theme_color_override("font_outline_color", Color("5b4a44"))
		_label.add_theme_constant_override("outline_size", 8)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_label.offset_top = -260
		_label.offset_left = -400
		_label.offset_right = 400
		add_child(_label)
		_text()

	func _text() -> void:
		_label.text = tr("CHE_ROAST_TURN") % [mini(_turn + 1, TURNS), TURNS] + "\n" + \
			tr("CHE_ROAST_HINT_TOUCH" if TouchControls.active else "CHE_ROAST_HINT")

	func _process(d: float) -> void:
		_t += d
		_flash = maxf(0.0, _flash - d * 2.0)
		if _t > beat + window + 0.25:
			_press_at(_t - beat)
		_draw.queue_redraw()

	func _press_at(off: float) -> void:
		_offsets.append(off)
		_good = absf(off) <= window
		_flash = 1.0
		Sound.play("bag.put")
		_turn += 1
		_t = 0.0
		if _turn >= TURNS:
			set_process(false)
			set_process_input(false)
			await get_tree().create_timer(0.6).timeout
			done.emit(_offsets)
			return
		_text()

	func _input(e: InputEvent) -> void:
		var hit := false
		if e is InputEventKey and e.pressed and not e.echo:
			hit = e.physical_keycode in [KEY_F, KEY_SPACE, KEY_ENTER]
		elif e is InputEventJoypadButton and e.pressed:
			hit = e.button_index == JOY_BUTTON_A
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			hit = true
		elif e is InputEventScreenTouch and e.pressed:
			hit = true
		if hit and _t > 0.25:
			_press_at(_t - beat)
		get_viewport().set_input_as_handled()

	func _paint() -> void:
		var sz := _draw.size
		var c := Vector2(sz.x * 0.5, sz.y * 0.47)
		var rim := minf(sz.x, sz.y) * 0.2
		_draw.draw_circle(c, rim * 1.12, Color("3b2f2a"))
		_draw.draw_circle(c, rim, Color("5a4a40"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + _turn
		for i in 26:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * rim * 0.78
			var p := c + Vector2(cos(a), sin(a)) * r
			var leaf := Color("6f8f3a").lerp(Color("4c5e2a"), float(_turn) / TURNS)
			_draw.draw_set_transform(p, a + _turn * 0.7, Vector2(1.0, 0.45))
			_draw.draw_circle(Vector2.ZERO, rim * 0.09, leaf)
		_draw.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var k := _t / beat
		var ring := lerpf(rim * 2.1, rim, k) if k <= 1.0 else rim * maxf(0.6, 1.0 - (k - 1.0) * 0.8)
		_draw.draw_arc(c, ring, 0.0, TAU, 64, Color(1.0, 0.95, 0.8, 0.85), 5.0)
		_draw.draw_arc(c, rim, 0.0, TAU, 64, Color(1.0, 0.85, 0.5, 0.6), 3.0)
		if _flash > 0.0:
			_draw.draw_arc(c, rim * (1.0 + (1.0 - _flash) * 0.3), 0.0, TAU, 64,
				Color(1.0, 0.9, 0.45, _flash) if _good else Color(0.9, 0.9, 0.9, _flash * 0.6), 6.0)
