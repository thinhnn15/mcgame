shader_type spatial;
render_mode specular_disabled, cull_disabled;
#include "res://shaders/sky_light.gdshaderinc"
#include "res://shaders/wind_gust.gdshaderinc"

#include "res://shaders/home_ground.gdshaderinc"
#include "res://shaders/season.gdshaderinc"

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

uniform float sway = 0.05;
uniform float gust = 0.11;
uniform vec4 pusher = vec4(0.0, -100.0, 0.0, 0.7);
uniform float fade_from = 20.0;
uniform float fade_to = 26.0;
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.62, 0.78, 1.0);

varying vec3 vcol;

void vertex() {
	vec3 ipos = MODEL_MATRIX[3].xyz;
	mat3 to_local = inverse(mat3(MODEL_MATRIX));
	float h = UV.y;
	float dist = distance(ipos, INV_VIEW_MATRIX[3].xyz);
	float keep = 1.0 - smoothstep(fade_from, fade_to, dist);
	VERTEX *= vec3(mix(0.4, 1.0, keep), keep, mix(0.4, 1.0, keep));
	vec3 wd = wg_dir3();
	float wave = sin(dot(ipos.xz, wd.xz) * 0.9 - TIME * 1.7 + UV.x * 3.0) * 0.5 + 0.5;
	float g = wg_gust(ipos.xz);
	vec3 bend = wd * (sway * wave + gust * g * (0.6 + 0.4 * wave)) * h * h;
	vec2 d = ipos.xz - pusher.xz;
	float near = 1.0 - smoothstep(0.12, pusher.w, length(d));
	if (near > 0.0) {
		vec2 away = normalize(d + vec2(0.001, 0.0));
		bend += vec3(away.x, 0.0, away.y) * near * 0.16 * h;
		bend.y -= near * 0.10 * h;
	}
	VERTEX += to_local * bend;
	NORMAL = normalize(to_local * vec3(0.0, 1.0, 0.0));

	vec3 base = home_grass(COLOR.rgb, ipos.xz, dist);
	float ch = hash(floor(ipos.xz * 3.1) + 0.37);
	vec3 tint = ch < 0.5 ? vec3(1.0) : (ch < 0.7 ? vec3(0.88, 1.02, 0.86) : (ch < 0.92 ? vec3(1.08, 1.02, 0.78) : vec3(1.1, 1.08, 0.96)));
	vcol = base * tint * mix(vec3(0.7), vec3(1.4, 1.36, 1.12), h) * (0.95 + 0.1 * UV.x);
	if (season_strength > 0.0) {
		vcol = season_tint(vcol);
	}
}

void fragment() {
	ALBEDO = vcol;
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
