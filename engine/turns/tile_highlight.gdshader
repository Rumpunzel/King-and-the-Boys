shader_type spatial;
// Soft frame on a tile: strongest at the edges, fading to the middle, slowly pulsing
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.86, 0.45, 0.45);
// Width of the frame, as a share of the tile
uniform float border : hint_range(0.0, 0.5) = 0.14;
// Opacity of the middle of the tile relative to the frame
uniform float fill : hint_range(0.0, 1.0) = 0.15;
uniform float pulse_speed = 2.5;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 to_edge = min(UV, 1.0 - UV);
	float frame = 1.0 - smoothstep(0.0, border, min(to_edge.x, to_edge.y));
	float pulse = 1.0 - pulse_strength * (0.5 + 0.5 * sin(TIME * pulse_speed));
	ALBEDO = color.rgb;
	ALPHA = color.a * mix(fill, 1.0, frame) * pulse;
}
