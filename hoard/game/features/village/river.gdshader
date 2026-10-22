shader_type canvas_item;
render_mode blend_add;
// The river at night: crisp pixel ripples that drift downstream on two scrolling sines, two
// slow highlight bands, and a shimmering vertical mirror under every neon sign and lamp.

uniform vec2 size = vec2(992.0, 48.0);
uniform vec4 tint : source_color = vec4(0.45, 0.62, 1.0, 1.0);
uniform float refl_x[12];
uniform vec4 refl_col[12] : source_color;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 p = floor(UV * size);
	float t = TIME;
	float drift = t * 7.0;
	float row = p.y;
	float ph = hash(row) * 6.2831;
	// Ripples: short dashes on every other row, drifting downstream (east).
	float s1 = sin((p.x - drift) * 0.13 + ph + sin(t * 0.9 + row * 0.7) * 1.3);
	float s2 = sin((p.x - drift * 1.6) * 0.041 + row * 0.5 - t * 0.6);
	float dash = step(0.9, s1) * step(0.15, s2) * step(0.5, mod(row, 2.0));
	// Two slow highlight bands that breathe across the width.
	float band1 = (1.0 - smoothstep(0.0, 1.5, abs(row - (size.y * 0.3 + sin(t * 0.35) * 2.0)))) * (0.5 + 0.5 * sin(p.x * 0.02 - t * 0.5));
	float band2 = (1.0 - smoothstep(0.0, 1.0, abs(row - (size.y * 0.72 + sin(t * 0.27 + 1.0) * 2.0)))) * (0.5 + 0.5 * sin(p.x * 0.031 + t * 0.4 + 2.0));
	float bands = floor((band1 * 0.5 + band2 * 0.4) * 4.0) / 4.0;
	vec3 col = tint.rgb * (dash * 0.32 + bands * 0.14);
	// Mirrors: a wobbling column of dashes under each light, fading toward the far bank.
	for (int i = 0; i < 12; i++) {
		float rx = refl_x[i];
		if (rx < -100.0) {
			continue;
		}
		float wob = sin(row * 0.9 + t * 3.0 + rx) * 1.5 + sin(row * 0.31 - t * 1.7) * 1.0;
		float width = 3.0 + 2.5 * sin(row * 1.3 + t * 2.2 + rx * 0.1);
		float near = 1.0 - row / size.y;
		near = 1.0 - near * 0.65;
		float on = step(abs(p.x - rx - floor(wob)), width) * step(0.3, sin(row * 1.7 - t * 4.0 + rx));
		col += refl_col[i].rgb * on * 0.38 * near;
	}
	COLOR = vec4(col, 1.0);
}
