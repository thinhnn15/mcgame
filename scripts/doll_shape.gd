class_name DollShape
extends SkeletonModifier3D

const HEAD_SCALE := 0.78
const HEAD_PITCH := 10.0

const ARM_THICK := 1.35
const LEG_THICK := 1.3
const FOOT_SCALE := 1.3
const WRIST_X := 0.453
const LEG_X := 0.088
const NOSE_SCALE := 0.6

const MAP := [[0.0, 0.0], [0.079, 0.115], [0.239, 0.40], [0.50, 0.73], [0.813, 1.076], [0.858, 1.10], [0.896, 1.133]]
const SHOULDER_X := 0.111
const ARM_STRETCH := 1.4
const ARM_BONES := ["Clavicle", "Arm_", "Wrist_", "Hand_", "Finger_"]
const TOOL_BONES := ["Item", "Pole", "Z_Pole"]

static var everyone := OS.get_cmdline_user_args().has("--doll")

var _head := -1
var _hips := -1
var _hips_lift := 0.0
var _ankles: Array[int] = []
var _old_g: Array[Transform3D] = []
var _new_g: Array[Transform3D] = []
var _old_rest: Array[Transform3D] = []
var _kind := PackedByteArray()

static func wants(look: Dictionary) -> bool:
	var b := str(look.get("body", ""))
	return b == "doll" or (everyone and b != "kid" and b != "chibi")

static func sync(c: Chibi) -> void:
	"""Make the chibi match its look: doll on, off, or reshape whatever was put on since."""
	if c.skel == null:
		return
	var cur: DollShape = c.get_meta("doll") if c.has_meta("doll") else null
	var want := wants(c.look)
	if want and cur == null:
		cur = DollShape.new()
		cur._setup(c.skel)
		c.skel.add_child(cur)
		c.set_meta("doll", cur)
	elif not want and cur != null:
		cur._undo(c.skel)
		c.remove_meta("doll")
		cur.queue_free()
		return
	if cur:
		for mi in c.skel.find_children("*", "MeshInstance3D", true, false):
			cur._reshape(mi, c.skel)

static func chibi_rest(sk: Skeleton3D, bone: int) -> Transform3D:
	"""A bone's global rest as the chibi has it, for things authored on the chibi (a mask, a scarf on a
	BoneAttachment): holder = chibi_rest(...).affine_inverse() then follows the doll's bone - and its scale."""
	for c in sk.get_children():
		if c is DollShape and not c._old_g.is_empty():
			return c._old_g[bone]
	return sk.get_bone_global_rest(bone)

static func g(y: float) -> float:
	if y >= MAP[-1][0]:
		return y + MAP[-1][1] - MAP[-1][0]
	for i in MAP.size() - 1:
		var a: Array = MAP[i]
		var b: Array = MAP[i + 1]
		if y <= b[0]:
			return lerpf(a[1], b[1], (y - a[0]) / (b[0] - a[0]))
	return y

static func slope(y: float) -> float:
	for i in MAP.size() - 1:
		if y <= MAP[i + 1][0]:
			return (MAP[i + 1][1] - MAP[i][1]) / (MAP[i + 1][0] - MAP[i][0])
	return 1.0

static func _begins(n: String, list: Array) -> bool:
	for p in list:
		if n.begins_with(p):
			return true
	return false

static func warp(p: Vector3, arm: float, head: float) -> Vector3:
	"""One rest point: the body follows g; the arm moves with the shoulder and stretches out; the head moves up."""
	var lift_s: float = g(MAP[4][0]) - MAP[4][0]
	var lift_h: float = g(MAP[-1][0]) - MAP[-1][0]
	var body := Vector3(p.x, g(p.y), p.z)
	var leg := clampf((0.47 - p.y) / 0.06, 0.0, 1.0)
	if leg > 0.0:
		var lx := signf(p.x) * LEG_X
		var k := lerpf(1.0, LEG_THICK, leg)
		body.x = lx + (p.x - lx) * k
		body.z = p.z * k
	var ex := absf(p.x)
	var ax := p.x
	if ex > SHOULDER_X:
		ax = signf(p.x) * (SHOULDER_X + (minf(ex, WRIST_X) - SHOULDER_X) * ARM_STRETCH + maxf(0.0, ex - WRIST_X))
	var out := clampf((ex - SHOULDER_X) / 0.05, 0.0, 1.0) * clampf((WRIST_X + 0.04 - ex) / 0.04, 0.0, 1.0)
	var ak := lerpf(1.0, ARM_THICK, out)
	var armp := Vector3(ax, MAP[4][0] + (p.y - MAP[4][0]) * ak + lift_s, -0.03 + (p.z + 0.03) * ak)
	var headp := Vector3(p.x, p.y + lift_h, p.z)
	return body * (1.0 - arm - head) + armp * arm + headp * head

func _setup(sk: Skeleton3D) -> void:
	var n := sk.get_bone_count()
	_kind.resize(n)
	for i in n:
		_old_g.append(sk.get_bone_global_rest(i))
		_old_rest.append(sk.get_bone_rest(i))
		var name := sk.get_bone_name(i)
		var par := sk.get_bone_parent(i)
		if _begins(name, TOOL_BONES):
			_kind[i] = 3
		elif _begins(name, ARM_BONES):
			_kind[i] = 1
		elif name == "Head" or name == "Feel" or (par >= 0 and _kind[par] == 2):
			_kind[i] = 2
	for i in n:
		var t := _old_g[i]
		var k := _kind[i]
		_new_g.append(Transform3D(t.basis, warp(t.origin, 1.0 if k == 1 or k == 3 else 0.0, 1.0 if k == 2 else 0.0)))
	for i in n:
		var par := sk.get_bone_parent(i)
		sk.set_bone_rest(i, _new_g[i] if par < 0 else _new_g[par].affine_inverse() * _new_g[i])
	sk.reset_bone_poses()
	_hips = sk.find_bone("Skl_Root")
	_head = sk.find_bone("Head")
	_hips_lift = _new_g[_hips].origin.y - _old_g[_hips].origin.y
	for side in ["L", "R"]:
		var a := sk.find_bone("Ankle_" + side)
		if a >= 0:
			_ankles.append(a)
			_hips_lift += 0.0 if side == "R" else _new_g[a].origin.y * (FOOT_SCALE - 1.0)

func _undo(sk: Skeleton3D) -> void:
	for i in _old_rest.size():
		sk.set_bone_rest(i, _old_rest[i])
	sk.reset_bone_poses()
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		if not mi.has_meta("doll_src"):
			continue
		var src: Array = mi.get_meta("doll_src")
		var ov := _overrides(mi)
		if mi.mesh == mi.get_meta("doll_mesh"):
			mi.mesh = src[0]
		if mi.skin == mi.get_meta("doll_skin"):
			mi.skin = src[1]
		_put_overrides(mi, ov)
		for k in ["doll_src", "doll_mesh", "doll_skin"]:
			mi.remove_meta(k)

static var _cache := {}

func _reshape(mi: MeshInstance3D, sk: Skeleton3D) -> void:
	"""Give a mesh its doll shape and binds, always from the ORIGINALS: chibi.gd swaps meshes back in on its own
	(face shapes put back their plain mesh on every apply_look) while the skin stays ours - so each of the two is
	checked against what we last put there, and the original is taken from what we kept, never reshaped twice."""
	if mi.mesh == null or mi.skin == null:
		return
	var had := mi.has_meta("doll_src")
	var ours_mesh: bool = had and mi.mesh == mi.get_meta("doll_mesh")
	var ours_skin: bool = had and mi.skin == mi.get_meta("doll_skin")
	if ours_mesh and ours_skin:
		return
	var src := (mi.get_meta("doll_src")[0] if ours_mesh else mi.mesh) as ArrayMesh
	var skin: Skin = mi.get_meta("doll_src")[1] if ours_skin else mi.skin
	if src == null:
		return
	if not _cache.has(src):
		_cache[src] = _doll_mesh(src, skin, sk)
	if not _cache.has(skin):
		_cache[skin] = _doll_skin(skin, sk)
	var ov := _overrides(mi)
	mi.set_meta("doll_src", [src, skin])
	mi.mesh = _cache[src]
	mi.skin = _cache[skin]
	mi.set_meta("doll_mesh", mi.mesh)
	mi.set_meta("doll_skin", mi.skin)
	_put_overrides(mi, ov)

func _bind_bones(skin: Skin, sk: Skeleton3D) -> PackedInt32Array:
	var bind_bone := PackedInt32Array()
	for b in skin.get_bind_count():
		var bn := skin.get_bind_name(b)
		bind_bone.append(sk.find_bone(bn) if bn != "" else skin.get_bind_bone(b))
	return bind_bone

func _doll_skin(skin: Skin, sk: Skeleton3D) -> Skin:
	var bind_bone := _bind_bones(skin, sk)
	var nskin := skin.duplicate() as Skin
	for b in nskin.get_bind_count():
		var bone := bind_bone[b]
		if bone >= 0:
			nskin.set_bind_pose(b, _new_g[bone].affine_inverse() * _old_g[bone] * skin.get_bind_pose(b))
	return nskin

func _doll_mesh(src: ArrayMesh, skin: Skin, sk: Skeleton3D) -> ArrayMesh:
	var bind_bone := _bind_bones(skin, sk)
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(vs.size(), 1)
		for v in vs.size():
			var arm := 0.0
			var head := 0.0
			var tool := 0.0
			var tool_d := Vector3.ZERO
			for k in per:
				var w := ws[v * per + k]
				var bone := bind_bone[bones[v * per + k]] if w > 0.0 else -1
				if bone < 0:
					continue
				match _kind[bone]:
					1: arm += w
					2: head += w
					3:
						tool += w
						tool_d += (_new_g[bone].origin - _old_g[bone].origin) * w
			var p := vs[v]
			vs[v] = warp(p, arm, head) * (1.0 - tool) + (p * tool + tool_d)
			if ns.size() == vs.size():
				var k := lerpf(slope(p.y), 1.0, clampf(arm + head + tool, 0.0, 1.0))
				var nn := ns[v]
				ns[v] = Vector3(nn.x, nn.y / maxf(k, 0.2), nn.z).normalized()
		var mat := src.surface_get_material(s)
		if mat and mat.resource_name.begins_with("mNose") and vs.size() > 0:
			var bb := AABB(vs[0], Vector3.ZERO)
			for q in vs:
				bb = bb.expand(q)
			var anchor := Vector3(bb.get_center().x, bb.get_center().y, bb.position.z)
			for v in vs.size():
				vs[v] = anchor + (vs[v] - anchor) * NOSE_SCALE
		arr[Mesh.ARRAY_VERTEX] = vs
		if ns.size() == vs.size():
			arr[Mesh.ARRAY_NORMAL] = ns
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arr, [], {},
			src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(s, src.surface_get_material(s))
	return out

static func _overrides(mi: MeshInstance3D) -> Array:
	var ov := []
	for s in mi.get_surface_override_material_count():
		ov.append(mi.get_surface_override_material(s))
	return ov

static func _put_overrides(mi: MeshInstance3D, ov: Array) -> void:
	for s in mini(ov.size(), mi.get_surface_override_material_count()):
		mi.set_surface_override_material(s, ov[s])

func _process_modification() -> void:
	var sk := get_skeleton()
	if _hips >= 0:
		sk.set_bone_pose_position(_hips, sk.get_bone_pose_position(_hips) + Vector3(0, _hips_lift, 0))
	for a in _ankles:
		sk.set_bone_pose_scale(a, sk.get_bone_pose_scale(a) * FOOT_SCALE)
	if _head >= 0:
		sk.set_bone_pose_scale(_head, sk.get_bone_pose_scale(_head) * HEAD_SCALE)
		sk.set_bone_pose_rotation(_head, sk.get_bone_pose_rotation(_head) * Quaternion(Vector3.RIGHT, deg_to_rad(HEAD_PITCH)))
