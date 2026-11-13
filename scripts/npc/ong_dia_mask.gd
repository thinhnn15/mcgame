class_name OngDiaMask
extends RefCounted

const NAME := "mat_na_ong_dia"
const HEAD_C := Vector3(0.0, 1.19, -0.07)

static func add(c: Chibi) -> Node3D:
	if c.skel == null or not ResourceLoader.exists(Furniture.DIR + NAME + ".glb"):
		return null
	var bone := c.skel.find_bone("Head")
	if bone < 0:
		return null
	var att := BoneAttachment3D.new()
	att.name = "OngDiaMask"
	att.bone_name = "Head"
	c.skel.add_child(att)
	var holder := Node3D.new()
	holder.transform = DollShape.chibi_rest(c.skel, bone).affine_inverse()
	att.add_child(holder)
	var scene: Node3D = load(Furniture.DIR + NAME + ".glb").instantiate()
	scene.position = HEAD_C
	holder.add_child(scene)
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = Furniture.material(NAME)
	return att
