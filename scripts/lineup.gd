extends Node3D

const LOOKS := [
	{"hair": "buns", "hair_color": "#6b4330", "eye_style": "classic", "eye_color": "#7a4a2a",
		"top": {"shape": "tee", "color": "#ff9fb8", "color_b": "#ffffff", "pattern": "stripes"},
		"bottom": {"shape": "shorts", "color": "#7fb4ff", "pattern": "plain"},
		"shoes": {"shape": "sneakers", "color": "#ffffff", "trim": "#ff8fa8"}},
	{"hair": "buns", "hair_color": "#e8c27a", "eye_style": "sparkle", "eye_color": "#4f86c6", "skin": "#ffe8d6",
		"top": {"shape": "dress", "color": "#a8e6a1", "color_b": "#ffffff", "pattern": "dots"},
		"bottom": {"shape": "none"},
		"shoes": {"shape": "boots", "color": "#ffb27a", "trim": "#8a5a3c"}},
	{"hair": "buns", "hair_color": "#2e2320", "eye_style": "calm", "eye_color": "#3a2a24", "skin": "#d9a074",
		"top": {"shape": "hoodie", "color": "#ffe17a", "pattern": "plain", "trim": "#ffffff"},
		"bottom": {"shape": "pants", "color": "#5a5f7a", "pattern": "plain"},
		"shoes": {"shape": "sneakers", "color": "#e06464", "trim": "#ffffff"}},
	{"hair": "buns", "hair_color": "#f2a6c0", "eye_style": "classic", "eye_color": "#b05aa8",
		"top": {"shape": "longsleeve", "color": "#c4a3ff", "color_b": "#ffffff", "pattern": "check"},
		"bottom": {"shape": "skirt", "color": "#ffffff", "color_b": "#ff9fb8", "pattern": "flowers"},
		"shoes": {"shape": "boots", "color": "#ffffff", "trim": "#c4a3ff"}},
	{"hair": "buns", "hair_color": "#8fb7ff", "eye_style": "dot", "eye_color": "#3a2a24", "skin": "#f2c29a",
		"top": {"shape": "tee", "color": "#7fd3e6", "color_b": "#ffffff", "pattern": "flowers"},
		"bottom": {"shape": "skirt", "color": "#ffe17a", "pattern": "plain"},
		"shoes": {"shape": "sneakers", "color": "#ffffff", "trim": "#7fd3e6"}},
	{"hair": "buns", "hair_color": "#a8693c", "eye_style": "sparkle", "eye_color": "#4aa56a", "skin": "#b47a52",
		"top": {"shape": "tee", "color": "#ffffff", "color_b": "#e06464", "pattern": "stripes"},
		"bottom": {"shape": "shorts", "color": "#e06464", "pattern": "plain"},
		"shoes": {"shape": "boots", "color": "#ffe17a", "trim": "#a8693c"}},
]

var still := []
var first: Chibi

func _ready() -> void:
	Stage.setup(self)
	var floor_ := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 10)
	floor_.mesh = pm
	var fm := ShaderMaterial.new()
	fm.shader = preload("res://shaders/toon.gdshader")
	fm.set_shader_parameter("base_color", Color("b8e39a"))
	floor_.material_override = fm
	add_child(floor_)
	var clip := Stage.arg("--clip", "Base_Wait")

	var looks: Array = LOOKS
	if Stage.arg("--chars") != "":
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Stage.arg("--data", "res://data/characters.json")))
		looks = []
		for id in Stage.arg("--chars").split(","):
			looks.append(data[id]["look"])
	for i in looks.size():
		var c := Chibi.new()
		add_child(c)
		var l := Looks.DEFAULT.duplicate(true)
		l.merge(looks[i], true)
		c.build(l)
		c.position = Vector3((i - (looks.size() - 1) / 2.0) * 1.05, 0, 0)
		c.play(clip, 0.0)
		if first == null:
			first = c
	var cam := Camera3D.new()
	add_child(cam)
	var cc := Stage.arg("--cam", "0,1.6,6.2,0,0.7,0,34").split_floats(",")
	cam.position = Vector3(cc[0], cc[1], cc[2])
	cam.look_at(Vector3(cc[3], cc[4], cc[5]), Vector3.UP)
	cam.fov = cc[6]
	still = Stage.still_args()

func _process(_d: float) -> void:
	if still[0] != "" and first._time >= still[1]:
		set_process(false)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(still[0])
		get_tree().quit()
