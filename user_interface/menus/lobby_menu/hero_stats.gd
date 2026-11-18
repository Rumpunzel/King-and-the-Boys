@tool
@icon("uid://cmkguhmw7vdp1")
class_name HeroStats
extends VBoxContainer
## Shows a hero's strength, intelligence, agility and movement in the lobby

@export_group("Configuration")
@export var _strength_score: Label
@export var _agility_score: Label
@export var _intelligence_score: Label
@export var _speed_score: Label

## The hero shown; none clears the stats
var character: CharacterProfile:
	set(new_character):
		character = new_character
		if is_node_ready(): _update()

func _ready() -> void:
	if Engine.is_editor_hint(): return
	_update()

func _update() -> void:
	_strength_score.text = str(character.strength) if character else ""
	_agility_score.text = str(character.agility) if character else ""
	_intelligence_score.text = str(character.intelligence) if character else ""
	_speed_score.text = str(character.speed) if character else ""

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _strength_score: warnings.append("Missing strength score Label reference.")
	if not _agility_score: warnings.append("Missing agility score Label reference.")
	if not _intelligence_score: warnings.append("Missing intelligence score Label reference.")
	if not _speed_score: warnings.append("Missing speed score Label reference.")
	return warnings
