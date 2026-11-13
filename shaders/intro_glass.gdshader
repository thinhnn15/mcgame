shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.45, 0.55, 0.8, 0.06);
uniform vec2 pane = vec2(1.5, 1.7);
uniform float flash = 0.0;
uniform float glow = 0.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 beads(vec2 uv, float cell, float rate, float t) {
	vec2 g = uv / cell;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	vec2 c = (vec2(hash(id + 1.3), hash(id + 2.7)) - 0.5) * 0.6;
	float rad = mix(0.12, 0.3, hash(id + 4.1));
	float life = fract(t * 0.05 + h * 7.0);
	rad *= smoothstep(0.0, 0.05, life) * smoothstep(1.0, 0.85, life);
	vec2 d = f - c;
	float m = smoothstep(rad, rad * 0.75, length(d)) * step(1.0 - rate, h);
	return vec3(d / max(rad, 1e-3) * m, m);
}

vec3 runs(vec2 uv, float t) {
	float colw = 0.07;
	float cx = uv.x / colw;
	float col = floor(cx);
	float h = hash(vec2(col, 1.0));
	if (h < 0.45) {
		return vec3(0.0);
	}
	float speed = 0.05 + h * 0.08;
	float tt = t * speed + h * 13.0;
	float y = fract(tt + 0.15 * sin(tt * 18.0) * 0.2) * (pane.y + 0.3) - 0.15;
	float x = (fract(cx) - 0.5) * colw + sin(uv.y * 9.0 + h * 6.0) * 0.006;
	vec2 d = vec2(x, (uv.y - y) * 0.8);
	float r = 0.012 + h * 0.006;
	float drop = smoothstep(r, r * 0.6, length(d));

	float above = y - uv.y;
	float trail = smoothstep(0.004, 0.001, abs(x)) * step(0.0, above) * smoothstep(0.35, 0.0, above) * 0.6;
	return vec3(d / r * drop, max(drop, trail));
}

void fragment() {
	vec2 uv = vec2(UV.x * pane.x, UV.y * pane.y);
	float dist = length(VERTEX);
	float near = smoothstep(0.6, 2.2, dist);

	float px = length(fwidth(uv));
	float k1 = 1.0 - smoothstep(0.02 / 7.0, 0.02 / 3.5, px);
	float k2 = 1.0 - smoothstep(0.01 / 7.0, 0.01 / 3.5, px);
	float kr = 1.0 - smoothstep(0.07 / 10.0, 0.07 / 4.0, px);
	vec3 b1 = beads(uv, 0.02, 0.22, TIME) * k1;
	vec3 b2 = beads(uv + 0.37, 0.01, 0.12, TIME * 1.3) * k2;
	vec3 rn = runs(uv, TIME) * kr;
	vec2 nrm = b1.xy + b2.xy * 0.6 + rn.xy;
	float wet = clamp(b1.z + b2.z * 0.7 + rn.z, 0.0, 1.0) * near;

	vec2 suv = SCREEN_UV - nrm * 0.02 * near;
	vec3 behind = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	vec3 bent = textureLod(screen_tex, suv, 1.0).rgb;
	float rim = smoothstep(0.5, 1.0, length(nrm)) * wet;
	vec3 col = mix(behind, bent * 1.08, wet);
	col *= 1.0 - rim * 0.15;

	float hl = smoothstep(0.55, 0.95, -nrm.y) * wet;
	col += vec3(0.12, 0.13, 0.2) * hl * (1.0 + flash * 3.0);
	col = mix(col, tint.rgb, tint.a);
	col += vec3(1.0, 0.75, 0.45) * glow * 0.06;
	col += vec3(0.5, 0.55, 0.8) * flash * 0.08;
	ALBEDO = col;
	ALPHA = clamp(0.15 + wet * 0.85, 0.0, 1.0) * mix(0.0, 1.0, smoothstep(0.25, 0.8, dist));
}
