shader_type spatial;
render_mode cull_disabled, specular_disabled, depth_draw_opaque;
#include "res://shaders/sky_light.gdshaderinc"
#include "res://shaders/wind_gust.gdshaderinc"

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 shadow_tint : source_color = vec4(0.62, 0.6, 0.8, 1.0);
uniform float shade_soft = 0.4;
uniform float sway = 0.06;
uniform float flutter = 0.025;
uniform float through = 0.35;

uniform float edge_lo = 0.12;
uniform float edge_hi = 0.32;

varying float is_leaf;
varying vec3 wnrm;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	is_leaf = UV2.y >= 0.0 ? 1.0 : 0.0;
	float k = UV2.x;
	float t = TIME;
	float tp = dot(origin, vec3(0.37, 0.0, 0.21));
	float gust = 0.2 + 0.8 * wg_gust(origin.xz);
	float lean = (0.3 + 0.7 * gust) * (0.6 + 0.4 * sin(t * 1.3 + tp));
	vec3 w = wg_dir3() * lean * k * k * sway;
	float ph = UV2.y * 6.2832;
	w += is_leaf * k * flutter * (0.5 + gust) * vec3(sin(t * 5.0 + ph * 9.0), sin(t * 7.3 + ph * 5.0) * 0.6, cos(t * 4.6 + ph * 7.0));
	VERTEX += inverse(mat3(MODEL_MATRIX)) * w;
	wnrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec4 tex = texture(atlas, UV);
	ALBEDO = tex.rgb * COLOR.rgb * COLOR.a;
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	float facing = abs(dot(fn, VIEW));
	ALPHA = tex.a * (is_leaf > 0.5 ? smoothstep(edge_lo, edge_hi, facing) : 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.25;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(atlas, 0));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(wnrm, 0.0)).xyz);
	SL_FRAGMENT;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.5 - shade_soft, 0.5 + shade_soft, w * ATTENUATION);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), lit);

	float reach = LIGHT_IS_DIRECTIONAL ? SL_SUN : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI * reach;
	float trans = clamp(dot(-NORMAL, LIGHT), 0.0, 1.0) * through * ATTENUATION;
	DIFFUSE_LIGHT += trans * vec3(1.0, 1.0, 0.8) * LIGHT_COLOR / PI;
}
