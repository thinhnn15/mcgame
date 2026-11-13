class_name FarmYard
extends RefCounted

const YARD := Rect2(-7.6, -11.6, 11.6, 7.4)
const GATE_X := -1.0

const GATE_HALF := 0.88
const FRONT_Z := -4.2
const BACK_Z := -11.0
const HENS := Rect2(3.3, -3.0, 4.1, 4.5)
const POMELO := Vector3(-5.6, 0, -3.4)
const PALMS := [Vector3(-7.05, -7.0, 37.0), Vector3(-6.9, -10.6, 120.0), Vector3(3.45, -8.1, 14.0)]
const KITCHEN := Vector3(-6.0, 0, -9.0)
const CHIMNEY := Vector3(-0.35, 3.4, -0.59)
const SMOKE_HOURS := [[5.5, 8.5], [16.5, 19.5]]

const HEDGES := [[Vector2(-12.6, 4.95), Vector2(-5.7, 4.95)]]

const GROVE := [[-12.2, 0.2, 40.0], [-13.3, 1.6, 200.0], [-11.4, 2.3, 120.0], [-13.0, -1.4, 300.0]]
const NE_POMELO := Vector3(15.3, 0, 3.4)
const NE_HAY := Vector3(15.4, 0, -1.2)
const HAMMOCK := Vector3(-7.2, 0, -2.75)

const FRUIT := [["khe_4", Vector2(-8.8, -8.7), 30.0], ["du_du_4", Vector2(-9.0, -5.9), 200.0], ["du_du_4", Vector2(-9.9, -7.3), 75.0]]

const KE_ARCS := [[52.0, 168.0], [192.0, 222.0]]

static func prepare(s: FarmScenery) -> void:
	s.pads.append([YARD.grow(0.7), 4.0])
	s.earth_rects.append([YARD.grow(-0.25)])
	s.worn_rects.append([YARD.grow(0.3), 0.6])
	s.no_grass.append(YARD.grow(-0.35))
	s.paths.append([[Vector2(GATE_X, FRONT_Z + 0.2), Vector2(GATE_X + 0.1, -2.4)], 0.8])

static func build(farm: Node3D, s: FarmScenery) -> Node3D:
	var root := Node3D.new()
	root.name = "FarmYard"
	farm.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var y := func(x: float, z: float) -> float: return s.height_at(x, z)

	var panels := []
	var posts := []
	var run := func(a: Vector2, b: Vector2, gaps: Array) -> void:

		var length := a.distance_to(b)
		var dir := (b - a) / length
		var yaw := -atan2(dir.y, dir.x)
		var pieces := [[0.0, length]]
		for g: Array in gaps:
			var out := []
			for p: Array in pieces:
				if g[1] <= p[0] or g[0] >= p[1]:
					out.append(p)
					continue
				if g[0] > p[0]:
					out.append([p[0], g[0]])
				if g[1] < p[1]:
					out.append([g[1], p[1]])
			pieces = out
		for p: Array in pieces:
			var seg: float = p[1] - p[0]
			var n := maxi(1, roundi(seg / 1.56))
			var each := seg / n
			for k in n:
				var c: Vector2 = a + dir * (float(p[0]) + each * (k + 0.5))
				var basis := Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-3.0, 3.0)), yaw + deg_to_rad(rng.randf_range(-1.5, 1.5)),
					deg_to_rad(rng.randf_range(-1.5, 1.5)))).scaled_local(Vector3(each / 1.56, 1, 1))
				panels.append(Transform3D(basis, Vector3(c.x, y.call(c.x, c.y), c.y)))
			for e in [p[0], p[1]]:
				var q: Vector2 = a + dir * float(e)
				posts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q.x, y.call(q.x, q.y), q.y)))

			var mid: Vector2 = a + dir * (float(p[0]) + float(p[1])) * 0.5
			var box := BoxShape3D.new()
			box.size = Vector3(seg if absf(dir.x) > 0.5 else 0.16, 1.0, seg if absf(dir.y) > 0.5 else 0.16)
			Props.solid(root, box, Vector3(mid.x, y.call(mid.x, mid.y) + 0.5, mid.y))
	var x0 := YARD.position.x
	var x1 := YARD.end.x
	run.call(Vector2(x0, FRONT_Z), Vector2(x1, FRONT_Z), [[GATE_X - GATE_HALF - x0, GATE_X + GATE_HALF - x0]])
	run.call(Vector2(x0, FRONT_Z), Vector2(x0, BACK_Z), [])
	run.call(Vector2(x1, FRONT_Z), Vector2(x1, BACK_Z), [])

	var h0 := HENS.position
	var h1 := HENS.end
	run.call(Vector2(h0.x, h0.y), Vector2(h1.x, h0.y), [[0.0, 0.95]])
	run.call(Vector2(h1.x, h0.y), Vector2(h1.x, h1.y), [])
	run.call(Vector2(h0.x, h1.y), Vector2(h1.x, h1.y), [[0.0, 2.6]])
	run.call(Vector2(h0.x, h0.y), Vector2(h0.x, h1.y), [[1.45, 2.95]])
	HomeKit._batch(root, "rao_tre", panels)
	HomeKit._batch(root, "coc_tre", posts)

	var gate := HomeKit.place(root, "cong_tre_lon", Vector3(GATE_X, y.call(GATE_X, FRONT_Z), FRONT_Z))
	HomeKit.set_door(gate, "Gate", 0.8)

	var stones := []
	for p in [Vector2(-1.0, -6.5), Vector2(-0.88, -5.72), Vector2(-1.06, -4.95), Vector2(-0.96, -3.45), Vector2(-1.04, -2.7)]:
		stones.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, y.call(p.x, p.y), p.y)))
	HomeKit._batch(root, "da_buoc", stones)

	var palms := []
	for c in PALMS:
		palms.append(Transform3D(Basis(Vector3.UP, deg_to_rad(c.z)), Vector3(c.x, y.call(c.x, c.y), c.y)))
	HomeKit._batch(root, "cay_cau", palms)
	var bananas := []
	for b in [[2.7, -10.4, 318.0], [3.35, -9.4, 217.0], [1.95, -11.0, 152.0]]:
		bananas.append(Transform3D(Basis(Vector3.UP, deg_to_rad(b[2])), Vector3(b[0], y.call(b[0], b[1]), b[1])))
	for g in GROVE:
		bananas.append(Transform3D(Basis(Vector3.UP, deg_to_rad(g[2])), Vector3(g[0], s.height_at(g[0], g[1]), g[1])))
	HomeKit._batch(root, "cay_chuoi", bananas)
	_piece(root, "bep_nha_cu", KITCHEN, 90.0, s, Vector3(2.3, 2.0, 2.6))
	var well := _piece(root, "gieng", Vector3(2.5, 0, -5.95), -90.0, s, Vector3(1.2, 1.0, 1.2))
	well.scale = Vector3.ONE * 0.88
	_batched(root, "dong_rom", [[Vector3(-6.75, 0, -5.3), 20.0], [NE_HAY, -30.0]], s, Vector3(1.2, 1.6, 1.2))
	var line := _piece(root, "day_phoi", Vector3(-5.35, 0, -5.6), 94.0, s, Vector3.ZERO)
	for mi: MeshInstance3D in line.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_batched(root, "cay_buoi", [[POMELO, 40.0], [NE_POMELO, 160.0]], s, Vector3(0.45, 2.0, 0.45))
	for c in PALMS:
		var trunk := CylinderShape3D.new()
		trunk.radius = 0.16
		trunk.height = 2.0
		Props.solid(root, trunk, Vector3(c.x, y.call(c.x, c.y) + 1.0, c.y))
	_hedges(root, s, rng)
	var hm := HAMMOCK
	hm.y = s.height_at(hm.x, hm.z)
	Furniture.place(root, "vong", hm, 0.0, false)
	for dx in [-1.2, 1.2]:
		var post := CylinderShape3D.new()
		post.radius = 0.08
		post.height = 1.3
		Props.solid(root, post, Vector3(HAMMOCK.x + dx, s.height_at(HAMMOCK.x + dx, HAMMOCK.z) + 0.65, HAMMOCK.z))
	_stone_bank(root, s)
	for f: Array in FRUIT:
		var at: Vector2 = f[1]
		var trunk := CylinderShape3D.new()
		trunk.radius = 0.18
		trunk.height = 2.0
		Props.solid(root, trunk, Vector3(at.x, s.height_at(at.x, at.y) + 1.0, at.y))
	var k := KITCHEN
	k.y = s.height_at(k.x, k.z)
	root.add_child(KitchenSmoke.new(k + CHIMNEY))

	for mmi: MultiMeshInstance3D in root.find_children("*", "MultiMeshInstance3D", false, false):
		if String(mmi.name).begins_with("ke_da") or String(mmi.name).begins_with("da_buoc"):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

static func _hedges(root: Node3D, s: FarmScenery, rng: RandomNumberGenerator) -> void:
	var lists := {"cay/hang_rao_dam_but": []}
	var i := 0
	for h: Array in HEDGES:
		var a: Vector2 = h[0]
		var b: Vector2 = h[1]
		var n := maxi(1, roundi(a.distance_to(b) / 2.4))
		var each := a.distance_to(b) / n
		var yaw := -atan2(b.y - a.y, b.x - a.x)
		for k in n:
			var c := a.lerp(b, (k + 0.5) / n)

			var basis := Basis(Vector3.UP, yaw + deg_to_rad(rng.randf_range(-3.0, 3.0))).scaled(
				Vector3((each + 0.45) / 2.6, rng.randf_range(0.68, 0.8), rng.randf_range(0.8, 0.92)))
			var nm := "cay/hang_rao_dam_but"
			if i % 2:
				basis = basis.rotated(Vector3.UP, PI)
			lists[nm].append(Transform3D(basis, Vector3(c.x, s.height_at(c.x, c.y) - 0.04, c.y)))
			i += 1
		var mid := (a + b) * 0.5
		var box := BoxShape3D.new()
		box.size = Vector3(a.distance_to(b), 0.9, 0.8)
		Props.solid(root, box, Vector3(mid.x, s.height_at(mid.x, mid.y) + 0.45, mid.y))
	for nm: String in lists:
		if not lists[nm].is_empty():
			s.batch_into(root, nm, lists[nm])

static func _stone_bank(root: Node3D, s: FarmScenery) -> void:
	var c := FarmScenery.POND_C
	var r := FarmScenery.POND_R * 1.02
	var blocks := []
	for arc: Array in KE_ARCS:
		var a0 := deg_to_rad(arc[0])
		var a1 := deg_to_rad(arc[1])

		var length := 0.0
		var prev := c + Vector2(cos(a0) * r.x, sin(a0) * r.y)
		for k in 65:
			var a := lerpf(a0, a1, k / 64.0)
			var p := c + Vector2(cos(a) * r.x, sin(a) * r.y)
			length += p.distance_to(prev)
			prev = p
		var n := maxi(1, roundi(length / 1.1))
		var pts := []
		for k in n + 1:
			var a := lerpf(a0, a1, k / float(n))
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		for k in n:
			var p0: Vector2 = pts[k]
			var p1: Vector2 = pts[k + 1]
			var mid := (p0 + p1) * 0.5
			var along := p1 - p0
			var yaw := -atan2(along.y, along.x)
			var face := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
			if Vector2(face.x, face.z).dot(c - mid) < 0.0:
				yaw += PI
			var out := mid + (mid - c).normalized() * 0.5
			var top := minf(s.height_at(out.x, out.y), 0.02) + 0.01
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3((along.length() + 0.18) / 2.0, 1.0, 0.75))
			blocks.append(Transform3D(basis, Vector3(mid.x, top - 1.0, mid.y)))
	HomeKit._batch(root, "ke_da", blocks)

	var ends := []
	for arc: Array in KE_ARCS:
		for a_deg in [arc[0], arc[1]]:
			var a := deg_to_rad(a_deg)
			var p := c + Vector2(cos(a) * r.x, sin(a) * r.y) * 1.03
			ends.append(Transform3D(Basis.IDENTITY, Vector3(p.x, minf(s.height_at(p.x, p.y), 0.02) + 0.08 - 1.0, p.y)))
	HomeKit._batch(root, "ke_da_goc", ends)

static func _batched(root: Node3D, name: String, list: Array, s: FarmScenery, solid: Vector3) -> void:
	var xf := []
	for it: Array in list:
		var at: Vector3 = it[0]
		at.y = s.height_at(at.x, at.z)
		xf.append(Transform3D(Basis(Vector3.UP, deg_to_rad(it[1])), at))
		var box := BoxShape3D.new()
		box.size = solid
		Props.solid(root, box, at + Vector3(0, solid.y * 0.5, 0))
	HomeKit._batch(root, name, xf)

static func _piece(root: Node3D, name: String, at: Vector3, yaw: float, s: FarmScenery, solid: Vector3) -> Node3D:
	at.y = s.height_at(at.x, at.z)
	var n := HomeKit.place(root, name, at, yaw)
	if solid != Vector3.ZERO:
		var box := BoxShape3D.new()
		box.size = Vector3(solid.z, solid.y, solid.x) if absf(fmod(absf(yaw), 180.0) - 90.0) < 1.0 else solid
		Props.solid(root, box, at + Vector3(0, solid.y * 0.5, 0))
	return n

static func fruit_trees() -> Array:
	var out := []
	var add := func(kind: String, x: float, z: float, r: float, yaw := 0.0, model := "") -> void:
		out.append({"id": "%s_%d" % [kind, out.size()], "kind": kind, "pos": Vector3(x, 0, z), "r": r, "yaw": yaw,
			"model": model, "seed": out.size() + 1})
	add.call("buoi", POMELO.x, POMELO.z, 1.5)
	add.call("buoi", NE_POMELO.x, NE_POMELO.z, 1.5)
	for b in [[2.7, -10.4], [3.35, -9.4], [1.95, -11.0]] + GROVE:
		add.call("chuoi", b[0], b[1], 1.0)
	for c in PALMS:
		add.call("cau", c.x, c.y, 0.9)
	for f: Array in FRUIT:
		var at: Vector2 = f[1]
		add.call(str(f[0]).trim_suffix("_4"), at.x, at.y, 1.3, float(f[2]), str(f[0]).trim_suffix("_4"))
	return out

static func blockers() -> Array:
	return [[YARD, "PEN_BAD_THING"], [HENS, "PEN_BAD_COOP"]]

class KitchenSmoke extends GPUParticles3D:
	static var _puff: Texture2D

	func _init(at: Vector3) -> void:
		position = at
		amount = 10
		lifetime = 6.0
		preprocess = 6.0
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visibility_range_end = 60.0
		if _puff == null:
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 0.6))
			g.set_color(1, Color(1, 1, 1, 0.0))
			var gt := GradientTexture2D.new()
			gt.gradient = g
			gt.fill = GradientTexture2D.FILL_RADIAL
			gt.fill_from = Vector2(0.5, 0.5)
			gt.fill_to = Vector2(0.5, 0.0)
			gt.width = 64
			gt.height = 64
			_puff = gt
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.08
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 8.0
		pm.initial_velocity_min = 0.28
		pm.initial_velocity_max = 0.4
		pm.gravity = Vector3(0.09, 0.02, 0.04)
		pm.damping_min = 0.03
		pm.damping_max = 0.06
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.25))
		sc.add_point(Vector2(1, 1.0))
		var sct := CurveTexture.new()
		sct.curve = sc
		pm.scale_curve = sct
		pm.scale_min = 0.7
		pm.scale_max = 1.0
		var cr := Gradient.new()
		cr.set_color(0, Color(0.86, 0.86, 0.88, 0.0))
		cr.add_point(0.12, Color(0.86, 0.86, 0.88, 0.6))
		cr.set_color(cr.get_point_count() - 1, Color(0.9, 0.9, 0.92, 0.0))
		var crt := GradientTexture1D.new()
		crt.gradient = cr
		pm.color_ramp = crt
		process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = _puff
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		q.material = m
		draw_pass_1 = q

	func _process(_d: float) -> void:
		if Engine.get_process_frames() % 30 != 0:
			return
		var h := Clock.hour()
		var on := false
		if Clock.weather == "":
			for r: Array in SMOKE_HOURS:
				if h >= r[0] and h < r[1]:
					on = true
		emitting = on
