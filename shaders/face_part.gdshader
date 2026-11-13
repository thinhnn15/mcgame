shader_type spatial;
render_mode specular_disabled, cull_back;
#include "res://shaders/sky_light.gdshaderinc"
const float chara = 1.0;

uniform int mode = 1;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform bool has_tex = false;
uniform bool has_mask = false;

uniform sampler2D brow_mask : filter_linear_mipmap, repeat_disable;
uniform bool has_brow_mask = false;
uniform sampler2D deco : source_color, filter_linear_mipmap, repeat_disable;
uniform bool has_deco = false;
uniform vec4 skin : source_color = vec4(1.0, 0.84, 0.77, 1.0);
uniform vec4 eye_color : source_color = vec4(0.45, 0.28, 0.2, 1.0);
uniform vec4 brow_color : source_color = vec4(0.35, 0.22, 0.16, 1.0);
uniform vec4 blush_color : source_color = vec4(1.0, 0.55, 0.6, 1.0);
uniform float blush = 0.55;

uniform vec4 shadow_tint : source_color = vec4(0.93, 0.9, 0.87, 1.0);
uniform float shade_soft = 0.45;
uniform float rim = 0.15;

void fragment() {
	vec3 c = skin.rgb;
	vec4 t = has_tex ? texture(tex, UV) : vec4(0.0);
	vec4 m = has_mask ? texture(mask, UV) : vec4(0.0);
	vec4 dc = has_deco ? texture(deco, UV) : vec4(0.0);
	if (mode != 3) {
		c = mix(c, dc.rgb, dc.a);
	}
	if (mode == 1) {
		vec3 d = mix(t.rgb, t.rgb * eye_color.rgb * 1.35, m.r);
		c = mix(c, d, t.a);
		if (has_brow_mask) {
			c = mix(c, brow_color.rgb, texture(brow_mask, UV).g * 0.9);
		}
	} else if (mode == 2) {
		c = mix(c, t.rgb, t.a);
	} else if (mode == 3) {
		c = mix(c, blush_color.rgb, t.a * blush * 0.7);
		c = mix(c, dc.rgb, dc.a);
	} else if (mode == 4) {
		c = mix(c, t.rgb, t.a);
		c = mix(c, brow_color.rgb, m.g * 0.9);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	SL_FRAGMENT;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.5 - shade_soft, 0.5 + shade_soft, w * ATTENUATION);
	float rim_lit = max(lit, 0.45);
	lit = sl_lift(lit, NORMAL, chara, LIGHT_IS_DIRECTIONAL);

	float reach = LIGHT_IS_DIRECTIONAL ? SL_SUN : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += mix(shadow_tint.rgb, vec3(1.0), lit) * LIGHT_COLOR / PI * reach;
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim * rim_lit;
	DIFFUSE_LIGHT += r * LIGHT_COLOR / PI;
}
