@tool
@icon("uid://c4udocqr7qeyj")
class_name ThingProfile
extends Profile

enum Groups {
	ITEMS,
}

@export var group: Groups = Groups.ITEMS:
	set(new_value):
		group = new_value
		changed.emit()

@export_custom(PROPERTY_HINT_RANGE, "0.001,1000.0,exp,suffix:kg") var mass: float = 1.0:
	set(new_value):
		mass = new_value
		changed.emit()

@export_group("")
@export_group("Configuration")

func create(variation: int, spawn_transform: Transform3D) -> Thing:
	var scene: PackedScene = load("uid://dnxaisin8ueu5")
	var new_thing: Thing = scene.instantiate()
	new_thing.variation = variation
	new_thing.profile = self
	new_thing.transform = spawn_transform
	return new_thing

func get_group_name() -> StringName:
	var group_name: StringName = Groups.keys()[group]
	return group_name.capitalize()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _model_variations.is_empty(): warnings.append("Missing model variations scene.")
	return warnings + super._get_configuration_warnings()
