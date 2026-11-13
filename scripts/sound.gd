extends Node

const EVENTS := "res://data/audio/events.json"
const STEPS := "res://data/step_timelines.json"
const AUDIO := "res://audio/"
const CFG := "user://settings.cfg"

const BUSES := [
	["Music", "Master"], ["Radio", "Music"],
	["Ambience", "Master"], ["Ambience_Out", "Ambience"], ["Ambience_In", "Ambience"],
	["SFX", "Master"], ["UI", "Master"], ["Voice", "Master"], ["Mic", "Master"],
	["Reverb_Room", "SFX"], ["Reverb_Big", "SFX"],
]
const SLIDERS := ["Master", "Music", "Ambience", "SFX", "UI", "Voice"]
const POOL := {"high": [12, 20], "medium": [10, 16], "low": [8, 12]}
const EAR_HEIGHT := 1.2
const NPC_STEP_RANGE := 12.0
const NPC_STEPS_MAX := 3
const NPC_STEP_DB := -4.0
const HERO_STEP_DB := -1.5
const RUN_DB := 3.0
const DUCK_FLOOR := -24.0
const EXTRA_DIST := Vector2(3.0, 7.0)
const NOTIFY_CLEAR := 2.0
const NOTIFY_DUCK := -4.0
const NOTIFY_HOLD := 1.5
const FPS := 30.0

var events := {}
var beds := {}
var surfaces := {}
var hero: Node3D
var log_sounds := false
var _groups_off := {}
var _steps := {}
var _streams := {}
var _p2: Array[AudioStreamPlayer] = []
var _p3: Array[AudioStreamPlayer3D] = []
var _last := {}
var _ducked := {}
var _follow := {}
var _ear: AudioListener3D
var _at_camera := false
var _walkers: Array = []
var _walk_frame := {}
var _ducks := {}
var _duck_now := {"music": 0.0, "ambience": 0.0, "radio": 0.0}
var _duck_speed := {"music": 1.0, "ambience": 1.0, "radio": 1.0}
var _bed: Array[AudioStreamPlayer] = []
var _bed_name := ""
var _bed_fade := [-80.0, -80.0]
var _song: AudioStreamPlayer
var _song_name := ""
var _song_fade := -80.0
var _indoor := false

var _silent := DisplayServer.get_name() == "headless"
var _extras: Array = []
var _extra_gap := [20.0, 60.0]
var _extra_t := 0.0
var _last_notify := -100.0
var _clock := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	log_sounds = "--sound-log" in OS.get_cmdline_user_args()
	build_buses()
	_load()
	_apply_settings()
	var lv := _quality()
	var n: Array = POOL.get(lv, POOL["high"])
	for i in n[0]:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_p2.append(p)
	for i in n[1]:
		var p := AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 2.5
		p.panning_strength = 0.6
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p)
		_p3.append(p)
	for i in 2:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_bed.append(p)
	_song = AudioStreamPlayer.new()
	_song.bus = "Music"
	add_child(_song)
	_ear = AudioListener3D.new()
	add_child(_ear)
	var watch: Node = load("res://scripts/sound_watch.gd").new()
	watch.name = "Watch"
	add_child(watch)

static func build_buses() -> void:
	"""The buses of docs/sound_spec.md 3, added to whatever is there (the saved layout, or nothing)."""
	for b in BUSES:
		if AudioServer.get_bus_index(b[0]) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b[0])
			match b[0]:
				"Radio":
					var hp := AudioEffectHighPassFilter.new()
					hp.cutoff_hz = 400.0
					hp.db = AudioEffectFilter.FILTER_24DB
					hp.resonance = 0.707
					var lp := AudioEffectLowPassFilter.new()
					lp.cutoff_hz = 3000.0
					lp.db = AudioEffectFilter.FILTER_24DB
					lp.resonance = 0.707
					var eq := AudioEffectEQ6.new()
					eq.set_band_gain_db(3, -4.0)
					AudioServer.add_bus_effect(i, hp)
					AudioServer.add_bus_effect(i, lp)
					AudioServer.add_bus_effect(i, eq)
				"Ambience_Out":
					var lp := AudioEffectLowPassFilter.new()
					lp.cutoff_hz = 800.0
					AudioServer.add_bus_effect(i, lp)
					AudioServer.set_bus_effect_enabled(i, 0, false)
				"Reverb_Room", "Reverb_Big":
					var r := AudioEffectReverb.new()
					r.room_size = 0.25 if b[0] == "Reverb_Room" else 0.85
					r.damping = 0.6 if b[0] == "Reverb_Room" else 0.3
					r.dry = 0.0
					r.wet = 0.6 if b[0] == "Reverb_Room" else 0.8
					AudioServer.add_bus_effect(i, r)
				"Mic":
					AudioServer.set_bus_mute(i, true)
	for b in BUSES:
		AudioServer.set_bus_send(AudioServer.get_bus_index(b[0]), b[1])
	if AudioServer.get_bus_effect_count(0) == 0:
		var mono := AudioEffectStereoEnhance.new()
		mono.pan_pullout = 0.0
		AudioServer.add_bus_effect(0, mono)
		AudioServer.set_bus_effect_enabled(0, 0, false)

func _load() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(EVENTS)) if FileAccess.file_exists(EVENTS) else null
	if d is Dictionary:
		events = d.get("events", {})
		beds = d.get("ambience", {})
		surfaces = d.get("surfaces", {})
		for g in d.get("groups_off", []):
			_groups_off[g] = true
	else:
		push_warning("Sound: no " + EVENTS)
	var s = JSON.parse_string(FileAccess.get_file_as_string(STEPS)) if FileAccess.file_exists(STEPS) else null
	if s is Dictionary:
		for clip in s:
			if s[clip] is Dictionary:
				_steps[clip] = (s[clip]["steps"] as Array).map(func(k): return float(k[0]))

func _quality() -> String:
	var v := Quality.chosen()
	return v if POOL.has(v) else "high"

func _apply_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	for b in SLIDERS:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(clampf(float(cfg.get_value("audio", b.to_lower(), 1.0)), 0.0, 1.0)))
	AudioServer.set_bus_effect_enabled(0, 0, bool(cfg.get_value("audio", "mono", false)))
	if not bool(cfg.get_value("audio", "babble", true)):
		_groups_off["babble"] = true

func set_volume(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0 or not bus in SLIDERS:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(clampf(v, 0.0, 1.0)))
	_save("audio", bus.to_lower(), v)

func volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(i)) if i >= 0 else 0.0

func set_mono(on: bool) -> void:
	AudioServer.set_bus_effect_enabled(0, 0, on)
	_save("audio", "mono", on)

func set_group(group: String, on: bool) -> void:
	"""Switch a set of sounds on or off (babble: the villagers' talk, decision 2 of docs/sound_spec.md 14)."""
	if on:
		_groups_off.erase(group)
	else:
		_groups_off[group] = true
	_save("audio", group, on)

func _save(section: String, key: String, v) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value(section, key, v)
	cfg.save(CFG)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		var cfg := ConfigFile.new()
		cfg.load(CFG)
		if bool(cfg.get_value("audio", "mute_unfocused", false)):
			AudioServer.set_bus_mute(0, what == NOTIFICATION_APPLICATION_FOCUS_OUT)

func play(event: String, db := 0.0):
	return _start(event, null, Vector3.ZERO, db)

func play_at(event: String, pos: Vector3, db := 0.0, pitch := 1.0):
	return _start(event, null, pos, db, true, pitch)

func play_on(event: String, node: Node3D, db := 0.0):
	return _start(event, node, node.global_position, db, true)

func stop(handle, fade := 0.0) -> void:
	if handle == null or not is_instance_valid(handle) or not handle.get("playing"):
		return
	_ducked.erase(handle)
	if fade <= 0.0:
		handle.stop()
		return
	var tw := create_tween()
	tw.tween_property(handle, "volume_db", -60.0, fade)
	tw.tween_callback(handle.stop)

func is_playing(handle) -> bool:
	return handle != null and is_instance_valid(handle) and handle.get("playing")

func _start(event: String, node: Node3D, pos: Vector3, db: float, spatial := false, pitch := 1.0):
	var ev: Dictionary = events.get(event, {})
	if ev.is_empty():
		_log("missing " + event)
		return null
	if ev.has("group") and _groups_off.has(ev["group"]):
		return null
	var now := Time.get_ticks_msec()
	if now - int(_last.get(event, -100000)) < float(ev.get("cooldown", 0.0)) * 1000.0:
		return null
	var range_m := float(ev.get("range_m", 0.0))
	spatial = spatial and range_m > 0.0
	var dist := 0.0
	if spatial:
		dist = pos.distance_to(_ear_pos())
		if dist > range_m:
			return null
	var pool: Array = _p3 if spatial else _p2
	var count := 0
	for p in pool:
		if p.playing and p.get_meta("event", "") == event:
			count += 1
	if count >= int(ev.get("max", 4)):
		return null
	var score := float(ev.get("priority", 2)) * 100.0 - dist
	var p = _voice(pool, score)
	if p == null:
		_log("dropped " + event)
		return null
	_last[event] = now
	if ev.get("notify", false):
		_last_notify = _clock
		duck("notify", NOTIFY_DUCK, 0.15, "ambience")
		duck("notify_radio", NOTIFY_DUCK, 0.15, "radio")
		duck("notify_music", NOTIFY_DUCK * 1.5, 0.15, "music")
	p.stream = _stream(event, ev)
	p.bus = str(ev.get("bus", "SFX"))
	p.volume_db = float(ev.get("volume_db", 0.0)) + db
	p.pitch_scale = pitch
	if ev.has("duck_with"):
		_ducked[p] = [str(ev["duck_with"]), p.volume_db]
	else:
		_ducked.erase(p)
	p.set_meta("event", event)
	p.set_meta("score", score)
	if spatial:
		p.max_distance = range_m
		p.global_position = pos
		if node:
			_follow[p] = node
		else:
			_follow.erase(p)
	if not _silent:
		p.play()
	_log("play %s%s bus=%s" % [event, (" at %.1f m" % dist) if spatial else "", p.bus])
	return p

func _voice(pool: Array, score: float):
	var worst = null
	var low := score
	for p in pool:
		if not p.playing:
			return p
		var s := float(p.get_meta("score", 0.0))
		if s < low:
			low = s
			worst = p
	if worst:
		_log("stolen " + str(worst.get_meta("event", "")))
		worst.stop()
	return worst

func _stream(event: String, ev: Dictionary) -> AudioStream:
	if _streams.has(event):
		return _streams[event]
	var files: Array = ev.get("files", [])
	var pitch: Array = ev.get("pitch", [1.0, 1.0])
	var s: AudioStream
	if files.size() == 1 and float(pitch[1]) <= 1.0:
		s = load(AUDIO + files[0])
	else:
		var r := AudioStreamRandomizer.new()
		r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS if files.size() > 2 else AudioStreamRandomizer.PLAYBACK_RANDOM
		for f in files:
			r.add_stream(-1, load(AUDIO + f))
		r.random_pitch = maxf(1.0, float(pitch[1]))
		s = r
	if ev.get("loop", false):
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		elif s is AudioStreamWAV:
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_streams[event] = s
	return s

func _log(s: String) -> void:
	if log_sounds:
		print("[sound %.2f] %s" % [Time.get_ticks_msec() / 1000.0, s])

func ambience(name: String, fade := 2.0) -> void:
	if name == _bed_name:
		return
	_bed_name = name
	_extras = []
	var old := 0 if _bed[0].playing and _bed_fade[0] > -60.0 else 1
	var new := 1 - old
	_fade_bed(old, -80.0, fade, true)
	if name == "" or not beds.has(name):
		return
	var b: Dictionary = beds[name]
	var s = load(AUDIO + str(b["file"]))
	if s is AudioStreamOggVorbis:
		s.loop = true
	_bed[new].stream = s
	_bed[new].bus = str(b.get("bus", "Ambience_Out"))
	_bed[new].set_meta("db", float(b.get("volume_db", 0.0)))
	_bed_fade[new] = -80.0
	_bed[new].volume_db = -80.0
	if not _silent:
		_bed[new].play(randf() * maxf(0.0, s.get_length() - 1.0))
	_fade_bed(new, 0.0, fade, false)
	_extras = b.get("extras", [])
	_extra_gap = b.get("gap", [20.0, 60.0])
	_extra_t = randf_range(float(_extra_gap[0]) * 0.3, float(_extra_gap[1]) * 0.5)
	_log("ambience " + name)

func _bed_extras(delta: float) -> void:
	"""Now and then one of the bed's one-shots (a printer, talk across the room...) somewhere round the ear."""
	if _extras.is_empty():
		return
	_extra_t -= delta
	if _extra_t > 0.0:
		return
	if _clock - _last_notify < NOTIFY_CLEAR:
		_extra_t = 2.0
		return
	var a := randf() * TAU
	play_at(str(_extras.pick_random()), _ear_pos() + Vector3(cos(a), 0.0, sin(a)) * randf_range(EXTRA_DIST.x, EXTRA_DIST.y))
	_extra_t = randf_range(float(_extra_gap[0]), float(_extra_gap[1]))

func _fade_bed(i: int, to: float, secs: float, stop_after: bool) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): _bed_fade[i] = v, _bed_fade[i], to, maxf(secs, 0.01))
	if stop_after:
		tw.tween_callback(_bed[i].stop)

func music(name: String, fade := 2.0, db := 0.0) -> void:
	"""The background music (A2 of docs/sound_spec.md 12 replaces this with AudioStreamInteractive). The
	piece loops (its silence, if it has one, is the gap between plays); db is its own level under the
	player's Music slider (the office's piece sits far down)."""
	if name == _song_name:
		return
	_song_name = name
	var tw := create_tween()
	tw.tween_method(func(v: float): _song_fade = v, _song_fade, -80.0, maxf(fade, 0.01))
	if name == "":
		tw.tween_callback(_song.stop)
		return
	var path := AUDIO + "music/" + name + ".ogg"
	if not ResourceLoader.exists(path):
		_log("missing music " + name)
		return
	tw.tween_callback(func():
		var s = load(path)
		if s is AudioStreamOggVorbis:
			s.loop = true
		_song.stream = s
		_song.set_meta("db", db)
		_song.volume_db = -80.0
		if not _silent:
			_song.play())
	tw.tween_method(func(v: float): _song_fade = v, -80.0, 0.0, maxf(fade, 0.01))
	_log("music " + name)

func duck(name: String, db: float, secs := 1.0, target := "music") -> void:
	_ducks[name] = {"db": db, "target": target}
	_duck_speed[target] = absf(_duck_goal(target) - _duck_now[target]) / maxf(secs, 0.01)

func unduck(name: String, secs := 1.0) -> void:
	if not _ducks.has(name):
		return
	var target: String = _ducks[name]["target"]
	_ducks.erase(name)
	_duck_speed[target] = absf(_duck_goal(target) - _duck_now[target]) / maxf(secs, 0.01)

func _duck_goal(target: String) -> float:
	var sum := 0.0
	for k in _ducks:
		if _ducks[k]["target"] == target:
			sum += float(_ducks[k]["db"])
	return clampf(sum, DUCK_FLOOR, 12.0)

func set_indoor(on: bool, secs := 0.6) -> void:
	if on == _indoor:
		return
	_indoor = on
	var i := AudioServer.get_bus_index("Ambience_Out")
	AudioServer.set_bus_effect_enabled(i, 0, on)
	var tw := create_tween()
	tw.tween_method(func(v: float): AudioServer.set_bus_volume_db(i, v), AudioServer.get_bus_volume_db(i), -10.0 if on else 0.0, secs)

func listen_at_camera(on: bool) -> void:
	_at_camera = on

func _ear_pos() -> Vector3:
	return _ear.global_position if _ear.is_current() else _cam_pos()

func _cam_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3.ZERO

func _place_ear() -> void:
	var cam := get_viewport().get_camera_3d()
	if _at_camera or hero == null or not is_instance_valid(hero) or not hero.is_inside_tree() or cam == null:
		if _ear.is_current():
			_ear.clear_current()
		return
	_ear.global_transform = Transform3D(cam.global_basis, hero.global_position + Vector3.UP * EAR_HEIGHT)
	if not _ear.is_current():
		_ear.make_current()

func add_walker(c: Node3D) -> void:
	if not c in _walkers:
		_walkers.append(c)

func _footsteps() -> void:
	var ear := _ear_pos()
	var hero_chibi: Node = hero.get("chibi") if hero and is_instance_valid(hero) else null
	var near := []
	for i in range(_walkers.size() - 1, -1, -1):
		var c = _walkers[i]
		if not is_instance_valid(c):
			_walkers.remove_at(i)
			_walk_frame.erase(c)
			continue
		if not c.is_inside_tree() or not c.is_visible_in_tree():
			continue
		var a: AnimationPlayer = c.get("anim")
		if a == null or not _steps.has(a.current_animation):
			_walk_frame.erase(c)
			continue
		var d: float = c.global_position.distance_to(ear)
		if c == hero_chibi or d < NPC_STEP_RANGE:
			near.append([d if c != hero_chibi else -1.0, c, a])
	near.sort_custom(func(p, q): return p[0] < q[0])
	var npcs := 0
	for e in near:
		var c: Node3D = e[1]
		var a: AnimationPlayer = e[2]
		var is_hero: bool = e[0] < 0.0
		if not is_hero:
			npcs += 1
			if npcs > NPC_STEPS_MAX:
				_walk_frame.erase(c)
				continue
		var clip := a.current_animation
		var f := a.current_animation_position * FPS
		var was = _walk_frame.get(c)
		_walk_frame[c] = [clip, f]
		if was == null or was[0] != clip:
			continue
		var f0: float = was[1]
		for k in _steps[clip]:
			var hit: bool = (f0 < k and k <= f) if f >= f0 else (k > f0 or k <= f)
			if hit:
				var db := (RUN_DB if clip == "Move_Run" else 0.0) + (HERO_STEP_DB if is_hero else NPC_STEP_DB)
				play_at("step." + _surface(c, is_hero), c.global_position, db)

func _surface(c: Node3D, look_down: bool) -> String:
	var s := ""
	if look_down:
		var space := c.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(c.global_position + Vector3.UP * 0.3, c.global_position + Vector3.DOWN * 0.4)
		if hero is CollisionObject3D:
			q.exclude = [(hero as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(q)
		if hit and hit["collider"] and hit["collider"].has_meta("surface"):
			s = str(hit["collider"].get_meta("surface"))
	if s == "":
		var scene := get_tree().current_scene
		var key := scene.scene_file_path.get_file().get_basename() if scene else ""
		s = str(surfaces.get(key, surfaces.get("_default", "wood")))
	return s if events.has("step." + s) else "wood"

func _process(delta: float) -> void:
	_clock += delta
	if _ducks.has("notify") and _clock - _last_notify > NOTIFY_HOLD:
		unduck("notify", 0.6)
		unduck("notify_radio", 0.6)
		unduck("notify_music", 1.2)
	_place_ear()
	for p in _ducked.keys():
		if not p.playing:
			_ducked.erase(p)
		else:
			p.volume_db = _ducked[p][1] + _duck_now.get(_ducked[p][0], 0.0)
	for p in _follow.keys():
		var n = _follow[p]
		if not p.playing or not is_instance_valid(n) or not n.is_inside_tree():
			_follow.erase(p)
		else:
			p.global_position = n.global_position
	for t in _duck_now:
		var goal := _duck_goal(t)
		_duck_now[t] = move_toward(_duck_now[t], goal, _duck_speed[t] * delta)
	for i in 2:
		if _bed[i].playing:
			_bed[i].volume_db = float(_bed[i].get_meta("db", 0.0)) + _bed_fade[i] + _duck_now["ambience"]
	if _song.playing:
		_song.volume_db = float(_song.get_meta("db", 0.0)) + _song_fade + _duck_now["music"]
	_footsteps()
	_bed_extras(delta)

func _exit_tree() -> void:

	for p in _p2 + _p3 + _bed + [_song]:
		p.stop()
		p.stream = null
	_streams.clear()
