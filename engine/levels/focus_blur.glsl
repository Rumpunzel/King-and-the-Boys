#[compute]
#version 450
// Blurs the frame by how far each pixel lies from the focal point across the floor, not from the camera: the focal point is where
// the camera's centre ray meets the floor (the camera looks at the player's figure), so all that stands near it (an arch over the
// figure) stays sharp however tall it is, and the dungeon blurs with distance like a photo of a miniature (see focus_blur.gd)

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict writeonly image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D source_color;
layout(set = 0, binding = 2) uniform sampler2D depth_texture;
layout(set = 0, binding = 3, std140) uniform Matrices {
	mat4 inverse_projection;
	mat4 camera_transform;
} matrices;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	// Metres across the floor from the focal point that stay sharp
	float focus_radius;
	// Metres beyond them until the blur is full
	float blur_falloff;
	// The full blur's radius, in pixels
	float max_blur;
	float padding_0;
	float padding_1;
	float padding_2;
} params;

const int SAMPLES = 24;
const float GOLDEN_ANGLE = 2.39996323;

vec3 world_position(vec2 uv, float depth) {
	vec4 view = matrices.inverse_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	return (matrices.camera_transform * vec4(view.xyz, 1.0)).xyz;
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(pixel, ivec2(params.raster_size)))) return;
	vec2 uv = (vec2(pixel) + 0.5) / params.raster_size;
	vec3 world = world_position(uv, texture(depth_texture, uv).r);
	vec3 eye = matrices.camera_transform[3].xyz;
	vec3 forward = -matrices.camera_transform[2].xyz;
	vec3 focus = eye + forward * (eye.y / max(-forward.y, 0.001));
	float away = length(world.xz - focus.xz);
	float radius = smoothstep(params.focus_radius, params.focus_radius + params.blur_falloff, away) * params.max_blur;
	if (radius < 0.5) {
		imageStore(color_image, pixel, texture(source_color, uv));
		return;
	}
	// A disc of samples spread by the golden angle
	vec4 sum = vec4(0.0);
	for (int i = 0; i < SAMPLES; i++) {
		float reach = sqrt((float(i) + 0.5) / float(SAMPLES)) * radius;
		float angle = float(i) * GOLDEN_ANGLE;
		sum += texture(source_color, uv + vec2(cos(angle), sin(angle)) * reach / params.raster_size);
	}
	imageStore(color_image, pixel, sum / float(SAMPLES));
}
