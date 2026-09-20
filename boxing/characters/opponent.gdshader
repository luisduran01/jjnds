shader_type spatial;
render_mode cull_disabled;
void fragment() {
	vec3 tint = COLOR.rgb;
	if (tint.r > tint.g * 2.0 && tint.g < 0.2) {
		tint = vec3(0.055, 0.26, 0.65);
	} else if (tint.b > tint.r * 1.3) {
		tint = vec3(0.045, 0.055, 0.085);
	}
	ALBEDO = tint;
	ROUGHNESS = 0.72;
}
