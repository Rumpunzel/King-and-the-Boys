shader_type spatial;

// Props the camera looks past: fragments near the line from the camera to the local player's character are dithered away, so
// arches and pillars standing between the camera and the player fade out softly (see OcclusionTarget). Shadows stay whole.

global uniform vec3 occlusion_target;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
// Lets strongly coloured parts glow (e.g. crystals in grey rock): emission by the albedo's saturation
uniform float saturated_glow = 0.0;
// Within this distance of the line fragments vanish completely; over the next fade_width they dither back in
uniform float clear_radius = 0.8;
uniform float fade_width = 1.2;

varying vec3 world_position;

// Thresholds of a 4 x 4 ordered dither
const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb;
	if (saturated_glow > 0.0) {
		float saturation = max(ALBEDO.r, max(ALBEDO.g, ALBEDO.b)) - min(ALBEDO.r, min(ALBEDO.g, ALBEDO.b));
		EMISSION = ALBEDO * saturated_glow * smoothstep(0.15, 0.4, saturation);
	}
	ROUGHNESS = roughness;
	if (!IN_SHADOW_PASS) {
		vec3 to_target = occlusion_target - CAMERA_POSITION_WORLD;
		float target_distance = length(to_target);
		vec3 direction = to_target / max(target_distance, 0.001);
		float along = dot(world_position - CAMERA_POSITION_WORLD, direction);
		// Only what stands between the camera and the target
		if (along > 0.0 && along < target_distance) {
			float off_line = length(world_position - CAMERA_POSITION_WORLD - direction * along);
			float visibility = clamp((off_line - clear_radius) / fade_width, 0.0, 1.0);
			ivec2 cell = ivec2(FRAGCOORD.xy) % 4;
			if (visibility < (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0) {
				discard;
			}
		}
	}
}
