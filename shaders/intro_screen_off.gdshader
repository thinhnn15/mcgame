shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 glass = vec3(0.010, 0.012, 0.02);
uniform vec3 window_refl = vec3(0.05, 0.06, 0.11);
uniform float sheen = 0.035;

void fragment() {
	vec2 uv = UV;
	vec3 c = glass;

	c += window_refl * smoothstep(0.55, 0.1, uv.y) * smoothstep(0.0, 0.25, uv.y) * (0.6 + 0.4 * uv.x);
	float d = uv.x * 0.8 + uv.y;
	float s = smoothstep(0.25, 0.45, d) * (1.0 - smoothstep(0.55, 0.85, d));
	c += vec3(0.75, 0.82, 1.0) * s * sheen;
	vec2 e = uv * (1.0 - uv);
	c *= mix(0.6, 1.0, clamp(pow(e.x * e.y * 18.0, 0.4), 0.0, 1.0));
	ALBEDO = c;
}
