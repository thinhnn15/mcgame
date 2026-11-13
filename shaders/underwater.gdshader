shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 fog_up : source_color = vec4(0.42, 0.66, 0.58, 1.0);
uniform vec4 fog_down : source_color = vec4(0.10, 0.25, 0.22, 1.0);
uniform float density = 0.1;
uniform float clear = 0.04;
uniform float fog_start = 3.0;
uniform float shafts = 0.22;
uniform float caustic = 0.42;
uniform float water_y = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	float dist = min(length(v.xyz), 200.0);
	vec3 ray = normalize((INV_VIEW_MATRIX * vec4(normalize(v.xyz), 0.0)).xyz);
	vec3 wp = (INV_VIEW_MATRIX * vec4(v.xyz, 1.0)).xyz;
	float f = clamp(clear + (1.0 - exp(-max(dist - fog_start, 0.0) * density)), 0.0, 1.0);
	vec3 col = mix(fog_down.rgb, fog_up.rgb, smoothstep(-0.6, 0.7, ray.y));

	float s1 = texture(noise_tex, vec2(SCREEN_UV.x * 1.3 + SCREEN_UV.y * 0.45 + TIME * 0.012, 0.37)).r;
	float s2 = texture(noise_tex, vec2(SCREEN_UV.x * 2.9 + SCREEN_UV.y * 0.8 - TIME * 0.009, 0.71)).r;
	float shaft = smoothstep(0.55, 0.85, s1 * 0.6 + s2 * 0.4) * smoothstep(-0.2, 0.8, ray.y + 0.3);
	col += shaft * shafts * vec3(0.85, 1.0, 0.9);

	float cw = 0.0;
	if (dist < 14.0 && wp.y < water_y) {
		float n1 = texture(noise_tex, wp.xz * 0.42 + vec2(0.7, 0.4) * TIME * 0.03).r;
		float n2 = texture(noise_tex, wp.xz * 0.37 * mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) - vec2(0.3, 0.8) * TIME * 0.025).r;
		float l1 = 1.0 - smoothstep(0.0, 0.11, abs(n1 - 0.5));
		float l2 = 1.0 - smoothstep(0.0, 0.11, abs(n2 - 0.5));
		float net = min(l1, l2) * 0.6 + l1 * l2 * 0.9 + max(l1, l2) * 0.12;
		cw = net * caustic * (1.0 - smoothstep(4.0, 14.0, dist)) * (1.0 - smoothstep(0.5, 3.5, water_y - wp.y));

		vec3 ddx = dFdx(wp);
		vec3 ddy = dFdy(wp);
		vec3 n = normalize(cross(ddy, ddx));
		float jump = max(length(ddx), length(ddy)) / max(dist, 0.5);
		cw *= smoothstep(0.75, 0.92, abs(n.y)) * (1.0 - smoothstep(0.01, 0.04, jump));
	}

	float a = clamp(f + cw * (1.0 - f), 0.0, 1.0);
	ALBEDO = mix(vec3(1.0, 1.0, 0.92), col, f / max(a, 1e-3));
	ALPHA = a;
}
