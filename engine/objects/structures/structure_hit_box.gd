@tool
@icon("uid://dsi6g62c3spch")
class_name StructureHitBox
extends HitBox

@export var structure: Structure

func get_body() -> Structure:
	return structure

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not structure: warnings.append("Missing Structure reference.")
	return warnings
