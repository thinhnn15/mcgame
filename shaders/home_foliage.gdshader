shader_type spatial;
render_mode cull_disabled, specular_disabled, depth_draw_opaque;
#include "res://shaders/sky_light.gdshaderinc"
#include "res://shaders/wind_gust.gdshaderinc"
#include "res://shaders/season.gdshaderinc"
#include "res://shaders/far_haze.gdshaderinc"

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;

uniform sampler2D bloom_mask : source_color, hint_default_transparent, filter_nearest, repeat_disable;

uniform sampler2D species_map : hint_default_black, filter_nearest, repeat_disable;
uniform vec4 shadow_tint : source_color = vec4(0.62, 0.6, 0.8, 1.0);
uniform float shade_soft = 0.4;
uniform float sway = 0.06;
uniform float flutter = 0.025;
uniform float through = 0.35;

uniform int lod_mode = 0;
uniform float lod_r = 45.0;
uniform vec3 view_pos = vec3(0.0);
uniform float lod_band = 6.0;

uniform float near_fade = 4.5;

uniform bool billboard = false;

uniform bool forest_pick = false;
uniform vec2 forest_cols = vec2(0.375, 0.625);
const float BAYER4[16] = float[](0.03, 0.53, 0.16, 0.66, 0.78, 0.28, 0.91, 0.41, 0.22, 0.72, 0.09, 0.59, 0.97, 0.47, 0.84, 0.34);

uniform bool leaf_dissolve = false;
uniform sampler2D leaf_mask : hint_default_white, filter_linear, repeat_enable;
uniform float leaf_mask_scale = 4.0;

uniform float far_cut = 0.0;
uniform bool far_set = false;
uniform vec3 far_thin = vec3(400.0, 800.0, 40.0);
uniform vec2 far_grow = vec2(0.5, 0.25);

uniform float far_spread = 0.3;

uniform bool far_kinds = false;

uniform vec4 far_haze_color : source_color = vec4(0.70, 0.80, 0.88, 1.0);
uniform vec3 far_hz = vec3(190.0, 1000.0, 0.7);

uniform vec3 far_mist = vec3(0.0, 16.0, 0.0);
uniform vec4 far_mist_color : source_color = vec4(0.93, 0.95, 0.96, 1.0);

uniform vec3 far_crown = vec3(0.38, 240.0, 360.0);
uniform vec2 far_jit = vec2(0.16, 0.1);

varying float is_leaf;
varying vec3 fr;
varying float thin_k;
varying vec2 far_j;
varying float lod_k;
varying vec3 wnrm;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	is_leaf = UV2.y >= 0.0 ? 1.0 : 0.0;
	float k = UV2.x;
	float t = TIME;
	vec3 bb_n = vec3(0.0);
	int fk = int(INSTANCE_CUSTOM.r * 4.0 + 0.5);
	if (far_kinds) {
		if (fk == 1) {
			VERTEX.xy = CUSTOM0.xy;
			UV = CUSTOM0.zw;
			NORMAL = vec3(CUSTOM2.xy, sqrt(max(1.0 - dot(CUSTOM2.xy, CUSTOM2.xy), 0.0)));
		} else if (fk == 2) {
			VERTEX.xy = CUSTOM1.xy;
			UV = CUSTOM1.zw;
			NORMAL = vec3(CUSTOM2.zw, sqrt(max(1.0 - dot(CUSTOM2.zw, CUSTOM2.zw), 0.0)));
		}
	}
	fr = (leaf_dissolve || far_set) ? INSTANCE_CUSTOM.gba : vec3(0.0);
	thin_k = 0.0;
	far_j = vec2(0.5);
	bool far_gone = false;
	if (far_cut > 0.0) {
		float fd = distance(origin, view_pos);
		far_gone = far_set ? fd <= far_cut : fd > far_cut;
		if (far_set) {
			float g = 0.5 * smoothstep(far_thin.x - far_thin.z, far_thin.x + far_thin.z, fd)
					+ 0.25 * smoothstep(far_thin.y - far_thin.z, far_thin.y + far_thin.z, fd);
			float tr = max(1.0 - fr.x, 0.08);
			thin_k = smoothstep(tr - 0.08, tr + 0.08, g);
			far_gone = far_gone || thin_k >= 1.0;
			float sp = 1.0 + far_spread * smoothstep(far_cut, far_thin.x, fd);

			float jk = smoothstep(far_cut, far_cut + 110.0, fd);
			float j1 = fract(fr.y * 7.13 + fr.z * 3.71);
			float j2 = fract(fr.x * 13.7 + fr.z * 5.31);
			vec2 gs = vec2(sp * pow(1.0 - g, -far_grow.x) * (1.0 + jk * far_jit.x * 0.6 * (2.0 * j1 - 1.0)),
					pow(1.0 - g, -far_grow.y) * (1.0 + jk * far_jit.x * (2.0 * j2 - 1.0)));
			VERTEX.xy *= gs;
			far_j = vec2(fract(fr.y * 5.77 + fr.x * 9.13), fract(fr.z * 11.3 + fr.x * 2.9)) * jk + 0.5 * (1.0 - jk);

			float ch = fk == 1 ? CUSTOM3.y : (fk == 2 ? CUSTOM3.z : CUSTOM3.x);
			VERTEX.y -= far_crown.x * ch * gs.y * smoothstep(far_crown.y, far_crown.z, fd);
		}

		if (billboard && far_set && fract(fr.y * 31.7) < 0.5) {
			VERTEX.x = -VERTEX.x;
			NORMAL.x = -NORMAL.x;
		}
	}
	if (billboard) {
		vec3 rt = INV_VIEW_MATRIX[0].xyz;
		rt = normalize(vec3(rt.x, 0.0, rt.z) + vec3(1e-4, 0.0, 0.0));
		vec3 bk = vec3(-rt.z, 0.0, rt.x);
		vec3 wv = rt * VERTEX.x * length(MODEL_MATRIX[0].xyz) + vec3(0.0, VERTEX.y * length(MODEL_MATRIX[1].xyz), 0.0);
		bb_n = normalize(rt * NORMAL.x + vec3(0.0, NORMAL.y, 0.0) + bk * NORMAL.z);
		VERTEX = inverse(mat3(MODEL_MATRIX)) * wv;
	}
	float tp = dot(origin, vec3(0.37, 0.0, 0.21));

	float gust = 0.2 + 0.8 * wg_gust(origin.xz);
	float lean = (0.3 + 0.7 * gust) * (0.6 + 0.4 * sin(t * 1.3 + tp));
	vec3 w = wg_dir3() * lean * k * k * sway;
	float ph = UV2.y * 6.2832;
	w += is_leaf * k * flutter * (0.5 + gust) * vec3(sin(t * 5.0 + ph * 9.0), sin(t * 7.3 + ph * 5.0) * 0.6, cos(t * 4.6 + ph * 7.0));
	VERTEX += inverse(mat3(MODEL_MATRIX)) * w;
	wnrm = billboard ? bb_n : normalize(mat3(MODEL_MATRIX) * NORMAL);
	lod_k = 0.0;
	if (lod_mode != 0) {
		float d = distance(origin, view_pos);
		float b = min(lod_band, lod_r * 0.2);
		lod_k = smoothstep(lod_r - b, lod_r + b, d);
		if ((lod_mode == 1 && d > lod_r + b) || (lod_mode == 2 && d <= lod_r - b)) {
			VERTEX = vec3(0.0);
		}
	}
	if (forest_pick) {
		int kd = UV.x < forest_cols.x ? 0 : (UV.x < forest_cols.y ? 1 : 2);
		if (kd != int(INSTANCE_CUSTOM.r * 4.0 + 0.5)) {
			VERTEX = vec3(0.0);
		}
	}
	if (far_gone) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	if (lod_mode != 0 && lod_k > 0.0 && lod_k < 1.0) {
		float bv = leaf_dissolve ? textureLod(leaf_mask, UV * leaf_mask_scale + fr.yz, 0.0).r
				: BAYER4[(int(FRAGCOORD.x) % 4) + (int(FRAGCOORD.y) % 4) * 4];
		if ((lod_mode == 1 && bv < lod_k) || (lod_mode == 2 && bv >= lod_k)) {
			discard;
		}
	}
	if (thin_k > 0.0 && textureLod(leaf_mask, UV * leaf_mask_scale + fr.yz, 0.0).r < thin_k) {
		discard;
	}
	float cd = length(VERTEX);
	if (cd < near_fade) {
		float keep = smoothstep(near_fade * 0.35, near_fade, cd);
		if (BAYER4[(int(FRAGCOORD.x) % 4) + (int(FRAGCOORD.y) % 4) * 4] > keep) {
			discard;
		}
	}
	if (UV2.y < -1.5) {
		vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		float face = abs(dot(fn, normalize(-VERTEX)));
		if (BAYER4[(int(FRAGCOORD.x) % 4) + (int(FRAGCOORD.y) % 4) * 4] > smoothstep(0.06, 0.3, face)) {
			discard;
		}
	}
	vec4 tex = texture(atlas, UV);
	ALBEDO = tex.rgb * COLOR.rgb * COLOR.a;
	if (season_strength > 0.0) {
		vec4 bm = texture(bloom_mask, UV);
		if (bm.a > 0.1) {
			float off = bloom_off(bm, UV, 96.0) * season_strength;
			if (bm.a > 0.56 && off > 0.5) {
				discard;
			}
			ALBEDO = mix(ALBEDO, bm.rgb * COLOR.rgb * COLOR.a, off);
		}
		ALBEDO = season_tint(ALBEDO);
		float sp = floor(texture(species_map, UV).r * 8.0 + 0.5);
		if (sp > 0.5) {

			float rank = UV2.y >= 0.0 ? UV2.y : fract(sin(dot(floor(UV * 96.0), vec2(12.9898, 78.233))) * 43758.5453);
			if (!leaf_keep(sp, rank)) {
				discard;
			}
			ALBEDO = leaf_year(ALBEDO, sp);
		}
	}

	vec2 tc = UV * vec2(textureSize(atlas, 0));
	vec2 ddx = dFdx(tc);
	vec2 ddy = dFdy(tc);
	float mip = max(0.0, 0.5 * log2(max(dot(ddx, ddx), dot(ddy, ddy))));
	ALPHA = tex.a * (1.0 + mip * 0.25);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.25;
	ALPHA_TEXTURE_COORDINATE = tc;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(wnrm, 0.0)).xyz);
	if (far_set) {
		float fd = length(VERTEX);
		vec3 fp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec4 hz = far_haze(fp, CAMERA_POSITION_WORLD, fd, smoothstep(far_hz.x, far_hz.y, fd) * far_hz.z,
				far_haze_color.rgb, far_hz.x, far_hz.y, far_hz.z);

		ALBEDO *= (1.0 + far_jit.y * (2.0 * far_j.x - 1.0)) * mix(vec3(0.96, 0.98, 1.05), vec3(1.05, 1.02, 0.9), far_j.y);
		float m = (1.0 - smoothstep(2.0, far_mist.y, fp.y)) * smoothstep(60.0, 400.0, fd) * far_mist.x;
		m += far_mist.z * 0.38 * (1.0 - smoothstep(4.0, far_mist.y * 2.2, fp.y)) * smoothstep(150.0, 420.0, fd);
		float fh = clamp(hz.a + m, 0.0, 0.85);
		ALBEDO *= 1.0 - fh;
		EMISSION = mix(hz.rgb, far_mist_color.rgb, m / max(hz.a + m, 0.001)) * fh;
	}
	SL_FRAGMENT;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.5 - shade_soft, 0.5 + shade_soft, w * ATTENUATION);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), lit);

	float reach = LIGHT_IS_DIRECTIONAL ? SL_SUN : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI * reach;
	float trans = clamp(dot(-NORMAL, LIGHT), 0.0, 1.0) * through * ATTENUATION;
	DIFFUSE_LIGHT += trans * vec3(1.0, 1.0, 0.8) * LIGHT_COLOR / PI;
}
