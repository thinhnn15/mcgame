global uniform vec2 wind_dir;
global uniform float wind_gust;

#define WG_SPEED 2.4
#define WG_SCALE 24.0

float wg_gust(vec2 xz) {
	vec2 d = normalize(wind_dir + vec2(1e-4, 0.0));

	float n = textureLod(cloud_noise, fract((xz - d * TIME * WG_SPEED) / WG_SCALE), 0.0).a;
	return smoothstep(0.35, 0.8, n) * clamp(wind_gust, 0.0, 2.5);
}

float wg_gust_px(vec2 xz) {
	vec2 d = normalize(wind_dir + vec2(1e-4, 0.0));
	vec2 uv = (xz - d * TIME * WG_SPEED) / WG_SCALE;
	float n = textureGrad(cloud_noise, fract(uv), dFdx(uv), dFdy(uv)).a;
	return smoothstep(0.35, 0.8, n) * clamp(wind_gust, 0.0, 2.5);
}

vec3 wg_dir3() {
	vec2 d = normalize(wind_dir + vec2(1e-4, 0.0));
	return vec3(d.x, 0.0, d.y);
}
