shader_type spatial;
// Procedural road surface. UV.x = lateral offset / half width (-1..1),
// UV.y = progress in metres, UV2.x = half width in metres.

uniform vec3 base_color : source_color = vec3(0.32, 0.31, 0.33);
uniform vec3 base_color2 : source_color = vec3(0.24, 0.23, 0.25);
uniform vec3 line_color : source_color = vec3(0.95, 0.95, 0.9);
uniform float line_emission = 0.0;
uniform int pattern = 0; // 0 asphalt, 1 planks, 2 cobbles, 3 dirt, 4 neon
uniform float edge_lines = 1.0;
uniform float center_dash = 0.0;
uniform float start_line = 1.0;
uniform float roughness_value = 0.85;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 m = vec2(UV.x * UV2.x, UV.y);
	float n = vnoise(m * 1.7) * 0.55 + vnoise(m * 7.0) * 0.3 + hash(floor(m * 24.0)) * 0.15;
	vec3 col = mix(base_color2, base_color, n);
	float lines = 0.0;
	if (pattern == 1) {
		float board = floor(m.y / 0.55);
		float tint = hash(vec2(board, 3.1));
		col = mix(base_color2, base_color, 0.35 + 0.65 * tint) * (0.9 + 0.2 * vnoise(vec2(m.x * 0.4, m.y * 9.0)));
		float seam = step(fract(m.y / 0.55), 0.07);
		col *= 1.0 - 0.55 * seam;
		float joint = step(abs(fract((m.x + hash(vec2(board, 1.0)) * 4.0) / 4.0) - 0.5), 0.012);
		col *= 1.0 - 0.4 * joint;
	} else if (pattern == 2) {
		vec2 c = m * vec2(1.4, 1.8);
		c.x += step(1.0, mod(floor(c.y), 2.0)) * 0.5;
		vec2 f = fract(c);
		float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		float tint = hash(floor(c));
		col = mix(base_color2, base_color, 0.3 + 0.7 * tint);
		col *= mix(0.55, 1.0, smoothstep(0.02, 0.12, edge));
	} else if (pattern == 3) {
		float big = vnoise(m * 0.35);
		col = mix(base_color2, base_color, n * 0.6 + big * 0.4);
		float ruts = smoothstep(0.6, 0.0, abs(abs(UV.x) - 0.45) * UV2.x);
		col *= 1.0 - 0.15 * ruts;
	} else if (pattern == 4) {
		float grid = step(fract(m.y / 4.0), 0.03) + step(abs(fract(m.x / 3.0) - 0.5), 0.015);
		col = mix(col, line_color * 0.5, clamp(grid, 0.0, 1.0) * 0.35);
	}
	float ax = abs(UV.x);
	if (edge_lines > 0.5) {
		lines += step(0.90, ax) * step(ax, 0.95);
	}
	if (center_dash > 0.5) {
		lines += step(abs(m.x), 0.12) * step(fract(m.y / 7.0), 0.45);
	}
	lines = clamp(lines, 0.0, 1.0);
	col = mix(col, line_color, lines);
	if (start_line > 0.5 && m.y >= 0.0 && m.y < 2.0) {
		float chk = mod(floor(m.x / 0.8) + floor(m.y / 0.8), 2.0);
		col = mix(vec3(0.06), vec3(0.97), chk);
		lines = 0.0;
	}
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	EMISSION = line_color * lines * line_emission;
}
