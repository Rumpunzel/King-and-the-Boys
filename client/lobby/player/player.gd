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
		# Not recursive: children (e.g. the lobby's pick synchronizer) keep the host's authority
		set_multiplayer_authority(player_id, false)
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
		if new_character == character: return
		character = new_character
		_character_id_cache = ResourceId.of(character)
		if Engine.is_editor_hint(): return
		# The player who picks rolls the look; peers receive it through the synchronizer
		if is_local_player(): body = character.roll_body(0) if character else {}
		player_info_changed.emit()

## The look of [member character] this player rolled when picking it: {part: [int] -> mesh [ResourceId]: [String]}, see
## [method CharacterProfile.roll_body]. Shown in the lobby and used in game if it fits (see [method CharacterProfile.create_character_data])
var body: Dictionary = {}:
	set(new_body):
		body = new_body
		if Engine.is_editor_hint(): return
		player_info_changed.emit()

## Whether this player is ready for the game to start; the host decides, see [method Lobby.try_set_ready]
var ready_to_start: bool = false:
	set(new_ready_to_start):
		ready_to_start = new_ready_to_start
		if Engine.is_editor_hint(): return
		player_info_changed.emit()

@export_group("Configuration")

# Read and written by the HostSynchronizer (player.tscn) only: the host decides the hero, peers take what it syncs
@warning_ignore("unused_private_class_variable")
var _character_id: String:
	get: return _character_id_cache
	set(new_character_id):
		var found: Resource = ResourceId.find(new_character_id)
		character = found if found is CharacterProfile else null
# [ResourceId] of [member character], kept by its setter as the synchronizer reads [member _character_id] every tick
var _character_id_cache: String = ""

static func create(new_player_id: int, new_player_name: String) -> Player:
	var new_player: Player = (Files.load_kept("uid://bvdlyl1asckv4") as PackedScene).instantiate()
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

## Asks the host for the hero; the answer reaches every peer through [member character]
func ask_for_character(profile: CharacterProfile) -> void:
	request_character.rpc_id(Multiplayer.HOST_ID, ResourceId.of(profile))

## Asks the host for another free hero, picked at random
func ask_for_random_character() -> void:
	request_pick_random.rpc_id(Multiplayer.HOST_ID)

## Asks the host to mark this player ready or not
func ask_for_ready(new_ready: bool) -> void:
	request_ready_to_start.rpc_id(Multiplayer.HOST_ID, new_ready)

## Rolls another look for this player's hero; only the local player rolls its own body
func reroll_body() -> void:
	if not is_local_player() or not character: return
	body = character.roll_body(0)

## Host side: the player asks for a hero of the roster by its [ResourceId], see [method Lobby.try_pick]
@rpc("any_peer", "call_local", "reliable")
func request_character(character_id: String) -> void:
	if not _is_request_from_self(): return
	var hero: CharacterProfile = _find_roster_hero(character_id)
	if hero: Lobby.try_pick(self, hero)

## Host side: the player asks for a free hero at random, see [method Lobby.pick_random]
@rpc("any_peer", "call_local", "reliable")
func request_pick_random() -> void:
	if not _is_request_from_self(): return
	Lobby.pick_random(self)

## Host side: the player asks to be marked ready or not, see [method Lobby.try_set_ready]
@rpc("any_peer", "call_local", "reliable")
func request_ready_to_start(new_ready: bool) -> void:
	if not _is_request_from_self(): return
	Lobby.try_set_ready(self, new_ready)

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

## Whether this peer is the host and the request came from this player's peer (called directly, the host itself)
func _is_request_from_self() -> bool:
	if not multiplayer.is_server(): return false
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = Multiplayer.HOST_ID
	return sender_id == player_id

## The roster's hero [param character_id] names, checked by its file before anything is loaded; null if it is none
func _find_roster_hero(character_id: String) -> CharacterProfile:
	if not Lobby.hero_roster: return null
	var file_path: String = ResourceId.get_file_path(character_id)
	if file_path.is_empty(): return null
	for hero: CharacterProfile in Lobby.hero_roster.heroes:
		if hero and hero.resource_path == file_path:
			# The id may still point inside the hero's file
			var found: CharacterProfile = ResourceId.find(character_id) as CharacterProfile
			return found if Lobby.hero_roster.has(found) else null
	return null

func _to_string() -> String:
	return "[%d, %s]: %s" % [player_id, player_name, character]

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	return warnings
