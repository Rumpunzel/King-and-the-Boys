#[compute]
#version 450
// Copies the frame into a texture the focus blur reads while it writes the frame (see focus_blur.gd): the frame's colour buffer
// can not be a copy source

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D color_image;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D copy_image;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 padding;
} params;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(pixel, ivec2(params.raster_size)))) return;
	imageStore(copy_image, pixel, imageLoad(color_image, pixel));
}
