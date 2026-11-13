shader_type sky;

uniform vec4 top_col : source_color = vec4(0.43, 0.45, 0.53, 1.0);
uniform vec4 horizon_col : source_color = vec4(0.79, 0.76, 0.75, 1.0);
uniform vec4 cloud_dark : source_color = vec4(0.36, 0.38, 0.47, 1.0);
uniform vec4 cloud_lit : source_color = vec4(0.84, 0.82, 0.8, 1.0);
uniform vec4 gap_col : source_color = vec4(1.0, 0.95, 0.82, 1.0);
uniform vec4 rim_col : source_color = vec4(1.0, 0.84, 0.58, 1.0);
uniform float coverage = 0.72;
uniform float gap_width = 5.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.0;
	float w = 0.5;
	for (int i = 0; i < 5; i++) {
		a += vnoise(p) * w;
		p = p * 2.03 + vec2(1.7, 9.2);
		w *= 0.5;
	}
	return a;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 sun = normalize(LIGHT0_DIRECTION);
	float toward = max(dot(normalize(vec3(d.x, 0.0, d.z) + 1e-4), normalize(vec3(sun.x, 0.0, sun.z) + 1e-4)), 0.0);
	vec3 col = mix(horizon_col.rgb, top_col.rgb, smoothstep(-0.02, 0.5, h));
	float gap = pow(toward, gap_width) * exp(-max(h, 0.0) * 6.0);
	col = mix(col, gap_col.rgb, gap * 0.9);
	if (h > -0.05) {
		vec2 p = d.xz / (max(h, 0.0) + 0.2) * 1.2 + vec2(TIME * 0.05, TIME * 0.02);
		float c = fbm(p);
		float cov = coverage - gap * 0.55;
		float cl = smoothstep(1.0 - cov - 0.12, 1.0 - cov + 0.22, c);
		vec3 cc = mix(cloud_dark.rgb, cloud_lit.rgb, smoothstep(0.5, 0.95, c) * 0.35 + gap * 0.75);
		float rim = smoothstep(0.02, 0.12, cl) * (1.0 - smoothstep(0.18, 0.6, cl)) * (0.15 + gap * 1.5);
		col = mix(col, cc, cl * smoothstep(-0.05, 0.06, h));
		col += rim_col.rgb * rim * 0.7;
	}
	float sd = max(dot(d, sun), 0.0);
	col += rim_col.rgb * (pow(sd, 48.0) * 0.5 + pow(sd, 6.0) * 0.08);
	COLOR = col;
}
