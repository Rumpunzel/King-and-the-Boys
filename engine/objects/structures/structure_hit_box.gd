@tool
@icon("uid://dsi6g62c3spch")
class_name StructureHitBox
extends HitBox

@export var structure: Structure

func get_body() -> Structure:
	return structure

func get_model() -> Model:
	return structure.model

func get_heads_up_anchor() -> Vector3:
	return structure.get_heads_up_anchor()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not structure: warnings.append("Missing Structure reference.")
	return warnings
