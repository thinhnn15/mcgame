extends Node3D

const TOOL_CLIPS := "res://data/tool_clips.json"
const TRUNK_R := 0.14
var IMPACT_LOCAL := Vector3(-0.077, 0.0, 0.832)
const REACH := 1.5
const TREES := [Vector3(0, 0, 0), Vector3(-2.6, 0, -1.4), Vector3(2.4, 0, -2.2)]

var player: Player
var cam: Camera3D
var trees: Array = []
var t := 0.0
var shake := 0.0
var cam_off := Vector3(0, 2.3, 3.6)

func _ready() -> void:
	Stage.setup(self)
	var tc = JSON.parse_string(FileAccess.get_file_as_string(TOOL_CLIPS)) if FileAccess.file_exists(TOOL_CLIPS) else null
	if tc is Dictionary and tc.has("Tool_Axe_Hit"):
		var e: Array = tc["Tool_Axe_Hit"]["blade_edge"]
		var w: Array = tc["Tool_Axe_Hit"]["edge_dir"]
		var way := Vector3(w[0], 0, w[2]).normalized()
		IMPACT_LOCAL = Vector3(e[0], 0, e[2]) + way * TRUNK_R
	var grass := MeshInstance3D.new()
	grass.mesh = Props.cyl(14.0, 14.0, 1.0)
	grass.material_override = Props.mat(Color("9fdc7c"))
	grass.position.y = -0.5
	add_child(grass)
	Props.solid(self, WorldBoundaryShape3D.new(), Vector3.ZERO)
	for i in TREES.size():
		var tr := ChopTree.new()
		add_child(tr)
		tr.position = TREES[i]
		tr.rotation.y = float(i) * 1.3
		trees.append(tr)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	player = Player.new()
	add_child(player)
	player.position = Vector3(0.3, 0, 2.4)
	player.setup(Looks.load_saved(), cam)
	player.chibi.hold("axe")
	player.tool_pressed.connect(swing)
	var hint := Label.new()
	hint.text = tr("HINT_CHOP")
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color("5b4a44"))
	hint.position = Vector2(24, 18)
	var layer := CanvasLayer.new()
	layer.add_child(hint)
	add_child(layer)
	var co := Stage.arg("--cam")
	if co != "":
		var v := co.split_floats(",")
		cam_off = Vector3(v[0], v[1], v[2])
	_place_camera(1.0)
	if Stage.arg("--auto") != "" or OS.get_cmdline_user_args().has("--auto"):
		_demo()

func _target() -> ChopTree:
	"""The standing tree in reach and roughly in front of the player."""
	var best: ChopTree = null
	var best_d := REACH
	var fwd := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
	for tr in trees:
		if tr.felled:
			continue
		var to: Vector3 = tr.global_position - player.global_position
		to.y = 0.0
		if to.length() < best_d and to.normalized().dot(fwd) > 0.3:
			best = tr
			best_d = to.length()
	return best

func swing() -> void:
	var c := player.chibi
	var tree := _target()
	if tree == null:
		c.use_tool("Tool_Axe_Air")
		return

	var to := tree.global_position - player.global_position
	var yaw := atan2(to.x, to.z) - atan2(IMPACT_LOCAL.x, IMPACT_LOCAL.z)
	var spot := tree.global_position - Basis(Vector3.UP, yaw) * IMPACT_LOCAL
	var tw := create_tween().set_parallel()
	tw.tween_property(player, "position", Vector3(spot.x, player.position.y, spot.z), 0.12)
	tw.tween_method(func(a: float): player.rotation.y = a; player.facing = a,
		player.rotation.y, player.rotation.y + angle_difference(player.rotation.y, yaw), 0.12)
	var impact := c.use_tool("Tool_Axe_Hit")
	await get_tree().create_timer(impact).timeout
	c.hit_stop(0.07)
	shake = 0.06
	tree.hit(player, c.posed_point("Item", Chibi.AXE_BLADE))

func _demo() -> void:
	"""Three hits on the first tree, watch it fall, then a swing at nothing; quit."""
	var tm := func(s: float): return get_tree().create_timer(s).timeout

	player.position = trees[0].global_position + Vector3(-1.1, 0, 0.15)
	player.rotation.y = PI * 0.5
	player.facing = player.rotation.y
	await tm.call(0.8)
	for i in 3:
		swing()
		await tm.call(1.15)
	await tm.call(2.4)
	player.rotation.y = PI
	player.facing = player.rotation.y
	await tm.call(0.5)
	swing()
	await tm.call(1.8)
	get_tree().quit()

func _place_camera(k: float) -> void:
	var target := player.global_position + Vector3(0, 0.75, 0)
	var want := target + cam_off
	cam.global_position = cam.global_position.lerp(want, k)
	cam.look_at(target, Vector3.UP)
	if shake > 0.0:
		cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.25

func _process(delta: float) -> void:
	t += delta
	shake = maxf(0.0, shake - delta)
	_place_camera(1.0 - exp(-delta * 5.0))
