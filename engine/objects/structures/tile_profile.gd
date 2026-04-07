@tool
@icon("uid://bes0anop2dh5u")
class_name TileProfile
extends StructureProfile

@export var connections: Array[Vector2i] = [
		Vector2i.UP,
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
	]

@export_group("Configuration")

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings + super._get_configuration_warnings()
