class_name DayNight
extends Node

const STEP := 0.25
const SUMMER_N := 0.35

const KEYS := [
	[4.5, Color("8fa3d6"), 0.12, Color("1b2448"), Color("3a4470"), Color("5a6aa0"), 0.35, Color("2a3358"), 1.0, Color("2a3358"), 1.0],
	[5.3, Color("b6a6d2"), 0.18, Color("4a5a8c"), Color("e8b8b0"), Color("8a88b0"), 0.32, Color("8c8aa8"), 0.8, Color("8a7a9c"), 0.75],
	[5.65, Color("ffc090"), 0.4, Color("7aa0d8"), Color("ffc9a0"), Color("bcb4d0"), 0.31, Color("d8c4c4"), 0.35,
	 Color("e8b8b0"), 0.5],
	[6.0, Color("ffd6b0"), 0.55, Color("92cdf6"), Color("ffe6cc"), Color("e8e0ee"), 0.3, Color("e8e6ea"), 0.0, Color("ffe2cc"), 0.3],
	[8.0, Color("fff1e0"), 0.78, Color("8fd3ff"), Color("d8f1ff"), Color("ece4f2"), 0.3, Color("dfe6ea"), 0.0, Color("ffffff"), 0.0],
	[16.0, Color("fff1e0"), 0.78, Color("8fd3ff"), Color("d8f1ff"), Color("ece4f2"), 0.3, Color("dfe6ea"), 0.0, Color("ffffff"), 0.0],
	[17.6, Color("ffb070"), 0.72, Color("86c4f0"), Color("ffe6bc"), Color("dde2f2"), 0.22,
	 Color("f0e2cc"), 0.0, Color("ffe2c0"), 0.25],
	[18.5, Color("ffa46c"), 0.45, Color("7290cc"), Color("ffbc94"), Color("e2d0d4"), 0.3, Color("ecc8b4"), 0.35, Color("b07c8c"), 0.4],
	[19.1, Color("b08cc8"), 0.16, Color("34407a"), Color("c88aa0"), Color("8a84b4"), 0.33, Color("6a5a88"), 0.85, Color("5a4a78"), 0.85],
	[19.8, Color("8fa3d6"), 0.12, Color("1b2448"), Color("3a4470"), Color("5a6aa0"), 0.35, Color("2a3358"), 1.0, Color("2a3358"), 1.0],
]

var home: Node3D
var sun: DirectionalLight3D
var env: Environment
var sky: ShaderMaterial
var _haze := {}
var _scan := 0.0
var _t := 0.0
var _own := 6.0 * 60.0
const MIST_TOP := 1.5
const MIST_DENSITY := 0.12

const AERIAL := 0.35
const SUN_SCATTER := 0.06
var morning_mist := 0.0
var _cloud_wet := 0.0

func _exit_tree() -> void:
	Wind.strength = 0.0
	RenderingServer.global_shader_parameter_set("wind_gust", 1.0)

static func add(parent: Node3D) -> DayNight:
	var args := OS.get_cmdline_user_args()
	if args.has("--night") or args.has("--no-daynight"):
		return null
	var d := DayNight.new()
	d.name = "DayNight"
	d.home = parent
	parent.add_child(d)
	return d

func _ready() -> void:
	await get_tree().process_frame
	sun = home.get_node_or_null("Sun") as DirectionalLight3D
	var we := home.get_node_or_null("WorldEnvironment") as WorldEnvironment
	env = we.environment if we else null
	if env and env.sky and env.sky.sky_material is ShaderMaterial:
		sky = env.sky.sky_material
	_rescan()
	WeatherLook.setup(self)
	WindowLights.add(home)
	if Stage.arg("--hour") != "":
		_own = float(Stage.arg("--hour")) * 60.0
	_apply()

func hour() -> float:
	if home.get_node_or_null("VillageLife") != null:
		return VillageLife.hour()
	for n in home.get_children():
		if n is HomeEvents:
			return Clock.minute / 60.0
	return _own / 60.0

func _process(delta: float) -> void:
	if home.get_node_or_null("VillageLife") == null:
		_own = fmod(_own + delta, 24.0 * 60.0)
	_t += delta
	_scan += delta
	if _scan > 8.0:
		_scan = 0.0
		_rescan()
	if _t >= STEP or VillageLife.speed > 4.0:
		_t = 0.0
		_apply()

func _rescan() -> void:
	"""Every far-haze material in the scene (the karst's, the terrain's): set as overrides or on the meshes."""
	var hz := preload("res://scripts/home/shader_copy.gd").family([preload("res://shaders/karst.gdshader"),
		preload("res://shaders/greybox_terrain.gdshader")])
	var found := {}
	for gi: GeometryInstance3D in home.find_children("*", "GeometryInstance3D", true, false):
		var mats := [gi.material_override]
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			var mi := gi as MeshInstance3D
			for k in mi.mesh.get_surface_count():
				mats.append(mi.get_surface_override_material(k))
				mats.append(mi.mesh.surface_get_material(k))
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh and (gi as MultiMeshInstance3D).multimesh.mesh:
			var mm := (gi as MultiMeshInstance3D).multimesh.mesh
			for k in mm.get_surface_count():
				mats.append(mm.surface_get_material(k))
		for m in mats:
			if m is ShaderMaterial and (m as ShaderMaterial).shader in hz:
				found[m] = true
	if OS.get_cmdline_user_args().has("--village-log"):
		print("daynight: %d haze materials" % found.size())
	for m: ShaderMaterial in found:
		if not _haze.has(m):
			_haze[m] = [_param(m, "haze_color"), _param(m, "mist_color"), _param(m, "mist_max")]

func _param(m: ShaderMaterial, name: String) -> Variant:
	"""A material's value, or its shader's default when the material never set it (get_shader_parameter: null)."""
	var v = m.get_shader_parameter(name)
	return v if v != null else RenderingServer.shader_get_parameter_default(m.shader.get_rid(), name)

const KEY_17_OLD := [17.6, Color("ffd59a"), 0.72, Color("86c4f0"), Color("ffe6bc"), Color("f2e2d8"), 0.3, Color("f0e2cc"), 0.0, Color("ffe2c0"), 0.25]

func _key(h: float) -> Array:
	"""The keys either side of hour h and how far between them (the night runs on round midnight)."""
	var keys: Array = KEYS
	if not Grade.enabled():
		keys = KEYS.duplicate()
		keys[5] = KEY_17_OLD
	if h < keys[0][0] or h >= keys[-1][0]:
		return [keys[-1], keys[-1], 0.0]
	for i in keys.size() - 1:
		if h < keys[i + 1][0]:
			var t: float = (h - float(keys[i][0])) / (float(keys[i + 1][0]) - float(keys[i][0]))
			return [keys[i], keys[i + 1], t * t * (3.0 - 2.0 * t)]
	return [keys[-1], keys[-1], 0.0]

func _apply() -> void:
	if sun == null:
		return
	var h := hour()
	var k := _key(h)
	var a: Array = k[0]
	var b: Array = k[1]
	var t: float = k[2]
	var wet := 1.0 if VillageLife.raining() else 0.0
	Wind.strength = 1.0 + wet * (1.2 if VillageLife.weather == "giong" else 0.5)
	RenderingServer.global_shader_parameter_set("wind_gust", Wind.strength)
	var grey := Color("b8c0c8")

	var day := clampf((h - 5.4) / (18.7 - 5.4), 0.0, 1.0)
	var lit := h >= 5.4 and h <= 18.9
	var dir: Vector3
	if lit:
		var ang := PI * day
		var elev := maxf(sin(ang), 0.12)
		dir = Vector3(cos(ang), elev, SUMMER_N).normalized()
	else:
		dir = Vector3(-0.3, 0.8, 0.45).normalized()
	sun.look_at_from_position(sun.global_position, sun.global_position - dir, Vector3.UP)
	sun.light_color = (a[1] as Color).lerp(b[1], t).lerp(grey, wet * 0.6)
	sun.light_energy = lerpf(a[2], b[2], t) * (1.0 - wet * 0.45)
	_cloud_wet = move_toward(_cloud_wet, wet, 0.01)
	Stage.clouds(lit, lerpf(0.8, 1.0, _cloud_wet))
	var night: float = lerpf(a[8], b[8], t)
	HomeKit.set_night(night)
	if env:
		env.ambient_light_color = (a[5] as Color).lerp(b[5], t).lerp(grey, wet * 0.4)
		env.ambient_light_energy = lerpf(a[6], b[6], t)
		env.fog_light_color = (a[7] as Color).lerp(b[7], t).lerp(grey, wet * 0.5)

		var mist := smoothstep(4.8, 5.8, h) * (1.0 - smoothstep(7.4, 8.9, h))
		if not Grade.enabled():
			mist = 0.0
		env.fog_height = MIST_TOP
		env.fog_height_density = MIST_DENSITY * maxf(mist, wet * 0.4)
		env.fog_aerial_perspective = AERIAL if Grade.enabled() else 0.2
		if OS.get_environment("MC_AERIAL") != "":
			env.fog_aerial_perspective = float(OS.get_environment("MC_AERIAL"))
		env.fog_sun_scatter = SUN_SCATTER * (1.0 - clampf(lerpf(a[8], b[8], t), 0.0, 1.0)) * (1.0 - wet) 				if Grade.enabled() else 0.0
		if OS.get_environment("MC_SCATTER") != "":
			env.fog_sun_scatter = float(OS.get_environment("MC_SCATTER"))
		RenderingServer.global_shader_parameter_set("sky_horizon",
				(a[4] as Color).lerp(b[4], t).lerp(grey, wet * 0.45))
		if Grade.enabled() and OS.get_environment("MC_NO_LUT") == "":
			Grade.update(env, h, wet)
		morning_mist = mist
	if sky:
		sky.set_shader_parameter("top_color", (a[3] as Color).lerp(b[3], t).lerp(grey, wet * 0.55))
		sky.set_shader_parameter("horizon_color", (a[4] as Color).lerp(b[4], t).lerp(grey, wet * 0.45))
		sky.set_shader_parameter("night", night)
		sky.set_shader_parameter("cover", lerpf(0.48, 0.85, wet))
	var hz_col: Color = (a[9] as Color).lerp(b[9], t)
	var hz: float = lerpf(a[10], b[10], t)
	var dark := clampf(night, 0.0, 1.0)
	for m: ShaderMaterial in _haze:
		var e: Array = _haze[m]
		if e[0] is Color:
			m.set_shader_parameter("haze_color", (e[0] as Color).lerp(hz_col, hz).lerp(grey, wet * 0.3))
		var mist_day: Color = e[1] if e[1] is Color else Color(0.93, 0.95, 0.96)
		m.set_shader_parameter("mist_color", mist_day.lerp(hz_col.lightened(0.1), hz))
		if e[2] != null:
			m.set_shader_parameter("mist_max", lerpf(float(e[2]), 0.2, dark))

		m.set_shader_parameter("mist_morning", morning_mist if Grade.enabled() else 0.0)
	WeatherLook.update(self, {"hour": h, "wet": wet, "night": night, "lit": lit, "sun_dir": dir, "key_a": a,
		"key_b": b, "key_t": t, "grey": grey})
