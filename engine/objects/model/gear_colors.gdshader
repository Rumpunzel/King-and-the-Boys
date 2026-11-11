// Repaints a character atlas in a character's colours: the gear's highlights in its primary colour (the packs' slate or steel blue)
// and its secondary one (their gold), and the body's skin and hair. Body parts and gear share each atlas, and gear shows skin too
// (bare hands, arms). Atlases with colour masks (Fantasy Hero) find the colours by mask, others by their key colours.
// The colours are per mesh (instance uniforms, set by ModularModel.set_gear_colors and set_body_colors); a transparent colour keeps the atlas'
shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
// Fantasy Hero's Mask_01: cyan marks the primary colour, magenta and blue the secondary one
uniform sampler2D mask_texture : hint_default_black, filter_nearest;
// Fantasy Hero's Mask_03: skin in cyan, stubble in yellow, lips in magenta, all repainted from the skin colour
uniform sampler2D skin_mask_texture : hint_default_white, filter_nearest;
// Fantasy Hero's Mask_04: hair (with eyebrows and beards) in yellow; its cyan and magenta are leather
uniform sampler2D hair_mask_texture : hint_default_white, filter_nearest;
uniform bool use_mask = false;
// The atlas' own colours: found by them without a mask, and the shading of the repainted pixels is kept relative to them
uniform vec3 primary_key : source_color = vec3(0.29, 0.4, 0.49);
uniform vec3 secondary_key : source_color = vec3(0.75, 0.61, 0.32);
uniform vec3 skin_key : source_color = vec3(1.0, 0.8, 0.686);
uniform vec3 hair_key : source_color = vec3(0.271, 0.212, 0.141);
// How far a pixel may stray from a key colour and still count, without a mask
uniform float key_tolerance : hint_range(0.0, 0.5) = 0.06;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;

instance uniform vec4 primary_color : source_color = vec4(0.0);
instance uniform vec4 secondary_color : source_color = vec4(0.0);
instance uniform vec4 skin_color : source_color = vec4(0.0);
instance uniform vec4 hair_color : source_color = vec4(0.0);

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
	float skin = 0.0;
	float hair = 0.0;
	if (use_mask) {
		vec3 mask = texture(mask_texture, UV).rgb;
		primary = mask.g * mask.b * (1.0 - mask.r);
		secondary = mask.r * mask.b * (1.0 - mask.g) + mask.b * (1.0 - mask.r) * (1.0 - mask.g);
		vec3 skin_mask = texture(skin_mask_texture, UV).rgb;
		skin = 1.0 - min(skin_mask.r, min(skin_mask.g, skin_mask.b));
		vec3 hair_mask = texture(hair_mask_texture, UV).rgb;
		hair = hair_mask.r * hair_mask.g * (1.0 - hair_mask.b);
	} else {
		primary = key_weight(color, primary_key);
		secondary = key_weight(color, secondary_key);
		skin = key_weight(color, skin_key);
		hair = key_weight(color, hair_key);
	}
	color = mix(color, repaint(color, primary_key, primary_color.rgb), primary * primary_color.a);
	color = mix(color, repaint(color, secondary_key, secondary_color.rgb), secondary * secondary_color.a);
	color = mix(color, repaint(color, skin_key, skin_color.rgb), skin * skin_color.a);
	color = mix(color, repaint(color, hair_key, hair_color.rgb), hair * hair_color.a);
	ALBEDO = color;
	ROUGHNESS = roughness;
}
