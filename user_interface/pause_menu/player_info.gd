@tool
class_name PlayerInfo
extends VBoxContainer

@export var player: Player:
	set(new_player):
		if player:
			player.player_info_changed.connect(_update_player_info)
		player = new_player
		if not player:
			_clear()
			return
		if Engine.is_editor_hint(): return
		_update_player_info()
		player.player_info_changed.connect(_update_player_info)

@export_group("Configuration")
@export var _placeholder_avatar: Texture2D
@export var _placeholder_name: String = "EMPTY"
@export var _host_indicator: Control
@export var _local_indicator: Control
@export var _character_portrait: TextureRect
@export var _character_name: Label
@export var _player_avatar: TextureRect
@export var _player_name: Label
@export var _ready: CheckBox

func _clear() -> void:
	name = _placeholder_name
	_host_indicator.visible = false
	_local_indicator.visible = false
	_character_portrait.texture = _placeholder_avatar
	_character_name.text = "?"
	_player_avatar.texture = null
	#_player_avatar.visible = player.player_avatar != null
	_player_name.text = _placeholder_name
	_ready.button_pressed = false
	_ready.disabled = true

func _update_player_info() -> void:
	name = "%d" % player.player_id
	_host_indicator.visible = player.player_id == Multiplayer.HOST_ID
	_local_indicator.visible = player.is_local_player()
	_character_portrait.texture = player.character.portrait
	_character_name.text = player.character.name
	_player_avatar.texture = player.player_avatar
	_player_avatar.visible = player.player_avatar != null
	_player_name.text = player.player_name
	_ready.button_pressed = true
	_ready.disabled = false

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _character_portrait: warnings.append("Missing character portrait.")
	if not _player_name: warnings.append("Missing player name.")
	return warnings
