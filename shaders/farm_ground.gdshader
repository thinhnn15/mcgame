shader_type spatial;
render_mode specular_disabled;

#include "res://shaders/farm_ground.gdshaderinc"
#include "res://shaders/season.gdshaderinc"

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grass_tile = 2.4;
uniform float dirt_tile = 2.0;
uniform float cloud_depth = 0.80;
uniform float wet = 0.0;
uniform vec4 puddle_col : source_color = vec4(0.55, 0.60, 0.63, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.60, 0.80, 1.0);
uniform float shade_soft = 0.22;
uniform float rim = 0.12;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 xz = wpos.xz;
	vec4 sp = splat_at(xz);
	vec3 g = grass_colour(xz, sp) * texture(grass_tex, xz / grass_tile).rgb * 1.12;
	vec3 d = texture(dirt_tex, xz / dirt_tile).rgb;
	d *= 0.95 + 0.1 * noise_at(xz, 9.0).g;
	float m = dirt_amount(xz, sp);
	float steep = smoothstep(0.80, 0.62, wnrm.y);
	m = max(m, steep);
	vec3 c = mix(g, d, m);
	c *= cloud_shade(xz, TIME, cloud_depth);
	if (wet > 0.0) {
		c *= mix(1.0, 0.70, wet * (0.55 + 0.45 * m));

		float pn = noise_at(xz + vec2(3.0, 9.0), 4.0).g;
		float where = wet * max(m, sp.g * 0.3);
		float puddle = where * smoothstep(0.61, 0.69, pn);
		float rim_ = where * (smoothstep(0.55, 0.62, pn) - puddle);
		c *= 1.0 - 0.18 * rim_;

		vec2 q = xz * 3.4;
		vec2 cell = floor(q);
		float hsh = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		vec2 at = cell + 0.25 + 0.5 * vec2(hsh, fract(hsh * 7.31));
		float t = fract(TIME * 1.5 + hsh);
		float ring = smoothstep(0.025, 0.0, abs(length(q - at) - t * 0.34)) * (1.0 - t);
		c = mix(c, mix(c, puddle_col.rgb, 0.75), puddle);
		c += ring * puddle * 0.16;
	}
	if (season_strength > 0.0) {
		c = season_tint_w(c, 0.5);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.5 - shade_soft, 0.5 + shade_soft, w * ATTENUATION);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), lit);
	float reach = LIGHT_IS_DIRECTIONAL ? 1.0 : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI * reach;
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim * lit;
	DIFFUSE_LIGHT += r * LIGHT_COLOR / PI;
}
