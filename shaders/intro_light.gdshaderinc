const int MAX_SRC = 40;
uniform vec4 src_pos[40];
uniform vec4 src_col[40];
uniform int src_n = 0;

vec3 painted_light(vec3 wp, vec3 wn) {
	vec3 acc = vec3(0.0);
	for (int i = 0; i < src_n; i++) {
		vec3 d = src_pos[i].xyz - wp;
		vec3 de = vec3(d.x, d.y * 0.45, d.z);
		float dist = length(de);
		float f = clamp(1.0 - dist / src_pos[i].w, 0.0, 1.0);
		if (f <= 0.0) {
			continue;
		}
		float ndl = clamp(dot(wn, normalize(d)) * 0.6 + 0.4, 0.0, 1.0);
		acc += src_col[i].rgb * src_col[i].a * f * f * ndl;
	}
	return acc;
}

vec3 painted_light_wet(vec3 wp, vec3 wn, vec3 V, float power, inout vec3 spec) {
	vec3 acc = vec3(0.0);
	for (int i = 0; i < src_n; i++) {
		vec3 d = src_pos[i].xyz - wp;
		float dl = length(d);
		float reach = src_pos[i].w;
		if (dl > reach * 1.6) {
			continue;
		}
		vec3 dn = d / max(dl, 1e-4);
		vec3 de = vec3(d.x, d.y * 0.45, d.z);
		float f = clamp(1.0 - length(de) / reach, 0.0, 1.0);
		float ndl = clamp(dot(wn, dn) * 0.6 + 0.4, 0.0, 1.0);
		vec3 c = src_col[i].rgb * src_col[i].a;
		acc += c * f * f * ndl;
		float fs = clamp(1.0 - dl / (reach * 1.6), 0.0, 1.0);
		vec3 H = normalize(dn + V);
		spec += c * fs * fs * pow(max(dot(wn, H), 0.0), power) * step(0.0, dot(wn, dn));
	}
	return acc;
}

float wall_rivulets(vec3 wp, vec3 wn, float t, float k) {
	float vert = 1.0 - smoothstep(0.3, 0.6, abs(wn.y));
	if (vert <= 0.0) {
		return 0.0;
	}
	vec2 along = normalize(vec2(-wn.z, wn.x) + 1e-5);
	float u = dot(wp.xz, along) * 7.0;
	float col = floor(u);
	float h = fract(sin(col * 127.1) * 43758.5453);
	if (h > k) {
		return 0.0;
	}
	float x = abs(fract(u) - 0.5 - (h - 0.5) * 0.6);
	float w = 0.05 + fwidth(u) * 0.6;
	float line = smoothstep(w, 0.0, x) * (0.05 / w);
	float y = fract(wp.y * 0.22 + t * (0.18 + 0.3 * h) + h * 11.0);
	float run = smoothstep(0.0, 0.08, y) * smoothstep(0.75, 0.2, y);
	return line * run * vert;
}
