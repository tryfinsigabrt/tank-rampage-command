shader_type spatial;

group_uniforms Aledo;
uniform sampler2D albedo_tex: repeat_enable, filter_linear;
uniform vec2 albedo_tiling = vec2(1.,1.);
uniform vec3 tint: source_color = vec3(0.,0.,1.);

uniform float roughness: hint_range(0.0, 1.0, 0.1) = 0.01;

group_uniforms Normal_1;
uniform sampler2D normal_map_tex : repeat_enable, filter_linear;
uniform vec2 normal_tiling = vec2(1.,1.);
uniform vec2 direction1 = vec2(1.,0.);
uniform float speed: hint_range(0.,1.0,.01) = 0.1;

group_uniforms Normal_2;
uniform sampler2D normal_map_tex_2 : repeat_enable, filter_linear;
uniform vec2 normal_tiling_2 = vec2(1.,1.);
uniform vec2 direction2 = vec2(.0,1.);
uniform float speed2: hint_range(0.,1.0,.01) = 0.1;

void fragment() {
	vec2 offset1 = UV * normal_tiling + direction1 * speed * TIME;
	vec2 offset2 = UV * normal_tiling_2 + direction2 * speed2 * TIME;

	vec3 normal = texture(normal_map_tex, offset1).rgb;
	vec3 normal2 = texture(normal_map_tex_2, offset2).rgb;

	vec3 final_normal = mix(normal, normal2, 0.5);
	
	vec3 color = texture(albedo_tex, UV * albedo_tiling).rgb * tint;
	
	ALBEDO = color;
	METALLIC = 0.;
	ROUGHNESS = roughness;
	NORMAL_MAP = final_normal;
}
