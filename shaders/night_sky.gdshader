shader_type sky;

uniform vec4 top_col : source_color = vec4(0.05, 0.05, 0.14, 1.0);
uniform vec4 horizon_col : source_color = vec4(0.2, 0.18, 0.34, 1.0);
uniform vec4 glow_col : source_color = vec4(0.46, 0.32, 0.46, 1.0);
uniform vec4 cloud_col : source_color = vec4(0.16, 0.15, 0.27, 1.0);
uniform float flash = 0.0;
uniform vec2 flash_dir = vec2(0.6, -0.8);

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
	vec3 col = mix(horizon_col.rgb, top_col.rgb, smoothstep(-0.02, 0.55, h));
	col += glow_col.rgb * exp(-max(h, 0.0) * 9.0) * 0.4;
	if (h > -0.05) {
		vec2 p = d.xz / (max(h, 0.0) + 0.25) * 1.4 + vec2(TIME * 0.03, TIME * 0.012);
		float c = fbm(p);
		float cl = smoothstep(0.42, 0.78, c);
		vec3 cc = mix(cloud_col.rgb, glow_col.rgb * 0.9, exp(-max(h, 0.0) * 4.0));
		cc *= 0.8 + 0.4 * smoothstep(0.5, 0.9, c);
		col = mix(col, cc, cl * 0.8 * smoothstep(-0.05, 0.08, h));
		float toward = 0.5 + 0.5 * dot(normalize(d.xz + 1e-4), normalize(flash_dir));
		col += flash * vec3(0.5, 0.55, 0.85) * (0.08 + cl * 0.5 * toward) * smoothstep(-0.05, 0.2, h);
	}
	COLOR = col;
}
