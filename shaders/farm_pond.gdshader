shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec4 shallow : source_color = vec4(0.46, 0.60, 0.44, 1.0);
uniform vec4 deep : source_color = vec4(0.14, 0.30, 0.31, 1.0);
uniform vec4 sky : source_color = vec4(0.82, 0.88, 0.90, 1.0);
uniform vec2 centre = vec2(0.0);
uniform vec2 radii = vec2(3.0, 2.0);
uniform float wave_scale = 0.32;
uniform float wave_speed = 0.025;
uniform float wave_bend = 5.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = (wpos.xz - centre) / radii;
	float e = dot(q, q);
	if (e > 1.4) {
		discard;
	}
	vec2 uv1 = wpos.xz * wave_scale + TIME * wave_speed * vec2(1.0, 0.6);
	vec2 uv2 = wpos.xz * wave_scale * 1.9 - TIME * wave_speed * vec2(0.4, 1.2);
	float d = 0.012;
	float h1 = texture(noise_tex, uv1).r + texture(noise_tex, uv2).r * 0.6;
	float hx = texture(noise_tex, uv1 + vec2(d, 0.0)).r + texture(noise_tex, uv2 + vec2(d, 0.0)).r * 0.6 - h1;
	float hz = texture(noise_tex, uv1 + vec2(0.0, d)).r + texture(noise_tex, uv2 + vec2(0.0, d)).r * 0.6 - h1;
	vec3 nw = normalize(vec3(-hx * wave_bend, 1.0, -hz * wave_bend));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	float zd = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
	vp.xyz /= vp.w;
	float thick = clamp(VERTEX.z - vp.z, 0.0, 4.0);
	float k = smoothstep(0.0, 0.5, thick);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 col = mix(shallow.rgb, deep.rgb, k);
	col = mix(col, sky.rgb, fres * 0.6);
	float lap = smoothstep(0.0, 0.025, thick) * (1.0 - smoothstep(0.03, 0.07, thick))
		* (0.5 + 0.5 * sin(TIME * 1.3 + wpos.x * 3.0 + wpos.z * 2.0));
	ALBEDO = mix(col, vec3(0.93, 0.92, 0.84), lap * 0.35);
	ALPHA = mix(0.12, 0.93, smoothstep(0.0, 0.45, thick)) * (1.0 - smoothstep(1.25, 1.4, e));
	ROUGHNESS = 0.07;
	METALLIC = 0.0;
	SPECULAR = 0.65;
}
