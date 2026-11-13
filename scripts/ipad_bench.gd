extends Node

const SCENE := "res://scenes/hometown.tscn"
const AT := Vector3(-180.0, 0.0, -6.0)
const SETTLE := 8.0
const SECS := 10.0

var _label: Label
var _lines := PackedStringArray()

var runner := false

func _ready() -> void:
	if not runner:
		var r = get_script().new()
		r.runner = true
		get_tree().root.add_child.call_deferred(r)
		return
	get_tree().root.add_child.call_deferred(_overlay())
	_run.call_deferred()

func _overlay() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 10)
	_label.position = Vector2(30, 30)
	layer.add_child(_label)
	return layer

func _say(s: String) -> void:
	_lines.append(s)
	_label.text = "\n".join(_lines)
	print("IPAD_BENCH ", s)

func _run() -> void:
	_say("Đo iPad: %s (%s)" % [OS.get_model_name(), RenderingServer.get_video_adapter_name()])
	_say("Khởi động engine tới cảnh đầu: %.1f s" % (Time.get_ticks_msec() / 1000.0))
	for k in 2:
		var tc := Time.get_ticks_usec()
		var c := Chibi.new()
		get_tree().root.add_child(c)
		var look := Looks.DEFAULT.duplicate(true)
		look["apron"] = "#6f8fae"
		c.build(look)
		_say("Dựng 1 nhân vật (%s): %.0f ms" % ["lần đầu" if k == 0 else "lần hai", (Time.get_ticks_usec() - tc) / 1000.0])
		c.queue_free()
		await get_tree().process_frame
	var t0 := Time.get_ticks_msec()
	get_tree().change_scene_to_file(SCENE)
	while get_tree().current_scene == null or get_tree().current_scene.scene_file_path != SCENE:
		await get_tree().process_frame
	var t1 := Time.get_ticks_msec()

	var slow := 0
	var slow_ms := 0.0
	var worst := 0.0
	var t := 0.0
	while t < 6.0:
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d
		if d > 0.05:
			slow += 1
			slow_ms += d * 1000.0
		worst = maxf(worst, d * 1000.0)
	_say("Nạp màn quê: %.1f s, rồi 6 s đầu: %d khung hình giật (tổng %.1f s, lâu nhất %.0f ms)" % [
		(t1 - t0) / 1000.0, slow, slow_ms / 1000.0, worst])
	var home := get_tree().current_scene
	var player = home.get("player")
	if player:
		player.global_position = AT + Vector3(0, home.height_at(AT.x, AT.z) + 0.2, 0)
	await get_tree().create_timer(2.0).timeout
	var a := await _measure()
	_say("Có người làng:   %s" % _fmt(a))
	var vl := home.get_node_or_null("VillageLife")
	if vl:
		vl.queue_free()
	await get_tree().create_timer(3.0).timeout
	var b := await _measure()
	_say("Không người làng: %s" % _fmt(b))
	_say("Người làng tốn: %+.2f ms khung hình, %+.2f ms GPU, %+d lần vẽ, %+d tam giác" % [
		a[0] - b[0], a[1] - b[1], int(a[2] - b[2]), int(a[3] - b[3])])
	var f := FileAccess.open("user://ipad_bench.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_lines))
	_say("Xong. Chụp màn hình gửi mình nhé.")

func _measure() -> Array:
	"""[frame ms, gpu ms, draws, triangles] averaged over SECS."""
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var n := 0
	var ft := 0.0
	var gpu := 0.0
	var dr := 0.0
	var tr := 0.0
	var t := 0.0
	while t < SECS:
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d
		if n > 0:
			ft += d * 1000.0
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			dr += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			tr += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		n += 1
	var k := maxf(1.0, n - 1)
	return [ft / k, gpu / k, dr / k, tr / k]

func _fmt(m: Array) -> String:
	return "%.1f ms (%.0f fps), GPU %.1f ms, %d lần vẽ, %dk tam giác" % [m[0], 1000.0 / maxf(m[0], 0.01), m[1], int(m[2]), int(m[3] / 1000.0)]
