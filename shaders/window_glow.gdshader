shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform sampler2D glass_tex : hint_default_black, filter_linear_mipmap;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 glow : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform float energy = 1.3;
uniform float night = 0.0;
instance uniform float lit = 0.0;

void vertex() {
	VERTEX += NORMAL * 0.004;
}

void fragment() {
	float m = texture(glass_tex, UV).r * lit * night;
	if (m < 0.01 || texture(albedo_tex, UV).a < 0.5) {
		discard;
	}
	ALBEDO = glow.rgb * energy * m;
}
