@tool
@icon("uid://dsi6g62c3spch")
class_name StructureHitBox
extends HitBox

@export var structure: Structure

@export_group("Configuration")

func update_hitbox() -> void:
	assert(structure)
	if not structure.profile:
		assert(Engine.is_editor_hint())
		_collision_shape.shape = null
		_collision_shape.position = Vector3.ZERO
		_collision_shape.rotation_degrees = Vector3.ZERO
		return
	structure.profile.configure_hit_box(_collision_shape)

func get_body() -> Structure:
	return structure

func get_model() -> Model:
	return structure.model

func get_heads_up_anchor() -> Vector3:
	return structure.get_heads_up_anchor()

func _on_profile_changed() -> void:
	update_hitbox()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not structure: warnings.append("Missing Structure reference.")
	return warnings + super._get_configuration_warnings()
