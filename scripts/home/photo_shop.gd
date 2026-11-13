class_name PhotoShop
extends CanvasLayer

signal closed

const INK := Color("5b4a44")
const PAPER := Color("fff6e6")
const PICK := Color("ffd98a")
const PRICES := "res://data/home/prices.json"
const OPEN_ALWAYS := ["vien_giay", "khung_go_moc"]

var shot := ""
var size := "vua"
var mount := "tuong"
var frame := "khung_go_moc"
var ready_today := false
var _panel: PanelContainer
var _shots: HFlowContainer
var _sizes: HBoxContainer
var _mounts: HBoxContainer
var _frames: HFlowContainer
var _price: Label
var _send: Button
var _note: Label
var _tex := {}

func _ready() -> void:
	layer = 20
	_build()
	_panel.visible = false

func open() -> void:
	var album := PhotoPrint.album()
	shot = album[album.size() - 1] if not album.is_empty() and shot == "" else shot
	_panel.visible = true
	_refresh()

func close() -> void:
	_panel.visible = false
	closed.emit()

func price() -> int:
	var p = JSON.parse_string(FileAccess.get_file_as_string(PRICES)) if FileAccess.file_exists(PRICES) else {}
	return int((p as Dictionary).get("photo_print", {}).get(size, {"nho": 3, "vua": 6, "to": 12}[size])) if p is Dictionary else 6

func frames_open() -> Array:
	var out := []
	var all := "--all" in OS.get_cmdline_user_args()
	for f in DecorRoom.art().get("frames", []):
		if not (all or f["id"] in OPEN_ALWAYS or Progress.is_open(f.get("unlock", f["id"]))):
			continue
		for v in f.get("variants", [""]):
			out.append([f["id"] + ("" if v == "" else "_" + v), f])
	return out

func send() -> bool:
	if shot == "":
		return false
	var cost := price()
	if not Progress.spend(cost):
		_note.text = tr("PHOTO_NO_MONEY")
		return false
	Clock.load_saved()
	PhotoPrint.order(shot, size, frame, mount, Clock.day + (0 if ready_today else 1))
	_note.text = tr("PHOTO_SENT")
	Sound.play("ui.click", -2.0)
	return true

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(PAPER, 0.97), 18, Color("e3b96a"), 3, 18))
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(860, 0)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	var title := _label(26)
	title.text = tr("PHOTO_TITLE")
	col.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 230)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_shots = HFlowContainer.new()
	_shots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_shots)
	_sizes = _row(col, "PHOTO_SIZE")
	_mounts = _row(col, "PHOTO_MOUNT")
	var fr := HBoxContainer.new()
	var fl := _label(18)
	fl.text = tr("PHOTO_FRAME")
	fl.custom_minimum_size.x = 110
	fr.add_child(fl)
	_frames = HFlowContainer.new()
	_frames.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fr.add_child(_frames)
	col.add_child(fr)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	col.add_child(bottom)
	_price = _label(20)
	_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_price)
	_send = _button(tr("PHOTO_SEND"))
	_send.pressed.connect(func() -> void:
		if send():
			_refresh())
	bottom.add_child(_send)
	var shut := _button(tr("PHOTO_CLOSE"))
	shut.pressed.connect(close)
	bottom.add_child(shut)
	_note = _label(17)
	col.add_child(_note)

func _row(col: VBoxContainer, key: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	var l := _label(18)
	l.text = tr(key)
	l.custom_minimum_size.x = 110
	r.add_child(l)
	col.add_child(r)
	return r

func _refresh() -> void:
	for box in [_shots, _frames]:
		for c in box.get_children():
			c.queue_free()
	for box in [_sizes, _mounts]:
		for i in range(1, box.get_child_count()):
			box.get_child(i).queue_free()
	var album := PhotoPrint.album()
	if album.is_empty():
		var l := _label(18)
		l.text = tr("PHOTO_ALBUM_EMPTY")
		_shots.add_child(l)
	for i in range(album.size() - 1, -1, -1):
		var id: String = album[i]
		var b := _button("")
		b.icon = _shot_tex(id)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(168, 112)
		b.add_theme_stylebox_override("normal", UiTheme.box(PICK if id == shot else Color.WHITE, 10,
			Color("e3b96a") if id == shot else Color("e3cfae"), 4 if id == shot else 2, 4))
		b.pressed.connect(func() -> void:
			shot = id
			_refresh())
		_shots.add_child(b)
	var stand: Array = DecorRoom.art()["photo"].get("stand", [])
	for sz in ["nho", "vua", "to"]:
		var b := _button(tr("PHOTO_SIZE_" + sz.to_upper()), sz == size)
		b.pressed.connect(func() -> void:
			size = sz
			if sz not in stand:
				mount = "tuong"
			_refresh())
		_sizes.add_child(b)
	for m in ["tuong", "ban"]:
		var b := _button(tr("PHOTO_MOUNT_" + m.to_upper()), m == mount)
		b.disabled = m == "ban" and size not in stand
		b.pressed.connect(func() -> void:
			mount = m
			_refresh())
		_mounts.add_child(b)
	var open_ := frames_open()
	if open_.filter(func(f): return f[0] == frame).is_empty() and not open_.is_empty():
		frame = open_[0][0]
	for f in open_:
		var fid: String = f[0]
		var b := _button(tr("FRAME_" + fid.to_upper()), fid == frame)
		var look := DecorRoom.frame_look(fid)
		b.add_theme_color_override("font_color", Color(look.get("tint", "5b4a44")).darkened(0.3) if look.has("tint") else INK)
		b.pressed.connect(func() -> void:
			frame = fid
			_refresh())
		_frames.add_child(b)
	_price.text = tr("PHOTO_PRICE") % [price(), Progress.money()]
	_send.disabled = shot == ""

func _shot_tex(id: String) -> Texture2D:
	if not _tex.has(id):
		var img := Image.load_from_file(PhotoPrint.shot_path(id))
		if img == null:
			return null
		var k := 168.0 / img.get_width()
		img.resize(168, maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_BILINEAR)
		_tex[id] = ImageTexture.create_from_image(img)
	return _tex[id]

func _label(px: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", INK)
	return l

func _button(text: String, on := false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.text = text
	b.add_theme_font_size_override("font_size", 17)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, INK)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.35))
	b.add_theme_stylebox_override("normal", UiTheme.box(PICK if on else Color.WHITE, 12, Color("e3cfae"), 3 if on else 2, 10))
	b.add_theme_stylebox_override("hover", UiTheme.box(Color("fff0d6"), 12, Color("e3b96a"), 2, 10))
	b.add_theme_stylebox_override("pressed", UiTheme.box(PICK, 12, Color("e3b96a"), 3, 10))
	b.add_theme_stylebox_override("disabled", UiTheme.box(Color(1, 1, 1, 0.6), 12, Color("eee2cc"), 2, 10))
	return b
