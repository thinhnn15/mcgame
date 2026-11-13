shader_type spatial;
render_mode specular_disabled, cull_disabled;

#include "res://shaders/farm_ground.gdshaderinc"
#include "res://shaders/season.gdshaderinc"

uniform vec3 wind_dir = vec3(1.0, 0.0, 0.35);
uniform float sway = 0.05;
uniform float gust = 0.12;
uniform vec4 pusher = vec4(0.0, -100.0, 0.0, 0.7);
uniform float fade_from = 11.0;
uniform float fade_to = 16.0;
uniform bool flowers = false;
uniform float wet = 0.0;
uniform float cloud_depth = 0.80;
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.60, 0.80, 1.0);
uniform float shade_soft = 0.25;

varying vec3 vcol;
varying vec3 wpos;

void vertex() {
	vec3 ipos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	mat3 to_local = inverse(mat3(MODEL_MATRIX));
	float h = COLOR.a;

	float dist = distance(ipos, INV_VIEW_MATRIX[3].xyz);
	float keep = 1.0 - smoothstep(fade_from, fade_to, dist);
	VERTEX *= vec3(mix(0.4, 1.0, keep), keep, mix(0.4, 1.0, keep));

	vec3 wd = normalize(wind_dir);
	float wave = sin(dot(ipos.xz, wd.xz) * 0.9 - TIME * 1.7 + COLOR.r * 3.0) * 0.5 + 0.5;
	float g = smoothstep(0.35, 0.8, noise_at(ipos.xz - wd.xz * TIME * 2.4, 24.0).a);
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
	vec4 sp = splat_at(ipos.xz);
	if (flowers) {
		vcol = INSTANCE_CUSTOM.rgb * (0.85 + 0.2 * h);
	} else {
		vcol = grass_colour(ipos.xz, sp) * mix(0.62, 1.16, h) * (0.92 + 0.16 * COLOR.r);
		if (season_strength > 0.0) {
			vcol = season_tint(vcol);
		}
	}
	wpos = ipos;
}

void fragment() {
	ALBEDO = vcol * cloud_shade(wpos.xz, TIME, cloud_depth) * mix(1.0, 0.78, wet);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.5 - shade_soft, 0.5 + shade_soft, w * ATTENUATION);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), lit);
	float reach = LIGHT_IS_DIRECTIONAL ? 1.0 : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI * reach;

	float back = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 4.0) * 0.25 * lit;
	DIFFUSE_LIGHT += back * LIGHT_COLOR / PI;
}
