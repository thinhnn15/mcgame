shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.78, 0.45, 1.0);
uniform float strength = 0.45;
uniform float night = 0.0;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 1.6);
	ALBEDO = color.rgb * a * strength * night;
}
