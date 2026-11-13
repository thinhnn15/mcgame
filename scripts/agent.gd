extends Node

const PORT := 47990

var enabled := false
var quiet := false
var port := PORT
var token := ""
var server: TCPServer
var conns: Array = []
var cam_override := {}
var rec := {}

func _ready() -> void:
	process_priority = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if not "--mcp" in OS.get_cmdline_user_args() and OS.get_environment("MCGAME_MCP") != "1":
		return
	if OS.has_feature("template") and not OS.is_debug_build():
		push_warning("[mcp] not available in a release build")
		return
	token = Crypto.new().generate_random_bytes(16).hex_encode()
	server = TCPServer.new()
	var first := int(Stage.arg("--mcp-port", str(PORT)))
	port = -1
	for p in range(first, first + 4):
		if server.listen(p, "127.0.0.1") == OK:
			port = p
			break
	if port < 0:
		push_warning("[mcp] no free port from %d" % first)
		return
	var f := FileAccess.open("user://mcp_%d.json" % port, FileAccess.WRITE)
	f.store_string(JSON.stringify({"port": port, "token": token, "pid": OS.get_process_id()}))
	f.close()
	enabled = true
	set_process(true)
	if "--mcp-quiet" in OS.get_cmdline_user_args():
		quiet = true
		get_viewport().gui_disable_input = true
		get_window().unfocusable = true
	print("[mcp] listening on 127.0.0.1:%d" % port)

func _exit_tree() -> void:
	if enabled:
		if not rec.is_empty():
			_record_stop_now()
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://mcp_%d.json" % port))

func _process(delta: float) -> void:
	while server.is_connection_available():
		conns.append({"peer": server.take_connection(), "buf": PackedByteArray(), "age": 0.0})
	for c in conns.duplicate():
		var peer: StreamPeerTCP = c["peer"]
		peer.poll()
		c["age"] += delta
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED or c["age"] > 10.0:
			conns.erase(c)
			continue
		var n := peer.get_available_bytes()
		if n > 0:
			c["buf"].append_array(peer.get_data(n)[1])
		var req := _parse(c["buf"])
		if not req.is_empty():
			conns.erase(c)
			_serve(peer, req)
	_camera()

static func _parse(buf: PackedByteArray) -> Dictionary:
	"""A whole HTTP request out of the bytes so far, or {} while it is still arriving."""
	var end := -1
	for i in range(buf.size() - 3):
		if buf[i] == 13 and buf[i + 1] == 10 and buf[i + 2] == 13 and buf[i + 3] == 10:
			end = i
			break
	if end < 0:
		return {}
	var lines := buf.slice(0, end).get_string_from_utf8().split("\r\n")
	var first := lines[0].split(" ")
	var headers := {}
	for l in lines.slice(1):
		headers[l.get_slice(":", 0).strip_edges().to_lower()] = l.substr(l.find(":") + 1).strip_edges()
	var body := buf.slice(end + 4)
	if body.size() < int(headers.get("content-length", "0")):
		return {}
	return {"method": first[0], "path": first[1] if first.size() > 1 else "/", "headers": headers,
		"body": body.get_string_from_utf8()}

func _serve(peer: StreamPeerTCP, req: Dictionary) -> void:
	var out: Dictionary
	var code := 200
	if req["headers"].get("x-token", "") != token:
		out = {"ok": false, "error": "bad token"}
		code = 403
	elif req["path"] == "/status":
		out = _status()
	elif req["path"] == "/cmd":
		var j = JSON.parse_string(req["body"])
		if j is Dictionary and j.has("cmd"):
			var args = j.get("args", {})
			out = await _run(str(j["cmd"]), args if args is Dictionary else {})
		else:
			out = {"ok": false, "error": "body must be {\"cmd\": ..., \"args\": {...}}"}
			code = 400
	else:
		out = {"ok": false, "error": "unknown path"}
		code = 404
	var body := JSON.stringify(out).to_utf8_buffer()
	var head := "HTTP/1.1 %d %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" \
		% [code, "OK" if code == 200 else "Error", body.size()]
	peer.put_data(head.to_utf8_buffer())
	peer.put_data(body)
	peer.disconnect_from_host()

func _run(cmd: String, a: Dictionary) -> Dictionary:
	var p := _player()
	match cmd:
		"status":
			return _status()
		"screenshot":
			return await _screenshot(int(a.get("height", 540)))
		"scenes":
			var names := []
			for f in DirAccess.get_files_at("res://scenes"):
				if f.ends_with(".tscn"):
					names.append(f.get_basename())
			return {"ok": true, "scenes": names}
		"scene":
			return await _change_scene(str(a.get("name", "")))
		"time_scale":
			Engine.time_scale = clampf(float(a.get("scale", 1.0)), 0.0, 8.0)
			return {"ok": true, "time_scale": Engine.time_scale}
		"pause":
			get_tree().paused = bool(a.get("on", true))
			return {"ok": true, "paused": get_tree().paused}
		"camera":
			return _set_camera(a)
		"net":
			return await _net(a)
		"click":
			return await _click(Vector2(float(a.get("x", 0.5)), float(a.get("y", 0.5))), bool(a.get("press", true)))
		"key":
			return await _key(str(a.get("key", "")))
		"ui":
			return _ui()
		"screen_point":
			var c := get_viewport().get_camera_3d()
			var w := Vector3(float(a.get("x", 0)), float(a.get("y", 0)), float(a.get("z", 0)))
			if c == null or c.is_position_behind(w):
				return {"ok": false, "error": "not in front of the camera"}
			var sp := c.unproject_position(w) / get_viewport().get_visible_rect().size
			return {"ok": true, "x": snappedf(sp.x, 0.001), "y": snappedf(sp.y, 0.001)}
		"npcs":
			var list := []
			for n in _npcs():
				list.append({"id": n.id, "pos": _v(n.global_position), "sitting": n.sitting})
			return {"ok": true, "npcs": list}
		"npc":
			return await _npc(a)
		"record_start":
			return _record_start(str(a.get("name", "")), int(a.get("fps", 30)), int(a.get("height", 1080)))
		"record_stop":
			return await _record_stop()
		"quit":
			get_tree().quit.call_deferred()
			return {"ok": true}

	if p == null:
		return {"ok": false, "error": "no player in this scene (%s)" % _scene_name()}
	match cmd:
		"walk":
			var d := Vector3(float(a.get("dx", 0)), 0, float(a.get("dz", 0)))
			if d.length() < 0.01:
				return {"ok": false, "error": "dx/dz is zero"}
			var from := p.global_position
			p.stop_going()
			p.steer = d.limit_length(1.0)
			p.steer_run = bool(a.get("run", false))
			await get_tree().create_timer(clampf(float(a.get("seconds", 1.0)), 0.0, 30.0)).timeout
			if is_instance_valid(p):
				p.steer = Vector3.ZERO

				return {"ok": true, "pos": _v(p.global_position), "moved": snappedf(p.global_position.distance_to(from), 0.01)}
			return {"ok": false, "error": "the player went away (scene change?)"}
		"walk_to":
			return await _walk_to(p, Vector3(float(a.get("x", 0)), 0, float(a.get("z", 0))), bool(a.get("run", false)),
				float(a.get("timeout", 20)))
		"stop":
			p.stop_going()
			p.auto_move = Vector2.ZERO
			return {"ok": true}
		"face":
			var yaw := deg_to_rad(float(a.get("yaw", 0)))
			if a.has("x") and a.has("z"):
				var to := Vector3(float(a["x"]), 0, float(a["z"])) - p.global_position
				yaw = atan2(to.x, to.z)
			p.facing = yaw
			p.rotation.y = yaw
			return {"ok": true, "yaw": snappedf(rad_to_deg(yaw), 0.1)}
		"teleport":
			p.global_position = Vector3(float(a.get("x", 0)), float(a.get("y", p.global_position.y)), float(a.get("z", 0)))
			p.velocity = Vector3.ZERO
			return {"ok": true, "pos": _v(p.global_position)}
		"emote":
			var kind := str(a.get("kind", "wave"))
			var known: Array = _unique(p.chibi.EMOTES.keys() + p.chibi.emotes.keys())
			if not known.has(kind):
				return {"ok": false, "error": "unknown emote", "emotes": known}
			Net.act("emote", kind)
			return {"ok": true}
		"sit":
			p.set_sitting(bool(a.get("on", true)))
			return {"ok": true, "sitting": p.sitting}
		"hold":
			p.chibi.hold(str(a.get("tool", "")))
			return {"ok": true, "tool": p.chibi.tool}
		"use_tool":
			if p.chibi.tool == "" or p.busy():
				return {"ok": false, "error": "nothing in hand" if p.chibi.tool == "" else "busy"}
			p.tool_pressed.emit()
			return {"ok": true}
		"clip":
			var clip := str(a.get("name", ""))
			if not p.chibi.anim.has_animation(clip):
				return {"ok": false, "error": "unknown clip", "clips": Array(p.chibi.anim.get_animation_list())}
			if bool(a.get("loop", false)):
				p.chibi.play(clip, 0.2)
			else:
				p.chibi.anim.play(clip, 0.15)
				p.chibi.anim.queue(p.chibi._base_clip)
			return {"ok": true}
		"look":
			return {"ok": true, "look": p.chibi.look}
		"set_look":
			var look: Dictionary = p.chibi.look.duplicate(true)
			var patch = a.get("look", {})
			if patch is Dictionary:
				for k in patch:
					if patch[k] is Dictionary and look.get(k) is Dictionary:
						look[k].merge(patch[k], true)
					else:
						look[k] = patch[k]
			look = Looks.from(look)
			p.chibi.apply_look(look)
			if bool(a.get("save", false)):
				Looks.save(look)
			Net.set_look(look)
			return {"ok": true, "look": look}
	return {"ok": false, "error": "unknown command: " + cmd}

func _status() -> Dictionary:
	var p := _player()
	var c := get_viewport().get_camera_3d()
	var st := {"ok": true, "scene": _scene_name(), "fps": Engine.get_frames_per_second(),
		"time_scale": Engine.time_scale, "paused": get_tree().paused, "recording": not rec.is_empty(),
		"window": [get_viewport().size.x, get_viewport().size.y],
		"net": {"mode": Net.Mode.keys()[Net.mode], "my_id": Net.my_id(),
			"players": Net.players.keys().map(func(id): return {"id": id, "name": Net.players[id]["name"]})}}
	if p:
		st["player"] = {"pos": _v(p.global_position), "yaw": snappedf(rad_to_deg(p.facing), 0.1),
			"clip": p.chibi._base_clip, "playing": p.chibi.anim.current_animation, "sitting": p.sitting,
			"tool": p.chibi.tool, "busy": p.busy()}
	if c:
		st["camera"] = {"pos": _v(c.global_position), "forward": _v(-c.global_transform.basis.z), "fov": c.fov,
			"override": cam_override.get("mode", "")}
	return st

func _walk_to(p: Player, goal: Vector3, run: bool, timeout: float) -> Dictionary:
	var result := await p.go_to(goal, run, 0.15, timeout)
	if not is_instance_valid(p):
		return {"ok": false, "error": "the player went away (scene change?)"}
	return {"ok": result == "arrived", "result": result, "pos": _v(p.global_position),
		"left": snappedf(Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z).length(), 0.01)}

func _change_scene(name: String) -> Dictionary:
	if not name.is_valid_filename():
		return {"ok": false, "error": "bad scene name"}
	var path := "res://scenes/%s.tscn" % name
	if not ResourceLoader.exists(path):
		return {"ok": false, "error": "no scene " + name}
	var old := get_tree().current_scene
	get_tree().change_scene_to_file(path)
	for i in 600:
		await get_tree().process_frame
		var cur := get_tree().current_scene
		if cur and cur != old and cur.is_node_ready():
			await get_tree().process_frame
			cam_override = {}
			return {"ok": true, "scene": name}
	return {"ok": false, "error": "scene did not load in time"}

func _screenshot(height: int) -> Dictionary:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if height > 0 and height < img.get_height():
		img.resize(img.get_width() * height / img.get_height(), height, Image.INTERPOLATE_BILINEAR)
	return {"ok": true, "width": img.get_width(), "height": img.get_height(),
		"png": Marshalls.raw_to_base64(img.save_png_to_buffer())}

func _click(at: Vector2, press: bool) -> Dictionary:
	"""Point at a spot of the window (0..1 each way) and left-click there, like a player."""
	var pos := at.clamp(Vector2.ZERO, Vector2.ONE) * Vector2(DisplayServer.window_get_size())

	get_viewport().gui_disable_input = false
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	Input.parse_input_event(mm)
	for i in 3:
		await get_tree().process_frame
	if press:
		for down in [true, false]:
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			mb.pressed = down
			mb.position = pos
			mb.global_position = pos
			Input.parse_input_event(mb)
			await get_tree().process_frame
	var hovered := get_viewport().gui_get_hovered_control()
	get_viewport().gui_disable_input = quiet
	return {"ok": true, "window_px": [int(pos.x), int(pos.y)], "over_ui": hovered != null}

func _key(name: String) -> Dictionary:
	"""Press and release one key, like a player (e.g. "T", "P", "Escape", "Space", "1")."""
	var code := OS.find_keycode_from_string(name)
	if code == KEY_NONE:
		return {"ok": false, "error": "unknown key " + name}
	get_viewport().gui_disable_input = false
	for down in [true, false]:
		var k := InputEventKey.new()
		k.keycode = code
		k.physical_keycode = code
		k.pressed = down
		Input.parse_input_event(k)
		await get_tree().process_frame
	get_viewport().gui_disable_input = quiet
	return {"ok": true}

func _ui() -> Dictionary:
	"""What a player could click right now: visible buttons and hand-cursor controls (text, rect 0..1),
	the visible named UI (script classes) and the visible labels' text."""
	var vs := get_viewport().get_visible_rect().size
	var items := []
	var panels := {}
	var texts := []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem and not (n as CanvasItem).visible:
			continue
		if (n is CanvasLayer and not (n as CanvasLayer).visible) or n is SubViewport:
			continue
		stack.append_array(n.get_children())
		if not (n is Control):
			continue
		var c := n as Control
		var s: Script = c.get_script()
		if s and s.get_global_name() != "":
			panels[str(s.get_global_name())] = true
		if c is Label and (c as Label).text != "" and c.modulate.a > 0.05:
			texts.append((c as Label).text)
		var clickable := (c is BaseButton and not (c as BaseButton).disabled) or \
			(c.mouse_filter == Control.MOUSE_FILTER_STOP and c.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)
		if not clickable or c.modulate.a < 0.05:
			continue
		var r := c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)
		items.append({"cls": c.get_class(), "text": (c as Button).text if c is Button else "",
			"rect": [snappedf(r.position.x / vs.x, 0.001), snappedf(r.position.y / vs.y, 0.001),
				snappedf(r.size.x / vs.x, 0.001), snappedf(r.size.y / vs.y, 0.001)]})
	return {"ok": true, "items": items, "panels": panels.keys(), "texts": texts}

func _set_camera(a: Dictionary) -> Dictionary:
	var mode := str(a.get("mode", "scene"))
	match mode:
		"scene":
			cam_override = {}
		"fixed":
			cam_override = {"mode": "fixed", "pos": _vec(a.get("pos", [0, 3, 6])), "at": _vec(a.get("at", [0, 0.7, 0]))}
		"follow":
			cam_override = {"mode": "follow", "offset": _vec(a.get("offset", [0, 4.6, 6]))}
		_:
			return {"ok": false, "error": "mode is scene | fixed | follow"}
	var c := get_viewport().get_camera_3d()
	if a.has("fov") and c:
		c.fov = clampf(float(a["fov"]), 10.0, 100.0)
	var scene := get_tree().current_scene
	if a.has("dist") and scene and "cam_dist" in scene:
		scene.cam_dist = float(a["dist"])
	return {"ok": true, "mode": mode}

func _camera() -> void:
	if cam_override.is_empty():
		return
	var c := get_viewport().get_camera_3d()
	if c == null:
		return
	if cam_override["mode"] == "fixed":
		c.global_position = cam_override["pos"]
		c.look_at(cam_override["at"], Vector3.UP)
	else:
		var p := _player()
		if p:
			var target := p.global_position + Vector3(0, 0.7, 0)
			c.global_position = target + cam_override["offset"]
			c.look_at(target, Vector3.UP)

func _net(a: Dictionary) -> Dictionary:
	match str(a.get("action", "")):
		"host":
			return {"ok": Net.host(), "addresses": Net.lan_addresses()}
		"join":
			Net.join(str(a.get("address", "127.0.0.1")))
			for i in 300:
				await get_tree().process_frame
				if Net.mode == Net.Mode.CLIENT:
					return {"ok": true, "host": Net.host_name()}
				if not multiplayer.multiplayer_peer is ENetMultiplayerPeer:
					break
			return {"ok": false, "error": "could not reach that village"}
		"leave":
			Net.leave()
			return {"ok": true}
		"name":
			Net.set_my_name(str(a.get("name", "")))
			return {"ok": true, "name": Net.my_name}
	return {"ok": false, "error": "action is host | join | leave | name"}

func _npc(a: Dictionary) -> Dictionary:
	var npc: Npc = null
	for n in _npcs():
		if n.id == str(a.get("id", "")):
			npc = n
	if npc == null:
		return {"ok": false, "error": "no such npc", "npcs": _npcs().map(func(n): return n.id)}
	npc.interrupt()
	var done := true
	match str(a.get("action", "")):
		"walk_to":
			done = await npc.walk_to(Vector3(float(a.get("x", 0)), 0, float(a.get("z", 0))), bool(a.get("run", false)))
		"face":
			if a.has("x"):
				done = await npc.face_point(Vector3(float(a["x"]), 0, float(a.get("z", 0))))
			else:
				done = await npc.face_dir(deg_to_rad(float(a.get("yaw", 0))))
		"emote":
			done = await npc.emote(str(a.get("kind", "wave")))
		"clip":
			done = await npc.act(str(a.get("name", "")))
		"say":
			npc.say(str(a.get("key", "")), {}, float(a.get("secs", 0)))
		"sit":
			done = await npc.sit_down()
		"stand":
			done = await npc.stand_up()
		"hold":
			npc.hold(str(a.get("tool", "")))
		_:
			return {"ok": false, "error": "action is walk_to | face | emote | clip | say | sit | stand | hold"}
	return {"ok": true, "finished": done, "pos": _v(npc.global_position)}

func _record_start(name: String, fps: int, height: int) -> Dictionary:
	"""Record the game window to user://recordings/<name>.mp4 with ffmpeg."""
	if not rec.is_empty():
		return {"ok": false, "error": "already recording " + rec["path"]}
	if not name.is_valid_filename():
		return {"ok": false, "error": "name must be a plain file name (no folders)"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://recordings"))
	var path := ProjectSettings.globalize_path("user://recordings/%s.mp4" % name.get_basename())
	var img := get_viewport().get_texture().get_image()
	var pix := "rgba" if img.get_format() == Image.FORMAT_RGBA8 else "rgb24"
	var ff := OS.get_environment("FFMPEG")
	var args := ["-y", "-loglevel", "error", "-nostats", "-f", "rawvideo", "-pix_fmt", pix,
		"-s", "%dx%d" % [img.get_width(), img.get_height()], "-r", str(clampi(fps, 1, 60)), "-i", "-"]
	if height > 0 and height != img.get_height():
		args += ["-vf", "scale=-2:%d:flags=lanczos" % height]
	args += ["-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-pix_fmt", "yuv420p", path]
	var r := OS.execute_with_pipe(ff if ff != "" else "ffmpeg", args)
	if r.is_empty():
		return {"ok": false, "error": "could not start ffmpeg (set FFMPEG to its path)"}
	rec = {"path": path, "pipe": r["stdio"], "pid": r["pid"], "fps": clampi(fps, 1, 60), "size": img.get_size(),
		"format": img.get_format(), "t0": Time.get_ticks_usec(), "frames": 0}
	RenderingServer.frame_post_draw.connect(_record_frame)
	return {"ok": true, "path": path, "size": [img.get_width(), img.get_height()]}

func _record_frame() -> void:
	"""Real time: a frame that took longer than 1/fps is written more than once, so the video keeps pace."""
	var img := get_viewport().get_texture().get_image()
	if img.get_size() != rec["size"] or img.get_format() != rec["format"]:
		return
	var due := int((Time.get_ticks_usec() - rec["t0"]) / 1e6 * rec["fps"]) + 1
	var n: int = mini(due - rec["frames"], 4)
	if n <= 0:
		return
	var data := img.get_data()
	for i in n:
		rec["pipe"].store_buffer(data)
	rec["frames"] = due

func _record_stop() -> Dictionary:
	if rec.is_empty():
		return {"ok": false, "error": "not recording"}
	var out := {"ok": true, "path": rec["path"], "frames": rec["frames"],
		"seconds": snappedf(float(rec["frames"]) / rec["fps"], 0.01)}
	var pid: int = rec["pid"]
	_record_stop_now()
	for i in 300:
		if not OS.is_process_running(pid):
			break
		await get_tree().create_timer(0.1, true, false, true).timeout
	return out

func _record_stop_now() -> void:
	RenderingServer.frame_post_draw.disconnect(_record_frame)
	rec["pipe"].close()
	rec = {}

func _player() -> Player:
	var scene := get_tree().current_scene
	if scene and "player" in scene and scene.player is Player and is_instance_valid(scene.player):
		return scene.player
	return null

func _npcs() -> Array:
	var scene := get_tree().current_scene
	return [] if scene == null else scene.find_children("*", "Node3D", true, false).filter(func(n): return n is Npc)

func _scene_name() -> String:
	var scene := get_tree().current_scene
	return "" if scene == null else scene.scene_file_path.get_file().get_basename()

static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]

static func _vec(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and a.size() == 3 else Vector3.ZERO

static func _unique(a: Array) -> Array:
	var out := []
	for x in a:
		if not out.has(x):
			out.append(x)
	return out
