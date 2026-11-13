shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec2 cell = vec2(42.0, 20.0);
uniform float bund = 0.55;
uniform float field_from = 1000.0;
uniform vec4 gold_a : source_color = vec4(0.93, 0.80, 0.42, 1.0);
uniform vec4 gold_b : source_color = vec4(0.80, 0.66, 0.30, 1.0);
uniform vec4 green_a : source_color = vec4(0.55, 0.74, 0.30, 1.0);
uniform vec4 green_b : source_color = vec4(0.42, 0.62, 0.26, 1.0);
uniform vec4 stubble : source_color = vec4(0.72, 0.62, 0.40, 1.0);
uniform vec4 water_col : source_color = vec4(0.34, 0.40, 0.42, 1.0);
uniform vec4 seedling : source_color = vec4(0.50, 0.76, 0.32, 1.0);
uniform vec4 bund_col : source_color = vec4(0.46, 0.62, 0.30, 1.0);
uniform vec4 grass_col : source_color = vec4(0.52, 0.66, 0.34, 1.0);
uniform float flood_rate = 0.34;
uniform float gold_rate = 0.38;
uniform float stubble_rate = 0.14;
uniform vec3 wind_dir = vec3(0.94, 0.0, 0.33);
uniform vec4 flood_box = vec4(0.0);

varying vec3 wpos;

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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	p += vec2(vnoise(p * 0.011), vnoise(p.yx * 0.013 + 17.0)) * 14.0 - 7.0;
	float big = vnoise(p * 0.004);

	float row = floor(p.y / cell.y);
	float cw = cell.x * (0.7 + 0.6 * hash(vec2(row, 7.3)));
	float qx = p.x + hash(vec2(row, 3.1)) * cw;
	float col = floor(qx / cw);
	vec2 f = vec2(qx - col * cw, p.y - row * cell.y);
	float edge = min(min(f.x, cw - f.x), min(f.y, cell.y - f.y));
	float h = fract(hash(vec2(col, row)) * 0.45 + vnoise(p * 0.005 + 3.0) * 1.1);
	float fl = flood_rate + (big - 0.5) * 0.3;
	if (wpos.x > flood_box.x && wpos.x < flood_box.z && wpos.z > flood_box.y && wpos.z < flood_box.w) {
		fl = 2.0;
	}
	vec3 c;
	float rough = 0.9;
	float spec = 0.3;
	float aa = fwidth(p.x) + fwidth(p.y);
	if (h < fl) {
		c = water_col.rgb;
		rough = 0.04;
		spec = 0.6;
		float along = (h < fl * 0.5) ? f.x : f.y;
		vec2 g = vec2(along / 0.22, (along == f.x ? f.y : f.x) / 0.18);
		float dot_ = length(fract(g) - 0.5);
		float seen = 1.0 - smoothstep(0.008, 0.035, aa);
		float dots = (1.0 - smoothstep(0.16, 0.26, dot_)) * seen;
		c = mix(c, seedling.rgb, max(dots, (1.0 - seen) * 0.22));
		rough = mix(rough, 0.8, max(dots, (1.0 - seen) * 0.22));
	} else if (h < fl + gold_rate) {
		float n = vnoise(p * 0.35 + h * 40.0);
		c = mix(gold_b.rgb, gold_a.rgb, n * 0.7 + 0.15);
		c = mix(c, green_a.rgb, 0.25 * hash(vec2(col, row + 9.0)));
		float stripe = sin(f.y * 6.2832 / 0.25) * 0.5 + 0.5;
		c *= 1.0 - 0.06 * stripe * (1.0 - smoothstep(0.02, 0.08, aa));
		float wave = sin(dot(p, wind_dir.xz) * 0.09 - TIME * 1.3 + vnoise(p * 0.02) * 4.0);
		c *= 1.0 + 0.07 * smoothstep(0.4, 1.0, wave);
	} else if (h < fl + gold_rate + stubble_rate) {
		c = stubble.rgb * (0.9 + 0.2 * vnoise(p * 0.6));
		float piles = step(0.985, hash(floor(p / 3.0) + col));
		c = mix(c, gold_a.rgb * 0.95, piles * (1.0 - smoothstep(0.05, 0.2, aa)));
	} else {
		c = mix(green_b.rgb, green_a.rgb, vnoise(p * 0.3 + h * 20.0));
	}
	c *= 0.9 + 0.2 * vnoise(p * 0.05 + h * 9.0);
	float b = 1.0 - smoothstep(bund - 0.1, bund + 0.1, edge);
	c = mix(c, bund_col.rgb * (0.9 + 0.2 * vnoise(p * 0.8)), b);
	rough = mix(rough, 0.9, b);
	spec = mix(spec, 0.3, b);
	float field = smoothstep(field_from - 40.0, field_from + 40.0, wpos.x + vnoise(p * 0.02) * 60.0);
	vec3 grass = grass_col.rgb * (0.85 + 0.3 * vnoise(p * 0.08));
	c = mix(grass, c, field);
	rough = mix(0.95, rough, field);
	spec = mix(0.2, spec, field);
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
