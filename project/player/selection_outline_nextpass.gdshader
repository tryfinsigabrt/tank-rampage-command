shader_type spatial;
//render_mode depth_draw_always;
render_mode blend_mix, cull_front, depth_draw_opaque, unshaded;

uniform float outline_size = 0.03;
uniform vec4 outline_color:source_color = vec4(1.0,1.0,1.0,1.0);

void vertex() {
	VERTEX += NORMAL * outline_size;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
