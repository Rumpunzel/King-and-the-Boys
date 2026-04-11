@tool
class_name LobbyMenu
extends CanvasLayer

signal game_started

@export_group("Configuration")
@export var _player_infos_container: Control
@export var _player_info_scene: PackedScene

var _player_infos: Dictionary[Player, PlayerInfo] = {}

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	Lobby.player_connected.connect(_add_player)

func _ready() -> void:
	_clear()
	for index: int in range(Multiplayer.MAX_CONNECTIONS + 1): _create_player_info()
	if Engine.is_editor_hint(): return
	var connected_players: Array[Player] = Lobby.get_connected_players()
	for index: int in connected_players.size():
		var connected_player: Player = connected_players[index]
		_add_player(connected_player)

func _create_player_info() -> void:
	var new_player_info: PlayerInfo = _player_info_scene.instantiate()
	new_player_info.player = null
	_player_infos_container.add_child(new_player_info, true)

func _add_player(player: Player) -> void:
	assert(player)
	var empty_player_info: PlayerInfo = null
	for player_info: PlayerInfo in _get_player_infos():
		if player_info.player == null:
			empty_player_info = player_info
			break
	assert(empty_player_info)
	assert(empty_player_info.player == null)
	var available_character: CharacterProfile = _get_available_character()
	assert(available_character)
	player.character = available_character
	empty_player_info.player = player
	player.tree_exiting.connect(_remove_player.bind(player))
	_player_infos[player] = empty_player_info

func _remove_player(player: Player) -> void:
	var player_info_to_clear: PlayerInfo = _player_infos[player]
	player_info_to_clear.player = null

func _clear() -> void:
	_player_infos.clear()
	for player_info: PlayerInfo in _get_player_infos():
		_player_infos_container.remove_child(player_info)
		player_info.queue_free()

func _get_player_infos() -> Array[PlayerInfo]:
	var children: Array[Node] = _player_infos_container.get_children()
	var player_infos: Array[PlayerInfo] = []
	for child: Node in children: if child is PlayerInfo: player_infos.append(child)
	return player_infos

func _get_available_character() -> CharacterProfile:
	return load("uid://ro6wvnf88xbo")

func _on_start_pressed() -> void:
	game_started.emit()
	print_debug("Confirming Lobby for : %s" % [_player_infos.keys()])

func _on_game_status_changed(new_game_status: Game.GameStatus) -> void:
	visible = new_game_status < Game.GameStatus.RUNNING

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _player_infos_container: warnings.append("Missing player infos container.")
	if not _player_info_scene: warnings.append("Missing PlayerInfo reference.")
	return warnings
