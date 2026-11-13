shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic;
uniform float sway = 0.0;

void vertex() {
	float hang = 1.0 - UV.y;
	float phase = floor(VERTEX.z * 2.0) * 1.7 + floor(VERTEX.x * 3.0);
	VERTEX.z += sin(TIME * 1.6 + phase) * sway * hang;
}

void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.15, 0.85, w * ATTENUATION);
	DIFFUSE_LIGHT += mix(vec3(0.72, 0.68, 0.8), vec3(1.0), lit) * LIGHT_COLOR * ATTENUATION / PI;
}
