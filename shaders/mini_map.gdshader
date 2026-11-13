shader_type canvas_item;

uniform sampler2D map_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 center = vec2(0.0);
uniform vec2 fwd = vec2(0.0, -1.0);
uniform float radius_m = 70.0;
uniform float world = 2048.0;
uniform vec4 rim : source_color = vec4(0.99, 0.96, 0.88, 1.0);
uniform vec4 rim_line : source_color = vec4(0.48, 0.38, 0.32, 1.0);

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float px = fwidth(r);
	vec2 right = vec2(-fwd.y, fwd.x);
	vec2 w = center + (right * d.x - fwd * d.y) * radius_m;
	vec3 c = texture(map_tex, w / world + 0.5).rgb;
	c *= 1.0 - 0.18 * smoothstep(0.55, 0.9, r);
	float ring = smoothstep(0.86 - px, 0.86, r);
	float line = smoothstep(0.95 - px, 0.95, r);
	vec3 col = mix(c, rim.rgb, ring);
	col = mix(col, rim_line.rgb, line);
	COLOR = vec4(col, 1.0 - smoothstep(1.0 - px * 1.5, 1.0, r));
}
