shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 tint : source_color = vec4(0.66, 0.84, 0.88, 0.14);
uniform vec4 sky_high : source_color = vec4(0.84, 0.94, 1.0, 1.0);
uniform vec4 sky_low : source_color = vec4(0.56, 0.72, 0.78, 1.0);
uniform float glint = 0.32;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(-VERTEX);
	float ndv = abs(dot(n, v));
	float fres = pow(1.0 - ndv, 3.0);
	vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-v, n * sign(dot(n, v))), 0.0)).xyz;
	vec3 sky = mix(sky_low.rgb, sky_high.rgb, smoothstep(-0.25, 0.6, r.y));
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float s = fract(dot(wp - cam * 0.25, normalize(vec3(0.9, 1.5, 0.5))) * 0.7);
	float bands = smoothstep(0.0, 0.03, s) * smoothstep(0.17, 0.13, s) + 0.55 * smoothstep(0.24, 0.26, s) * smoothstep(0.31, 0.29, s);
	ALBEDO = mix(tint.rgb, sky, clamp(fres * 0.85 + 0.15, 0.0, 1.0)) + vec3(bands * glint);
	ALPHA = clamp(tint.a + fres * 0.6 + bands * glint * 0.55, 0.0, 0.92);
}
