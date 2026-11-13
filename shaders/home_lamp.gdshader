shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 day_color : source_color = vec4(0.93, 0.92, 0.88, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.82, 0.5, 1.0);
uniform float glow_energy = 2.2;
uniform float night = 0.0;

void fragment() {
	ALBEDO = mix(day_color.rgb, glow_color.rgb * glow_energy, night);
}
