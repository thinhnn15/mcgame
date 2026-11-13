shader_type spatial;
render_mode specular_disabled, cull_back;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D tile_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tile_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float nrm_depth = 1.0;
uniform vec2 tile_size = vec2(1.0);
uniform vec2 tile_origin = vec2(0.0);
uniform sampler2D overlay : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D overlay_emit : filter_linear_mipmap_anisotropic;
uniform float emit_strength = 1.2;
uniform float metro_light = 0.0;
uniform float old_light = 0.0;
uniform vec4 metro_col : source_color = vec4(0.55, 0.62, 0.72, 1.0);
uniform vec4 old_col : source_color = vec4(0.9, 0.55, 0.22, 1.0);
uniform vec4 sky_col : source_color = vec4(0.82, 0.84, 0.88, 1.0);
uniform float wet_dark = 0.72;
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.58, 0.80, 1.0);
uniform float shade_soft = 0.22;
uniform float rim = 0.12;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec2 tuv = (w_pos.xz - tile_origin) / tile_size;
	vec2 cell = floor(tuv * 2.0);
	float tone = 1.0 + (fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 0.08;
	vec4 ov = texture(overlay, UV);
	vec4 em = texture(overlay_emit, UV);
	vec3 c = mix(base_color.rgb * texture(tile_alb, tuv).rgb * tone, ov.rgb, ov.a);
	c *= mix(1.0, wet_dark, em.a);
	ALBEDO = c;
	vec3 n = texture(tile_nrm, tuv).rgb * 2.0 - 1.0;
	n.xy *= nrm_depth * (1.0 - ov.a);
	vec3 wn = normalize(vec3(1.0, 0.0, 0.0) * n.x + vec3(0.0, 0.0, 1.0) * n.y + w_nrm * n.z);
	NORMAL = normalize(mat3(VIEW_MATRIX) * wn);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = c * em.r * emit_strength + metro_col.rgb * em.g * metro_light + old_col.rgb * em.b * old_light
		+ sky_col.rgb * (0.22 + fres) * em.a * 0.55;
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
