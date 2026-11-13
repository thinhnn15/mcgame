shader_type spatial;
render_mode specular_disabled;
#include "res://shaders/sky_light.gdshaderinc"
#include "res://shaders/far_haze.gdshaderinc"

uniform vec2 ring = vec2(0.0, 0.0);
uniform vec3 focus = vec3(0.0);

uniform vec2 swap = vec2(0.0, 0.0);

instance uniform vec4 foot_down = vec4(0.0);
instance uniform vec2 foot_band = vec2(0.0);
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.62, 0.78, 1.0);
uniform vec4 haze_color : source_color = vec4(0.70, 0.80, 0.88, 1.0);
uniform vec4 mist_color : source_color = vec4(0.93, 0.95, 0.96, 1.0);
uniform float haze_near = 110.0;
uniform float haze_far = 900.0;
uniform float haze_max = 0.72;
uniform float mist_top = 16.0;
uniform float mist_max = 0.35;

uniform float mist_morning = 0.0;
uniform float detail = 1.0;

uniform bool cov_mode = false;

uniform sampler2D rock_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_rock = false;
uniform float rock_tile = 14.0;

uniform sampler2D cloud_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform bool has_clouds = false;
uniform float cloud_size = 300.0;
uniform vec2 cloud_wind = vec2(0.010, 0.0035);
uniform float cloud_depth = 0.38;
uniform float rim = 0.45;

uniform vec4 leaf_a : source_color = vec4(0.349, 0.522, 0.275, 1.0);
uniform vec4 leaf_b : source_color = vec4(0.478, 0.667, 0.345, 1.0);
uniform float rock_value = 0.68;
uniform float bump = 0.9;

uniform bool karst_v2 = false;
uniform vec4 shadow_tint_v2 : source_color = vec4(0.55, 0.61, 0.75, 1.0);
uniform vec4 leaf_a_v2 : source_color = vec4(0.325, 0.439, 0.290, 1.0);
uniform vec4 leaf_b_v2 : source_color = vec4(0.467, 0.573, 0.361, 1.0);
uniform float rock_value_v2 = 0.72;
uniform float mist_v2 = 0.34;
uniform float sky_v2 = 0.55;
uniform float desat_v2 = 0.30;

varying vec3 wpos;
varying vec3 wnrm;
varying vec2 kfoot;

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

void vertex() {
	if (foot_down.w > 0.0) {
		float o = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - foot_band.x;
		VERTEX += foot_down.xyz * foot_down.w * (1.0 - smoothstep(0.0, foot_band.y, o));
	}
	if (swap.y > 0.0) {
		float sd = distance(CAMERA_POSITION_WORLD, vec3(UV2.x, UV.x, UV2.y));
		if (sd < swap.x || sd >= swap.y) {
			VERTEX = vec3(0.0);
		}
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	kfoot = vec2(0.0, 60.0);
	if (karst_v2) {
		if (swap.y > 0.0) {
			kfoot = vec2(UV.y, max(2.0 * (UV.x - UV.y), 20.0));
		} else {
			kfoot = vec2(MODEL_MATRIX[3].y + 1.0 - foot_down.w, foot_band.y > 0.0 ? foot_band.y / 0.15 : 60.0);
		}
	}
}

void fragment() {

#ifndef KARST_NO_RING
	if (ring.y > 0.0) {
		float d = distance(wpos.xz, focus.xz);
		if (d < ring.x || d > ring.y) {
			discard;
		}
	}
#endif
	vec3 c = COLOR.rgb;
	float dist = length(VERTEX);
	float green = smoothstep(0.02, 0.08, c.g - max(c.r, c.b));
	float wx = abs(wnrm.x) / max(abs(wnrm.x) + abs(wnrm.z), 0.001);
	float rk = 1.0;
	if (has_rock && dist < 550.0) {
		vec2 ty = vec2(0.0, wpos.y / (rock_tile * 1.3));
		rk = mix(texture(rock_tex, vec2(wpos.x / rock_tile, 0.0) + ty).r,
			texture(rock_tex, vec2(wpos.z / rock_tile, 0.0) + ty).r, wx) * 2.0;
	}

	float across = mix(wpos.x, wpos.z, wx);
	float hf = wpos.y - kfoot.x;
	float sn = 0.5;
	float cl = 0.5;
	float nf = 1.0 - smoothstep(120.0, 320.0, dist);
	if (karst_v2) {

		float wv = vnoise(vec2(across * 0.06, wpos.y * 0.035) + 4.0) - 0.5;
		sn = vnoise(vec2(across * 0.15 + wv * 2.6, wpos.y * 0.006 + wv * 0.2));
		if (has_rock && dist < 400.0) {
			cl = texture(rock_tex, wpos.xz / 7.0 + vec2(0.0, wpos.y / 7.0)).r;
		}
	}
	if (cov_mode) {

		float cv;
		if (karst_v2) {

			float edge = vnoise(vec2(across * 0.05 + (sn - 0.5) * 0.9, wpos.y * 0.012 + (sn - 0.5) * 0.12)) * 0.8
				+ vnoise(wpos.xz * 0.04 + wpos.y * 0.03) * 0.2;
			float pf = 1.0 - smoothstep(180.0, 420.0, dist);
			cv = COLOR.a + (edge - 0.5) * 0.3 * pf + (1.0 - rk) * 0.12 * (1.0 - smoothstep(120.0, 300.0, dist));

			cv -= ((1.0 - smoothstep(0.08, 0.25, abs(wnrm.y))) * 0.08
				+ 0.08 * smoothstep(6.0, 12.0, hf) * (1.0 - smoothstep(0.3 * kfoot.y, 0.5 * kfoot.y, hf + (sn - 0.5) * 0.5 * kfoot.y))) * nf;
			cv += 0.22 * smoothstep(0.6, 0.72, vnoise(vec2(across * 0.11, wpos.y * 0.004 + 3.0))) * nf;

			cv += (vnoise(wpos.xz * 0.55 + wpos.y * 0.45) - 0.5) * 0.16 * nf;

			cv += 0.3 * smoothstep(220.0, 380.0, dist);
		} else {
			float edge = vnoise(wpos.xz * 0.09 + wpos.y * 0.05) * 0.5 + vnoise(vec2((wpos.x + wpos.z) * 0.35, wpos.y * 0.05)) * 0.5;
			cv = COLOR.a + (edge - 0.5) * 0.55 + (1.0 - rk) * 0.22;
		}
		green = smoothstep(0.47, 0.53, cv);
		float g2 = vnoise(wpos.xz * 0.03 + wpos.y * 0.02);
		if (karst_v2) {

			float fd = smoothstep(200.0, 500.0, dist);
			c = mix(c * rock_value_v2 * mix(1.0, 0.78, fd), mix(leaf_a_v2.rgb, leaf_b_v2.rgb, g2), green);
		} else {
			c = mix(c * rock_value, mix(leaf_a.rgb, leaf_b.rgb, g2), green);
		}
	}
	float near_detail = detail * (1.0 - smoothstep(350.0, 700.0, dist));
	float run = 0.0;
	if (near_detail > 0.0) {

		float fine = 1.0 - smoothstep(40.0, 140.0, dist);
		float s1 = vnoise(vec2(wpos.z * 0.25, wpos.y * 0.02)) * mix(1.0, 0.65, fine) + vnoise(vec2(wpos.z * 0.9, wpos.y * 0.05)) * 0.35 * fine;
		float s2 = vnoise(vec2(wpos.x * 0.25, wpos.y * 0.02)) * mix(1.0, 0.65, fine) + vnoise(vec2(wpos.x * 0.9, wpos.y * 0.05)) * 0.35 * fine;
		float streak = mix(s2, s1, wx);
		float band = vnoise(vec2((wpos.x + wpos.z) * 0.03, wpos.y * 0.12));
		float crack = smoothstep(0.78, 0.92, vnoise(vec2(across * 1.1, wpos.y * 0.012)))
			* (1.0 - smoothstep(60.0, 160.0, dist));
		vec3 stone;
		if (karst_v2) {

			vec3 lime = mix(COLOR.rgb, vec3(dot(COLOR.rgb, vec3(0.33))) * vec3(1.02, 1.0, 0.95), 0.8);
			stone = (cov_mode ? lime * rock_value_v2 : c) * 0.9 * mix(0.9, 1.06, streak) * (1.0 - crack * 0.35)
				* mix(1.0, 0.78, smoothstep(200.0, 500.0, dist));
		} else {
			stone = (cov_mode ? COLOR.rgb * rock_value : c) * 0.9 * mix(0.66, 1.04, streak) * (1.0 - crack * 0.35);
		}
		if (has_rock) {

			float rkc = karst_v2 ? 0.35 * (1.0 - smoothstep(0.5, 0.7, abs(wnrm.y))) : 1.3;
			stone *= max(mix(1.0, (rk - 1.0) * rkc + 1.0, 1.0 - smoothstep(200.0, 550.0, dist)), 0.3);
		}
		if (cov_mode) {
			float bed = smoothstep(0.9, 1.0, abs(sin(wpos.y * 0.55 + vnoise(wpos.xz * 0.05) * 3.0))) * fine;
			stone *= 1.0 - bed * 0.16;
			float under = smoothstep(0.3, 0.47, COLOR.a + (vnoise(vec2(across * 0.4, wpos.y * 0.03)) - 0.5) * 0.5);
			if (karst_v2) {

				float sf = 1.0 - smoothstep(250.0, 450.0, dist);
				stone *= vec3(0.93, 0.89, 0.80);

				float lp = across * 0.18 + (sn - 0.5) * 1.5 + vnoise(vec2(across * 0.05, wpos.y * 0.01)) * 2.0;
				float thin = 1.0 - smoothstep(0.03, 0.09, abs(fract(lp) - 0.5));
				float clumps = smoothstep(0.5, 0.75, vnoise(vec2(floor(lp) * 0.37, wpos.y * 0.02 + 7.0)));
				float dk = max(thin * clumps * sf * 0.85, under * 0.9 * (1.0 - smoothstep(100.0, 220.0, dist)) * nf)
					* (1.0 - green);
				stone *= mix(0.9, 1.05, vnoise(vec2(across * 0.08, wpos.y * 0.03) + 2.0));
				stone *= mix(vec3(1.0), vec3(0.42, 0.42, 0.43), dk);
				float oc = smoothstep(0.78, 0.9, vnoise(vec2(across * 0.07, wpos.y * 0.05) + 7.0)) * (1.0 - dk);
				stone = mix(stone, stone * vec3(1.12, 0.92, 0.72), oc * 0.7);
			} else {
				stone = mix(stone, stone * vec3(0.78, 0.8, 0.74), under * (1.0 - green) * 0.6);
			}
		}
		stone *= mix(vec3(1.04, 0.99, 0.92), vec3(0.90, 0.94, 1.0), band);

		vec3 leaf = c;
		if (green > 0.01) {
			float top = clamp(wnrm.y * 0.5 + 0.5, 0.0, 1.0);
			float sh = vnoise(wpos.xz * 0.35 + wpos.y * 0.3) * 0.6 + vnoise(wpos.xz * 0.11 + wpos.y * 0.13) * 0.4;

			float lump = vnoise(wpos.xz * 1.1 + wpos.y * 0.9) * (1.0 - smoothstep(40.0, 90.0, dist));

			float big = vnoise(wpos.xz * 0.33 + wpos.y * 0.3 + 5.0) * (1.0 - smoothstep(80.0, 160.0, dist));
			leaf = c * mix(0.84, 1.1, smoothstep(0.25, 0.8, sh)) * mix(0.9, 1.08, top)
				* mix(0.86, 1.1, clamp(rk * 0.5, 0.0, 1.0)) * mix(1.0, mix(0.8, 1.12, lump), 0.8)
				* mix(1.0, mix(0.78, 1.14, smoothstep(0.3, 0.7, big)), 0.85);
			leaf = mix(leaf, leaf * vec3(0.92, 1.05, 0.88), vnoise(wpos.xz * 0.05));
			if (karst_v2) {
				leaf *= mix(1.0, mix(0.78, 1.12, cl), 1.0 - smoothstep(250.0, 400.0, dist));
				leaf *= mix(1.0, mix(0.82, 1.0, smoothstep(0.3, 0.6, sn)), nf * smoothstep(100.0, 180.0, dist));
			}
		}
		c = mix(c, mix(stone, leaf, green), near_detail);
		if (rain_wet > 0.0) {

			float rs = smoothstep(0.5, 0.75, streak) * (1.0 - green) * near_detail * rain_wet;
			c *= 1.0 - 0.35 * rs;
			run = max(rs, crack) * (1.0 - green) * rain_wet * (1.0 - smoothstep(30.0, 60.0, dist))
				* pow(fract(wpos.y * 0.35 + TIME * 0.6 + streak * 4.0), 8.0);
		}
	}
	if (rain_wet > 0.0) {

		c = sl_wet(c, mix(0.58, 0.85, green));
		EMISSION = sky_horizon.rgb * (sl_sheen(dot(NORMAL, VIEW), mix(1.0, 0.15, green)) + run * 0.25);
	}
	if (karst_v2) {

		float fn = hf + (sn - 0.5) * 1.6;
		c *= mix(vec3(0.45, 0.485, 0.44), vec3(1.0), smoothstep(0.5, 4.5, fn)) * (1.0 - 0.35 * (1.0 - smoothstep(0.0, 0.8, fn)));

		float gul = vnoise(vec2(across * 0.07, wpos.y * 0.004 + 11.0));
		c *= mix(1.0, mix(0.8, 1.0, smoothstep(0.3, 0.55, gul)), green * smoothstep(80.0, 200.0, dist));
		c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), smoothstep(300.0, 1000.0, dist) * desat_v2);
	}
	ALBEDO = c;
	if (karst_v2 && swap.y <= 0.0) {

		vec3 ax = MODEL_MATRIX[3].xyz;
		vec3 rn = normalize(vec3(wpos.x - ax.x, 0.25 * length(wpos.xz - ax.xz) / max(kfoot.y, 10.0), wpos.z - ax.z));
		vec3 rv = normalize((VIEW_MATRIX * vec4(rn, 0.0)).xyz);
		NORMAL = normalize(mix(NORMAL, rv, 0.65 * (1.0 - green)));
	}
	ROUGHNESS = 1.0;

	float bk = bump * (1.0 - green) * (1.0 - smoothstep(90.0, 150.0, dist)) * (has_rock && cov_mode ? 1.0 : 0.0);
	if (bk > 0.0) {
		vec3 dpx = dFdx(VERTEX);
		vec3 dpy = dFdy(VERTEX);
		float dhx = dFdx(rk) * 0.18 * bk;
		float dhy = dFdy(rk) * 0.18 * bk;
		vec3 r1 = cross(dpy, NORMAL);
		vec3 r2 = cross(NORMAL, dpx);
		float det = dot(dpx, r1);
		vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad);
	}

	vec4 hz = far_haze(wpos, CAMERA_POSITION_WORLD, dist, smoothstep(haze_near, haze_far, dist) * haze_max,
		haze_color.rgb, haze_near, haze_far, haze_max);
	float h = hz.a;
	if (karst_v2) {

		h = min(h * mix(0.6, 1.2, smoothstep(450.0, 1300.0, dist)), 0.85);

		if (fh_on) {
			float s = max(dot((wpos - CAMERA_POSITION_WORLD) / max(dist, 1.0), fh_sun), 0.0);
			float f = 0.35 + fh_sun_sky * s * s;
			float k1 = fh_sky * f;
			hz.rgb = mix(hz.rgb, sky_horizon.rgb, max(sky_v2 * f - k1, 0.0) / max(1.0 - k1, 0.05));
		}
		float md = (1.0 - smoothstep(0.0, mist_top * (1.0 + 0.2 * sin(wpos.x * 0.013) + 0.2 * sin(wpos.z * 0.017)), hf))
			* smoothstep(400.0, 800.0, dist) * mist_max * mix(mist_v2, 1.0, rain_wet);
		float mm = mist_morning * 0.38 * (1.0 - smoothstep(4.0, mist_top * 2.2, wpos.y)) * smoothstep(150.0, 420.0, dist);
		float m = md + mm;
		vec3 mc = (mix(hz.rgb, vec3(1.0), 0.05) * md + mist_color.rgb * mm) / max(m, 0.001);
		FOG = vec4(mix(hz.rgb, mc, m / max(h + m, 0.001)), clamp(h + m, 0.0, 0.85));
	} else {
		float m = (1.0 - smoothstep(2.0, mist_top, wpos.y)) * smoothstep(60.0, 400.0, dist) * mist_max;
		m += mist_morning * 0.38 * (1.0 - smoothstep(4.0, mist_top * 2.2, wpos.y)) * smoothstep(150.0, 420.0, dist);
		vec3 fogc = mix(hz.rgb, mist_color.rgb, m / max(h + m, 0.001));
		FOG = vec4(fogc, clamp(h + m, 0.0, 0.85));
	}
	SL_FRAGMENT;
	if (has_clouds) {
		sl_cloud_v = 1.0;
	}
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float sun = ATTENUATION;
	if (has_clouds && LIGHT_IS_DIRECTIONAL) {
		float cl = texture(cloud_tex, wpos.xz / cloud_size + cloud_wind * TIME).r;
		sun *= 1.0 - smoothstep(0.56, 0.68, cl) * cloud_depth;
	}

	float lit = karst_v2 ? smoothstep(0.30, 0.70, w * sun) : smoothstep(0.2, 0.8, w * sun);
	float reach = LIGHT_IS_DIRECTIONAL ? SL_SUN : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += mix(karst_v2 ? shadow_tint_v2.rgb : shadow_tint.rgb, vec3(1.0), lit) * LIGHT_COLOR / PI * reach;
	if (LIGHT_IS_DIRECTIONAL) {
		float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float back = clamp(dot(LIGHT, -VIEW) * 0.5 + 0.5, 0.0, 1.0);
		DIFFUSE_LIGHT += smoothstep(0.62, 0.8, fres) * (0.35 + 0.65 * back) * rim * (karst_v2 ? 0.55 : 1.0) * LIGHT_COLOR / PI;
	}
}
