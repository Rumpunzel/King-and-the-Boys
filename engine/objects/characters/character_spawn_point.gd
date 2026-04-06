@tool
@icon("uid://duke3cveuxxso")
class_name CharacterSpawnPoint
extends SpawnPoint

@export var character_profile: CharacterProfile
## Maximum number of [Character]s allowed to be spawned by this [CharacterSpawnPoint]
## When set to [code]<=0[/code], there is no limit
@export_enum("CharacterSpawnPoints", "PlayerSpawnPoints") var role: String = "CharacterSpawnPoints"

@export_group("Configuration")

func _enter_tree() -> void:
	add_to_group(role)

func get_character_data() -> Dictionary[StringName, Variant]:
	var character_data: Dictionary[StringName, Variant] = {
		Character.VARIATION: variation,
		Character.PROFILE_PATH: character_profile.resource_path,
		Character.SPAWN_TRANSFORM: transform,
	}
	Character.validate_character_data(character_data)
	return character_data

func get_profile() -> CharacterProfile:
	return character_profile

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings + super._get_configuration_warnings()
