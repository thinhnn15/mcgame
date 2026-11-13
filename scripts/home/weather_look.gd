class_name WeatherLook
extends RefCounted

static func sky_on() -> bool:
	return OS.get_environment("MC_SKY_OLD") == ""

static func far_on() -> bool:
	return OS.get_environment("MC_FAR_OLD") == ""

static func wet_on() -> bool:
	return OS.get_environment("MC_WET_OLD") == ""

static func moon_on() -> bool:
	return sky_on() and OS.get_environment("MC_MOON_OLD") == ""

static func setup(dn: DayNight) -> void:
	_sky_setup(dn)
	_far_setup(dn)
	_wet_setup(dn)
	_moon_setup(dn)
	_rb_setup(dn)

static func update(dn: DayNight, s: Dictionary) -> void:
	_sky_update(dn, s)
	_far_update(dn, s)
	_wet_update(dn, s)
	_moon_update(dn, s)
	_rb_update(dn, s)

static var _sky_rain := -1.0

static func _sky_setup(dn: DayNight) -> void:
	_sky_rain = -1.0
	if dn.sky == null or not sky_on():
		return
	dn.sky.set_shader_parameter("look", 1.0)

static func _sky_update(dn: DayNight, s: Dictionary) -> void:
	if dn.sky == null or not sky_on():
		return
	var wet: float = s.wet

	var clear := RB_CLEAR if wet < _sky_rain and _rb_gap > 0.0 else 0.02
	_sky_rain = wet if _sky_rain < 0.0 else move_toward(_sky_rain, wet, clear)
	dn.sky.set_shader_parameter("look", 1.0)
	dn.sky.set_shader_parameter("cover", 0.48)
	dn.sky.set_shader_parameter("rain", _sky_rain)

	var h: float = s.hour
	var dir: Vector3 = s.sun_dir
	var power := 0.0
	var tint := Color("ff9a70")
	if s.lit and dn.sun:
		power = dn.sun.light_energy
		tint = dn.sun.light_color
	else:
		var after := h > 12.0
		var past := (h - 18.9) if after else (5.4 - h)
		if past >= 0.0 and past < 0.8:
			dir = Vector3(-1.0 if after else 1.0, 0.12 - past * 0.5, DayNight.SUMMER_N).normalized()
			power = 0.24 * (1.0 - smoothstep(0.0, 0.8, past)) * (1.0 - 0.45 * wet)
	dn.sky.set_shader_parameter("sun_dir", dir)
	dn.sky.set_shader_parameter("sun_tint", tint)
	dn.sky.set_shader_parameter("sun_power", power)

const FAR_MIE := [[4.8, 0.0], [5.7, 10.7], [7.0, 2.7], [9.5, 1.5], [12.0, 1.0], [15.0, 4.0], [17.3, 6.0],
	[18.4, 8.0], [19.2, 0.0]]
const FAR_GLOW := 0.035

static func _far_setup(dn: DayNight) -> void:
	if not far_on():
		return
	for m: ShaderMaterial in dn._haze:
		m.set_shader_parameter("fh_on", true)

static func far_mie(h: float) -> float:
	"""The sun glow's strength at hour h, 1 at noon (FAR_MIE, eased between the keys)."""
	if h <= FAR_MIE[0][0] or h >= FAR_MIE[-1][0]:
		return 0.0
	for i in FAR_MIE.size() - 1:
		if h < FAR_MIE[i + 1][0]:
			var t: float = (h - float(FAR_MIE[i][0])) / (float(FAR_MIE[i + 1][0]) - float(FAR_MIE[i][0]))
			return lerpf(FAR_MIE[i][1], FAR_MIE[i + 1][1], t * t * (3.0 - 2.0 * t))
	return 0.0

static func _far_update(dn: DayNight, s: Dictionary) -> void:
	if not far_on():
		return
	var wet: float = s.wet
	var mie := far_mie(s.hour) * (1.0 - clampf(s.night, 0.0, 1.0)) * (1.0 - 0.85 * wet)
	var sun_col: Color = dn.sun.light_color if dn.sun else Color.WHITE
	var glow := sun_col.srgb_to_linear() * FAR_GLOW * mie
	if not s.lit:
		glow = Color.BLACK
	var sun_dir: Vector3 = s.sun_dir

	var late := smoothstep(12.0, 16.0, float(s.hour))
	for m: ShaderMaterial in dn._haze:
		m.set_shader_parameter("fh_on", true)
		m.set_shader_parameter("fh_sun", sun_dir)
		m.set_shader_parameter("fh_glow", Vector3(glow.r, glow.g, glow.b))
		m.set_shader_parameter("fh_sun_sky", lerpf(0.65, 0.35, late))
		m.set_shader_parameter("fh_warm_top", lerpf(1.0, 0.2, late))

const WET_IN := 6.0
const WET_OUT := 110.0
const PUDDLE_IN := 25.0
const PUDDLE_OUT := 200.0
const FALL_EASE := 2.0
static var _w_wet := -1.0
static var _w_pud := 0.0
static var _w_fall := 0.0
static var _w_hour := 0.0

static func _wet_setup(_dn: DayNight) -> void:
	_w_wet = -1.0
	_wet_set(0.0, 0.0, 0.0)

static func _wet_set(w: float, p: float, f: float) -> void:
	RenderingServer.global_shader_parameter_set("rain_wet", w)
	RenderingServer.global_shader_parameter_set("rain_puddle", p)
	RenderingServer.global_shader_parameter_set("rain_fall", f)

static func _wet_update(_dn: DayNight, s: Dictionary) -> void:
	if not wet_on():
		_wet_set(0.0, 0.0, 0.0)
		return
	var rain: bool = float(s.wet) > 0.5
	var h: float = s.hour
	if _w_wet < 0.0:
		_w_wet = 1.0 if rain else 0.0
		_w_pud = _w_wet
		_w_fall = _w_wet
	else:
		var dm := fposmod(h - _w_hour, 24.0) * 60.0
		if dm > 720.0:
			dm = 0.0
		if rain:
			_w_wet = minf(_w_wet + dm / WET_IN, 1.0)
			if _w_wet > 0.5:
				_w_pud = minf(_w_pud + dm / PUDDLE_IN, 1.0)
		else:
			_w_wet = maxf(_w_wet - dm / (WET_OUT * (1.0 if s.lit else 2.5)), 0.0)
			_w_pud = maxf(_w_pud - dm / (PUDDLE_OUT * (1.0 if s.lit else 2.5)), 0.0)
		_w_fall = move_toward(_w_fall, 1.0 if rain else 0.0, dm / FALL_EASE)
	_w_hour = h

	_wet_set(_w_wet * (2.0 - _w_wet), _w_pud, _w_fall)

const MOON_RISE := 18.67
const MOON_LATE := 50.0 / 60.0
const MOON_UP := 12.4
const MOON_S := 0.55
const SKY_RISE := 5.3
const SKY_SET := 18.9
const NIGHT_DIR := Vector3(-0.3, 0.8, 0.45)
const MOON_SILVER := Color("c9d6f5")
const MOON_DIM := Color("7d90cc")

const FOG_SKY := [[4.4, 0.22], [5.1, 0.18], [6.3, 0.22], [7.6, 0.5], [16.4, 0.5], [17.4, 0.28], [18.4, 0.18],
	[19.6, 0.2], [20.4, 0.22]]
const FOG_DENS := [[4.6, 1.0], [5.3, 0.7], [6.6, 0.7], [7.8, 1.0], [16.8, 1.0], [17.6, 0.7], [19.3, 0.7], [20.0, 1.0]]
static var _fog_base := -1.0

static func moon_day() -> int:
	var e := OS.get_environment("MC_LUNAR_DAY")
	if e != "":
		return clampi(int(e), 1, 30)
	return clampi(int(Clock.lunar()[1]), 1, 30)

static func moon_lit(d: int) -> float:
	"""The moon's lit fraction on lunar day d: 0 new (day 1), 1 full (day 15-16)."""
	return (1.0 - cos(TAU * float(d - 1) / 29.5)) * 0.5

static func moon_dir(h: float, d: int) -> Vector3:
	"""Toward the moon at hour h of lunar day d (below the horizon: y < 0)."""
	var t := fposmod(h - (MOON_RISE + float(d - 15) * MOON_LATE), 24.0)
	var a := PI * t / MOON_UP
	return Vector3(cos(a), sin(a) * 0.9, MOON_S).normalized()

static func sky_sun_dir(h: float) -> Vector3:
	var a := PI * (h - SKY_RISE) / (SKY_SET - SKY_RISE)
	return Vector3(cos(a), sin(a), DayNight.SUMMER_N).normalized()

static func _keyed(keys: Array, h: float) -> float:
	if h <= keys[0][0]:
		return keys[0][1]
	for i in keys.size() - 1:
		if h < keys[i + 1][0]:
			var t: float = (h - float(keys[i][0])) / (float(keys[i + 1][0]) - float(keys[i][0]))
			return lerpf(keys[i][1], keys[i + 1][1], t * t * (3.0 - 2.0 * t))
	return keys[-1][1]

static func _twilight(h: float) -> float:
	"""0..1: the sun just under the horizon (after sunset, before sunrise)."""
	return smoothstep(18.65, 19.0, h) * (1.0 - smoothstep(19.4, 19.95, h)) \
		+ smoothstep(4.7, 5.0, h) * (1.0 - smoothstep(5.25, 5.65, h))

static func _moon_setup(dn: DayNight) -> void:
	RenderingServer.global_shader_parameter_set("moon_glint", 0.0)
	if dn.sky == null or not moon_on():
		return
	_fog_base = dn.env.fog_density if dn.env else -1.0
	dn.sky.set_shader_parameter("sun_disc", 1.0)

	dn.tree_exiting.connect(func() -> void: RenderingServer.global_shader_parameter_set("moon_glint", 0.0))

static func _moon_update(dn: DayNight, s: Dictionary) -> void:
	if dn.sky == null or not moon_on():
		return
	var h: float = s.hour
	var rain := clampf(_sky_rain, 0.0, 1.0)
	var night := clampf(float(s.night), 0.0, 1.0)
	var deep := smoothstep(0.6, 1.0, night)
	var d := moon_day()
	var lit := moon_lit(d)
	var md := moon_dir(h, d)

	var ph := TAU * float(d - 1) / 29.5
	var wv := Vector3(-1.0, -0.15, 0.0)
	wv = (wv - md * md.dot(wv)).normalized()
	var ml := (md * cos(ph) + wv * sin(ph)).normalized()
	var up := smoothstep(-0.01, 0.04, md.y)
	var high := smoothstep(0.02, 0.25, md.y)
	var bright := lit * high * (1.0 - rain)
	var sk := dn.sky
	sk.set_shader_parameter("sun_disc", 1.0)
	sk.set_shader_parameter("sun_dir", sky_sun_dir(h))
	sk.set_shader_parameter("twilight", _twilight(h))
	sk.set_shader_parameter("moon_dir", md)
	sk.set_shader_parameter("moon_light", ml)
	sk.set_shader_parameter("moon_power", up * (1.0 - rain) * lerpf(0.35, 1.0, deep))
	sk.set_shader_parameter("moon_glow", pow(lit, 1.5) * up * deep * (1.0 - rain))
	sk.set_shader_parameter("stars", smoothstep(0.82, 1.0, night) * (1.0 - 0.6 * bright) * (1.0 - rain))
	if dn.env:
		dn.env.fog_sky_affect = lerpf(_keyed(FOG_SKY, h), 0.5, rain)
		if _fog_base > 0.0:
			dn.env.fog_density = _fog_base * lerpf(_keyed(FOG_DENS, h), 1.0, rain)

	sk.set_shader_parameter("cover", 0.48 + 0.1 * bright * deep)
	var glint := 0.0
	if not s.lit and dn.sun:

		var to := Vector3(md.x, maxf(md.y, 0.45), md.z).normalized()
		var dir := NIGHT_DIR.normalized().slerp(to, high)
		dn.sun.look_at_from_position(dn.sun.global_position, dn.sun.global_position - dir, Vector3.UP)
		dn.sun.light_energy *= lerpf(1.0, lerpf(0.82, 1.45, bright), deep)
		dn.sun.light_color = dn.sun.light_color.lerp(MOON_SILVER, 0.7 * bright * deep) \
			.lerp(MOON_DIM, 0.35 * (1.0 - bright) * deep)
		if dn.env:
			dn.env.ambient_light_energy *= lerpf(1.0, lerpf(0.93, 1.1, bright), deep)
		glint = lit * lit * smoothstep(0.03, 0.2, md.y) * deep * (1.0 - rain)
	RenderingServer.global_shader_parameter_set("moon_glint", glint)

const RB_IN := 5.0
const RB_HOLD := 14.0
const RB_OUT := 8.0
const RB_MIN_RAIN := 3.0
const RB_SHOWER := 0.6
const RB_SHOWER_AFTER := 6.0
const RB_SHOWER_GAP := 0.7
const RB_GAP_IN := 4.0
const RB_GAP_OUT := 10.0
const RB_CLEAR := 0.008
static var _rb := 0.0
static var _rb_gap := 0.0
static var _rb_wet := 0.0
static var _rb_dry := 999.0
static var _rb_last := 0.0
static var _rb_hour := -1.0

static func rainbow_on() -> bool:
	return sky_on() and OS.get_environment("MC_RAINBOW_OLD") == ""

static var _rb_shown := 0.0

static func rainbow() -> float:
	return _rb_shown

static func _rb_set(dn: DayNight, bow: float, gap: float) -> void:
	_rb_shown = bow if dn.sky else 0.0
	if dn.sky:
		dn.sky.set_shader_parameter("rainbow", bow)
		dn.sky.set_shader_parameter("rain_gap", gap)

static func _rb_setup(dn: DayNight) -> void:
	_rb = 0.0
	_rb_gap = 0.0
	_rb_wet = 0.0
	_rb_dry = 999.0
	_rb_last = 0.0
	_rb_hour = -1.0
	_rb_set(dn, 0.0, 0.0)
	dn.tree_exiting.connect(func() -> void: _rb_shown = 0.0)

static func _rb_update(dn: DayNight, s: Dictionary) -> void:
	if dn.sky == null or not rainbow_on():
		_rb_gap = 0.0
		_rb_set(dn, 0.0, 0.0)
		return
	var h: float = s.hour
	var rain: bool = float(s.wet) > 0.5
	var first := _rb_hour < 0.0
	var dm := 0.0
	if first:
		_rb_wet = 60.0 if rain else 0.0
	else:
		dm = fposmod(h - _rb_hour, 24.0) * 60.0
		if dm > 720.0:
			dm = 0.0
	_rb_hour = h
	if rain:
		_rb_wet += dm
		_rb_dry = 0.0
	elif _rb_wet > 0.0:
		_rb_last = _rb_wet
		_rb_wet = 0.0
		_rb_dry = 0.0
	else:
		_rb_dry += dm

	var e := -1.0
	if moon_on():
		e = sky_sun_dir(h).y
	elif s.lit:
		e = (s.sun_dir as Vector3).y
	var fe := smoothstep(0.015, 0.07, e) * (1.0 - smoothstep(0.42, 0.6, e))
	var bow := 0.0
	var gap := 0.0
	if rain:
		if VillageLife.weather != "giong" and _rb_wet >= RB_SHOWER_AFTER:
			bow = RB_SHOWER
			gap = RB_SHOWER_GAP
	elif _rb_dry < RB_HOLD and _rb_last >= RB_MIN_RAIN:
		bow = 1.0
		gap = 1.0
	if fe <= 0.0:
		gap = 0.0
	bow *= fe
	if OS.get_environment("MC_RAINBOW") != "":
		bow = 1.0
	if first:
		_rb = bow
		_rb_gap = gap
	else:
		_rb = move_toward(_rb, bow, dm / (RB_IN if bow > _rb else RB_OUT))
		_rb_gap = move_toward(_rb_gap, gap, dm / (RB_GAP_IN if gap > _rb_gap else RB_GAP_OUT))
	_rb_set(dn, _rb, _rb_gap)
