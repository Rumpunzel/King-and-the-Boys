@tool
extends CompositorEffect
## Tilt-shift by distance across the floor: blurs what lies far from the focal point (where the camera's centre ray meets the
## floor, under the player's figure) and keeps what stands near it sharp at any height, unlike depth of field, which measures from
## the camera. A compute shader ([code]focus_blur.glsl[/code]) after the transparent pass, before glow and tone mapping

const _SHADER: RDShaderFile = preload("uid://c8hkh7epogoxv") # focus_blur.glsl
const _COPY_SHADER: RDShaderFile = preload("uid://c1mbx5oqgbddd") # focus_copy.glsl

## Metres across the floor from the focal point that stay sharp
@export var focus_radius: float = 5.0
## Metres beyond them until the blur is full
@export var blur_falloff: float = 8.0
## The full blur's radius, in pixels of a frame 1080 pixels high
@export var max_blur: float = 7.0

var _device: RenderingDevice
var _shader: RID
var _pipeline: RID
var _copy_shader: RID
var _copy_pipeline: RID
var _sampler: RID
var _copy: RID
var _copy_size: Vector2i
# The inverse projection and the camera transform, kept between frames and updated in place
var _matrices: RID

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	access_resolved_depth = true
	RenderingServer.call_on_render_thread(_initialize)

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or not _device: return
	for rid: RID in [_matrices, _copy, _sampler, _pipeline, _shader, _copy_pipeline, _copy_shader]:
		if rid.is_valid(): _device.free_rid(rid)

func _initialize() -> void:
	_device = RenderingServer.get_rendering_device()
	# Without a rendering device (headless, the dummy renderer) nothing is blurred
	if not _device: return
	_shader = _device.shader_create_from_spirv(_SHADER.get_spirv())
	_pipeline = _device.compute_pipeline_create(_shader)
	_copy_shader = _device.shader_create_from_spirv(_COPY_SHADER.get_spirv())
	_copy_pipeline = _device.compute_pipeline_create(_copy_shader)
	var sampler_state: RDSamplerState = RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler = _device.sampler_create(sampler_state)
	_matrices = _device.uniform_buffer_create(128)

func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if not _device or not _pipeline.is_valid() or callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT: return
	var buffers: RenderSceneBuffersRD = render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene_data: RenderSceneDataRD = render_data.get_render_scene_data() as RenderSceneDataRD
	if not buffers or not scene_data: return
	var size: Vector2i = buffers.get_internal_size()
	if size.x == 0 or size.y == 0: return
	var push_constants: PackedFloat32Array = [size.x, size.y, focus_radius, blur_falloff, max_blur * size.y / 1080.0, 0.0, 0.0, 0.0]
	for view: int in buffers.get_view_count():
		var color: RID = buffers.get_color_layer(view)
		var depth: RID = buffers.get_depth_layer(view)
		_prepare_copy(size)
		# Uniform sets come from Godot's cache, which keeps them while their textures live
		var copy_set: RID = UniformSetCacheRD.get_cache(_copy_shader, 0, [
			_uniform(RenderingDevice.UNIFORM_TYPE_IMAGE, 0, [color]),
			_uniform(RenderingDevice.UNIFORM_TYPE_IMAGE, 1, [_copy]),
		])
		_dispatch(_copy_pipeline, copy_set, push_constants.slice(0, 4), size)
		var matrices: PackedByteArray = _get_matrices(scene_data, view).to_byte_array()
		_device.buffer_update(_matrices, 0, matrices.size(), matrices)
		var uniform_set: RID = UniformSetCacheRD.get_cache(_shader, 0, [
			_uniform(RenderingDevice.UNIFORM_TYPE_IMAGE, 0, [color]),
			_uniform(RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE, 1, [_sampler, _copy]),
			_uniform(RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE, 2, [_sampler, depth]),
			_uniform(RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, 3, [_matrices]),
		])
		_dispatch(_pipeline, uniform_set, push_constants, size)

func _dispatch(pipeline: RID, uniform_set: RID, push_constants: PackedFloat32Array, size: Vector2i) -> void:
	var compute_list: int = _device.compute_list_begin()
	_device.compute_list_bind_compute_pipeline(compute_list, pipeline)
	_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	_device.compute_list_set_push_constant(compute_list, push_constants.to_byte_array(), push_constants.size() * 4)
	_device.compute_list_dispatch(compute_list, ceili(size.x / 8.0), ceili(size.y / 8.0), 1)
	_device.compute_list_end()

## A texture to read the frame from while the shader writes it (the frame's colour buffer can not be a copy source, so a compute
## pass copies it, see [code]focus_copy.glsl[/code]); made again when the frame's size changes
func _prepare_copy(size: Vector2i) -> void:
	if _copy.is_valid() and _copy_size == size: return
	if _copy.is_valid(): _device.free_rid(_copy)
	var copy_format: RDTextureFormat = RDTextureFormat.new()
	copy_format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	copy_format.width = size.x
	copy_format.height = size.y
	copy_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	_copy = _device.texture_create(copy_format, RDTextureView.new())
	_copy_size = size

## The inverse projection and the camera's transform, column by column, as the shader's std140 block wants them
func _get_matrices(scene_data: RenderSceneDataRD, view: int) -> PackedFloat32Array:
	var inverse_projection: Projection = scene_data.get_view_projection(view).inverse()
	var camera: Projection = Projection(scene_data.get_cam_transform())
	var values: PackedFloat32Array = []
	for matrix: Projection in [inverse_projection, camera]:
		for column: Vector4 in [matrix.x, matrix.y, matrix.z, matrix.w]: values.append_array([column.x, column.y, column.z, column.w])
	return values

func _uniform(uniform_type: RenderingDevice.UniformType, binding: int, ids: Array[RID]) -> RDUniform:
	var rd_uniform: RDUniform = RDUniform.new()
	rd_uniform.uniform_type = uniform_type
	rd_uniform.binding = binding
	for id: RID in ids: rd_uniform.add_id(id)
	return rd_uniform
