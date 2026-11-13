shader_type spatial;
render_mode specular_disabled, cull_disabled;
#include "res://shaders/sky_light.gdshaderinc"
#include "res://shaders/far_haze.gdshaderinc"

uniform float grid_alpha = 0.0;
uniform vec4 steep_tint : source_color = vec4(0.74, 0.71, 0.65, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.62, 0.78, 1.0);
uniform vec2 ring = vec2(0.0, 0.0);
uniform vec3 focus = vec3(0.0);
uniform vec4 haze_color : source_color = vec4(0.70, 0.80, 0.88, 1.0);
uniform float haze_near = 160.0;
uniform float haze_far = 1100.0;
uniform float haze_max = 0.6;

uniform vec4 mist_color : source_color = vec4(0.93, 0.95, 0.96, 1.0);
uniform float mist_morning = 0.0;

uniform vec3 skirt_haze = vec3(0.0);

uniform vec4 skirt_v2 = vec4(0.0);

uniform bool road_on = false;
uniform sampler2D road_sdf : filter_linear, repeat_disable;
uniform vec3 road_col = vec3(0.808, 0.698, 0.518);

uniform vec3 road_tone = vec3(0.66, 0.60, 0.44);
uniform vec3 verge_col = vec3(0.78, 0.75, 0.43);

uniform bool road_info_on = false;
uniform sampler2D road_info : filter_linear, repeat_disable;
uniform vec3 pebble_col = vec3(0.56, 0.51, 0.40);
uniform bool rail_on = false;
uniform sampler2D rail_sdf : filter_linear, repeat_disable;
uniform vec3 ballast_col = vec3(0.4, 0.37, 0.345);
uniform float grid_n = 2049.0;
uniform float grid_half = 1024.0;

global uniform float rain_puddle;
global uniform float rain_fall;

varying vec3 wpos;
varying vec3 wnrm;

#include "res://shaders/home_ground.gdshaderinc"
#include "res://shaders/season.gdshaderinc"

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_grass_tex = false;
uniform float grass_tile = 2.4;
uniform sampler2D rock_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_rock = false;
uniform float rock_tile = 14.0;

uniform vec4 nr_zone = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec2 nr_stairs[16];
uniform float nr_less = 0.3;

float seg_d(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
	return length(p - a - ab * t);
}

uniform float depth_push = 0.0;

uniform bool fill_skip = true;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION = PROJECTION_MATRIX * vp;
	if (depth_push > 0.0) {
		vec4 pushed = PROJECTION_MATRIX * vec4(vp.xyz + normalize(vp.xyz) * depth_push, 1.0);
		POSITION.z = pushed.z / pushed.w * POSITION.w;
	}
}

void fragment() {
#ifndef TERR_NO_RING
	if (ring.y > 0.0) {
		float d = distance(wpos.xz, focus.xz);
		if (d < ring.x || d > ring.y) {
			discard;
		}
	}
#endif
	vec3 c = COLOR.rgb;
	float dist = length(VERTEX);
	float on_road = 0.0;
	float pud = 0.0;
	float pud_rim = 0.0;
	float pud_deep = 0.0;

	vec2 w_dx = dFdx(wpos.xz);
	vec2 w_dy = dFdy(wpos.xz);
	float w_fw = length(abs(w_dx) + abs(w_dy));
	float verge_w = 0.0;
	float drop = 0.0;
	float sk_flat = smoothstep(0.72, 0.86, wnrm.y);
	float sk_uw = smoothstep(-0.02, 0.06, -0.05 - wpos.y);
	bool do_ground = !fill_skip || (sk_flat > 0.0 && (sk_uw < 1.0 || rain_puddle > 0.0));
	bool do_rock = !fill_skip || sk_uw < 1.0 || rain_wet > 0.0;
	float wy_dx = dFdx(wpos.y);
	float wy_dy = dFdy(wpos.y);
	float wet_k = 1.0;
	float wet_s = 0.0;
	float run = 0.0;
	if (do_ground) {
	if (road_on) {
		float sd = texture(road_sdf, (wpos.xz + grid_half + 0.5) / grid_n).r * 8.0 - 2.0;
		if (sd < 3.0) {

			float nearf = 1.0 - smoothstep(25.0, 40.0, dist);
			float e = sd + (vnoise(wpos.xz / 20.0 + 41.0) - 0.5) * 1.0
				+ (fbm(wpos.xz / 1.6 + 17.0) - 0.5) * 0.5 + (vnoise(wpos.xz * 3.0) - 0.5) * 0.15;
			float t = smoothstep(-0.25, 0.75, e);
			float tuft = vnoise(wpos.xz * 2.6) * 0.7 + mix(0.15, vnoise(wpos.xz * 7.0), nearf) * 0.3;
			float gw = smoothstep(-0.06, 0.06, (tuft + t * 1.2) - (0.55 + (1.0 - t) * 1.2));

			float vw = mix(0.65, 0.2, smoothstep(0.6, 1.6, e)) * (1.0 - smoothstep(1.6, 3.0, e))
				* smoothstep(0.03, 0.10, c.g - max(c.r, c.b));
			vec3 lawn = mix(c, c * verge_col / vec3(0.48, 0.70, 0.35), vw);
			vec3 earth_c = road_col * road_tone * mix(0.9, 1.05, vnoise(wpos.xz * 0.7 + 3.0));
			if (road_info_on && dist < 50.0 && gw < 0.999) {

				vec2 ri = texture(road_info, (wpos.xz + grid_half + 0.5) / grid_n).rg;
				float kind = floor(ri.r * 255.0 / 64.0 + 0.5);
				float dc = abs(sd + (kind < 1.5 ? 2.0 : (kind < 2.5 ? 1.4 : 1.1)));
				float aa = fwidth(dc);
				float fade = 1.0 - smoothstep(30.0, 50.0, dist);
				float rut = 0.0;
				float med = 0.0;
				if (kind > 0.5 && kind < 1.5) {
					rut = (1.0 - smoothstep(0.14 - aa, 0.28 + aa, abs(dc - 0.75))) * ri.g * fade;
					earth_c *= 1.0 - 0.22 * rut;
					med = (1.0 - smoothstep(0.18, 0.32 + aa, dc)) * ri.g * fade
						* smoothstep(0.45, 0.6, vnoise(wpos.xz * 0.9 + 5.0) * 0.6 + vnoise(wpos.xz * 3.1) * 0.4);
					earth_c = mix(earth_c, c * verge_col / vec3(0.48, 0.70, 0.35), 0.7 * med);
				} else if (kind > 1.5 && kind < 3.5) {
					float strip = (1.0 - smoothstep(0.25, 0.55 + aa, dc)) * min(ri.g / 0.6, 1.0) * fade
						* mix(0.5, 1.0, vnoise(wpos.xz * 0.8 + 9.0));
					earth_c *= 1.0 + 0.10 * strip;
				}
				if (rain_puddle > 0.0 && kind > 0.5 && kind < 3.5) {

					vec2 pu = wpos.xz / 12.0 + vec2(0.37, 0.61);
					float pn = textureGrad(cloud_noise, fract(pu), w_dx / 12.0, w_dy / 12.0).r;
					float big = vnoise(wpos.xz / 7.0 + vec2(13.1, 4.7));
					float low = pn * 0.75 + (big - 0.5) * 0.65 + rut * 0.12 + (1.0 - t) * 0.06 - med * 0.5;
					float thr = mix(0.92, 0.62, rain_puddle);
					float pw = 0.02 + 0.5 * w_fw;
					float keep = fade * smoothstep(0.93, 0.98, wnrm.y);
					pud = smoothstep(thr - pw, thr + pw, low) * keep;
					pud_rim = smoothstep(thr - 0.08, thr, low) * keep;
					pud_deep = smoothstep(thr, thr + 0.14, low);
					if (pud > 0.0 && rain_fall > 0.0 && dist < 22.0) {

						vec2 rq = wpos.xz / 0.45;
						vec2 rc = floor(rq);
						float beat = TIME * 1.1 + hash(rc + 3.7);
						float cyc = floor(beat);
						float tt = fract(beat);
						vec2 rp = vec2(hash(rc + cyc * 0.731), hash(rc + cyc * 0.293 + 5.9)) * 0.36 + 0.32;
						float rr = length(fract(rq) - rp);
						float rw = w_fw / 0.45 + 0.018;
						drop = (1.0 - smoothstep(0.0, rw, abs(rr - tt * 0.3))) * (1.0 - tt)
							* step(0.3, hash(rc + cyc * 1.37 + 2.2)) * rain_fall * (1.0 - smoothstep(14.0, 22.0, dist));
					}
				}
				float pf = 1.0 - smoothstep(18.0, 30.0, dist);
				if (pf > 0.0) {
					vec2 pq = wpos.xz / 0.33;
					vec2 pc = floor(pq);
					float pr = mix(0.04, 0.08, hash(pc + 2.9)) / 0.33;
					vec2 pv = fract(pq) - (vec2(hash(pc + 4.1), hash(pc + 8.3)) * (0.9 - 2.0 * pr) + pr + 0.05);
					float edge = 1.0 - smoothstep(0.3, 0.9, -e);

					float clump = smoothstep(0.45, 0.75, vnoise(wpos.xz * 0.6 + 21.0));
					float on = step(hash(pc + 13.7), mix(0.02, 0.28, edge) * mix(0.3, 1.6, clump) * (1.0 - min(rut * 3.0, 1.0)));
					float pa = fwidth(pq.x) * 0.7;
					float disc = 1.0 - smoothstep(pr - pa, pr + pa, length(pv));
					float shd = 1.0 - smoothstep(pr - pa, pr + pa, length(pv + vec2(0.55, 0.83) * 0.04 / 0.33));
					earth_c *= 1.0 - 0.14 * shd * on * pf;
					earth_c = mix(earth_c, pebble_col * mix(0.88, 1.12, hash(pc + 6.6)), disc * on * pf);
				}
			}
			c = mix(earth_c, lawn, gw);
			on_road = 1.0 - gw;
			verge_w = vw * gw;
		}
	}
	if (rail_on) {
		float rs = texture(rail_sdf, (wpos.xz + grid_half + 0.5) / grid_n).r * 8.0 - 2.0;
		if (rs < 1.0) {

			float e = rs + (vnoise(wpos.xz * 1.3 + 3.0) - 0.5) * 0.4 + (vnoise(wpos.xz * 4.5) - 0.5) * 0.14;
			float b = 1.0 - smoothstep(-0.05, 0.05, e);
			float st = mix(1.0, mix(0.8, 1.14, hash(floor(wpos.xz * 7.0))), 1.0 - smoothstep(15.0, 40.0, dist));
			c = mix(c, ballast_col * 0.86 * st, b);
		}
	}
	float grassy = smoothstep(0.03, 0.10, c.g - max(c.r, c.b));
	vec3 g = c;
	if (!fill_skip || grassy > 0.0) {
	g = home_grass_c(c, wpos.xz, dist);
	g *= mix(0.93, 1.0, smoothstep(18.0, 26.0, dist));

	if (has_grass_tex && dist < 70.0) {

		vec3 st = textureGrad(grass_tex, wpos.xz / grass_tile, w_dx / grass_tile, w_dy / grass_tile).rgb / vec3(0.448, 0.490, 0.389);
		float nf = 1.0 - smoothstep(35.0, 70.0, dist);
		g *= mix(vec3(1.0), mix(vec3(1.0), st, 0.85), nf);
		vec2 fc = wpos.xz * 0.9;
		vec2 fo = vec2(hash(floor(fc) + 5.3), hash(floor(fc) + 9.1)) * 0.6 + 0.2;
		float meadow = smoothstep(0.5, 0.72, vnoise(wpos.xz / 14.0 + 23.0));
		vec2 fv = (fract(fc) - fo) / 0.9;
		float fr = length(fv);
		float fh = hash(floor(fc) + 1.7);
		float petal = 0.085 * (0.72 + 0.28 * cos(5.0 * atan(fv.y, fv.x) + fh * 40.0));
		float fl = step(1.0 - 0.3 * meadow, fh) * (1.0 - smoothstep(petal - 0.012, petal + 0.004, fr))
			* (1.0 - smoothstep(18.0, 40.0, dist));
		vec3 fcol = fh > 0.985 ? vec3(0.80, 0.70, 0.95) : (fh > 0.93 ? vec3(1.0, 0.86, 0.36) : vec3(0.98, 0.97, 0.90));
		fcol = mix(fcol, vec3(1.0, 0.78, 0.28), 1.0 - smoothstep(0.018, 0.03, fr));
		g = mix(g, fcol, fl);
	}
	}

	vec3 o = c;
	float flags = 0.0;
	float brick = 0.0;
	if (!fill_skip || grassy < 1.0) {
	o = c * mix(0.86, 1.06, fbm(wpos.xz / 3.0 + 5.0));
	vec2 pc = wpos.xz * 2.2;
	vec2 po = vec2(hash(floor(pc) + 3.1), hash(floor(pc) + 7.7)) * 0.5 + 0.25;
	float peb = step(0.9, hash(floor(pc))) * (1.0 - smoothstep(0.08, 0.14, length(fract(pc) - po)))
		* (1.0 - smoothstep(25.0, 60.0, dist)) * (road_info_on ? 1.0 - on_road : 1.0);
	o *= 1.0 - peb * 0.18;
	float soil = 1.0 - smoothstep(0.02, 0.05, abs(c.r - 0.541) + abs(c.g - 0.4) + abs(c.b - 0.275));
	float near_pat = 1.0 - smoothstep(30.0, 70.0, dist);
	flags = 1.0 - smoothstep(0.02, 0.05, abs(c.r - 0.318) + abs(c.g - 0.294) + abs(c.b - 0.271));
	brick = 1.0 - smoothstep(0.02, 0.05, abs(c.r - 0.612) + abs(c.g - 0.478) + abs(c.b - 0.392));
	if (near_pat > 0.0 && flags + brick > 0.0) {

		vec2 fs = wpos.xz / vec2(0.9, 0.6);
		fs.x += floor(fs.y) * 0.5;
		vec2 fc = floor(fs);
		vec2 ff = fract(fs);
		float fj = smoothstep(0.0, 0.05, min(min(ff.x, 1.0 - ff.x), min(ff.y, 1.0 - ff.y)) * 0.9);
		vec3 fl = mix(0.82, 1.12, hash(fc)) * mix(0.55, 1.0, fj) * vec3(1.0);
		vec2 bs = wpos.xz / vec2(0.24, 0.12);
		bs.x += floor(bs.y) * 0.5;
		vec2 bc = floor(bs);
		vec2 bf = fract(bs);
		float bj = smoothstep(0.0, 0.08, min(min(bf.x, 1.0 - bf.x), min(bf.y, 1.0 - bf.y)));
		vec3 br = mix(0.84, 1.1, hash(bc)) * mix(0.62, 1.0, bj) * vec3(1.08, 0.9, 0.78);
		vec3 pat = mix(vec3(1.0), fl, flags) * mix(vec3(1.0), br, brick);
		o = mix(o, o * pat, near_pat);
		o *= mix(1.0, mix(0.85, 1.05, fbm(wpos.xz / 7.0 + 2.0)), flags + brick);
	}
	o *= mix(1.0, mix(0.78, 1.08, smoothstep(0.2, 0.5, abs(fract(wpos.z / 1.3) - 0.5))), soil);
	}

	wet_k = mix(mix(0.55, 0.65, clamp(flags + brick, 0.0, 1.0)), 1.0, grassy);
	wet_s = mix(1.0, 0.15, grassy);
	wet_k *= 1.0 - 0.2 * verge_w;
	c = mix(o, g, grassy);
	}

	float zn = 0.0;
	float sd = 1e9;
	if (nr_zone.z > 0.0) {
		zn = (1.0 - smoothstep(nr_zone.z * 0.85, nr_zone.z * 1.1, distance(wpos.xz, nr_zone.xy)))
			* smoothstep(nr_zone.w - 6.0, nr_zone.w + 6.0, wpos.y);
		if (zn > 0.0) {
			for (int i = 0; i < 15; i++) {
				sd = min(sd, seg_d(wpos.xz, nr_stairs[i], nr_stairs[i + 1]));
			}
		}
	}

	if (do_rock && (wnrm.y < 0.88 || zn > 0.0)) {
	float wx = abs(wnrm.x) / max(abs(wnrm.x) + abs(wnrm.z), 0.001);
	float fine = 1.0 - smoothstep(40.0, 120.0, dist);
	float s1 = vnoise(vec2(wpos.z * 0.22, wpos.y * 0.02)) * mix(1.0, 0.65, fine) + vnoise(vec2(wpos.z * 0.8, wpos.y * 0.05)) * 0.35 * fine;
	float s2 = vnoise(vec2(wpos.x * 0.22, wpos.y * 0.02)) * mix(1.0, 0.65, fine) + vnoise(vec2(wpos.x * 0.8, wpos.y * 0.05)) * 0.35 * fine;
	float streak = mix(s2, s1, wx);
	float band = vnoise(vec2((wpos.x + wpos.z) * 0.03, wpos.y * 0.12));

	vec3 rock = vec3(0.42, 0.40, 0.36) * mix(0.74, 1.06, streak) * mix(vec3(1.04, 0.99, 0.92), vec3(0.9, 0.94, 1.0), band);
	rock *= 1.0 - smoothstep(0.9, 1.0, abs(sin(wpos.y * 0.55 + vnoise(wpos.xz * 0.05) * 3.0))) * fine * 0.14;
	float rk = 1.0;
	if (has_rock) {
		vec2 ty = vec2(0.0, wpos.y / (rock_tile * 1.3));
		vec2 gy = vec2(wy_dx, wy_dy) / (rock_tile * 1.3);
		rk = mix(textureGrad(rock_tex, vec2(wpos.x / rock_tile, 0.0) + ty, vec2(w_dx.x / rock_tile, gy.x), vec2(w_dy.x / rock_tile, gy.y)).r,
			textureGrad(rock_tex, vec2(wpos.z / rock_tile, 0.0) + ty, vec2(w_dx.y / rock_tile, gy.x), vec2(w_dy.y / rock_tile, gy.y)).r, wx) * 2.0;
		rock *= max(mix(1.0, (rk - 1.0) * 1.3 + 1.0, 1.0 - smoothstep(200.0, 550.0, dist)), 0.3);
	}

	float edge = vnoise(wpos.xz * 0.09 + wpos.y * 0.05) * 0.5 + vnoise(vec2((wpos.x + wpos.z) * 0.35, wpos.y * 0.05)) * 0.5;
	float cov = clamp((wnrm.y - 0.12) * 1.9, 0.0, 1.0) * 0.8 + vnoise(wpos.xz * 0.02 + wpos.y * 0.01) * 0.45;
	float flat_ = smoothstep(0.72, 0.86, wnrm.y);

	cov -= zn * mix(nr_less * smoothstep(3.0, 5.0, sd), 0.22, flat_);

	float gr = smoothstep(0.47, 0.53, cov + (edge - 0.5) * 0.55 + (1.0 - rk) * 0.22);

	vec3 scrub = mix(vec3(0.32, 0.50, 0.24), vec3(0.42, 0.60, 0.30), vnoise(wpos.xz * 0.03 + wpos.y * 0.02));
	vec3 sp = wpos * 0.42;
	float cl = vnoise(sp.xz + sp.y) * 0.65 + vnoise(sp.zx * 2.1 + sp.y * 1.7 + 3.0) * 0.35;
	scrub *= mix(0.74, 1.1, smoothstep(0.25, 0.75, cl)) * mix(0.9, 1.05, clamp(wnrm.y + 0.5, 0.0, 1.0));

	if (zn > 0.0) {

		vec3 shrub = mix(vec3(0.107, 0.263, 0.073), vec3(0.214, 0.420, 0.107), vnoise(wpos.xz * 0.05 + wpos.y * 0.04));
		shrub *= mix(0.66, 1.12, smoothstep(0.3, 0.7, cl));
		scrub = mix(scrub, shrub, zn);
		float gp = vnoise(vec2((wpos.x + wpos.z) * 0.55, wpos.y * 0.2)) * 0.55 + vnoise(wpos.xz * 0.9 + 9.0) * 0.45;
		gr *= 1.0 - zn * (1.0 - smoothstep(0.27, 0.34, gp));

		rock *= mix(1.0, 0.6, zn);
	}
	rock = mix(rock, scrub, gr);
	float flat_w = flat_ * (1.0 - zn * smoothstep(3.0, 5.0, sd));
	c = mix(rock, c, flat_w);
	wet_k = mix(mix(0.58, 0.85, gr), wet_k, flat_w);
	wet_s = mix(mix(1.0, 0.15, gr), wet_s, flat_w);
	if (rain_wet > 0.0) {

		run = smoothstep(0.5, 0.75, streak) * (1.0 - gr) * (1.0 - flat_w) * rain_wet;
		c *= 1.0 - 0.35 * run;
		run *= pow(fract(wpos.y * 0.35 + TIME * 0.6 + streak * 4.0), 10.0) * (1.0 - smoothstep(30.0, 60.0, dist));
	}
	}

	float under = clamp(-0.05 - wpos.y, 0.0, 3.0);
	float uw = smoothstep(-0.02, 0.06, -0.05 - wpos.y);
	if (uw > 0.0) {
		float mot = vnoise(wpos.xz * 1.7) * 0.6 + vnoise(wpos.xz * 4.3 + 7.0) * 0.4;
		vec3 bed = mix(vec3(0.42, 0.34, 0.19), vec3(0.15, 0.14, 0.07), smoothstep(0.08, 0.7, under));
		bed *= mix(0.82, 1.12, smoothstep(0.35, 0.75, mot));
		bed = mix(bed, vec3(0.30, 0.29, 0.25), smoothstep(0.78, 0.86, mot) * 0.6);
		c = mix(c, bed, uw);
		wet_k = mix(wet_k, 1.0, uw);
		wet_s *= 1.0 - uw;
	}

	c *= home_ground_ao_grad(wpos.xz, w_dx, w_dy);
	if (grid_alpha > 0.0) {
		vec2 gl = abs(fract(wpos.xz / 10.0 + 0.5) - 0.5) * 10.0;
		float line = 1.0 - smoothstep(0.0, 0.12, min(gl.x, gl.y));
		line *= 1.0 - smoothstep(60.0, 140.0, dist);
		c *= 1.0 - grid_alpha * line;
	}
	if (season_strength > 0.0) {
		c = season_tint_w(c, 0.5);
	}
	if (rain_wet > 0.0 || rain_puddle > 0.0) {

		c = sl_wet(c, wet_k);
		c *= 1.0 - 0.26 * pud_rim * (1.0 - pud);
		c = mix(c, c * 0.15, pud);
		float ndv = dot(NORMAL, VIEW);
		float fres = pow(1.0 - clamp(ndv, 0.0, 1.0), 5.0);

		float elev = (CAMERA_POSITION_WORLD.y - wpos.y) / max(dist, 0.5);
		float up = smoothstep(0.12, 0.55, elev);
		vec3 refl = mix(vec3(0.22, 0.27, 0.24) * 0.6, vec3(0.6, 0.65, 0.7) * 1.6, up) * sky_horizon.rgb;
		EMISSION = sky_horizon.rgb * (sl_sheen(ndv, wet_s) + drop * 0.2 + run * 0.25)
			+ refl * pud * (0.16 + 0.2 * fres) * (0.7 + 0.3 * pud_deep);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	vec4 hz = far_haze(wpos, CAMERA_POSITION_WORLD, dist, smoothstep(haze_near, haze_far, dist) * haze_max,
		haze_color.rgb, haze_near, haze_far, haze_max);
	if (skirt_haze.z > 0.0) {
		vec4 hk = far_haze(wpos, CAMERA_POSITION_WORLD, dist, smoothstep(skirt_haze.x, skirt_haze.y, dist) * skirt_haze.z,
			haze_color.rgb, skirt_haze.x, skirt_haze.y, skirt_haze.z);
		if (skirt_v2.x > 0.0) {
			float ka = 1.0 - COLOR.a;
			ALBEDO = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), smoothstep(150.0, 700.0, dist) * skirt_v2.z * ka);
			if (fh_on) {
				float s = max(dot((wpos - CAMERA_POSITION_WORLD) / max(dist, 1.0), fh_sun), 0.0);
				float f = 0.35 + fh_sun_sky * s * s;
				float k1 = fh_sky * f;
				hk.rgb = mix(hk.rgb, sky_horizon.rgb, max(skirt_v2.y * f - k1, 0.0) / max(1.0 - k1, 0.05));
			}
			hk.a = min(hk.a + skirt_v2.w * smoothstep(skirt_haze.x, skirt_haze.y, dist), 0.85);
		}
		hz = mix(hz, hk, 1.0 - COLOR.a);
	}
	float fh = hz.a;
	float fm = mist_morning * 0.3 * (1.0 - smoothstep(3.0, 14.0, wpos.y)) * smoothstep(150.0, 420.0, dist);
	FOG = vec4(mix(hz.rgb, mist_color.rgb, fm / max(fh + fm, 0.001)), clamp(fh + fm, 0.0, 0.85));
	SL_FRAGMENT;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.2, 0.8, w * ATTENUATION);

	float reach = LIGHT_IS_DIRECTIONAL ? SL_SUN : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += mix(shadow_tint.rgb, vec3(1.0), lit) * LIGHT_COLOR / PI * reach;
}
