shader_type canvas_item;

uniform vec2 polygon_points[8];
uniform float edge_fade_width : hint_range(0.001, 0.5) = 0.15;

float distance_to_segment(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float ab_len_sq = dot(ab, ab);

	float t = clamp(dot(p - a, ab) / ab_len_sq, 0.0, 1.0);
	vec2 closest = a + ab * t;
	return distance(p, closest);
}

void fragment() {
	float min_edge_distance = 1000000.0;
	for (int i = 0; i < 8; i++) {
		vec2 a = polygon_points[i];
		vec2 b = polygon_points[(i + 1) % 8];
		min_edge_distance = min(min_edge_distance, distance_to_segment(UV, a, b));
	}

	float fade = smoothstep(0.0, edge_fade_width, min_edge_distance);
	COLOR = vec4(vec3(fade), 1.0);
}
