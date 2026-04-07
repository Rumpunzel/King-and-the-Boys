@tool
@icon("uid://duke3cveuxxso")
class_name PlayerSpawnPoint
extends Marker3D

const PLAYER_SPAWN_POINTS: StringName = "PlayerSpawnPoints"

@export_group("Configuration")
@export var _editor_material: Material = preload("uid://dilpjt8kd3s4d")

func _enter_tree() -> void:
	add_to_group(PLAYER_SPAWN_POINTS)

#func _ready() -> void:
	#var _variation: int = variation if variation >= 0 else get_profile().get_random_variation()
	#if not Engine.is_editor_hint():
		#variation = _variation
		#return
	#var model: Model = get_profile().create_model(_variation)
	#if _editor_material: model.apply_material_override(_editor_material)
	#add_child(model)

func get_character_data(character_profile: CharacterProfile, variation: int) -> Dictionary[StringName, Variant]:
	var character_data: Dictionary[StringName, Variant] = {
		Character.VARIATION: variation,
		Character.PROFILE_PATH: character_profile.resource_path,
		Character.SPAWN_TRANSFORM: transform,
	}
	Character.validate_character_data(character_data)
	return character_data

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
