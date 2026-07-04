shader_type spatial;

uniform vec3 albedo_color: source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 emissive_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float base_intensity : hint_range(0.0, 10.0) = 1.0;
uniform float max_intensity : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	// pulse the emissive intensity from base to max wrapping sin from [0,1]
	float pulse = (sin(TIME * pulse_speed) * 0.5) + 0.5;
	
	// Calculate final emission strength
	float current_emission = base_intensity + (pulse * max_intensity);
	
	// Apply to the built-in EMISSION channel
	EMISSION = emissive_color * current_emission;
	ALBEDO = albedo_color.rgb;
}