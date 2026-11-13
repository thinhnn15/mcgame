class_name AnimPacks
extends RefCounted

const DATA := "res://data/anim_packs.json"
const DIR := "res://characters/anims/"

static var _data := {}
static var _lib: AnimationLibrary
static var _loaded := {}
static var lazy := false

static func _read() -> void:
	if _data.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
		_data = d if d is Dictionary else {"packs": {}}

static func on_build(anim: AnimationPlayer) -> void:
	"""A body was built (Chibi.build): remember its clip library; outside the lazy scenes, every pack in."""
	_read()
	if anim == null or not anim.has_animation_library(""):
		return
	var lib := anim.get_animation_library("")
	if lib != _lib:
		_lib = lib
		_loaded.clear()
	var scene := anim.get_tree().current_scene if anim.is_inside_tree() else null
	var key := scene.scene_file_path.get_file().get_basename() if scene else ""
	lazy = key in _data.get("lazy_scenes", [])
	if not lazy:
		for pack in _data.get("packs", {}):
			need(pack)

static func need(pack: String) -> void:
	if _lib == null or _loaded.has(pack) or not ResourceLoader.exists(DIR + pack + ".res"):
		return
	var src: AnimationLibrary = load(DIR + pack + ".res")
	var names := []
	for name in src.get_animation_list():
		if not _lib.has_animation(name):
			var a := src.get_animation(name)
			if String(name) in Chibi.LOOPING:
				a.loop_mode = Animation.LOOP_LINEAR
			_lib.add_animation(name, a)
			names.append(name)
	_loaded[pack] = names

static func release(pack: String) -> void:
	"""The pack's clips out again (in the lazy scenes: an event's clips once it is over)."""
	if not lazy or _lib == null or not _loaded.has(pack):
		return
	for name in _loaded[pack]:
		if _lib.has_animation(name):
			_lib.remove_animation(name)
	_loaded.erase(pack)

static func pack_of(clip: String) -> String:
	_read()
	for pack in _data.get("packs", {}):
		for p: String in _data["packs"][pack]:
			if clip.begins_with(p):
				return pack
	return ""

static func ensure(clip: String) -> void:
	"""A clip asked for that the body doesn't have: its pack in (a short load, once)."""
	var pack := pack_of(clip)
	if pack != "":
		need(pack)

static func loaded() -> Array:
	return _loaded.keys()
