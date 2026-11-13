extends Node

const NOT_PLAY := ["res://scenes/logo.tscn", "res://scenes/title.tscn", "res://scenes/credits.tscn"]
const FLUSH_EVERY := 60.0
const THUMB_EVERY := 600.0
const THUMB_FIRST := 20.0
const DARK := 0.09

var off := false
var _acc := 0.0
var _since_flush := 0.0
var _since_thumb := 0.0
var _thumb_done := false
var _scene := ""
var _seen: Node
var _counting := false
var core := ClassDB.class_exists(&"SaveSlots")

func _init() -> void:
	_core(&"recover")

func _core(method: StringName, args := []) -> Variant:
	"""SaveSlots.<method>(args), or null in a build without it."""
	if not core:
		return null
	return Callable(ClassDB, &"class_call_static").callv([&"SaveSlots", method] + args)

func slots() -> Array:
	"""Each slot's card (SaveSlots.info); one slot, the files in place, when the core has no SaveSlots."""
	if core:
		return _core(&"all")
	Story.load_saved()
	var empty := not Story.exists() and not Hero.exists()
	return [{"slot": 1, "active": true, "empty": empty, "name": Hero.name, "chapter": Story.chapter, "day": Story.day,
		"opening_done": Story.opening_done, "playtime": 0.0, "saved_at": 0, "thumb": ""}]

func active() -> int:
	return int(_core(&"active")) if core else 1

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var direct := false
	for a in OS.get_cmdline_args():
		if a.ends_with(".tscn") or a.ends_with(".scn") or a == "--write-movie" or a == "-s" or a == "--script":
			direct = true
	off = direct or DisplayServer.get_name() == "headless" or args.has("--still") or args.has("--no-slot-time")
	set_process(not off)

func _playing() -> bool:
	var cs := get_tree().current_scene
	return cs != null and not cs.scene_file_path in NOT_PLAY and FileAccess.file_exists(Story.FILE)

func _process(delta: float) -> void:
	var cs := get_tree().current_scene
	if cs != _seen:
		_seen = cs
		_scene = cs.scene_file_path if cs else ""
		_counting = _playing()
	if not _counting:
		return
	_acc += delta
	_since_flush += delta
	_since_thumb += delta
	if _since_flush >= FLUSH_EVERY:
		flush()
	if (not _thumb_done and _since_thumb >= THUMB_FIRST) or _since_thumb >= THUMB_EVERY:
		_since_thumb = 0.0
		thumb()

func flush() -> void:
	"""The time played so far onto the active slot's card."""
	_since_flush = 0.0
	if off or _acc <= 0.0 or not FileAccess.file_exists(Story.FILE):
		_acc = 0.0
		return
	_core(&"touch", [_acc, _scene])
	_acc = 0.0

func thumb() -> void:
	"""What the screen shows now, as the slot's picture (skipped in the dark: a fade or a black card)."""
	if off or not _playing():
		return
	var tex := get_viewport().get_texture()
	var img: Image = tex.get_image() if tex else null
	if img == null or img.is_empty():
		return
	var probe := img.duplicate() as Image
	probe.resize(16, 9, Image.INTERPOLATE_BILINEAR)
	var lum := 0.0
	for y in 9:
		for x in 16:
			lum += probe.get_pixel(x, y).get_luminance()
	if lum / 144.0 < DARK:
		return
	_core(&"save_thumb", [img])
	_thumb_done = true

func _notification(what: int) -> void:
	if off:
		return
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED:
			thumb()
			flush()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_EXIT_TREE:
			flush()

func forget_all() -> void:
	"""Every script's in-memory copy of a save back to its defaults (another slot is in place now)."""
	Story.forget()
	Hero.forget()
	Bonds.forget()
	Clock.forget()
	HomeEvents.forget()
	Phone.forget()
	FishLog.forget()
	DecorRoom.forget()
	if ClassDB.class_has_method(&"Progress", &"forget"):
		Callable(ClassDB, &"class_call_static").callv([&"Progress", &"forget"])
	_acc = 0.0
	_since_thumb = 0.0
	_thumb_done = false

func use_slot(n: int) -> bool:
	"""Play slot n from now on: the time so far goes onto the old slot's card, then the files change places."""
	if not core:
		return n == 1
	flush()
	var ok: bool = _core(&"use", [n])
	forget_all()
	return ok

func erase_slot(n: int) -> void:
	if not core:
		return
	_core(&"erase", [n])
	if n == active():
		forget_all()
