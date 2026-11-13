class_name Underwater
extends Node

const BODY := 0.95
const BACK := 2.6
const UP := 0.5

var cam: Camera3D
var hero: Node3D
var u := 0.0
var _quad: MeshInstance3D
var _mat: ShaderMaterial
var _auto := false
var _t_auto := 1.5

static func add(parent: Node, cam_: Camera3D, hero_: Node3D) -> Underwater:
	var w := Underwater.new()
	w.name = "Underwater"
	w.cam = cam_
	w.hero = hero_
	parent.add_child(w)
	return w

func _ready() -> void:
	process_priority = 100
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/underwater.gdshader")
	_mat.set_shader_parameter("noise_tex", load("res://props/farm/ground/noise.png"))
	_mat.render_priority = -1
	_quad = MeshInstance3D.new()
	_quad.mesh = q
	_quad.material_override = _mat
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	_quad.visible = false
	cam.add_child(_quad)
	_quad.position = Vector3(0, 0, -0.5)
	_auto = OS.get_cmdline_user_args().has("--dive")

func _diving() -> bool:
	var d: String = hero.get("dive")
	if d == "Swim_Under":
		return true
	if d == "Swim_Dive":
		return float(hero.get("_dive_t")) > 0.55
	return false

func _process(delta: float) -> void:
	if cam == null or hero == null or not is_instance_valid(hero):
		return
	if _auto and str(hero.get("dive")) == "":
		_t_auto -= delta
		if _t_auto <= 0.0:
			_t_auto = 2.0
			hero.call("toggle_dive")
	u = lerpf(u, 1.0 if _diving() else 0.0, 1.0 - exp(-delta * 2.2))
	var wy: float = hero.get("water_y")
	if u > 0.002 and not is_nan(wy):
		var yaw: float = hero.rotation.y
		var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
		var body := hero.global_position - Vector3(0, BODY, 0)
		var want := body - fwd * BACK + Vector3(0, UP, 0)
		want.y = minf(want.y, wy - 0.35)
		var k := smoothstep(0.0, 1.0, u)
		cam.global_position = cam.global_position.lerp(want, k)

		var tgt := (hero.global_position + Vector3(0, 0.8, 0)).lerp(body + fwd * 0.9 + Vector3(0, 0.75, 0), k)
		cam.look_at(tgt, Vector3.UP)
	var p := cam.global_position
	var w := Water.at(p.x, p.z)
	var under := w.y > 0.0 and p.y < w.x + Swell.lift(p.x, p.z, w.y) - 0.03
	_quad.visible = under
	if under:
		_mat.set_shader_parameter("water_y", w.x)
