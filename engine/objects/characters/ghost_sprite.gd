@tool
@icon("uid://c8lah4qxw5f0v")
class_name GhostSprite
extends Model

@export_group("Configuration")

func play_animation(_normalized_velocity: Vector3, _is_on_floor: bool) -> void:
	pass

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings + super._get_configuration_warnings()
