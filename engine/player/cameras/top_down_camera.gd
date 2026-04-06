@tool
class_name TopDownCamera
extends Camera3D

const _ray_length: float = 1000.0

@export var distance_off_ground: float = 24.0
@export var distance_from_follow: float = 24.0
@export var camera_angle_offset: float = 45.0
@export var camera_turn_angle: float = 90.0
@export var zoom: float = 1.0

@warning_ignore("unused_private_class_variable")
@export_tool_button("Frame origin", "Camera3D") var _frame_origin_action: Callable = frame_point.bind(Vector3.ZERO, true)
@export var _smoothing_speed: float = 12.0

var _turnIndex: int = 0
var _point_to_frame: Vector3
var _position_to_smooth_to: Vector3:
	set(new_position_to_smooth_to):
		_position_to_smooth_to = new_position_to_smooth_to
		set_process(true)

func _ready() -> void:
	frame_point(Vector3.ZERO, true)

func _process(delta: float) -> void:
	position = position.move_toward(_position_to_smooth_to, _smoothing_speed * delta)

func frame_node(node_to_frame: Node3D, instant: bool = false) -> void:
	assert(node_to_frame)
	frame_point(node_to_frame.position, instant)

func frame_point(point_to_frame: Vector3, instant: bool = false) -> void:
	assert(point_to_frame != null)
	_point_to_frame = point_to_frame
	var angle: float = deg_to_rad(_turnIndex * camera_turn_angle + camera_angle_offset)
	var inverse_zoom: float = 1.0 / zoom
	var inverse_zoom_root: float = sqrt(inverse_zoom)
	
	var offset: Vector3 = Vector3(
		distance_from_follow * cos(angle) * inverse_zoom_root,
		distance_off_ground * inverse_zoom - _point_to_frame.y,
		distance_from_follow * sin(angle) * inverse_zoom_root,
	)
	
	if not instant:
		_position_to_smooth_to = _point_to_frame + offset
		return
	set_process(false)
	position = _point_to_frame + offset
	look_at(point_to_frame, Vector3.UP)

func get_adjusted_movement(input_vector: Vector2) -> Vector2:
	var camera_forward: Vector3 = transform.basis.z
	camera_forward.y = 0.0
	var camera_right: Vector3 = transform.basis.x
	camera_right.y = 0.0
	var adjusted_input_vector: Vector3 = camera_forward.normalized() * input_vector.y + camera_right.normalized() * input_vector.x
	return Vector2(adjusted_input_vector.x, adjusted_input_vector.z)

func mouse_as_world_point() -> CameraRay:
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = project_ray_origin(mouse_position)
	var to: Vector3 = from + project_ray_normal(mouse_position) * _ray_length
	return CameraRay.new(from, to)


class CameraRay:
	var from: Vector3
	var to: Vector3
	
	func _init(new_from: Vector3, new_to: Vector3) -> void:
		from = new_from
		to = new_to
