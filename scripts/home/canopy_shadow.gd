class_name CanopyShadow
extends RefCounted

const DIR := "res://props/hometown/cay/"
const MAX_PX := 2048
const MIN_M_PER_PX := 0.5

static var _pending := []
static var _queued := false
static var _crown := {}

static func add(kind: String, xfs: Array) -> void:
	_pending.append([kind, xfs])
	if not _queued:
		_queued = true
		bake.call_deferred()

static func off() -> void:
	_pending.clear()
	RenderingServer.global_shader_parameter_set("canopy_on", 0.0)

static func _radius(kind: String) -> Array:
	if _crown.has(kind):
		return _crown[kind]
	var r := 0.0
	var top := 0.0
	var path := DIR + kind + ".glb"
	if ResourceLoader.exists(path):
		var n: Node = (load(path) as PackedScene).instantiate()
		var box := AABB()
		var first := true
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			var b := mi.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		n.free()
		if not first and box.size.y > 2.0:
			r = maxf(box.size.x, box.size.z) * 0.5 * 0.8
			top = box.end.y
	_crown[kind] = [r, top]
	return _crown[kind]

static func bake() -> void:
	_queued = false
	if OS.get_cmdline_user_args().has("--no-canopy") or Quality.chosen() == "low":

		_pending.clear()
		return
	var pts := []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for item: Array in _pending:
		var rt: Array = _radius(item[0])
		var r0: float = rt[0]
		if r0 <= 0.0:
			continue
		for xf: Transform3D in item[1]:
			var sc := xf.basis.get_scale().x
			var r := r0 * sc
			pts.append([xf.origin.x, xf.origin.z, r, xf.origin.y + float(rt[1]) * sc])
			lo = lo.min(Vector2(xf.origin.x - r, xf.origin.z - r))
			hi = hi.max(Vector2(xf.origin.x + r, xf.origin.z + r))
	_pending.clear()
	if pts.is_empty():
		return
	lo -= Vector2(8, 8)
	hi += Vector2(8, 8)
	var m_px := maxf(MIN_M_PER_PX, maxf(hi.x - lo.x, hi.y - lo.y) / MAX_PX)
	var y0 := INF
	var y1 := -INF
	for p: Array in pts:
		y0 = minf(y0, p[3])
		y1 = maxf(y1, p[3])
	var span := maxf(y1 - y0, 1.0)
	var w := int(ceil((hi.x - lo.x) / m_px))
	var h := int(ceil((hi.y - lo.y) / m_px))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	var stamps := {}
	for p: Array in pts:
		var rp := maxi(1, int(round(p[2] / m_px)))
		if not stamps.has(rp):
			stamps[rp] = _stamp(rp)
		var st: Image = stamps[rp]

		var ht := clampf((float(p[3]) - y0) / span, 0.0, 1.0)
		var tinted := _tint(st, ht)
		var at := Vector2i(int((p[0] - lo.x) / m_px) - rp, int((p[1] - lo.y) / m_px) - rp)
		img.blend_rect(tinted, Rect2i(Vector2i.ZERO, st.get_size()), at)
	img.convert(Image.FORMAT_RG8)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	RenderingServer.global_shader_parameter_set("canopy_tex", tex)
	RenderingServer.global_shader_parameter_set("canopy_rect", Vector4(lo.x, lo.y, 1.0 / (w * m_px), 1.0 / (h * m_px)))
	RenderingServer.global_shader_parameter_set("canopy_h", Vector4(y0, span, 0, 0))
	RenderingServer.global_shader_parameter_set("canopy_on", 1.0)
	print("canopy_shadow: %d crowns, %dx%d px at %.2f m" % [pts.size(), w, h, m_px])

static var _tints := {}

static func _tint(st: Image, h: float) -> Image:
	"""The stamp with its G set to h (height steps of 1/32 are plenty; cached)."""
	var key := str(st.get_width()) + ":" + str(int(h * 32.0))
	if _tints.has(key):
		return _tints[key]
	var im := st.duplicate() as Image
	var g := int(h * 32.0) / 32.0
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			im.set_pixel(x, y, Color(1, g, 0, c.a))
	_tints[key] = im
	return im

static func _stamp(rp: int) -> Image:
	"""A crown seen from above: a soft disc, a little uneven at the rim (the gaps between the leaf clumps)."""
	var s := rp * 2 + 1
	var im := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var dx := (x - rp) / float(rp)
			var dy := (y - rp) / float(rp)
			var a := atan2(dy, dx)
			var edge := 0.86 + 0.1 * sin(a * 5.0 + rp) + 0.05 * sin(a * 11.0)
			var d := sqrt(dx * dx + dy * dy)
			var v := clampf((edge - d) / 0.28, 0.0, 1.0)
			im.set_pixel(x, y, Color(1, 1, 1, v * 0.9))
	return im
