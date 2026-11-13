class_name Scarf
extends RefCounted

const PATH := "res://characters/face_wear/khan_ran.glb"
const MAPS := "res://characters/face_wear/khan_ran"

static func add(c: Chibi, look: Dictionary) -> Node3D:
	if not look.has("scarf") or c.skel == null or not ResourceLoader.exists(PATH):
		return null
	var bone := c.skel.find_bone("Spine_3")
	if bone < 0:
		return null
	var att := BoneAttachment3D.new()
	att.name = "Scarf"
	att.bone_name = "Spine_3"
	c.skel.add_child(att)
	var holder := Node3D.new()
	holder.transform = DollShape.chibi_rest(c.skel, bone).affine_inverse()
	att.add_child(holder)
	var scene: Node = load(PATH).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		copy.transform = mi.transform
		for s in copy.mesh.get_surface_count():
			var m := ShaderMaterial.new()
			m.shader = Chibi.TOON_CLOTH
			m.set_shader_parameter("base_color", Color(str(look["scarf"])))
			m.set_shader_parameter("shade_soft", 0.5)
			m.set_shader_parameter("rim", 0.2)
			m.set_shader_parameter("has_maps", true)
			m.set_shader_parameter("detail_nrm", load(MAPS + "_nrm.png"))
			m.set_shader_parameter("detail_mix", load(MAPS + "_mix.png"))
			m.set_shader_parameter("has_design", true)
			m.set_shader_parameter("design_tex", load(MAPS + "_dsn.png"))
			m.set_shader_parameter("design_b", Color(str(look.get("scarf_b", "#2b2b30"))))
			copy.set_surface_override_material(s, m)
		holder.add_child(copy)
	scene.free()
	return att
