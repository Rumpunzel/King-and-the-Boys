@tool
class_name CharacterSelection
extends CharacterPanel

signal character_selected(character: CharacterProfile)

@export var _available_characters: Array[CharacterProfile]

@export_group("Configuration")

func _ready() -> void:
	randomize_character()

func randomize_character() -> void:
	character = _available_characters.pick_random()

func set_character(new_character: CharacterProfile) -> void:
	super.set_character(new_character)
	character_selected.emit(character)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _available_characters.is_empty(): warnings.append("No available characters.")
	return warnings + super._get_configuration_warnings()
