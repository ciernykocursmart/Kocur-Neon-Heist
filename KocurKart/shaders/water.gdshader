shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec3 deep : source_color = vec3(0.05, 0.32, 0.5);
uniform vec3 shallow : source_color = vec3(0.16, 0.62, 0.72);
uniform vec3 foam : source_color = vec3(0.92, 0.97, 1.0);
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
	VERTEX.y += sin(wpos.x * 0.15 + TIME * 1.2) * 0.12 + cos(wpos.z * 0.12 + TIME) * 0.12;
}

void fragment() {
	vec2 p = wpos.xz * 0.08;
	float n = vnoise(p + vec2(TIME * 0.05, TIME * 0.03)) * 0.6 + vnoise(p * 3.0 - vec2(TIME * 0.08, 0.0)) * 0.4;
	vec3 col = mix(deep, shallow, n);
	float f = smoothstep(0.78, 0.86, vnoise(wpos.xz * 0.35 + vec2(TIME * 0.2, -TIME * 0.1)));
	col = mix(col, foam, f * 0.5);
	ALBEDO = col;
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
