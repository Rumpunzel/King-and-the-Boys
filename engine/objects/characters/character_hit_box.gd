@tool
@icon("uid://bykpbpoxx72ox")
class_name CharacterHitBox
extends HitBox

@export var character: Character

func get_body() -> Character:
	return character

func get_model() -> Model:
	return character.model

func get_heads_up_anchor() -> Vector3:
	return character.get_heads_up_anchor()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not character: warnings.append("Missing Character reference.")
	return warnings
