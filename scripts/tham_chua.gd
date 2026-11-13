extends Node3D

const SPOTS := [
	[Vector3(0, 0.1, 11.0), PI, 0.0],
	[Vector3(0, 3.1, -17.0), PI, 0.0],
	[Vector3(0, 3.1 + 0.95, -28.0), PI, 0.0],
	[Vector3(-7.5, 3.1, -17.5), -2.3, 0.9],
	[Vector3(9.0, 3.1, -16.5), 2.4, -0.8],
	[Vector3(0, 6.6, -51.0), PI, 0.0],
	[Vector3.INF, PI / 2, -PI / 2],
	[Vector3(0, 3.0 + 0.95, -32.5), PI, 0.0],
	[Vector3(0, 0.1, 26.5), PI, 0.0],
	[Vector3(0, -20.0 + 0.1, 100.0), PI, 0.0],
	[Vector3(2.0, -6.67 + 0.1, 52.0), PI, 0.0],
	[Vector3(0, 0.1, 29.5), 0.0, PI],
]
const HILL := 20.0

var player: Player
var cam: OrbitCam
var chua: ChuaMay
var _still := []
var _t := 0.0
var _stat_spot := -1

func _ready() -> void:
	get_tree().physics_interpolation = true
	var sun := Stage.setup(self)
	sun.directional_shadow_max_distance = 80.0
	_morning(sun)
	chua = ChuaMay.new()
	chua.position.y = HILL
	chua.stair_drop = HILL
	add_child(chua)
	chua.build(true)
	ChuaMayDoi.build(self, chua)
	cam = OrbitCam.new()
	cam.fov = 50.0
	cam.far = 600.0
	add_child(cam)
	player = Player.new()
	add_child(player)
	player.bounds_box = 220.0
	player.floor_max_angle = deg_to_rad(46.0)
	player.floor_snap_length = 0.4
	player.setup(Looks.load_saved(), cam)
	Sound.hero = player
	Sound.ambience("temple_day")
	chua.hero = player
	chua.cam = cam
	_drop(int(Stage.arg("--spot", "0")))
	_still = Stage.still_args()
	if "--ring" in OS.get_cmdline_user_args():
		chua.ring_bell()
	if "--up" in OS.get_cmdline_user_args():
		chua._through_door(true)
	if "--stats" in OS.get_cmdline_user_args():
		_stat_spot = 0
		_drop(0)

func _morning(sun: DirectionalLight3D) -> void:
	sun.look_at_from_position(Vector3(10, 6, 3), Vector3.ZERO, Vector3.UP)
	sun.light_color = Color("ffe2bc")
	var env: Environment = (find_child("WorldEnvironment", false, false) as WorldEnvironment).environment
	env.fog_enabled = true
	env.fog_light_color = Color("dfe6ea")
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.35
	env.fog_height = 6.0
	env.fog_height_density = 0.006

func _drop(i: int) -> void:
	var s: Array = SPOTS[clampi(i, 0, SPOTS.size() - 1)]
	var at: Vector3 = s[0] + chua.position
	if s[0] == Vector3.INF:
		at = chua.to_global(Vector3(0, ChuaMay.L2, -64.0) + Vector3(0, ChuaMay.BALCONY + 0.05, ChuaMay.BALCONY_IN + 1.0) * ChuaMay.K)
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = s[1]
	player.facing = s[1]
	player.reset_physics_interpolation()
	cam.follow(player, s[2])

func _physics_process(_delta: float) -> void:
	if player.global_position.y < -5.0:
		_drop(0)

func _process(delta: float) -> void:
	_t += delta
	if _stat_spot >= 0 and _t > 2.5:
		print("tham_chua stats: spot %d  draw calls %d  objects %d  primitives %d  fps %d" % [_stat_spot,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Engine.get_frames_per_second()])
		_stat_spot += 1
		_t = 0.0
		if _stat_spot >= SPOTS.size():
			get_tree().quit()
			return
		_drop(_stat_spot)
	if _still.size() == 2 and _still[0] != "" and _t >= _still[1]:
		get_viewport().get_texture().get_image().save_png(_still[0])
		get_tree().quit()
