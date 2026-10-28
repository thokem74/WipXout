shader_type canvas_item;
uniform float boost_amount = 0.0;
uniform float impact_amount = 0.0;
void fragment() {
	// Keep the road, minimap, and touch regions free of full-screen effects.
	float edges = smoothstep(0.68, 1.0, abs(UV.x * 2.0 - 1.0));
	float band = smoothstep(0.12, 0.22, UV.y) * (1.0 - smoothstep(0.56, 0.67, UV.y));
	float streak = pow(max(0.0, sin(UV.y * 180.0 - TIME * 40.0 + UV.x * 12.0)), 18.0);
	float speed_alpha = edges * band * streak * boost_amount * 0.65;
	float hit_alpha = edges * band * impact_amount * 0.32;
	COLOR = vec4(mix(vec3(0.1, 0.7, 1.0), vec3(1.0, 0.15, 0.3), impact_amount), max(speed_alpha, hit_alpha));
}
