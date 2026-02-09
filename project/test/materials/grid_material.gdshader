shader_type spatial;

uniform float cell_size = 10.0;
uniform float line_width = 0.001;
uniform float axis_width = 0.02;
uniform float fade_start = 500.0;
uniform float fade_end = 2000.0;
uniform float fade_power = 0.5;

uniform vec3 grid_color:source_color = vec3(0.75);
uniform vec3 line_color:source_color = vec3(0.15);
uniform vec3 axis_color:source_color = vec3(0.9);

varying vec3 v_world_pos;

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 world_pos = v_world_pos;
	
	// Grid coordinates
	float gx = abs(fract(world_pos.x / cell_size) - 0.5);
	float gz = abs(fract(world_pos.z / cell_size) - 0.5);

    float dist = length(CAMERA_POSITION_WORLD - world_pos);
    float line_scale = clamp(dist / fade_end, 1.0, cell_size);

	// Pixel footprint in grid space
	float w = max(fwidth(world_pos.x / cell_size), fwidth(world_pos.z / cell_size));

    float lw = max(line_width * line_scale, w * 0.5);

	// Smooth line mask
	float line_x = 1.0 - smoothstep(lw - w, lw + w, gx);
	float line_z = 1.0 - smoothstep(lw - w, lw + w, gz);
	float line = max(line_x, line_z);

    // Axis lines (X and Z)
    float axis_x = step(abs(world_pos.x), axis_width);
    float axis_z = step(abs(world_pos.z), axis_width);

	float fade = smoothstep(fade_end, fade_start, dist);
	fade = pow(fade, fade_power);

    vec3 color = grid_color;

    if (line > 0.0) {
        color = line_color;
    }

    if (axis_x > 0.0 || axis_z > 0.0) {
        color = axis_color;
    }

    ALBEDO = mix(grid_color, color, fade);
}