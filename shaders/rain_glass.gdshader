shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 tint : source_color = vec4(0.45, 0.55, 0.8, 0.1);
uniform vec2 pane = vec2(1.5, 1.7);
uniform float flash = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = UV * pane;

	float cx = uv.x / 0.04;
	float col = floor(cx);
	float r = hash(vec2(col, 3.0));
	float y = fract(uv.y / pane.y * 0.8 + TIME * (0.08 + r * 0.22) + r * 7.0);
	float w = abs(fract(cx) - 0.5 - (hash(vec2(col, floor(uv.y * 6.0))) - 0.5) * 0.25);
	float streak = smoothstep(0.14, 0.0, w) * smoothstep(0.0, 0.25, y) * smoothstep(1.0, 0.75, y) * step(0.5, r);

	vec2 g = uv / 0.03;
	vec2 id = floor(g);
	float h = hash(id);
	vec2 f = fract(g) - 0.5 - (vec2(hash(id + 1.3), hash(id + 2.7)) - 0.5) * 0.4;
	float drop = smoothstep(0.22, 0.12, length(f)) * step(0.8, h);
	float wet = clamp(streak * 0.7 + drop * 0.8, 0.0, 1.0);
	ALBEDO = mix(tint.rgb, vec3(0.8, 0.88, 1.0), wet) * (1.0 + flash * 2.0);
	ALPHA = clamp(tint.a + wet * 0.35 + flash * 0.15, 0.0, 1.0);
}
