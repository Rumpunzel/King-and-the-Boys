@tool
@icon("uid://cscgs7miwut5n")
class_name ThingSpawnPoint
extends SpawnPoint

@export var thing_profile: ThingProfile
@export_enum("ThingSpawnPoints") var role: String = "ThingSpawnPoints"

@export_group("Configuration")

func _enter_tree() -> void:
	add_to_group(role)

func get_thing_data() -> Dictionary[StringName, Variant]:
	assert(thing_profile)
	var thing_data: Dictionary[StringName, Variant] = {
		Thing.VARIATION: variation,
		Thing.PROFILE_PATH: thing_profile.resource_path,
		Thing.SPAWN_TRANSFORM: transform,
	}
	Thing.validate_thing_data(thing_data)
	return thing_data

func get_profile() -> ThingProfile:
	return thing_profile

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
