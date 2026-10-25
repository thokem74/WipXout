shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform float glow_energy : hint_range(0.0, 8.0) = 1.0;

void vertex() {
	// Face the camera while retaining each GPU particle's size and position.
	vec3 particle_scale = vec3(length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * particle_scale.x,
		INV_VIEW_MATRIX[1] * particle_scale.y,
		INV_VIEW_MATRIX[2] * particle_scale.z, MODEL_MATRIX[3]);
}

void fragment() {
	// A radial falloff makes a soft plasma bead without a texture asset.
	float radius = length(UV * 2.0 - 1.0);
	float softness = pow(max(0.0, 1.0 - radius), 2.0);
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * glow_energy;
	ALPHA = COLOR.a * softness;
}
