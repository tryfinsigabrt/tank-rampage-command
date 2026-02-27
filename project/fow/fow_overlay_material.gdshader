shader_type spatial;
// We use 'unlit' so the fog itself doesn't receive shadows/light, saving performance
render_mode blend_mix, depth_draw_opaque, unshaded; 

uniform sampler2D fow_viewport_texture : source_color, filter_linear;
uniform float fow_range_min = 0.01;
uniform float fow_range_max = 0.99;

// You still need these to map the SubViewport over the whole world!
uniform vec2 fow_world_pos;
uniform vec2 fow_world_size = vec2(1000.0, 1000.0);

void fragment() {
    // 1. Map world position to FoW texture UV
    vec2 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
    vec2 fow_uv = (world_pos - fow_world_pos) / fow_world_size;

    // 2. Sample the FoW texture
    vec4 fow_data = texture(fow_viewport_texture, fow_uv);

    // 3. Smooth transitions (from your screenshot)
    float is_explored = smoothstep(fow_range_min, fow_range_max, fow_data.g);
    float is_visible = smoothstep(fow_range_min, fow_range_max, fow_data.r);

    // 4. Calculate visibility
    float visibility = mix(
        is_explored * 0.3, // Start with 0.0 (Unexplored), add 0.3 if explored
        1.0,               // Mix in 1.0 if visible
        is_visible
    );

    // 5. Apply to Overlay
    ALBEDO = vec3(0.0);          // The fog itself is pure black
    ALPHA = 1.0 - visibility;    // Invert the visibility to dictate transparency
}