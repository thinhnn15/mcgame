class_name Apron
extends RefCounted

const PATH := "res://characters/face_wear/tap_de.glb"
const DESIGN := "res://characters/face_wear/tap_de_dsn.png"

const STYLES := {"": ["res://characters/face_wear/tap_de.glb", "res://characters/face_wear/tap_de_dsn.png"],
	"ren": ["res://characters/face_wear/tap_de_ren.glb", "res://characters/face_wear/tap_de_ren_dsn.png"]}

static func add(c: Chibi, look: Dictionary) -> Array:
	var out := []
	var style: Array = STYLES.get(str(look.get("apron_style", "")), STYLES[""])
	if not look.has("apron") or c.skel == null or c.skel.find_bone("Ta_F_1") < 0 or not ResourceLoader.exists(style[0]):
		return out
	var base := Color(str(look["apron"]))
	var scene: Node = load(style[0]).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.name = "Apron"
		copy.mesh = mi.mesh
		copy.skin = mi.skin
		var m := ShaderMaterial.new()
		m.shader = Chibi.TOON_CLOTH
		m.set_shader_parameter("base_color", base)
		m.set_shader_parameter("shade_soft", 0.5)
		m.set_shader_parameter("rim", 0.2)
		m.set_shader_parameter("has_design", true)
		m.set_shader_parameter("design_tex", load(style[1]))
		m.set_shader_parameter("design_b", Color(str(look.get("apron_b", base.darkened(0.18).to_html()))))
		m.set_shader_parameter("color_c", Color(str(look.get("apron_c", "#f3efe6"))))

		var fab := str(look.get("apron_fabric", "da" if style == STYLES["ren"] else "vai"))
		if Wardrobe.fabrics_on:
			m.set_shader_parameter("fabric", Wardrobe.FABRIC_IDS.get(fab, 0))
			m.set_shader_parameter("gloss_b", 1.0 if style == STYLES["ren"] else 0.0)
			m.set_shader_parameter("has_weave", true)
			m.set_shader_parameter("weave_tex", load(Wardrobe.WEAVE_DIR + fab + ".png"))
			m.set_shader_parameter("weave_scale", Vector2(45.0, 45.0))
		for s in copy.mesh.get_surface_count():
			copy.set_surface_override_material(s, m)
		c.skel.add_child(copy)
		copy.skeleton = NodePath("..")
		out.append(copy)
	scene.free()
	return out
