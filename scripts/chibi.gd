class_name Chibi
extends Node3D

const TOON := preload("res://shaders/toon.gdshader")
const TOON_CLOTH := preload("res://shaders/toon_cloth.gdshader")
const TOON_WEAR := preload("res://shaders/toon_wear.gdshader")
const FACE := preload("res://shaders/face_part.gdshader")
const HAIR := preload("res://shaders/hair.gdshader")
const HAIR2 := preload("res://shaders/hair2.gdshader")
const HAIR_SHADE := preload("res://shaders/hair_shade.gdshader")
const HAIR_TEX := "res://characters/hair_tex/"
const FACE_MODES := {"mEye": 1, "mMouth": 2, "mCheek": 3, "mPaint": 4}
const BODY := "res://characters/body/body.glb"
const FACE_DIR := "res://characters/face/"
const PATTERN_DIR := "res://characters/patterns/"
const LOOPING := ["Base_Wait", "Move_Walk", "Move_Run", "Tool_Cane_Walk", "Act_SitFloor", "Act_SitChair_Type", "Act_SitChair_Slump",
	"Act_Talk", "Act_Listen", "Act_PhoneLook", "Act_SitChair_Idle", "Act_FaintLie",
	"Tool_Rod_Aim", "Tool_Rod_GetKeep", "Wait_Doze", "Tool_Sweep_Keep", "Tool_Rake_Keep"]
const SLOTS := ["hair", "top", "bottom", "shoes", "socks", "hat", "acc"]

const LOW_SHOES := ["bata", "loafer", "ballet", "maryjane"]
const OPEN_SHOES := {"slides": 0.017, "flipflop": 0.024, "strapsandal": 0.024, "guoc": 0.032, "wedge": 0.042}

const ONEPIECE := ["overalls", "pinafore"]

const PAIRED_BOTTOM := {"aodai": "silk"}
const HIGH_HATS := ["nonla", "nonla_noquai"]

const HAT_BADGE := Color("e8c35a")

const TOOL_DIR := "res://characters/tools/"
const TOOL_COLORS := {"mUmbA": Color("ff93b3"), "mUmbB": Color("fff3e9"), "mUmbBand": Color("ffffff"), "mUmbTip": Color("c98b55"), "mToolWood": Color("c98b55"), "mToolWrap": Color("e86a6a"), "mToolMetal": Color("8fa3bd"),
	"mToolEdge": Color("eef3f8"), "mToolRubber": Color("3a3634"), "mToolCane": Color("b07a45"), "mCupPaper": Color("f6efe2"), "mCupSleeve": Color("c48a58"), "mCupDrink": Color("7a4a32")}

const TOOL_IMPACT := {"Tool_Axe_Hit": 9, "Tool_Hoe_Hit": 9}

const AXE_BLADE := Vector3(-0.68, -0.30, 0.782)

const HOE_EDGE := Vector3(-0.78, -0.44, 0.782)

const EMOTES := {
	"wave": {"clip": "Emo_Wave", "eye": 3, "mouth": 1, "secs": 1.6},
	"happy": {"clip": "Emo_Happy", "eye": 3, "mouth": 1, "secs": 1.2},
	"surprised": {"clip": "", "eye": 4, "mouth": 2, "secs": 1.2},
	"sleepy": {"clip": "", "eye": 1, "mouth": 4, "secs": 2.0},
	"proud": {"clip": "", "eye": 3, "mouth": 13, "secs": 3.5},
}

var body: Node3D
var skirt_follow: SkirtFollow

var _seat_hide: Array = []
var _seat_hidden := false
var _seat_lift := 0.0
var skel: Skeleton3D
var anim: AnimationPlayer
var look := {}
var parts := {}
var face_parts := {}
var noses := {}
var skin_mats: Array = []
var hair_skel: Skeleton3D
var feet: Array = []
var ears: Array = []

const COVERS_EARS := ["bob", "bob2", "bobcurl", "wolfcut", "braids", "tripo_wavy", "tripo_ponytail"]

const HAIR_RETIRED := {"undercut": "twoblock", "songvai": "tripo_wavy", "layered": "tripo_long", "hime": "tripo_long", "halfup": "tripo_long", "layered_bangs": "tripo_long", "clawclip": "topbun",
	"buns": "tripo_buns"}
const HIDDEN := preload("res://shaders/hidden.gdshader")
const EMOTE_DATA := "res://data/emotes.json"
static var emotes := {}
var _brow := -1

static func load_emotes() -> Dictionary:
	if emotes.is_empty() and FileAccess.file_exists(EMOTE_DATA):
		var ed = JSON.parse_string(FileAccess.get_file_as_string(EMOTE_DATA))
		if ed is Dictionary:
			ed.erase("_comment")
			emotes = ed
	return emotes

var _blush_extra := 0.0
var base_eye := 0
var base_mouth := 0
var base_brow := 0
var base_deco := 0
var _deco := -1
const DECO_PATCHES := {"mEye": "eye", "mCheek": "cheek", "mPaint": "paint"}

const BLINKING := [0, 4, 5, 6, 8, 12, 13, 14, 15]
var _override_until := -1.0
var _override := Vector2i(-1, -1)
var _time := 0.0
var _next_blink := 2.5
var _base_clip := "Base_Wait"

static var _tex_keep := {}
static var _tex_weak := {}

const FACE_TIMELINES := "res://data/face_timelines.json"
static var _timelines := {}
var _blink_t := -1.0
var _blink_steps := []

func build(l: Dictionary) -> void:
	body = load(BODY).instantiate()
	add_child(body)
	skel = body.find_child("Skeleton3D", true, false)
	anim = body.find_child("AnimationPlayer", true, false)
	for n in LOOPING:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	AnimPacks.on_build(anim)
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		_dress(mi, "body")
	load_emotes()
	if _timelines.is_empty() and FileAccess.file_exists(FACE_TIMELINES):
		var tl = JSON.parse_string(FileAccess.get_file_as_string(FACE_TIMELINES))
		if tl is Dictionary:
			_timelines = tl
	_kid = KidBody.new()
	skel.add_child(_kid)
	skel.move_child(_kid, 0)
	apply_look(l)
	play("Base_Wait", 0.0)
	skel.skeleton_updated.connect(_keep_final_poses)
	if skel.find_bone("Skirt_1_LF") >= 0:
		skirt_follow = SkirtFollow.new()
		skel.add_child(skirt_follow)
		skirt_follow.lap = _part_file("top").contains("dress") or _part_file("top").contains("aodai") or _part_file("top").contains("poncho") or _part_file("top").contains("pinafore") or _part_file("bottom").contains("skirt")
		skirt_follow.long_hem = _part_file("top").contains("aodai")
		skirt_follow.seat_lift = _seat_lift
	ChainSway.attach(skel)

func apply_look(l: Dictionary) -> void:
	var old := look
	look = l.duplicate(true)
	DollShape.sync(self)
	var top_spec = look.get("top", "")
	var top_shape: String = top_spec.get("shape", "") if top_spec is Dictionary else str(top_spec)
	if PAIRED_BOTTOM.has(top_shape) and top_spec is Dictionary:

		if not look.has("bottom_own"):
			look["bottom_own"] = look.get("bottom", "")
		var silk: String = top_spec.get("trim", "#ffffff")
		look["bottom"] = {"shape": PAIRED_BOTTOM[top_shape], "design": "", "color": silk, "color_b": silk,
			"trim": silk, "pattern": "plain"}
	elif look.has("bottom_own"):
		look["bottom"] = look["bottom_own"]
		look.erase("bottom_own")
	for slot in SLOTS:
		var want: String = _part_file(slot)
		var had: String = "" if old.is_empty() else _part_file(slot, old)
		if want != had or not parts.has(slot):
			set_part(slot, want)
	_apply_colors()
	_apply_face()
	_place_acc()
	_dress_apron()

	var kid := str(look.get("body", "")) == "kid"
	scale = Vector3.ONE * (float(look.get("kid_scale", KID_SCALE)) if kid else 1.0)
	if _kid:
		_kid.head_scale = float(look.get("kid_head", KID_HEAD)) if kid else 1.0
	_shown = Vector2i(-1, -1)
	_update_face(0.0)

	var has_top: bool = not parts.get("top", []).is_empty()
	var covers_crotch: bool = not parts.get("bottom", []).is_empty() or (has_top and _part_file("top").contains("dress")) \
		or (has_top and ONEPIECE.has(_part_file("top").get_file().get_basename()))
	if skirt_follow:
		skirt_follow.lap = _part_file("top").contains("dress") or _part_file("top").contains("aodai") or _part_file("top").contains("poncho") or _part_file("top").contains("pinafore") or _part_file("bottom").contains("skirt")
		skirt_follow.long_hem = _part_file("top").contains("aodai")

	var sleeveless: bool = has_top and ((_part_file("top").contains("dress") and not _part_file("top").contains("dress_office"))
		or _part_file("top").contains("balo"))
	var tuck := Vector3(0.05 if covers_crotch else 0.0, 0.025 if has_top and not sleeveless else 0.0, 0.012 if has_top else 0.0)

	_seat_hide = []
	_seat_hidden = false
	var dress_lap: bool = has_top and (_part_file("top").contains("dress") or _part_file("top").contains("poncho") or _part_file("top").contains("pinafore"))
	if dress_lap and not _part_file("bottom").contains("skirt") and skel.find_bone("Leg_2_L") >= 0:
		var knee_y := skel.get_bone_global_rest(skel.find_bone("Leg_2_L")).origin.y
		for mi in parts.get("bottom", []):
			if mi is MeshInstance3D and (mi as MeshInstance3D).get_aabb().position.y > knee_y:
				_seat_hide.append(mi)
	_seat_lift = _lap_lift(dress_lap)
	if skirt_follow:
		skirt_follow.seat_lift = _seat_lift
	for m in skin_mats:
		m.set_shader_parameter("tuck", tuck)
	if not feet.is_empty():
		var hidden := ShaderMaterial.new()
		hidden.shader = HIDDEN
		var shoe: String = _part_file("shoes").get_file().get_basename()
		var shod: bool = not parts.get("shoes", []).is_empty() and not OPEN_SHOES.has(shoe)
		feet[0].set_surface_override_material(feet[1], hidden if shod else feet[2])

		var sock = look.get("socks", {})
		var socked: bool = not shod and not parts.get("socks", []).is_empty() and sock is Dictionary
		(feet[2] as ShaderMaterial).set_shader_parameter("base_color",
			Color(sock.get("color", "#ffffff")) if socked else Color(look.get("skin", "#ffd9bd")))
		body.position.y = OPEN_SHOES.get(shoe, 0.0) if not parts.get("shoes", []).is_empty() else 0.0
	if not ears.is_empty():
		var covered: bool = COVERS_EARS.has(str(look.get("hair", "")))
		var hid_ears := ShaderMaterial.new()
		hid_ears.shader = HIDDEN
		ears[0].set_surface_override_material(ears[1], hid_ears if covered else ears[2])
	DollShape.sync(self)

const FACES := ["chubby", "slim", "square", "hollow"]
static var _face_meshes := {}

func _apply_face() -> void:
	"""The face's shape (bầu bĩnh, thon, vuông, hóp; none = the plain head): the head shell and its face patches
	swapped for the ones built on that shape (tools/build_faces.py), rigid on the Head bone like the body's own;
	their materials stay (the surface overrides are the chibi's)."""
	var face := str(look.get("face", ""))
	if face != "" and not _face_meshes.has(face):
		var path := "res://characters/face_shapes/%s.glb" % face
		var got := {}
		if ResourceLoader.exists(path):
			var sc: Node = load(path).instantiate()
			for mi: MeshInstance3D in sc.find_children("Head_*", "MeshInstance3D", true, false):
				got[String(mi.name)] = mi.mesh
			sc.free()
		_face_meshes[face] = got
	var want: Dictionary = _face_meshes.get(face, {})
	for mi: MeshInstance3D in skel.find_children("Head_*", "MeshInstance3D", true, false):
		if not mi.has_meta("plain_mesh"):
			mi.set_meta("plain_mesh", mi.mesh)
		mi.mesh = want.get(String(mi.name), mi.get_meta("plain_mesh"))

var _apron_key := ""

func _dress_apron() -> void:
	"""The apron (tạp dề, scripts/npc/apron.gd: "apron" / "apron_b" / "apron_c" in the look), a layer over any top
	skinned to the cloth chains: put on, taken off or recoloured with the look like the slots."""
	var key := "%s|%s|%s|%s" % [look.get("apron", ""), look.get("apron_b", ""), look.get("apron_c", ""), look.get("apron_style", "")]
	if key == _apron_key:
		return
	_apron_key = key
	for mi in parts.get("apron", []):
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	parts["apron"] = Apron.add(self, look) if look.has("apron") else []

func _part_file(slot: String, l := {}) -> String:
	var src: Dictionary = look if l.is_empty() else l
	var v = src.get(slot, "")
	var shape: String = v.get("shape", "") if v is Dictionary else str(v)
	if shape == "" or shape == "none":
		return ""
	if slot == "bottom":
		var top = src.get("top", "")
		if ONEPIECE.has(top.get("shape", "") if top is Dictionary else str(top)):
			return ""
	var folder: String = {"hair": "hair", "top": "tops", "bottom": "bottoms", "shoes": "shoes", "socks": "socks", "hat": "hats", "acc": "accessories"}[slot]
	if slot == "hair":
		shape = HAIR_RETIRED.get(shape, shape)
		var hat = src.get("hat", "")
		var hat_shape: String = hat.get("shape", "") if hat is Dictionary else str(hat)
		if hat_shape != "" and hat_shape != "none" and ResourceLoader.exists("res://characters/hair_cap/%s.glb" % shape):
			folder = "hair_cap"

			if HIGH_HATS.has(hat_shape) and ResourceLoader.exists("res://characters/hair_full/%s.glb" % shape):
				folder = "hair_full"

	if slot == "socks":
		var shoe_file := _part_file("shoes", src)
		var shoe_name := shoe_file.get_file().get_basename()
		if shoe_file != "" and not LOW_SHOES.has(shoe_name) and not OPEN_SHOES.has(shoe_name) \
				and ResourceLoader.exists("res://characters/socks/%s_in.glb" % shape):
			return "res://characters/socks/%s_in.glb" % shape

	if slot == "hat" and str(src.get("body", "")) == "kid" and ResourceLoader.exists("res://characters/hats/%s_kid.glb" % shape):
		return "res://characters/hats/%s_kid.glb" % shape
	return "res://characters/%s/%s.glb" % [folder, shape]

func set_part(slot: String, path: String) -> void:
	for mi in parts.get(slot, []):
		if mi.get_parent() is BoneAttachment3D:
			mi.get_parent().queue_free()
		else:
			mi.queue_free()
	if slot == "hat":
		hat_ears.clear()
	if slot == "hair" and hair_skel:
		hair_skel.queue_free()
		hair_skel = null
	parts[slot] = []
	if path == "" or not ResourceLoader.exists(path):
		return
	var p: Node3D = load(path).instantiate()
	add_child(p)
	var own := p.find_child("Skeleton3D", true, false) as Skeleton3D
	if slot == "hair" and own and own.find_bone("Root") >= 0:

		own.reparent(skel.get_parent(), false)
		own.transform = skel.transform
		var phys := HairPhysics.new()
		phys.body = skel
		phys.chibi = self
		own.add_child(phys)
		for mi in own.find_children("*", "MeshInstance3D", true, false):
			_dress(mi, slot)
			parts[slot].append(mi)
		hair_skel = own
		p.queue_free()
		return
	for mi in p.find_children("*", "MeshInstance3D", true, false):
		if slot == "acc":
			var att := BoneAttachment3D.new()
			att.bone_name = "Head"
			skel.add_child(att)
			mi.reparent(att, false)
			_dress(mi, slot)
			parts[slot].append(mi)
			continue
		if String(mi.name).begins_with("HatEar"):
			_hang_ear(mi, own)
			_dress(mi, slot)
			parts[slot].append(mi)
			continue
		mi.reparent(skel, false)
		mi.skeleton = NodePath("..")
		_dress(mi, slot)
		_detail_maps(mi, path.get_basename() + "_" + String(mi.name))
		parts[slot].append(mi)
	p.queue_free()
	if has_meta("doll"):
		DollShape.sync(self)

var hat_ears: Array = []
var _ear_wag := 0.0
var _ear_perk := 0.0
var _ear_droop := 0.0
var _ear_droop_until := 0.0
var _ear_twitch := Vector2(-1, 0)
var _next_twitch := 3.0
const EAR_HAPPY := ["happy", "laugh", "love", "wave", "excited", "clap", "content", "mischief", "proud", "agree", "please"]
const EAR_PERK := ["surprised", "idea", "shocked", "confused", "sneeze"]
const EAR_SAD := ["sad", "cry", "sigh", "sorry", "scared", "doze", "cold", "nervous", "shy"]

const ACC_SPOTS := {"bow": [44.0, 52.0, -18.0], "strawberry_clip": [22.0, 62.0, 12.0], "star_clip": [20.0, 62.0, -14.0],
	"claw_clip": [10.0, 180.0, -10.0]}
const HAIR_ACC_SPOTS := {}
const HEAD_CENTRE := Vector3(0.0, 1.19, -0.07)

func _place_acc() -> void:
	var pieces: Array = parts.get("acc", [])
	if pieces.is_empty():
		return
	var shape := _part_file("acc").get_file().get_basename()

	var hs := _part_file("hair").get_file().get_basename()
	var spot: Array = HAIR_ACC_SPOTS.get(hs, {}).get(shape, ACC_SPOTS.get(shape, [30.0, 60.0, 0.0]))
	var lat := deg_to_rad(spot[0])
	var lon := deg_to_rad(spot[1])
	var dir := Vector3(sin(lon) * cos(lat), sin(lat), cos(lon) * cos(lat))
	var from := HEAD_CENTRE + dir * 0.9
	var best := -1.0
	var hit := HEAD_CENTRE + dir * 0.35
	var nrm := dir
	var inv := skel.global_transform.affine_inverse()
	for mi in parts.get("hair", []):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		var rel := inv * mesh_inst.global_transform
		var f: PackedVector3Array = mesh_inst.mesh.get_faces()
		for i in range(0, f.size(), 3):
			var a: Vector3 = rel * f[i]
			var b: Vector3 = rel * f[i + 1]
			var c: Vector3 = rel * f[i + 2]
			var p = Geometry3D.ray_intersects_triangle(from, -dir, a, b, c)
			if p != null and (best < 0.0 or from.distance_to(p) < best):
				best = from.distance_to(p)
				hit = p
				nrm = (b - a).cross(c - a).normalized()
	if nrm.dot(dir) < 0.0:
		nrm = -nrm
	nrm = (nrm + dir).normalized()
	var up := (Vector3.UP - nrm * nrm.dot(Vector3.UP)).normalized()
	var basis := Basis(up.cross(nrm), up, nrm).rotated(nrm, deg_to_rad(spot[2]))
	var head_rest := DollShape.chibi_rest(skel, skel.find_bone("Head"))
	var hatted: bool = not parts.get("hat", []).is_empty()
	var k: float = spot[3] if spot.size() > 3 else 1.0
	for mi in pieces:
		mi.transform = head_rest.affine_inverse() * Transform3D(basis.scaled(Vector3.ONE * k), hit - nrm * 0.006)
		mi.visible = not hatted

func _hang_ear(mi: MeshInstance3D, own: Skeleton3D) -> void:
	var head := skel.find_bone("Head")
	var in_skel: Transform3D = (own.global_transform.affine_inverse() if own else Transform3D()) * mi.global_transform
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	skel.add_child(att)
	mi.reparent(att, false)
	mi.transform = DollShape.chibi_rest(skel, head).affine_inverse() * in_skel
	var side := 1.0 if String(mi.name).ends_with("_L") else -1.0
	hat_ears.append([mi, side, mi.transform])

func _ear_mood(kind: String) -> void:
	if hat_ears.is_empty():
		return
	if EAR_HAPPY.has(kind):
		_ear_wag = 1.1
	elif EAR_PERK.has(kind):
		_ear_perk = 0.6
	elif EAR_SAD.has(kind):
		_ear_droop_until = _time + 2.2

func _update_ears(delta: float) -> void:
	if hat_ears.is_empty():
		return
	_ear_wag = maxf(0.0, _ear_wag - delta)
	_ear_perk = maxf(0.0, _ear_perk - delta)
	_ear_droop = move_toward(_ear_droop, 1.0 if _time < _ear_droop_until else 0.0, delta * 2.5)
	_next_twitch -= delta
	if _next_twitch <= 0.0 and _ear_wag <= 0.0 and _ear_droop <= 0.0:
		_ear_twitch = Vector2(0.28, 1.0 if randf() < 0.5 else -1.0)
		_next_twitch = randf_range(4.0, 9.0)
	_ear_twitch.x -= delta
	var long_ears := String(look.get("hat", {}).get("shape", "") if look.get("hat") is Dictionary else look.get("hat", "")).ends_with("bunny")
	for e in hat_ears:
		var mi: MeshInstance3D = e[0]
		if not is_instance_valid(mi):
			continue
		var side: float = e[1]
		var wag := sin(_ear_wag * 26.0) * 0.32 * minf(1.0, _ear_wag * 3.0)
		var perk := sin((0.6 - _ear_perk) / 0.6 * PI) * 0.25 if _ear_perk > 0.0 else 0.0
		var twitch := sin((0.28 - _ear_twitch.x) / 0.28 * PI * 2.0) * 0.22 if _ear_twitch.x > 0.0 and _ear_twitch.y == side else 0.0
		var droop := _ear_droop * (1.15 if long_ears else 0.55)

		var out := -side * (wag + droop * 0.8 + twitch)
		var back := droop * 0.55 - perk
		var basis := Basis(Vector3(0, 0, 1), out) * Basis(Vector3(1, 0, 0), -back)
		var rest: Transform3D = e[2]
		mi.transform = Transform3D(rest.basis * basis * Basis().scaled(Vector3.ONE * (1.0 + perk * 0.25)), rest.origin)

func _detail_maps(mi: MeshInstance3D, base: String) -> void:
	"""Seams, ribs, folds, pockets and soles baked per garment by tools/cloth_tex.py (if present)."""
	if not TexCache.exists(base + "_nrm.png"):
		return
	mi.set_meta("maps", base)
	var nrm := _load_tex(base + "_nrm.png")
	var mix_tex := _load_tex(base + "_mix.png")
	for s in mi.mesh.get_surface_count():
		var m := mi.get_surface_override_material(s) as ShaderMaterial
		if m == null:
			continue
		m.set_shader_parameter("has_maps", true)
		m.set_shader_parameter("detail_nrm", nrm)
		m.set_shader_parameter("detail_mix", mix_tex)

func _dress(mi: MeshInstance3D, slot: String) -> void:

	mi.lod_bias = 128.0
	for s in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(s)
		var mname := src.resource_name if src else ""
		var m := ShaderMaterial.new()
		if slot == "hair" and mname.begins_with("mHairShade"):
			m.shader = HAIR_SHADE
		elif slot == "hair" and (mname.begins_with("mHair2") or mname.ends_with("_2")):
			m.shader = HAIR2
		elif slot == "hair" and mname.begins_with("mHair"):
			m.shader = HAIR
		elif FACE_MODES.has(mname):
			m.shader = FACE
			m.set_shader_parameter("mode", FACE_MODES[mname])
			face_parts[mname] = m

		elif slot in ["top", "bottom", "hat"] or mname.begins_with("mUmb"):
			m.shader = TOON_CLOTH
		elif slot == "shoes":
			m.shader = TOON_WEAR
		else:
			m.shader = TOON
		if m.shader == TOON:
			m.set_shader_parameter("chara", 1.0)
		if mname.begins_with("mNose_"):
			noses[mname.substr(6)] = mi
		m.set_meta("slot", slot)
		m.set_meta("name", mname)
		mi.set_surface_override_material(s, m)
		if mname.begins_with("mSkin") or mname.begins_with("mNose") or mname.begins_with("mSocks") or mname == "mFeet":
			skin_mats.append(m)
		if mname == "mFeet":
			feet = [mi, s, m]
		if mname == "mSkin_Ear":
			ears = [mi, s, m]

func _apply_colors() -> void:
	var skin := Color(look.get("skin", "#ffd9bd"))
	for m in skin_mats:
		var nose: bool = str(m.get_meta("name")).begins_with("mNose")
		if nose:

			m.set_shader_parameter("base_color", skin * Color(0.97, 0.84, 0.76))
			m.set_shader_parameter("shadow_tint", Color(0.8, 0.68, 0.66))
			m.set_shader_parameter("shade_soft", 0.25)
			m.set_shader_parameter("rim", 0.3)
			continue
		if str(m.get_meta("name")) == "mSkin_Ear":

			m.set_shader_parameter("base_color", skin * Color(0.99, 0.93, 0.9))
			m.set_shader_parameter("shadow_tint", Color(0.86, 0.76, 0.74))
			m.set_shader_parameter("shade_soft", 0.32)
			m.set_shader_parameter("rim", 0.2)
			m.set_shader_parameter("uv_ao", 0.22)
			continue
		m.set_shader_parameter("base_color", skin)

		m.set_shader_parameter("shadow_tint", Color(0.93, 0.9, 0.87))
		m.set_shader_parameter("shade_soft", 0.45)
		m.set_shader_parameter("rim", 0.15)
	var hair_col := Color(look.get("hair_color", "#6b4330"))
	for slot in SLOTS:
		var spec = look.get(slot, {})
		for mi in parts.get(slot, []):
			for s in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(s) as ShaderMaterial
				var mname: String = m.get_meta("name")
				if slot == "hair":

					var c := hair_col
					if mname.begins_with("mHairClip"):
						c = hair_col.lerp(Color(look.get("skin", "#ffd9bd")), 0.2).darkened(0.15)
					elif mname.begins_with("mHairFade"):
						c = hair_col.lerp(Color(look.get("skin", "#ffd9bd")), 0.65)
					elif mname.begins_with("mHairTie"):
						c = Color(look.get("hair_tie", "#e8546b"))
					if mname.begins_with("mHairShade"):
						continue
					var tex := "hair2_" if mname.begins_with("mHair2") or mname.ends_with("_2") else "hair_"
					m.set_shader_parameter("hair_color", c)
					m.set_shader_parameter("alb_tex", _load_tex(HAIR_TEX + tex + "alb.png"))
					m.set_shader_parameter("mix_tex", _load_tex(HAIR_TEX + tex + "mix.png"))
					m.set_shader_parameter("nrm_tex", _load_tex(HAIR_TEX + tex + "nrm.png"))
					m.set_shader_parameter("has_tex", true)
					if mname.begins_with("mHair2") or mname.ends_with("_2"):
						var hat = look.get("hat", {})
						var hs: String = str(hat.get("shape", "")) if hat is Dictionary else str(hat)
						m.set_shader_parameter("hat_shade", 0.0 if hs in ["", "none"] else 1.0)
				elif spec is Dictionary:
					var c := Color(spec.get("color", "#ffffff"))
					if mname.ends_with("_Trim"):
						c = Color(spec.get("trim", spec.get("color_b", "#ffffff")))
						m.set_shader_parameter("has_pattern", false)
					elif mname.ends_with("_Hood"):
						m.set_shader_parameter("has_pattern", false)
						m.set_shader_parameter("has_design", false)
					elif mname.ends_with("_Inner"):
						c = Color(spec.get("color_c", "#ffb6c8"))
						m.set_shader_parameter("has_pattern", false)
					elif mname.ends_with("_Rim"):
						c = c * Color(0.85, 0.8, 0.75)
						m.set_shader_parameter("has_pattern", false)
					elif mname.ends_with("_Dot"):
						c = Color("fff1a8")
						m.set_shader_parameter("has_pattern", false)
					elif mname.ends_with("_Badge"):
						c = HAT_BADGE
						m.set_shader_parameter("has_pattern", false)
					else:
						var pat: String = spec.get("pattern", "plain")

						var design: String = spec.get("design", "")
						var dbase: String = str(mi.get_meta("maps", "")) + "__" + design
						var has_design := design != "" and TexCache.exists(dbase + "_dsn.png")
						m.set_shader_parameter("has_design", has_design)
						if mi.has_meta("maps"):
							var mb: String = dbase if has_design else str(mi.get_meta("maps"))
							m.set_shader_parameter("detail_nrm", _load_tex(mb + "_nrm.png"))
							m.set_shader_parameter("detail_mix", _load_tex(mb + "_mix.png"))
						if has_design:
							m.set_shader_parameter("design_tex", _load_tex(dbase + "_dsn.png"))
							m.set_shader_parameter("color_c", Color(spec.get("color_c", "#ffffff")))
							pat = "plain"
						m.set_shader_parameter("has_pattern", pat != "plain")
						if pat != "plain":
							m.set_shader_parameter("pattern_tex", _load_tex(PATTERN_DIR + pat + ".png"))

							var ps: float = float(spec.get("pattern_scale", 4.0)) * (KID_SCALE if str(look.get("body", "")) == "kid" else 1.0)
							m.set_shader_parameter("pattern_scale", Vector2(ps, ps))
						m.set_shader_parameter("color_b", Color(spec.get("color_b", "#ffffff")))

						m.set_shader_parameter("design_b", Color(spec.get("color_b", "#ffffff")))
						m.set_shader_parameter("design_b_inside", not _part_file(slot).contains("polo"))

						var own: String = str(mi.get_meta("maps", "")) + "_dsn.png"
						if not has_design and mi.has_meta("maps") and TexCache.exists(own):
							m.set_shader_parameter("has_design", true)
							m.set_shader_parameter("design_tex", _load_tex(own))
							var inside := Color(spec.get("trim", spec.get("color_b", "#ffffff")))
							if not spec.has("trim") and _part_file(slot).contains("rolled"):
								inside = Color(spec.get("color", "#ffffff")).lightened(0.22)
							m.set_shader_parameter("design_b", inside)
					m.set_shader_parameter("base_color", c)

					m.set_shader_parameter("shade_soft", 0.5)
					m.set_shader_parameter("shadow_tint", Color(0.64, 0.6, 0.72))

					m.set_shader_parameter("rim", 0.5 if _part_file(slot).contains("raincoat") or _part_file(slot).contains("poncho") else (0.32 if _part_file(slot).contains("sunjacket") else 0.22))
					m.set_shader_parameter("nrm_depth", 0.8)

					m.set_shader_parameter("stitch_tint", spec.has("stitch"))
					m.set_shader_parameter("stitch_color", Color(spec.get("stitch", "#ffffff")))

					Wardrobe.set_fabric(m, slot, spec, mname, str(look.get("body", "")) == "kid")
	for k in face_parts:
		var fm: ShaderMaterial = face_parts[k]
		fm.set_shader_parameter("skin", skin)
		fm.set_shader_parameter("eye_color", Color(look.get("eye_color", "#5a3a2a")))

		fm.set_shader_parameter("brow_color", hair_col.darkened(0.6 if int(look.get("age", 0)) > 0 else 0.25))
		fm.set_shader_parameter("blush", float(look.get("blush", 0.55)))
	if face_parts.has("mCheek"):
		face_parts["mCheek"].set_shader_parameter("tex", _load_tex(FACE_DIR + "cheek_0.png"))
		face_parts["mCheek"].set_shader_parameter("has_tex", true)
	if face_parts.has("mPaint"):
		face_parts["mPaint"].set_shader_parameter("mask", _load_tex(FACE_DIR + _brows() + ".png"))
		face_parts["mPaint"].set_shader_parameter("has_mask", look.get("brows", true) and not _kid_brows())
	if face_parts.has("mEye"):
		face_parts["mEye"].set_shader_parameter("has_brow_mask", look.get("brows", true) and _kid_brows())
		if _kid_brows():
			face_parts["mEye"].set_shader_parameter("brow_mask", _load_tex(FACE_DIR + "eye_brows_kid.png"))

		var aged: bool = int(look.get("age", 0)) > 0
		face_parts["mPaint"].set_shader_parameter("has_tex", aged)
		if aged:
			face_parts["mPaint"].set_shader_parameter("tex", _load_tex(FACE_DIR + "paint_elder.png"))
	var nose: String = look.get("nose", "button")
	for style in noses:
		noses[style].visible = style == nose

func _load_tex(path: String) -> Texture2D:
	var t: Texture2D = _tex_keep.get(path)
	if t == null and _tex_weak.has(path):
		t = _tex_weak[path].get_ref()
	if t != null:
		return t
	var small := path.begins_with(FACE_DIR) or path.begins_with(HAIR_TEX) or path.begins_with(PATTERN_DIR)
	var img: Image = null if small else TexCache.compressed(path)
	if img == null:
		img = TexCache.read(path)
		if img == null:
			push_warning("missing " + path)
			return null
		if not img.has_mipmaps():
			img.generate_mipmaps()
	t = ImageTexture.create_from_image(img)
	if small:
		_tex_keep[path] = t
	else:
		_tex_weak[path] = weakref(t)
	return t

func set_deco(id: int) -> void:
	"""Show face mark `id` on the patches that have a slice of it (characters/face/deco_<id>_<patch>.png)."""
	for patch in DECO_PATCHES:
		if not face_parts.has(patch):
			continue
		var fm: ShaderMaterial = face_parts[patch]
		var path := FACE_DIR + "deco_%d_%s.png" % [id, DECO_PATCHES[patch]]
		var on := id > 0 and TexCache.exists(path)
		fm.set_shader_parameter("has_deco", on)
		if on:
			fm.set_shader_parameter("deco", _load_tex(path))

func _kid_brows() -> bool:
	"""A kid's brows go on the eye patch (tools/make_face.py kid_brows): the big head puts the forehead's under the fringe."""
	return look.get("body", "") == "kid" and int(look.get("age", 0)) == 0

func _brows() -> String:
	"""The brow drawings: thinner, drooping ones on an older face ("age": 1)."""
	return "paint_brows_elder" if int(look.get("age", 0)) > 0 else "paint_brows"

func set_face(eye: int, mouth: int) -> void:
	var style: String = look.get("eye_style", "classic")
	if face_parts.has("mEye"):
		var em: ShaderMaterial = face_parts["mEye"]
		em.set_shader_parameter("tex", _load_tex(FACE_DIR + "eye_%s_%d.png" % [style, eye]))
		em.set_shader_parameter("mask", _load_tex(FACE_DIR + "eye_%s_%d_mask.png" % [style, eye]))
		em.set_shader_parameter("has_tex", true)
		em.set_shader_parameter("has_mask", true)
	if face_parts.has("mMouth"):
		var mm: ShaderMaterial = face_parts["mMouth"]
		var mouths := "mouth_elder_%d.png" if int(look.get("age", 0)) > 0 else "mouth_%d.png"
		mm.set_shader_parameter("tex", _load_tex(FACE_DIR + mouths % mouth))
		mm.set_shader_parameter("has_tex", true)

var _shown := Vector2i(-1, -1)

func _update_face(delta: float) -> void:
	var e := base_eye
	var m := base_mouth
	var playing := anim != null and anim.current_animation != ""
	var tl: Dictionary = _timelines.get(anim.current_animation, {}) if playing else {}
	var frame := anim.current_animation_position * 30.0 if playing else 0.0
	if _time < _override_until:
		e = _override.x if _override.x >= 0 else e
		m = _override.y if _override.y >= 0 else m
	if tl.has("eye"):
		e = _step(tl["eye"], frame)
	elif BLINKING.has(e):
		var bk := _blink(delta)
		e = e if bk == 0 else bk
	if tl.has("mouth"):
		m = _step(tl["mouth"], frame)
	if Vector2i(e, m) != _shown:
		_shown = Vector2i(e, m)
		set_face(e, m)

	var b := _step(tl["brow"], frame) if tl.has("brow") else base_brow
	if b != _brow and face_parts.has("mPaint"):
		_brow = b
		if _kid_brows() and face_parts.has("mEye"):
			face_parts["mEye"].set_shader_parameter("brow_mask", _load_tex(FACE_DIR + "eye_brows_kid_%d.png" % b))
		else:
			face_parts["mPaint"].set_shader_parameter("mask", _load_tex(FACE_DIR + _brows() + "_%d.png" % b))
	var dk := _step(tl["deco"], frame) if tl.has("deco") else base_deco
	if dk != _deco:
		_deco = dk
		set_deco(dk)
	var bl := float(_step(tl["blush"], frame)) if tl.has("blush") else 0.0
	_blush_extra = move_toward(_blush_extra, bl, delta * 4.0)
	if face_parts.has("mCheek"):
		face_parts["mCheek"].set_shader_parameter("blush", minf(1.0, float(look.get("blush", 0.55)) + 0.55 * _blush_extra))

static func _step(keys: Array, frame: float) -> int:
	var s := int(keys[0][1])
	for k in keys:
		if float(k[0]) <= frame:
			s = int(k[1])
		else:
			break
	return s

func _blink(delta: float) -> int:
	if _blink_t < 0.0:
		if _time < _next_blink:
			return 0
		_blink_t = 0.0
		var closing := [[0, 2]] if randf() < 0.55 else [[0, 1], [1, 2]]
		var shut := int(closing[-1][0]) + randi_range(2, 4)
		_blink_steps = closing + [[shut, 1], [shut + randi_range(1, 2), 0]]
	var s := _step(_blink_steps, _blink_t)
	_blink_t += delta * 30.0
	if s == 0 and _blink_t > float(_blink_steps[-1][0]):
		_blink_t = -1.0
		_next_blink = _time + randf_range(2.5, 6.0)
	return s

func _lap_lift(dress_lap: bool) -> float:
	var lap_slot := "top" if dress_lap else ("bottom" if _part_file("bottom").contains("skirt") else "")
	if lap_slot == "":
		return 0.0
	var lift := 0.0
	var off := _chain_offset(parts.get(lap_slot, []), ["Skirt_2_LF", "Skirt_2_RF"])
	if not is_nan(off):
		lift += clampf(-0.002 - off, -0.03, 0.04)
	if dress_lap and _seat_hide.is_empty() and not parts.get("bottom", []).is_empty():
		var r := _thigh_radius(parts["bottom"])
		var bare := _thigh_radius(body.find_children("Body", "MeshInstance3D", true, false))
		if not is_nan(r) and not is_nan(bare):
			lift += clampf(r - bare, 0.0, 0.05)
	if _part_file("top").contains("poncho"):
		lift += 0.085
	return lift

func _chain_offset(meshes: Array, bones: Array) -> float:
	var sum := 0.0
	var n := 0
	for mi in meshes:
		if not (mi is MeshInstance3D) or (mi as MeshInstance3D).skin == null:
			continue
		var skin: Skin = mi.skin
		var want := {}
		for b in skin.get_bind_count():
			var nm: String = String(skin.get_bind_name(b)) if skin.get_bind_bone(b) < 0 else skel.get_bone_name(skin.get_bind_bone(b))
			if nm in bones:
				want[b] = skin.get_bind_pose(b).affine_inverse()
		if want.is_empty():
			continue
		for s in mi.mesh.get_surface_count():
			var arr := (mi.mesh as Mesh).surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bo = arr[Mesh.ARRAY_BONES]
			var we = arr[Mesh.ARRAY_WEIGHTS]
			if bo == null or v.is_empty():
				continue
			var per: int = (bo as PackedInt32Array).size() / v.size()
			for k in v.size():
				var best := 0
				for j in per:
					if we[k * per + j] > we[k * per + best]:
						best = j
				var bi: int = bo[k * per + best]
				if want.has(bi):
					var t: Transform3D = want[bi]
					var ax := t.basis.y.normalized()
					var r := v[k] - t.origin
					sum += (r - ax * r.dot(ax)).z
					n += 1
	return sum / n if n > 0 else NAN

func _thigh_radius(meshes: Array) -> float:
	var hip := skel.get_bone_global_rest(skel.find_bone("Leg_1_L")).origin
	var knee := skel.get_bone_global_rest(skel.find_bone("Leg_2_L")).origin
	var ax := (knee - hip).normalized()
	var tl := hip.distance_to(knee)
	var ds := []
	for mi in meshes:
		if not (mi is MeshInstance3D) or (mi as MeshInstance3D).skin == null:
			continue
		var skin: Skin = mi.skin
		var leg := -1
		for b in skin.get_bind_count():
			var nm: String = String(skin.get_bind_name(b)) if skin.get_bind_bone(b) < 0 else skel.get_bone_name(skin.get_bind_bone(b))
			if nm == "Leg_1_L":
				leg = b
		if leg < 0:
			continue
		for s in mi.mesh.get_surface_count():
			var arr := (mi.mesh as Mesh).surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bo = arr[Mesh.ARRAY_BONES]
			var we = arr[Mesh.ARRAY_WEIGHTS]
			if bo == null or v.is_empty():
				continue
			var per: int = (bo as PackedInt32Array).size() / v.size()
			for k in v.size():
				var best := 0
				for j in per:
					if we[k * per + j] > we[k * per + best]:
						best = j
				if bo[k * per + best] != leg:
					continue
				var r := v[k] - hip
				var t := r.dot(ax) / tl
				if t > 0.2 and t < 0.8:
					ds.append((r - ax * r.dot(ax)).length())
	if ds.is_empty():
		return NAN
	ds.sort()
	return ds[ds.size() / 2]

func play(clip: String, blend := 0.2) -> void:

	if tool == "cane" and clip in ["Move_Walk", "Move_Run"] and anim and anim.has_animation("Tool_Cane_Walk"):
		clip = "Tool_Cane_Walk"
	_base_clip = clip
	if anim and not anim.has_animation(clip):
		AnimPacks.ensure(clip)
	if anim and anim.has_animation(clip) and anim.current_animation != clip:
		anim.play(clip, blend)

var tool := ""
const KID_SCALE := 0.66
const KID_HEAD := 1.3
var _kid: KidBody
const KID_CADENCE := 1.2
const CHAIR_HIP := 0.386

func size() -> float:
	"""1 for an adult, KID_SCALE for a child: whoever moves, seats or collides the character scales by it."""
	return scale.x

func seat_lift() -> float:
	"""How far a child is lifted onto a chair: the chair clips put an adult's hips on the seat, and a child's
	scaled-down hips would sink into it (their legs dangle instead, as children's do)."""
	return (1.0 - scale.x) * CHAIR_HIP
const CANE_WALK_SPEED := 0.34
var _grip: GripOverride
var _follow: ItemFollow

const TRACKED := ["Item", "Z_Pole", "Wrist_R", "Head"]
var _final := {}

func hold(t: String) -> void:
	"""Put a tool in the right hand ("" puts it away). The fingers keep their grip over any clip."""
	tool = t
	umb_fold = 0.0
	set_part("tool", "" if t == "" else TOOL_DIR + t + ".glb")

	var alb := TOOL_DIR + t + "_alb.png"
	var painted := t != "" and TexCache.exists(alb)
	for mi in parts.get("tool", []):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if painted:
				m.set_shader_parameter("base_color", Color.WHITE)
				m.set_shader_parameter("has_albedo", true)
				m.set_shader_parameter("albedo_tex", _load_tex(alb))
				if TexCache.exists(TOOL_DIR + t + "_nrm.png"):
					m.set_shader_parameter("has_prop_nrm", true)
					m.set_shader_parameter("prop_nrm", _load_tex(TOOL_DIR + t + "_nrm.png"))
			else:
				m.set_shader_parameter("base_color", _umbrella_color(str(m.get_meta("name"))) if t == "umbrella"
					else TOOL_COLORS.get(m.get_meta("name"), Color("b0b0b0")))
	if _grip == null and anim.has_animation("Tool_Grip"):
		_grip = GripOverride.new()
		skel.add_child(_grip)
		_follow = ItemFollow.new()
		skel.add_child(_follow)
		_follow.setup(skel)
	if _grip:

		var carry := "Tool_Grip_" + t if anim.has_animation("Tool_Grip_" + t) else "Tool_Grip"
		_grip.setup(anim.get_animation(carry), skel)
		_grip.influence = 1.0 if t != "" else 0.0
		_follow.active = t != ""

func _umbrella_color(mname: String) -> Color:
	"""(04/11, Agent làm quần áo) the look's umbrella: "umbrella": "#ffd23f" (every panel) or [panel A, panel B];
	without it the pink and cream one (TOOL_COLORS)."""
	var u = look.get("umbrella")
	if u is String and (mname == "mUmbA" or mname == "mUmbB"):
		return Color(u)
	if u is Array and u.size() >= 2 and (mname == "mUmbA" or mname == "mUmbB"):
		return Color(str(u[0] if mname == "mUmbA" else u[1]))
	return TOOL_COLORS.get(mname, Color("b0b0b0"))

const UMB_TOP := Vector3(-0.53, -1.16, 0.782)
const UMB_GRIP := Vector3(-0.53, 0.03, 0.782)
var umb_fold := 1.0
var _umb_t := -1.0
var _umb_closing := false

func open_umbrella() -> void:
	hold("umbrella")
	umb_fold = 1.0
	_umb_t = 0.0
	_umb_closing = false
	_update_umbrella(0.0)

func close_umbrella() -> void:
	if tool != "umbrella":
		return
	_umb_t = 0.0
	_umb_closing = true

func _update_umbrella(delta: float) -> void:
	if tool != "umbrella":
		return
	if _umb_t >= 0.0:
		_umb_t += delta
		if _umb_closing:
			var k := minf(1.0, _umb_t / 0.3)
			umb_fold = k * k
			if k >= 1.0:
				_umb_t = -1.0
				hold("")
				return
		else:
			var k := minf(1.0, _umb_t / 0.45)
			umb_fold = 1.0 - (1.0 + 2.2 * pow(k - 1.0, 3.0) + 1.2 * pow(k - 1.0, 2.0))
			if k >= 1.0:
				umb_fold = 0.0
				_umb_t = -1.0
	var top := posed_point("Item", UMB_TOP)
	var up := (top - posed_point("Item", UMB_GRIP)).normalized()
	for mi in parts.get("tool", []):
		var inv: Transform3D = mi.global_transform.affine_inverse()
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m and String(m.get_meta("name", "")).begins_with("mUmb"):
				m.set_shader_parameter("fold", umb_fold)
				m.set_shader_parameter("fold_apex", inv * top)
				m.set_shader_parameter("fold_up", (inv.basis * up).normalized())

func use_tool(clip: String) -> float:
	"""Play a tool clip, then go back to the base clip. Returns the seconds until the tool meets its
	target (TOOL_IMPACT), or -1 for a clip that hits nothing."""
	if not anim.has_animation(clip):
		return -1.0
	anim.speed_scale = 1.0
	anim.play(clip, 0.08)
	anim.queue(_base_clip)
	return float(TOOL_IMPACT[clip] + 1) / 30.0 if TOOL_IMPACT.has(clip) else -1.0

func hit_stop(secs := 0.07) -> void:
	"""The tiny freeze of a hit that lands (the clip itself already stops the axe dead)."""
	anim.speed_scale = 0.0
	await get_tree().create_timer(secs).timeout
	anim.speed_scale = 1.0

func _keep_final_poses() -> void:
	for b in TRACKED:
		var bi := skel.find_bone(b)
		if bi >= 0:
			_final[bi] = skel.get_bone_global_pose(bi)

func final_pose(bone: int) -> Transform3D:
	"""A tracked bone's pose after every modifier (a turned head, a gripped tool)."""
	return _final.get(bone, skel.get_bone_global_pose(bone))

func posed_point(bone: String, rest_point: Vector3) -> Vector3:
	"""A point given in the T-pose (Blender axes) carried along by a bone, in world space (after the
	modifiers: a carried tool rides the wrist through ItemFollow)."""
	var bi := skel.find_bone(bone)
	var d: Transform3D = _final.get(bi, skel.get_bone_global_pose(bi)) * skel.get_bone_global_rest(bi).affine_inverse()
	return skel.global_transform * (d * Vector3(rest_point.x, rest_point.z, -rest_point.y))

func emote(kind: String) -> void:
	_ear_mood(kind)
	var e: Dictionary = EMOTES.get(kind, {})
	var d: Dictionary = emotes.get(kind, {})
	if d.has("clip"):
		e = e.duplicate()
		e["clip"] = d["clip"]
	if e.is_empty():
		return

	if not _timelines.has(e["clip"]):
		_override = Vector2i(e.get("eye", -1), e.get("mouth", -1))
		_override_until = _time + e.get("secs", 1.5)
	if e["clip"] != "" and anim.has_animation(e["clip"]):
		anim.play(e["clip"], 0.15)
		anim.queue(_base_clip)

	EmoteFx.play(self, str(d.get("fx", "")), float(d.get("fx_at", 0)) / 30.0)

func _process(delta: float) -> void:
	_time += delta
	if skirt_follow and not _seat_hide.is_empty():
		var hide := skirt_follow.get_seated() > 0.35
		if hide != _seat_hidden:
			_seat_hidden = hide
			for mi in _seat_hide:
				if is_instance_valid(mi):
					mi.visible = not hide
	if _grip:
		var want := 1.0 if tool != "" and not anim.current_animation.begins_with("Tool_") else 0.0
		_grip.influence = move_toward(_grip.influence, want, delta * (4.0 if want > 0.0 else 20.0))
		_grip.active = _grip.influence > 0.0

		_follow.influence = 1.0 if want > 0.0 else move_toward(_follow.influence, 0.0, delta / 0.08)
		_follow.active = tool != "" and _follow.influence > 0.0
	_update_face(delta)
	_update_ears(delta)
	_update_umbrella(delta)
