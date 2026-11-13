uniform vec4 lush : source_color = vec4(0.40, 0.66, 0.30, 1.0);
uniform vec4 dry : source_color = vec4(0.78, 0.76, 0.42, 1.0);
uniform vec4 earth : source_color = vec4(0.74, 0.64, 0.45, 1.0);

uniform sampler2D paint_tex : filter_linear, repeat_disable;
uniform float paint_on = 0.0;
uniform vec2 paint_grid = vec2(2049.0, 1024.0);

float hash(vec2 p) {

	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03 + 7.1) * 0.3 + vnoise(p * 4.1 + 3.3) * 0.15;
}

global uniform sampler2D ground_ao_tex : filter_linear_mipmap, repeat_disable;
global uniform vec4 ground_ao_rect;
global uniform float ground_ao_on;

float ao_shade(vec2 cg) {
	float r = cg.r * sqrt(cg.r);
	return 1.0 - mix(0.2 * cg.g, 0.46, r) * ground_ao_on;
}

float home_ground_ao(vec2 xz) {
	if (ground_ao_on <= 0.0) {
		return 1.0;
	}
	vec2 uv = (xz - ground_ao_rect.xy) * ground_ao_rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 1.0;
	}
	return ao_shade(textureLod(ground_ao_tex, uv, 0.0).rg);
}

float home_ground_ao_grad(vec2 xz, vec2 dx, vec2 dy) {
	if (ground_ao_on <= 0.0) {
		return 1.0;
	}
	vec2 uv = (xz - ground_ao_rect.xy) * ground_ao_rect.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 1.0;
	}
	return ao_shade(textureGrad(ground_ao_tex, uv, dx * ground_ao_rect.zw, dy * ground_ao_rect.zw).rg);
}

vec3 home_grass_c(vec3 c, vec2 xz, float dist) {

	float big = fbm(xz / 36.0);
	float mid = fbm(xz / 5.5 + 11.0);
	float bare = smoothstep(0.72, 0.86, fbm(xz / 9.0 + 41.0)) * (1.0 - smoothstep(60.0, 160.0, dist));
	vec3 patch = mix(lush.rgb, dry.rgb, smoothstep(0.35, 0.75, big));
	vec3 g = mix(c, c * patch / vec3(0.48, 0.70, 0.35), 0.55);
	g *= mix(0.86, 1.06, mid);
	if (paint_on > 0.0) {
		vec3 pf = textureLod(paint_tex, (xz + paint_grid.y + 0.5) / paint_grid.x, 0.0).rgb * 2.0;
		g *= mix(vec3(1.0), pf, paint_on);
	}

	if (canopy_on > 0.0) {
		float cv = textureLod(canopy_tex, (xz - canopy_rect.xy) * canopy_rect.zw, 0.0).r;
		g = mix(g, g * vec3(0.62, 0.72, 0.52), smoothstep(0.05, 0.6, cv) * 0.75 * canopy_on * (1.0 - 0.5 * paint_on));
	}

	return mix(g, earth.rgb, bare * 0.5) * mix(vec3(1.0), mix(vec3(0.83, 0.87, 0.82), vec3(0.6), bare * 0.5), rain_wet);
}

vec3 home_grass(vec3 c, vec2 xz, float dist) {
	return home_grass_c(c, xz, dist) * home_ground_ao(xz);
}
