@tool
class_name CharacterPanel
extends PanelContainer

var character: CharacterProfile:
	set = set_character

@export_group("Configuration")
@export var _placeholder_avatar: Texture2D
@export var _character_portrait: TextureRect
@export var _character_name: Label

func set_character(new_character: CharacterProfile) -> void:
	character = new_character
	if not character:
		_character_portrait.texture = _placeholder_avatar
		_character_name.text = ""
		return
	_character_portrait.texture = character.portrait
	_character_name.text = character.name

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _character_portrait: warnings.append("Missing character portrait reference.")
	if not _character_name: warnings.append("Missing character name reference.")
	return warnings
