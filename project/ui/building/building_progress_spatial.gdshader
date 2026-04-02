shader_type spatial;
render_mode unshaded, cull_disabled, diffuse_lambert, depth_draw_opaque;

instance uniform float progress:hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float darkness:hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float opacity:hint_range(0.0, 1.0, 0.01) = 1.0;
uniform sampler2D image : source_color;

void fragment() {
	vec4 original_color = texture(image, UV);

	if(UV.y >= progress) {
		float grayscale = (1.0 - darkness) * (original_color.r + original_color.g + original_color.b) / 3.;
		ALBEDO = vec3(grayscale);
		ALPHA = original_color.a * opacity;
	}
	else {
		ALBEDO = original_color.rgb;
		ALPHA = original_color.a;
	}
}
