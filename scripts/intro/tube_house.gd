extends RefCounted

const CityKit := preload("res://scripts/intro/city_kit.gd")
const Batch := preload("res://scripts/intro/batch.gd")
const FACADE := preload("res://shaders/intro_facade.gdshader")
const ATLAS := "res://props/furniture/tube_house_atlas.json"

const GH := 3.8
const SH := 3.3
const DEPTH := 12.0
const WALLS := [Color("e8b94f"), Color("e0c48e"), Color("a8cc84"), Color("e8977a"), Color("8fb4de"),
	Color("c9a6dc"), Color("eedcb8"), Color("d99a5e")]
const LOUVRES := [Color("6f9e7c"), Color("7193b4"), Color("9c7a60"), Color("8fb6a8")]
const RAILS := [Color("3d4450"), Color("f0ebe2"), Color("4a5a52"), Color("6a4a3c")]
const SIGN_LIT := 0.85

var kit: CityKit
var b: Batch
var rng: RandomNumberGenerator
var walk_y: float
var mat: ShaderMaterial
var sign_mat: ShaderMaterial
var win_dark: Material
var win_warm: Material
var win_cool: Material
var meta: Dictionary
var _shop := 0

var detail_range := Vector2.ZERO
var _drng := RandomNumberGenerator.new()

func setup(k: CityKit, r: RandomNumberGenerator, y: float) -> void:
	_drng.seed = 4242
	kit = k
	rng = r
	walk_y = y
	b = Batch.new()
	meta = b.load_atlas(ATLAS)
	mat = _material("res://props/furniture/tube_house_alb.png")
	sign_mat = _material(Lang.path_for("res://props/furniture/signs", "street_signs_alb.png"))
	win_dark = kit.windows({"lit_rate": 0.0, "seed": 3.0, "glass_top": Color("2a2d4c"), "glass_bottom": Color("12131f")})
	win_warm = kit.windows({"lit_rate": 1.0, "cool_rate": 0.0, "seed": 3.0, "lit_energy": 0.9, "cell": Vector2(1.0, 3.3)})
	win_cool = kit.windows({"lit_rate": 1.0, "cool_rate": 1.0, "seed": 4.0, "lit_energy": 0.8, "cell": Vector2(1.0, 3.3)})

func _material(tex: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FACADE
	m.set_shader_parameter("albedo_tex", load(tex))
	return kit.register(m)

func _f(n: String, s := Rect2(0, 0, 1, 1)) -> Rect2:
	return b.uv("facade", n, s)

func house(h: Dictionary) -> void:
	var w: float = h["w"]
	var floors: int = h["floors"]
	var xf := Transform3D(Basis(Vector3.UP, 0.0 if h["facing"] > 0 else PI), Vector3(h["x0"] + w / 2.0, walk_y, h["z"]))
	var c: Color = WALLS[rng.randi() % WALLS.size()]
	var top := GH + (floors - 1) * SH
	var z := -rng.randf_range(0.0, 0.3)
	var at := xf.origin
	_body(xf, w, z, top, c, h, at)
	match h["kind"]:
		"cafe":
			_cafe(xf, w, z, c, at)
		"mart":
			_mart(xf, w, z, c, at)
		_:
			_shopfront(xf, w, z, c, at)
	var variant := rng.randi() % 4
	for k in range(1, floors):
		_storey(xf, w, z, GH + (k - 1) * SH, c, variant, at)
	_roof(xf, w, z, top, c, at)
	if detail_range.y > detail_range.x and at.x > detail_range.x and at.x < detail_range.y:
		_detail(xf, w, z, top, floors, c, at)

func _q(xf: Transform3D, centre: Vector3, size: Vector2, r: Rect2, col: Color, glow := 0.0, two := false, rot := Basis(), m: Material = null) -> void:
	b.quad(m if m else mat, xf * Transform3D(rot, centre), size, r, col, glow, two)

const FACE_X := Basis(Vector3.UP, PI / 2.0)
const FACE_NX := Basis(Vector3.UP, -PI / 2.0)
const FACE_UP := Basis(Vector3.RIGHT, -PI / 2.0)
const FACE_DOWN := Basis(Vector3.RIGHT, PI / 2.0)
const FACE_BACK := Basis(Vector3.UP, PI)

func _body(xf: Transform3D, w: float, z: float, top: float, c: Color, h: Dictionary, at: Vector3) -> void:
	var sc := c.darkened(0.12)
	for side in [-1, 1]:
		var nh: float = h["left_h"] if side < 0 else h["right_h"]
		var rot := FACE_NX if side < 0 else FACE_X
		if top > nh + 0.01:
			var y0 := maxf(nh, 0.0)
			var hh := top - y0

			var r := _f("side", Rect2(0, 1.0 - hh / 16.0, 1, hh / 16.0)) if hh < 16.0 else _f("side")
			var ctr := Vector3(side * w / 2.0, y0 + hh / 2.0, z - DEPTH / 2.0)
			_q(xf, ctr, Vector2(DEPTH, hh), r, sc, 0.0, false, rot)
		if nh > 0.0:
			var hh2 := minf(nh, top)
			_q(xf, Vector3(side * w / 2.0, hh2 / 2.0, z - 0.175), Vector2(0.35, hh2), _f("side", Rect2(0, 0.5, 0.03, 0.5)), sc, 0.0, false, rot)
	_q(xf, Vector3(0, top / 2.0, z - DEPTH), Vector2(w, top), _f("back", Rect2(0, maxf(0.0, 1.0 - top / 16.0), 1, minf(1.0, top / 16.0))), c.darkened(0.2), 0.0, false, FACE_BACK)
	_q(xf, Vector3(0, top, z - DEPTH / 2.0 - 0.1), Vector2(w, DEPTH - 0.2), _f("roof"), Color(0.92, 0.92, 0.95), 0.0, false, FACE_UP)

func _shopfront(xf: Transform3D, w: float, z: float, c: Color, at: Vector3) -> void:
	var pk := rng.randi() % 3
	for sx in [-1, 1]:
		var r := _f("pilaster_%d_plate" % pk if sx < 0 else "pilaster_%d" % pk)
		var px: float = sx * (w / 2.0 - 0.15)
		var faces := {"front": r, "top": _f("concrete")}
		faces["right" if sx < 0 else "left"] = Rect2(r.position, Vector2(r.size.x * 0.45, r.size.y))
		b.box(mat, xf * Transform3D(Basis(), Vector3(px, GH / 2.0, z + 0.07)), Vector3(0.3, GH, 0.14), faces, Color.WHITE)
	var sw := w - 0.6
	var shut := rng.randi() % 4
	_q(xf, Vector3(0, 1.375, z + 0.005), Vector2(sw, 2.75), _f("shutter_%d" % shut), Color.WHITE)
	b.box(mat, xf * Transform3D(Basis(), Vector3(0, 2.9, z + 0.15)), Vector3(sw + 0.02, 0.3, 0.3),
		{"front": _f("housing"), "bottom": _f("housing", Rect2(0, 0.6, 1, 0.4)), "top": _f("housing", Rect2(0, 0, 1, 0.3))}, Color.WHITE)
	_q(xf, Vector3(0, 2.7 + (GH - 2.7) / 2.0, z), Vector2(sw, GH - 2.7), _f("ground_wall"), c)
	var lit := rng.randf() < 0.3
	var idx := _shop % 18
	_shop += 1
	_sign(xf, w, z, idx, lit, GH - 0.38)
	if lit:
		var p := xf * Vector3(0, 3.0, z + 1.2)
		if absf(p.x) < 40.0 and kit.src_pos.size() < 36:
			kit.add_source(p, 4.0, _sign_color(idx).lerp(Color.WHITE, 0.4), 0.6)

const SIGN_COLS := ["d94a3d", "2f6fb7", "e8b33a", "3f9a6a", "2f9a5a", "c0437a", "2f6fb7", "c0437a", "3f9a6a",
	"2f6fb7", "e05a8a", "e8b33a", "d94a3d", "e8b33a", "3f9a6a", "2f6fb7", "d94a3d", "c0437a", "2f5d50", "2fae6a"]

func _sign_color(i: int) -> Color:
	return Color(SIGN_COLS[i])

func _sign(xf: Transform3D, w: float, z: float, idx: int, lit: bool, y: float, bw := -1.0, bh := 0.85) -> void:
	bw = w - 0.2 if bw < 0.0 else bw
	var sx := xf * Transform3D(Basis(), Vector3(0, y, z + 0.3))
	b.box(mat, sx, Vector3(bw, bh, 0.12), {"top": _f("metal"), "bottom": _f("metal"), "left": _f("metal"), "right": _f("metal")}, Color.WHITE)
	b.quad(sign_mat, sx * Transform3D(Basis(), Vector3(0, 0, 0.061)), Vector2(bw, bh), b.uv("signs", "sign_%d" % idx), Color.WHITE,
		SIGN_LIT if lit else 0.0)

func _storey(xf: Transform3D, w: float, z: float, y0: float, c: Color, variant: int, at: Vector3) -> void:
	var st: Dictionary = meta["storey"]
	var pw: float = st["w"]
	var ph: float = st["h"]
	var fr: float = st["frame"]
	var oy0: float = st["open_y0"]
	var oh: float = st["open_h"]
	var dw: float = 1.7 if w >= 4.2 else 1.4
	var xi := dw / 2.0 + fr

	var pow_: float = st["open_w"]
	var ui0 := (pw / 2.0 - pow_ / 2.0 - fr) / pw
	var uo0 := (pw / 2.0 - pow_ / 2.0) / pw
	var vt := (ph - oy0 - oh) / ph
	var vb := (ph - oy0) / ph
	var pn := "storey_%d" % variant
	var wall := [
		[-w / 2.0, -xi, 0.0, ph, 0.0, ui0, 0.0, 1.0],
		[xi, w / 2.0, 0.0, ph, 1.0 - ui0, 1.0, 0.0, 1.0],
		[-xi, xi, oy0 + oh, ph, ui0, 1.0 - ui0, 0.0, vt],
		[-xi, xi, 0.0, oy0, ui0, 1.0 - ui0, vb, 1.0],
		[-xi, -dw / 2.0, oy0, oy0 + oh, ui0, uo0, vt, vb],
		[dw / 2.0, xi, oy0, oy0 + oh, 1.0 - uo0, 1.0 - ui0, vt, vb]]
	for p in wall:
		var cx: float = (p[0] + p[1]) / 2.0
		var cy: float = y0 + (p[2] + p[3]) / 2.0
		_q(xf, Vector3(cx, cy, z), Vector2(p[1] - p[0], p[3] - p[2]), _f(pn, Rect2(p[4], p[6], p[5] - p[4], p[7] - p[6])), c)

	var d := 0.16
	var rc := c.lightened(0.25)
	var oc := Vector3(0, y0 + oy0 + oh / 2.0, z - d / 2.0)
	_q(xf, oc + Vector3(-dw / 2.0, 0, 0), Vector2(d, oh), _f("white"), rc.darkened(0.15), 0.0, false, FACE_X)
	_q(xf, oc + Vector3(dw / 2.0, 0, 0), Vector2(d, oh), _f("white"), rc.darkened(0.15), 0.0, false, FACE_NX)
	_q(xf, oc + Vector3(0, oh / 2.0, 0), Vector2(dw, d), _f("white"), rc.darkened(0.3), 0.0, false, FACE_DOWN)
	_q(xf, oc + Vector3(0, -oh / 2.0, 0), Vector2(dw, d), _f("white"), rc, 0.0, false, FACE_UP)
	var r := rng.randf()
	var win := win_dark
	if r < 0.2:
		win = win_warm
	elif r < 0.25:
		win = win_cool
	b.quad(win, xf * Transform3D(Basis(), oc + Vector3(0, 0, -d / 2.0)), Vector2(dw, oh), Rect2(0, 0, 1, 1), Color.WHITE)

	if rng.randf() < 0.55 and w > 3.8:
		var lc: Color = LOUVRES[rng.randi() % LOUVRES.size()]
		for sx in [-1, 1]:
			var lr := _f("louvre")
			if sx > 0:
				lr = Rect2(lr.end.x, lr.position.y, -lr.size.x, lr.size.y)
			_q(xf, Vector3(sx * (dw * 0.75 + 0.06), y0 + oy0 + oh / 2.0, z + 0.03), Vector2(dw / 2.0, oh), lr, lc)

	var kind := rng.randf()
	var railc: Color = RAILS[rng.randi() % RAILS.size()]
	if kind < 0.72:
		_balcony(xf, w, z, y0, c, railc)
	elif kind < 0.86:
		_cage(xf, dw, z, y0 + oy0, oh, railc)

	if rng.randf() < 0.6:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var ax := side * (w / 2.0 - 0.6)
		if absf(ax) > dw / 2.0 + 0.45:
			_ac(xf, Vector3(ax, y0 + 2.35, z + 0.16))

func _balcony(xf: Transform3D, w: float, z: float, y0: float, c: Color, railc: Color) -> void:
	var bw := w - 0.3
	var bd := 0.9
	var ctr := Vector3(0, y0 + 0.07, z + bd / 2.0)
	var e := _f("slab_edge")
	var bot := _f("slab_bottom")
	b.box(mat, xf * Transform3D(Basis(), ctr), Vector3(bw, 0.14, bd),
		{"front": e, "left": Rect2(e.position, Vector2(e.size.x * bd / 4.6, e.size.y)), "right": Rect2(e.position, Vector2(e.size.x * bd / 4.6, e.size.y)),
		"top": _f("slab_top"), "bottom": Rect2(bot.position.x, bot.end.y, bot.size.x, -bot.size.y)}, c.lightened(0.3))

	var lip := xf * Vector3(0, y0, z + bd)
	if absf(lip.x) < 48.0:
		kit.drip_edge(xf * Vector3(-bw / 2.0, y0, z + bd + 0.01), xf * Vector3(bw / 2.0, y0, z + bd + 0.01), 0.35)
	var rk := rng.randi() % 3
	var rr := _f("rail_%d" % rk)
	var rcol := railc if rk != 1 else Color.WHITE
	if rk == 2:
		rcol = c.lightened(0.35)
	var ry := y0 + 0.14 + 0.525
	_q(xf, Vector3(0, ry, z + bd - 0.03), Vector2(bw, 1.05), rr, rcol, 0.0, true)
	var side_r := Rect2(rr.position, Vector2(rr.size.x * (bd - 0.03) / 4.6, rr.size.y))
	for sx in [-1, 1]:
		_q(xf, Vector3(sx * bw / 2.0, ry, z + (bd - 0.03) / 2.0), Vector2(bd - 0.03, 1.05), side_r, rcol, 0.0, true, FACE_X)
	var roll := rng.randf()
	if roll < 0.55:
		_q(xf, Vector3(0, y0 + 0.14 + 0.65, z + bd - 0.3), Vector2(bw - 0.2, 1.3), _f("plants_%d" % (rng.randi() % 3)), Color.WHITE)
	if roll > 0.35 and roll < 0.7:
		_q(xf, Vector3(0, y0 + 2.45 - 0.65, z + bd - 0.5), Vector2(bw - 0.3, 1.3), _f("laundry_%d" % (rng.randi() % 2)), Color.WHITE, 0.0, true)

func _cage(xf: Transform3D, dw: float, z: float, y: float, oh: float, railc: Color) -> void:
	var cw := dw + 0.5
	var ch := oh + 0.3
	var cd := 0.5
	var r := _f("cage")
	var ctr := Vector3(0, y + oh / 2.0, z + cd)
	_q(xf, ctr, Vector2(cw, ch), r, railc, 0.0, true)
	for sx in [-1, 1]:
		_q(xf, Vector3(sx * cw / 2.0, ctr.y, z + cd / 2.0), Vector2(cd, ch), Rect2(r.position, Vector2(r.size.x * cd / 2.2, r.size.y)), railc, 0.0, true, FACE_X)
	_q(xf, Vector3(0, ctr.y + ch / 2.0, z + cd / 2.0), Vector2(cw, cd), _f("metal"), railc.darkened(0.2), 0.0, true, FACE_UP)

func _ac(xf: Transform3D, p: Vector3) -> void:
	var s := _f("ac_side")
	var t := _f("ac_top")
	b.box(mat, xf * Transform3D(Basis(), p), Vector3(0.8, 0.55, 0.3),
		{"front": _f("ac_front"), "left": s, "right": s, "top": t, "bottom": t}, Color.WHITE)
	for sx in [-0.3, 0.3]:
		b.box(mat, xf * Transform3D(Basis(), p + Vector3(sx, -0.3, -0.02)), Vector3(0.04, 0.04, 0.34),
			{"front": _f("metal"), "left": _f("metal"), "right": _f("metal"), "top": _f("metal")}, Color.WHITE)

func _roof(xf: Transform3D, w: float, z: float, top: float, c: Color, at: Vector3) -> void:
	var pc := c.darkened(0.04)
	var pr := _f("parapet")
	b.box(mat, xf * Transform3D(Basis(), Vector3(0, top + 0.35, z - 0.12)), Vector3(w, 0.7, 0.24),
		{"front": pr, "back": pr, "top": _f("coping")}, pc)
	if rng.randf() < 0.65:
		var tx := rng.randf_range(-w / 2.0 + 0.9, w / 2.0 - 0.9)
		var tz := z - rng.randf_range(1.5, 4.0)
		var m := _f("metal")
		b.box(mat, xf * Transform3D(Basis(), Vector3(tx, top + 0.25, tz)), Vector3(1.4, 0.5, 0.8),
			{"front": m, "back": m, "left": m, "right": m, "top": m}, Color(0.85, 0.85, 0.88))
		b.cyl(mat, xf * Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(tx, top + 1.0, tz)), 0.5, 1.7, 12,
			_f("tank"), _f("tank_cap"), Color.WHITE)
	if rng.randf() < 0.4:
		var rw := minf(w - 0.6, 3.0)
		var ac: Color = WALLS[rng.randi() % WALLS.size()]
		var sd := _f("side", Rect2(0, 0.6, 0.3, 0.4))
		b.box(mat, xf * Transform3D(Basis(), Vector3(0, top + 1.15, z - 6.5)), Vector3(rw, 2.3, 3.0),
			{"front": _f("attic"), "left": sd, "right": sd, "back": sd, "top": _f("roof")}, ac.darkened(0.08))
	if rng.randf() < 0.45:
		var ax := rng.randf_range(-w / 2.0 + 0.4, w / 2.0 - 0.4)
		var m := _f("metal")
		var f4 := {"front": m, "back": m, "left": m, "right": m}
		b.box(mat, xf * Transform3D(Basis(), Vector3(ax, top + 1.9, z - 1.0)), Vector3(0.05, 2.4, 0.05), f4, Color(0.8, 0.8, 0.85))
		for i in 3:
			b.box(mat, xf * Transform3D(Basis(), Vector3(ax, top + 2.4 + i * 0.35, z - 1.0)), Vector3(0.9 - i * 0.2, 0.03, 0.03),
				{"front": m, "back": m, "top": m}, Color(0.8, 0.8, 0.85))

func _detail(xf: Transform3D, w: float, z: float, top: float, floors: int, c: Color, at: Vector3) -> void:
	var lc := c.lightened(0.18)
	var conc := _f("concrete")
	for k in range(1, floors):
		b.box(mat, xf * Transform3D(Basis(), Vector3(0, GH + (k - 1) * SH, z + 0.1)), Vector3(w - 0.04, 0.12, 0.2),
			{"front": conc, "top": _f("coping"), "bottom": conc}, lc)
	b.box(mat, xf * Transform3D(Basis(), Vector3(0, top - 0.1, z + 0.14)), Vector3(w, 0.22, 0.3),
		{"front": conc, "bottom": conc, "left": conc, "right": conc}, lc)
	var pr := _f("parapet")
	var pc := c.darkened(0.04)
	for side in [-1, 1]:
		b.box(mat, xf * Transform3D(Basis(), Vector3(side * (w / 2.0 - 0.1), top + 0.35, z - DEPTH / 2.0 - 0.12)),
			Vector3(0.2, 0.7, DEPTH - 0.24), {"left": pr, "right": pr, "top": _f("coping")}, pc)
	b.box(mat, xf * Transform3D(Basis(), Vector3(0, top + 0.35, z - DEPTH + 0.1)), Vector3(w, 0.7, 0.2),
		{"front": pr, "back": pr, "top": _f("coping")}, pc)
	var m := _f("metal")
	if _drng.randf() < 0.6:
		var ton: Color = [Color("5a7fa8"), Color("b5523e"), Color("9aa0a8"), Color("6f9e7c")][_drng.randi() % 4]
		var lw := minf(w - 0.6, 3.6)
		var z0 := z - DEPTH + 0.4
		var z1 := z0 + 3.0
		var hb := 2.0
		var hf := 2.5
		for px in [-lw / 2.0 + 0.1, lw / 2.0 - 0.1]:
			for pz in [z0 + 0.1, z1 - 0.1]:
				var ph := hb if pz < z0 + 1.0 else hf
				b.box(mat, xf * Transform3D(Basis(), Vector3(px, top + ph / 2.0, pz)), Vector3(0.07, ph, 0.07),
					{"front": m, "back": m, "left": m, "right": m}, Color(0.55, 0.55, 0.6))
		var p0 := xf * Vector3(-lw / 2.0 - 0.15, top + hb, z0 - 0.2)
		var p1 := xf * Vector3(lw / 2.0 + 0.15, top + hb, z0 - 0.2)
		var p2 := xf * Vector3(lw / 2.0 + 0.15, top + hf, z1 + 0.25)
		var p3 := xf * Vector3(-lw / 2.0 - 0.15, top + hf, z1 + 0.25)
		b.quad4(mat, p0, p1, p2, p3, m, ton, 0.0, true)
	if _drng.randf() < 0.45:
		var lz := z - 4.6
		var hx := w / 2.0 - 0.5
		for px in [-hx, hx]:
			b.box(mat, xf * Transform3D(Basis(), Vector3(px, top + 0.8, lz)), Vector3(0.05, 1.6, 0.05),
				{"front": m, "back": m, "left": m, "right": m}, Color(0.6, 0.6, 0.64))
		b.box(mat, xf * Transform3D(Basis(), Vector3(0, top + 1.58, lz)), Vector3(2.0 * hx, 0.02, 0.02), {"front": m, "top": m}, Color(0.7, 0.7, 0.72))
		var n := 2 + _drng.randi() % 3
		for i in n:
			var cx := -hx + 0.5 + (2.0 * hx - 1.0) * (i + 0.5) / n
			var cloth: Color = [Color("ff9fb8"), Color("7fd3e6"), Color("ffe17a"), Color("ffffff"), Color("a8e6a1")][_drng.randi() % 5]
			b.quad(mat, xf * Transform3D(Basis(), Vector3(cx, top + 1.22, lz)), Vector2(0.5, 0.7), _f("white"), cloth, 0.0, true)
	for i in _drng.randi() % 4:
		var px := _drng.randf_range(-w / 2.0 + 0.5, w / 2.0 - 0.5)
		var wh := _f("white")
		b.box(mat, xf * Transform3D(Basis(), Vector3(px, top + 0.2, z - 0.5)), Vector3(0.36, 0.4, 0.36),
			{"front": wh, "back": wh, "left": wh, "right": wh}, Color("b5523e"))
		b.box(mat, xf * Transform3D(Basis(), Vector3(px, top + 0.62, z - 0.5)), Vector3(0.5, 0.45, 0.5),
			{"front": wh, "back": wh, "left": wh, "right": wh, "top": wh}, Color("5f9a4a"))

func _interior(xf: Transform3D, w: float, z: float, h: float, d: float, prefix: String, glow: float) -> void:
	var iw := w - 0.4
	_q(xf, Vector3(0, h / 2.0, z - d), Vector2(iw, h), _f(prefix + "_back"), Color.WHITE, glow)
	var sr := _f(prefix + "_side")
	_q(xf, Vector3(-iw / 2.0, h / 2.0, z - d / 2.0), Vector2(d, h), sr, Color.WHITE, glow * 0.9, false, FACE_X)
	_q(xf, Vector3(iw / 2.0, h / 2.0, z - d / 2.0), Vector2(d, h), Rect2(sr.end.x, sr.position.y, -sr.size.x, sr.size.y), Color.WHITE, glow * 0.9, false, FACE_NX)
	_q(xf, Vector3(0, 0.01, z - d / 2.0), Vector2(iw, d), _f(prefix + "_floor"), Color.WHITE, glow * 0.7, false, FACE_UP)
	_q(xf, Vector3(0, h, z - d / 2.0), Vector2(iw, d), _f(prefix + "_ceiling"), Color.WHITE, glow, false, FACE_DOWN)

func _pilasters(xf: Transform3D, w: float, z: float, col: Color) -> void:
	for sx in [-1, 1]:
		var faces := {"front": _f("white"), "top": _f("white")}
		faces["right" if sx < 0 else "left"] = _f("white")
		b.box(mat, xf * Transform3D(Basis(), Vector3(sx * (w / 2.0 - 0.15), GH / 2.0, z + 0.08)), Vector3(0.3, GH, 0.16), faces, col)

func _cafe(xf: Transform3D, w: float, z: float, c: Color, at: Vector3) -> void:
	var ih := GH - 0.4
	_interior(xf, w, z, ih, 3.0, "cafe", 0.85)
	_pilasters(xf, w, z, Color("7a543c"))
	_q(xf, Vector3(0, ih + (GH - ih) / 2.0, z), Vector2(w - 0.6, GH - ih), _f("ground_wall"), c)
	var cr := _f("counter")
	b.box(mat, xf * Transform3D(Basis(), Vector3(-0.6, 0.5, z - 2.2)), Vector3(2.2, 1.0, 0.6),
		{"front": cr, "left": cr, "right": cr, "top": _f("counter", Rect2(0, 0, 1, 0.08))}, Color.WHITE, 0.55)

	var aw := w + 0.2
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-90.0 + 18.0))
	_q(xf, Vector3(0, GH - 0.2, z + 0.8), Vector2(aw, 1.7), _f("awning"), Color.WHITE, 0.0, true, tilt)
	_q(xf, Vector3(0, GH - 0.2 - 0.26 - 0.12, z + 1.61), Vector2(aw, 0.25), _f("valance"), Color.WHITE, 0.0, true)

	kit.drip_edge(xf * Vector3(-aw / 2.0, GH - 0.2 - 0.26 - 0.25, z + 1.62), xf * Vector3(aw / 2.0, GH - 0.2 - 0.26 - 0.25, z + 1.62), 0.12)
	for i in 50:
		var u := rng.randf_range(-0.5, 0.5) * aw
		var v := rng.randf()
		kit.hit_pts.append(xf * Vector3(u, GH - 0.2 + 0.26 - v * 0.52 + 0.02, z + 0.8 - 0.81 + v * 1.62))
	_sign(xf, w, z, 18, true, GH + 0.4, w - 0.4, 0.8)

	for i in 9:
		var bx := -aw / 2.0 + 0.2 + i * (aw - 0.4) / 8.0
		var sag := 0.12 * sin(PI * float(i % 4) / 4.0)
		var p := Vector3(bx, GH - 0.78 - sag, z + 1.6)
		kit.part(Props._sph(0.06), kit.glow(Color("ffd890"), 3.0), xf * p)
		kit.halo(xf * p, 0.5, Color("ffc070"), 0.35)
	kit.add_source(xf * Vector3(0, 2.2, z + 1.5), 7.0, Color("ffb070"), 1.5)
	kit.add_source(xf * Vector3(0, 1.6, z - 1.5), 4.5, Color("ffc890"), 0.8)

	var f := Node3D.new()
	f.transform = xf
	kit.root.add_child(f)
	var seats := [[-1.4, 1.0, ""], [-0.9, 1.6, "plastic_stool_blue"], [-1.9, 1.55, ""], [0.9, 1.1, "plastic_stool_blue"],
		[1.5, 1.6, ""], [0.4, 1.75, ""], [1.9, 0.9, "plastic_stool_blue"]]
	for s in seats:
		kit.place("plastic_stool", Vector3(s[0], 0.0, z + s[1]), rng.randf_range(0, 90), 1.25, s[2], f)
	for t in [Vector3(-1.4, 0, z + 1.35), Vector3(1.2, 0, z + 1.4)]:
		var m := _f("metal_lt")
		b.box(mat, xf * Transform3D(Basis(), t + Vector3(0, 0.42, 0)), Vector3(0.55, 0.04, 0.55), {"front": m, "back": m, "left": m, "right": m, "top": _f("white")}, Color("e2dccd"))
		b.box(mat, xf * Transform3D(Basis(), t + Vector3(0, 0.2, 0)), Vector3(0.05, 0.4, 0.05), {"front": m, "back": m, "left": m, "right": m}, Color.WHITE)
		b.cyl(mat, xf * Transform3D(Basis(), t + Vector3(0.1, 0.485, 0.05)), 0.04, 0.09, 8, _f("white"), _f("white"), Color("f0e8da"))

func _mart(xf: Transform3D, w: float, z: float, c: Color, at: Vector3) -> void:
	var ih := GH - 0.5
	_interior(xf, w, z, ih, 4.0, "mart", 0.8)

	for row in 2:
		var sz := z - 1.4 - row * 1.4
		var sf := _f("shelf_front")
		b.box(mat, xf * Transform3D(Basis(), Vector3(0, 0.8, sz)), Vector3(w - 1.4, 1.6, 0.4),
			{"front": sf, "back": sf, "top": _f("white"), "left": _f("white"), "right": _f("white")}, Color.WHITE, 0.7)
	_pilasters(xf, w, z, Color("e9eef0"))
	b.box(mat, xf * Transform3D(Basis(), Vector3(0, (GH - 0.9) / 2.0, z + 0.04)), Vector3(0.08, GH - 0.9, 0.08),
		{"front": _f("white"), "left": _f("white"), "right": _f("white")}, Color("cfd6da"))
	_sign(xf, w, z, 19, true, GH - 0.45, w, 0.9)
	b.box(mat, xf * Transform3D(Basis(), Vector3(0, GH - 0.95, z + 0.3)), Vector3(w, 0.12, 0.14),
		{"front": _f("white"), "bottom": _f("white")}, Color("f2fff6"), 0.9)
	kit.add_source(xf * Vector3(0, 2.0, z + 1.6), 7.0, Color("d8f2ff"), 1.3)

	var gw := w - 0.6
	var gh := GH - 1.0
	var q := MeshInstance3D.new()
	q.mesh = kit.quad_mesh(Vector2(gw, gh))
	var gm := ShaderMaterial.new()
	gm.shader = preload("res://shaders/intro_glass.gdshader")
	gm.set_shader_parameter("pane", Vector2(gw, gh))
	gm.set_shader_parameter("tint", Color(0.7, 0.85, 0.95, 0.1))
	q.material_override = gm
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.transform = xf * Transform3D(Basis(), Vector3(0, 0.05 + gh / 2.0, z + 0.03))
	kit.root.add_child(q)
	var fr := Color("e6ecee")
	for fx in [-gw / 2.0, -0.55, 0.55, gw / 2.0]:
		kit.box(Vector3(0.06, gh, 0.07), fr, xf * Vector3(fx, 0.05 + gh / 2.0, z + 0.03), Vector3(0, rad_to_deg(xf.basis.get_euler().y), 0))
	kit.box(Vector3(gw, 0.07, 0.08), fr, xf * Vector3(0, 0.05 + gh, z + 0.03), Vector3(0, rad_to_deg(xf.basis.get_euler().y), 0))
	kit.box(Vector3(gw, 0.1, 0.1), Color("9aa4aa"), xf * Vector3(0, 0.05, z + 0.03), Vector3(0, rad_to_deg(xf.basis.get_euler().y), 0))
	kit.box(Vector3(0.025, 0.4, 0.03), Color("c9d2d6"), xf * Vector3(-0.1, 1.05, z + 0.09), Vector3(0, rad_to_deg(xf.basis.get_euler().y), 0))
	kit.box(Vector3(0.025, 0.4, 0.03), Color("c9d2d6"), xf * Vector3(0.1, 1.05, z + 0.09), Vector3(0, rad_to_deg(xf.basis.get_euler().y), 0))

func commit() -> int:
	return b.commit(kit.root)
