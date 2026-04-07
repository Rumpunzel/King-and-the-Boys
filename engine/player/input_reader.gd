@tool
@icon("uid://bkxn2uupbbt34")
class_name InputReader
extends Node

@export_group("Configuration")
@export var _camera: Camera3D

var direction_input: Vector2 = Vector2.ZERO

func _ready() -> void:
	if Engine.is_editor_hint(): return
	set_process(is_multiplayer_authority())
	if not is_multiplayer_authority(): return
	# Only collect input if this is the local [Player]
	_collect_input()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	assert(is_multiplayer_authority())
	# Only collect input if this is the local [Player]
	_collect_input()

func read_movement_input() -> Vector2:
	if get_viewport().is_input_handled(): return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func get_camera_adjusted_direction_input() -> Vector2:
	var camera_forward: Vector3 = _camera.transform.basis.z
	camera_forward.y = 0.0
	var camera_right: Vector3 = _camera.transform.basis.x
	camera_right.y = 0.0
	var adjusted_input_vector: Vector3 = camera_forward.normalized() * direction_input.y + camera_right.normalized() * direction_input.x
	return Vector2(adjusted_input_vector.x, adjusted_input_vector.z)

func _collect_input() -> void:
	direction_input = read_movement_input()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _camera: warnings.append("Missing Camera3D reference.")
	return warnings
