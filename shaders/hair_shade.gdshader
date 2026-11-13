shader_type spatial;
render_mode blend_mul, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 shade : source_color = vec4(0.914, 0.737, 0.682, 1.0);
uniform float strength = 0.75;

void fragment() {

	float a = smoothstep(0.0, 0.3, UV.y) * (1.0 - smoothstep(0.45, 0.95, UV.y));
	ALBEDO = mix(vec3(1.0), shade.rgb, a * strength * UV.x);
}
