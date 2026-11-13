class_name FaceMask
extends RefCounted

const PATH := "res://characters/face_wear/khau_trang.glb"
const MAPS := "res://characters/face_wear/khau_trang"

static func add(c: Chibi, look: Dictionary) -> Node3D:
	if not look.has("mask") or c.skel == null or not ResourceLoader.exists(PATH):
		return null
	var bone := c.skel.find_bone("Head")
	if bone < 0:
		return null
	var att := BoneAttachment3D.new()
	att.name = "FaceMask"
	att.bone_name = "Head"
	c.skel.add_child(att)
	var holder := Node3D.new()
	holder.transform = DollShape.chibi_rest(c.skel, bone).affine_inverse()
	att.add_child(holder)
	var main := Color(str(look["mask"]))
	var trim := Color(str(look.get("mask_trim", main.darkened(0.2).to_html())))
	var path := PATH
	var fitted := "res://characters/face_wear/khau_trang_%s.glb" % str(look.get("face", ""))
	if str(look.get("face", "")) not in ["", "normal"] and ResourceLoader.exists(fitted):
		path = fitted
	var scene: Node = load(path).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		copy.transform = mi.transform
		for s in copy.mesh.get_surface_count():
			var m := ShaderMaterial.new()
			m.shader = Chibi.TOON_CLOTH
			var mn := str(copy.mesh.surface_get_material(s).resource_name) if copy.mesh.surface_get_material(s) else ""
			m.set_shader_parameter("base_color", trim if mn.ends_with("_Trim") else main)
			if not mn.ends_with("_Trim"):
				m.set_shader_parameter("has_maps", true)
				m.set_shader_parameter("detail_nrm", load(MAPS + "_nrm.png"))
				m.set_shader_parameter("detail_mix", load(MAPS + "_mix.png"))
				m.set_shader_parameter("has_design", true)
				m.set_shader_parameter("design_tex", load(MAPS + "_dsn.png"))
				m.set_shader_parameter("design_b", trim)
			m.set_shader_parameter("shade_soft", 0.5)
			m.set_shader_parameter("rim", 0.2)
			copy.set_surface_override_material(s, m)
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(copy)
	scene.free()
	return att
