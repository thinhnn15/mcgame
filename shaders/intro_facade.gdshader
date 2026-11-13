shader_type spatial;
render_mode specular_disabled, cull_back;

#include "res://shaders/intro_light.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 shadow_tint : source_color = vec4(0.62, 0.58, 0.82, 1.0);
uniform float shade_soft = 0.3;
uniform float rim = 0.12;
uniform float glow_k = 1.0;
uniform float lamp_gain = 1.0;
uniform float wet = 0.3;
uniform float albedo_gain = 1.22;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	float glow = 1.0 - COLOR.a;
	vec3 c = t.rgb * COLOR.rgb * mix(albedo_gain, 1.0, glow);

	float splash = 1.0 - smoothstep(-31.85, -31.0, wpos.y);
	c *= 1.0 - (wet * 0.25 + 0.12 * splash) * (1.0 - glow);
	ALBEDO = c * (1.0 - 0.75 * glow);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;

	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 spec = vec3(0.0);
	vec3 L = painted_light_wet(wpos, wnrm, V, 18.0, spec);
	float riv = wall_rivulets(wpos, wnrm, TIME, 0.35) * (1.0 - glow) * t.a;
	EMISSION = c * glow * glow_k + c * L * lamp_gain * (1.0 - glow)
		+ (spec * 0.22 * wet * 2.0 + L * riv * 0.9 + vec3(0.06, 0.07, 0.11) * riv) * (1.0 - glow);
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.5 - shade_soft, 0.5 + shade_soft, w * ATTENUATION);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), lit);
	float reach = LIGHT_IS_DIRECTIONAL ? 1.0 : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI * reach;
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim * lit;
	DIFFUSE_LIGHT += r * LIGHT_COLOR / PI * reach;
}
