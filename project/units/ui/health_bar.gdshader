shader_type spatial;
render_mode unshaded, cull_disabled;

instance uniform float health_fraction : hint_range(0.0, 1.0) = 1.0;
uniform vec3 health_color : source_color = vec3(1.0, 0.0, 0.0);
uniform vec3 bg_color : source_color = vec3(0.0, 0.0, 0.0);

void fragment() {
    // Basic horizontal bar logic
    if (UV.x < health_fraction) {
        ALBEDO = health_color;
    } else {
        ALBEDO = bg_color;
    }
}