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

## [param chosen_body] is the look the player picked in the lobby, used if it fits
func get_character_data(character_profile: CharacterProfile, variation: int, chosen_body: Dictionary = {}) -> Dictionary[StringName, Variant]:
	return character_profile.create_character_data(variation, transform, chosen_body)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
