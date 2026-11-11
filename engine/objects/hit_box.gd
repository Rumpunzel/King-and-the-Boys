@tool
@icon("uid://bv63hb5gynt8d")
class_name HitBox
extends Area3D

signal controlled(controller: Character)
signal released

@export_group("Configuration")
@export var _collision_shape: CollisionShape3D

@rpc("any_peer", "call_local", "reliable")
func take_control(controller_path: NodePath) -> void:
	var controller: Character = get_node(controller_path)
	assert(controller)
	controlled.emit(controller)

@rpc("any_peer", "call_local", "reliable")
func release_control() -> void:
	released.emit()

func get_body() -> Node3D:
	assert(false, "HitBox.get_body is 'virtual' and needs to be overriden!")
	return null

func get_model() -> Model:
	assert(false, "HitBox.get_model is 'virtual' and needs to be overriden!")
	return null

func get_heads_up_anchor() -> Vector3:
	assert(false, "HitBox.get_heads_up_anchor is 'virtual' and needs to be overriden!")
	return Vector3.ZERO

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _collision_shape: warnings.append("Missing CollisionShape3D reference.")
	return warnings
