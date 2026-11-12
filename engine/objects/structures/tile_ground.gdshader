shader_type spatial;
// The ground under a tile (see TileDecorations.create_ground): it reaches past the tile's footprint through its openings only,
// towards the neighbours it connects to, and frays into the table, so connected tiles share one ground; closed sides and corners
// keep it close. Its texture lies in world space, so overlapping patches of neighbours line up, and a soft contact shadow runs
// along the tile's edge.
render_mode blend_mix, depth_draw_never, cull_back;

// Half the patch's size, set per tile, in metres: how far the ground reaches through an opening from the tile's middle
instance uniform float half_size = 1.4;
// Which sides open to a neighbour, set per tile in the patch's space: +x, -x, +z, -z, 1 for open
instance uniform vec4 open_sides = vec4(1.0);
// Half the tile's footprint, in metres: the ground is fully there inside it
uniform float footprint = 1.0;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
// Metres the textures cover once
uniform float texture_size = 2.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.9;
// How far the ground reaches past closed sides, in metres
uniform float closed_reach = 0.15;
// How much the ground through an opening narrows away from the opening's middle: 0 spans the whole side (rooms), 1 a tongue
uniform float taper : hint_range(0.0, 1.0) = 0.6;
// How unevenly the patch frays into the table, as a share of the reach beyond the footprint
uniform float fray : hint_range(0.0, 1.0) = 0.5;
// Frayed patches per metre
uniform float patch_density = 1.2;
// How dark the ground gets right at the tile's edge
uniform float contact_shadow : hint_range(0.0, 1.0) = 0.55;
// How far from the tile's edge the contact shadow reaches, in metres
uniform float contact_width = 0.35;

varying vec2 local_spot;
varying vec2 world_spot;

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
	local_spot = VERTEX.xz;
	world_spot = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 from_middle = abs(local_spot);
	float reach = max(half_size - footprint, 0.001);
	// Through an opening the ground reaches its full length near the opening's middle; elsewhere it stays close
	float open_x = local_spot.x >= 0.0 ? open_sides.x : open_sides.y;
	float open_z = local_spot.y >= 0.0 ? open_sides.z : open_sides.w;
	float across_x = 1.0 - taper * smoothstep(footprint * 0.25, footprint, from_middle.y);
	float across_z = 1.0 - taper * smoothstep(footprint * 0.25, footprint, from_middle.x);
	vec2 side_reach = max(vec2(closed_reach), vec2(reach * open_x * across_x, reach * open_z * across_z));
	vec2 beyond = max(from_middle - vec2(footprint), vec2(0.0)) / side_reach;
	float frayed = length(beyond) + (patches(world_spot * patch_density) - 0.5) * fray;
	float ground = 1.0 - smoothstep(0.15, 1.0, frayed);
	float edge_distance = abs(max(from_middle.x, from_middle.y) - footprint);
	float shadow = contact_shadow * (1.0 - smoothstep(0.0, contact_width, edge_distance));
	vec2 ground_uv = world_spot / texture_size;
	ALBEDO = texture(albedo_texture, ground_uv).rgb * tint.rgb * (1.0 - shadow);
	ALPHA = clamp(ground * opacity * tint.a, 0.0, 1.0);
	ROUGHNESS = texture(roughness_texture, ground_uv).g;
	NORMAL_MAP = texture(normal_texture, ground_uv).rgb;
}
