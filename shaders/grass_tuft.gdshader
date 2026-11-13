shader_type spatial;
render_mode specular_disabled, cull_disabled;
#include "res://shaders/sky_light.gdshaderinc"
#include "res://shaders/wind_gust.gdshaderinc"

#include "res://shaders/home_ground.gdshaderinc"
#include "res://shaders/season.gdshaderinc"

uniform vec4 shadow_tint : source_color = vec4(0.66, 0.62, 0.78, 1.0);
uniform float height = 0.45;
uniform float sway = 0.06;
uniform vec3 ground = vec3(0.478, 0.698, 0.345);

varying float tip;
varying vec3 gcol;

void vertex() {
	tip = clamp(VERTEX.y / height, 0.0, 1.0);
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	VERTEX.x += sin(TIME * 1.7 + w.x * 0.35 + w.z * 0.21) * sway * tip;
	VERTEX.z += cos(TIME * 1.3 + w.z * 0.31) * sway * 0.6 * tip;

	VERTEX += (inverse(MODEL_MATRIX) * vec4(wg_dir3() * wg_gust(w.xz) * 0.08 * tip * tip, 0.0)).xyz;
	NORMAL = (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	gcol = home_grass(ground, w.xz, distance(w, INV_VIEW_MATRIX[3].xyz)) * (COLOR.rgb / vec3(0.45, 0.73, 0.27));
	if (season_strength > 0.0) {
		gcol = season_tint(gcol);
	}
}

void fragment() {
	ALBEDO = gcol * mix(vec3(0.9), vec3(1.3, 1.27, 1.06), tip);
	ROUGHNESS = 1.0;
	SL_FRAGMENT;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.2, 0.8, w * ATTENUATION);
	float reach = LIGHT_IS_DIRECTIONAL ? SL_SUN : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += mix(shadow_tint.rgb, vec3(1.0), lit) * LIGHT_COLOR / PI * reach;
}
