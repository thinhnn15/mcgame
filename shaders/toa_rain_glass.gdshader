shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.7, 0.86, 0.9, 0.05);
uniform vec4 sky_high : source_color = vec4(0.84, 0.94, 1.0, 1.0);
uniform vec4 sky_low : source_color = vec4(0.56, 0.72, 0.78, 1.0);
uniform float glint = 0.18;
uniform float wet = 1.0;
uniform float run = 0.0;
uniform float back = -1.0;

varying vec3 opos;
varying vec3 onrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

vec3 beads(vec2 q, float size, float rate, float seed) {
	vec2 g = q / size;
	vec2 id = floor(g);
	float h = hash(id + seed);
	vec2 c = (vec2(hash(id + seed + 1.3), hash(id + seed + 2.7)) - 0.5) * 0.5;
	float r = mix(0.16, 0.38, hash(id + seed + 4.1));
	vec2 f = (fract(g) - 0.5 - c) / r;
	f.y *= 0.85;
	float m = (1.0 - smoothstep(0.75, 1.0, length(f))) * step(1.0 - rate, h);
	return vec3(m, f);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(-VERTEX);
	float ndv = abs(dot(n, v));
	float fres = pow(1.0 - ndv, 3.0);
	vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-v, n * sign(dot(n, v))), 0.0)).xyz;
	vec3 sky = mix(sky_low.rgb, sky_high.rgb, smoothstep(-0.25, 0.6, r.y));
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float s = fract(dot(wp - cam * 0.25, normalize(vec3(0.9, 1.5, 0.5))) * 0.7);
	float bands = smoothstep(0.0, 0.03, s) * smoothstep(0.17, 0.13, s) + 0.55 * smoothstep(0.24, 0.26, s) * smoothstep(0.31, 0.29, s);
	vec3 glass = mix(tint.rgb, sky, clamp(fres * 0.85 + 0.15, 0.0, 1.0)) + vec3(bands * glint);
	float glass_a = clamp(tint.a + fres * 0.6 + bands * glint * 0.55, 0.0, 0.92);

	bool side = abs(onrm.x) > abs(onrm.z);
	vec2 q = side ? vec2(opos.z * back, opos.y) : vec2(opos.x, opos.y);
	float seen = 1.0 - smoothstep(0.004, 0.012, fwidth(q.x) + fwidth(q.y));

	vec3 b1 = beads(q, 0.032, 0.42 * wet * (1.0 - run * 0.5), 0.0);
	vec3 b2 = beads(q + 0.011, 0.014, 0.5 * wet, 7.0);

	float slant = side ? mix(0.05, 1.6, run) : 0.0;
	vec2 d = normalize(vec2(slant, -1.0));
	vec2 acr = vec2(-d.y, d.x);
	float a = dot(q, d);
	float bq = dot(q, acr) + sin(a * 9.0 + floor(dot(q, acr) / 0.045) * 3.1) * 0.006;
	float lane = floor(bq / 0.045);
	float lh = hash(vec2(lane, 11.0));
	float speed = mix(0.15, 0.5, lh) * mix(0.6, 3.5, run);
	float L = 0.7 + lh;
	float t = fract(a / L - TIME * speed / L + lh * 9.0);
	float x = abs(fract(bq / 0.045) - 0.5) / 0.5;
	float head = (1.0 - smoothstep(0.0, 0.035 / L, t)) * (1.0 - smoothstep(0.35, 0.55, x));
	float trail = smoothstep(0.035 / L, 0.06 / L, t) * (1.0 - smoothstep(0.06 / L, 0.45 / L, t)) * (1.0 - smoothstep(0.08, 0.2, x));
	float on = step(1.0 - 0.38 * wet, hash(vec2(lane, floor(a / L - TIME * speed / L + lh * 9.0))));
	float riv = max(head, trail * 0.55) * on;

	vec2 bend = b1.x > 0.0 ? b1.yz : b2.yz * 0.6;
	float m = max(b1.x, b2.x * 0.8);
	m = max(m, riv);
	if (riv > 0.0 && riv >= max(b1.x, b2.x * 0.8)) {
		bend = vec2(x * sign(fract(bq / 0.045) - 0.5), 0.3);
	}
	m *= seen;
	vec2 off = -bend * 0.018 * m;
	vec3 behind = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	vec3 drop = behind * 0.82 + vec3(0.05, 0.06, 0.07);
	float hi = (1.0 - smoothstep(0.0, 0.35, length(bend - vec2(-0.35, 0.45)))) * m;
	float rim = smoothstep(0.55, 0.95, length(bend)) * m;
	drop = drop * (1.0 - rim * 0.35) + vec3(hi * 0.9);

	vec3 film = textureLod(screen_tex, SCREEN_UV, 1.5).rgb;
	float wash = 0.25 * wet;
	vec3 base = mix(glass, film * 0.95 + 0.04, wash * (1.0 - glass_a));
	float base_a = max(glass_a, wash * 0.6);
	ALBEDO = mix(base, drop, m);
	ALPHA = mix(base_a, 0.95, m);
}
