@tool
@icon("uid://c73t2rg8wrdt3")
class_name Player
extends Synchronizer

signal player_info_changed

## Config
const PLAYER_SECTION: StringName = "player"

const ID: StringName = "player_id"
const NAME: StringName = "player_name"

@export var player_id: int = Multiplayer.HOST_ID:
	set(new_player_id):
		if not Engine.is_editor_hint(): name = "%d" % new_player_id
		player_id = new_player_id
		if Engine.is_editor_hint(): return
		set_multiplayer_authority(player_id)
		player_info_changed.emit()
		player_avatar = await Client.get_player_avatar(player_id)

@export var player_name: String:
	set(new_player_name):
		player_name = new_player_name
		if Engine.is_editor_hint(): return
		player_info_changed.emit()

@export var player_avatar: Texture2D:
	set(new_player_avatar):
		player_avatar = new_player_avatar
		if Engine.is_editor_hint(): return
		player_info_changed.emit()

@export var character: CharacterProfile:
	set(new_character):
		character = new_character
		if Engine.is_editor_hint(): return
		player_info_changed.emit()

@export_group("Configuration")

var _serialized_character: String:
	get: return character.resource_path if character else ""
	set(new_serialized_character): if not new_serialized_character.is_empty(): character = load(new_serialized_character)

static func create(new_player_id: int, new_player_name: String) -> Player:
	var scene: PackedScene = load("uid://bvdlyl1asckv4")
	var new_player: Player = scene.instantiate()
	new_player.player_id = new_player_id
	new_player.player_name = new_player_name
	return new_player

static func get_local_player_info() -> Dictionary[StringName, Variant]:
	var local_player_id: int = Multiplayer.HOST_ID
	var local_player_name: String = Client.get_player_name(local_player_id)
	var player_info: Dictionary[StringName, Variant] = {
		ID: local_player_id,
		NAME: local_player_name if not local_player_name.is_empty() else "Player %d" % local_player_id,
	}
	validate_player_info(player_info)
	return player_info

static func from_player_info(player_info: Dictionary[StringName, Variant]) -> Player:
	validate_player_info(player_info)
	var new_player_id: int = player_info[ID]
	var new_player_name: String = player_info[NAME]
	var new_player: Player = create(new_player_id, new_player_name)
	return new_player

static func validate_player_info(player_info: Dictionary[StringName, Variant]) -> void:
	assert(player_info.has_all([ID, NAME]))
	assert(player_info.size() == 2)

func is_host() -> bool: return player_id == Multiplayer.HOST_ID
func is_local_player() -> bool:
	if not Multiplayer.is_online(): return true
	if not is_inside_tree(): return Multiplayer.multiplayer.get_unique_id() == player_id
	return multiplayer.get_unique_id() == player_id

func get_player_info() -> Dictionary[StringName, Variant]:
	var player_info: Dictionary[StringName, Variant] = {
		ID: player_id,
		NAME: player_name if not player_name.is_empty() else "Player %d" % player_id,
	}
	validate_player_info(player_info)
	return player_info

func _to_string() -> String:
	return "[%d, %s]: %s" % [player_id, player_name, character]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
