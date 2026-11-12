shader_type spatial;
// A worn sandy path on a tile's floor (see TileDecorations.create_paths): a strip from the tile's middle (its local origin)
// along +z to the edge, with a round end in the middle so paths meeting there merge. Sand grains and patches come from noise in
// the strip's own space, so they stay put as the tile lifts and turns; the grains catch the light through the normal.
render_mode blend_mix, depth_draw_never, cull_back;

// Half the path's width, in metres of the strip's space, set per path
instance uniform float half_width = 0.4;
uniform vec4 sand_color : source_color = vec4(0.72, 0.58, 0.38, 1.0);
uniform vec4 dark_sand_color : source_color = vec4(0.42, 0.32, 0.2, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.9;
// How far into the path its frayed edge reaches, as a share of the half width
uniform float edge_softness : hint_range(0.0, 1.0) = 0.45;
// Grains per metre
uniform float grain_density = 90.0;
// Sand patches per metre
uniform float patch_density = 2.5;
uniform float grain_bump : hint_range(0.1, 4.0) = 1.2;

varying vec2 spot;

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 within = fract(point);
	vec2 blend = within * within * (3.0 - 2.0 * within);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

float patches(vec2 point) {
	return value_noise(point) * 0.6 + value_noise(point * 2.3 + 17.0) * 0.3 + value_noise(point * 5.1 + 41.0) * 0.1;
}

float grains(vec2 point) {
	return value_noise(point * grain_density) * 0.7 + value_noise(point * grain_density * 0.37 + 7.0) * 0.3;
}

void vertex() {
	spot = VERTEX.xz;
}

void fragment() {
	// Distance from the path's spine, rounded around the middle
	float from_spine = spot.y < 0.0 ? length(spot) : abs(spot.x);
	float frayed = from_spine / half_width + (patches(spot * patch_density * 3.0) - 0.5) * edge_softness;
	float edge = 1.0 - smoothstep(1.0 - edge_softness, 1.0, frayed);
	float sand = patches(spot * patch_density);
	float grain = grains(spot);
	ALBEDO = mix(dark_sand_color.rgb, sand_color.rgb, clamp(sand * 1.3 - 0.15, 0.0, 1.0)) * (0.8 + 0.4 * grain);
	ALPHA = clamp(edge * opacity * (0.55 + 0.6 * sand), 0.0, 1.0);
	ROUGHNESS = 1.0;
	// The grains' slope, for the light to catch
	float step_size = 0.25 / grain_density;
	float slope_x = grains(spot + vec2(step_size, 0.0)) - grain;
	float slope_y = grains(spot + vec2(0.0, step_size)) - grain;
	NORMAL_MAP = normalize(vec3(-slope_x, -slope_y, 0.25 / grain_bump)) * 0.5 + 0.5;
}
