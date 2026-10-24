shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 line_color : source_color = vec4(1.0);
uniform float energy = 1.5;

void vertex() {
	// Preserve subpixel city lines without drawing a full-screen glow layer.
	// UV.x stores the ribbon's authored half-width; normals point out from its centre.
	float depth = max(0.0, -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z);
	float minimum_radius = min(depth * 0.00065, 0.55);
	VERTEX += NORMAL * max(0.0, minimum_radius - UV.x);
}

void fragment() {
	ALBEDO = mix(line_color.rgb, vec3(1.0), clamp(energy - 1.0, 0.0, 1.0) * 0.22);
	EMISSION = line_color.rgb * energy;
}
