class_name NeckWear
extends RefCounted

const DIR := "res://characters/face_wear/"
const DEFAULTS := {"coi": ["#c8383e", "#d4d8de"], "the_nv": ["#ff8fb0", "#ff8fb0"],
	"khan_mat": ["#eeeadf", "#6f9ac9"]}
const CARD := Color("fbfaf6")

static func add(c: Chibi, look: Dictionary) -> Node3D:
	var kind := str(look.get("neck", ""))
	var path := DIR + kind + ".glb"
	if kind == "" or c.skel == null or not ResourceLoader.exists(path):
		return null
	var bone := c.skel.find_bone("Spine_3")
	if bone < 0:
		return null
	var att := BoneAttachment3D.new()
	att.name = "NeckWear"
	att.bone_name = "Spine_3"
	c.skel.add_child(att)
	var holder := Node3D.new()
	holder.transform = DollShape.chibi_rest(c.skel, bone).affine_inverse()
	att.add_child(holder)
	var d: Array = DEFAULTS.get(kind, ["#2b2b30", "#d4d8de"])
	var cols := {"mNeck_Cord": Color(str(look.get("neck_cord", d[0]))), "mNeck_Item": Color(str(look.get("neck_item", d[1]))),
		"mNeck_Card": CARD, "mNeck_Ink": Color("3a3d48")}
	var scene: Node = load(path).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		copy.transform = mi.transform
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in copy.mesh.get_surface_count():
			var src := copy.mesh.surface_get_material(s)
			var mname := src.resource_name if src else ""
			var m := ShaderMaterial.new()
			m.shader = Chibi.TOON_CLOTH
			m.set_shader_parameter("base_color", cols.get(mname, Color("b0b0b0")))
			m.set_shader_parameter("shade_soft", 0.5)
			m.set_shader_parameter("rim", 0.45 if mname == "mNeck_Item" and kind == "coi" else 0.2)
			copy.set_surface_override_material(s, m)
		holder.add_child(copy)
	scene.free()
	return att
