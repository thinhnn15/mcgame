shader_type spatial;
render_mode specular_disabled, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.58, 0.80, 1.0);
uniform float shade_soft = 0.22;
uniform float rim = 0.3;
uniform float head_z = 0.2;
uniform float body_len = 0.4;

uniform float wave_n = 3.2;
uniform float eel = 0.0;
uniform float beat = 1.0;

void vertex() {
	float u = clamp((head_z - VERTEX.z) / body_len, 0.0, 1.0);
	float ph = INSTANCE_CUSTOM.r;
	float amp = INSTANCE_CUSTOM.g;
	float w = sin(ph - wave_n * u);

	float env = mix(0.10 * u * u - 0.02 * (1.0 - u) * (1.0 - u), 0.05 * (0.3 + 0.7 * u), eel);
	float denv = mix(0.20 * u + 0.04 * (1.0 - u), 0.035, eel);
	float side = env * w * amp * beat;
	float dside = (denv * w - env * wave_n * cos(ph - wave_n * u)) * amp * beat;

	float b = INSTANCE_CUSTOM.b * 0.35;
	side += b * (u - 0.33) * (u - 0.33);
	dside += b * 2.0 * (u - 0.33);
	VERTEX.x += side * body_len;

	float s = -dside;
	NORMAL = normalize(vec3(NORMAL.x + NORMAL.z * s, NORMAL.y, NORMAL.z - NORMAL.x * s));
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.5 - shade_soft, 0.5 + shade_soft, w * ATTENUATION);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), lit);
	float reach = LIGHT_IS_DIRECTIONAL ? 1.0 : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI * reach;
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim * lit;
	DIFFUSE_LIGHT += r * LIGHT_COLOR / PI;
}
