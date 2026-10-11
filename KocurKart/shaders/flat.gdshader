shader_type spatial;
// Props: albedo from vertex colour (x instance colour for MultiMesh).
uniform float roughness_value = 0.8;
uniform float emission_strength = 0.0;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness_value;
	EMISSION = COLOR.rgb * emission_strength * COLOR.a;
}
