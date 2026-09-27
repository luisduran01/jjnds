shader_type spatial;
render_mode cull_disabled;
uniform sampler2D damage_map;
uniform float damage_strength = 1.0;
void fragment() {
	vec3 tint = COLOR.rgb;
	if (tint.r > tint.g * 2.0 && tint.g < 0.2) {
		tint = vec3(0.055, 0.26, 0.65);
	} else if (tint.b > tint.r * 1.3) {
		tint = vec3(0.045, 0.055, 0.085);
	}
	vec3 trauma = texture(damage_map, UV).rgb;
	float skin = smoothstep(0.16, 0.55, tint.r) * (1.0 - smoothstep(0.30, 0.72, tint.b));
	vec3 bruise = mix(vec3(0.20, 0.025, 0.04), vec3(0.38, 0.035, 0.015), trauma.g);
	ALBEDO = mix(tint, bruise, clamp(trauma.r * skin * damage_strength, 0.0, 0.78));
	ROUGHNESS = mix(0.72, 0.45, trauma.b * skin);
	// B is an independently accumulated height/swelling channel. This tangent-space
	// perturbation is cheaper and safer than vertex displacement on the current mesh.
	NORMAL_MAP = vec3(0.5 + trauma.b * skin * 0.16, 0.5 + trauma.b * skin * 0.10, 1.0);
	NORMAL_MAP_DEPTH = trauma.b * skin * 0.42;
}
