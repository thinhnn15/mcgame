shader_type spatial;
render_mode specular_disabled, cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.58, 0.80, 1.0);
uniform float shade_soft = 0.22;
uniform float rim = 0.3;
#include "res://shaders/sky_light.gdshaderinc"
uniform float chara = 1.0;
uniform float eye_glint = 0.45;
instance uniform float blink = 0.0;

instance uniform float glow = 0.0;

void fragment() {
	vec2 uv = UV;
	if (uv.y > 0.875) {
		uv.x += 0.25 * blink;
	}
	ALBEDO = texture(albedo_tex, uv).rgb * tint.rgb;
	if (UV.y > 0.875) {

		float l = dot(ALBEDO, vec3(0.333));
		EMISSION = ALBEDO * smoothstep(0.9, 0.97, l) * eye_glint;
	}
	if (glow > 0.0 && UV.x > 0.75 && UV.y < 0.25) {
		EMISSION = ALBEDO * glow;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	SL_FRAGMENT;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.5 - shade_soft, 0.5 + shade_soft, w * ATTENUATION);
	float rim_lit = mix(lit, max(lit, 0.45), chara);
	lit = sl_lift(lit, NORMAL, chara, LIGHT_IS_DIRECTIONAL);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), lit);
	float reach = LIGHT_IS_DIRECTIONAL ? SL_SUN : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI * reach;
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim * rim_lit;
	DIFFUSE_LIGHT += r * LIGHT_COLOR / PI * reach;
}
