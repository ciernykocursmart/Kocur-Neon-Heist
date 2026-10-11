shader_type spatial;
// Curbs: UV.y = progress in metres. COLOR.r = corner amount (0 straight, 1 corner).
uniform vec3 color_a : source_color = vec3(0.86, 0.12, 0.14);
uniform vec3 color_b : source_color = vec3(0.96, 0.96, 0.94);
uniform vec3 plain : source_color = vec3(0.62, 0.62, 0.6);
uniform float emission = 0.0;

void fragment() {
	float stripe = step(0.5, fract(UV.y / 1.6));
	vec3 striped = mix(color_a, color_b, stripe);
	vec3 col = mix(plain, striped, COLOR.r);
	ALBEDO = col;
	ROUGHNESS = 0.7;
	EMISSION = striped * COLOR.r * emission;
}
