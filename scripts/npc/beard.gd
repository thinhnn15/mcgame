class_name Beard
extends RefCounted

const AT := Vector3(0.0, 0.955, 0.21)

const FACE_AT := {"chubby": Vector3(0.0, -0.006, 0.014), "slim": Vector3(0.0, -0.01, 0.008),
	"square": Vector3(0.0, 0.004, 0.006), "hollow": Vector3(0.0, 0.0, -0.004)}
const TILT := 18.0

const PROFILE := [[0.03, -0.012, 0.066, 0.03], [0.0, 0.0, 0.07, 0.035], [-0.025, 0.005, 0.05, 0.03],
	[-0.042, 0.008, 0.028, 0.02]]
const TIP := Vector3(0.0, -0.056, 0.01)
const SEGS := 10

static var _mesh: ArrayMesh

static func add(c: Chibi, look: Dictionary) -> Node3D:
	if not look.has("beard") or c.skel == null:
		return null
	var col := Color(str(look["beard"]))
	var bone := c.skel.find_bone("Head")
	if bone < 0:
		return null
	var att := BoneAttachment3D.new()
	att.name = "Beard"
	att.bone_name = "Head"
	c.skel.add_child(att)
	var holder := Node3D.new()
	holder.transform = DollShape.chibi_rest(c.skel, bone).affine_inverse() \
		* Transform3D(Basis(Vector3.RIGHT, deg_to_rad(TILT)), AT + FACE_AT.get(str(look.get("face", "")), Vector3.ZERO))
	att.add_child(holder)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/toon.gdshader")
	m.set_shader_parameter("base_color", col)
	m.set_shader_parameter("chara", 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	return att

static func mesh() -> ArrayMesh:
	"""The whole tuft as one mesh (one draw call): 70 triangles, smooth shared normals."""
	if _mesh:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in PROFILE:
		for j in SEGS:
			var u := TAU * j / SEGS
			st.add_vertex(Vector3(sin(u) * ring[2], ring[0], ring[1] + cos(u) * ring[3]))
	st.add_vertex(TIP)
	var tip := PROFILE.size() * SEGS
	for i in PROFILE.size():
		for j in SEGS:
			var a := i * SEGS + j
			var b := i * SEGS + (j + 1) % SEGS
			if i == PROFILE.size() - 1:
				st.add_index(a)
				st.add_index(b)
				st.add_index(tip)
				continue
			var d := a + SEGS
			var e := b + SEGS
			st.add_index(a)
			st.add_index(b)
			st.add_index(d)
			st.add_index(b)
			st.add_index(e)
			st.add_index(d)
	st.generate_normals()
	_mesh = st.commit()
	return _mesh
