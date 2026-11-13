shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.75, 0.45, 1.0);
uniform float strength = 0.1;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(facing, 2.5);
	float along = (1.0 - UV.y);
	float fall = pow(along, 1.6);
	float dist = length(VERTEX);
	ALBEDO = color.rgb * strength * edge * fall * smoothstep(1.0, 4.0, dist) * (1.0 - smoothstep(25.0, 60.0, dist));
}
