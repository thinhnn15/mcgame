class_name EmoteFx
extends Node3D

const FX_DIR := "res://characters/fx/"
const SIZE := 0.0011

var chibi: Chibi
var top := Node3D.new()
var face := Node3D.new()
var _live := 0
var _head := -1

static func play(c: Chibi, kind: String, delay := 0.0) -> void:
	if kind == "":
		return
	var fx := EmoteFx.new()
	fx.chibi = c
	c.add_child(fx)
	fx._start(kind, delay)

func _ready() -> void:
	top_level = true
	add_child(top)
	add_child(face)
	_follow()

func _process(_d: float) -> void:
	_follow()

func _follow() -> void:
	if chibi == null or chibi.skel == null:
		return
	if _head < 0:
		_head = chibi.skel.find_bone("Head")
	var sk := chibi.skel
	var hp := sk.global_transform * sk.get_bone_global_pose(_head)
	var up := hp.basis.y.normalized()
	var b := chibi.global_transform.basis.orthonormalized()
	top.global_transform = Transform3D(b, hp.origin + up * 0.74)
	face.global_transform = Transform3D(b, hp.origin + up * 0.3 + b.z * 0.31)

func _sprite(tex: String, parent: Node3D, pos: Vector3, scale_ := 1.0) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load(FX_DIR + tex + ".png")
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.pixel_size = SIZE
	s.shaded = false
	s.no_depth_test = true
	s.render_priority = 20
	s.position = pos
	s.scale = Vector3.ONE * 0.001
	s.modulate.a = 0.0
	s.set_meta("size", scale_)
	parent.add_child(s)
	_live += 1
	s.tree_exited.connect(func():
		_live -= 1
		if _live <= 0 and is_inside_tree():
			queue_free())
	return s

func _pop(s: Sprite3D, at: float, hold: float, fade := 0.3) -> Tween:
	var k: float = s.get_meta("size")
	var t := create_tween()
	t.tween_interval(at)
	t.tween_property(s, "modulate:a", 1.0, 0.06)
	t.parallel().tween_property(s, "scale", Vector3.ONE * k * 1.25, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "scale", Vector3.ONE * k, 0.1)
	t.tween_interval(hold)
	t.tween_property(s, "modulate:a", 0.0, fade)
	t.tween_callback(s.queue_free)
	return t

func _rise(s: Sprite3D, at: float, life: float, move: Vector3, sway := 0.0) -> void:
	var k: float = s.get_meta("size")
	var p0 := s.position
	var t := create_tween()
	t.tween_interval(at)
	t.tween_property(s, "modulate:a", 1.0, 0.1)
	t.parallel().tween_property(s, "scale", Vector3.ONE * k, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(func(u: float): s.position = p0 + move * u + Vector3(sin(u * TAU * 1.5) * sway, 0, 0), 0.0, 1.0, life)
	t.parallel().tween_property(s, "modulate:a", 0.0, life * 0.35).set_delay(life * 0.65)
	t.tween_callback(s.queue_free)

func _start(kind: String, delay: float) -> void:
	match kind:
		"heart":
			for i in 3:
				var s := _sprite("heart", top, Vector3([-0.16, 0.14, -0.02][i], 0.0, 0.0), [0.9, 0.75, 1.0][i])
				_rise(s, delay + 0.35 * i, 1.3, Vector3(0, 0.3, 0), 0.04)
		"sparkle":
			for i in 5:
				var a := -0.9 + 0.45 * i
				var s := _sprite("sparkle", top, Vector3(sin(a) * 0.36, -0.12 + cos(a) * 0.12, 0), 0.55 + 0.15 * (i % 2))
				_pop(s, delay + 0.1 * i, 0.25, 0.25)
				var r := create_tween()
				r.tween_interval(delay + 0.1 * i)
				r.tween_property(s, "rotation:z", PI * 0.5, 0.7)
		"note":
			for i in 3:
				var sx := -1.0 if i % 2 else 1.0
				var s := _sprite("note", top, Vector3(0.22 * sx, -0.1, 0), 0.7)
				_rise(s, delay + 0.45 * i, 1.2, Vector3(0.14 * sx, 0.3, 0), 0.05)
		"exclaim":
			var s := _sprite("exclaim", top, Vector3(0.05, 0.0, 0), 1.0)
			_pop(s, delay, 1.1)
		"question":
			var s := _sprite("question", top, Vector3(0.05, 0.0, 0), 1.0)
			_pop(s, delay, 1.3)
			var r := create_tween().set_loops(3)
			r.tween_property(s, "rotation:z", 0.2, 0.25).set_trans(Tween.TRANS_SINE)
			r.tween_property(s, "rotation:z", -0.2, 0.25).set_trans(Tween.TRANS_SINE)
		"dot":
			for i in 3:
				var s := _sprite("dot", top, Vector3(-0.14 + 0.14 * i, -0.04, 0), 0.32)
				_pop(s, delay + 0.35 * i, 1.4 - 0.35 * i)
		"bulb":
			var s := _sprite("bulb", top, Vector3(0, 0.02, 0), 1.05)
			_pop(s, delay, 1.0)
			var g := create_tween()
			g.tween_interval(delay + 0.25)
			for i in 3:
				g.tween_property(s, "modulate:b", 0.55, 0.16)
				g.tween_property(s, "modulate:b", 1.0, 0.16)
		"gloom":
			var s := _sprite("gloom", top, Vector3(0, -0.12, 0), 1.0)
			var t := create_tween()
			t.tween_interval(delay)
			t.tween_property(s, "modulate:a", 0.9, 0.4)
			t.parallel().tween_property(s, "scale", Vector3.ONE, 0.01)
			t.parallel().tween_property(s, "position:y", -0.18, 1.8)
			t.tween_property(s, "modulate:a", 0.0, 0.4)
			t.tween_callback(s.queue_free)
		"tear":
			for i in 7:
				for sx in [-1.0, 1.0]:
					var s := _sprite("tear", face, Vector3(0.13 * sx, 0.0, 0.0), 0.3)
					var p0 := s.position
					var t := create_tween()
					t.tween_interval(delay + 0.24 * i + (0.1 if sx > 0 else 0.0))
					t.tween_property(s, "modulate:a", 1.0, 0.05)
					t.parallel().tween_property(s, "scale", Vector3.ONE * 0.3, 0.05)
					t.parallel().tween_method(func(u: float): s.position = p0 + Vector3(0.1 * sx * u, -0.32 * u * u + 0.04 * u, 0.0), 0.0, 1.0, 0.55)
					t.parallel().tween_property(s, "modulate:a", 0.0, 0.2).set_delay(0.35)
					t.tween_callback(s.queue_free)
		"anger":
			var s := _sprite("anger", top, Vector3(0.28, -0.12, 0), 0.8)
			_pop(s, delay, 1.2)
			var p := create_tween().set_loops(3)
			p.tween_interval(0.12)
			p.tween_property(s, "scale", Vector3.ONE * 1.0, 0.12)
			p.tween_property(s, "scale", Vector3.ONE * 0.8, 0.14)
		"shy":
			for sx in [-1.0, 1.0]:
				var s := _sprite("shy", face, Vector3(0.22 * sx, -0.15, 0.02), 0.45)
				_pop(s, delay, 1.4)
		"z":
			for i in 4:
				var s := _sprite("z", top, Vector3(0.12, -0.1, 0), 0.45 + 0.12 * i)
				_rise(s, delay + 0.45 * i, 1.4, Vector3(0.2, 0.3, 0), 0.03)
		"sweat":
			var s := _sprite("sweat", top, Vector3(0.3, -0.18, 0), 0.6)
			_pop(s, delay, 1.1)
			var m := create_tween()
			m.tween_interval(delay + 0.2)
			m.tween_property(s, "position:y", -0.26, 1.0).set_trans(Tween.TRANS_SINE)
		"confetti":
			for i in 10:
				var s := _sprite("confetti", top, Vector3(randf_range(-0.1, 0.1), -0.1, 0), randf_range(0.35, 0.5))
				s.modulate = Color.from_hsv(randf(), 0.35, 1.0, 0.0)
				var p0 := s.position
				var vx := randf_range(-0.55, 0.55)
				var vy := randf_range(0.45, 0.8)
				var spin := randf_range(-6.0, 6.0)
				var t := create_tween()
				t.tween_interval(delay + 0.03 * i)
				t.tween_property(s, "modulate:a", 1.0, 0.05)
				t.parallel().tween_property(s, "scale", Vector3.ONE * float(s.get_meta("size")), 0.05)
				t.parallel().tween_method(func(u: float):
					s.position = p0 + Vector3(vx * u, vy * u - 1.1 * u * u, 0)
					s.rotation.z = spin * u, 0.0, 1.0, 1.3)
				t.parallel().tween_property(s, "modulate:a", 0.0, 0.35).set_delay(0.95)
				t.tween_callback(s.queue_free)
		"puff":
			var s := _sprite("puff", face, Vector3(0.06, -0.2, 0.08), 0.35)
			_rise(s, delay, 1.4, Vector3(0.22, -0.12, 0.1), 0.0)
			var g := create_tween()
			g.tween_interval(delay)
			g.tween_property(s, "scale", Vector3.ONE * 0.6, 1.4)
		"stars":
			for i in 3:
				var s := _sprite("stars", top, Vector3.ZERO, 0.4)
				var ph := TAU * i / 3.0
				var t := create_tween()
				t.tween_interval(delay)
				t.tween_property(s, "modulate:a", 1.0, 0.15)
				t.parallel().tween_property(s, "scale", Vector3.ONE * 0.4, 0.15)
				t.parallel().tween_method(func(u: float):
					var a := ph + u * TAU * 2.5
					s.position = Vector3(cos(a) * 0.3, -0.16 + sin(a) * 0.05, sin(a) * 0.3), 0.0, 1.0, 2.0)
				t.parallel().tween_property(s, "modulate:a", 0.0, 0.3).set_delay(1.7)
				t.tween_callback(s.queue_free)
		"breath":
			for i in 5:
				var s := _sprite("breath", face, Vector3(0.0, -0.2, 0.06), 0.25)
				_rise(s, delay + 0.6 * i, 0.9, Vector3(0.05 * (1 - 2 * (i % 2)), 0.08, 0.16), 0.0)
		"achoo":
			var s := _sprite("achoo", face, Vector3(-0.3, -0.08, 0.1), 0.6)
			_pop(s, delay, 0.35, 0.25)
			var p := _sprite("puff", face, Vector3(0.0, -0.2, 0.14), 0.3)
			_rise(p, delay + 0.05, 0.8, Vector3(0, -0.05, 0.25), 0.0)
	if _live == 0:
		queue_free()
