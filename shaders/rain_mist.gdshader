shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled;

#include "res://shaders/intro_light.gdshaderinc"
#include "res://shaders/intro_wind.gdshaderinc"

uniform vec2 size = vec2(7.0, 1.6);
uniform vec4 tint : source_color = vec4(0.42, 0.45, 0.66, 1.0);
uniform float alpha = 0.16;
uniform float flash = 0.0;

varying vec3 v_col;
varying float v_fade;
varying vec2 v_seed;

void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - c;
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	vec3 wp = c + side * VERTEX.x * size.x + vec3(0.0, 1.0, 0.0) * (VERTEX.y + 0.5) * size.y;
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
	vec3 L = painted_light(c + vec3(0.0, 0.5, 0.0), normalize(to_cam));
	v_col = tint.rgb * (1.0 + flash * 2.0) + L * 1.1;
	float dist = length(to_cam);
	float life = INSTANCE_CUSTOM.y;
	v_fade = smoothstep(2.0, 6.0, dist) * (1.0 - smoothstep(35.0, 55.0, dist)) * smoothstep(0.0, 0.25, life) * smoothstep(1.0, 0.7, life)
		* (0.7 + 0.6 * dot(L, vec3(0.4)));
	v_seed = vec2(float(INSTANCE_ID) * 0.37, float(INSTANCE_ID) * 1.13);
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float shape = (1.0 - smoothstep(0.3, 1.0, abs(p.x))) * smoothstep(0.0, 0.15, p.y) * (1.0 - smoothstep(0.25, 1.0, p.y));
	vec2 q = vec2(UV.x * 3.0, UV.y * 1.2) + v_seed - vec2(TIME * 0.12, TIME * 0.05);
	float n = wind_noise(q * 2.0) * 0.6 + wind_noise(q * 4.7 + 3.0) * 0.4;
	ALBEDO = v_col;
	ALPHA = clamp(shape * smoothstep(0.3, 0.8, n) * alpha * v_fade, 0.0, 1.0);
}
