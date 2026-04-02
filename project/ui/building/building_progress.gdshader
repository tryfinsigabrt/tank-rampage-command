shader_type canvas_item;

uniform float progress:hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float darkness:hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float opacity:hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);

	if(UV.y >= progress) {
		float grayscale = (1.0 - darkness) * (original_color.r + original_color.g + original_color.b) / 3.;
		COLOR = vec4(vec3(grayscale), opacity * original_color.a);
	}
	else {
		COLOR = original_color;
	}
}
