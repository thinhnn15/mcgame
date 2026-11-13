shader_type spatial;
render_mode unshaded, cull_back;

#include "res://shaders/intro_light.gdshaderinc"

uniform int kind = 0;
uniform vec4 base_a : source_color = vec4(0.16, 0.17, 0.22, 1.0);
uniform vec4 base_b : source_color = vec4(0.2, 0.2, 0.25, 1.0);
uniform vec4 paint : source_color = vec4(0.85, 0.85, 0.8, 1.0);
uniform vec4 ambient : source_color = vec4(0.32, 0.34, 0.5, 1.0);
uniform vec4 sky_refl : source_color = vec4(0.25, 0.24, 0.42, 1.0);
uniform vec4 lines = vec4(-14.5, -9.8, -19.2, 0.0);
uniform vec2 crossing = vec2(0.0, 2.0);
uniform float puddles = 0.45;
uniform float flash = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

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
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 3.7) * 0.3 + vnoise(p * 4.3 + 9.1) * 0.15;
}

float ripples(vec2 p, float t) {
	float acc = 0.0;
	for (int k = 0; k < 2; k++) {
		vec2 q = p / 0.35 + float(k) * 0.5;
		vec2 id = floor(q);
		vec2 f = fract(q) - 0.5;
		float h = hash(id + float(k) * 17.0);
		vec2 c = (vec2(hash(id + 3.1), hash(id + 5.7)) - 0.5) * 0.5;
		float age = fract(t * (0.9 + h * 0.6) + h * 9.0);
		float r = age * 0.45;
		float d = length(f - c);
		acc += smoothstep(0.06, 0.0, abs(d - r)) * (1.0 - age) * (1.0 - age);
	}
	return acc;
}

vec2 ripple_slope(vec2 p, float t) {
	vec2 acc = vec2(0.0);
	for (int k = 0; k < 2; k++) {
		vec2 q = p / 0.35 + float(k) * 0.5;
		vec2 id = floor(q);
		vec2 f = fract(q) - 0.5;
		float h = hash(id + float(k) * 17.0);
		vec2 c = (vec2(hash(id + 3.1), hash(id + 5.7)) - 0.5) * 0.5;
		float age = fract(t * (0.9 + h * 0.6) + h * 9.0);
		float r = age * 0.45;
		vec2 dv = f - c;
		float d = length(dv) + 1e-4;
		float x = (d - r) * 26.0;
		acc += dv / d * cos(x * 3.0) * exp(-x * x) * (1.0 - age) * (1.0 - age);
	}
	return acc;
}

void fragment() {
	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	float dist = length(CAMERA_POSITION_WORLD - wpos);
	vec2 p = wpos.xz;

	vec3 col;
	float tile_seam = 0.0;
	if (kind == 0) {
		col = mix(base_a.rgb, base_b.rgb, vnoise(p * 1.7) * 0.6 + vnoise(p * 9.0) * 0.4);
		float m = 0.0;
		float aa = fwidth(wpos.z) + 0.004;
		m = max(m, smoothstep(0.07 + aa, 0.07, abs(wpos.z - lines.x)) * step(0.5, fract(wpos.x / 6.0)));
		m = max(m, smoothstep(0.06 + aa, 0.06, abs(wpos.z - lines.y)));
		m = max(m, smoothstep(0.06 + aa, 0.06, abs(wpos.z - lines.z)));
		float zc = abs(wpos.x - crossing.x) < crossing.y ? 1.0 : 0.0;
		float zs = fract((wpos.z - lines.y) / 1.0);
		m = max(m, zc * smoothstep(0.0, 0.03, zs) * smoothstep(0.53, 0.5, zs) * step(lines.z + 0.4, wpos.z) * step(wpos.z, lines.y - 0.4));
		m *= 0.75 + 0.25 * vnoise(p * 6.0);
		col = mix(col, paint.rgb, m);
	} else {
		vec2 g = p / 0.5;
		vec2 id = floor(g);
		vec2 f = abs(fract(g) - 0.5);
		tile_seam = smoothstep(0.44, 0.48, max(f.x, f.y));
		col = mix(base_a.rgb, base_b.rgb, hash(id));
		col *= 1.0 - tile_seam * 0.45;
	}

	float n = fbm(p * 0.28 + 11.0);
	float pud = smoothstep(1.0 - puddles, 1.0 - puddles + 0.06, n);
	if (kind == 1) {
		pud *= 0.6;
	}
	col *= mix(0.7, 0.42, pud);

	vec3 L = painted_light(wpos, vec3(0.0, 1.0, 0.0));
	vec3 lit = col * (ambient.rgb + L * 1.25);

	vec2 rs = ripple_slope(p, TIME) * mix(0.35, 1.0, pud) * smoothstep(28.0, 4.0, dist);
	vec3 Nw = normalize(vec3(-rs.x * 0.22, 1.0, -rs.y * 0.22));
	vec3 R = reflect(-V, Nw);
	vec2 rh = normalize(R.xz + 1e-5);
	float kh = mix(900.0, 5000.0, pud);
	float kv = mix(5.0, 40.0, pud);
	vec3 refl = vec3(0.0);
	for (int i = 0; i < src_n; i++) {
		vec3 d = src_pos[i].xyz - wpos;
		float dl = length(d);
		vec3 dn = d / dl;
		float eh = 1.0 - dot(rh, normalize(dn.xz + 1e-5));
		float ev = R.y - dn.y;
		float g = exp(-eh * kh) * exp(-ev * ev * kv);
		refl += src_col[i].rgb * src_col[i].a * g / (1.0 + dl * 0.04);
	}
	float fres = 0.05 + 0.95 * pow(1.0 - clamp(V.y, 0.0, 1.0), 5.0);
	lit += refl * mix(0.45, 1.1, pud) * (1.0 - tile_seam * 0.7);
	lit += sky_refl.rgb * (1.0 + flash * 3.0) * fres * mix(0.35, 0.9, pud);

	float rp = ripples(p, TIME) * mix(0.3, 1.0, pud) * smoothstep(30.0, 6.0, dist);
	lit += rp * (ambient.rgb * 0.35 + L * 0.6 + refl * 0.3);
	ALBEDO = lit;
}
