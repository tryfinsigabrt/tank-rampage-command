shader_type spatial;
render_mode unshaded, cull_disabled;

varying vec3 local_position;

uniform vec4 edge_color : source_color = vec4(0.42, 0.16, 0.16, 0.85);
uniform vec4 center_color : source_color = vec4(0.72, 0.34, 0.24, 0.85);
uniform vec3 outer_fade_color : source_color = vec3(0.16, 0.10, 0.09);
uniform vec2 field_half_extents = vec2(5.0, 5.0);
uniform float center_blend_width : hint_range(0.01, 1.0) = 0.45;
uniform sampler2D fade_mask_texture : source_color, repeat_disable, filter_linear;
uniform vec3 crack_color : source_color = vec3(0.08, 0.05, 0.04);
uniform sampler2D crack_mask_texture : source_color, repeat_enable, filter_linear;
uniform float crack_strength : hint_range(0.0, 1.0) = 0.65;
uniform vec3 scrap_color : source_color = vec3(0.45, 0.48, 0.50);
uniform sampler2D scrap_mask_texture : source_color, repeat_enable, filter_linear;
uniform float scrap_strength : hint_range(0.0, 1.0) = 0.65;
uniform float remaining_fraction : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 local_xz = local_position.xz;
	vec2 normalized = abs(local_xz) / field_half_extents;
	float edge_factor = max(normalized.x, normalized.y);
	float fade = texture(fade_mask_texture, UV).r;
	float center_mask = 1.0 - smoothstep(0.0, center_blend_width, edge_factor);
	vec3 albedo = mix(edge_color.rgb, center_color.rgb, center_mask);
	albedo = mix(outer_fade_color, albedo, fade);

	float crack_noise = texture(crack_mask_texture, UV).r;
	float crack_mask = smoothstep(0.78, 0.92, 1.0 - crack_noise);
	albedo = mix(albedo, crack_color, crack_mask * crack_strength);
	
	float scrap_noise = texture(scrap_mask_texture, UV).r;
	float scrap_mask = smoothstep(0.30, 0.9, scrap_noise);
	scrap_mask *= fade;
	scrap_mask *= (1.0 - crack_mask);
	scrap_mask *= remaining_fraction;
	albedo = mix(albedo, scrap_color, scrap_mask * scrap_strength);
	
	float roughness = mix(1.0, 0.65, scrap_mask * scrap_strength);
	ROUGHNESS = roughness;
	ALBEDO = albedo;
	SPECULAR = 0.05;
	ALPHA = fade;
}
