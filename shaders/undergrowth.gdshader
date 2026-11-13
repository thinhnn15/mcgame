shader_type spatial;
render_mode specular_disabled, cull_disabled;
#include "res://shaders/sky_light.gdshaderinc"
#include "res://shaders/wind_gust.gdshaderinc"

#include "res://shaders/home_ground.gdshaderinc"
#include "res://shaders/season.gdshaderinc"

uniform sampler2D kit_data : filter_nearest, repeat_disable;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 ground_green = vec3(0.478, 0.698, 0.345);
uniform float flower_scale = 1.45;

uniform float weed_keep = 0.45;
uniform float weed_scale = 1.45;
uniform float leaf_lift = 1.08;
uniform float sway = 0.03;
uniform float gust = 0.07;
uniform vec4 pusher = vec4(0.0, -100.0, 0.0, 0.7);
uniform float fade_from = 17.0;
uniform float fade_to = 23.0;
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.62, 0.78, 1.0);

varying vec3 vtint;
varying vec3 vleaf;
varying float vmask;

void vertex() {
	int k = int(INSTANCE_CUSTOM.x + 0.5);
	int vi = int(UV.x + 0.5);
	vec4 a = texelFetch(kit_data, ivec2(vi, k * 3), 0);
	vec4 b = texelFetch(kit_data, ivec2(vi, k * 3 + 1), 0);
	vec4 c = texelFetch(kit_data, ivec2(vi, k * 3 + 2), 0);
	float sc = k >= 4 ? flower_scale : (INSTANCE_CUSTOM.w < weed_keep ? weed_scale : 0.0);
	VERTEX = a.xyz * sc;
	UV = vec2(a.w, b.w);

	vec3 ipos = MODEL_MATRIX[3].xyz;
	mat3 to_local = inverse(mat3(MODEL_MATRIX));
	float dist = distance(ipos, INV_VIEW_MATRIX[3].xyz);
	float keep = 1.0 - smoothstep(fade_from, fade_to, dist);
	VERTEX *= vec3(mix(0.3, 1.0, keep), keep, mix(0.3, 1.0, keep));
	float h = clamp(VERTEX.y / 0.25, 0.0, 1.0);
	vec3 wd = wg_dir3();
	float wave = sin(dot(ipos.xz, wd.xz) * 0.9 - TIME * 1.7 + INSTANCE_CUSTOM.w * 13.0) * 0.5 + 0.5;
	float g = wg_gust(ipos.xz);
	vec3 bend = wd * (sway * wave + gust * g * (0.6 + 0.4 * wave)) * h * h;
	vec2 d = ipos.xz - pusher.xz;
	float near = 1.0 - smoothstep(0.12, pusher.w, length(d));
	if (near > 0.0) {
		vec2 away = normalize(d + vec2(0.001, 0.0));
		bend += vec3(away.x, 0.0, away.y) * near * 0.1 * h;
		bend.y -= near * 0.06 * h;
	}
	VERTEX += to_local * bend;
	NORMAL = normalize(to_local * vec3(0.0, 1.0, 0.0));

	vec3 turf = home_grass(ground_green, ipos.xz, dist);
	float ch = INSTANCE_CUSTOM.y;
	vec3 tint = ch < 0.6 ? vec3(1.0) : (ch < 0.8 ? vec3(0.96, 1.03, 0.94) : vec3(1.06, 1.04, 0.9));
	vec3 grad = c.rgb * 1.25;
	vleaf = turf * tint * leaf_lift * max(mix(vec3(1.0), grad, 0.35), vec3(1.0));
	vtint = grad;
	vmask = c.a;
}

void fragment() {
	vec4 t = texture(atlas, UV);

	float lum = dot(t.rgb, vec3(0.3, 0.59, 0.11));
	vec3 leaf = vleaf * clamp(mix(1.0, lum / 0.52, 0.5), 0.95, 1.25);
	ALBEDO = mix(t.rgb * vtint, leaf, vmask);
	if (season_strength > 0.0) {
		ALBEDO = season_tint(ALBEDO);
	}
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SL_FRAGMENT;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.2, 0.8, w * ATTENUATION);
	float reach = LIGHT_IS_DIRECTIONAL ? SL_SUN : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += mix(shadow_tint.rgb, vec3(1.0), lit) * LIGHT_COLOR / PI * reach;
	float back = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 4.0) * 0.2 * lit;
	DIFFUSE_LIGHT += back * LIGHT_COLOR / PI;
}
