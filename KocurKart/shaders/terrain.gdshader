shader_type spatial;
// World-space ground: grass, sand, snow, rock. Vertex COLOR tints the result.
uniform vec3 color_a : source_color = vec3(0.36, 0.62, 0.25);
uniform vec3 color_b : source_color = vec3(0.27, 0.5, 0.2);
uniform vec3 speck : source_color = vec3(0.95, 0.9, 0.5);
uniform float speck_amount = 0.04;
uniform float scale = 0.25;
uniform float roughness_value = 0.95;
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * scale;
	float n = vnoise(p) * 0.6 + vnoise(p * 4.3) * 0.3 + vnoise(p * 17.0) * 0.1;
	vec3 col = mix(color_b, color_a, n);
	float s = step(1.0 - speck_amount, hash(floor(wpos.xz * 2.5)));
	col = mix(col, speck, s * 0.8);
	ALBEDO = col * pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = roughness_value;
}
