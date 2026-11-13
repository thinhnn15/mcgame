class_name ChibiMerge
extends RefCounted

const KEEP := ["Head_mCheek", "Head_mEye", "Head_mMouth", "Head_mPaint", "Apron"]
const KEEP_PREFIX := ["Hair_", "Tool_"]
const WHITE := Color(1, 1, 1, 1)

static func merge(c: Chibi) -> int:
	"""Merge what can be merged; returns how many draws were saved."""
	var groups := {}
	for mi: MeshInstance3D in c.skel.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if not mi.visible or mi.mesh == null or mi.skin == null or n in KEEP \
				or KEEP_PREFIX.any(func(pre: String) -> bool: return n.begins_with(pre)):
			continue
		if mi.get_node_or_null(mi.skeleton) != c.skel:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m == null:
				continue
			var key := _signature(m)
			if not groups.has(key):
				groups[key] = []
			groups[key].append([mi, s])
	var saved := 0
	for key in groups:
		var g: Array = groups[key]
		if g.size() < 2:
			continue
		var whole := _merge_group(c, g)
		if whole != null:
			saved += g.size() - 1
	return saved

static func _signature(m: Material) -> String:
	if not m is ShaderMaterial:
		return str(m.get_instance_id())
	var sm := m as ShaderMaterial
	var vals := [sm.shader.get_instance_id()]
	for u in sm.shader.get_shader_uniform_list(true):
		var v = sm.get_shader_parameter(u["name"])
		vals.append(v.get_instance_id() if v is Object else v)
	return str(vals)

static func _merge_group(c: Chibi, g: Array) -> MeshInstance3D:
	"""One mesh, one surface, one skin out of the group's surfaces; the parts that are wholly merged are hidden."""
	var first: MeshInstance3D = g[0][0]
	var skin := Skin.new()
	var bind_of := {}
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var index := PackedInt32Array()
	var per := -1
	for item in g:
		var mi: MeshInstance3D = item[0]
		var a := mi.mesh.surface_get_arrays(item[1])
		var vb: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var vw: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		if vb.is_empty() or v.is_empty() or a[Mesh.ARRAY_TEX_UV] == null:
			return null
		var k := vb.size() / v.size()
		if per < 0:
			per = k
		elif k != per:
			return null
	for item in g:
		var mi: MeshInstance3D = item[0]
		var a := mi.mesh.surface_get_arrays(item[1])
		var base := verts.size()
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		verts.append_array(v)
		normals.append_array(a[Mesh.ARRAY_NORMAL])
		uvs.append_array(a[Mesh.ARRAY_TEX_UV])
		if a[Mesh.ARRAY_COLOR] != null:
			colors.append_array(a[Mesh.ARRAY_COLOR])
		else:
			for i in v.size():
				colors.append(WHITE)
		var remap := PackedInt32Array()
		for b in mi.skin.get_bind_count():
			var bn := String(mi.skin.get_bind_name(b))
			if bn == "":
				bn = "#%d" % mi.skin.get_bind_bone(b)
			if not bind_of.has(bn):
				bind_of[bn] = skin.get_bind_count()
				skin.add_bind(mi.skin.get_bind_bone(b), mi.skin.get_bind_pose(b))
				skin.set_bind_name(skin.get_bind_count() - 1, mi.skin.get_bind_name(b))
			remap.append(bind_of[bn])
		for bi: int in a[Mesh.ARRAY_BONES]:
			bones.append(remap[bi] if bi < remap.size() else 0)
		weights.append_array(a[Mesh.ARRAY_WEIGHTS])
		var idx = a[Mesh.ARRAY_INDEX]
		if idx == null:
			for i in v.size():
				index.append(base + i)
		else:
			for i: int in idx:
				index.append(base + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	var whole := MeshInstance3D.new()
	whole.name = "Merged_" + String(first.name)
	whole.mesh = mesh
	whole.skin = skin
	whole.set_surface_override_material(0, first.get_active_material(g[0][1]))
	whole.cast_shadow = first.cast_shadow
	first.get_parent().add_child(whole)
	whole.skeleton = whole.get_path_to(c.skel)
	whole.transform = first.transform

	var taken := {}
	for item in g:
		taken[item[0]] = taken.get(item[0], 0) + 1
	for mi: MeshInstance3D in taken:
		if taken[mi] == mi.mesh.get_surface_count():
			mi.visible = false
		else:
			for item in g:
				if item[0] == mi:
					mi.set_surface_override_material(item[1], _invisible())
	return whole

static var _none: Material

static func _invisible() -> Material:
	"""A surface drawn by the merged mesh now, left in a part that keeps others: discarded."""
	if _none == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nvoid fragment() { discard; }\n"
		var m := ShaderMaterial.new()
		m.shader = sh
		_none = m
	return _none
