shader_type canvas_item;
// The one cheap pass over every scene: a soft violet vignette, a gentle grade that
// lifts shadows toward violet and warms highlights without touching the mids (pack
// colors stay their own), and a faint grain on the 480x270 grid at 12 fps.
// One backbuffer copy, no blur, no bloom.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float vignette = 0.3;
uniform float grain = 0.012;
uniform vec3 ink : source_color = vec3(0.1137, 0.0784, 0.1412);

// An integer hash (PCG), exact at any TIME: float hashes of growing inputs lose their
// fractional bits in float32 after a minute and turn into flickering stripes.
uint pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float hash(vec2 px, float frame) {
	uint h = pcg(uint(px.x) + pcg(uint(px.y) + pcg(uint(frame))));
	return float(h & 65535u) / 65535.0;
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// Shadows lean violet, highlights lean warm, the mids are left alone.
	c += vec3(0.015, 0.0, 0.03) * (1.0 - smoothstep(0.0, 0.2, l));
	c *= mix(vec3(1.0), vec3(1.02, 1.005, 0.985), smoothstep(0.8, 1.0, l));
	c = (c - 0.4) * 1.06 + 0.4;
	// Soft vignette toward ink, never pure black.
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.75);
	float v = smoothstep(0.45, 1.1, length(d) * 1.4);
	c = mix(c, ink, clamp(v * vignette * 2.2, 0.0, 0.85));
	// Grain on game pixels, 12 changes a second.
	vec2 px = floor(SCREEN_UV * vec2(480.0, 270.0));
	// The frame counter wraps, so its inputs stay small whatever TIME is.
	float frame = mod(floor(TIME * 12.0), 64.0);
	float g = hash(px, frame) - 0.5;
	c += g * grain * 2.0;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
