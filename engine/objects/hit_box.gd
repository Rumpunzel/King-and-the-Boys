@tool
@icon("uid://bv63hb5gynt8d")
class_name HitBox
extends Area3D

signal haunted(haunting: Character)
signal unhaunted

@export_group("Configuration")
@export var _collision_shape: CollisionShape3D

@rpc("any_peer", "call_local", "reliable")
func haunt(haunting_path: NodePath) -> void:
	var haunting: Character = get_node(haunting_path)
	assert(haunting)
	haunted.emit(haunting)

@rpc("any_peer", "call_local", "reliable")
func unhaunt() -> void:
	unhaunted.emit()

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
