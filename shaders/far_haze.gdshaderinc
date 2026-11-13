global uniform vec4 sky_horizon : source_color;
uniform bool fh_on = false;
uniform float fh_len = 0.7;
uniform float fh_gain = 1.3;
uniform float fh_base = 2.0;
uniform float fh_scale = 75.0;
uniform float fh_top = 0.35;
uniform float fh_sky = 0.3;

uniform float fh_sun_sky = 0.65;
uniform float fh_warm_top = 1.0;

uniform vec3 fh_sun = vec3(0.0, 1.0, 0.0);
uniform vec3 fh_glow = vec3(0.0);

vec4 far_haze(vec3 p, vec3 cam, float dist, float h_old, vec3 col, float near, float far, float amax) {
	if (!fh_on) {
		return vec4(col, h_old);
	}
	float hf = mix(fh_top, 1.0, exp(-max(p.y - fh_base, 0.0) / fh_scale));
	float tau = max(dist - near, 0.0) / (far * fh_len) * hf;
	float h = amax * fh_gain * (1.0 - exp(-tau)) * smoothstep(near, near + 500.0, dist);
	float s = max(dot((p - cam) / max(dist, 1.0), fh_sun), 0.0);
	float s2 = s * s;
	float lobe = s2 * s2 * s;

	float foot = (hf - fh_top) / (1.0 - fh_top);
	float wk = mix(fh_warm_top, 1.0, foot);
	vec3 c = mix(col, sky_horizon.rgb, fh_sky * (0.35 + fh_sun_sky * s2) * mix(1.0, wk, s2)) + fh_glow * lobe * wk;
	return vec4(c, h);
}
