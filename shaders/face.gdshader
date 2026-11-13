shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_disabled;
#include "res://shaders/sky_light.gdshaderinc"
const float chara = 1.0;

uniform sampler2D eye_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D eye_mask : filter_linear_mipmap, repeat_disable;
uniform sampler2D mouth_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 eye_color : source_color = vec4(0.45, 0.28, 0.2, 1.0);
uniform vec4 brow_color : source_color = vec4(0.35, 0.22, 0.16, 1.0);
uniform vec4 blush_color : source_color = vec4(1.0, 0.55, 0.6, 1.0);
uniform float blush = 0.55;
uniform vec4 shadow_tint : source_color = vec4(0.9, 0.84, 0.9, 1.0);
uniform float shade_soft = 0.45;

uniform vec2 cheek_l = vec2(0.83, 0.66);
uniform vec2 cheek_r = vec2(0.17, 0.66);

vec4 over(vec4 dst, vec4 src) {
	float a = src.a + dst.a * (1.0 - src.a);
	vec3 c = (src.rgb * src.a + dst.rgb * dst.a * (1.0 - src.a)) / max(a, 1e-4);
	return vec4(c, a);
}

void fragment() {
	vec2 uv = UV;
	vec4 col = vec4(0.0);

	for (int i = 0; i < 2; i++) {
		vec2 c = i == 0 ? cheek_l : cheek_r;
		vec2 d = (uv - c) / vec2(0.075, 0.055);
		float b = smoothstep(1.0, 0.2, length(d)) * blush;
		col = over(col, vec4(blush_color.rgb, b * 0.6));
	}
	col = over(col, texture(mouth_tex, uv));
	vec4 e = texture(eye_tex, uv);
	vec4 m = texture(eye_mask, uv);
	vec3 iris = e.rgb * eye_color.rgb * 1.35;
	e.rgb = mix(e.rgb, iris, m.r);
	col = over(col, e);
	col = over(col, vec4(brow_color.rgb, m.g * 0.9));
	ALBEDO = col.rgb;
	ALPHA = col.a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	SL_FRAGMENT;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.5 - shade_soft, 0.5 + shade_soft, w * ATTENUATION);
	lit = sl_lift(lit, NORMAL, chara, LIGHT_IS_DIRECTIONAL);

	float reach = LIGHT_IS_DIRECTIONAL ? SL_SUN : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += mix(shadow_tint.rgb, vec3(1.0), lit) * LIGHT_COLOR / PI * reach;
}
