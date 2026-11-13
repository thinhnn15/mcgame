shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform;

#include "res://shaders/intro_light.gdshaderinc"

uniform vec2 size = vec2(0.22, 0.14);
uniform vec4 tint : source_color = vec4(0.75, 0.8, 0.95, 1.0);
uniform float alpha = 0.4;
uniform float far_fade = 16.0;
uniform vec4 ambient : source_color = vec4(0.35, 0.38, 0.55, 1.0);
uniform float flash = 0.0;

varying float v_age;
varying vec3 v_col;
varying float v_fade;
varying float v_seed;

void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - c;
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	float sc = length(MODEL_MATRIX[0].xyz);
	vec3 wp = c + side * VERTEX.x * size.x * sc + vec3(0.0, 1.0, 0.0) * (VERTEX.y + 0.5) * size.y * sc;
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
	v_age = INSTANCE_CUSTOM.y;
	v_seed = fract(float(INSTANCE_ID) * 0.618);
	vec3 L = painted_light(c, vec3(0.0, 1.0, 0.0));
	v_col = tint.rgb * ambient.rgb * (1.0 + flash * 2.0) + L * 1.5;
	float dist = length(to_cam);
	float lum = dot(L, vec3(0.3, 0.5, 0.2));
	v_fade = smoothstep(0.6, 1.5, dist) * (1.0 - smoothstep(far_fade * 0.55, far_fade, dist)) * (0.35 + lum * 1.6);
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float t = v_age;
	float a = 0.0;

	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float spread = (fi - 2.5) / 2.5;
		float vx = spread * (0.75 + 0.2 * fract(v_seed * 7.0 + fi * 0.37));
		float vy = (1.0 - abs(spread) * 0.45) * (0.85 + 0.3 * fract(v_seed * 3.0 + fi * 0.71));
		float x = vx * t;
		float y = 3.6 * vy * t * (1.0 - t);
		float dy = 3.6 * vy * (1.0 - 2.0 * t);
		vec2 dir = normalize(vec2(vx, dy * 0.6) + 1e-4);
		vec2 d = p - vec2(x, y);
		float along = dot(d, dir);
		float across = dot(d, vec2(-dir.y, dir.x));
		a += smoothstep(0.07, 0.025, abs(across)) * smoothstep(0.16, 0.0, abs(along)) * (1.0 - t * 0.5);
	}

	float ring = abs(length(vec2(p.x, p.y * 7.0)) - t * 0.95);
	a += smoothstep(0.07, 0.0, ring) * (1.0 - t) * 0.8;
	ALBEDO = v_col;
	ALPHA = clamp(a * alpha * (1.0 - t * 0.5) * v_fade, 0.0, 1.0);
}
