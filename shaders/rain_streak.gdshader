shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled;

#include "res://shaders/intro_light.gdshaderinc"
#include "res://shaders/intro_wind.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.72, 0.78, 0.95, 1.0);
uniform float alpha = 0.3;
uniform float width = 0.012;
uniform float length = 0.7;
uniform float near_fade = 1.2;
uniform float far_fade = 60.0;
uniform float px_angle = 0.0008;
uniform float lamp_gain = 1.6;
uniform vec4 ambient : source_color = vec4(0.35, 0.38, 0.55, 1.0);
uniform float flash = 0.0;
uniform vec3 cut_min = vec3(-4.7, -0.5, -3.75);
uniform vec3 cut_max = vec3(4.7, 3.3, 3.8);
uniform float gust_lean = 0.35;

varying float v_alpha;
varying vec3 v_col;

void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;

	float g = wind_gust(c, TIME);
	c += WIND_DIR * (g - 0.5) * 1.6 * gust_lean;
	vec3 up = normalize(normalize(MODEL_MATRIX[1].xyz) + WIND_DIR * (g - 0.5) * gust_lean);
	float sheet = rain_sheets(c, TIME);
	vec3 to_cam = CAMERA_POSITION_WORLD - c;
	float dist = length(to_cam);
	vec3 side = normalize(cross(up, to_cam));
	float w = max(width, dist * px_angle * 1.5);
	vec3 wp = c + side * VERTEX.x * w + up * VERTEX.y * length;
	VERTEX = (VIEW_MATRIX * vec4(wp, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(to_cam, 0.0)).xyz);
	vec3 L = painted_light(c, normalize(to_cam));
	v_col = tint.rgb * (ambient.rgb + flash * 0.8) + L * lamp_gain;
	float lum = dot(L, vec3(0.3, 0.5, 0.2));
	float cut = (all(greaterThan(c, cut_min)) && all(lessThan(c, cut_max))) ? 0.0 : 1.0;
	v_alpha = cut * alpha * (width / w) * smoothstep(near_fade * 0.5, near_fade, dist)
		* (1.0 - smoothstep(far_fade * 0.6, far_fade, dist)) * (1.0 + lum * 2.5) * sheet;
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = smoothstep(0.0, 0.45, 1.0 - UV.y) * smoothstep(1.0, 0.8, 1.0 - UV.y);
	ALBEDO = v_col;
	ALPHA = clamp(v_alpha * across * along, 0.0, 1.0);
}
