shader_type spatial;
render_mode specular_disabled, cull_back;

uniform sampler2DArray layers_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray layers_nrm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform int face_layer[12];
uniform vec4 face_tint[12] : source_color;
uniform float face_m[12];
uniform int dado_layer[12];
uniform vec4 dado_tint[12] : source_color;
uniform float dado_m[12];
uniform float dado_h = 0.9;
uniform vec4 rail_color : source_color = vec4(0.42, 0.29, 0.2, 1.0);
uniform float nrm_depth = 1.0;
uniform int glow_face = -1;
uniform float mip_bias = -0.9;
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.58, 0.80, 1.0);
uniform float shade_soft = 0.22;
uniform float rim = 0.35;

varying vec3 w_pos;
varying vec3 w_nrm;
varying flat int face;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
	face = clamp(int(UV2.x + 0.5), 0, 11);
}

void fragment() {
	vec3 an = abs(w_nrm);
	vec2 uv;
	vec3 t;
	vec3 b;
	if (an.y >= an.x && an.y >= an.z) {
		uv = w_pos.xz;
		t = vec3(1.0, 0.0, 0.0);
		b = vec3(0.0, 0.0, 1.0);
	} else if (an.x >= an.z) {
		uv = vec2(w_pos.z * sign(w_nrm.x), -w_pos.y);
		t = vec3(0.0, 0.0, sign(w_nrm.x));
		b = vec3(0.0, -1.0, 0.0);
	} else {
		uv = vec2(-w_pos.x * sign(w_nrm.z), -w_pos.y);
		t = vec3(-sign(w_nrm.z), 0.0, 0.0);
		b = vec3(0.0, -1.0, 0.0);
	}
	int layer = face_layer[face];
	vec3 tint = face_tint[face].rgb;
	float m = face_m[face];
	float rail = 0.0;
	if (face < 8 && dado_layer[face] >= 0 && w_pos.y < dado_h + 0.035) {
		if (w_pos.y < dado_h) {
			layer = dado_layer[face];
			tint = dado_tint[face].rgb;
			m = dado_m[face];
		} else {
			rail = 1.0;
		}
	}
	vec3 suv = vec3(uv / max(m, 0.05), float(layer));
	vec3 col = tint * texture(layers_alb, suv, mip_bias).rgb;
	ALBEDO = mix(col, rail_color.rgb, rail);
	if (face == glow_face) {
		ALBEDO = mix(ALBEDO, vec3(1.0, 0.86, 0.55), 0.22 + 0.1 * sin(TIME * 4.0));
	}
	vec3 n = texture(layers_nrm, suv).rgb * 2.0 - 1.0;
	n.xy *= nrm_depth * (1.0 - rail);
	vec3 wn = normalize(t * n.x + b * n.y + w_nrm * max(n.z, 0.05));
	NORMAL = normalize(mat3(VIEW_MATRIX) * wn);
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
