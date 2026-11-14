@tool
@icon("uid://c4udocqr7qeyj")
class_name ThingProfile
extends Profile

enum Groups {
	ITEMS,
}

## thing.tscn, loaded on first use and kept: a scene nothing holds is freed after each instance and read from disk again
static var _thing_scene: PackedScene

@export var group: Groups = Groups.ITEMS:
	set(new_value):
		group = new_value
		changed.emit()

@export var spawn_animation: ModelAnimation = preload("uid://djq27fwrmrv2")

@export_group("")
@export_group("Configuration")

func create(variation: int, spawn_transform: Transform3D, status: Thing.Status) -> Thing:
	if not _thing_scene: _thing_scene = load("uid://dnxaisin8ueu5")
	var new_thing: Thing = _thing_scene.instantiate()
	new_thing.variation = variation
	new_thing.profile = self
	new_thing.transform = spawn_transform
	new_thing.status = status
	return new_thing

func get_group_name() -> StringName:
	var group_name: StringName = Groups.keys()[group]
	return group_name.capitalize()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _model_variations.is_empty(): warnings.append("Missing model variations scene.")
	return warnings + super._get_configuration_warnings()
