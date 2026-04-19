@tool
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
		if not player.character: player.character = _character_panel.character
		_update_player_panel()
		player.player_info_changed.connect(_on_player_info_changed)

@export_group("Configuration")
@export var _character_panel: CharacterPanel
@export var _player_info: PlayerInfo
@export var _ready_button: ToggleButton

func _unhandled_key_input(event: InputEvent) -> void:
	if not _character_panel is CharacterSelection: return
	if event is InputEventKey and (event as InputEventKey).as_text_key_label() == "R" and (event as InputEventKey).is_pressed():
		(_character_panel as CharacterSelection).randomize_character()

func _clear() -> void:
	modulate.a = 0.5
	_player_info.player = null
	_character_panel.character = null
	_ready_button.button_pressed = false
	_ready_button.disabled = true
	_ready_button.modulate.a = 0.0

func _update_player_panel() -> void:
	modulate.a = 1.0
	_player_info.player = player
	_character_panel.character = player.character
	_ready_button.button_pressed = true
	_ready_button.disabled = false
	_ready_button.modulate.a = 1.0

func _on_character_selected(character: CharacterProfile) -> void:
	if not player or player.character == character: return
	player.character = character

func _on_player_info_changed() -> void:
	print(player)
	assert(player)
	_character_panel.character = player.character

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _character_panel: warnings.append("Missing CharacterPanel reference.")
	if not _player_info: warnings.append("Missing PlayerInfo reference.")
	if not _ready_button: warnings.append("Missing ready button reference.")
	return warnings
