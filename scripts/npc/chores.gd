class_name Chores
extends RefCounted

const JOBS := {
	"sweep": {"tool": "choi_tre", "start": "Tool_Sweep_Start", "loop": "Tool_Sweep_Keep", "stop": "Tool_Sweep_Stop"},

	"rake": {"tool": "cao_thoc", "start": "Tool_Rake_Start", "loop": "Tool_Rake_Keep", "stop": "Tool_Rake_Stop",
		"fx": Color(0.93, 0.80, 0.42)},

	"water": {"tool": "binh_tuoi", "once": "Tool_Water_Pour", "fx": Color(0.75, 0.89, 0.95)},

	"feed": {"tool": "ro_thoc", "once": "Tool_Grain_Scatter", "fx": Color(0.91, 0.76, 0.35)},
}
const SMALL_AFTER := 10.0
const BIG_AFTER := 30.0

const SMALL := {"binh_thuong": ["Act_LookAround", "Wait_ScratchHead"], "vui": ["Wait_Hum", "emote:happy"],
	"met": ["Act_Stretch", "emote:sigh"]}
const BIG := {"binh_thuong": ["Wait_Nails"], "vui": ["emote:laugh"], "met": ["doze"]}
const CLIP_FX := {"Wait_Hum": ["note", 14]}
const TOOL_CLIPS := "res://data/tool_clips.json"

const LAID := Vector3(-0.16, -0.75, 0.05)

static var _events := {}

static func events(clip: String) -> Dictionary:
	if _events.is_empty() and FileAccess.file_exists(TOOL_CLIPS):
		var d = JSON.parse_string(FileAccess.get_file_as_string(TOOL_CLIPS))
		if d is Dictionary:
			_events = d.get("_events", {})
	return _events.get(clip, {})

static func _always() -> bool:
	return true

static func _wait(c: Chibi, secs: float, alive: Callable) -> bool:
	var left := secs
	while left > 0.0:
		await c.get_tree().process_frame
		if not alive.call():
			return false
		left -= c.get_process_delta_time()
	return true

static func run(c: Chibi, job: String, strokes: int, alive: Callable = _always, on_event: Callable = Callable()) -> bool:
	"""on_event(world point): where the chore's stuff lands (the grain flung: the hens come to it)."""
	var j: Dictionary = JOBS[job]
	pick_up(c, j["tool"])
	if j.has("once"):
		for k in strokes:
			if not await _pour(c, j, alive, on_event):
				return false
		c.play("Base_Wait", 0.15)
		return true
	var rest: bool = MoodLayer.moods().get(MoodLayer.mood_of(c), {}).get("rest_mid_chore", false) and strokes >= 4
	var parts := [strokes / 2, strokes - strokes / 2] if rest else [strokes]
	for k in parts.size():
		if k > 0:
			await _gesture(c, "emote:sigh", alive)
		if not await _one_shot(c, j["start"], alive):
			return false
		if not await _strokes(c, j["loop"], parts[k], alive, j.get("fx", Color(0.86, 0.80, 0.68))):
			return false
		if not await _one_shot(c, j["stop"], alive):
			return false
	c.play("Base_Wait", 0.1)
	return true

static func _pour(c: Chibi, j: Dictionary, alive: Callable, on_event: Callable = Callable()) -> bool:
	"""One go of a one-shot chore; the water (fx) falls where the rose points while it pours, the grain where
	each flick throws it."""
	var clip: String = j["once"]
	var ev := events(clip)
	var flicks: Array = ev.get("flicks", [])
	var hands: Array = ev.get("hand_at_flicks", [])
	var flung := 0
	var t0 := float(ev.get("water_start", -1)) / 30.0
	var t1 := float(ev.get("water_end", -1)) / 30.0
	if not c.anim.has_animation(clip):
		return true
	c.anim.play(clip, 0.12)
	var length := c.anim.get_animation(clip).length
	var next := t0
	while c.anim.current_animation == clip and c.anim.current_animation_position < length - 0.04:
		await c.get_tree().process_frame
		if not alive.call():
			return false
		var pos := c.anim.current_animation_position
		if flung < flicks.size() and pos >= float(flicks[flung]) / 30.0:
			var h: Array = hands[flung] if flung < hands.size() else [0.2, 0.7, 0.35]
			var land := c.to_global(Vector3(h[0] * 1.6, 0.03, h[2] + 0.55))
			_dust(c, land, j["fx"])
			if on_event.is_valid():
				on_event.call(land)
			flung += 1
		if j.has("fx") and t0 >= 0.0 and pos >= next and pos <= t1:
			next = pos + 0.25
			var at: Array = ev.get("rose_mid_pour", [0, 0, 0.6])
			_dust(c, c.to_global(Vector3(at[0], 0.03, at[2])), j["fx"])
	return true

static func _strokes(c: Chibi, loop: String, n: int, alive: Callable, col := Color(0.86, 0.80, 0.68)) -> bool:
	c.anim.play(loop, 0.05)
	var ev := events(loop)
	var fx_t := float(ev.get("dust", [-1])[0]) / 30.0
	var done := 0
	var prev := 0.0
	while done < n:
		await c.get_tree().process_frame
		if not alive.call():
			return false
		var pos := c.anim.current_animation_position
		if pos < prev:
			done += 1
		elif fx_t >= 0.0 and prev < fx_t and pos >= fx_t:
			var at: Array = ev.get("tip_at_dust", [0, 0, 1])
			_dust(c, c.to_global(Vector3(at[0], 0.04, at[2])), col)
		prev = pos
	return true

static func _one_shot(c: Chibi, clip: String, alive: Callable) -> bool:
	"""Play a clip once and wait for its end, at whatever speed the mood plays it."""
	if not c.anim.has_animation(clip):
		return true
	c.anim.play(clip, 0.12)
	var length := c.anim.get_animation(clip).length
	while c.anim.current_animation == clip and c.anim.current_animation_position < length - 0.04:
		await c.get_tree().process_frame
		if not alive.call():
			return false
	return true

static func put_down(c: Chibi) -> void:
	"""Lay the tool in hand on the ground by the right foot (a still copy of it), the hands free."""
	if c.tool == "" or c.has_meta("laid_tool"):
		return
	var laid := Node3D.new()
	c.get_parent().add_child(laid)
	laid.global_transform = c.global_transform * Transform3D(Basis(), LAID)
	for mi in c.parts.get("tool", []):
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		for s in mi.mesh.get_surface_count():
			copy.set_surface_override_material(s, mi.get_surface_override_material(s))
		laid.add_child(copy)
	c.set_meta("laid_tool", laid)
	c.set_meta("laid_name", c.tool)
	c.hold("")
	_dust(c, laid.global_position + c.global_basis * Vector3(-0.53, 0.0, 0.4))

static func pick_up(c: Chibi, tool: String) -> void:
	if c.has_meta("laid_tool"):
		var laid: Node3D = c.get_meta("laid_tool")
		_dust(c, laid.global_position + c.global_basis * Vector3(-0.53, 0.0, 0.4))
		laid.queue_free()
		c.remove_meta("laid_tool")
	if c.tool != tool:
		c.hold(tool)

static func idle(c: Chibi, secs: float, alive: Callable = _always) -> bool:
	"""Stand about for secs, the tool laid down: a small gesture after 10 s, a big one after 30 s."""
	put_down(c)
	var t := 0.0
	var small_done := false
	var big_done := false
	c.play("Base_Wait", 0.2)
	while t < secs:
		await c.get_tree().process_frame
		if not alive.call():
			return false
		t += c.get_process_delta_time()
		var mood := MoodLayer.mood_of(c)
		if not small_done and t >= SMALL_AFTER:
			small_done = true
			var pick: Array = SMALL.get(mood, SMALL["binh_thuong"]).duplicate()
			if ChainSway.wears(c.skel, "Day_L"):
				pick.erase("Wait_Hum")
			t += await _gesture(c, pick.pick_random(), alive)
		elif not big_done and t >= BIG_AFTER:
			big_done = true
			t += await _gesture(c, BIG.get(mood, BIG["binh_thuong"]).pick_random(), alive)
	return true

static func _gesture(c: Chibi, g: String, alive: Callable) -> float:
	"""Play one gesture; returns how long it took (game time)."""
	var took := [0.0]
	var tick := func(): took[0] += c.get_process_delta_time()
	c.get_tree().process_frame.connect(tick)
	if g.begins_with("emote:"):
		var kind := g.trim_prefix("emote:")
		c.emote(kind)
		var clip := str(Chibi.emotes.get(kind, {}).get("clip", ""))
		if clip != "":
			await _one_shot(c, clip, alive)
		else:
			await _wait(c, 1.5, alive)
	elif g == "doze":
		await _one_shot(c, "Emo_Sleepy", alive)
		c.anim.play("Wait_Doze", 0.2)
		EmoteFx.play(c, "z")
		await _wait(c, 5.0, alive)
	else:
		if CLIP_FX.has(g):
			EmoteFx.play(c, CLIP_FX[g][0], float(CLIP_FX[g][1]) / 30.0)
		await _one_shot(c, g, alive)
	c.get_tree().process_frame.disconnect(tick)
	c.play("Base_Wait", 0.2)
	return took[0]

static func _dust(c: Chibi, p: Vector3, col := Color(0.86, 0.80, 0.68)) -> void:
	"""A small puff of dust (or of water drops: col): three soft billboards that swell and fade."""
	for i in 3:
		var s := Sprite3D.new()
		s.texture = _puff_tex()
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.shaded = false
		s.transparent = true
		s.pixel_size = 0.004
		s.modulate = Color(col.r, col.g, col.b, 0.0)
		c.get_parent().add_child(s)
		s.global_position = p + Vector3(randf_range(-0.12, 0.12), 0.03 * i, randf_range(-0.08, 0.08))
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "modulate:a", 0.55, 0.12).set_delay(0.04 * i)
		tw.tween_property(s, "pixel_size", 0.009, 0.7).set_delay(0.04 * i)
		tw.tween_property(s, "position:y", s.position.y + 0.18, 0.7).set_delay(0.04 * i)
		tw.chain().tween_property(s, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(s.queue_free)

static var _puff: Texture2D

static func _puff_tex() -> Texture2D:
	if _puff == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_puff = t
	return _puff
