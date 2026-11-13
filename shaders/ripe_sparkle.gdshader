shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 core_col : source_color = vec3(1.0, 1.0, 0.92);
uniform vec3 star_col : source_color = vec3(1.0, 0.86, 0.30);
uniform vec3 rim_col : source_color = vec3(0.95, 0.48, 0.10);

varying float v_tw;
varying float v_ph;

void vertex() {
	v_ph = INSTANCE_CUSTOM.r * 6.2832;
	vec3 bob = vec3(0.0, sin(TIME * 1.6 + v_ph) * 0.04, 0.0);
	v_tw = 0.5 + 0.5 * sin(TIME * 2.6 + v_ph * 1.7);
	float s = 0.92 + 0.14 * v_tw;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz + bob;
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 world = origin + (right * VERTEX.x + up * VERTEX.y) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

vec2 star4(vec2 q, float thin) {
	vec2 a = abs(q);

	float k = thin;
	float d = pow(a.x, k) + pow(a.y, k);
	float inside = 1.0 - smoothstep(0.88, 1.0, d);
	float rim = smoothstep(0.62, 0.86, d) * inside;
	return vec2(inside, rim);
}

mat2 rot(float a) { return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);

	vec2 q = rot(sin(TIME * 0.7 + v_ph) * 0.35) * p / 0.55;
	vec2 st = star4(q, 0.55);
	float core = 1.0 - smoothstep(0.05, 0.22, length(q));
	vec3 col = mix(star_col, rim_col, st.y);
	col = mix(col, core_col, core);
	float a = st.x;

	float halo = (1.0 - smoothstep(0.0, 0.62, r)) * 0.42;

	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		float ang = TIME * 0.9 + v_ph + fi * 3.1416;
		vec2 c = vec2(cos(ang), sin(ang) * 0.8) * 0.72;
		float blink = smoothstep(0.2, 1.0, sin(TIME * 3.3 + v_ph + fi * 3.1416));
		vec2 g = star4((p - c) / 0.17, 0.55);
		col = mix(col, core_col, g.x * blink * (1.0 - a));
		a = max(a, g.x * blink);
	}
	ALBEDO = mix(star_col, col, step(0.001, a));
	ALPHA = clamp(max(a, halo) * (0.80 + 0.20 * v_tw), 0.0, 1.0);
}
