shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_front, shadows_disabled;

#include "res://shaders/intro_light.gdshaderinc"
#include "res://shaders/intro_wind.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.62, 0.66, 0.9, 1.0);
uniform vec4 haze : source_color = vec4(0.2, 0.21, 0.36, 1.0);
uniform float alpha = 0.55;
uniform float haze_alpha = 0.16;
uniform float circumference = 280.0;
uniform float flash = 0.0;
uniform float y_fade_lo = -33.0;
uniform float y_fade_hi = 40.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float streaks(vec2 uv_m, float cols, float speed, float len, float t, float seed) {

	vec2 q = vec2(uv_m.x * cols, uv_m.y);
	q.x += uv_m.y * 0.18 * cols;
	float id = floor(q.x);
	float h = wind_hash(vec2(id, seed));
	float h2 = wind_hash(vec2(id, seed + 9.1));
	float y = fract((q.y + t * speed * (0.85 + 0.3 * h)) / len + h2);
	float along = smoothstep(0.0, 0.25, y) * smoothstep(0.7, 0.35, y) * step(0.35, h);
	float x = fract(q.x) - 0.5 - (h - 0.5) * 0.5;
	float w = fwidth(q.x) * 0.9 + 0.04;
	return smoothstep(w, 0.0, abs(x)) * along;
}

void fragment() {
	float u = UV.x * circumference;
	vec2 m = vec2(u, wpos.y);
	float t = TIME;
	float s = streaks(m, 1.6, 14.0, 6.0, t, 1.0) * 0.55 + streaks(m * vec2(1.0, 1.0) + 37.0, 3.1, 12.0, 4.0, t, 2.0) * 0.4
		+ streaks(m + 71.0, 6.3, 10.0, 3.0, t, 3.0) * 0.28;
	float sheet = rain_sheets(wpos, t);
	float g = wind_gust(wpos, t);
	float yf = smoothstep(y_fade_lo, y_fade_lo + 4.0, wpos.y) * (1.0 - smoothstep(y_fade_hi - 25.0, y_fade_hi, wpos.y));
	vec3 L = painted_light(wpos, normalize(CAMERA_POSITION_WORLD - wpos));
	vec3 col = mix(haze.rgb, tint.rgb, clamp(s, 0.0, 1.0)) * (1.0 + flash * 2.0) + L * 0.8;
	ALBEDO = col;
	ALPHA = clamp((s * alpha + haze_alpha) * sheet * (0.75 + 0.5 * g) * yf, 0.0, 1.0);
}
