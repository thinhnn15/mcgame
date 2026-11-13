class_name StoryPhotoSet
extends Node3D

const CAST := "res://data/hometown/cast.json"
const SIT := ["Act_SitChair_Idle", "Act_SitChair_Phone", "Act_SitChair_Slump"]

var people := {}

func _ready() -> void:
	Stage.setup(self)
	var cam := get_node_or_null("Cam") as Camera3D
	if cam and cam.has_meta("aim"):
		cam.look_at(to_global(cam.get_meta("aim")), Vector3.UP)
		cam.rotate_object_local(Vector3.BACK, deg_to_rad(float(cam.get_meta("roll", 0.0))))
	var cast: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CAST))
	for m in get_children():
		if not m is Marker3D:
			continue
		if m.has_meta("prop"):
			var n := Furniture.place(self, str(m.get_meta("prop")), m.position, m.rotation_degrees.y, false)
			n.scale = m.scale
		elif m.has_meta("box"):
			_box(m)
		elif m.has_meta("cast"):
			var id := str(m.get_meta("cast"))
			if not cast["people"].has(id):
				push_warning("StoryPhotoSet: nobody called '%s' in cast.json" % id)
				continue
			people[m.name] = put(cast_look(cast, id, m.get_meta("look", {})), m)

static func cast_look(cast: Dictionary, id: String, over := {}) -> Dictionary:
	"""A cast member's look over Looks.DEFAULT ('base' first, as HomeEvents does), then the marker's overrides."""
	var l: Dictionary = cast["people"][id].get("look", {})
	var look := Looks.DEFAULT.duplicate(true)
	for part in [cast["bases"].get(str(l.get("base", "")), {}), l, over]:
		for k in part:
			if k != "base":
				look[k] = part[k].duplicate(true) if part[k] is Dictionary else part[k]
	return look

func put_hero(look: Dictionary) -> Chibi:
	"""The hero on the Hero marker, in `look` (the player's Looks) with the marker's own wear put on over it."""
	var m: Marker3D = get_node("Hero")
	var l := look.duplicate(true)
	for k in m.get_meta("wear", {}):
		l[k] = m.get_meta("wear")[k]
	return put(l, m)

func put(look: Dictionary, m: Marker3D) -> Chibi:
	var l := look.duplicate(true)
	if m.get_meta("kid", false):
		l["body"] = "kid"
	var c := Chibi.new()
	add_child(c)
	c.build(l)
	c.position = m.position
	c.rotation.y = m.rotation.y
	var pose := str(m.get_meta("pose", "Base_Wait"))
	c.play(pose, 0.0)
	if pose in SIT:
		c.position.y += c.seat_lift()
	if m.has_meta("hold"):
		c.hold(str(m.get_meta("hold")))
	if m.has_meta("at") and c.anim.has_animation(pose):
		c.anim.seek(float(m.get_meta("at")) * c.anim.get_animation(pose).length, true)
		c.anim.pause()
	var f: Dictionary = TalkBox.FACES.get(str(m.get_meta("face", "smile")), TalkBox.FACES["smile"])
	c.base_eye = f["eye"]
	c.base_brow = f["brow"]
	c.base_mouth = f["mouth"]
	return c

func _box(m: Marker3D) -> void:
	var spec: Dictionary = m.get_meta("box")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = spec.get("size", Vector3.ONE * 0.2)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = spec.get("color", Color.WHITE)
	mat.roughness = 0.85
	mi.material_override = mat
	mi.transform = m.transform
	mi.position.y += bm.size.y * 0.5
	add_child(mi)
