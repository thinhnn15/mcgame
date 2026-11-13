uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D splat_tex : filter_linear, repeat_disable;
uniform vec4 splat_rect = vec4(-24.0, -24.0, 48.0, 48.0);
uniform vec4 grass_lush : source_color = vec4(0.56, 0.79, 0.33, 1.0);
uniform vec4 grass_dry : source_color = vec4(0.82, 0.82, 0.44, 1.0);
uniform vec4 grass_deep : source_color = vec4(0.40, 0.66, 0.36, 1.0);
uniform vec4 worn_col : source_color = vec4(0.74, 0.72, 0.46, 1.0);

vec4 splat_at(vec2 xz) {
	vec2 uv = (xz - splat_rect.xy) / splat_rect.zw;
	return texture(splat_tex, uv);
}

vec4 noise_at(vec2 xz, float metres) {
	return texture(noise_tex, xz / metres);
}

vec3 grass_colour(vec2 xz, vec4 sp) {
	vec4 n1 = noise_at(xz, 46.0);
	vec4 n2 = noise_at(xz + vec2(17.0, 5.0), 13.0);
	vec3 c = mix(grass_lush.rgb, grass_dry.rgb, smoothstep(0.42, 0.74, n1.r));
	c = mix(c, grass_deep.rgb, smoothstep(0.50, 0.80, n1.g) * 0.55);
	c *= 0.92 + 0.16 * n2.b;
	c = mix(c, grass_deep.rgb * 0.95, sp.b * 0.8);
	c = mix(c, worn_col.rgb, sp.g * 0.85);
	return c;
}

float dirt_amount(vec2 xz, vec4 sp) {
	float edge = noise_at(xz, 3.0).b - 0.5;
	return smoothstep(0.42, 0.58, sp.r + edge * 0.55);
}

float cloud_shade(vec2 xz, float t, float depth) {
	float c = noise_at(xz + vec2(t * 1.1, t * 0.45), 70.0).a;
	return mix(1.0, depth, smoothstep(0.56, 0.72, c));
}
