class_name GroundAO
extends RefCounted

const PNG := "res://data/hometown/ground_ao.png"
const META := "res://data/hometown/ground_ao.json"
const M_PX := 0.5
const EXTENT := 320.0
const CONTACT_LO := -0.6
const CONTACT_HI := 0.9
const OVER_HI := 4.5
const FALLOFF := 2.0

const SKIP_SHADERS := ["greybox_terrain", "home_water", "home_grass", "grass_tuft", "undergrowth", "farm_grass",
	"home_lamp_pool", "crop_foliage", "rice"]

static func off() -> void:
	RenderingServer.global_shader_parameter_set("ground_ao_on", 0.0)

static func after_build(home: Node3D) -> void:
	if OS.get_cmdline_user_args().has("--groundao-bake"):
		bake.call_deferred(home)
		return
	load_baked()

static func load_baked() -> void:
	off()
	if OS.get_environment("MC_GROUNDAO_OLD") == "1" or not FileAccess.file_exists(META):
		return
	var t0 := Time.get_ticks_usec()
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(META))
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(PNG)) if not TexCache.shipped() \
		else (load(PNG) as Texture2D).get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RG8)
	img.generate_mipmaps()
	var m: float = meta["m"]
	RenderingServer.global_shader_parameter_set("ground_ao_tex", ImageTexture.create_from_image(img))
	RenderingServer.global_shader_parameter_set("ground_ao_rect", Vector4(meta["x0"], meta["z0"],
		1.0 / (img.get_width() * m), 1.0 / (img.get_height() * m)))
	RenderingServer.global_shader_parameter_set("ground_ao_on", 1.0)
	print("ground_ao: loaded %dx%d in %.1f ms" % [img.get_width(), img.get_height(), (Time.get_ticks_usec() - t0) / 1000.0])

static var _tris := {}

static func _mesh_tris(mesh: Mesh) -> PackedVector3Array:
	var id := mesh.get_instance_id()
	if _tris.has(id):
		return _tris[id]
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
			continue
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ix = arr[Mesh.ARRAY_INDEX]
		if ix != null and (ix as PackedInt32Array).size() > 0:
			for i: int in ix:
				out.append(v[i])
		else:
			out.append_array(v.slice(0, v.size() - v.size() % 3))
	_tris[id] = out
	return out

static func _skip_material(gi: GeometryInstance3D, mesh: Mesh) -> bool:
	var mats := [gi.material_override]
	if mesh != null and mesh.get_surface_count() > 0:
		mats.append(mesh.surface_get_material(0))
		if gi is MeshInstance3D:
			mats.append((gi as MeshInstance3D).get_surface_override_material(0))
	for m in mats:
		if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
			var p := (m as ShaderMaterial).shader.resource_path.get_file().get_basename()
			for s: String in SKIP_SHADERS:
				if p.begins_with(s):
					return true
	return false

static func _skip_node(n: Node, root: Node) -> bool:
	var p := n
	while p != null and p != root:
		if p is CharacterBody3D or p is Skeleton3D:
			return true
		var nm := String(p.name).to_lower()
		if nm.contains("boat") or nm.contains("bus") or nm == "far" or nm.ends_with("_far") or nm.ends_with("_shadow"):
			return true
		p = p.get_parent()
	return false

static func bake(home: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var hts: PackedFloat32Array = home.get("heights")
	var gn: int = home.get("N")
	var gh: int = home.get("HALF")
	var w := int(EXTENT * 2.0 / M_PX)
	var x0 := -EXTENT
	var z0 := -EXTENT
	var rc := PackedByteArray()
	rc.resize(w * w)
	var gc := PackedByteArray()
	gc.resize(w * w)
	var rect := AABB(Vector3(x0, -1000, z0), Vector3(EXTENT * 2.0, 4000, EXTENT * 2.0))
	var jobs := []
	for gi: GeometryInstance3D in home.find_children("*", "GeometryInstance3D", true, false):
		if not gi.is_visible_in_tree() or gi.visibility_range_begin > 0.0 \
				or gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or _skip_node(gi, home):
			continue
		if gi is MeshInstance3D:
			var mi := gi as MeshInstance3D
			if mi.mesh == null or mi.skin != null or mi.name == &"Decals" or _skip_material(mi, mi.mesh):
				continue
			if not (mi.global_transform * mi.mesh.get_aabb()).intersects(rect):
				continue
			jobs.append([mi.mesh, [mi.global_transform], true])
		elif gi is MultiMeshInstance3D:
			var mm := (gi as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null or mm.transform_format != MultiMesh.TRANSFORM_3D \
					or _skip_material(gi, mm.mesh) or mm.mesh.get_aabb().size.y < 0.4:
				continue
			var gx := (gi as Node3D).global_transform
			var xs := []
			var n := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			for i in n:
				var xf := gx * mm.get_instance_transform(i)
				if (xf * mm.mesh.get_aabb()).intersects(rect):
					xs.append(xf)
			if not xs.is_empty():
				jobs.append([mm.mesh, xs, false])
	var n_tri := 0
	var n_inst := 0
	for job: Array in jobs:
		var lt := _mesh_tris(job[0])
		if lt.is_empty():
			continue
		var over: bool = job[2]
		var hi := OVER_HI if over else CONTACT_HI
		for xf: Transform3D in job[1]:
			n_inst += 1
			var box: AABB = xf * (job[0] as Mesh).get_aabb()
			var cx := clampi(roundi(box.get_center().x) + gh, 0, gn - 1)
			var cz := clampi(roundi(box.get_center().z) + gh, 0, gn - 1)
			if box.position.y - hts[cz * gn + cx] > hi + 3.0:
				continue
			var wt: PackedVector3Array = xf * lt
			for t in range(0, wt.size(), 3):
				var a := wt[t]
				var b := wt[t + 1]
				var c := wt[t + 2]
				var lo_x := minf(a.x, minf(b.x, c.x))
				var hi_x := maxf(a.x, maxf(b.x, c.x))
				var lo_z := minf(a.z, minf(b.z, c.z))
				var hi_z := maxf(a.z, maxf(b.z, c.z))
				if hi_x < x0 or lo_x > -x0 or hi_z < z0 or lo_z > -z0:
					continue
				var ax := clampi(roundi(a.x) + gh, 0, gn - 1)
				var az := clampi(roundi(a.z) + gh, 0, gn - 1)
				if minf(a.y, minf(b.y, c.y)) - hts[az * gn + ax] > hi + 2.0:
					continue
				var nrm := (b - a).cross(c - a)
				var ln := nrm.length()
				if ln < 1e-6:
					continue
				var flat := absf(nrm.y) / ln > 0.75
				if flat and not over:
					continue
				n_tri += 1
				var e := maxf((b - a).length(), maxf((c - a).length(), (c - b).length()))
				var k := clampi(ceili(e / 0.3), 1, 240)
				var ab := (b - a) / k
				var ac := (c - a) / k
				for i in k + 1:
					for j in k + 1 - i:
						var p := a + ab * i + ac * j
						var px := int((p.x - x0) / M_PX)
						var pz := int((p.z - z0) / M_PX)
						if px < 0 or pz < 0 or px >= w or pz >= w:
							continue
						var hx := clampi(roundi(p.x) + gh, 0, gn - 1)
						var hz := clampi(roundi(p.z) + gh, 0, gn - 1)
						var h := p.y - hts[hz * gn + hx]
						if h > CONTACT_LO and h < CONTACT_HI and not flat:
							rc[pz * w + px] = 1
						elif over and h >= CONTACT_HI and h < OVER_HI:
							gc[pz * w + px] = 1
	var t1 := Time.get_ticks_msec()

	var d := PackedFloat32Array()
	d.resize(w * w)
	for i in w * w:
		d[i] = 0.0 if rc[i] else 1e9
	const D2 := 1.4142
	for z in w:
		for x in w:
			var i := z * w + x
			var v := d[i]
			if v == 0.0:
				continue
			if x > 0: v = minf(v, d[i - 1] + 1.0)
			if z > 0:
				v = minf(v, d[i - w] + 1.0)
				if x > 0: v = minf(v, d[i - w - 1] + D2)
				if x < w - 1: v = minf(v, d[i - w + 1] + D2)
			d[i] = v
	for z in range(w - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := z * w + x
			var v := d[i]
			if v == 0.0:
				continue
			if x < w - 1: v = minf(v, d[i + 1] + 1.0)
			if z < w - 1:
				v = minf(v, d[i + w] + 1.0)
				if x < w - 1: v = minf(v, d[i + w + 1] + D2)
				if x > 0: v = minf(v, d[i + w - 1] + D2)
			d[i] = v
	var fr := FALLOFF / M_PX
	var r := PackedFloat32Array()
	r.resize(w * w)
	var g := PackedFloat32Array()
	g.resize(w * w)
	for i in w * w:
		r[i] = clampf(1.0 - d[i] / fr, 0.0, 1.0)
		g[i] = float(gc[i])
	_box(r, w, 1)
	for pass_ in 2:
		_box(g, w, 2)

	var lo := Vector2i(w, w)
	var hi := Vector2i(-1, -1)
	var data := PackedByteArray()
	data.resize(w * w * 2)
	for z in w:
		for x in w:
			var i := z * w + x
			var rv := roundi(r[i] * 255.0)
			var gv := roundi(clampf(g[i], 0.0, 1.0) * 255.0)
			data[i * 2] = rv
			data[i * 2 + 1] = gv
			if rv > 2 or gv > 2:
				lo = lo.min(Vector2i(x, z))
				hi = hi.max(Vector2i(x, z))
	var img := Image.create_from_data(w, w, false, Image.FORMAT_RG8, data)
	lo = (lo - Vector2i(4, 4)).max(Vector2i.ZERO)
	hi = (hi + Vector2i(5, 5)).min(Vector2i(w, w))
	var sub := img.get_region(Rect2i(lo, hi - lo))
	sub.save_png(ProjectSettings.globalize_path(PNG))
	var f := FileAccess.open(META, FileAccess.WRITE)
	f.store_string(JSON.stringify({"x0": x0 + lo.x * M_PX, "z0": z0 + lo.y * M_PX, "m": M_PX,
		"w": sub.get_width(), "h": sub.get_height(), "baked": Time.get_datetime_string_from_system()}, "  "))
	f.close()
	print("ground_ao bake: %d meshes / %d instances / %d triangles, %dx%d px, raster %d ms, total %d ms" % [jobs.size(),
		n_inst, n_tri, sub.get_width(), sub.get_height(), t1 - t0, Time.get_ticks_msec() - t0])
	home.get_tree().quit()

static func _box(a: PackedFloat32Array, w: int, rad: int) -> void:
	"""a separable box blur of radius rad px, in place (rows then columns, running sums)"""
	var tmp := PackedFloat32Array()
	tmp.resize(w)
	var inv := 1.0 / (rad * 2 + 1)
	for z in w:
		var s := 0.0
		for x in range(-rad, rad + 1):
			s += a[z * w + clampi(x, 0, w - 1)]
		for x in w:
			tmp[x] = s * inv
			s += a[z * w + mini(x + rad + 1, w - 1)] - a[z * w + maxi(x - rad, 0)]
		for x in w:
			a[z * w + x] = tmp[x]
	for x in w:
		var s := 0.0
		for z in range(-rad, rad + 1):
			s += a[clampi(z, 0, w - 1) * w + x]
		for z in w:
			tmp[z] = s * inv
			s += a[mini(z + rad + 1, w - 1) * w + x] - a[maxi(z - rad, 0) * w + x]
		for z in w:
			a[z * w + x] = tmp[z]
