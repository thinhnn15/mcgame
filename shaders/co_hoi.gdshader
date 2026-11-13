shader_type spatial;
render_mode cull_disabled, specular_disabled, depth_draw_opaque;

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 shadow_tint : source_color = vec4(0.66, 0.62, 0.78, 1.0);
uniform float amp = 0.3;
uniform float wave_len = 1.1;
uniform float speed = 4.2;
uniform float width = 1.8;

varying vec3 n_obj;
varying float fold;

float wave(float x, float y, float t) {
	float g = 0.7 + 0.3 * sin(t * 0.37) * sin(t * 0.23 + 1.3);
	return (sin(x * 6.2832 / wave_len - t * speed + y * 0.9) * 0.75 + sin(x * 6.2832 / (wave_len * 0.53) - t * speed * 1.6 + y * 1.7) * 0.25) * g;
}

void vertex() {
	float t = TIME + dot(MODEL_MATRIX[3].xyz, vec3(0.31, 0.0, 0.17));
	float x = UV.x * width;
	float y = UV.y * width;
	float k = UV.x * UV.x * 0.85 + UV.x * 0.15;
	float w = wave(x, y, t) * amp * (0.35 + 0.65 * k) * smoothstep(0.0, 0.25, UV.x);
	VERTEX.z += w;
	VERTEX.y -= k * 0.08 * (0.6 + 0.4 * sin(t * 0.5));
	VERTEX.y += wave(x * 1.3 + 0.7, y, t * 1.1) * k * 0.05;
	VERTEX.x -= abs(w) * 0.35;
	float e = 0.02;
	float dw = (wave(x + e, y, t) - wave(x - e, y, t)) / (2.0 * e) * amp * (0.35 + 0.65 * k);
	n_obj = normalize(vec3(-dw * 1.6, 0.0, 1.0));
	fold = dw;
	VERTEX.x -= k * (0.06 + 0.05 * sin(t * 2.3 + y));
	NORMAL = n_obj;
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * (1.0 - clamp(fold * 0.55, -0.12, 0.28));
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float lit = smoothstep(0.3, 0.7, w * ATTENUATION);
	float reach = LIGHT_IS_DIRECTIONAL ? 1.0 : smoothstep(0.0, 0.2, ATTENUATION);
	DIFFUSE_LIGHT += mix(shadow_tint.rgb, vec3(1.0), lit) * LIGHT_COLOR / PI * reach;
	DIFFUSE_LIGHT += clamp(dot(-NORMAL, LIGHT), 0.0, 1.0) * 0.25 * LIGHT_COLOR / PI * ATTENUATION;
}
