shader_type spatial;
render_mode specular_disabled, cull_back;

#include "res://shaders/intro_light.gdshaderinc"

uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.62, 0.58, 0.82, 1.0);
uniform float shade_soft = 0.3;
uniform float rim = 0.15;
uniform vec3 emission = vec3(0.0);
uniform float lamp_gain = 1.0;
uniform float stripes = 0.0;
uniform bool has_albedo = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform bool has_prop_nrm = false;
uniform sampler2D prop_nrm : hint_normal, filter_linear_mipmap;
uniform bool has_prop_emit = false;
uniform sampler2D prop_emit : filter_linear_mipmap;
uniform float emit_strength = 1.2;
uniform float wet = 0.0;
uniform float gloss = 1.0;
uniform bool has_tile = false;
uniform sampler2D tile_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tile_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 tile_size = vec2(1.0);
uniform float tile_gain = 1.08;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = base_color.rgb;
	if (has_albedo) {
		c *= texture(albedo_tex, UV).rgb;
	}
	if (stripes > 0.0) {
		float s = fract(wpos.y * stripes);
		c *= 0.78 + 0.22 * smoothstep(0.0, 0.25, s) * smoothstep(1.0, 0.7, s);
	}
	c *= 1.0 - wet * 0.25;
	if (has_prop_nrm) {
		NORMAL_MAP = texture(prop_nrm, UV).rgb;
	}
	if (has_tile) {
		vec3 an = abs(wnrm);
		vec2 tuv;
		vec3 t;
		vec3 b = vec3(0.0, -1.0, 0.0);
		if (an.y >= an.x && an.y >= an.z) {
			tuv = wpos.xz;
			t = vec3(1.0, 0.0, 0.0);
			b = vec3(0.0, 0.0, 1.0);
		} else if (an.x >= an.z) {
			tuv = vec2(wpos.z * sign(wnrm.x), -wpos.y);
			t = vec3(0.0, 0.0, sign(wnrm.x));
		} else {
			tuv = vec2(-wpos.x * sign(wnrm.z), -wpos.y);
			t = vec3(-sign(wnrm.z), 0.0, 0.0);
		}
		tuv /= tile_size;
		c *= texture(tile_alb, tuv).rgb * tile_gain;
		vec3 tn = texture(tile_nrm, tuv).rgb * 2.0 - 1.0;
		NORMAL = normalize(mat3(VIEW_MATRIX) * normalize(t * tn.x + b * tn.y + wnrm * tn.z));
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 e = emission + (has_prop_emit ? c * texture(prop_emit, UV).r * emit_strength : vec3(0.0));

	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 spec = vec3(0.0);
	vec3 L = painted_light_wet(wpos, normalize(mix(wnrm, n, 0.5)), V, 28.0, spec);
	float wk = clamp(wet * 2.5, 0.0, 1.0) * gloss * lamp_gain;
	EMISSION = e + c * L * lamp_gain + spec * 0.45 * wk;
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
