shader_type spatial;
render_mode blend_mix, depth_draw_opaque, specular_disabled, cull_back;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform bool has_depth = true;
uniform float depth_max = 2.5;
uniform float grid_n = 2049.0;
uniform float grid_half = 1024.0;
uniform bool stream = false;
uniform float stream_depth = 0.45;
uniform bool paddy = false;
uniform sampler2D paddy_mask : filter_nearest, repeat_disable;
uniform vec4 shore_col : source_color = vec4(0.62, 0.84, 0.76, 1.0);
uniform vec4 shallow_col : source_color = vec4(0.36, 0.72, 0.80, 1.0);
uniform vec4 deep_col : source_color = vec4(0.17, 0.42, 0.66, 1.0);
uniform vec4 sky_col : source_color = vec4(0.82, 0.92, 0.98, 1.0);
uniform vec4 foam_col : source_color = vec4(0.97, 0.99, 1.0, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.70, 0.70, 0.86, 1.0);
uniform vec3 wind_dir = vec3(0.94, 0.0, 0.33);
uniform float ripple_scale = 0.3;
uniform float ripple_speed = 0.05;
uniform float detail_end = 90.0;
uniform float clear_min = 0.3;
uniform float clear_depth = 1.1;
uniform float caustic = 0.22;

global uniform float moon_glint;
#include "res://shaders/water_flow.gdshaderinc"

varying vec3 wpos;
varying float wdepth;
varying float cam_d;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	cam_d = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float d;
	if (paddy) {
		if (texture(paddy_mask, (wpos.xz + grid_half + 0.5) / grid_n).r < 0.002) {
			discard;
		}
		d = 0.25;
	} else if (stream) {
		float across = abs(UV.x * 2.0 - 1.0);
		d = stream_depth * (1.0 - across * across);
	} else if (has_depth) {
		d = texture(depth_map, (wpos.xz + grid_half + 0.5) / grid_n).r * depth_max;
	} else {
		d = depth_max;
	}

	float near = 1.0 - smoothstep(detail_end * 0.5, detail_end, length(VERTEX));

	vec2 flow = stream ? vec2(0.0, 1.0) : normalize(wind_dir.xz);
	vec2 p = stream ? vec2(UV.x * 3.0, UV.y) : wpos.xz;
	vec2 uv1 = p * ripple_scale + flow * TIME * ripple_speed * (stream ? 4.0 : 1.0);
	vec2 uv2 = p * ripple_scale * 2.3 - vec2(flow.y, -flow.x) * TIME * ripple_speed * 1.4;

	float wa = 0.6;
	float wb = 0.4;
	float wk = 1.0;
	float od = 7.0;
	float fm = 0.0;
	if (water2 && !paddy) {
		vec4 fs = stream ? vec4(0.0, stream_flow * (1.0 - pow(abs(UV.x * 2.0 - 1.0), 2.0)), 7.0, 0.5 + 0.5 * sin(UV.y * 0.15)) : w2_sample(wpos.xz);
		od = fs.z;
		fm = smoothstep(0.05, 0.5, length(fs.xy));
		w2_flow(fs.xy * ripple_scale, fs.w, TIME, uv1, uv2, wa, wb, wk);

		uv2 = mat2(vec2(0.7986, -0.6018), vec2(0.6018, 0.7986)) * uv2 * 1.4142;
	}
	float h1 = texture(noise_tex, uv1).r;
	float h2 = texture(noise_tex, uv2).r;
	float h = 0.5 + (h1 * wa + h2 * wb - 0.5) * wk;

	float e = 0.03;
	float hx = (texture(noise_tex, uv1 + vec2(e, 0.0)).r * wa + texture(noise_tex, uv2 + vec2(e * 2.3, 0.0)).r * wb - 0.5) * wk + 0.5 - h;
	float hz = (texture(noise_tex, uv1 + vec2(0.0, e)).r * wa + texture(noise_tex, uv2 + vec2(0.0, e * 2.3)).r * wb - 0.5) * wk + 0.5 - h;

	vec3 nw = normalize(vec3(-hx * 1.2 * near, 1.0, -hz * 1.2 * near));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	float b1 = smoothstep(0.08, 0.32, d);
	float b2 = smoothstep(0.7, 1.4, d + (h - 0.5) * 0.08);

	vec3 sh_c = water2 ? mix(shallow_col.rgb, vec3(0.24, 0.56, 0.47), 0.82) : shallow_col.rgb;
	vec3 dp_c = water2 ? mix(deep_col.rgb, vec3(0.06, 0.24, 0.21), 0.9) : deep_col.rgb;
	vec3 col = mix(shore_col.rgb, sh_c, b1);
	col = mix(col, dp_c, b2);
	col *= 0.96 + 0.08 * h;

	float rl = smoothstep(0.60, 0.625, h) * (1.0 - smoothstep(0.64, 0.67, h)) * b1 * near;
	col = mix(col, mix(col, sky_col.rgb, 0.75), rl * (0.15 + 0.07 * fm));

	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	col = mix(col, sky_col.rgb, smoothstep(0.55, 0.85, fres) * 0.3);

	float breathe = 0.5 + 0.5 * sin(TIME * 1.1 + (wpos.x + wpos.z) * 0.15);
	float lap = 1.0 - smoothstep(0.03, 0.07 + 0.05 * breathe, d + (h1 - 0.5) * 0.06);
	float ring2 = smoothstep(0.012, 0.0, abs(d - (0.17 + 0.07 * breathe) + (h2 - 0.5) * 0.06)) * 0.55 * near;

	float wet = (has_depth && !paddy && !stream) ? smoothstep(0.0, 0.025, d) : 1.0;
	float foam = clamp(max(lap, ring2), 0.0, 1.0) * wet;
	if (water2) {

		float fleck = smoothstep(0.87, 0.9, h2) * wb * fm * near * 0.4;

		float st = (smoothstep(0.62, 0.645, h1) * (1.0 - smoothstep(0.67, 0.71, h1)) * wa
			+ smoothstep(0.62, 0.645, h2) * (1.0 - smoothstep(0.67, 0.71, h2)) * wb) * near * (0.35 + 0.65 * fm);
		col = mix(col, mix(col, sky_col.rgb, 0.7), st * 0.17);
		float ring = od < 3.0 ? w2_ring(od, h1, breathe, TIME) : 0.0;
		foam = max(foam, max(fleck, ring) * wet);
		if (boat_wake.w > 0.05) {
			float rip;
			foam = max(foam, w2_wake(wpos.xz, h2, rip) * wet);
			col = mix(col, dp_c, rip * 0.25);
		}
	}

	if (stream && COLOR.r + COLOR.g > 0.0) {
		float wn = texture(noise_tex, vec2(UV.x * 1.7, UV.y * 0.35 - TIME * 0.9)).r;
		float white = COLOR.r * (0.6 + 0.4 * smoothstep(0.35, 0.55, wn))
			+ COLOR.g * smoothstep(0.45, 0.62, wn + (h2 - 0.5) * 0.3);
		foam = max(foam, clamp(white, 0.0, 1.0));
	}

	float shal = smoothstep(0.02, 0.1, d) * (1.0 - smoothstep(0.25, 0.9, d)) * near;
	if (shal > 0.0) {
		float c1 = texture(noise_tex, wpos.xz * 0.55 + vec2(0.7, 0.4) * TIME * 0.035).r;
		float c2 = texture(noise_tex, wpos.xz * 0.47 * mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) - vec2(0.3, 0.8) * TIME * 0.03).r;
		float net = 1.0 - smoothstep(0.0, 0.035, abs(c1 - c2));
		col += net * caustic * 0.35 * shal * vec3(1.0, 0.98, 0.85);
	}
	col = mix(col, foam_col.rgb, foam);
	ALBEDO = col;
	ROUGHNESS = 1.0;

	float a = mix(clear_min, 1.0, smoothstep(0.04, clear_depth, d));
	a = max(a, foam * 0.9);
	ALPHA = mix(1.0, a, near);
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.25, 0.75, w * ATTENUATION);
	float reach = LIGHT_IS_DIRECTIONAL ? 1.0 : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += mix(mix(shadow_tint.rgb, vec3(1.0), 0.45), vec3(1.0), lit) * LIGHT_COLOR / PI * reach;

	vec3 hv = normalize(LIGHT + VIEW);
	float s = pow(clamp(dot(NORMAL, hv), 0.0, 1.0), 160.0);
	DIFFUSE_LIGHT += step(0.35, s) * LIGHT_COLOR * 1.1 * ATTENUATION * (LIGHT_IS_DIRECTIONAL ? 1.0 : 0.0);

	if (moon_glint > 0.0 && LIGHT_IS_DIRECTIONAL) {
		float fl = dot(normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz), hv);
		float path = smoothstep(0.965, 0.997, fl);
		float fl8 = fl * fl;
		fl8 *= fl8;
		fl8 *= fl8;
		SPECULAR_LIGHT += moon_glint * path * (step(0.4, s) * 4.0 + fl8 * fl8 * fl8 * fl8 * 0.35) * LIGHT_COLOR * ATTENUATION;
	}
}
