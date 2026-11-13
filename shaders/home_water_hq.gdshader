shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
global uniform vec4 sky_horizon : source_color;

global uniform float water_time;
#include "res://shaders/water_flow.gdshaderinc"
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

uniform bool displace = false;
uniform float lift_k = 1.7;
uniform vec2 grid_c = vec2(0.0);
uniform float grid_r = 28.0;
uniform bool hole = false;
uniform float swell = 1.0;
uniform vec4 water_tint : source_color = vec4(0.62, 0.80, 0.68, 1.0);

uniform vec4 jade_shallow : source_color = vec4(0.561, 0.749, 0.643, 1.0);
uniform vec4 jade_mid : source_color = vec4(0.310, 0.561, 0.478, 1.0);
uniform vec4 jade_deep : source_color = vec4(0.173, 0.373, 0.322, 1.0);
uniform float absorb = 0.62;
uniform float refract_k = 0.035;
uniform float reflect_k = 0.85;
uniform float contact = 0.16;
uniform int debug_view = 0;

varying vec3 wpos;
varying vec2 base_xz;
varying float cam_d;

const vec4 SW[3] = vec4[](vec4(0.94, 0.33, 7.0, 0.035), vec4(0.55, -0.83, 4.3, 0.021), vec4(-0.3, 0.95, 2.6, 0.011));
const float SW_SPEED[3] = float[](1.0, 0.8, 0.65);

vec3 swells(vec2 p, float t, out vec3 n) {
	vec3 off = vec3(0.0);
	vec3 dx = vec3(1.0, 0.0, 0.0);
	vec3 dz = vec3(0.0, 0.0, 1.0);
	for (int i = 0; i < 3; i++) {
		vec2 d = normalize(SW[i].xy);
		float k = 6.2832 / SW[i].z;
		float a = SW[i].w * swell;
		float c = sqrt(9.8 / k) * SW_SPEED[i];
		float f = k * (dot(d, p) - c * t);
		float q = 0.35;
		off += vec3(q * a * d.x * cos(f), a * sin(f), q * a * d.y * cos(f));
		dx += vec3(-q * a * d.x * d.x * k * sin(f), a * d.x * k * cos(f), -q * a * d.x * d.y * k * sin(f));
		dz += vec3(-q * a * d.x * d.y * k * sin(f), a * d.y * k * cos(f), -q * a * d.y * d.y * k * sin(f));
	}
	n = normalize(cross(dz, dx));
	return off;
}

float grid_box(vec2 p) {
	vec2 q = abs(p - grid_c);
	return max(q.x, q.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	base_xz = wpos.xz;
	if (displace) {
		vec3 n;
		vec3 off = swells(wpos.xz, water_time, n) * lift_k;

		float rim = 1.0 - smoothstep(grid_r * 0.7, grid_r * 0.92, grid_box(wpos.xz));
		float dd = has_depth ? textureLod(depth_map, (wpos.xz + grid_half + 0.5) / grid_n, 0.0).r * depth_max : depth_max;
		float k = rim * smoothstep(0.15, 1.0, dd);
		VERTEX += inverse(mat3(MODEL_MATRIX)) * off * k;
		wpos += off * k;
	}
	cam_d = length((VIEW_MATRIX * vec4(wpos, 1.0)).xyz);
}

float view_z(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return v.z / v.w;
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

	if (!paddy && !stream && (displace || hole)) {
		float gb = grid_box(base_xz);
		float d0 = has_depth ? texture(depth_map, (base_xz + grid_half + 0.5) / grid_n).r * depth_max : depth_max;
		if (displace && (gb > grid_r * 0.94 || d0 < 0.005)) {
			discard;
		}
		if (hole && gb <= grid_r * 0.94 && d0 >= 0.005) {
			discard;
		}
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
	}
	float h1 = texture(noise_tex, uv1).r;
	float h2 = texture(noise_tex, uv2).r;
	float h = 0.5 + (h1 * wa + h2 * wb - 0.5) * wk;
	float e = 0.03;
	float hx = (texture(noise_tex, uv1 + vec2(e, 0.0)).r * wa + texture(noise_tex, uv2 + vec2(e * 2.3, 0.0)).r * wb - 0.5) * wk + 0.5 - h;
	float hz = (texture(noise_tex, uv1 + vec2(0.0, e)).r * wa + texture(noise_tex, uv2 + vec2(0.0, e * 2.3)).r * wb - 0.5) * wk + 0.5 - h;
	vec3 ns;
	swells(wpos.xz, water_time, ns);
	float sk = stream ? 0.3 : 1.0;
	float rip = stream ? 3.0 : 1.1;

	float graze = 1.0 - clamp(dot(normalize((INV_VIEW_MATRIX * vec4(-VERTEX, 0.0)).xyz), vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	float calm = (stream ? 1.0 : mix(0.3, 1.0, smoothstep(0.15, 1.3, d))) * mix(1.0, 0.3, smoothstep(0.55, 0.95, graze));
	vec3 nw = normalize(vec3((ns.x * sk - hx * rip * near) * calm, 1.0, (ns.z * sk - hz * rip * near) * calm));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	vec3 vdir = normalize(-VERTEX);

	float surf_z = VERTEX.z;
	float scene_z = view_z(SCREEN_UV, INV_PROJECTION_MATRIX);
	float thick = max(surf_z - scene_z, 0.0);
	vec2 bend = (nw.xz) * refract_k * clamp(thick, 0.0, 1.0) * near;
	vec2 ruv = SCREEN_UV + bend;
	float scene_z2 = view_z(ruv, INV_PROJECTION_MATRIX);
	if (scene_z2 > surf_z) {
		ruv = SCREEN_UV;
		scene_z2 = scene_z;
	}
	float thick2 = max(surf_z - scene_z2, 0.0);
	vec3 under = textureLod(screen_tex, ruv, 0.6).rgb;

	float b1 = smoothstep(0.08, 0.45, d);
	float b2 = smoothstep(0.7, 1.8, d + (h - 0.5) * 0.25);
	vec3 band = (stream || paddy) ? mix(mix(shore_col.rgb, shallow_col.rgb, b1), deep_col.rgb, b2)
		: mix(mix(jade_shallow.rgb, jade_mid.rgb, b1), jade_deep.rgb, b2);
	float fog = 1.0 - exp(-thick2 * absorb);

	vec3 col = mix(under * water_tint.rgb, band, clamp(0.2 + fog * 1.05, 0.0, 1.0) * smoothstep(0.0, 0.06, thick2));

	float shal = smoothstep(0.02, 0.1, d) * (1.0 - smoothstep(0.35, 1.2, d)) * near;
	if (shal > 0.0) {
		float c1 = texture(noise_tex, wpos.xz * 0.55 + vec2(0.7, 0.4) * TIME * 0.035).r;
		float c2 = texture(noise_tex, wpos.xz * 0.47 * mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) - vec2(0.3, 0.8) * TIME * 0.03).r;
		float net = 1.0 - smoothstep(0.0, 0.035, abs(c1 - c2));
		col += net * caustic * shal * (1.0 - fog) * vec3(1.0, 0.98, 0.85);
	}

	vec3 rd = reflect(-vdir, NORMAL);
	vec3 sky = sky_horizon.rgb;
	vec3 wr = (INV_VIEW_MATRIX * vec4(rd, 0.0)).xyz;
	sky = mix(sky, sky * vec3(0.72, 0.84, 1.0), smoothstep(0.05, 0.7, wr.y));
	vec3 refl = sky;
	float dbg_hit = 0.0;
	float dbg_try = 0.0;
	dbg_try = (near > 0.0 && rd.z < 0.0) ? 1.0 : 0.0;

	if (near > 0.0 && rd.z < 0.0 && wr.y > 0.0) {
		float t = 0.25;
		float tp = 0.0;
		for (int i = 0; i < 22; i++) {
			vec3 q = VERTEX + rd * t;
			vec4 cp = PROJECTION_MATRIX * vec4(q, 1.0);
			vec2 suv = cp.xy / cp.w * 0.5 + 0.5;
			if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
				break;
			}
			float gap = view_z(suv, INV_PROJECTION_MATRIX) - q.z;
			if (gap > 0.0) {

				float lo = tp, hi = t;
				for (int j = 0; j < 4; j++) {
					float mid = (lo + hi) * 0.5;
					vec3 qm = VERTEX + rd * mid;
					vec4 cm = PROJECTION_MATRIX * vec4(qm, 1.0);
					vec2 um = cm.xy / cm.w * 0.5 + 0.5;
					if (view_z(um, INV_PROJECTION_MATRIX) - qm.z > 0.0) { hi = mid; suv = um; } else { lo = mid; }
				}
				vec3 qh = VERTEX + rd * hi;
				vec3 hw = (INV_VIEW_MATRIX * vec4(qh, 1.0)).xyz;

				float tol = hi * 0.25 + 0.4;
				float gap2 = view_z(suv, INV_PROJECTION_MATRIX) - qh.z;
				float conf = smoothstep(0.0, 0.12, min(min(suv.x, 1.0 - suv.x), min(suv.y, 1.0 - suv.y)));
				conf *= 1.0 - smoothstep(tol * 0.55, tol, gap2);
				conf *= 1.0 - smoothstep(18.0, 40.0, hi);
				conf *= smoothstep(0.0, 0.12, wr.y);
				conf *= smoothstep(wpos.y - 0.05, wpos.y + 0.25, hw.y);
				refl = mix(sky, textureLod(screen_tex, suv, 2.0).rgb, conf);
				dbg_hit = conf;
				break;
			}
			tp = t;
			t = t * 1.28 + 0.05;
		}
	}
	float fres = pow(1.0 - clamp(dot(NORMAL, vdir), 0.0, 1.0), 4.0);
	float rk = mix(0.04, 1.0, fres) * reflect_k;
	col = mix(col, refl, rk);
	col *= 0.9 + 0.32 * clamp(dot(nw, normalize(vec3(-0.35, 1.0, 0.45))) * 1.6 - 0.6, 0.0, 1.0) * near;

	float breathe = 0.5 + 0.5 * sin(TIME * 1.1 + (wpos.x + wpos.z) * 0.15);
	float lap = 1.0 - smoothstep(0.03, 0.07 + 0.05 * breathe, d + (h1 - 0.5) * 0.06);
	float wet = (has_depth && !paddy && !stream) ? smoothstep(0.0, 0.025, d) : 1.0;
	float touch = 1.0 - smoothstep(contact * 0.25, contact * (0.7 + 0.6 * h2), thick);
	touch *= smoothstep(0.35, 0.6, h1 + 0.25 * breathe) * near;
	float foam = clamp(max(lap * wet, touch * 0.85), 0.0, 1.0);
	if (water2) {
		float fleck = smoothstep(0.88, 0.91, h2) * wb * fm * near * 0.3;
		float ring = od < 3.0 ? w2_ring(od, h1, breathe, TIME) : 0.0;
		foam = max(foam, max(fleck, ring) * wet);
		if (boat_wake.w > 0.05) {
			float wrip;
			foam = max(foam, w2_wake(wpos.xz, h2, wrip) * wet);
			col = mix(col, band, wrip * 0.25);
		}
	}
	if (stream && COLOR.r + COLOR.g > 0.0) {
		float wn = texture(noise_tex, vec2(UV.x * 1.7, UV.y * 0.35 - TIME * 0.9)).r;
		float white = COLOR.r * (0.6 + 0.4 * smoothstep(0.35, 0.55, wn))
			+ COLOR.g * smoothstep(0.45, 0.62, wn + (h2 - 0.5) * 0.3);
		foam = max(foam, clamp(white, 0.0, 1.0));
	}
	col = mix(col, foam_col.rgb, foam);

	ALBEDO = mix(band * 0.12, foam_col.rgb, foam);
	EMISSION = col * (1.0 - foam) * 0.92;
	ROUGHNESS = 1.0;
	ALPHA = 1.0;
	if (!FRONT_FACING) {

		vec3 look = normalize((INV_VIEW_MATRIX * vec4(normalize(VERTEX), 0.0)).xyz);
		vec2 buv = clamp(SCREEN_UV + nw.xz * 0.06, vec2(0.001), vec2(0.999));
		vec3 above = textureLod(screen_tex, buv, 0.8).rgb;
		float win = smoothstep(0.6, 0.74, look.y + (h - 0.5) * 0.06);

		float sh = smoothstep(0.45, 0.75, h) * 0.5 + smoothstep(0.58, 0.64, h1) * 0.6 + clamp(nw.x * 3.0 + nw.z * 2.0, -0.4, 0.6);
		vec3 tir = jade_mid.rgb * (0.55 + 0.35 * sh);
		vec3 ucol = mix(tir, above * vec3(0.82, 0.98, 0.92) + vec3(0.04, 0.07, 0.06), win);
		ucol += win * smoothstep(0.62, 0.66, h1) * 0.25;
		NORMAL = -NORMAL;
		ALBEDO = vec3(0.0);
		EMISSION = ucol;
		ROUGHNESS = 1.0;
		ALPHA = 1.0;
	}
	if (debug_view == 1) { ALBEDO = vec3(0.0); EMISSION = vec3(dbg_hit, dbg_try * 0.3, 0.0); }
	if (debug_view == 3) { ALBEDO = vec3(0.0); EMISSION = vec3(near, rd.z < 0.0 ? 1.0 : 0.0, clamp(-VERTEX.z / 60.0, 0.0, 1.0)); }
	if (debug_view == 2) { ALBEDO = vec3(0.0); EMISSION = vec3(clamp(thick / 3.0, 0.0, 1.0)); }
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.25, 0.75, w * ATTENUATION);
	float reach = LIGHT_IS_DIRECTIONAL ? 1.0 : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += mix(mix(shadow_tint.rgb, vec3(1.0), 0.45), vec3(1.0), lit) * LIGHT_COLOR / PI * reach;
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 hv = normalize(LIGHT + VIEW);
		float nh = clamp(dot(NORMAL, hv), 0.0, 1.0);
		float glint = step(0.45, pow(nh, 300.0));
		float sheen = pow(nh, 40.0) * 0.28;
		SPECULAR_LIGHT += (glint * 1.6 + sheen) * LIGHT_COLOR * ATTENUATION;
	}
}
