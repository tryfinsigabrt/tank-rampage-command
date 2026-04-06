shader_type spatial;
//render_mode depth_draw_always;
//render_mode blend_mix, cull_front, depth_draw_opaque, unshaded;
//render_mode blend_mix, cull_front, depth_test_disabled, unshaded;

// True root cause was a render_priority issue. Set FOW to 126 and outline to 127
// to be sure that the outline renders before the fow screen texture overlay
// We don't need a transparent outline so keep it opaque
//render_mode blend_mix, cull_front, depth_test_default, depth_draw_never, unshaded;
render_mode cull_front, depth_test_default, depth_draw_never, unshaded;

uniform float outline_size = 0.03;
uniform vec4 outline_color:source_color = vec4(1.0,1.0,1.0,1.0);

void vertex() {
	VERTEX += NORMAL * outline_size;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	//ALPHA = outline_color.a;
}
