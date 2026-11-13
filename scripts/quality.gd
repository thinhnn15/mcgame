class_name Quality
extends RefCounted

const LEVELS := ["low", "medium", "high"]
const CFG := "user://settings.cfg"

static func chosen() -> String:
	var want := Stage.arg("--quality")
	if want == "":
		var cfg := ConfigFile.new()
		if cfg.load(CFG) == OK:
			want = str(cfg.get_value("video", "quality", "auto"))
	if want in LEVELS:
		return want
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_CPU:
			return "low"
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
			return "medium"
	return "high"

static func set_level(level: String, root: Node3D = null) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("video", "quality", level)
	cfg.save(CFG)
	if root != null:
		var we := root.find_child("WorldEnvironment", false, false) as WorldEnvironment
		var sun := root.find_child("Sun", false, false) as DirectionalLight3D
		if we and sun:
			apply(root, we.environment, sun)

static func label(level: String) -> String:
	return TranslationServer.translate("QUALITY_" + level.to_upper())

static func saved() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CFG) == OK:
		return str(cfg.get_value("video", "quality", "auto"))
	return "auto"

static func apply(root: Node3D, env: Environment, sun: DirectionalLight3D) -> void:
	var q := chosen()
	var vp := root.get_viewport()
	var high := q == "high"

	if not env.has_meta("glow_base"):
		env.set_meta("glow_base", env.glow_enabled)
	if not sun.has_meta("blur_base"):
		sun.set_meta("blur_base", sun.shadow_blur)
	sun.shadow_blur = sun.get_meta("blur_base")
	if vp:
		vp.msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if high else Viewport.SCREEN_SPACE_AA_FXAA
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if q == "low" else Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 0.75 if q == "low" else 1.0
	env.ssao_enabled = q != "low"
	env.glow_enabled = env.get_meta("glow_base") and q != "low"
	RenderingServer.environment_set_ssao_quality(
		RenderingServer.ENV_SSAO_QUALITY_MEDIUM if high else RenderingServer.ENV_SSAO_QUALITY_LOW,
		true, 0.5, 2, 50.0, 300.0)
	RenderingServer.directional_shadow_atlas_set_size(4096 if high else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW if high else RenderingServer.SHADOW_QUALITY_HARD)

	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high \
			else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.1 if high else 0.4
	if q == "low":
		sun.shadow_blur = 0.0

	RenderingServer.global_shader_parameter_set("quality_high", 1.0 if high else 0.0)

static func is_high() -> bool:
	return chosen() == "high"
