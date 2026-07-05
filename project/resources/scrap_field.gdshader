shader_type spatial;
render_mode unshaded, cull_disabled;

varying vec3 local_position;

uniform vec4 edge_color : source_color = vec4(0.42, 0.16, 0.16, 0.85);
uniform vec4 center_color : source_color = vec4(0.72, 0.34, 0.24, 0.85);
uniform vec3 outer_fade_color : source_color = vec3(0.16, 0.10, 0.09);
uniform vec2 field_half_extents = vec2(5.0, 5.0);
uniform float edge_fade_width : hint_range(0.01, 0.5) = 0.15;
uniform float center_blend_width : hint_range(0.01, 1.0) = 0.45;
uniform vec3 crack_color : source_color = vec3(0.08, 0.05, 0.04);
uniform float crack_scale : hint_range(0.01, 2.0) = 0.35;
uniform float crack_strength : hint_range(0.0, 1.0) = 0.65;
uniform vec3 scrap_color : source_color = vec3(0.45, 0.48, 0.50);
uniform float scrap_scale : hint_range(0.01, 2.0) = 0.22;
uniform float scrap_strength : hint_range(0.0, 1.0) = 0.65;
uniform float remaining_fraction : hint_range(0.0, 1.0) = 1.0;


float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash12(i + vec2(0.0, 0.0));
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 local_xz = local_position.xz;
	vec2 normalized = abs(local_xz) / field_half_extents;
	float edge_factor = max(normalized.x, normalized.y);
	float fade = 1.0 - smoothstep(1.0 - edge_fade_width, 1.0, edge_factor);
	float center_mask = 1.0 - smoothstep(0.0, center_blend_width, edge_factor);
	vec3 albedo = mix(edge_color.rgb, center_color.rgb, center_mask);
	albedo = mix(outer_fade_color, albedo, fade);

	float crack_noise = noise2(local_xz * crack_scale);
	float crack_mask = smoothstep(0.82, 0.92, crack_noise);
	albedo = mix(albedo, crack_color, crack_mask * crack_strength);
	
	float scrap_noise = noise2(local_xz * scrap_scale + vec2(20.0, 20.0));
	float scrap_mask = smoothstep(0.72, 0.9, scrap_noise);
	scrap_mask *= fade;
	scrap_mask *= remaining_fraction;
	albedo = mix(albedo, scrap_color, scrap_mask * scrap_strength);
	
	float roughness = mix(1.0, 0.65, scrap_mask * scrap_strength);
	ROUGHNESS = roughness;
	ALBEDO = albedo;
	SPECULAR = 0.05;
}
