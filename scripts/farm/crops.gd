class_name Crops

const DIR := "res://props/farm/"
const TABLE := "res://data/farm/crops.json"
const FOLIAGE := preload("res://shaders/crop_foliage.gdshader")
const CELL := 0.4
const HIDE_AT := 30.0

static var _table := {}
static var _meshes := {}
static var _arrays := {}
static var _mat: ShaderMaterial

static func table() -> Dictionary:
	if _table.is_empty():
		_table = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	return _table

static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = FOLIAGE
		_mat.set_shader_parameter("atlas", load(DIR + "crop_atlas.png"))
	return _mat

static func mesh(model: String) -> Mesh:
	if not _meshes.has(model):
		var scene: Node = (load(DIR + model + ".glb") as PackedScene).instantiate()
		var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
		_meshes[model] = mi.mesh
		scene.free()
	return _meshes[model]

static func model(crop: String, stage: int) -> String:
	var models: Array = table()[crop]["models"]
	return models[clampi(stage, 0, models.size() - 1)]

static func draw(parent: Node3D, plants: Array, shadows := false, merge := false) -> Array:
	if merge:
		return [_merged(parent, plants, shadows)]
	var groups := {}
	for p in plants:
		if not groups.has(p.model):
			groups[p.model] = []
		groups[p.model].append(p)
	var out := []
	for model_name in groups:
		var list: Array = groups[model_name]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh(model_name)
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, list[i].get("yaw", 0.0)), list[i].pos))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = model_name
		mmi.multimesh = mm
		mmi.material_override = material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = HIDE_AT
		mmi.visibility_range_end_margin = 4.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent.add_child(mmi)
		out.append(mmi)
	return out

static func _merged(parent: Node3D, plants: Array, shadows: bool) -> MeshInstance3D:
	var cols := {Mesh.ARRAY_VERTEX: PackedVector3Array(), Mesh.ARRAY_NORMAL: PackedVector3Array(),
			Mesh.ARRAY_COLOR: PackedColorArray(), Mesh.ARRAY_TEX_UV: PackedVector2Array(),
			Mesh.ARRAY_TEX_UV2: PackedVector2Array()}
	var idx := PackedInt32Array()
	for p in plants:
		if not _arrays.has(p.model):
			_arrays[p.model] = mesh(p.model).surface_get_arrays(0)
		var a: Array = _arrays[p.model]
		var xf := Transform3D(Basis(Vector3.UP, p.get("yaw", 0.0)), p.pos)
		var base: int = cols[Mesh.ARRAY_VERTEX].size()
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		for i in vs.size():
			cols[Mesh.ARRAY_VERTEX].append(xf * vs[i])
			cols[Mesh.ARRAY_NORMAL].append(xf.basis * ns[i])
		cols[Mesh.ARRAY_COLOR].append_array(a[Mesh.ARRAY_COLOR])
		cols[Mesh.ARRAY_TEX_UV].append_array(a[Mesh.ARRAY_TEX_UV])
		cols[Mesh.ARRAY_TEX_UV2].append_array(a[Mesh.ARRAY_TEX_UV2])
		var ii: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var at := idx.size()
		idx.append_array(ii)
		for i in ii.size():
			idx[at + i] += base
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	for k in cols:
		arr[k] = cols[k]
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "Garden"
	mi.mesh = am
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
