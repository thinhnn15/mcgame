shader_type spatial;
render_mode specular_disabled;
#include "res://shaders/sky_light.gdshaderinc"
#include "res://shaders/wind_gust.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile = 8.0;
uniform vec2 ring = vec2(44.0, 100000.0);
uniform vec3 focus = vec3(0.0);
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.62, 0.78, 1.0);

uniform sampler2D cells : filter_nearest, repeat_disable;
uniform sampler2D cells_soft : filter_linear, repeat_disable;
uniform bool has_cells = false;
uniform float grid_n = 2049.0;
uniform float grid_half = 1024.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {

	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float d = distance(wpos.xz, focus.xz);
	if (d < ring.x || d > ring.y) {
		discard;
	}
	float cv = 0.5;
	if (has_cells) {
		vec2 cuv = (wpos.xz + grid_half + 0.5) / grid_n;
		cv = texture(cells, cuv).r;

		if (cv < 0.002 || texture(cells_soft, cuv).r < cv * 0.5) {
			discard;
		}
	}

	vec2 q = wpos.xz;
	mat2 rot = mat2(vec2(0.7986, 0.6018), vec2(-0.6018, 0.7986));
	vec3 a = texture(tex, q / tile).rgb;
	vec3 b = texture(tex, (rot * q) / (tile * 1.63)).rgb;
	float n1 = vnoise(q / 40.0);
	float n2 = vnoise(q / 23.0 + 7.3);
	vec3 c = mix(a, b, smoothstep(0.3, 0.7, n1));
	vec3 avg = textureLod(tex, vec2(0.5), 9.0).rgb;
	c = mix(c, avg, 0.62 * smoothstep(30.0, 95.0, d));

	c *= (0.92 + 0.14 * n2) * mix(vec3(1.16, 1.08, 0.92), vec3(1.24, 1.15, 0.86), vnoise(q / 55.0 + 3.1));
	float pv = fract(cv * 251.0 * 0.6180339);
	c *= mix(0.84, 1.1, pv);
	c = mix(c, c * vec3(0.62, 1.1, 0.5), smoothstep(0.64, 0.7, pv));

	c = mix(c, c * vec3(1.1, 0.92, 0.74), smoothstep(0.16, 0.06, pv) * 0.8);

	float g = clamp(wg_gust_px(q), 0.0, 1.0);
	c *= 1.0 + 0.10 * g - 0.02 * (1.0 - g);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SL_FRAGMENT;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.2, 0.8, w * ATTENUATION);
	float reach = LIGHT_IS_DIRECTIONAL ? SL_SUN : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += mix(shadow_tint.rgb, vec3(1.0), lit) * LIGHT_COLOR / PI * reach;
}
