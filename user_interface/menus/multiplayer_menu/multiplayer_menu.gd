@tool
@abstract
@icon("uid://r4re5w2nnw4h")
class_name MultiplayerMenu
extends VBoxContainer

@export_group("Configuration")
@export var _player_name: BetterLineEdit

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	Multiplayer.disconnected_from_multiplayer.connect(_on_disconnected_from_multiplayer)
	GameConfig.config_updated.connect(_on_config_updated)

func _ready() -> void:
	if Engine.is_editor_hint(): return
	var local_player_name: String = Client.get_player_name(Multiplayer.HOST_ID)
	update_player_name(local_player_name)

@abstract func reset_menu() -> void

func update_player_name(player_name: String) -> void:
	if _player_name.text == player_name: return
	_player_name.text = player_name

func _on_player_name_text_changed(new_player_name: String) -> void:
	var local_player: Player = Lobby.get_local_player()
	local_player.player_name = new_player_name

func _on_disconnected_from_multiplayer() -> void:
	reset_menu()

# [Client] callbacks
func _on_config_updated(value: Variant, section: String, key: String) -> void:
	if section != Player.PLAYER_SECTION: return
	if key != Player.NAME: return
	assert(value is String)
	var player_name: String = value
	update_player_name(player_name)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _player_name: warnings.append("Missing player name reference.")
	return warnings
