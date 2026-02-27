shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D fow_viewport_texture : source_color, repeat_disable, filter_linear;

uniform float fow_range_min = 0.01;
uniform float fow_range_max = 0.99;

uniform vec2 fow_world_pos;
uniform vec2 fow_world_size = vec2(1000.0, 1000.0);

uniform float explored_visibility = 0.3;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 scene_color = texture(screen_texture, SCREEN_UV).rgb;
	float depth = texture(depth_texture, SCREEN_UV).r;

	vec3 output_color = scene_color;

	if (depth < 1.0) {
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
		vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view_pos.xyz /= view_pos.w;

		vec3 world_pos = (INV_VIEW_MATRIX * vec4(view_pos.xyz, 1.0)).xyz;
		vec2 fow_uv = (world_pos.xz - fow_world_pos) / fow_world_size;
		vec4 fow_data = texture(fow_viewport_texture, fow_uv);

		float is_explored = smoothstep(fow_range_min, fow_range_max, fow_data.g);
		float is_visible = smoothstep(fow_range_min, fow_range_max, fow_data.r);
		float visibility = mix(is_explored * explored_visibility, 1.0, is_visible);
		float fog_alpha = 1.0 - visibility;

		output_color = scene_color * (1.0 - fog_alpha);
	}

	ALBEDO = output_color;
	ALPHA = 1.0;
}
