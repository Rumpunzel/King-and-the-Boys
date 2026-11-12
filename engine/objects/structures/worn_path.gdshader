shader_type spatial;
// A worn path on a tile's floor (see TileDecorations.create_paths): a strip from the tile's middle (its local origin) along +z
// to the edge, with a round end in the middle so paths meeting there merge. Its ground is a tiling texture set (e.g. sand), laid
// in the strip's own space so it stays put as the tile lifts and turns; noise frays its edges and thins it in patches.
render_mode blend_mix, depth_draw_never, cull_back;

// Half the path's width, in metres of the strip's space, set per path
instance uniform float half_width = 0.4;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
// Metres the textures cover once
uniform float texture_size = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.9;
// How far into the path its frayed edge reaches, as a share of the half width
uniform float edge_softness : hint_range(0.0, 1.0) = 0.45;
// Worn patches per metre
uniform float patch_density = 2.5;

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

void vertex() {
	spot = VERTEX.xz;
}

void fragment() {
	// Distance from the path's spine, rounded around the middle
	float from_spine = spot.y < 0.0 ? length(spot) : abs(spot.x);
	float frayed = from_spine / half_width + (patches(spot * patch_density * 3.0) - 0.5) * edge_softness;
	float edge = 1.0 - smoothstep(1.0 - edge_softness, 1.0, frayed);
	float worn = patches(spot * patch_density);
	vec2 ground_uv = spot / texture_size;
	ALBEDO = texture(albedo_texture, ground_uv).rgb * tint.rgb;
	ALPHA = clamp(edge * opacity * tint.a * (0.55 + 0.6 * worn), 0.0, 1.0);
	ROUGHNESS = texture(roughness_texture, ground_uv).g;
	NORMAL_MAP = texture(normal_texture, ground_uv).rgb;
}
