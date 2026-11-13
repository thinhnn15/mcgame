class_name WaterGrid
extends MeshInstance3D

const R := 28.0
const STEP := 0.5

static var time := 0.0
static var active := false

var follow: Node3D
var sheet: ShaderMaterial
var mat: ShaderMaterial

static func make(parent: Node3D, follow_: Node3D, sheet_: ShaderMaterial, y: float) -> WaterGrid:
	var g := WaterGrid.new()
	g.name = "WaterGrid"
	g.follow = follow_
	g.sheet = sheet_
	g.position.y = y
	parent.add_child(g)
	return g

func _ready() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.0 * R, 2.0 * R)
	pm.subdivide_width = int(2.0 * R / STEP) - 1
	pm.subdivide_depth = int(2.0 * R / STEP) - 1
	mesh = pm
	custom_aabb = AABB(Vector3(-R, -0.5, -R), Vector3(2.0 * R, 1.0, 2.0 * R))
	mat = sheet.duplicate() as ShaderMaterial
	mat.set_shader_parameter("displace", true)
	mat.set_shader_parameter("grid_r", R)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.set_shader_parameter("hole", true)
	sheet.set_shader_parameter("grid_r", R)
	active = true
	_process(0.0)

func _exit_tree() -> void:
	active = false

func _process(_delta: float) -> void:
	time = fmod(Time.get_ticks_msec() / 1000.0, 1200.0)
	RenderingServer.global_shader_parameter_set("water_time", time)
	if follow == null or not is_instance_valid(follow):
		return
	var c := Vector2(roundf(follow.global_position.x / STEP), roundf(follow.global_position.z / STEP)) * STEP
	position.x = c.x
	position.z = c.y
	mat.set_shader_parameter("grid_c", c)
	sheet.set_shader_parameter("grid_c", c)
