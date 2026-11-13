global uniform sampler2D cloud_noise;
global uniform float cloud_shadow;
global uniform float chara_key;
global uniform sampler2D canopy_tex;
global uniform vec4 canopy_rect;
global uniform float canopy_on;
global uniform vec4 canopy_h;
global uniform float weathering;

varying float sl_cloud_v;
varying vec3 sl_wpos;

#define SL_FRAGMENT sl_wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz; sl_cloud_v = sl_cloud(sl_wpos, TIME)
#define SL_SUN sl_sun_at((INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz, INV_VIEW_MATRIX[3].xyz)

float sl_cloud(vec3 p_w, float t) {
	if (cloud_shadow >= 0.999) {
		return 1.0;
	}
	vec2 uv = (p_w.xz + vec2(t * 1.1, t * 0.45)) / 70.0;

	float c = textureGrad(cloud_noise, fract(uv), dFdx(uv), dFdy(uv)).a;
	return mix(1.0, cloud_shadow, smoothstep(0.56, 0.72, c));
}

float sl_lift(float lit, vec3 n, float ch, bool sun) {
	if (!sun || ch <= 0.0) {
		return lit;
	}

	float k = smoothstep(0.1, 0.75, dot(n, vec3(0.0, 0.55, 0.835)));
	return max(lit, k * chara_key * ch);
}

float sl_sun_at(vec3 lw, vec3 cam) {
	float s = sl_cloud_v;
	if (canopy_on > 0.0) {
		float far = smoothstep(30.0, 40.0, distance(sl_wpos, cam));
		if (far > 0.0) {
			vec2 at = sl_wpos.xz + lw.xz / max(lw.y, 0.3) * 4.0;
			vec2 cg = textureLod(canopy_tex, (at - canopy_rect.xy) * canopy_rect.zw, 0.0).rg;
			float c = cg.r;
			float top = canopy_h.x + cg.g / max(cg.r, 0.004) * canopy_h.y;
			c *= 1.0 - smoothstep(top - 0.6, top, sl_wpos.y);
			s *= 1.0 - 0.55 * c * far * canopy_on;
		}
	}
	return s;
}

vec3 sl_moss(vec3 c, vec3 p_w, vec3 wn, float amt) {
	float k = weathering * amt;
	if (k <= 0.0) {
		return c;
	}
	vec2 u1 = (p_w.xz + vec2(p_w.y * 0.37, -p_w.y * 0.21)) / 4.3;
	vec2 u2 = (p_w.xz + vec2(p_w.y * 0.53, p_w.y * 0.29)) / 0.83;
	float n1 = textureGrad(cloud_noise, fract(u1), dFdx(u1), dFdy(u1)).g;
	float n2 = textureGrad(cloud_noise, fract(u2), dFdx(u2), dFdy(u2)).b;
	float up = smoothstep(0.35, 0.85, wn.y);
	float m = up * smoothstep(0.48, 0.70, n1 * 0.72 + n2 * 0.28) * k;

	vec3 mcol = mix(vec3(0.076, 0.112, 0.025), vec3(0.136, 0.191, 0.042), n2);
	return mix(c, c * 0.35 + mcol * 0.65, m * 0.7);
}

global uniform float rain_wet;
vec3 sl_wet(vec3 c, float wet_k) {
	vec3 g = vec3(dot(c, vec3(0.3, 0.59, 0.11)));
	return mix(c, mix(c, g, (1.0 - wet_k) * 0.12) * wet_k, rain_wet);
}
float sl_sheen(float ndv, float amt) {
	float f = 1.0 - clamp(ndv, 0.0, 1.0);
	return rain_wet * amt * (0.05 + 0.35 * f * f * f * f) * 0.24;
}

float sl_sun(bool sun) {
	return sun ? sl_cloud_v : 1.0;
}
