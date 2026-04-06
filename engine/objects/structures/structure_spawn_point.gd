@tool
@icon("uid://5w8hyoyx7uqy")
class_name StructureSpawnPoint
extends SpawnPoint

@export var structure_profile: StructureProfile
@export_enum("StructureSpawnPoints") var role: String = "StructureSpawnPoints"

@export_group("Configuration")

func _enter_tree() -> void:
	add_to_group(role)

func get_structure_data() -> Dictionary[StringName, Variant]:
	assert(structure_profile)
	var structure_data: Dictionary[StringName, Variant] = {
		Structure.VARIATION: variation,
		Structure.PROFILE_PATH: structure_profile.resource_path,
		Structure.SPAWN_TRANSFORM: transform,
	}
	Structure.validate_structure_data(structure_data)
	return structure_data

func get_profile() -> StructureProfile:
	return structure_profile

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
