shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;
uniform float darken : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE * blur_amount;

	// 9-sample box blur
	vec4 color = vec4(0.0);
	color += textureLod(screen_texture, SCREEN_UV + vec2(-ps.x, -ps.y), 0.0);
	color += textureLod(screen_texture, SCREEN_UV + vec2(0.0, -ps.y), 0.0);
	color += textureLod(screen_texture, SCREEN_UV + vec2(ps.x, -ps.y), 0.0);
	color += textureLod(screen_texture, SCREEN_UV + vec2(-ps.x, 0.0), 0.0);
	color += textureLod(screen_texture, SCREEN_UV, 0.0);
	color += textureLod(screen_texture, SCREEN_UV + vec2(ps.x, 0.0), 0.0);
	color += textureLod(screen_texture, SCREEN_UV + vec2(-ps.x, ps.y), 0.0);
	color += textureLod(screen_texture, SCREEN_UV + vec2(0.0, ps.y), 0.0);
	color += textureLod(screen_texture, SCREEN_UV + vec2(ps.x, ps.y), 0.0);
	color /= 9.0;

	color.rgb *= (1.0 - darken);
	COLOR = color;
}
