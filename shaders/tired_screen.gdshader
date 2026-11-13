shader_type canvas_item;

uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform float blink : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 q = UV - vec2(0.5);
	q.x *= 1.25;
	float d = length(q);
	float edge = smoothstep(0.5 - 0.3 * vignette - 0.15 * blink, 0.82, d) * vignette;
	float lids = smoothstep(0.5 - 0.42 * blink, 0.5, abs(UV.y - 0.5)) * blink;
	float a = clamp(edge * 0.85 + lids * 0.85 + blink * 0.18 + vignette * 0.1, 0.0, 0.95);
	COLOR = vec4(0.06, 0.04, 0.08, a);
}
