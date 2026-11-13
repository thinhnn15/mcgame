extends Node3D

const OUT := Phone.PORTRAITS
const PX := 256
const WAIT := 0.6

var _vp: SubViewport
var _cam: Camera3D

func _ready() -> void:
	Stage.setup(self)
	_vp = SubViewport.new()
	_vp.size = Vector2i(PX, PX)
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 31.0
	_cam.near = 0.3
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff3e6")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_cam.environment = env
	_vp.add_child(_cam)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_bake.call_deferred()

func _bake() -> void:
	var contacts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Phone.CONTACTS))["contacts"]
	var cast: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hometown/cast.json"))
	var chars: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	for id in contacts:
		var src := str(contacts[id].get("look", ""))
		var look := _look(src, cast, chars)
		if look.is_empty():
			if src != "":
				push_warning("portrait_bake: no look '%s' for %s" % [src, id])
			continue
		var c := Chibi.new()
		add_child(c)
		c.build(look)
		await get_tree().process_frame
		c.play("Base_Wait", 0.0)
		var f: Dictionary = TalkBox.FACES.get(str(contacts[id].get("face", "smile")), TalkBox.FACES["smile"])
		c.base_eye = f["eye"]
		c.base_brow = f["brow"]
		c.base_mouth = f["mouth"]
		await get_tree().create_timer(WAIT).timeout
		_aim(c)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _circle(_vp.get_texture().get_image())
		img.save_png(ProjectSettings.globalize_path(OUT + id + ".png"))
		print("portrait_bake: ", OUT + id + ".png")
		c.queue_free()
		await get_tree().process_frame
	get_tree().quit()

func _look(src: String, cast: Dictionary, chars: Dictionary) -> Dictionary:
	"""The look a contact points at, over Looks.DEFAULT (cast.json's 'base' first, as HomeEvents does)."""
	var l := {}
	if src.begins_with("cast:"):
		l = cast["people"].get(src.substr(5), {}).get("look", {})
	elif src.begins_with("chars:"):
		l = chars.get(src.substr(6), {}).get("look", {})
	if l.is_empty():
		return {}
	var look := Looks.DEFAULT.duplicate(true)
	for part in [cast["bases"].get(str(l.get("base", "")), {}), l]:
		for k in part:
			if k != "base":
				look[k] = part[k].duplicate(true) if part[k] is Dictionary else part[k]
	return look

func _aim(c: Chibi) -> void:
	"""TalkBox's framing: the camera and its target carried by the Head bone (Blender axes x left, y back, z up)."""
	var skel := c.skel
	var bi := skel.find_bone("Head")
	var d := skel.get_bone_global_pose(bi) * skel.get_bone_global_rest(bi).affine_inverse()
	var at := skel.global_transform * (d * Vector3(TalkBox.CAM_AT.x, TalkBox.CAM_AT.z, -TalkBox.CAM_AT.y))
	var from := skel.global_transform * (d * Vector3(TalkBox.CAM_FROM.x, TalkBox.CAM_FROM.z, -TalkBox.CAM_FROM.y))
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)

func _circle(img: Image) -> Image:
	"""Cut to the round avatar: clear outside the circle, a 1.5 px soft edge."""
	img.convert(Image.FORMAT_RGBA8)
	var r := PX * 0.5
	for y in PX:
		for x in PX:
			var e := clampf((r - Vector2(x + 0.5 - r, y + 0.5 - r).length()) / 1.5, 0.0, 1.0)
			if e < 1.0:
				var p := img.get_pixel(x, y)
				p.a *= e
				img.set_pixel(x, y, p)
	return img
