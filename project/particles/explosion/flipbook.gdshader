shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform sampler2D atlas_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform int columns : hint_range(1, 64, 1) = 4;
uniform int rows : hint_range(1, 64, 1) = 4;
uniform float animation_cycles : hint_range(0.1, 10.0, 0.1) = 1.0;

varying float particle_progress;

vec2 flipbook_uv(vec2 uv, vec2 atlas_grid, float frame_index) {
	vec2 frame_size = 1.0 / atlas_grid;
	vec2 frame = vec2(
		mod(frame_index, atlas_grid.x),
		floor(frame_index / atlas_grid.x)
	);
	return fract(uv) * frame_size + frame * frame_size;
}

void vertex() {
	particle_progress = clamp(INSTANCE_CUSTOM.y, 0.0, 0.999999);

	vec3 model_scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * model_scale.x, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * model_scale.y, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * model_scale.z, 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec2 atlas_grid = vec2(float(columns), float(rows));
	float frame_count = atlas_grid.x * atlas_grid.y;
	float frame_index = floor(particle_progress * animation_cycles * frame_count);
	frame_index = mod(frame_index, frame_count);

	vec4 flipbook_color = texture(atlas_texture, flipbook_uv(UV, atlas_grid, frame_index));
	ALBEDO = flipbook_color.rgb * COLOR.rgb;
	ALPHA = flipbook_color.a * COLOR.a;
}
