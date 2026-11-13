shader_type spatial;
render_mode specular_disabled, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D emit_tex : filter_linear_mipmap;
uniform float emit_strength = 1.6;
uniform float flutter = 0.06;
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.58, 0.80, 1.0);
uniform float shade_soft = 0.35;
uniform float rim = 0.12;

varying vec3 coat_col;
varying vec3 body_col;
varying vec2 mask;

void vertex() {
	float w = COLOR.r;
	float t = TIME * 7.0 + INSTANCE_CUSTOM.a * 6.283;
	VERTEX.y += sin(t + VERTEX.z * 5.0 + VERTEX.x * 3.0) * flutter * w;
	VERTEX.z -= (0.6 + 0.4 * sin(t * 0.7 + VERTEX.x * 4.0)) * flutter * 1.5 * w;
	coat_col = INSTANCE_CUSTOM.rgb;
	float k = floor(fract(INSTANCE_CUSTOM.a * 7.31) * 4.0);
	body_col = k < 0.5 ? vec3(0.9, 0.36, 0.34) : (k < 1.5 ? vec3(0.95, 0.93, 0.86) : (k < 2.5 ? vec3(0.36, 0.62, 0.78) : vec3(0.42, 0.45, 0.54)));
	mask = COLOR.gb;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	c *= mix(vec3(1.0), coat_col, clamp(mask.x, 0.0, 1.0));
	c *= mix(vec3(1.0), body_col, clamp(mask.y, 0.0, 1.0));
	ALBEDO = c;
	EMISSION = c * texture(emit_tex, UV).r * emit_strength + coat_col * clamp(mask.x, 0.0, 1.0) * 0.1;
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
