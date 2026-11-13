shader_type sky;

uniform vec4 top_color : source_color = vec4(0.56, 0.83, 1.0, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform vec4 ground_color : source_color = vec4(0.75, 0.89, 0.63, 1.0);
uniform vec4 cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_shade : source_color = vec4(0.84, 0.84, 0.93, 1.0);
uniform float cover = 0.48;
uniform float drift = 0.004;
uniform float night = 0.0;

uniform float look = 0.0;
uniform float rain = 0.0;
uniform vec4 rain_light : source_color = vec4(0.76, 0.79, 0.83, 1.0);
uniform vec4 rain_dark : source_color = vec4(0.52, 0.55, 0.62, 1.0);
uniform float glow_tail = 0.45;
uniform float glow_warm = 0.7;
uniform float lining = 0.35;
uniform float veil = 0.18;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_power = 0.0;

uniform float sun_disc = 0.0;
uniform float twilight = 0.0;
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 moon_light = vec3(0.0, 0.0, 1.0);
uniform float moon_power = 0.0;
uniform float moon_glow = 0.0;
uniform float stars = 0.0;

uniform float rainbow = 0.0;
uniform float rain_gap = 0.0;

global uniform sampler2D cloud_noise;

float hash(vec2 p) {

	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += vnoise(p) * a;
		p = p * 2.02 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v;
}

float fbm_m(vec2 p, float t, int oct) {
	float v = vnoise(p) * 0.5;
	if (oct < 2) {
		return v + 0.22;
	}
	p = p * 2.02 + vec2(3.1, 1.7);
	v += vnoise(p + t * vec2(0.012, -0.006)) * 0.25;
	if (oct > 2) {
		p = p * 2.02 + vec2(3.1, 1.7);
		v += vnoise(p + t * vec2(-0.018, 0.012)) * 0.125;
	}
	if (oct > 3) {
		p = p * 2.02 + vec2(3.1, 1.7);
		v += vnoise(p + t * vec2(0.014, 0.028)) * 0.0625;
	} else {
		v += oct > 2 ? 0.03 : 0.09;
	}
	return v;
}

vec3 glow_add(vec3 c, vec3 g) {
	return c + g * clamp(vec3(1.0) - c * 0.75, 0.25, 1.0);
}

float bump(float x) {
	float t = clamp(1.0 - x * x, 0.0, 1.0);
	return t * t;
}

vec3 sky_old(vec3 d) {
	float up = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(horizon_color.rgb, top_color.rgb, pow(up, 0.55));
	if (d.y < 0.0) {
		col = mix(horizon_color.rgb, ground_color.rgb, clamp(-d.y * 4.0, 0.0, 1.0));
	}

	float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
	col += vec3(1.0, 0.95, 0.85) * pow(sd, 48.0) * 0.35 * LIGHT0_ENERGY;
	if (d.y > 0.01) {
		vec2 uv = d.xz / (d.y + 0.12) * 1.6 + vec2(TIME * drift, TIME * drift * 0.4);
		float n = fbm(uv);
		float fade = smoothstep(0.01, 0.12, d.y);
		float c = smoothstep(cover, cover + 0.22, n) * fade;
		float shade = smoothstep(cover + 0.05, cover + 0.4, fbm(uv + vec2(0.06, 0.03)));
		vec3 cc = mix(cloud_color.rgb, cloud_shade.rgb, shade * 0.6);
		cc = mix(cc, cc * vec3(0.25, 0.28, 0.4), night);
		col = mix(col, cc, c * mix(0.92, 0.15, night));
	}
	return col;
}

void sky() {
	if (look < 0.5) {
		COLOR = sky_old(EYEDIR);
	} else {
		vec3 d = EYEDIR;
		vec3 s = normalize(sun_dir);

		float day = 1.0 - smoothstep(0.7, 0.95, night);
		float up = clamp(d.y, 0.0, 1.0);
		vec3 sun_col = mix(vec3(1.0, 0.95, 0.85), sun_tint, 0.6);
		vec2 dh = normalize(d.xz + vec2(1e-4, 0.0));
		vec2 sh = normalize(s.xz + vec2(1e-4, 0.0));
		float side = 0.5 + 0.5 * dot(dh, sh);

		float rn = rain * (1.0 - rain_gap * smoothstep(0.3, 0.92, side));

		vec3 col = mix(horizon_color.rgb, top_color.rgb, pow(up, mix(0.55, 0.9, rn)));
		col = mix(col, rain_light.rgb * 0.97, rn * 0.6);

		float low = 1.0 - smoothstep(0.12, 0.65, s.y);
		float hz = 1.0 - up;
		float warm = side * side * hz * hz * sqrt(hz) * low * glow_warm * min(sun_power * 3.0, 1.0) * (1.0 - rn);
		vec3 wc = sun_col / max(max(sun_col.r, sun_col.g), 0.001) * vec3(1.0, 0.72, 0.45);

		wc = mix(wc, sun_col / max(max(sun_col.r, sun_col.g), 0.001) * vec3(1.0, 0.42, 0.13), sun_disc * low * 0.8);

		col = mix(col, wc, warm * (1.0 - twilight * smoothstep(0.06, 0.3, up) * smoothstep(0.2, -0.2, s.x)));

		if (twilight > 0.0) {
			float e = max(d.y, 0.0);
			float tw = twilight * (1.0 - rn);
			float hb = max(max(horizon_color.r, horizon_color.g), horizon_color.b);
			float band = smoothstep(-0.02, 0.03, d.y) * (1.0 - smoothstep(0.08, 0.34, e));

			float s2 = side * side;
			vec3 rose = mix(vec3(1.0, 0.33, 0.42), vec3(1.0, 0.45, 0.16), s2 * s2 * (1.0 - smoothstep(0.0, 0.1, e)));
			col = mix(col, rose * hb, band * tw * (0.25 + 0.4 * s2));
			float vio = smoothstep(0.1, 0.3, e) * (1.0 - smoothstep(0.45, 0.95, e));

			col = mix(col, col * vec3(0.82, 0.78, 1.15), vio * tw * (0.45 + 0.35 * side));
			float es = (1.0 - side) * (1.0 - side) * (1.0 - smoothstep(0.012, 0.06, e));
			col = mix(col, mix(top_color.rgb, vec3(0.42, 0.44, 0.66) * hb, 0.5), es * tw * 0.5);
		}
		if (d.y < 0.0) {
			col = mix(col, ground_color.rgb, clamp(-d.y * 4.0, 0.0, 1.0));
		}

		float cs = dot(d, s);
		float sd = max(cs, 0.0);
		float q = 1.5625 - 1.5 * cs;
		float hg = 0.015625 / (q * sqrt(q));
		float sd6 = sd * sd * sd;
		sd6 *= sd6;
		float sd48 = sd6 * sd6;
		sd48 *= sd48;
		sd48 *= sd48;
		vec3 core = sun_col * sd48 * 0.35 * smoothstep(-0.04, 0.03, s.y) * sun_power * (1.0 - 0.85 * rn);
		vec3 glow = core + sun_col * hg * glow_tail * sun_power * (1.0 - 0.85 * rn);
		vec2 wind = vec2(1.0, 0.4) * TIME * drift * (1.0 + 1.5 * rain);
		float thr = mix(cover, 0.14, rn);
		float edge = mix(0.22, 0.4, rn);
		if (AT_CUBEMAP_PASS) {

			float cov = mix(0.25, 0.9, rn) * smoothstep(0.0, 0.15, d.y);
			vec3 cav = mix(mix(cloud_color.rgb, cloud_shade.rgb, 0.3), mix(rain_light.rgb, rain_dark.rgb, 0.5), rn);
			cav = mix(cav, cav * vec3(0.25, 0.28, 0.4), night);
			COLOR = mix(glow_add(col, glow * 0.6), cav, cov * mix(0.92, 0.15, night));
		} else {

			vec2 vuv = d.xz * (0.45 / (max(d.y, 0.0) + 0.06)) * vec2(1.0, 3.0) + vec2(TIME * drift * 0.35, 0.0);
			vec2 vdx = dFdx(vuv);
			vec2 vdy = dFdy(vuv);
			float pxs = length(dFdx(d)) + length(dFdy(d));
			vec3 m = normalize(moon_dir);
			float mq = 1.0 - dot(d, m);
			vec3 mcol = vec3(0.78, 0.85, 1.0);
			if (d.y > 0.01) {
				float k = 1.6 / (d.y + 0.12);
				vec2 uv = d.xz * k + wind;
				float n = fbm_m(uv, TIME, 3);
				float fade = smoothstep(0.01, 0.12, d.y);
				float c = smoothstep(thr, thr + edge, n) * fade;

				vec2 suv = s.xz * (1.6 / (max(s.y, 0.02) + 0.12)) + wind;
				vec2 tow = suv - uv;
				tow = tow / max(length(tow), 1e-3);
				float ns = fbm_m(uv + tow * 0.09, TIME, 2);
				float shade = smoothstep(thr + 0.05, thr + 0.4, ns);
				shade = clamp(shade * 0.7 + (ns - n) * 3.5, 0.0, 1.0);
				float lit = clamp((n - ns) * 5.0, 0.0, 1.0);

				vec3 c_lit = mix(cloud_color.rgb, rain_light.rgb, rn);
				vec3 c_dark = mix(cloud_shade.rgb, rain_dark.rgb, rn);
				float sh = mix(shade * 0.6, clamp(shade * 0.55 + smoothstep(thr + 0.05, thr + 0.45, n) * 0.6, 0.0, 1.0), rn);
				vec3 cc = mix(c_lit, c_dark, sh * 1.15);
				cc += sun_col * lit * 0.12 * min(sun_power * 1.6, 1.0) * day * (1.0 - rn);

				float thin = c * (1.0 - c) * 4.0;

				float facing = clamp((n - ns) * 8.0, 0.0, 1.0);
				cc += sun_col * thin * sd6 * lining * (0.15 + 0.85 * facing) * sun_power * (1.0 - 0.8 * rn);

				float cgold = sun_disc * max(low * min(sun_power * 3.0, 1.0) * (0.3 + 0.5 * side), twilight * (0.45 + 0.35 * side)) * (1.0 - rn);
				if (cgold > 0.0) {
					vec3 ct = mix(vec3(1.0, 0.36, 0.42), vec3(1.0, 0.5, 0.22), side * side * (1.0 - twilight * 0.6));
					float under = 1.0 - smoothstep(0.1, 0.5, d.y);
					cc = mix(cc, cc * ct * 1.2, cgold * (0.5 + 0.5 * under));
					cc += ct * twilight * 0.28 * (0.4 + 0.6 * under) * (1.0 - rn) * sun_disc;
				}
				cc = mix(cc, cc * vec3(0.25, 0.28, 0.4), night);

				cc += mcol * (0.035 + thin * exp(-mq * 70.0) * 0.9 + exp(-mq * 900.0) * 0.5) * moon_glow * night * (1.0 - rn);

				if (veil * (1.0 - rain * (1.0 - rain_gap)) > 0.0) {
					float vn = textureGrad(cloud_noise, fract(vuv), vdx, vdy).r;
					float va = smoothstep(0.55, 0.85, vn) * fade * veil * day * (1.0 - rn);
					vec3 vc = mix(cloud_color.rgb, sun_col, 0.25);
					vc = mix(vc, vc * vec3(0.25, 0.28, 0.4), night);
					col = mix(col, glow_add(vc, glow * 0.5), va);
				}

				float occ = 0.0;
				if (cs > 0.95 && s.y > 0.0) {
					float ncs = fbm_m(suv, TIME, 1);
					occ = smoothstep(thr, thr + edge, ncs) * smoothstep(0.01, 0.12, s.y);
				}

				if (stars > 0.0) {
					vec3 sp = d * 160.0;
					vec3 cell = floor(sp);
					float hs = hash3(cell);
					if (hs > 0.9) {
						vec3 off = vec3(hash3(cell + 17.3), hash3(cell + 41.9), hash3(cell + 7.1)) - 0.5;
						float r = length(fract(sp) - 0.5 - off * 0.5);
						float px = max(pxs * 80.0, 0.05);
						float b = (hs - 0.9) * 10.0;
						b = 0.2 + 1.5 * b * b * b;
						float tw = 0.7 + 0.3 * sin(TIME * (1.2 + 2.5 * off.x) + off.y * 40.0);
						float st = (1.0 - smoothstep(px * 0.6, px * 2.0, r)) * b * tw;
						vec3 tint = mix(vec3(0.8, 0.88, 1.0), vec3(1.0, 0.9, 0.76), off.z + 0.5);
						col += tint * st * stars * smoothstep(0.03, 0.25, d.y) * (1.0 - c) * smoothstep(0.0004, 0.0006, mq);
					}
				}

				if (moon_glow > 0.0) {
					col += mcol * (exp(-mq * 2500.0) * 0.5 + exp(-mq * 300.0) * 0.12 + exp(-mq * 30.0) * 0.1) * moon_glow * (1.0 - 0.75 * c);
				}

				if (moon_power > 0.0 && mq < 0.002) {
					const float MR = 0.03;
					vec3 er = normalize(cross(m, vec3(0.0, 1.0, 0.0)));
					vec3 eu = cross(er, m);
					vec2 q = vec2(dot(d, er), dot(d, eu)) / MR;
					float r2 = dot(q, q);
					float pr = pxs / MR;
					float inside = 1.0 - smoothstep(1.0 - pr, 1.0 + pr, sqrt(r2));
					vec3 n = er * q.x + eu * q.y - m * sqrt(max(1.0 - r2, 0.0));
					float ml = smoothstep(-0.06, 0.1, dot(n, moon_light));
					float mar = vnoise(q * 2.3 + vec2(4.1, 1.3)) * 0.65 + vnoise(q * 5.1 + vec2(9.2, 3.7)) * 0.35;
					vec3 face = vec3(1.0, 0.96, 0.86) * (1.0 - 0.16 * smoothstep(0.38, 0.72, mar)) * (1.0 - 0.1 * r2);

					col = mix(col, face * mix(1.15, 2.0, moon_glow), inside * ml * moon_power * (1.0 - 0.85 * c));
				}
				col = glow_add(col, glow - core * 0.85 * occ);

				if (sun_disc > 0.0 && cs > 0.985) {
					float g = 1.0 - smoothstep(0.0, 0.32, s.y);
					float sr = 0.017 * (1.0 + 1.3 * g * g * (3.0 - 2.0 * g));
					vec3 er = normalize(cross(s, vec3(0.0, 1.0, 0.0)));
					vec3 eu = cross(er, s);
					vec2 q = vec2(dot(d, er), dot(d, eu) / (1.0 - 0.1 * g));
					float sa = length(q);
					float sk = sun_disc * min(sun_power * 2.5, 1.0) * (1.0 - rn);

					float h1 = sa / (sr * 1.9);
					float h2 = 1.0 - smoothstep(0.0, 0.17, sa);
					vec3 halo = vec3(1.0, 0.55, 0.18) * exp(-h1 * h1) * 0.6 + vec3(1.0, 0.3, 0.1) * h2 * h2 * 0.38;
					col = glow_add(col, halo * g * sk * smoothstep(-0.01, 0.02, d.y));
					if (sa < sr * 1.2) {
						float dk = 1.0 - smoothstep(sr * 0.72, sr * 1.04 + pxs, sa);

						vec3 dcol = vec3(1.0, mix(0.03, 0.86, smoothstep(0.035, 0.42, s.y)), mix(0.008, 0.6, smoothstep(0.08, 0.45, s.y)));
						dcol *= mix(2.2, 1.7, g);
						float lim = clamp(-q.y / sr, 0.0, 1.0) * g;
						dcol *= mix(vec3(1.0), vec3(0.72, 0.5, 0.45), lim) * (1.0 - 0.16 * g * sa * sa / (sr * sr));
						col = mix(col, dcol, dk * sk * smoothstep(0.0, 0.006, d.y));
					}
				}
				col = mix(col, cc, c * mix(mix(0.92, 0.97, rn), 0.15 + 0.2 * moon_glow, night));
			} else {
				col = glow_add(col, glow);
			}

			float ca = -cs;
			if (rainbow > 0.0 && ca > 0.52 && ca < 0.86 && d.y > -0.02) {
				float th = degrees(acos(ca));
				vec3 bow = vec3(bump((th - 42.0) * 0.85) + 0.22 * bump((th - 39.9) * 1.3), bump((th - 41.15) * 0.9),
					bump((th - 40.3) * 0.85));
				bow += vec3(bump((th - 50.3) * 0.65), bump((th - 51.4) * 0.65), bump((th - 52.5) * 0.65)) * 0.35;
				float inner = (1.0 - smoothstep(38.8, 40.8, th)) * smoothstep(31.0, 37.5, th);
				float alex = smoothstep(42.6, 44.0, th) * (1.0 - smoothstep(49.0, 50.4, th));
				float vis = rainbow * smoothstep(-0.02, 0.0, d.y) * (0.35 + 0.65 * smoothstep(0.0, 0.14, d.y)) * day
					* min(sun_power * 3.0, 1.0);
				vis *= 0.87 + 0.14 * sin(d.x * 7.0 + d.z * 5.3 + TIME * 0.02) + 0.12 * sin(d.y * 11.0 - d.z * 3.1);
				vec3 band = bow * sun_col / max(sun_col.r, 0.001);
				col *= 1.0 + vis * (0.14 * inner - 0.1 * alex);
				col += vis * 0.27 * (band - dot(band, vec3(0.333)) * 0.5);
			}
			COLOR = col;
		}
	}
}
