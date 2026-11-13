class_name BugCatch
extends MiniGame

class Bug:
	extends Control
	signal squashed
	var vel := Vector2.ZERO
	var dead := false

	func _ready() -> void:
		size = Vector2(70, 70)
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var c := size * 0.5
		var ang := vel.angle() + PI * 0.5
		draw_set_transform(c, ang, Vector2.ONE * 1.5)
		for s in [-1.0, 1.0]:
			for k in 3:
				draw_line(Vector2(s * 8, -6 + k * 7), Vector2(s * 17, -9 + k * 9), Color("2a2224"), 2.5, true)
		draw_circle(Vector2(0, 3), 13.0, Color("e0453c"), true, -1.0, true)
		draw_circle(Vector2(0, -11), 7.0, Color("2a2224"), true, -1.0, true)
		draw_line(Vector2(0, -8), Vector2(0, 15), Color("2a2224"), 2.0, true)
		for p in [Vector2(-6, 0), Vector2(6, 2), Vector2(-5, 9), Vector2(5, 10)]:
			draw_circle(p, 2.6, Color("2a2224"), true, -1.0, true)

	func _gui_input(e: InputEvent) -> void:
		if dead:
			return
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			dead = true
			squashed.emit()
			var tw := create_tween().set_parallel()
			tw.tween_property(self, "scale", Vector2(1.5, 0.3), 0.12)
			tw.tween_property(self, "modulate:a", 0.0, 0.35)

var total := 6
var caught := 0
var _bugs: Array = []
var _count: Label

func _build(area: Control) -> void:
	total = 8 if hard else 6
	duration = 26.0
	_left = duration
	var code := RichTextLabel.new()
	code.bbcode_enabled = true
	code.scroll_active = false
	code.mouse_filter = Control.MOUSE_FILTER_IGNORE
	code.size = MiniGame.AREA
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Menlo", "monospace"])
	code.add_theme_font_override("normal_font", mono)
	code.add_theme_font_size_override("normal_font_size", 17)
	code.add_theme_color_override("default_color", Color("8a93a6"))
	var bg := ColorRect.new()
	bg.color = Color("1e222a")
	bg.size = MiniGame.AREA
	bg.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			fumble())
	area.add_child(bg)
	var lines := ""
	for i in 18:
		lines += "%2d   %s\n" % [i + 1, ["if (!mesh) return;", "auto* s = cache_.find(id);", "ctx.draw(item.mesh);",
			"for (auto& item : items_) {", "LOG_WARN(\"missing %u\", id);", "}", "[color=#f0636b]error: undefined reference[/color]",
			"items_.clear();"][i % 8]]
	code.text = lines
	area.add_child(code)
	_count = label("", 22, Color("e3e7ee"))
	_count.position = Vector2(MiniGame.AREA.x - 230, 8)
	area.add_child(_count)
	var speed := 150.0 * (1.0 + 0.9 * difficulty) * (1.15 if hard else 1.0)
	for i in total:
		var b := Bug.new()
		b.position = Vector2(randf_range(40, MiniGame.AREA.x - 90), randf_range(40, MiniGame.AREA.y - 90))
		b.vel = Vector2.from_angle(randf() * TAU) * speed * randf_range(0.8, 1.2)
		b.squashed.connect(_on_squash)
		area.add_child(b)
		_bugs.append(b)
	_show()

func _on_squash() -> void:
	caught += 1
	_show()
	if caught >= total:
		done(1.0)

func _show() -> void:
	_count.text = Lang.t("MG_BUGS", {"n": caught, "t": total})

func _tick(delta: float) -> void:
	for b in _bugs:
		var g: Bug = b
		if g.dead:
			continue
		if randf() < delta * 0.8:
			g.vel = g.vel.rotated(randf_range(-1.4, 1.4))
		g.position += g.vel * delta
		if g.position.x < 0 or g.position.x > MiniGame.AREA.x - g.size.x:
			g.vel.x = -g.vel.x
			g.position.x = clampf(g.position.x, 0, MiniGame.AREA.x - g.size.x)
		if g.position.y < 0 or g.position.y > MiniGame.AREA.y - g.size.y:
			g.vel.y = -g.vel.y
			g.position.y = clampf(g.position.y, 0, MiniGame.AREA.y - g.size.y)
		g.queue_redraw()

func timeout_score() -> float:
	return float(caught) / total
