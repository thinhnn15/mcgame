class_name FarmCutscene
extends Node

signal finished

var plot: Node3D
var cam: Camera3D
var own_light := false
var drives_hens := false
var _shake := 0.0
var _shot := {}
var _look := Vector3.ZERO
var _pos := Vector3.ZERO
var _t := 0.0
var _speed := 1.0
var _bars: Array[ColorRect] = []
var _labels: Array[Label3D] = []
var _spy := Stage.arg("--cam").split_floats(",")

func play(_p: Node3D) -> void:
	pass

func _begin(p: Node3D) -> void:
	plot = p
	cam = p.cam
	_letterbox(true)
	p.player.controls = false
	p.player.visible = false
	p.hud.visible = false
	for n in p.find_children("*", "Label3D", true, false):
		if (n as Label3D).visible:
			n.visible = false
			_labels.append(n)

func _end() -> void:
	plot.player.controls = true
	plot.player.visible = true
	plot.hud.visible = true
	for n in _labels:
		if is_instance_valid(n):
			n.visible = true
	finished.emit()

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _tick(_delta: float) -> void:
	pass

func _rig_pose(_kind: String, _s: float, _delta: float) -> Array:
	return [_pos, _look, 1.0]

func _process(delta: float) -> void:
	_t += minf(delta, 1.0 / 20.0)
	var real := delta / maxf(Engine.time_scale, 0.01)
	if not is_equal_approx(Engine.time_scale, _speed):
		Engine.time_scale = move_toward(Engine.time_scale, _speed, real * 3.5)
	_tick(delta)
	if cam == null or _shot.is_empty():
		return
	var s := clampf((_t - float(_shot.t0)) / float(_shot.dur), 0.0, 1.0)
	s = s * s * (3.0 - 2.0 * s)
	cam.fov = lerpf(_shot.fov0, _shot.fov1, s)
	var pos := Vector3.ZERO
	var want := Vector3.ZERO
	var k := 1.0 - exp(-delta * 9.0)
	match _shot.kind:
		"fix":
			pos = (_shot.p0 as Vector3).lerp(_shot.p1, s)
			want = (_shot.l0 as Vector3).lerp(_shot.l1, s)
		"follow":
			pos = (_shot.p0 as Vector3).lerp(_shot.p1, s)
			want = (_shot.node as Node3D).global_position + (_shot.off as Vector3)
			if _shot.has("mix"):
				want = want.lerp(_shot.mix_at, _shot.mix)
		_:
			var r := _rig_pose(_shot.kind, s, delta)
			pos = r[0]
			want = r[1]
			k = r[2]
	if _shot.get("fresh", true):
		_shot.fresh = false
		_pos = pos
		_look = want
	_pos = pos if _shot.kind == "fix" or _shot.kind == "follow" else _pos.lerp(pos, k)
	_look = _look.lerp(want, k)
	cam.global_position = _pos
	if _shake > 0.0:
		cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = maxf(_shake - real * 0.05, 0.0)
	cam.look_at(_look, Vector3.UP)
	if _spy.size() >= 6:
		cam.global_position = Vector3(_spy[0], _spy[1], _spy[2])
		cam.look_at(Vector3(_spy[3], _spy[4], _spy[5]), Vector3.UP if absf(_spy[0] - _spy[3]) + absf(_spy[2] - _spy[5]) > 0.01 else Vector3.FORWARD)
		cam.fov = _spy[6] if _spy.size() > 6 else 50.0

func _fix(p0: Vector3, p1: Vector3, l0: Vector3, l1: Vector3, dur: float, fov: float, fov1 := NAN) -> void:
	_shot = {"kind": "fix", "p0": p0, "p1": p1, "l0": l0, "l1": l1, "t0": _t, "dur": dur, "fov0": fov,
		"fov1": fov if is_nan(fov1) else fov1}

func _follow(p0: Vector3, p1: Vector3, node: Node3D, off: Vector3, dur: float, fov0: float, fov1: float,
		mix := 0.0, mix_at := Vector3.ZERO) -> void:
	_shot = {"kind": "follow", "p0": p0, "p1": p0 if p1 == Vector3.INF else p1, "node": node, "off": off,
		"t0": _t, "dur": dur, "fov0": fov0, "fov1": fov1}
	if mix > 0.0:
		_shot.mix = mix
		_shot.mix_at = mix_at

func _rig(kind: String, dur: float, fov: float) -> void:
	_shot = {"kind": kind, "t0": _t, "dur": dur, "fov0": fov, "fov1": fov}

func _slow(to: float) -> void:
	_speed = to
	if to < 1.0:
		Engine.time_scale = to

func _until(t: float) -> void:
	while _t < t:
		await get_tree().process_frame

func _move(n: Node3D, pts: Array, dur: float, face := true, trans := Tween.TRANS_SINE, ease_ := Tween.EASE_IN_OUT) -> Tween:
	var tw := create_tween()
	tw.tween_method(_step.bind(n, pts, face), 0.0, 1.0, dur).set_trans(trans).set_ease(ease_)
	return tw

func _step(s: float, n: Node3D, pts: Array, face: bool) -> void:
	n.position = _bez(pts, s)
	if face:
		var d := _bez(pts, minf(s + 0.01, 1.0)) - _bez(pts, maxf(s - 0.01, 0.0))
		d.y = 0.0
		if d.length() > 0.0005:
			n.rotation.y = lerp_angle(n.rotation.y, atan2(d.x, d.z), 1.0 - exp(-get_process_delta_time() * 7.0))

static func _bez(pts: Array, s: float) -> Vector3:
	var q: Array = pts.duplicate()
	while q.size() > 1:
		for i in q.size() - 1:
			q[i] = (q[i] as Vector3).lerp(q[i + 1], s)
		q.pop_back()
	return q[0] as Vector3

func _letterbox(on: bool) -> void:
	if _bars.is_empty():
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		for top in [true, false]:
			var b := ColorRect.new()
			b.color = Color.BLACK
			b.anchor_right = 1.0
			b.anchor_top = 0.0 if top else 1.0
			b.anchor_bottom = 0.0 if top else 1.0
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(b)
			_bars.append(b)
	var tw := create_tween().set_parallel()
	var h := 0.115 if on else 0.0
	tw.tween_property(_bars[0], "anchor_bottom", h, 0.45)
	tw.tween_property(_bars[1], "anchor_top", 1.0 - h, 0.45)
