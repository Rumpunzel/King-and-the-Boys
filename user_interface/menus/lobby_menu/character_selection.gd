@tool
@icon("uid://dflrk3do2ph2u")
class_name CharacterSelection
extends CharacterPanel

signal character_selected(character: CharacterProfile)

@export var _available_characters: Array[CharacterProfile]

@export_group("Configuration")

func _ready() -> void:
	randomize_character()

## Picks another character at random (R), so the pick always shows, see [member CharacterProfile.selected_animation]
func randomize_character() -> void:
	var others: Array[CharacterProfile] = _available_characters.filter(func(other: CharacterProfile) -> bool: return other != character)
	character = (others if not others.is_empty() else _available_characters).pick_random()

func set_character(new_character: CharacterProfile) -> void:
	super.set_character(new_character)
	character_selected.emit(character)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if _available_characters.is_empty(): warnings.append("No available characters.")
	return warnings + super._get_configuration_warnings()
