shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 line_color : source_color = vec4(1.0);

void vertex() {
	float depth = max(0.0, -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z);
	float minimum_radius = min(depth * 0.0015, 0.9);
	VERTEX += NORMAL * max(0.0, minimum_radius - UV.x);
}

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	ALBEDO = line_color.rgb;
	ALPHA = pow(1.0 - across, 2.0) * 0.25;
}
