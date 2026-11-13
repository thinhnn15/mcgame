shader_type spatial;
render_mode specular_disabled, cull_back;
#include "res://shaders/sky_light.gdshaderinc"
global uniform vec4 sky_horizon : source_color;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nrm_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_nrm = true;
uniform float nrm_depth = 0.8;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D ao_tex : filter_linear_mipmap;
uniform bool has_ao = false;
uniform float ao_strength = 0.7;
uniform bool cutout = false;

uniform float damp = 0.0;
uniform float damp_y0 = 0.0;
uniform float damp_h = 0.6;
uniform float moss = 1.0;
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.58, 0.80, 1.0);
uniform float shade_soft = 0.35;
uniform float rim = 0.08;

varying float obj_y;

void vertex() {
	obj_y = VERTEX.y;
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	if (cutout && a.a < 0.5) {
		discard;
	}
	vec3 c = a.rgb * tint.rgb;
	if (has_ao) {
		c *= mix(1.0, texture(ao_tex, UV2).r, ao_strength);
	}
	float d = damp * (1.0 - smoothstep(damp_y0, damp_y0 + damp_h, obj_y));
	c *= mix(vec3(1.0), vec3(0.74, 0.77, 0.66), d);
	c = sl_moss(c, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz, moss);
	if (rain_wet > 0.0) {

		float wy = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
		float wa = mix(0.45, 1.0, smoothstep(0.2, 0.6, wy)) * smoothstep(-0.35, -0.05, wy);
		c = sl_wet(c, mix(1.0, 0.65, wa));
		EMISSION = sky_horizon.rgb * sl_sheen(dot(NORMAL, VIEW), wa * wa * 0.7);
	}
	if (has_nrm) {
		NORMAL_MAP = texture(nrm_tex, UV).rgb;
		NORMAL_MAP_DEPTH = nrm_depth;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	SL_FRAGMENT;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.5 - shade_soft, 0.5 + shade_soft, w * ATTENUATION);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), lit);

	float reach = LIGHT_IS_DIRECTIONAL ? SL_SUN : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI * reach;
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim * lit;
	DIFFUSE_LIGHT += r * LIGHT_COLOR / PI;
}
