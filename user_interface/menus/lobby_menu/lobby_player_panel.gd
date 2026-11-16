@tool
@icon("uid://bs3bnvm5r50sd")
class_name LobbyPlayerPanel
extends PanelContainer

@export var player: Player:
	set(new_player):
		if player:
			player.player_info_changed.disconnect(_on_player_info_changed)
		player = new_player
		if not player:
			_clear()
			return
		if Engine.is_editor_hint(): return
		_update_player_panel()
		player.player_info_changed.connect(_on_player_info_changed)

@export_group("Configuration")
## Shows the hero's portrait and name where the hero's model does not stand in the panel; optional
@export var _character_panel: CharacterPanel
## Lets the local player pick a hero; optional, other players' panels have none
@export var _hero_picker: HeroPicker
## Shows the hero's stats and abilities; optional
@export var _hero_stats: HeroStats
@export var _player_info: PlayerInfo
@export var _ready_button: ToggleButton

func get_character_panel() -> CharacterPanel: return _character_panel

## R asks the host for another free hero, picked at random
func _unhandled_key_input(event: InputEvent) -> void:
	if not _hero_picker or not player: return
	if event is InputEventKey and (event as InputEventKey).as_text_key_label() == "R" and (event as InputEventKey).is_pressed():
		player.ask_for_random_character()

func _clear() -> void:
	modulate.a = 0.5
	_player_info.player = null
	_show_character(null)
	if _hero_picker: _hero_picker.player = null
	_ready_button.button_pressed = false
	_ready_button.disabled = true
	_ready_button.modulate.a = 0.0

func _update_player_panel() -> void:
	modulate.a = 1.0
	_player_info.player = player
	_show_character(player.character)
	if _hero_picker: _hero_picker.player = player
	_ready_button.button_pressed = true
	_ready_button.disabled = false
	_ready_button.modulate.a = 1.0

func _show_character(character: CharacterProfile) -> void:
	if _character_panel: _character_panel.character = character
	if _hero_stats: _hero_stats.character = character

func _on_player_info_changed() -> void:
	assert(player)
	_show_character(player.character)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _character_panel and not _hero_stats: warnings.append("Missing CharacterPanel or HeroStats reference.")
	if not _player_info: warnings.append("Missing PlayerInfo reference.")
	if not _ready_button: warnings.append("Missing ready button reference.")
	return warnings
