shader_type canvas_item;

uniform sampler2D visible_data_texture; // The current visibility (blobs)
uniform sampler2D screen_texture: hint_screen_texture, filter_nearest;

uniform float blur_amount:hint_range(0.0, 10.0, 0.1) = 1.5;
uniform bool reset;

// Isolated blur function
// samples 4 points diagonally to leverage hardware bilinear filtering
float get_blurred_vision(sampler2D tex, vec2 uv, float amount) {
	vec2 texel_size = 1.0 / vec2(textureSize(tex, 0));
	vec2 offset = texel_size * amount;

	float sample_0 = texture(tex, uv + vec2(-offset.x, -offset.y)).r;
	float sample_1 = texture(tex, uv + vec2(offset.x, -offset.y)).r;
	float sample_2 = texture(tex, uv + vec2(-offset.x, offset.y)).r;
	float sample_3 = texture(tex, uv + vec2(offset.x, offset.y)).r;

	return (sample_0 + sample_1 + sample_2 + sample_3) * 0.25;
}

// Isolated 3x3 box blur function
// samples a 9-pixel grid and averages them
float get_box_blurred_vision(sampler2D tex, vec2 uv, float amount) {
	vec2 texel_size = 1.0 / vec2(textureSize(tex, 0));
	vec2 offset = texel_size * amount;

	float sum = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 sample_uv = uv + vec2(float(x), float(y)) * offset;
			sum += texture(tex, sample_uv).r;
		}
	}

	return sum / 9.0;
}

void fragment() {
	if(!reset) {
		// 1. Get current blobs from Viewport A
		float current_visible_areas = get_box_blurred_vision(visible_data_texture, UV, blur_amount);
		
		// Store only the GREEN channel from the visible
		float explored_data = texture(screen_texture, SCREEN_UV).g;
		
		// replace darker colors by bright color, [using max()];
		// 'adding' the GREEN channel to the current visible areas
		float compiled_data_texture = max(explored_data, current_visible_areas);
		
		// Output: Red = Visible Area, Green = Explored Areas, Blue = 0
		COLOR = vec4(current_visible_areas, compiled_data_texture, 0.0, 1.0);
	}
	// Reset everything back to black
	else {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
}
