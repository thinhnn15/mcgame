shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
uniform float dark = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	uv += vec2(sin(t * 1.7 + uv.y * 6.0), cos(t * 1.3 + uv.x * 5.0)) * 0.006 * strength;
	float lod = strength * 2.5;
	vec3 col = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float k = float(i) / 5.0;
		col += textureLod(screen, mix(uv, vec2(0.5), k * 0.035 * strength), lod).rgb;
	}
	col /= 6.0;
	vec3 ghost = textureLod(screen, uv + vec2(0.014 * strength * sin(t * 0.9), 0.004 * strength), lod).rgb;
	col = mix(col, ghost, 0.35 * strength);
	float v = smoothstep(0.9, 0.25, distance(SCREEN_UV, vec2(0.5)));
	col *= mix(1.0, v, 0.75 * strength);
	col *= 1.0 - dark;
	COLOR = vec4(col, 1.0);
}
