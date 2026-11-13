shader_type spatial;
render_mode unshaded, cull_back;

uniform vec2 cell = vec2(1.8, 3.2);
uniform vec2 cell_offset = vec2(0.0, 0.0);
uniform float lit_rate = 0.06;
uniform float cool_rate = 0.25;
uniform float seed = 0.0;
uniform vec4 glass_top : source_color = vec4(0.2, 0.22, 0.4, 1.0);
uniform vec4 glass_bottom : source_color = vec4(0.07, 0.08, 0.16, 1.0);
uniform vec4 warm : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform vec4 cool : source_color = vec4(0.75, 0.88, 1.0, 1.0);
uniform float lit_energy = 1.0;
uniform float flash = 0.0;
uniform float shutters = 0.0;

uniform bool procedural = false;
uniform vec2 win_size = vec2(0.6, 0.55);
uniform vec4 wall_col : source_color = vec4(0.1, 0.1, 0.18, 1.0);

uniform bool has_frame = false;
uniform sampler2D frame_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float frame_light = 0.55;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float h = abs(wnrm.x) > 0.5 ? wpos.z : wpos.x;
	vec2 id = floor((vec2(h, wpos.y) - cell_offset) / cell);
	id += vec2(seed * 13.0, seed * 7.0) + (abs(wnrm.x) > 0.5 ? vec2(101.0, 0.0) : vec2(0.0));
	float r = hash(id);
	float r2 = hash(id + 0.37);
	vec2 uv = UV;
	bool wall = false;
	if (procedural) {
		vec2 q = fract((vec2(h, wpos.y) - cell_offset) / cell);
		vec2 m = (vec2(1.0) - win_size) * 0.5;
		wall = abs(wnrm.y) > 0.5 || q.x < m.x || q.x > 1.0 - m.x || q.y < m.y || q.y > 1.0 - m.y;
		uv = vec2((q.x - m.x) / win_size.x, 1.0 - (q.y - m.y) / win_size.y);
	}
	vec3 col;
	if (r < lit_rate) {
		vec3 lc = r2 < cool_rate ? cool.rgb : warm.rgb;

		float grad = mix(0.55, 1.0, smoothstep(1.0, 0.1, uv.y));
		col = lc * grad;
		col *= 1.0 - 0.45 * smoothstep(0.7, 0.74, uv.y) * step(0.5, hash(id + 2.0));

		float bl = hash(id + 4.0);
		if (bl < 0.4) {
			float edge = mix(0.25, 0.6, hash(id + 5.0));
			float slat = 0.75 + 0.25 * step(0.5, fract(uv.y * 24.0));
			col = mix(col, lc * 0.72 * slat, step(uv.y, edge));
		}
		if (shutters > 0.0 && hash(id + 6.0) < shutters) {
			col *= mix(0.25, 1.0, step(abs(uv.x - 0.5), 0.18));
		}
		col *= lit_energy * (0.85 + 0.3 * hash(id + 8.0));
	} else {

		col = mix(glass_top.rgb, glass_bottom.rgb, smoothstep(0.0, 1.0, uv.y));
		float sheen = smoothstep(0.08, 0.0, abs(uv.x * 0.6 - uv.y * 0.5 + 0.2 - r2 * 0.5));
		col += glass_top.rgb * sheen * 0.35;
		float grid = step(0.85, fract(uv.x * 3.0)) * step(uv.y, 0.12);
		col *= 1.0 - grid * 0.25;
		col *= 0.85 + 0.3 * r2;

		float dv = hash(id + 11.0);
		if (dv < 0.3) {
			float edge = mix(0.3, 0.95, hash(id + 12.0));
			float slat = 0.8 + 0.2 * step(0.5, fract(uv.y * 30.0));
			col = mix(col, vec3(0.12, 0.13, 0.21) * slat, step(uv.y, edge));
		} else if (dv < 0.45) {
			vec3 cc = mix(vec3(0.2, 0.13, 0.18), vec3(0.13, 0.17, 0.21), hash(id + 13.0));
			float w = mix(0.12, 0.26, hash(id + 14.0));
			float fold = 0.85 + 0.15 * sin(uv.x * 90.0);
			col = mix(col, cc * fold, step(uv.x, w) + step(1.0 - w, uv.x));
		}
		col += vec3(0.55, 0.6, 0.85) * flash * (0.35 + sheen);
	}
	if (has_frame && !wall) {
		vec4 f = texture(frame_tex, uv);
		vec3 fc = f.rgb * frame_light * (r < lit_rate ? 1.25 : 1.0) + vec3(0.5, 0.55, 0.85) * flash * 0.15;
		col = mix(col, fc, f.a);
	}
	if (wall) {
		col = wall_col.rgb * (0.9 + 0.2 * hash(id + 9.0)) + vec3(0.5, 0.55, 0.85) * flash * 0.1;
	}
	ALBEDO = col;
}
