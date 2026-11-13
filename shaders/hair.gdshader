shader_type spatial;
render_mode cull_disabled, shadows_disabled;
#include "res://shaders/sky_light.gdshaderinc"
const float chara = 1.0;

uniform vec4 hair_color : source_color = vec4(0.42, 0.26, 0.19, 1.0);
uniform sampler2D alb_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D mix_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_tex = false;
uniform float ao_strength = 0.8;
uniform float shine_strength = 0.3;
uniform float shift_1 = 0.12;
uniform float shift_2 = -0.18;
uniform float exp_1 = 90.0;
uniform float exp_2 = 18.0;
uniform float spec_1 = 0.015;
uniform float spec_2 = 0.0;
uniform vec4 shadow_tint : source_color = vec4(0.8, 0.72, 0.8, 1.0);
uniform float shade_soft = 0.5;
uniform float rim = 0.15;

varying vec3 strand;
varying float shift_noise;
varying float sparkle;
varying vec3 base_col;

void fragment() {
	vec3 c = hair_color.rgb;
	shift_noise = 0.0;
	sparkle = 1.0;
	if (has_tex) {
		vec4 m = texture(mix_tex, UV);
		c *= texture(alb_tex, UV).r;
		c *= mix(1.0, m.g, ao_strength);
		c *= mix(0.9, 1.05, m.r);
		vec3 shine = c * 1.45 + vec3(0.05, 0.04, 0.03);
		c = mix(c, shine, m.b * shine_strength);
		shift_noise = 0.0;
		sparkle = 0.5 + m.b;
		NORMAL_MAP = texture(nrm_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 0.35;
	}
	strand = normalize(BINORMAL);
	base_col = c;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	SL_FRAGMENT;
}

float kk(vec3 t, vec3 n, float shift, vec3 h, float e) {
	vec3 ts = normalize(t + n * shift);
	float th = dot(ts, h);
	float s = sqrt(max(0.0, 1.0 - th * th));
	return smoothstep(-1.0, 0.0, th) * pow(s, e);
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.5 - shade_soft, 0.5 + shade_soft, w * ATTENUATION);
	float rim_lit = max(lit, 0.45);
	float dlit = sl_lift(lit, NORMAL, chara, LIGHT_IS_DIRECTIONAL);

	float reach = LIGHT_IS_DIRECTIONAL ? SL_SUN : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += mix(shadow_tint.rgb, vec3(1.0), dlit) * LIGHT_COLOR / PI * reach;
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim * rim_lit;
	DIFFUSE_LIGHT += r * LIGHT_COLOR / PI;
	vec3 h = normalize(LIGHT + VIEW);
	float s1 = kk(strand, NORMAL, shift_1 + shift_noise, h, exp_1);
	float s2 = kk(strand, NORMAL, shift_2 + shift_noise, h, exp_2);

	s1 = smoothstep(0.0, 1.0, s1) * spec_1;
	s2 = smoothstep(0.0, 1.0, s2) * spec_2 * sparkle;
	SPECULAR_LIGHT += (s1 * vec3(1.0, 0.97, 0.92) + s2 * mix(base_col, vec3(1.0), 0.4)) * lit * LIGHT_COLOR;
}
