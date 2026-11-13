extends Node

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:

	if n.get_parent() != get_tree().root or n.scene_file_path == "" or n is Window:
		return
	var cur := get_tree().current_scene
	if cur == null or cur == n or not cur.is_inside_tree():
		reset()

static func reset() -> void:
	RenderingServer.global_shader_parameter_set("cloud_shadow", 1.0)
	RenderingServer.global_shader_parameter_set("canopy_on", 0.0)
	RenderingServer.global_shader_parameter_set("ground_ao_on", 0.0)
	RenderingServer.global_shader_parameter_set("weathering", 0.0)
	RenderingServer.global_shader_parameter_set("rain_wet", 0.0)
	RenderingServer.global_shader_parameter_set("rain_puddle", 0.0)
	RenderingServer.global_shader_parameter_set("rain_fall", 0.0)
	RenderingServer.global_shader_parameter_set("chara_key", 0.0)
