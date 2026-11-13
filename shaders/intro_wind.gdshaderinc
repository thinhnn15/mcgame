const vec3 WIND_DIR = vec3(0.944, 0.0, 0.330);

float wind_gust(vec3 p, float t) {
	return 0.5 + 0.5 * sin(t * 0.55 - p.x * 0.045) * sin(t * 0.23 + 1.7 + p.x * 0.02);
}

float wind_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float wind_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(wind_hash(i), wind_hash(i + vec2(1, 0)), f.x), mix(wind_hash(i + vec2(0, 1)), wind_hash(i + vec2(1, 1)), f.x), f.y);
}

float rain_sheets(vec3 p, float t) {
	vec2 q = p.xz * 0.045 - WIND_DIR.xz * t * 0.35;
	return 0.4 + 1.0 * wind_noise(q) * (0.6 + 0.4 * wind_noise(q * 2.3 + 5.0));
}
