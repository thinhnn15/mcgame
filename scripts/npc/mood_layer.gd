class_name MoodLayer
extends SkeletonModifier3D

const DATA := "res://data/moods.json"
const FADE := 0.6
const HEAD_ONLY := ["Neck", "Head"]
const PACED := ["Tool_", "Base_", "Wait_"]

static var _moods := {}

var chibi: Chibi
var mood := "binh_thuong"
var _bones := PackedInt32Array()
var _from := PackedVector3Array()
var _to := PackedVector3Array()
var _head := PackedByteArray()
var _sway: Array = []
var _w := 1.0
var _t := 0.0
var _next_fx := 0.0
var _clip := ""

static func of(c: Chibi) -> MoodLayer:
	for n in c.skel.get_children():
		if n is MoodLayer:
			return n
	var m := MoodLayer.new()
	m.chibi = c
	c.skel.add_child(m)
	c.skel.move_child(m, 0)
	return m

static func mood_of(c: Chibi) -> String:
	for n in c.skel.get_children():
		if n is MoodLayer:
			return n.mood
	return "binh_thuong"

static func moods() -> Dictionary:
	if _moods.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_moods = d if d is Dictionary else {}
	return _moods

func set_mood(name: String) -> void:
	var m: Dictionary = moods().get(name, {})
	if m.is_empty():
		return
	mood = name
	var skel := get_skeleton()

	var now := {}
	for i in _bones.size():
		now[_bones[i]] = _from[i] * (1.0 - _w) + _to[i] * _w
	var want := {}
	for b in m.get("bones", {}):
		var bi := skel.find_bone(b)
		if bi >= 0:
			var v: Array = m["bones"][b]
			want[bi] = Vector3(v[0], v[1], v[2])
	var sway_bones := []
	for s in m.get("sway", []):
		var bi := skel.find_bone(s["bone"])
		if bi >= 0:
			sway_bones.append(bi)
	var all := {}
	for bi in now.keys() + want.keys() + sway_bones:
		all[bi] = true
	var order := all.keys()
	order.sort()
	_bones = PackedInt32Array(order)
	_from.resize(order.size())
	_to.resize(order.size())
	_head.resize(order.size())
	for i in order.size():
		_from[i] = now.get(order[i], Vector3.ZERO)
		_to[i] = want.get(order[i], Vector3.ZERO)
		_head[i] = 1 if skel.get_bone_name(order[i]) in HEAD_ONLY else 0
	_sway = []
	for s in m.get("sway", []):
		var bi := skel.find_bone(s["bone"])
		if bi >= 0:
			_sway.append([order.find(bi), ["x", "y", "z"].find(s["axis"]), float(s["deg"]), float(s["secs"])])
	_w = 0.0
	var f: Array = m.get("face", [0, 0, 0])
	chibi.base_eye = int(f[0])
	chibi.base_mouth = int(f[1])
	chibi.base_brow = int(f[2]) if f.size() > 2 else 0
	_clip = ""
	_next_fx = _t + _fx_gap(m)

func speed() -> float:
	return float(moods().get(mood, {}).get("speed", 1.0))

func _fx_gap(m: Dictionary) -> float:
	var e: Array = m.get("fx_every", [8, 12])
	return randf_range(e[0], e[1])

func _process(delta: float) -> void:
	_t += delta
	_w = minf(1.0, _w + delta / FADE)
	var cur := chibi.anim.current_animation
	if cur != _clip:
		_clip = cur
		for p in PACED:
			if cur.begins_with(p):
				chibi.anim.speed_scale = speed()
				break
	var m: Dictionary = moods().get(mood, {})
	if m.has("fx") and _t >= _next_fx and chibi.visible:
		EmoteFx.play(chibi, str(m["fx"]))
		_next_fx = _t + _fx_gap(m)

func _process_modification() -> void:
	var n := _bones.size()
	if n == 0:
		return
	var skel := get_skeleton()
	var working: bool = chibi.anim.current_animation.begins_with("Tool_")
	for i in n:
		if working and _head[i] == 0:
			continue
		var d := _from[i] * (1.0 - _w) + _to[i] * _w
		for s in _sway:
			if s[0] == i:
				d[s[1]] += s[2] * sin(TAU * _t / s[3]) * _w
		if d.length_squared() < 1e-6:
			continue
		var g := skel.get_bone_global_pose(_bones[i])
		g.basis = Basis.from_euler(d * (PI / 180.0)) * g.basis
		skel.set_bone_global_pose(_bones[i], g)
