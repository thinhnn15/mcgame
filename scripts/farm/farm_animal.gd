class_name FarmAnimal
extends Node3D

const DIR := "res://props/farm/animals/"
const SHADER := preload("res://shaders/animal.gdshader")
const FUR := preload("res://shaders/animal_fur.gdshader")

const ONE_SHOT := {"Sit_Start": "Sit_Keep", "Sit_End": "Idle", "Lie_Start": "Lie_Keep", "Stand_Up": "Idle",
	"Sit": "Sit_Keep", "Lie": "Lie_Keep", "Hide": "Hide_Keep", "Flap": "", "Crow": "", "Bark": "", "Hop": "",
	"Stretch": "", "Strike": "", "Takeoff": "Fly", "Land": "Idle", "Bleat": "", "Coo": "", "Croak": "", "Look_Up": "",
	"Swoop": "", "Flap_Away": "Fly", "Look_Back": "Fly", "Clash": "", "Recoil": "Flap_Away", "Kick": "", "Shake": "Swim", "Pounce": "", "Put_Down": "Idle", "Shake_Dry": "Idle", "Call_Swim": "Swim", "Shield": "Shield_Keep", "Shield_End": "Idle",
	"Peek": "Idle", "Bow": "Idle", "Rear": "Idle", "Shake_Head": "Idle"}

const EYES := {"Sleep": 2.0, "Loaf": 1.0}
const EYES_OF := {"cho_vang": {"Lie_Keep": 1.0, "Wag": 3.0}, "meo_muop": {"Sneak": 1.0, "Wiggle": 1.0},
		"ga_con": {"Hide": 3.0, "Hide_Keep": 3.0, "Shiver": 3.0}, "ga_mai": {"Shield": 3.0, "Shield_Keep": 3.0},
		"dieu_hau": {"Look_Back": 3.0, "Hover": 3.0, "Clash": 3.0, "Recoil": 2.0}, "vit_con": {"Hop": 3.0}, "vit_con_hd": {"Hop": 3.0},
		"ga_con_hd": {"Hide": 3.0, "Hide_Keep": 3.0, "Shiver": 3.0}, "lan": {"Sleep_Keep": 2.0, "Dance": 3.0, "Bow": 3.0}}

const MOOD := 3.0

const SPEED := {"ga_mai": {"Walk": 0.233, "Run": 0.75}, "trau": {"Walk": 0.30, "Swim": 0.30},
	"nghe": {"Walk": 0.30, "Follow": 0.30, "Run": 1.286}, "vit": {"Walk": 0.216, "Run": 0.57, "Swim": 0.20},
	"vit_con": {"Walk": 0.216, "Run": 0.57, "Swim": 0.20}, "vit_con_hd": {"Walk": 0.216, "Run": 0.57, "Swim": 0.20},
	"ga_trong": {"Walk": 0.255, "Run": 0.85},
	"ga_con": {"Walk": 0.18, "Run": 0.45}, "ga_con_hd": {"Walk": 0.18, "Run": 0.45}, "cho_vang": {"Walk": 0.545, "Follow": 1.7, "Run": 3.4, "Swim": 0.35,
		"Track": 0.30, "Carry": 0.545}, "lan": {"Walk": 0.55},
	"meo_muop": {"Walk": 0.36, "Follow": 1.0, "Run": 2.1, "Sneak": 0.188},
	"co_trang": {"Walk": 0.15, "Fly": 2.6, "Glide": 3.0}, "ca_chep": {"Swim": 0.25, "Dart": 1.1},
	"ca_ro": {"Swim": 0.1, "Dart": 0.5}, "ca_tram": {"Swim": 0.28, "Dart": 1.25}, "ca_diec": {"Swim": 0.11, "Dart": 0.55},

	"lon_i": {"Walk": 0.184, "Run": 0.828}, "lon_con": {"Walk": 0.184, "Follow": 0.184, "Run": 0.638},
	"bo_vang": {"Walk": 0.276}, "de": {"Walk": 0.390, "Run": 1.329},
	"chim_se": {"Walk": 0.21, "Fly": 3.5, "Glide": 3.0}, "bo_cau": {"Walk": 0.225, "Fly": 4.0, "Glide": 4.0},
	"chao_mao": {"Walk": 0.24, "Fly": 3.5, "Glide": 3.0},
	"dom_dom": {"Fly": 0.35}, "chuon_chuon": {"Fly": 2.5}, "chuon_kim": {"Fly": 1.2}, "buom_vang": {"Fly": 0.8, "Glide": 1.0},
	"buom_xanh": {"Fly": 0.8, "Glide": 1.0}, "ong": {"Fly": 1.2},
	"ngan": {"Walk": 0.208, "Run": 0.545, "Swim": 0.20},
	"ech": {"Walk": 0.110, "Hop": 0.200, "Swim": 0.150},
	"cua_dong": {"Walk": 0.096},
	"oc": {"Walk": 0.012}, "ca_me": {"Swim": 0.26, "Dart": 1.15},
	"tho": {"Walk": 0.095, "Run": 0.536}, "dieu_hau": {"Fly": 6.0, "Soar": 5.0, "Look_Back": 6.0}}
const SCALE := {"ngan": 1.15, "tho": 1.2}
const BLEND_OF := {"Sleep": 0.55}
const GLOWS := ["dom_dom"]

const COATS := {"tho": ["", "trang", "xam", "vang", "den_trang", "dom"],
	"meo_muop": ["", "vang", "mun", "trang", "xam", "tam_the", "bo_sua"],
	"ca_chep": ["", "do"], "ca_tram": ["", "den"],
	"cho_vang": ["", "muc", "ven"],
	"chuon_chuon": ["", "ngo", "vang", "xanh", "tim", "hoa"],
	"chuon_kim": ["", "do", "luc", "den"],
	"de": ["", "den", "trang", "bach_thao", "khoang"]}

const LOD_NEAR := 12.0
const LOD_MID := 25.0
const SHADOW_FAR := 28.0

const NO_SHADOW := ["buom_vang", "buom_xanh", "ong", "dom_dom", "chuon_chuon", "chuon_kim", "oc", "cua_dong", "ech", "ca_chep",
	"ca_tram", "ca_ro", "ca_diec", "ca_me", "luon", "chach", "ca_bong", "ca_co", "ca_muong", "ca_nganh", "ca_tre",
	"ca_qua", "ca_that_lat", "ca_ro_phi"]
const DRAW_END := {"buom_vang": 22.0, "buom_xanh": 22.0, "ong": 16.0, "chuon_chuon": 22.0, "chuon_kim": 18.0, "oc": 16.0,
	"cua_dong": 18.0, "ech": 22.0, "ga_con": 35.0, "vit_con": 35.0, "chim_se": 35.0}

const MESH_LOD := {"bo_cau": [4.0, 12.0],
	"ga_trong": [7.0, 18.0],
	"ga_mai": [6.0, 16.0],
	"meo_muop": [6.0, 16.0],
	"vit": [6.0, 16.0],
	"ngan": [7.0, 18.0],
	"vit_con": [2.5, 7.0],
	"ga_con": [2.5, 7.0],
	"ech": [1.6, 4.5],
	"cho_vang": [11.0, 28.0],
	"dieu_hau": [8.0, 20.0],
	"de": [9.0, 24.0]}
const MESH_LOD_DEFAULT := [6.0, 16.0]

static var lod := true
static var force_lod := -1
static var _view_frame := -1
static var _view_cam: Camera3D
static var _view_planes: Array[Plane] = []
static var _view_k := 1.0
static var _view_cut := false
static var _view_pos := Vector3.ZERO
static var _view_fov := 0.0
static var _mats := {}

var kind := ""
var coat := ""
var anim: AnimationPlayer
var _meshes: Array[GeometryInstance3D] = []
var _lod_sets: Array = []
var _lod_at: Array = []
var _lod_level := 0
var _loop := "Idle"
var _blink_t := 0.0
var _blink_step := -1
var _mood := false
var full_rate := false
var hold_eyes := -1.0
var _shadow_on := true
var _lod_t := 0.0
var _casts := true
var _draw_end := INF
var _step := 0.0
var _acc := 0.0

static func spawn(parent: Node, what: String, pos := Vector3.ZERO, yaw := 0.0, coat_ := "") -> FarmAnimal:
	var a := FarmAnimal.new()
	a.kind = what
	var coats: Array = COATS.get(what, [""])
	a.coat = coats.pick_random() if coat_ == "random" else (coat_ if coats.has(coat_) else "")
	a.name = what
	a.position = pos
	a.rotation.y = yaw
	a.scale = Vector3.ONE * SCALE.get(what, 1.0)
	parent.add_child(a)
	return a

static func material(what: String, coat_ := "") -> ShaderMaterial:
	var key := what + ("_" + coat_ if coat_ != "" else "")
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("albedo_tex", load(DIR + what + "_alb" + ("_" + coat_ if coat_ != "" else "") + ".png"))
		_mats[key] = m
	return _mats[key]

static func fur_material(what: String) -> ShaderMaterial:
	var key := what + "|fur"
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = FUR
		m.set_shader_parameter("fur_tex", load(DIR + what + "_fur.png"))
		_mats[key] = m
	return _mats[key]

func _ready() -> void:
	var model: Node3D = (load(DIR + kind + ".glb") as PackedScene).instantiate()
	add_child(model)
	var has_lod := not model.find_children("*_lod1", "MeshInstance3D", true, false).is_empty()
	var lr: Array = MESH_LOD.get(kind, MESH_LOD_DEFAULT)
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.material_override = fur_material(kind) if mi.name.ends_with("_fur") else material(kind, coat)
		if mi.name.ends_with("_fur"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 20.0
			continue
		if kind in NO_SHADOW:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if DRAW_END.has(kind):
			mi.visibility_range_end = DRAW_END[kind]
		if has_lod:
			if _lod_sets.is_empty():
				_lod_sets = [[], [], []]
				_lod_at = lr
			var lv := 2 if mi.name.ends_with("_lod2") else (1 if mi.name.ends_with("_lod1") else 0)
			_lod_sets[lv].append(mi)
			mi.visible = lv == 0
		_meshes.append(mi)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_casts = not kind in NO_SHADOW
	_lod_t = randf() * 0.25
	_draw_end = DRAW_END.get(kind, INF)
	_acc = randf() * 0.1
	for clip in anim.get_animation_list():
		anim.get_animation(clip).loop_mode = Animation.LOOP_NONE if ONE_SHOT.has(clip) else Animation.LOOP_LINEAR
	anim.animation_finished.connect(_on_finished)
	_blink_t = randf_range(1.0, 4.0)
	_loop = "Idle" if anim.has_animation("Idle") else "Swim"
	play(_loop)

func play(clip: String, blend := 0.25) -> void:
	if clip == "Idle" and not anim.has_animation(clip):
		clip = "Swim"
	if not anim.has_animation(clip):
		push_warning("FarmAnimal %s: no clip %s" % [kind, clip])
		return
	if not ONE_SHOT.has(clip):
		_loop = clip

	if anim.current_animation == clip and anim.is_playing():
		return
	anim.play(clip, BLEND_OF.get(clip, blend) if blend == 0.25 else blend)
	_blink_step = -1
	_set_eyes(_held_eyes(clip))

func speed(clip := "") -> float:
	return SPEED.get(kind, {}).get(clip if clip != "" else anim.current_animation, 0.0)

func _on_finished(clip: StringName) -> void:
	var next: String = ONE_SHOT.get(String(clip), "")
	play(next if next != "" else _loop)

func _held_eyes(clip: String) -> float:
	if hold_eyes >= 0.0:
		return hold_eyes
	if _mood:
		return MOOD
	return EYES_OF.get(kind, {}).get(clip, EYES.get(clip, 0.0))

func set_mood(on: bool) -> void:
	_mood = on
	_blink_step = -1
	_set_eyes(_held_eyes(anim.current_animation))

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_view(cam)
	_lod_t -= delta
	if _lod_t <= 0.0 or _view_cut:
		_lod_t = 0.25
		_update_lod(cam)
	_acc += delta
	if _acc >= _step:
		anim.advance(_acc)
		_acc = 0.0
	if kind in GLOWS:
		var t := Time.get_ticks_msec() / 1000.0 + get_instance_id() % 97 * 0.37
		var g := 1.6 + 1.4 * pow(0.5 + 0.5 * sin(t * 2.3) * sin(t * 0.71 + 1.3), 2.0)
		for m in _meshes:
			if not m.name.ends_with("_fur"):
				m.set_instance_shader_parameter("glow", g)
	if hold_eyes >= 0.0 or _held_eyes(anim.current_animation) > 0.0:
		return
	_blink_t -= delta
	if _blink_t > 0.0:
		return
	_blink_step += 1
	var states := [1.0, 2.0, 1.0, 0.0]
	_set_eyes(states[_blink_step])
	_blink_t = 0.04
	if _blink_step == states.size() - 1:
		_blink_step = -1
		_blink_t = randf_range(2.0, 5.5)

func _set_mesh_lod(lv: int) -> void:
	if lv == _lod_level or _lod_sets.is_empty():
		return
	_lod_level = lv
	for k in 3:
		for m in _lod_sets[k]:
			m.visible = k == lv

func _update_lod(cam: Camera3D) -> void:
	if force_lod >= 0:
		_set_mesh_lod(mini(force_lod, 2))
	if not lod or full_rate or cam == null:
		_step = 0.0
		if force_lod < 0:
			_set_mesh_lod(0)
		return
	var p := global_position
	var d := cam.global_position.distance_to(p)
	var c := p + Vector3.UP * 0.4
	var seen := d < 3.0
	if not seen:
		seen = true
		for pl in _view_planes:
			if pl.distance_to(c) > 1.3:
				seen = false
				break
	var dz := d * _view_k
	if not seen or d > _draw_end:
		_step = 0.5
	else:
		_step = 0.0 if dz < LOD_NEAR else (1.0 / 15.0 if dz < LOD_MID else 0.1)
	if not _lod_sets.is_empty() and seen and force_lod < 0:
		var lv := _lod_level
		if dz > _lod_at[1] + 0.5:
			lv = 2
		elif dz > _lod_at[0] + 0.5 and dz < _lod_at[1] - 0.5:
			lv = 1
		elif dz < _lod_at[0] - 0.5:
			lv = 0
		_set_mesh_lod(lv)
	if _casts:
		var on := dz < SHADOW_FAR
		if on != _shadow_on:
			_shadow_on = on
			for m in _meshes:
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on 					else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _view(cam: Camera3D) -> void:
	var f := Engine.get_process_frames()
	if f == _view_frame and cam == _view_cam:
		return
	var pos := cam.global_position
	_view_cut = cam != _view_cam or pos.distance_to(_view_pos) > 1.5 or absf(cam.fov - _view_fov) > 2.0
	_view_frame = f
	_view_cam = cam
	_view_pos = pos
	_view_fov = cam.fov
	_view_planes = cam.get_frustum()
	_view_k = tan(deg_to_rad(cam.fov) * 0.5) / tan(deg_to_rad(25.0)) 		if cam.projection == Camera3D.PROJECTION_PERSPECTIVE else 1.0

func _set_eyes(state: float) -> void:
	for m in _meshes:
		if not m.name.ends_with("_fur"):
			m.set_instance_shader_parameter("blink", state)
