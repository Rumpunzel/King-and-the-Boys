@tool
@icon("uid://cmkguhmw7vdp1")
class_name HeroStats
extends Container
## Shows a hero's strength, intelligence, agility and movement in the lobby

@export_group("Configuration")
@export var _strength_label: Label
@export var _intelligence_label: Label
@export var _agility_label: Label
@export var _movement_label: Label

## The hero shown; none clears the stats
var character: CharacterProfile:
	set(new_character):
		character = new_character
		if is_node_ready(): _update()

func _ready() -> void:
	if Engine.is_editor_hint(): return
	_update()

func _update() -> void:
	_strength_label.text = str(character.strength) if character else ""
	_intelligence_label.text = str(character.intelligence) if character else ""
	_agility_label.text = str(character.agility) if character else ""
	_movement_label.text = str(character.speed) if character else ""

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _strength_label: warnings.append("Missing strength label reference.")
	if not _intelligence_label: warnings.append("Missing intelligence label reference.")
	if not _agility_label: warnings.append("Missing agility label reference.")
	if not _movement_label: warnings.append("Missing movement label reference.")
	return warnings
