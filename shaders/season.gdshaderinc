global uniform float season;
global uniform float season_strength;
global uniform sampler2D season_ramp;
global uniform sampler2D bloom_ramp;

const float SEASON_RAMP_ROWS = 64.0;
const float SEASON_ROWS = 16.0;

float season_u() {
	return mix(0.5 / 256.0, 1.0 - 0.5 / 256.0, fract(season));
}

vec3 season_tint_w(vec3 c, float w) {
	float leaf = clamp((c.g - max(c.r, c.b)) * 4.0, 0.0, 1.0);
	float lum = clamp(dot(c, vec3(0.3, 0.59, 0.11)) * 1.6, 0.0, 1.0);
	vec2 at = vec2(mix(0.5 / 256.0, 1.0 - 0.5 / 256.0, lum),
			mix(0.5 / SEASON_RAMP_ROWS, 1.0 - 0.5 / SEASON_RAMP_ROWS, fract(season)));
	vec3 m = textureLod(season_ramp, at, 0.0).rgb * 2.0;
	return mix(c, c * m, season_strength * w * leaf);
}

vec3 season_tint(vec3 c) {
	return season_tint_w(c, 1.0);
}

float bloom_off(vec4 m, vec2 uv, float cell) {
	if (m.a < 0.1) {
		return 0.0;
	}
	float sp = floor(m.a * 8.0 + 0.5);
	float b = textureLod(bloom_ramp, vec2(season_u(), (sp - 0.5) / SEASON_ROWS), 0.0).r;
	float rank = fract(sin(dot(floor(uv * cell), vec2(12.9898, 78.233))) * 43758.5453);
	return 1.0 - smoothstep(rank - 0.06, rank + 0.06, b * 1.04 - 0.02);
}

vec3 leaf_year(vec3 c, float sp) {
	if (sp < 0.5) {
		return c;
	}
	vec4 y = textureLod(bloom_ramp, vec2(season_u(), (7.5 + sp) / SEASON_ROWS), 0.0);
	float leaf = clamp((c.g - max(c.r, c.b)) * 10.0, 0.0, 1.0);
	float k = clamp(dot(c, vec3(0.3, 0.59, 0.11)) / 0.16, 0.4, 1.4);
	return mix(c, y.rgb * k, y.a * leaf * season_strength);
}

bool leaf_keep(float sp, float rank) {
	if (sp < 0.5) {
		return true;
	}
	float cover = textureLod(bloom_ramp, vec2(season_u(), (11.5 + sp) / SEASON_ROWS), 0.0).r;
	return rank <= mix(1.0, cover, season_strength) + 0.001;
}
