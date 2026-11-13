class_name AmbientLife
extends Node3D

const EGRET_FLEE := 8.0
const EGRET_FLEE_RUN := 11.0
const EGRET_FREE := 75.0
const EGRET_DAY := Vector2(6.0, 18.0)
const BUG_FAR := 26.0
const FLY_FAR := 32.0
const EARTH := [3, 5, 7, 13]
const LEAFY := [9, 10]
const XOM_DINH := Rect2(-180, -110, 60, 40)

var who: Node3D
var ground: Callable
var hk: Node
var high := true
var _t := 0.0
var _seen := 0.0
var _egrets: Array = []
var _egret_n := 3
var _fly: MultiMeshInstance3D
var _fly_n := 0
var _dfly: MultiMeshInstance3D
var _bfly: MultiMeshInstance3D
var _dfly_on := 0
var _bfly_on := 0
var _dust: CPUParticles3D
var _leaf: CPUParticles3D
var _last := Vector3.INF
var _speed := 0.0
var _sp_d := 0.0
var _sp_t := 0.0
var _step_t := 0.0
var _puff_t := 0.0
var _was_rain := false
var _after_rain := 0.0
var _vl: Node
var _rng := RandomNumberGenerator.new()

static func make(parent: Node3D, who_: Node3D, ground_: Callable) -> AmbientLife:
	if OS.get_environment("MC_LIFE_OLD") == "1":
		return null
	var l := AmbientLife.new()
	l.name = "AmbientLife"
	l.who = who_
	l.ground = ground_
	l.hk = parent
	l.high = Quality.is_high()
	parent.add_child(l)
	return l

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--still"):
		_rng.seed = 7
	else:
		_rng.randomize()
	if OS.get_environment("MC_LIFE_LOG") == "1":
		print("LIFE on: high %s, summer %s (season %.3f)" % [high, _summer(), Season._now()])
	_egret_n = 2
	_bfly = _motes(_bug_mesh(false), 0, 6, true)
	_dfly = _motes(_bug_mesh(true), 1, 8, true)
	if high:
		_fly_n = 48
		_fly = _motes(_glow_mesh(), 2, _fly_n, false)
		_dust = _puffer(Color("d8c4a0", 0.7), 0.38, false)
		_leaf = _puffer(Color(0.42, 0.58, 0.28, 1.0), 0.07, true)

var _us := 0
var _frames := 0
var _log := OS.get_environment("MC_LIFE_LOG") == "1"

func _process(delta: float) -> void:
	if who == null or not is_instance_valid(who):
		return
	if not _log:
		_tick(delta)
		return
	var t0 := Time.get_ticks_usec()
	_tick(delta)
	_us += Time.get_ticks_usec() - t0
	_frames += 1
	if _frames >= 300:
		print("LIFE cpu %.3f ms/frame (egrets %d, speed %.1f)" % [_us / 1000.0 / _frames, _egrets.size(), _speed])
		_us = 0
		_frames = 0

func _tick(delta: float) -> void:
	var p := who.global_position
	if _last != Vector3.INF:
		_sp_d += Vector2(p.x - _last.x, p.z - _last.z).length()
		_sp_t += delta
		if _sp_t >= 0.15:
			var v := _sp_d / _sp_t
			_speed = v if v < 12.0 else 0.0
			_sp_d = 0.0
			_sp_t = 0.0
	_last = p
	_feet(delta, p)
	_egrets_step(delta, p)
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var h := VillageLife.hour()
	var rain := VillageLife.raining()
	if _was_rain and not rain:
		_after_rain = 150.0
	_was_rain = rain
	_after_rain = maxf(0.0, _after_rain - 0.5)
	var summer := _summer()
	var day := h >= 6.5 and h < 18.0 and not rain

	if _fly != null:
		var on := summer > 0.0 and (h >= 19.5 or h < 4.5) and not rain
		_fly.visible = on
		if on:
			_place(_fly, _fly_n, p, 2.0, 24.0, FLY_FAR, 0.3, 1.8, _fly_spot)

	var want_d := 0
	if not rain:
		if _after_rain > 0.0 or _rain_coming(h):
			want_d = 8
		elif day and summer > 0.0:
			want_d = 3
	_dfly.visible = want_d > 0
	if want_d > 0:
		_dfly.multimesh.visible_instance_count = want_d
		_place(_dfly, want_d, p, 2.0, 11.0 if want_d > 3 else 16.0, BUG_FAR, 0.6, 1.6, _dfly_spot if want_d <= 3 else _any_spot)

	var want_b := 0
	if day and h > 7.5 and h < 17.0:
		want_b = 6 if summer > 0.0 else 3
	_bfly.visible = want_b > 0
	if want_b > 0:
		_bfly.multimesh.visible_instance_count = want_b
		_place(_bfly, want_b, p, 3.0, 14.0, BUG_FAR, 0.3, 1.0, _bfly_spot)
	_egrets_life(p, h, rain)

func _mat(x: float, z: float) -> int:
	var tr = hk.get("terrain")
	if tr == null:
		return -1
	var n: int = hk.get("N")
	var half: int = hk.get("HALF")
	var gx := int(round(x)) + half
	var gz := int(round(z)) + half
	if gx < 0 or gz < 0 or gx >= n or gz >= n:
		return -1
	var m: PackedByteArray = tr.mats
	return m[gz * n + gx] if m.size() == n * n else -1

func _summer() -> float:
	"""How much it is summer (fireflies, dragonflies): lunar month ~4 .. ~8 (the story's summer is 5/15 .. 8/15)."""
	var s: float = Season._now()
	return 1.0 if s > 0.25 and s < 0.70 else 0.0

func _rain_coming(h: float) -> bool:
	if _vl == null or not is_instance_valid(_vl):
		_vl = hk.get_node_or_null("VillageLife")
		if _vl == null:
			return false
	var sh = _vl.get("_shower")
	if sh is Array and (sh as Array).size() == 2 and float(sh[0]) >= 0.0:
		var m := h * 60.0
		return m < float(sh[0]) and m > float(sh[0]) - 45.0
	return false

func _fly_spot(x: float, z: float) -> bool:
	var m := _mat(x, z)
	return m in [0, 1, 2, 8, 9, 10, 6] or not is_nan(Water.at(x, z).x)

func _dfly_spot(x: float, z: float) -> bool:
	var m := _mat(x, z)
	return m == 1 or m == 2 or m == 6 or not is_nan(Water.at(x, z).x)

func _bfly_spot(x: float, z: float) -> bool:
	return _mat(x, z) in [0, 7, 8, 10, 2]

func _any_spot(x: float, z: float) -> bool:
	return _mat(x, z) >= 0

const BUG_SHADER := """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform int mode = 0;                       // 0 butterfly, 1 dragonfly
varying float v_wing;
varying vec2 v_uv;
vec3 hash3(float n) { return fract(sin(vec3(n, n + 1.7, n + 3.1)) * vec3(43758.55, 22578.14, 19642.35)); }
vec3 path(float t, float ph) {
	if (mode == 0) {
		return vec3(sin(t * 0.7 + ph * 5.0) * 1.6 + sin(t * 1.9 + ph) * 0.5,
			0.35 + sin(t * 1.3 + ph * 2.0) * 0.3 + 0.12 * sin(t * 4.1 + ph),
			cos(t * 0.55 + ph * 3.0) * 1.6 + cos(t * 1.7 + ph * 7.0) * 0.5);
	}
	float T = 1.4 + fract(ph * 7.3) * 0.9;
	float s = floor(t / T);
	float f = fract(t / T);
	vec3 a = (hash3(s + ph * 91.0) - 0.5) * vec3(5.0, 1.0, 5.0);
	vec3 b = (hash3(s + 1.0 + ph * 91.0) - 0.5) * vec3(5.0, 1.0, 5.0);
	float k = smoothstep(0.0, 0.16, f);
	return mix(a, b, k) + vec3(0.0, sin(t * 3.0 + ph * 9.0) * 0.03, 0.0);
}
void vertex() {
	float ph = INSTANCE_CUSTOM.x;
	float t = TIME * (mode == 0 ? 0.55 : 1.0) + ph * 40.0;
	vec3 at = path(t, ph);
	vec3 dir;
	if (mode == 0) {
		dir = path(t + 0.08, ph) - at;
	} else {
		float T = 1.4 + fract(ph * 7.3) * 0.9;
		float s = floor(t / T);
		dir = hash3(s + 1.0 + ph * 91.0) - hash3(s + ph * 91.0);
	}
	float yaw = atan(dir.x, dir.z);
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	v_wing = UV2.x;
	v_uv = UV;
	if (UV2.x > 0.5) {                      // a wing: hinged at the body (x = 0), beating about the body's axis
		float a = mode == 0 ? (0.25 + 0.95 * sin(TIME * 13.0 + ph * 17.0)) : (0.15 + 0.35 * sin(TIME * 55.0 + ph * 23.0 + UV2.y));
		float side = sign(v.x);
		float r = abs(v.x);
		v = vec3(side * r * cos(a), v.y + r * sin(a), v.z);
		n = vec3(-side * sin(a), cos(a), 0.0);
	}
	float c = cos(yaw), s2 = sin(yaw);
	mat3 R = mat3(vec3(c, 0.0, -s2), vec3(0.0, 1.0, 0.0), vec3(s2, 0.0, c));
	VERTEX = R * v + at;
	NORMAL = R * n;
}
void fragment() {
	vec3 col = COLOR.rgb;
	if (v_wing > 0.5) {
		vec2 q = vec2(v_uv.x, v_uv.y * 2.0 - 1.0);
		float r = length(q);
		if (r > 1.0) { discard; }
		if (mode == 0) {
			col = mix(col, col * 0.25, smoothstep(0.72, 0.9, r));
		} else {
			col = mix(vec3(0.85, 0.92, 0.95), col, 0.15) * (0.9 + 0.2 * q.x);
		}
	} else {
		col = mode == 0 ? vec3(0.12, 0.1, 0.08) : col * 0.9;
	}
	ALBEDO = col;
	ROUGHNESS = 0.8;
}
"""

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, world_vertex_coords;
uniform vec4 tint : source_color = vec4(0.85, 1.0, 0.45, 1.0);
uniform float size = 0.75;
varying float v_g;
void vertex() {
	float ph = INSTANCE_CUSTOM.x * 6.2831;
	float t = TIME;
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 o = vec3(sin(t * 0.31 + ph * 3.1) * 0.9 + sin(t * 0.83 + ph) * 0.3, sin(t * 0.47 + ph * 2.0) * 0.35,
		cos(t * 0.27 + ph * 1.7) * 0.9 + cos(t * 0.71 + ph * 4.0) * 0.3);
	vec3 l = VERTEX - c;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	VERTEX = c + o + (right * l.x + up * l.y) * size;
	float b = sin(t * (0.7 + fract(ph * 3.7) * 0.6) + ph * 9.0);
	v_g = 0.3 + 0.7 * pow(max(b, 0.0), 4.0);
	float d = length(c - CAMERA_POSITION_WORLD);
	v_g *= 1.0 - smoothstep(30.0, 40.0, d);
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = smoothstep(0.22, 0.0, d) + exp(-d * d * 7.0) * 0.45;
	ALBEDO = tint.rgb * 3.2;
	ALPHA = clamp(a * v_g, 0.0, 1.0);
}
"""

func _motes(mesh: Mesh, mode: int, n: int, lit: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = lit
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = n
	var sh := Shader.new()
	sh.code = BUG_SHADER if lit else GLOW_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	if lit:
		m.set_shader_parameter("mode", mode)
	var butter := [Color(1.0, 0.86, 0.25), Color(0.98, 0.97, 0.92), Color(0.45, 0.72, 1.0), Color(1.0, 0.62, 0.25)]
	var drag := [Color(0.25, 0.55, 0.95), Color(0.85, 0.22, 0.15), Color(0.35, 0.7, 0.3)]
	for i in n:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -1000, 0)))
		mm.set_instance_custom_data(i, Color(_rng.randf(), 0, 0, 0))
		if lit:
			mm.set_instance_color(i, (butter if mode == 0 else drag)[i % (4 if mode == 0 else 3)])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	mi.set_meta("placed", PackedVector3Array())
	add_child(mi)
	return mi

func _place(mi: MultiMeshInstance3D, n: int, p: Vector3, r0: float, r1: float, far: float, y0: float, y1: float,
		ok: Callable) -> void:
	var placed: PackedVector3Array = mi.get_meta("placed")
	if placed.size() != mi.multimesh.instance_count:
		placed.resize(mi.multimesh.instance_count)
		for i in placed.size():
			placed[i] = Vector3.INF
	var moved := 0
	for i in n:
		if placed[i] != Vector3.INF and Vector2(placed[i].x - p.x, placed[i].z - p.z).length() < far:
			continue
		for tries in 6:
			var a := _rng.randf() * TAU
			var r := lerpf(r0, r1, sqrt(_rng.randf()))
			var x := p.x + cos(a) * r
			var z := p.z + sin(a) * r
			if ok.call(x, z) or tries == 5:
				var gy: float = ground.call(x, z)
				var w := Water.at(x, z)
				if not is_nan(w.x):
					gy = maxf(gy, w.x)
				placed[i] = Vector3(x, gy + _rng.randf_range(y0, y1), z)
				mi.multimesh.set_instance_transform(i, Transform3D(Basis(), placed[i]))
				break
		moved += 1
		if moved >= 6:
			break
	mi.set_meta("placed", placed)
	mi.custom_aabb = AABB(Vector3(p.x - far - 6.0, p.y - 30.0, p.z - far - 6.0), Vector3(far * 2 + 12.0, 60.0, far * 2 + 12.0))

func _bug_mesh(dragon: bool) -> ArrayMesh:
	"""A tiny insect along +z: a body (two crossed strips) and wings (quads hinged at x = 0; UV2.x = 1 marks them,
	UV2.y the pair). The shader beats the wings and flies it."""
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, wing: float, pair: float) -> void:
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var vs := [a, b, c, d]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color.WHITE)
			st.set_uv(uvs[k])
			st.set_uv2(Vector2(wing, pair))
			st.set_normal(Vector3.UP)
			st.add_vertex(vs[k])
	var L := 0.075 if dragon else 0.035
	var w := 0.006 if dragon else 0.006
	quad.call(Vector3(-w, 0, -L * 0.6), Vector3(w, 0, -L * 0.6), Vector3(w, 0, L * 0.4), Vector3(-w, 0, L * 0.4), 0.0, 0.0)
	quad.call(Vector3(0, -w, -L * 0.6), Vector3(0, w, -L * 0.6), Vector3(0, w, L * 0.4), Vector3(0, -w, L * 0.4), 0.0, 0.0)
	for side in [-1.0, 1.0]:
		if dragon:
			for pr in [[0.016, 0.055, 0.013], [0.0, 0.05, 0.014]]:
				var z0: float = pr[0]
				var sp: float = pr[1]
				var cw: float = pr[2]
				quad.call(Vector3(side * 0.002, 0, z0 + cw * 0.5), Vector3(side * sp, 0, z0 + cw * 0.5),
					Vector3(side * sp, 0, z0 - cw * 0.5), Vector3(side * 0.002, 0, z0 - cw * 0.5), 1.0, z0 * 40.0)
		else:
			quad.call(Vector3(side * 0.002, 0, 0.032), Vector3(side * 0.045, 0, 0.032),
				Vector3(side * 0.045, 0, -0.004), Vector3(side * 0.002, 0, -0.004), 1.0, 0.0)
			quad.call(Vector3(side * 0.002, 0, 0.002), Vector3(side * 0.034, 0, 0.002),
				Vector3(side * 0.034, 0, -0.03), Vector3(side * 0.002, 0, -0.03), 1.0, 0.0)
	var m := st.commit()
	var s := 6.0 if dragon else 5.5
	var arr := m.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in vs.size():
		vs[i] *= s
	arr[Mesh.ARRAY_VERTEX] = vs
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out

func _glow_mesh() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	return q

func _puffer(col: Color, size: float, leaf: bool) -> CPUParticles3D:
	var c := CPUParticles3D.new()
	c.emitting = false
	c.amount = 40 if not leaf else 24
	c.lifetime = 0.9 if not leaf else 1.1
	c.local_coords = false
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	c.emission_sphere_radius = 0.12
	c.direction = Vector3(0, 1, 0)
	c.spread = 70.0
	c.initial_velocity_min = 0.25 if not leaf else 0.8
	c.initial_velocity_max = 0.6 if not leaf else 1.5
	c.gravity = Vector3(0, 0.15, 0) if not leaf else Vector3(0, -2.2, 0)
	c.damping_min = 0.6
	c.damping_max = 1.2
	c.scale_amount_min = 0.7
	c.scale_amount_max = 1.3
	var curve := Curve.new()
	if leaf:
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(1, 0.6))
		c.angular_velocity_min = -300.0
		c.angular_velocity_max = 300.0
	else:
		curve.add_point(Vector2(0, 0.5))
		curve.add_point(Vector2(0.7, 1.5))
		curve.add_point(Vector2(1, 0.0))
	c.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	c.color_ramp = grad

	var q := ArrayMesh.new()
	var hx := size * 0.5
	var hy := size * (0.6 if leaf else 1.0) * 0.5
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-hx, -hy, 0), Vector3(hx, -hy, 0), Vector3(hx, hy, 0), Vector3(-hx, hy, 0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arr[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	q.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if not leaf else BaseMaterial3D.SHADING_MODE_PER_VERTEX

	m.vertex_color_use_as_albedo = false
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not leaf:
		var gt := GradientTexture2D.new()
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 32
		gt.height = 32
		var g2 := Gradient.new()
		g2.set_color(0, Color(1, 1, 1, 1))
		g2.set_color(1, Color(1, 1, 1, 0))
		gt.gradient = g2
		m.albedo_texture = gt
	q.surface_set_material(0, m)
	c.mesh = q
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(c)
	return c

var _dust_test_t := 0.0

func _feet(delta: float, p: Vector3) -> void:
	if _dust == null:
		return
	if OS.get_environment("MC_DUST_TEST") != "":
		_dust_test_t -= delta
		if _dust_test_t <= 0.0:
			_dust_test_t = 0.4
			var f := OS.get_environment("MC_DUST_TEST").split_floats(",")
			_dust.global_position = Vector3(f[0], f[1], f[2])
			_dust.restart()
			_dust.emitting = true
		return
	_puff_t -= delta
	if _puff_t <= 0.0:
		_dust.emitting = false
		_leaf.emitting = false
	var riding := who is Player and (who as Player).riding()
	if riding:
		p -= Vector3(sin(who.rotation.y), 0.0, cos(who.rotation.y)) * 0.5
	if _speed < 1.0 or not who.visible or (who is Player and (who as Player).water > 0):
		_step_t = 0.0
		return
	_step_t -= delta
	if _step_t > 0.0:
		return
	var run := _speed > 2.5
	_step_t = (0.2 if riding else (0.32 if run else 0.5))
	var m := _mat(p.x, p.z)
	var c: CPUParticles3D = _dust if m in EARTH else (_leaf if m in LEAFY and run else null)
	if c == null:
		return
	c.global_position = p + Vector3(0, 0.08, 0)
	c.set("amount_ratio", 1.0 if run else 0.5)
	c.emitting = true
	_puff_t = 0.12

func _egrets_life(p: Vector3, h: float, rain: bool) -> void:
	var day := h >= EGRET_DAY.x and h < EGRET_DAY.y and not rain
	for g in _egrets.duplicate():
		var c: Vector2 = g.c
		var gone := true
		for b in g.birds:
			if b.st != "gone":
				gone = false
		if gone or c.distance_to(Vector2(p.x, p.z)) > EGRET_FREE:
			for b in g.birds:
				if is_instance_valid(b.a):
					(b.a as Node).queue_free()
			_egrets.erase(g)
		elif not day and not g.get("leaving", false):
			_flee(g, p, true)
	if not day or _egrets.size() >= 1:
		return
	for tries in 24:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(20.0, 45.0)
		var c := Vector2(p.x + cos(a) * r, p.z + sin(a) * r)
		if XOM_DINH.has_point(c) or not _on_bund(c) or not _paddy(c, 3.0):
			continue
		_spawn_group(c)
		if OS.get_environment("MC_LIFE_LOG") == "1":
			print("LIFE egrets at %s (hero %s)" % [c, Vector2(p.x, p.z)])
		return

func _paddy(c: Vector2, rad: float) -> bool:
	"""An egret's spot: a bund (the grassy dyke between plots: the rice near the hero stands too tall to see a bird
	in it) with paddy close by, or the edge row of a plot."""
	var m := _mat(c.x, c.y)
	if m != 2 and m != 1:
		return false
	var wet := 0
	for k in 8:
		var a := k * TAU / 8.0
		if _mat(c.x + cos(a) * rad, c.y + sin(a) * rad) == 1:
			wet += 1
	if m == 1 and wet == 8:
		return false
	var w := Water.at(c.x, c.y)
	return wet >= 2 and (is_nan(w.x) or w.y < 0.3)

func _on_bund(q: Vector2) -> bool:
	return _mat(q.x, q.y) == 2

func _spawn_group(c: Vector2) -> void:
	var g := {"c": c, "birds": []}
	for i in _egret_n:
		var at := c
		for tries in 8:
			var q := c + Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0))
			if _on_bund(q):
				at = q
				break
		var a := FarmAnimal.spawn(self, "co_trang", Vector3(at.x, ground.call(at.x, at.y), at.y), _rng.randf() * TAU)
		_no_shadow(a)
		a.scale = Vector3.ONE * 1.2
		g.birds.append({"a": a, "st": "stand", "t": _rng.randf_range(0.5, 3.0), "goal": Vector3.INF, "alt": 0.0,
			"dir": Vector3.ZERO, "land": Vector3.INF, "fly": 0.0})
	_egrets.append(g)

func _no_shadow(a: FarmAnimal) -> void:
	a._casts = false
	for m in a._meshes:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visibility_range_end = 70.0

func _flee(g: Dictionary, p: Vector3, away := false) -> void:
	"""Up and off, away from the hero: to a paddy farther on (or, `away` / none found, off and freed)."""
	var c: Vector2 = g.c
	var off := (c - Vector2(p.x, p.z))
	off = off.normalized() if off.length() > 0.1 else Vector2.RIGHT
	var land := Vector2.INF
	if not away:
		for tries in 14:
			var d := off.rotated(_rng.randf_range(-0.7, 0.7)) * _rng.randf_range(26.0, 44.0)
			var q := c + d
			if not XOM_DINH.has_point(q) and _on_bund(q) and _paddy(q, 2.5) and q.distance_to(Vector2(p.x, p.z)) > 22.0:
				land = q
				break
	g.leaving = land == Vector2.INF
	var delay := 0.0
	for b in g.birds:
		if b.st != "stand":
			continue
		b.st = "wait"
		b.t = delay
		delay += _rng.randf_range(0.12, 0.4)
		var a: FarmAnimal = b.a
		if land == Vector2.INF:
			var far := Vector2(a.position.x, a.position.z) + off.rotated(_rng.randf_range(-0.3, 0.3)) * 90.0
			b.land = Vector3(far.x, INF, far.y)
		else:
			var q := land
			for tries in 8:
				var q2 := land + Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0))
				if _on_bund(q2):
					q = q2
					break
			b.land = Vector3(q.x, ground.call(q.x, q.y), q.y)
	if land != Vector2.INF:
		g.c = land
	if OS.get_environment("MC_LIFE_LOG") == "1":
		print("LIFE egrets flee to %s, hero %s, t %d ms" % [land, Vector2(p.x, p.z), Time.get_ticks_msec()])

func _egrets_step(delta: float, p: Vector3) -> void:
	var pp := Vector2(p.x, p.z)
	var flee := EGRET_FLEE_RUN if _speed > 2.5 else EGRET_FLEE
	for g in _egrets:
		var scared := false
		for b in g.birds:
			if b.st == "stand" and Vector2(b.a.position.x, b.a.position.z).distance_to(pp) < flee:
				scared = true
		if scared and who.visible:
			_flee(g, p)
		for b in g.birds:
			_bird(b, delta)

func _bird(b: Dictionary, delta: float) -> void:
	var a: FarmAnimal = b.a
	if not is_instance_valid(a) or b.st == "gone":
		return
	b.t -= delta
	match b.st:
		"stand":
			if b.goal != Vector3.INF:
				var to: Vector3 = b.goal - a.position
				to.y = 0.0
				if to.length() > 0.05:
					var np: Vector3 = a.position + to.normalized() * minf(0.15 * delta, to.length())
					np.y = ground.call(np.x, np.z)
					a.position = np
					a.rotation.y = lerp_angle(a.rotation.y, atan2(to.x, to.z), 1.0 - exp(-delta * 4.0))
					return
				b.goal = Vector3.INF
				a.play("Idle")
				b.t = _rng.randf_range(1.0, 3.5)
			if b.t > 0.0:
				return
			var r := _rng.randf()
			if r < 0.4:
				a.play("Strike")
				b.t = _rng.randf_range(2.0, 4.0)
			elif r < 0.8:
				var q := Vector2(a.position.x, a.position.z) + Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2))
				if _mat(q.x, q.y) == 2:
					b.goal = Vector3(q.x, 0.0, q.y)
					a.play("Walk")
				b.t = 1.0
			else:
				b.t = _rng.randf_range(1.5, 4.0)
		"wait":
			if b.t <= 0.0:
				b.st = "take"
				a.play("Takeoff", 0.1)
				b.t = a.anim.get_animation("Takeoff").length if a.anim.has_animation("Takeoff") else 0.6
				b.fly = b.t
				var to: Vector3 = b.land - a.position
				to.y = 0.0
				b.dir = to.normalized()
				b.alt = 0.0
		"take":
			var k := 1.0 - clampf(b.t / maxf(b.fly, 0.01), 0.0, 1.0)
			b.alt = 1.3 * k * k
			_move(a, b, 1.6 * k, delta)
			if b.t <= 0.0:
				b.st = "fly"
				a.play("Fly", 0.15)
		"fly":
			var to: Vector3 = b.land - a.position
			to.y = 0.0
			var d := to.length()
			if b.land.y == INF and d < 3.0:
				b.st = "gone"
				a.visible = false
				return
			b.dir = b.dir.lerp(to.normalized(), 1.0 - exp(-delta * 2.0)).normalized()
			var cruise := 3.2
			if b.land.y != INF and d < 9.0:
				cruise = lerpf(0.0, 3.2, clampf(d / 9.0, 0.0, 1.0))
				if a.anim.current_animation == "Fly" and d < 7.0:
					a.play("Glide", 0.3)
			b.alt = move_toward(b.alt, cruise, delta * 1.4)
			_move(a, b, FarmAnimal.SPEED["co_trang"]["Fly"] * (0.75 if d < 5.0 and b.land.y != INF else 1.0), delta, d)
			if b.land.y != INF and d < 0.9:
				b.st = "land"
				a.play("Land", 0.15)
				b.t = a.anim.get_animation("Land").length if a.anim.has_animation("Land") else 0.6
				b.fly = b.t
		"land":
			b.alt = move_toward(b.alt, 0.0, delta * 2.5)
			_move(a, b, 0.3 * clampf(b.t / maxf(b.fly, 0.01), 0.0, 1.0), delta)
			if b.t <= 0.0:
				b.st = "stand"
				b.alt = 0.0
				b.t = _rng.randf_range(1.0, 3.0)
				b.goal = Vector3.INF
				a.play("Idle")

func _move(a: FarmAnimal, b: Dictionary, sp: float, delta: float, cap := INF) -> void:
	var step: Vector3 = b.dir * minf(sp * delta, cap)
	var np := a.position + step
	np.y = ground.call(np.x, np.z) + b.alt
	if b.alt > 0.2:
		var w := Water.at(np.x, np.z)
		if not is_nan(w.x):
			np.y = maxf(np.y, w.x + b.alt)
	a.position = np
	if b.dir.length() > 0.1:
		a.rotation.y = lerp_angle(a.rotation.y, atan2(b.dir.x, b.dir.z), 1.0 - exp(-delta * 5.0))
