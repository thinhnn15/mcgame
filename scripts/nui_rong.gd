class_name NuiRong
extends RefCounted

const STEP := 0.45
const NEAR_END := 70.0
const RUN := 24
const CRAG_SEED := 7
const CRAG_ASPECTS := [1.5, 1.9, 2.4, 3.0]
const BOARDWALK := [[-132, 214], [-121, 208], [-110, 216], [-98, 212], [-87, 219], [-76, 213]]
const CHOI_AT := 2
const FLANKS := 11
const WALL_CRAGS := false
const LIFT := 1.1

static var _home

static func build(home: Node3D) -> void:
	_home = home
	var s: Dictionary = home.layout["shrine"]
	if not s.has("stairs"):
		return
	var root := Node3D.new()
	root.name = "NuiRong"
	home.add_child(root)
	var stair := _stair_points(s)
	_stairs(root, s, stair)
	_flanks(root, s, stair)
	_crags(root, s, stair)
	_summit(root, s, stair)
	_dragon(root, s, stair)
	if home.terrain and home.terrain.has_method("set_all"):
		home.terrain.set_all("nr_less", 0.9)
	_foot(root, s, stair)

static func _stair_points(s: Dictionary) -> Dictionary:
	var pts: Array = s["stairs"]
	var y0: float = s["stair_y"][0]
	var y1: float = s["stair_y"][1]
	var arcs: Array[float] = [0.0]
	for i in range(1, pts.size()):
		arcs.append(arcs[-1] + Vector2(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]).length())
	var total: float = arcs[-1]
	var ys: Array[float] = []
	for i in pts.size():
		ys.append(float(s["stair_ys"][i]) if s.has("stair_ys") else y0 + (y1 - y0) * arcs[i] / total)
	var lands: Array = s.get("landings", [])
	var out := []
	var a := 1.0
	while a < total - 0.2:
		var e := _at(pts, arcs, ys, a)
		var ahead := _at(pts, arcs, ys, minf(a + STEP, total))
		var to_c := 1e9
		for lc: Dictionary in lands:
			to_c = minf(to_c, maxf(absf(a - float(lc["arc"])) - float(lc["len"]) / 2.0, 0.0))
		var p: Vector3 = e["p"]
		var pa: Vector3 = ahead["p"]
		out.append({"p": p, "dir": e["dir"], "flat": absf(pa.y - p.y) < 0.04, "arc": a, "to_corner": to_c})
		a += STEP
	var simple: Array = s.get("stair_simple", pts)
	return {"steps": out, "w": float(s["stair_w"]), "top": Vector3(pts[-1][0], y1, pts[-1][1]),
		"foot": Vector3(pts[0][0], y0, pts[0][1]), "pts": pts, "simple": simple, "lands": lands, "total": total,
		"arcs": arcs}

static func _near_other(st: Dictionary, x: float, z: float, arc: float, r: float) -> bool:
	var pts: Array = st["pts"]
	var arcs: Array[float] = st["arcs"]
	for i in range(1, pts.size()):
		if arcs[i] > arc - 0.8 and arcs[i - 1] < arc + 0.8:
			continue
		var a := Vector2(pts[i - 1][0], pts[i - 1][1])
		var b := Vector2(pts[i][0], pts[i][1])
		var q := Vector2(x, z)
		var ab := b - a
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		if q.distance_to(a + ab * t) < r:
			return true
	return false

static func _at(pts: Array, arcs: Array[float], ys: Array[float], a: float) -> Dictionary:
	var i := 1
	while i < pts.size() - 1 and arcs[i] < a:
		i += 1
	var t := clampf((a - arcs[i - 1]) / maxf(arcs[i] - arcs[i - 1], 1e-4), 0.0, 1.0)
	var pa := Vector2(pts[i - 1][0], pts[i - 1][1])
	var pb := Vector2(pts[i][0], pts[i][1])
	var q := pa.lerp(pb, t)
	return {"p": Vector3(q.x, lerpf(ys[i - 1], ys[i], t), q.y), "dir": (pb - pa).normalized()}

static func _zeros(n: int) -> Array[float]:
	var z: Array[float] = []
	z.resize(n)
	z.fill(0.0)
	return z

static func _h01(v: float) -> float:
	var x := absf(sin(v) * 43758.5453)
	return x - floorf(x)

static func _stairs(root: Node3D, s: Dictionary, st: Dictionary) -> void:
	var w: float = st["w"]
	var steps: Array = st["steps"]

	var raw_r: Array[float] = []
	var raw_l: Array[float] = []
	for e: Dictionary in steps:
		var p: Vector3 = e["p"]
		var dir: Vector2 = e["dir"]
		var rt := Vector2(-dir.y, dir.x)
		var off: float = w / 2.0 + (2.6 if e["flat"] else 1.6)
		raw_r.append(float(_home.height_at(p.x + rt.x * off, p.z + rt.y * off)) - p.y)
		raw_l.append(float(_home.height_at(p.x - rt.x * off, p.z - rt.y * off)) - p.y)
	var bac := {"nr_bac": [], "nr_bac_b": [], "nr_bac_c": []}
	var walls := {"nr_tuong": [], "nr_tuong_b": [], "nr_tuong_c": []}
	var kes := {"nr_ke": [], "nr_ke_b": []}
	var lat := []
	var far := []
	var wall_boxes := []
	var crags := []
	var turns: Array[Vector3] = []
	for lc: Dictionary in st["lands"]:
		if lc["kind"] == "den":
			turns.append(Vector3(float(lc["x"]), float(lc["y"]), float(lc["z"])))
	var last_crag := -100.0
	for k in steps.size():
		var e: Dictionary = steps[k]
		var dir: Vector2 = e["dir"]
		var p: Vector3 = e["p"]
		var yaw := atan2(dir.x, dir.y)
		var flat: bool = e["flat"]
		far.append(Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, -0.06, 0)))
		var on_turn := false
		for tc: Vector3 in turns:
			on_turn = on_turn or Vector2(p.x - tc.x, p.z - tc.z).length() < 2.45
		if on_turn:
			pass
		elif flat:
			if k % 2 == 0:
				lat.append(Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.08 - LIFT, 0)))
		else:
			var hsh := _h01(k * 12.9898 + 4.1)
			var kind := "nr_bac" if hsh < 0.5 else ("nr_bac_b" if hsh < 0.8 else "nr_bac_c")
			var jitter := sin(k * 7.31) * 0.03
			bac[kind].append(Transform3D(Basis(Vector3.UP, yaw + jitter), p + Vector3(0, 0.12 - LIFT, 0)))
		if k % 2 != 0:
			continue

		var r_avg := 0.0
		var l_avg := 0.0
		var n_avg := 0
		for j in range(maxi(k - 4, 0), mini(k + 5, steps.size())):
			r_avg += raw_r[j]
			l_avg += raw_l[j]
			n_avg += 1
		r_avg /= n_avg
		l_avg /= n_avg
		var half: float = w / 2.0 + (1.0 if flat else 0.0)
		for side: float in [1.0, -1.0]:
			var rise: float = r_avg if side > 0.0 else l_avg
			var d3 := Vector3(dir.x, 0, dir.y)
			var out3 := Vector3(-dir.y, 0, dir.x) * side
			var x_axis := d3 if side > 0.0 else -d3
			var o := p + out3 * half
			if side < 0.0:
				o -= x_axis * 0.9
			var basis := Basis(x_axis, Vector3.UP, x_axis.cross(Vector3.UP))
			var h2 := _h01(k * 3.77 + side * 1.3)
			var mid := o + x_axis * 0.45
			if _near_other(st, mid.x, mid.z, e["arc"], w / 2.0 - 0.05):
				continue
			if WALL_CRAGS and rise > 4.0 and float(e["arc"]) - last_crag > 3.2:

				var top_y: float = _home.height_at(p.x + out3.x * (w / 2.0 + 7.0), p.z + out3.z * (w / 2.0 + 7.0))
				var hgt := clampf(top_y - p.y + 2.0, 4.0, 18.0)
				var shp := 3 if h2 < 0.6 else 2
				var cr := clampf(hgt / float(CRAG_ASPECTS[shp]), 1.8, 4.2)
				var cp := p + out3 * (w / 2.0 + 0.25 + cr * 0.75)
				if not _near_other(st, cp.x, cp.z, e["arc"], cr * 0.75 + w / 2.0 + 0.1):
					crags.append([Vector3(cp.x, p.y - 1.2, cp.z), cr, shp, h2 * TAU])
					last_crag = float(e["arc"]) - cr * 0.6
			if rise < -0.6:
				if flat and h2 < 0.1:
					continue
				var wk := "nr_tuong" if h2 < 0.78 else ("nr_tuong_b" if h2 < 0.9 else "nr_tuong_c")
				walls[wk].append(Transform3D(basis, o))
				wall_boxes.append([o + x_axis * 0.45 + out3 * 0.18 + Vector3(0, 0.45, 0), x_axis])
			elif rise > 0.7:
				kes["nr_ke" if h2 < 0.6 else "nr_ke_b"].append(Transform3D(basis, o))
	for kind: String in bac:
		_runs(root, kind, bac[kind], NEAR_END, false)
	for kind: String in walls:
		_runs(root, kind, walls[kind], NEAR_END + 20.0, false)
	for kind: String in kes:
		_runs(root, kind, kes[kind], NEAR_END + 20.0, false)
	_runs(root, "nr_lat", lat, NEAR_END + 30.0, false)
	var slab := BoxMesh.new()
	slab.size = Vector3(w, 0.3, STEP + 0.04)
	_plain_runs(root, slab, far, Props.mat(Color("bdb6a6")), NEAR_END)
	var body := StaticBody3D.new()
	root.add_child(body)
	for wb: Array in wall_boxes:
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.95, 1.4, 0.36)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		var xa: Vector3 = wb[1]
		cs.transform = Transform3D(Basis(xa, Vector3.UP, xa.cross(Vector3.UP)), wb[0])
		body.add_child(cs)
	if not crags.is_empty():
		var by_shape := {}
		for c: Array in crags:
			var cr: float = c[1]
			var shp: int = c[2]
			if not by_shape.has(shp):
				by_shape[shp] = []
			var basis := Basis(Vector3.UP, float(c[3])) * Basis.from_scale(Vector3(cr, cr * 1.05, cr * 0.85))
			by_shape[shp].append(Transform3D(basis, c[0]))
		var mat := _karst_mat()
		for shp: int in by_shape:
			_plain_runs_mat(root, _home._first_mesh("res://props/hometown/karst/nr_crag_%d.glb" % shp), by_shape[shp], mat)
	_landings(root, st, body)

static func _karst_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/karst.gdshader")
	mat.set_shader_parameter("cov_mode", true)
	if ResourceLoader.exists("res://props/hometown/karst/rock_tile.png"):
		mat.set_shader_parameter("rock_tex", load("res://props/hometown/karst/rock_tile.png"))
		mat.set_shader_parameter("has_rock", true)
	mat.set_shader_parameter("cloud_tex", load("res://props/farm/ground/noise.png"))
	mat.set_shader_parameter("has_clouds", true)
	return mat

static func _landings(root: Node3D, st: Dictionary, body: StaticBody3D) -> void:
	var w: float = st["w"]
	var trees := []
	for lc: Dictionary in st["lands"]:
		var c := Vector3(float(lc["x"]), float(lc["y"]), float(lc["z"]))
		var d := Vector3(float(lc["dir"][0]), 0, float(lc["dir"][1]))
		var rt := Vector3(-d.z, 0, d.x)
		var ln: float = float(lc["len"])
		var hr: float = _home.height_at(c.x + rt.x * (w / 2.0 + 3.0), c.z + rt.z * (w / 2.0 + 3.0))
		var hl: float = _home.height_at(c.x - rt.x * (w / 2.0 + 3.0), c.z - rt.z * (w / 2.0 + 3.0))
		var up := rt if hr > hl else -rt
		var down := -up
		var face_down := rad_to_deg(atan2(down.x, down.z))
		var kind: String = lc["kind"]
		match kind:
			"nghi", "ngam":

				var bp := c + (up if kind == "nghi" else down) * (w / 2.0 + 0.35)
				_home._model("ghe_da", Vector3(bp.x, c.y + 0.04, bp.z), face_down, [])
				var lp := c + down * (w / 2.0 + 0.55) + d * (ln / 2.0 - 0.4)
				HomeKit.place(root, "nr_den", Vector3(lp.x, c.y + 0.04, lp.z), face_down)
				if kind == "nghi":
					var tp := c + up * (w / 2.0 + 2.6) - d * 0.6
					var sc := 0.62
					trees.append(Transform3D(Basis(Vector3.UP, float(lc["arc"])).scaled(Vector3(sc, sc, sc)),
						Vector3(tp.x, float(_home.height_at(tp.x, tp.z)) - 0.2, tp.z)))
			"den":

				var e0 := _at(st["pts"], st["arcs"], _zeros(st["pts"].size()), float(lc["arc"]) - 3.0)
				var e1 := _at(st["pts"], st["arcs"], _zeros(st["pts"].size()), float(lc["arc"]) + 3.0)
				var p0: Vector3 = e0["p"]
				var p1: Vector3 = e1["p"]
				var inner := Vector3((p0.x + p1.x) / 2.0 - c.x, 0, (p0.z + p1.z) / 2.0 - c.z)
				var outer := -inner.normalized() if inner.length() > 0.05 else down
				HomeKit.place(root, "nr_tron", Vector3(c.x, c.y + 0.06 - LIFT, c.z), 0.0)
				for sx: float in [-1.0, 1.0]:
					var lp := c + outer * (w / 2.0 + 0.6) + d * sx * 1.3
					HomeKit.place(root, "nr_den", Vector3(lp.x, c.y + 0.04, lp.z), rad_to_deg(atan2(outer.x, outer.z)))
			"mieu":
				var mp := c + up * (w / 2.0 + 0.45)
				Furniture.place(root, "am_tho", Vector3(mp.x, c.y + 0.04, mp.z), face_down, true)
				var lp := c + down * (w / 2.0 + 0.55)
				HomeKit.place(root, "nr_den", Vector3(lp.x, c.y + 0.04, lp.z), face_down)
			"cong":

				var gp := c + d * (ln / 2.0 - 0.3)
				HomeKit.place(root, "nr_cong_nho", Vector3(gp.x, c.y + 0.04, gp.z), rad_to_deg(atan2(-d.x, -d.z)), {}, 90.0)
				for sx: float in [-1.0, 1.0]:
					var bs := BoxShape3D.new()
					bs.size = Vector3(0.8, 3.0, 0.8)
					var cs := CollisionShape3D.new()
					cs.shape = bs
					cs.position = Vector3(gp.x, c.y + 1.5, gp.z) + rt * sx * 2.1
					body.add_child(cs)
	if not trees.is_empty():
		_home._kit_dress("cay_gao", trees)

static func _runs(root: Node3D, name: String, xforms: Array, end: float, shadow := true) -> void:
	var tmp := HomeKit.place(root, name, Vector3.ZERO)
	var parts := []
	for mi: MeshInstance3D in tmp.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh.duplicate()
		for sn in mesh.get_surface_count():
			mesh.surface_set_material(sn, mi.get_surface_override_material(sn))
		parts.append([mesh, tmp.global_transform.affine_inverse() * mi.global_transform])
	tmp.free()
	for start in range(0, xforms.size(), RUN):
		var chunk := xforms.slice(start, start + RUN)
		var c := Vector3.ZERO
		for xf: Transform3D in chunk:
			c += xf.origin
		c /= chunk.size()
		for part: Array in parts:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = chunk.size()
			for i in chunk.size():
				var xf: Transform3D = chunk[i]
				mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - c) * (part[1] as Transform3D))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d" % [name, start]
			mmi.multimesh = mm
			mmi.position = c
			if end > 0.0:
				mmi.visibility_range_end = end
				mmi.visibility_range_end_margin = 4.0
			if not shadow:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mmi)

static func _plain_runs(root: Node3D, mesh: Mesh, xforms: Array, m: Material, begin: float) -> void:
	for start in range(0, xforms.size(), RUN):
		var chunk := xforms.slice(start, start + RUN)
		var c := Vector3.ZERO
		for xf: Transform3D in chunk:
			c += xf.origin
		c /= chunk.size()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = chunk.size()
		for i in chunk.size():
			var xf: Transform3D = chunk[i]
			mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin - c))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m
		mmi.position = c
		mmi.visibility_range_begin = begin
		mmi.visibility_range_begin_margin = 4.0
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)

static func _crags(root: Node3D, s: Dictionary, st: Dictionary) -> void:
	var cx: float = s["x"]
	var cz: float = s["z"]
	var r: float = s["r"]
	var rng := RandomNumberGenerator.new()
	rng.seed = CRAG_SEED
	var placed := []
	var by_shape := {}
	var tries := 0
	while placed.size() < 10 and tries < 4000:
		tries += 1
		var an := rng.randf() * TAU
		var d := rng.randf_range(0.1, 0.85) * r
		var x := cx + cos(an) * d
		var z := cz + sin(an) * d
		if _stair_dist(st, x, z) < st["w"] / 2.0 + 4.0 or Vector2(x, z).distance_to(Vector2(st["top"].x, st["top"].z)) < 11.0:
			continue
		var ld := _line_dist(s["dragon"], x, z)
		if ld < 3.5 or _home.height_at(x, z) < 42.0:
			continue
		var u := d / (0.85 * r)
		var cr := lerpf(4.4, 2.8, u) * rng.randf_range(0.85, 1.15)
		var ok := true
		for q: Vector3 in placed:
			if Vector2(q.x, q.z).distance_to(Vector2(x, z)) < (q.y + cr) * 0.75:
				ok = false
				break
		if not ok:
			continue
		placed.append(Vector3(x, cr, z))
		var k := rng.randi_range(2, CRAG_ASPECTS.size() - 1)
		var asp: float = CRAG_ASPECTS[k]
		var gy: float = _home.height_at(x, z)
		var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(cr, cr * rng.randf_range(0.85, 1.15), cr * rng.randf_range(0.7, 1.0)))
		if not by_shape.has(k):
			by_shape[k] = []
		by_shape[k].append(Transform3D(basis, Vector3(x, gy - asp * cr * 0.35, z)))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/karst.gdshader")
	mat.set_shader_parameter("cov_mode", true)
	if ResourceLoader.exists("res://props/hometown/karst/rock_tile.png"):
		mat.set_shader_parameter("rock_tex", load("res://props/hometown/karst/rock_tile.png"))
		mat.set_shader_parameter("has_rock", true)
	mat.set_shader_parameter("cloud_tex", load("res://props/farm/ground/noise.png"))
	mat.set_shader_parameter("has_clouds", true)
	var body := StaticBody3D.new()
	root.add_child(body)
	for k: int in by_shape:
		var mesh: Mesh = _home._first_mesh("res://props/hometown/karst/nr_crag_%d.glb" % k)
		_plain_runs_mat(root, mesh, by_shape[k], mat)
		for xf: Transform3D in by_shape[k]:
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = xf.basis.x.length() * 0.75
			cy.height = float(CRAG_ASPECTS[k]) * xf.basis.y.length()
			cs.shape = cy
			cs.position = xf.origin + Vector3(0, cy.height / 2.0, 0)
			body.add_child(cs)

	var bushes := {"bui_dai_a": [], "bui_dai_b": []}
	var n := 0
	tries = 0
	while n < 90 and tries < 900:
		tries += 1
		var an := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r * 0.95
		var x := cx + cos(an) * d
		var z := cz + sin(an) * d
		if _stair_dist(st, x, z) < st["w"] / 2.0 + 1.5 or Vector2(x, z).distance_to(Vector2(st["top"].x, st["top"].z)) < 9.0:
			continue
		var inside := false
		for q: Vector3 in placed:
			if Vector2(q.x, q.z).distance_to(Vector2(x, z)) < q.y * 0.8:
				inside = true
				break
		if inside:
			continue
		var sc := rng.randf_range(0.8, 1.4)
		bushes["bui_dai_a" if n % 2 == 0 else "bui_dai_b"].append(Transform3D(
			Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(x, _home.height_at(x, z) - 0.1, z)))
		n += 1

	var k2 := 0
	for e: Dictionary in st["steps"]:
		k2 += 1
		if k2 % 5 != 0 or e["to_corner"] < 3.0:
			continue
		var dir: Vector2 = e["dir"]
		var side := Vector2(-dir.y, dir.x)
		for sd in [-1.0, 1.0]:
			if rng.randf() < 0.35:
				continue
			var o: Vector2 = Vector2(e["p"].x, e["p"].z) + side * sd * (st["w"] / 2.0 + rng.randf_range(0.9, 2.0))
			var sc := rng.randf_range(0.9, 1.5)
			bushes["bui_dai_a" if rng.randf() < 0.5 else "bui_dai_b"].append(Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(o.x, _home.height_at(o.x, o.y) - 0.15, o.y)))
	for kind: String in bushes:
		_home._kit_dress(kind, bushes[kind])

static func _flanks(root: Node3D, s: Dictionary, st: Dictionary) -> void:
	var dir := "res://props/hometown/karst/"
	var meta: Array = JSON.parse_string(FileAccess.get_file_as_string(dir + "karst.json"))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/karst.gdshader")
	mat.set_shader_parameter("cov_mode", true)
	if ResourceLoader.exists(dir + "rock_tile.png"):
		mat.set_shader_parameter("rock_tex", load(dir + "rock_tile.png"))
		mat.set_shader_parameter("has_rock", true)
	mat.set_shader_parameter("cloud_tex", load("res://props/farm/ground/noise.png"))
	mat.set_shader_parameter("has_clouds", true)
	var cx: float = s["x"]
	var cz: float = s["z"]
	var r: float = s["r"]
	var top: Vector3 = st["top"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var placed := []
	var body := StaticBody3D.new()
	root.add_child(body)
	var tries := 0
	while placed.size() < FLANKS and tries < 4000:
		tries += 1
		var an := rng.randf() * TAU
		var d := rng.randf_range(0.12, 0.62) * r
		var x := cx + cos(an) * d
		var z := cz + sin(an) * d
		var tr := rng.randf_range(6.0, 10.0)
		if _stair_dist(st, x, z) < st["w"] / 2.0 + 3.0 + tr * 0.9 or _line_dist(s["dragon"], x, z) < tr + 3.0:
			continue
		if Vector2(x, z).distance_to(Vector2(top.x, top.z)) < 12.0 + tr:
			continue
		var ok := true
		for q: Vector3 in placed:
			if Vector2(q.x, q.z).distance_to(Vector2(x, z)) < (q.y + tr) * 0.8:
				ok = false
				break
		if not ok:
			continue
		var gc: float = _home.height_at(x, z)
		if gc < 28.0:
			continue
		var gy := gc
		for j in 6:
			var aj := TAU * j / 6.0
			gy = minf(gy, _home.height_at(x + cos(aj) * tr * 0.8, z + sin(aj) * tr * 0.8))
		gy = (gy + gc) / 2.0
		var k := rng.randi_range(0, meta.size() - 1)
		var asp: float = meta[k]["aspect"]
		var hgt := tr * asp
		var y0: float = gy - hgt * 0.25
		if y0 + hgt > top.y + 6.0:
			hgt = top.y + 6.0 - y0
			if hgt < tr * 1.3:
				continue
		placed.append(Vector3(x, tr, z))
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(tr, hgt / asp, tr * rng.randf_range(0.75, 0.95))),
			Vector3(x, y0, z))
		var mi := MeshInstance3D.new()
		mi.mesh = _home._first_mesh(dir + "karst_%d.glb" % k)
		mi.material_override = mat
		mi.transform = xf
		root.add_child(mi)
		var pts := PackedVector3Array()
		for v: Vector3 in _home._first_mesh(dir + "karst_%d_far.glb" % k).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			pts.append(xf * v)
		var hull := ConvexPolygonShape3D.new()
		hull.points = pts
		var cs := CollisionShape3D.new()
		cs.shape = hull
		body.add_child(cs)

static func _plain_runs_mat(root: Node3D, mesh: Mesh, xforms: Array, m: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	root.add_child(mmi)

static func _stair_dist(st: Dictionary, x: float, z: float) -> float:
	return _line_dist(st["simple"], x, z)

static func _line_dist(pts: Array, x: float, z: float) -> float:
	var best := 1e9
	var q := Vector2(x, z)
	for i in range(1, pts.size()):
		var a := Vector2(pts[i - 1][0], pts[i - 1][1])
		var b := Vector2(pts[i][0], pts[i][1])
		best = minf(best, Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q))
	return best

static func _summit(root: Node3D, s: Dictionary, st: Dictionary) -> void:
	var top: Vector3 = st["top"]
	var pts: Array = st["pts"]
	var arrive := Vector2(pts[-1][0] - pts[-2][0], pts[-1][1] - pts[-2][1]).normalized()
	HomeKit.place(root, "nr_san", top + Vector3(0, -0.07, 0), 0.0, {}, 0.0)

	var crown := []
	var crng := RandomNumberGenerator.new()
	crng.seed = 77
	for i in 12:
		var an := TAU * (i + crng.randf_range(-0.2, 0.2)) / 12.0
		if absf(angle_difference(an, atan2(-arrive.y, -arrive.x))) < 0.28:
			continue
		var cr := crng.randf_range(2.6, 3.4)

		var below: float = top.y - 0.6 - _home.height_at(top.x + cos(an) * 6.3, top.z + sin(an) * 6.3)
		var hgt := clampf(below + 2.0, 1.5 * cr, 16.0) * crng.randf_range(0.95, 1.1)
		crown.append(Transform3D(Basis(Vector3.UP, crng.randf() * TAU) * Basis.from_scale(Vector3(cr, hgt / 1.5, cr * 0.85)),
			top + Vector3(cos(an) * 6.3, -hgt - 0.6, sin(an) * 6.3)))
	var km := ShaderMaterial.new()
	km.shader = preload("res://shaders/karst.gdshader")
	km.set_shader_parameter("cov_mode", true)
	if ResourceLoader.exists("res://props/hometown/karst/rock_tile.png"):
		km.set_shader_parameter("rock_tex", load("res://props/hometown/karst/rock_tile.png"))
		km.set_shader_parameter("has_rock", true)
	_plain_runs_mat(root, _home._first_mesh("res://props/hometown/karst/nr_crag_0.glb"), crown, km)
	var posts := []
	var rails := []
	var R := 5.2
	var gap_an := atan2(-arrive.y, -arrive.x)
	var n := 16
	for i in n:
		var an := TAU * i / n
		if absf(angle_difference(an, gap_an)) < 0.5:
			continue
		var p := top + Vector3(cos(an) * R, 0.2, sin(an) * R)
		posts.append(Transform3D(Basis(), p))
		var an2 := TAU * (i + 1) / n
		if absf(angle_difference(an2, gap_an)) < 0.5:
			continue
		var p2 := top + Vector3(cos(an2) * R, 0.2, sin(an2) * R)
		var d := p2 - p
		var bx := d.normalized()
		rails.append(Transform3D(Basis(bx, Vector3.UP, bx.cross(Vector3.UP)) * Basis.from_scale(Vector3(d.length() / 2.0, 1, 1)), p))
	_runs(root, "nr_cot", posts, 0.0, false)
	_runs(root, "nr_lan", rails, 0.0, false)

	var dr := Vector2(s["dragon"][2][0], s["dragon"][2][1]) - Vector2(top.x, top.z)
	var aside := Vector2(-arrive.y, arrive.x)
	if aside.dot(dr) > 0.0:
		aside = -aside

	var off := (arrive * 0.6 + aside * 0.8).normalized() * 3.0
	var at := top + Vector3(off.x, 0.2, off.y)
	var face := -off.normalized()
	var yaw := rad_to_deg(atan2(face.x, face.y))
	HomeKit.place(root, "nr_qa", at, yaw, {}, 0.0)
	var fwd := Vector3(face.x, 0, face.y)
	var rgt := fwd.cross(Vector3.UP)
	for sx in [-1.0, 1.0]:
		HomeKit.place(root, "chau_cay", at + fwd * 0.6 + rgt * sx * 1.6, yaw)
	for an2 in [gap_an + 1.2, gap_an - 1.25, gap_an + 2.4]:
		HomeKit.place(root, "chau_cay", top + Vector3(cos(an2) * (R - 0.8), 0.2, sin(an2) * (R - 0.8)), rad_to_deg(an2))
	var body := StaticBody3D.new()
	root.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.1, 3.0, 2.1)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = at + Vector3(0, 1.5, 0)
	cs.rotation.y = deg_to_rad(yaw)
	body.add_child(cs)
	for i in n:
		var an := TAU * (i + 0.5) / n
		if absf(angle_difference(an, gap_an)) < 0.5:
			continue
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.3, 1.2, TAU * R / n + 0.1)
		var c2 := CollisionShape3D.new()
		c2.shape = bs
		c2.position = top + Vector3(cos(an) * R, 0.8, sin(an) * R)
		c2.rotation.y = -an
		body.add_child(c2)
	_home._label("Đỉnh Núi Rồng", top + Vector3(0, 12, 0), 1.2)

static func _dragon(root: Node3D, s: Dictionary, st: Dictionary) -> void:
	if not ResourceLoader.exists(HomeKit.DIR + "rd_vay.glb"):
		return
	var top2 := Vector2(st["top"].x, st["top"].z)
	var flat := []
	var dp: Array = s["dragon"]
	for i in range(1, dp.size()):
		var a := Vector2(dp[i - 1][0], dp[i - 1][1])
		var b := Vector2(dp[i][0], dp[i][1])
		var ln := a.distance_to(b)
		var d := 0.0
		while d < ln:
			var p := a + (b - a) * d / ln
			if p.distance_to(top2) > 11.0:
				flat.append(p)
			d += 0.6
	if flat.size() < 12:
		return
	flat.reverse()
	var n := flat.size()
	var ground := []
	for p: Vector2 in flat:
		ground.append(_home.height_at(p.x, p.y))
	var smooth := []
	for i in n:
		var acc := 0.0
		var c := 0
		for j in range(maxi(i - 5, 0), mini(i + 6, n)):
			acc += ground[j]
			c += 1
		smooth.append(maxf(acc / c, ground[i] - 0.5))
	var spine := []
	var radius := []
	var arch := []
	for i in n:
		var u := float(i) / (n - 1)
		var r := lerpf(1.0, 0.36, pow(u, 1.1))
		var p2: Vector2 = flat[i]
		var t2: Vector2 = ((flat[mini(i + 1, n - 1)] as Vector2) - (flat[maxi(i - 1, 0)] as Vector2)).normalized()
		p2 += Vector2(-t2.y, t2.x) * 0.7 * sin(u * PI * 3.0)
		var hump := sin(clampf((u - 0.1) / 0.9, 0.0, 1.0) * PI * 4.0)

		var a := smoothstep(0.0, 1.0, absf(hump))
		var h := lerpf(-1.3 * r, 0.9 * r, a) if u > 0.1 else lerpf(2.2, -1.3 * r, u / 0.1)
		arch.append(a if u > 0.1 else 1.0)
		spine.append(Vector3(p2.x, float(smooth[i]) + h, p2.y))
		radius.append(r)

	var shown := []
	for i in n:
		var y: float = (spine[i] as Vector3).y
		var r: float = radius[i]
		var lift := 0.6 if float(i) / (n - 1) > 0.1 else 3.0
		shown.append(y + r * 0.95 >= float(ground[i]) and y - r - float(ground[i]) < lift)
	var i0 := 0
	while i0 < n:
		var i1 := i0
		while i1 < n and shown[i1] == shown[i0]:
			i1 += 1
		if shown[i0] and i1 - i0 < 4 and i0 > 0:
			for j in range(i0, i1):
				shown[j] = false
		i0 = i1
	var collars := []
	for i in range(1, n):
		if shown[i] != shown[i - 1]:
			var k := i if shown[i] else i - 1
			var cr: float = float(radius[k]) * 1.7
			var gp: Vector3 = spine[k]
			collars.append(Transform3D(Basis(Vector3.UP, float(k) * 2.1) * Basis.from_scale(Vector3(cr, cr * 0.55, cr)),
				Vector3(gp.x, float(ground[k]) - cr * 0.3, gp.z)))
	if not collars.is_empty():
		var cm := ShaderMaterial.new()
		cm.shader = preload("res://shaders/karst.gdshader")
		cm.set_shader_parameter("cov_mode", true)
		if ResourceLoader.exists("res://props/hometown/karst/rock_tile.png"):
			cm.set_shader_parameter("rock_tex", load("res://props/hometown/karst/rock_tile.png"))
			cm.set_shader_parameter("has_rock", true)
		_plain_runs_mat(root, _home._first_mesh("res://props/hometown/karst/nr_crag_0.glb"), collars, cm)
	var segs := []
	var crest := []
	var last_crest := -99
	for i in n:
		var r: float = radius[i]
		if not shown[i]:
			continue
		var t: Vector3 = ((spine[mini(i + 1, n - 1)] as Vector3) - (spine[maxi(i - 1, 0)] as Vector3)).normalized()
		var yv := (Vector3.UP - t * t.dot(Vector3.UP)).normalized()
		var bas := Basis(t, yv, t.cross(yv))
		segs.append(Transform3D(bas * Basis.from_scale(Vector3(1.0, r, r)), spine[i]))
		if float(arch[i]) > 0.35 and i - last_crest >= 2 and i > 4:
			last_crest = i
			crest.append(Transform3D(bas * Basis.from_scale(Vector3.ONE * r * 1.15), (spine[i] as Vector3) + yv * r * 0.78))
	_runs(root, "rd_dot", segs, 200.0)
	_runs(root, "rd_vay", crest, 160.0)

	var t0: Vector3 = ((spine[0] as Vector3) - (spine[2] as Vector3))
	t0.y = 0.0
	t0 = t0.normalized()
	var turn := t0.cross(Vector3.UP)
	var to_top: Vector3 = st["top"] - (spine[0] as Vector3)
	if turn.dot(to_top) < 0.0:
		turn = -turn
	t0 = (t0 + turn * 1.1).normalized()
	var hb := Basis(t0, Vector3.UP, t0.cross(Vector3.UP)) * Basis(Vector3(0, 0, 1), deg_to_rad(16.0)) * Basis.from_scale(Vector3.ONE * 0.85)
	_place(root, "rd_dau", Transform3D(hb, (spine[0] as Vector3) + Vector3(0, 0.3, 0)))

	var tail := n - 1
	while tail > 2 and not shown[tail]:
		tail -= 1
	var te: Vector3 = ((spine[tail] as Vector3) - (spine[tail - 2] as Vector3)).normalized()
	var yv2 := (Vector3.UP - te * te.dot(Vector3.UP)).normalized()
	_place(root, "rd_duoi", Transform3D(Basis(-te, yv2, (-te).cross(yv2)), spine[tail]))

static func _place(root: Node3D, name: String, xf: Transform3D) -> void:
	var n := HomeKit.place(root, name, Vector3.ZERO, 0.0, {}, 0.0)
	n.transform = xf

static func _foot(root: Node3D, s: Dictionary, st: Dictionary) -> void:
	var pts: Array = st["pts"]
	var first := Vector2(pts[1][0] - pts[0][0], pts[1][1] - pts[0][1]).normalized()
	var foot: Vector3 = st["foot"]
	var gate := Vector3(foot.x, _home.height_at(foot.x, foot.z), foot.z) - Vector3(first.x, 0, first.y) * 1.0
	var gn := HomeKit.place(root, "nr_cong", gate, rad_to_deg(atan2(-first.x, -first.y)), {}, 60.0)
	var name := Label3D.new()
	name.text = "Núi Rồng"
	name.font_size = 96
	name.pixel_size = 0.0032
	name.modulate = Color("f2c94c")
	name.outline_size = 0
	name.position = Vector3(0, 3.62, 0.27)
	name.double_sided = false
	gn.add_child(name)
	var out := -Vector3(first.x, 0, first.y)
	for sx in [-1.0, 1.0]:
		var lp: Vector3 = gate + out * 2.6 + Vector3(-first.y, 0, first.x) * float(sx) * 2.8
		HomeKit.place(root, "nr_den", Vector3(lp.x, _home.height_at(lp.x, lp.z), lp.z), rad_to_deg(atan2(out.x, out.z)))
	var body := StaticBody3D.new()
	root.add_child(body)
	var side := Vector3(-first.y, 0, first.x)
	for sx in [-1.0, 1.0]:
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.85, 3.4, 0.85)
		var cs := CollisionShape3D.new()
		cs.shape = bs
		cs.position = gate + side * sx * 2.1 + Vector3(0, 1.7, 0)
		body.add_child(cs)

	var walk := []
	var deck := []
	for i in range(1, BOARDWALK.size()):
		var a := Vector3(BOARDWALK[i - 1][0], 0, BOARDWALK[i - 1][1])
		var b := Vector3(BOARDWALK[i][0], 0, BOARDWALK[i][1])
		var ln := a.distance_to(b)
		var n := maxi(1, roundi(ln / 3.0))
		var bx := (b - a).normalized()
		var basis := Basis(bx, Vector3.UP, bx.cross(Vector3.UP))
		for j in n:
			walk.append(Transform3D(basis * Basis.from_scale(Vector3(ln / n / 3.0, 1, 1)), a + bx * (ln * j / n)))
		deck.append([a, b])
	_runs(root, "nr_cau", walk, 0.0, false)
	var choi_at := Vector3(BOARDWALK[CHOI_AT][0], 0, BOARDWALK[CHOI_AT][1])
	HomeKit.place(root, "nr_choi", choi_at, 20.0, {}, 60.0)
	for ab: Array in deck:
		var a: Vector3 = ab[0]
		var b: Vector3 = ab[1]
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.6, 0.2, a.distance_to(b) + 1.6)
		var cs := CollisionShape3D.new()
		cs.shape = bs
		cs.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) / 2.0 + Vector3(0, 0.36, 0))
		body.add_child(cs)
	var pv := BoxShape3D.new()
	pv.size = Vector3(3.4, 0.2, 3.4)
	var pcs := CollisionShape3D.new()
	pcs.shape = pv
	pcs.position = choi_at + Vector3(0, 0.36, 0)
	body.add_child(pcs)

	var lotus: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for lp: Array in _home.layout.get("lotus", []):
		var sc := rng.randf_range(0.85, 1.2)
		var yaw := rng.randf() * TAU
		if _line_dist(BOARDWALK, lp[0], lp[1]) < 2.0 or Vector2(lp[0], lp[1]).distance_to(Vector2(choi_at.x, choi_at.z)) < 3.4:
			continue
		lotus.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc, sc)), Vector3(lp[0], -0.05, lp[1])))
	if not lotus.is_empty() and ResourceLoader.exists("res://props/farm/sen_3.glb"):
		var lm := ShaderMaterial.new()
		lm.shader = preload("res://shaders/crop_foliage.gdshader")
		lm.set_shader_parameter("atlas", load("res://props/farm/dong_atlas.png"))
		_home._multimesh_mat(_home._first_mesh("res://props/farm/sen_3.glb"), lotus, lm, 160.0)
