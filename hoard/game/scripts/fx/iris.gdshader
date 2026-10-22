shader_type canvas_item;
// The room-to-room iris: a pixel circle around `center` (game pixels) with a
// Bayer-dithered rim. radius 0 = closed (all night), large = open.

uniform vec2 center = vec2(240.0, 135.0);
uniform float radius = 600.0;
uniform float rim = 7.0;
uniform vec4 night : source_color = vec4(0.0706, 0.0471, 0.0941, 1.0);

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 px = floor(SCREEN_UV * vec2(480.0, 270.0));
	float d = length(px + 0.5 - center);
	int i = int(mod(px.x, 4.0)) + int(mod(px.y, 4.0)) * 4;
	float b = (BAYER[i] + 0.5) / 16.0;
	float over = (d - radius) / rim;
	float cover = over > b ? 1.0 : 0.0;
	COLOR = vec4(night.rgb, cover * night.a);
}
