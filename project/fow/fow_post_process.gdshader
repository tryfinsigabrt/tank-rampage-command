// New approach that avoids sampling the depth buffer which doesn't work well on web (GLES3)
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D fow_viewport_texture : source_color, repeat_disable, filter_linear;

uniform float fow_range_min = 0.01;
uniform float fow_range_max = 0.99;

uniform vec2 fow_world_pos;
uniform vec2 fow_world_size = vec2(1000.0, 1000.0);

uniform float explored_visibility = 0.3;
// Set domainant/average elevation
uniform float ground_y = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 scene_color = texture(screen_texture, SCREEN_UV).rgb;

	// Reconstruct camera ray from screen UV using camera matrices
	vec2 ndc_xy = SCREEN_UV * 2.0 - 1.0;
	vec4 view_far = INV_PROJECTION_MATRIX * vec4(ndc_xy, 1.0, 1.0);
	view_far.xyz /= view_far.w;

	vec3 cam_origin = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 ray_dir = normalize((INV_VIEW_MATRIX * vec4(normalize(view_far.xyz), 0.0)).xyz);

	// Intersect ray with ground plane (y = ground_y)
	vec3 output_color = scene_color;
	float denom = ray_dir.y;

	if (abs(denom) > 0.0001) {
		float t = (ground_y - cam_origin.y) / denom;
		if (t > 0.0) {
			vec3 world_pos = cam_origin + ray_dir * t;
			vec2 fow_uv = (world_pos.xz - fow_world_pos) / fow_world_size;
			vec4 fow_data = texture(fow_viewport_texture, fow_uv);

			float is_explored = smoothstep(fow_range_min, fow_range_max, fow_data.g);
			float is_visible = smoothstep(fow_range_min, fow_range_max, fow_data.r);
			float visibility = mix(is_explored * explored_visibility, 1.0, is_visible);

			output_color = scene_color * visibility;
		}
	}

	ALBEDO = output_color;
	ALPHA = 1.0;
}
