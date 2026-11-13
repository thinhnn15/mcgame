shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 glow_col : source_color = vec3(1.0, 0.84, 0.36);

varying float v_ph;

void vertex() {
	v_ph = INSTANCE_CUSTOM.r * 6.2832;
}

void fragment() {
	float r = length((UV - 0.5) * 2.0);
	float breathe = 0.5 + 0.5 * sin(TIME * 2.0 + v_ph);
	float ring_r = 0.70 + 0.06 * breathe;
	float ring = exp(-pow((r - ring_r) / 0.13, 2.0));
	float fill = (1.0 - smoothstep(0.0, ring_r, r)) * 0.30;
	ALBEDO = glow_col;
	ALPHA = clamp((ring * 0.6 + fill) * (0.70 + 0.30 * breathe), 0.0, 1.0) * (1.0 - smoothstep(0.92, 1.0, r));
}
