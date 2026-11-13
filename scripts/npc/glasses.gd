class_name Glasses
extends RefCounted

const AT := Vector3(0.0, 1.225, 0.275)
const EYE_X := 0.168
const HALF := Vector2(0.105, 0.078)
const RIM := 0.014
const DEPTH := 0.016
const WRAP := 12.0
const TEMPLE := Vector3(-0.01, -0.01, -0.17)
const PTS := 22
const SHAPES := {"rect": 3.2, "round": 2.15}

static var _meshes := {}

static func add(c: Chibi, look: Dictionary) -> Node3D:
	if not look.has("glasses") or c.skel == null:
		return null
	var bone := c.skel.find_bone("Head")
	if bone < 0:
		return null
	var att := BoneAttachment3D.new()
	att.name = "Glasses"
	att.bone_name = "Head"
	c.skel.add_child(att)
	var holder := Node3D.new()
	holder.transform = DollShape.chibi_rest(c.skel, bone).affine_inverse() * Transform3D(Basis(), AT)
	att.add_child(holder)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/toon.gdshader")
	m.set_shader_parameter("base_color", Color(str(look["glasses"])))
	m.set_shader_parameter("chara", 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(str(look.get("glasses_shape", "rect")))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	return att

static func _rim_point(k: int, grow: float, n: float) -> Vector2:
	"""Point k round the lens, `grow` outside it (a squarish ellipse: |x|^n + |y|^n = 1)."""
	var t := TAU * k / PTS
	var cx := cos(t)
	var sy := sin(t)
	var e := 2.0 / n
	return Vector2(signf(cx) * pow(absf(cx), e) * (HALF.x + grow), signf(sy) * pow(absf(sy), e) * (HALF.y + grow))

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	"""a-b-c-d round a face (either way round) that should face the side n points to: two triangles, wound
	so that side is the front (Godot: clockwise seen from the front)."""
	var order := [a, b, c, a, c, d] if (b - a).cross(c - a).dot(n) < 0.0 else [a, c, b, a, d, c]
	for p in order:
		st.set_normal(n)
		st.add_vertex(p)

static func mesh(shape := "rect") -> ArrayMesh:
	if _meshes.has(shape):
		return _meshes[shape]
	var n: float = SHAPES.get(shape, SHAPES["rect"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(WRAP) * side), Vector3(EYE_X * side, 0, 0))
		for k in PTS:
			var i0 := _rim_point(k, 0.0, n)
			var i1 := _rim_point(k + 1, 0.0, n)
			var o0 := _rim_point(k, RIM, n)
			var o1 := _rim_point(k + 1, RIM, n)
			var f := xf.basis * Vector3.BACK
			_quad(st, xf * Vector3(i0.x, i0.y, 0), xf * Vector3(o0.x, o0.y, 0), xf * Vector3(o1.x, o1.y, 0),
				xf * Vector3(i1.x, i1.y, 0), f)
			var out := xf.basis * Vector3((o0 + o1).x, (o0 + o1).y, 0).normalized()
			_quad(st, xf * Vector3(o0.x, o0.y, 0), xf * Vector3(o0.x, o0.y, -DEPTH), xf * Vector3(o1.x, o1.y, -DEPTH),
				xf * Vector3(o1.x, o1.y, 0), out)

		var edge := xf * Vector3((HALF.x + RIM) * side, HALF.y * 0.35, -DEPTH * 0.5)
		var back := edge + Vector3(TEMPLE.x * side, TEMPLE.y, TEMPLE.z)
		var h := Vector3(0, RIM * 0.5, 0)
		var w := Vector3(RIM * 0.6 * side, 0, 0)
		_quad(st, edge + h, back + h, back + h - w, edge + h - w, Vector3.UP)
		_quad(st, edge + h, edge - h, back - h, back + h, Vector3(side, 0, 0))

	var inner := EYE_X - HALF.x - RIM * 0.3
	var y := HALF.y * 0.3
	var bh := RIM * 0.45
	_quad(st, Vector3(-inner, y - bh, 0), Vector3(inner, y - bh, 0), Vector3(inner, y + bh, 0), Vector3(-inner, y + bh, 0), Vector3.BACK)
	_quad(st, Vector3(-inner, y + bh, 0), Vector3(inner, y + bh, 0), Vector3(inner, y + bh, -DEPTH), Vector3(-inner, y + bh, -DEPTH), Vector3.UP)
	st.index()
	_meshes[shape] = st.commit()
	return _meshes[shape]
