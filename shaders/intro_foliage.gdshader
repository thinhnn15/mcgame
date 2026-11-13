shader_type spatial;
render_mode cull_disabled, specular_disabled, depth_draw_opaque;

#include "res://shaders/intro_light.gdshaderinc"
#include "res://shaders/intro_wind.gdshaderinc"
#include "res://shaders/season.gdshaderinc"

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 shadow_tint : source_color = vec4(0.4, 0.42, 0.68, 1.0);
uniform float shade_soft = 0.35;
uniform float lamp_gain = 1.15;
uniform float wet = 1.0;
uniform float sway = 0.11;
uniform float flutter = 0.035;
uniform float glint = 0.6;
uniform float back_light = 0.35;
uniform float rim = 0.5;
uniform vec4 sky_fill : source_color = vec4(0.17, 0.19, 0.32, 1.0);
uniform vec4 ground_fill : source_color = vec4(0.03, 0.035, 0.06, 1.0);

varying vec3 wpos;
varying vec3 wnrm;
varying float is_leaf;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	is_leaf = UV2.y >= 0.0 ? 1.0 : 0.0;
	float k = UV2.x;
	float t = TIME;

	float g = wind_gust(origin, t);
	float tp = dot(origin, vec3(0.37, 0.0, 0.21));
	float lean = (0.35 + 0.65 * g) + 0.35 * sin(t * 1.25 + tp) + 0.15 * sin(t * 2.3 + tp * 1.7);
	vec3 w = WIND_DIR * lean * k * k * sway * 2.0;
	w.y -= 0.25 * lean * k * k * sway;

	float ph = UV2.y * 6.2832;
	w += is_leaf * k * flutter * (0.6 + 0.8 * g) * vec3(sin(t * 7.0 + ph * 9.0), sin(t * 9.3 + ph * 5.0) * 0.7, cos(t * 6.1 + ph * 7.0));
	VERTEX += inverse(mat3(MODEL_MATRIX)) * w;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec4 tex = texture(atlas, UV);

	NORMAL = normalize((VIEW_MATRIX * vec4(wnrm, 0.0)).xyz);
	vec3 c = tex.rgb * COLOR.rgb;
	if (season_strength > 0.0) {
		c = season_tint(c);
	}
	float ao = COLOR.a;

	float l = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(vec3(l), c, 1.0 + 0.18 * wet) * (1.0 - 0.22 * wet);
	ALBEDO = c * ao;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.25;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(atlas, 0));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 L = painted_light(wpos, wnrm);

	vec3 Lb = painted_light(wpos, -wnrm) * is_leaf;
	float fres = pow(1.0 - clamp(abs(dot(wnrm, V)), 0.0, 1.0), 2.0);
	vec3 e = c * ao * L * lamp_gain;
	e += c * Lb * (back_light + rim * fres) * mix(0.6, 1.0, ao);

	vec3 jn = normalize(wnrm + 0.9 * (vec3(hash12(floor(UV * 96.0)), hash12(floor(UV * 96.0) + 7.1), hash12(floor(UV * 96.0) + 3.3)) - 0.5));
	float spark = 0.0;
	for (int i = 0; i < src_n; i++) {
		vec3 d = src_pos[i].xyz - wpos;
		float dist = length(d);
		float f = clamp(1.0 - dist / (src_pos[i].w * 1.2), 0.0, 1.0);
		if (f <= 0.0) {
			continue;
		}
		vec3 H = normalize(d / dist + V);
		spark += pow(max(dot(jn, H), 0.0), 40.0) * f * src_col[i].a;
	}
	e += vec3(1.0, 0.92, 0.8) * spark * glint * wet * smoothstep(0.15, 0.45, l) * is_leaf;
	EMISSION = e + mix(ground_fill.rgb, sky_fill.rgb, smoothstep(-0.6, 0.8, wnrm.y)) * c * ao;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.5 - shade_soft, 0.5 + shade_soft, w * ATTENUATION);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), lit);
	float reach = LIGHT_IS_DIRECTIONAL ? 1.0 : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI * reach;

	float trans = clamp(dot(-NORMAL, LIGHT), 0.0, 1.0) * 0.3;
	DIFFUSE_LIGHT += trans * LIGHT_COLOR / PI * reach;
}
