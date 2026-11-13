shader_type spatial;
render_mode specular_disabled, cull_back;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D tile_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tile_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_nrm = false;
uniform float nrm_depth = 1.0;
uniform vec2 tile_size = vec2(1.0);
uniform vec2 tile_origin = vec2(0.0);
uniform bool clamp_tile = false;
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.58, 0.80, 1.0);
uniform float shade_soft = 0.22;
uniform float rim = 0.35;

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
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
	uv = (uv - tile_origin) / tile_size;
	if (clamp_tile) {
		uv = clamp(uv, vec2(0.002), vec2(0.998));
	}
	ALBEDO = base_color.rgb * texture(tile_alb, uv).rgb;
	if (has_nrm) {
		vec3 n = texture(tile_nrm, uv).rgb * 2.0 - 1.0;
		n.xy *= nrm_depth;
		vec3 wn = normalize(t * n.x + b * n.y + w_nrm * n.z);
		NORMAL = normalize(mat3(VIEW_MATRIX) * wn);
	}
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
