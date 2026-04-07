@tool
@icon("uid://bes0anop2dh5u")
class_name StructureProfile
extends Profile

enum Groups {
	BUILDING,
	FLORA,
}

@export var group: Groups = Groups.BUILDING

@export var grid_cell_extents: Vector3i = Vector3i.ONE

@export_group("")
@export_group("Configuration")

func create(variation: int, spawn_transform: Transform3D) -> Structure:
	var scene: PackedScene = load("uid://d4b5bccvs2ik1")
	var new_structure: Structure = scene.instantiate()
	new_structure.variation = variation
	new_structure.profile = self
	new_structure.transform = spawn_transform
	return new_structure

func get_group_name() -> StringName:
	var group_name: StringName = Groups.keys()[group]
	return group_name.capitalize()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _model_variations.is_empty(): warnings.append("Missing model variations scene.")
	return warnings + super._get_configuration_warnings()
