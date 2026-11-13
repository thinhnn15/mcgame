shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D screen_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool on = true;
uniform float brightness = 1.0;
uniform vec4 caret = vec4(0.0);
uniform vec3 caret_color = vec3(0.9);
uniform float sheen = 0.03;

void fragment() {
	vec2 uv = UV;
	vec3 c = vec3(0.05, 0.06, 0.075);
	if (on) {
		c = texture(screen_tex, uv).rgb;
		vec2 q = (uv - caret.xy) / max(caret.zw, vec2(1e-5));
		if (caret.z > 0.0 && q.x >= 0.0 && q.x <= 1.0 && q.y >= 0.0 && q.y <= 1.0 && fract(TIME * 0.9) < 0.55) {
			c = caret_color;
		}
		c *= brightness;
		vec2 e = uv * (1.0 - uv);
		c *= mix(0.86, 1.0, clamp(pow(e.x * e.y * 18.0, 0.35), 0.0, 1.0));
	}

	float d = uv.x * 0.8 + uv.y;
	float s = smoothstep(0.25, 0.45, d) * (1.0 - smoothstep(0.55, 0.85, d));
	c += vec3(0.85, 0.9, 1.0) * s * (on ? sheen : sheen * 1.6);
	ALBEDO = c;
}
