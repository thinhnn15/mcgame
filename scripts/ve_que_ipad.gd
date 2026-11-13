extends Node

const FRONT := Vector2(-700.0, -30.0)

var _film: Node
var _left := 0.0
var _step := 0

func _ready() -> void:
	if Stage.arg("--from") == "walk":
		_walk.call_deferred()
		return
	_play("res://scenes/hanh_trinh.tscn", _secs(load("res://scripts/hanh_trinh.gd").SHOTS))

func _play(path: String, secs: float) -> void:
	_film = load(path).instantiate()
	add_child(_film)
	_left = secs - 0.3

func _secs(shots: Array) -> float:
	var t := 0.0
	for s in shots:
		t += float(s["secs"])
	return t

func _process(delta: float) -> void:
	if _film == null:
		return
	_left -= delta
	if _left > 0.0:
		return
	_film.queue_free()
	_film = null
	_step += 1
	if _step == 1:
		_play("res://scenes/ve_ga.tscn", _secs(load("res://scripts/ve_ga.gd").SHOT_LIST))
		var home: Node = _film.home
		home.show_names = false
		for c in home.get_children():
			if c is CanvasLayer:
				c.visible = false
		for l in home._names:
			l.visible = false
	else:
		_walk.call_deferred()

func _walk() -> void:
	for i in 2:
		await get_tree().process_frame
	var home: Node = load("res://scenes/hometown.tscn").instantiate()
	add_child(home)
	await get_tree().process_frame
	home.player.global_position = Vector3(FRONT.x, home.height_at(FRONT.x, FRONT.y) + 0.8, FRONT.y)
