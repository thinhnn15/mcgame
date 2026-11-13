class_name TamCoc
extends RefCounted

const QUAY_X := 140.0
const QUAY_L := 11.0
const QUAY_D := 3.4
const PAVE := 0.45
const QUAY_Y0 := 2.0
const FLIGHTS := [-3.0, 2.6]
const RIDE_CLEAR := 3.2

static func add(home: Node3D) -> void:
	if OS.get_cmdline_user_args().has("--no-tam-coc"):
		return
	var river: Array = home.layout["river"]["points"]
	var g: Callable = home.height_at

	var along := _dir_at(river, QUAY_X)
	var out := Vector2(-along.y, along.x)
	if out.y < 0.0:
		out = -out
	var yaw := rad_to_deg(atan2(-out.x, -out.y))

	var mid := _river_z(river, QUAY_X)
	var back := Vector2(QUAY_X, mid - 12.0)
	for i in 120:
		var p := Vector2(QUAY_X, mid - 12.0 + i * 0.1)
		var hi := -99.0
		for s in range(-5, 6):
			var q := p + along * (s * QUAY_L / 10.0)
			hi = maxf(hi, g.call(q.x, q.y))
		back = p
		if hi <= PAVE + 0.05:
			break
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3(back.x, PAVE, back.y))
	var at := func(lx: float, lz: float) -> Vector2:
		var w: Vector3 = xf * Vector3(lx, 0, lz)
		return Vector2(w.x, w.z)
	_clear_shore(home, at)
	var boxes := [[Vector3(QUAY_L, 0.3, QUAY_D), Vector3(0, QUAY_Y0 - 0.3, -QUAY_D / 2.0)]]
	for fx: float in FLIGHTS:
		boxes.append([Vector3(1.8, 0.2, 1.7), Vector3(fx, QUAY_Y0 - 0.56, -QUAY_D - 0.75), Vector3(-25, 0, 0)])
	home._model("tc_ke", xf.origin - Vector3(0, QUAY_Y0, 0), yaw, boxes)
	for i in 8:
		var c: Vector2 = at.call(-QUAY_L / 2.0 + 0.7 + i * (QUAY_L - 1.4) / 7.0, -QUAY_D / 2.0)
		home._no_grass.append(Vector3(c.x, c.y, 2.0))

	var cs: Vector2 = at.call(-0.2, -1.35)
	var post := Vector3(0.18, 2.0, 0.18)
	home._model("tc_choi", Vector3(cs.x, PAVE, cs.y), yaw + 180.0,
		[[post, Vector3(1.4, 0, 1.0)], [post, Vector3(-1.4, 0, 1.0)], [post, Vector3(1.4, 0, -1.0)],
		[post, Vector3(-1.4, 0, -1.0)], [Vector3(2.5, 0.45, 0.45), Vector3(0, 0, -0.68)]])

	var tied := []
	var b0: Vector2 = at.call(FLIGHTS[1], -QUAY_D - 1.52 - 0.62)
	tied.append([b0, yaw + 90.0])
	for i in 4:
		var row := i / 2
		var bp: Vector2 = at.call(QUAY_L / 2.0 + 3.0 + (i % 2) * 4.6, -0.9 - row * 1.25)
		bp = _to_water(g, bp, out)
		tied.append([bp, yaw + 90.0 + (i % 2) * 180.0 + (row - 0.5) * 6.0])
	var stakes := []
	for t: Array in tied:
		var p: Vector2 = t[0]
		if absf(p.y - _river_z(river, p.x)) < RIDE_CLEAR:
			continue
		var bt: Node3D = home._model("thuyen_nan", Vector3(p.x, -0.05, p.y), t[1], [])
		if bt:
			home._bob.append([bt, bt.position.y, bt.rotation, p.x * 0.13 + p.y * 0.07])
		var sp: Vector2 = p + Vector2.from_angle(deg_to_rad(-float(t[1]))) * 2.5 + out * 0.7
		stakes.append(Transform3D(Basis(), Vector3(sp.x, g.call(sp.x, sp.y), sp.y)))
	home._yard_dress("coc_tre", stakes, 60.0, false)

	var kerb := []
	for s: Array in [[QUAY_L / 2.0 + 0.4, QUAY_L / 2.0 + 10.0], [-QUAY_L / 2.0 - 3.2, -QUAY_L / 2.0 - 0.6]]:
		var x0: float = s[0]
		while x0 < float(s[1]):
			var p: Vector2 = at.call(x0 + 1.0, 0.0)
			var e := _edge(g, p, out)
			kerb.append(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw + 180.0)), Vector3(e.x, g.call(e.x, e.y) - 0.55, e.y)))
			x0 += 2.0
	home._yard_dress("ke_da", kerb, 70.0, false)
	_hyacinth(home, river, g)

static func _hyacinth(home: Node3D, river: Array, g: Callable) -> void:
	"""Water hyacinth in the shallows of both banks, from the landing to the first cave, thinning into the cave."""
	var rng := RandomNumberGenerator.new()
	rng.seed = 140
	var a := []
	var b := []
	var x := 102.0
	while x < 168.0:
		x += rng.randf_range(0.8, 2.6)
		var mid := _river_z(river, x)
		for side: float in [-1.0, 1.0]:
			if rng.randf() < 0.35:
				continue
			var off := rng.randf_range(4.2, 6.8)
			var p := Vector2(x, mid + side * off)
			var h: float = g.call(p.x, p.y)
			if h > -0.25 or h < -1.4 or _near_quay(p):
				continue
			var s := rng.randf_range(0.8, 1.25)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, -0.02, p.y))
			(a if rng.randf() < 0.45 else b).append(xf)
			if rng.randf() < 0.5:
				var q := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.7, 1.2)
				if absf(q.y - mid) > RIDE_CLEAR + 0.6:
					b.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s * 0.7), Vector3(q.x, -0.02, q.y)))
	home._yard_dress("beo_tay_a", a, 70.0, false)
	home._yard_dress("beo_tay_b", b, 60.0, false)

static var _quay_box := Rect2()

static func _near_quay(p: Vector2) -> bool:
	return _quay_box.grow(1.5).has_point(p)

static func _clear_shore(home: Node3D, at: Callable) -> void:
	"""Reeds and stones off the quay, its steps and the boats' water (in memory only)."""
	var c0: Vector2 = at.call(QUAY_L / 2.0 + 13.0, 1.0)
	var c1: Vector2 = at.call(-QUAY_L / 2.0 - 0.5, -QUAY_D - 3.6)
	_quay_box = Rect2(c0, Vector2.ZERO).expand(c1)
	var core0: Vector2 = at.call(-QUAY_L / 2.0, 0.0)
	var core1: Vector2 = at.call(QUAY_L / 2.0, -QUAY_D - 1.6)
	var core := Rect2(core0, Vector2.ZERO).expand(core1)
	var sd: Dictionary = home.layout["dress"].get("shore", {})
	if sd.is_empty():
		return
	var keep := []
	for e: Array in sd["bo"]:
		var p := Vector2(e[0], e[1])
		if core.grow(0.6).has_point(p):
			continue
		if _quay_box.has_point(p) and String(e[2]) not in ["da_bo_a", "da_bo_b"] and p.y > core.end.y - 2.5:
			continue
		keep.append(e)
	sd["bo"] = keep

static func _to_water(g: Callable, p: Vector2, out: Vector2) -> Vector2:
	"""Out from the bank until there is water under a boat (a little deep)."""
	for i in 40:
		if g.call(p.x, p.y) < -0.45:
			return p
		p += out * 0.2
	return p

static func _edge(g: Callable, p: Vector2, out: Vector2) -> Vector2:
	"""Along `out` to where the bank meets the water line."""
	var q := p - out * 3.0
	for i in 60:
		if g.call(q.x, q.y) < 0.08:
			return q
		q += out * 0.1
	return p

static func _river_z(river: Array, x: float) -> float:
	for i in river.size() - 1:
		var a: Array = river[i]
		var b: Array = river[i + 1]
		if (x >= a[0] and x <= b[0]) or (x <= a[0] and x >= b[0]):
			return lerpf(a[1], b[1], (x - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])))
	return 0.0

static func _dir_at(river: Array, x: float) -> Vector2:
	for i in river.size() - 1:
		var a: Array = river[i]
		var b: Array = river[i + 1]
		if x >= minf(a[0], b[0]) and x <= maxf(a[0], b[0]):
			return (Vector2(b[0], b[1]) - Vector2(a[0], a[1])).normalized()
	return Vector2.RIGHT
