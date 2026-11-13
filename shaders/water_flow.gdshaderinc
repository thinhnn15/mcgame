uniform bool water2 = false;
uniform sampler2D flow_tex : filter_linear, repeat_disable;
uniform vec4 flow_rect = vec4(-1032.0, -556.0, 0.0004845, 0.0006868);
uniform float flow_speed = 0.75;
uniform float stream_flow = 1.3;
uniform float flow_period = 3.0;
global uniform vec4 boat_wake;

vec4 w2_sample(vec2 xz) {
	vec2 uv = (xz - flow_rect.xy) * flow_rect.zw;
	vec4 f = texture(flow_tex, uv);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	return vec4((f.rg * 2.0 - 1.0) * flow_speed * inside, mix(7.0, f.b * 8.0 - 1.0, inside), f.a);
}

void w2_flow(vec2 flow_uv, float jit, float tm, inout vec2 uv1, inout vec2 uv2, out float wa, out float wb, out float k) {
	float m = smoothstep(0.004, 0.03, length(flow_uv));
	float t0 = fract(tm / flow_period + jit);
	float t1 = fract(t0 + 0.5);
	uv1 -= flow_uv * (t0 - 0.5) * flow_period;
	uv2 -= flow_uv * 2.3 * (t1 - 0.5) * flow_period;
	float a = 1.0 - abs(2.0 * t0 - 1.0);
	wa = mix(0.6, a, m);
	wb = 1.0 - wa;
	k = 0.72 * inversesqrt(wa * wa + wb * wb);
}

float w2_ring(float od, float h1, float breathe, float tm) {

	float n = h1 - 0.5;
	float band = 1.0 - smoothstep(0.0, 0.3 + 0.25 * breathe, max(od, 0.0) + n * 0.5);
	band *= smoothstep(0.4, 0.62, h1 + 0.22 * breathe) * smoothstep(-1.2, -0.4, od);
	float ph = fract(tm * 0.22 + h1 * 0.15);
	float r2 = (1.0 - smoothstep(0.0, 0.22, abs(od - 0.5 - 1.5 * ph + n * 0.6))) * (1.0 - ph) * smoothstep(0.45, 0.62, h1);
	return clamp(max(band * 0.6, r2 * 0.35), 0.0, 1.0);
}

float w2_wake(vec2 xz, float h2, out float rip) {
	rip = 0.0;
	vec2 f = vec2(sin(boat_wake.z), cos(boat_wake.z));
	vec2 r = xz - boat_wake.xy;
	float b = -dot(r, f) - 1.9;
	float sd = abs(r.x * f.y - r.y * f.x);
	float spd = clamp(boat_wake.w / 3.0, 0.0, 1.0);
	float len = 6.0 + 2.0 * spd;
	if (b < -4.2 || b > len || sd > 2.0 + max(b, 0.0) * 0.5) {
		return 0.0;
	}
	float bp = max(b, 0.0);
	float fade = 1.0 - bp / len;
	fade *= fade;
	float n = (h2 - 0.5);

	float arm = abs(sd - (0.75 + bp * 0.36));
	float arms = (1.0 - smoothstep(0.03 + 0.06 * bp, 0.2 + 0.16 * bp, arm + n * (0.4 + 0.12 * bp)))
		* smoothstep(-0.6, 0.4, b) / (1.0 + 0.3 * bp)
		* mix(1.0, smoothstep(0.35, 0.6, h2), smoothstep(0.5, 3.0, bp));

	float trail = (1.0 - smoothstep(0.2, 0.75, sd + n * 0.5)) * smoothstep(-0.4, 0.3, b) * (1.0 - smoothstep(0.0, 3.5, b))
		* smoothstep(0.42, 0.58, h2 + 0.1);
	float hull = (1.0 - smoothstep(0.08, 0.25, abs(sd - 0.72) + n * 0.15)) * (1.0 - smoothstep(-0.3, 0.3, b)) * step(-4.0, b);
	rip = (1.0 - smoothstep(0.05, 0.2, abs(sd - (1.35 + bp * 0.45)))) * fade * smoothstep(-0.3, 0.6, b);
	return clamp(max(max(arms, trail), hull * 0.8) * fade, 0.0, 1.0) * mix(0.35, 1.0, spd);
}
