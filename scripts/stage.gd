class_name Stage
extends RefCounted

const SKY_TOP := Color("8fd3ff")
const SKY_HORIZON := Color("d8f1ff")
const GROUND := Color("bfe3a0")
const SUN := Color("fff1e0")
const AMB_FILL := Color("ece4f2")

static func setup(root: Node3D, sun_energy := 0.78) -> DirectionalLight3D:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SKY_TOP
	sky_mat.sky_horizon_color = SKY_HORIZON
	sky_mat.ground_horizon_color = SKY_HORIZON
	sky_mat.ground_bottom_color = GROUND
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY

	env.ambient_light_sky_contribution = 0.35
	env.ambient_light_color = AMB_FILL
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.2
	env.glow_hdr_threshold = 1.5
	env.ssao_enabled = true
	env.ssao_radius = 0.4
	env.ssao_intensity = 0.8
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	if Grade.enabled() and OS.get_environment("MC_NO_LUT") == "":
		Grade.attach(env)
	else:
		env.adjustment_saturation = 1.04
	if OS.get_environment("MC_REFL") != "":
		env.reflected_light_source = int(OS.get_environment("MC_REFL"))
	if OS.get_environment("MC_GLOW") != "":
		env.glow_enabled = OS.get_environment("MC_GLOW") == "1"
	if OS.get_environment("MC_SAT") != "":
		env.adjustment_saturation = float(OS.get_environment("MC_SAT"))
	if OS.get_environment("MC_TONE") != "":
		env.tonemap_mode = int(OS.get_environment("MC_TONE"))
	if OS.get_environment("MC_EXPO") != "":
		env.tonemap_exposure = float(OS.get_environment("MC_EXPO"))
	if OS.get_environment("MC_AMB") != "":
		env.ambient_light_energy = float(OS.get_environment("MC_AMB"))
	if OS.get_environment("MC_SKYC") != "":
		env.ambient_light_sky_contribution = float(OS.get_environment("MC_SKYC"))
	if OS.get_environment("MC_SUN") != "":
		sun_energy = float(OS.get_environment("MC_SUN"))
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = SUN
	sun.light_energy = sun_energy
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.shadow_opacity = 0.55
	sun.directional_shadow_max_distance = 40.0
	sun.name = "Sun"
	root.add_child(sun)
	sun.look_at_from_position(Vector3(4, 8, 6), Vector3.ZERO, Vector3.UP)
	Quality.apply(root, env, sun)
	clouds(false)
	CanopyShadow.off()
	RenderingServer.global_shader_parameter_set("weathering", 0.0)
	RenderingServer.global_shader_parameter_set("chara_key", 0.55)
	return sun

static func clouds(on: bool, depth := 0.8) -> void:
	if Quality.chosen() == "low" or OS.get_cmdline_user_args().has("--no-sky"):
		on = false
	RenderingServer.global_shader_parameter_set("cloud_shadow", depth if on else 1.0)

static func still_args() -> Array:
	var args := OS.get_cmdline_user_args()
	var path := ""
	var at := -1.0
	for i in args.size():
		if args[i] == "--still":
			path = args[i + 1]
		elif args[i] == "--at":
			at = float(args[i + 1])
	return [path, at]

static func arg(name: String, default := "") -> String:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == name and i + 1 < args.size():
			return args[i + 1]
	return default
