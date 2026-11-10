// Repaints a gear atlas' highlights in a character's colours: its primary colour (the packs' slate or steel blue) and its
// secondary one (their gold). Atlases with colour masks (Fantasy Hero) find them by mask, others by their key colours.
// The colours are per mesh (instance uniforms, set by ModularModel.set_gear_colors); a transparent colour keeps the atlas'
shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
// Fantasy Hero's Mask_01: cyan marks the primary colour, magenta and blue the secondary one
uniform sampler2D mask_texture : hint_default_black, filter_nearest;
uniform bool use_mask = false;
// The atlas' own colours: found by them without a mask, and the shading of the repainted pixels is kept relative to them
uniform vec3 primary_key : source_color = vec3(0.29, 0.4, 0.49);
uniform vec3 secondary_key : source_color = vec3(0.75, 0.61, 0.32);
// How far a pixel may stray from a key colour and still count, without a mask
uniform float key_tolerance : hint_range(0.0, 0.5) = 0.06;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;

instance uniform vec4 primary_color : source_color = vec4(0.0);
instance uniform vec4 secondary_color : source_color = vec4(0.0);

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

float key_weight(vec3 color, vec3 key) {
	return 1.0 - smoothstep(key_tolerance * 0.5, key_tolerance, distance(color, key));
}

// [param color] repainted in [param target], keeping its brightness relative to [param key]
vec3 repaint(vec3 color, vec3 key, vec3 target) {
	return clamp(target * luminance(color) / max(luminance(key), 0.001), 0.0, 1.0);
}

void fragment() {
	vec3 color = texture(albedo_texture, UV).rgb;
	float primary = 0.0;
	float secondary = 0.0;
	if (use_mask) {
		vec3 mask = texture(mask_texture, UV).rgb;
		primary = mask.g * mask.b * (1.0 - mask.r);
		secondary = mask.r * mask.b * (1.0 - mask.g) + mask.b * (1.0 - mask.r) * (1.0 - mask.g);
	} else {
		primary = key_weight(color, primary_key);
		secondary = key_weight(color, secondary_key);
	}
	color = mix(color, repaint(color, primary_key, primary_color.rgb), primary * primary_color.a);
	color = mix(color, repaint(color, secondary_key, secondary_color.rgb), secondary * secondary_color.a);
	ALBEDO = color;
	ROUGHNESS = roughness;
}
