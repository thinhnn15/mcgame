class_name SapGiay
extends Node3D

const SAP := "res://data/home/sap_giay.json"
const PRICES := "res://data/home/prices.json"
const BOARD := [Vector3(-1.68, 0.936, 0.306), Vector3(-1.36, 0.936, 0.306)]
const PANEL := Vector2(0.3, 0.78)
const SELLER_AT := Vector3(0.0, 0.0, -0.5)
const NEAR := 2.2
const INK := Color("5b4a44")
const PAPER := Color("fff6e6")

var hero: Node3D
var force := false
var stock: Array = []
var _sap := {}
var _prices := {}
var _open := false
var _ui_on := false
var _t := 0.0
var _body: Node3D
var _seller: Chibi
var _panels: Array[MeshInstance3D] = []
var _prompt: Label3D
var _ui: CanvasLayer
var _cards: HBoxContainer
var _money: Label
var _say: Label
var _pinned := []

static func add(parent: Node3D, at: Vector3, yaw := 0.0) -> SapGiay:
	var s := SapGiay.new()
	s.name = "SapGiay"
	s.position = at
	s.rotation.y = yaw
	parent.add_child(s)
	return s

func _ready() -> void:
	force = force or "--sap" in OS.get_cmdline_user_args()
	if force:
		(func() -> void: print("SapGiay at ", global_position, " yaw ", rad_to_deg(global_rotation.y))).call_deferred()
	_sap = JSON.parse_string(FileAccess.get_file_as_string(SAP))
	_prices = JSON.parse_string(FileAccess.get_file_as_string(PRICES)).get("surfaces", {})
	_body = HomeKit.place(self, "sap_giay", Vector3.ZERO)
	var col := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.6, 1.0, 1.0)
	cs.shape = bs
	cs.position = Vector3(-0.2, 0.5, 0.15)
	col.add_child(cs)
	_body.add_child(col)
	for at in BOARD:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = PANEL
		mi.mesh = q
		mi.position = at
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(mi)
		_panels.append(mi)
	var cast: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hometown/cast.json"))
	var who: Dictionary = cast["people"].get(String(_sap.get("seller", "co_ban_giay")), {})
	var look := Looks.DEFAULT.duplicate(true)
	for src in [cast["bases"].get(str(who.get("look", {}).get("base", "")), {}), who.get("look", {})]:
		for k in src:
			if k != "base":
				look[k] = src[k].duplicate(true) if src[k] is Dictionary else src[k]
	_seller = Chibi.new()
	_seller.name = "CoBanGiay"
	_body.add_child(_seller)
	_seller.build(look)
	if not OS.get_cmdline_user_args().has("--no-merge"):
		ChibiMerge.merge(_seller)
	_seller.position = SELLER_AT
	_prompt = Label3D.new()
	_prompt.font_size = 44
	_prompt.pixel_size = 0.004
	_prompt.modulate = INK
	_prompt.outline_modulate = PAPER
	_prompt.outline_size = 12
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.position = Vector3(0, 2.0, 0.6)
	_prompt.visible = false
	_body.add_child(_prompt)
	_refresh()
	if "--sap-ui" in OS.get_cmdline_user_args():
		_open_ui.call_deferred()

func open_now() -> bool:
	if force:
		return true
	var h := Clock.hour()
	return Clock.market() and h >= float(_sap.get("from", 6.0)) and h < float(_sap.get("until", 11.0))

func _refresh() -> void:
	_open = open_now()
	_body.visible = _open
	_body.process_mode = Node.PROCESS_MODE_INHERIT if _open else Node.PROCESS_MODE_DISABLED
	if not _open:
		_close_ui()
		return
	var lunar: Array = Clock.lunar()
	stock = PatternShop.stock(_prices, _sap.get("seasons", {}), int(lunar[0]), int(lunar[1])) \
		if ClassDB.class_exists("PatternShop") else []
	if _pinned.is_empty():
		for row in stock.slice(0, 2):
			_pinned.append(row["id"])
	_pin_board()

func _pin_board() -> void:
	for i in _panels.size():
		var mi := _panels[i]
		if i >= _pinned.size():
			mi.visible = false
			continue
		var o := _option(String(_pinned[i]))
		var tile := String(o.get("tile", "voi"))
		var be := DecorRoom.be_mat()
		var k := (be["layers"] as Array).find(tile)
		var m := float(be["metres"][k]) if k >= 0 else 1.0
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(DecorRoom.tile_path(tile))
		mat.uv1_scale = Vector3(PANEL.x / m, PANEL.y / m, 1.0)
		mat.texture_repeat = true
		mat.roughness = 1.0
		mi.material_override = mat
		mi.visible = true

func _option(id: String) -> Dictionary:
	for o in DecorRoom.finish().get("surfaces", {}).get("wall", {}).get("options", []):
		if o["id"] == id:
			return o
	return {}

func _process(delta: float) -> void:
	_t += delta
	if _t > 1.0:
		_t = 0.0
		if open_now() != _open:
			_refresh()
	if not _open:
		return
	if hero == null or not is_instance_valid(hero):
		hero = Sound.hero
	var near := hero != null and _body.global_position.distance_to(hero.global_position) < NEAR
	_prompt.visible = near and not _ui_on
	if _prompt.visible:
		_prompt.text = tr("SAP_GIAY_E")

func _unhandled_input(e: InputEvent) -> void:
	if not _open:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_E and _prompt.visible:
			_open_ui()
			get_viewport().set_input_as_handled()
		elif e.physical_keycode == KEY_ESCAPE and _ui_on:
			_close_ui()
			get_viewport().set_input_as_handled()

func _open_ui() -> void:
	if _ui == null:
		_build_ui()
	_ui_on = true
	_ui.visible = true
	if hero is Player:
		(hero as Player).controls = false
	_fill()
	Sound.play("ui.click", -6.0)

func _close_ui() -> void:
	if not _ui_on:
		return
	_ui_on = false
	if _ui:
		_ui.visible = false
	if hero is Player:
		(hero as Player).controls = true

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(PAPER, 0.97), 18, Color("e3b96a"), 3, 16))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -24
	_ui.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	var title := Label.new()
	title.text = tr("SAP_GIAY_TITLE")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_money = Label.new()
	_money.add_theme_font_size_override("font_size", 20)
	_money.add_theme_color_override("font_color", INK)
	top.add_child(_money)
	var shut := Button.new()
	shut.text = tr("SAP_GIAY_CLOSE")
	shut.focus_mode = Control.FOCUS_NONE
	shut.pressed.connect(_close_ui)
	top.add_child(shut)
	_say = Label.new()
	_say.add_theme_font_size_override("font_size", 17)
	_say.add_theme_color_override("font_color", Color(INK, 0.85))
	col.add_child(_say)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 12)
	col.add_child(_cards)

func _fill() -> void:
	for c in _cards.get_children():
		c.queue_free()
	_money.text = tr("SAP_GIAY_MONEY") % Progress.money()
	_say.text = tr("SAP_GIAY_HELLO") if not stock.is_empty() else tr("SAP_GIAY_EMPTY")
	for row in stock:
		var id := String(row["id"])
		var owned: bool = PatternShop.owned(id)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 6)
		var pic := Button.new()
		pic.focus_mode = Control.FOCUS_NONE
		pic.custom_minimum_size = Vector2(112, 112)
		pic.icon = load(DecorRoom.tile_path(String(_option(id).get("tile", "voi"))))
		pic.expand_icon = true
		pic.add_theme_stylebox_override("normal", UiTheme.box(Color.WHITE, 12,
			Color("e39a3a") if id in _pinned else Color("e3cfae"), 3 if id in _pinned else 2, 4))
		pic.pressed.connect(_pin.bind(id))
		card.add_child(pic)
		var name_ := Label.new()
		name_.text = tr("DECOR_" + id.to_upper())
		name_.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_.custom_minimum_size = Vector2(112, 0)
		name_.add_theme_font_size_override("font_size", 14)
		name_.add_theme_color_override("font_color", INK)
		card.add_child(name_)
		var buy := Button.new()
		buy.focus_mode = Control.FOCUS_NONE
		buy.text = tr("SAP_GIAY_OWNED") if owned else tr("SAP_GIAY_BUY") % int(row["price"])
		buy.disabled = owned
		buy.pressed.connect(_buy.bind(id, int(row["price"])))
		card.add_child(buy)
		_cards.add_child(card)

func _pin(id: String) -> void:
	_pinned.erase(id)
	_pinned.push_front(id)
	_pinned = _pinned.slice(0, 2)
	_pin_board()
	_fill()
	Sound.play("ui.click", -8.0)

func _buy(id: String, price: int) -> void:
	match String(PatternShop.buy(id, price)):
		"ok":
			Sound.play("mg.good", -8.0)
			_fill()
			_say.text = tr("SAP_GIAY_BOUGHT")
		"money":
			Sound.play("mg.bad", -8.0)
			_say.text = tr("SAP_GIAY_NO_MONEY")
		_:
			_fill()
