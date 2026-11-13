#include "res://shaders/sky_light.gdshaderinc"

#ifndef TOON_CHARA
#define TOON_CHARA 0.0
#endif
uniform float chara = TOON_CHARA;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 color_b : source_color = vec4(1.0);
uniform vec4 design_b : source_color = vec4(1.0);
uniform bool design_b_inside = true;

uniform sampler2D pattern_tex : filter_linear_mipmap, repeat_enable;
uniform bool has_pattern = false;
uniform vec2 pattern_scale = vec2(1.0);
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform bool has_detail = false;
uniform float detail_strength = 0.35;
uniform vec2 detail_scale = vec2(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.58, 0.80, 1.0);
uniform float shade_soft = 0.22;
uniform float rim = 0.35;
uniform vec3 emission = vec3(0.0);

uniform sampler2D design_tex : filter_linear_mipmap;
uniform bool has_design = false;
uniform vec4 color_c : source_color = vec4(1.0);
uniform float uv_ao = 0.0;
#ifdef TOON_FABRIC

uniform int fabric = 0;
uniform float gloss_b = 0.0;
uniform bool has_weave = false;
uniform sampler2D weave_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 weave_scale = vec2(60.0);
uniform float weave_depth = 0.3;
uniform float weave_shade = 0.15;
varying float fab_b;
#endif

uniform vec3 tuck = vec3(0.0);

uniform bool has_maps = false;
uniform sampler2D detail_nrm : hint_normal, filter_linear_mipmap;
uniform sampler2D detail_mix : filter_linear_mipmap;
uniform float nrm_depth = 1.0;
uniform vec4 stitch_color : source_color = vec4(1.0);
uniform bool stitch_tint = false;

uniform bool has_albedo = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform bool has_prop_nrm = false;
uniform sampler2D prop_nrm : hint_normal, filter_linear_mipmap_anisotropic;
uniform float prop_nrm_depth = 1.0;
uniform bool has_prop_emit = false;
uniform sampler2D prop_emit : filter_linear_mipmap;
uniform float emit_strength = 1.2;

uniform float fold = 0.0;
uniform vec3 fold_apex = vec3(0.0);
uniform vec3 fold_up = vec3(0.0, 1.0, 0.0);

void vertex() {
	vec3 m = vec3(1.0) - COLOR.rgb;
	VERTEX -= NORMAL * dot(m, tuck);
	if (fold != 0.0) {
		vec3 rel = VERTEX - fold_apex;
		float along = dot(rel, fold_up);
		vec3 radial = rel - fold_up * along;
		float r = length(radial);
		vec3 rdir = r > 1e-4 ? radial / r : vec3(0.0);
		vec3 shut = fold_apex - fold_up * (length(rel) * 0.97) + rdir * (0.012 + 0.02 * min(r / 0.62, 1.0));
		VERTEX = mix(VERTEX, shut, fold);
	}
}

void fragment() {
	vec3 c = base_color.rgb;
	if (has_albedo) {
		c *= texture(albedo_tex, UV).rgb;
	}
	if (has_pattern) {
		float m = texture(pattern_tex, UV * pattern_scale).r;
		c = mix(c, color_b.rgb, m);
	}
#ifdef TOON_FABRIC
	fab_b = 0.0;
#endif
	if (has_design) {
		vec3 d = texture(design_tex, UV).rgb;
		c = mix(c, design_b.rgb, (FRONT_FACING || design_b_inside) ? d.r : 0.0);
		c = mix(c, color_c.rgb, d.g);
		c = mix(c, vec3(0.97, 0.96, 0.93), d.b);
#ifdef TOON_FABRIC
		fab_b = d.b * gloss_b;
#endif
	}
	if (has_detail) {
		float dt = texture(detail_tex, UV * detail_scale).r;
		c *= mix(1.0, dt * 1.15, detail_strength);
	}
	if (has_maps) {
		vec4 mx = texture(detail_mix, UV);
		c = stitch_tint ? mix(c, stitch_color.rgb, mx.b * 0.85) : c * (1.0 - 0.18 * mx.b);
		c *= (1.0 - 0.35 * mx.r) * mx.g;
		NORMAL_MAP = texture(detail_nrm, UV).rgb;
		NORMAL_MAP_DEPTH = nrm_depth;
	}
#ifdef TOON_FABRIC
	if (has_weave) {
		vec2 wuv = UV * weave_scale;
		vec4 wv = texture(weave_tex, wuv);

		vec2 fw = fwidth(wuv);
		float near = 1.0 - smoothstep(0.07, 0.16, max(fw.x, fw.y));
		vec3 n0 = has_maps ? NORMAL_MAP * 2.0 - 1.0 : vec3(0.0, 0.0, 1.0);
		vec2 wn = (wv.rg * 2.0 - 1.0) * (weave_depth * near / max(has_maps ? nrm_depth : 1.0, 0.25));
		NORMAL_MAP = normalize(vec3(n0.xy / max(n0.z, 0.2) + wn, 1.0)) * 0.5 + 0.5;
		if (!has_maps) {
			NORMAL_MAP_DEPTH = 1.0;
		}
		c *= 1.0 + (wv.b - 0.5) * 2.0 * weave_shade * near;
	}
#endif
	c *= 1.0 - uv_ao * UV.x;
	if (!FRONT_FACING) {
		c *= 0.8;
	}
	if (has_prop_nrm) {
		NORMAL_MAP = texture(prop_nrm, UV).rgb;
		NORMAL_MAP_DEPTH = prop_nrm_depth;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = emission + (has_prop_emit ? c * texture(prop_emit, UV).r * emit_strength : vec3(0.0));
	SL_FRAGMENT;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.5 - shade_soft, 0.5 + shade_soft, w * ATTENUATION);
	float rim_lit = mix(lit, max(lit, 0.45), chara);
	lit = sl_lift(lit, NORMAL, chara, LIGHT_IS_DIRECTIONAL);
	vec3 shade = mix(shadow_tint.rgb, vec3(1.0), lit);

	float reach = LIGHT_IS_DIRECTIONAL ? SL_SUN : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI * reach;
	float r = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim * rim_lit;
	DIFFUSE_LIGHT += r * LIGHT_COLOR / PI * reach;
#ifdef TOON_FABRIC

	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float nh = clamp(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0, 1.0);
	float sun = lit * reach;
	if (fabric == 1) {
		DIFFUSE_LIGHT += pow(1.0 - nv, 1.6) * 0.3 * (0.4 + 0.6 * lit) * reach * LIGHT_COLOR / PI;
	} else if (fabric == 2) {
		float band = smoothstep(0.62, 0.9, nh);
		DIFFUSE_LIGHT += band * 0.45 * sun * LIGHT_COLOR / PI;
		SPECULAR_LIGHT += smoothstep(0.9, 0.97, nh) * 0.12 * sun * LIGHT_COLOR / PI;
	} else if (fabric == 3) {
		SPECULAR_LIGHT += smoothstep(0.9, 0.975, nh) * 0.16 * sun * LIGHT_COLOR * vec3(1.0, 0.95, 0.85) / PI;
	}
	float metal = fabric == 4 ? 1.0 : fab_b;
	if (metal > 0.0) {

		SPECULAR_LIGHT += (smoothstep(0.78, 0.9, nh) * 0.45 + smoothstep(0.94, 0.97, nh) * 0.5) * metal * sun * LIGHT_COLOR / PI;
	}
#endif
}
