shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float visible = step(0.01, original.a);
	COLOR = mix(original, vec4(flash_color.rgb, original.a), flash_amount * visible);
}
