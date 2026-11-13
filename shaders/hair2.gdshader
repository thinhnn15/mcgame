shader_type spatial;
render_mode cull_disabled, shadows_disabled;
#include "res://shaders/sky_light.gdshaderinc"
const float chara = 1.0;

uniform vec4 hair_color : source_color = vec4(0.42, 0.26, 0.19, 1.0);
uniform sampler2D alb_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D mix_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_tex = false;
uniform float ao_strength = 1.0;
uniform float shade_edge = 0.46;
uniform float shade_soft = 0.08;
uniform vec4 shadow_tint : source_color = vec4(0.8, 0.69, 0.65, 1.0);
uniform float hl_strength = 0.7;
uniform float hl_shade = 0.25;
uniform float hl_slide = 0.05;
uniform float rim = 0.22;
uniform float hat_shade = 0.0;

varying vec3 base_col;
varying float hl;

void fragment() {

	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 c = hair_color.rgb;
	hl = 0.0;
	if (has_tex) {
		vec4 m = texture(mix_tex, UV);
		c *= texture(alb_tex, UV).r;
		c *= mix(1.0, m.g, ao_strength);

		float lo = UV.y < 0.6 ? 0.0 : (UV.y < 0.8 ? 0.6 : 0.8);
		float hi = UV.y < 0.6 ? 0.6 : (UV.y < 0.8 ? 0.8 : 1.0);
		float s = dot(normalize(BINORMAL), VIEW) * hl_slide;
		hl = texture(mix_tex, vec2(UV.x, clamp(UV.y + s, lo + 0.002, hi - 0.002))).b;

		hl *= smoothstep(-0.2, 0.6, dot(NORMAL, VIEW));
		NORMAL_MAP = texture(nrm_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 0.5;
	}

	c *= COLOR.rgb;
	base_col = c;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	SL_FRAGMENT;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(shade_edge - shade_soft, shade_edge + shade_soft, w * ATTENUATION);
	float reach = LIGHT_IS_DIRECTIONAL ? SL_SUN : smoothstep(0.0, 0.2, ATTENUATION);
	float dlit = sl_lift(lit, NORMAL, chara, LIGHT_IS_DIRECTIONAL);
	DIFFUSE_LIGHT += mix(shadow_tint.rgb, vec3(1.0), dlit) * mix(1.0, 0.8, hat_shade) * LIGHT_COLOR / PI * reach;
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim * mix(1.0, 0.2, hat_shade) * max(lit, 0.45);
	DIFFUSE_LIGHT += r * LIGHT_COLOR / PI * reach;

	float lum = dot(base_col, vec3(0.3, 0.59, 0.11));
	vec3 hcol = mix(base_col + vec3(0.10, 0.11, 0.14), base_col * vec3(1.38, 1.3, 1.2) + vec3(0.04, 0.03, 0.02), smoothstep(0.02, 0.15, lum));

	DIFFUSE_LIGHT += hl * hl_strength * mix(1.0, 0.2, hat_shade) * hcol / max(base_col, vec3(0.03)) * mix(hl_shade, 1.0, lit) * LIGHT_COLOR / PI * reach;
}
