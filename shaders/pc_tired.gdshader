shader_type canvas_item;

uniform float blur : hint_range(0.0, 1.0) = 0.0;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * (1.5 + blur * 6.0);
	vec4 c = base * 0.2;
	c += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.1;
	c += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.1;
	c += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.1;
	c += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.1;
	c += texture(TEXTURE, UV + px) * 0.1;
	c += texture(TEXTURE, UV - px) * 0.1;
	c += texture(TEXTURE, UV + vec2(px.x, -px.y)) * 0.1;
	c += texture(TEXTURE, UV + vec2(-px.x, px.y)) * 0.1;
	COLOR = mix(base, c, clamp(blur, 0.0, 1.0)) * tint;
}
