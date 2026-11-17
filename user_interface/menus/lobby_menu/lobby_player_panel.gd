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
## Shows the hero's name, and its portrait while no model stands in the panel
@export var _character_panel: CharacterPanel
@export var _player_info: PlayerInfo
@export var _ready_button: ToggleButton

func get_character_panel() -> CharacterPanel: return _character_panel

func _ready() -> void:
	if Engine.is_editor_hint(): return
	_ready_button.toggled.connect(_on_ready_toggled)

func _clear() -> void:
	modulate.a = 0.5
	_player_info.player = null
	_show_character(null)
	_show_ready(false)
	_ready_button.disabled = true
	_ready_button.modulate.a = 0.0

func _update_player_panel() -> void:
	modulate.a = 1.0
	_player_info.player = player
	_show_character(player.character)
	_update_ready_button()

## Ready only shows online and for guests: the host starts the game instead. The local guest toggles it, the host decides
func _update_ready_button() -> void:
	var shown: bool = Multiplayer.is_online() and not player.is_host()
	_ready_button.modulate.a = 1.0 if shown else 0.0
	_ready_button.disabled = not shown or not player.is_local_player()
	_show_ready(player.ready_to_start)

## Shows the ready state the host decided, without asking for it again
func _show_ready(ready_to_start: bool) -> void:
	_ready_button.set_pressed_no_signal(ready_to_start)
	# Not before the button stored its untoggled text and icon
	if _ready_button.is_node_ready(): _ready_button.update_button()

func _on_ready_toggled(toggled_on: bool) -> void:
	if not player or not player.is_local_player(): return
	player.ask_for_ready(toggled_on)
	# The button follows the host's answer: it shows the new state once the host took it
	_show_ready(player.ready_to_start)

func _show_character(character: CharacterProfile) -> void:
	_character_panel.character = character

func _on_player_info_changed() -> void:
	assert(player)
	_show_character(player.character)
	_update_ready_button()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _character_panel: warnings.append("Missing CharacterPanel reference.")
	if not _player_info: warnings.append("Missing PlayerInfo reference.")
	if not _ready_button: warnings.append("Missing ready button reference.")
	return warnings
