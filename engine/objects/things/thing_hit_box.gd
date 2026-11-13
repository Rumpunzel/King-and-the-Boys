@tool
@icon("uid://bv63hb5gynt8d")
class_name ThingHitBox
extends HitBox

@export var thing: Thing

func get_body() -> Thing:
	return thing

func get_model() -> Model:
	return thing.model

func get_heads_up_anchor() -> Vector3:
	return thing.get_heads_up_anchor()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not thing: warnings.append("Missing Thing reference.")
	return warnings
