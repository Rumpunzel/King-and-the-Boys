@tool
class_name PlayerInfo
extends PanelContainer

@export var player: Player:
	set(new_player):
		if player:
			player.player_info_changed.disconnect(_update_player_info)
		player = new_player
		if not player:
			_clear()
			return
		if Engine.is_editor_hint(): return
		_update_player_info()
		player.player_info_changed.connect(_update_player_info)

@export_group("Configuration")
@export var _placeholder_name: String = "EMPTY"
@export var _host_indicator: Control
@export var _player_avatar: TextureRect
@export var _name: Label

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	Multiplayer.connected_to_multiplayer.connect(_on_connected_to_multiplayer)
	Multiplayer.disconnected_from_multiplayer.connect(_on_disconnected_from_multiplayer)

func _clear() -> void:
	name = _placeholder_name
	_host_indicator.visible = false
	_name.modulate = Color.WHITE
	_player_avatar.texture = null
	#_player_avatar.visible = player.player_avatar != null
	_name.text = _placeholder_name

func _update_player_info() -> void:
	name = "%d" % player.player_id
	_update_host_indicator()
	_name.modulate = Color("#c4850e") if player.is_local_player() else Color.WHITE
	_player_avatar.texture = player.player_avatar
	_player_avatar.visible = player.player_avatar != null
	_name.text = player.player_name

func _update_host_indicator() -> void:
	_host_indicator.visible = player and player.is_host()

func _on_connected_to_multiplayer() -> void:
	_update_host_indicator()

func _on_disconnected_from_multiplayer() -> void:
	_update_host_indicator()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _host_indicator: warnings.append("Missing host indicator reference.")
	if not _player_avatar: warnings.append("Missing player avatar reference.")
	if not _name: warnings.append("Missing player name reference.")
	return warnings
