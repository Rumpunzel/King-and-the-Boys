@tool
@icon("uid://cmkguhmw7vdp1")
class_name CharacterPanel
extends PanelContainer

@export_group("Configuration")
@export var _placeholder_avatar: Texture2D
@export var _character_portrait: TextureRect
@export var _character_name: Label

var character: CharacterProfile:
	set = set_character

func set_character(new_character: CharacterProfile) -> void:
	character = new_character
	if not character:
		_character_portrait.texture = _placeholder_avatar
		_character_name.text = ""
		return
	_character_portrait.texture = character.portrait
	_character_name.text = character.name

## Hides the portrait while a 3D model stands in its place; the space stays
func set_portrait_shown(shown: bool) -> void:
	_character_portrait.self_modulate.a = 1.0 if shown else 0.0

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _character_portrait: warnings.append("Missing character portrait reference.")
	if not _character_name: warnings.append("Missing character name reference.")
	return warnings
