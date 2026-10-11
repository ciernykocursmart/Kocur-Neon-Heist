shader_type spatial;
// Props, karts and landmarks: albedo from vertex colour (x MultiMesh instance
// colour). Colours are authored in sRGB, so convert to linear here.
uniform float roughness_value = 0.8;
uniform float emission_strength = 0.0;

void fragment() {
	vec3 c = pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));
	ALBEDO = c;
	ROUGHNESS = roughness_value;
	EMISSION = c * emission_strength * COLOR.a;
}
