class_name LookThumbs
extends Node

const PX := Vector2i(176, 176)

const FRAMES := {
	"head": [Vector3(0.0, 1.18, 2.0), Vector3(0.0, 1.1, 0.0), 30.0],
	"body": [Vector3(0.0, 0.7, 2.7), Vector3(0.0, 0.62, 0.0), 30.0],
	"feet": [Vector3(0.0, 0.42, 1.6), Vector3(0.0, 0.14, 0.0), 30.0],
}

var _vp: SubViewport
var _cam: Camera3D
var _twin: Chibi
var _queue: Array = []
var _busy := false

func _ready() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.size = PX
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.mesh_lod_threshold = 0.0
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var root := Node3D.new()
	_vp.add_child(root)
	Stage.setup(root)
	var we := root.find_child("WorldEnvironment", false, false) as WorldEnvironment
	we.environment = we.environment.duplicate()
	we.environment.background_mode = Environment.BG_CLEAR_COLOR
	we.environment.ssao_enabled = false
	_cam = Camera3D.new()
	root.add_child(_cam)
	_twin = Chibi.new()
	root.add_child(_twin)
	_twin.rotation.y = deg_to_rad(-14.0)

func request(look: Dictionary, frame: String, done: Callable) -> void:
	_queue.push_front([look.duplicate(true), frame, done])
	if not _busy:
		_run()

func clear() -> void:
	_queue.clear()

func _run() -> void:
	_busy = true
	if _twin.body == null:
		_twin.build(_queue[0][0])
		_twin.play("Base_Wait", 0.0)
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		var f: Array = FRAMES.get(job[1], FRAMES["body"])
		_cam.position = f[0]
		_cam.look_at(f[1], Vector3.UP)
		_cam.fov = f[2]
		_twin.apply_look(job[0])
		_twin.anim.seek(0.4, true)
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		if (job[2] as Callable).is_valid():
			(job[2] as Callable).call(ImageTexture.create_from_image(img))
	_busy = false
