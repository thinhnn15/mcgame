shader_type spatial;
render_mode specular_disabled, cull_disabled;

uniform vec4 shallow : source_color = vec4(0.47, 0.88, 0.86, 1.0);
uniform vec4 deep : source_color = vec4(0.28, 0.62, 0.92, 1.0);
uniform vec4 foam : source_color = vec4(1.0);
uniform float shore_r = 20.5;
uniform float t = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += 0.04 * sin(wpos.x * 0.6 + TIME * 1.2) * cos(wpos.z * 0.5 + TIME);
}

void fragment() {
	float r = length(wpos.xz);
	float k = smoothstep(shore_r, shore_r + 14.0, r);
	vec3 c = mix(shallow.rgb, deep.rgb, k);
	float ring = sin(r * 2.2 - TIME * 1.5) * 0.5 + 0.5;
	float f = smoothstep(shore_r + 1.6, shore_r, r) * (0.55 + 0.45 * ring);
	c = mix(c, foam.rgb, f * 0.85);
	float sp = pow(max(0.0, sin(wpos.x * 1.7 + TIME * 0.8) * sin(wpos.z * 1.3 - TIME * 0.6)), 24.0);
	c += sp * 0.35 * (1.0 - k * 0.5);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}

void light() {
	float w = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	DIFFUSE_LIGHT += mix(0.85, 1.0, w) * LIGHT_COLOR * ATTENUATION / PI;
}
