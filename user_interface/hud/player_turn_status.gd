@tool
@icon("uid://dopairwuunnb0")
class_name PlayerTurnStatus
extends HBoxContainer
## Another player's turn: avatar, name and their character's moves; dimmed once they passed

@export var player: Player:
	set(new_player):
		player = new_player
		if _avatar: _avatar.player = player
		if _name: _name.player = player

@export var character: Character:
	set(new_character):
		character = new_character
		if _moves_bar: _moves_bar.character = character

## Opacity of the row once the player passed
@export_range(0.0, 1.0) var passed_alpha: float = 0.5

@export_group("Configuration")
@export var _avatar: PlayerAvatar
@export var _name: PlayerName
@export var _moves_bar: MovesBar

func show_passed(passed: bool) -> void:
	modulate.a = passed_alpha if passed else 1.0

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _avatar: warnings.append("Missing PlayerAvatar reference.")
	if not _name: warnings.append("Missing PlayerName reference.")
	if not _moves_bar: warnings.append("Missing MovesBar reference.")
	return warnings
