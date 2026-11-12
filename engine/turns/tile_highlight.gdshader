shader_type spatial;
// Marks a tile with four thin glowing corner brackets, a faint halo along them and a soft glow in the middle, breathing slowly
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.84, 0.55, 1.0);
// Brighter than 1 blooms through the environment's glow
uniform float energy = 2.4;
// Distance of the brackets from the tile's edge, as a share of the tile
uniform float inset : hint_range(0.0, 0.3) = 0.07;
uniform float line_width : hint_range(0.001, 0.05) = 0.016;
// How far each bracket reaches along its sides
uniform float corner_length : hint_range(0.0, 0.5) = 0.16;
uniform float halo : hint_range(0.0, 1.0) = 0.3;
uniform float glow : hint_range(0.0, 1.0) = 0.1;
uniform float breathe_speed = 1.6;
// How far the brackets move out and in while breathing
uniform float breathe : hint_range(0.0, 0.05) = 0.012;

void fragment() {
	vec2 p = UV - 0.5;
	vec2 a = abs(p);
	float breath = 0.5 + 0.5 * sin(TIME * breathe_speed);
	float half_size = 0.5 - inset - breathe * breath;
	float square = max(a.x, a.y);
	float to_line = abs(square - half_size);
	float aa = fwidth(square);
	float line = 1.0 - smoothstep(line_width * 0.5, line_width * 0.5 + aa, to_line);
	float corner = smoothstep(half_size - corner_length - 0.02, half_size - corner_length, min(a.x, a.y));
	float glow_line = exp(-to_line * 50.0) * halo;
	float middle = (1.0 - smoothstep(0.0, half_size, length(p))) * glow;
	ALBEDO = color.rgb * energy;
	ALPHA = clamp((line + glow_line) * corner + middle, 0.0, 1.0) * mix(0.75, 1.0, breath);
}
