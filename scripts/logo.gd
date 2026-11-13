extends Control

const TITLE := "res://scenes/title.tscn"
const FADE := 0.4
const HOLD := 1.4

var _done := false

func _ready() -> void:
	var logo: TextureRect = $Logo
	var w := size.x * 0.45
	logo.size = Vector2(w, w * logo.texture.get_height() / logo.texture.get_width())
	logo.position = (size - logo.size) / 2.0
	logo.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(logo, "modulate:a", 1.0, FADE)
	tw.tween_interval(HOLD)
	tw.tween_property(logo, "modulate:a", 0.0, FADE)
	tw.tween_callback(_go)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_pressed() and (e is InputEventKey or e is InputEventMouseButton or e is InputEventScreenTouch or e is InputEventJoypadButton):
		_go()

func _go() -> void:
	if _done:
		return
	_done = true
	get_tree().change_scene_to_file(TITLE)
