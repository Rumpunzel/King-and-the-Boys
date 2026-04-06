@tool
class_name PlayerInfo
extends VBoxContainer

@export var player: Player:
	set(new_player):
		assert(not player)
		player = new_player
		if Engine.is_editor_hint(): return
		_update_player_info()
		player.player_info_changed.connect(_update_player_info)

@export_group("Configuration")
@export var _host_indicator: Control
@export var _local_indicator: Control
@export var _character_portrait: TextureRect
@export var _player_avatar: TextureRect
@export var _player_name: Label

func _update_player_info() -> void:
	name = "%d" % player.player_id
	_host_indicator.visible = player.player_id == Multiplayer.HOST_ID
	_local_indicator.visible = player.is_local_player()
	#_character_portrait.texture = 
	_player_avatar.texture = player.player_avatar
	_player_avatar.visible = player.player_avatar != null
	_player_name.text = player.player_name

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _character_portrait: warnings.append("Missing character portrait.")
	if not _player_name: warnings.append("Missing player name.")
	return warnings
